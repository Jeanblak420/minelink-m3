// The Operations Hub speaks the portal's card vocabulary.
//
// Phase 3 mine-portal pass, 2026-08-23. The hub was still built from stock
// Material — a `Card` headed by a 24px sans ExtraBold company name that
// sized to its content (ended at x≈1040 on a 1600px canvas while every card
// under it spanned the column), a tab card headed by a 22px sans ExtraBold
// row with the create button stacked UNDER it, and a hand-rolled empty state
// in the same sans. Plus title case on tab titles and dialog titles ("Gate
// Checks", "Add Mineral", "Record Weighbridge Entry"). This pins the heading
// faces by `fontFamily`, the card's width by geometry, the action's
// placement (right of the heading, not under it) and the casing.

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:flutter_application_1/core/design/components/ml_components.dart';
import 'package:flutter_application_1/core/theme/app_theme.dart';
import 'package:flutter_application_1/features/auth/models/user_type.dart';
import 'package:flutter_application_1/features/operations/models/operations_models.dart';
import 'package:flutter_application_1/features/operations/screens/operations_hub_screen.dart';

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
      anonKey: 'operations-hub-heads-test',
    );
  });

  Future<void> pumpHub(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(ProviderScope(
      overrides: [
        ...companyScopeOverrides(
            role: UserRole.admin, orgType: OrgType.transporter),
        operationsOverride(),
      ],
      child: MaterialApp(
        theme: AppTheme.darkTheme,
        home: const Scaffold(body: OperationsHubScreen()),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  String? familyOf(WidgetTester tester, String text) {
    final paragraph =
        find.text(text).evaluate().single.renderObject! as RenderParagraph;
    return paragraph.text.style?.fontFamily;
  }

  testWidgets('the company card and the tab card head in the display face',
      (tester) async {
    await pumpHub(tester);

    final company = find.text('Fixture Haulage (Pty) Ltd');
    expect(company, findsOneWidget);
    expect(familyOf(tester, 'Fixture Haulage (Pty) Ltd'), MlTokens.fontSerif,
        reason: 'company card heading is not in Fraunces');

    // The tab heading: the tab bar also says "Transactions", so find the one
    // that is a section title.
    final heading = find.descendant(
      of: find.byType(MlSectionTitle),
      matching: find.text('Transactions'),
    );
    expect(heading, findsOneWidget, reason: 'tab heading is not a section title');
    expect(
      (heading.evaluate().single.renderObject! as RenderParagraph)
          .text
          .style
          ?.fontFamily,
      MlTokens.fontSerif,
    );
  });

  testWidgets('the company card spans the column', (tester) async {
    await pumpHub(tester);
    // The hub pads 16 each side, so a full-width card ends at 1584.
    final card = tester.getRect(find.ancestor(
      of: find.text('Fixture Haulage (Pty) Ltd'),
      matching: find.byType(MlCard),
    ));
    expect(card.right, closeTo(1584, 1.5),
        reason: 'company card ends at ${card.right}, not the column edge');
  });

  testWidgets('the create action sits beside the heading, not under it',
      (tester) async {
    await pumpHub(tester);
    final heading = tester.getRect(find.descendant(
      of: find.byType(MlSectionTitle),
      matching: find.text('Transactions'),
    ));
    final button = tester.getRect(find.text('Add transaction'));
    expect(button.right, greaterThan(1500),
        reason: 'action should be right-aligned, ends at ${button.right}');
    expect(button.top, lessThan(heading.bottom + 4),
        reason: 'action sits under the heading (top ${button.top} vs '
            'heading bottom ${heading.bottom})');
  });

  test('tab titles and dialog titles are sentence case', () {
    for (final tab in OperationsTab.values) {
      final label = tab.label;
      final words = label.split(' ');
      for (final w in words.skip(1)) {
        expect(w, isNot(matches(RegExp(r'^[A-Z][a-z]'))),
            reason: '"$label" is title case');
      }
    }
  });

  testWidgets('the empty state is the shared one', (tester) async {
    await pumpHub(tester);
    expect(find.byType(MlEmptyState), findsOneWidget);
    expect(find.text('No transactions yet'), findsOneWidget);
  });
}
