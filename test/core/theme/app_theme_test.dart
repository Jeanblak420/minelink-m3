import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/core/theme/app_theme.dart';
import 'package:flutter_application_1/core/design/tokens/ml_tokens.dart';

void main() {
  group('AppTheme (MineLink redesign)', () {
    test('uses Plus Jakarta Sans as the app-wide sans family', () {
      final light = AppTheme.lightTheme;
      expect(light.textTheme.bodyMedium?.fontFamily, MlTokens.fontSans);
      expect(light.textTheme.titleLarge?.fontFamily, MlTokens.fontSans);
    });

    test('type scale matches typography.css', () {
      final t = AppTheme.lightTheme.textTheme;
      expect(t.displaySmall?.fontSize, MlTokens.fsDisplay);
      expect(t.displaySmall?.fontWeight, FontWeight.w800);
      expect(t.headlineSmall?.fontSize, MlTokens.fsH1);
      expect(t.titleLarge?.fontSize, MlTokens.fsH2);
      expect(t.titleLarge?.fontWeight, FontWeight.w800);
      expect(t.titleMedium?.fontSize, MlTokens.fsTitle);
      expect(t.bodyMedium?.fontSize, MlTokens.fsBody);
      expect(t.bodySmall?.fontSize, MlTokens.fsBodySm);
    });

    test('light surfaces keep the slate palette', () {
      final light = AppTheme.lightTheme;
      expect(light.scaffoldBackgroundColor, MlTokens.slate50);
      expect(light.cardTheme.color, Colors.white);
    });

    test('dark surfaces follow the semantic dark remap', () {
      final dark = AppTheme.darkTheme;
      expect(dark.scaffoldBackgroundColor, const Color(0xFF0A1424));
      expect(dark.cardTheme.color, const Color(0xFF111C30));
    });

    test('inputs focus with the cyan accent', () {
      final light = AppTheme.lightTheme;
      final focused =
          light.inputDecorationTheme.focusedBorder as OutlineInputBorder;
      expect(focused.borderSide.color, MlTokens.accent);
      expect(focused.borderSide.width, 2);
    });
  });
}
