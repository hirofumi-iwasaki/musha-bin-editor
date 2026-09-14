import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mushagaeshi_binary_editor/main.dart';

void main() {
  testWidgets('empty prototype offers file selection without overflow', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    await tester.pumpWidget(const MushagaeshiBinaryEditorApp());
    await tester.pumpAndSettle();
    expect(find.text('Open Left'), findsOneWidget);
    expect(find.text('Open Right'), findsOneWidget);
    expect(find.text('Open Sample'), findsNothing);
    expect(find.text('Edit OFF'), findsNWidgets(2));
    expect(find.byTooltip('Save Left As'), findsOneWidget);
    expect(find.byTooltip('Save Right As'), findsOneWidget);
    expect(find.text('Drag file here to open'), findsNWidgets(2));
    expect(find.text('SHA-1'), findsOneWidget);
    expect(find.text('Left: No file', findRichText: true), findsOneWidget);
    expect(find.text('Right: No file', findRichText: true), findsOneWidget);
    await tester.tap(find.text('8 B/row'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.binding.setSurfaceSize(const Size(980, 600));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.binding.setSurfaceSize(null);
  });
}
