import 'package:flutter/material.dart';

import 'package:flutter_application_1/core/design/tokens/m3/ml_scheme.dart';

/// MineLink design tokens, ported 1:1 from
/// `docs/new system design/minelink-new-design-v0.1/tokens/*.css`.
///
/// Raw scale values live here; brightness-aware semantic aliases are on
/// [MlSemantic]; status fg/bg pairs are on [MlTone].
abstract final class MlTokens {
  // ---- Brand ----
  static const cyan50 = Color(0xFFE6FBFF);
  static const cyan100 = Color(0xFFCBF3FB);
  static const cyan200 = Color(0xFF9FE7F4);
  static const cyan300 = Color(0xFF5FD6EA);
  // S5-5 (2026-08-14): cyan400/600 retuned to the exact values the design
  // reference renders — `docs/design-reference.md`, captured from the
  // super-admin dashboard and transporters overview. Both were within ~2% of
  // these already, so this is an alignment, not a new palette.
  static const cyan400 = Color(0xFF22D3EE); // reference accent, dark surfaces
  static const cyan500 = Color(0xFF00B5D8);
  static const cyan600 = Color(0xFF0891B2); // reference accent, light surfaces
  static const cyan700 = Color(0xFF0A7791);
  static const teal700 = Color(0xFF0F6E8C); // Material seed

  /// THE accent. One value, and this is it (S5-5).
  ///
  /// Was `cyan500` (#00B5D8). The design reference — the super-admin dashboard
  /// and transporters overview, captured to `docs/design-reference/` — renders
  /// #22D3EE, and the client ruled on 2026-08-14 that those screens are the
  /// reference. This supersedes CLAUDE.md §5's "brand cyan = #00B5D8".
  ///
  /// `MlGlass.accent` and `MlOv.acc` resolve to the same pair, and
  /// `reference_capture_test.dart` asserts that equality so they cannot drift.
  static const accent = cyan400;
  static const accentHover = cyan600;
  static const accentPress = cyan700;
  static const accentSoft = cyan50;

  // ---- Portal navy chrome ----
  static const navy700 = Color(0xFF0B2545);
  static const navy800 = Color(0xFF0B192E); // sidebar (light theme)
  static const navy900 = Color(0xFF060F20);
  static const navy950 = Color(0xFF020617); // sidebar (dark theme)

  /// ui_kits/shared/shell.jsx sidebar gradient: linear-gradient(168deg,#0c1c34,#050b18)
  static const sidebarGradientTop = Color(0xFF0C1C34);
  static const sidebarGradientBottom = Color(0xFF050B18);

  /// Active nav-tile hue in the shell kit (borders, inset bar, home chip).
  static const sidebarActiveBlue = Color(0xFF6AB8FF);

  /// Brand wordmark gradient (cyan → blue).
  static const wordmarkGradientStart = Color(0xFF7FE3F2);
  static const wordmarkGradientEnd = Color(0xFF5AA2FF);

  // ---- Slate neutral scale ----
  static const slate50 = Color(0xFFF8FAFC);
  static const slate100 = Color(0xFFF1F5F9);
  static const slate200 = Color(0xFFE2E8F0);
  static const slate300 = Color(0xFFCBD5E1);
  static const slate400 = Color(0xFF94A3B8);
  static const slate500 = Color(0xFF64748B);
  static const slate600 = Color(0xFF475569);
  static const slate700 = Color(0xFF334155);
  static const slate800 = Color(0xFF1E293B);
  static const slate900 = Color(0xFF0F172A);
  static const slate950 = Color(0xFF020617);

