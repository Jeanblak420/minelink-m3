// ============================================================================
// MineLink — Targets Core  (v2.1, 2026-08-09)
// ----------------------------------------------------------------------------
// v2.1 follows the ANCHOR DECISION: `started_on` is null on a draft and set by
// `lock_target_cycle` to the 1st of the FOLLOWING month. One column, one
// meaning — the date the commitment runs from. Nothing downstream reconciles
// two dates.
//
// What that changes here, versus v2:
//   * A cycle with no `startedOn` has NOT STARTED. It reports no elapsed days,
//     no progress, no completion and no horizon outcomes. v2 fell back to
//     counting the daily series, which would have put a draft back to showing
//     "9 of 365 days" against targets nobody has committed to.
//   * Every horizon on an unstarted cycle is `pending`, never `short`.
//   * `cumulativeTo()` returns 0 before the cycle starts.
//   * A cycle locked but not yet begun (locked 15 Jan, starts 1 Feb) is a real
//     state and reads correctly: locked, 0 of 365, all six pending.
//
// CARRIED FROM v2:
//   1. `MlCycle.startedOn` (DateTime?) replaces `startedAt`.
//   2. Horizons and completion count CALENDAR days, not recorded days — the
//      cron closes on `started_on + 1 year` and the Dart must agree with it.
//   3. `cumulativeTo()` sums by date window, not list index, so a gap in the
//      record shifts nothing and `months` can carry history from before the
//      cycle.
//   4. `mlParseTons` -> `mlParseTargetTons` (deprecated shim kept).
//
// BREAKING (single consumer, both trivial):
//   - `startedAt` -> `startedOn`, and it is nullable
//   - `MlTargetsData` is no longer const — it memoises the day index
// ============================================================================

import 'package:flutter/foundation.dart';

// ===========================================================================
// Outcome bands
// ===========================================================================

/// How a target landed. [pending] means the checkpoint has not been reached
/// yet — it must never render like [short], or "not judged" reads as "failed".
enum MlTargetOutcome { surpassed, close, short, pending, none }

extension MlTargetOutcomeX on MlTargetOutcome {
  String get label {
    switch (this) {
      case MlTargetOutcome.surpassed:
        return 'SURPASSED';
      case MlTargetOutcome.close:
        return 'CLOSE';
      case MlTargetOutcome.short:
        return 'SHORT';
      case MlTargetOutcome.pending:
        return 'PENDING';
      case MlTargetOutcome.none:
        return 'NO TARGET';
    }
  }
}

/// Band boundaries in one place, so the two systems can never drift apart.
class MlTargetBands {
  const MlTargetBands._();

  static const double surpassed = 1.0;

  /// Within 10% — a near miss worth noting rather than explaining.
  static const double close = 0.9;

  static MlTargetOutcome classify({
    required double target,
    required double? actual,
  }) {
    if (target <= 0) return MlTargetOutcome.none;
    if (actual == null) return MlTargetOutcome.pending;
    final a = actual / target;
    if (a >= surpassed) return MlTargetOutcome.surpassed;
    if (a >= close) return MlTargetOutcome.close;
    return MlTargetOutcome.short;
  }
}

// ===========================================================================
// Short term — monthly targets
// ===========================================================================

@immutable
class MlMonthTarget {
  const MlMonthTarget({
    required this.year,
    required this.month,
    required this.daysInMonth,
    required this.daily,
    required this.target,
    this.trips = 0,
    this.waybillsDone = 0,
    this.waybillsOpen = 0,
  });

  final int year;

  /// 1–12.
  final int month;

  final int daysInMonth;

  /// One entry per calendar day recorded so far, zeros included. Empty for a
  /// planned month.
  final List<double> daily;

  /// Tons targeted. Zero means NOT SET, which is different from a target of
  /// zero and renders differently.
  final double target;

  final int trips;
  final int waybillsDone;
  final int waybillsOpen;

  static const List<String> monthNames = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  String get shortLabel => monthNames[(month - 1).clamp(0, 11)];
  String get label => '$shortLabel $year';

  /// Persistence key — '2026-08'.
  String get key => '$year-${month.toString().padLeft(2, '0')}';

  DateTime get firstDay => DateTime(year, month, 1);

  bool get hasActuals => daily.isNotEmpty;

  double get total => daily.fold<double>(0, (a, b) => a + b);

  int get activeDays => daily.where((d) => d > 0).length;

  double get avgPerActiveDay => activeDays == 0 ? 0 : total / activeDays;

