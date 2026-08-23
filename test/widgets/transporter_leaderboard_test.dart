// The leaderboard board. The drop shipped it as a static mock: an On-time
// column reading 96/93/88, a "vs. JUL" header regardless of period, and a
// footnote claiming ranks were held "by registration date". These cover what
// replaced them, so a regression shows up here rather than as a confident
// wrong number in the console.
//
// Layout assertions load the REAL fonts — `flutter test` otherwise renders in a
// fallback face where every glyph is one em wide, which both invents overflows
// and hides real ones (CLAUDE.md §7).
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/features/portal/services/recon_exporter.dart';
import 'package:flutter_application_1/features/super_admin/data/models/company_monthly_ops_stats.dart';
import 'package:flutter_application_1/features/super_admin/data/models/insights_period.dart';
import 'package:flutter_application_1/features/super_admin/screens/transporter_leaderboard_screen.dart';
import 'package:flutter_application_1/features/super_admin/widgets/transporters_overview/leaderboard_board_body.dart';
import 'package:flutter_application_1/features/super_admin/widgets/transporters_overview/leaderboard_models.dart';
import 'package:flutter_application_1/core/design/tokens/ml_overview_tokens.dart';

Future<void> _loadFont(String family, List<String> files) async {
  final loader = FontLoader(family);
  var loaded = false;
  for (final f in files) {
    final file = File('assets/fonts/$f');
    if (!file.existsSync()) continue;
    loaded = true;
    loader.addFont(file.readAsBytes().then((b) => ByteData.sublistView(b)));
  }
  if (loaded) await loader.load();
}