  /// The ink that goes **on top of a saturated fill** — a primary button, a
  /// selected chip, a tone-filled well, a swipe-to-dismiss background.
  ///
  /// Deliberately theme-independent, and that is the whole point of naming it.
  /// The surface underneath is a brand accent or a semantic tone, and those are
  /// saturated in *both* themes, so the ink on them does not flip with the
  /// theme the way `MlSemantic.textStrong` does. Reaching for
  /// `MlSemantic.of(context).textStrong` here would be the actual bug: on a
  /// light theme it resolves to near-black and vanishes into a cyan fill.
  ///
  /// Added 2026-08-15 while migrating the portal (S5-20). Counting what
  /// `no-material-colors` was measuring found **72 sites** of
  /// `color: Colors.white` / `foregroundColor: Colors.white`, all of them this
  /// one case — including inside `MlButton` itself, which is where the habit
  /// came from. They were not wrong about the colour; they were unnamed, so a
  /// correct use and a lazy `Colors.white` were indistinguishable in review.
  /// This names the decision so the guard can forbid the unnamed form.
  static const inkOnFill = Color(0xFFFFFFFF);

  /// [inkOnFill] at 70% — the secondary line on a filled surface (a subtitle
  /// under a white title on the driver card's navy gradient). Named rather
  /// than written as `Colors.white70` so it reads as the same decision, one
  /// step quieter.
  static const inkOnFill70 = Color(0xB3FFFFFF);

  /// White and black used as **overlay paint** — a wash, a glaze, a scrim, a
  /// cast shadow.
  ///
  /// Distinct from [inkOnFill], which is white *as ink*. These are white and
  /// black *as a translucent layer*, always at an alpha, and the alpha is the
  /// decision. Naming them apart is what lets review tell a deliberate 3%
  /// sheen from a `Colors.white` somebody could not be bothered to look up —
  /// the two were indistinguishable before S5-19, at 40 sites.
  static const overlayLight = Color(0xFFFFFFFF);
  static const overlayDark = Color(0xFF000000);

  /// The ink that goes on top of a **brand-accent** fill — a cyan badge, a
  /// selected rail capsule, an accent-filled chip.
  ///
  /// Distinct from [inkOnFill] and deliberately so. White on `accent`
  /// (#22D3EE) measures 1.9:1, which fails every contrast floor there is; the
  /// console's nav badges and the chat palettes had already independently
  /// settled on this deep cyan-navy, which measures 11.3:1 on the same fill.
  /// Named 2026-08-15 (S5-19) after finding the literal repeated verbatim in
  /// `console_palette_tokens.dart` and across the chat palette table.
  static const inkOnAccent = Color(0xFF04222B);

  // ---- Status hues ----
  static const blue50 = Color(0xFFEFF6FF);
  static const blue600 = Color(0xFF2563EB);
  static const amber50 = Color(0xFFFEF3C7);
  static const amber700 = Color(0xFFB45309);
  static const green50 = Color(0xFFDCFCE7);
  /// "Live" green — a presence dot, an online badge, a healthy status lamp.
  /// Brighter than [green600] because it is almost always a small mark on a
  /// dark chrome rather than text on paper. Counted 12 sites at S5-19.
  static const green500 = Color(0xFF22C55E);
  static const green600 = Color(0xFF16A34A); // confirm / arrived
  static const green700 = Color(0xFF15803D);
  static const orange50 = Color(0xFFFFEDD5);
  static const orange500 = Color(0xFFF97316); // mark departed / logout
  static const orange600 = Color(0xFFEA580C);
  static const orange700 = Color(0xFFC2410C);
  static const red50 = Color(0xFFFEE2E2);
  /// Red on a dark surface. [red600] is tuned for text on paper and goes muddy
  /// on navy; these two are the dark-chrome pair the console already used at
  /// 14 sites before S5-19 named them.
  static const red400 = Color(0xFFF87171);
  static const red500 = Color(0xFFEF4444);
  static const red600 = Color(0xFFDC2626);
  // Violet completes the hue set the design reference uses for org types.
  // Taken from MlOv.violet so the console and the portal cannot drift.
  static const violet50 = Color(0xFFF3E8FF);
  static const violet400 = Color(0xFFA78BFA);
  static const violet700 = Color(0xFF7C3AED);

