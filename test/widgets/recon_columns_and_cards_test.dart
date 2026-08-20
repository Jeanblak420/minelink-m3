// S6-18 (recon column order) and S6-19 (the D/W/M/Y/Total cards), pinned.
//
// Both gates were written `D` — a human at a screen. They do not need one.
// The column order is a property of what is DRAWN, so it is asserted on
// geometry: the required headers must sit left-to-right in the required order
// on a real rendered table. That is stronger than reading the list, because a
// list can be right while the builder paints it in another order (the row
// builder indexes `_cols` positionally, and its own comment records that two
// columns were once inserted ahead of POD and nearly moved the POD link onto
// the Variance cell).
//
// Fonts: loaded for real. `flutter test` otherwise renders in a fallback font
// where every glyph is one em wide, and these assertions are all about x
// positions. See CLAUDE.md §7.
//
// The required order is CLAUDE.md §4:
//   DATE · TIME-IN · WAYBILL NUMBER · TRANSPORTER NAME · TRUCK REGISTRATION NO
//   · DESTINATION · PRODUCT · SOURCE · CUSTOMER · NET MASS · TIME-OUT
//
// The shipped table carries three MORE columns — Delivered, Variance, POD —
// inserted between Net mass and Time-out. That is deliberate and is not a
// deviation being waved through: two-weight variance and cross-party POD
// visibility are both features CLAUDE.md §4 itself specifies, and the eleven
// required columns keep their required relative order. So the property
// asserted is SUBSEQUENCE, not equality, and the extra columns are named here
// so that adding a fourth is a decision someone makes on purpose.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/features/portal/models/raw_recon_row.dart';
import 'package:flutter_application_1/features/portal/services/reconciliation_service.dart';
import 'package:flutter_application_1/core/design/components/ml_stat_card.dart';
import 'package:flutter_application_1/features/portal/widgets/raw_recon_view.dart';

/// CLAUDE.md §4, verbatim and in order. Written out rather than imported so
/// the test states the requirement independently of the code it checks.
/// This is what the EXPORT must say — `csvHeaders` carries the spec names.
const _requiredExport = [
  'DATE',
  'TIME-IN',
  'WAYBILL NUMBER',
  'TRANSPORTER NAME',
  'TRUCK REGISTRATION NO',
  'DESTINATION',
  'PRODUCT',
  'SOURCE',
  'CUSTOMER',
  'NET MASS',
  'TIME-OUT',
];

/// What the SCREEN draws, in the same order. The table renders
/// `label.toUpperCase()`, and **three headers are abbreviated** to fit a
/// 14-column row: WAYBILL NUMBER → WAYBILL, TRANSPORTER NAME → TRANSPORTER,
/// TRUCK REGISTRATION NO → TRUCK.
///
/// Recorded rather than failed. S6-18 asks for the column *order*, and the
/// export — the artifact anyone reconciles against off-screen — carries the
/// spec names in full. Widening three headers to their spec length would push
/// a 14-column table into horizontal scrolling to satisfy a wording the gate
/// does not ask for. If that judgement is ever revisited, this list is where
/// the decision is written down.
const _requiredScreen = [
  'DATE',
  'TIME-IN',
  'WAYBILL',
  'TRANSPORTER',
  'TRUCK',
  'DESTINATION',
  'PRODUCT',
  'SOURCE',
  'CUSTOMER',
  'NET MASS',
  'TIME-OUT',
];

/// Deliberate additions (see the header note).
const _additional = ['DELIVERED', 'VARIANCE', 'POD'];

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

Future<void> _loadRealFonts() async {
  await _loadFont('PlusJakartaSans', [
    'PlusJakartaSans-Regular.ttf',
    'PlusJakartaSans-Medium.ttf',
    'PlusJakartaSans-SemiBold.ttf',
    'PlusJakartaSans-Bold.ttf',
    'PlusJakartaSans-ExtraBold.ttf',
  ]);
  await _loadFont('JetBrainsMono', [
    'JetBrainsMono-Regular.ttf',
    'JetBrainsMono-Medium.ttf',
    'JetBrainsMono-Bold.ttf',
  ]);
  await _loadFont('Fraunces', ['Fraunces-Medium.ttf', 'Fraunces-SemiBold.ttf']);
}

