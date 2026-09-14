// SPDX-License-Identifier: GPL-3.0-or-later
// Run: dart run tool/benchmark.dart [sizeMiB ...]
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:mushaaeshi_binary_editor/infrastructure/file_comparison.dart';

Future<void> main(List<String> args) async {
  final results = <Map<String, Object?>>[];
  final dir = await Directory.systemTemp.createTemp('mushaaeshi-bench-');
  try {
    for (final mib in args.isEmpty ? [1, 100, 1024] : args.map(int.parse)) {
      final a = File('${dir.path}/a.bin');
      final b = File('${dir.path}/b.bin');
      final zeros = Uint8List(1024 * 1024);
      final fa = await a.open(mode: FileMode.write);
      final fb = await b.open(mode: FileMode.write);
      for (var i = 0; i < mib; i++) {
        await fa.writeFrom(zeros);
        await fb.writeFrom(zeros);
      }
      await fa.close();
      await fb.close();
      final edit = await b.open(mode: FileMode.append);
      await edit.setPosition(mib * 1024 * 1024 ~/ 2);
      await edit.writeFrom([1]);
      await edit.close();
      final stamp = await FileStamp.read(a.path);
      final page = PagedFile(a.path, stamp);
      final read = Stopwatch()..start();
      await page.read(0, 1024);
      final firstReadUs = read.elapsedMicroseconds;
      final port = ReceivePort();
      final terminal = port.firstWhere((m) => (m as Map)['type'] != 'progress');
      final watch = Stopwatch()..start();
      await Isolate.spawn(compareWorker, <String, Object>{
        'port': port.sendPort,
        'left': a.path,
        'right': b.path,
        'leftStamp': stamp,
        'rightStamp': await FileStamp.read(b.path),
      });
      final result = Map<String, Object?>.from(await terminal as Map);
      final wallMs = watch.elapsedMilliseconds;
      port.close();
      if (result['type'] != 'done' ||
          result['bytes'] != 1 ||
          result['runs'] != 1) {
        throw StateError('Unexpected result: $result');
      }
      results.add({
        'sizeMiB': mib,
        'firstViewportReadUs': firstReadUs,
        'wallMs': wallMs,
        'rssBytes': ProcessInfo.currentRss,
        ...result,
      });
    }
    stdout.writeln(
      const JsonEncoder.withIndent('  ').convert({
        'os': Platform.operatingSystemVersion,
        'dart': Platform.version,
        'results': results,
      }),
    );
  } finally {
    await dir.delete(recursive: true);
  }
}
