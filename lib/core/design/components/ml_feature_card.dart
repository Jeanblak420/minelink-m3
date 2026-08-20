import 'package:flutter/material.dart';
import 'package:flutter_application_1/core/design/tokens/m3/ml_typography.dart';
import 'package:flutter_application_1/core/design/tokens/ml_tokens.dart';
import 'package:flutter_application_1/core/design/components/ml_buttons.dart';
import 'package:flutter_application_1/core/design/components/ml_card.dart';
import 'package:flutter_application_1/core/design/components/ml_icon_well.dart';

/// Dashboard feature card: tinted icon chip, extrabold title, one calm
/// helper sentence, outlined "Open →" button.
class MlFeatureCard extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final MlTone tone;
  final String buttonLabel;
  final VoidCallback? onOpen;

  const MlFeatureCard({
    super.key,
    required this.title,
    required this.description,
    required this.icon,
    this.tone = MlTone.accent,
    this.buttonLabel = 'Open',
    this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final semantic = MlSemantic.of(context);
    return MlCard(
      hoverLift: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          MlIconWell(icon: icon, tone: tone, size: 48),
          const SizedBox(height: 14),
          Text(
            title,
            style: context.mlText.titleMedium.copyWith(
              color: semantic.textStrong,
              fontWeight: FontWeight.w800,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            description,
            style: context.mlText.bodyMedium.copyWith(color: semantic.textMuted),
          ),
          if (onOpen != null) ...[
            const SizedBox(height: 16),
            MlButton.outline(
              label: buttonLabel,
              trailingIcon: Icons.arrow_forward_rounded,
              compact: true,
              onPressed: onOpen,
            ),
          ],
        ],
      ),
    );
  }
}
