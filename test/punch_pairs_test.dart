import 'package:flutter_test/flutter_test.dart';

import 'package:attendence/core/utils/punch_pairs.dart';

/// The report reads a day by the order of its scans, not by the clock. These
/// are the shapes that order can take, including the odd one that used to be
/// mistaken for an arrival.
void main() {
  test('no scans means no pairs', () {
    expect(PunchPairs.fromOrdered(const []), isEmpty);
  });

  test('one scan is the last check-out of the day', () {
    final pairs = PunchPairs.fromOrdered(const ['08:00']);

    expect(pairs, hasLength(1));
    expect(pairs.single.checkIn, isNull);
    expect(pairs.single.checkOut, '08:00');
  });

  test('two scans are one complete pair', () {
    final pairs = PunchPairs.fromOrdered(const ['08:00', '17:00']);

    expect(pairs, hasLength(1));
    expect(pairs.single.checkIn, '08:00');
    expect(pairs.single.checkOut, '17:00');
  });

  test('three scans pair the first two and end on the last check-out', () {
    final pairs = PunchPairs.fromOrdered(const ['08:00', '12:00', '17:00']);

    expect(pairs, hasLength(2));
    expect(pairs[0].checkIn, '08:00');
    expect(pairs[0].checkOut, '12:00');
    expect(pairs[1].checkIn, isNull);
    expect(pairs[1].checkOut, '17:00');
  });

  test('four scans are two complete pairs', () {
    final pairs = PunchPairs.fromOrdered(const [
      '08:00',
      '12:00',
      '13:00',
      '17:00',
    ]);

    expect(pairs, hasLength(2));
    expect(pairs[0].checkIn, '08:00');
    expect(pairs[0].checkOut, '12:00');
    expect(pairs[1].checkIn, '13:00');
    expect(pairs[1].checkOut, '17:00');
  });

  test('five scans leave the last check-out on its own again', () {
    final pairs = PunchPairs.fromOrdered(const [
      '08:00',
      '10:00',
      '10:15',
      '13:00',
      '17:00',
    ]);

    expect(pairs, hasLength(3));
    expect(pairs[0].checkIn, '08:00');
    expect(pairs[0].checkOut, '10:00');
    expect(pairs[1].checkIn, '10:15');
    expect(pairs[1].checkOut, '13:00');
    expect(pairs[2].checkIn, isNull);
    expect(pairs[2].checkOut, '17:00');
  });
}
