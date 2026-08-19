// The printed waybill states the time on the clock at the mine, not UTC.
//
// Found 2026-08-17 by generating a real waybill and reading it. A load recorded
// at `loaded_at = 2026-08-17 05:51:31+00` printed **DATE 2026-08-17 / TIME
// 05:51** while the clock at the mine read **07:51 SAST**.
//
// `get_trip_waybill` returns UTC and `DateTime.tryParse` keeps `isUtc = true`,
// so `DateFormat('HH:mm').format(...)` rendered the UTC wall clock. The slip
// carries no zone marker, so there is nothing on the document to explain the
// gap — and it is the document a load controller hands to a driver standing in
// front of them, governing when the load left.
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/features/portal/services/trip_waybill_builder.dart';

void main() {
  group('waybillTimestamp', () {
    test('a UTC timestamp is converted to the reader\'s local time', () {
      final parsed = waybillTimestamp('2026-08-17 05:51:31.286212+00');
      expect(parsed, isNotNull);
      expect(parsed!.isUtc, isFalse,
          reason: 'a waybill prints local time — this is what was wrong');
      expect(
        parsed.toUtc(),
        DateTime.utc(2026, 8, 17, 5, 51, 31, 286, 212),
        reason: 'the instant must not move, only the frame it is read in',
      );
    });

    test('the offset form is respected, not ignored', () {
      // Same instant, written with an explicit +02:00 offset.
      final a = waybillTimestamp('2026-08-17 07:51:31+02:00');
      final b = waybillTimestamp('2026-08-17 05:51:31Z');
      expect(a, isNotNull);
      expect(b, isNotNull);
      expect(a!.toUtc(), b!.toUtc());
    });

    test('null in, null out — an unreceived load has no received time', () {
      expect(waybillTimestamp(null), isNull);
    });

    test('an unparseable value is null rather than a wrong time', () {
      expect(waybillTimestamp('not a timestamp'), isNull);
    });
  });
}
