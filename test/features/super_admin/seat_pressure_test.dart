import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/features/super_admin/utils/seat_pressure.dart';

void main() {
  test('near: a fifth or less left, and always the last seat', () {
    expect(seatPressure(7, 10), SeatPressure.none);
    expect(seatPressure(8, 10), SeatPressure.near);
    expect(seatPressure(3, 5), SeatPressure.none);
    expect(seatPressure(4, 5), SeatPressure.near);
    expect(seatPressure(1, 2), SeatPressure.near);
    expect(seatPressure(0, 1), SeatPressure.near, reason: 'one seat, none used: one left');
  });

  test('full and over', () {
    expect(seatPressure(10, 10), SeatPressure.full);
    expect(seatPressure(11, 10), SeatPressure.over);
  });

  test('no limit set is never a warning', () {
    expect(seatPressure(5, 0), SeatPressure.none);
    expect(seatPressureLabel(5, 0), isNull);
  });

  test('the words', () {
    expect(seatPressureLabel(4, 5), '1 seat left');
    expect(seatPressureLabel(8, 10), '2 seats left');
    expect(seatPressureLabel(10, 10), 'All seats used');
    expect(seatPressureLabel(12, 10), '2 people over the limit');
    expect(seatPressureLabel(4, 10), isNull);
  });
}
