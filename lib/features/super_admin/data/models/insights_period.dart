/// The windows the leaderboard's period control can be set to.
///
/// One place owns what each chip means, because the whole point of the control
/// is that every column moves together. The board re-queries
/// `super_admin_monthly_insights_bundle` with the window below rather than
/// re-deriving anything client-side — that RPC was already range-parameterised
/// (the repository simply always passed the current month), so the board's
/// tons, trips, waybills and on-time counts come back scoped by exactly the
/// same SQL the overview screen reads. Two screens cannot disagree about the
/// same month if neither of them does its own arithmetic.
///
/// [monthToDate] deliberately ends at the end of the current month rather than
/// at "now": that is the window the transporters overview already uses, and no
/// trip is dated in the future, so the figures are identical while staying
/// literally comparable with that screen.
library;

import 'package:flutter_application_1/core/time/ml_time.dart';

enum InsightsPeriod {
  monthToDate('MTD', 'month to date'),
  lastMonth('Last month', 'last month'),
  quarterToDate('Quarter', 'quarter to date'),
  yearToDate('YTD', 'year to date');

  const InsightsPeriod(this.chipLabel, this.phrase);

  /// Text on the segmented control.
  final String chipLabel;

  /// Reads as part of the board subtitle: "… ranked by tonnage moved · {phrase}".
  final String phrase;

  /// Inclusive window, on the South African clock, matching the repository's
/// month window. It was the device's local time, so two admins whose laptops
/// were set differently asked for different months and read different totals
/// off the same database.
  ({DateTime start, DateTime end}) window([DateTime? now]) {
    final today = now ?? MlTime.now();
    final thisMonth = DateTime(today.year, today.month);
    // One millisecond before the next boundary — the RPC filters `<=`.
    DateTime endOf(DateTime monthStart) =>
        DateTime(monthStart.year, monthStart.month + 1)
            .subtract(const Duration(milliseconds: 1));

    switch (this) {
      case InsightsPeriod.monthToDate:
        return (start: thisMonth, end: endOf(thisMonth));
      case InsightsPeriod.lastMonth:
        final prev = DateTime(today.year, today.month - 1);
        return (start: prev, end: endOf(prev));
      case InsightsPeriod.quarterToDate:
        final firstMonthOfQuarter = ((today.month - 1) ~/ 3) * 3 + 1;
        return (
          start: DateTime(today.year, firstMonthOfQuarter),
          end: endOf(thisMonth),
        );
      case InsightsPeriod.yearToDate:
        return (start: DateTime(today.year), end: endOf(thisMonth));
    }
  }

  /// "Aug 2026", "Jul 2026", "Q3 2026", "2026" — the period named in the
  /// subtitle so the reader can never mistake which window they are looking at.
  String periodLabel([DateTime? now]) {
    final today = now ?? MlTime.now();
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    switch (this) {
      case InsightsPeriod.monthToDate:
        return '${months[today.month - 1]} ${today.year}';
      case InsightsPeriod.lastMonth:
        final prev = DateTime(today.year, today.month - 1);
        return '${months[prev.month - 1]} ${prev.year}';
      case InsightsPeriod.quarterToDate:
        return 'Q${((today.month - 1) ~/ 3) + 1} ${today.year}';
      case InsightsPeriod.yearToDate:
        return '${today.year}';
    }
  }

  /// The window immediately before this one, for the "vs." delta column. A
  /// quarter is compared with the previous quarter, a year with the previous
  /// year — comparing a year against last month would be meaningless.
  ({DateTime start, DateTime end}) previousWindow([DateTime? now]) {
    final today = now ?? MlTime.now();
    switch (this) {
      case InsightsPeriod.monthToDate:
        return InsightsPeriod.lastMonth.window(today);
      case InsightsPeriod.lastMonth:
        return InsightsPeriod.lastMonth
            .window(DateTime(today.year, today.month - 1, 1, 12));
      case InsightsPeriod.quarterToDate:
        final firstMonthOfQuarter = ((today.month - 1) ~/ 3) * 3 + 1;
        final prevQuarterEndMonth = DateTime(today.year, firstMonthOfQuarter - 1);
        return (
          start: DateTime(prevQuarterEndMonth.year, prevQuarterEndMonth.month - 2),
          end: DateTime(prevQuarterEndMonth.year, prevQuarterEndMonth.month + 1)
              .subtract(const Duration(milliseconds: 1)),
        );
      case InsightsPeriod.yearToDate:
        return (
          start: DateTime(today.year - 1),
          end: DateTime(today.year).subtract(const Duration(milliseconds: 1)),
        );
    }
  }

  /// "vs. Jul", "vs. Q2", "vs. 2025" — names the comparison the delta is against.
  String previousLabel([DateTime? now]) {
    final today = now ?? MlTime.now();
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    switch (this) {
      case InsightsPeriod.monthToDate:
        return months[DateTime(today.year, today.month - 1).month - 1];
      case InsightsPeriod.lastMonth:
        return months[DateTime(today.year, today.month - 2).month - 1];
      case InsightsPeriod.quarterToDate:
        final q = ((today.month - 1) ~/ 3) + 1;
        return q == 1 ? 'Q4' : 'Q${q - 1}';
      case InsightsPeriod.yearToDate:
        return '${today.year - 1}';
    }
  }
}
