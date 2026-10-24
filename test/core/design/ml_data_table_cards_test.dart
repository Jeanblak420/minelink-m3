// MlDataTable's opt-in phone layout (admin phone audit, 2026-10-24): the
// admin tables on a 360dp phone broke headers mid-word, cut cells, and kept
// their most important columns behind a sideways scroll.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/core/design/components/ml_components.dart';
import 'package:flutter_application_1/core/theme/app_theme.dart';

Future<void> _pump(WidgetTester tester, double width, {required bool cards}) async {
  tester.view.physicalSize = Size(width, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    theme: AppTheme.darkTheme,
    home: Scaffold(
      body: SingleChildScrollView(
        child: MlDataTable(
          cardsOnPhone: cards,
          columns: const [
            MlColumn('Route ID'),
            MlColumn('Product'),
            MlColumn('Margin earned', align: TextAlign.right),
          ],
          rows: const [
            [Text('RT-0042'), Text('Chrome concentrate'), Text('R 141,306.00')],
            [Text('RT-0043'), Text('Manganese'), Text('R 12,000.00')],
          ],
        ),
      ),
    ),
  ));
}

void main() {
  testWidgets('phone + opt-in: a card per row, every value on screen', (tester) async {
    await _pump(tester, 360, cards: true);
    expect(find.byType(MlWideTable), findsNothing, reason: 'still a sideways table');
    expect(find.text('ROUTE ID'), findsNWidgets(2), reason: 'a label line per row');
    for (final v in ['R 141,306.00', 'R 12,000.00', 'Chrome concentrate']) {
      final r = tester.getRect(find.text(v));
      expect(r.right, lessThanOrEqualTo(360), reason: '$v is off the screen');
    }
  });

  testWidgets('desktop keeps the table', (tester) async {
    await _pump(tester, 1280, cards: true);
    expect(find.byType(MlWideTable), findsOneWidget);
    expect(find.text('ROUTE ID'), findsOneWidget, reason: 'one header row');
  });

  testWidgets('without the opt-in a phone keeps the table', (tester) async {
    await _pump(tester, 360, cards: false);
    expect(find.byType(MlWideTable), findsOneWidget);
  });
}
