// The workspace keeps clear of side system bars (S25 and the S25-matched
// emulator held sideways, 2026-10-24): Android 15+ draws edge to edge and a
// landscape phone puts its navigation buttons on the RIGHT, so the page ran
// under them — "Complete now" and the chat disc were cut.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/core/design/shell/ml_app_shell.dart';
import 'package:flutter_application_1/core/design/shell/ml_nav_rail.dart';
import 'package:flutter_application_1/core/theme/app_theme.dart';
import 'package:flutter_application_1/features/super_admin/nav/console_nav.dart';

void main() {
  for (final (size, label) in [
    (const Size(891, 411), 'landscape phone (rail)'),
    (const Size(411, 891), 'portrait phone'),
  ]) {
    testWidgets('$label: nothing under a 48 dp right-hand bar', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.darkTheme,
        home: MediaQuery(
          data: MediaQueryData(
            size: size,
            padding: const EdgeInsets.only(right: 48),
            viewPadding: const EdgeInsets.only(right: 48),
          ),
          child: MlAppShell(
            tree: consoleNavTree(),
            selectedRoute: '/super-admin',
            onNavigate: (_) {},
            child: const SizedBox.expand(key: ValueKey('page')),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      final page = tester.getRect(find.byKey(const ValueKey('page')));
      expect(page.right, lessThanOrEqualTo(size.width - 48),
          reason: 'the page runs under the side system bar: $page');
    });
  }

  // The camera cutout held sideways (the "empty rail band", 2026-10-24/25).
  // A punch-hole phone in landscape reports a LEFT display-cutout inset —
  // 78 dp on the S25-matched emulator. Before the shell took a side safe area
  // the rail sat at x=0, under the cutout, and on the device a company portal
  // showed an empty band where its menu was. Since then the rail starts clear
  // of the cutout and the emulator draws its icons. (Why the icons vanished
  // under the cutout is not pinned down: in this test they still paint.)
  testWidgets('landscape phone: a left cutout does not empty the rail',
      (tester) async {
    const size = Size(891, 411);
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.darkTheme,
      home: MediaQuery(
        data: const MediaQueryData(
          size: size,
          padding: EdgeInsets.only(left: 78, right: 48),
          viewPadding: EdgeInsets.only(left: 78, right: 48),
        ),
        child: MlAppShell(
          tree: consoleNavTree(),
          selectedRoute: '/super-admin/organizations',
          onNavigate: (_) {},
          child: const SizedBox.expand(key: ValueKey('page')),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    final rail = tester.getRect(find.byType(MlNavRail));
    expect(rail.left, greaterThanOrEqualTo(78),
        reason: 'the rail sits under the camera cutout: $rail');
    final dash = find.descendant(
        of: find.byType(MlNavRail),
        matching: find.byIcon(Icons.dashboard_outlined));
    expect(dash, findsOneWidget);
    final icon = tester.getRect(dash);
    expect(rail.contains(icon.center), isTrue,
        reason: 'the Dashboard icon is pushed out of the rail: $icon in $rail');
  });
}
