// The mine's Buyers screen: a page head, and cards that are not all heroes.
//
// Phase 3 mine-portal pass, 2026-08-23 (reviewer findings #41 and #42, both
// verified in `screen-mine-buyers-desktop-dark`).
//
// 1. The page opened with `MlSectionTitle('Buyers', icon:, action:)` and a
//    hand-rolled `Text` under it — the exact shape `MlPageHeader` was written
//    to end. A section head is smaller, carries a section icon, and lays its
//    tools out by its own rules; the description was not part of the header at
//    all, so on a phone the meta and the button stacked left ABOVE a sentence
//    that belonged with the title.
//
// 2. `BuyerOverviewCard` wraps `OverviewHeroTile`, and the mine's Buyers
//    screen draws one per buyer in a three-column `Wrap`. Every card therefore
//    took the hero treatment — an accent gradient across the panel AND a cyan
//    cast shadow under it. Emphasis on everything is emphasis on nothing, and
//    §5.5 asks that a tone mean something. `muted` already existed and was
//    passed by nobody; it thinned the wash but the glow was drawn either way,
//    which is the louder half.
//
// The other eight `OverviewHeroTile` call sites really are single tiles on
// their screens ("Tons delivered", "Loading activity", "No stockpiles yet",
// the selected buyer's panel) and keep the full treatment — deliberately not
// re-skinned.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:flutter_application_1/core/design/components/ml_components.dart';
import 'package:flutter_application_1/core/theme/app_theme.dart';
import 'package:flutter_application_1/features/auth/models/user_type.dart';
import 'package:flutter_application_1/features/portal/screens/mine_supplier_buyers_detail_screen.dart';
import 'package:flutter_application_1/features/portal/widgets/premium_overview_widgets.dart';

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
      anonKey: 'mine-buyers-head-and-cards-test',
    );
  });

  Future<void> pumpScreen(WidgetTester tester, {double width = 1600}) async {
    tester.view.physicalSize = Size(width, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...companyScopeOverrides(
            role: UserRole.admin,
            orgType: OrgType.mineSupplier,
          ),
          ...portalCaptureOverrides(),
          ...portalTailOverrides(),
        ],
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: const Scaffold(body: MineSupplierBuyersDetailScreen()),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
  }

  Future<void> pumpTile(WidgetTester tester, {required bool muted}) async {
    tester.view.physicalSize = const Size(600, 600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 320,
              child: OverviewHeroTile(
                title: 'A tile',
                muted: muted,
                child: const Text('body'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  /// Every `BoxShadow` painted by the tile's own decoration.
  List<BoxShadow> tileShadows(WidgetTester tester) {
    final decorated = tester.widget<DecoratedBox>(
      find
          .descendant(
            of: find.byType(OverviewHeroTile),
            matching: find.byType(DecoratedBox),
          )
          .first,
    );
    return (decorated.decoration as BoxDecoration).boxShadow ??
        const <BoxShadow>[];
  }

  testWidgets('a muted tile casts no accent glow', (tester) async {
    await pumpTile(tester, muted: true);
    expect(
      tileShadows(tester),
      isEmpty,
      reason:
          'the wash AND the glow together are what say "this one". Thinning '
          'one and keeping the other still halos every card in a list',
    );
  });

  // The GREEN case: an UNmuted tile is still a hero and still glows. Eight
  // call sites depend on that and none of them was re-skinned.
  testWidgets('an unmuted tile still casts its glow', (tester) async {
    await pumpTile(tester, muted: false);
    expect(tileShadows(tester), isNotEmpty);
  });

  testWidgets('every buyer card is muted', (tester) async {
    await pumpScreen(tester);

    final cards = find.byType(BuyerOverviewCard);
    expect(
      tester.widgetList(cards).length,
      greaterThan(1),
      reason: 'one card cannot show that a repeated card is over-emphasised',
    );

    for (final tile in tester.widgetList<OverviewHeroTile>(
      find.descendant(of: cards, matching: find.byType(OverviewHeroTile)),
    )) {
      expect(
        tile.muted,
        isTrue,
        reason: '"${tile.title}" is one buyer of several, not the hero of the '
            'screen',
      );
    }
  });

  testWidgets('the page opens with a page header, not a section head', (
    tester,
  ) async {
    await pumpScreen(tester);

    final header = tester.widget<MlPageHeader>(find.byType(MlPageHeader));
    expect(header.title, 'Buyers');
    expect(
      header.description,
      'Tonnage shipped per buyer, with recons and invoicing.',
      reason: 'the sentence belongs to the header, so the header lays it out',
    );
    expect(header.meta, isNotNull);
    expect(header.actions, isNotEmpty);

    expect(
      find.descendant(
        of: find.byType(MlSectionTitle),
        matching: find.text('Buyers'),
      ),
      findsNothing,
      reason: 'a page title is not a section title',
    );
  });

  testWidgets('on a phone the meta is not stranded at the left margin', (
    tester,
  ) async {
    await pumpScreen(tester, width: 412);

    final title = tester.getRect(find.text('Buyers'));
    final meta = tester.getRect(find.text('2 buyers'));
    final action = tester.getRect(find.text('Request buyers'));
    final description = tester.getRect(
      find.text('Tonnage shipped per buyer, with recons and invoicing.'),
    );

    // Measured at 412px on 2026-08-23, both ways:
    //
    //            title              meta                action     description
    //   before   L48 T16 B42    L16  T62 B78       L276 T60.5    T94
    //   after    L16 T20 B52    L179 T28 B44       L276 T26.5    T60
    //
    // The meta at L16 under a title indented to L48 is the reviewer's
    // "phone meta/action stack left": `MlSectionTitle` puts its tools in a run
    // beneath the title at the LEFT, while the measuring `_HeaderLayout`
    // right-aligns them whether it stacks or not (`bcb0fdb`).
    expect(
      meta.left,
      greaterThan(title.right),
      reason:
          'the meta belongs at the right end of the header, not at the left '
          'margin under the title',
    );
    expect(
      meta.center.dy,
      inInclusiveRange(title.top, title.bottom),
      reason: 'at this width the tools fit beside the title, so they sit on '
          'its row',
    );
    expect(action.center.dy, inInclusiveRange(title.top, title.bottom));

    // A page title starts at the body's left margin. A section title is
    // indented by its icon well, which is how it read here (L48 vs L16).
    expect(
      title.left,
      description.left,
      reason: 'no section icon pushing the page title in',
    );

    expect(description.top, greaterThan(action.bottom));
  });
}
