// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:async';
import 'dart:convert';

import 'package:flutter/scheduler.dart';

import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'application/compare_controller.dart';
import 'presentation/hex_pane.dart';

void main() => runApp(const MushaaeshiBinaryEditorApp());

class MushaaeshiBinaryEditorApp extends StatelessWidget {
  const MushaaeshiBinaryEditorApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Mushaaeshi Binary Editor',
    locale: const Locale('en'),
    supportedLocales: const [Locale('en')],
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF315EA8)),
      useMaterial3: true,
      scaffoldBackgroundColor: const Color(0xFFFFFFFF),
    ),
    darkTheme: ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF7BA6ED),
        brightness: Brightness.dark,
      ),
      useMaterial3: true,
      scaffoldBackgroundColor: const Color(0xFF191E26),
    ),
    home: const CompareWindow(),
  );
}

class CompareWindow extends StatefulWidget {
  const CompareWindow({super.key, this.controller});
  final CompareController? controller;
  @override
  State<CompareWindow> createState() => _CompareWindowState();
}

class _CompareWindowState extends State<CompareWindow> {
  late final controller = widget.controller ?? CompareController();
  final leftFocus = FocusNode(debugLabel: 'Left hex');
  final rightFocus = FocusNode(debugLabel: 'Right hex');
  static const platform = MethodChannel('mushaaeshi/files');
  double wheelRemainder = 0;
  bool picking = false;

  @override
  void initState() {
    super.initState();
    if (const bool.fromEnvironment('BENCHMARK')) {
      unawaited(benchmark());
    } else if (const bool.fromEnvironment('DEMO')) {
      unawaited(controller.demo());
    }
  }

  Future<void> benchmark() async {
    await controller.demo();
    while (mounted && controller.busy) {
      await Future<void>.delayed(const Duration(milliseconds: 30));
    }
    await Future<void>.delayed(const Duration(seconds: 1));
    final frames = <FrameTiming>[];
    void collect(List<FrameTiming> timings) => frames.addAll(timings);
    SchedulerBinding.instance.addTimingsCallback(collect);
    for (var i = 0; i < 180 && mounted; i++) {
      controller.scrollTo((i * 3) % math.max(1, controller.maxTop));
      await Future<void>.delayed(const Duration(milliseconds: 17));
    }
    await Future<void>.delayed(const Duration(seconds: 1));
    SchedulerBinding.instance.removeTimingsCallback(collect);
    double percentile(List<int> values, double p) {
      if (values.isEmpty) return 0;
      values.sort();
      return values[((values.length - 1) * p).round()] / 1000;
    }

    debugPrint(
      'MUSHAAESHI_FRAME_BENCHMARK ${jsonEncode({'frames': frames.length, 'buildP50Ms': percentile(frames.map((f) => f.buildDuration.inMicroseconds).toList(), 0.5), 'buildP95Ms': percentile(frames.map((f) => f.buildDuration.inMicroseconds).toList(), 0.95), 'rasterP50Ms': percentile(frames.map((f) => f.rasterDuration.inMicroseconds).toList(), 0.5), 'rasterP95Ms': percentile(frames.map((f) => f.rasterDuration.inMicroseconds).toList(), 0.95)})}',
    );
    if (mounted) controller.jump(0);
  }

  @override
  void dispose() {
    if (widget.controller == null) controller.dispose();
    leftFocus.dispose();
    rightFocus.dispose();
    super.dispose();
  }

