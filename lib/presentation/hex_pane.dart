// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../core/comparison.dart';
import '../l10n/app_localizations.dart';

const hexRowHeight = 25.0;
const hexHeaderHeight = 30.0;

class HexMetrics {
  const HexMetrics(
    this.glyphWidth,
    this.glyphHeight,
    this.rowHeight,
    this.headerHeight,
    this.textScaler,
    this.unitScale,
  );

  factory HexMetrics.measure(BuildContext context) {
    final painter = TextPainter(
      textDirection: TextDirection.ltr,
      textScaler: MediaQuery.textScalerOf(context),
      text: const TextSpan(
        text: '0',
        style: TextStyle(fontFamily: 'monospace', fontSize: 13),
      ),
    )..layout();
    final textScaler = MediaQuery.textScalerOf(context);
    final unitScale = textScaler.scale(13) / 13;
    return HexMetrics(
      painter.width,
      painter.height,
      math.max(hexRowHeight * unitScale, painter.height + 8 * unitScale),
      hexHeaderHeight * unitScale,
      textScaler,
      unitScale,
    );
  }

  final double glyphWidth;
  final double glyphHeight;
  final double rowHeight;
  final double headerHeight;
  final TextScaler textScaler;
  final double unitScale;
  double get hexCell => glyphWidth * 2 + 6 * unitScale;
}

Color modifiedDifferenceBackground(Brightness brightness) =>
    brightness == Brightness.dark
    ? const Color(0xFF743C48)
    : const Color(0xFFFFD9DD);

class HexLayout {
  HexLayout(this.columns, this.digits, this.width, this.metrics);
  final int columns;
  final int digits;
  final double width;
  final HexMetrics metrics;
  double get hexStart =>
      18 * metrics.unitScale +
      digits * metrics.glyphWidth +
      20 * metrics.unitScale;
  double get cell => metrics.hexCell;
  double x(int col) =>
      hexStart + col * cell + (col ~/ 8) * 9 * metrics.unitScale;
  double get asciiStart => x(columns) + 12 * metrics.unitScale;
  double get requiredWidth =>
      asciiStart + columns * metrics.glyphWidth + 16 * metrics.unitScale;
  int? column(double xPosition) {
    for (var i = 0; i < columns; i++) {
      if (xPosition >= x(i) && xPosition < x(i) + cell) return i;
      if (xPosition >= asciiStart + i * metrics.glyphWidth &&
          xPosition < asciiStart + (i + 1) * metrics.glyphWidth) {
        return i;
      }
    }
    return null;
  }
}

