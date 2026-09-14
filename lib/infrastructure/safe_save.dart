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
}) async {
  RandomAccessFile? input;
  IOSink? output;
  File? temporary;
  try {
    final current = await FileStamp.read(sourcePath);
    if (!current.matches(sourceStamp) && !allowExternalChange) {
      return const SaveResult(SaveOutcome.externallyChanged);
    }
    final destination = File(destinationPath);
    final directory = destination.parent;
    temporary = File(
      '${directory.path}/.${destination.uri.pathSegments.last}.mushagaeshi-$pid-${DateTime.now().microsecondsSinceEpoch}.tmp',
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
    await temporary.rename(destinationPath);
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
