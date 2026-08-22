// A variance is a comparison. With nothing on one side there is no variance —
// and "R0.00", in green, is the most reassuring possible way to say so wrongly.
//
// Photographed on the live buyer screen as `atlasbuyer.owner`, 2026-08-23:
//
//     R138,118.50      R138,118.50     R0.00        R0.00
//     Delivered value  Payable value   Invoiced     Invoice variance
//
//     Per-load values & invoices                    33 loads · 0 invoiced
//
// `R0.00 Invoice variance` in the `done` tone reads "every invoice you have
// captured balances to the cent". Nought invoices had been captured. The card
// header two lines below it says so in words.
//
// The fold was over `rows.where(hasInvoice)`, and a fold over an empty list is
// `0.0` — the same shape as the mine's pit-to-port loss, which reported a
// figure against a window that recorded nothing. `Invoiced R0.00` beside it is
// NOT the same thing and stays: nothing invoiced really is zero rand invoiced.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:flutter_application_1/core/theme/app_theme.dart';
import 'package:flutter_application_1/features/portal/models/buyer_load_value.dart';
import 'package:flutter_application_1/features/portal/screens/buyer_loads_value_screen.dart';
import 'package:flutter_application_1/features/auth/models/user_type.dart';
import 'package:flutter_application_1/features/portal/services/buyer_value_service.dart';

import '../../fixtures/screen_fixtures.dart';
import '../../test_helpers/real_fonts.dart';
import '../../test_helpers/frozen_clock.dart';

BuyerLoadValue _load({
  required String id,
  double? invoicedAmount,
  double? invoiceVariance,
}) =>
    BuyerLoadValue(
      tripId: id,
      updatedAt: DateTime.utc(2026, 8, 15, 9),
      reference: 'TRP-$id',
      truckReg: 'S6W001GP',
      commodity: 'Chrome Ore',
      sourceName: 'Iron Hills Mining',
      transporterName: 'Roadhaul Logistics',
      netTons: 34.05,
      deliveredTons: 34.05,
      ratePerTon: 950,
      currency: 'ZAR',
      loadedValue: 32347.50,
      deliveredValue: 32347.50,
      payableValue: 32347.50,
      invoicedAmount: invoicedAmount,
      invoiceVariance: invoiceVariance,
      tripStatus: 'completed',
    );

void main() {
  setUpAll(() async {
    freezeCaptureClock();
    await loadRealFonts();
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'http://localhost:54321',
      anonKey: 'invoice-variance-test',
    );
  });

  Future<List<String>> pump(
      WidgetTester tester, List<BuyerLoadValue> rows) async {
    tester.view.physicalSize = const Size(1600, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(ProviderScope(
      overrides: [
        ...companyScopeOverrides(
            role: UserRole.admin, orgType: OrgType.buyer),
        buyerTripValuesProvider.overrideWith((ref, _) async => rows),
      ],
      child: MaterialApp(
        theme: AppTheme.darkTheme,
        home: const Scaffold(body: BuyerLoadsValueScreen()),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1200));

    return [
      for (final e in find.byType(Text).evaluate())
        (e.widget as Text).data ?? '',
    ]..removeWhere((s) => s.isEmpty);
  }

  testWidgets('nothing invoiced reports no variance, not a balanced one',
      (tester) async {
    final strings = await pump(tester, [
      _load(id: 'a'),
      _load(id: 'b'),
    ]);

    // The Invoiced card is a real sum and stays at R0.00 — that IS the fact.
    expect(strings, contains('R0.00'),
        reason: 'the Invoiced card should still read R0.00: nothing invoiced '
            'really is zero rand invoiced.');

    // …but exactly once. A second R0.00 is the variance card claiming the
    // books balance against invoices that do not exist.
    expect(strings.where((s) => s == 'R0.00').length, 1,
        reason: 'two cards read R0.00. The variance one is a COMPARISON with '
            'nothing on one side of it, and R0.00 in the done tone reads as '
            '"every invoice balances" on a screen headed "0 invoiced".');

    expect(strings, contains('no_invoices_captured'),
        reason: 'the variance card must say WHY it has no figure.');
  });

  testWidgets('a real invoice still produces a real variance', (tester) async {
    final strings = await pump(tester, [
      _load(id: 'a', invoicedAmount: 33000, invoiceVariance: 652.50),
      _load(id: 'b'),
    ]);

    expect(strings, contains('R652.50'),
        reason: 'one load is over-invoiced by R652.50 and the roll-up must '
            'still report it. The fix is about an ABSENT comparison, not '
            'about suppressing variances that exist.');
    expect(strings, isNot(contains('no_invoices_captured')));
  });
}
