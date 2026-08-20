import 'package:flutter/material.dart';
import 'package:flutter_application_1/core/design/tokens/ml_tokens.dart';

/// Rounded-square tinted icon well — the one primitive every
/// "icon in a chip" surface uses (stat tiles, feature tiles, list-row
/// identity icons, section headers). Cyan by default; amber/green/blue
/// to vary rhythm across a row.
///
/// Uses flat Material Symbols glyphs in a tinted well (the app's standard,
/// as on the Super-Admin dashboard).
class MlIconWell extends StatelessWidget {
  final IconData icon;
  final MlTone tone;
  final double size;
  final double? radius;

  const MlIconWell({
    super.key,
    required this.icon,
    this.tone = MlTone.accent,
    this.size = 46,
    this.radius,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final iconColor =
        tone == MlTone.accent ? MlTokens.accent : tone.colors(brightness).fg;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: tone.well(brightness),
        borderRadius: BorderRadius.circular(radius ?? size * 0.28),
      ),
      child: Icon(icon, size: (size * 0.5).roundToDouble(), color: iconColor),
    );
  }
}