void main() {
  final now = DateTime(2026, 8, 20, 12);

  setUpAll(() async {
    await _loadFont('PlusJakartaSans', [
      'PlusJakartaSans-Regular.ttf',
      'PlusJakartaSans-Medium.ttf',
      'PlusJakartaSans-SemiBold.ttf',
      'PlusJakartaSans-Bold.ttf',
    ]);
    await _loadFont('JetBrainsMono', [
      'JetBrainsMono-Regular.ttf',
      'JetBrainsMono-Medium.ttf',
      'JetBrainsMono-Bold.ttf',
    ]);
    await _loadFont('Fraunces', [
      'Fraunces-Medium.ttf',
      'Fraunces-SemiBold.ttf',
    ]);
  });

  CompanyMonthlyOpsStats company(
    String name, {
    double tons = 0,
    int trips = 0,
    int fleet = 0,
    int routes = 0,
    int open = 0,
    int onTime = 0,
    int due = 0,
  }) =>
      CompanyMonthlyOpsStats(
        companyId: name,
        companyName: name,
        orgType: 'transporter',
        fleetVehicles: fleet,
        drivers: 0,
        employees: 0,
        routesDistinct: routes,
        trips: trips,
        loadsCount: trips,
        tonsMoved: tons,
        completedWaybills: 0,
        pendingWaybills: open,
        onTimeTrips: onTime,
        dueTrips: due,
      );

  MonthlyInsightsBundle bundle(List<CompanyMonthlyOpsStats> companies) =>
      MonthlyInsightsBundle(
        companies: companies,
        aggregate: OrgTypeAggregateStats(
          orgType: 'transporter',
          companyCount: companies.length,
          activeTripsApprox: 0,
          fleetVehiclesTotal: companies.fold(0, (s, c) => s + c.fleetVehicles),
          tonsMoved: companies.fold<double>(0, (s, c) => s + c.tonsMoved),
          transactionsTotal: 0,
          completedWaybills: 0,
          pendingWaybills: 0,
        ),
      );

  OvLeaderboardBoard map(
    List<CompanyMonthlyOpsStats> companies, {
    List<CompanyMonthlyOpsStats>? previous,
    InsightsPeriod period = InsightsPeriod.monthToDate,
  }) =>
      TransporterLeaderboardMapper.build(
        bundle: bundle(companies),
        previous: previous == null ? null : bundle(previous),
        period: period,
        now: now,
      );

  final populated = [
    company('Roadhaul Logistics',
        tons: 12460.8, trips: 18, fleet: 42, routes: 9, open: 6,
        onTime: 17, due: 18),
    company('Trans African Haul',
        tons: 9580.0, trips: 14, fleet: 31, routes: 7, open: 9,
        onTime: 13, due: 14),
    company('Corridor Freight',
        tons: 6800.0, trips: 10, fleet: 23, routes: 5, open: 3,
        onTime: 9, due: 10),
    company('b man trans', fleet: 1),
    company('Land Rover', fleet: 1),
  ];

  group('on-time is reported, never invented', () {
    test('nothing judgeable reads as a dash in the muted tone, not 0%', () {
      // The whole point of carrying due_trips: 0-of-0 is "no measure", and it
      // must not look like a transporter that missed every delivery.
      final d = map([company('Quiet', tons: 100, trips: 4, due: 0)]);
      final row = d.rows.single;
      expect(row.onTime, '—');
      expect(row.onTimeTone, OvTone.muted);
      expect(row.onTimeTone, isNot(OvTone.bad));
    });

    test('every load late reads 0% in bad — the opposite statement', () {
      final d = map([company('Late', tons: 100, trips: 9, onTime: 0, due: 9)]);
      expect(d.rows.single.onTime, '0%');
      expect(d.rows.single.onTimeTone, OvTone.bad);
    });

    test('the tone ladder is 90 good / 85 warn / below bad', () {
      OvRankRow at(int onTime, int due) =>
          map([company('C', tons: 1, trips: due, onTime: onTime, due: due)])
              .rows
              .single;
      expect(at(90, 100).onTimeTone, OvTone.good);
      expect(at(89, 100).onTimeTone, OvTone.warn);
      expect(at(85, 100).onTimeTone, OvTone.warn);
      expect(at(84, 100).onTimeTone, OvTone.bad);
    });

    test('the footnote explains a dash only when one is on screen', () {
      final withDash = map([company('Quiet', tons: 5, trips: 1)]);
      expect(withDash.footnote, contains('nothing to measure'));

      final allJudged = map([
        company('Measured', tons: 5, trips: 2, onTime: 2, due: 2),
      ]);
      expect(allJudged.footnote, isNot(contains('nothing to measure')));
    });

    test('the footnote states how untied rows are ordered, truthfully', () {
      // The drop claimed "by registration date", which is not in the payload.
      final d = map(populated);
      expect(d.footnote, contains('alphabetically'));
      expect(d.footnote, isNot(contains('registration date')));
    });
  });

  group('ranking', () {
    test('movers rank by tonnage; the quiet are alphabetical behind them', () {
      final d = map(populated);
      expect(
        d.rows.map((r) => r.name),
        // Alphabetical is case-insensitive, so "b man trans" sorts before
        // "Land Rover" rather than after every capitalised name.
        ['Roadhaul Logistics', 'Trans African Haul', 'Corridor Freight',
         'b man trans', 'Land Rover'],
      );
      expect(d.rows.last.inactive, isTrue);
      expect(d.rows.first.inactive, isFalse);
    });

    test('the share bar is relative to the leader, not the share percent', () {
      // Using the share is the drop's listed mistake #4 — every bar comes out
      // short. 9,580 of 28,840.8 is 33.2% share but 0.769 of the leader.
      final d = map(populated);
      expect(d.rows[1].shareLabel, '33.2%');
      expect(d.rows[1].barFraction, closeTo(0.769, 0.001));
      expect(d.rows.first.barFraction, 1.0);
      expect(d.rows.last.barFraction, 0);
    });

    test('avg per trip is a dash when no trip ran', () {
      final d = map(populated);
      // 12,460.8 over 18 trips is 692.26…, rounded to one decimal.
      expect(d.rows.first.avgPerTrip, '692.3');
      expect(d.rows.last.avgPerTrip, '—');
    });

    test('meta names the fleet and says plainly when no route ran', () {
      final d = map(populated);
      expect(d.rows.first.meta, '42 fleet · 9 routes');
      expect(d.rows.last.meta, '1 fleet · no active route');
    });
  });

  group('the delta column', () {
    test('no prior period, or a prior of zero, is a dash — not a percentage',
        () {
      final noPrior = map(populated);
      expect(noPrior.rows.first.delta, '—');
      expect(noPrior.rows.first.deltaTone, OvTone.muted);

      final fromZero = map(
        [company('Roadhaul Logistics', tons: 100, trips: 2)],
        previous: [company('Roadhaul Logistics')],
      );
      expect(fromZero.rows.single.delta, '—',
          reason: 'growth from zero has no percentage to state');
    });

    test('up and down are signed and toned', () {
      final d = map(
        [
          company('Up', tons: 200, trips: 2),
          company('Down', tons: 50, trips: 1),
        ],
        previous: [
          company('Up', tons: 100, trips: 1),
          company('Down', tons: 100, trips: 2),
        ],
      );
      final byName = {for (final r in d.rows) r.name: r};
      expect(byName['Up']!.delta, '▲ 100.0%');
      expect(byName['Up']!.deltaTone, OvTone.good);
      expect(byName['Down']!.delta, '▼ 50.0%');
      // Amber, not red: docs/design-reference.md §4 reserves red for a fault;
      // a downward trend is a warning. It was OvTone.bad.
      expect(byName['Down']!.deltaTone, OvTone.warn);
    });

    test('no change is "unchanged" in the muted tone, not a green ▲ 0.0%', () {
      // The fixture carried the same tonnage both months, and the board drew
      // a rising green arrow on a figure that did not rise. Phase 3 pass,
      // 2026-08-23; the dashboard's stat cards already say "unchanged".
      final d = map(
        [company('Same', tons: 100, trips: 2)],
        previous: [company('Same', tons: 100, trips: 2)],
      );
      expect(d.rows.single.delta, 'unchanged');
      expect(d.rows.single.deltaTone, OvTone.muted);
      expect(d.rows.single.delta, isNot(contains('▲')));
      // The podium carries the same tone as the row — it used to have only
      // a boolean, so it painted the same "unchanged" green.
      expect(d.podium.single.delta, 'unchanged');
      expect(d.podium.single.deltaTone, OvTone.muted);
    });

    test('the column header follows the period, instead of always "vs. Jul"',
        () {
      expect(map(populated).deltaColumnLabel, 'vs. Jul');
      expect(
        map(populated, period: InsightsPeriod.quarterToDate).deltaColumnLabel,
        'vs. Q2',
      );
      expect(
        map(populated, period: InsightsPeriod.yearToDate).deltaColumnLabel,
        'vs. 2025',
      );
    });
  });

  group('KPIs and podium', () {
    test('the four tiles are all derived from the rows they sit above', () {
      final d = map(populated);
      final byLabel = {for (final k in d.kpis) k.label: k};
      expect(byLabel['Network tons']!.value, '28,840.8');
      expect(byLabel['Active haulers']!.value, '3');
      expect(byLabel['Active haulers']!.unit, ' of 5');
      // 28,840.8 over 3 active.
      expect(byLabel['Avg per active hauler']!.value, '9,613.6');
      // 12,460.8 − 9,580.0.
      expect(byLabel['Lead over #2']!.value, '2,880.8');
      expect(byLabel['Lead over #2']!.tone, OvTone.sky);
    });

    test('the podium seats only transporters that actually moved product', () {
      final d = map(populated);
      expect(d.podium.map((p) => p.rank), [1, 2, 3]);
      expect(d.podium.first.metaSuffix, '· 18 trips');
      expect(d.podium.first.shareLabel, '43.2% of network');

      // A period where nothing moved is not a race with three winners.
      final quiet = map([company('a', fleet: 2), company('b', fleet: 1)]);
      expect(quiet.podium, isEmpty);
      // Two transporters on zero: the lead genuinely is nothing, and 0.0 t is
      // the true statement — unlike the podium, which would be a fiction.
      expect(
        quiet.kpis.firstWhere((k) => k.label == 'Lead over #2').value,
        '0.0',
      );
      expect(
        quiet.kpis.firstWhere((k) => k.label == 'Avg per active hauler').value,
        '—',
        reason: 'no active hauler to average over',
      );
    });

    test('a single transporter has no lead over a #2 that does not exist', () {
      final d = map([company('Only', tons: 10, trips: 1)]);
      expect(d.kpis.firstWhere((k) => k.label == 'Lead over #2').value, '—');
      expect(d.kpis.firstWhere((k) => k.label == 'Lead over #2').unit, isNull);
    });
  });

  group('export', () {
    test('the file is the table — same rows, same figures, same order', () {
      final d = map(populated);
      final headers = TransporterLeaderboardMapper.exportHeaders(d);
      final rows = TransporterLeaderboardMapper.exportRows(d);

      expect(headers.length, 10);
      expect(headers.last, 'vs. Jul', reason: 'follows the period on screen');
      expect(rows.length, d.rows.length);
      expect(
        rows.map((r) => r[1]),
        d.rows.map((r) => r.name),
        reason: 'export order must be the ranking order',
      );
      // Row 1 verbatim from the board, including the dashes.
      expect(rows.first,
          ['1', 'Roadhaul Logistics', '42 fleet · 9 routes', '43.2%',
           '12,460.8', '18', '692.3', '94%', '6', '—']);
      expect(rows.last[7], '—', reason: 'unjudged on-time stays a dash');
    });

    test('the dash caveat is carried into the file, not left on screen', () {
      // A spreadsheet outlives the page it came from; a reader who never saw
      // the footnote must still be able to tell "—" from a bad score.
      final d = map(populated);
      final csv = ReconExporter.buildCsv(
        TransporterLeaderboardMapper.exportHeaders(d),
        TransporterLeaderboardMapper.exportRows(d),
        title: 'Transporter leaderboard',
        summary: {'Note': d.footnote},
        noTotalColumns: TransporterLeaderboardMapper.exportNoTotalColumns,
      );
      expect(csv, contains('nothing to measure'));
      expect(csv, contains('Roadhaul Logistics'));
    });

    test('quantities total; the per-trip average does not', () {
      // Summing three transporters' tons-per-trip produces a figure that means
      // nothing, and a TOTAL row is read as authoritative.
      final d = map(populated);
      final headers = TransporterLeaderboardMapper.exportHeaders(d);
      final csv = ReconExporter.buildCsv(
        headers,
        TransporterLeaderboardMapper.exportRows(d),
        title: 'Transporter leaderboard',
        noTotalColumns: TransporterLeaderboardMapper.exportNoTotalColumns,
      );
      final total = csv
          .trim()
          .split('\n')
          .last
          .split(',')
          .map((c) => c.replaceAll('"', '').trim())
          .toList();

      expect(total[0], 'TOTAL');
      expect(total[4], '28840.80', reason: 'tons is a real quantity');
      expect(total[5], '42.00', reason: '18 + 14 + 10 trips');
      expect(total[8], '18.00', reason: '6 + 9 + 3 open waybills');
      expect(total[6], '', reason: 'avg / trip must not be summed');
      expect(total[3], '', reason: 'a share column is not summable');
      expect(total[7], '', reason: 'nor is a percentage of on-time');
    });

    test('the opt-out is off by default, so existing exports are unchanged',
        () {
      // The recon tables pass no noTotalColumns and must keep totalling every
      // numeric column exactly as before.
      final csv = ReconExporter.buildCsv(
        ['A', 'Qty', 'Rate'],
        [
          ['x', '2', '1.5'],
          ['y', '3', '2.5'],
        ],
        title: 'unchanged',
      );
      final total = csv.trim().split('\n').last.split(',');
      expect(total[1], '5.00');
      expect(total[2], '4.00', reason: 'no opt-out given: still summed');
    });
  });

  // -------------------------------------------------------------------------

  group('the board renders what the mapper produces', () {
    Future<void> pump(
      WidgetTester tester,
      Size size, {
      required OvLeaderboardBoard data,
      double textScale = 1.0,
      Brightness brightness = Brightness.dark,
      VoidCallback? onBack,
    }) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(brightness: brightness),
          home: Scaffold(
            body: MediaQuery(
              data: MediaQueryData(
                size: size,
                textScaler: TextScaler.linear(textScale),
              ),
              child: OvLeaderboardBoardBody(
                data: data,
                onBack: onBack ?? () {},
                onExport: () {},
                onPeriodSelected: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('it builds at every console width and text scale',
        (tester) async {
      final data = map(populated);
      for (final w in [900.0, 1100.0, 1440.0, 1920.0, 2560.0]) {
        for (final scale in [0.85, 1.0, 1.3]) {
          await pump(tester, Size(w, 2400), data: data, textScale: scale);
          expect(
            tester.takeException(),
            isNull,
            reason: 'at ${w.toInt()}px, text scale $scale',
          );
        }
      }
    });

    testWidgets('the light console keeps it legible', (tester) async {
      await pump(
        tester,
        const Size(1600, 2400),
        data: map(populated),
        brightness: Brightness.light,
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Full ranking'), findsOneWidget);
    });

    testWidgets('the table scrolls sideways rather than squashing its columns',
        (tester) async {
      // The columns are fixed widths inside a 1000px floor. Below that the
      // table must scroll — squashing is the drop's listed failure.
      await pump(tester, const Size(900, 2400), data: map(populated));
      final scrollers = tester.widgetList<SingleChildScrollView>(
        find.byType(SingleChildScrollView),
      );
      expect(
        scrollers.any((s) => s.scrollDirection == Axis.horizontal),
        isTrue,
      );
    });

    testWidgets('the column geometry scales with the reader\'s text size',
        (tester) async {
      // A 108px TONS cell holds "12,460.8" at 13px, and cannot at 1.3 scale.
      // Header and body must move together, so measure the shared grid.
      double tableWidth(WidgetTester t) => t
          .widgetList<SizedBox>(find.descendant(
            of: find.byType(OvLeaderboardBoardBody),
            matching: find.byType(SizedBox),
          ))
          .map((s) => s.width ?? 0)
          .reduce((a, b) => a > b ? a : b);

      await pump(tester, const Size(1100, 2400), data: map(populated));
      final atOne = tableWidth(tester);
      await pump(
        tester,
        const Size(1100, 2400),
        data: map(populated),
        textScale: 1.3,
      );
      expect(tableWidth(tester), greaterThan(atOne));
    });

    testWidgets('Export is offered, reports the tap, and is absent when there '
        'is nothing behind it', (tester) async {
      var exports = 0;
      tester.view.physicalSize = const Size(1600, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      Future<void> pumpBoard({required bool wired}) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(brightness: Brightness.dark),
            home: Scaffold(
              body: OvLeaderboardBoardBody(
                data: map(populated),
                onBack: () {},
                onExport: wired ? () => exports++ : null,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
      }

      // Unwired, the control does not ship at all — a button that does nothing
      // is worse than no button.
      await pumpBoard(wired: false);
      expect(find.text('Export'), findsNothing);

      await pumpBoard(wired: true);
      expect(find.text('Export'), findsOneWidget);
      await tester.tap(find.text('Export'));
      await tester.pump();
      expect(exports, 1);
    });

    testWidgets('back is always offered, and reports the tap', (tester) async {
      var backs = 0;
      await pump(
        tester,
        const Size(1600, 2400),
        data: map(populated),
        onBack: () => backs++,
      );
      await tester.tap(find.text('Back to overview'));
      await tester.pump();
      expect(backs, 1);
    });

    testWidgets('an empty platform says so instead of drawing an empty podium',
        (tester) async {
      final empty = map(const <CompanyMonthlyOpsStats>[]);
      await pump(tester, const Size(1600, 2000), data: empty);
      expect(tester.takeException(), isNull);
      expect(find.text('No transporters are registered yet.'), findsOneWidget);
      // And none of the drop's baked-in figures survive anywhere.
      for (final ghost in ['28,840.8', '12,460.8', '96%', '43.2%']) {
        expect(find.text(ghost), findsNothing, reason: '$ghost is mock data');
      }
    });
  });
}
