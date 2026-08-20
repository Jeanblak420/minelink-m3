import 'package:flutter/material.dart';

import 'package:flutter_application_1/core/design/tokens/m3/ml_shape.dart';
import 'package:flutter_application_1/core/design/tokens/ml_tokens.dart';

/// A vehicle plate, waybill number, ticket or serial — the machine identifiers.
///
/// Always monospace and always tabular. `docs/design-reference.md` §3 puts
/// `CK 84 RT GP` and `TRP-000123` in mono precisely so they read as machine
/// identifiers rather than as quantities, which is also why this is a separate
/// component from the display numeral ([MlType.figure]) rather than a size of
/// it.
///
/// ## What changed in the M3 rebuild
///
/// **The style is [MlType.code] rather than a fifth hand-written copy of it.**
/// This file spelled out family, size, weight, tracking and
/// `FontFeature.tabularFigures()` inline — and it is one of **138 sites in
/// `lib/` that name `MlTokens.fontMono` by hand**. The helper exists so that
/// list can shrink; a component in the design system reaching past it set the
/// worst possible example.
///
/// **The radius is a scale step** — [MlShape.radiusSmall] (8), which is the
/// value it already used, now named as a step rather than as `rSm`.
class MlPlatePill extends StatelessWidget {
  final String text;
  final double fontSize;

  const MlPlatePill(this.text, {super.key, this.fontSize = 13});

  @override
  Widget build(BuildContext context) {
    final semantic = MlSemantic.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: semantic.surfaceSunken,
        borderRadius: MlShape.radiusSmall,
        border: Border.all(color: semantic.borderSubtle),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: MlType.code(
          color: semantic.textStrong,
          size: fontSize,
          weight: FontWeight.w700,
          letterSpacing: 0.8,
        ).copyWith(height: 1.4),
      ),
    );
  }
}
