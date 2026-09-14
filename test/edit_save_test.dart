import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mushagaeshi_binary_editor/application/compare_controller.dart';
import 'package:mushagaeshi_binary_editor/infrastructure/safe_save.dart';

void main() {
  late Directory directory;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('mushagaeshi-edit-test-');
  });

  tearDown(() async {
    await directory.delete(recursive: true);
  });

  test(
    'two hex digits edit one byte and Save As preserves all other bytes',
    () async {
      final source = File('${directory.path}/source.bin');
      final destination = '${directory.path}/saved.bin';
      await source.writeAsBytes([0x10, 0x20, 0x30]);
      final controller = CompareController();
      await controller.open(source.path, true);
      controller.setEditing(true, true);
      controller.select(1, true);

      expect(controller.inputHex('A'), isTrue);
      expect(controller.pendingNibble, 0xA);
      expect(controller.dirty(true), isFalse);
      expect(controller.inputHex('f'), isTrue);
      expect(controller.pendingNibble, isNull);
      expect(controller.dirty(true), isTrue);
      await controller.refresh();
      expect(controller.leftBytes.sublist(0, 3), [0x10, 0xAF, 0x30]);

      final result = await controller.save(true, destination);
      expect(result.outcome, SaveOutcome.saved);
      expect(await File(destination).readAsBytes(), [0x10, 0xAF, 0x30]);
      expect(controller.dirty(true), isFalse);
      controller.dispose();
    },
  );

  test('save refuses an externally changed source without approval', () async {
    final source = File('${directory.path}/source.bin');
    await source.writeAsBytes([1, 2, 3]);
    final controller = CompareController();
    await controller.open(source.path, true);
    controller.setEditing(true, true);
    controller.select(0, true);
    controller.inputHex('F');
    controller.inputHex('F');
    await Future<void>.delayed(const Duration(milliseconds: 10));
    await source.writeAsBytes([9, 9, 9]);

    final result = await controller.save(true, source.path);
    expect(result.outcome, SaveOutcome.externallyChanged);
    expect(controller.dirty(true), isTrue);
    expect(await source.readAsBytes(), [9, 9, 9]);
    controller.dispose();
  });

  test('the same canonical file cannot be opened in both panes', () async {
    final source = File('${directory.path}/same.bin');
    await source.writeAsBytes([1, 2, 3]);
    final controller = CompareController();
    await controller.open(source.path, true);
    await controller.open(source.path, false);
    expect(controller.right, isNull);
    expect(controller.error, contains('already open in the other pane'));
    controller.dispose();
  });

  test(
    'a hard link to the opposite file is rejected as the same file',
    () async {
      final source = File('${directory.path}/same.bin');
      final alias = '${directory.path}/alias.bin';
      await source.writeAsBytes([1, 2, 3]);
      await Process.run('ln', [source.path, alias]);
      final controller = CompareController();
      await controller.open(source.path, true);
      await controller.open(alias, false);
      expect(controller.right, isNull);
      expect(controller.error, contains('already open in the other pane'));
      controller.dispose();
    },
  );

  test(
    'saving over the opposite pane through a hard link is rejected',
    () async {
      final left = File('${directory.path}/left.bin');
      final right = File('${directory.path}/right.bin');
      final rightAlias = '${directory.path}/right-alias.bin';
      await left.writeAsBytes([1]);
      await right.writeAsBytes([2]);
      await Process.run('ln', [right.path, rightAlias]);
      final controller = CompareController();
      await controller.open(left.path, true);
      await controller.open(right.path, false);
      controller.setEditing(true, true);
      controller.select(0, true);
      controller.inputHex('F');
      controller.inputHex('F');

      final result = await controller.save(true, rightAlias);
      expect(result.outcome, SaveOutcome.failed);
      expect(await right.readAsBytes(), [2]);
      expect(controller.dirty(true), isTrue);
      controller.dispose();
    },
  );
}
