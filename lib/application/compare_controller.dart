// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

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
  final Map<int, int> leftEdits = {}, rightEdits = {};
  final Map<int, int> _leftOriginalValues = {}, _rightOriginalValues = {};
  int? pendingNibble;
  int _generation = 0;
  int _viewGeneration = 0;
  int _openGeneration = 0;
  int _leftHashGeneration = 0;
  int _rightHashGeneration = 0;
  bool _disposed = false;
  Isolate? _worker;
  ReceivePort? _port;
  StreamSubscription<dynamic>? _subscription;
  Directory? _benchmarkDirectory;
  Future<void> _readQueue = Future.value();

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
    if (hashAlgorithm == value) return;
    hashAlgorithm = value;
    final l = left;
    final r = right;
    if (l != null) unawaited(_calculateHash(l, true));
    if (r != null) unawaited(_calculateHash(r, false));
    _notify();
  }

  Future<void> _calculateHash(PagedFile file, bool isLeft) async {
    final generation = isLeft ? ++_leftHashGeneration : ++_rightHashGeneration;
    final algorithm = hashAlgorithm;
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
      result = await calculateFileHash(file.path, algorithm);
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
    } else {
      rightHash = result;
      rightHashing = false;
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

  Future<void> open(String path, bool isLeft) async {
    final ticket = ++_openGeneration;
    try {
      final canonical = await File(path).resolveSymbolicLinks();
      final other = isLeft ? right : left;
      if (other != null && await _sameFile(canonical, other.path)) {
        error = 'This file is already open in the other pane. Open a copy to edit it independently.';
        _notify();
        return;
      }
      final file = PagedFile(canonical, await FileStamp.read(canonical));
      if (_disposed || ticket != _openGeneration) return;
      stop(notify: false);
      if (isLeft) {
        left = file;
        leftEdits.clear();
        _leftOriginalValues.clear();
        leftEditing = false;
        unawaited(_calculateHash(file, true));
      } else {
        right = file;
        rightEdits.clear();
        _rightOriginalValues.clear();
        rightEditing = false;
        unawaited(_calculateHash(file, false));
      }
      topRow = 0;
      selected = null;
      error = null;
      invalid = false;
      complete = false;
      diffBytes = diffRuns = processed = 0;
      await refresh();
      if (ticket != _openGeneration || _disposed) return;
      if (canCompare) {
        await compare();
      } else {
        status = 'One file open · Read-only preview';
        _notify();
      }
    } catch (e) {
      if (ticket == _openGeneration && !_disposed) {
        error = 'Unable to open file: $e';
        _notify();
      }
    }
  }

  void reportError(String message) {
    error = message;
    _notify();
  }

  Future<void> loadBenchmarkFixture() async {
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

  Future<void> refresh() {
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
        stop(notify: false);
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
    if (selected == null || !editing(selectedLeft)) return false;
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
    Future<void> Function(String stagedPath, String destinationPath)? install,
  }) async {
    final file = isLeft ? left : right;
    if (file == null) {
      return const SaveResult(SaveOutcome.failed, 'No file is open.');
    }
    final other = isLeft ? right : left;
    if (other != null && await _sameFile(destination, other.path)) {
      return const SaveResult(
        SaveOutcome.failed,
        'The other pane already has this file open. Choose another destination.',
      );
    }
    final result = await safelySave(
      sourcePath: file.path,
      sourceStamp: file.stamp,
      destinationPath: destination,
      edits: isLeft ? leftEdits : rightEdits,
      allowExternalChange: allowExternalChange,
      install: install,
    );
    if (result.outcome == SaveOutcome.saved) {
      await open(destination, isLeft);
      status = 'Saved ${destination.split('/').last}';
      _notify();
    } else if (result.message != null) {
      error = result.message;
      _notify();
    }
    return result;
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

  Future<void> compare({bool? forward}) async {
    if (!canCompare) return;
    stop(notify: false);
    final generation = _generation;
    busy = true;
    if (forward == null) {
      complete = false;
      diffBytes = diffRuns = processed = 0;
    }
    status = forward == null ? 'Comparing files…' : 'Finding difference…';
    _notify();
    final port = ReceivePort();
    _port = port;
    _subscription = port.listen((dynamic message) {
      if (_disposed || generation != _generation) return;
      final m = message as Map;
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
          unawaited(_subscription?.cancel());
          _port?.close();
          _port = null;
        case 'error':
          busy = false;
          invalid = true;
          complete = false;
          error = m['message'] as String;
          status = 'Comparison error · Reopen the files';
          unawaited(_subscription?.cancel());
          _port?.close();
          _port = null;
      }
      _notify();
    });
    try {
      final worker = await Isolate.spawn(compareWorker, <String, Object>{
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
      if (_disposed || generation != _generation) {
        worker.kill(priority: Isolate.immediate);
      } else {
        _worker = worker;
      }
    } catch (e) {
      if (generation == _generation && !_disposed) {
        stop(notify: false);
        error = e.toString();
        status = 'Unable to start comparison';
        _notify();
      }
    }
  }

  void stop({bool notify = true}) {
    _generation++;
    _worker?.kill(priority: Isolate.immediate);
    _worker = null;
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

  @override
  void dispose() {
    _disposed = true;
    ++_openGeneration;
    ++_viewGeneration;
    ++_leftHashGeneration;
    ++_rightHashGeneration;
    stop(notify: false);
    final fixture = _benchmarkDirectory;
    if (fixture != null) {
      unawaited(fixture.delete(recursive: true).catchError((_) => fixture));
    }
    super.dispose();
  }
}
