// The trip detail screen: a card that says what it is, and codes in the code
// face.
//
// Phase 3 mine-portal pass, 2026-08-23 (reviewer finding #44, verified in
// `screen-trip-detail-desktop-dark`).
//
// The plate at the top of this screen is already `MlType.code`, with a comment
// saying why: "a plate is a code, not a numeral". Two rows below it the
// WAYBILL NUMBER — `TRP-000123`, the transaction reference, the same string
// the recon table prints in JetBrainsMono — was PlusJakartaSans w600, and so
// was the net mass. The buyer's Loads & value table one route over prints
// `INV-2026-0001` and `34.90 t` in mono in the same product; a reference that
// reads in two faces is one reference and two products.
//
// The facts also sat in a hand-rolled `Container` repainting `MlCard`'s
// surface, radius and border by hand, with no heading at all — so the one
// panel on the screen floated under the plate unlabelled — and its single
// action was a stock `FilledButton.icon`, the same drift the Requests screen
// carried in this pass.

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:flutter_application_1/core/design/components/ml_components.dart';
import 'package:flutter_application_1/core/theme/app_theme.dart';
import 'package:flutter_application_1/features/auth/models/user_type.dart';
import 'package:flutter_application_1/features/portal/screens/portal_trip_detail_screen.dart';

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
      anonKey: 'trip-detail-faces-test',
    );
  });

  Future<void> pump(WidgetTester tester, {double width = 1600}) async {
    tester.view.physicalSize = Size(width, 1400);
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
          home: const Scaffold(
            body: PortalTripDetailScreen(tripId: 't-2'),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
  }

  /// The font family the text [t] is actually drawn in.
  String? familyOf(WidgetTester tester, String t) =>
      (find.text(t).evaluate().single.renderObject! as RenderParagraph)
          .text
          .style
          ?.fontFamily;

  testWidgets('the waybill number and the net mass are in the code face', (
    tester,
  ) async {
    await pump(tester);

    expect(
      familyOf(tester, 'TRP-000123'),
      MlTokens.fontMono,
      reason:
          'the recon table and the buyer\'s Loads & value print this exact '
          'reference in mono',
    );
    expect(familyOf(tester, '34.90 t'), MlTokens.fontMono);
  });

  // The GREEN case: the words are still words. Mono is for codes and figures,
  // not for everything in the value column — sweeping the whole column into
  // the code face would be a different fault of the same kind.
  testWidgets('the prose facts stay in the body face', (tester) async {
    await pump(tester);

    for (final prose in ['Chrome', 'Iron Hills Mining', 'Richards Bay']) {
      expect(
        familyOf(tester, prose),
        isNot(MlTokens.fontMono),
        reason: '"$prose" is a name, not a code',
      );
    }
  });

  testWidgets('the facts sit in a card that names itself', (tester) async {
    await pump(tester);

    expect(find.byType(MlCard), findsWidgets);
    expect(
      find.descendant(
        of: find.byType(MlCard),
        matching: find.text('Trip facts'),
      ),
      findsOneWidget,
      reason: 'the one panel on the screen had no heading at all',
    );
    expect(
      find.byType(MlSectionTitle),
      findsOneWidget,
      reason: 'and the heading is the shared one, not another hand-rolled Text',
    );
  });

  testWidgets('the waybill action is the product\'s button', (tester) async {
    await pump(tester);

    expect(find.text('View waybill'), findsOneWidget);
    expect(find.byType(MlButton), findsWidgets);
    expect(
      find.byType(FilledButton),
      findsNothing,
      reason: 'stock Material on a redesigned screen',
    );
  });
}