  /// Blue and amber on a **dark** surface. `blue600`/`amber700` are tuned for
  /// text on paper; these are the console/portal-dark pair the app already
  /// used anonymously.
  static const blue400 = Color(0xFF60A5FA);
  static const amber500 = Color(0xFFF59E0B);

  /// Emerald — the fleet's *available* hue, and deliberately not `green600`.
  /// Availability is a two-stop gradient on a pill, and green600 into green700
  /// reads as one flat colour at that size.
  static const emerald400 = Color(0xFF34D399);
  static const emerald500 = Color(0xFF10B981);

  /// The deep in/out pair used by stockpile and dispatch ledgers: tons IN is
  /// [green800], tons OUT is [red700]. Darker than the `MlTone` pair because
  /// these are figures in a dense table, not status chips.
  static const green800 = Color(0xFF2E7D32);
  static const red700 = Color(0xFFC62828);

  /// The driver hero card's gradient — a lit cyan falling into [navy700] — and
  /// the pale cyan pip drawn on it.
  static const cyan650 = Color(0xFF0AA6C7);
  static const cyan250 = Color(0xFF7EE0F2);

  /// [navy700] at 28% and 33%: the shadow a card casts on the portal's navy.
  /// Stated rather than composed so `const BoxShadow` stays const.
  static const navyShadowSoft = Color(0x470B2545);
  static const navyShadowStrong = Color(0x550B2545);

  /// Black at 35% — the drop shadow under a control floating over a **map**,
  /// where a slate-tinted shadow would tint the terrain under it.
  static const mapControlShadow = Color(0x59000000);

  /// Modal barrier scrims: [barrierStrong] for a dialog that must take focus,
  /// [barrierSoft] for a slide-over that keeps its page legible behind it.
  /// Slate-900 rather than black, so the page behind cools rather than greys.
  static const barrierStrong = Color(0x730F172A);
  static const barrierSoft = Color(0x520F172A);

  /// The coloured bloom under a raised, filled button — the fill's own hue at
  /// ~30%, so the glow reads as light coming off the button rather than as a
  /// grey shadow beneath it.
  static const glowAccent = Color(0x5922D3EE);
  static const glowSuccess = Color(0x4D16A34A);
  static const glowWarn = Color(0x4DF97316);

  /// Waybill stock. The cream is measured off `assets/Varsiwave waybil 2l.png`
  /// — the real printed slip this app reproduces — and the tan is the tint the
  /// NET MASS cell carries on it, which is why neither is a slate.
  static const waybillPaper = Color(0xFFF7EFCD);
  static const waybillMassTint = Color(0xFFF6C19A);

  /// Signature ink. Near-black rather than [slate950]: a signature is drawn as
  /// a physical mark and a blue-tinted one looks like a stamp.
  static const signatureInk = Color(0xFF111111);

  // ---- Tinted icon wells ----
  static const wellCyan = Color(0xFFE2F6FB);
  static const wellAmber = Color(0xFFFDEEDD);
  static const wellGreen = Color(0xFFE3F5EA);
  static const wellBlue = Color(0xFFE7EFFE);

  // ---- Typography ----
  static const fontSans = 'PlusJakartaSans';
  static const fontMono = 'JetBrainsMono';
  static const fontSerif = 'Fraunces';

