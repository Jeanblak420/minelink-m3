import 'package:flutter_application_1/core/design/tokens/m3/ml_shape.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application_1/core/design/tokens/m3/ml_typography.dart';
import 'package:flutter_application_1/core/design/tokens/ml_tokens.dart';
import 'package:flutter_application_1/core/design/charts/ml_sparkline.dart';
import 'package:flutter_application_1/core/design/tokens/ml_console_palettes.dart';
import 'package:flutter_application_1/core/design/tokens/ml_rail_tokens.dart';

/// Editorial serif used for the Super-Admin console's display numbers and
/// section titles (matches the design system's Fraunces headings).
const String kEditorialSerif = MlTokens.fontSerif; // 'Fraunces'

/// Console UI sans.
///
/// The design drop overrode the design-system sans with Sora for the whole
/// console (`--font-sans: 'Sora'`), and this constant carried that. It no
/// longer does, as of 2026-08-20.
///
/// The override was never applied to the console. `mlConsoleSans`, the rail's
/// copy of the same string, had already stopped being read by anything, so the
/// chrome around these cards ran Plus Jakarta Sans while the seven tiles inside
/// it ran Sora — one screen, two sans faces, and a fourth typeface in a system
/// that has three (`docs/design-reference.md` §3). Sora was not chosen over
/// Plus Jakarta Sans here; it was simply the half of the drop that survived.
///
/// Kept as a name rather than deleted, because "the console's UI sans" is a
/// real role and seven sites read better saying so than repeating the family.
const String kConsoleSans = MlTokens.fontSans;

/// Muted hairline-caption ink the design hardcodes on card subtitles
/// (`#657795`) — same literal in both themes.
const Color kConsoleSubInk = mlRailSearchInk;

/// Design's header link (`{link} →`): accent text, 12.5/700, no chrome.
class SaHeaderLink extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const SaHeaderLink({super.key, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Text(
        '$label →',
        style: context.mlText.titleSmall.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// Section title in the editorial serif with a muted one-line description and
/// an optional trailing action — mirrors the design's dashboard sections.
class SaSectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final String? meta;
  final Widget? action;

  /// Small inline badge shown immediately after the title (e.g. a "NEW" pill).
  final Widget? badge;
  const SaSectionHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.meta,
    this.action,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    final s = MlSemantic.of(context);
    final titleText = Text(
      title,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: context.mlText.editorialMedium.copyWith(color: s.textStrong),
    );

    final metaText = meta == null
        ? null
        : Text(
            meta!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.mlText.bodySmall.copyWith(color: s.textFaint),
          );

    // The head tools were three non-flex children after a `Spacer`, which is
    // fine at console widths and overflows by ~39px on a 430px portal viewport
    // at 1.3 text scale — now that the portal dashboards use this header, it
    // gets rendered narrow for the first time. Below the breakpoint the tools
    // drop to their own line; above it they keep the design's single row.
    //
    // THE META IS CAPPED, NOT FLEXED — and there is no Spacer.
    //
    // Until 2026-08-23 the wide row was `Flexible(title) · Spacer() ·
    // Flexible(meta) · action`. `Flexible` defaults to `flex: 1` and a
    // `Spacer` IS an `Expanded(flex: 1)`, so the row's free space was split
    // three ways and the meta was handed the middle-to-right third: a loose
    // child sizes to its content at the START of its allotment, so "Target
    // 903 t/day · View →" rendered at two-thirds of the row, nowhere near the
    // right edge the reference puts every meta line at. On the mine
    // dashboard at 1600px that put "4 queues with work" at x≈860 inside a
    // band ending at 1570, on all five bands, on all three portal dashboards.
    // CLAUDE.md §10.4 records this exact trap, and the portal's own
    // `MlSectionTitle` already carries the right shape: the title is the long
    // child and takes the free space (`Expanded`); the meta is a non-flex
    // child, so the title pushes it to the right edge, but BOUNDED to half
    // the row so a long one ellipsises instead of running off. Seen in the
    // Phase 3 mine-portal pass; pinned by `portal_dashboard_kit_test.dart`
    // ("the head's meta and link sit at the right edge").
    return LayoutBuilder(
      builder: (context, c) {
        final stack = c.maxWidth < 560;
        final metaCap =
            c.maxWidth.isFinite ? c.maxWidth * 0.5 : double.infinity;
        final tools = <Widget>[
          if (metaText != null)
            stack
                ? metaText
                : ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: metaCap),
                    child: metaText,
                  ),
          if (action != null) ...[
            SizedBox(width: metaText == null ? 0 : 14),
            action!,
          ],
        ];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (stack) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Flexible(child: titleText),
                  if (badge != null) ...[const SizedBox(width: 10), badge!],
                ],
              ),
              if (tools.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (metaText != null) metaText,
                      if (action != null) action!,
                    ],
                  ),
                ),
            ] else
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // The title owns the free space; the badge rides right
                  // after it. The inner Row is bounded by the Expanded, so
                  // the Flexible title ellipsises instead of throwing.
                  Expanded(
                    child: Row(
                      children: [
                        Flexible(child: titleText),
                        if (badge != null) ...[
                          const SizedBox(width: 10),
                          badge!,
                        ],
                      ],
                    ),
                  ),
                  if (tools.isNotEmpty) const SizedBox(width: 12),
                  ...tools,
                ],
              ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: context.mlText.bodyMedium.copyWith(color: s.textMuted),
            ),
          ],
        );
      },
    );
  }
}

