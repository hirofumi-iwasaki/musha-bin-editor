// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:convert';
import 'dart:io';

void main(List<String> args) {
  if (args.length != 3) throw ArgumentError('usage: <directory> <target> <flutter-bin>');
  final output = Directory(args[0]);
  if (!output.existsSync()) throw ArgumentError.value(output.path, 'directory');
  File('LICENSE').copySync('${output.path}${Platform.pathSeparator}LICENSE');
  final sourceRevision = _run('git', const ['rev-parse', 'HEAD']);
  final sourceUrl = _run('git', const ['remote', 'get-url', 'origin']);
  final flutterVersion = _run(args[2], const ['--version']);
  File('${output.path}${Platform.pathSeparator}SOURCE_AND_BUILD.txt').writeAsStringSync('''Mushagaeshi Binary Editor distribution metadata
Target: ${args[1]}
Source repository: $sourceUrl
Source revision: $sourceRevision
Flutter SDK:
$flutterVersion

Corresponding source is available from the repository at the revision above.
Build from a clean checkout with the pinned Flutter SDK, flutter pub get, and
the platform packaging command recorded by this release workflow.
''');

  final licenses = Directory('${output.path}${Platform.pathSeparator}THIRD_PARTY_LICENSES')..createSync();
  final copied = <String>[];
  final packageConfig = File('.dart_tool/package_config.json');
  if (packageConfig.existsSync()) {
    final config = jsonDecode(packageConfig.readAsStringSync()) as Map<String, dynamic>;
    for (final package in config['packages'] as List<dynamic>) {
      final data = package as Map<String, dynamic>;
      final root = Uri.parse(data['rootUri'] as String);
      if (!root.isScheme('file')) continue;
      final packageRoot = Directory.fromUri(root);
      for (final candidate in const ['LICENSE', 'LICENSE.md', 'COPYING']) {
        final license = File('${packageRoot.path}${Platform.pathSeparator}$candidate');
        if (license.existsSync()) {
          final destination = File('${licenses.path}${Platform.pathSeparator}${data['name']}-$candidate');
          if (!destination.existsSync()) {
            license.copySync(destination.path);
            copied.add(destination.uri.pathSegments.last);
          }
          break;
        }
      }
    }
  }
  File('${output.path}${Platform.pathSeparator}THIRD_PARTY_NOTICES.txt').writeAsStringSync('''License texts copied from the package roots resolved by pub are in THIRD_PARTY_LICENSES/. Flutter and Dart notices remain in the complete runtime bundle. pubspec.lock fixes the exact dependency set.

Included license files:
${copied.isEmpty ? '(none found; inspect pubspec.lock before distribution)' : copied.join('\n')}
''');
}

String _run(String executable, List<String> arguments) {
  final result = Process.runSync(executable, arguments);
  if (result.exitCode != 0) throw ProcessException(executable, arguments, '${result.stderr}', result.exitCode);
  return result.stdout.toString().trim();
}
