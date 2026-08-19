// ============================================================================
// VERSION 3 — "WEIGHBRIDGE"
// ----------------------------------------------------------------------------
// Light-first, and built like an instrument rather than app chrome. The
// premise: MineLink is a ledger business — tare, gross, net, tonnes, ticket
// counts — so the sidebar is set as a manifest.
//
// Two signatures:
//   1. A fixed right-hand tally column. Counts are typeset as mono figures in
//      their own aligned column, not stuffed into pills, so a super-admin can
//      read down the edge and see where work is piling up.
//   2. The active row is an ink block — solid stamp, inverted type. Nothing
//      else on screen is filled, so there is never a question of where you are.
//
// Rows are full-bleed and hairline-ruled; expansion is a ledger + / − rather
// than a chevron. Pick this one if density and legibility beat atmosphere.
//
// Vendored from the design drop; `MlTokens` renamed to `MlSidebarTokens` and
// `withOpacity` → `withValues` for this repo. See the core file's header.
// ============================================================================

import 'package:flutter/material.dart';

// WeighbridgeTokens moved to the design-token layer at S5-19 — it is a palette table,
// not a screen. Re-exported so existing imports still resolve it.
export 'package:flutter_application_1/core/design/tokens/ml_sidebar_skin_palettes.dart';
import 'package:flutter_application_1/core/design/tokens/ml_sidebar_skin_palettes.dart';

import 'minelink_sidebar_core.dart';
import 'package:flutter_application_1/core/design/tokens/ml_tokens.dart';

/// Type set on the inverted ink block. `tokens.onInk` (additive to the drop)
/// lets a palette variant supply its own; null keeps the original pair.
/// Derived from the skin rather than restated: on a dark skin the block is
/// inverted (paper on ink), so its type is the skin's own panel colour; on a
/// light skin the block is ink and its type is the paper. Both resolve to the
/// exact literals this used to hardcode — `WeighbridgeTokens.dark.surface` is
/// `#101317` and `.light.surfaceRaised` is `#FFFFFF` — but a palette variant
/// that changes either now carries its ink with it (S5-19).
Color _onInk(MlSidebarTokens t) =>
    t.onInk ?? (t.isDarkSurface ? t.surface : t.surfaceRaised);

class WeighbridgeSidebar extends StatefulWidget {
  const WeighbridgeSidebar({
    super.key,
    required this.selectedId,
    required this.onSelect,
    this.onLogout,
    this.collapsed = false,
    this.onCollapsedChanged,
    this.badges = const <String, int>{},
    required this.user,
    this.brand = const MlBrand(),
    this.tokens,
    this.showSearch = true,
  });

  final String selectedId;
  final ValueChanged<String> onSelect;
  final VoidCallback? onLogout;
  final bool collapsed;
  final ValueChanged<bool>? onCollapsedChanged;
  final Map<String, int> badges;
  final MlSidebarUser user;
  final MlBrand brand;
  final MlSidebarTokens? tokens;
  final bool showSearch;

  @override
  State<WeighbridgeSidebar> createState() => _WeighbridgeSidebarState();
}

