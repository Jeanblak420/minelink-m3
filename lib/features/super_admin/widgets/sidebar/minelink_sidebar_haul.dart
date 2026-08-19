// ============================================================================
// VERSION 2 — "HAUL"
// ----------------------------------------------------------------------------
// Brand-forward. Cyan is the default accent of every admin console on earth;
// the MineLink logo's second colour is gold, so this one runs on gold over
// graphite.
//
// Two signatures:
//   1. The rail detaches — collapsed, the sidebar becomes a floating capsule
//      that hovers over the page rather than a wall bolted to its edge.
//   2. Submenus hang from a chain thread, drawn link by link, lifted straight
//      off the MineLink mark.
//
// NOTE on the light theme: INTEGRATION.md's comparison table claims Haul
// "stays dark-panelled" in light mode. The shipped Dart it was written for
// does not — `HaulTokens.light` is a warm-paper palette and the skin picks it
// up from `Theme.of(context).brightness`, same as Weighbridge. The code is
// vendored here as delivered (both token sets live, sidebar follows the
// console's light/dark preference); the doc's prose is the thing that's out of
// date, not this file. Flip `tokens:` to `HaulTokens.dark` at the call site if
// the always-graphite reading is what's wanted.
//
// Vendored from the design drop; `MlTokens` renamed to `MlSidebarTokens` and
// `withOpacity` → `withValues` for this repo. See the core file's header.
// ============================================================================

import 'package:flutter/material.dart';

// HaulTokens moved to the design-token layer at S5-19 — it is a palette table,
// not a screen. Re-exported so existing imports still resolve it.
export 'package:flutter_application_1/core/design/tokens/ml_sidebar_skin_palettes.dart';
import 'package:flutter_application_1/core/design/tokens/ml_sidebar_skin_palettes.dart';

import 'minelink_sidebar_core.dart';
import 'package:flutter_application_1/core/design/tokens/ml_tokens.dart';

