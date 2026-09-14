import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mushagaeshi_binary_editor/infrastructure/file_hash.dart';

void main() {
  test('calculates standard SHA-1 and MD5 digests', () async {
    final directory = await Directory.systemTemp.createTemp(
      'mushagaeshi-hash-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/abc.bin');
    await file.writeAsString('abc');

    expect(
      await calculateFileHash(file.path, FileHashAlgorithm.sha1),
      'a9993e364706816aba3e25717850c26c9cd0d89d',
    );
    expect(
      await calculateFileHash(file.path, FileHashAlgorithm.md5),
      '900150983cd24fb0d6963f7d28e17f72',
    );
  });
}
