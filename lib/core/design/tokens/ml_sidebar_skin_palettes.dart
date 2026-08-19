import 'package:flutter/material.dart';

import 'package:flutter_application_1/core/design/tokens/ml_sidebar_tokens.dart';

/// The two vendored sidebar-skin palettes, in the layer that is allowed to
/// hold raw colour literals.
///
/// Extracted from `minelink_sidebar_haul.dart` and
/// `minelink_sidebar_weighbridge.dart` on 2026-08-15 (S5-19). Each is a
/// complete, self-contained scheme — Haul runs gold over graphite because the
/// MineLink mark's second colour is gold and every admin console on earth is
/// already cyan; Weighbridge is a paper-and-ink manifest. Both declare their
/// own `isDarkSurface` and supply a matched foreground for every surface, so
/// neither can break light mode, which is the fault `no-raw-color-hex` names.
///
/// They are deliberately **not** derived from `MlTokens`: being other than the
/// app palette is the reason the alternate skins exist. The MineLink-coloured
/// variants of the same two layouts are built by `MlPaletteSidebarTokens`,
/// which `copyWith`s these and reads every colour from `MlSemantic`/`MlTone`.
///
/// Both files re-export this, so existing imports resolve unchanged.

class HaulTokens {
  const HaulTokens._();

  static const MlSidebarTokens dark = MlSidebarTokens(
    isDarkSurface: true,
    surface: Color(0xFF0C0E12),
    surfaceRaised: Color(0xFF15181F),
    surfaceHover: Color(0xFF1D212A),
    surfaceActive: Color(0xFF2A2212),
    border: Color(0xFF242833),
    textPrimary: Color(0xFFF3F4F6),
    textSecondary: Color(0xFF9AA1AE),
    textMuted: Color(0xFF636B7A),
    accent: Color(0xFFF5B301),
    accentSoft: Color(0xFF2E2410),
    onAccent: Color(0xFF11100B),
    badgeBg: Color(0xFFF5B301),
    badgeFg: Color(0xFF14120A),
    danger: Color(0xFFEF4444),
    dangerBg: Color(0xFF2A1114),
    online: Color(0xFF22C55E),
    expandedWidth: 278,
    railWidth: 82,
    radius: 14,
    rowHeight: 44,
    display: 'PlusJakartaSans',
    body: 'PlusJakartaSans',
    mono: 'JetBrainsMono',
  );

  static const MlSidebarTokens light = MlSidebarTokens(
    isDarkSurface: false,
    surface: Color(0xFFFBFAF7),
    surfaceRaised: Color(0xFFF2F1EC),
    surfaceHover: Color(0xFFEAE8E1),
    surfaceActive: Color(0xFFFBEFCD),
    border: Color(0xFFE3E1D9),
    textPrimary: Color(0xFF15171C),
    textSecondary: Color(0xFF565C68),
    textMuted: Color(0xFF8B919C),
    accent: Color(0xFFB07D06),
    accentSoft: Color(0xFFF7EACB),
    onAccent: Color(0xFFFFFFFF),
    badgeBg: Color(0xFF15171C),
    badgeFg: Color(0xFFF5B301),
    danger: Color(0xFFB91C1C),
    dangerBg: Color(0xFFFBEBEB),
    online: Color(0xFF16A34A),
    expandedWidth: 278,
    railWidth: 82,
    radius: 14,
    rowHeight: 44,
    display: 'PlusJakartaSans',
    body: 'PlusJakartaSans',
    mono: 'JetBrainsMono',
  );
}

class WeighbridgeTokens {
  const WeighbridgeTokens._();

  static const MlSidebarTokens light = MlSidebarTokens(
    isDarkSurface: false,
    surface: Color(0xFFF7F8FA),
    surfaceRaised: Color(0xFFFFFFFF),
    surfaceHover: Color(0xFFEDEFF3),
    surfaceActive: Color(0xFF0E1116), // ink block
    border: Color(0xFFE1E5EA),
    textPrimary: Color(0xFF0E1116),
    textSecondary: Color(0xFF4E5663),
    textMuted: Color(0xFF8E97A4),
    accent: Color(0xFFA87400),
    accentSoft: Color(0xFFF4E9CE),
    onAccent: Color(0xFFFFFFFF),
    badgeBg: Color(0xFF0E1116),
    badgeFg: Color(0xFFF5B301),
    danger: Color(0xFFB3261E),
    dangerBg: Color(0xFFFBECEA),
    online: Color(0xFF15803D),
    expandedWidth: 288,
    railWidth: 72,
    radius: 5,
    rowHeight: 40,
    display: 'PlusJakartaSans',
    body: 'PlusJakartaSans',
    mono: 'JetBrainsMono',
  );

  static const MlSidebarTokens dark = MlSidebarTokens(
    isDarkSurface: true,
    surface: Color(0xFF101317),
    surfaceRaised: Color(0xFF171B21),
    surfaceHover: Color(0xFF1E232B),
    surfaceActive: Color(0xFFF3F5F8), // inverted: paper block on ink
    border: Color(0xFF262C35),
    textPrimary: Color(0xFFEDEFF2),
    textSecondary: Color(0xFFA3ABB8),
    textMuted: Color(0xFF6D7684),
    accent: Color(0xFFE0A32E),
    accentSoft: Color(0xFF2A2211),
    onAccent: Color(0xFF101317),
    badgeBg: Color(0xFFEDEFF2),
    badgeFg: Color(0xFF101317),
    danger: Color(0xFFF87171),
    dangerBg: Color(0xFF2A1517),
    online: Color(0xFF4ADE80),
    expandedWidth: 288,
    railWidth: 72,
    radius: 5,
    rowHeight: 40,
    display: 'PlusJakartaSans',
    body: 'PlusJakartaSans',
    mono: 'JetBrainsMono',
  );
}
