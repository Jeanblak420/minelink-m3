// ============================================================================
// SCREEN 1 — Super Admin Dashboard
// ----------------------------------------------------------------------------
// Your original layout, re-skinned in the Transporters visual system.
//
// Structure is unchanged — six full-width sections, stacked, in the original
// order and grid shapes:
//
//   1. Live operations by organization type   3-up cards
//   2. Pending requests                       3-up cards
//   3. Platform registry                      4-up stat tiles
//   4. Expired token requests                 full-width banner
//   5. Quick actions                          button row
//   6. Recently active organizations          tabbed table
//
// What changed is only the surface: MlGlass tokens, MlPanel cards with a
// single hairline and 12px radii, Instrument Serif headings and hero figures,
// JetBrains Mono for every number, and the same pill / well / caption
// primitives the Transporters overview uses.
// ============================================================================

import 'package:flutter_application_1/core/design/tokens/m3/ml_shape.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'minelink_screens_core.dart';
import 'minelink_charts.dart';
import 'package:flutter_application_1/core/design/tokens/m3/ml_typography.dart';
import 'package:flutter_application_1/core/design/tokens/ml_surface_tokens.dart';
import 'package:flutter_application_1/core/design/charts/ml_sparkline.dart';
import 'package:flutter_application_1/core/design/tokens/ml_console_palettes.dart';
import 'package:flutter_application_1/core/design/tokens/ml_tokens.dart';
import 'package:flutter_application_1/core/time/ml_time.dart';

class MineLinkDashboardScreen extends StatelessWidget {
  const MineLinkDashboardScreen({
    super.key,
    this.onNavigate,
    // P9-03: these were DEFAULTED to `MlSampleData`. A caller that omitted
    // one — or a new call site written from the constructor signature — would
    // silently ship fabricated platform totals to a platform admin, and
    // nothing in the type system or the render would say so. Required now:
    // the screen cannot be built without being handed real data.
    required this.orgAggregates,
    required this.pendingRequests,
    required this.registry,
    required this.recentOrgs,
    this.newCompanies24h,
    this.newUsers24h,
    this.expiredCompanies,
    this.asOf,
    this.tokens,
    this.padding = const EdgeInsets.fromLTRB(24, 20, 24, 40),
  });

  /// Companies and users added in the trailing 24 hours.
  ///
  /// **These were hardcoded.** The registry section's meta line read
  /// `'Last 24h · +2 companies, +14 users'` — a literal, on the platform
  /// admin's landing screen, next to eight tiles the view model derives with
  /// visible care. `SuperAdminDashboardV2ViewModel` already reads
  /// `stats['newCompanies24h']` and `stats['newUsers24h']` and puts them on
  /// the tiles as deltas, so the screen was drawing a *fake version of a
  /// number it already had*.
  ///
  /// Null means the caller has no figure, and the clause is omitted rather
  /// than shown as zero — the same rule the targets store follows
  /// (`CLAUDE.md` §4: a placeholder nobody chose that looks like a decision).
  final int? newCompanies24h;
  final int? newUsers24h;

  /// Companies whose token has expired. Drives the expired-token banner, which
  /// **took no data at all** before this: it always read *"3 companies need
  /// approvals or action … oldest 5 days waiting"* and was rendered
  /// unconditionally, so a platform with nothing expired still saw a standing
  /// amber alert claiming three companies needed action. Null or zero now
  /// hides the banner.
  final int? expiredCompanies;

  /// The instant the screen labels itself with. Defaults to [MlTime.now] —
  /// South African time, per `CLAUDE.md` §7.1, because this is a business-day
  /// label and the device's own zone is not the product's.
  ///
  /// The month used to be the literal `'Jul 2026'`. It was written in July and
  /// read `Jul 2026` in August; the section it heads is *"Live operations …
  /// this calendar month"*.
  final DateTime? asOf;

  /// Fires with a nav id — the same ids the sidebar emits.
  final ValueChanged<String>? onNavigate;

  final List<MlOrgAggregate> orgAggregates;
  final List<MlPendingRequest> pendingRequests;
  final List<MlRegistryStat> registry;
  final List<MlRecentOrg> recentOrgs;

  final MlGlass? tokens;
  final EdgeInsets padding;

  void _go(String id) => onNavigate?.call(id);

