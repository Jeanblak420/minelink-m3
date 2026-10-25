// A route's contract spec reads on a phone (S25 walk, 2026-10-25): the card
// gave the route a ~97px column, so `RT-9F7B5BA3` broke mid-code and "No spec
// set — loads on this route are not penalised." ran to five lines beside it.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/core/theme/app_theme.dart';
import 'package:flutter_application_1/features/portal/models/load_quality.dart';
import 'package:flutter_application_1/features/portal/screens/mine_quality_screen.dart';

import '../../test_helpers/real_fonts.dart';

const _spec = RouteQualitySpec(
  routeId: 'r1',
  routeNumber: 'RT-9F7B5BA3',
  commodity: 'Coal',
  offloadingPoint: 'maputo',
);

Future<void> _pump(WidgetTester tester, double width) async {
  tester.view.physicalSize = Size(width, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    child: MaterialApp(
      theme: AppTheme.darkTheme,
      home: MediaQuery(
        data: MediaQueryData(
            size: Size(width, 900), textScaler: const TextScaler.linear(1.3)),
        child: Scaffold(
          // The page gutter plus the card's padding, as on the phone.
          body: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 36),
            child: Column(children: const [
              RouteSpecTile(spec: _spec, companyId: 'c1'),
            ]),
          ),
        ),
      ),
    ),
  ));
  await tester.pumpAndSettle();
}

double _lineHeight(WidgetTester tester, String text) =>
    tester.getSize(find.text(text)).height;

void main() {
  setUpAll(loadRealFonts);

  testWidgets('411dp at 1.3: the code keeps one line, the sentence two at most',
      (tester) async {
    await _pump(tester, 411);
    expect(tester.takeException(), isNull);
    final code = _lineHeight(tester, 'RT-9F7B5BA3');
    final sentence =
        _lineHeight(tester, 'No spec set — loads on this route are not penalised.');
    // One line of the 13px code at 1.3 is well under 30px; a break doubles it.
    expect(code, lessThan(30), reason: 'the route code broke onto two lines');
    expect(sentence, lessThan(code * 3),
        reason: 'the spec sentence is squeezed into a narrow column');
    expect(find.text('Set spec'), findsOneWidget);
  });

  testWidgets('a wide card keeps the three columns side by side',
      (tester) async {
    await _pump(tester, 1000);
    final code = tester.getRect(find.text('RT-9F7B5BA3'));
    final sentence = tester.getRect(
        find.text('No spec set — loads on this route are not penalised.'));
    expect(sentence.left, greaterThan(code.right),
        reason: 'on a wide card the spec sits beside the route');
  });
}
