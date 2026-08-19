import 'package:flutter/material.dart';
import 'package:flutter_application_1/core/design/tokens/ml_surface_tokens.dart';
import 'package:flutter_application_1/core/design/tokens/ml_tokens.dart';
import 'package:flutter_application_1/features/portal/widgets/ml/ml_card.dart';
import 'package:flutter_application_1/features/portal/widgets/ml/ml_icon_well.dart';

/// KPI stat tile, in the reference's treatment.
///
/// `docs/design-reference.md` §4 describes the card this is aligned to: tinted
/// icon well, **large Fraunces numeral**, PlusJakartaSans label, **mono
/// sub-caption**, and *"a coloured 3px bar runs down the left edge, carrying
/// the semantic tone"*. §3 puts **every large numeral** in the display face.
///
/// This card draws 40 figures across 11 screens, which makes it the portal's
/// most repeated numeral — and it was the one place the portal most visibly
/// disagreed with the console it sits behind.
///
/// **The three portal dashboards do not use this** and were not touched: they
/// render through the console's own `SaStatTile` (`portal_dashboard_kit.dart`),
/// which already has this treatment. This is what the rest of the portal uses.
///
/// Pinned by `test/widgets/portal_stat_card_test.dart`.
class MlStatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final MlTone tone;
  final VoidCallback? onTap;

  /// The mono sub-caption — `net_mass · all_time`, `across_4_org_types`.
  /// Lowercase, underscored, monospaced: `docs/design-reference.md` §3 calls
  /// this texture "a deliberate texture, not a bug", and §4 makes it part of
  /// the card. Optional, because a figure with nothing true to say underneath
  /// it should say nothing rather than pad.
  final String? caption;

  /// A short trend note. **Rendered in the warn tone when [deltaPositive] is
  /// false, never red** — `docs/design-reference.md` §4: *"Negative deltas are
  /// amber, not red. Red is reserved for a fault (expired, variance, missing
  /// POD); a downward trend is a warning, not an error."*
  ///
  /// Neither of these is passed anywhere today — all 40 call sites omit them,
  /// so this branch draws nothing. Kept and corrected rather than deleted: the
  /// old code hardcoded `MlTokens.red600` for a downward move, which is the
  /// rule the reference explicitly rejects, and leaving that in place would
  /// have meant the first caller to use it shipped the wrong semantic.
  final String? delta;
  final bool deltaPositive;

  /// When non-null the numeric part animates 0 → [animateValue] over 850ms
  /// and [valueBuilder] formats it; [value] is then the settled text.
  final double? animateValue;
  final String Function(double)? valueBuilder;

  const MlStatCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.tone = MlTone.accent,
    this.caption,
    this.delta,
    this.deltaPositive = true,
    this.onTap,
    this.animateValue,
    this.valueBuilder,
  });

  @override
  Widget build(BuildContext context) {
    final semantic = MlSemantic.of(context);
    final brightness = Theme.of(context).brightness;
    final toneColors = tone.colors(brightness);

    Widget valueWidget;
    if (animateValue != null) {
      valueWidget = TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: animateValue!),
        duration: MlTokens.durCount,
        curve: Curves.easeOut,
        builder: (context, v, _) => Text(
          valueBuilder?.call(v) ?? v.toStringAsFixed(0),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: _valueStyle(semantic),
        ),
      );
    } else {
      valueWidget = Text(
        value,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: _valueStyle(semantic),
      );
    }

    return MlCard(
      onTap: onTap,
      padding: EdgeInsets.zero,
      child: Row(
        children: [
          // The reference's left tone bar. It is the card's only decoration and
          // it is not decorative — the hue says which of good / warn / error /
          // transit this figure belongs to, readable before the text is.
          Container(
            width: 3,
            // Stretches to the card's height; the Row sizes to its tallest
            // child, so this cannot force an unbounded constraint the way a
            // CrossAxisAlignment.stretch inside a scrollable would
            // (CLAUDE.md §10.4).
            constraints: const BoxConstraints(minHeight: 62),
            decoration: BoxDecoration(
              color: toneColors.fg,
              borderRadius: const BorderRadius.horizontal(
                left: Radius.circular(MlTokens.rMd),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(13, 16, 16, 16),
              child: Row(
                children: [
                  MlIconWell(icon: icon, tone: tone, size: 46),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        valueWidget,
                        const SizedBox(height: 2),
                        Text(
                          label,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: MlTokens.fontSans,
                            fontSize: MlTokens.fsBodySm,
                            fontWeight: FontWeight.w500,
                            color: semantic.textMuted,
                            height: 1.3,
                          ),
                        ),
                        if (caption != null) ...[
                          const SizedBox(height: 3),
                          Text(
                            caption!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: MlTokens.fontMono,
                              fontSize: MlTokens.fsMicro,
                              color: semantic.textFaint,
                              letterSpacing: 0.2,
                              fontFeatures: const [FontFeature.tabularFigures()],
                            ),
                          ),
                        ],
                        if (delta != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            delta!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: MlTokens.fontSans,
                              fontSize: MlTokens.fsLabel,
                              fontWeight: FontWeight.w700,
                              color: deltaPositive
                                  ? MlTone.done.colors(brightness).fg
                                  : MlTone.warn.colors(brightness).fg,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (onTap != null)
                    Icon(Icons.chevron_right_rounded,
                        size: 20, color: semantic.textFaint),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  TextStyle _valueStyle(MlSemantic semantic) => TextStyle(
        fontFamily: MlGlass.display,
        fontSize: MlTokens.fsH2,
        // Fraunces carries the emphasis the sans needed w800 for; §3 renders
        // the reference's numerals at the display face's own weight.
        fontWeight: FontWeight.w500,
        letterSpacing: -0.2,
        color: semantic.textStrong,
        height: 1.1,
        // S5-7. Stat cards sit in grids, and proportional digits make two
        // adjacent figures disagree by a glyph width down a column.
        fontFeatures: const [FontFeature.tabularFigures()],
      );
}