/// Small green "NEW" pill (design's Pending-requests accent).
class SaNewPill extends StatelessWidget {
  const SaNewPill({super.key});

  @override
  Widget build(BuildContext context) {
    // Design: status-done-fg text on rgba(34,197,94,.14) with a
    // rgba(34,197,94,.3) border — theme-aware fg, literal green tint.
    final fg = MlTone.done.colors(Theme.of(context).brightness).fg;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: MlConsolePalettes.newPillFill,
        border: Border.all(color: MlConsolePalettes.newPillBorder),
        borderRadius: MlShape.pill,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Dot(color: fg),
          const SizedBox(width: 5),
          Text(
            'NEW',
            style: context.mlText.labelSmall.copyWith(
              color: fg,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.66,
            ),
          ),
        ],
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  final Color color;
  const _Dot({required this.color});
  @override
  Widget build(BuildContext context) => Container(
    width: 6,
    height: 6,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
}

/// Decorative accent sparkline (design `Sparkline`: 2px stroke + soft area
/// fill fading to transparent, terminal-rounded).
// SaSparkline DELETED 2026-08-14 (S5-13). A complete sparkline implementation
// — widget and painter — with ZERO callers anywhere in the tree. The canonical
// one is MlSparkline in core/design/charts/ml_sparkline.dart.

class SaOrgTypeCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color accent;
  final String sublabel;
  final List<(String, String)> metrics; // (LABEL, VALUE)
  final VoidCallback? onTap;

  /// Icon ink (design ORG_CHIP.fg — may be lighter than [accent], the tint
  /// base used for the well fill/border). Defaults to [accent].
  final Color? iconFg;

  /// Decorative trend series (design ORG_AGG.spark). Rendered bottom-right.
  final List<double>? spark;
  final Color? sparkColor;

  const SaOrgTypeCard({
    super.key,
    required this.title,
    required this.icon,
    required this.accent,
    required this.sublabel,
    required this.metrics,
    this.onTap,
    this.iconFg,
    this.spark,
    this.sparkColor,
  });

