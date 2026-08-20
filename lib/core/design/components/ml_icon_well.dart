import 'package:flutter/material.dart';

import 'package:flutter_application_1/core/design/tokens/ml_tokens.dart';

/// The tinted icon well — the "icon in a chip" surface used by stat tiles,
/// feature tiles, list-row identity icons, section headers and empty states.
/// **60 of the census's decorations** are a circle or tinted square doing this
/// job by hand.
///
/// ## What changed in the M3 rebuild
///
/// **The icon is hidden from screen readers.** A well is decoration standing
/// next to the label that names it: a stat tile announced "truck, Trucks on
/// route, 12" says the same thing twice, and an empty state announced "inbox,
/// No trips yet" reads the picture before the sentence. Material does not
/// exclude `Icon` automatically — an `Icon` with no `semanticLabel` produces
/// no *label*, but it still produces a node. [semanticLabel] is there for the
/// rare well that stands alone and genuinely carries the meaning.
///
/// **The radius is proportional and stays so.** `size * 0.28` is not a shape
/// scale step and deliberately is not one: this is a squircle-ish well whose
/// corner has to track its own size, and pinning it to a fixed 12 makes a 64px
/// well look square and a 32px well look round. Documented rather than
/// "corrected" — the M3 shape scale governs *panels*, not a proportional
/// glyph frame.
class MlIconWell extends StatelessWidget {
  final IconData icon;
  final MlTone tone;
  final double size;
  final double? radius;

  /// Set only when the well is the sole carrier of its meaning. Left null the
  /// well is decorative and excluded from the semantics tree.
  final String? semanticLabel;

  const MlIconWell({
    super.key,
    required this.icon,
    this.tone = MlTone.accent,
    this.size = 46,
    this.radius,
    this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final iconColor =
        tone == MlTone.accent ? MlTokens.accent : tone.colors(brightness).fg;

    final well = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: tone.well(brightness),
        borderRadius: BorderRadius.circular(radius ?? size * 0.28),
      ),
      child: Icon(icon, size: (size * 0.5).roundToDouble(), color: iconColor),
    );

    if (semanticLabel != null) {
      return Semantics(label: semanticLabel, image: true, child: well);
    }
    return ExcludeSemantics(child: well);
  }
}
