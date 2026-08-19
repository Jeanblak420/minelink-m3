import 'package:flutter/material.dart';
import 'package:flutter_application_1/core/design/tokens/ml_tokens.dart';

/// Lifecycle status pill — the single most repeated motif of the MineLink
/// design. Fully rounded, tonal fg/bg pair, 12px w700 UPPERCASE with slight
/// letter-spacing and an optional leading dot.
class MlStatusBadge extends StatelessWidget {
  final String label;
  final MlTone tone;
  final bool dot;

  const MlStatusBadge({
    super.key,
    required this.label,
    required this.tone,
    this.dot = false,
  });

  /// Maps the app's trip/truck status strings to design tones:
  /// blue = in transit/OTW, amber = at mine, green = loaded/available/
  /// confirmed, orange = maintenance/departed, red = declined/error.
  static MlTone toneForStatus(String status) {
    final s = status.trim().toLowerCase();
    if (s.contains('otw') || s.contains('transit') || s.contains('on trip') ||
        s.contains('en route') || s.contains('pending')) {
      return MlTone.transit;
    }
    if (s.contains('at mine') || s.contains('arrived') || s.contains('waiting')) {
      return MlTone.atMine;
    }
    if (s.contains('loaded') || s.contains('available') ||
        s.contains('approved') || s.contains('confirmed') ||
        s.contains('completed') || s.contains('active') || s.contains('done')) {
      return MlTone.done;
    }
    if (s.contains('maintenance') || s.contains('departed') ||
        s.contains('left') || s.contains('disputed')) {
      return MlTone.warn;
    }
    // 'dismissed' was in this list until the dismissal feature was removed
    // (client ruling, 2026-08-11). No status string in the app can carry it any
    // more, so matching on it only invited it back.
    if (s.contains('declined') || s.contains('error') || s.contains('rejected') ||
        s.contains('expired') || s.contains('failed')) {
      return MlTone.error;
    }
    return MlTone.neutral;
  }

  /// Convenience: badge with the tone derived from the status string.
  factory MlStatusBadge.forStatus(String status, {Key? key, bool dot = false}) =>
      MlStatusBadge(
        key: key,
        label: status,
        tone: toneForStatus(status),
        dot: dot,
      );

  @override
  Widget build(BuildContext context) {
    final colors = tone.colors(Theme.of(context).brightness);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: colors.bg,
        borderRadius: BorderRadius.circular(MlTokens.rPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot) ...[
            Container(
              width: 6,
              height: 6,
              decoration:
                  BoxDecoration(color: colors.fg, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
          ],
          Text(
            label.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: MlTokens.fontSans,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
              color: colors.fg,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}