  double get peak => daily.isEmpty ? 0 : daily.reduce((a, b) => a > b ? a : b);

  int get peakDay {
    if (daily.isEmpty) return 0;
    var best = 0;
    for (var i = 1; i < daily.length; i++) {
      if (daily[i] > daily[best]) best = i;
    }
    return best + 1;
  }

  double get attainment => target <= 0 ? 0 : total / target;

  MlTargetOutcome get outcome => MlTargetBands.classify(
        target: target,
        actual: hasActuals ? total : null,
      );

  bool get isPartial => daily.length < daysInMonth;

  double get projected => avgPerActiveDay * daysInMonth;

  int get daysAbovePace {
    if (target <= 0) return 0;
    final perDay = target / daysInMonth;
    return daily.where((d) => d >= perDay).length;
  }

  double get closedRatio {
    final all = waybillsDone + waybillsOpen;
    return all == 0 ? 0 : waybillsDone / all;
  }

  /// A target orders of magnitude from actual is a configuration fault, not a
  /// miss. Surfacing it beats drawing a chart nobody can read.
  bool get targetLooksWrong =>
      target > 0 && hasActuals && (attainment < 0.1 || attainment > 3.0);

  MlMonthTarget copyWith({double? target}) => MlMonthTarget(
        year: year,
        month: month,
        daysInMonth: daysInMonth,
        daily: daily,
        target: target ?? this.target,
        trips: trips,
        waybillsDone: waybillsDone,
        waybillsOpen: waybillsOpen,
      );
}

// ===========================================================================
// Long term — horizon cycles
// ===========================================================================

@immutable
class MlHorizon {
  const MlHorizon(this.key, this.days, this.name, this.description);

  final String key;
  final int days;
  final String name;
  final String description;
}

/// Persistence keys. Do not rename without a migration.
const List<MlHorizon> kMlHorizons = <MlHorizon>[
  MlHorizon('d7', 7, '7 days', 'FIRST WEEK'),
  MlHorizon('d14', 14, '14 days', 'FIRST FORTNIGHT'),
  MlHorizon('m1', 30, '1 month', '30 DAYS'),
  MlHorizon('m3', 90, '3 months', '90 DAYS'),
  MlHorizon('m6', 180, '6 months', '180 DAYS'),
  MlHorizon('m12', 365, '12 months', 'FULL CYCLE'),
];

enum MlCycleStatus { draft, locked, closed }

@immutable
class MlCycle {
  const MlCycle({
    required this.id,
    required this.label,
    required this.status,
    required this.targets,
    required this.draft,
    this.startedOn,
    this.lockedAt,
  });

  final String id;
  final String label;
  final MlCycleStatus status;

  /// Horizon key -> tons. What was committed.
  final Map<String, double> targets;

  /// What the user is editing before committing.
  final Map<String, double> draft;

  /// The date the commitment runs from — `target_cycles.started_on`.
  ///
  /// NULL ON A DRAFT. Set by `lock_target_cycle` to the 1st of the month after
  /// the lock, so the first horizons are never judged on tonnage that moved
  /// before anyone agreed to them.
  ///
  /// Everything measures from here: horizons, cumulative tonnage, the reopen
  /// date, the cron.
  final DateTime? startedOn;

  final DateTime? lockedAt;

  static const int cycleDays = 365;

  bool get isDraft => status == MlCycleStatus.draft;
  bool get isLocked => status == MlCycleStatus.locked;
  bool get isClosed => status == MlCycleStatus.closed;

  /// A locked cycle whose start month has not arrived yet is a real state:
  /// locked 15 Jan, starts 1 Feb. It reads as locked, 0 of 365, all pending.
  bool get hasStarted => startedOn != null;

  /// Matches `started_on + 1 year` in the guard and the close job.
  DateTime? get reopensOn => startedOn == null
      ? null
      : DateTime(startedOn!.year + 1, startedOn!.month, startedOn!.day);

  List<MlHorizon> get unsetHorizons =>
      kMlHorizons.where((z) => (draft[z.key] ?? 0) <= 0).toList();

  bool get canLock => isDraft && unsetHorizons.isEmpty;

  MlCycle copyWith({
    MlCycleStatus? status,
    Map<String, double>? targets,
    Map<String, double>? draft,
    DateTime? startedOn,
    DateTime? lockedAt,
  }) =>
      MlCycle(
        id: id,
        label: label,
        status: status ?? this.status,
        targets: targets ?? this.targets,
        draft: draft ?? this.draft,
        startedOn: startedOn ?? this.startedOn,
        lockedAt: lockedAt ?? this.lockedAt,
      );
}

