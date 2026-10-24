// The driver's hero card shows its route line whole at a raised text size
// (emulator walk matched to Jean's S25 Ultra, 2026-10-24): at 1.3 it read
// "Your next load will appear he…".
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/core/theme/app_theme.dart';
import 'package:flutter_application_1/features/portal/screens/driver_app_screen.dart';

import '../test_helpers/real_fonts.dart';

void main() {
  setUpAll(loadRealFonts);

  for (final scale in [1.0, 1.3]) {
    testWidgets('360 dp at text x$scale: the route is not cut', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.build(Brightness.dark),
        home: MediaQuery(
          data: MediaQueryData(
              size: const Size(360, 800), textScaler: TextScaler.linear(scale)),
          child: const Scaffold(
            body: Padding(
              padding: EdgeInsets.all(16),
              child: DriverActiveTripHeroForTest(
                plate: 'No truck yet',
                route: 'Your next load will appear here.',
                statusLabel: 'NO ACTIVE TRIP',
              ),
            ),
          ),
        ),
      ));
      await tester.pump();
      final route = tester
          .renderObject<RenderParagraph>(find.text('Your next load will appear here.'));
      expect(route.didExceedMaxLines, isFalse, reason: 'the route line was cut');
    });
  }
}
