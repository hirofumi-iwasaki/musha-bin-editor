import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mushagaeshi_binary_editor/application/compare_controller.dart';
import 'package:mushagaeshi_binary_editor/infrastructure/file_hash.dart';

Future<void> idle(CompareController c) async {
  final deadline = DateTime.now().add(const Duration(seconds: 10));
  while (c.busy) {
    if (DateTime.now().isAfter(deadline)) fail('Worker did not finish');
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

Future<void> hashesIdle(CompareController c) async {
  final deadline = DateTime.now().add(const Duration(seconds: 10));
  while (c.leftHashing || c.rightHashing) {
    if (DateTime.now().isAfter(deadline)) fail('Hash worker did not finish');
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

void main() {
  test(
    'SHA-1 is the default and selecting MD5 recalculates open files',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'mushagaeshi-controller-hash-',
      );
      final controller = CompareController();
      try {
        final file = File('${directory.path}/abc.bin');
        await file.writeAsString('abc');
        await controller.open(file.path, true);
        await hashesIdle(controller);

        expect(controller.hashAlgorithm, FileHashAlgorithm.sha1);
        expect(controller.leftHash, 'a9993e364706816aba3e25717850c26c9cd0d89d');
        expect(controller.hashesDiffer, isFalse);
        final peer = File('${directory.path}/peer.bin');
        await peer.writeAsString('different');
        await controller.open(peer.path, false);
        await hashesIdle(controller);
        expect(controller.hashesDiffer, isTrue);
        controller.setHashAlgorithm(FileHashAlgorithm.md5);
        await hashesIdle(controller);
        expect(controller.leftHash, '900150983cd24fb0d6963f7d28e17f72');
      } finally {
        controller.dispose();
        await directory.delete(recursive: true);
      }
    },
  );

  test('benchmark fixture, difference navigation and rapid viewport changes stay coherent', () async {
    final c = CompareController();
    addTearDown(c.dispose);
    await c.loadBenchmarkFixture();
    await idle(c);
    expect(c.error, null);
    expect(c.diffBytes, 24);
    expect(c.diffRuns, 4);
    await c.compare(forward: true);
    await idle(c);
    expect(c.selected, 0x12);
    await c.compare(forward: true);
    await idle(c);
    expect(c.selected, 0x40);
    await c.compare(forward: false);
    await idle(c);
    expect(c.selected, 0x12);
    for (var row = 1; row <= 50; row++) {
      c.scrollTo(row);
    }
    await c.refresh();
    expect(c.offset, 800);
    expect(c.leftBytes.first, 800 % 256);
    c.setWidth(8);
    await c.refresh();
    expect(c.offset, 800);
    expect(c.leftBytes.first, 800 % 256);
    c.jump(c.length - 1);
    await c.refresh();
    expect(c.selectedLeft, false);
    expect(c.selected, 4107);
  });

  test('external changes invalidate results and clearing a scan does not publish stale results', () async {
    final dir = await Directory.systemTemp.createTemp(
      'mushagaeshi-controller-',
    );
    final c = CompareController();
    try {
      final a = File('${dir.path}/a');
      final b = File('${dir.path}/b');
      await a.writeAsBytes(List.filled(4096, 0));
      await b.writeAsBytes(List.filled(4096, 1));
      await c.open(a.path, true);
      await c.open(b.path, false);
      await idle(c);
      expect(c.diffBytes, 4096);
      final pending = c.compare();
      // Stop can race the worker's `ready` message. Awaiting it proves that
      // cancellation waited for the worker's handle-closing acknowledgement.
      await c.stop();
      await pending;
      expect(c.busy, false);
      expect(c.complete, false);
      await a.writeAsBytes([0]);
      await c.refresh();
      expect(c.invalid, true);
      expect(c.complete, false);
      expect(c.error, isNotNull);
    } finally {
      c.dispose();
      await dir.delete(recursive: true);
    }
  });
}