/// A closed cycle. Actuals are as recorded at close, never recomputed.
@immutable
class MlArchivedCycle {
  const MlArchivedCycle({
    required this.id,
    required this.label,
    required this.targets,
    required this.actuals,
  });

  final String id;
  final String label;
  final Map<String, double> targets;
  final Map<String, double> actuals;

  MlTargetOutcome outcomeFor(MlHorizon z) => MlTargetBands.classify(
        target: targets[z.key] ?? 0,
        actual: actuals[z.key],
      );

  int get surpassedCount => kMlHorizons
      .where((z) => outcomeFor(z) == MlTargetOutcome.surpassed)
      .length;
}

// ===========================================================================
// Aggregate
// ===========================================================================

@immutable
class MlTargetsData {
  MlTargetsData({
    required this.months,
    required this.cycle,
    this.pastCycles = const <MlArchivedCycle>[],
    DateTime? asOf,
  }) : asOf = asOf ?? DateTime.now();

  /// Oldest first. Carries FULL history — no longer trimmed to the cycle. Must
  /// still include planned future months, or there is nothing to plan against.
  final List<MlMonthTarget> months;

  final MlCycle cycle;
  final List<MlArchivedCycle> pastCycles;

  /// Injected so tests can sit on a boundary date.
  final DateTime asOf;

  // -- short term ----------------------------------------------------------

  late final int currentIndex = () {
    var k = 0;
    for (var i = 0; i < months.length; i++) {
      if (months[i].hasActuals) k = i;
    }
    return k;
  }();

  bool isPast(int i) => i < currentIndex;
  bool isPlanned(int i) => i > currentIndex;

  /// The single authority on whether a month may be edited.
  bool canEditMonth(int i) => i >= currentIndex;

  // -- the daily record ----------------------------------------------------

  late final List<double> dailySeries = () {
    final out = <double>[];
    for (final m in months) {
      if (m.hasActuals) out.addAll(m.daily);
    }
    return out;
  }();

  /// Date of each entry in [dailySeries] — same length, same order. Memoised
  /// because the painters walk it repeatedly.
  late final List<DateTime> dailyDates = () {
    final out = <DateTime>[];
    for (final m in months) {
      for (var k = 0; k < m.daily.length; k++) {
        out.add(DateTime(m.year, m.month, k + 1));
      }
    }
    return out;
  }();

  /// The month row for [asOf]'s calendar month, or null if the payload does
  /// not carry it.
  ///
  /// Deliberately NOT `months.last` and NOT `months[currentIndex]`.
  /// `months.last` is the furthest PLANNED month — six ahead by default — so a
  /// target set for next December would be reported as this month's. And
  /// `currentIndex` is the last month with recorded actuals, which is only the
  /// current month while tonnage has moved in it: on the 1st, or after a quiet
  /// spell, it is a previous month.
  late final MlMonthTarget? currentMonth = () {
    for (final m in months) {
      if (m.year == asOf.year && m.month == asOf.month) return m;
    }
    return null;
  }();

  /// This month's target as tons per day, or null when no target is set for
  /// this month. Zero means NOT SET throughout this system, so it maps to null
  /// rather than to a pace of zero.
  ///
  /// Per day because every surface that draws it plots a DAILY series. Laying
  /// a month of tonnage on a daily axis pins the rule to the ceiling and
  /// flattens every real day into the floor — the fault already corrected once
  /// on the transporters overview.
  ///
  /// Divided by the month's own length, never a flat 30. A 28-day February and
  /// a 31-day March do not carry the same daily pace for the same monthly
  /// commitment, and two surfaces disagreeing on which divisor is right is how
  /// one figure ends up quoted two ways.
  double? get currentMonthDailyPace {
    final m = currentMonth;
    if (m == null || m.target <= 0) return null;
    final days = m.daysInMonth > 0 ? m.daysInMonth : 30;
    return m.target / days;
  }

  // -- long term -----------------------------------------------------------

  DateTime get _today => DateTime(asOf.year, asOf.month, asOf.day);

  DateTime? get _start {
    final s = cycle.startedOn;
    return s == null ? null : DateTime(s.year, s.month, s.day);
  }

  /// True once the cycle has a start date AND that date has arrived.
  bool get cycleRunning {
    final s = _start;
    return s != null && !_today.isBefore(s);
  }

