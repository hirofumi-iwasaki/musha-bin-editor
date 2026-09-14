// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:io';
import 'dart:math' as math;

import 'file_comparison.dart';

enum SaveOutcome { saved, externallyChanged, failed }

class SaveResult {
  const SaveResult(this.outcome, [this.message]);
  final SaveOutcome outcome;
  final String? message;
}

Future<SaveResult> safelySave({
  required String sourcePath,
  required FileStamp sourceStamp,
  required String destinationPath,
  required Map<int, int> edits,
  bool allowExternalChange = false,
  Future<void> Function(String stagedPath, String destinationPath)? install,
}) async {
  RandomAccessFile? input;
  IOSink? output;
  File? temporary;
  try {
    final current = await FileStamp.read(sourcePath);
    if (!current.matches(sourceStamp) && !allowExternalChange) {
      return const SaveResult(SaveOutcome.externallyChanged);
    }
    // A sandbox extension granted by NSSavePanel covers the selected file, not
    // arbitrary sibling files in its parent directory. Build the complete
    // output in the app's temporary directory, then atomically move it to the
    // user-selected destination.
    temporary = File(
      '${Directory.systemTemp.path}/mushagaeshi-save-$pid-${DateTime.now().microsecondsSinceEpoch}.tmp',
    );
    input = await File(sourcePath).open();
    output = temporary.openWrite(mode: FileMode.writeOnly);
    const blockSize = 1024 * 1024;
    for (var offset = 0; offset < current.size; offset += blockSize) {
      final data = await readExactRange(
        input,
        current.size,
        offset,
        math.min(blockSize, current.size - offset),
      );
      for (final entry in edits.entries) {
        if (entry.key >= offset && entry.key < offset + data.length) {
          data[entry.key - offset] = entry.value;
        }
      }
      output.add(data);
    }
    await output.flush();
    await output.close();
    output = null;
    await input.close();
    input = null;
    if (destinationPath == sourcePath &&
        !allowExternalChange &&
        !(await FileStamp.read(sourcePath)).matches(current)) {
      await temporary.delete();
      return const SaveResult(SaveOutcome.externallyChanged);
    }
    if (install != null) {
      await install(temporary.path, destinationPath);
    } else {
      try {
        await temporary.rename(destinationPath);
      } on FileSystemException {
        // A destination on another volume cannot be reached with rename(2).
        await temporary.copy(destinationPath);
        await temporary.delete();
      }
    }
    return const SaveResult(SaveOutcome.saved);
  } catch (error) {
    return SaveResult(SaveOutcome.failed, 'Unable to save file: $error');
  } finally {
    await input?.close();
    await output?.close();
    if (temporary != null && await temporary.exists()) {
      await temporary.delete().catchError((_) => temporary!);
    }
  }
}
