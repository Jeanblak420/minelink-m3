// `MlAppShell` decides the rail's width from the caller's preference AND the
// window class:
//
//   expanded: windowClass.usesExpandedRail && widget.expanded
//
// but `railHeader` and `railFooter` are pre-built widgets, given their own
// `expanded` by that same caller from the preference alone. On a medium window
// the shell narrowed the rail to 80dp while `MlRailIdentity` went on building
// its 280dp layout inside it — an avatar, a name and a role in a Row — and
// overflowed by 2px. Two sources of truth for one fact, and the widgets read
// the wrong one.
//
// `MlRailScope` publishes what the rail actually did. These tests hold it.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/core/design/nav/ml_nav_node.dart';
import 'package:flutter_application_1/core/design/shell/ml_nav_rail.dart';
import 'package:flutter_application_1/core/design/shell/ml_rail_blocks.dart';
import 'package:flutter_application_1/core/theme/app_theme.dart';
import 'package:flutter_application_1/core/widgets/user_identity_flyout.dart';
import '../test_helpers/real_fonts.dart';

const _identity = UserIdentity(
  name: 'Jean Blak',
  email: 'jean@cyberhouse.co.za',
  roleLabel: 'Super Admin',
);

final _tree = <MlNavNode>[
  const MlNavNode.leaf(
    label: 'Dashboard',
    icon: Icons.dashboard_outlined,
    selectedIcon: Icons.dashboard_rounded,
    route: '/super-admin',
  ),
];

/// A rail whose own state is [railExpanded], containing blocks that were told
/// the opposite. The disagreement is the point.
Widget _rail({required bool railExpanded, required bool blocksTold}) =>
    MaterialApp(
      theme: AppTheme.darkTheme,
      home: Scaffold(
        body: Row(
          children: [
            MlNavRail(
              tree: _tree,
              selectedRoute: '/super-admin',
              onNavigate: (_) {},
              expanded: railExpanded,
              header: MlRailBrand(
                expanded: blocksTold,
                subtitle: 'GLOBAL ADMIN',
                onTap: () {},
              ),
              footer: MlRailIdentity(
                expanded: blocksTold,
                identity: _identity,
                onOpenProfile: () {},
              ),
            ),
            const Expanded(child: SizedBox()),
          ],
        ),
      ),
    );

Future<List<String>> _faults(WidgetTester tester, Widget w) async {
  final faults = <String>[];
  final prior = FlutterError.onError;
  FlutterError.onError = (d) {
    final s = d.exception.toString();
    if (s.contains('overflowed')) {
      faults.add(s.split('\n').first);
    } else {
      prior?.call(d);
    }
  };
  addTearDown(() => FlutterError.onError = prior);
  await tester.pumpWidget(w);
  await tester.pump();
  FlutterError.onError = prior;
  return faults;
}

void main() {
  setUpAll(loadRealFonts);

  testWidgets('a collapsed rail collapses its blocks, whatever they were told',
      (tester) async {
    tester.view.physicalSize = const Size(760, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // The exact disagreement the shell produced on a medium window.
    final faults =
        await _faults(tester, _rail(railExpanded: false, blocksTold: true));

    expect(faults, isEmpty, reason: faults.join('\n'));
    // The wide layout's text is genuinely absent, not merely clipped — the
    // block rebuilt, it did not just get cropped.
    expect(find.text('Jean Blak'), findsNothing);
    expect(find.text('GLOBAL ADMIN'), findsNothing);
  });

  testWidgets('an expanded rail still shows the wide blocks', (tester) async {
    tester.view.physicalSize = const Size(1400, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final faults =
        await _faults(tester, _rail(railExpanded: true, blocksTold: true));

    expect(faults, isEmpty, reason: faults.join('\n'));
    expect(find.text('Jean Blak'), findsOneWidget);
    expect(find.text('GLOBAL ADMIN'), findsOneWidget);
  });

  testWidgets('the rail overrides a block told to collapse, too — the scope is '
      'the truth in both directions', (tester) async {
    tester.view.physicalSize = const Size(1400, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await _faults(tester, _rail(railExpanded: true, blocksTold: false));

    expect(find.text('Jean Blak'), findsOneWidget);
  });

  testWidgets('outside a rail a block falls back to its own parameter',
      (tester) async {
    // The modal drawer and tests render these blocks with no rail above them.
    // There is no scope to read, so the parameter has to still work.
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.darkTheme,
      home: const Scaffold(
        body: SizedBox(
          width: 280,
          child: MlRailIdentity(
            expanded: true,
            identity: _identity,
            onOpenProfile: _noop,
          ),
        ),
      ),
    ));
    await tester.pump();

    expect(MlRailScope.maybeOf(tester.element(find.byType(MlRailIdentity))),
        isNull);
    expect(find.text('Jean Blak'), findsOneWidget);
  });
}

void _noop() {}
