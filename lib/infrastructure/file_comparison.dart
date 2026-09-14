// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import '../core/comparison.dart';

const scanBlockSize = 1024 * 1024;

class FileStamp {
  const FileStamp(this.size, this.modified, this.changed);
  final int size;
  final DateTime modified;
  final DateTime changed;
  static Future<FileStamp> read(String path) async {
    final stat = await File(path).stat();
    if (stat.type != FileSystemEntityType.file) {
      throw FileSystemException('Please select a regular file', path);
    }
    return FileStamp(stat.size, stat.modified, stat.changed);
  }

  bool matches(FileStamp other) =>
      size == other.size &&
      modified == other.modified &&
      changed == other.changed;
}

Future<Uint8List> readExactRange(
  RandomAccessFile file,
  int size,
  int offset,
  int count,
) async {
  final length = math.min(count, math.max(0, size - offset));
  if (length == 0) return Uint8List(0);
  await file.setPosition(offset);
  final result = Uint8List(length);
  var read = 0;
  while (read < length) {
    final n = await file.readInto(result, read, length);
    if (n == 0) {
      throw const FileSystemException('File size changed while reading');
    }
    read += n;
  }
  return result;
}

/// Worker owns its handles. Only progress/counts cross the isolate boundary.
/// Cancellation kills the worker; normal completion closes all handles.
Future<void> compareWorker(Map<String, Object> request) async {
  final port = request['port'] as SendPort;
  RandomAccessFile? left;
  RandomAccessFile? right;
  try {
    final lp = request['left'] as String;
    final rp = request['right'] as String;
    final ls = await FileStamp.read(lp);
    final rs = await FileStamp.read(rp);
    if (!ls.matches(request['leftStamp'] as FileStamp) ||
        !rs.matches(request['rightStamp'] as FileStamp)) {
      throw const FileSystemException(
        'File changed outside the app. Please reopen it',
      );
    }
    left = await File(lp).open();
    right = await File(rp).open();
    final length = math.max(ls.size, rs.size);
    final accumulator = DiffAccumulator();
    final cursor = request['cursor'] as int?;
    final leftEdits =
        (request['leftEdits'] as Map?)?.cast<int, int>() ?? const <int, int>{};
    final rightEdits =
        (request['rightEdits'] as Map?)?.cast<int, int>() ?? const <int, int>{};
    final navigator = cursor == null
        ? null
        : RunNavigator(cursor, request['forward'] as bool);
    final watch = Stopwatch()..start();
    var lastProgress = 0;
    for (var offset = 0; offset < length; offset += scanBlockSize) {
      final a = await readExactRange(left, ls.size, offset, scanBlockSize);
      final b = await readExactRange(right, rs.size, offset, scanBlockSize);
      for (final entry in leftEdits.entries) {
        if (entry.key >= offset && entry.key < offset + a.length) {
          a[entry.key - offset] = entry.value;
        }
      }
      for (final entry in rightEdits.entries) {
        if (entry.key >= offset && entry.key < offset + b.length) {
          b[entry.key - offset] = entry.value;
        }
      }
      if (navigator == null) {
        accumulator.add(a, b, offset);
      } else {
        for (var i = 0; i < math.max(a.length, b.length); i++) {
          navigator.add(
            i >= a.length || i >= b.length || a[i] != b[i],
            offset + i,
          );
          if (navigator.done) break;
        }
      }
      if (navigator?.done ?? false) break;
      if (watch.elapsedMilliseconds - lastProgress >= 100) {
        lastProgress = watch.elapsedMilliseconds;
        port.send({
          'type': 'progress',
          'processed': math.min(offset + scanBlockSize, length),
          'bytes': accumulator.bytes,
          'runs': accumulator.runs,
        });
      }
    }
    if (navigator != null && !navigator.done) navigator.finish(length);
    if (!ls.matches(await FileStamp.read(lp)) ||
        !rs.matches(await FileStamp.read(rp))) {
      throw const FileSystemException(
        'File changed outside the app. Please reopen it',
      );
    }
    port.send({
      'type': 'done',
      'bytes': accumulator.bytes,
      'runs': accumulator.runs,
      'first': accumulator.first,
      'target': navigator?.result,
      'milliseconds': watch.elapsedMilliseconds,
    });
  } catch (error) {
    port.send({'type': 'error', 'message': error.toString()});
  } finally {
    await left?.close();
    await right?.close();
  }
}

/// Small viewport cache; never retains the entire file.
class PagedFile {
  PagedFile(this.path, this.stamp);
  final String path;
  final FileStamp stamp;
  static const pageSize = 64 * 1024;
  int _cachedStart = -1;
  Uint8List _cached = Uint8List(0);

  Future<Uint8List> read(int offset, int count) async {
    if (!stamp.matches(await FileStamp.read(path))) {
      throw const FileSystemException(
        'File changed outside the app. Please reopen it',
      );
    }
    if (offset >= stamp.size) return Uint8List(0);
    final end = math.min(stamp.size, offset + count);
    if (_cachedStart <= offset &&
        _cachedStart >= 0 &&
        _cachedStart + _cached.length >= end) {
      return Uint8List.sublistView(
        _cached,
        offset - _cachedStart,
        end - _cachedStart,
      );
    }
    final start = (offset ~/ pageSize) * pageSize;
    final file = await File(path).open();
    Uint8List data;
    try {
      data = await readExactRange(
        file,
        stamp.size,
        start,
        math.max(pageSize, end - start),
      );
    } finally {
      await file.close();
    }
    if (!stamp.matches(await FileStamp.read(path))) {
      throw const FileSystemException(
        'File changed outside the app while reading',
      );
    }
    _cachedStart = start;
    _cached = data;
    return Uint8List.sublistView(data, offset - start, end - start);
  }
}
