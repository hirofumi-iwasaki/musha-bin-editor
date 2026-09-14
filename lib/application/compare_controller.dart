// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../infrastructure/file_comparison.dart';

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
  int _generation = 0;
  int _viewGeneration = 0;
  int _openGeneration = 0;
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

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> open(String path, bool isLeft) async {
    final ticket = ++_openGeneration;
    try {
      final canonical = await File(path).resolveSymbolicLinks();
      final file = PagedFile(canonical, await FileStamp.read(canonical));
      if (_disposed || ticket != _openGeneration) return;
      stop(notify: false);
      if (isLeft) {
        left = file;
      } else {
        right = file;
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
        'mushaaeshi-benchmark-',
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
    _notify();
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
    stop(notify: false);
    final fixture = _benchmarkDirectory;
    if (fixture != null) {
      unawaited(fixture.delete(recursive: true).catchError((_) => fixture));
    }
    super.dispose();
  }
}
