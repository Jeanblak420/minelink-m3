// The buyer's reconciliations screen calls the mine's net weight by its name.
//
// Buyer pass, 2026-08-23 (reviewer finding #22, seen in
// `screen-buyer-reconciliations-phone-dark`).
//
// A stat card read "71.12 t · Tons Delivered" and the hero tile below it "Tons
// delivered · 71.12 t". Both take `tons.total`, which is `_windows()` summing
// `TripRecord.netTons` — the weight the MINE recorded at load. CLAUDE.md §4
// calls that the authoritative figure for recon and billing and says the
// delivered tonnage is stored SEPARATELY, precisely so the variance between
// them stays visible; §4 again: "never overwrite one with the other".
//
// So the screen whose entire purpose is that distinction was collapsing it in
// its own summary — and doing it two thousand pixels below a card reading
// "Loaded (mine net) 103.22 t" over "Delivered 70.70 t" over "Net variance".
// One screen, one scroll, two vocabularies.
//
// Also title case ("Total Records", "Tons Delivered") and two dropdowns whose
// no-filter option was composed as `'All $label'` — "All Source", "All
// Product" — while `raw_recon_view.dart`, on this same screen, has said "All
// products" since it was written.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:flutter_application_1/core/design/components/ml_components.dart';
import 'package:flutter_application_1/core/theme/app_theme.dart';
import 'package:flutter_application_1/features/auth/models/user_type.dart';
import 'package:flutter_application_1/features/portal/screens/buyer_reconciliations_screen.dart';
import 'package:flutter_application_1/features/portal/widgets/premium_overview_widgets.dart';
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
      anonKey: 'buyer-reconciliations-copy-test',
    );
  });

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1600, 5200);
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

  /// The labels of the screen's OWN summary row — every `MlStatCard` except
  /// the ones `WeightReconciliationView` draws, which speak for themselves.
  List<String> summaryLabels(WidgetTester tester) {
    final inRecon = find
        .descendant(
          of: find.byType(WeightReconciliationView),
          matching: find.byType(MlStatCard),
        )
        .evaluate()
        .map((e) => e.widget)
        .toSet();
    return tester
        .widgetList<MlStatCard>(find.byType(MlStatCard))
        .where((c) => !inRecon.contains(c))
        .map((c) => c.label)
        .toList();
  }

  testWidgets('the mine-net summary does not call itself delivered', (
    tester,
  ) async {
    await pump(tester);

    // THE SCREEN'S OWN summary row, not the cards inside
    // `WeightReconciliationView` — that widget has a "Delivered" card and it
    // is right, because that one really is the offload weight.
    final labels = summaryLabels(tester);
    expect(labels, contains('Loaded (mine net)'));
    for (final l in labels) {
      expect(
        l.toLowerCase(),
        isNot(contains('delivered')),
        reason:
            '"$l" sits over a sum of TripRecord.netTons, which is what the '
            'mine weighed at load',
      );
    }

    // And the hero tile that repeats the same figure.
    final heroes = tester
        .widgetList<OverviewHeroTile>(find.byType(OverviewHeroTile))
        .map((t) => t.title)
        .toList();
    expect(heroes, contains('Loaded (mine net)'));
    expect(
      heroes.where((t) => t.toLowerCase().contains('delivered')),
      isEmpty,
    );
  });

  // The GREEN case, and the one that makes the rule a rule rather than a
  // word-ban: the weight-reconciliation card at the top of this same screen
  // has a "Delivered" figure, and it is CORRECT — that one really is the
  // offload weight. Blanket-replacing the word would take it out.
  testWidgets('the weight-reconciliation card keeps its Delivered figure', (
    tester,
  ) async {
    await pump(tester);
    expect(find.text('Delivered'), findsWidgets);
    expect(find.text('Loaded (mine net)'), findsWidgets);
    expect(find.text('Net variance'), findsOneWidget);
  });

  testWidgets('the stat labels read as sentences', (tester) async {
    await pump(tester);

    final labels = tester
        .widgetList<MlStatCard>(find.byType(MlStatCard))
        .map((c) => c.label);
    expect(labels, contains('Total records'));
    expect(labels, isNot(contains('Total Records')));
    expect(labels, isNot(contains('Tons Delivered')));
  });

  testWidgets('a filter\'s no-filter option is grammatical', (tester) async {
    await pump(tester);

    expect(find.text('All sources'), findsWidgets);
    expect(find.text('All Source'), findsNothing);
    expect(find.text('All Product'), findsNothing);
  });
}
