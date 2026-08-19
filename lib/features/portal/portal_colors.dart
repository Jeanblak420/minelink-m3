import 'package:flutter_application_1/core/design/tokens/ml_tokens.dart';

/// MineLink portal chrome palette. Values delegate to [MlTokens]
/// (ported from docs/new system design/minelink-new-design-v0.1).
abstract final class PortalColors {
  /// The one member still worth having here: a short alias onto the design
  /// token, used widely enough that spelling it out at every call site is
  /// noise. Everything else has gone.
  static const accent = MlTokens.accent;

  // ── sidebar* DELETED 2026-08-14 (S5-8, P5-13) ─────────────────────────────
  //
  // sidebarLight / sidebarDark / sidebarBackground / sidebarGradient /
  // sidebarActive / sidebarOnBackground / sidebarMuted are gone.
  //
  // Most of them were not being used as a rail at all. `sidebarLight` (navy800)
  // was the backgroundColor of SIX detail-screen AppBars and FOUR primary
  // buttons — a rail colour borrowed as page chrome and as a button fill. The
  // design reference has no navy app bars: content sits on the canvas, and a
  // primary action is the accent. Those sites now use MlSemantic.surfaceApp /
  // MlSemantic.textStrong and MlTokens.accent with readable ink.
  //
  // The one genuine rail usage — the gradient — moved to
  // `core/design/tokens/ml_rail_tokens.dart` as `mlPortalRailGradient`, beside
  // the console's rail tokens, because S5-10 merges the two shells and a rail
  // gradient living in a feature's colour file is one that gets hand-copied.

  // ── metric* DELETED 2026-08-14 (S5-8, P5-12) ──────────────────────────────
  //
  // Seven ColorScheme-based helpers — metricCardFill, metricIconWell,
  // metricBorder, metricIconColor, metricValueColor, metricActionForeground,
  // metricActionFill — used at 50 sites across 10 files. They are gone; those
  // sites now resolve through `MlSemantic.of(context)` and `MlTokens.accent`.
  //
  // They were not aliases. `metricCardFill` blended the accent at 11% over
  // `surfaceContainerLow` and `metricBorder` at 22% over `outlineVariant`, so
  // every portal card carried a cyan wash and a cyan-tinted border. The design
  // reference does the opposite: neutral panels, with a coloured LEFT BAR
  // carrying the tone (docs/design-reference.md §4). Dropping the wash is what
  // moves the portal onto the reference rather than merely renaming a token.
  //
  // Taking a ColorScheme was also the reason they could not simply be swapped:
  // MlSemantic takes a BuildContext, which is why this waited for the portal
  // layout sweep to exist before it was safe to do.
}
