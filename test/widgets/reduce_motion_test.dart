// Does the app actually stop moving when the user asks it to?
//
// `MediaQuery.disableAnimations` is what an operating system's "reduce motion"
// accessibility setting turns into, and MineLink has three kinds of animation
// that answer to it differently:
//
//   1. ONE-SHOT transitions — a hover lift, a card expanding, a modal. These
//      go through `MlMotion.of`, which collapses the duration to 1ms. Never to
//      zero: a zero-duration controller notifies its listeners SYNCHRONOUSLY,
//      and `AnimatedSize` then calls `markNeedsLayout()` from inside its own
//      `performLayout` (CLAUDE.md §10.4).
//
//   2. COUNT-UPS — a tonnage spinning from 0. Same treatment; the figure
//      simply appears at its value.
//
//   3. LOOPS — a pulsing dot, typing dots, a shaking bell. **These cannot be
//      shortened.** Collapsing a 1200ms loop to 1ms runs it at a thousand
//      frames a second, which is worse than leaving it alone. The only correct
//      answer for a loop is not to start it, and to render a settled frame.
//
// The third kind is what this file is really for. Three loops were running
// unguarded, and all three are somewhere a user cannot get away from:
//
//   * the notification bell in the app bar of EVERY screen, which shakes on
//     arrival and then re-shakes every 30 seconds for as long as anything is
//     unread;
//   * the typing dots in the chat dock, which both shells mount on every
//     screen;
//   * the pulsing dot marking the current waypoint, which is on a driver's
//     screen for the whole of a haul.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/core/design/components/ml_components.dart';
import 'package:flutter_application_1/core/design/tokens/m3/ml_motion.dart';
import 'package:flutter_application_1/core/theme/app_theme.dart';
import 'package:flutter_application_1/features/portal/widgets/waypoint_progress_bar.dart';

Widget _host(Widget child, {required bool reduce}) => MaterialApp(
      theme: AppTheme.darkTheme,
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: reduce),
        child: Scaffold(body: Center(child: child)),
      ),
    );

void main() {
  group('MlMotion collapses one-shot durations, and never to zero', () {
    testWidgets('a duration shortens to 1ms, not 0ms', (tester) async {
      late Duration withMotion;
      late Duration withoutMotion;

      await tester.pumpWidget(_host(
        Builder(builder: (c) {
          withMotion = MlMotion.of(c, MlMotion.enter);
          return const SizedBox();
        }),
        reduce: false,
      ));
      await tester.pumpWidget(_host(
        Builder(builder: (c) {
          withoutMotion = MlMotion.of(c, MlMotion.enter);
          return const SizedBox();
        }),
        reduce: true,
      ));

      expect(withMotion.inMilliseconds, greaterThan(1));
      expect(withoutMotion, MlMotion.reducedFloor);
      // The whole reason the floor is 1ms and not Duration.zero.
      expect(withoutMotion, isNot(Duration.zero));
      expect(withoutMotion.inMicroseconds, greaterThan(0));
    });

    testWidgets('a curve flattens to linear', (tester) async {
      late Curve reduced;
      await tester.pumpWidget(_host(
        Builder(builder: (c) {
          reduced = MlMotion.curveOf(c, MlMotion.standard);
          return const SizedBox();
        }),
        reduce: true,
      ));
      expect(reduced, MlMotion.linear);
    });
  });

  group('a stat card does not count up when motion is off', () {
    Widget card() => const MlStatCard(
          label: 'Tons delivered',
          value: '128.4',
          icon: Icons.scale_rounded,
          animateValue: 128.4,
        );

    testWidgets('the figure is at its value on the first frame', (tester) async {
      await tester.pumpWidget(_host(card(), reduce: true));
      // One frame past the 1ms floor. With the count-up suppressed the settled
      // figure is already painted; with it running this would still read '0'.
      await tester.pump(const Duration(milliseconds: 2));

      expect(find.text('128'), findsOneWidget);
    });

    testWidgets('and it DOES count up when motion is on — so the test above '
        'is measuring something', (tester) async {
      await tester.pumpWidget(_host(card(), reduce: false));
      await tester.pump(const Duration(milliseconds: 2));

      // Still climbing: nowhere near 128 two milliseconds into an 800ms tween.
      expect(find.text('128'), findsNothing);

      await tester.pump(MlMotion.count);
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('128'), findsOneWidget);
    });
  });

  group('loops stop rather than speed up', () {
    /// Every `Ticker` the tester knows about. A loop that has been correctly
    /// suppressed leaves none of them running; a loop that was merely
    /// "shortened" leaves one spinning, which is the failure this catches.
    bool anyTickerActive(WidgetTester tester) =>
        tester.binding.transientCallbackCount > 0;

    testWidgets('the waypoint pulse holds still', (tester) async {
      // The REAL MlPulsingDot, not a stand-in: it is rendered directly rather
      // than through the whole progress bar because the bar needs trip data,
      // and the loop is what is under test.
      await tester.pumpWidget(
          _host(const MlPulsingDot(color: Colors.cyan), reduce: true));
      await tester.pump(const Duration(milliseconds: 50));

      expect(anyTickerActive(tester), isFalse,
          reason: 'a repeating AnimationController is still driving frames '
              'with reduce-motion on');
    });

    testWidgets('and it DOES pulse when motion is on', (tester) async {
      await tester.pumpWidget(
          _host(const MlPulsingDot(color: Colors.cyan), reduce: false));
      await tester.pump(const Duration(milliseconds: 50));

      expect(anyTickerActive(tester), isTrue,
          reason: 'the pulse is not running at all, so the test above proves '
              'nothing');
      // Let the repeating controller go, or the tester fails the test for
      // leaving a timer pending.
      await tester.pumpWidget(_host(const SizedBox(), reduce: false));
    });
  });
}