  // ---- Type scale (px) ----
  //
  // **These are the M3 slot sizes, under the app's older names.**
  //
  // There were TWO type scales, neither derived from the other — this one,
  // and the `TextTheme` in `MlTypeScale`, which is what every Material widget
  // actually resolves. That is the same fault Phase 1 fixed for colour, where
  // `Theme.of(context).colorScheme.primary` and `MlTokens.accent` were simply
  // different colours that both meant "the accent". Here it was
  // `MlTokens.fsBodySm` (13) and `textTheme.bodyMedium` (14) both meaning
  // "small body text", 1px apart, on adjacent lines of the same screen.
  //
  // The theme won, on two grounds: it is what Material widgets read without
  // being told, and it was already the more used of the two (158 sites
  // against 96). So these nine constants are now aliases of their slots, and
  // MineLink has one type scale.
  //
  // Five were already equal. The four that moved, and the direction chosen:
  //
  //   fsDisplay  34 -> 32   headlineLarge. Down: a hero numeral loses nothing
  //                         at 32 and the tile it sits in gets 2px back.
  //   fsH1       26 -> 24   headlineSmall. 26 sits exactly between two slots;
  //                         down, for the same reason.
  //   fsH3       18 -> 16   titleMedium. M3 has no step between 16 and 22, and
  //                         growing a sub-heading by 4px would have been the
  //                         larger change of the two.
  //   fsBody     15 -> 16   bodyLarge. UP, because this one is read rather
  //                         than scanned, and shrinking running text is the
  //                         direction that harms without looking broken.
  //   fsBodySm   13 -> 14   bodyMedium. Up, same reason.
  //
  // Kept as names rather than deleted: 96 call sites read better saying
  // `fsBodySm` than `14.0`, and a name is what makes the next change one edit
  // instead of ninety-six.
  static const fsDisplay = 32.0; // headlineLarge / displaySmall
  static const fsH1 = 24.0; // headlineSmall
  static const fsH2 = 22.0; // titleLarge
  static const fsH3 = 16.0; // titleMedium
  static const fsTitle = 16.0; // titleMedium
  static const fsBody = 16.0; // bodyLarge
  static const fsBodySm = 14.0; // bodyMedium
  static const fsLabel = 12.0; // bodySmall / labelMedium
  static const fsMicro = 11.0; // labelSmall

  // ---- Radii ----
  static const rXs = 6.0;
  static const rSm = 8.0; // chips, badges
  static const rMd = 12.0; // buttons, inputs, nav tiles
  static const rLg = 16.0; // cards, dialogs
  static const rXl = 20.0; // hero tiles
  static const r2xl = 24.0; // bottom sheets
  static const rPill = 999.0;

  // ---- Elevation ----
  static const shadowXs = [
    BoxShadow(color: Color(0x0A0F172A), offset: Offset(0, 1), blurRadius: 2),
  ];
  static const shadowSm = [
    BoxShadow(color: Color(0x0F0F172A), offset: Offset(0, 1), blurRadius: 3),
    BoxShadow(color: Color(0x0A0F172A), offset: Offset(0, 1), blurRadius: 2),
  ];
  static const shadowMd = [
    BoxShadow(color: Color(0x120F172A), offset: Offset(0, 4), blurRadius: 12),
    BoxShadow(color: Color(0x0A0F172A), offset: Offset(0, 2), blurRadius: 4),
  ];
  static const shadowLg = [
    BoxShadow(color: Color(0x1A0F172A), offset: Offset(0, 12), blurRadius: 28),
    BoxShadow(color: Color(0x0D0F172A), offset: Offset(0, 4), blurRadius: 10),
  ];
  static const shadowHero = [
    // Accent-derived: tracks `accent`, which moved to #22D3EE at S5-5.
    BoxShadow(color: Color(0x1222D3EE), offset: Offset(0, 8), blurRadius: 18),
    BoxShadow(color: Color(0x0A0F172A), offset: Offset(0, 2), blurRadius: 6),
  ];
  static const shadowDrawer = [
    BoxShadow(color: Color(0x1F0F172A), offset: Offset(-16, 0), blurRadius: 40),
  ];

  // ---- Motion ----
  static const durFast = Duration(milliseconds: 140);
  static const durBase = Duration(milliseconds: 200);
  static const durSlow = Duration(milliseconds: 260);
  static const durSlideOver = Duration(milliseconds: 280);
  static const durCount = Duration(milliseconds: 850);
  static const easeOutCubic = Curves.easeOutCubic;

