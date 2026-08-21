// `kMlBottomNavHeight` has to be the height the bar actually takes.
//
// It is a constant living outside the `Scaffold`, which is unusual and needs
// justifying: the Scaffold reserves the bottom navigation bar for its own body
// automatically, so nothing INSIDE the shell has to know the number. The chat
// dock wraps the whole shell, so it is outside, and it has to keep off the bar
// by hand.
//
// It got that wrong. Measured on a 412x915 phone viewport in a browser on
// 2026-08-21, the dock's 66px launcher sat at y 835..890 inside a bar occupying
// y 831..914, covering **68% of the width of the fifth destination** — "More",
// which is the only route from the bottom bar to the rest of the navigation.
// The render harness builds `MlAppShell` directly and never mounts a dock, so
// the launcher is absent from all 100 phone renders and no picture could have
// shown it.
//
// A constant copied off a measurement rots. This file re-measures a real
// `NavigationBar` under this app's real theme, so if somebody sets a height in
// `navigationBarTheme` again — it used to be 72, and the note there explains
// why that was removed — the number and the reserve stop agreeing here rather
// than on somebody's phone.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/core/design/shell/ml_app_shell.dart';
import 'package:flutter_application_1/core/theme/app_theme.dart';

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('the bar is kMlBottomNavHeight tall in ${brightness.name}',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.build(brightness),
          home: Scaffold(
            body: const SizedBox.expand(),
            bottomNavigationBar: NavigationBar(
              selectedIndex: 0,
              destinations: const [
                NavigationDestination(
                    icon: Icon(Icons.dashboard_outlined), label: 'Dashboard'),
                NavigationDestination(
                    icon: Icon(Icons.insights_outlined), label: 'Insights'),
                NavigationDestination(
                    icon: Icon(Icons.more_horiz), label: 'More'),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        tester.getSize(find.byType(NavigationBar)).height,
        kMlBottomNavHeight,
        reason: 'the chat dock reserves kMlBottomNavHeight to stay off this '
            'bar; if the bar is a different height the launcher lands on a '
            'navigation destination',
      );
    });
  }

  testWidgets('the theme sets no explicit bar height, so M3 decides it',
      (tester) async {
    // The reserve is only safe to state as a constant BECAUSE the height comes
    // from M3's defaults rather than from something that varies. If a height
    // is ever set here, this fails and points at the reserve.
    final theme = AppTheme.build(Brightness.dark);
    expect(
      theme.navigationBarTheme.height,
      isNull,
      reason: 'a themed height would have to be mirrored into '
          'kMlBottomNavHeight, and the two would drift',
    );
  });
}
