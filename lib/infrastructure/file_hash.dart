// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;

import 'file_comparison.dart';

enum FileHashAlgorithm {
  sha1('SHA-1'),
  md5('MD5');

  const FileHashAlgorithm(this.label);
  final String label;
}

class FileHashJob {
  FileHashJob._(this._control, this._messages, this._result);

  final SendPort _control;
  final ReceivePort _messages;
  final Future<String?> _result;
  var _canceled = false;

  Future<String?> get result => _result;

  /// Waits for the worker's finally block, which closes its file handle.
  Future<void> cancel() async {
    if (_canceled) return;
    _canceled = true;
    _control.send('cancel');
    try {
      await _result;
    } finally {
      _messages.close();
    }
  }

  static Future<FileHashJob> start(
    String path,
    FileHashAlgorithm algorithm,
  ) async {
    final messages = ReceivePort();
    final ready = Completer<SendPort>();
    final complete = Completer<String?>();
    late final StreamSubscription<dynamic> subscription;
    subscription = messages.listen((dynamic message) {
      final value = message as Map;
      switch (value['type']) {
        case 'ready':
          if (!ready.isCompleted) {
            ready.complete(value['control'] as SendPort);
          }
        case 'done':
          if (!complete.isCompleted) {
            complete.complete(value['digest'] as String?);
          }
        case 'canceled':
          if (!complete.isCompleted) {
            complete.complete(null);
          }
        case 'error':
          if (!complete.isCompleted) {
            complete.completeError(value['error'] as Object);
          }
      }
      if (complete.isCompleted) unawaited(subscription.cancel());
    });
    await Isolate.spawn(_hashWorker, <String, Object>{
      'port': messages.sendPort,
      'path': path,
      'algorithm': algorithm.name,
    });
    return FileHashJob._(await ready.future, messages, complete.future);
  }
}

Future<String> calculateFileHash(
  String path,
  FileHashAlgorithm algorithm,
) async {
  final job = await FileHashJob.start(path, algorithm);
  try {
    final result = await job.result;
    if (result == null) {
      throw const FileSystemException('Hash calculation canceled');
    }
    return result;
  } finally {
    await job.cancel();
  }
}

Future<void> _hashWorker(Map<String, Object> request) async {
  final port = request['port'] as SendPort;
  final control = ReceivePort();
  var canceled = false;
  control.listen((_) => canceled = true);
  port.send({'type': 'ready', 'control': control.sendPort});
  RandomAccessFile? file;
  try {
    final path = request['path'] as String;
    final stamp = await FileStamp.read(path);
    final hash = switch (request['algorithm'] as String) {
      'sha1' => crypto.sha1,
      'md5' => crypto.md5,
      _ => throw const FormatException('Unknown hash algorithm'),
    };
    final output = _DigestSink();
    final sink = hash.startChunkedConversion(output);
    file = await File(path).open();
    const blockSize = 64 * 1024;
    var offset = 0;
    while (offset < stamp.size && !canceled) {
      final length = (stamp.size - offset).clamp(0, blockSize);
      final bytes = await file.read(length);
      if (bytes.length != length) {
        throw const FileSystemException(
          'File size changed while calculating its hash',
        );
      }
      sink.add(Uint8List.fromList(bytes));
      offset += length;
    }
    await file.close();
    file = null;
    if (canceled) {
      port.send({'type': 'canceled'});
    } else if (!stamp.matches(await FileStamp.read(path))) {
      throw const FileSystemException(
        'File changed while calculating its hash',
      );
    } else {
      sink.close();
      port.send({'type': 'done', 'digest': output.value.toString()});
    }
  } catch (error) {
    port.send({'type': 'error', 'error': error});
  } finally {
    await file?.close();
    control.close();
  }
}

class _DigestSink implements Sink<crypto.Digest> {
  crypto.Digest? _value;

  crypto.Digest get value => _value!;

  @override
  void add(crypto.Digest data) => _value = data;

  @override
  void close() {}
}
