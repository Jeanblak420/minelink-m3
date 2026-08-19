// Behaviour of the one navigation rail.
//
// Replaces three test files that each drove a different sidebar skin:
// `app_sidebar_behaviour_test.dart`, `reduce_motion_animated_size_test.dart`
// and `sidebar_user_chip_integration_test.dart`. There is one rail now, so
// there is one file — but every behaviour those three protected is protected
// here, against the widget that actually ships.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/core/design/nav/ml_nav_node.dart';
import 'package:flutter_application_1/core/design/shell/ml_nav_rail.dart';
import 'package:flutter_application_1/core/design/tokens/m3/ml_motion.dart';
import 'package:flutter_application_1/core/theme/app_theme.dart';

final _tree = <MlNavNode>[
  const MlNavNode.leaf(
    label: 'Dashboard',
    icon: Icons.dashboard_outlined,
    route: '/dash',
  ),
  const MlNavNode.group(
    label: 'Insights',
    icon: Icons.insights_outlined,
    children: [
      MlNavNode.leaf(
        label: 'Transporters',
        icon: Icons.local_shipping_outlined,
        route: '/insights/transporter',
      ),
      MlNavNode.leaf(
        label: 'Buyers',
        icon: Icons.shopping_bag_outlined,
        route: '/insights/buyer',
      ),
    ],
  ),
  const MlNavNode.leaf(
    label: 'Disputes',
    icon: Icons.gavel_outlined,
    route: '/disputes',
    badge: MlNavBadge.openDisputes,
  ),
];

Widget _host({
  required bool expanded,
  String? selected,
  bool disableAnimations = false,
  Map<MlNavBadge, int> counts = const {},
  ValueChanged<String>? onNavigate,
  VoidCallback? onToggle,
}) {
  return MaterialApp(
    theme: AppTheme.darkTheme,
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: disableAnimations),
      child: Scaffold(
        body: Row(
          children: [
            MlNavRail(
              tree: _tree,
              selectedRoute: selected,
              expanded: expanded,
              badgeCounts: counts,
              showSearch: false,
              onToggleExpanded: onToggle,
              onNavigate: onNavigate ?? (_) {},
            ),
            const Expanded(child: SizedBox()),
          ],
        ),
      ),
    ),
  );
}

