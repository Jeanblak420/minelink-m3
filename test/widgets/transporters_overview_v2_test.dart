// The transporters overview arrived as a static design mock — every headline
// figure ('29,240.5t', '+18%', 'Reliability 92%', 'Target 28.0k') was baked in.
// These cover the mapper that replaced them, so a regression shows up as a
// failing test rather than a plausible-looking wrong number in the console.
//
// Layout assertions load the REAL fonts. `flutter test` otherwise renders in a
// fallback face where every glyph is one em wide, which both invents overflows
// that do not exist and hides ones that do (CLAUDE.md §7).
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/features/portal/models/raw_recon_row.dart';
import 'package:flutter_application_1/features/super_admin/data/models/company_monthly_ops_stats.dart';
import 'package:flutter_application_1/features/super_admin/screens/transporters_overview_v2_screen.dart';
import 'package:flutter_application_1/features/super_admin/widgets/transporters_overview/charts.dart';
import 'package:flutter_application_1/features/super_admin/widgets/transporters_overview/fleet_distribution_card.dart';
import 'package:flutter_application_1/features/super_admin/widgets/transporters_overview/overview_models.dart';
import 'package:flutter_application_1/core/design/tokens/ml_overview_tokens.dart';
import 'package:flutter_application_1/features/super_admin/widgets/transporters_overview/tons_moved_card.dart';
import 'package:flutter_application_1/features/super_admin/widgets/transporters_overview/transporter_card.dart';
import 'package:flutter_application_1/features/super_admin/widgets/transporters_overview/transporters_overview_body.dart';

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
    int done = 0,
    int open = 0,
    int routes = 0,
    int loads = 0,
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
        loadsCount: loads == 0 ? trips : loads,
        tonsMoved: tons,
        completedWaybills: done,
        pendingWaybills: open,
      );

  MonthlyInsightsBundle bundle(
    List<CompanyMonthlyOpsStats> companies, {
    double? tons,
    int? fleetTotal,
    int done = 0,
    int open = 0,
  }) =>
      MonthlyInsightsBundle(
        companies: companies,
        aggregate: OrgTypeAggregateStats(
          orgType: 'transporter',
          companyCount: companies.length,
          activeTripsApprox: 0,
          fleetVehiclesTotal:
              fleetTotal ?? companies.fold(0, (s, c) => s + c.fleetVehicles),
          tonsMoved:
              tons ?? companies.fold<double>(0, (s, c) => s + c.tonsMoved),
          transactionsTotal: 0,
          completedWaybills: done,
          pendingWaybills: open,
        ),
      );

  RawReconRow row({
    required DateTime date,
    String transporter = 'Roadhaul',
    double? net,
    double? delivered,
    String? truck,
    String? status,
    String? pod,
    DateTime? tIn,
    DateTime? tOut,
  }) =>
      RawReconRow(
        tripId: '${date.millisecondsSinceEpoch}$transporter$truck',
        tripDate: date,
        timeIn: tIn,
        timeOut: tOut,
        transporterName: transporter,
        truckReg: truck,
        netMass: net,
        deliveredTons: delivered,
        tripStatus: status,
        podPhotoPath: pod,
      );

  OverviewData map({
    required MonthlyInsightsBundle b,
    List<RawReconRow> rows = const [],
    double? target,
  }) =>
      TransportersOverviewMapper.build(
        bundle: b,
        rows: rows,
        targetTons: target,
        now: now,
      );

  group('flagship figures', () {
    test('headline tonnage comes from the RPC, not the row sum', () {
      final d = map(
        b: bundle([company('Roadhaul', tons: 900)], tons: 1234.5),
        rows: [row(date: DateTime(2026, 8, 3), net: 10)],
      );
      expect(d.tons.value, '1,234');
      expect(d.tons.valueSuffix, '.5 t');
    });

    test('month-on-month delta is computed, and absent when there is no '
        'prior month to compare', () {
      final d = map(
        b: bundle([company('Roadhaul')]),
        rows: [
          row(date: DateTime(2026, 8, 2), net: 100),
          row(date: DateTime(2026, 8, 3), net: 100),
          row(date: DateTime(2026, 7, 2), net: 100),
        ],
      );
      // 200 this month vs 100 last -> +100%.
      expect(d.tons.delta?.label, '▲ 100.0%');
      expect(d.tons.delta?.tone, OvTone.good);
      expect(d.tons.deltaLine, '▲ 100 t vs. Jul');

      final noPrior = map(
        b: bundle([company('Roadhaul')]),
        rows: [row(date: DateTime(2026, 8, 2), net: 100)],
      );
      expect(noPrior.tons.delta, isNull);
      expect(noPrior.tons.deltaLine, isNull);
    });

    test('a month down on the last one reads down, not up', () {
      final d = map(
        b: bundle([company('Roadhaul')]),
        rows: [
          row(date: DateTime(2026, 8, 2), net: 50),
          row(date: DateTime(2026, 7, 2), net: 100),
        ],
      );
      expect(d.tons.delta?.label, '▼ 50.0%');
      expect(d.tons.delta?.tone, OvTone.warn);
      expect(d.tons.deltaLine, startsWith('▼'));
      expect(d.tons.deltaLineTone, OvTone.warn);
    });

    test('peak day and daily average track the real series', () {
      final d = map(
        b: bundle([company('Roadhaul')]),
        rows: [
          row(date: DateTime(2026, 8, 4), net: 50),
          row(date: DateTime(2026, 8, 9), net: 250),
          row(date: DateTime(2026, 8, 9), net: 50),
        ],
      );
      final peak = d.tons.metrics[0];
      expect(peak.value, '300');
      expect(peak.trailing, '· Aug 9');
      // 350 t over 20 elapsed days.
      expect(d.tons.metrics[1].value, '18');
    });

    test('waybill close-out is a share, and an em dash when there are none',
        () {
      final withWb = map(b: bundle([company('R')], done: 90, open: 10));
      final closed = withWb.tons.footer.last;
      expect(closed.label, 'Waybills closed');
      expect(closed.value, '90');
      expect(closed.suffix, '%');

      final none = map(b: bundle([company('R')]));
      expect(none.tons.footer.last.value, '—');
      expect(none.tons.footer.last.suffix, isNull);
    });

    test('the third metric reports movement, not a forecast', () {
      final d = map(
        b: bundle([company('Roadhaul', fleet: 10)], fleetTotal: 10),
        rows: [
          row(date: DateTime(2026, 8, 2), truck: 'AAA', net: 1),
          row(date: DateTime(2026, 8, 3), truck: 'BBB', net: 1),
        ],
      );
      final third = d.tons.metrics[2];
      expect(third.label, 'Trucks active');
      expect(third.value, '2');
      expect(third.trailing, '· of 10 on file');
    });

    test('an empty month renders zero, never a placeholder figure', () {
      final d = map(b: bundle(const []));
      expect(d.tons.value, '0');
      expect(d.tons.delta, isNull);
      expect(d.tons.deltaLine, isNull);
      expect(d.tons.calloutLabel, isNull);
      expect(d.tons.metrics[0].value, '—');
      expect(d.transporters, isEmpty);
      expect(d.fleet.slices, isEmpty);
      expect(d.leaderboard.entries, isEmpty);
      // The alert column always says something truthful.
      expect(d.alerts.single.tone, OvTone.good);
    });
  });

  group('the flagship chart', () {
    test('both series share one scale, so the comparison is comparable', () {
      final d = map(
        b: bundle([company('Roadhaul')]),
        rows: [
          row(date: DateTime(2026, 8, 1), net: 100),
          row(date: DateTime(2026, 7, 1), net: 200),
        ],
      );
      // Max across both is 200. 200 -> 0.12, 100 -> 0.51, 0 -> 0.90.
      expect(d.tons.compareSeries.first, closeTo(0.12, 0.001));
      expect(d.tons.series.first, closeTo(0.51, 0.001));
      expect(d.tons.series[1], closeTo(0.90, 0.001));
      // Everything stays inside the plot box.
      for (final y in [...d.tons.series, ...d.tons.compareSeries]) {
        expect(y, inInclusiveRange(0, 1));
      }
    });

    test('no target set draws no rule, no caption and no legend key', () {
      final d = map(b: bundle([company('Roadhaul', tons: 3200)]));
      expect(d.tons.targetY, isNull);
      expect(d.tons.targetLabel, isNull);
      expect(
        d.tons.legend.map((k) => k.label),
        isNot(contains('Target pace')),
      );
    });

    test('a month target is drawn as the daily pace it implies', () {
      // 5,000 t over August's 31 days is 161 t/day. Drawing 5,000 on a daily
      // axis is what flattened every real day into the floor in the drop.
      final d = map(
        b: bundle([company('Roadhaul')]),
        rows: [row(date: DateTime(2026, 8, 1), net: 100)],
        target: 5000,
      );
      expect(d.tons.targetLabel, 'Target 161 t/day');
      expect(d.tons.targetY, inInclusiveRange(0, 1));
      // The pace is above the busiest day here, so it is the scale's maximum
      // and sits at the top padding.
      expect(d.tons.targetY, closeTo(0.12, 0.001));
      // …and the day that actually moved 100 t is still legible, not pinned
      // to the floor: 100/161.29 of the range.
      expect(d.tons.series.first, closeTo(0.416, 0.005));
      expect(d.tons.legend.map((k) => k.label), contains('Target pace'));
    });

    test('a pace under the busiest day does not widen the scale', () {
      final d = map(
        b: bundle([company('Roadhaul')]),
        rows: [row(date: DateTime(2026, 8, 1), net: 620)],
        target: 3100, // 100 t/day
      );
      expect(d.tons.targetLabel, 'Target 100 t/day');
      // 620 is the max, so it holds the top and the rule sits below it.
      expect(d.tons.series.first, closeTo(0.12, 0.001));
      expect(d.tons.targetY!, greaterThan(d.tons.series.first));
    });

    test('markers land on every third day plus the newest', () {
      final d = map(b: bundle([company('Roadhaul')]));
      expect(d.tons.markerIndexes.first, 0);
      expect(d.tons.markerIndexes.last, 19, reason: '20 elapsed days of Aug');
      expect(d.tons.markerIndexes, containsAll(<int>[0, 3, 6, 9, 12, 15, 18]));
    });

    test('the axis is the real month, ending on Today', () {
      final d = map(b: bundle([company('Roadhaul')]));
      expect(d.tons.axisLabels.first.value, '01');
      expect(d.tons.axisLabels.first.key, 0);
      expect(d.tons.axisLabels.last.value, 'Today');
      expect(d.tons.axisLabels.last.key, 1.0);
    });
  });

  group('fleet distribution', () {
    test('counts distinct trucks that actually moved against fleet on file',
        () {
      final d = map(
        b: bundle([company('Roadhaul', fleet: 10)], fleetTotal: 10),
        rows: [
          row(date: DateTime(2026, 8, 2), truck: 'AAA', net: 1),
          row(date: DateTime(2026, 8, 3), truck: 'AAA', net: 1),
          row(date: DateTime(2026, 8, 4), truck: 'BBB', net: 1),
          // Last month's movement must not count toward this month.
          row(date: DateTime(2026, 7, 4), truck: 'CCC', net: 1),
        ],
      );
      expect(d.fleet.utilisedPercent, 20);
      expect(d.fleet.totalLabel, '10 total');
      expect(d.transporters.single.meters.first.percent, 20);
    });

    test('no fleet on file is 0%, not a divide-by-zero', () {
      final d = map(
        b: bundle([company('Roadhaul')], fleetTotal: 0),
        rows: [row(date: DateTime(2026, 8, 2), truck: 'AAA', net: 1)],
      );
      expect(d.fleet.utilisedPercent, 0);
    });

    test('past the palette the tail is collected, not dropped or recoloured',
        () {
      final d = map(
        b: bundle([
          for (var i = 0; i < 8; i++) company('Co $i', fleet: 10 - i),
        ]),
      );
      // Four named + one "Other" — never more slices than the design's five.
      expect(d.fleet.slices.length, 5);
      expect(d.fleet.slices.last.label, 'Other (4)');
      // And the tail keeps its trucks: 10+9+8+7 named, 6+5+4+3 collected.
      expect(d.fleet.slices.last.count, 18);
      expect(d.fleet.total, 52);
    });
  });

  group('leaderboard', () {
    test('bars are relative to the leader and shares are of the total', () {
      final d = map(
        b: bundle([
          company('Big', tons: 1000, trips: 4),
          company('Half', tons: 500, trips: 2),
          company('Parked', tons: 0, fleet: 3),
        ]),
      );
      expect(d.leaderboard.totalLabel, '1,500.0 t');
      expect(d.leaderboard.entries[0].barFraction, 1.0);
      expect(d.leaderboard.entries[0].share, '66.7%');
      expect(d.leaderboard.entries[1].barFraction, closeTo(0.5, 0.0001));
      expect(d.leaderboard.entries[1].share, '33.3%');
      // The zero row is the muted state: no fill, no emphasis.
      expect(d.leaderboard.entries[2].muted, isTrue);
      expect(d.leaderboard.entries[2].barFraction, 0);
      expect(d.leaderboard.entries[2].tons, '0.0 t');
    });
  });

  group('transporter cards', () {
    test('PoD coverage is measured, and absent when nothing was delivered',
        () {
      final d = map(
        b: bundle([company('Roadhaul', tons: 10, trips: 4)]),
        rows: [
          row(date: DateTime(2026, 8, 2), status: 'completed', pod: 'a.jpg'),
          row(date: DateTime(2026, 8, 3), status: 'completed', pod: 'b.jpg'),
          row(date: DateTime(2026, 8, 4), status: 'completed', pod: 'c.jpg'),
          row(date: DateTime(2026, 8, 5), status: 'completed'),
        ],
      );
      expect(d.transporters.single.badges.map((b) => b.label),
          contains('75% PoD'));

      final nothingDelivered = map(
        b: bundle([company('Roadhaul', tons: 10, trips: 1)]),
      );
      expect(
        nothingDelivered.transporters.single.badges.map((b) => b.label),
        isNot(anyElement(contains('PoD'))),
      );
    });

    test('the open-waybill ladder colours at 4 and 6', () {
      TransporterRow at(int open) => map(
            b: bundle([company('R', tons: 5, trips: 1, open: open)]),
          ).transporters.single;
      expect(at(3).openTone, OvTone.ink);
      expect(at(4).openTone, OvTone.warn);
      expect(at(6).openTone, OvTone.bad);
    });

    test('the second meter is waybill close-out, never an invented on-time %',
        () {
      final d = map(b: bundle([company('R', tons: 5, done: 8, open: 2)]));
      expect(d.transporters.single.meters[1].label, 'Waybills closed');
      expect(d.transporters.single.meters[1].percent, 80);
    });

    test('the tempo strip is always the 15-day window it is labelled', () {
      final d = map(b: bundle([company('Roadhaul')]));
      expect(d.transporters.single.tempo.length, 15);
    });
  });

  group('alerts are real conditions', () {
    test('weight variance, missing POD and open waybills each raise one', () {
      final d = map(
        b: bundle([company('Roadhaul', fleet: 2, trips: 1)], open: 3),
        rows: [
          // Variance: mine net vs delivered differ by > 0.5 t.
          row(date: DateTime(2026, 8, 2), net: 34.0, delivered: 30.0),
          // Completed with no POD.
          row(date: DateTime(2026, 8, 3), status: 'completed'),
        ],
      );
      final titles = d.alerts.map((a) => a.title).join(' | ');
      expect(titles, contains('Weight variance on 1 load'));
      expect(titles, contains('POD missing on 1 delivered load'));
      expect(titles, contains('3 waybills still open'));
    });

    test('a company with fleet but no trips is flagged idle', () {
      final d = map(b: bundle([company('Parked', fleet: 5)]));
      expect(d.alerts.map((a) => a.title), contains('Parked has run no trips'));
      expect(d.leaderboard.entries.single.muted, isTrue);
    });
  });

  test('movement tiles are all derived, none invented', () {
    final d = map(
      b: bundle([company('Roadhaul', fleet: 4, trips: 3, loads: 7)], open: 2),
      rows: [
        row(
          date: DateTime(2026, 8, 5),
          truck: 'AAA',
          net: 30,
          tIn: DateTime(2026, 8, 5, 8),
          tOut: DateTime(2026, 8, 5, 10),
        ),
      ],
    );
    final byLabel = {for (final s in d.trend.stats) s.label: s.value};
    expect(byLabel['Avg turnaround'], '2.0');
    expect(byLabel['Transporters'], '1');
    expect(byLabel['Loads'], '7');
    expect(byLabel['Weight variances'], '0');
    expect(byLabel['PODs missing'], '0');
    expect(byLabel['Fleet on file'], '4');
    // Six tiles, rendered two-up.
    expect(d.trend.stats.length, 6);
  });

  test('no prior month leaves the trend headline blank, not "+0%"', () {
    final d = map(b: bundle([company('Roadhaul')]));
    expect(d.trend.headline, isNull);
    expect(d.trend.caption, 'No prior month to compare against');
    expect(d.trend.series.length, 6);
  });

  // -------------------------------------------------------------------------

  group('the screen renders what the mapper produces', () {
    final populated = TransportersOverviewMapper.build(
      bundle: bundle(
        [
          company('Roadhaul Logistics',
              tons: 4210.4, trips: 40, fleet: 12, done: 88, open: 4, routes: 6),
          company('Fast Freight',
              tons: 1980.0, trips: 18, fleet: 7, done: 30, open: 2, routes: 3),
        ],
        done: 118,
        open: 6,
      ),
      rows: [
        row(date: DateTime(2026, 8, 4), truck: 'AAA', net: 34.2),
        row(date: DateTime(2026, 8, 9), truck: 'BBB', net: 31.8),
        row(date: DateTime(2026, 7, 9), truck: 'BBB', net: 28.0),
      ],
      now: now,
    );

    Future<void> pump(
      WidgetTester tester,
      Size size, {
      required OverviewData data,
      void Function(TransporterRow)? onOpen,
      double textScale = 1.0,
    }) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(brightness: Brightness.dark),
          home: Scaffold(
            body: MediaQuery(
              data: MediaQueryData(
                size: size,
                textScaler: TextScaler.linear(textScale),
              ),
              child: TransportersOverviewBody(
                data: data,
                onOpenWorkspace: onOpen,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('the two-column layout builds at every console width',
        (tester) async {
      for (final w in [1100.0, 1280.0, 1440.0, 1600.0, 1920.0, 2560.0]) {
        await pump(tester, Size(w, 2000), data: populated);
        expect(
          tester.takeException(),
          isNull,
          reason: 'overflowed at ${w.toInt()}px wide',
        );
      }

      await pump(tester, const Size(1600, 2000), data: populated);
      expect(find.text('TONS MOVED THIS PERIOD'), findsOneWidget);
      expect(find.text('FLEET DISTRIBUTION'), findsOneWidget);
      expect(find.text('Top transporters'), findsOneWidget);
      // Headline is the real RPC figure (6,190.4), with the decimal carried
      // in its own smaller span.
      expect(find.text('6,190  .4 t'), findsOneWidget);
      expect(find.text('Roadhaul Logistics'), findsWidgets);
    });

    testWidgets('the narrow layout stacks the aside without overflow',
        (tester) async {
      await pump(tester, const Size(860, 2600), data: populated);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the top row ends level at every console width and text scale',
        (tester) async {
      // The fleet card holds a header, a 160px donut and at most five legend
      // rows; the tons card holds a headline, a chart, three metrics and four
      // stat cells. Left to their natural heights they end ~95px apart, which
      // is what the ragged top row looked like before `equalHeight`.
      for (final w in [1100.0, 1280.0, 1440.0, 1600.0, 1920.0, 2560.0]) {
        for (final scale in [1.0, 1.3]) {
          await pump(tester, Size(w, 2400), data: populated, textScale: scale);
          final fleet = tester.getSize(find.byType(OvFleetDistributionCard));
          final tons = tester.getSize(find.byType(OvTonsMovedCard));
          final why = 'at ${w.toInt()}px, text scale $scale';
          expect(fleet.height, tons.height, reason: why);
          // Matched, not squashed: the taller card keeps its own height and is
          // never trimmed to fit the shorter one.
          expect(tons.height, greaterThan(300), reason: why);
          expect(tester.takeException(), isNull, reason: why);
        }
      }
    });

    testWidgets('the slack goes to the donut, not a dead band at the bottom',
        (tester) async {
      await pump(tester, const Size(1600, 2000), data: populated);
      final card = tester.getRect(find.byType(OvFleetDistributionCard));
      final donut = tester.getRect(find.byType(OvFleetDonut));
      // Slices are ordered by fleet size, so this is the last legend row.
      final lastLegend = tester.getRect(find.descendant(
        of: find.byType(OvFleetDistributionCard),
        matching: find.text('Fast Freight'),
      ));

      // The legend holds the bottom edge — one card padding beneath it, the
      // same as the top. Slack pooled under the last row is what makes a
      // stretched card look unfinished.
      expect(card.bottom - lastLegend.bottom, closeTo(24, 5));
      // The donut sits in the space above it, at full size: matched, not
      // scaled down to fill.
      expect(donut.height, 160);
      expect(donut.bottom, lessThan(lastLegend.top));
      expect(donut.top, greaterThan(card.top));
    });

    testWidgets('an empty fleet card still matches, and says why it is empty',
        (tester) async {
      // No slices is the shortest this card ever gets — the widest gap to
      // close, and the one most likely to overflow the donut if the slack is
      // mishandled.
      final empty = TransportersOverviewMapper.build(
        bundle: bundle(const []),
        rows: const [],
        now: now,
      );
      await pump(tester, const Size(1600, 2000), data: empty);
      expect(tester.takeException(), isNull);
      expect(find.text('No fleet on file for any transporter'), findsOneWidget);
      expect(
        tester.getSize(find.byType(OvFleetDistributionCard)).height,
        tester.getSize(find.byType(OvTonsMovedCard)).height,
      );
    });

    testWidgets('stacked, each card keeps its own height', (tester) async {
      // Once the row collapses to a column there is no neighbour to match, and
      // running the fleet card to the tons card's height would only stretch a
      // small card down a phone-width page.
      await pump(tester, const Size(640, 3200), data: populated);
      expect(tester.takeException(), isNull);
      expect(
        tester.getSize(find.byType(OvFleetDistributionCard)).height,
        lessThan(tester.getSize(find.byType(OvTonsMovedCard)).height),
      );
    });

    testWidgets('the light console keeps the screen legible', (tester) async {
      tester.view.physicalSize = const Size(1600, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(brightness: Brightness.light),
          home: Scaffold(body: TransportersOverviewBody(data: populated)),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Top transporters'), findsOneWidget);
    });

    testWidgets('each card opens that transporter\'s workspace',
        (tester) async {
      TransporterRow? opened;
      await pump(
        tester,
        const Size(1600, 2000),
        data: populated,
        onOpen: (r) => opened = r,
      );

      // The mapper carries the company id through so the button can route.
      expect(populated.transporters.first.id, 'Roadhaul Logistics');
      await tester.tap(find.text('Open workspace').first);
      await tester.pump();
      expect(opened, isNotNull);
      expect(opened!.id, isNotEmpty);
    });

    testWidgets('a company with no id shows no dead open button',
        (tester) async {
      // pump() with no onOpen: the action must not be offered at all.
      await pump(tester, const Size(1600, 2000), data: populated);
      expect(find.text('Open workspace'), findsNothing);
    });

    testWidgets('the filter chips filter for real', (tester) async {
      // Count cards, not names: the leaderboard lists the same companies in
      // the aside and would mask the filter doing nothing.
      Finder cardNamed(String name) => find.descendant(
            of: find.byType(OvTransporterCard),
            matching: find.text(name),
          );

      await pump(tester, const Size(1600, 2400), data: populated);
      expect(find.byType(OvTransporterCard), findsNWidgets(2));
      expect(cardNamed('Fast Freight'), findsOneWidget);

      // "High throughput" means above the mean of the set, so only the leader
      // survives it.
      await tester.tap(find.text('High throughput'));
      await tester.pumpAndSettle();
      expect(find.byType(OvTransporterCard), findsOneWidget);
      expect(cardNamed('Fast Freight'), findsNothing);
      expect(cardNamed('Roadhaul Logistics'), findsOneWidget);
    });

    testWidgets('a filter that matches nothing says why', (tester) async {
      final quiet = TransportersOverviewMapper.build(
        bundle: bundle([company('Parked', fleet: 3)]),
        rows: const [],
        now: now,
      );
      await pump(tester, const Size(1600, 2000), data: quiet);
      await tester.tap(find.text('Active'));
      await tester.pumpAndSettle();
      expect(find.text('No transporters match “Active”'), findsOneWidget);
    });

    testWidgets('an empty month renders blanks, not placeholder numbers',
        (tester) async {
      final empty = TransportersOverviewMapper.build(
        bundle: bundle(const []),
        rows: const [],
        now: now,
      );
      await pump(tester, const Size(1600, 2000), data: empty);
      expect(tester.takeException(), isNull);
      // None of the drop's baked-in mock figures may survive anywhere.
      for (final ghost in [
        '29,240',
        '+18%',
        '▲ 16.2%',
        '1,612',
        '42,180',
        // The chart's own default caption, which named a target that was never
        // stored anywhere and disagreed with the line it labelled.
        'TARGET 28.0K',
      ]) {
        expect(find.text(ghost), findsNothing, reason: '$ghost is mock data');
      }
      expect(find.text('Nothing needs attention'), findsOneWidget);
    });
  });

  // -------------------------------------------------------------------------
  // NOTHING ON THIS BOARD IS CUT OFF, at any width it is drawn at.
  //
  // Three separate truncations were photographed on 2026-08-21, the first time
  // this screen was rendered at any width by anything:
  //
  //   * `TONS 4,382.…` on a phone — the figure the board is RANKED BY, in the
  //     four-cell stat strip. `OvCellGrid`'s threshold was a row width (300)
  //     rather than a cell width, and at 305 each cell got 72px.
  //   * `WAYBILLS CLO…` on a 1600px monitor — same arithmetic, in the headline
  //     tons-moved card's footer.
  //   * `Leaderboard — …`, the card's own heading, because a short trailing
  //     pill sat in a `Flexible` (default `flex: 1`) beside the `Expanded`
  //     title and the two split the row equally (CLAUDE.md §10.4).
  //
  // None of them threw, none of them overflowed, and a sweep passes on all
  // three. `didExceedMaxLines` is the paragraph's own answer to "did I have to
  // cut this", which is the question.
  group('nothing is truncated', () {
    List<String> cutOff(WidgetTester tester) {
      final out = <String>[];
      void visit(Element e) {
        final ro = e.renderObject;
        if (ro is RenderParagraph && ro.didExceedMaxLines) {
          out.add(ro.text.toPlainText());
        }
        e.visitChildren(visit);
      }

      tester.allElements.first.visitAncestorElements((a) {
        visit(a);
        return false;
      });
      return out;
    }

    Future<void> pumpBoard(WidgetTester tester, Size size) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final data = TransportersOverviewMapper.build(
        // Five figures of tonnage, because that is the width the strip has to
        // survive and a three-figure fixture would pass through the fault.
        // SHORT company names, deliberately.
        //
        // A company NAME is allowed to ellipsise in the leaderboard's compact
        // ranking row — that row is 26px of rank, a name, a bar and a figure
        // inside a 300px aside, the full name is on the card beside it, and
        // `maxLines: 1` there is a decision with its own comment. What is not
        // allowed is a LABEL or a FIGURE being cut, and a long fixture name
        // would drown that signal in a truncation nobody intends to fix.
        bundle: bundle([
          company('Roadhaul', tons: 12420.5, trips: 128, fleet: 24,
              done: 121, open: 7),
          company('Kopano', tons: 96.2, trips: 3, fleet: 4),
        ]),
        rows: [row(date: DateTime(2026, 8, 4), truck: 'AAA', net: 120)],
        targetTons: 4200,
        now: now,
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(brightness: Brightness.dark),
          // NOT wrapped in another scroll view: `TransportersOverviewBody`
          // has its own, inside a `Stack`. Nesting a second one hands that
          // Stack an unbounded height, the flex row then lays out against a
          // different width, and every measurement taken here would be of a
          // layout the product never draws.
          home: Scaffold(body: TransportersOverviewBody(data: data)),
        ),
      );
      await tester.pumpAndSettle();
    }

    // A SWEEP, because every truncation on this board so far has appeared at
    // one width and not at its neighbours: the meter label needs the card's
    // three-column arrangement (widest), the tons-moved footer needs the
    // fleet card beside it (middle), and the stat strip needs a phone.
    for (final size in const [
      Size(1900, 2800),
      Size(1750, 2800),
      Size(1600, 3000),
      Size(1300, 3200),
      Size(1100, 3400),
      Size(900, 3800),
      Size(700, 4200),
      Size(412, 4600),
      Size(360, 4800),
    ]) {
      testWidgets('at ${size.width.toInt()}px', (tester) async {
        await pumpBoard(tester, size);
        expect(cutOff(tester), isEmpty,
            reason: 'these were cut off at ${size.width.toInt()}px');
      });
    }
  });

  group('a company that has never moved a load', () {
    testWidgets('reads "never active", not "last active never"',
        (tester) async {
      tester.view.physicalSize = const Size(1600, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final data = TransportersOverviewMapper.build(
        bundle: bundle([company('Kopano Freight', tons: 0, trips: 0, fleet: 4)]),
        rows: const [],
        now: now,
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(brightness: Brightness.dark),
          // NOT wrapped in another scroll view: `TransportersOverviewBody`
          // has its own, inside a `Stack`. Nesting a second one hands that
          // Stack an unbounded height, the flex row then lays out against a
          // different width, and every measurement taken here would be of a
          // layout the product never draws.
          home: Scaffold(body: TransportersOverviewBody(data: data)),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('last active never'), findsNothing);
      expect(find.text('never active'), findsOneWidget);
    });
  });

  group('the flagship target line, on screen', () {
    Future<void> pumpWith(WidgetTester tester, double? target) async {
      tester.view.physicalSize = const Size(1600, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final data = TransportersOverviewMapper.build(
        bundle: bundle([company('Roadhaul', tons: 3200, trips: 9, fleet: 4)]),
        rows: [row(date: DateTime(2026, 8, 4), truck: 'AAA', net: 120)],
        targetTons: target,
        now: now,
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(brightness: Brightness.dark),
          home: Scaffold(body: TransportersOverviewBody(data: data)),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('no target set draws no caption at all', (tester) async {
      await pumpWith(tester, null);
      expect(tester.takeException(), isNull);
      // Not a zero, not a default, not a dimmed placeholder — nothing. A
      // target nobody chose must not render like one somebody did.
      expect(find.textContaining('TARGET'), findsNothing);
      expect(find.text('Target pace'), findsNothing);
    });

    testWidgets('a real target is captioned with the pace it is drawn at',
        (tester) async {
      // 4,200 t across August's 31 days.
      await pumpWith(tester, 4200);
      expect(tester.takeException(), isNull);
      expect(find.text('TARGET 135 T/DAY'), findsOneWidget);
      // …and the key explains the extra line.
      expect(find.text('Target pace'), findsOneWidget);
    });

    testWidgets('the caption follows the value it labels', (tester) async {
      // The drop's fault was a caption and a line that disagreed, so the
      // number in the text has to come from the number being drawn.
      await pumpWith(tester, 987);
      expect(find.text('TARGET 32 T/DAY'), findsOneWidget);
      expect(find.text('TARGET 135 T/DAY'), findsNothing);
    });
  });
}
