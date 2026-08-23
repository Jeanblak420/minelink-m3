// The Requests screen names the requests the org can actually raise, and its
// actions belong to its header.
//
// Phase 3 mine-portal pass, 2026-08-23 (reviewer finding #43, verified in the
// code and then in a render that did not exist — see below).
//
// `BuyerRequestsScreen` is shared: a buyer gets it plain, a mine gets it with
// `isMine: true`. Its own class doc says "buyers request products, mines
// request buyers", and §4 of CLAUDE.md is explicit — Request 2 (product) is
// BUYER ONLY, Request 3 (buyer) is MINE/SUPPLIER ONLY. The button under the
// header branched on `isMine` correctly. The sentence above it did not: both
// orgs read "Raise transportation and product requests", so the mine's screen
// named the one request type it cannot raise and omitted the one it can.
//
// And the two actions sat in a left `Wrap` BELOW the header as stock Material
// — a `FilledButton.tonalIcon` beside a `FilledButton.icon`, two button
// languages neither of which is this product's — while the header's own right
// end held only the meta.
//
// NO RENDER OF `isMine: true` EXISTED. `unphotographed_screens.py` counted the
// class as photographed because the name appears in the render file, which is
// the name-based limit its own header documents; every picture was the buyer.
// `screen-mine-requests-{desktop,phone}-dark` were added in the same commit,
// and they also photograph `_RequestCard`'s `'buyer'` branch for the first
// time.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:flutter_application_1/core/design/components/ml_components.dart';
import 'package:flutter_application_1/core/theme/app_theme.dart';
import 'package:flutter_application_1/features/auth/models/user_type.dart';
import 'package:flutter_application_1/features/portal/screens/buyer_requests_screen.dart';

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
      anonKey: 'requests-copy-and-actions-test',
    );
  });

  Future<void> pump(
    WidgetTester tester, {
    required bool isMine,
    double width = 1600,
  }) async {
    tester.view.physicalSize = Size(width, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...companyScopeOverrides(
            role: UserRole.admin,
            orgType: isMine ? OrgType.mineSupplier : OrgType.buyer,
          ),
          ...portalCaptureOverrides(),
          ...portalTailOverrides(),
        ],
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(body: BuyerRequestsScreen(isMine: isMine)),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
  }

  MlPageHeader header(WidgetTester tester) =>
      tester.widget<MlPageHeader>(find.byType(MlPageHeader).first);

  testWidgets('a mine is told it raises BUYER requests', (tester) async {
    await pump(tester, isMine: true);

    expect(header(tester).description, contains('buyer requests'));
    expect(
      header(tester).description,
      isNot(contains('product')),
      reason:
          'CLAUDE.md §4 Request 2 is buyer-only — a mine cannot raise a '
          'product request, and the button beside this sentence already knew '
          'that',
    );
    expect(find.text('Request buyers'), findsOneWidget);
    expect(find.text('Request products'), findsNothing);
  });

  // The GREEN case: the buyer's own copy was right and must stay right. This
  // is the half a careless `isMine` branch would have broken.
  testWidgets('a buyer is still told it raises PRODUCT requests', (
    tester,
  ) async {
    await pump(tester, isMine: false);

    expect(header(tester).description, contains('product requests'));
    expect(header(tester).description, isNot(contains('buyer requests')));
    expect(find.text('Request products'), findsOneWidget);
    expect(find.text('Request buyers'), findsNothing);
  });

  testWidgets('both actions live in the page header, in the product\'s own '
      'button language', (tester) async {
    for (final isMine in [true, false]) {
      await pump(tester, isMine: isMine);

      expect(
        header(tester).actions.length,
        2,
        reason: 'the screen-level actions belong to the screen-level header',
      );
      for (final w in header(tester).actions) {
        expect(w, isA<MlButton>());
      }

      // `FilledButton.tonalIcon` and `FilledButton.icon` both build a
      // `FilledButton`; `MlButton` does not.
      expect(
        find.byType(FilledButton),
        findsNothing,
        reason: 'stock Material buttons, in two different languages, next to '
            'each other (isMine: $isMine)',
      );
    }
  });

  /// The fill `MlButton` actually paints for the button labelled [label].
  ///
  /// `MlButton._kind` is private and so is its enum, so the variant cannot be
  /// read off the widget — but the colour it paints can, and that is the thing
  /// a reader sees anyway.
  Color? fillOf(WidgetTester tester, String label) {
    final container = tester.widget<AnimatedContainer>(
      find
          .ancestor(
            of: find.text(label),
            matching: find.byType(AnimatedContainer),
          )
          .first,
    );
    return (container.decoration as BoxDecoration?)?.color;
  }

  testWidgets('the transportation action is the quieter of the two', (
    tester,
  ) async {
    await pump(tester, isMine: true);

    final actions = header(tester).actions.cast<MlButton>();
    expect(actions.first.label, 'Request transportation');
    expect(
      actions.last.label,
      'Request buyers',
      reason:
          'the org-specific action keeps the right edge it already had, which '
          'is where the Buyers page puts its single primary too',
    );

    // And it is quieter, not merely earlier. `MlButton.primary` fills with the
    // accent; `MlButton.tonal` fills with the card surface.
    expect(
      fillOf(tester, 'Request buyers'),
      MlTokens.accent,
      reason: 'the org-specific action is the primary one',
    );
    expect(
      fillOf(tester, 'Request transportation'),
      isNot(MlTokens.accent),
      reason:
          'two accent-filled buttons side by side is the same "everything is '
          'emphasised" fault as the buyer cards on the Buyers page',
    );
  });
}
