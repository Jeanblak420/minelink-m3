// The Locations screen's two cards head themselves in the display face, and
// the anchor names are sentence case.
//
// Phase 3 mine-portal pass, 2026-08-23. "Mine anchor points" and "Locations"
// were hand-built icon-well rows with 16px sans ExtraBold titles and no meta
// line; below 420px the Locations card dropped "Add location" to the far
// LEFT while the anchor rows' Edit / Set up stacked RIGHT (three reviewers).
// And `MineLocationType.label` read "Main Gate" / "Loading Point" — title
// case, in a product that cases every label as a sentence.

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:flutter_application_1/core/design/components/ml_components.dart';
import 'package:flutter_application_1/core/theme/app_theme.dart';
import 'package:flutter_application_1/features/auth/models/user_type.dart';
import 'package:flutter_application_1/features/portal/models/mine_location.dart';
import 'package:flutter_application_1/features/portal/screens/mine_locations_screen.dart';

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
      anonKey: 'mine-locations-heads-test',
    );
  });

  Future<void> pump(WidgetTester tester, {double width = 1600}) async {
    tester.view.physicalSize = Size(width, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        ...companyScopeOverrides(
            role: UserRole.admin, orgType: OrgType.mineSupplier),
        ...portalCaptureOverrides(),
        ...portalTailOverrides(),
      ],
      child: MaterialApp(
        theme: AppTheme.darkTheme,
        home: const Scaffold(body: MineLocationsScreen()),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
  }

  /// The family of the section-title heading reading [text] (the page
  /// header also says Locations, so the plain finder is ambiguous).
  String? family(String text) => (find
          .descendant(of: find.byType(MlSectionTitle), matching: find.text(text))
          .evaluate()
          .single
          .renderObject! as RenderParagraph)
      .text
      .style
      ?.fontFamily;

  testWidgets('both card headings are section titles in Fraunces',
      (tester) async {
    await pump(tester);
    for (final h in const ['Mine anchor points', 'Locations']) {
      expect(find.descendant(
          of: find.byType(MlSectionTitle), matching: find.text(h)),
          findsOneWidget, reason: '"$h" is not a section title');
      expect(family(h), MlTokens.fontSerif, reason: '"$h" is not Fraunces');
    }
    // The anchor card carries a meta line; the saved-point count stays on
    // the page header alone, once.
    // The count agrees with the CONFIGURED badges — a pinned anchor, not a
    // row. The fixture pins one of three.
    final configured = find.text('CONFIGURED').evaluate().length;
    expect(find.text('$configured of 3 set'), findsOneWidget);
    expect(find.textContaining(RegExp(r'^\d+ saved points?$')), findsOneWidget);
  });

  testWidgets('on a phone, Add location sits at the RIGHT of its row',
      (tester) async {
    await pump(tester, width: 360);
    final button = tester.getRect(find.text('Add location'));
    // The card pads 20 inside a 16px page gutter; flush right is ≥ 300.
    expect(button.right, greaterThan(300),
        reason: 'Add location ends at ${button.right} of 360');
  });

  test('anchor names are sentence case', () {
    expect(MineLocationType.mainGate.label, 'Main gate');
    expect(MineLocationType.loadingPoint.label, 'Loading point');
    expect(MineLocationType.weighbridge.label, 'Weighbridge');
  });
}
