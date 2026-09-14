import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mushaaeshi_binary_editor/application/compare_controller.dart';
import 'package:mushaaeshi_binary_editor/infrastructure/file_comparison.dart';
import 'package:mushaaeshi_binary_editor/main.dart';

class DropRecordingController extends CompareController {
  DropRecordingController() {
    final stamp = FileStamp(8192, DateTime(2026), DateTime(2026));
    left = PagedFile('left.bin', stamp);
    right = PagedFile('right.bin', stamp);
  }

  String? openedPath;
  bool? openedLeft;

  @override
  Future<void> open(String path, bool isLeft) async {
    openedPath = path;
    openedLeft = isLeft;
  }

  @override
  Future<void> refresh() async {
    loading = false;
    leftBytes = Uint8List((visibleRows + 1) * bytesPerRow);
    rightBytes = Uint8List(leftBytes.length);
    notifyListeners();
  }
}

Future<void> sendNativeMethod(MethodCall call) async {
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  await messenger.handlePlatformMessage(
    'mushaaeshi/files',
    const StandardMethodCodec().encodeMethodCall(call),
    (_) {},
  );
}

void main() {
  testWidgets('native file drops open the side reported by macOS', (
    tester,
  ) async {
    final controller = DropRecordingController();
    await tester.binding.setSurfaceSize(const Size(1440, 800));
    await tester.pumpWidget(
      MaterialApp(home: CompareWindow(controller: controller)),
    );
    await tester.pumpAndSettle();

    await sendNativeMethod(
      const MethodCall('fileDropped', {
        'path': '/tmp/left.bin',
        'side': 'Left',
      }),
    );
    expect(controller.openedPath, '/tmp/left.bin');
    expect(controller.openedLeft, isTrue);

    await sendNativeMethod(
      const MethodCall('fileDropped', {
        'path': '/tmp/right.bin',
        'side': 'Right',
      }),
    );
    expect(controller.openedPath, '/tmp/right.bin');
    expect(controller.openedLeft, isFalse);

    await sendNativeMethod(
      const MethodCall('fileDropError', {
        'message': 'Drop exactly one file at a time.',
      }),
    );
    expect(controller.error, 'Drop exactly one file at a time.');
    Finder dropTarget(String label) => find.byWidgetPredicate(
      (widget) => widget is Semantics && widget.properties.label == label,
    );
    expect(
      dropTarget(
        'Left file drop target. Drop one binary file to open it on the left.',
      ),
      findsOneWidget,
    );
    expect(
      dropTarget(
        'Right file drop target. Drop one binary file to open it on the right.',
      ),
      findsOneWidget,
    );

    await tester.pumpWidget(const SizedBox());
    controller.dispose();
    await tester.binding.setSurfaceSize(null);
  });
}
