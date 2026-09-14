// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:io';
import 'dart:isolate';

import 'package:crypto/crypto.dart' as crypto;

enum FileHashAlgorithm {
  sha1('SHA-1'),
  md5('MD5');

  const FileHashAlgorithm(this.label);
  final String label;
}

Future<String> calculateFileHash(String path, FileHashAlgorithm algorithm) =>
    Isolate.run(() async {
      final hash = switch (algorithm) {
        FileHashAlgorithm.sha1 => crypto.sha1,
        FileHashAlgorithm.md5 => crypto.md5,
      };
      final digest = await hash.bind(File(path).openRead()).first;
      return digest.toString();
    });
