import 'package:flutter/material.dart';

/// The sidebar-skin colour + metric contract, and the layer that is allowed to
/// hold the raw literals filling it in.
///
/// Extracted from `features/super_admin/widgets/sidebar/minelink_sidebar_core`
/// on 2026-08-15 (S5-19) together with the two skin palettes in
/// `ml_sidebar_skin_palettes.dart`. The class had always been a pure data
/// contract sitting in a file of widgets; the palettes that fill it — Haul's
/// gold-over-graphite and Weighbridge's paper-and-ink — are complete
/// self-contained schemes in the same sense the chat palettes are, each
/// declaring its own `isDarkSurface` and supplying a matched foreground for
/// every surface. They cannot be expressed in `MlTokens`, because being *not*
/// the app palette is the entire reason the alternate skins exist.
///
/// `minelink_sidebar_core.dart` re-exports this, so every existing import of
/// the sidebar core still resolves `MlSidebarTokens` unchanged.
/// Colour + metric contract every skin fills in. Each skin ships its own
/// `dark` / `light` sets; pass a custom instance to override.
///
/// NOTE: deliberately *not* `MlTokens` — that name belongs to the app-wide
/// design tokens in `lib/core/design/tokens/ml_tokens.dart`. These are the sidebar
/// skins' own palettes, which is the whole point of the alternate versions.
@immutable
class MlSidebarTokens {
  const MlSidebarTokens({
    required this.surface,
    required this.surfaceRaised,
    required this.surfaceHover,
    required this.surfaceActive,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.accent,
    required this.accentSoft,
    required this.onAccent,
    required this.badgeBg,
    required this.badgeFg,
    required this.danger,
    required this.dangerBg,
    required this.online,
    required this.isDarkSurface,
    this.onInk,
    this.expandedWidth = 272,
    this.railWidth = 76,
    this.radius = 10,
    this.rowHeight = 42,
    this.display,
    this.body,
    this.mono,
  });

  final Color surface;
  final Color surfaceRaised;
  final Color surfaceHover;
  final Color surfaceActive;
  final Color border;

  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;

  final Color accent;
  final Color accentSoft;
  final Color onAccent;

  final Color badgeBg;
  final Color badgeFg;

  final Color danger;
  final Color dangerBg;
  final Color online;

  /// Drives which brand artwork is used and which system overlay style fits.
  final bool isDarkSurface;

  /// Type/icon colour on Weighbridge's solid active block. Null keeps the
  /// drop's built-in near-black/white pair. (Additive to the original drop, so
  /// a palette variant can put its own ink colour on the block instead of the
  /// hardcoded one.)
  final Color? onInk;

  final double expandedWidth;
  final double railWidth;
  final double radius;
  final double rowHeight;

  /// Font families. Both are registered in `pubspec.yaml`; leave null to
  /// inherit the app's default text theme.
  final String? display;
  final String? body;
  final String? mono;

  /// Colour-only override helper. Geometry and fonts carry over untouched,
  /// which is what lets the app-palette variants be *exactly* the drop with a
  /// different palette — see `console_palette_tokens.dart`.
  MlSidebarTokens copyWith({
    Color? surface,
    Color? surfaceRaised,
    Color? surfaceHover,
    Color? surfaceActive,
    Color? border,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? accent,
    Color? accentSoft,
    Color? onAccent,
    Color? badgeBg,
    Color? badgeFg,
    Color? danger,
    Color? dangerBg,
    Color? online,
    bool? isDarkSurface,
    Color? onInk,
  }) {
    return MlSidebarTokens(
      surface: surface ?? this.surface,
      surfaceRaised: surfaceRaised ?? this.surfaceRaised,
      surfaceHover: surfaceHover ?? this.surfaceHover,
      surfaceActive: surfaceActive ?? this.surfaceActive,
      border: border ?? this.border,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      accent: accent ?? this.accent,
      accentSoft: accentSoft ?? this.accentSoft,
      onAccent: onAccent ?? this.onAccent,
      badgeBg: badgeBg ?? this.badgeBg,
      badgeFg: badgeFg ?? this.badgeFg,
      danger: danger ?? this.danger,
      dangerBg: dangerBg ?? this.dangerBg,
      online: online ?? this.online,
      isDarkSurface: isDarkSurface ?? this.isDarkSurface,
      onInk: onInk ?? this.onInk,
      expandedWidth: expandedWidth,
      railWidth: railWidth,
      radius: radius,
      rowHeight: rowHeight,
      display: display,
      body: body,
      mono: mono,
    );
  }
}