  // ---- Layout ----
  static const sidebarWidth = 274.0;
  static const sidebarWidthCollapsed = 78.0;
  static const appBarHeight = 72.0;
  static const contentMaxWidth = 1280.0;
  static const contentPadding = 28.0;
}

/// The org-type hue set — **one** palette, as the design reference renders it:
/// `MINE` amber · `BUYER` violet · `TRANSPORTER` cyan (see the badge pills in
/// `docs/design-reference/super-admin-dashboard-dark.png`).
///
/// There were TWO competing sets before 2026-08-14: the reference's, and a
/// blue/purple/orange trio duplicated verbatim in
/// `organization_management_screen` and `request_review_screen`. Two palettes
/// for one concept means a buyer is violet on one screen and purple on the
/// next, which is precisely the kind of drift a design system exists to stop.
enum MlOrgTone {
  mineSupplier,
  buyer,
  transporter;

  /// Parses the wire strings `org_type` uses; unknown values fall back to the
  /// neutral-most member rather than throwing, per the tolerant-parse rule.
  static MlOrgTone parse(String? wire) => switch (wire) {
        'buyer' => MlOrgTone.buyer,
        'transporter' => MlOrgTone.transporter,
        _ => MlOrgTone.mineSupplier,
      };

  MlToneColors colors(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    switch (this) {
      case MlOrgTone.mineSupplier:
        return dark
            ? const MlToneColors(Color(0xFFE6B56B), Color(0x33B45309))
            : const MlToneColors(MlTokens.amber700, MlTokens.amber50);
      case MlOrgTone.buyer:
        return dark
            ? const MlToneColors(MlTokens.violet400, Color(0x337C3AED))
            : const MlToneColors(MlTokens.violet700, MlTokens.violet50);
      case MlOrgTone.transporter:
        return dark
            ? const MlToneColors(MlTokens.cyan400, Color(0x2422D3EE))
            : const MlToneColors(MlTokens.cyan700, MlTokens.cyan50);
    }
  }
}

/// A foreground/background tonal pair for one status hue.
class MlToneColors {
  final Color fg;
  final Color bg;
  const MlToneColors(this.fg, this.bg);
}

/// Status / accent tones — the fixed hue set carrying trip & truck lifecycle
/// meaning (blue = in transit, amber = at mine, green = loaded/available,
/// orange = maintenance/departure, red = declined/error).
enum MlTone {
  transit,
  atMine,
  done,
  warn,
  error,
  neutral,
  accent;

  MlToneColors colors(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    switch (this) {
      case MlTone.transit:
        return dark
            ? const MlToneColors(Color(0xFF7AB0FF), Color(0x2E2563EB))
            : const MlToneColors(MlTokens.blue600, MlTokens.blue50);
      case MlTone.atMine:
        return dark
            ? const MlToneColors(Color(0xFFE6B56B), Color(0x33B45309))
            : const MlToneColors(MlTokens.amber700, MlTokens.amber50);
      case MlTone.done:
        return dark
            ? const MlToneColors(Color(0xFF5CC487), Color(0x3315803D))
            : const MlToneColors(MlTokens.green700, MlTokens.green50);
      case MlTone.warn:
        return dark
            ? const MlToneColors(Color(0xFFFB923C), Color(0x33C2410C))
            : const MlToneColors(MlTokens.orange700, MlTokens.orange50);
      case MlTone.error:
        return dark
            ? const MlToneColors(Color(0xFFF0715A), Color(0x33DC2626))
            : const MlToneColors(MlTokens.red600, MlTokens.red50);
      case MlTone.neutral:
        return dark
            ? const MlToneColors(MlTokens.slate400, Color(0x2994A3B8))
            : const MlToneColors(MlTokens.slate600, MlTokens.slate100);
      case MlTone.accent:
        return dark
            ? const MlToneColors(MlTokens.cyan400, Color(0x2422D3EE))
            // cyan700, not cyan600. Measured on the cyan50 well these chips
            // actually sit on: cyan600 gives 3.44:1 and cyan700 gives 4.83:1,
            // against a 4.5:1 floor. Chip and badge text is small, so the
            // normal-text threshold is the one that applies. Pinned by
            // test/core/accent_contrast_test.dart.
            : const MlToneColors(MlTokens.cyan700, MlTokens.cyan50);
    }
  }

