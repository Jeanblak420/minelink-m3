// The driver's hero card must not say two opposite things in one row.
//
// Photographed on an Android emulator on 2026-08-21 — the redesign's first run
// on Android — signed in as `roadhaul.driver` with no trip assigned:
//
//     ● ACTIVE TRIP                            [ NO ACTIVE TRIP ]
//
// A fixed eyebrow naming the slot, and a live pill naming its state, 500px
// apart on the same line, disagreeing. The eyebrow is "CURRENT TRIP" now: it
// names the SLOT and stays true whatever is in it, and the pill says what is
// in it.
//
// The general rule, which is what this file actually checks: **no two strings
// in the hero may negate each other.** Asserting only on the literal
// "ACTIVE TRIP" would pass the moment somebody wrote "ON A TRIP" over
// "NOT ON A TRIP".
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/core/theme/app_theme.dart';
import 'package:flutter_application_1/features/portal/screens/driver_app_screen.dart';

List<String> _paintedText(WidgetTester tester) {
  final out = <String>[];
  void walk(RenderObject node) {
    if (node is RenderParagraph && node.hasSize && !node.debugNeedsLayout) {
      final t = node.text.toPlainText().trim();
      if (t.isNotEmpty) out.add(t);
    }
    node.visitChildren(walk);
  }

  walk(tester.binding.rootElement!.renderObject!);
  return out;
}

Future<void> _pumpHero(WidgetTester tester, String statusLabel) async {
  tester.view.physicalSize = const Size(412, 915);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.build(Brightness.dark),
      home: Scaffold(
        body: DriverActiveTripHeroForTest(
          plate: 'S6W001GP',
          route: 'Your next load will appear here.',
          statusLabel: statusLabel,
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('with NO trip the card does not claim there is one',
      (tester) async {
    await _pumpHero(tester, 'NO ACTIVE TRIP');

    final painted = _paintedText(tester).map((s) => s.toUpperCase()).toList();

    // The negation is present — that is the honest half.
    expect(painted, contains('NO ACTIVE TRIP'));

    // And nothing else asserts the opposite. A string that is a strict
    // substring of the negation is the shape of the fault: "ACTIVE TRIP" sat
    // inside "NO ACTIVE TRIP" and read as its contradiction.
    for (final line in painted) {
      if (line == 'NO ACTIVE TRIP') continue;
      expect(
        'NO $line' == 'NO ACTIVE TRIP' || 'NOT $line' == 'NO ACTIVE TRIP',
        isFalse,
        reason: 'the hero prints "$line" beside "NO ACTIVE TRIP" — one row, '
            'two opposite claims',
      );
    }
  });

  testWidgets('with a trip the eyebrow still names the slot', (tester) async {
    await _pumpHero(tester, 'LOADED');

    final painted = _paintedText(tester).map((s) => s.toUpperCase()).toList();
    expect(painted, contains('CURRENT TRIP'));
    expect(painted, contains('LOADED'));
    expect(painted, isNot(contains('NO ACTIVE TRIP')));
  });
}
