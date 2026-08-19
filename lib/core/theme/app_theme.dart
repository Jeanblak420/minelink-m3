import 'package:flutter/material.dart';
import 'package:flutter_application_1/core/design/tokens/ml_tokens.dart';

/// Application-wide [ThemeData]. Light theme uses a slightly darker
/// [ColorScheme.onSurfaceVariant] than raw seed generation so secondary
/// labels remain legible on white/off-white surfaces.
///
/// Typography and surfaces follow the MineLink design system
/// (`docs/new system design/minelink-new-design-v0.1`): Plus Jakarta Sans,
/// slate-neutral surfaces, cyan focus accents. See [MlTokens].
class AppTheme {
  static const _seedColor = MlTokens.teal700;
  /// Slate-600 — sufficient contrast on light surfaces for helper/subtitle text.
  static const _lightOnSurfaceVariant = MlTokens.slate600;

  static ThemeData get lightTheme => _buildTheme(Brightness.light);
  static ThemeData get darkTheme => _buildTheme(Brightness.dark);

  /// MineLink type scale (typography.css) on top of the Material text theme.
  static TextTheme _mlTextTheme(TextTheme base, ColorScheme scheme) {
    return base
        .copyWith(
          displaySmall: base.displaySmall?.copyWith(
            fontSize: MlTokens.fsDisplay,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.34,
            height: 1.1,
          ),
          headlineSmall: base.headlineSmall?.copyWith(
            fontSize: MlTokens.fsH1,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.26,
            height: 1.1,
          ),
          titleLarge: base.titleLarge?.copyWith(
            fontSize: MlTokens.fsH2,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.22,
            height: 1.15,
          ),
          titleMedium: base.titleMedium?.copyWith(
            fontSize: MlTokens.fsTitle,
            fontWeight: FontWeight.w700,
            height: 1.3,
          ),
          titleSmall: base.titleSmall?.copyWith(
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
          bodyLarge: base.bodyLarge?.copyWith(fontSize: 16, height: 1.5),
          bodyMedium:
              base.bodyMedium?.copyWith(fontSize: MlTokens.fsBody, height: 1.5),
          bodySmall: base.bodySmall?.copyWith(
            fontSize: MlTokens.fsBodySm,
            height: 1.4,
          ),
          labelLarge: base.labelLarge?.copyWith(
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
          labelMedium: base.labelMedium?.copyWith(
            fontSize: MlTokens.fsLabel,
            fontWeight: FontWeight.w600,
          ),
          labelSmall: base.labelSmall?.copyWith(
            fontSize: MlTokens.fsMicro,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        )
        .apply(fontFamily: MlTokens.fontSans);
  }

  static ThemeData _buildTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final seeded = ColorScheme.fromSeed(
      seedColor: _seedColor,
      brightness: brightness,
    );
    final scheme = isDark
        ? seeded
        : seeded.copyWith(onSurfaceVariant: _lightOnSurfaceVariant);

    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      fontFamily: MlTokens.fontSans,
    );
    final semantic = MlSemantic.from(brightness);

    return base.copyWith(
      textTheme: _mlTextTheme(base.textTheme, scheme),
      primaryTextTheme: _mlTextTheme(base.primaryTextTheme, scheme),
      scaffoldBackgroundColor: semantic.surfaceApp,
      canvasColor: semantic.surfaceCard,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: semantic.surfaceApp,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: base.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w600,
          color: scheme.onSurface,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: semantic.surfaceCard,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: scheme.outlineVariant.withAlpha(102)),
        ),
        margin: EdgeInsets.zero,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: semantic.surfaceCard,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark ? MlTokens.slate700 : MlTokens.slate800,
        contentTextStyle: const TextStyle(color: MlTokens.inkOnFill),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          // Brand-forward cyan for every primary action (design-system rule:
          // "cyan is the derivative used everywhere interactive").
          backgroundColor: MlTokens.accent,
          // Dark ink, not white. The accent is a LIGHT cyan: white on it
          // measures 1.81:1 against a WCAG requirement of 4.5:1, so the label
          // on every primary button in the product was effectively unreadable.
          // navy950 measures 11.16:1. (White was already failing at 2.44:1 on
          // the previous accent — S5-5 made it worse, it did not create it.)
          foregroundColor: MlTokens.navy950,
          minimumSize: const Size(80, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(
            fontFamily: MlTokens.fontSans,
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(80, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(
            fontFamily: MlTokens.fontSans,
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(80, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          side: BorderSide(color: scheme.outlineVariant),
          textStyle: const TextStyle(
            fontFamily: MlTokens.fontSans,
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(80, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(
            fontFamily: MlTokens.fontSans,
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: semantic.surfaceSunken,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: _inputBorder(Colors.transparent),
        enabledBorder: _inputBorder(Colors.transparent),
        focusedBorder: _inputBorder(MlTokens.accent, width: 2),
        errorBorder: _inputBorder(scheme.error),
        focusedErrorBorder: _inputBorder(scheme.error, width: 2),
        hintStyle: TextStyle(color: scheme.onSurfaceVariant),
      ),
      navigationBarTheme: NavigationBarThemeData(
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        height: 64,
        indicatorColor: scheme.primaryContainer,
        backgroundColor: semantic.surfaceCard,
        surfaceTintColor: Colors.transparent,
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: semantic.surfaceCard,
        indicatorColor: scheme.primaryContainer,
        selectedIconTheme: IconThemeData(color: scheme.onPrimaryContainer),
        unselectedIconTheme: IconThemeData(color: scheme.onSurfaceVariant),
        selectedLabelTextStyle: base.textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.w600,
          color: scheme.onSurface,
        ),
        unselectedLabelTextStyle: base.textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.normal,
          color: scheme.onSurfaceVariant,
        ),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant.withAlpha(128),
        space: 1,
        thickness: 1,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: semantic.surfaceCard,
        modalBackgroundColor: semantic.surfaceCard,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        surfaceTintColor: Colors.transparent,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        iconColor: scheme.primary,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
      chipTheme: base.chipTheme.copyWith(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        backgroundColor: isDark ? MlTokens.slate700 : MlTokens.slate100,
        side: BorderSide.none,
      ),
    );
  }

  static OutlineInputBorder _inputBorder(Color color, {double width = 1}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: color, width: width),
    );
  }
}
