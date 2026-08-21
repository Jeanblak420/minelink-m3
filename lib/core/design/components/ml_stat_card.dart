import 'package:flutter/material.dart';
import 'package:flutter_application_1/core/design/components/ml_card.dart';
import 'package:flutter_application_1/core/design/components/ml_icon_well.dart';
import 'package:flutter_application_1/core/design/tokens/m3/ml_motion.dart';
import 'package:flutter_application_1/core/design/tokens/m3/ml_shape.dart';
import 'package:flutter_application_1/core/design/tokens/ml_tokens.dart';

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
///
/// ## What changed in the M3 rebuild
///
/// **The count-up ignored reduce-motion.** [animateValue] ran a 800ms
/// `TweenAnimationBuilder` on a bare `Duration` and `Curves.easeOut`. Neither
/// consults `MediaQuery.disableAnimations`, so a user who has asked the system
/// to stop animating still had every figure on the dashboard spin up from
/// zero — and this card draws 40 figures across 11 screens, so a single
/// dashboard was a page of moving numerals. It now runs through [MlMotion],
/// which collapses the tween to 1ms; the figure simply appears at its value.
///
/// **The card announces itself as one fact.** A screen reader previously met
/// four loose nodes — an icon, "128.4", "Tons delivered", "net_mass ·
/// all_time" — in layout order, which reads the number before the thing it
/// measures. It is now a single semantics node reading "Tons delivered,
/// 128.4", with the icon excluded and the caption folded in. Tapping is
/// announced as a button.
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
    final theme = Theme.of(context);
    final text = theme.textTheme;
    final brightness = theme.brightness;
    final toneColors = tone.colors(brightness);

    Widget valueWidget;
    if (animateValue != null) {
      valueWidget = TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: animateValue!),
        duration: MlMotion.of(context, MlMotion.count),
        curve: MlMotion.curveOf(context, MlMotion.decelerate),
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

    // One node, in the order a person reads the fact: what it measures, then
    // the figure, then the qualifier. Layout order puts the figure first
    // because that is the visual hierarchy; it is not the spoken one.
    final spoken = <String>[
      label,
      value,
      if (caption != null) caption!,
      if (delta != null) delta!,
    ].join(', ');

    return Semantics(
      label: spoken,
      button: onTap != null,
      excludeSemantics: true,
      child: MlCard(
        onTap: onTap,
        padding: EdgeInsets.zero,
        child: Row(
          children: [
            // The reference's left tone bar. It is the card's only decoration
            // and it is not decorative — the hue says which of good / warn /
            // error / transit this figure belongs to, readable before the text.
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
                  left: Radius.circular(MlShape.medium),
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
                            // `bodySmall` is the 12px slot; the tile wants it a
                            // step firmer than prose so the label holds its own
                            // under a display numeral.
                            style: text.bodySmall?.copyWith(
                              fontWeight: FontWeight.w500,
                              color: semantic.textMuted,
                              height: 1.3,
                            ),
                          ),
                          if (caption != null) ...[
                            const SizedBox(height: 3),
                            Text(
                              caption!,
                              // TWO lines. `net_mass · last_365_days` is 24
                              // characters of 11px mono — about 163px — and
                              // the text column of a 220px tile is 128. So the
                              // recon table's five period cards, on the screen
                              // whose whole purpose is those five figures,
                              // read `last_7_da…`, `last_30_d…`,
                              // `last_365_…`. The caption is a machine string
                              // and its whole value is being exact about which
                              // window the number covers; cut in half it says
                              // the opposite of what it is for. Photographed
                              // 2026-08-21. It breaks at the middot.
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              // A caption is a machine string
                              // (`net_mass · all_time`), so it is code, not
                              // prose — MlType.code rather than a fifth
                              // hand-written mono style.
                              style: MlType.code(
                                color: semantic.textFaint,
                                size: MlTokens.fsMicro,
                                weight: FontWeight.w400,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ],
                          if (delta != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              delta!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: text.labelMedium?.copyWith(
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
      ),
    );
  }

  /// The figure. [MlType.figure] is the sanctioned display numeral — Fraunces,
  /// w500, tabular — rather than a sixth inline copy of those five properties.
  ///
  /// It used to read `fontFamily: MlGlass.display`, which is a *different*
  /// constant naming the same face from the glass-surface token file. Two
  /// names for one font in one component is how a face drifts.
  TextStyle _valueStyle(MlSemantic semantic) =>
      MlType.figure(color: semantic.textStrong);
}
