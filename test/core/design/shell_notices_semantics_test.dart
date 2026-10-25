// The portal's account-setup banner and licence notice are visible to a
// screen reader (S25 walk, 2026-10-25). They sit in a Column ABOVE the shell
// route's nested Navigator, whose route carries `BlockSemantics` — which drops
// everything painted before it in the same semantics container. On the phone
// the banner was drawn but absent from the accessibility tree, so TalkBack
// could neither read it nor reach "Complete now".
//
// Two halves: the mechanism, pumped (so the boundary is known to be what
// fixes it), and the portal shell's source, read (standing the whole portal
// shell up needs auth, company, employee and workspace providers — see
// sidebar_starts_collapsed_test.dart for the same trade).
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _body({required bool boundary}) {
  final nav = Navigator(
    onGenerateRoute: (_) =>
        MaterialPageRoute<void>(builder: (_) => const Text('page body')),
  );
  return MaterialApp(
    home: Scaffold(
      body: Semantics(
        container: true,
        child: Column(children: [
          const Text('banner above'),
          Expanded(
              child: boundary ? Semantics(container: true, child: nav) : nav),
        ]),
      ),
    ),
  );
}

void main() {
  testWidgets('without a boundary the nested Navigator hides the banner',
      (tester) async {
    final h = tester.ensureSemantics();
    await tester.pumpWidget(_body(boundary: false));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('banner above'), findsNothing,
        reason: 'Flutter no longer blocks here — the boundary below may be '
            'unnecessary, but it is harmless');
    h.dispose();
  });

  testWidgets('with its own boundary the banner and the page are both seen',
      (tester) async {
    final h = tester.ensureSemantics();
    await tester.pumpWidget(_body(boundary: true));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('banner above'), findsOneWidget);
    expect(find.bySemanticsLabel('page body'), findsOneWidget);
    h.dispose();
  });

  test('the portal shell gives its routed child that boundary', () {
    final src = File('lib/features/portal/widgets/portal_shell_layout.dart')
        .readAsLinesSync()
        .map((l) {
          final i = l.indexOf('//');
          return i == -1 ? l : l.substring(0, i);
        })
        .join('\n');
    final banner = src.indexOf('const ProfileSetupBanner()');
    expect(banner, isNot(-1), reason: 'the banner moved — re-point this test');
    final after = src.substring(banner);
    expect(
      after.contains(
          RegExp(r'child:\s*Semantics\(\s*container:\s*true,\s*child:\s*widget\.child\)')),
      isTrue,
      reason: 'the routed child below the banner must sit in its own '
          'Semantics(container: true) or the banner is invisible to TalkBack',
    );
  });
}
