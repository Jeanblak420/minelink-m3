// Routes & mines: a page header, and one tone for one kind of thing.
//
// Buyer pass, 2026-08-23 (reviewer findings #8 and #9, both seen in
// `screen-buyer-routes-mines-desktop-dark`).
//
// 1. The page opened with `MlSectionTitle('Routes & Mines', icon:)` and a
//    hand-rolled `Text` under it — the shape `MlPageHeader` exists to end, and
//    the same one the mine's Buyers page carried until `06ecf4b`. "Routes &
//    Mines" was also the last title-case spelling of it: the nav label,
//    `ml_route_title.dart` and the legacy-label alias map all say "Routes &
//    mines". (That map's KEY is the legacy tab label and is deliberately left
//    alone — it is the seam, not the copy.)
//
// 2. Every route card's icon well took its tone from `_tones[i % 4]` —
//    accent, atMine, done, transit, cycled BY INDEX. Route 1 was cyan and
//    route 2 amber, and `atMine`'s amber means "pending at the mine" in this
//    product (CLAUDE.md §5), so the second route card said something about
//    itself that was not true and the colour carried no information at all.
//    §5.2 is one accent; §5.5 is that a tone must mean something. The "Linked
//    mines & suppliers" list directly below draws every partner in the same
//    well, which is the pattern.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:flutter_application_1/core/design/components/ml_components.dart';
import 'package:flutter_application_1/core/theme/app_theme.dart';
import 'package:flutter_application_1/features/auth/models/user_type.dart';
import 'package:flutter_application_1/features/portal/screens/buyer_routes_mines_screen.dart';

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
      anonKey: 'buyer-routes-mines-test',
    );
  });

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1600, 1600);
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
          home: const Scaffold(body: BuyerRoutesMinesScreen()),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
  }

  testWidgets('the page opens with a page header, in sentence case', (
    tester,
  ) async {
    await pump(tester);

    final header = tester.widget<MlPageHeader>(find.byType(MlPageHeader));
    expect(header.title, 'Routes & mines');
    expect(
      header.description,
      'All your purchase routes across mines and delivery points.',
      reason: 'the sentence belongs to the header that lays it out',
    );
    expect(
      find.text('Routes & Mines'),
      findsNothing,
      reason: 'the nav, the route title and the alias map all say "mines"',
    );
  });

  // The GREEN case: the section BELOW the page title is a real section and
  // stays a section head, icon and all. Promoting both would flatten the
  // hierarchy the fix exists to restore.
  testWidgets('the partner list is still a section, not a second page title', (
    tester,
  ) async {
    await pump(tester);

    expect(
      find.descendant(
        of: find.byType(MlSectionTitle),
        matching: find.text('Linked mines & suppliers'),
      ),
      findsOneWidget,
    );
    expect(find.byType(MlPageHeader), findsOneWidget);
  });

  testWidgets('every route card wears the same well', (tester) async {
    await pump(tester);

    final wells = tester
        .widgetList<MlIconWell>(find.byType(MlIconWell))
        .where((w) => w.icon == Icons.conveyor_belt)
        .toList();

    expect(
      wells.length,
      greaterThan(1),
      reason: 'one card cannot show that a list cycles its colours',
    );
    expect(
      wells.map((w) => w.tone).toSet(),
      {MlTone.accent},
      reason:
          'the wells cycled accent → atMine → done → transit by index, so the '
          'second route was amber: "pending at the mine", about a route',
    );
  });
}
