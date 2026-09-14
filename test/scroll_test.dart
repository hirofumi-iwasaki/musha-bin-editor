import 'dart:typed_data';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mushaaeshi_binary_editor/application/compare_controller.dart';
import 'package:mushaaeshi_binary_editor/infrastructure/file_comparison.dart';
import 'package:mushaaeshi_binary_editor/main.dart';
import 'package:mushaaeshi_binary_editor/presentation/hex_pane.dart';

// Keep file I/O out of gesture tests while exercising the real controller's
// viewport clamping and the complete window's nested scrollable structure.
class MemoryPreviewController extends CompareController {
  MemoryPreviewController() {
    final stamp = FileStamp(8192, DateTime(2026), DateTime(2026));
    left = PagedFile('left.bin', stamp);
    right = PagedFile('right.bin', stamp);
  }
  @override
  Future<void> refresh() async {
    loading = false;
    leftBytes = Uint8List((visibleRows + 1) * bytesPerRow);
    rightBytes = Uint8List(leftBytes.length);
    notifyListeners();
  }
}

void main() {
  for (final width in [1440.0, 980.0]) {
    testWidgets('wheel and trackpad scroll both panes at width $width', (
      tester,
    ) async {
      final c = MemoryPreviewController();
      await tester.binding.setSurfaceSize(Size(width, 800));
      await tester.pumpWidget(MaterialApp(home: CompareWindow(controller: c)));
      await tester.pumpAndSettle();
      // No extra title row; the sample action remains in the toolbar.
      expect(find.text('Mushaaeshi Binary Editor'), findsNothing);
      expect(find.text('Open Sample'), findsOneWidget);
      void expectRow(int row) {
        expect(c.topRow, row);
        final panes = tester.widgetList<HexPane>(find.byType(HexPane));
        expect(panes.map((p) => p.offset), everyElement(row * c.bytesPerRow));
      }

      for (final side in ['left', 'right']) {
        c.scrollTo(0);
        await tester.pumpAndSettle();
        final surface = find.byKey(ValueKey('$side-hex-surface'));
        final point = tester.getTopLeft(surface) + const Offset(150, 80);
        // Mixed horizontal jitter must not steal vertical wheel movement.
        await tester.sendEventToBinding(
          PointerScrollEvent(position: point, scrollDelta: const Offset(2, 75)),
        );
        await tester.pumpAndSettle();
        expectRow(3); // Exactly once, not once for each ancestor listener.
        await tester.sendEventToBinding(
          PointerScrollEvent(
            position: point,
            scrollDelta: const Offset(0, -25),
          ),
        );
        await tester.pumpAndSettle();
        expectRow(2);
        // Flutter delivers macOS trackpad deltas after applying the user's
        // system scroll-direction preference. The app forwards them unchanged
        // to the standard ScrollPosition.
        await tester.sendEventToBinding(
          PointerScrollEvent(
            kind: PointerDeviceKind.trackpad,
            position: point,
            scrollDelta: const Offset(0, 75),
          ),
        );
        await tester.pumpAndSettle();
        expectRow(5);
        await tester.sendEventToBinding(
          PointerScrollEvent(
            kind: PointerDeviceKind.trackpad,
            position: point,
            scrollDelta: const Offset(0, -50),
          ),
        );
        await tester.pumpAndSettle();
        expectRow(3);
        // Pixel deltas accumulate naturally in Flutter's ScrollPosition.
        for (var i = 0; i < 5; i++) {
          await tester.sendEventToBinding(
            PointerScrollEvent(
              position: point,
              scrollDelta: const Offset(0, 5),
            ),
          );
        }
        await tester.pumpAndSettle();
        expectRow(4);
        c.scrollTo(c.maxTop);
        await tester.pumpAndSettle();
        await tester.sendEventToBinding(
          PointerScrollEvent(
            position: point,
            scrollDelta: const Offset(0, 100),
          ),
        );
        await tester.pumpAndSettle();
        expectRow(c.maxTop);
        await tester.sendEventToBinding(
          PointerScrollEvent(
            position: point,
            scrollDelta: const Offset(0, -25),
          ),
        );
        await tester.pumpAndSettle();
        expectRow(c.maxTop - 1);
        expect(tester.takeException(), isNull);
      }
      await tester.pumpWidget(const SizedBox());
      c.dispose();
      await tester.binding.setSurfaceSize(null);
    });
  }
}
