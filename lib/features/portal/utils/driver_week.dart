import 'package:flutter_application_1/core/time/ml_time.dart';
import 'package:flutter_application_1/features/portal/models/logistics_models.dart';

/// Tonnage delivered per weekday, Monday first, for the driver's week chart.
///
/// ## Why this is a function and not four lines in a build method
///
/// It was four lines in a build method, and the middle one asked the wrong
/// clock:
///
///     byDay[t.updatedAt.weekday - 1] += t.netTons ?? 0;
///
/// `updatedAt` is the UTC instant. SAST is two hours ahead of it, so anything
/// delivered between 00:00 and 02:00 SAST still reads as YESTERDAY in UTC.
///
/// Measured on the emulator on 2026-08-22, a Saturday: trip `4c1995dd` was
/// delivered at **01:29 on Monday SAST — 23:29 on Sunday UTC** — so 33.7 t of
/// the driver's week was drawn on **Sunday, a day that had not happened yet**.
/// The chart read `Mon 68.4 · Sat 34.2 · Sun 33.7` where the truth is
/// `Mon 102.1 · Sat 34.2`.
///
/// What makes this shape worth pulling out is that it survived a CORRECT
/// filter sitting on the lines either side of it. `inWeek` and `inPrevWeek`
/// both used `MlTime.sast`, so the WEEK TOTAL was right to the kilogram —
/// 136.3 t, agreeing with the stat card above the chart — and only the
/// distribution across the days was wrong. There was nothing to notice unless
/// you looked at the bars and knew what day it was.
///
/// 00:00–02:00 SAST is night shift, which is exactly when this product runs.
List<double> tonsByWeekday(
  Iterable<TripRecord> delivered, {
  required DateTime weekStart,
}) {
  final byDay = List<double>.filled(7, 0);
  for (final t in delivered) {
    final day = MlTime.sast(t.updatedAt);
    if (day.isBefore(weekStart)) continue;
    byDay[day.weekday - 1] += t.netTons ?? 0;
  }
  return byDay;
}
