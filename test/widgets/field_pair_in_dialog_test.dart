// Two fields side by side in a dialog keep their labels whole on a phone.
//
// S25 walk, 2026-10-26: at 411dp and system font 1.3 a dialog Row of two
// TextFields cut both labels ("Commod…", "Target Cr…"). `MlFieldPair` stacks
// them when each half would be too narrow. Its first version measured with a
// LayoutBuilder and threw inside AlertDialog, which sizes by intrinsic width —
// so this test runs it inside a real AlertDialog.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/core/design/components/ml_field_pair.dart';
import 'package:flutter_application_1/core/theme/app_theme.dart';

Future<void> _pump(WidgetTester tester, Size size, double scale) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    theme: AppTheme.darkTheme,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(textScaler: TextScaler.linear(scale)),
      child: child!,
    ),
    home: const Scaffold(
      body: AlertDialog(
        title: Text('Contract spec'),
        content: SingleChildScrollView(
          child: MlFieldPair(
            first: TextField(
                decoration: InputDecoration(labelText: 'Target Cr₂O₃ %')),
            second: TextField(
                decoration: InputDecoration(labelText: 'Max moisture %')),
          ),
        ),
      ),
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('on a phone at a raised font the pair stacks', (tester) async {
    await _pump(tester, const Size(411, 891), 1.3);
    expect(tester.takeException(), isNull);
    final a = tester.getRect(find.byType(TextField).first);
    final b = tester.getRect(find.byType(TextField).last);
    expect(b.top, greaterThan(a.bottom), reason: 'second field is below');
  });

  testWidgets('on a desktop the pair sits side by side', (tester) async {
    await _pump(tester, const Size(1280, 800), 1.0);
    expect(tester.takeException(), isNull);
    final a = tester.getRect(find.byType(TextField).first);
    final b = tester.getRect(find.byType(TextField).last);
    expect(b.left, greaterThan(a.right), reason: 'second field is beside');
    expect(b.top, closeTo(a.top, 1));
  });
}
