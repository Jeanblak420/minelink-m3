// The supervisor's stockpile card prints every tonnage the same way (emulator
// walk, 2026-10-24): it read "5,000 / 5000 t" — the balance grouped, the cap
// and the "to go" figure not.
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/core/theme/app_theme.dart';
import 'package:flutter_application_1/features/portal/models/stockpile_entry.dart';
import 'package:flutter_application_1/features/portal/widgets/stockpile_widgets.dart';

Future<String> _painted(WidgetTester tester, StockpileEntry pile) async {
  await tester.pumpWidget(MaterialApp(
    theme: AppTheme.darkTheme,
    home: Scaffold(
      body: SingleChildScrollView(
        child: StockpileCard(
          pile: pile,
          onAddTons: () {},
          onUploadResults: () {},
          onUploadPicture: () {},
        ),
      ),
    ),
  ));
  await tester.pumpAndSettle();
  return tester.allRenderObjects
      .whereType<RenderParagraph>()
      .map((p) => p.text.toPlainText())
      .join('\n');
}

void main() {
  testWidgets('a full order: cap and total grouped like the balance',
      (tester) async {
    final text = await _painted(tester,
        const StockpileEntry(name: 'Coal', tons: 5000, maxCapTons: 5000));
    expect(text, contains('/ 5,000 t'));
    expect(text, contains('Order complete · 5,000 t'));
    expect(text, isNot(contains('5000')));
  });

  testWidgets('a part-filled order: "to go" grouped too', (tester) async {
    final text = await _painted(tester,
        const StockpileEntry(name: 'Coal', tons: 1200, maxCapTons: 12000));
    expect(text, contains('10,800 t to go'));
    expect(text, contains('/ 12,000 t'));
  });
}
