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
import 'package:flutter_application_1/core/design/shell/workspace_canvas.dart';
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

    // ---------------------------------------------------------------------
    // AND THE SAME FAULT ON A PHONE, where there is no Row to stretch.
    //
    // `Scaffold` lays its body out under a LOOSE height constraint. At compact
    // width the workspace IS the body, the `AnimatedSwitcher`'s `Stack` is
    // `StackFit.loose`, and `MlPageBody` is a bare `SingleChildScrollView` —
    // so a page shorter than the screen shrink-wrapped the whole chain and the
    // canvas painter, which sizes to its child, stopped painting where the
    // content stopped. Below that line the `Scaffold`'s own `canvasBase`
    // (`#0A1424`) showed against the canvas's `#060B15`: a hard horizontal
    // seam across the page, at a different height on every screen.
    //
    // Measured on the phone renders 2026-08-21: **23 of 61** had it.
    //
    // The assertion is on the PAINTED canvas, not on the page, because the
    // page is allowed to be short — that is the whole point. What may not be
    // short is the ground under it.
    testWidgets('the canvas fills a phone screen under a short page',
        (tester) async {
      tester.view.physicalSize = const Size(412, 900);
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
          child: const SizedBox(height: 120, child: Text('page top')),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 900));
      await tester.pump(const Duration(milliseconds: 400));

      final canvas = find.byWidgetPredicate(
          (w) => w is CustomPaint && w.painter is MlWorkspaceCanvasPainter);
      expect(canvas, findsOneWidget);

      final painted = tester.getSize(canvas).height;
      final bottomBar = tester.getSize(find.byType(NavigationBar)).height;
      // 900 window − 72 app bar − the bottom bar. Anything materially short of
      // that is the seam.
      final available = 900 - 72 - bottomBar;
      expect(painted, closeTo(available, 2),
          reason: 'the workspace canvas is ${painted.toStringAsFixed(0)}px tall '
              'in a ${available.toStringAsFixed(0)}px body, so '
              '${(available - painted).toStringAsFixed(0)}px of the page is '
              "painted in the Scaffold's canvasBase instead of the canvas");
    });

    // AND THE PAGE INSIDE IT FILLS TOO.
    //
    // The canvas fix above is one layer short on its own: the
    // `AnimatedSwitcher`'s `Stack` was `StackFit.loose`, which hands children
    // `0..maxHeight`, so a page that shrink-wraps stops where its content
    // stops. About a third of the portal's screens paint their OWN ground —
    // `ColoredBox(MlSemantic.surfaceApp)`, one step lighter than the shell's
    // canvas — and those came out TWO-TONE. Measured on the mine's Buyers page
    // 2026-08-21: `surfaceApp` ran to y=607 of a 1600px page and the canvas
    // showed for the remaining 993.
    testWidgets('a page that paints its own ground fills the workspace',
        (tester) async {
      tester.view.physicalSize = const Size(1400, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      const key = ValueKey('own-ground');
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
          // The exact shape those screens use: a ground colour wrapped around
          // a scroll view whose content is shorter than the window.
          child: const ColoredBox(
            key: key,
            // The colour does not matter to the assertion — the SHAPE does:
            // a ground wrapped around a scroll view shorter than the window.
            color: Color(0xFF0A1424),
            child: SingleChildScrollView(
              child: SizedBox(height: 120, child: Text('page top')),
            ),
          ),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 900));
      await tester.pump(const Duration(milliseconds: 400));

      final ground = tester.getSize(find.byKey(key)).height;
      // 1200 window − 72 app bar.
      expect(ground, closeTo(1200 - 72, 2),
          reason: 'the page paints its own ground for only '
              '${ground.toStringAsFixed(0)}px of a '
              '${(1200 - 72).toStringAsFixed(0)}px workspace, so the shell '
              'canvas shows underneath it from there down');
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
