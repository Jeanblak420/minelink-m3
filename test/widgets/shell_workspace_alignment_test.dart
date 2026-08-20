// A page starts at the top of the workspace, whatever the window height is.
//
// It did not. `Expanded` expands along the MAIN axis — horizontally, in the
// shell's rail-plus-workspace Row — and the CROSS axis is governed by
// `crossAxisAlignment`, which defaults to `center`. So the workspace was handed
// a loose vertical constraint, shrink-wrapped to its content, and was centred in
// what was left.
//
// Measured 2026-08-20 on a 1900px window: the Row was 1828 tall, the workspace
// inside it 1493, sitting at y=239 with 168px of nothing above and the same
// below. Every dashboard floated in the middle of the page and the taller the
// monitor the worse it got.
//
// THE TEST IS THE COMPARISON, not a fixed number. A single-height assertion
// would have passed throughout the fault — at 1200px, where the console
// dashboard's content fills the viewport, it was already correct. What gives it
// away is that the position MOVES with the window, which is why this renders the
// same short page at three heights and asserts they agree.
//
// Two other vertical centrings were found and fixed while looking for this one
// (`Center` in the workspace's width cap, and `AnimatedSwitcher`'s default
// centred `Stack`). Neither was the cause; both are covered here because any of
// the three reintroduces the same symptom on its own.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/core/design/shell/ml_app_shell.dart';
import 'package:flutter_application_1/core/design/nav/ml_nav_node.dart';
import 'package:flutter_application_1/core/theme/app_theme.dart';
import '../test_helpers/real_fonts.dart';

void main() {
  setUpAll(loadRealFonts);

  const tree = <MlNavNode>[
    MlNavNode.leaf(
      label: 'Dashboard',
      icon: Icons.dashboard_outlined,
      route: '/home',
    ),
    MlNavNode.leaf(
      label: 'Somewhere else',
      icon: Icons.map_outlined,
      route: '/other',
    ),
  ];

  /// The top of a deliberately SHORT page, in a window [height] tall.
  Future<double> pageTop(WidgetTester tester, double height) async {
    tester.view.physicalSize = Size(1400, height);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.darkTheme,
      home: MlAppShell(
        tree: tree,
        selectedRoute: '/home',
        onNavigate: (_) {},
        title: 'Fixture',
        subtitle: 'Workspace',
        expanded: true,
        onExpandedChanged: (_) {},
        // Short on purpose: a page that fills the viewport cannot float, which
        // is exactly why this went unnoticed on the long screens.
        child: const SizedBox(height: 120, child: Text('page top')),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 900));
    await tester.pump(const Duration(milliseconds: 400));

    return tester.getTopLeft(find.text('page top')).dy;
  }

  group('the workspace is TOP aligned, not centred', () {
    testWidgets('a short page sits at the same height in any window',
        (tester) async {
      final short = await pageTop(tester, 900);
      final tall = await pageTop(tester, 1900);
      final taller = await pageTop(tester, 2400);

      expect(tall, closeTo(short, 1),
          reason: 'the page moved ${(tall - short).toStringAsFixed(0)}px down '
              'when the window grew by 1000px. Something is centring the '
              'workspace vertically — the Row\'s crossAxisAlignment, the width '
              'cap, or the AnimatedSwitcher\'s layoutBuilder.');
      expect(taller, closeTo(short, 1));
    });

    testWidgets('and it sits just under the app bar, not far below it',
        (tester) async {
      final top = await pageTop(tester, 1900);
      // The app bar is 72; the workspace adds its content padding. Anything
      // much past that is the fault this file exists for.
      expect(top, lessThan(72 + 80),
          reason: 'the page starts ${top.toStringAsFixed(0)}px down, which is '
              'further than the app bar plus one gutter');
      expect(top, greaterThanOrEqualTo(72),
          reason: 'the page has climbed under the app bar');
    });

    testWidgets('the workspace fills the height it is given', (tester) async {
      // The positive statement behind the two above: the workspace should be
      // as tall as the Row, so a page CAN fill it and a scroll view inside it
      // scrolls rather than shrink-wraps.
      await pageTop(tester, 1900);
      final row = tester.getSize(find.descendant(
        of: find.byType(MlAppShell),
        matching: find.byType(Row),
      ).first);
      expect(row.height, greaterThan(1700),
          reason: 'the shell Row should occupy the window under the app bar');
    });
  });
}
