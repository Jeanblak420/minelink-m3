// Crossing a layout breakpoint must not move the routed child.
//
// This is the SECOND half of the Duplicate GlobalKey fault, and it is here
// because the first fix was not enough — which the handset said, not a test.
//
// Removing the route-derived key from both shells' NavHistoryRecorder (commit
// ca0a835) stopped the remount on every NAVIGATION. The new build was installed
// on Jean's SM-G780G and, seven seconds after launch, reported:
//
//     Duplicate GlobalKey detected in widget tree.
//     - [GlobalObjectKey int#715dc]
//     ... the specific parent that did not update ... is:
//     - NavHistoryRecorder(state: _NavHistoryRecorderState#8c8da)
//
// Note what changed and what did not: the recorder no longer carries
// `-[<'/super-admin'>]`, so the key removal landed — and the reparenting was
// still happening. Once, at startup, "while finalizing the widget tree".
//
// The remaining cause is in `MlAppShell.build`, which put the workspace at two
// different DEPTHS:
//
//     body: windowClass.usesRail
//         ? Row([rail, Expanded(child: workspace)])
//         : workspace,
//
// The workspace holds the routed child, which hosts go_router's shell
// navigator, keyed `GlobalObjectKey(navigatorKey.hashCode)`. The instant the
// real MediaQuery arrives and the window class resolves, Flutter tears down one
// shape and reparents that global key into the other. On a phone that happens
// once per launch, which is exactly the report.
//
// The Row is unconditional now; only the RAIL slot changes, so the workspace
// stays at index 1 in the same Expanded and is updated in place.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/core/design/nav/ml_nav_node.dart';
import 'package:flutter_application_1/core/design/shell/ml_app_shell.dart';
import 'package:flutter_application_1/core/design/shell/ml_nav_rail.dart';
import 'package:flutter_application_1/core/theme/app_theme.dart';

/// Stands in for go_router's `_CustomNavigator`: a stateful widget carrying a
/// `GlobalObjectKey` over an int, the exact key shape in the report.
class _RoutedChild extends StatefulWidget {
  const _RoutedChild({super.key});
  @override
  State<_RoutedChild> createState() => _RoutedChildState();
}

class _RoutedChildState extends State<_RoutedChild> {
  @override
  Widget build(BuildContext context) => const SizedBox.expand();
}

const _navigatorKey = GlobalObjectKey<_RoutedChildState>(0x715dc);

/// Two destinations, so the rail has something to draw.
final _tree = <MlNavNode>[
  const MlNavNode.leaf(label: 'Dashboard', icon: Icons.dashboard, route: '/a'),
  const MlNavNode.leaf(label: 'Second', icon: Icons.list, route: '/b'),
];

Widget _shellAt(double width) => MediaQuery(
  data: MediaQueryData(size: Size(width, 900)),
  child: MaterialApp(
    theme: AppTheme.build(Brightness.dark),
    home: MlAppShell(
      tree: _tree,
      selectedRoute: '/a',
      onNavigate: (_) {},
      title: 'Shell',
      child: const _RoutedChild(key: _navigatorKey),
    ),
  ),
);

void main() {
  testWidgets(
    'crossing the rail breakpoint does not reparent the routed child',
    (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      // Start wide — the rail layout.
      await tester.pumpWidget(_shellAt(1400));
      await tester.pumpAndSettle();
      final wide = _navigatorKey.currentState;
      expect(wide, isNotNull);

      // Cross to compact, which is what happens on a phone as the first real
      // MediaQuery arrives, and on any rotation or window resize after that.
      await tester.pumpWidget(_shellAt(420));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(
        identical(_navigatorKey.currentState, wide),
        isTrue,
        reason: 'the routed child must keep its element across the breakpoint',
      );

      // And back, because a resize goes both ways.
      await tester.pumpWidget(_shellAt(1400));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(identical(_navigatorKey.currentState, wide), isTrue);
    },
  );

  testWidgets('every breakpoint in turn keeps the same element', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // compact | medium | expanded | large — 599/839/1199 are the boundaries in
    // ml_window_class.dart, and the rail appears at medium. Walking all four
    // rather than one crossing, because only ONE of these transitions used to
    // change the tree's shape and a single pair could miss it.
    await tester.pumpWidget(_shellAt(420));
    await tester.pumpAndSettle();
    final first = _navigatorKey.currentState;

    for (final w in const [700.0, 1000.0, 1500.0, 700.0, 420.0]) {
      await tester.pumpWidget(_shellAt(w));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'at width $w');
      expect(
        identical(_navigatorKey.currentState, first),
        isTrue,
        reason: 'the routed child was rebuilt at width $w',
      );
    }
  });

  testWidgets('the rail is still there when it should be, and gone when not', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // Without this, "keep the element stable" could be satisfied by always
    // rendering the rail, which would ruin every phone layout. The rail slot
    // is the ONLY thing allowed to change across the breakpoint.
    await tester.pumpWidget(_shellAt(1400));
    await tester.pumpAndSettle();
    expect(
      find.byType(MlNavRail),
      findsOneWidget,
      reason: 'the rail is the point of the wide layout',
    );

    await tester.pumpWidget(_shellAt(420));
    await tester.pumpAndSettle();
    expect(
      find.byType(MlNavRail),
      findsNothing,
      reason:
          'at compact width the destinations are the drawer and the '
          'bottom bar, not a rail beside the workspace',
    );

    // ...and the routed child came through both of those unmoved, which is the
    // pair of properties that has to hold at once.
    expect(tester.takeException(), isNull);
  });
}
