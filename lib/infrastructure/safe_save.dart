// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:io';
import 'dart:math' as math;

import 'file_comparison.dart';

/// The state reported by a platform-specific installation of a complete file.
///
/// An [ambiguous] result means that the installer cannot prove which copy is
/// now authoritative. In that case [recoveryPath] names a complete retained
/// copy for recovery.
enum SaveInstallation { installed, ambiguous, failed }

class SaveInstallResult {
  const SaveInstallResult._(this.status, {this.message, this.recoveryPath});

  const SaveInstallResult.installed() : this._(SaveInstallation.installed);
  const SaveInstallResult.failed(String message)
    : this._(SaveInstallation.failed, message: message);
  const SaveInstallResult.ambiguous(String message, String recoveryPath)
    : this._(
        SaveInstallation.ambiguous,
        message: message,
        recoveryPath: recoveryPath,
      );

  final SaveInstallation status;
  final String? message;
  final String? recoveryPath;
}

typedef SaveInstaller = Future<SaveInstallResult> Function(
  String stagedPath,
  String destinationPath,
);

enum SaveOutcome {
  saved,
  savedButCouldNotReopen,
  externallyChanged,
  destinationChanged,
  failed,
}

/// Application-owned failure state. The UI selects localized text from this
/// code and only appends [SaveResult.detail] as an OS diagnostic.
enum SaveError {
  noFileOpen,
  saveInProgress,
  otherPaneHasDestination,
  couldNotStart,
  noBackend,
  destinationDirectoryMissing,
  destinationChanged,
  installationAmbiguous,
  installationFailed,
  saveFailed,
  savedButCouldNotReopen,
}

class SaveResult {
  const SaveResult(this.outcome, {this.error, this.detail, this.recoveryPath});
  final SaveOutcome outcome;
  final SaveError? error;
  final String? detail;
  final String? recoveryPath;
}

class DestinationSnapshot {
  const DestinationSnapshot._(this.stamp);

  final FileStamp? stamp;

  static Future<DestinationSnapshot> capture(String path) async {
    final file = File(path);
    if (!await file.exists()) return const DestinationSnapshot._(null);
    return DestinationSnapshot._(await FileStamp.read(path));
  }

  Future<bool> matches(String path) async {
    final file = File(path);
    if (!await file.exists()) return stamp == null;
    if (stamp == null) return false;
    return stamp!.matches(await FileStamp.read(path));
  }
}

/// Streams [sourcePath] with a frozen copy of [edits] into a staged file.
///
/// Installation is deliberately delegated to a platform backend. A generic
/// rename-to-copy fallback can truncate an existing destination after a failed
/// replacement, so it is never used here. The backend receives only a fully
/// flushed and closed staged file.
Future<SaveResult> safelySave({
  required String sourcePath,
  required FileStamp sourceStamp,
  required String destinationPath,
  required Map<int, int> edits,
  bool allowExternalChange = false,
  SaveInstaller? install,
  String? stagingDirectory,
  DestinationSnapshot? destinationSnapshot,
}) async {
  // Copy before the first await. This is the document's immutable save
  // snapshot, without materialising its original bytes in memory.
  final frozenEdits = Map<int, int>.unmodifiable(Map<int, int>.from(edits));
  RandomAccessFile? input;
  IOSink? output;
  File? temporary;
  var keepTemporary = false;
  try {
    if (install == null) {
      return const SaveResult(SaveOutcome.failed, error: SaveError.noBackend);
    }
    final current = await FileStamp.read(sourcePath);
    if (!current.matches(sourceStamp) && !allowExternalChange) {
      return const SaveResult(SaveOutcome.externallyChanged);
    }
    final directory = Directory(
      stagingDirectory ?? File(destinationPath).parent.path,
    );
    if (!await directory.exists()) {
      return SaveResult(
        SaveOutcome.failed,
        error: SaveError.destinationDirectoryMissing,
        detail: directory.path,
      );
    }
    temporary = await _createExclusiveStage(directory);
    input = await File(sourcePath).open();
    output = temporary.openWrite(mode: FileMode.writeOnly);
    const blockSize = 1024 * 1024;
    final editEntries = frozenEdits.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    var editIndex = 0;
    for (var offset = 0; offset < current.size; offset += blockSize) {
      final data = await readExactRange(
        input,
        current.size,
        offset,
        math.min(blockSize, current.size - offset),
      );
      while (editIndex < editEntries.length &&
          editEntries[editIndex].key < offset) {
        editIndex++;
      }
      for (
        var index = editIndex;
        index < editEntries.length &&
            editEntries[index].key < offset + data.length;
        index++
      ) {
        final edit = editEntries[index];
        data[edit.key - offset] = edit.value;
      }
      output.add(data);
    }
    await output.flush();
    await output.close();
    output = null;
    await input.close();
    input = null;

    // This applies to Save As as well: an unchanged destination name does not
    // make the source safe to reread after it has changed externally.
    if (!allowExternalChange &&
        !(await FileStamp.read(sourcePath)).matches(current)) {
      return const SaveResult(SaveOutcome.externallyChanged);
    }

    if (destinationSnapshot != null &&
        !await destinationSnapshot.matches(destinationPath)) {
      return const SaveResult(
        SaveOutcome.destinationChanged,
        error: SaveError.destinationChanged,
      );
    }
    final installation = await install(temporary.path, destinationPath);
    switch (installation.status) {
      case SaveInstallation.installed:
        return const SaveResult(SaveOutcome.saved);
      case SaveInstallation.ambiguous:
        keepTemporary = true;
        return SaveResult(
          SaveOutcome.failed,
          error: SaveError.installationAmbiguous,
          detail: installation.message,
          recoveryPath: installation.recoveryPath ?? temporary.path,
        );
      case SaveInstallation.failed:
        return SaveResult(
          SaveOutcome.failed,
          error: SaveError.installationFailed,
          detail: installation.message,
        );
    }
  } catch (error) {
    return SaveResult(
      SaveOutcome.failed,
      error: SaveError.saveFailed,
      detail: error.toString(),
    );
  } finally {
    await input?.close();
    await output?.close();
    if (!keepTemporary && temporary != null && await temporary.exists()) {
      await temporary.delete().catchError((_) => temporary!);
    }
  }
}

Future<File> _createExclusiveStage(Directory directory) async {
  final random = math.Random.secure();
  for (var attempt = 0; attempt != 32; attempt++) {
    final file = File(
      '${directory.path}/.mushagaeshi-save-$pid-${DateTime.now().microsecondsSinceEpoch}-${random.nextInt(1 << 32)}.tmp',
    );
    try {
      await file.create(exclusive: true);
      return file;
    } on FileSystemException {
      // A collision is harmless; a later attempt uses a new unpredictable name.
    }
  }
  throw const FileSystemException('Unable to create an exclusive staging file');
}
