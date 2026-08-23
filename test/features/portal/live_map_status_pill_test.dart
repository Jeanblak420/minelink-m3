// A status pill on the live map is drawn at the type scale's size, the plate
// beside it is never shortened, and every row in the list has one shape.
//
// Buyer pass, 2026-08-23 (reviewer finding #17, seen in
// `screen-live-trip-map-desktop-dark`).
//
// The trailing badge sat in `SizedBox(width: 112)` around a
// `FittedBox(fit: scaleDown)`, so a pill whose label did not fit 112px was
// SHRUNK. `EN ROUTE TO OFFLOAD` therefore rendered in visibly smaller type
// than the `LOADING` in the row beneath it — two pills, one list, two type
// sizes, decided by how long the words are. A fixed pixel box around text also
// undoes the reader's own text scale (§5.6, CLAUDE.md §10.4).
//
// Two more shapes had to be tried before the right one, and the test carries
// all three because each failure is a thing that could be reintroduced:
//
//   * dropping the `FittedBox` alone cost the IDENTITY instead — a full-size
//     pill left the `Expanded` too little in this ~330px panel and the plate
//     ellipsised to `JD 22 …`;
//   * `MlHeaderLayout` fixed both by measuring per row, and then two adjacent
//     rows with the SAME status laid out differently, because whether the row
//     fits comes down to how wide the transporter's name is.
//
// So the pill takes its own right-aligned line, always.

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:flutter_application_1/core/design/components/ml_components.dart';
import 'package:flutter_application_1/core/theme/app_theme.dart';
import 'package:flutter_application_1/features/auth/models/user_type.dart';
import 'package:flutter_application_1/features/portal/widgets/live_trip_map_view.dart';

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
      anonKey: 'live-map-status-pill-test',
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
          home: const Scaffold(body: LiveTripMapView(companyId: null)),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));
  }

  /// Every status pill's label paragraph, in list order.
  List<RenderParagraph> pills(WidgetTester tester) => [
    for (final e in find
        .descendant(
          of: find.byType(MlStatusBadge),
          matching: find.byType(RichText),
        )
        .evaluate())
      e.renderObject! as RenderParagraph,
  ];

  testWidgets('every pill in the list is drawn at the same height', (
    tester,
  ) async {
    await pump(tester);

    final badges = find.byType(MlStatusBadge);
    expect(
      badges.evaluate().length,
      greaterThan(1),
      reason: 'one pill cannot show that two disagree',
    );

    // HEIGHT, not the declared `fontSize`. A `FittedBox` scales the PAINTED
    // result and leaves the style alone, so comparing font sizes would have
    // passed with the fault in place — measured, 2026-08-23.
    final heights = {
      for (var i = 0; i < badges.evaluate().length; i++)
        double.parse(tester.getRect(badges.at(i)).height.toStringAsFixed(1)),
    };
    expect(
      heights.length,
      1,
      reason:
          'a pill scaled to fit a fixed box takes its drawn size from its own '
          'label length; these must all be the type scale\'s — got $heights',
    );
  });

  testWidgets('no pill is inside a FittedBox', (tester) async {
    await pump(tester);

    // Walk the whole ancestor chain, not just the immediate parent: the badge
    // puts several render objects between its text and whatever contains it,
    // and checking only `p.parent` passed with the FittedBox still there.
    for (final p in pills(tester)) {
      for (var n = p.parent; n != null; n = n.parent) {
        expect(
          n,
          isNot(isA<RenderFittedBox>()),
          reason:
              '"${p.text.toPlainText()}" is inside a FittedBox — its drawn '
              'size is a function of how long the words are',
        );
        if (n is RenderRepaintBoundary) break;
      }
    }
  });

  testWidgets('the plate is never shortened to make room', (tester) async {
    await pump(tester);

    final plates = find.descendant(
      of: find.byType(MlPlatePill),
      matching: find.byType(RichText),
    );
    expect(plates, findsWidgets);
    for (final e in plates.evaluate()) {
      final p = e.renderObject! as RenderParagraph;
      expect(
        p.didExceedMaxLines,
        isFalse,
        reason:
            '"${p.text.toPlainText()}" was truncated — a plate is which truck '
            'this is',
      );
    }
  });

  testWidgets('every row puts its pill on the same line, at every width', (
    tester,
  ) async {
    for (final width in const [1600.0, 412.0]) {
      await pump(tester, width: width);

      // The vertical gap between each row's plate and its pill. If one row
      // shares its line and another stacks, these differ.
      final offsets = <double>[];
      final badges = find.byType(MlStatusBadge);
      for (var i = 0; i < badges.evaluate().length; i++) {
        final badge = tester.getRect(badges.at(i));
        final plate = tester.getRect(find.byType(MlPlatePill).at(i));
        offsets.add(
          double.parse((badge.top - plate.top).toStringAsFixed(1)),
        );
      }
      expect(offsets.length, greaterThan(1));
      expect(
        offsets.toSet().length,
        1,
        reason:
            'at ${width.toInt()}px the rows disagree about where the pill '
            'goes: $offsets. Two rows with the same status laid out '
            'differently is what per-row measuring produced here',
      );
      expect(
        offsets.first,
        greaterThan(0),
        reason: 'the pill sits BELOW the plate, on its own line',
      );
    }
  });

  // The GREEN case: the pill is still right-aligned, not stranded at the left
  // margin, which is what a stacked run does unless it is told otherwise.
  testWidgets('the stacked pill is flush right', (tester) async {
    await pump(tester, width: 412);

    final badge = tester.getRect(find.byType(MlStatusBadge).first);
    final card = tester.getRect(
      find
          .ancestor(
            of: find.byType(MlStatusBadge).first,
            matching: find.byType(MlCard),
          )
          .first,
    );
    expect(badge.right, closeTo(card.right - 10, 12));
  });
}
