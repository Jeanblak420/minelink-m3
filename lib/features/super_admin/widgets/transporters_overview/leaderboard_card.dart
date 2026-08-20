import 'package:flutter_application_1/core/design/tokens/m3/ml_shape.dart';
import 'package:flutter/material.dart';

import 'overview_models.dart';
import 'package:flutter_application_1/core/design/tokens/ml_overview_tokens.dart';
import 'primitives.dart';

/// Aside card #2 — the accent "pop" card.
///
/// This is the only panel on the screen that uses [OvGlassCard.accent]. Keep it
/// that way: a second glowing card and the right column has no anchor.
///
/// With [onTap] it becomes the way in to the full-screen board: a chevron chip
/// beside the total, a lift and a brighter glow on hover, a pointer cursor over
/// the whole card, and one button in the semantics tree. Without it the card is
/// exactly what it was — the affordance appears only when there is somewhere to
/// go, so a card that does nothing never advertises that it does.
///
/// No "View all" text button: the chevron and the lift are the affordance in
/// this design.
class OvLeaderboardCard extends StatefulWidget {
  const OvLeaderboardCard({
    super.key,
    required this.tokens,
    required this.data,
    this.onTap,
  });

  final MlOv tokens;
  final Leaderboard data;

  /// Opens the full ranking. Null hides the chevron and the hover response.
  final VoidCallback? onTap;

  @override
  State<OvLeaderboardCard> createState() => _OvLeaderboardCardState();
}

