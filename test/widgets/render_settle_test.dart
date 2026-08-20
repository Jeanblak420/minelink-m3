// A render must not photograph an animation half way through.
//
// `pumpForCapture` is the settle schedule every golden in this project runs
// before the picture is taken, and it has now been too short TWICE. Both times
// the render looked entirely plausible, which is the whole problem:
//
//   1. **The scrollbar.** `RawScrollbar` fades in from a post-frame callback,
//      so a wide table's only affordance was captured at zero opacity. Pinned
//      in `wide_table_scrollbar_test.dart`, which counts thumb pixels.
//
//   2. **The count-up.** `MlStatCard.animateValue` runs `MlMotion.count`
//      (800ms) and it cannot START until the figure exists — which, for data
//      from a `FutureProvider`, is the second frame. The final pump was
//      `kScrollbarFade + 100` = 400ms, so it landed 50ms short. Measured
//      2026-08-20 on the supervisor's stockpiles: three piles whose fixture
//      values are 128.4, 18.0 and 412.6 photographed as **128.254, 17.98 and
//      412.131** — every one of them 99.886% of the real figure.
//
// A picture of a tonnage nobody entered is worse than no picture. This asserts
// the schedule outlasts the slowest thing the design system animates, using the
// same shape that broke it: a figure that arrives from a future.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/core/design/components/ml_components.dart';
import 'package:flutter_application_1/core/theme/app_theme.dart';

import '../test_helpers/real_fonts.dart';
import '../test_helpers/render_pumps.dart';

void main() {
  setUpAll(loadRealFonts);

  testWidgets('a count-up figure is settled before the picture is taken',
      (tester) async {
    tester.view.physicalSize = const Size(420, 200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // Arrives after the SECOND frame, which is where a provider chain actually
    // lands — a service call, a model parse, a rebuild. That is the case the
    // old schedule missed, and reproducing it is the whole difficulty: a figure
    // present on frame one starts its animation at t=0 and any schedule covers
    // it, which is why this fault only ever appeared on screens fed from the
    // network. 950ms puts the card's first build on `pumpForCapture`'s second
    // pump, exactly as the supervisor's stockpiles did.
    final value = Future<double>.delayed(
      const Duration(milliseconds: 950),
      () => 412.6,
    );

    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.darkTheme,
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 400,
            child: FutureBuilder<double>(
              future: value,
              builder: (context, snap) {
                if (!snap.hasData) {
                  return const SizedBox(height: 90);
                }
                return MlStatCard(
                  label: 'Stockpile balance',
                  value: '${snap.data!.toStringAsFixed(1)} t',
                  icon: Icons.layers_outlined,
                  animateValue: snap.data,
                  valueBuilder: (v) => '${v.toStringAsFixed(1)} t',
                );
              },
            ),
          ),
        ),
      ),
    ));

    await pumpForCapture(tester);

    expect(find.text('412.6 t'), findsOneWidget,
        reason: 'the count-up has not finished. `pumpForCapture` must outlast '
            'the SLOWEST animation the design system runs on arriving data — '
            'MlMotion.count, 800ms — and that animation starts on the frame '
            'the figure arrives, not the first frame. A schedule that stops '
            'early photographs a tween mid-flight, and the picture then shows '
            'a tonnage nobody entered.');
  });

  test('the schedule outlasts the longest animation it has to cover', () {
    // The arithmetic, stated once so a future edit to either end is checked
    // against the other rather than against a memory.
    expect(kCountUp.inMilliseconds, greaterThanOrEqualTo(800),
        reason: 'kCountUp is meant to be MlMotion.count. If that got longer, '
            'this constant and the final pump have to follow it.');
    expect(kCountUp, greaterThan(kScrollbarFade),
        reason: 'the final pump is sized to kCountUp precisely because it is '
            'the longer of the two. If the scrollbar fade ever overtakes it, '
            'the pump has to be sized to that instead.');
  });
}
