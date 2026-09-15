// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../infrastructure/file_comparison.dart';
import '../infrastructure/file_hash.dart';
import '../infrastructure/safe_save.dart';

class CompareController extends ChangeNotifier {
  PagedFile? left;
  PagedFile? right;
  Uint8List leftBytes = Uint8List(0);
  Uint8List rightBytes = Uint8List(0);
  int bytesPerRow = 16;
  int topRow = 0;
  int visibleRows = 24;
  int? selected;
  bool selectedLeft = true;
  bool loading = false;
  bool busy = false;
  bool complete = false;
  bool invalid = false;
  String status = 'Open two files to compare';
  String? error;
  int diffBytes = 0;
  int diffRuns = 0;
  int processed = 0;
  int elapsedMs = 0;
  FileHashAlgorithm hashAlgorithm = FileHashAlgorithm.sha1;
  String? leftHash, rightHash;
  bool leftHashing = false, rightHashing = false;
  bool leftEditing = false, rightEditing = false;
  bool leftSaving = false, rightSaving = false;
  bool _saving = false;
  final Map<int, int> leftEdits = {}, rightEdits = {};
  final Map<int, int> _leftOriginalValues = {}, _rightOriginalValues = {};
  int? pendingNibble;
  int _generation = 0;
  int _viewGeneration = 0;
  int _leftOpenGeneration = 0;
  int _rightOpenGeneration = 0;
  int _leftHashGeneration = 0;
  int _rightHashGeneration = 0;
  FileHashJob? _leftHashJob;
  FileHashJob? _rightHashJob;
  bool _disposed = false;
  Isolate? _worker;
  ReceivePort? _port;
  StreamSubscription<dynamic>? _subscription;
  SendPort? _workerControl;
  Completer<void>? _workerClosed;
  Completer<void>? _workerReady;
  Directory? _benchmarkDirectory;
  Future<void> _readQueue = Future.value();
  Future<Isolate>? _workerStarting;
  Future<void>? _closeFuture;

  int get length => math.max(left?.stamp.size ?? 0, right?.stamp.size ?? 0);
  int get rowCount => (length + bytesPerRow - 1) ~/ bytesPerRow;
  int get maxTop => math.max(0, rowCount - visibleRows);
  int get offset => topRow * bytesPerRow;
  bool get pair => left != null && right != null;
  bool get canCompare => pair && !invalid;
  bool dirty(bool isLeft) => (isLeft ? leftEdits : rightEdits).isNotEmpty;
  bool editing(bool isLeft) => isLeft ? leftEditing : rightEditing;
  String? path(bool isLeft) => (isLeft ? left : right)?.path;
  String? hash(bool isLeft) => isLeft ? leftHash : rightHash;
  bool hashing(bool isLeft) => isLeft ? leftHashing : rightHashing;
  bool get hashesDiffer =>
      leftHash != null && rightHash != null && leftHash != rightHash;

  void setHashAlgorithm(FileHashAlgorithm value) {
    if (_disposed || _saving || hashAlgorithm == value) return;
    hashAlgorithm = value;
    final l = left;
    final r = right;
    if (l != null) unawaited(_calculateHash(l, true));
    if (r != null) unawaited(_calculateHash(r, false));
    _notify();
  }

  Future<void> _calculateHash(
    PagedFile file,
    bool isLeft, {
    bool allowDuringSave = false,
  }) async {
    if (_saving && !allowDuringSave) return;
    final generation = isLeft ? ++_leftHashGeneration : ++_rightHashGeneration;
    final algorithm = hashAlgorithm;
    final previous = isLeft ? _leftHashJob : _rightHashJob;
    if (previous != null) await previous.cancel();
    if (_saving && !allowDuringSave) return;
    if (isLeft) {
      leftHash = null;
      leftHashing = true;
    } else {
      rightHash = null;
      rightHashing = true;
    }
    _notify();
    String? result;
    try {
      final job = await FileHashJob.start(file.path, algorithm);
      if (_disposed ||
          generation != (isLeft ? _leftHashGeneration : _rightHashGeneration)) {
        await job.cancel();
        return;
      }
      if (isLeft) {
        _leftHashJob = job;
      } else {
        _rightHashJob = job;
      }
      result = await job.result;
    } catch (_) {
      result = null;
    }
    if (_disposed ||
        generation != (isLeft ? _leftHashGeneration : _rightHashGeneration) ||
        algorithm != hashAlgorithm ||
        file != (isLeft ? left : right)) {
      return;
    }
    if (isLeft) {
      leftHash = result;
      leftHashing = false;
      _leftHashJob = null;
    } else {
      rightHash = result;
      rightHashing = false;
      _rightHashJob = null;
    }
    _notify();
  }

