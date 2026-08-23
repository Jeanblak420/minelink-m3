// An available-route chip that cannot fit ellipsises; it is not cut.
//
// Buyer pass, 2026-08-23 (reviewer finding #5, seen in
// `screen-buyer-requests-phone-dark` and three more phone goldens — this
// section is mirrored on the mine's and buyer's Requests screens and on both
// dashboards).
//
// The chip read `RT-0042 · Iron Hills Mining → Richards Bay · perm`, truncated
// mid-word with nothing to say so.
//
// ## It is NOT the `Wrap` trap it looks like
//
// The obvious reading is CLAUDE.md §10.4 — a child laid out against unbounded
// width, so `TextOverflow.ellipsis` never engages. That was the first fix
// written here, a `ConstrainedBox` per chip inside a `LayoutBuilder`, and
// MEASUREMENT SHOWED IT WAS A NO-OP: `RenderWrap` bounds its children to the
// row already, and the chip lays out at 33..379 inside a card at 16..396 with
// or without it. The geometry never moved, and the first version of this test
// — which asserted on that geometry — passed with the "fix" taken back out.
//
// What overran was the LABEL inside the correctly-bounded chip. With no
// `maxLines`/`overflow`, `Chip` clips its label rather than shortening it, and
// clipping is silent: no overflow stripe, nothing for a layout sweep to catch,
// and the label's own `RenderParagraph` reports a width that fits.
//
// So what is asserted here is the RENDERED fact that the label was shortened —
// `didExceedMaxLines` — and not a rectangle that was always correct.

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/core/design/components/ml_components.dart';
import 'package:flutter_application_1/core/theme/app_theme.dart';
import 'package:flutter_application_1/features/portal/widgets/available_routes_section.dart';

import '../../fixtures/portal_capture_fixtures.dart';
import '../../fixtures/portal_tail_fixtures.dart';
import '../../test_helpers/real_fonts.dart';
import '../../test_helpers/frozen_clock.dart';

void main() {
  setUpAll(() async {
    freezeCaptureClock();
    await loadRealFonts();
  });

  /// The section at [width], inside the horizontal padding `MlPageBody` gives
  /// it on a real screen — without which the card is the whole viewport and
  /// nothing is ever tight enough to truncate.
  Future<void> pump(WidgetTester tester, {required double width}) async {
    tester.view.physicalSize = Size(width, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [...portalCaptureOverrides(), ...portalTailOverrides()],
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: const Scaffold(
            body: SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: AvailableRoutesSection(
                  companyId: 'co-buyer',
                  enabled: true,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
  }

  /// Every chip label, as the framework actually laid it out.
  List<RenderParagraph> chipLabels(WidgetTester tester) => [
    for (final e in find
        .descendant(
          of: find.byType(ActionChip),
          matching: find.byType(RichText),
        )
        .evaluate())
      e.renderObject! as RenderParagraph,
  ];

  testWidgets('a label too long for its chip is ellipsised, not clipped', (
    tester,
  ) async {
    await pump(tester, width: 412);

    final labels = chipLabels(tester);
    expect(
      labels.length,
      greaterThan(1),
      reason: 'the fixture has to supply more than one route',
    );

    final long = labels.firstWhere(
      (p) => p.text.toPlainText().contains('permanent'),
      orElse: () =>
          throw StateError('no route long enough to truncate at 412px'),
    );
    expect(
      long.didExceedMaxLines,
      isTrue,
      reason:
          'the label wants 284px in a chip that can give it less; without '
          'maxLines/overflow the Chip clips it mid-word and says nothing',
    );
  });

  // The GREEN case: a label that FITS is left alone. A test that only checked
  // "the long one is truncated" would pass if every label were truncated.
  testWidgets('a label that fits is not shortened', (tester) async {
    await pump(tester, width: 412);

    final short = chipLabels(
      tester,
    ).firstWhere((p) => !p.text.toPlainText().contains('permanent'));
    expect(short.didExceedMaxLines, isFalse);
  });

  // And on a desktop nothing is truncated at all.
  testWidgets('at 1600px every label is drawn whole', (tester) async {
    await pump(tester, width: 1600);
    for (final p in chipLabels(tester)) {
      expect(
        p.didExceedMaxLines,
        isFalse,
        reason: '"${p.text.toPlainText()}" has room here',
      );
    }
  });

  // The chip GEOMETRY was always right, and this records that so the no-op
  // constraint is not reinvented: every chip sits inside its card at every
  // width, with nothing of ours bounding it.
  for (final width in const [412.0, 360.0, 1600.0]) {
    testWidgets('the chip itself never left its card at ${width.toInt()}px', (
      tester,
    ) async {
      await pump(tester, width: width);

      final chips = find.byType(ActionChip);
      final card = tester.getRect(
        find.ancestor(of: chips.first, matching: find.byType(MlCard)).first,
      );
      for (var i = 0; i < chips.evaluate().length; i++) {
        final chip = tester.getRect(chips.at(i));
        expect(chip.right, lessThanOrEqualTo(card.right + 0.5));
        expect(chip.left, greaterThanOrEqualTo(card.left - 0.5));
      }
    });
  }
}