  /// This tone's pair for [context]'s theme.
  ///
  /// Prefer this over `colors(Theme.of(context).brightness)` — it is the same
  /// answer with one fewer thing to get wrong, and it is the seam through
  /// which a tone could later become scheme-aware without touching call sites.
  ///
  /// **The hues themselves are deliberately not derived from the
  /// `ColorScheme`.** M3 supplies exactly one semantic hue — `error`. These
  /// seven carry *lifecycle* meaning (blue = in transit, amber = at mine,
  /// green = loaded, orange = maintenance, red = declined) and that meaning is
  /// fixed by the domain, not by the theme. Regenerating them from a tonal
  /// palette would make "at mine" change hue when somebody picks a new accent
  /// in Settings, which is a data-integrity problem dressed as a style choice.
  /// A status hue is content, not chrome.
  MlToneColors colorsOf(BuildContext context) =>
      colors(Theme.of(context).brightness);

  /// Tinted icon-well fill for this tone, for [context]'s theme.
  Color wellOf(BuildContext context) => well(Theme.of(context).brightness);

  /// Tinted icon-well fill for this tone (feature/stat cards).
  Color well(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    switch (this) {
      case MlTone.atMine:
      case MlTone.warn:
        return dark ? const Color(0x29E0A44A) : MlTokens.wellAmber;
      case MlTone.done:
        return dark ? const Color(0x245CC487) : MlTokens.wellGreen;
      case MlTone.transit:
        return dark ? const Color(0x246AA4F0) : MlTokens.wellBlue;
      case MlTone.error:
        return dark ? const Color(0x29DC2626) : MlTokens.red50;
      case MlTone.neutral:
        return dark ? const Color(0x2994A3B8) : MlTokens.slate100;
      case MlTone.accent:
        return dark ? const Color(0x2422D3EE) : MlTokens.wellCyan;
    }
  }
}

/// Brightness-aware semantic aliases mirroring `tokens/semantic.css`
/// (light `:root` values and the `[data-theme="dark"]` remap).
class MlSemantic {
  final Color surfaceApp;
  final Color surfaceCard;
  final Color surfaceRaised;
  final Color surfaceSunken;
  final Color textStrong;
  final Color textBody;
  final Color textMuted;
  final Color textFaint;
  final Color borderSubtle;
  final Color borderCard;
  final Color borderStrong;
  final Color borderAccent;
  final Color divider;

  const MlSemantic._({
    required this.surfaceApp,
    required this.surfaceCard,
    required this.surfaceRaised,
    required this.surfaceSunken,
    required this.textStrong,
    required this.textBody,
    required this.textMuted,
    required this.textFaint,
    required this.borderSubtle,
    required this.borderCard,
    required this.borderStrong,
    required this.borderAccent,
    required this.divider,
  });

  /// Build a custom semantic palette (used by the mine premium themes to skin
  /// the whole mine UI). Additive — the light/dark defaults are unchanged.
  const MlSemantic.custom({
    required Color surfaceApp,
    required Color surfaceCard,
    required Color surfaceRaised,
    required Color surfaceSunken,
    required Color textStrong,
    required Color textBody,
    required Color textMuted,
    required Color textFaint,
    required Color borderSubtle,
    required Color borderCard,
    required Color borderStrong,
    required Color borderAccent,
    required Color divider,
  }) : this._(
          surfaceApp: surfaceApp,
          surfaceCard: surfaceCard,
          surfaceRaised: surfaceRaised,
          surfaceSunken: surfaceSunken,
          textStrong: textStrong,
          textBody: textBody,
          textMuted: textMuted,
          textFaint: textFaint,
          borderSubtle: borderSubtle,
          borderCard: borderCard,
          borderStrong: borderStrong,
          borderAccent: borderAccent,
          divider: divider,
        );