  /// Calendar days since the cycle began — 0 before it starts.
  ///
  /// NOT the number of recorded days: a checkpoint arrives on a date whether
  /// or not a truck moved, and the cron closes on `started_on + 1 year`. An
  /// unstarted cycle reports 0 rather than falling back to the record, so a
  /// draft never shows progress against targets nobody has committed to.
  late final int elapsedCycleDays = () {
    final s = _start;
    if (s == null) return 0;
    final d = _today.difference(s).inDays;
    return d < 0 ? 0 : d;
  }();

  double get cycleProgress =>
      (elapsedCycleDays / MlCycle.cycleDays).clamp(0.0, 1.0);

  /// Both of these read [MlCycle.reopensOn] rather than counting to a flat 365.
  ///
  /// The server reopens on `started_on + interval '1 year'` — a CALENDAR year,
  /// which is 366 days across a 29 February. Counting to 365 would call a
  /// leap-spanning cycle complete a day early: the banner would offer a new
  /// cycle and `start_new_target_cycle` would refuse it, with nothing on screen
  /// to say which was lying. `reopensOn` is the same calendar arithmetic, so
  /// there is one boundary rather than two that must agree.
  bool get cycleComplete {
    final reopens = cycle.reopensOn;
    return reopens != null && !_today.isBefore(reopens);
  }

  int get daysUntilCycleReopens {
    final reopens = cycle.reopensOn;
    // An unstarted cycle has its whole term still to run.
    if (reopens == null) return MlCycle.cycleDays;
    final left = reopens.difference(_today).inDays;
    return left < 0 ? 0 : left;
  }

  /// Tonnage between the cycle start and [days] after it. Zero before the
  /// cycle starts. Summed by date window, not list index, so a gap in the
  /// record shifts nothing and months recorded before the start are excluded.
  double cumulativeTo(int days) {
    final start = _start;
    if (start == null) return 0;
    final cutoff = start.add(Duration(days: days));
    var t = 0.0;
    for (var i = 0; i < dailySeries.length; i++) {
      final d = dailyDates[i];
      if (d.isBefore(start)) continue;
      if (!d.isBefore(cutoff)) break;
      t += dailySeries[i];
    }
    return t;
  }

  /// A checkpoint on a cycle that has not started has not been reached.
  bool horizonReached(MlHorizon z) =>
      cycle.hasStarted && elapsedCycleDays >= z.days;

  double? horizonActual(MlHorizon z) =>
      horizonReached(z) ? cumulativeTo(z.days) : null;

  double horizonTarget(MlHorizon z) =>
      (cycle.isDraft ? cycle.draft[z.key] : cycle.targets[z.key]) ?? 0;

  MlTargetOutcome horizonOutcome(MlHorizon z) => MlTargetBands.classify(
        target: cycle.targets[z.key] ?? 0,
        actual: horizonActual(z),
      );

  /// Client-side half of the long-term lock. The Postgres trigger is the half
  /// that actually holds.
  bool get canEditCycle => cycle.isDraft;

  MlTargetsData copyWith({
    List<MlMonthTarget>? months,
    MlCycle? cycle,
    List<MlArchivedCycle>? pastCycles,
    DateTime? asOf,
  }) =>
      MlTargetsData(
        months: months ?? this.months,
        cycle: cycle ?? this.cycle,
        pastCycles: pastCycles ?? this.pastCycles,
        asOf: asOf ?? this.asOf,
      );
}


// ===========================================================================
// Formatting
// ===========================================================================

/// Thousands-separated, decimal only where it carries information.
String mlTons(double v, {int decimals = 1}) {
  final whole = v.truncate();
  final frac = (v - whole).abs();
  final s = whole.abs().toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
    buf.write(s[i]);
  }
  final sign = v < 0 ? '-' : '';
  if (frac < 0.05 || decimals == 0) return '$sign$buf';
  return '$sign$buf.${(frac * 10).round().clamp(0, 9)}';
}

/// Parses what a person types — '28,100', ' 410 ', '410t'.
///
/// RENAMED from `mlParseTons` to end the collision with the screens-core
/// version that returns 0 on failure. Null and zero mean different things
/// here: null is "couldn't read that", zero is "not set". The import hide in
/// targets_workspace.dart can come out.
double? mlParseTargetTons(String raw) {
  final cleaned =
      raw.replaceAll(',', '').replaceAll(RegExp(r'[^0-9.\-]'), '').trim();
  if (cleaned.isEmpty) return null;
  final v = double.tryParse(cleaned);
  if (v == null || v < 0) return null;
  return v;
}

@Deprecated('Renamed to mlParseTargetTons to avoid the screens-core collision')
double? mlParseTons(String raw) => mlParseTargetTons(raw);
