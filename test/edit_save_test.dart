import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mushagaeshi_binary_editor/application/compare_controller.dart';
import 'package:mushagaeshi_binary_editor/infrastructure/file_comparison.dart';
import 'package:mushagaeshi_binary_editor/infrastructure/safe_save.dart';

void main() {
  late Directory directory;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('mushagaeshi-edit-test-');
  });

  tearDown(() async {
    await directory.delete(recursive: true);
  });

  Future<SaveInstallResult> install(
    String stagedPath,
    String destination,
  ) async {
    await File(stagedPath).rename(destination);
    return const SaveInstallResult.installed();
  }

  test('a changed destination is rejected before installation', () async {
    final source = File('${directory.path}/source.bin');
    final destination = File('${directory.path}/destination.bin');
    await source.writeAsBytes([1]);
    await destination.writeAsBytes([2]);
    final snapshot = await DestinationSnapshot.capture(destination.path);
    await Future<void>.delayed(const Duration(milliseconds: 10));
    await destination.writeAsBytes([3]);
    var installed = false;

    final result = await safelySave(
      sourcePath: source.path,
      sourceStamp: await FileStamp.read(source.path),
      destinationPath: destination.path,
      edits: const {},
      destinationSnapshot: snapshot,
      install: (_, _) async {
        installed = true;
        return const SaveInstallResult.installed();
      },
    );

    expect(result.outcome, SaveOutcome.destinationChanged);
    expect(installed, isFalse);
    expect(await destination.readAsBytes(), [3]);
  });

  test('save locks editing and opening until the installer returns', () async {
    final source = File('${directory.path}/source.bin');
    final other = File('${directory.path}/other.bin');
    final destination = '${directory.path}/destination.bin';
    await source.writeAsBytes([1]);
    await other.writeAsBytes([2]);
    final controller = CompareController();
    await controller.open(source.path, true);
    controller.setEditing(true, true);
    controller.select(0, true);
    controller.inputHex('F');
    controller.inputHex('F');
    final release = Completer<void>();
    final saving = controller.save(
      true,
      destination,
      install: (staged, target) async {
        await release.future;
        await File(staged).rename(target);
        return const SaveInstallResult.installed();
      },
    );
    await Future<void>.delayed(Duration.zero);
    expect(controller.inputHex('0'), isFalse);
    await controller.open(other.path, false);
    expect(controller.right, isNull);
    expect(controller.error, contains('save is in progress'));
    release.complete();
    expect((await saving).outcome, SaveOutcome.saved);
    controller.dispose();
  });

  test('open started before a save lock cannot replace a document', () async {
    final source = File('${directory.path}/source.bin');
    final peer = File('${directory.path}/peer.bin');
    final other = File('${directory.path}/other.bin');
    await source.writeAsBytes([1]);
    await peer.writeAsBytes([2]);
    await other.writeAsBytes([2]);
    final controller = CompareController();
    await controller.open(source.path, true);
    await controller.open(peer.path, false);
    final release = Completer<void>();
    // `open` yields while resolving/statting its path. A save that locks the
    // document during that gap must prevent the open from committing.
    final opening = controller.open(other.path, true);
    final saving = controller.save(
      true,
      '${directory.path}/destination.bin',
      install: (staged, target) async {
        await release.future;
        await File(staged).rename(target);
        return const SaveInstallResult.installed();
      },
    );
    await Future<void>.delayed(Duration.zero);
    await opening;

    expect(controller.path(true), await source.resolveSymbolicLinks());
    expect(controller.error, contains('save is in progress'));
    release.complete();
    await saving;
    controller.dispose();
  });

  test(
    'a source changed during Save As leaves the destination untouched',
    () async {
      final source = File('${directory.path}/source.bin');
      final destination = File('${directory.path}/destination.bin');
      await source.writeAsBytes(List<int>.filled(32 * 1024 * 1024, 0x11));
      await destination.writeAsBytes([0xA5]);

      final saving = safelySave(
        sourcePath: source.path,
        sourceStamp: await FileStamp.read(source.path),
        destinationPath: destination.path,
        edits: const {},
        install: install,
      );
      // Let the transaction enter its asynchronous read path, then replace the
      // source while it is being staged.
      await Future<void>.delayed(Duration.zero);
      await source.writeAsBytes([0x55]);

      final result = await saving;
      expect(result.outcome, isNot(SaveOutcome.saved));
      expect(await destination.readAsBytes(), [0xA5]);
    },
  );

  test(
    'an ambiguous installation retains and reports the complete recovery copy',
    () async {
      final source = File('${directory.path}/source.bin');
      final destination = '${directory.path}/destination.bin';
      await source.writeAsBytes([0x10, 0x20, 0x30]);

      final result = await safelySave(
        sourcePath: source.path,
        sourceStamp: await FileStamp.read(source.path),
        destinationPath: destination,
        edits: const {1: 0xAF},
        install: (staged, _) async => SaveInstallResult.ambiguous(
          'The installer could not prove the destination contents.',
          staged,
        ),
      );

      expect(result.outcome, SaveOutcome.failed);
      expect(result.recoveryPath, isNotNull);
      final recovery = File(result.recoveryPath!);
      expect(await recovery.exists(), isTrue);
      expect(await recovery.readAsBytes(), [0x10, 0xAF, 0x30]);
      expect(await File(destination).exists(), isFalse);
    },
  );

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

      final result = await controller.save(true, destination, install: install);
      expect(result.outcome, SaveOutcome.saved);
      expect(await File(destination).readAsBytes(), [0x10, 0xAF, 0x30]);
      expect(controller.dirty(true), isFalse);
      expect(
        controller.path(true),
        await File(destination).resolveSymbolicLinks(),
      );
      expect(controller.path(true)?.split('/').last, 'saved.bin');
      controller.dispose();
    },
  );

  test('Save As installs the staged file and adopts its destination', () async {
    final source = File('${directory.path}/source.bin');
    final destination = '${directory.path}/renamed.bin';
    await source.writeAsBytes([0x10, 0x20, 0x30]);
    final controller = CompareController();
    await controller.open(source.path, true);
    controller.setEditing(true, true);
    controller.select(1, true);
    controller.inputHex('A');
    controller.inputHex('F');
    var installed = false;

    final result = await controller.save(
      true,
      destination,
      install: (stagedPath, destinationPath) async {
        installed = true;
        expect(destinationPath, destination);
        await File(stagedPath).rename(destinationPath);
        return const SaveInstallResult.installed();
      },
    );

    expect(result.outcome, SaveOutcome.saved);
    expect(installed, isTrue);
    expect(await File(destination).readAsBytes(), [0x10, 0xAF, 0x30]);
    expect(
      controller.path(true),
      await File(destination).resolveSymbolicLinks(),
    );
    expect(controller.dirty(true), isFalse);
    controller.dispose();
  });

  test('former source opens in the opposite pane after Save As', () async {
    final source = File('${directory.path}/original.bin');
    final destination = '${directory.path}/saved-as.bin';
    await source.writeAsBytes([1, 2, 3, 4]);
    final controller = CompareController();
    await controller.open(source.path, true);
    expect(
      (await controller.save(true, destination, install: install)).outcome,
      SaveOutcome.saved,
    );

    // Metadata changes can occur when macOS grants sandbox access or a cloud
    // provider updates extended attributes during a Finder drop.
    await Future<void>.delayed(const Duration(milliseconds: 10));
    await Process.run('chmod', ['400', source.path]);
    await controller.open(source.path, false);

    expect(controller.path(true)?.split('/').last, 'saved-as.bin');
    expect(controller.path(false)?.split('/').last, 'original.bin');
    expect(controller.invalid, isFalse);
    expect(controller.error, isNull);
    controller.dispose();
  });

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

    final result = await controller.save(true, source.path, install: install);
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

      final result = await controller.save(true, rightAlias, install: install);
      expect(result.outcome, SaveOutcome.failed);
      expect(await right.readAsBytes(), [2]);
      expect(controller.dirty(true), isTrue);
      controller.dispose();
    },
  );
}
