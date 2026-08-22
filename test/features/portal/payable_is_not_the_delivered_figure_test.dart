// A column headed PAYABLE must not quietly print a different quantity.
//
// `list_load_quality` returns NULL for `payable_tons` whenever the load has no
// moisture reading — no certificate means no penalty and nothing to compute.
// The cell filled that gap with `deliveredTons ?? netTons`, muted, under the
// same heading and in the same format as a real payable figure.
//
// Photographed on the live mine Quality screen as `ironhills.owner`,
// 2026-08-23. The card header read `0 of 35 loads certified` and every
// Cr₂O₃ and Moisture cell on every row read `—`:
//
//     TRUCK      NET        CR2O3   MOISTURE   PAYABLE
//     S6W001GP   34.20 t    —       —          34.05 t
//     S6W001GP   34.70 t    —       —          34.40 t
//     KVK007MP   31.80 t    —       —          34.90 t   <- payable ABOVE net
//
// Payable is the tonnage REDUCED by an excess-moisture penalty, so it can never
// exceed the mine net. That last row is the delivered figure — a real number,
// but not the one the column claims — and the screen gave no hint.
//
// The exporter beside it already wrote an empty cell for the same rows, so a
// mine reading the screen and a mine reading its own spreadsheet were told two
// different things about the same load.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:flutter_application_1/core/theme/app_theme.dart';
import 'package:flutter_application_1/features/portal/models/load_quality.dart';
import 'package:flutter_application_1/features/portal/services/quality_service.dart';
import 'package:flutter_application_1/features/portal/widgets/load_quality_table.dart';

import '../../test_helpers/real_fonts.dart';
import '../../test_helpers/frozen_clock.dart';

/// The live shape: a mine net of 31.80 t, a DELIVERED figure 3.10 t above it,
/// and no certificate at all, so the server declines to compute a payable.
final _uncertified = LoadQualityRow(
  tripId: 't-uncertified',
  updatedAt: DateTime.utc(2026, 8, 15, 7, 30),
  reference: 'TRP-DEMO-036',
  truckReg: 'KVK007MP',
  commodity: 'Chrome Ore',
  sourceName: 'Iron Hills Mining',
  customerName: 'Atlas Buyer Group',
  netTons: 31.80,
  deliveredTons: 34.90,
  tripStatus: 'completed',
);

/// A certified load, so the test can tell "the column is empty" from "the
/// column stopped working".
final _certified = LoadQualityRow(
  tripId: 't-certified',
  updatedAt: DateTime.utc(2026, 8, 15, 6, 30),
  reference: 'TRP-000123',
  truckReg: 'CK84RTGP',
  commodity: 'Chrome Ore',
  sourceName: 'Iron Hills Mining',
  customerName: 'Atlas Buyer Group',
  netTons: 36.22,
  deliveredTons: 35.80,
  cr2o3Pct: 38,
  moisturePct: 10,
  specCr2o3Pct: 42,
  specMoistureMaxPct: 8,
  payableTons: 34.10,
  gradeFactor: 0.9048,
  certPath: 'FIXTURE-company/quality/t-1.pdf',
  certFileName: 'lab.pdf',
  tripStatus: 'completed',
);

void main() {
  setUpAll(() async {
    freezeCaptureClock();
    await loadRealFonts();
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'http://localhost:54321',
      anonKey: 'payable-column-test',
    );
  });

  Future<List<String>> pumpTable(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1600, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(ProviderScope(
      overrides: [
        loadQualityProvider
            .overrideWith((ref, _) async => [_certified, _uncertified]),
      ],
      child: MaterialApp(
        theme: AppTheme.darkTheme,
        home: const Scaffold(
          body: SingleChildScrollView(
            child: LoadQualityTable(companyId: 'FIXTURE-company'),
          ),
        ),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    return [
      for (final e in find.byType(Text).evaluate())
        (e.widget as Text).data ?? '',
    ]..removeWhere((s) => s.isEmpty);
  }

  testWidgets('an uncertified load shows no payable, not its delivered tons',
      (tester) async {
    final strings = await pumpTable(tester);

    expect(strings, contains('31.80 t'),
        reason: 'the uncertified row is not on screen at all — the NET column '
            'should still carry the mine weight.');

    expect(strings, isNot(contains('34.90 t')),
        reason: 'the DELIVERED tonnage (34.90 t) is being printed in the '
            'PAYABLE column of a load with no certificate. Payable is net '
            'reduced by a moisture penalty, so a payable ABOVE the 31.80 t net '
            'cannot be a payable figure at all — and nothing on the row says '
            'it is the delivered weight instead.');
  });

  testWidgets('a certified load still shows its real payable figure',
      (tester) async {
    final strings = await pumpTable(tester);

    expect(strings, contains('34.10 t'),
        reason: 'the certified row lost its computed payable. The fix is about '
            'a column filling an EMPTY value with a different quantity, not '
            'about hiding figures the server actually computed.');
  });

  testWidgets('the screen and the export agree about the same load',
      (tester) async {
    // They did not. The export wrote an empty cell for a null payable while
    // the screen wrote the delivered tonnage, so a mine reading its own
    // spreadsheet and a mine reading the screen got different answers.
    final strings = await pumpTable(tester);
    final exported = LoadQualityTable.exportRows([_uncertified]).single;

    // Column 12 of `exportHeaders` is PAYABLE TONS.
    expect(exported[12], '',
        reason: 'the exporter changed: this test pins the two together.');
    expect(strings.where((s) => s == '34.90 t'), isEmpty,
        reason: 'the export says nothing is payable on this load and the '
            'screen says 34.90 t.');
  });
}