class HaulSidebar extends StatefulWidget {
  const HaulSidebar({
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
  State<HaulSidebar> createState() => _HaulSidebarState();
}

class _HaulSidebarState extends State<HaulSidebar> {
  final Set<String> _open = <String>{};
  final TextEditingController _search = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _openAncestorsOf(widget.selectedId);
  }

  @override
  void didUpdateWidget(covariant HaulSidebar old) {
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
          ? HaulTokens.dark
          : HaulTokens.light);

  void _toggle(String id) =>
      setState(() => _open.contains(id) ? _open.remove(id) : _open.add(id));

  List<MlNavItem> _visible(List<MlNavItem> src) {
    if (_query.trim().isEmpty) return src;
    return src.map((i) => i.filtered(_query)).whereType<MlNavItem>().toList();
  }

  @override
  Widget build(BuildContext context) {
    final t = _t;
    final collapsed = widget.collapsed;

    // The detached capsule: margin + full rounding when collapsed, flush to
    // the page edge when expanded.
    return AnimatedContainer(
      duration: mlMotion(context, const Duration(milliseconds: 280)),
      curve: Curves.easeOutCubic,
      width: collapsed ? t.railWidth + 20 : t.expandedWidth,
      padding: EdgeInsets.all(collapsed ? 10 : 0),
      child: AnimatedContainer(
        duration: mlMotion(context, const Duration(milliseconds: 280)),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: BorderRadius.circular(collapsed ? 26 : 0),
          border: Border.all(
            color: collapsed ? t.border : Colors.transparent,
          ),
          boxShadow: collapsed
              ? [
                  BoxShadow(
                    color: MlTokens.overlayDark
                        .withValues(alpha: t.isDarkSurface ? 0.55 : 0.10),
                    blurRadius: 30,
                    offset: const Offset(0, 10),
                  ),
                ]
              : null,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(collapsed ? 26 : 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _HaulHeader(
                tokens: t,
                brand: widget.brand,
                collapsed: collapsed,
                onToggle: () => widget.onCollapsedChanged?.call(!collapsed),
              ),
              if (widget.showSearch)
                _HaulSearch(
                  tokens: t,
                  collapsed: collapsed,
                  controller: _search,
                  onChanged: (v) => setState(() => _query = v),
                  onExpandRequest: () => widget.onCollapsedChanged?.call(false),
                ),
              Expanded(
                child: ScrollConfiguration(
                  behavior: ScrollConfiguration.of(context)
                      .copyWith(scrollbars: false),
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(
                        collapsed ? 9 : 13, 8, collapsed ? 9 : 13, 16),
                    children: _nav(t, collapsed),
                  ),
                ),
              ),
              _HaulFooter(
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
      ),
    );
  }

  List<Widget> _nav(MlSidebarTokens t, bool collapsed) {
    final out = <Widget>[_row(t, MlNav.dashboard, collapsed)];
    for (final item in _visible(MlNav.main)) {
      if (item.section != null) {
        out.add(collapsed
            ? _HaulRailDivider(tokens: t)
            : _HaulEyebrow(label: item.section!, tokens: t));
      }
      out.add(_row(t, item, collapsed));
    }
    if (_query.trim().isNotEmpty && _visible(MlNav.main).isEmpty) {
      out.add(_HaulEmpty(tokens: t, query: _query));
    }
    return out;
  }

  Widget _row(MlSidebarTokens t, MlNavItem item, bool collapsed) => _HaulRow(
        key: ValueKey(item.id),
        item: item,
        tokens: t,
        collapsed: collapsed,
        expanded: _open.contains(item.id),
        selectedId: widget.selectedId,
        selected: widget.selectedId == item.id ||
            item.children.any((c) => c.id == widget.selectedId),
        badges: widget.badges,
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
// Header — the console label uses the logo's own rule-word-rule device
// ---------------------------------------------------------------------------

class _HaulHeader extends StatelessWidget {
  const _HaulHeader({
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
    return Padding(
      padding: EdgeInsets.fromLTRB(
          collapsed ? 9 : 16, collapsed ? 14 : 16, collapsed ? 9 : 12, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: collapsed ? Alignment.center : Alignment.centerRight,
            child: _HaulIconButton(
              tokens: t,
              icon: collapsed
                  ? Icons.keyboard_double_arrow_right_rounded
                  : Icons.keyboard_double_arrow_left_rounded,
              tooltip: collapsed ? 'Expand sidebar' : 'Collapse sidebar',
              onTap: onToggle,
            ),
          ),
          // Brand lockup at the classic rail's size and placement — centred,
          // 92px expanded / 38px collapsed (see MlBrand.classicLogoHeight).
          SizedBox(height: collapsed ? 12 : 8),
          Center(
            child: Image.asset(
              collapsed
                  ? brand.icon(onDarkSurface: t.isDarkSurface)
                  : brand.logo(onDarkSurface: t.isDarkSurface),
              height: collapsed ? brand.iconSize : brand.logoHeight,
              width: collapsed ? brand.iconSize : null,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.medium,
              semanticLabel: 'MineLink Technologies',
              errorBuilder: (_, __, ___) => SizedBox(
                height: collapsed ? brand.iconSize : brand.logoHeight,
                child: Center(
                  child: Text(
                    collapsed ? 'ML' : 'MineLink',
                    style: TextStyle(
                      fontFamily: t.display,
                      fontSize: collapsed ? 16 : 26,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.6,
                      color: t.textPrimary,
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (!collapsed && brand.consoleLabel.isNotEmpty) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(child: _rule(t)),
                const SizedBox(width: 9),
                Text(
                  brand.consoleLabel,
                  style: TextStyle(
                    fontFamily: t.mono,
                    fontSize: 8.5,
                    letterSpacing: 1.6,
                    fontWeight: FontWeight.w700,
                    color: t.textSecondary,
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(child: _rule(t)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _rule(MlSidebarTokens t) => Container(
        height: 2,
        decoration: BoxDecoration(
          color: t.accent,
          borderRadius: BorderRadius.circular(1),
        ),
      );
}

// ---------------------------------------------------------------------------
// Search — pill
// ---------------------------------------------------------------------------

class _HaulSearch extends StatelessWidget {
  const _HaulSearch({
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
      return Padding(
        padding: const EdgeInsets.fromLTRB(9, 0, 9, 4),
        child: Center(
          child: _HaulIconButton(
            tokens: t,
            icon: Icons.search_rounded,
            tooltip: 'Search the console',
            onTap: onExpandRequest,
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(13, 0, 13, 6),
      child: SizedBox(
        height: 42,
        child: TextField(
          controller: controller,
          onChanged: onChanged,
          style:
              TextStyle(fontFamily: t.body, fontSize: 13, color: t.textPrimary),
          cursorColor: t.accent,
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: t.surfaceRaised,
            hintText: 'Search the console',
            hintStyle:
                TextStyle(fontFamily: t.body, fontSize: 13, color: t.textMuted),
            prefixIcon: Icon(Icons.search_rounded, size: 17, color: t.textMuted),
            prefixIconConstraints:
                const BoxConstraints(minWidth: 40, minHeight: 40),
            contentPadding: const EdgeInsets.symmetric(vertical: 11),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(21),
              borderSide: BorderSide(color: t.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(21),
              borderSide: BorderSide(color: t.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(21),
              borderSide: BorderSide(color: t.accent, width: 1.4),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Section markers
// ---------------------------------------------------------------------------

class _HaulEyebrow extends StatelessWidget {
  const _HaulEyebrow({required this.label, required this.tokens});

  final String label;
  final MlSidebarTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 20, 10, 9),
      child: Row(
        children: [
          Container(
            width: 5,
            height: 5,
            decoration:
                BoxDecoration(color: tokens.accent, shape: BoxShape.circle),
          ),
          const SizedBox(width: 9),
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontFamily: tokens.mono,
              fontSize: 9,
              letterSpacing: 2.0,
              fontWeight: FontWeight.w700,
              color: tokens.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _HaulRailDivider extends StatelessWidget {
  const _HaulRailDivider({required this.tokens});

  final MlSidebarTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Center(
        child: Container(
          width: 18,
          height: 2,
          decoration: BoxDecoration(
            color: tokens.border,
            borderRadius: BorderRadius.circular(1),
          ),
        ),
      ),
    );
  }
}

class _HaulEmpty extends StatelessWidget {
  const _HaulEmpty({required this.tokens, required this.query});

  final MlSidebarTokens tokens;
  final String query;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 28, 14, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'No match',
            style: TextStyle(
              fontFamily: tokens.display,
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: tokens.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
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
// Chain thread — Haul's submenu connector
// ---------------------------------------------------------------------------

class _ChainThreadPainter extends CustomPainter {
  const _ChainThreadPainter({required this.color, required this.accent});

  final Color color;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = color;

    const linkH = 11.0;
    const gap = 5.0;
    double y = 0;
    var i = 0;
    while (y < size.height) {
      final h = (y + linkH > size.height) ? size.height - y : linkH;
      if (h <= 2) break;
      paint.color = i.isEven ? color : accent;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(size.width / 2 - 2.5, y, 5, h),
          const Radius.circular(2.5),
        ),
        paint,
      );
      y += linkH + gap;
      i++;
    }
  }

  @override
  bool shouldRepaint(covariant _ChainThreadPainter old) =>
      old.color != color || old.accent != accent;
}

// ---------------------------------------------------------------------------
// Rows
// ---------------------------------------------------------------------------

class _HaulRow extends StatelessWidget {
  const _HaulRow({
    super.key,
    required this.item,
    required this.tokens,
    required this.collapsed,
    required this.expanded,
    required this.selected,
    required this.selectedId,
    required this.badges,
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
          duration: mlMotion(context, const Duration(milliseconds: 210)),
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
    final active = selectedId == item.id;
    final count = badges[item.id];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.5),
      child: MlRowShell(
        tokens: t,
        semanticLabel: item.label,
        borderRadius: BorderRadius.circular(t.radius),
        onTap: () => item.hasChildren ? onToggle() : onSelect(item.id),
        builder: (ctx, hovered, focused) {
          return AnimatedContainer(
            duration: mlMotion(ctx, const Duration(milliseconds: 150)),
            height: t.rowHeight,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: active
                  ? t.surfaceActive
                  : hovered
                      ? t.surfaceHover
                      : Colors.transparent,
              borderRadius: BorderRadius.circular(t.radius),
              border: Border.all(
                color: focused
                    ? t.accent
                    : active
                        ? t.accent.withValues(alpha: 0.30)
                        : Colors.transparent,
                width: focused ? 1.6 : 1,
              ),
            ),
            child: Row(
              children: [
                _IconChip(
                  tokens: t,
                  icon: item.icon,
                  active: active,
                  hovered: hovered,
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Text(
                    item.label,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: t.body,
                      fontSize: 13.5,
                      height: 1.1,
                      letterSpacing: -0.1,
                      fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                      color: active
                          ? t.textPrimary
                          : hovered
                              ? t.textPrimary
                              : t.textSecondary,
                    ),
                  ),
                ),
                if (count != null) ...[
                  const SizedBox(width: 8),
                  MlBadge(count: count, tokens: t),
                ],
                if (item.hasChildren) ...[
                  const SizedBox(width: 4),
                  AnimatedRotation(
                    turns: expanded ? 0.5 : 0,
                    duration: mlMotion(ctx, const Duration(milliseconds: 210)),
                    child: Icon(Icons.expand_more_rounded,
                        size: 18, color: t.textMuted),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _children(BuildContext context) {
    final t = tokens;
    return Padding(
      padding: const EdgeInsets.only(top: 3, bottom: 6),
      child: Stack(
        children: [
          Positioned(
            left: 18,
            top: 2,
            bottom: 10,
            width: 12,
            child: CustomPaint(
              painter: _ChainThreadPainter(
                color: t.border,
                accent: t.accent.withValues(alpha: 0.55),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: item.children.map((c) {
              final active = selectedId == c.id;
              final count = badges[c.id];
              return Padding(
                padding: const EdgeInsets.only(left: 34, bottom: 2),
                child: MlRowShell(
                  tokens: t,
                  semanticLabel: c.label,
                  borderRadius: BorderRadius.circular(t.radius - 3),
                  onTap: () => onSelect(c.id),
                  builder: (ctx, hovered, focused) => AnimatedContainer(
                    duration: mlMotion(ctx, const Duration(milliseconds: 150)),
                    height: 38,
                    padding: const EdgeInsets.symmetric(horizontal: 11),
                    decoration: BoxDecoration(
                      color: active
                          ? t.surfaceActive
                          : hovered
                              ? t.surfaceHover
                              : Colors.transparent,
                      borderRadius: BorderRadius.circular(t.radius - 3),
                      border: Border.all(
                        color: focused ? t.accent : Colors.transparent,
                        width: 1.4,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(c.icon,
                            size: 16, color: active ? t.accent : t.textMuted),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            c.label,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: t.body,
                              fontSize: 12.6,
                              fontWeight:
                                  active ? FontWeight.w700 : FontWeight.w500,
                              color: active || hovered
                                  ? t.textPrimary
                                  : t.textSecondary,
                            ),
                          ),
                        ),
                        if (count != null) ...[
                          const SizedBox(width: 6),
                          MlBadge(count: count, tokens: t),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _rail(BuildContext context) {
    final t = tokens;
    final count = badges[item.id];

    final tile = Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: MlRowShell(
        tokens: t,
        semanticLabel: item.label,
        borderRadius: BorderRadius.circular(t.radius + 2),
        onTap: () => item.hasChildren ? onToggle() : onSelect(item.id),
        builder: (ctx, hovered, focused) => AnimatedContainer(
          duration: mlMotion(ctx, const Duration(milliseconds: 150)),
          height: 46,
          decoration: BoxDecoration(
            color: selected
                ? t.accent
                : hovered
                    ? t.surfaceHover
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(t.radius + 2),
            border: Border.all(
              color: focused ? t.accent : Colors.transparent,
              width: 1.6,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: t.accent.withValues(alpha: 0.30),
                      blurRadius: 16,
                      spreadRadius: -2,
                    ),
                  ]
                : null,
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(
                item.icon,
                size: 21,
                color: selected
                    ? t.onAccent
                    : hovered
                        ? t.textPrimary
                        : t.textSecondary,
              ),
              if (count != null)
                Positioned(
                  top: 8,
                  right: 12,
                  child: MlBadge(
                    count: count,
                    tokens: t,
                    compact: true,
                    background: selected ? t.onAccent : t.accent,
                  ),
                ),
              if (item.hasChildren)
                Positioned(
                  right: 6,
                  bottom: 7,
                  child: Container(
                    width: 4,
                    height: 4,
                    decoration: BoxDecoration(
                      color: selected ? t.onAccent : t.textMuted,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );

    return MlFlyout(
      horizontalGap: 16,
      panelBuilder: (ctx) => _HaulFlyout(
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

class _IconChip extends StatelessWidget {
  const _IconChip({
    required this.tokens,
    required this.icon,
    required this.active,
    required this.hovered,
  });

  final MlSidebarTokens tokens;
  final IconData icon;
  final bool active;
  final bool hovered;

  @override
  Widget build(BuildContext context) {
    final t = tokens;
    return AnimatedContainer(
      duration: mlMotion(context, const Duration(milliseconds: 150)),
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        color: active ? t.accent : Colors.transparent,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Icon(
        icon,
        size: 18,
        color: active
            ? t.onAccent
            : hovered
                ? t.textPrimary
                : t.textSecondary,
      ),
    );
  }
}

class _HaulFlyout extends StatelessWidget {
  const _HaulFlyout({
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
      constraints: const BoxConstraints(minWidth: 216, maxWidth: 268),
      padding: const EdgeInsets.all(7),
      decoration: BoxDecoration(
        color: t.surfaceRaised,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: t.border),
        boxShadow: [
          BoxShadow(
            color:
                MlTokens.overlayDark.withValues(alpha: t.isDarkSurface ? 0.55 : 0.12),
            blurRadius: 28,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(11, 9, 11, 9),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 4,
                  decoration:
                      BoxDecoration(color: t.accent, shape: BoxShape.circle),
                ),
                const SizedBox(width: 9),
                Flexible(
                  child: Text(
                    item.label,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: t.display,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.2,
                      color: t.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (item.hasChildren)
            ...item.children.map((c) {
              final active = selectedId == c.id;
              final count = badges[c.id];
              return MlRowShell(
                tokens: t,
                semanticLabel: c.label,
                borderRadius: BorderRadius.circular(11),
                onTap: () => onSelect(c.id),
                builder: (ctx, hovered, focused) => Container(
                  height: 36,
                  padding: const EdgeInsets.symmetric(horizontal: 11),
                  decoration: BoxDecoration(
                    color: active
                        ? t.surfaceActive
                        : hovered
                            ? t.surfaceHover
                            : Colors.transparent,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Row(
                    children: [
                      Icon(c.icon,
                          size: 16, color: active ? t.accent : t.textMuted),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          c.label,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: t.body,
                            fontSize: 12.5,
                            fontWeight:
                                active ? FontWeight.w700 : FontWeight.w500,
                            color: active ? t.textPrimary : t.textSecondary,
                          ),
                        ),
                      ),
                      if (count != null) ...[
                        const SizedBox(width: 6),
                        MlBadge(count: count, tokens: t),
                      ],
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

class _HaulFooter extends StatelessWidget {
  const _HaulFooter({
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
      padding:
          EdgeInsets.fromLTRB(collapsed ? 9 : 13, 8, collapsed ? 9 : 13, 6),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: t.border)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ...MlNav.footer.map(
            (item) => _HaulRow(
              item: item,
              tokens: t,
              collapsed: collapsed,
              expanded: open.contains(item.id),
              selected: selectedId == item.id ||
                  item.children.any((c) => c.id == selectedId),
              selectedId: selectedId,
              badges: badges,
              onSelect: onSelect,
              onToggle: () {
                if (collapsed) onCollapsedChanged?.call(false);
                onToggleGroup(item.id);
              },
            ),
          ),
          const SizedBox(height: 10),
          _HaulSignOut(tokens: t, collapsed: collapsed, onTap: onLogout),
          const SizedBox(height: 10),
          _HaulUser(tokens: t, user: user, collapsed: collapsed),
        ],
      ),
    );
  }
}

class _HaulSignOut extends StatelessWidget {
  const _HaulSignOut({
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
      borderRadius: BorderRadius.circular(t.radius + 2),
      onTap: onTap ?? () {},
      builder: (ctx, hovered, focused) => AnimatedContainer(
        duration: mlMotion(ctx, const Duration(milliseconds: 150)),
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: hovered ? t.danger.withValues(alpha: 0.15) : t.dangerBg,
          borderRadius: BorderRadius.circular(t.radius + 2),
          border: Border.all(
            color: focused ? t.danger : t.danger.withValues(alpha: 0.35),
            width: focused ? 1.6 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.logout_rounded, size: 18, color: t.danger),
            if (!collapsed) ...[
              const SizedBox(width: 10),
              Text(
                'Sign out',
                style: TextStyle(
                  fontFamily: t.body,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
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

class _HaulUser extends StatelessWidget {
  const _HaulUser({
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
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [t.accent, t.accent.withValues(alpha: 0.55)],
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            user.initial,
            style: TextStyle(
              fontFamily: t.display,
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: t.onAccent,
            ),
          ),
        ),
        if (user.online)
          Positioned(
            right: -2,
            bottom: -2,
            child: Container(
              width: 11,
              height: 11,
              decoration: BoxDecoration(
                color: t.online,
                shape: BoxShape.circle,
                border: Border.all(color: t.surface, width: 2),
              ),
            ),
          ),
      ],
    );

    if (collapsed) {
      return MlSidebarUserChip(
        user: user,
        accent: t.accent,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Center(child: avatar),
        ),
      );
    }

    return MlSidebarUserChip(
      user: user,
      accent: t.accent,
      child: Container(
      padding: const EdgeInsets.fromLTRB(9, 9, 9, 9),
      decoration: BoxDecoration(
        color: t.surfaceRaised,
        borderRadius: BorderRadius.circular(t.radius + 2),
        border: Border.all(color: t.border),
      ),
      child: Row(
        children: [
          avatar,
          const SizedBox(width: 11),
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
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: t.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  user.email,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: t.mono,
                    fontSize: 10,
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

class _HaulIconButton extends StatelessWidget {
  const _HaulIconButton({
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
      borderRadius: BorderRadius.circular(11),
      onTap: onTap,
      builder: (ctx, hovered, focused) => AnimatedContainer(
        duration: mlMotion(ctx, const Duration(milliseconds: 130)),
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: hovered ? t.surfaceHover : t.surfaceRaised,
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: focused ? t.accent : t.border),
        ),
        child: Icon(icon, size: 17, color: t.textSecondary),
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
