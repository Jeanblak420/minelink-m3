import 'package:flutter/material.dart';
import 'package:flutter_application_1/core/design/tokens/ml_tokens.dart';

/// Vehicle plate / ticket / serial chip — JetBrains Mono, slate fill,
/// 8px radius. Plates and ticket numbers are always monospace.
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
        borderRadius: BorderRadius.circular(MlTokens.rSm),
        border: Border.all(color: semantic.borderSubtle),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontFamily: MlTokens.fontMono,
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
          color: semantic.textStrong,
          height: 1.4,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}
