import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mushagaeshi_binary_editor/infrastructure/file_comparison.dart';

void main() {
  late Directory directory;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('mushagaeshi-test-');
  });
  tearDown(() async {
    await directory.delete(recursive: true);
  });

  test(
    'viewport reads page boundary and detects external modification',
    () async {
      final file = File('${directory.path}/a.bin');
      await file.writeAsBytes(List.generate(131072, (i) => i % 256));
      final paged = PagedFile(file.path, await FileStamp.read(file.path));
      expect(
        await paged.read(65530, 20),
        List.generate(20, (i) => (65530 + i) % 256),
      );
      expect(await paged.read(131070, 20), [254, 255]);
      expect(await paged.read(131072, 20), isEmpty);
      await file.writeAsBytes([1, 2, 3]);
      await expectLater(paged.read(0, 1), throwsA(isA<FileSystemException>()));
    },
  );

  test(
    'worker merges differences across 1MiB boundary and includes tail',
    () async {
      final a = File('${directory.path}/a.bin');
      final b = File('${directory.path}/b.bin');
      await a.writeAsBytes(Uint8List(scanBlockSize + 3));
      final bytes = Uint8List(scanBlockSize + 5);
      bytes[scanBlockSize - 1] = 1;
      bytes[scanBlockSize] = 1;
      await b.writeAsBytes(bytes);
      final port = ReceivePort();
      final future = port.firstWhere((m) => (m as Map)['type'] != 'progress');
      await compareWorker({
        'port': port.sendPort,
        'left': a.path,
        'right': b.path,
        'leftStamp': await FileStamp.read(a.path),
        'rightStamp': await FileStamp.read(b.path),
      });
      final result = await future as Map;
      expect(result['type'], 'done');
      expect(result['bytes'], 4);
      expect(result['runs'], 2);
      port.close();
    },
  );

  test('metadata-only changes do not invalidate an open file', () async {
    final file = File('${directory.path}/metadata.bin');
    await file.writeAsBytes([1, 2, 3, 4]);
    final original = await FileStamp.read(file.path);

    await Future<void>.delayed(const Duration(milliseconds: 10));
    await Process.run('chmod', ['400', file.path]);
    final metadataChanged = await FileStamp.read(file.path);

    expect(metadataChanged.changed, isNot(original.changed));
    expect(metadataChanged.modified, original.modified);
    expect(metadataChanged.matches(original), isTrue);
    expect(await PagedFile(file.path, original).read(0, 4), [1, 2, 3, 4]);
  });
}
