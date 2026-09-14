// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:async';
import 'dart:convert';

import 'package:flutter/scheduler.dart';

import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'application/compare_controller.dart';
import 'infrastructure/safe_save.dart';
import 'presentation/hex_pane.dart';

void main() => runApp(const MushagaeshiBinaryEditorApp());

class MushagaeshiBinaryEditorApp extends StatelessWidget {
  const MushagaeshiBinaryEditorApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Mushagaeshi Binary Editor',
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
  final leftPaneKey = GlobalKey();
  final rightPaneKey = GlobalKey();
  final verticalScroll = ScrollController();
  static const platform = MethodChannel('mushagaeshi/files');
  bool picking = false;
  bool? hoveredDropLeft;

  @override
  void initState() {
    super.initState();
    verticalScroll.addListener(_scrollChanged);
    platform.setMethodCallHandler(_handlePlatformCall);
    if (const bool.fromEnvironment('BENCHMARK')) {
      unawaited(benchmark());
    }
  }

  Future<void> benchmark() async {
    await controller.loadBenchmarkFixture();
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
      'MUSHAGAESHI_FRAME_BENCHMARK ${jsonEncode({'frames': frames.length, 'buildP50Ms': percentile(frames.map((f) => f.buildDuration.inMicroseconds).toList(), 0.5), 'buildP95Ms': percentile(frames.map((f) => f.buildDuration.inMicroseconds).toList(), 0.95), 'rasterP50Ms': percentile(frames.map((f) => f.rasterDuration.inMicroseconds).toList(), 0.5), 'rasterP95Ms': percentile(frames.map((f) => f.rasterDuration.inMicroseconds).toList(), 0.95)})}',
    );
    if (mounted) controller.jump(0);
  }

  @override
  void dispose() {
    platform.setMethodCallHandler(null);
    verticalScroll
      ..removeListener(_scrollChanged)
      ..dispose();
    if (widget.controller == null) controller.dispose();
    leftFocus.dispose();
    rightFocus.dispose();
    super.dispose();
  }

  void _scrollChanged() {
    if (!verticalScroll.hasClients) return;
    controller.scrollTo((verticalScroll.offset / hexRowHeight).floor());
  }

  Future<void> _handlePlatformCall(MethodCall call) async {
    if (!mounted) return;
    if (call.method == 'fileDropped') {
      final arguments = call.arguments;
      if (arguments is! Map ||
          arguments['path'] is! String ||
          arguments['x'] is! num ||
          arguments['y'] is! num) {
        controller.reportError('Unable to open the dropped file.');
        return;
      }
      final side = _dropSideAt(
        Offset(
          (arguments['x'] as num).toDouble(),
          (arguments['y'] as num).toDouble(),
        ),
      );
      if (side == null) {
        controller.reportError(
          'Drop the file on the left or right binary pane.',
        );
      } else {
        if (await _confirmReplace(side)) {
          await controller.open(arguments['path'] as String, side);
        }
      }
      if (mounted) setState(() => hoveredDropLeft = null);
    } else if (call.method == 'fileDragUpdated') {
      final arguments = call.arguments;
      if (arguments is Map && arguments['x'] is num && arguments['y'] is num) {
        final side = _dropSideAt(
          Offset(
            (arguments['x'] as num).toDouble(),
            (arguments['y'] as num).toDouble(),
          ),
        );
        if (side != hoveredDropLeft) setState(() => hoveredDropLeft = side);
      }
    } else if (call.method == 'fileDragExited') {
      if (hoveredDropLeft != null) setState(() => hoveredDropLeft = null);
    } else if (call.method == 'fileDropError') {
      final arguments = call.arguments;
      final message = arguments is Map ? arguments['message'] : null;
      controller.reportError(
        message is String ? message : 'Unable to open the dropped file.',
      );
      if (hoveredDropLeft != null) setState(() => hoveredDropLeft = null);
    } else if (call.method == 'requestClose') {
      if (await _confirmBothDirty()) {
        await platform.invokeMethod<void>('confirmClose');
      }
    }
  }

  Future<bool> _confirmBothDirty() async {
    if (controller.dirty(true) && !await _confirmReplace(true)) return false;
    if (controller.dirty(false) && !await _confirmReplace(false)) return false;
    return true;
  }

  Future<bool> _confirmReplace(bool left) async {
    if (!controller.dirty(left)) return true;
    final action = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text('Save changes to the ${left ? 'left' : 'right'} file?'),
        content: const Text('Unsaved edits will be lost if you discard them.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'cancel'),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'discard'),
            child: const Text('Discard'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, 'save'),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (action == 'save') return save(left, saveAs: false);
    return action == 'discard';
  }

  bool? _dropSideAt(Offset point) {
    for (final entry in [(leftPaneKey, true), (rightPaneKey, false)]) {
      final box = entry.$1.currentContext?.findRenderObject() as RenderBox?;
      if (box == null || !box.hasSize) continue;
      final local = box.globalToLocal(point);
      if ((Offset.zero & box.size).contains(local)) return entry.$2;
    }
    return null;
  }

  Future<void> open(bool left) async {
    if (picking) return;
    if (!await _confirmReplace(left)) return;
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

  Future<bool> save(bool left, {required bool saveAs}) async {
    var destination = controller.path(left);
    if (destination == null) return false;
    if (saveAs) {
      destination = await platform.invokeMethod<String>('saveFile', {
        'side': left ? 'Left' : 'Right',
        'name': destination.split('/').last,
      });
      if (destination == null) return false;
    }
    var result = await controller.save(
      left,
      destination,
      install: _installSavedFile,
    );
    if (result.outcome == SaveOutcome.externallyChanged && mounted) {
      final overwrite = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('File changed outside the app'),
          content: const Text(
            'Overwrite the externally changed file with the current edited content?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Overwrite'),
            ),
          ],
        ),
      );
      if (overwrite == true) {
        result = await controller.save(
          left,
          destination,
          allowExternalChange: true,
          install: _installSavedFile,
        );
      }
    }
    if (result.outcome == SaveOutcome.failed && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message ?? 'Unable to save file.')),
      );
    }
    return result.outcome == SaveOutcome.saved;
  }

  Future<void> _installSavedFile(
    String stagedPath,
    String destinationPath,
  ) async {
    await platform.invokeMethod<void>('installSavedFile', {
      'stagedPath': stagedPath,
      'destinationPath': destinationPath,
    });
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

  void _pointerScroll(PointerScrollEvent event) {
    if (!verticalScroll.hasClients) return;
    verticalScroll.position.pointerScroll(event.scrollDelta.dy);
  }

  void _syncScrollPosition() {
    if (!verticalScroll.hasClients) return;
    final desired = controller.topRow * hexRowHeight;
    final currentRow = (verticalScroll.offset / hexRowHeight).floor();
    if (currentRow != controller.topRow) {
      verticalScroll.jumpTo(
        desired.clamp(0, verticalScroll.position.maxScrollExtent),
      );
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
    if (k == LogicalKeyboardKey.escape) {
      controller.cancelPending();
      return KeyEventResult.handled;
    }
    final character = event.character;
    if (character != null &&
        character.length == 1 &&
        RegExp(r'[0-9a-fA-F]').hasMatch(character)) {
      if (controller.inputHex(character)) return KeyEventResult.handled;
    }
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
      child: AnimatedContainer(
        key: left ? leftPaneKey : rightPaneKey,
        duration: const Duration(milliseconds: 100),
        decoration: BoxDecoration(
          color: hoveredDropLeft == left
              ? Theme.of(context).colorScheme.primaryContainer
                    .withValues(alpha: 0.32)
              : null,
          border: hoveredDropLeft == left
              ? Border.all(
                  color: Theme.of(context).colorScheme.primary,
                  width: 3,
                )
              : null,
        ),
        child: Semantics(
          container: true,
          label:
              '${left ? 'Left' : 'Right'} file drop target. Drop one binary file to open it on the ${left ? 'left' : 'right'}.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                height: 62,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: Theme.of(context).dividerColor
                          .withValues(alpha: 0.15),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      left
                          ? Icons.file_present_outlined
                          : Icons.compare_outlined,
                      size: 21,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${left ? 'Left' : 'Right'} · ${file == null ? 'No file selected' : '${file.path.split('/').last}${controller.dirty(left) ? ' *' : ''}'}',
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
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: controller.editing(left),
                      onChanged: file == null
                          ? null
                          : (value) => controller.setEditing(left, value),
                    ),
                    Text(
                      controller.editing(left) ? 'Edit ON' : 'Edit OFF',
                      style: const TextStyle(fontSize: 11),
                    ),
                    IconButton(
                      tooltip: 'Save ${left ? 'Left' : 'Right'}',
                      onPressed: controller.dirty(left)
                          ? () => save(left, saveAs: false)
                          : null,
                      icon: const Icon(Icons.save_outlined, size: 18),
                    ),
                    IconButton(
                      tooltip: 'Save ${left ? 'Left' : 'Right'} As',
                      onPressed: file == null
                          ? null
                          : () => save(left, saveAs: true),
                      icon: const Icon(Icons.save_as_outlined, size: 18),
                    ),
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
                  edited: Set.unmodifiable(
                    left
                        ? controller.leftEdits.keys
                        : controller.rightEdits.keys,
                  ),
                  editing: controller.editing(left),
                  onSelect: (at) => controller.select(at, left),
                  onVerticalPointerScroll: _pointerScroll,
                  focusNode: left ? leftFocus : rightFocus,
                ),
              ),
            ],
          ),
        ),
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
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) _syncScrollPosition();
                      });
                      return Scrollbar(
                        controller: verticalScroll,
                        thumbVisibility: true,
                        child: CustomScrollView(
                          controller: verticalScroll,
                          slivers: [
                            SliverPersistentHeader(
                              pinned: true,
                              delegate: _PinnedPaneDelegate(
                                extent: bounds.maxHeight,
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
                                  ],
                                ),
                              ),
                            ),
                            SliverToBoxAdapter(
                              child: SizedBox(
                                height: controller.maxTop * hexRowHeight,
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

class _PinnedPaneDelegate extends SliverPersistentHeaderDelegate {
  const _PinnedPaneDelegate({required this.extent, required this.child});

  final double extent;
  final Widget child;

  @override
  double get minExtent => extent;

  @override
  double get maxExtent => extent;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) => child;

  @override
  bool shouldRebuild(covariant _PinnedPaneDelegate oldDelegate) =>
      extent != oldDelegate.extent || child != oldDelegate.child;
}