class _WeighbridgeSidebarState extends State<WeighbridgeSidebar> {
  final Set<String> _open = <String>{};
  final TextEditingController _search = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _openAncestorsOf(widget.selectedId);
  }

  @override
  void didUpdateWidget(covariant WeighbridgeSidebar old) {
    super.didUpdateWidget(old);
    if (old.selectedId != widget.selectedId) {
      _openAncestorsOf(widget.selectedId);
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _openAncestorsOf(String id) {
    if (id.contains('.')) _open.add(id.split('.').first);
  }

  MlSidebarTokens get _t =>
      widget.tokens ??
      (Theme.of(context).brightness == Brightness.dark
          ? WeighbridgeTokens.dark
          : WeighbridgeTokens.light);

  void _toggle(String id) =>
      setState(() => _open.contains(id) ? _open.remove(id) : _open.add(id));

  List<MlNavItem> _visible(List<MlNavItem> src) {
    if (_query.trim().isEmpty) return src;
    return src.map((i) => i.filtered(_query)).whereType<MlNavItem>().toList();
  }

  /// Sum of every count under a collapsed group — the tally column shows the
  /// rolled-up figure so nothing hides behind a closed section.
  int? _rollup(MlNavItem item) {
    final own = widget.badges[item.id];
    if (item.children.isEmpty) return own;
    var total = own ?? 0;
    for (final c in item.children) {
      total += widget.badges[c.id] ?? 0;
    }
    return total == 0 ? null : (own ?? total);
  }

  @override
  Widget build(BuildContext context) {
    final t = _t;
    final collapsed = widget.collapsed;

    return AnimatedContainer(
      duration: mlMotion(context, const Duration(milliseconds: 220)),
      curve: Curves.easeOutCubic,
      width: collapsed ? t.railWidth : t.expandedWidth,
      decoration: BoxDecoration(
        color: t.surface,
        border: Border(right: BorderSide(color: t.border)),
      ),
      child: ClipRect(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _WbHeader(
              tokens: t,
              brand: widget.brand,
              collapsed: collapsed,
              onToggle: () => widget.onCollapsedChanged?.call(!collapsed),
            ),
            if (widget.showSearch)
              _WbSearch(
                tokens: t,
                collapsed: collapsed,
                controller: _search,
                onChanged: (v) => setState(() => _query = v),
                onExpandRequest: () => widget.onCollapsedChanged?.call(false),
              ),
            Expanded(
              child: ScrollConfiguration(
                behavior:
                    ScrollConfiguration.of(context).copyWith(scrollbars: false),
                child: ListView(
                  padding: const EdgeInsets.only(bottom: 16),
                  children: _nav(t, collapsed),
                ),
              ),
            ),
            _WbFooter(
              tokens: t,
              collapsed: collapsed,
              open: _open,
              selectedId: widget.selectedId,
              badges: widget.badges,
              user: widget.user,
              onSelect: widget.onSelect,
              onToggleGroup: _toggle,
              onLogout: widget.onLogout,
              onCollapsedChanged: widget.onCollapsedChanged,
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _nav(MlSidebarTokens t, bool collapsed) {
    final out = <Widget>[_row(t, MlNav.dashboard, collapsed)];
    for (final item in _visible(MlNav.main)) {
      if (item.section != null) {
        out.add(collapsed
            ? _WbRailRule(tokens: t)
            : _WbBand(label: item.section!, tokens: t));
      }
      out.add(_row(t, item, collapsed));
    }
    if (_query.trim().isNotEmpty && _visible(MlNav.main).isEmpty) {
      out.add(_WbEmpty(tokens: t, query: _query));
    }
    return out;
  }

  Widget _row(MlSidebarTokens t, MlNavItem item, bool collapsed) => _WbRow(
        key: ValueKey(item.id),
        item: item,
        tokens: t,
        collapsed: collapsed,
        expanded: _open.contains(item.id),
        selectedId: widget.selectedId,
        selected: widget.selectedId == item.id ||
            item.children.any((c) => c.id == widget.selectedId),
        badges: widget.badges,
        tally: _rollup(item),
        onSelect: widget.onSelect,
        onToggle: () {
          if (collapsed) {
            widget.onCollapsedChanged?.call(false);
            setState(() => _open.add(item.id));
          } else {
            _toggle(item.id);
          }
        },
      );
}

// ---------------------------------------------------------------------------
// Header — centred lockup between two gold rules, ruled underneath
// ---------------------------------------------------------------------------

class _WbHeader extends StatelessWidget {
  const _WbHeader({
    required this.tokens,
    required this.brand,
    required this.collapsed,
    required this.onToggle,
  });

  final MlSidebarTokens tokens;
  final MlBrand brand;
  final bool collapsed;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final t = tokens;

    if (collapsed) {
      return Container(
        padding: const EdgeInsets.fromLTRB(0, 14, 0, 14),
        decoration:
            BoxDecoration(border: Border(bottom: BorderSide(color: t.border))),
        child: Column(
          children: [
            _WbGhostButton(
              tokens: t,
              icon: Icons.chevron_right_rounded,
              tooltip: 'Expand sidebar',
              onTap: onToggle,
            ),
            // Brand mark at the classic rail's size and placement.
            const SizedBox(height: 12),
            Image.asset(
              brand.icon(onDarkSurface: t.isDarkSurface),
              height: brand.iconSize,
              width: brand.iconSize,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.medium,
              semanticLabel: 'MineLink',
              errorBuilder: (_, __, ___) => Text(
                'ML',
                style: TextStyle(
                  fontFamily: t.display,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: t.textPrimary,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
      decoration:
          BoxDecoration(border: Border(bottom: BorderSide(color: t.border))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: _WbGhostButton(
              tokens: t,
              icon: Icons.chevron_left_rounded,
              tooltip: 'Collapse sidebar',
              onTap: onToggle,
            ),
          ),
          // Brand lockup at the classic rail's size and placement.
          const SizedBox(height: 8),
          Center(
            child: Image.asset(
              brand.logo(onDarkSurface: t.isDarkSurface),
              height: brand.logoHeight,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.medium,
              semanticLabel: 'MineLink Technologies',
              errorBuilder: (_, __, ___) => Text(
                'MineLink',
                style: TextStyle(
                  fontFamily: t.display,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.7,
                  color: t.textPrimary,
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: Container(height: 2, color: t.accent)),
              const SizedBox(width: 9),
              Text(
                brand.consoleLabel,
                style: TextStyle(
                  fontFamily: t.mono,
                  fontSize: 8.5,
                  letterSpacing: 1.7,
                  fontWeight: FontWeight.w700,
                  color: t.textSecondary,
                ),
              ),
              const SizedBox(width: 9),
              Expanded(child: Container(height: 2, color: t.accent)),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Search — ruled, not boxed
// ---------------------------------------------------------------------------

class _WbSearch extends StatelessWidget {
  const _WbSearch({
    required this.tokens,
    required this.collapsed,
    required this.controller,
    required this.onChanged,
    required this.onExpandRequest,
  });

  final MlSidebarTokens tokens;
  final bool collapsed;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onExpandRequest;

  @override
  Widget build(BuildContext context) {
    final t = tokens;

    if (collapsed) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration:
            BoxDecoration(border: Border(bottom: BorderSide(color: t.border))),
        child: _WbGhostButton(
          tokens: t,
          icon: Icons.search_rounded,
          tooltip: 'Search the console',
          onTap: onExpandRequest,
        ),
      );
    }

    return Container(
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration:
          BoxDecoration(border: Border(bottom: BorderSide(color: t.border))),
      child: Row(
        children: [
          Icon(Icons.search_rounded, size: 16, color: t.textMuted),
          const SizedBox(width: 11),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              style: TextStyle(
                fontFamily: t.body,
                fontSize: 13,
                color: t.textPrimary,
              ),
              cursorColor: t.accent,
              decoration: InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                hintText: 'Search the console',
                hintStyle: TextStyle(
                  fontFamily: t.body,
                  fontSize: 13,
                  color: t.textMuted,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Section band
// ---------------------------------------------------------------------------

class _WbBand extends StatelessWidget {
  const _WbBand({required this.label, required this.tokens});

  final String label;
  final MlSidebarTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 30,
      padding: const EdgeInsets.only(left: 18, right: 14),
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: tokens.border),
          bottom: BorderSide(color: tokens.border),
        ),
        color: tokens.isDarkSurface
            ? tokens.surfaceRaised
            : tokens.surfaceHover.withValues(alpha: 0.55),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontFamily: tokens.mono,
          fontSize: 8.5,
          letterSpacing: 2.0,
          fontWeight: FontWeight.w700,
          color: tokens.textMuted,
        ),
      ),
    );
  }
}

class _WbRailRule extends StatelessWidget {
  const _WbRailRule({required this.tokens});

  final MlSidebarTokens tokens;

  @override
  Widget build(BuildContext context) => Container(
        height: 1,
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        color: tokens.border,
      );
}

class _WbEmpty extends StatelessWidget {
  const _WbEmpty({required this.tokens, required this.query});

  final MlSidebarTokens tokens;
  final String query;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 26, 18, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'NO ENTRY',
            style: TextStyle(
              fontFamily: tokens.mono,
              fontSize: 9,
              letterSpacing: 2,
              fontWeight: FontWeight.w700,
              color: tokens.accent,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Nothing in the console is called "$query". Try a shorter term.',
            style: TextStyle(
              fontFamily: tokens.body,
              fontSize: 12.5,
              height: 1.45,
              color: tokens.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// The tally column — Weighbridge's signature
// ---------------------------------------------------------------------------

class _Tally extends StatelessWidget {
  const _Tally({
    required this.tokens,
    required this.count,
    required this.onInk,
  });

  final MlSidebarTokens tokens;
  final int? count;
  final bool onInk;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 30,
      child: Text(
        count == null ? '' : (count! > 999 ? '999+' : '$count'),
        textAlign: TextAlign.right,
        style: TextStyle(
          fontFamily: tokens.mono,
          fontSize: 11.5,
          height: 1,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
          fontFeatures: const [FontFeature.tabularFigures()],
          color: onInk ? _onInk(tokens) : tokens.accent,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Rows
// ---------------------------------------------------------------------------

class _WbRow extends StatelessWidget {
  const _WbRow({
    super.key,
    required this.item,
    required this.tokens,
    required this.collapsed,
    required this.expanded,
    required this.selected,
    required this.selectedId,
    required this.badges,
    required this.tally,
    required this.onSelect,
    required this.onToggle,
  });

  final MlNavItem item;
  final MlSidebarTokens tokens;
  final bool collapsed;
  final bool expanded;
  final bool selected;
  final String selectedId;
  final Map<String, int> badges;
  final int? tally;
  final ValueChanged<String> onSelect;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    if (collapsed) return _rail(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _parent(context),
        AnimatedSize(
          duration: mlMotion(context, const Duration(milliseconds: 190)),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: (item.hasChildren && expanded)
              ? _children(context)
              : const SizedBox(width: double.infinity, height: 0),
        ),
      ],
    );
  }

  Widget _parent(BuildContext context) {
    final t = tokens;
    final ink = selectedId == item.id;

    return MlRowShell(
      tokens: t,
      semanticLabel: item.label,
      borderRadius: BorderRadius.zero,
      onTap: () => item.hasChildren ? onToggle() : onSelect(item.id),
      builder: (ctx, hovered, focused) => AnimatedContainer(
        duration: mlMotion(ctx, const Duration(milliseconds: 120)),
        height: t.rowHeight,
        padding: const EdgeInsets.only(left: 18, right: 14),
        decoration: BoxDecoration(
          color: ink
              ? t.surfaceActive
              : hovered
                  ? t.surfaceHover
                  : Colors.transparent,
          border: Border(
            left: BorderSide(
              color: focused ? t.accent : Colors.transparent,
              width: 3,
            ),
          ),
        ),
        child: Row(
          children: [
            Icon(
              item.icon,
              size: 17,
              color:
                  ink ? _onInk(t) : (hovered ? t.textPrimary : t.textSecondary),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Text(
                item.label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: t.body,
                  fontSize: 13,
                  height: 1.1,
                  fontWeight: ink ? FontWeight.w700 : FontWeight.w500,
                  color: ink
                      ? _onInk(t)
                      : (hovered ? t.textPrimary : t.textSecondary),
                ),
              ),
            ),
            if (item.hasChildren) ...[
              Icon(
                expanded ? Icons.remove_rounded : Icons.add_rounded,
                size: 14,
                color: ink ? _onInk(t) : t.textMuted,
              ),
              const SizedBox(width: 8),
            ],
            _Tally(tokens: t, count: tally, onInk: ink),
          ],
        ),
      ),
    );
  }

  Widget _children(BuildContext context) {
    final t = tokens;
    return Container(
      decoration: BoxDecoration(
        color: t.isDarkSurface
            ? t.surfaceRaised
            : t.surfaceHover.withValues(alpha: 0.4),
        border: Border(
          top: BorderSide(color: t.border),
          bottom: BorderSide(color: t.border),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: item.children.map((c) {
          final ink = selectedId == c.id;
          final count = badges[c.id];
          return MlRowShell(
            tokens: t,
            semanticLabel: c.label,
            borderRadius: BorderRadius.zero,
            onTap: () => onSelect(c.id),
            builder: (ctx, hovered, focused) => AnimatedContainer(
              duration: mlMotion(ctx, const Duration(milliseconds: 120)),
              height: 36,
              padding: const EdgeInsets.only(left: 40, right: 14),
              decoration: BoxDecoration(
                color: ink
                    ? t.surfaceActive
                    : hovered
                        ? t.surfaceHover
                        : Colors.transparent,
                border: Border(
                  left: BorderSide(
                    color: focused
                        ? t.accent
                        : ink
                            ? t.accent
                            : Colors.transparent,
                    width: 3,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Icon(c.icon, size: 15, color: ink ? _onInk(t) : t.textMuted),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Text(
                      c.label,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: t.body,
                        fontSize: 12.5,
                        fontWeight: ink ? FontWeight.w700 : FontWeight.w500,
                        color: ink
                            ? _onInk(t)
                            : (hovered ? t.textPrimary : t.textSecondary),
                      ),
                    ),
                  ),
                  _Tally(tokens: t, count: count, onInk: ink),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _rail(BuildContext context) {
    final t = tokens;
    final tile = MlRowShell(
      tokens: t,
      semanticLabel: item.label,
      borderRadius: BorderRadius.zero,
      onTap: () => item.hasChildren ? onToggle() : onSelect(item.id),
      builder: (ctx, hovered, focused) => AnimatedContainer(
        duration: mlMotion(ctx, const Duration(milliseconds: 120)),
        height: 46,
        decoration: BoxDecoration(
          color: selected
              ? t.surfaceActive
              : hovered
                  ? t.surfaceHover
                  : Colors.transparent,
          border: Border(
            left: BorderSide(
              color: focused ? t.accent : Colors.transparent,
              width: 3,
            ),
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(
              item.icon,
              size: 19,
              color: selected
                  ? _onInk(t)
                  : (hovered ? t.textPrimary : t.textSecondary),
            ),
            if (tally != null)
              Positioned(
                top: 6,
                right: 8,
                child: Text(
                  tally! > 99 ? '99+' : '$tally',
                  style: TextStyle(
                    fontFamily: t.mono,
                    fontSize: 9,
                    height: 1,
                    fontWeight: FontWeight.w700,
                    fontFeatures: const [FontFeature.tabularFigures()],
                    color: selected ? _onInk(t) : t.accent,
                  ),
                ),
              ),
            if (item.hasChildren)
              Positioned(
                right: 7,
                bottom: 7,
                child: Icon(
                  Icons.more_horiz_rounded,
                  size: 11,
                  color: selected ? _onInk(t) : t.textMuted,
                ),
              ),
          ],
        ),
      ),
    );

    return MlFlyout(
      horizontalGap: 1,
      panelBuilder: (ctx) => _WbFlyout(
        item: item,
        tokens: t,
        selectedId: selectedId,
        badges: badges,
        onSelect: onSelect,
      ),
      child: tile,
    );
  }
}

class _WbFlyout extends StatelessWidget {
  const _WbFlyout({
    required this.item,
    required this.tokens,
    required this.selectedId,
    required this.badges,
    required this.onSelect,
  });

  final MlNavItem item;
  final MlSidebarTokens tokens;
  final String selectedId;
  final Map<String, int> badges;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final t = tokens;
    return Container(
      constraints: const BoxConstraints(minWidth: 232, maxWidth: 280),
      decoration: BoxDecoration(
        color: t.surfaceRaised,
        border: Border.all(color: t.border),
        boxShadow: [
          BoxShadow(
            color:
                MlTokens.overlayDark.withValues(alpha: t.isDarkSurface ? 0.5 : 0.10),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 30,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            alignment: Alignment.centerLeft,
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: t.border)),
            ),
            child: Text(
              item.label.toUpperCase(),
              style: TextStyle(
                fontFamily: t.mono,
                fontSize: 9,
                letterSpacing: 1.8,
                fontWeight: FontWeight.w700,
                color: t.textMuted,
              ),
            ),
          ),
          if (item.hasChildren)
            ...item.children.map((c) {
              final ink = selectedId == c.id;
              final count = badges[c.id];
              return MlRowShell(
                tokens: t,
                semanticLabel: c.label,
                borderRadius: BorderRadius.zero,
                onTap: () => onSelect(c.id),
                builder: (ctx, hovered, focused) => Container(
                  height: 36,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  color: ink
                      ? t.surfaceActive
                      : hovered
                          ? t.surfaceHover
                          : Colors.transparent,
                  child: Row(
                    children: [
                      Icon(c.icon,
                          size: 15, color: ink ? _onInk(t) : t.textMuted),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Text(
                          c.label,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: t.body,
                            fontSize: 12.5,
                            fontWeight: ink ? FontWeight.w700 : FontWeight.w500,
                            color: ink ? _onInk(t) : t.textSecondary,
                          ),
                        ),
                      ),
                      _Tally(tokens: t, count: count, onInk: ink),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Footer
// ---------------------------------------------------------------------------

class _WbFooter extends StatelessWidget {
  const _WbFooter({
    required this.tokens,
    required this.collapsed,
    required this.open,
    required this.selectedId,
    required this.badges,
    required this.user,
    required this.onSelect,
    required this.onToggleGroup,
    required this.onLogout,
    required this.onCollapsedChanged,
  });

  final MlSidebarTokens tokens;
  final bool collapsed;
  final Set<String> open;
  final String selectedId;
  final Map<String, int> badges;
  final MlSidebarUser user;
  final ValueChanged<String> onSelect;
  final ValueChanged<String> onToggleGroup;
  final VoidCallback? onLogout;
  final ValueChanged<bool>? onCollapsedChanged;

  @override
  Widget build(BuildContext context) {
    final t = tokens;
    return Container(
      decoration:
          BoxDecoration(border: Border(top: BorderSide(color: t.border))),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ...MlNav.footer.map(
            (item) => _WbRow(
              item: item,
              tokens: t,
              collapsed: collapsed,
              expanded: open.contains(item.id),
              selected: selectedId == item.id ||
                  item.children.any((c) => c.id == selectedId),
              selectedId: selectedId,
              badges: badges,
              tally: badges[item.id],
              onSelect: onSelect,
              onToggle: () {
                if (collapsed) onCollapsedChanged?.call(false);
                onToggleGroup(item.id);
              },
            ),
          ),
          _WbSignOut(tokens: t, collapsed: collapsed, onTap: onLogout),
          _WbUser(tokens: t, user: user, collapsed: collapsed),
        ],
      ),
    );
  }
}

class _WbSignOut extends StatelessWidget {
  const _WbSignOut({
    required this.tokens,
    required this.collapsed,
    required this.onTap,
  });

  final MlSidebarTokens tokens;
  final bool collapsed;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = tokens;
    return MlRowShell(
      tokens: t,
      semanticLabel: 'Sign out',
      borderRadius: BorderRadius.zero,
      onTap: onTap ?? () {},
      builder: (ctx, hovered, focused) => AnimatedContainer(
        duration: mlMotion(ctx, const Duration(milliseconds: 120)),
        height: 42,
        padding: EdgeInsets.only(left: collapsed ? 0 : 18, right: 14),
        alignment: collapsed ? Alignment.center : Alignment.centerLeft,
        decoration: BoxDecoration(
          color: hovered ? t.dangerBg : Colors.transparent,
          border: Border(
            top: BorderSide(color: t.border),
            left: BorderSide(
              color: focused ? t.danger : Colors.transparent,
              width: 3,
            ),
          ),
        ),
        child: Row(
          mainAxisAlignment:
              collapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
          children: [
            Icon(Icons.logout_rounded, size: 16, color: t.danger),
            if (!collapsed) ...[
              const SizedBox(width: 13),
              Text(
                'Sign out',
                style: TextStyle(
                  fontFamily: t.body,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: t.danger,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _WbUser extends StatelessWidget {
  const _WbUser({
    required this.tokens,
    required this.user,
    required this.collapsed,
  });

  final MlSidebarTokens tokens;
  final MlSidebarUser user;
  final bool collapsed;

  @override
  Widget build(BuildContext context) {
    final t = tokens;
    final avatar = Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: t.accentSoft,
            borderRadius: BorderRadius.circular(t.radius),
            border: Border.all(color: t.accent.withValues(alpha: 0.45)),
          ),
          alignment: Alignment.center,
          child: Text(
            user.initial,
            style: TextStyle(
              fontFamily: t.mono,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: t.accent,
            ),
          ),
        ),
        if (user.online)
          Positioned(
            right: -3,
            bottom: -3,
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: t.online,
                borderRadius: BorderRadius.circular(2),
                border: Border.all(color: t.surface, width: 2),
              ),
            ),
          ),
      ],
    );

    return MlSidebarUserChip(
      user: user,
      accent: t.accent,
      child: Container(
      padding: EdgeInsets.fromLTRB(collapsed ? 0 : 18, 12, 14, 14),
      decoration:
          BoxDecoration(border: Border(top: BorderSide(color: t.border))),
      child: collapsed
          ? Center(child: avatar)
          : Row(
              children: [
                avatar,
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        user.name,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: t.display,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: t.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        user.email,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: t.mono,
                          fontSize: 9.5,
                          letterSpacing: 0.2,
                          color: t.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
      ),
    );
  }
}

class _WbGhostButton extends StatelessWidget {
  const _WbGhostButton({
    required this.tokens,
    required this.icon,
    required this.onTap,
    this.tooltip,
  });

  final MlSidebarTokens tokens;
  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final t = tokens;
    final b = MlRowShell(
      tokens: t,
      semanticLabel: tooltip,
      borderRadius: BorderRadius.circular(t.radius),
      onTap: onTap,
      builder: (ctx, hovered, focused) => Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: hovered ? t.surfaceHover : Colors.transparent,
          borderRadius: BorderRadius.circular(t.radius),
          border: Border.all(color: focused ? t.accent : t.border),
        ),
        child: Icon(icon, size: 16, color: t.textSecondary),
      ),
    );
    return tooltip == null
        ? b
        : Tooltip(
            message: tooltip!,
            waitDuration: const Duration(milliseconds: 500),
            child: b,
          );
  }
}