/// Rows spanning every era a card measures, **plus a row just outside two of
/// the boundaries**.
///
/// today · 3d · **7d12h** · 20d · **30d12h** · 200d · 3 YEARS.
///
/// The ancient row is what makes "Total never resets" checkable — it must be
/// in Total and in nothing else.
///
/// The two boundary rows were added 2026-08-16 because `mutation_check.py`
/// reported **NOT DETECTED** for "the Month caption drifts from the 30-day
/// window it describes": widening Month from 30 days to 31 changed nothing,
/// because the fixture had no row between 20 and 200 days. A window test with
/// no row near the window's edge tests the middle of the range and calls it
/// the boundary. Each boundary row sits **12 hours outside** its window, so a
/// one-day drift in either direction moves a card.
List<RawReconRow> _rows() {
  final now = DateTime.now();
  RawReconRow at(String id, Duration ago, double tons) => RawReconRow(
        tripId: id,
        tripDate: now.subtract(ago),
        timeIn: now.subtract(ago),
        timeOut: now.subtract(ago),
        waybillNumber: 'TRP-$id',
        transporterName: 'Roadhaul Logistics',
        truckReg: 'KVK007MP',
        destination: 'Richards Bay',
        product: 'Chrome Ore',
        sourceName: 'Iron Hills Mining',
        customerName: 'Atlas Buyer Group',
        netMass: tons,
        deliveredTons: tons,
        varianceTons: 0,
      );
  return [
    at('today', const Duration(hours: 2), 10),
    at('thisweek', const Duration(days: 3), 20),
    // 12h past the 7-day edge: in Month, not in Week.
    at('justpastweek', const Duration(days: 7, hours: 12), 3),
    at('thismonth', const Duration(days: 20), 40),
    // 12h past the 30-day edge: in Year, not in Month.
    at('justpastmonth', const Duration(days: 30, hours: 12), 5),
    at('thisyear', const Duration(days: 200), 80),
    at('ancient', const Duration(days: 365 * 3), 160),
  ];
}

