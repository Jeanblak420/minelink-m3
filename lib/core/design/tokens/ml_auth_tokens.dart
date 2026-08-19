import 'package:flutter/material.dart';

/// Sign-in surface tokens — the pre-session palette, type, geometry and brand
/// assets.
///
/// Extracted from `features/auth/widgets/signin/minelink_signin_theme.dart` on
/// 2026-08-15 (S5-19). It is a token table in the same sense `MlTokens` is,
/// and the reason it is a *separate* one is in that file's header and still
/// holds: the sign-in screen renders before any session exists, so it must not
/// reach into anything that assumes an authenticated user. The token layer
/// imports nothing but Flutter, which satisfies that constraint more strictly
/// than living under `features/auth/` ever did.
///
/// It is not folded into `MlTokens` because it is not the app palette: the
/// sign-in runs a fixed dark brand surface (gold mark, cyan action) regardless
/// of the theme the user later picks, and it has no light variant by design.
/// `MlAuth.accent` is nonetheless the same `#22D3EE` as `MlTokens.accent`, and
/// `MlAuth.onAccent` the same decision as `MlTokens.inkOnAccent` one shade
/// apart; `test/core/auth_token_alignment_test.dart` pins the first so the two
/// cannot drift.
@immutable
class MlAuth {
  const MlAuth._();

  // -- surfaces ------------------------------------------------------------
  static const Color bg = Color(0xFF050912);
  static const Color bg2 = Color(0xFF0A1220);
  static const Color panel = Color(0xFF0D1626);

  static const Color line = Color(0x12FFFFFF); // ~7%

  /// The two white tints this dark surface uses as *fills* rather than as
  /// rules: a ghost button's resting wash and an icon button's hover. Named at
  /// S5-19 — they were `Colors.white.withValues(alpha: …)`, which reads as an
  /// ad-hoc choice and is indistinguishable from a lazy one.
  static const Color tintRest = Color(0x08FFFFFF); // 3%
  static const Color tintHover = Color(0x0FFFFFFF); // 6%

  /// Drop shadow under a floating notice on this surface. Black at 50% rather
  /// than a slate-tinted shadow: the sign-in backdrop is near-black already,
  /// and a tinted shadow reads as a halo on it.
  static const Color shadow = Color(0x80000000);

  // -- the backdrop, as painted ---------------------------------------------
  /// Three stops of the sign-in page's own gradient. Not [bg]/[bg2]/[panel]:
  /// those are flat surfaces a card sits on, these are a lit wash across the
  /// whole viewport, and the design gives the two different values.
  static const Color backdropTop = Color(0xFF08111F);
  static const Color backdropMid = Color(0xFF0B1A2E);
  static const Color backdropBottom = Color(0xFF061019);

  /// The sign-in card's own two-stop fill, at the alphas the design states —
  /// it is translucent so the backdrop's bloom shows through it.
  static const Color cardTop = Color(0xDC142034); // #142034 @ 86%
  static const Color cardBottom = Color(0xE60B1321); // #0B1321 @ 90%

  /// A sheet or popover raised above the card. Nearly opaque, so the bloom
  /// stops at its edge and the layering reads.
  static const Color sheetBase = Color(0xED080F1A); // #080F1A @ 93%

  /// The indigo bloom in the brand panel's upper corner — the one hue on this
  /// screen that is neither gold nor cyan, and the reason the backdrop does
  /// not read as flat navy.
  static const Color bloomIndigo = Color(0xFF6366F1);

  // -- the shared auth shell ------------------------------------------------
  // `auth_shell.dart` wraps the non-sign-in auth screens (forgot password,
  // reset, WhatsApp OTP). It runs the same fixed dark surface at one step less
  // contrast, because those screens are a form and a sentence rather than a
  // brand moment.
  static const Color shellSurface = Color(0xFF0C1626);
  static const Color shellInkHi = Color(0xFFEFF4FA);
  static const Color shellInkMid = Color(0xFF8DA0BC);
  static const Color shellInkBody = Color(0xC7E2E8F0); // slate-200 @ 78%
  static const Color shellInkMuted = Color(0xD994A3B8); // slate-400 @ 85%
  static const Color shellHairline = Color(0x0F94A3B8); // slate-400 @ 6%
  static const Color line2 = Color(0x1CFFFFFF); // ~11%
  static const Color lineStrong = Color(0x2EFFFFFF); // ~18%