  @override
  Widget build(BuildContext context) {
    final s = MlSemantic.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(MlTokens.rXl),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            // Design: linear-gradient(180deg, surface-card, rgba(tint,.05)) —
            // the bottom stop is 95% transparent, so it reads as the page
            // canvas washed with 5% tint.
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                s.surfaceCard,
                Color.alphaBlend(accent.withValues(alpha: 0.05), s.surfaceApp),
              ],
            ),
            borderRadius: BorderRadius.circular(MlTokens.rXl),
            border: Border.all(color: s.borderCard),
            boxShadow: MlTokens.shadowSm,
          ),
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.10),
                      borderRadius: MlShape.radiusMedium,
                      border: Border.all(color: accent.withValues(alpha: 0.28)),
                    ),
                    child: Icon(icon, color: iconFg ?? accent, size: 19),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: context.mlText.editorialMedium.copyWith(
                            color: s.textStrong,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          sublabel,
                          // TWO lines. This caption is the sentence that says
                          // what the figure above it counts — "At the agreed
                          // rate, after quality penalty" is 269px in a tile
                          // that is 269px, so the buyer's Payable figure lost
                          // the words "quality penalty" and read as a plain
                          // total. It is also where an empty tile explains
                          // ITSELF (`emptyReason`), which is the one line that
                          // must not be cut.
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: kConsoleSans,
                            fontSize: 12,
                            height: 1.4,
                            color: kConsoleSubInk,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: s.textFaint,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Flexible: a Row hands non-flex children unbounded
                        // width, so these cells sized to their text and pushed
                        // the row past its bounds once the labels grew (larger
                        // UiPrefs.textScale, narrow window). The value's
                        // ellipsis can only engage on a bounded cell.
                        for (final m in metrics)
                          Flexible(
                            child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                m.$1.toUpperCase(),
                                style: const TextStyle(
                                  fontFamily: kConsoleSans,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 1.33,
                                  // Design hardcodes #465774 on these
                                  // micro-labels in both themes.
                                  color: MlConsolePalettes.microLabelInk,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                m.$2,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: context.mlText.code(
                                  color: s.textStrong,
                                  size: 14,
                                  weight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          ),
                      ],
                    ),
                  ),
                  if (spark != null && spark!.length >= 2) ...[
                    const SizedBox(width: 16),
                    MlSparkline(data: spark!, color: sparkColor ?? accent),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Delta-badge tone (design `Delta` component) — **colour and emphasis only**.
///
/// It used to decide the ARROW too: `up` and `warn` drew a hardcoded `▲`, and
/// `good` and `live` drew none. That was safe while the only deltas on this
/// tile were the console's own 24-hour counts of NEW things, which cannot be
/// negative. `PortalKpiRow` then reused the tile for a signed
/// period-over-period figure and mapped the SIGN onto the TONE — welcome
/// movement `good`, unwelcome movement `warn` — and the two meanings collided
/// twice over on the live buyer dashboard, 2026-08-22:
///
///     ▲ −35 · 24h        Tons delivered 68.7 t     (amber)
///       −6351            Payable R49,710           (green, no arrow)
///
/// An up arrow on a fall, and beside it the same kind of measurement wearing a
/// different shape because a fall happened to be welcome there.
///
/// The direction is now derived from the sign of the delta string itself, in
/// `_Delta`, so it cannot disagree with the number it sits next to. The tone
/// answers the separate question — *is this movement welcome?* — which is why
/// a falling `Payable` is correctly a green `▼`.
enum SaDeltaTone { up, warn, good, live, flat }

/// Platform-registry stat tile — matches the design exactly: subtle
/// surface→tinted gradient, 3px left accent border, 40px icon well, 32px serif
/// value (+optional unit), 13px label, 11.5px mono sub, and a mono delta badge.
class SaStatTile extends StatelessWidget {
  final String value;
  final String? unit;
  final String label;
  final String sublabel;
  final IconData icon;

  /// Tint base (design REG_TONE rgb) used for washes & the left accent.
  final Color tint;

  /// Icon colour (design REG_TONE fg — a lighter variant of [tint]).
  final Color iconFg;
  final String? delta;
  final SaDeltaTone deltaTone;

  /// The window [delta] is measured over — `7d`, `30d`, `12m`. Rendered after
  /// the figure as `· 7d`.
  ///
  /// It used to be the literal `24h`, welded into the badge. The portal's
  /// deltas are computed against the previous window of the SELECTED period —
  /// Today / 7 days / 30 days / 12 months — so on the live buyer dashboard a
  /// seven-day movement was captioned `24h`, and on the 12-month view a year
  /// would have been. The caller states the window because the caller is the
  /// only one that knows it.
  final String? deltaPeriod;
  final VoidCallback? onTap;
  const SaStatTile({
    super.key,
    required this.value,
    required this.label,
    required this.sublabel,
    required this.icon,
    required this.tint,
    required this.iconFg,
    this.unit,
    this.delta,
    this.deltaTone = SaDeltaTone.flat,
    this.deltaPeriod,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final s = MlSemantic.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(MlTokens.rLg),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                s.surfaceCard,
                Color.alphaBlend(tint.withValues(alpha: 0.05), s.surfaceApp),
              ],
            ),
            borderRadius: BorderRadius.circular(MlTokens.rLg),
            border: Border.all(color: s.borderCard),
            boxShadow: MlTokens.shadowXs,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(MlTokens.rLg),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 3px left accent as a strip (non-uniform borders can't have a
                // borderRadius, so the accent is a sibling, not a border side).
                Container(width: 3, color: tint.withValues(alpha: 0.85)),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: tint.withValues(alpha: 0.10),
                                borderRadius: MlShape.radiusMedium,
                                border: Border.all(
                                  color: tint.withValues(alpha: 0.28),
                                ),
                              ),
                              child: Icon(icon, size: 18, color: iconFg),
                            ),
                            const Spacer(),
                            // FLEXIBLE, not a bare child. A `Row` hands a
                            // non-flex child unbounded width (CLAUDE.md
                            // §10.4), so the badge could never ellipsise — it
                            // simply pushed the row over. It survived only
                            // because `▲ −35 · 24h` is short; the moment a
                            // delta carries a currency prefix, thousands
                            // separators and a real period (`▼ −R156,567 ·
                            // 12m`) it is 17 characters, and at the console's
                            // 2.0 text scale that is wider than the tile.
                            if (delta != null)
                              Flexible(
                                child: _Delta(
                                  delta: delta!,
                                  tone: deltaTone,
                                  period: deltaPeriod,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        RichText(
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          text: TextSpan(
                            style: context.mlText.figure(
                              color: s.textStrong,
                              size: 32,
                              height: 1.0,
                            ),
                            children: [
                              TextSpan(text: value),
                              if (unit != null)
                                WidgetSpan(
                                  alignment: PlaceholderAlignment.baseline,
                                  baseline: TextBaseline.alphabetic,
                                  child: Padding(
                                    // Design: 16px unit, 2px to the left of the value.
                                    padding: const EdgeInsets.only(left: 2),
                                    child: Text(
                                      unit!,
                                      style: context.mlText.editorialSmall.copyWith(
                                        color: s.textFaint,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.mlText.titleSmall.copyWith(
                            color: s.textStrong,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          sublabel,
                          // TWO lines, for the same reason as the other stat
                          // tile in this file: this caption says what the
                          // figure counts, and on the buyer's DESKTOP
                          // dashboard "At the agreed rate, after quality
                          // penalty" is 269px in a 269px tile.
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: context.mlText.code(
                            color: s.textFaint,
                            size: 12,
                            weight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The design's `Delta` badge, in mono.
class _Delta extends StatelessWidget {
  final String delta;
  final SaDeltaTone tone;

  /// Window the figure is measured over — `7d`, `12m`. Null draws no suffix.
  final String? period;
  const _Delta({required this.delta, required this.tone, this.period});

  /// ▲ for a rise, ▼ for a fall, nothing for a figure that states no
  /// direction — **read off [delta] itself, never off [tone]**.
  ///
  /// This is the whole point of the 2026-08-22 change. The arrow used to ride
  /// on the tone, and the tone answers a different question (*is this movement
  /// welcome?*), so the buyer dashboard drew `▲ −35`: an up arrow on a fall,
  /// because a fall in tons delivered is unwelcome and unwelcome meant `warn`
  /// and `warn` meant ▲. Derived from the sign, the glyph cannot contradict
  /// the number it is glued to, whatever a caller does with the colour.
  ///
  /// `PortalKpiRow.formatDelta` writes U+2212 MINUS SIGN, not a hyphen, so the
  /// negative test is on that character. A `+` is a rise; anything else — a
  /// bare count like the console's `3` — gets no arrow, which is what those
  /// registry tiles have always wanted.
  String? get _arrow {
    if (delta.startsWith('−') || delta.startsWith('-')) return '▼';
    if (delta.startsWith('+')) return '▲';
    return null;
  }

  // Brightness-aware, not two fixed light-mode hues.
  //
  // These were `green600` and `orange600` — values tuned for ink on PAPER —
  // written onto a console that is dark for most admins. Both directions were
  // wrong at once: `#16A34A` measured 3.24:1 as ink on the light dashboard,
  // and when `green600` was deepened to fix it as a BUTTON FILL the dark side
  // went to 3.71:1. One token cannot be both the fill under white ink and the
  // ink on a dark card; `MlTone` is the pair that already knows the
  // difference, and it carries the lifecycle meaning too.
  //
  // Caught by the LOW CONTRAST ratchet on the very commit that deepened
  // `green600`, which is the ratchet doing exactly its job.

  @override
  Widget build(BuildContext context) {
    final s = MlSemantic.of(context);
    final brightness = Theme.of(context).brightness;
    final green = MlTone.done.colors(brightness).fg;
    final orange = MlTone.warn.colors(brightness).fg;
    late final Color c;
    var dot = false;
    switch (tone) {
      case SaDeltaTone.up:
      case SaDeltaTone.good:
        c = green;
        break;
      case SaDeltaTone.warn:
        c = orange;
        break;
      case SaDeltaTone.live:
        c = green;
        dot = true;
        break;
      case SaDeltaTone.flat:
        c = s.textFaint;
        break;
    }
    final arrow = _arrow;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (dot) ...[
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: c, shape: BoxShape.circle),
          ),
          const SizedBox(width: 4),
        ],
        if (arrow != null) ...[
          Text(
            arrow,
            style: TextStyle(
              fontFamily: MlTokens.fontMono,
              fontSize: 8,
              height: 1,
              color: c,
            ),
          ),
          const SizedBox(width: 3),
        ],
        // The FIGURE first and the window after it, so that when the badge is
        // squeezed — a narrow tile, or an admin on the 2.0 text scale — it is
        // the `· 7d` tail that goes and never the number. Ellipsis rather than
        // overflow is only possible because `SaStatTile` puts this whole Row
        // in a `Flexible`; see the note at that call site.
        Flexible(
          child: Text(
            period == null ? delta : '$delta · $period',
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.ellipsis,
            style: context.mlText.code(
              color: c,
              size: 11,
              weight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}
