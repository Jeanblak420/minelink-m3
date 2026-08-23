// "Add vehicle" was a floating action button. Nothing else in this product is.
//
// Transporter pass, 2026-08-23 (reviewer finding #9). A FAB is Material's own
// answer to a primary action, but this console's answer — the reference's, and
// every other register's — is a primary button in the page header, beside the
// page's name, where the reader is already looking when they decide to add
// something.
//
// Two things it cost beyond consistency:
//
//  * **It sat ON TOP of the register.** At phone width the circle overlapped
//    the last row's actions — visible on `screen-fleet-phone-dark`, where it
//    covered the fourth truck's card.
//  * **Its only label was a tooltip**, which a touch device never shows. The
//    one control that creates a vehicle was an unlabelled `+`.
//
// The screen's header already carried `Refresh`, so the slot was there.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/core/design/components/ml_components.dart';
import 'package:flutter_application_1/core/theme/app_theme.dart';
import 'package:flutter_application_1/features/fleet/screens/fleet_management_screen.dart';

import '../../fixtures/portal_capture_fixtures.dart';
import '../../fixtures/screen_fixtures.dart';
import '../../test_helpers/real_fonts.dart';
import '../../test_helpers/frozen_clock.dart';
import '../../test_helpers/test_supabase.dart';

void main() {
  setUpAll(() async {
    freezeCaptureClock();
    await loadRealFonts();
    await ensureTestSupabaseInitialized();
  });

  Future<void> pump(WidgetTester tester, double width) async {
    tester.view.physicalSize = Size(width, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...companyScopeOverrides(),
          ...portalCaptureOverrides(),
        ],
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: const Scaffold(body: FleetManagementScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final width in const [412.0, 1600.0]) {
    testWidgets('no floating action button at ${width.toInt()}px',
        (tester) async {
      await pump(tester, width);

      expect(
        find.byType(FloatingActionButton),
        findsNothing,
        reason: 'no other screen in this product has one',
      );
    });

    testWidgets('"Add vehicle" is a labelled header action at '
        '${width.toInt()}px', (tester) async {
      await pump(tester, width);

      // Labelled, not a bare `+` whose only name is a tooltip a touch device
      // never shows.
      expect(find.text('Add vehicle'), findsOneWidget);
      expect(
        find.ancestor(
          of: find.text('Add vehicle'),
          matching: find.byType(MlPageHeader),
        ),
        findsOneWidget,
        reason: 'the primary action belongs in the header, beside the '
            'page name',
      );
    });
  }

  // THE CASE THAT MUST STAY GREEN. Refresh was already in that slot and must
  // still be — moving the primary action in must not have displaced it.
  testWidgets('Refresh keeps its place beside it', (tester) async {
    await pump(tester, 1600);

    expect(find.text('Refresh'), findsOneWidget);
    final refresh = tester.getRect(find.text('Refresh'));
    final add = tester.getRect(find.text('Add vehicle'));
    expect(
      (refresh.center.dy - add.center.dy).abs(),
      lessThan(4),
      reason: 'the two header actions are on one row',
    );
    expect(
      add.left,
      greaterThan(refresh.left),
      reason: 'the primary action sits last, at the right edge',
    );
  });
}
