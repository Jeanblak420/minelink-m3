// The driver's week chart drew tonnage on a day that had not happened yet.
//
// Found on the emulator, 2026-08-22 — a SATURDAY. The "Tons delivered / This
// week" chart showed bars on Mon, Sat AND SUN. Sunday was tomorrow.
//
// The data settles it. Four deliveries make up this driver's 136.3 t week:
//
//   trip      net    UTC                     SAST
//   4c1995dd  33.7   Sun 16 Aug 23:29 UTC    Mon 17 Aug 01:29   <- the bug
//   90e0617c  33.7   Mon 17 Aug 06:55 UTC    Mon 17 Aug 08:55
//   02806e4f  34.7   Mon 17 Aug 13:51 UTC    Mon 17 Aug 15:51
//   927cbf1b  34.2   Sat 22 Aug 08:10 UTC    Sat 22 Aug 10:10
//
// The bucketing read `t.updatedAt.weekday` — the UTC weekday. SAST is two
// hours ahead, so a load delivered at 01:29 on Monday morning is still Sunday
// in UTC, and 33.7 t went onto the Sunday bar.
//
// WHAT MAKES THIS SHAPE WORTH A TEST OF ITS OWN: it survived a CORRECT filter
// on the lines either side of it. `inWeek` and `inPrevWeek` both used
// `MlTime.sast`, so the week TOTAL was right to the kilogram — 136.3 t, in
// agreement with the stat card directly above the chart — and only the
// distribution was wrong. Two numbers on one screen, both derived from the
// same list, one right and one wrong, with nothing to reconcile them against.
//
// 00:00–02:00 SAST is night shift. It is when this product runs.
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/core/time/ml_time.dart';
import 'package:flutter_application_1/features/portal/models/logistics_models.dart';
import 'package:flutter_application_1/features/portal/utils/driver_week.dart';

TripRecord _trip(String id, double tons, DateTime updatedAtUtc) => TripRecord(
  id: id,
  transactionId: 'txn-$id',
  status: 'completed',
  netTons: tons,
  updatedAt: updatedAtUtc,
);

/// Production, exactly as it stood. Stamps are the real UTC instants.
final _week = <TripRecord>[
  _trip('4c1995dd', 33.7, DateTime.utc(2026, 8, 16, 23, 29)), // Mon 01:29 SAST
  _trip('90e0617c', 33.7, DateTime.utc(2026, 8, 17, 6, 55)),
  _trip('02806e4f', 34.7, DateTime.utc(2026, 8, 17, 13, 51)),
  _trip('927cbf1b', 34.2, DateTime.utc(2026, 8, 22, 8, 10)),
];

/// Monday 17 Aug 2026, 00:00 SAST — the week containing Saturday the 22nd.
final _weekStart = DateTime(2026, 8, 17);

const _mon = 0, _sat = 5, _sun = 6;

void main() {
  test('a 01:29 Monday delivery lands on MONDAY, not the Sunday before', () {
    final byDay = tonsByWeekday(_week, weekStart: _weekStart);

    expect(
      byDay[_sun],
      0,
      reason: 'Sunday is TOMORROW; nothing can have been delivered on it',
    );
    expect(
      byDay[_mon],
      closeTo(102.1, 1e-9),
      reason: '33.7 + 33.7 + 34.7 — all three are Monday on the pit clock',
    );
    expect(byDay[_sat], closeTo(34.2, 1e-9));
  });

  test('the bars still add up to the week total the stat card shows', () {
    final byDay = tonsByWeekday(_week, weekStart: _weekStart);

    // 136.3 t is what the card above the chart reads, and it was ALREADY
    // right — the total was never the broken half. The chart has to agree
    // with it while also putting the tonnage on the right days.
    expect(byDay.fold<double>(0, (s, v) => s + v), closeTo(136.3, 1e-9));
  });

  test('the UTC answer is a different chart, which is the bug', () {
    // Stated rather than implied: this is what the old line computed. Keeping
    // it here means the test says what was wrong, not only what is right.
    final utc = List<double>.filled(7, 0);
    for (final t in _week) {
      utc[t.updatedAt.weekday - 1] += t.netTons ?? 0;
    }

    expect(utc[_sun], closeTo(33.7, 1e-9));
    expect(utc[_mon], closeTo(68.4, 1e-9));
    expect(utc, isNot(tonsByWeekday(_week, weekStart: _weekStart)));
  });

  test('a delivery before the week starts is not counted', () {
    final earlier = [
      _trip('old', 50, DateTime.utc(2026, 8, 14, 9, 0)), // Fri 14th
      ..._week,
    ];
    final byDay = tonsByWeekday(earlier, weekStart: _weekStart);

    expect(
      byDay.fold<double>(0, (s, v) => s + v),
      closeTo(136.3, 1e-9),
      reason: 'last week must not leak into this week\'s bars',
    );
  });

  test('the boundary itself: 00:00 SAST Monday is Monday', () {
    // 22:00 UTC Sunday IS 00:00 SAST Monday — the first instant of the week,
    // and the one the old code was guaranteed to get wrong.
    final t = _trip('edge', 10, DateTime.utc(2026, 8, 16, 22, 0));
    expect(MlTime.sast(t.updatedAt).weekday, DateTime.monday);

    final byDay = tonsByWeekday([t], weekStart: _weekStart);
    expect(byDay[_mon], 10);
    expect(byDay[_sun], 0);
  });
}
