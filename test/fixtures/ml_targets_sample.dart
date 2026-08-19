// Sample/fixture data for the insights-v2 console widgets.
//
// S3-11 / S3-12 (P5-03, P1-26, P9 items), moved here 2026-08-13.
//
// These classes used to live in `lib/features/super_admin/widgets/insights_v2/`.
// Nothing in `lib/` referenced them any more — P9-03 had already removed the
// constructor DEFAULTS that let a caller omit an argument and silently render
// fabricated platform figures — but they still shipped inside the library, and
// they carried the last hardcoded `spark:` trend arrays in the tree
// (`[4, 6, 5, 7, 6, 8, 7, 9, 8, 10]` and two more), which is exactly what S3-12
// forbids.
//
// They are fixtures, not product data, and widget tests legitimately need
// fixtures — so they are MOVED rather than deleted. Deleting them, as S3-11's
// wording said, would have taken 5 test files' data with them and bought
// nothing: the defect was that invented figures shipped in the app, not that
// invented figures exist in a test.
//
// Carried across verbatim, so the extraction cannot have altered any value.

import 'package:flutter_application_1/features/super_admin/widgets/insights_v2/minelink_targets_core.dart';

// ===========================================================================
// Sample data — previews and widget tests only
// ===========================================================================

class MlTargetsSample {
  const MlTargetsSample._();

  /// [asOf] is pinned so the fixture's outcome mix does not drift with the
  /// wall clock. Against this date the horizons read 2 surpassed / 2 short /
  /// 1 close / 1 pending, and the eleven closed months read 6 / 2 / 3.
  static MlTargetsData build({DateTime? asOf}) => MlTargetsData(
        months: _months,
        cycle: _cycle,
        pastCycles: _archive,
        asOf: asOf ?? DateTime(2026, 8, 18),
      );

  /// A cycle drafted but never locked — no start date, all six horizons
  /// pending, no progress. Exercises the "not started yet" state.
  static MlTargetsData draftFixture({DateTime? asOf}) => MlTargetsData(
        months: _months,
        asOf: asOf ?? DateTime(2026, 8, 18),
        cycle: const MlCycle(
          id: 'draft:platform',
          label: 'Not started',
          status: MlCycleStatus.draft,
          targets: <String, double>{},
          draft: <String, double>{},
        ),
      );

