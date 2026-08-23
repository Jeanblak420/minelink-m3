// The Search loads screen speaks the reference's vocabulary.
//
// Phase 3 mine-portal pass, 2026-08-23. This was the one mine screen still
// in the pre-redesign language end to end: five cyan-gradient `_SummaryBox`
// tiles with letter badges (the accent spent five times where the reference
// spends it once), a 14px sans ExtraBold "Filters" heading, a page titled
// "Tons out" under a rail entry reading "Search loads", a Material DataTable
// with sans-ExtraBold title-case heads ("Truck Reg No", "Net Mass") on an
// accent-tinted band, plates in body sans, the mass cell in a peach tint, and
// a `minWidth` floor of the WINDOW width that scrolled the Net mass column
// out of a 1600px desktop. Two reviewers, six findings.

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:flutter_application_1/core/design/components/ml_components.dart';
import 'package:flutter_application_1/core/theme/app_theme.dart';
import 'package:flutter_application_1/features/auth/models/user_type.dart';
import 'package:flutter_application_1/features/portal/screens/portal_tons_out_search_screen.dart';

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
      anonKey: 'search-loads-vocabulary-test',
    );
  });

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1600, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        ...companyScopeOverrides(
            role: UserRole.admin, orgType: OrgType.mineSupplier),
        ...portalCaptureOverrides(),
      ],
      child: MaterialApp(
        theme: AppTheme.darkTheme,
        home: const Scaffold(body: PortalTonsOutSearchScreen()),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
  }

  String? family(Element e) =>
      (e.renderObject! as RenderParagraph).text.style?.fontFamily;

  testWidgets('the page is titled as the rail names it, and Filters is a '
      'section title', (tester) async {
    await pump(tester);
    expect(find.text('Search loads'), findsOneWidget);
    expect(find.text('Tons out'), findsNothing);
    expect(family(find.text('Filters').evaluate().single), MlTokens.fontSerif,
        reason: '"Filters" is not in the display face');
  });

  testWidgets('the five windows are reference stat cards', (tester) async {
    await pump(tester);
    expect(find.byType(MlStatCard), findsNWidgets(5));
    for (final label in const ['Day', 'Week', 'Month', 'Year', 'Total']) {
      expect(find.text(label), findsWidgets, reason: '"$label" card missing');
    }
    // The old letter badges are gone.
    expect(find.text('D'), findsNothing);
    expect(find.text('Last 24h'), findsNothing);
  });

  testWidgets('the table heads are uppercase, sentence-cased, and name the '
      'check-out clock', (tester) async {
    await pump(tester);
    for (final head in const ['TIME OUT', 'TRUCK REG', 'NET MASS']) {
      expect(find.text(head), findsOneWidget, reason: '"$head" head missing');
    }
    for (final stale in const ['Time', 'Truck Reg No', 'Net Mass']) {
      expect(find.text(stale), findsNothing, reason: '"$stale" is back');
    }
  });

  testWidgets('plates are pills and the mass is a mono figure with its unit',
      (tester) async {
    await pump(tester);
    expect(find.byType(MlPlatePill), findsWidgets);
    // Inside the table — the stat cards above it carry Fraunces tonnages.
    final mass = find
        .descendant(
          of: find.byType(DataTable),
          matching: find.textContaining(RegExp(r'^\d+\.\d\d t$')),
        )
        .evaluate();
    expect(mass, isNotEmpty, reason: 'no mass cell rendered');
    for (final e in mass) {
      expect(family(e), MlTokens.fontMono,
          reason: '"${(e.widget as Text).data}" is not mono');
    }
  });

  testWidgets('the Net mass column is on the canvas at 1600px', (tester) async {
    await pump(tester);
    final head = tester.getRect(find.text('NET MASS'));
    expect(head.right, lessThan(1600),
        reason: 'NET MASS head ends at ${head.right} — off the canvas');
  });
}