  // -- ink -----------------------------------------------------------------
  static const Color inkHi = Color(0xFFF2F6FC);
  static const Color ink = Color(0xFFC3CFE2);
  static const Color inkMid = Color(0xFF8494AC);
  static const Color inkLo = Color(0xFF5D6C86);
  static const Color inkXlo = Color(0xFF3B475E);

  // -- brand & status ------------------------------------------------------
  static const Color gold = Color(0xFFF5B301);
  static const Color gold2 = Color(0xFFFFD34D);
  static const Color accent = Color(0xFF22D3EE);
  static const Color accent2 = Color(0xFF67E8F9);
  static const Color accent3 = Color(0xFF5EEAD4);
  static const Color good = Color(0xFF34D399);
  static const Color warn = Color(0xFFF59E0B);
  static const Color bad = Color(0xFFFB7185);
  static const Color whatsapp = Color(0xFF25D366);

  /// Ink used on top of the cyan action colour.
  static const Color onAccent = Color(0xFF04202A);

  /// [onAccent] at 28% — the unfilled track of a spinner drawn *on* an accent
  /// fill (the primary button's busy state). Named at S5-19; it was written as
  /// the raw `0x4704202A` at the one call site.
  static const Color onAccentTrack = Color(0x4704202A);

  /// The deep end of the primary button's three-stop accent sweep
  /// (accent2 → accent → here). Darker than [accent] so the gradient reads as
  /// lit from the top-left rather than as a flat fill.
  static const Color accentDeep = Color(0xFF0EA5C4);

  /// The two-stop sweep a ghost/secondary action lifts to on hover — [accent2]
  /// and [accent] each one step brighter.
  static const Color accentLift1 = Color(0xFF8CF0FF);
  static const Color accentLift2 = Color(0xFF3ADDF5);

  /// Message ink inside a banner, tinted toward the banner's own hue so the
  /// text belongs to it rather than sitting on it. Paired with [bad] and
  /// [accent] respectively.
  static const Color inkOnBad = Color(0xFFFFD9DF);
  static const Color inkOnAccentBanner = Color(0xFFCFF5FD);

  /// Label ink for a ghost button on hover — [inkHi] pulled toward [good], so
  /// a confirming secondary action warms rather than just brightens.
  static const Color inkHiGood = Color(0xFFDDF7E6);

  // -- type ----------------------------------------------------------------
  // These three are already registered in pubspec for the console. Do not add
  // Inter or Instrument Serif — Flutter falls back silently and the screen
  // quietly loses its character with nothing to catch it.
  static const String sans = 'PlusJakartaSans';
  static const String mono = 'JetBrainsMono';
  static const String serif = 'Fraunces';

  // -- geometry ------------------------------------------------------------
  static const double cardMaxWidth = 452;
  static const double cardRadius = 20;
  static const double fieldRadius = 13;
  static const double fieldHeight = 54;

  /// Below this the brand panel is replaced by a slim header. On a phone the
  /// sign-in is the job; the marketing is not.
  static const double splitBreakpoint = 1040;

  // -- brand assets --------------------------------------------------------
  // Repointed at this repo's real filenames (the drop guessed
  // `White-ML-Logo.png` / `White-ML-Icon.png`). These are the same two
  // white/gold artworks the rest of the app uses via `MineLinkLogo` /
  // `MineLinkMark` in `core/widgets/minelink_logo.dart` — cropped to their
  // content bounds by the brand owner on 2026-08-05. `assets/branding/` is
  // registered as a directory in pubspec, so nothing needed adding there.
  static const String logoAsset = 'assets/branding/minelink_logo_white.png';
  static const String iconAsset = 'assets/branding/minelink_mark_white.png';
}
