import 'package:flutter/material.dart';

import 'package:flutter_application_1/core/design/tokens/ml_tokens.dart';

/// Console **series** and **identity** colours — the hues a chart or an avatar
/// picks from, as opposed to the hues a surface is painted in.
///
/// The two are worth separating. A surface colour has one right answer and
/// belongs in `MlSemantic`/`MlGlass`. A series colour has to be *distinguishable
/// from its neighbours*, which is a property of the set, not of any member —
/// so a ramp is the unit, and pulling one entry out to "reuse the token" is
/// how a chart ends up with two identical wedges.
///
/// Collected at S5-19 from three places that each had their own copy of the
/// idea: `super_admin_dashboard_v2_screen` (the avatar ramp and three spark
/// hues), `minelink_screens_core` (the chip tones), and
/// `super_admin_dashboard_widgets` (the "NEW" pill's green wash).
abstract final class MlConsolePalettes {
  const MlConsolePalettes._();

  /// Two-stop gradients for organisation avatars, indexed by a stable hash of
  /// the org id so a company keeps its colour between sessions.
  ///
  /// Six pairs, chosen to stay apart at 28px: indigo→violet, pink→purple,
  /// orange→amber, mint→emerald, cyan→sky, violet→deep violet.
  static const List<List<Color>> avatarRamp = [
    [Color(0xFF6D8BFF), Color(0xFF9B6CF0)],
    [Color(0xFFF472B6), Color(0xFFA855F7)],
    [Color(0xFFFB9A4B), MlTokens.orange500],
    [Color(0xFF4ADE80), Color(0xFF10B981)],
    [MlTokens.accent, Color(0xFF0EA5E9)],
    [MlTokens.violet400, MlTokens.violet700],
  ];

  /// Sparkline stroke for each of the three org-type rollup cards. Lighter
  /// than the card's chip tone so a 24px trend reads against the tinted well
  /// it is drawn on rather than disappearing into it.
  static const Color sparkTransporter = Color(0xFF5FA8FF);
  static const Color sparkBuyer = Color(0xFFB98CFF);
  static const Color sparkMine = Color(0xFFF0A55F);

  /// The "NEW" pill's fill and edge — [MlTokens.green500] at 14% and 30%, the
  /// values the design states directly as `rgba(34,197,94,…)`.
  static const Color newPillFill = Color(0x2422C55E);
  static const Color newPillBorder = Color(0x4D22C55E);

  /// Chip / tinted-well hue pairs. `base` backs the well and its border (at
  /// 10% and 28%); `fg` is the glyph on top, one step brighter so it reads
  /// against its own tint.
  ///
  /// Six of them, and they are a *set*: `cyan` and `violet` deliberately use
  /// one value for both slots because those two are already light enough at
  /// base to serve as their own foreground, and lifting them further would
  /// have broken the even spacing across the six.
  /// Declared as twelve `const` colours rather than as a list of records,
  /// because `MlChipTone.amber` and friends must stay `const` — the widget
  /// fixtures build `const MlPendingRequest(tone: MlChipTone.amber)`, and Dart
  /// cannot const-evaluate a read out of a collection. [chipRamp] is the same
  /// twelve in order, for anything that wants to iterate them.
  static const Color chipBlueBase = Color(0xFF608CFF);
  static const Color chipBlueFg = Color(0xFF8FB4FF);
  static const Color chipCyanBase = Color(0xFF6AB8FF);
  static const Color chipCyanFg = chipCyanBase;
  static const Color chipGreenBase = Color(0xFF34C778);
  static const Color chipGreenFg = Color(0xFF5FD68F);
  static const Color chipAmberBase = Color(0xFFF58C3C);
  static const Color chipAmberFg = Color(0xFFF7A45A);
  static const Color chipRedBase = Color(0xFFF45A6E);
  static const Color chipRedFg = Color(0xFFF77F92);
  static const Color chipVioletBase = Color(0xFFC07CF0);
  static const Color chipVioletFg = chipVioletBase;

  static const List<(Color base, Color fg)> chipRamp = [
    (chipBlueBase, chipBlueFg),
    (chipCyanBase, chipCyanFg),
    (chipGreenBase, chipGreenFg),
    (chipAmberBase, chipAmberFg),
    (chipRedBase, chipRedFg),
    (chipVioletBase, chipVioletFg),
  ];

  /// Type on a small filled badge in the console rail and dashboard. The dark
  /// value is a near-black warmed toward the gold the Haul skin fills these
  /// with; the light value is plain paper.
  static const Color badgeInkOnDark = Color(0xFF14120A);
  static const Color badgeInkOnLight = MlTokens.inkOnFill;

  /// The console's micro-label ink — the 9.5px uppercase captions above stat
  /// figures. The design hardcodes it in **both** themes, which is unusual
  /// enough to be worth stating: these labels always sit on a card, never on
  /// the canvas, and the card is light in one theme and navy in the other, so
  /// a mid slate is the one value that reads on both.
  static const Color microLabelInk = Color(0xFF465774);
}
