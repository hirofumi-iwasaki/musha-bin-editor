// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mushagaeshi_binary_editor/application/language_controller.dart';
import 'package:mushagaeshi_binary_editor/application/compare_controller.dart';
import 'package:mushagaeshi_binary_editor/infrastructure/settings/language_preferences.dart';
import 'package:mushagaeshi_binary_editor/main.dart';

class MemoryPreferences implements LanguagePreferences {
  String? value;
  bool failRead = false;
  bool failWrite = false;
  Completer<void>? gate;
  final writes = <String>[];

  @override
  Future<String?> read() async {
    if (failRead) throw StateError('read failed');
    return value;
  }

  @override
  Future<void> write(String value) async {
    writes.add(value);
    await gate?.future;
    if (failWrite) throw StateError('write failed');
    this.value = value;
  }
}

void main() {
  test('system uses only the first OS language', () {
    expect(
      resolveAppLocale(AppLanguage.system, [const Locale('ja', 'JP')]),
      const Locale('ja'),
    );
    expect(
      resolveAppLocale(AppLanguage.system, [
        const Locale('en'),
        const Locale('ja'),
      ]),
      const Locale('en'),
    );
    expect(
      resolveAppLocale(AppLanguage.system, [
        const Locale('fr'),
        const Locale('ja'),
      ]),
      const Locale('en'),
    );
  });

  test(
    'manual selection persists and invalid data returns to System',
    () async {
      final store = MemoryPreferences();
      final controller = LanguageController(preferences: store);
      await controller.select(AppLanguage.ja);
      final restarted = LanguageController(preferences: store);
      await restarted.load();
      expect(restarted.selection, AppLanguage.ja);
      store.value = 'unsupported';
      await restarted.load();
      expect(restarted.selection, AppLanguage.system);
    },
  );

  test('serial persistence leaves the latest choice stored', () async {
    final gate = Completer<void>();
    final store = MemoryPreferences()..gate = gate;
    final controller = LanguageController(preferences: store);
    final first = controller.select(AppLanguage.ja);
    final second = controller.select(AppLanguage.en);
    await Future<void>.delayed(Duration.zero);
    expect(store.writes, ['ja']);
    gate.complete();
    await Future.wait([first, second]);
    expect(store.writes, ['ja', 'en']);
    expect(store.value, 'en');
  });

  testWidgets('manual switch updates locale without replacing dirty edits', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1100, 760));
    addTearDown(() async => tester.binding.setSurfaceSize(null));
    final language = LanguageController();
    final controller = CompareController()..leftEdits[0x12] = 0xff;
    await tester.pumpWidget(
      MushagaeshiBinaryEditorApp(language: language, controller: controller),
    );
    await language.select(AppLanguage.ja);
    await tester.pumpAndSettle();
    expect(
      Localizations.localeOf(tester.element(find.byType(Scaffold))),
      const Locale('ja'),
    );
    expect(find.text('左を開く'), findsWidgets);
    expect(find.text('ファイルをここへドラッグして開く'), findsNWidgets(2));
    expect(find.text('比較する 2 つのファイルを開いてください'), findsOneWidget);
    expect(controller.leftEdits, {0x12: 0xff});
    controller.dispose();
  });

  testWidgets('visible semantic errors change language without losing detail', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1100, 760));
    addTearDown(() async => tester.binding.setSurfaceSize(null));
    final language = LanguageController();
    final controller = CompareController()
      ..reportError(
        CompareError.openFileFailed,
        detail: 'FileSystemException: denied',
      );
    await tester.pumpWidget(
      MushagaeshiBinaryEditorApp(language: language, controller: controller),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Unable to open file.'), findsOneWidget);
    expect(find.textContaining('FileSystemException: denied'), findsOneWidget);

    await language.select(AppLanguage.ja);
    await tester.pumpAndSettle();
    expect(find.textContaining('ファイルを開けません。'), findsOneWidget);
    expect(find.textContaining('FileSystemException: denied'), findsOneWidget);
    controller.dispose();
  });
}