  Future<bool> _sameFile(String first, String second) async {
    if (first == second) return true;
    try {
      return await FileSystemEntity.identical(first, second);
    } on FileSystemException {
      return false;
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> open(String path, bool isLeft) => _open(path, isLeft);

  Future<void> _open(
    String path,
    bool isLeft, {
    bool allowDuringSave = false,
  }) async {
    if (_disposed) return;
    if (_saving && !allowDuringSave) {
      error = 'A save is in progress. Wait before opening another file.';
      _notify();
      return;
    }
    final ticket = isLeft ? ++_leftOpenGeneration : ++_rightOpenGeneration;
    try {
      final canonical = await File(path).resolveSymbolicLinks();
      final other = isLeft ? right : left;
      if (other != null && await _sameFile(canonical, other.path)) {
        error = 'This file is already open in the other pane. Open a copy to edit it independently.';
        _notify();
        return;
      }
      final file = PagedFile(canonical, await FileStamp.read(canonical));
      if (_disposed ||
          ticket != _openGenerationFor(isLeft) ||
          (_saving && !allowDuringSave)) {
        if (_saving && !allowDuringSave) _reportOpenBlocked();
        return;
      }
      await _stop(notify: false);
      if (_disposed ||
          ticket != _openGenerationFor(isLeft) ||
          (_saving && !allowDuringSave)) {
        if (_saving && !allowDuringSave) _reportOpenBlocked();
        return;
      }
      if (isLeft) {
        left = file;
        leftEdits.clear();
        _leftOriginalValues.clear();
        leftEditing = false;
        unawaited(_calculateHash(file, true, allowDuringSave: allowDuringSave));
      } else {
        right = file;
        rightEdits.clear();
        _rightOriginalValues.clear();
        rightEditing = false;
        unawaited(
          _calculateHash(file, false, allowDuringSave: allowDuringSave),
        );
      }
      topRow = 0;
      selected = null;
      error = null;
      invalid = false;
      complete = false;
      diffBytes = diffRuns = processed = 0;
      await refresh(allowDuringSave: allowDuringSave);
      if (ticket != _openGenerationFor(isLeft) || _disposed) return;
      if (canCompare) {
        await _compare(allowDuringSave: allowDuringSave);
      } else {
        status = 'One file open · Read-only preview';
        _notify();
      }
    } catch (e) {
      if (ticket == _openGenerationFor(isLeft) && !_disposed) {
        error = 'Unable to open file: $e';
        _notify();
      }
    }
  }

  int _openGenerationFor(bool isLeft) =>
      isLeft ? _leftOpenGeneration : _rightOpenGeneration;

  void _reportOpenBlocked() {
    error = 'A save is in progress. Wait before opening another file.';
    _notify();
  }

  void reportError(String message) {
    error = message;
    _notify();
  }

  Future<void> loadBenchmarkFixture() async {
    if (_saving) return;
    try {
      _benchmarkDirectory ??= await Directory.systemTemp.createTemp(
        'mushagaeshi-benchmark-',
      );
      final a = Uint8List.fromList(List.generate(4096, (i) => i % 256));
      final b = Uint8List.fromList([
        ...a,
        ...List.generate(12, (i) => 0xA0 + i),
      ]);
      b[0x12] = 0xFF;
      for (var i = 0x40; i < 0x48; i++) {
        b[i] = 0xEE;
      }
      b[0x3FF] = 0;
      b[0x400] = 0xEE;
      b[0x401] = 0;
      final lp = '${_benchmarkDirectory!.path}/original.bin';
      final rp = '${_benchmarkDirectory!.path}/modified.bin';
      await File(lp).writeAsBytes(a);
      await File(rp).writeAsBytes(b);
      await open(lp, true);
      await open(rp, false);
    } catch (e) {
      error = e.toString();
      _notify();
    }
  }

  Future<void> refresh({bool allowDuringSave = false}) {
    if (_saving && !allowDuringSave) return Future<void>.value();
    final ticket = ++_viewGeneration;
    final at = offset;
    final count = (visibleRows + 1) * bytesPerRow;
    final l = left;
    final r = right;
    loading = true;
    // Never show data from the previous offset underneath a new address.
    leftBytes = Uint8List(0);
    rightBytes = Uint8List(0);
    _notify();
    _readQueue = _readQueue.then((_) async {
      if (_disposed || ticket != _viewGeneration || invalid) return;
      try {
        final bytes = await Future.wait([
          l?.read(at, count) ?? Future.value(Uint8List(0)),
          r?.read(at, count) ?? Future.value(Uint8List(0)),
        ]);
        if (_disposed || ticket != _viewGeneration) return;
        leftBytes = bytes[0];
        rightBytes = bytes[1];
        for (final entry in leftEdits.entries) {
          if (entry.key >= at && entry.key < at + leftBytes.length) {
            leftBytes[entry.key - at] = entry.value;
          }
        }
        for (final entry in rightEdits.entries) {
          if (entry.key >= at && entry.key < at + rightBytes.length) {
            rightBytes[entry.key - at] = entry.value;
          }
        }
        loading = false;
      } catch (e) {
        if (_disposed || ticket != _viewGeneration) return;
        unawaited(stop(notify: false));
        invalid = true;
        loading = false;
        complete = false;
        error = e.toString();
        status = 'Read error · Reopen the file';
      }
      _notify();
    });
    return _readQueue;
  }

  void setRows(int value) {
    if (visibleRows == value) return;
    visibleRows = math.max(1, value);
    topRow = topRow.clamp(0, maxTop);
    unawaited(refresh());
  }

  void setWidth(int value) {
    final at = offset;
    bytesPerRow = value;
    topRow = (at ~/ value).clamp(0, maxTop);
    unawaited(refresh());
  }

  void scrollTo(int row) {
    final next = row.clamp(0, maxTop);
    if (next == topRow) return;
    topRow = next;
    unawaited(refresh());
  }

  void select(int at, bool isLeft) {
    final size = (isLeft ? left : right)?.stamp.size ?? 0;
    if (at < 0 || at >= size) return;
    selected = at;
    selectedLeft = isLeft;
    pendingNibble = null;
    _notify();
  }

  void setEditing(bool isLeft, bool enabled) {
    if (isLeft ? leftSaving : rightSaving) return;
    if (isLeft) {
      leftEditing = enabled;
    } else {
      rightEditing = enabled;
    }
    pendingNibble = null;
    status = enabled
        ? '${isLeft ? 'Left' : 'Right'} editing enabled'
        : '${isLeft ? 'Left' : 'Right'} editing disabled';
    _notify();
  }

  bool inputHex(String character) {
    if (selected == null ||
        !editing(selectedLeft) ||
        (selectedLeft ? leftSaving : rightSaving)) {
      return false;
    }
    final digit = int.tryParse(character, radix: 16);
    if (digit == null) return false;
    if (pendingNibble == null) {
      pendingNibble = digit;
      status = 'Enter second hex digit: ${character.toUpperCase()}_';
      _notify();
      return true;
    }
    final value = pendingNibble! * 16 + digit;
    pendingNibble = null;
    final edits = selectedLeft ? leftEdits : rightEdits;
    final at = selected!;
    final originals = selectedLeft ? _leftOriginalValues : _rightOriginalValues;
    final visible = selectedLeft ? leftBytes : rightBytes;
    final index = at - offset;
    if (!originals.containsKey(at) && index >= 0 && index < visible.length) {
      originals[at] = visible[index];
    }
    if (originals[at] == value) {
      edits.remove(at);
      originals.remove(at);
    } else {
      edits[at] = value;
    }
    status = 'Edited 0x${at.toRadixString(16).toUpperCase()}';
    final size = (selectedLeft ? left : right)!.stamp.size;
    selected = math.min(size - 1, at + 1);
    unawaited(
      refresh().then((_) {
        if (pair) unawaited(compare());
      }),
    );
    return true;
  }

  void cancelPending() {
    if (pendingNibble == null) return;
    pendingNibble = null;
    status = 'Hex input canceled';
    _notify();
  }

  Future<SaveResult> save(
    bool isLeft,
    String destination, {
    bool allowExternalChange = false,
    SaveInstaller? install,
    String? stagingDirectory,
  }) async {
    final file = isLeft ? left : right;
    if (file == null) {
      return const SaveResult(SaveOutcome.failed, 'No file is open.');
    }
    if (_saving || (isLeft ? leftSaving : rightSaving)) {
      return const SaveResult(
        SaveOutcome.failed,
        'A save is already in progress.',
      );
    }
    _saving = true;
    if (isLeft) {
      leftSaving = true;
    } else {
      rightSaving = true;
    }
    _notify();
    var result = const SaveResult(SaveOutcome.failed, 'Unable to start save.');
    try {
      final other = isLeft ? right : left;
      if (other != null && await _sameFile(destination, other.path)) {
        return const SaveResult(
          SaveOutcome.failed,
          'The other pane already has this file open. Choose another destination.',
        );
      }
      try {
        final destinationSnapshot = await DestinationSnapshot.capture(
          destination,
        );
        // Viewport reads, comparison workers and streaming hashes can retain
        // file handles. Stop them before the staged file is installed.
        await _stop(notify: false);
        await _readQueue;
        await Future.wait([
          _leftHashJob?.cancel() ?? Future<void>.value(),
          _rightHashJob?.cancel() ?? Future<void>.value(),
        ]);
        _leftHashJob = null;
        _rightHashJob = null;
        // safelySave copies this edit map before its first await. Keep the UI
        // editing lock until that transaction has installed or failed.
        result = await safelySave(
          sourcePath: file.path,
          sourceStamp: file.stamp,
          destinationPath: destination,
          edits: isLeft ? leftEdits : rightEdits,
          allowExternalChange: allowExternalChange,
          install: install,
          stagingDirectory: stagingDirectory,
          destinationSnapshot: destinationSnapshot,
        );
      } catch (error) {
        result = SaveResult(SaveOutcome.failed, 'Unable to save file: $error');
      }
      if (result.outcome == SaveOutcome.saved) {
        try {
          // Do not clear frozen edits until the installed bytes can be adopted.
          // Retain the global save lock while adopting the result so another
          // open cannot race this document commit.
          await _open(destination, isLeft, allowDuringSave: true);
          if ((isLeft ? left : right)?.path !=
              await File(destination).resolveSymbolicLinks()) {
            result = const SaveResult(
              SaveOutcome.savedButCouldNotReopen,
              'The file was saved, but could not be reopened.',
            );
          } else {
            status = 'Saved ${p.basename(destination)}';
          }
        } catch (_) {
          result = const SaveResult(
            SaveOutcome.savedButCouldNotReopen,
            'The file was saved, but could not be reopened.',
          );
        }
      } else if (result.message != null) {
        error = result.message;
      }
      return result;
    } finally {
      _saving = false;
      if (isLeft) {
        leftSaving = false;
      } else {
        rightSaving = false;
      }
      _notify();
    }
  }

  void jump(int at) {
    if (at < 0 || at >= length) return;
    selected = at;
    if (!busy) {
      status = 'Offset 0x${at.toRadixString(16).toUpperCase()}';
    }
    if (at >= ((selectedLeft ? left : right)?.stamp.size ?? 0)) {
      selectedLeft = !selectedLeft;
    }
    topRow = (at ~/ bytesPerRow).clamp(0, maxTop);
    unawaited(refresh());
  }

  Future<void> compare({bool? forward}) => _compare(forward: forward);

  Future<void> _compare({bool? forward, bool allowDuringSave = false}) async {
    if ((_saving && !allowDuringSave) || !canCompare) return;
    final generation = _generation + 1;
    if (forward == null) {
      // Clear completed data synchronously so a cancellation raced against the
      // worker shutdown cannot leave a stale "complete" result visible.
      complete = false;
      diffBytes = diffRuns = processed = 0;
    }
    await _stop(notify: false);
    if (_disposed ||
        generation != _generation ||
        (_saving && !allowDuringSave)) {
      return;
    }
    busy = true;
    status = forward == null ? 'Comparing files…' : 'Finding difference…';
    _notify();
    final port = ReceivePort();
    _port = port;
    _subscription = port.listen((dynamic message) {
      final m = message as Map;
      if (m['type'] == 'ready') {
        _workerControl = m['control'] as SendPort;
        _workerReady?.complete();
        return;
      }
      if (m['type'] == 'closed') {
        _workerClosed?.complete();
        return;
      }
      if (_disposed || generation != _generation) return;
      switch (m['type']) {
        case 'progress':
          if (forward == null) {
            processed = m['processed'] as int;
            diffBytes = m['bytes'] as int;
            diffRuns = m['runs'] as int;
          }
        case 'done':
          busy = false;
          if (forward == null) {
            complete = true;
            processed = length;
            diffBytes = m['bytes'] as int;
            diffRuns = m['runs'] as int;
            elapsedMs = m['milliseconds'] as int;
            status = diffBytes == 0
                ? 'Comparison complete · Files are identical'
                : 'Comparison complete';
          } else {
            final target = m['target'] as int?;
            if (target == null) {
              status = forward
                  ? 'No later differences'
                  : 'No earlier differences';
            } else {
              jump(target);
              status =
                  'Differences 0x${target.toRadixString(16).toUpperCase()}';
            }
          }
        case 'error':
          busy = false;
          invalid = true;
          complete = false;
          error = m['message'] as String;
          status = 'Comparison error · Reopen the files';
        case 'canceled':
          busy = false;
      }
      _notify();
    });
    _workerReady = Completer<void>();
    _workerClosed = Completer<void>();
    try {
      final starting = Isolate.spawn(compareWorker, <String, Object>{
        'port': port.sendPort,
        'left': left!.path,
        'right': right!.path,
        'leftStamp': left!.stamp,
        'rightStamp': right!.stamp,
        'leftEdits': leftEdits,
        'rightEdits': rightEdits,
        if (forward != null)
          'cursor': selected ?? (forward ? offset - 1 : offset),
        'forward': ?forward,
      });
      _workerStarting = starting;
      final worker = await starting;
      if (identical(_workerStarting, starting)) _workerStarting = null;
      if (_disposed || generation != _generation) {
        _worker = worker;
        await _stop(notify: false);
      } else {
        _worker = worker;
      }
    } catch (e) {
      _workerStarting = null;
      _workerReady = null;
      _workerClosed = null;
      if (generation == _generation && !_disposed) {
        await _stop(notify: false);
        error = e.toString();
        status = 'Unable to start comparison';
        _notify();
      }
    }
  }

  /// Cancels the comparison and completes once its worker has closed handles.
  ///
  /// Callers that will replace a file must await this rather than relying on
  /// cancellation being delivered before the worker has received its control
  /// port.
  Future<void> stop({bool notify = true}) => _stop(notify: notify);

  Future<void> _stop({bool notify = true}) async {
    _generation++;
    final closed = _workerClosed;
    var control = _workerControl;
    if (control == null && _worker != null) {
      final ready = _workerReady;
      if (ready != null && !ready.isCompleted) await ready.future;
      control = _workerControl;
    }
    if (control != null && closed != null && !closed.isCompleted) {
      control.send('cancel');
      await closed.future;
    } else {
      _worker?.kill(priority: Isolate.immediate);
    }
    _worker = null;
    _workerControl = null;
    _workerClosed = null;
    _workerReady = null;
    unawaited(_subscription?.cancel());
    _subscription = null;
    _port?.close();
    _port = null;
    if (busy) {
      busy = false;
      status = 'Canceled · Visible differences remain available';
    }
    if (notify) _notify();
  }

  /// Stops all asynchronous file work and waits until every file handle closes.
  ///
  /// Desktop widget disposal cannot await this operation. Callers that remove a
  /// document directory can await it before deletion.
  Future<void> close() => _closeFuture ??= _close();

  Future<void> _close() async {
    _disposed = true;
    ++_leftOpenGeneration;
    ++_rightOpenGeneration;
    ++_viewGeneration;
    ++_leftHashGeneration;
    ++_rightHashGeneration;

    final leftHash = _leftHashJob;
    final rightHash = _rightHashJob;
    _leftHashJob = null;
    _rightHashJob = null;
    await Future.wait([
      leftHash?.cancel() ?? Future<void>.value(),
      rightHash?.cancel() ?? Future<void>.value(),
    ]);

    // A close may arrive while an isolate is spawning. Wait for that spawn,
    // then stop the worker it produced, until neither state remains.
    while (_workerStarting != null || _worker != null) {
      final starting = _workerStarting;
      if (starting != null) {
        try {
          await starting;
        } catch (_) {
          // _compare reports startup failures when the controller is active.
        }
      }
      await _stop(notify: false);
    }
    await _readQueue;

    final fixture = _benchmarkDirectory;
    if (fixture != null) {
      await fixture.delete(recursive: true).catchError((_) => fixture);
    }
  }

  @override
  void dispose() {
    unawaited(close());
    super.dispose();
  }
}
