import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mushagaeshi_bin_diff/core/comparison.dart';

Uint8List b(List<int> values) => Uint8List.fromList(values);

void main() {
  test('counts positions once and joins runs across blocks', () {
    final count = DiffAccumulator();
    count.add(b([1, 2, 3]), b([1, 9, 9]), 0);
    count.add(b([4, 5]), b([9, 5]), 3);
    count.add(b([]), b([6, 7]), 5);
    expect(count.bytes, 5);
    expect(count.runs, 2);
    expect(count.first, 1);
  });
  test('empty, identical, and one-sided files', () {
    final empty = DiffAccumulator()..add(b([]), b([]), 0);
    expect(empty.bytes, 0);
    expect(empty.runs, 0);
    final same = DiffAccumulator()..add(b([0, 255]), b([0, 255]), 0);
    expect(same.bytes, 0);
    final tail = DiffAccumulator()..add(b([0, 0]), b([]), 0);
    expect(tail.bytes, 2);
    expect(tail.runs, 1);
    expect(difference(0, null), ByteDifference.leftOnly);
    expect(difference(null, 0), ByteDifference.rightOnly);
  });
  test('insertion is compared at absolute offsets', () {
    final count = DiffAccumulator()
      ..add(b([0x10, 0x20, 0x30]), b([0x10, 0xff, 0x20, 0x30]), 0);
    expect(count.bytes, 3);
    expect(count.runs, 1);
  });
  test('dense alternating differences have exact counts', () {
    final count = DiffAccumulator()
      ..add(
        Uint8List(100000),
        Uint8List.fromList(List.generate(100000, (i) => i % 2)),
        0,
      );
    expect(count.bytes, 50000);
    expect(count.runs, 50000);
  });
  test('navigation skips current run, handles EOF and no wrap', () {
    const data = [false, true, true, false, true, true];
    int? navigate(int cursor, bool forward) {
      final nav = RunNavigator(cursor, forward);
      for (var i = 0; i < data.length; i++) {
        nav.add(data[i], i);
      }
      nav.finish(data.length);
      return nav.result;
    }

    expect(navigate(-1, true), 1);
    expect(navigate(1, true), 4);
    expect(navigate(2, true), 4);
    expect(navigate(5, true), null);
    expect(navigate(4, false), 1);
    expect(navigate(5, false), 1);
    expect(navigate(3, false), 1);
    expect(navigate(1, false), null);
    expect(navigate(6, false), 4);
  });
}
