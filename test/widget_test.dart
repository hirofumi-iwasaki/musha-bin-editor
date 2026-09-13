import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mushagaeshi_bin_diff/main.dart';

void main() {
  testWidgets(
    'empty prototype offers file selection and sample without overflow',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));
      await tester.pumpWidget(const MushagaeshiApp());
      await tester.pumpAndSettle();
      expect(find.text('左を開く'), findsOneWidget);
      expect(find.text('右を開く'), findsOneWidget);
      expect(find.text('サンプルを開く'), findsOneWidget);
      expect(find.text('ファイルを開いてください'), findsNWidgets(2));
      await tester.tap(find.text('8 B/行'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.binding.setSurfaceSize(const Size(980, 600));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.binding.setSurfaceSize(null);
    },
  );
}