Future<void> _pump(WidgetTester tester, {String? companyId}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        rawReconRowsProvider(companyId).overrideWith((ref) async => _rows()),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 1600,
            child: SingleChildScrollView(
              child: RawReconView(companyId: companyId),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(_loadRealFonts);

  group('S6-18 recon column order', () {
    testWidgets('the eleven required headers are drawn in the required order',
        (tester) async {
      tester.view.physicalSize = const Size(2200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await _pump(tester);

      // Left edge of each required header, as actually laid out.
      final xs = <String, double>{};
      for (final label in _requiredScreen) {
        final finder = find.text(label);
        expect(finder, findsWidgets, reason: 'header "$label" is not drawn');
        xs[label] = tester.getTopLeft(finder.first).dx;
      }

      // Guard against a vacuous pass: if the table collapsed to one column
      // every x would be equal and "ascending" would hold trivially.
      expect(xs.values.toSet().length, _requiredScreen.length,
          reason: 'headers share an x position - the table did not lay out');

      for (var i = 1; i < _requiredScreen.length; i++) {
        expect(xs[_requiredScreen[i]]!, greaterThan(xs[_requiredScreen[i - 1]]!),
            reason: '"${_requiredScreen[i]}" must be drawn to the right of '
                '"${_requiredScreen[i - 1]}"');
      }
    });

    testWidgets('the three additional columns sit between Net mass and Time-out',
        (tester) async {
      tester.view.physicalSize = const Size(2200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await _pump(tester);

      final netMass = tester.getTopLeft(find.text('NET MASS').first).dx;
      final timeOut = tester.getTopLeft(find.text('TIME-OUT').first).dx;
      for (final label in _additional) {
        final x = tester.getTopLeft(find.text(label).first).dx;
        expect(x, greaterThan(netMass),
            reason: '"$label" must not displace a required column');
        expect(x, lessThan(timeOut),
            reason: '"$label" must stay ahead of Time-out');
      }
    });

    test('the export headers carry the required order as a subsequence', () {
      final headers = RawReconView.csvHeaders;
      var i = 0;
      for (final want in _requiredExport) {
        final at = headers.indexWhere((h) => h.toUpperCase() == want, i);
        expect(at, isNot(-1),
            reason: '"$want" missing from csvHeaders, or out of order. The '
                'export must carry the CLAUDE.md §4 names in full - the screen '
                'may abbreviate, the export may not.');
        i = at + 1;
      }
      // The export and the screen must not drift apart.
      expect(headers.length, _requiredExport.length + _additional.length);
    });
  });

  group('S6-19 period cards', () {
    testWidgets('each card says WHICH window it measures — S6-21',
        (tester) async {
      // The windows are ROLLING, which is what §4 specifies ("a row of live
      // summary cards showing **rolling** NET MASS totals"). The labels did
      // not say so, and on 2026-08-16 that was measurably misleading: Iron
      // Hills' "Month" card read 664.02 t in the running web build while
      // August's actual tonnage was 277.52 t. A mine manager reading a card
      // headed "Month" on the 16th takes it for the calendar month and is out
      // by 2.4x. The figure was never wrong; the label was silent about which
      // thirty days it meant.
      //
      // Red first: before this, `MlStatCard.caption` was null on all five and
      // not one of these strings was on the screen.
      tester.view.physicalSize = const Size(2200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await _pump(tester);

      for (final caption in const [
        'net_mass · last_24h',
        'net_mass · last_7_days',
        'net_mass · last_30_days',
        'net_mass · last_365_days',
        'net_mass · all_time',
      ]) {
        expect(find.text(caption), findsOneWidget, reason: caption);
      }
    });

    testWidgets('Day/Week/Month/Year/Total render in full words',
        (tester) async {
      tester.view.physicalSize = const Size(2200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await _pump(tester);

      for (final label in ['Day', 'Week', 'Month', 'Year', 'Total']) {
        expect(find.text(label), findsWidgets,
            reason: 'the $label card must be labelled in full, not "'
                '${label[0]}="');
      }
      // The abbreviated forms §4 explicitly rejects.
      for (final abbrev in ['D=', 'W=', 'M=', 'Y=', 'T=']) {
        expect(find.text(abbrev), findsNothing);
      }
    });

    testWidgets('every window is right, and Total is all-time',
        (tester) async {
      tester.view.physicalSize = const Size(2200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await _pump(tester);

      // Fixture tonnage: 10 today · 20 at 3d · 3 at 7d12h · 40 at 20d ·
      // 5 at 30d12h · 80 at 200d · 160 at 3y. Cards render
      // `'${value.toStringAsFixed(2)} t'`, so each is exact.
      //
      // The two 12-hour-outside rows are what make the EDGES checkable: widen
      // Week by a day and it gains the 3 t; widen Month by a day and it gains
      // the 5 t. Without them a window could drift by a day and every card
      // still read the same.
      //
      // The 3-year-old 160 t appears ONLY in Total. If Total were windowed --
      // or reset per period -- it would read 158.00 t, the same as Year.
      //
      // ⚠ This asserts on the CARD, not on the footer. An earlier version of
      // this test looked for the total anywhere and passed against a Total card
      // that had been mutated to a 1-year window -- because `Total Tons =
      // <total>` in the footer matched. The footer is `_totalTons(filtered)`,
      // a different function from `_windows`, so it cannot stand in for this.
      // tool/mutation_check.py caught that; the reason it is written down is
      // that nothing else would have.
      // Scoped to the card. `10.00 t` also appears in the table's Net mass and
      // Delivered cells for the 10 t row, so an unscoped finder matches three
      // widgets and says nothing about which one is the card.
      for (final MapEntry(key: label, value: tons) in {
        'Day': '10.00',
        'Week': '30.00',
        'Month': '73.00',
        'Year': '158.00',
        'Total': '318.00',
      }.entries) {
        expect(
          find.descendant(
            of: find.widgetWithText(MlStatCard, label),
            matching: find.text('$tons t'),
          ),
          findsOneWidget,
          reason: 'the $label card must read $tons t',
        );
      }
    });

    testWidgets('hiding a card removes it without touching the data',
        (tester) async {
      tester.view.physicalSize = const Size(2200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await _pump(tester);
      expect(find.text('318.00 t'), findsOneWidget);

      // The Show/Hide chip for Total.
      await tester.tap(find.widgetWithText(FilterChip, 'Total'));
      await tester.pumpAndSettle();

      expect(find.text('318.00 t'), findsNothing,
          reason: 'hiding Total must remove its card');
      // §4: hiding is display-only. The footer total, which is data, stays.
      expect(find.textContaining('Total Tons ='), findsOneWidget,
          reason: 'hiding a card must not remove the underlying data');
    });
  });
}