  /// Derives the whole semantic palette from a Material 3 [ColorScheme].
  ///
  /// **This is the change that makes the design system one system.** These
  /// thirteen values used to be hand-authored constants living beside a
  /// `ColorScheme` that was seeded from a different colour entirely, so
  /// `MlSemantic.of(context).surfaceCard` and
  /// `Theme.of(context).colorScheme.surfaceContainerLow` were unrelated
  /// colours that both meant "card". Now there is one source and this is a
  /// view onto it.
  ///
  /// ### Two places the mapping is not one-to-one, and why
  ///
  /// **1. `surfaceCard` reads a different role per brightness.** In light this
  /// app puts white cards on a slate canvas — cards *lighter* than the page.
  /// In dark, cards are lighter than the page too. But M3's container ladder
  /// runs *darker* as it rises in light and *lighter* as it rises in dark, so
  /// "one step above the canvas" is `surfaceContainerLowest` going one way and
  /// `surfaceContainer` going the other. Naming that translation is exactly
  /// what this class is for; hiding it inside the scheme would mean writing a
  /// scheme that lies about which role is which.
  ///
  /// **2. The ink ladder has four steps and M3 has two.** M3 gives exactly
  /// `onSurface` and `onSurfaceVariant`. This app's screens genuinely use four
  /// weights — a table has a heading, a value, a unit and a hint in one row.
  /// The two middle steps are therefore *derived* from the two real roles by
  /// alpha rather than invented as new constants, so they cannot drift away
  /// from the scheme when it changes.
  static MlSemantic fromScheme(ColorScheme scheme) {
    if (identical(scheme, _cachedScheme)) return _cached!;
    final light = scheme.brightness == Brightness.light;
    final built = MlSemantic._(
      surfaceApp: scheme.surface,
      surfaceCard:
          light ? scheme.surfaceContainerLowest : scheme.surfaceContainer,
      surfaceRaised:
          light ? scheme.surfaceContainerLow : scheme.surfaceContainerHigh,
      surfaceSunken:
          light ? scheme.surfaceContainer : scheme.surfaceContainerLowest,
      textStrong: scheme.onSurface,
      textBody: scheme.onSurface.withValues(alpha: 0.86),
      textMuted: scheme.onSurfaceVariant,
      textFaint: scheme.onSurfaceVariant.withValues(alpha: 0.62),
      // `borderSubtle`, `borderCard` and `divider` were three separate
      // near-identical greys (#E2E8F0 / #E7EDF3 / #E9EEF4). Nothing ever
      // depended on the difference — it is below the threshold at which a
      // hairline is distinguishable — so they collapse onto one role.
      borderSubtle: scheme.outlineVariant,
      borderCard: scheme.outlineVariant,
      borderStrong: scheme.outline,
      borderAccent: scheme.primary.withValues(alpha: 0.45),
      divider: scheme.outlineVariant,
    );
    _cachedScheme = scheme;
    _cached = built;
    return built;
  }

  // A one-entry memo. `Theme.of(context).colorScheme` hands back the same
  // instance for the life of a theme, so `identical` hits on every call after
  // the first and `of()` stays allocation-free on the hot path — it is called
  // in the build method of most widgets in the app.
  static ColorScheme? _cachedScheme;
  static MlSemantic? _cached;

