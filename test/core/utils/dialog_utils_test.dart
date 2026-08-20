import 'package:flutter_application_1/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/core/utils/dialog_utils.dart';

const _probeKey = Key('dialog-width-probe');

void main() {
  group('DialogUtils.contentMaxWidth', () {
    Future<void> pumpWidth(WidgetTester tester, double screenWidth) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: MediaQuery(
            data: MediaQueryData(size: Size(screenWidth, 800)),
            child: Builder(
              key: _probeKey,
              builder: (context) => const SizedBox.shrink(),
            ),
          ),
        ),
      );
    }

    BuildContext contextFrom(WidgetTester tester) {
      return tester.element(find.byKey(_probeKey));
    }

    testWidgets('clamps to minWidth on narrow phones', (tester) async {
      await pumpWidth(tester, 320);
      expect(DialogUtils.contentMaxWidth(contextFrom(tester)), 280);
    });

    testWidgets('uses screen minus inset between min and max', (tester) async {
      await pumpWidth(tester, 400);
      expect(DialogUtils.contentMaxWidth(contextFrom(tester)), 352);
    });

    testWidgets('caps at maxWidth on wide screens', (tester) async {
      await pumpWidth(tester, 600);
      expect(DialogUtils.contentMaxWidth(contextFrom(tester)), 520);
      await pumpWidth(tester, 1200);
      expect(DialogUtils.contentMaxWidth(contextFrom(tester)), 520);
    });

    testWidgets('respects custom maxWidth', (tester) async {
      await pumpWidth(tester, 800);
      expect(
        DialogUtils.contentMaxWidth(contextFrom(tester), maxWidth: 400),
        400,
      );
    });
  });
}
