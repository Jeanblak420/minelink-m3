// `MlSectionHead` must never ellipsise its own heading.
//
// The console's first band read **"Live operations by organization ty…"** at a
// ~500px viewport, driven in a browser on 2026-08-21. The trailing meta/link
// column is unflexed on purpose — a short right-aligned block given `flex: 1`
// lands mid-row instead of at the edge (CLAUDE.md §10.4) — so when it does not
// fit beside the title, the title's `Flexible` is what gives way.
//
// The decision to stack instead was `c.maxWidth < 420 * scale`, and 420 is a
// number somebody chose. That is wrong for any title longer than the one it
// was chosen for, and the failure lives in a BAND rather than at the small
// end: at 412 the header stacked and read perfectly; at 500 it did not stack
// and cut a heading. Sweeping narrower and narrower never reaches a band.
//
// So the sweep here goes UP as well as down, and the assertion is on the
// heading itself rather than on the absence of an overflow — a truncation is a
// valid layout and throws nothing.
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/core/design/tokens/ml_surface_tokens.dart';
import 'package:flutter_application_1/core/theme/app_theme.dart';
import 'package:flutter_application_1/features/super_admin/widgets/insights_v2/minelink_screens_core.dart';

import '../test_helpers/real_fonts.dart';

/// Every `RenderParagraph` under [of] that had to truncate.
///
/// `toPlainText()` returns the WHOLE string whichever part of it was drawn, so
/// it cannot see a truncation — `didExceedMaxLines` is the only thing that can
/// (handoff §5), and it is what the render harness's cut-off report is built
/// on.
List<String> _truncated(WidgetTester tester) {
  final out = <String>[];
  void walk(RenderObject node) {
    if (node is RenderParagraph &&
        node.hasSize &&
        !node.debugNeedsLayout &&
        node.didExceedMaxLines) {
      out.add(node.text.toPlainText());
    }
    node.visitChildren(walk);
  }

  walk(tester.binding.rootElement!.renderObject!);
  return out;
}

Future<void> _pump(
  WidgetTester tester,
  double width, {
  double textScale = 1.0,
  String? badgeless,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.build(Brightness.dark),
      home: MediaQuery(
        data: MediaQueryData(
          size: Size(width, 900),
          textScaler: TextScaler.linear(textScale),
        ),
        child: Scaffold(
          body: SizedBox(
            width: width,
            child: MlSectionHead(
              tokens: MlGlass.dark,
              title: badgeless ?? 'Live operations by organization type',
              subtitle: 'Tap a card to drill into company-level monthly '
                  'rollups this calendar month.',
              meta: 'This month · Aug 2026',
              link: 'View insights',
              onLink: () {},
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadRealFonts);

  // The band the old constant sat inside, plus either side of it.
  //
  // **452 is the one that matters**, and it was measured off the browser
  // screenshot rather than assumed: at a 500px viewport the page gutters are
  // 24 a side, so the header gets 452 — not the 468 an earlier version of this
  // file guessed, which is wide enough that the title fits and the test proved
  // nothing. The pixels: title ink ran x 25..335 ending in an ellipsis, and
  // the trailing block sat at x 352..475, i.e. 124px wide.
  const widths = <double>[
    360, 412, 440, 452, 468, 500, 560, 640, 820, 1240, 1560,
  ];

  for (final width in widths) {
    for (final scale in <double>[1.0, 1.3, 2.0]) {
      testWidgets('the heading is whole at ${width.toInt()}px x $scale',
          (tester) async {
        await _pump(tester, width, textScale: scale);

        expect(
          _truncated(tester),
          isNot(contains('Live operations by organization type')),
          reason: 'the section heading was ellipsised at ${width}px — the '
              'trailing block is unflexed, so the title is what gives way, '
              'and the header should have stacked instead',
        );
      });
    }
  }

  // ── The stacking decision itself ────────────────────────────────────────
  //
  // The sweep above asserts the USER-VISIBLE property — the heading is never
  // cut — and that is the right thing to assert. But it cannot see the
  // stacking decision on its own, and finding that out is worth recording:
  // reverting the measurement to the old `c.maxWidth < 420` left the sweep
  // GREEN, because `maxLines: 2` lets the squeezed title wrap instead of
  // ellipsising. Two changes went in together and each hid the other's
  // regression from that assertion.
  //
  // So the decision gets its own pair, in both directions. Reverting the
  // measurement fails the first; reverting it also un-stacks a header that
  // has no room, which is what put four lines of heading into a column 130px
  // wide before anyone measured it.
  testWidgets('a LONG title moves its meta BELOW at 452px — the width a '
      '500px viewport really leaves, and the one that was cut in the browser',
      (t) async {
    await _pump(t, 452);

    // HORIZONTAL position, not vertical. Comparing `meta.top` to
    // `title.bottom` looks like the obvious test and proves nothing: the
    // title block also holds a two-line subtitle, so an un-stacked trailing
    // column sits below the TITLE's baseline while still being beside the
    // block. That version passed against the very constant it was written to
    // catch.
    //
    // Stacked, the trailing column is `CrossAxisAlignment.start` and begins at
    // the left edge. Beside, it is right-aligned and begins past the title.
    final meta = t.getRect(find.text('This month · Aug 2026'));
    expect(
      meta.left,
      lessThan(40),
      reason: 'at 452 the title needs the whole row — 318 for the title, 16 '
          'of gap and 124 for the trailing block is 458 — so the meta should '
          'have moved underneath and started at the left edge. It is at '
          '${meta.left.round()}px, i.e. still beside the title, which is what '
          'squeezed the heading. 420 was a guessed constant and 452 is not '
          'below it.',
    );
  });

  testWidgets('a SHORT title still keeps its meta on the same row', (t) async {
    // Stacking is a cost — it spends a line. The measurement has to buy that
    // line only when it is needed, or every header in the console grows by one
    // and the fix is worse than the fault.
    await _pump(t, 640, badgeless: 'Fleet');

    final title = t.getRect(find.text('Fleet'));
    final meta = t.getRect(find.text('This month · Aug 2026'));
    expect(
      meta.left,
      greaterThan(title.right),
      reason: 'a short title leaves room beside it; stacking there would '
          'spend a line for nothing',
    );
  });
}