class _OvLeaderboardCardState extends State<OvLeaderboardCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final card = _card(context);
    if (widget.onTap == null) return card;

    // Reduce-motion is respected by the duration, not by dropping the lift:
    // the brightened glow is the affordance, and it must still arrive.
    final motion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return Semantics(
      button: true,
      label: 'Leaderboard by tons. Opens the full ranking.',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedSlide(
            offset: _hovered ? const Offset(0, -0.004) : Offset.zero,
            duration: motion
                ? const Duration(milliseconds: 1)
                : const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            child: card,
          ),
        ),
      ),
    );
  }

  Widget _card(BuildContext context) {
    final t = widget.tokens;
    final data = widget.data;
    return OvGlassCard(
      tokens: t,
      accent: true,
      hoverGlow: _hovered && widget.onTap != null,
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: MlShape.radiusMedium,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [t.acc3, t.acc],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: t.acc.withValues(alpha: 0.8),
                      blurRadius: 18,
                      spreadRadius: -8,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.emoji_events_rounded,
                  size: 19,
                  color: t.trophyInk,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text.rich(
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      TextSpan(
                        style: t.f(
                          size: 17,
                          weight: FontWeight.w500,
                          letterSpacing: -0.18,
                        ),
                        children: [
                          const TextSpan(text: 'Leaderboard — '),
                          TextSpan(
                            text: 'Tons',
                            style: t.f(
                              size: 17,
                              weight: FontWeight.w500,
                              color: t.acc,
                              style: FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Network share this month',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.s(size: 11, color: t.inkMid),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: OvPill(
                  tokens: t,
                  label: data.totalLabel,
                  tone: OvTone.accent,
                  mono: true,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                ),
              ),
              if (widget.onTap != null) ...[
                const SizedBox(width: 8),
                Container(
                  width: 26,
                  height: 26,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: t.acc.withValues(alpha: 0.10),
                    borderRadius: MlShape.radiusSmall,
                    border: Border.all(color: t.acc.withValues(alpha: 0.30)),
                  ),
                  child: Icon(
                    Icons.chevron_right_rounded,
                    size: 16,
                    color: t.acc2,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          if (data.entries.isEmpty)
            Text(
              'No tonnage recorded this month',
              style: t.s(size: 12, color: t.inkMid),
            )
          else
            for (var i = 0; i < data.entries.length; i++) ...[
              if (i > 0) const SizedBox(height: 8),
              _LeaderRow(
                tokens: t,
                entry: data.entries[i],
                // The leader treatment belongs to whoever actually moved the
                // most, so a month with no movement at all has no leader.
                leader: i == 0 && !data.entries[i].muted,
              ),
            ],
        ],
      ),
    );
  }
}

class _LeaderRow extends StatelessWidget {
  const _LeaderRow({
    required this.tokens,
    required this.entry,
    required this.leader,
  });

  final MlOv tokens;
  final LeaderboardEntry entry;
  final bool leader;

  @override
  Widget build(BuildContext context) {
    final t = tokens;

    // Ratio of scaled to unscaled 13px body type — 1.0 at the default. Same
    // idiom as `_Cols.of` in leaderboard_board_body.dart.
    //
    // The tons/share block is deliberately UNFLEXED at ordinary sizes: a Row
    // lays non-flex children out first, so it keeps its natural width and sits
    // flush right while the name column absorbs the rest. Wrapping it in a
    // Flexible unconditionally would defeat that — a Flexible next to an
    // Expanded splits the free space evenly and the block lands mid-row
    // (CLAUDE.md §10.4).
    //
    // Past ~1.35 that stops being affordable. Measured at a 2.0 text scale:
    // the row is 208.6px, the badge and its two gaps take 52, and the block's
    // natural width is 158.5 — 210.5 in a 208.6 box, so the name column was
    // squeezed to zero and it still overflowed by 1.9px. There it has to be
    // allowed to give, so it becomes Flexible and its two figures ellipsize.
    final tight = MediaQuery.textScalerOf(context).scale(13) / 13 > 1.35;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(MlOv.rRow),
        border: Border.all(
          color: leader ? t.acc.withValues(alpha: 0.35) : t.line,
        ),
        gradient: leader
            ? LinearGradient(
                colors: [
                  t.acc.withValues(alpha: 0.14),
                  t.acc.withValues(alpha: 0.03),
                ],
              )
            : null,
        color: leader ? null : t.overlay(entry.muted ? 0.01 : 0.024),
      ),
      child: Row(
        children: [
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: MlShape.radiusSmall,
              gradient: leader
                  ? LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [t.acc3, t.acc],
                    )
                  : null,
              color: leader ? null : t.overlay(entry.muted ? 0.03 : 0.05),
              border: leader
                  ? null
                  : Border.all(color: entry.muted ? t.line : t.line2),
            ),
            child: Text(
              entry.rank,
              style: t.m(
                size: 11,
                weight: leader ? FontWeight.w700 : FontWeight.w400,
                color: leader
                    ? t.trophyInk
                    : entry.muted
                        ? t.inkXlo
                        : t.inkMid,
              ),
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  entry.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.s(
                    size: 13,
                    weight: entry.muted ? FontWeight.w500 : FontWeight.w600,
                    color: entry.muted ? t.inkMid : t.inkHi,
                  ),
                ),
                const SizedBox(height: 8),
                OvMeter(
                  fraction: entry.barFraction,
                  track: t.overlay(entry.muted ? 0.05 : 0.06),
                  glowColor: leader ? t.acc : null,
                  gradient:
                      leader ? LinearGradient(colors: [t.acc, t.acc3]) : null,
                  color: leader ? null : t.acc2.withValues(alpha: 0.6),
                ),
              ],
            ),
          ),
          const SizedBox(width: 13),
          _maybeFlexible(
            tight,
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  entry.tons,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.m(
                    size: 13,
                    color: leader
                        ? t.acc2
                        : entry.muted
                            ? t.inkLo
                            : t.inkHi,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  entry.share,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.m(
                    size: 10,
                    color: leader
                        ? t.inkMid
                        : entry.muted
                            ? t.inkXlo
                            : t.inkLo,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// [child] as-is, or wrapped so it can give up width. See [build].
  static Widget _maybeFlexible(bool flexible, Widget child) =>
      flexible ? Flexible(child: child) : child;
}
