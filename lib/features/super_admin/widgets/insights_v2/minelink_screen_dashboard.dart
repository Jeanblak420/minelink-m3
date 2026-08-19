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

import 'package:flutter/material.dart';

import 'minelink_screens_core.dart';
import 'minelink_charts.dart';
import 'package:flutter_application_1/core/design/tokens/ml_surface_tokens.dart';
import 'package:flutter_application_1/core/design/charts/ml_sparkline.dart';
import 'package:flutter_application_1/core/design/tokens/ml_console_palettes.dart';
import 'package:flutter_application_1/core/design/tokens/ml_tokens.dart';

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
    this.tokens,
    this.padding = const EdgeInsets.fromLTRB(24, 20, 24, 40),
  });

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
                  meta: 'This month · Jul 2026',
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
                        '${pendingRequests.fold<int>(0, (a, r) => a + r.count)}'
                        ' open · 2 aging > 24h',
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
                  meta: 'Last 24h · +2 companies, +14 users',
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
                const SizedBox(height: 26),
                _ExpiredBanner(
                    tokens: t, onTap: () => _go('tokens.requests')),

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
          borderRadius: BorderRadius.circular(12),
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
                          style: TextStyle(
                            fontFamily: MlGlass.sans,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.15,
                            color: t.inkHi,
                          )),
                      const SizedBox(height: 3),
                      Text(agg.subtitle,
                          style: TextStyle(
                              fontFamily: MlGlass.sans,
                              fontSize: 10.5,
                              color: t.inkMid)),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded,
                    size: 18, color: hovered ? t.accent2 : t.inkLo),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    // Flexible, not a bare child: a Row hands non-flex children
                    // unbounded width, and MlStat ellipsises its value through
                    // a Flexible — which asserts under an unbounded parent.
                    // Loose fit keeps the spaceBetween look.
                    children: agg.metrics
                        .map((m) => Flexible(
                            child: MlStat(
                                tokens: t,
                                label: m.key,
                                value: m.value,
                                valueSize: 15)))
                        .toList(),
                  ),
                ),
                const SizedBox(width: 14),
                MlSparkline(
                    data: agg.spark,
                    color: agg.sparkColor,
                    width: 84,
                    height: 30),
              ],
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
          borderRadius: BorderRadius.circular(12),
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
                      borderRadius: BorderRadius.circular(999),
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
                      style: TextStyle(
                        fontFamily: MlGlass.sans,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: t.inkHi,
                      )),
                  const SizedBox(height: 4),
                  Text(req.sub,
                      style: TextStyle(
                        fontFamily: MlGlass.sans,
                        fontSize: 11,
                        height: 1.45,
                        color: t.inkMid,
                      )),
                  const SizedBox(height: 8),
                  Text('${req.count} new · Review →',
                      style: TextStyle(
                        fontFamily: MlGlass.sans,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
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
        borderRadius: BorderRadius.circular(999),
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
              style: TextStyle(
                fontFamily: MlGlass.sans,
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.6,
                color: t.good,
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
          borderRadius: BorderRadius.circular(12),
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
                        style: TextStyle(
                            fontFamily: MlGlass.sans,
                            fontSize: 14,
                            color: t.inkMid)),
                  ),
              ],
            ),
            const SizedBox(height: 9),
            Text(stat.label,
                style: TextStyle(
                  fontFamily: MlGlass.sans,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: t.inkHi,
                )),
            const SizedBox(height: 3),
            Text(stat.sub,
                style: TextStyle(
                    fontFamily: MlGlass.mono,
                    fontSize: 10.5,
                    color: t.inkLo)),
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
          Text('▲', style: TextStyle(fontSize: 7.5, height: 1, color: c)),
          const SizedBox(width: 4),
        ],
        Text(
          suffix ? '$label · 24h' : label!,
          style: TextStyle(
            fontFamily: MlGlass.mono,
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            color: c,
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
  const _ExpiredBanner({required this.tokens, this.onTap});

  final MlGlass tokens;
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
          borderRadius: BorderRadius.circular(12),
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
                      style: TextStyle(
                        fontFamily: MlGlass.sans,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: t.inkHi,
                      )),
                  const SizedBox(height: 3),
                  Text(
                    '3 companies need approvals or action from the Admin '
                    'panel · oldest 5 days waiting.',
                    style: TextStyle(
                      fontFamily: MlGlass.sans,
                      fontSize: 11.5,
                      height: 1.45,
                      color: t.inkMid,
                    ),
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
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Review',
                      style: TextStyle(
                        fontFamily: MlGlass.sans,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: t.warn,
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
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon,
                  size: 16, color: widget.primary ? t.accent2 : t.inkMid),
              const SizedBox(width: 9),
              Text(
                widget.label,
                style: TextStyle(
                  fontFamily: MlGlass.sans,
                  fontSize: 12,
                  fontWeight:
                      widget.primary ? FontWeight.w700 : FontWeight.w500,
                  color: widget.primary ? t.accent2 : t.inkHi,
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
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              MlWell(
                  icon: Icons.monitor_heart_outlined,
                  color: t.good,
                  size: 38,
                  iconSize: 18),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Recently active organizations',
                        style: TextStyle(
                          fontFamily: MlGlass.display,
                          fontSize: 18,
                          fontWeight: FontWeight.w400,
                          letterSpacing: -0.2,
                          color: t.inkHi,
                        )),
                    const SizedBox(height: 3),
                    Text(
                      'Live token expiry — companies under 7 days are '
                      'flagged for upgrade.',
                      style: TextStyle(
                          fontFamily: MlGlass.sans,
                          fontSize: 11.5,
                          color: t.inkMid),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _ManageAll(
                  tokens: t, onTap: () => widget.onNavigate?.call('orgs')),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _tabs.map((tab) {
                    final key = tab[0];
                    final sel = _tab == key;
                    return MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: GestureDetector(
                        onTap: () => setState(() => _tab = key),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 11, vertical: 6),
                          decoration: BoxDecoration(
                            color: sel
                                ? t.accent.withValues(alpha: 0.12)
                                : t.inkHi.withValues(alpha: 0.03),
                            border: Border.all(
                                color:
                                    sel ? t.accent.withValues(alpha: 0.35) : t.line),
                            borderRadius: BorderRadius.circular(7),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(tab[1],
                                  style: TextStyle(
                                      fontFamily: MlGlass.sans,
                                      fontSize: 11.5,
                                      color: sel ? t.accent2 : t.inkMid)),
                              const SizedBox(width: 6),
                              Text('${_count(key)}',
                                  style: TextStyle(
                                      fontFamily: MlGlass.mono,
                                      fontSize: 10,
                                      color: sel ? t.accent : t.inkLo)),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              Text.rich(
                TextSpan(children: [
                  TextSpan(
                      text: 'Sort by ',
                      style: TextStyle(
                          fontFamily: MlGlass.sans,
                          fontSize: 11,
                          color: t.inkLo)),
                  TextSpan(
                      text: 'last active ↓',
                      style: TextStyle(
                          fontFamily: MlGlass.sans,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: t.inkMid)),
                ]),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _head(t),
          Container(height: 1, color: t.line2),
          if (rows.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 28),
              child: Text(
                'No organizations of this type in the current window.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontFamily: MlGlass.sans, fontSize: 12.5, color: t.inkMid),
              ),
            ),
          ...rows.map((r) => _row(t, r)),
        ],
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
                  Container(
                    width: 36,
                    height: 36,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: r.avatarColors,
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(r.initials,
                        style: const TextStyle(
                          fontFamily: MlGlass.mono,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: MlTokens.inkOnFill,
                        )),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(r.name,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: MlGlass.sans,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: t.inkHi,
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
                                style: TextStyle(
                                    fontFamily: MlGlass.sans,
                                    fontSize: 11,
                                    color: t.inkMid),
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
                      style: TextStyle(
                        fontFamily: MlGlass.mono,
                        fontSize: 11,
                        color: t.inkMid,
                        fontFeatures: const [FontFeature.tabularFigures()],
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
                        style: TextStyle(
                          fontFamily: MlGlass.mono,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: r.expiryState == MlExpiry.expired
                              ? t.bad
                              : t.inkHi,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        )),
                  ),
                  const SizedBox(width: 9),
                  Text(r.date,
                      style: TextStyle(
                          fontFamily: MlGlass.sans,
                          fontSize: 10.5,
                          color: t.inkLo)),
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
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.open_in_new_rounded, size: 15, color: t.accent2),
              const SizedBox(width: 8),
              Text('Manage all',
                  style: TextStyle(
                    fontFamily: MlGlass.sans,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: t.accent2,
                  )),
            ],
          ),
        ),
      ),
    );
  }
}