  /// The palette for [brightness], from the canonical scheme of that
  /// brightness.
  ///
  /// Prefer [of] wherever a `BuildContext` is available: this cannot see a
  /// per-user accent or the high-contrast preference, because a `Brightness`
  /// does not carry them. It exists for the handful of places that genuinely
  /// have no context (a `paint()` on a custom painter given only a brightness,
  /// a PDF being rendered off-screen).
  static MlSemantic from(Brightness brightness) =>
      fromScheme(MlScheme.of(brightness));

  /// Resolves the active semantic palette.
  ///
  /// When an [MlSemanticScope] is present above [context] its palette wins;
  /// otherwise the palette is derived from the theme's own `ColorScheme` — so
  /// a per-user accent or the high-contrast preference flows through here
  /// automatically instead of needing a parallel override.
  static MlSemantic of(BuildContext context) =>
      MlSemanticScope.maybeOf(context) ??
      fromScheme(Theme.of(context).colorScheme);
}

/// Overrides [MlSemantic.of] for its subtree. Used to skin the entire mine
/// portal (sidebar, app bar, every page) with a premium palette while leaving
/// the rest of the app on the default light/dark semantics.
class MlSemanticScope extends InheritedWidget {
  final MlSemantic semantic;

  const MlSemanticScope({
    super.key,
    required this.semantic,
    required super.child,
  });

  static MlSemantic? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<MlSemanticScope>()
      ?.semantic;

  @override
  bool updateShouldNotify(MlSemanticScope oldWidget) =>
      oldWidget.semantic != semantic;
}

/// The two text roles that are **not** the UI sans, named once.
///
/// `docs/design-reference.md` §3 gives three faces three jobs: Fraunces for
/// display numerals and section titles, JetBrainsMono for codes and figures,
/// PlusJakartaSans for everything else. The third needs no helper — it is the
/// theme's default. The first two do, because reaching for them means writing
/// out a family, a size, a weight and a font feature, and every site that did
/// so by hand got at least one of them wrong.
///
/// Measured 2026-08-15 while closing S5-6/S5-7: `AppTheme._mlTextTheme` ends
/// with `.apply(fontFamily: MlTokens.fontSans)`, which covers the **whole**
/// text theme — so every `textTheme.headlineSmall` numeral the portal drew was
/// in the UI sans, at 12 sites. Six of them went through `AnimatedTons`, which
/// took its style from the caller and so had no opinion of its own.
abstract final class MlType {
  const MlType._();

  /// A **display numeral** — a tonnage, a count, a headline figure.
  ///
  /// Fraunces, with tabular figures. The tabular part is not cosmetic: an
  /// `AnimatedTons` counting 0 → 128.4 re-measures on every frame with
  /// proportional digits, so the number visibly jitters as it climbs, and a
  /// column of figures fails to line up.
  ///
  /// Weight is the display face's own (`w500`) rather than the `w800` the sans
  /// needed to carry emphasis — Fraunces already has it.
  static TextStyle figure({
    required Color color,
    double size = MlTokens.fsH2,
    double? height,
  }) =>
      TextStyle(
        fontFamily: MlTokens.fontSerif,
        fontSize: size,
        fontWeight: FontWeight.w500,
        letterSpacing: -0.2,
        color: color,
        height: height ?? 1.1,
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  /// A **code**: a truck plate, a waybill number, a reference, a timer.
  ///
  /// JetBrainsMono, also tabular. Deliberately separate from [figure] — a
  /// plate is not a numeral, and collapsing the two is the easy mistake. §3
  /// puts `CK 84 RT GP` and `TRP-000123` in mono precisely so they read as
  /// machine identifiers rather than as quantities.
  static TextStyle code({
    required Color color,
    double size = MlTokens.fsBody,
    FontWeight weight = FontWeight.w600,
    double? letterSpacing,
  }) =>
      TextStyle(
        fontFamily: MlTokens.fontMono,
        fontSize: size,
        fontWeight: weight,
        letterSpacing: letterSpacing,
        color: color,
        fontFeatures: const [FontFeature.tabularFigures()],
      );
}
