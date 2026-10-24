// The expanded rail on a SHORT window (Jean's follow-up, 2026-10-24). On the
// S25 held sideways (~411dp tall) the brand, search box, collapse control and
// user footer left the items a strip about one row high, which could not be
// scrolled by hand: the Organizations row was unreachable. Below
// `MlNavRail.compactHeight` the whole rail now scrolls as one list.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/core/design/shell/ml_nav_rail.dart';
import 'package:flutter_application_1/core/theme/app_theme.dart';
import 'package:flutter_application_1/features/super_admin/nav/console_nav.dart';

import '../../test_helpers/real_fonts.dart';

Future<List<String>> _pump(WidgetTester tester, double height) async {
  final overflows = <String>[];
  final previous = FlutterError.onError;
  FlutterError.onError = (d) {
    final m = d.exception.toString();
    m.contains('overflowed') ? overflows.add(m.split('\n').first) : previous?.call(d);
  };
  tester.view.physicalSize = Size(900, height);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    theme: AppTheme.darkTheme,
    home: Scaffold(
      body: Row(children: [
        MlNavRail(
          tree: consoleNavTree(),
          selectedRoute: '/super-admin/organizations',
          onNavigate: (_) {},
          // As tall as the console's brand block and identity footer.
          header: const SizedBox(height: 90, child: Text('MineLink brand')),
          footer: const SizedBox(height: 80, child: Text('jean footer')),
          onToggleExpanded: () {},
        ),
        const Expanded(child: SizedBox()),
      ]),
    ),
  ));
  await tester.pumpAndSettle();
  FlutterError.onError = previous;
  return overflows;
}

void main() {
  setUpAll(loadRealFonts);

  testWidgets('411dp tall: nothing overflows and every item can be reached',
      (tester) async {
    expect(await _pump(tester, 411), isEmpty);
    // The rail is ONE scrollable now; dragging it reaches the selected item
    // and the last group, and finally the footer.
    final rail = find.descendant(
        of: find.byType(MlNavRail), matching: find.byType(Scrollable)).first;
    await tester.scrollUntilVisible(find.text('Organizations'), 60,
        scrollable: rail);
    expect(tester.getRect(find.text('Organizations')).bottom,
        lessThanOrEqualTo(411));
    await tester.scrollUntilVisible(find.text('Settings'), 60, scrollable: rail);
    await tester.scrollUntilVisible(find.text('jean footer'), 60,
        scrollable: rail);
  });

  testWidgets('a tall window keeps the brand and footer pinned', (tester) async {
    expect(await _pump(tester, 1000), isEmpty);
    final brandTop = tester.getTopLeft(find.text('MineLink brand')).dy;
    final rail = find.descendant(
        of: find.byType(MlNavRail), matching: find.byType(Scrollable)).first;
    await tester.drag(rail, const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.text('MineLink brand')).dy, brandTop,
        reason: 'the brand scrolled with the list on a tall window');
    expect(find.text('jean footer'), findsOneWidget);
  });
}
