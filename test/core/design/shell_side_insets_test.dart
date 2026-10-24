// The workspace keeps clear of side system bars (S25 and the S25-matched
// emulator held sideways, 2026-10-24): Android 15+ draws edge to edge and a
// landscape phone puts its navigation buttons on the RIGHT, so the page ran
// under them — "Complete now" and the chat disc were cut.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/core/design/shell/ml_app_shell.dart';
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
}
