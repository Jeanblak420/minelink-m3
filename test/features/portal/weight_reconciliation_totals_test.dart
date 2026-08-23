// The three weight-reconciliation figures cover the same loads, so they
// reconcile.
//
// Found by LOOKING at `screen-buyer-reconciliations-desktop-dark`, which had
// to be created first — only the phone had ever been photographed. Buyer pass,
// 2026-08-23; no reviewer raised it.
//
// The card row read `103.22 t Loaded (mine net) · 70.70 t Delivered · 0.42 t
// Net variance` over a table of three trips, one of them still `Pending`.
// "Loaded" summed EVERY row; "Delivered" and "Net variance" summed the
// delivered ones. 103.22 − 70.70 is 32.52, and the caption directly invites
// that subtraction — "mine Net Weight loaded (authoritative) vs delivered tons
// at offload. Variance is the mass lost en route." So a reader checking the
// cross-check got a number seventy-seven times the real variance, on the
// screen whose whole purpose is to say whether mass went missing en route.
//
// The file already knew: the same figure was computed under the name
// `deliveredLoaded` to serve as the severity denominator, under a comment
// saying `totalLoaded` "includes loads still on the road, which have no
// variance yet". Only the denominator had been fixed.
//
// Nothing is hidden by the change: the load still on the road keeps its row
// and its mine net (`Pending` in the Delivered column), and the raw recon
// table below totals every row.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:flutter_application_1/core/design/components/ml_components.dart';
import 'package:flutter_application_1/core/theme/app_theme.dart';
import 'package:flutter_application_1/features/auth/models/user_type.dart';
import 'package:flutter_application_1/features/portal/screens/buyer_reconciliations_screen.dart';
import 'package:flutter_application_1/features/portal/widgets/weight_reconciliation_view.dart';

import '../../fixtures/portal_capture_fixtures.dart';
import '../../fixtures/portal_tail_fixtures.dart';
import '../../fixtures/screen_fixtures.dart';
import '../../test_helpers/real_fonts.dart';
import '../../test_helpers/frozen_clock.dart';

void main() {
  setUpAll(() async {
    freezeCaptureClock();
    await loadRealFonts();
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'http://localhost:54321',
      anonKey: 'weight-reconciliation-totals-test',
    );
  });

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1600, 3400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...companyScopeOverrides(
            role: UserRole.admin,
            orgType: OrgType.buyer,
          ),
          ...portalCaptureOverrides(),
          ...portalTailOverrides(),
        ],
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: const Scaffold(body: BuyerReconciliationsScreen()),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));
  }

  /// The three figures the cross-check draws, by label, as numbers.
  Map<String, double> figures(WidgetTester tester) {
    final cards = tester.widgetList<MlStatCard>(
      find.descendant(
        of: find.byType(WeightReconciliationView),
        matching: find.byType(MlStatCard),
      ),
    );
    return {
      for (final c in cards)
        c.label: double.parse(c.value.replaceAll(RegExp(r'[^0-9.\-]'), '')),
    };
  }

  testWidgets('loaded minus delivered is the variance', (tester) async {
    await pump(tester);

    final f = figures(tester);
    expect(f.keys, containsAll(['Loaded (mine net)', 'Delivered']));
    final loaded = f['Loaded (mine net)']!;
    final delivered = f['Delivered']!;
    final variance = f['Net variance']!;

    expect(
      loaded - delivered,
      closeTo(variance, 0.01),
      reason:
          'the caption asks the reader to subtract these two. $loaded − '
          '$delivered = ${(loaded - delivered).toStringAsFixed(2)}, and the '
          'third card says $variance',
    );
  });

  testWidgets('a load still on the road is in none of the three', (
    tester,
  ) async {
    await pump(tester);

    // The fixture deliberately carries an undelivered trip; without one this
    // test proves nothing, because every population is then the same.
    expect(
      find.descendant(
        of: find.byType(WeightReconciliationView),
        matching: find.text('Pending'),
      ),
      findsWidgets,
      reason: 'the fixture must include a trip that has not been delivered',
    );

    final f = figures(tester);
    // Its mine net would push "Loaded" above the delivered total by far more
    // than any real variance.
    expect(
      f['Loaded (mine net)']! - f['Delivered']!,
      lessThan(5),
      reason:
          'a pending load\'s tonnage is in "Loaded" — it is not missing mass, '
          'it simply has not arrived',
    );
  });

  // The GREEN case, and the thing that stops this being a fix by deletion: the
  // pending load is still ON the screen, with its mine net, in its own row.
  testWidgets('the pending load keeps its row and its tonnage', (tester) async {
    await pump(tester);

    final table = find.byType(WeightReconciliationView);
    expect(
      find.descendant(of: table, matching: find.textContaining('32.10')),
      findsWidgets,
      reason:
          'the load still on the road is excluded from the CROSS-CHECK, not '
          'from the screen',
    );
  });

  testWidgets('the caption says which loads the three figures cover', (
    tester,
  ) async {
    await pump(tester);
    expect(
      find.textContaining('DELIVERED loads'),
      findsWidgets,
      reason:
          'three totals over a subset must say so; the previous caption said '
          'the opposite by omission',
    );
  });
}
