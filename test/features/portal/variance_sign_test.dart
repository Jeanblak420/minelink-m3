// One load, one variance, one sign — everywhere it is written down.
//
// `trips.variance_tons` is a generated Postgres column, and both models that
// carry it say the same thing in their doc comments: **positive means mass that
// left the mine and did not arrive.** The CSV/Excel/PDF exports carry that sign.
// Side A's raw recon table prints that sign. The "Net variance" stat card prints
// that sign.
//
// Side B's per-row cell inverted it, with no comment saying why, so a load
// rendered as `0.42 t` on the stat card and `−0.42 t` in the row directly
// beneath — same figure, same load, same card, opposite signs. On the screen
// whose entire job is to say whether mass went missing. Found 2026-08-20 by
// looking at `screen-mine-reconciliations-desktop-dark.png`.
//
// This test does not care WHICH convention wins. It cares that there is one.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:flutter_application_1/core/theme/app_theme.dart';
import 'package:flutter_application_1/features/portal/widgets/raw_recon_view.dart';
import 'package:flutter_application_1/features/portal/widgets/weight_reconciliation_view.dart';

import '../../fixtures/portal_capture_fixtures.dart';
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
      anonKey: 'variance-sign-test',
    );
  });

  Future<void> pump(WidgetTester tester, Widget child) async {
    tester.view.physicalSize = const Size(1600, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [...companyScopeOverrides(), ...portalCaptureOverrides()],
      child: MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: child,
          ),
        ),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  // `t-1` in `kTripReconciliations` / `kRawReconRows`: 36.22 loaded, 35.80
  // delivered, so 0.42 t left the mine and did not arrive.
  const positive = '0.42 t';
  // What the inversion used to print. U+2212, the character the old code used.
  const inverted = '−0.42 t';

  testWidgets('Side B prints the stored sign, not its negation', (tester) async {
    await pump(tester, const WeightReconciliationView(companyId: 'FIXTURE-company'));

    expect(find.text(inverted), findsNothing,
        reason: 'the per-row variance cell is negating a figure whose sign is '
            'defined by the database and repeated in the models, the exports, '
            'the raw table and the stat card at the top of this very card. If '
            'the convention is genuinely meant to change, change it in all five '
            'places and write down which way round it now means.');
    expect(find.text(positive), findsWidgets,
        reason: 'no variance figure at all. The fixture stopped reaching the '
            'view, so this proves nothing.');
  });

  testWidgets('Side A prints the same sign as Side B', (tester) async {
    // Both halves of the Reconciliations screen, one after the other, exactly
    // as the screen stacks them.
    await pump(
      tester,
      const Column(
        children: [
          WeightReconciliationView(companyId: 'FIXTURE-company'),
          SizedBox(height: 16),
          RawReconView(companyId: null),
        ],
      ),
    );

    expect(find.text(inverted), findsNothing,
        reason: 'one of the two tables on this screen is negating the other. '
            'A reconciliation screen that reports the same load two ways is '
            'worse than one that does not report it.');
    // Side A renders it inside the table, Side B in a pill: both present.
    expect(find.text(positive), findsAtLeast(2),
        reason: 'the same load should appear with the same variance in the raw '
            'table and in the system cross-check.');
  });
}