class HexPane extends StatelessWidget {
  const HexPane({
    super.key,
    required this.bytes,
    required this.other,
    required this.offset,
    required this.size,
    required this.totalSize,
    required this.columns,
    required this.isLeft,
    required this.hasFile,
    required this.hasOther,
    required this.loading,
    required this.invalid,
    required this.selected,
    required this.edited,
    required this.editing,
    required this.onSelect,
    required this.onVerticalPointerScroll,
    required this.focusNode,
  });
  final Uint8List bytes;
  final Uint8List other;
  final int offset, size, totalSize, columns;
  final bool isLeft, hasFile, hasOther, loading, invalid;
  final int? selected;
  final Set<int> edited;
  final bool editing;
  final ValueChanged<int> onSelect;
  final ValueChanged<PointerScrollEvent> onVerticalPointerScroll;
  final FocusNode focusNode;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final digits = math.max(
      8,
      math.max(0, totalSize - 1).toRadixString(16).length,
    );
    String selectedLabel = '';
    if (selected != null &&
        selected! >= offset &&
        selected! < offset + bytes.length) {
      final i = selected! - offset;
      final d = hasOther
          ? difference(
              isLeft ? bytes[i] : (i < other.length ? other[i] : null),
              isLeft ? (i < other.length ? other[i] : null) : bytes[i],
            )
          : null;
      final comparison = d == null
          ? l10n?.hexPaneNotCompared ?? 'not compared'
          : d == ByteDifference.equal
          ? l10n?.hexPaneEqual ?? 'equal'
          : l10n?.hexPaneDifferent ?? 'different';
      selectedLabel =
          l10n?.hexPaneSelectedByte(
            selected!.toRadixString(16).toUpperCase(),
            bytes[i].toRadixString(16).padLeft(2, '0').toUpperCase(),
            comparison,
          ) ??
          'Offset ${selected!.toRadixString(16).toUpperCase()}, value ${bytes[i].toRadixString(16).padLeft(2, '0').toUpperCase()}, $comparison';
    }
    return Semantics(
      label:
          l10n?.hexPaneSemantics(
            isLeft ? l10n.left : l10n.right,
            editing ? l10n.hexPaneEditingEnabled : l10n.hexPaneEditingDisabled,
            selectedLabel,
          ) ??
          '${isLeft ? 'Left' : 'Right'} binary pane, ${editing ? 'editing enabled' : 'editing disabled'}. $selectedLabel',
      focusable: true,
      child: Focus(
        focusNode: focusNode,
        child: LayoutBuilder(
          builder: (context, bounds) {
            final layout = HexLayout(
              columns,
              digits,
              bounds.maxWidth,
              HexMetrics.measure(context),
            );
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Listener(
                key: ValueKey(
                  isLeft ? 'left-hex-surface' : 'right-hex-surface',
                ),
                behavior: HitTestBehavior.opaque,
                // Give vertical input to the shared Flutter ScrollPosition before
                // this pane's horizontal Scrollable can claim mixed-axis events.
                onPointerSignal: (event) {
                  if (event is PointerScrollEvent &&
                      event.scrollDelta.dy != 0) {
                    GestureBinding.instance.pointerSignalResolver.register(
                      event,
                      (_) => onVerticalPointerScroll(event),
                    );
                  }
                },
                child: SizedBox(
                  width: math.max(bounds.maxWidth, layout.requiredWidth),
                  height: bounds.maxHeight,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapDown: (event) {
                      focusNode.requestFocus();
                      final col = layout.column(event.localPosition.dx);
                      final row =
                          ((event.localPosition.dy -
                                      layout.metrics.headerHeight) /
                                  layout.metrics.rowHeight)
                              .floor();
                      if (col != null && row >= 0 && !loading && !invalid) {
                        onSelect(offset + row * columns + col);
                      }
                    },
                    child: RepaintBoundary(
                      child: CustomPaint(
                        painter: HexPainter(
                          bytes: bytes,
                          other: other,
                          offset: offset,
                          size: size,
                          totalSize: totalSize,
                          layout: layout,
                          isLeft: isLeft,
                          hasFile: hasFile,
                          hasOther: hasOther,
                          loading: loading,
                          invalid: invalid,
                          selected: selected,
                          edited: edited,
                          dark: Theme.of(context).brightness == Brightness.dark,
                          offsetHeader: l10n?.hexPaneOffsetHeader ?? 'OFFSET',
                          asciiHeader: l10n?.hexPaneAsciiHeader ?? 'ASCII',
                        ),
                        child: !hasFile
                            ? Center(
                                child: Text(
                                  l10n?.hexPaneDragFileHereToOpen ??
                                      'Drag file here to open',
                                ),
                              )
                            : invalid
                            ? Center(
                                child: Text(
                                  l10n?.statusReadError ??
                                      'Read error · Reopen the file',
                                ),
                              )
                            : size == 0 && !hasOther
                            ? Center(
                                child: Text(
                                  l10n?.hexPaneFileEmpty ??
                                      'This file is empty',
                                ),
                              )
                            : null,
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class HexPainter extends CustomPainter {
  HexPainter({
    required this.bytes,
    required this.other,
    required this.offset,
    required this.size,
    required this.totalSize,
    required this.layout,
    required this.isLeft,
    required this.hasFile,
    required this.hasOther,
    required this.loading,
    required this.invalid,
    required this.selected,
    required this.edited,
    required this.dark,
    required this.offsetHeader,
    required this.asciiHeader,
  });
  final Uint8List bytes, other;
  final int offset, size, totalSize;
  final HexLayout layout;
  final bool isLeft, hasFile, hasOther, loading, invalid, dark;
  final String offsetHeader, asciiHeader;
  final int? selected;
  final Set<int> edited;

  @override
  void paint(Canvas canvas, Size canvasSize) {
    final foreground = dark ? const Color(0xFFE1E5ED) : const Color(0xFF243044);
    final muted = dark ? const Color(0xFF929EAE) : const Color(0xFF69778C);
    final red = modifiedDifferenceBackground(
      dark ? Brightness.dark : Brightness.light,
    );
    final orange = dark ? const Color(0xFF725329) : const Color(0xFFFFE5B9);
    final rowPaint = Paint()
      ..color = dark ? const Color(0xFF202630) : const Color(0xFFF6F8FB);
    void draw(
      String value,
      double x,
      double y,
      Color color, {
      double fontSize = 13,
    }) {
      _glyphs
          .get(value, color, fontSize, layout.metrics.textScaler)
          .paint(canvas, Offset(x, y));
    }

    canvas.save();
    canvas.clipRect(Offset.zero & canvasSize);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, canvasSize.width, layout.metrics.headerHeight),
      rowPaint,
    );
    draw(
      offsetHeader,
      18 * layout.metrics.unitScale,
      7 * layout.metrics.unitScale,
      muted,
      fontSize: 11,
    );
    for (var c = 0; c < layout.columns; c++) {
      draw(
        c.toRadixString(16).padLeft(2, '0').toUpperCase(),
        layout.x(c),
        7 * layout.metrics.unitScale,
        muted,
        fontSize: 11,
      );
    }
    draw(
      asciiHeader,
      layout.asciiStart,
      7 * layout.metrics.unitScale,
      muted,
      fontSize: 11,
    );
    if (hasFile && !invalid) {
      final rows =
          ((canvasSize.height - layout.metrics.headerHeight) /
                  layout.metrics.rowHeight)
              .ceil();
      for (var row = 0; row < rows; row++) {
        final address = offset + row * layout.columns;
        if (address >= totalSize) break;
        final y = layout.metrics.headerHeight + row * layout.metrics.rowHeight;
        if (row.isOdd) {
          canvas.drawRect(
            Rect.fromLTWH(0, y, canvasSize.width, layout.metrics.rowHeight),
            rowPaint,
          );
        }
        draw(
          address.toRadixString(16).padLeft(layout.digits, '0').toUpperCase(),
          18 * layout.metrics.unitScale,
          y + 4 * layout.metrics.unitScale,
          muted,
        );
        for (var col = 0; col < layout.columns; col++) {
          final index = row * layout.columns + col;
          final at = offset + index;
          if (at >= totalSize) break;
          final value = index < bytes.length ? bytes[index] : null;
          final peer = index < other.length ? other[index] : null;
          final x = layout.x(col);
          if (!loading && hasOther) {
            final kind = isLeft
                ? difference(value, peer)
                : difference(peer, value);
            if (kind != ByteDifference.equal) {
              final color = kind == ByteDifference.modified ? red : orange;
              canvas.drawRRect(
                RRect.fromRectAndRadius(
                  Rect.fromLTWH(
                    x - layout.metrics.unitScale,
                    y + 2 * layout.metrics.unitScale,
                    layout.cell - 2 * layout.metrics.unitScale,
                    layout.metrics.rowHeight - 4 * layout.metrics.unitScale,
                  ),
                  Radius.circular(3 * layout.metrics.unitScale),
                ),
                Paint()..color = color,
              );
              canvas.drawRect(
                Rect.fromLTWH(
                  layout.asciiStart +
                      col * layout.metrics.glyphWidth -
                      layout.metrics.unitScale,
                  y + 2 * layout.metrics.unitScale,
                  layout.metrics.glyphWidth,
                  layout.metrics.rowHeight - 4 * layout.metrics.unitScale,
                ),
                Paint()..color = color,
              );
            }
          }
          final hex = loading
              ? '··'
              : value == null
              ? '--'
              : value.toRadixString(16).padLeft(2, '0').toUpperCase();
          draw(
            hex,
            x,
            y + 4 * layout.metrics.unitScale,
            value == null || loading ? muted : foreground,
          );
          final ascii = loading
              ? '·'
              : value == null
              ? ' '
              : value >= 32 && value <= 126
              ? String.fromCharCode(value)
              : '.';
          draw(
            ascii,
            layout.asciiStart + col * layout.metrics.glyphWidth,
            y + 4 * layout.metrics.unitScale,
            foreground,
          );
          if (edited.contains(at) && value != null) {
            canvas.drawLine(
              Offset(
                x,
                y + layout.metrics.rowHeight - 3 * layout.metrics.unitScale,
              ),
              Offset(
                x + layout.cell - 4 * layout.metrics.unitScale,
                y + layout.metrics.rowHeight - 3 * layout.metrics.unitScale,
              ),
              Paint()
                ..color = const Color(0xFF4D8DEF)
                ..strokeWidth = 2 * layout.metrics.unitScale,
            );
          }
          if (selected == at && value != null && !loading) {
            canvas.drawRRect(
              RRect.fromRectAndRadius(
                Rect.fromLTWH(
                  x - 2 * layout.metrics.unitScale,
                  y + layout.metrics.unitScale,
                  layout.cell,
                  layout.metrics.rowHeight - 2 * layout.metrics.unitScale,
                ),
                Radius.circular(3 * layout.metrics.unitScale),
              ),
              Paint()
                ..color = const Color(0xFF4D8DEF)
                ..style = PaintingStyle.stroke
                ..strokeWidth = 2 * layout.metrics.unitScale,
            );
          }
        }
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant HexPainter old) =>
      old.bytes != bytes ||
      old.other != other ||
      old.offset != offset ||
      old.layout.columns != layout.columns ||
      old.layout.digits != layout.digits ||
      old.layout.metrics.glyphWidth != layout.metrics.glyphWidth ||
      old.layout.metrics.glyphHeight != layout.metrics.glyphHeight ||
      old.layout.metrics.rowHeight != layout.metrics.rowHeight ||
      old.layout.metrics.headerHeight != layout.metrics.headerHeight ||
      old.selected != selected ||
      old.edited != edited ||
      old.dark != dark ||
      old.loading != loading ||
      old.invalid != invalid ||
      old.hasFile != hasFile ||
      old.hasOther != hasOther ||
      old.totalSize != totalSize ||
      old.offsetHeader != offsetHeader ||
      old.asciiHeader != asciiHeader;
}

/// Bounded cache shared by both panes. Repeated HEX/ASCII glyphs are laid out
/// once, while old address labels are evicted during long scroll sessions.
final _glyphs = _GlyphCache();

class _GlyphCache {
  final _entries = <(String, Color, double, TextScaler), TextPainter>{};
  TextPainter get(
    String text,
    Color color,
    double size,
    TextScaler textScaler,
  ) {
    final key = (text, color, size, textScaler);
    var painter = _entries.remove(key);
    painter ??= TextPainter(
      textDirection: TextDirection.ltr,
      textScaler: textScaler,
      text: TextSpan(
        text: text,
        style: TextStyle(fontFamily: 'monospace', fontSize: size, color: color),
      ),
    )..layout();
    _entries[key] = painter;
    if (_entries.length > 2048) {
      _entries.remove(_entries.keys.first)!.dispose();
    }
    return painter;
  }
}
