import 'package:flutter/material.dart';
import 'package:flutter_application_1/core/theme/app_theme.dart';
import 'package:flutter_application_1/core/design/tokens/ml_tokens.dart';

/// Premium Mine Dashboard theming (mine/supplier only).
///
/// These directions restyle ONLY the mine/supplier dashboard surface — they are
/// read by the mine dashboard widgets and never touch the global app theme, so
/// the buyer and transporter portals are unaffected. Adapted from the
/// `design_handoff_premium_minelink` "Glass / Frost" and "Industrial Premium"
/// directions, mapped onto the app's already-bundled fonts (no google_fonts):
///   • display / UI  → [MlTokens.fontSans]  (Plus Jakarta Sans)
///   • numerics      → [MlTokens.fontMono]  (JetBrains Mono)
///   • accents       → [MlTokens.fontSerif] (Fraunces)
///
/// [MineThemeDirection.minelink] is the app's existing look — when it is
/// selected no premium palette is applied and the dashboard renders exactly as
/// it does today.
enum MineThemeDirection {
  minelink('minelink', 'MineLink (current)'),
  glass('glass', 'Glass · Frost'),
  industrial('industrial', 'Industrial Premium');

  const MineThemeDirection(this.wire, this.label);

  /// Stable persistence string.
  final String wire;

  /// Human-readable name for the picker.
  final String label;

  static MineThemeDirection parse(String? value) {
    for (final d in MineThemeDirection.values) {
      if (d.wire == value) return d;
    }
    return MineThemeDirection.minelink;
  }
}

/// Layout density for the mine dashboard cards.
enum MineDensity {
  comfortable('comfortable', 'Comfortable'),
  compact('compact', 'Compact');

  const MineDensity(this.wire, this.label);

  final String wire;
  final String label;

  static MineDensity parse(String? value) {
    for (final d in MineDensity.values) {
      if (d.wire == value) return d;
    }
    return MineDensity.comfortable;
  }

  /// Card inner padding for this density (handoff: 22 comfortable / 18 compact).
  double get cardPadding => this == MineDensity.compact ? 18 : 22;
}

/// A resolved colour/shape palette for one premium direction.
///
/// Only [MineThemeDirection.glass] and [MineThemeDirection.industrial] have a
/// palette; [MineThemeDirection.minelink] returns null from [forDirection] and
/// the dashboard falls back to `MlSemantic`/`MlTokens`.
@immutable
class MinePremiumPalette {
  final Color bg;
  final Color panel;
  final Color panelHi;
  final Color border;
  final Color borderHi;

  final Color accent;
  final Color accent2;
  final Color accentWarm;
  final Color success;
  final Color danger;

  final Color textHi;
  final Color textMd;
  final Color textLo;
  final Color textDim;

  final double panelRadius;
  final double cardRadius;

  /// Glass uses a translucent backdrop-blur panel; Industrial uses solid
  /// hairline-bordered panels.
  final bool frosted;

  const MinePremiumPalette({
    required this.bg,
    required this.panel,
    required this.panelHi,
    required this.border,
    required this.borderHi,
    required this.accent,
    required this.accent2,
    required this.accentWarm,
    required this.success,
    required this.danger,
    required this.textHi,
    required this.textMd,
    required this.textLo,
    required this.textDim,
    required this.panelRadius,
    required this.cardRadius,
    required this.frosted,
  });

  /// Version A — "Glass / Frost": deep aurora navy, iced sky-cyan + violet,
  /// translucent blurred panels.
  static const glass = MinePremiumPalette(
    bg: Color(0xFF0B1120),
    panel: Color(0x0EFFFFFF), // 5.5% white
    panelHi: Color(0x17FFFFFF), // 9% white
    border: Color(0x1FFFFFFF), // 12% white
    borderHi: Color(0x38FFFFFF), // 22% white
    accent: Color(0xFF7DD3FC), // iced sky
    accent2: Color(0xFFA78BFA), // violet
    accentWarm: Color(0xFFFBBF24), // amber
    success: Color(0xFF86EFAC),
    danger: Color(0xFFF43F5E),
    textHi: Color(0xF5FFFFFF),
    textMd: Color(0xB8FFFFFF),
    textLo: Color(0x7AFFFFFF),
    textDim: Color(0x52FFFFFF),
    panelRadius: 20,
    cardRadius: 14,
    frosted: true,
  );

