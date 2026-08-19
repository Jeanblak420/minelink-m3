// Reduce-motion regression.
//
// The motion helpers used to collapse to Duration.zero when the platform asks
// for reduced motion. AnimationController treats a zero duration as "jump to
// the target and notifyListeners() synchronously", and AnimatedSize's listener
// calls markNeedsLayout() — from inside its own performLayout. Flutter asserts:
//
//   A RenderAnimatedSize was mutated in its own performLayout implementation.
//
// It reproduced on every super-admin page load with OS/browser reduce-motion
// on, for all three sidebar skins, because each expands its nav groups with an
// AnimatedSize fed by one of these helpers.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/features/super_admin/widgets/insights_v2/minelink_screens_core.dart';
import 'package:flutter_application_1/features/super_admin/widgets/sidebar/minelink_sidebar_app.dart';
import 'package:flutter_application_1/features/super_admin/widgets/sidebar/minelink_sidebar_core.dart';
import 'package:flutter_application_1/features/super_admin/widgets/sidebar/minelink_sidebar_haul.dart';
import 'package:flutter_application_1/features/super_admin/widgets/sidebar/minelink_sidebar_weighbridge.dart';

void main() {
  const user = MlSidebarUser(name: 'jean', email: 'jean@cyberhouse.co.za');

  group('motion helpers under reduce-motion', () {
    testWidgets('never return a zero duration', (tester) async {
      late Duration screen;
      late Duration sidebar;

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Builder(
            builder: (context) {
              screen =
                  mlScreenMotion(context, const Duration(milliseconds: 150));
              sidebar = mlMotion(context, const Duration(milliseconds: 210));
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      // Zero is what makes AnimationController notify during layout.
      expect(screen, isNot(Duration.zero));
      expect(sidebar, isNot(Duration.zero));
      // Still effectively instant — well inside a single 16ms frame.
      expect(screen.inMilliseconds, lessThan(16));
      expect(sidebar.inMilliseconds, lessThan(16));
    });

    testWidgets('full duration is untouched when motion is allowed',
        (tester) async {
      late Duration screen;
      late Duration sidebar;

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(),
          child: Builder(
            builder: (context) {
              screen =
                  mlScreenMotion(context, const Duration(milliseconds: 150));
              sidebar = mlMotion(context, const Duration(milliseconds: 210));
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(screen, const Duration(milliseconds: 150));
      expect(sidebar, const Duration(milliseconds: 210));
    });
  });

  // All three skins expand nav groups through an AnimatedSize fed by one of
  // the helpers, so all three asserted before the fix.
  final skins = <String, Widget>{
    'app': MineLinkAppSidebar(
      selectedId: 'dashboard',
      onSelect: (_) {},
      collapsed: false,
      onCollapsedChanged: (_) {},
      user: user,
    ),
    'haul': HaulSidebar(
      selectedId: 'dashboard',
      onSelect: (_) {},
      user: user,
    ),
    'weighbridge': WeighbridgeSidebar(
      selectedId: 'dashboard',
      onSelect: (_) {},
      user: user,
    ),
  };

  for (final entry in skins.entries) {
    testWidgets('${entry.key} rail expands a nav group under reduce-motion '
        'without a layout assertion', (tester) async {
      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(brightness: Brightness.dark),
          // Inside MaterialApp: its own MediaQuery.fromView would otherwise
          // replace an outer one and the flag would never reach the rail.
          builder: (context, child) => MediaQuery(
            // The exact condition from the bug report: reduce-motion on.
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          ),
          home: Scaffold(
            body: Row(
              children: [entry.value, const Expanded(child: SizedBox())],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // Opening a group mounts the AnimatedSize child and drives the size
      // change that used to assert.
      final group = find.text('Tokens & Seats');
      expect(group, findsWidgets, reason: 'nav group missing from skin');
      await tester.tap(group.first);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // ...and closing it animates back the other way.
      await tester.tap(group.first);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
