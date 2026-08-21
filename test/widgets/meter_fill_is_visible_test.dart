// Every meter in this product had a track, and two of them had no FILL.
//
// Found 2026-08-21 by measuring `screen-targets-org-type-desktop-dark.png`
// rather than looking at it. The "All months" row for Sep 2025 reads **82%**,
// and the 315px rail beside it was a single flat colour from end to end: the
// track painted, the 100% tick painted, and the bar that is the whole reason
// the row has a rail did not exist.
//
// THE MECHANISM, because it is not obvious and it will happen again:
//
//   * A `Stack` lays its NON-POSITIONED children out with LOOSE constraints.
//     So does an `Align`.
//   * A `FractionallySizedBox` that declares only a `widthFactor` tightens the
//     width and passes the height range **straight through** — loose stays
//     loose.
//   * A `DecoratedBox` / `ColoredBox` with no child is a `RenderProxyBox`, and
//     a childless `RenderProxyBox` takes `constraints.smallest`.
//
// Loose height + no child = **zero pixels tall**. It raises nothing, overflows
// nothing and fails no golden, because a zero-height box is a perfectly valid
// layout. Four other meters in the tree were correct only because their parent
// happened to be a `Container(height:)`, which tightens the constraint for
// them — an accident of composition, not a decision.
//
// The cure is one argument, `heightFactor: 1`, stated at every site so it
// survives the widget being moved somewhere looser. The source rule is held by
// `fractional-fill-declares-its-height` in `tool/release_guards.dart`; this
// file is the other half, because a grep proves the argument is written and
// only a measurement proves the pixels are there.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:flutter_application_1/core/theme/app_theme.dart';
import 'package:flutter_application_1/features/super_admin/screens/request_tracking_screen.dart';
import 'package:flutter_application_1/features/super_admin/screens/super_admin_org_insights_screen.dart';
import 'package:flutter_application_1/features/super_admin/screens/targets_platform_screen.dart';

import '../fixtures/console_capture_fixtures.dart';
import '../fixtures/portal_capture_fixtures.dart';
import '../fixtures/screen_fixtures.dart';
import '../test_helpers/real_fonts.dart';

void main() {
  setUpAll(() async {
    await loadRealFonts();
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'http://localhost:54321',
      anonKey: 'meter-fill',
    );
  });

  Future<void> pump(WidgetTester tester, Widget body, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        ...companyScopeOverrides(),
        ...consoleCaptureOverrides(),
        ...portalCaptureOverrides(),
      ],
      child: MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(body: body),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 900));
  }

  /// Every fill on screen, as `(width, height)`.
  ///
  /// `getSize` on the `FractionallySizedBox` itself is the right measurement:
  /// its own size is `constraints.constrain(child.size)`, so it reports what
  /// the fill actually came out as rather than what it was asked for.
  List<Size> fills(WidgetTester tester) => find
      .byType(FractionallySizedBox)
      .evaluate()
      .map((e) => tester.getSize(find.byElementPredicate((x) => x == e)))
      .toList();

  void expectEveryFillPainted(WidgetTester tester, String where) {
    final measured = fills(tester);
    expect(measured, isNotEmpty,
        reason: 'no meter fills were found on $where at all, so this test is '
            'measuring nothing. Either the fixture stopped producing rows or '
            'the meter was rebuilt out of a different widget.');
    final flat = measured.where((s) => s.height <= 0).toList();
    expect(flat, isEmpty,
        reason: '${flat.length} of ${measured.length} meter fills on $where '
            'are ZERO PIXELS TALL, so the bar shows a track and no reading. A '
            '`FractionallySizedBox` under a loose-height parent (a `Stack`\'s '
            'non-positioned child, or an `Align`) must state `heightFactor: 1` '
            'or its childless `DecoratedBox` takes `constraints.smallest`.');
  }

  testWidgets('the targets board draws its attainment bars', (tester) async {
    await pump(tester, const TargetsPlatformScreen(), const Size(1600, 2600));
    expectEveryFillPainted(tester, 'the targets board');
  });

  // The one that motivated the whole check: a row that says 82% next to a rail
  // that says nothing. The fill is a FRACTION of the track, so "painted" is not
  // enough — it has to be narrower than the rail it sits in, or the meter is
  // reporting 100% for every month on the board.
  testWidgets('and draws them at the width the percentage claims',
      (tester) async {
    await pump(tester, const TargetsPlatformScreen(), const Size(1600, 2600));
    final measured = fills(tester);
    final widths = measured.map((s) => s.width).toSet();
    expect(widths.length, greaterThan(1),
        reason: 'every attainment bar on the board is the same width, so the '
            'fill is not tracking the attainment it is drawn for. The board '
            'carries months at 74%, 100% and 117%.');
  });

  testWidgets('request tracking draws its completed-trips meter',
      (tester) async {
    await pump(tester, const RequestTrackingScreen(), const Size(1600, 1600));
    expectEveryFillPainted(tester, 'the request-tracking table');
  });

  testWidgets('org insights draws its rate meters', (tester) async {
    await pump(
      tester,
      const SuperAdminOrgInsightsScreen(orgType: 'transporter'),
      const Size(1600, 2400),
    );
    expectEveryFillPainted(tester, 'the org-insights board');
  });
}