  Future<void> open(bool left) async {
    if (picking) return;
    setState(() => picking = true);
    try {
      final path = await platform.invokeMethod<String>('openFile', {
        'side': left ? 'Left' : 'Right',
      });
      if (path != null && mounted) await controller.open(path, left);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Unable to open file: $error')));
      }
    } finally {
      if (mounted) setState(() => picking = false);
    }
  }

  Future<void> goTo() async {
    final input = TextEditingController();
    String? error;
    final result = await showDialog<int>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, update) {
          void submit() {
            var text = input.text.trim().toLowerCase();
            if (text.startsWith('0x')) text = text.substring(2);
            final at = int.tryParse(text, radix: 16);
            if (at == null || at < 0 || at >= controller.length) {
              update(
                () => error = 'Enter a hexadecimal offset within the file',
              );
              return;
            }
            Navigator.pop(context, at);
          }

          return AlertDialog(
            title: const Text('Go to Offset'),
            content: SizedBox(
              width: 360,
              child: TextField(
                controller: input,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Hex offset (e.g. 400 or 0x400)',
                  errorText: error,
                ),
                onSubmitted: (_) => submit(),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              FilledButton(onPressed: submit, child: const Text('Go')),
            ],
          );
        },
      ),
    );
    // The route finishes its dismissal animation after showDialog completes.
    Future<void>.delayed(const Duration(milliseconds: 300), input.dispose);
    if (result != null && mounted) controller.jump(result);
  }

  void wheel(double delta) {
    wheelRemainder += delta;
    final rows = (wheelRemainder / hexRowHeight).truncate();
    if (rows != 0) {
      wheelRemainder -= rows * hexRowHeight;
      final previous = controller.topRow;
      controller.scrollTo(previous + rows);
      if (controller.topRow == previous) wheelRemainder = 0;
    }
  }

  KeyEventResult key(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    if (HardwareKeyboard.instance.isMetaPressed ||
        HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isAltPressed) {
      return KeyEventResult.ignored;
    }
    final k = event.logicalKey;
    if (k == LogicalKeyboardKey.pageDown) {
      controller.scrollTo(controller.topRow + controller.visibleRows);
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.pageUp) {
      controller.scrollTo(controller.topRow - controller.visibleRows);
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.home) {
      controller.jump(0);
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.end) {
      controller.jump(controller.length - 1);
      return KeyEventResult.handled;
    }
    final delta = k == LogicalKeyboardKey.arrowDown
        ? controller.bytesPerRow
        : k == LogicalKeyboardKey.arrowUp
        ? -controller.bytesPerRow
        : k == LogicalKeyboardKey.arrowRight
        ? 1
        : k == LogicalKeyboardKey.arrowLeft
        ? -1
        : 0;
    if (delta != 0 && controller.length > 0) {
      final left = !rightFocus.hasFocus;
      final size = (left ? controller.left : controller.right)?.stamp.size ?? 0;
      if (size == 0) return KeyEventResult.handled;
      final at = ((controller.selected ?? controller.offset) + delta).clamp(
        0,
        size - 1,
      );
      controller.select(at, left);
      if (at < controller.offset ||
          at >=
              controller.offset +
                  controller.visibleRows * controller.bytesPerRow) {
        controller.jump(at);
      }
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  String fileSize(int size) => size < 1024
      ? '$size B'
      : size < 1024 * 1024
      ? '${(size / 1024).toStringAsFixed(1)} KiB'
      : '${(size / 1024 / 1024).toStringAsFixed(1)} MiB';

  Widget pane(bool left) {
    final file = left ? controller.left : controller.right;
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 62,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: Theme.of(context).dividerColor.withValues(alpha: 0.15),
                ),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  left ? Icons.file_present_outlined : Icons.compare_outlined,
                  size: 21,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${left ? 'Left' : 'Right'} · ${file == null ? 'No file selected' : file.path.split('/').last}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Tooltip(
                        message: file?.path ?? '',
                        child: Text(
                          file == null
                              ? 'Choose Open ${left ? 'Left' : 'Right'}'
                              : '${fileSize(file.stamp.size)}  ·  ${file.stamp.size} bytes',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
                const Text('Read-only', style: TextStyle(fontSize: 11)),
              ],
            ),
          ),
          Expanded(
            child: HexPane(
              bytes: left ? controller.leftBytes : controller.rightBytes,
              other: left ? controller.rightBytes : controller.leftBytes,
              offset: controller.offset,
              size: file?.stamp.size ?? 0,
              totalSize: controller.length,
              columns: controller.bytesPerRow,
              isLeft: left,
              hasFile: file != null,
              hasOther: (left ? controller.right : controller.left) != null,
              loading: controller.loading,
              invalid: controller.invalid,
              selected: controller.selectedLeft == left
                  ? controller.selected
                  : null,
              onSelect: (at) => controller.select(at, left),
              onScroll: wheel,
              focusNode: left ? leftFocus : rightFocus,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) => CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyO, meta: true): () =>
            open(true),
        const SingleActivator(
          LogicalKeyboardKey.keyO,
          meta: true,
          shift: true,
        ): () =>
            open(false),
        const SingleActivator(LogicalKeyboardKey.keyG, meta: true): () {
          if (controller.length > 0) unawaited(goTo());
        },
      },
      child: Focus(
        onKeyEvent: key,
        child: Scaffold(
          body: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      FilledButton.tonalIcon(
                        onPressed: picking ? null : () => open(true),
                        icon: const Icon(Icons.folder_open, size: 18),
                        label: const Text('Open Left'),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: picking ? null : () => open(false),
                        icon: const Icon(Icons.folder_open, size: 18),
                        label: const Text('Open Right'),
                      ),
                      OutlinedButton.icon(
                        onPressed: controller.canCompare && !controller.busy
                            ? () => controller.compare(forward: false)
                            : null,
                        icon: const Icon(Icons.arrow_upward, size: 16),
                        label: const Text('Previous Diff'),
                      ),
                      OutlinedButton.icon(
                        onPressed: controller.canCompare && !controller.busy
                            ? () => controller.compare(forward: true)
                            : null,
                        icon: const Icon(Icons.arrow_downward, size: 16),
                        label: const Text('Next Diff'),
                      ),
                      TextButton(
                        onPressed: controller.length > 0 ? goTo : null,
                        child: const Text('Go to Offset'),
                      ),
                      SegmentedButton<int>(
                        segments: const [
                          ButtonSegment(value: 8, label: Text('8 B/row')),
                          ButtonSegment(value: 16, label: Text('16 B/row')),
                        ],
                        selected: {controller.bytesPerRow},
                        onSelectionChanged: (v) => controller.setWidth(v.first),
                        showSelectedIcon: false,
                        style: const ButtonStyle(
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                      TextButton(
                        onPressed: picking ? null : controller.demo,
                        child: const Text('Open Sample'),
                      ),
                      TextButton(
                        onPressed: controller.busy
                            ? controller.stop
                            : controller.canCompare
                            ? controller.compare
                            : null,
                        child: Text(
                          controller.busy ? 'Cancel' : 'Compare Again',
                        ),
                      ),
                    ],
                  ),
                ),
                if (controller.busy)
                  LinearProgressIndicator(
                    minHeight: 2,
                    value: controller.length > 0 && !controller.complete
                        ? controller.processed / controller.length
                        : null,
                  )
                else
                  const SizedBox(height: 2),
                if (controller.error != null)
                  Container(
                    width: double.infinity,
                    color: Theme.of(context).colorScheme.errorContainer,
                    padding: const EdgeInsets.all(10),
                    child: Text(
                      controller.error!,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, bounds) {
                      final rows = math.max(
                        1,
                        ((bounds.maxHeight - 62 - hexHeaderHeight) /
                                hexRowHeight)
                            .floor(),
                      );
                      if (rows != controller.visibleRows) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted) controller.setRows(rows);
                        });
                      }
                      return Listener(
                        onPointerSignal: (event) {
                          if (event is PointerScrollEvent &&
                              event.scrollDelta.dy != 0) {
                            GestureBinding.instance.pointerSignalResolver
                                .register(
                                  event,
                                  (_) => wheel(event.scrollDelta.dy),
                                );
                          }
                        },
                        child: Row(
                          children: [
                            pane(true),
                            VerticalDivider(
                              width: 1,
                              thickness: 1,
                              color: Theme.of(context).dividerColor
                                  .withValues(alpha: 0.2),
                            ),
                            pane(false),
                            SizedBox(
                              width: 18,
                              child: LayoutBuilder(
                                builder: (context, track) {
                                  final height = track.maxHeight;
                                  final thumb = math.max(
                                    32.0,
                                    height *
                                        math.min(
                                          1,
                                          controller.visibleRows /
                                              math.max(1, controller.rowCount),
                                        ),
                                  );
                                  final travel = math.max(0.0, height - thumb);
                                  void move(double y) {
                                    if (travel > 0) {
                                      controller.scrollTo(
                                        (((y - thumb / 2) / travel).clamp(
                                                  0.0,
                                                  1.0,
                                                ) *
                                                controller.maxTop)
                                            .round(),
                                      );
                                    }
                                  }

                                  return Semantics(
                                    label: 'Synchronized scrolling',
                                    value: 'Row ${controller.topRow + 1}',
                                    increasedValue:
                                        'Row ${(controller.topRow + controller.visibleRows).clamp(0, controller.maxTop) + 1}',
                                    decreasedValue:
                                        'Row ${(controller.topRow - controller.visibleRows).clamp(0, controller.maxTop) + 1}',
                                    onIncrease: () => controller.scrollTo(
                                      controller.topRow +
                                          controller.visibleRows,
                                    ),
                                    onDecrease: () => controller.scrollTo(
                                      controller.topRow -
                                          controller.visibleRows,
                                    ),
                                    child: GestureDetector(
                                      behavior: HitTestBehavior.opaque,
                                      onTapDown: (d) =>
                                          move(d.localPosition.dy),
                                      onVerticalDragUpdate: (d) =>
                                          move(d.localPosition.dy),
                                      child: Stack(
                                        children: [
                                          Positioned(
                                            top: controller.maxTop == 0
                                                ? 0
                                                : travel *
                                                      controller.topRow /
                                                      controller.maxTop,
                                            left: 5,
                                            right: 5,
                                            height: math.min(height, thumb),
                                            child: DecoratedBox(
                                              decoration: BoxDecoration(
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .outline
                                                    .withValues(alpha: 0.45),
                                                borderRadius:
                                                    BorderRadius.circular(5),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(
                        color: Theme.of(context).dividerColor
                            .withValues(alpha: 0.2),
                      ),
                    ),
                  ),
                  child: Wrap(
                    spacing: 20,
                    runSpacing: 4,
                    children: [
                      const Text(
                        'Same-offset comparison',
                        style: TextStyle(fontSize: 12),
                      ),
                      Text(
                        controller.status,
                        style: const TextStyle(fontSize: 12),
                      ),
                      if (controller.pair && !controller.invalid)
                        Text(
                          '${controller.complete ? 'Differences' : 'Found so far'} ${controller.diffBytes} bytes / ${controller.diffRuns} ranges',
                          style: const TextStyle(fontSize: 12),
                        ),
                      if (controller.selected != null)
                        Text(
                          '${controller.selectedLeft ? 'Left' : 'Right'} 0x${controller.selected!.toRadixString(16).padLeft(8, '0').toUpperCase()}',
                          style: const TextStyle(fontSize: 12),
                        ),
                      if (controller.complete)
                        Text(
                          '${controller.elapsedMs} ms',
                          style: const TextStyle(fontSize: 12),
                        ),
                      const Text(
                        'Red: different  ·  Orange: one side only',
                        style: TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