  static const List<MlMonthTarget> _months = <MlMonthTarget>[
    MlMonthTarget(year: 2025, month: 9, daysInMonth: 30, target: 300,
      trips: 9, waybillsDone: 7, waybillsOpen: 2,
      daily: [0,0,42,0,0,38,0,0,0,55,0,0,0,0,47,0,0,0,0,0,36,0,0,0,0,29,0,0,0,0]),
    MlMonthTarget(year: 2025, month: 10, daysInMonth: 31, target: 320,
      trips: 11, waybillsDone: 9, waybillsOpen: 2,
      daily: [0,51,0,0,44,0,0,0,62,0,0,0,0,39,0,0,48,0,0,0,0,57,0,0,0,0,41,0,0,0,0]),
    MlMonthTarget(year: 2025, month: 11, daysInMonth: 30, target: 340,
      trips: 10, waybillsDone: 8, waybillsOpen: 3,
      daily: [0,0,58,0,0,0,46,0,0,63,0,0,0,0,52,0,0,0,71,0,0,0,0,44,0,0,0,0,38,0]),
    MlMonthTarget(year: 2025, month: 12, daysInMonth: 31, target: 280,
      trips: 7, waybillsDone: 6, waybillsOpen: 1,
      daily: [0,0,0,49,0,0,0,0,55,0,0,0,0,0,61,0,0,0,0,0,0,0,0,0,0,0,0,42,0,0,0]),
    MlMonthTarget(year: 2026, month: 1, daysInMonth: 31, target: 350,
      trips: 12, waybillsDone: 10, waybillsOpen: 2,
      daily: [0,0,0,0,47,0,0,59,0,0,0,66,0,0,0,0,53,0,0,71,0,0,0,0,48,0,0,0,0,39,0]),
    MlMonthTarget(year: 2026, month: 2, daysInMonth: 28, target: 350,
      trips: 11, waybillsDone: 9, waybillsOpen: 2,
      daily: [0,0,54,0,0,0,68,0,0,0,0,49,0,0,77,0,0,0,0,58,0,0,0,0,44,0,0,0]),
    MlMonthTarget(year: 2026, month: 3, daysInMonth: 31, target: 380,
      trips: 13, waybillsDone: 11, waybillsOpen: 2,
      daily: [0,62,0,0,0,71,0,0,0,0,58,0,0,84,0,0,0,0,66,0,0,0,49,0,0,0,0,55,0,0,0]),
    MlMonthTarget(year: 2026, month: 4, daysInMonth: 30, target: 380,
      trips: 12, waybillsDone: 10, waybillsOpen: 3,
      daily: [0,0,0,57,0,0,0,69,0,0,0,0,0,74,0,0,0,61,0,0,0,0,52,0,0,0,0,0,46,0]),
    MlMonthTarget(year: 2026, month: 5, daysInMonth: 31, target: 400,
      trips: 14, waybillsDone: 12, waybillsOpen: 2,
      daily: [0,0,66,0,0,0,0,78,0,0,0,59,0,0,0,0,88,0,0,0,64,0,0,0,0,0,51,0,0,0,0]),
    MlMonthTarget(year: 2026, month: 6, daysInMonth: 30, target: 400,
      trips: 13, waybillsDone: 11, waybillsOpen: 2,
      daily: [0,0,0,0,72,0,0,0,63,0,0,0,0,81,0,0,0,0,57,0,0,0,0,0,69,0,0,0,0,44]),
    MlMonthTarget(year: 2026, month: 7, daysInMonth: 31, target: 420,
      trips: 15, waybillsDone: 13, waybillsOpen: 2,
      daily: [0,0,58,0,0,0,0,0,74,0,0,0,66,0,0,0,0,91,0,0,0,0,0,62,0,0,0,0,0,0,0]),
    MlMonthTarget(year: 2026, month: 8, daysInMonth: 31, target: 28000,
      trips: 12, waybillsDone: 9, waybillsOpen: 3,
      daily: [0, 129, 0, 0, 0, 46, 0, 52, 0, 0, 38, 0, 0, 0, 0, 67.3, 0, 0]),
    MlMonthTarget(year: 2026, month: 9, daysInMonth: 30, target: 450, daily: []),
    MlMonthTarget(year: 2026, month: 10, daysInMonth: 31, target: 450, daily: []),
    MlMonthTarget(year: 2026, month: 11, daysInMonth: 30, target: 0, daily: []),
    MlMonthTarget(year: 2026, month: 12, daysInMonth: 31, target: 0, daily: []),
    MlMonthTarget(year: 2027, month: 1, daysInMonth: 31, target: 0, daily: []),
    MlMonthTarget(year: 2027, month: 2, daysInMonth: 28, target: 0, daily: []),
  ];

  /// Locked in Aug 2025, starting 1 Sep 2025 — the shape v2.1 produces.
  static final MlCycle _cycle = MlCycle(
    id: '2025-26',
    label: 'Sep 2025 → Aug 2026',
    status: MlCycleStatus.locked,
    startedOn: DateTime(2025, 9, 1),
    lockedAt: DateTime(2025, 8, 14),
    targets: const {'d7': 80, 'd14': 160, 'm1': 300, 'm3': 960, 'm6': 2050, 'm12': 4300},
    draft: const {'d7': 80, 'd14': 160, 'm1': 300, 'm3': 960, 'm6': 2050, 'm12': 4300},
  );

  static const List<MlArchivedCycle> _archive = <MlArchivedCycle>[
    MlArchivedCycle(
      id: '2024-25',
      label: 'Sep 2024 → Aug 2025',
      targets: {'d7': 60, 'd14': 120, 'm1': 230, 'm3': 700, 'm6': 1500, 'm12': 3100},
      actuals: {'d7': 71, 'd14': 118, 'm1': 242, 'm3': 688, 'm6': 1290, 'm12': 3260},
    ),
  ];
}