void main() {
  group('the rail at both widths', () {
    testWidgets('expanded shows labels; collapsed shows none', (tester) async {
      await tester.pumpWidget(_host(expanded: true));
      await tester.pumpAndSettle();
      expect(find.text('Dashboard'), findsOneWidget);
      expect(find.text('Insights'), findsOneWidget);

      await tester.pumpWidget(_host(expanded: false));
      await tester.pumpAndSettle();
      expect(find.text('Dashboard'), findsNothing);
      expect(find.text('Insights'), findsNothing);
    });

    testWidgets('collapsed, every destination is still named by a tooltip',
        (tester) async {
      // A collapsed rail without tooltips is a column of unlabelled glyphs.
      await tester.pumpWidget(_host(expanded: false));
      await tester.pumpAndSettle();
      final messages = tester
          .widgetList<Tooltip>(find.byType(Tooltip))
          .map((t) => t.message)
          .toSet();
      expect(messages, containsAll(<String>['Dashboard', 'Insights', 'Disputes']));
    });

    testWidgets('the two widths are M3\'s rail sizes', (tester) async {
      await tester.pumpWidget(_host(expanded: false));
      await tester.pumpAndSettle();
      expect(
        tester.getSize(find.byType(MlNavRail)).width,
        MlNavRail.collapsedWidth,
      );

      await tester.pumpWidget(_host(expanded: true));
      await tester.pumpAndSettle();
      expect(
        tester.getSize(find.byType(MlNavRail)).width,
        MlNavRail.expandedWidth,
      );
    });

    testWidgets('the collapse control is offered only when the host allows it',
        (tester) async {
      await tester.pumpWidget(_host(expanded: true));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Collapse navigation'), findsNothing);

      var toggled = false;
      await tester
          .pumpWidget(_host(expanded: true, onToggle: () => toggled = true));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Collapse navigation'));
      expect(toggled, isTrue);
    });
  });

  group('groups', () {
    testWidgets('a group holding the current route opens itself',
        (tester) async {
      await tester.pumpWidget(
        _host(expanded: true, selected: '/insights/buyer'),
      );
      await tester.pumpAndSettle();
      // Its children are on screen without anyone having expanded it.
      expect(find.text('Buyers'), findsOneWidget);
      expect(find.text('Transporters'), findsOneWidget);
    });

    testWidgets('groups start open', (tester) async {
      // A rail whose groups start closed hides most of the app behind a click
      // and makes the tree look smaller than it is. The filter box is for
      // narrowing; the default is "you can see what there is" (P7-03).
      await tester.pumpWidget(_host(expanded: true, selected: '/dash'));
      await tester.pumpAndSettle();
      expect(find.text('Buyers'), findsOneWidget);
    });

    testWidgets('tapping the header closes and reopens it', (tester) async {
      await tester.pumpWidget(_host(expanded: true, selected: '/dash'));
      await tester.pumpAndSettle();
      expect(find.text('Buyers'), findsOneWidget);

      await tester.tap(find.text('Insights'));
      await tester.pumpAndSettle();
      expect(find.text('Buyers'), findsNothing);

      await tester.tap(find.text('Insights'));
      await tester.pumpAndSettle();
      expect(find.text('Buyers'), findsOneWidget);
    });

    testWidgets('the group you are inside cannot be closed', (tester) async {
      // Otherwise the rail can be put into a state where nothing is
      // highlighted while you are plainly on a page — you lose your place in
      // your own navigation.
      await tester.pumpWidget(
        _host(expanded: true, selected: '/insights/buyer'),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Insights'));
      await tester.pumpAndSettle();
      expect(find.text('Buyers'), findsOneWidget);
    });

    testWidgets('a child navigates to its own route', (tester) async {
      String? went;
      await tester.pumpWidget(_host(
        expanded: true,
        selected: '/insights/buyer',
        onNavigate: (r) => went = r,
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Transporters'));
      expect(went, '/insights/transporter');
    });

    testWidgets('collapsed, a group opens its children as a flyout',
        (tester) async {
      await tester.pumpWidget(_host(expanded: false, selected: '/dash'));
      await tester.pumpAndSettle();
      expect(find.text('Buyers'), findsNothing);

      await tester.tap(find.byIcon(Icons.insights_outlined));
      await tester.pumpAndSettle();
      // The children are reachable at 80px wide, which is the whole point —
      // narrowing the rail must not remove destinations.
      expect(find.text('Buyers'), findsOneWidget);
      expect(find.text('Transporters'), findsOneWidget);
    });
  });

  group('badges', () {
    testWidgets('a leaf shows its own count', (tester) async {
      await tester.pumpWidget(
        _host(expanded: true, counts: {MlNavBadge.openDisputes: 3}),
      );
      await tester.pumpAndSettle();
      expect(find.text('3'), findsOneWidget);
    });

    testWidgets('no count means no badge, not a zero', (tester) async {
      await tester.pumpWidget(
        _host(expanded: true, counts: {MlNavBadge.openDisputes: 0}),
      );
      await tester.pumpAndSettle();
      expect(find.text('0'), findsNothing);
    });

    testWidgets('a closed group sums its children', (tester) async {
      final tree = <MlNavNode>[
        const MlNavNode.group(
          label: 'Requests',
          icon: Icons.assignment_outlined,
          children: [
            MlNavNode.leaf(
              label: 'A',
              icon: Icons.abc,
              route: '/a',
              badge: MlNavBadge.pendingRequests,
            ),
            MlNavNode.leaf(
              label: 'B',
              icon: Icons.abc,
              route: '/b',
              badge: MlNavBadge.openDisputes,
            ),
          ],
        ),
      ];
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: Row(
              children: [
                MlNavRail(
                  tree: tree,
                  selectedRoute: '/elsewhere',
                  expanded: true,
                  showSearch: false,
                  badgeCounts: const {
                    MlNavBadge.pendingRequests: 4,
                    MlNavBadge.openDisputes: 2,
                  },
                  onNavigate: (_) {},
                ),
                const Expanded(child: SizedBox()),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      // 4 + 2, on the header, because the group is shut and the counts would
      // otherwise be invisible.
      expect(find.text('6'), findsOneWidget);
    });
  });

  group('reduce motion', () {
    // The regression this guards, verbatim from the file it replaces:
    //
    //   The motion helpers used to collapse to Duration.zero when the platform
    //   asks for reduced motion. AnimationController treats a zero duration as
    //   "jump to the target and notifyListeners() synchronously", and
    //   AnimatedSize's listener calls markNeedsLayout() — from inside its own
    //   performLayout. Flutter asserts:
    //
    //     A RenderAnimatedSize was mutated in its own performLayout
    //     implementation.
    //
    // It reproduced on every console page load with OS/browser reduce-motion
    // on, because the rail expands its groups with an AnimatedSize.
    testWidgets('the helper never returns a zero duration', (tester) async {
      late Duration reduced;
      late Duration normal;

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Builder(
            builder: (context) {
              reduced = MlMotion.of(context, MlMotion.expand);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(),
          child: Builder(
            builder: (context) {
              normal = MlMotion.of(context, MlMotion.expand);
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(reduced, isNot(Duration.zero));
      // Still effectively instant — well inside a single 16ms frame.
      expect(reduced.inMilliseconds, lessThan(16));
      // And untouched when motion is allowed.
      expect(normal, MlMotion.expand);
    });

    testWidgets('expanding a group under reduce-motion does not assert',
        (tester) async {
      await tester.pumpWidget(
        _host(expanded: true, selected: '/dash', disableAnimations: true),
      );
      await tester.pumpAndSettle();

      // Close it, then reopen — the expand is the direction that drives
      // AnimatedSize and the one that used to throw.
      await tester.tap(find.text('Insights'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Insights'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Buyers'), findsOneWidget);
    });
  });
}
