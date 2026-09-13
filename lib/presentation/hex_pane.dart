// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../core/comparison.dart';

const hexRowHeight = 25.0;
const hexHeaderHeight = 30.0;

class HexLayout {
  HexLayout(this.columns, this.digits, this.width);
  final int columns;
  final int digits;
  final double width;
  double get hexStart => 18 + digits * 8.0 + 20;
  double get cell => 22;
  double x(int col) => hexStart + col * cell + (col ~/ 8) * 9;
  double get asciiStart => x(columns) + 12;
  double get requiredWidth => asciiStart + columns * 8 + 16;
  int? column(double xPosition) {
    for (var i = 0; i < columns; i++) {
      if (xPosition >= x(i) && xPosition < x(i) + cell) return i;
      if (xPosition >= asciiStart + i * 8 &&
          xPosition < asciiStart + (i + 1) * 8) {
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
    required this.onSelect,
    required this.onScroll,
    required this.focusNode,
  });
  final Uint8List bytes;
  final Uint8List other;
  final int offset, size, totalSize, columns;
  final bool isLeft, hasFile, hasOther, loading, invalid;
  final int? selected;
  final ValueChanged<int> onSelect;
  final ValueChanged<double> onScroll;
  final FocusNode focusNode;

  @override
  Widget build(BuildContext context) {
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
      selectedLabel =
          ' オフセット ${selected!.toRadixString(16)}, 値 ${bytes[i].toRadixString(16).padLeft(2, '0')}, ${d == null
              ? '未比較'
              : d == ByteDifference.equal
              ? '一致'
              : '差分あり'}';
    }
    return Semantics(
      label: '${isLeft ? '左' : '右'}の16進数表示。閲覧専用。$selectedLabel',
      focusable: true,
      child: Focus(
        focusNode: focusNode,
        child: Listener(
          onPointerSignal: (event) {},
          child: LayoutBuilder(
            builder: (context, bounds) {
              final layout = HexLayout(columns, digits, bounds.maxWidth);
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: math.max(bounds.maxWidth, layout.requiredWidth),
                  height: bounds.maxHeight,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapDown: (event) {
                      focusNode.requestFocus();
                      final col = layout.column(event.localPosition.dx);
                      final row =
                          ((event.localPosition.dy - hexHeaderHeight) /
                                  hexRowHeight)
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
                          dark: Theme.of(context).brightness == Brightness.dark,
                        ),
                        child: !hasFile
                            ? const Center(child: Text('ファイルを開いてください'))
                            : invalid
                            ? const Center(child: Text('読込エラー · 開き直してください'))
                            : size == 0 && !hasOther
                            ? const Center(child: Text('空のファイルです'))
                            : null,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
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
    required this.dark,
  });
  final Uint8List bytes, other;
  final int offset, size, totalSize;
  final HexLayout layout;
  final bool isLeft, hasFile, hasOther, loading, invalid, dark;
  final int? selected;

  @override
  void paint(Canvas canvas, Size canvasSize) {
    final foreground = dark ? const Color(0xFFE1E5ED) : const Color(0xFF243044);
    final muted = dark ? const Color(0xFF929EAE) : const Color(0xFF69778C);
    final red = dark ? const Color(0xFF743C48) : const Color(0xFFFFD9DD);
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
      _glyphs.get(value, color, fontSize).paint(canvas, Offset(x, y));
    }

    canvas.save();
    canvas.clipRect(Offset.zero & canvasSize);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, canvasSize.width, hexHeaderHeight),
      rowPaint,
    );
    draw('OFFSET', 18, 7, muted, fontSize: 11);
    for (var c = 0; c < layout.columns; c++) {
      draw(
        c.toRadixString(16).padLeft(2, '0').toUpperCase(),
        layout.x(c),
        7,
        muted,
        fontSize: 11,
      );
    }
    draw('ASCII', layout.asciiStart, 7, muted, fontSize: 11);
    if (hasFile && !invalid) {
      final rows = ((canvasSize.height - hexHeaderHeight) / hexRowHeight)
          .ceil();
      for (var row = 0; row < rows; row++) {
        final address = offset + row * layout.columns;
        if (address >= totalSize) break;
        final y = hexHeaderHeight + row * hexRowHeight;
        if (row.isOdd) {
          canvas.drawRect(
            Rect.fromLTWH(0, y, canvasSize.width, hexRowHeight),
            rowPaint,
          );
        }
        draw(
          address.toRadixString(16).padLeft(layout.digits, '0').toUpperCase(),
          18,
          y + 4,
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
                  Rect.fromLTWH(x - 1, y + 2, 20, 21),
                  const Radius.circular(3),
                ),
                Paint()..color = color,
              );
              canvas.drawRect(
                Rect.fromLTWH(layout.asciiStart + col * 8 - 1, y + 2, 8, 21),
                Paint()..color = color,
              );
            }
          }
          final hex = loading
              ? '··'
              : value == null
              ? '--'
              : value.toRadixString(16).padLeft(2, '0').toUpperCase();
          draw(hex, x, y + 4, value == null || loading ? muted : foreground);
          final ascii = loading
              ? '·'
              : value == null
              ? ' '
              : value >= 32 && value <= 126
              ? String.fromCharCode(value)
              : '.';
          draw(ascii, layout.asciiStart + col * 8, y + 4, foreground);
          if (selected == at && value != null && !loading) {
            canvas.drawRRect(
              RRect.fromRectAndRadius(
                Rect.fromLTWH(x - 2, y + 1, 22, 23),
                const Radius.circular(3),
              ),
              Paint()
                ..color = const Color(0xFF4D8DEF)
                ..style = PaintingStyle.stroke
                ..strokeWidth = 2,
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
      old.selected != selected ||
      old.dark != dark ||
      old.loading != loading ||
      old.invalid != invalid ||
      old.hasFile != hasFile ||
      old.hasOther != hasOther ||
      old.totalSize != totalSize;
}

/// Bounded cache shared by both panes. Repeated HEX/ASCII glyphs are laid out
/// once, while old address labels are evicted during long scroll sessions.
final _glyphs = _GlyphCache();

class _GlyphCache {
  final _entries = <(String, Color, double), TextPainter>{};
  TextPainter get(String text, Color color, double size) {
    final key = (text, color, size);
    var painter = _entries.remove(key);
    painter ??= TextPainter(
        textDirection: TextDirection.ltr,
        text: TextSpan(
          text: text,
          style: TextStyle(fontFamily: 'Menlo', fontSize: size, color: color),
        ),
      )..layout();
    _entries[key] = painter;
    if (_entries.length > 2048) {
      _entries.remove(_entries.keys.first)!.dispose();
    }
    return painter;
  }
}
