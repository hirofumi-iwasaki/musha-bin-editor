// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:math' as math;
import 'dart:typed_data';

enum ByteDifference { equal, modified, leftOnly, rightOnly }

ByteDifference difference(int? left, int? right) {
  if (left == right) return ByteDifference.equal;
  if (left == null) return ByteDifference.rightOnly;
  if (right == null) return ByteDifference.leftOnly;
  return ByteDifference.modified;
}

/// Counts positions once, merging runs across I/O boundaries without storing
/// one object per difference. Memory use is independent of difference density.
class DiffAccumulator {
  int bytes = 0;
  int runs = 0;
  bool _previousDifferent = false;
  int? first;

  void add(Uint8List left, Uint8List right, int offset) {
    final length = math.max(left.length, right.length);
    for (var i = 0; i < length; i++) {
      final different =
          i >= left.length || i >= right.length || left[i] != right[i];
      if (different) {
        bytes++;
        first ??= offset + i;
        if (!_previousDifferent) runs++;
      }
      _previousDifferent = different;
    }
  }
}

/// Returns the run after/before the one containing the current position.
/// Input is streamed from offset zero, so previous navigation stays bounded.
class RunNavigator {
  RunNavigator(this.cursor, this.forward);
  final int cursor;
  final bool forward;
  bool _different = false;
  int? _start;
  int? _previous;
  int? result;
  bool done = false;

  void add(bool different, int offset) {
    if (done) return;
    if (different && !_different) {
      _start = offset;
      if (forward && offset > cursor) {
        result = offset;
        done = true;
      }
    }
    if (!different && _different) {
      if (!forward && _start! < cursor && offset <= cursor) _previous = _start;
    }
    if (!forward && offset >= cursor) {
      result = _previous;
      done = true;
    }
    _different = different;
  }

  void finish(int length) {
    add(false, length);
    if (!forward && !done) result = _previous;
    done = true;
  }
}