  /// Version B — "Industrial Premium": near-black graphite, safety-orange +
  /// amber, solid hairline panels with sharp corners.
  static const industrial = MinePremiumPalette(
    bg: Color(0xFF0B0D10),
    panel: Color(0xFF14171C),
    panelHi: Color(0xFF181C22),
    border: Color(0xFF242A33),
    borderHi: Color(0xFF2F3742),
    accent: Color(0xFFFF6B1A), // safety orange
    accent2: Color(0xFFFFB020), // amber
    accentWarm: Color(0xFFFFB020),
    success: Color(0xFF22C55E),
    danger: Color(0xFFF43F5E),
    textHi: Color(0xFFF5F7FA),
    textMd: Color(0xFFB8C0CC),
    textLo: Color(0xFF6E7789),
    textDim: Color(0xFF4A5262),
    panelRadius: 8,
    cardRadius: 8,
    frosted: false,
  );

  /// The palette for [direction], or null for the current MineLink look.
  static MinePremiumPalette? forDirection(MineThemeDirection direction) {
    switch (direction) {
      case MineThemeDirection.glass:
        return glass;
      case MineThemeDirection.industrial:
        return industrial;
      case MineThemeDirection.minelink:
        return null;
    }
  }

  // Opaque surface colours derived from the (possibly translucent) panel
  // tokens, so cards read solidly when used as `MlSemantic` surfaces.
  Color get _surfaceCard => Color.alphaBlend(panel, bg);
  Color get _surfaceRaised => Color.alphaBlend(panelHi, bg);
  Color get _surfaceSunken => Color.alphaBlend(const Color(0x33000000), bg);

  /// The [MlSemantic] palette that skins the whole mine UI for this direction.
  /// Cached so repeated shell rebuilds don't churn the inherited scope.
  MlSemantic get semantic => _semanticCache[this] ??= MlSemantic.custom(
        surfaceApp: bg,
        surfaceCard: _surfaceCard,
        surfaceRaised: _surfaceRaised,
        surfaceSunken: _surfaceSunken,
        textStrong: textHi,
        textBody: textMd,
        textMuted: textLo,
        textFaint: textDim,
        borderSubtle: border,
        borderCard: border,
        borderStrong: borderHi,
        borderAccent: accent.withValues(alpha: 0.5),
        divider: border,
      );

  /// A full [ThemeData] so Material widgets (buttons, dialogs, inputs, app bar)
  /// also adopt this direction across the mine UI. Cached like [semantic].
  ThemeData get themeData => _themeCache[this] ??= _buildThemeData();

  ThemeData _buildThemeData() {
    final base = AppTheme.darkTheme;
    final scheme = base.colorScheme.copyWith(
      primary: accent,
      secondary: accent2,
      surface: _surfaceCard,
      onSurface: textHi,
      onSurfaceVariant: textMd,
      error: danger,
      outlineVariant: border,
    );
    return base.copyWith(
      colorScheme: scheme,
      scaffoldBackgroundColor: bg,
      canvasColor: _surfaceCard,
      appBarTheme: base.appBarTheme.copyWith(
        backgroundColor: bg,
        foregroundColor: textHi,
      ),
      cardTheme: base.cardTheme.copyWith(color: _surfaceCard),
      dialogTheme: base.dialogTheme.copyWith(backgroundColor: _surfaceCard),
      bottomSheetTheme: base.bottomSheetTheme.copyWith(
        backgroundColor: _surfaceCard,
        modalBackgroundColor: _surfaceCard,
      ),
      dividerTheme: base.dividerTheme.copyWith(color: border),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: bg,
          minimumSize: const Size(80, 48),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: accent),
      ),
      inputDecorationTheme: base.inputDecorationTheme.copyWith(
        fillColor: _surfaceSunken,
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: accent, width: 2),
        ),
      ),
      floatingActionButtonTheme: base.floatingActionButtonTheme.copyWith(
        backgroundColor: accent,
        foregroundColor: bg,
      ),
    );
  }
}

// Per-palette caches (there are only two premium palettes, both const).
final Map<MinePremiumPalette, MlSemantic> _semanticCache = {};
final Map<MinePremiumPalette, ThemeData> _themeCache = {};
