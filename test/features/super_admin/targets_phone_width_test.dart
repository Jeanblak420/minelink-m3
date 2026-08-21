// The targets board on a phone, which nothing had ever rendered.
//
// It had been photographed only at 1600px, and at 412 it produced **22 layout
// overflows** and a header reading `Plat…`. Two faults, both of the shape
// CLAUDE.md §10.4 names, both invisible to every sweep in the tree:
//
//   * The "All months" table laid four `Expanded` columns straight into the
//     page with no minimum. At 412px the ATTAINMENT cell had 118.8px for
//     content needing 154.9 (a bar, `117%`, and a `SURPASSED` badge) and the
//     locked TARGET field had 46px for 55.2. It is the same disease as the
//     organizations registry beside it, and it has the same cure: `MlWideTable`
//     scrolls the table sideways rather than compressing it.
//
//   * `TargetsBand` put the title in a `Flexible` and the two scope tags
//     unflexed, so a Row handed the tags their natural width and cut the
//     screen's own name to four characters — "Plat…" against 190px of
//     decoration reading PLATFORM-WIDE and CYCLE LOCKED.
//
// Neither raises anything a person would see as an error. The first is a
// RenderFlex overflow, which paints a stripe in debug and is silently clipped
// in a release build; the second is an ellipsis, which is a layout that fits.
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:flutter_application_1/core/design/components/ml_components.dart';
import 'package:flutter_application_1/core/theme/app_theme.dart';
import 'package:flutter_application_1/features/super_admin/screens/targets_platform_screen.dart';
import 'package:flutter_application_1/features/super_admin/screens/targets_org_type_screen.dart';
import 'package:flutter_application_1/features/super_admin/screens/targets_company_screen.dart';
import 'package:flutter_application_1/features/super_admin/widgets/targets/targets_chrome.dart';

import '../../fixtures/console_capture_fixtures.dart';
import '../../fixtures/portal_capture_fixtures.dart';
import '../../fixtures/screen_fixtures.dart';
import '../../test_helpers/real_fonts.dart';