  @override
  Widget build(BuildContext context) {
    final t = tokens ?? MlGlass.of(context);
    final now = asOf ?? MlTime.now();

    // "Last 24h · +2 companies, +14 users" — but only the parts that are real.
    // Nothing new in a quiet 24 hours is a fact worth stating plainly, so the
    // line still appears; it just says so instead of naming invented figures.
    final registryMeta = (newCompanies24h == null && newUsers24h == null)
        ? null
        : () {
            final parts = <String>[
              if (newCompanies24h != null && newCompanies24h! > 0)
                '+$newCompanies24h ${newCompanies24h == 1 ? 'company' : 'companies'}',
              if (newUsers24h != null && newUsers24h! > 0)
                '+$newUsers24h ${newUsers24h == 1 ? 'user' : 'users'}',
            ];
            return parts.isEmpty
                ? 'Last 24h · no new registrations'
                : 'Last 24h · ${parts.join(', ')}';
          }();

    final expired = expiredCompanies ?? 0;

    return Container(
      color: t.bg0,
      child: SingleChildScrollView(
        padding: padding,
        child: LayoutBuilder(
          builder: (context, c) {
            // Column counts step down on narrow windows rather than letting
            // cards crush; the section order never changes.
            final w = c.maxWidth;
            final threeUp = w < 900 ? (w < 620 ? 1 : 2) : 3;
            final fourUp = w < 1180 ? (w < 860 ? (w < 620 ? 1 : 2) : 3) : 4;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1 ─────────────────────────────────────────────────────────
                MlSectionHead(
                  tokens: t,
                  title: 'Live operations by organization type',
                  subtitle: 'Tap a card to drill into company-level monthly '
                      'rollups this calendar month.',
                  meta: 'This month · ${DateFormat('MMM y').format(now)}',
                  link: 'View insights',
                  onLink: () => _go('insights.mines'),
                ),
                const SizedBox(height: 14),
                MlGrid(
                  columns: threeUp,
                  gap: 14,
                  children: orgAggregates
                      .map((a) => _OrgCard(
                          tokens: t, agg: a, onTap: () => _go(a.id)))
                      .toList(),
                ),

                // 2 ─────────────────────────────────────────────────────────
                if (pendingRequests.isNotEmpty) ...[
                  const SizedBox(height: 26),
                  MlSectionHead(
                    tokens: t,
                    title: 'Pending requests',
                    subtitle: 'Requests waiting on your approval — oldest '
                        'first, ordered by criticality.',
                    badge: _NewBadge(tokens: t),
                    meta:
                        // '· 2 aging > 24h' used to follow this. MlPendingRequest
                        // carries no timestamp, so nothing on this screen could
                        // ever have known it; the count is real, the age was not.
                        '${pendingRequests.fold<int>(0, (a, r) => a + r.count)}'
                        ' open',
                    link: 'All requests',
                    onLink: () => _go('requests'),
                  ),
                  const SizedBox(height: 14),
                  MlGrid(
                    columns: threeUp.clamp(1, pendingRequests.length),
                    gap: 14,
                    children: pendingRequests
                        .map((r) => _PendingCard(
                            tokens: t, req: r, onTap: () => _go(r.id)))
                        .toList(),
                  ),
                ],

                // 3 ─────────────────────────────────────────────────────────
                const SizedBox(height: 26),
                MlSectionHead(
                  tokens: t,
                  title: 'Platform registry',
                  subtitle: 'Companies, users and throughput — updated live '
                      'read fresh on every load.',
                  meta: registryMeta,
                  link: 'Export snapshot',
                  onLink: () => _go('orgs'),
                ),
                const SizedBox(height: 14),
                MlGrid(
                  columns: fourUp,
                  gap: 14,
                  children: registry
                      .map((s) => _RegistryTile(
                          tokens: t, stat: s, onTap: () => _go(s.id)))
                      .toList(),
                ),

                // 4 ─────────────────────────────────────────────────────────
                if (expired > 0) ...[
                  const SizedBox(height: 26),
                  _ExpiredBanner(
                      tokens: t,
                      count: expired,
                      onTap: () => _go('tokens.requests')),
                ],

                // 5 ─────────────────────────────────────────────────────────
                const SizedBox(height: 26),
                MlSectionHead(
                  tokens: t,
                  title: 'Quick actions',
                  subtitle: 'Jump straight to the most-used admin flows.',
                ),
                const SizedBox(height: 14),
                _QuickActions(tokens: t, onNavigate: onNavigate),

                // 6 ─────────────────────────────────────────────────────────
                const SizedBox(height: 26),
                _RecentOrgsPanel(
                    tokens: t, rows: recentOrgs, onNavigate: onNavigate),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ===========================================================================
// 1. Org rollup card
// ===========================================================================

class _OrgCard extends StatelessWidget {
  const _OrgCard({required this.tokens, required this.agg, this.onTap});

  final MlGlass tokens;
  final MlOrgAggregate agg;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = tokens;
    final tone = agg.tone.base;

    return MlHoverLift(
      lift: 2,
      onTap: onTap,
      builder: (context, hovered) => AnimatedContainer(
        duration: mlScreenMotion(context, const Duration(milliseconds: 150)),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: t.panel,
          borderRadius: MlShape.radiusMedium,
          border: Border.all(
            color: hovered ? tone.withValues(alpha: 0.30) : t.line2,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                MlWell(icon: agg.icon, color: tone, size: 38, iconSize: 18),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(agg.title,
                          style: context.mlText.titleMedium.copyWith(
                            color: t.inkHi,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.15,
                          )),
                      const SizedBox(height: 3),
                      Text(agg.subtitle,
                          style: context.mlText.labelSmall.copyWith(
                            color: t.inkMid,
                            fontWeight: FontWeight.w400,
                          )),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded,
                    size: 18, color: hovered ? t.accent2 : t.inkLo),
              ],
            ),
            const SizedBox(height: 18),
            LayoutBuilder(
              builder: (context, c) {
                final stats = [
                  for (final m in agg.metrics)
                    MlStat(
                        tokens: t,
                        label: m.key,
                        value: m.value,
                        valueSize: 15),
                ];
                // Three figures and an 84px sparkline do not fit in a card
                // narrower than this. At 760px the console draws these two-up,
                // each card is ~305px, and the three stats were left ~58px
                // each — so the TONS figure, which is the largest number on
                // the platform's front page, read "55,34…". A cut NUMBER is
                // not a truncation, it is a wrong number.
                //
                // The sparkline is the part that goes. It carries a shape,
                // the figures carry the values, and the values win.
                if (c.maxWidth < 360) {
                  return Wrap(
                    spacing: 20,
                    runSpacing: 10,
                    children: stats,
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        // Flexible, not a bare child: a Row hands non-flex
                        // children unbounded width, and MlStat ellipsises its
                        // value through a Flexible — which asserts under an
                        // unbounded parent. Loose fit keeps the spaceBetween
                        // look.
                        children: [
                          for (final st in stats) Flexible(child: st),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),
                    MlSparkline(
                        data: agg.spark,
                        color: agg.sparkColor,
                        width: 84,
                        height: 30),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ===========================================================================
// 2. Pending request card
// ===========================================================================

class _PendingCard extends StatelessWidget {
  const _PendingCard({required this.tokens, required this.req, this.onTap});

  final MlGlass tokens;
  final MlPendingRequest req;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = tokens;
    final tone = req.tone.base;

    return MlHoverLift(
      lift: 2,
      onTap: onTap,
      builder: (context, hovered) => AnimatedContainer(
        duration: mlScreenMotion(context, const Duration(milliseconds: 150)),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: t.panel,
          borderRadius: MlShape.radiusMedium,
          border: Border.all(
            color: hovered ? tone.withValues(alpha: 0.30) : t.line2,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                MlWell(icon: req.icon, color: tone, size: 42, iconSize: 19),
                Positioned(
                  top: -6,
                  right: -6,
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 19),
                    height: 19,
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: t.warn,
                      borderRadius: MlShape.pill,
                      border: Border.all(color: t.panel, width: 2),
                    ),
                    child: Text('${req.count}',
                        style: TextStyle(
                          fontFamily: MlGlass.mono,
                          fontSize: 10,
                          height: 1,
                          fontWeight: FontWeight.w700,
                          color: t.isDark
                              ? MlConsolePalettes.badgeInkOnDark
                              : MlConsolePalettes.badgeInkOnLight,
                        )),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(req.label,
                      style: context.mlText.titleSmall.copyWith(
                        color: t.inkHi,
                        fontWeight: FontWeight.w700,
                      )),
                  const SizedBox(height: 4),
                  Text(req.sub,
                      style: context.mlText.labelSmall.copyWith(
                        color: t.inkMid,
                        fontWeight: FontWeight.w400,
                      )),
                  const SizedBox(height: 8),
                  Text('${req.count} new · Review →',
                      style: context.mlText.labelSmall.copyWith(
                        color: t.accent2,
                      )),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NewBadge extends StatelessWidget {
  const _NewBadge({required this.tokens});

  final MlGlass tokens;

  @override
  Widget build(BuildContext context) {
    final t = tokens;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: t.good.withValues(alpha: 0.14),
        border: Border.all(color: t.good.withValues(alpha: 0.3)),
        borderRadius: MlShape.pill,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(color: t.good, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text('NEW',
              style: context.mlText.labelSmall.copyWith(
                color: t.good,
                fontWeight: FontWeight.w800,
              )),
        ],
      ),
    );
  }
}

// ===========================================================================
// 3. Registry tile
// ===========================================================================

class _RegistryTile extends StatelessWidget {
  const _RegistryTile({required this.tokens, required this.stat, this.onTap});

  final MlGlass tokens;
  final MlRegistryStat stat;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = tokens;
    final tone = stat.tone.base;

    return MlHoverLift(
      lift: 0,
      onTap: onTap,
      builder: (context, hovered) => _LeftAccent(
        color: tone.withValues(alpha: 0.85),
        radius: 12,
        child: AnimatedContainer(
        duration: mlScreenMotion(context, const Duration(milliseconds: 150)),
        // 1px outline + 18 reproduces the 19px inset the 3px accent side gave.
        padding: const EdgeInsets.fromLTRB(18, 15, 16, 15),
        decoration: BoxDecoration(
          color: t.panel,
          borderRadius: MlShape.radiusMedium,
          border: Border.all(
              color: hovered ? tone.withValues(alpha: 0.3) : t.line2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                MlWell(
                    icon: stat.icon, color: tone, size: 34, iconSize: 16,
                    radius: 9),
                const Spacer(),
                _Delta(tokens: t, label: stat.delta, tone: stat.deltaTone),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Flexible(
                  child: Text(
                    stat.value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: MlGlass.display,
                      fontFamilyFallback: MlGlass.displayFallback,
                      fontSize: 30,
                      fontWeight: FontWeight.w400,
                      height: 1,
                      letterSpacing: -0.8,
                      color: t.inkHi,
                    ),
                  ),
                ),
                if (stat.unit != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 3),
                    child: Text(stat.unit!,
                        style: context.mlText.bodyMedium.copyWith(
                          color: t.inkMid,
                        )),
                  ),
              ],
            ),
            const SizedBox(height: 9),
            Text(stat.label,
                style: context.mlText.titleSmall.copyWith(
                  color: t.inkHi,
                  fontWeight: FontWeight.w700,
                )),
            const SizedBox(height: 3),
            Text(stat.sub,
                style: context.mlText.code(
                  color: t.inkLo,
                  size: 11,
                  weight: FontWeight.w400,
                )),
          ],
        ),
      ),
      ),
    );
  }
}

/// A rounded panel with a coloured left edge.
///
/// CSS puts `border-left: 3px` on a rounded box happily; Flutter asserts on a
/// non-uniform [Border] combined with a [BoxDecoration.borderRadius], so the
/// accent is painted as a clipped overlay instead of a border side. Clipping to
/// the same radius keeps the bar following the card's corner.
class _LeftAccent extends StatelessWidget {
  const _LeftAccent({
    required this.color,
    required this.radius,
    required this.child,
  });

  final Color color;
  final double radius;
  final Widget child;

  /// Matches the 3px accent side the drop used before the radius forced this
  /// to become an overlay.
  static const double _width = 3;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        Positioned(
          left: 0,
          top: 0,
          bottom: 0,
          child: ClipRRect(
            borderRadius:
                BorderRadius.horizontal(left: Radius.circular(radius)),
            child: SizedBox(width: _width, child: ColoredBox(color: color)),
          ),
        ),
      ],
    );
  }
}

class _Delta extends StatelessWidget {
  const _Delta({
    required this.tokens,
    required this.label,
    required this.tone,
  });

  final MlGlass tokens;
  final String? label;
  final MlDelta tone;

  @override
  Widget build(BuildContext context) {
    if (label == null || tone == MlDelta.none) return const SizedBox.shrink();
    final t = tokens;

    late final Color c;
    var triangle = false;
    var dot = false;
    var suffix = false;

    switch (tone) {
      case MlDelta.up:
        c = t.good;
        triangle = true;
        suffix = true;
        break;
      case MlDelta.warn:
        c = t.warn;
        triangle = true;
        suffix = true;
        break;
      case MlDelta.good:
        c = t.good;
        break;
      case MlDelta.live:
        c = t.good;
        dot = true;
        break;
      case MlDelta.flat:
      case MlDelta.none:
        c = t.inkLo;
        break;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (dot) ...[
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: c, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
        ],
        if (triangle) ...[
          Text('▲', style: TextStyle(fontSize: 8, height: 1, color: c)),
          const SizedBox(width: 4),
        ],
        Text(
          suffix ? '$label · 24h' : label!,
          style: context.mlText.code(
            color: c,
            size: 11,
            weight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

// ===========================================================================
// 4. Expired token banner
// ===========================================================================

class _ExpiredBanner extends StatelessWidget {
  const _ExpiredBanner({
    required this.tokens,
    required this.count,
    this.onTap,
  });

  final MlGlass tokens;

  /// How many companies are actually expired. Required — this banner is an
  /// alert, and an alert that cannot count is worse than no alert.
  final int count;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = tokens;
    return MlHoverLift(
      lift: 0,
      onTap: onTap,
      builder: (context, hovered) => _LeftAccent(
        color: t.warn.withValues(alpha: 0.85),
        radius: 12,
        child: Container(
        padding: const EdgeInsets.fromLTRB(18, 15, 16, 15),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              t.warn.withValues(alpha: 0.10),
              t.warn.withValues(alpha: 0.02),
              Colors.transparent,
            ],
            stops: const [0, 0.45, 1],
          ),
          borderRadius: MlShape.radiusMedium,
          border: Border.all(color: t.line2),
        ),
        child: Row(
          children: [
            MlWell(
                icon: Icons.warning_amber_rounded,
                color: t.warn,
                size: 38,
                iconSize: 18),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Expired token requests',
                      style: context.mlText.titleSmall.copyWith(
                        color: t.inkHi,
                        fontWeight: FontWeight.w700,
                      )),
                  const SizedBox(height: 3),
                  Text(
                    // The "· oldest 5 days waiting" clause is gone with the
                    // literal count: nothing reaching this screen carries how
                    // long a token has been expired, so the age was invented
                    // alongside the number.
                    '$count ${count == 1 ? 'company needs' : 'companies need'} '
                    'approvals or action from the Admin panel.',
                    style: context.mlText.bodySmall.copyWith(color: t.inkMid),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            AnimatedContainer(
              duration:
                  mlScreenMotion(context, const Duration(milliseconds: 140)),
              height: 32,
              padding: const EdgeInsets.symmetric(horizontal: 13),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: t.warn.withValues(alpha: hovered ? 0.24 : 0.16),
                border: Border.all(color: t.warn.withValues(alpha: 0.4)),
                borderRadius: MlShape.radiusSmall,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Review',
                      style: context.mlText.labelMedium.copyWith(
                        color: t.warn,
                        fontWeight: FontWeight.w700,
                      )),
                  const SizedBox(width: 5),
                  Icon(Icons.chevron_right_rounded, size: 15, color: t.warn),
                ],
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }
}

// ===========================================================================
// 5. Quick actions
// ===========================================================================

class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.tokens, this.onNavigate});

  final MlGlass tokens;
  final ValueChanged<String>? onNavigate;

  static const List<List<Object>> _actions = <List<Object>>[
    ['register', 'Register company', Icons.add_rounded, true],
    ['orgs', 'Organizations', Icons.domain_rounded, false],
    ['tokens.requests', 'Token requests', Icons.vpn_key_outlined, false],
    ['tokens.history', 'Token history', Icons.history_rounded, false],
    ['tokens.audit', 'Audit logs', Icons.description_outlined, false],
    ['export', 'Export report', Icons.download_rounded, false],
  ];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: _actions
          .map((a) => _ActionButton(
                tokens: tokens,
                label: a[1] as String,
                icon: a[2] as IconData,
                primary: a[3] as bool,
                onTap: () => onNavigate?.call(a[0] as String),
              ))
          .toList(),
    );
  }
}

class _ActionButton extends StatefulWidget {
  const _ActionButton({
    required this.tokens,
    required this.label,
    required this.icon,
    required this.primary,
    this.onTap,
  });

  final MlGlass tokens;
  final String label;
  final IconData icon;
  final bool primary;
  final VoidCallback? onTap;

  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton> {
  bool _h = false;

  @override
  Widget build(BuildContext context) {
    final t = widget.tokens;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _h = true),
      onExit: (_) => setState(() => _h = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: mlScreenMotion(context, const Duration(milliseconds: 140)),
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 15),
          decoration: BoxDecoration(
            color: widget.primary
                ? t.accent.withValues(alpha: _h ? 0.18 : 0.11)
                : (_h ? t.inkHi.withValues(alpha: 0.05) : t.panel),
            border: Border.all(
              color: widget.primary ? t.accent.withValues(alpha: 0.34) : t.line2,
            ),
            borderRadius: MlShape.radiusMedium,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon,
                  size: 16, color: widget.primary ? t.accent2 : t.inkMid),
              const SizedBox(width: 9),
              Text(
                widget.label,
                style: context.mlText.labelMedium.copyWith(
                  color: widget.primary ? t.accent2 : t.inkHi,
                  fontWeight: widget.primary ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ===========================================================================
// 6. Recently active organizations
// ===========================================================================

class _RecentOrgsPanel extends StatefulWidget {
  const _RecentOrgsPanel({
    required this.tokens,
    required this.rows,
    this.onNavigate,
  });

  final MlGlass tokens;
  final List<MlRecentOrg> rows;
  final ValueChanged<String>? onNavigate;

  @override
  State<_RecentOrgsPanel> createState() => _RecentOrgsPanelState();
}

class _RecentOrgsPanelState extends State<_RecentOrgsPanel> {
  String _tab = 'all';

  static const List<List<String>> _tabs = [
    ['all', 'All types'],
    ['Mine', 'Mines'],
    ['Buyer', 'Buyers'],
    ['Transporter', 'Transporters'],
  ];

  /// Live count per tab. The drop hardcoded these (24 / 11 / 7 / 6) as design
  /// placeholders; against real rows a fixed number would contradict the table
  /// rendered directly beneath it.
  int _count(String key) => key == 'all'
      ? widget.rows.length
      : widget.rows.where((r) => r.type == key).length;

  Color _dot(MlGlass t, MlExpiry e) {
    switch (e) {
      case MlExpiry.ok:
        return t.good;
      case MlExpiry.warn:
        return t.warn;
      case MlExpiry.expired:
        return t.bad;
    }
  }

  String _pillKind(String type) {
    switch (type) {
      case 'Buyer':
        return 'v';
      case 'Mine':
        return 'w';
      default:
        return 'c';
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.tokens;
    final rows = _tab == 'all'
        ? widget.rows
        : widget.rows.where((r) => r.type == _tab).toList();

    return MlPanel(
      tokens: t,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          LayoutBuilder(
            builder: (context, c) {
              final words = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Recently active organizations',
                      style: context.mlText.editorialMedium.copyWith(
                        color: t.inkHi,
                        fontWeight: FontWeight.w400,
                      )),
                  const SizedBox(height: 3),
                  Text(
                    'Live token expiry — companies under 7 days are '
                    'flagged for upgrade.',
                    style: context.mlText.bodySmall.copyWith(color: t.inkMid),
                  ),
                ],
              );
              final well = MlWell(
                  icon: Icons.monitor_heart_outlined,
                  color: t.good,
                  size: 38,
                  iconSize: 18);
              final manage = _ManageAll(
                  tokens: t, onTap: () => widget.onNavigate?.call('orgs'));
              // Below 460px the "Manage all" button and the words cannot share
              // a row: on a 412px phone the button's ~140px left the heading
              // "Recently active / organizations" over two lines and its
              // sentence over four, in a 150px column.
              if (c.maxWidth < 460) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        well,
                        const SizedBox(width: 13),
                        Expanded(child: words),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Align(alignment: Alignment.centerLeft, child: manage),
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  well,
                  const SizedBox(width: 13),
                  Expanded(child: words),
                  const SizedBox(width: 12),
                  manage,
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                // A Wrap lays every child out against UNBOUNDED width, so a
                // chip wider than the Wrap itself does not wrap -- it
                // overflows. At text scale 1.6 with bold text on a 412px
                // phone, the "Transporters" chip is exactly that, and it
                // overflowed by 6.1px. Flexible cannot help inside a Wrap
                // (there is no free space to flex against); the chip needs a
                // real maximum, which is what this LayoutBuilder supplies.
                child: LayoutBuilder(
                  builder: (context, c) => Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: _tabs.map((tab) {
                      final key = tab[0];
                      final sel = _tab == key;
                      return MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: GestureDetector(
                          onTap: () => setState(() => _tab = key),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(maxWidth: c.maxWidth),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 11, vertical: 6),
                              decoration: BoxDecoration(
                                color: sel
                                    ? t.accent.withValues(alpha: 0.12)
                                    : t.inkHi.withValues(alpha: 0.03),
                                border: Border.all(
                                    color: sel
                                        ? t.accent.withValues(alpha: 0.35)
                                        : t.line),
                                borderRadius: MlShape.radiusSmall,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // The count must never be the thing that
                                  // gets clipped -- a tab reading "Transp… 12"
                                  // is still usable, one reading
                                  // "Transporters 1" is a lie. So the label
                                  // flexes and the count does not.
                                  Flexible(
                                    child: Text(tab[1],
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: context.mlText.bodySmall.copyWith(
                                          color: sel ? t.accent2 : t.inkMid,
                                        )),
                                  ),
                                  const SizedBox(width: 6),
                                  Text('${_count(key)}',
                                      style: context.mlText.code(
                                        color: sel ? t.accent : t.inkLo,
                                        size: 10,
                                        weight: FontWeight.w400,
                                      )),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
              Text.rich(
                TextSpan(children: [
                  TextSpan(
                      text: 'Sort by ',
                      style: context.mlText.labelSmall.copyWith(
                        color: t.inkLo,
                        fontWeight: FontWeight.w400,
                      )),
                  TextSpan(
                      text: 'last active ↓',
                      style: context.mlText.labelSmall.copyWith(color: t.inkMid)),
                ]),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // A four-column table is a desktop shape. Below `_tableFloor` each
          // organization becomes a stacked card instead — see [_card].
          LayoutBuilder(
            builder: (context, c) {
              final asTable = c.maxWidth >= _tableFloor;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (asTable) ...[
                    _head(t),
                    Container(height: 1, color: t.line2),
                  ],
                  if (rows.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 28),
                      child: Text(
                        'No organizations of this type in the current window.',
                        textAlign: TextAlign.center,
                        style: context.mlText.bodyMedium.copyWith(
                          color: t.inkMid,
                        ),
                      ),
                    ),
                  ...rows.map((r) => asTable ? _row(t, r) : _card(t, r)),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  /// Below this the table becomes a list of cards.
  ///
  /// 720 is not a guess: the row has a fixed 76px action column and four flex
  /// columns weighted 32/14/16/24. At 412px the token-expiry cell (flex 24)
  /// resolves to roughly 74px and has to hold a status dot, a
  /// `42d 08 : 34 : 55` countdown AND a date -- it cannot, at any text scale.
  /// Four of the six rows overflowed there. Widening that cell only moves the
  /// squeeze onto the company name; a four-column table is simply a desktop
  /// shape, and the fix is to stop drawing one on a phone.
  static const double _tableFloor = 720;

  /// One organization as a stacked card -- the phone rendering of [_row].
  ///
  /// Same data, same order, nothing dropped: identity, then type and seats,
  /// then the token countdown. It reads top-to-bottom instead of
  /// left-to-right, which is the only thing that actually changes.
  Widget _card(MlGlass t, MlRecentOrg r) {
    final dot = _dot(t, r.expiryState);
    final full = r.seatsUsed >= r.seats;

    Widget label(String s) => Text(s.toUpperCase(),
        style: TextStyle(
          fontFamily: MlGlass.sans,
          fontSize: 9,
          letterSpacing: 1.15,
          fontWeight: FontWeight.w600,
          color: t.inkLo,
        ));

    return MlHoverLift(
      lift: 0,
      onTap: () => widget.onNavigate?.call('orgs'),
      builder: (context, hovered) => AnimatedContainer(
        duration: mlScreenMotion(context, const Duration(milliseconds: 120)),
        margin: const EdgeInsets.only(top: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: hovered ? t.inkHi.withValues(alpha: 0.025) : Colors.transparent,
          border: Border.all(color: t.line),
          borderRadius: MlShape.radiusMedium,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // ---- identity ----
            Row(
              children: [
                _OrgAvatar(colors: r.avatarColors, initials: r.initials),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(r.name,
                          // TWO lines: the company NAME is what this row is,
                          // and the longest on the platform is 333px against
                          // 226px here.
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: context.mlText.titleSmall.copyWith(
                            color: t.inkHi,
                            fontWeight: FontWeight.w700,
                          )),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Container(
                            width: 5,
                            height: 5,
                            decoration: BoxDecoration(
                                color: dot, shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '${r.status} - ${r.location} - ${r.users} users',
                              overflow: TextOverflow.ellipsis,
                              style: context.mlText.labelSmall.copyWith(
                                color: t.inkMid,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded,
                    size: 18, color: hovered ? t.accent2 : t.inkLo),
              ],
            ),
            const SizedBox(height: 12),
            // ---- org type + seats ----
            Row(
              children: [
                // Flexible: at 360px and text scale 2.0 a "MINESUPPLIER" pill
                // claims so much of this row that the seat count beside it
                // overflowed by 3.4px. The pill is the part that can afford to
                // give — it ellipsises, and the count cannot.
                Flexible(
                  child: MlPill(r.type.toUpperCase(),
                      tokens: t, kind: _pillKind(r.type)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      label('Seats'),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          Expanded(
                            child: MlMeter(
                              value: r.seats == 0 ? 0 : r.seatsUsed / r.seats,
                              track: t.inkHi.withValues(alpha: 0.07),
                              fill: full ? t.warn : t.accent3,
                              gradientEnd: full ? t.warn : t.accent,
                              height: 3,
                              radius: 999,
                            ),
                          ),
                          const SizedBox(width: 9),
                          Text('${r.seatsUsed}/${r.seats}',
                              style: TextStyle(
                                fontFamily: MlGlass.mono,
                                fontSize: 11,
                                color: t.inkMid,
                                fontFeatures: const [
                                  FontFeature.tabularFigures()
                                ],
                              )),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // ---- token expiry: the cell that could not fit as a column ----
            label('Token expiry'),
            const SizedBox(height: 5),
            Row(
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
                ),
                const SizedBox(width: 9),
                Flexible(
                  child: Text(r.expiry,
                      overflow: TextOverflow.ellipsis,
                      style: context.mlText.code(
                        color: r.expiryState == MlExpiry.expired ? t.bad : t.inkHi,
                        size: 12,
                        weight: FontWeight.w600,
                      )),
                ),
                const SizedBox(width: 9),
                Flexible(
                  child: Text(r.date,
                      overflow: TextOverflow.ellipsis,
                      style: context.mlText.labelSmall.copyWith(
                        color: t.inkLo,
                        fontWeight: FontWeight.w400,
                      )),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _head(MlGlass t) {
    Widget cell(String label, int flex) => Expanded(
          flex: flex,
          child: Text(label.toUpperCase(),
              style: TextStyle(
                fontFamily: MlGlass.sans,
                fontSize: 9,
                letterSpacing: 1.15,
                fontWeight: FontWeight.w600,
                color: t.inkLo,
              )),
        );
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          cell('Company', 32),
          cell('Org type', 14),
          cell('Seats', 16),
          cell('Token expiry', 24),
          const SizedBox(width: 76),
        ],
      ),
    );
  }

  Widget _row(MlGlass t, MlRecentOrg r) {
    final dot = _dot(t, r.expiryState);
    final full = r.seatsUsed >= r.seats;

    return MlHoverLift(
      lift: 0,
      onTap: () => widget.onNavigate?.call('orgs'),
      builder: (context, hovered) => AnimatedContainer(
        duration: mlScreenMotion(context, const Duration(milliseconds: 120)),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: hovered ? t.inkHi.withValues(alpha: 0.025) : Colors.transparent,
          border: Border(bottom: BorderSide(color: t.line)),
        ),
        child: Row(
          children: [
            Expanded(
              flex: 32,
              child: Row(
                children: [
                  _OrgAvatar(colors: r.avatarColors, initials: r.initials),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(r.name,
                            // TWO lines: the company NAME is what this row is,
                            // and the longest on the platform is 333px against
                            // 226px here.
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: context.mlText.titleSmall.copyWith(
                              color: t.inkHi,
                              fontWeight: FontWeight.w700,
                            )),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Container(
                              width: 5,
                              height: 5,
                              decoration: BoxDecoration(
                                  color: dot, shape: BoxShape.circle),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                '${r.status} · ${r.location} · ${r.users} users',
                                overflow: TextOverflow.ellipsis,
                                style: context.mlText.labelSmall.copyWith(
                                  color: t.inkMid,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 14,
              child: Align(
                alignment: Alignment.centerLeft,
                child: MlPill(r.type.toUpperCase(),
                    tokens: t, kind: _pillKind(r.type)),
              ),
            ),
            Expanded(
              flex: 16,
              child: Row(
                children: [
                  Expanded(
                    child: MlMeter(
                      value: r.seats == 0 ? 0 : r.seatsUsed / r.seats,
                      track: t.inkHi.withValues(alpha: 0.07),
                      fill: full ? t.warn : t.accent3,
                      gradientEnd: full ? t.warn : t.accent,
                      height: 3,
                      radius: 999,
                    ),
                  ),
                  const SizedBox(width: 9),
                  Text('${r.seatsUsed}/${r.seats}',
                      style: context.mlText.code(
                        color: t.inkMid,
                        size: 11,
                        weight: FontWeight.w400,
                      )),
                ],
              ),
            ),
            Expanded(
              flex: 24,
              child: Row(
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration:
                        BoxDecoration(color: dot, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 9),
                  Flexible(
                    child: Text(r.expiry,
                        overflow: TextOverflow.ellipsis,
                        style: context.mlText.code(
                          color: r.expiryState == MlExpiry.expired ? t.bad : t.inkHi,
                          size: 12,
                          weight: FontWeight.w600,
                        )),
                  ),
                  const SizedBox(width: 9),
                  // Flexible, like the countdown beside it. A Row hands a
                  // non-flex child unbounded width (CLAUDE.md 10.4), so this
                  // date could not ellipsize and simply pushed the cell over --
                  // four of the six rows overflowed at 412px.
                  Flexible(
                    child: Text(r.date,
                        overflow: TextOverflow.ellipsis,
                        style: context.mlText.labelSmall.copyWith(
                          color: t.inkLo,
                          fontWeight: FontWeight.w400,
                        )),
                  ),
                ],
              ),
            ),
            SizedBox(
              width: 76,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Icon(Icons.chat_bubble_outline_rounded,
                      size: 16, color: t.inkLo),
                  const SizedBox(width: 10),
                  Icon(Icons.chevron_right_rounded,
                      size: 18, color: hovered ? t.accent2 : t.inkLo),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ManageAll extends StatefulWidget {
  const _ManageAll({required this.tokens, this.onTap});

  final MlGlass tokens;
  final VoidCallback? onTap;

  @override
  State<_ManageAll> createState() => _ManageAllState();
}

class _ManageAllState extends State<_ManageAll> {
  bool _h = false;

  @override
  Widget build(BuildContext context) {
    final t = widget.tokens;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _h = true),
      onExit: (_) => setState(() => _h = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: mlScreenMotion(context, const Duration(milliseconds: 140)),
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 13),
          decoration: BoxDecoration(
            color: t.accent.withValues(alpha: _h ? 0.16 : 0.08),
            border: Border.all(color: t.accent.withValues(alpha: 0.25)),
            borderRadius: MlShape.radiusSmall,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.open_in_new_rounded, size: 15, color: t.accent2),
              const SizedBox(width: 8),
              Text('Manage all',
                  style: context.mlText.labelMedium.copyWith(color: t.accent2)),
            ],
          ),
        ),
      ),
    );
  }
}

/// The organisation avatar: an org's initials on its own two-stop gradient.
///
/// Extracted because the console had this block twice, byte for byte, and
/// both copies drew the initials in WHITE. `MlConsolePalettes.avatarRamp` is
/// six MID-SATURATION brand gradients, and mid-saturation is exactly where
/// "white on a colour" stops working: white reached 4.5:1 on NONE of the six,
/// bottoming out at 1.89:1 on the amber. `MlTokens.inkOnFills` measures both
/// candidate inks against BOTH stops and takes the better one, which for
/// every ramp in this set is the near-black.
///
/// Two copies of a fault is a shape, not two bugs — a third call site added
/// later would have been white again.
class _OrgAvatar extends StatelessWidget {
  const _OrgAvatar({required this.colors, required this.initials});

  final List<Color> colors;
  final String initials;

  /// The console draws this at one size. Kept as constants rather than as
  /// parameters nothing passes - an unused knob is a claim about flexibility
  /// that no call site is making.
  static const double _size = 36;
  static const double _fontSize = 12;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _size,
      height: _size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
        borderRadius: MlShape.radiusMedium,
      ),
      child: Text(
        initials,
        style: TextStyle(
          fontFamily: MlGlass.mono,
          fontSize: _fontSize,
          fontWeight: FontWeight.w700,
          color: MlTokens.inkOnFills(colors),
        ),
      ),
    );
  }
}
