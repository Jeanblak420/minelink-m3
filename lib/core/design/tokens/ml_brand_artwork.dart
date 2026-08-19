import 'package:flutter/material.dart';

import 'package:flutter_application_1/core/design/tokens/ml_tokens.dart';

/// Colours that belong to a **drawn mark**, not to the interface.
///
/// The distinction matters and it is the reason this file exists. A UI colour
/// answers "what does this surface mean here" and must follow the theme. An
/// artwork colour answers "what is this thing made of" — the shade partway
/// down a sphere, the rim light on its edge, the shadow inside a speech
/// bubble. It does not flip in light mode any more than a logo does, and there
/// is no semantic token that could express it, because it expresses no
/// semantics.
///
/// `MlTokens.wordmarkGradientStart/End` were already here on that reasoning.
/// S5-19 found the live-chat launcher's 12-colour artwork palette declared as
/// file-private constants inside `features/chat/widgets/live_chat_icon.dart`,
/// which made them invisible to the design system and unusable by the marks
/// that need to match — so they join it.
abstract final class MlLiveChatIconArt {
  const MlLiveChatIconArt._();

  // ── The cyan disc ──────────────────────────────────────────────────────
  // A five-stop shade ramp for one sphere, lit from the upper left. The mid
  // tone is THE brand accent; the other four are that accent rendered as a
  // solid object, which is why they are not further tokens in their own right.
  /// Specular highlight, upper left.
  static const discBright = Color(0xFF7FE4F5);

  /// Body — the same accent every other surface uses.
  static const discMain = MlTokens.accent;

  /// Terminator, where the surface turns away from the light.
  static const discDeep = Color(0xFF0781A1);

  /// Core shadow at the lower right.
  static const discDark = Color(0xFF06485A);

  /// Rim light picked up from the page behind the disc.
  static const discRim = Color(0xFF2CC7E4);

  // ── The orange typing bubble ───────────────────────────────────────────
  static const bubbleBright = Color(0xFFFFA253);
  static const bubbleMain = Color(0xFFF26A1B);
  static const bubbleDeep = MlTokens.orange700;

  // ── The white speech-bubble mark on the disc face ──────────────────────
  static const markFace = MlTokens.inkOnFill;

  /// The mark's underside, catching cyan bounce off the disc.
  static const markShade = Color(0xFFEAF6FB);

  /// The three message lines drawn inside the mark.
  static const markLine = Color(0xFF0E86A8);

  // ── The unread-count badge ─────────────────────────────────────────────
  // A second sphere, same construction, in alert red. Its own ramp rather
  // than `MlTokens.red*` for the reason at the top of this file: these are
  // three stops of one radial gradient, not three meanings.
  static const badgeBright = Color(0xFFFF8A78);
  static const badgeMain = Color(0xFFF4321F);
  static const badgeDeep = Color(0xFFB30E04);

  /// Contact shadow under the tilted disc, and the drop shadow under the
  /// numeral on the badge.
  static const contactShadow = Color(0x61000000);
  static const numeralShadow = Color(0x66000000);

  /// The badge's white rim, and the glaze across its top.
  static const badgeRim = Color(0xD9FFFFFF);
  static const badgeGlaze = Color(0x8CFFFFFF);

  /// Pure white and pure black used as **paint**: every remaining glaze, rim
  /// light and cast shadow on these marks is one of the two at an alpha, and
  /// the alpha is the drawing decision.
  ///
  /// Named rather than written `Colors.white` / `Colors.black` for one
  /// reason: in review those two are indistinguishable from a UI colour
  /// somebody could not be bothered to look up, which is the whole fault
  /// `no-material-colors` was written to catch. Here they are correct, and
  /// saying so in the name is cheaper than arguing it at each of 18 sites.
  static const glaze = Color(0xFFFFFFFF);
  static const shade = Color(0xFF000000);
}