void main() {
  setUpAll(() async {
    await loadRealFonts();
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'http://localhost:54321',
      anonKey: 'targets-phone',
    );
  });

  /// Pumps the board and returns every overflow the framework reported.
  ///
  /// The messages are captured rather than left to `FlutterError.onError`,
  /// because the binding's handler records the FIRST exception and re-throws it
  /// at the end of the test — so all a plain pump tells you is that something
  /// overflowed once, not that it happened twenty-two times.
  ///
  /// The handler is restored before returning, NOT in an `addTearDown`. Tear-
  /// downs run after the body's `expect`s, and the binding asserts on any
  /// `expect` raised while its own handler is displaced:
  /// *"A test overrode FlutterError.onError but either failed to return it to
  /// its original state…"*, which times the whole file out at ten minutes.
  Future<List<String>> pumpBoard(
    WidgetTester tester,
    double width, {
    Widget board = const TargetsPlatformScreen(),
  }) async {
    final overflows = <String>[];
    final previous = FlutterError.onError;
    FlutterError.onError = (details) {
      final message = details.exception.toString();
      if (message.contains('overflowed')) {
        overflows.add(message.split('\n').first);
      } else {
        previous?.call(details);
      }
    };

    tester.view.physicalSize = Size(width, 4200);
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
        home: Scaffold(body: board),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 900));
    FlutterError.onError = previous;
    return overflows;
  }

  bool isTruncated(WidgetTester tester, String text) {
    final elements = find.text(text).evaluate();
    expect(elements, isNotEmpty, reason: '"$text" is not on the board.');
    return elements
        .map((e) => (e.renderObject! as RenderParagraph).didExceedMaxLines)
        .any((t) => t);
  }

  for (final width in const [360.0, 412.0]) {
    testWidgets('nothing overflows at ${width.toInt()}px', (tester) async {
      final overflows = await pumpBoard(tester, width);
      expect(overflows, isEmpty,
          reason: 'the board overflows ${overflows.length} time(s) at '
              '${width.toInt()}px. The "All months" table is being compressed '
              'into the width instead of scrolling: MlWideTable(minWidth:) is '
              'what keeps its columns at the width they need.');
    });

    testWidgets('the board still says which board it is at ${width.toInt()}px',
        (tester) async {
      await pumpBoard(tester, width);
      expect(isTruncated(tester, 'Platform targets'), isFalse,
          reason: 'the title is cut. It was a `Flexible` next to two unflexed '
              'scope tags, so the tags kept their width and the screen lost '
              'its name — "Plat…". The tags belong on their own line.');
      // The tags must survive the reflow: dropping them would be the other
      // wrong answer to the same problem.
      expect(find.text('PLATFORM-WIDE'), findsOneWidget);
    });

    testWidgets('the month table scrolls at ${width.toInt()}px', (tester) async {
      await pumpBoard(tester, width);
      expect(find.byType(MlWideTable), findsWidgets,
          reason: 'the month table is laid straight into the panel again. A '
              'scrollbar is also the only thing that tells a reader ATTAINMENT '
              'exists past the right edge.');
      // The month is the leftmost column and must be readable whole — it is
      // the row's identity.
      expect(isTruncated(tester, 'Aug 2026'), isFalse);
    });
  }

  // -------------------------------------------------------------------------
  // THE OTHER TWO SCOPES, photographed for the first time 2026-08-21.
  //
  // The platform board is the one scope with NO selector, so everything below
  // is a fault the platform board could not have. All three were found in the
  // pictures and none of them failed anything.
  // -------------------------------------------------------------------------

  /// The longest real organisation name in the registry fixture. It is both a
  /// pill in the by-company picker and the band's own title, which is what
  /// makes it the right string to test with.
  const longCompany = 'Consolidated Mineral Offtake & Logistics Holdings';

  for (final width in const [360.0, 412.0]) {
    testWidgets('the by-company picker stays inside the panel at '
        '${width.toInt()}px', (tester) async {
      final overflows = await pumpBoard(tester, width,
          board: const TargetsCompanyScreen(companyId: 'o4'));
      expect(overflows, isEmpty,
          reason: 'the company picker overflows ${overflows.length} time(s). '
              'A `TargetsScopePill` lays its label Column out unflexed inside '
              'a Row, so the Row hands it UNBOUNDED width and a long '
              'organisation name runs straight off the end of the Wrap — '
              'CLAUDE.md §10.4. Measured at 412px: 37px over.');
    });

    testWidgets('and the board still names the company at ${width.toInt()}px',
        (tester) async {
      await pumpBoard(tester, width,
          board: const TargetsCompanyScreen(companyId: 'o4'));
      expect(isTruncated(tester, '$longCompany targets'), isFalse,
          reason: 'the by-company title is cut. `overflow: ellipsis` with no '
              '`maxLines` truncates a paragraph to ONE line, so this read '
              '"Consolidated Mineral Offta…" — losing the rest of the name '
              'AND the word "targets", on the only screen where either '
              'appears. It has to wrap, with no line cap: two lines is enough '
              'at 412px and not at 360.');
      // Wrapping, not shrinking: a title squeezed onto one line by a smaller
      // face would pass the check above and be just as unreadable.
      expect(
        tester.getRect(find.text('$longCompany targets')).height,
        greaterThan(40),
        reason: 'the title is on one line at ${width.toInt()}px, which this '
            'name cannot fit onto.',
      );
    });

    testWidgets('the org-type switch puts its label above the pills at '
        '${width.toInt()}px', (tester) async {
      final overflows = await pumpBoard(tester, width,
          board:
              const TargetsOrgTypeScreen(orgType: TargetOrgType.transporter));
      expect(overflows, isEmpty, reason: 'the org-type switch overflows.');

      // The label sits ABOVE the pills, not beside them: `Row[label, gap,
      // Expanded(Wrap)]` leaves 266px for three pills at 412, so they stack
      // three deep and the vertically-centred label floats in dead space.
      final label = tester.getRect(find.text('ORG TYPE'));
      final firstPill = tester.getRect(find.text('Mines / Suppliers'));
      expect(label.bottom, lessThanOrEqualTo(firstPill.top),
          reason: 'ORG TYPE is still beside the pills at ${width.toInt()}px. '
              '`TargetsSelectorField` stacks below 560px.');
      expect(label.left, lessThan(60),
          reason: 'the stacked label should start at the panel edge.');
    });
  }

  testWidgets('and the org-type switch stays a ROW on a console', (tester) async {
    await pumpBoard(tester, 1600,
        board: const TargetsOrgTypeScreen(orgType: TargetOrgType.transporter));
    final label = tester.getRect(find.text('ORG TYPE'));
    final firstPill = tester.getRect(find.text('Mines / Suppliers'));
    expect(label.bottom, greaterThan(firstPill.top),
        reason: 'the label dropped onto its own line at 1600px, where three '
            'pills and a caption fit on one comfortably. Stacking everywhere '
            'is not the fix; stacking when the row stops working is.');
    expect(find.byType(TargetsSelectorField), findsOneWidget);
  });

  testWidgets('and it does NOT scroll on a console-width window',
      (tester) async {
    // A scrollbar over content that fits is a promise of more. ~589px is what
    // the columns need at text scale 1.0; a 1600px console is far above it.
    await pumpBoard(tester, 1600);
    expect(find.byType(Scrollbar), findsNothing,
        reason: 'the board is scrolling at 1600px, so the declared minimum has '
            'grown past what the four columns actually need.');
  });
}
