// ============================================================================
// MineLink — App Sidebar
// ----------------------------------------------------------------------------
// Structure and behaviour modelled on the CPS Smart Central AppSidebar, with
// the MineLink nav tree and palette. Everything from our sidebar is here:
// same items, labels, ids, badges, section groupings.
//
// Behaviour carried across from CPS:
//   • Starts collapsed; 68px rail ↔ 260px panel, 220ms easeInOutCubicEmphasized
//   • Content expansion LAGS the width animation by two-thirds of the duration,
//     so labels never paint inside a too-narrow container
//   • Auto-collapses after every navigation
//   • Forced collapsed below 768px, and the toggles hide at that size
//   • Collapsing clears every open dropdown
//   • Three expand controls (header collapse, header expand, bottom bar)
//   • Collapsed search is an icon that expands the rail, then focuses the
//     field 240ms later; a live query replaces the nav list with results
//   • Tooltips on every collapsed tile, 400ms wait
//
// One deliberate divergence: CPS dropdown parents navigate to their own screen
// when collapsed, because theirs have one. Ours don't — Insights, Tokens and
// Requests are groupings only — so a collapsed parent expands the rail and
// opens its section instead. Navigating to nothing would be a dead click.
// ============================================================================

import 'package:flutter/material.dart';

import 'minelink_sidebar_core.dart';
import '../insights_v2/minelink_screens_core.dart';
import 'package:flutter_application_1/core/design/tokens/ml_surface_tokens.dart';
import 'package:flutter_application_1/core/design/tokens/ml_tokens.dart';

/// Dimensions and timings — the CPS SidebarConstants values, unchanged.
class MlSidebarMetrics {
  const MlSidebarMetrics._();

  static const double collapsedWidth = 68;
  static const double expandedWidth = 260;

  static const Duration expandDuration = Duration(milliseconds: 220);
  static const Duration dropdownDuration = Duration(milliseconds: 180);
  static const Curve expandCurve = Curves.easeInOutCubicEmphasized;

  static const double itemRadius = 10;
  static const double itemHeight = 42;
  static const double itemGap = 2;
  static const double itemMarginH = 8;
  static const double itemPaddingH = 10;
  static const double iconSize = 20;
  static const double iconLabelGap = 12;

  static const double childIndent = 14;
  static const double childIconSize = 18;
  static const double childItemHeight = 36;

  static const double logoHeightExpanded = 86;
  static const double logoHeightCollapsed = 40;

  static const double compactBreakpoint = 768;

  /// How far the content lag trails the width animation.
  static Duration get contentLag =>
      Duration(milliseconds: expandDuration.inMilliseconds * 2 ~/ 3);
}

class MineLinkAppSidebar extends StatefulWidget {
  const MineLinkAppSidebar({
    super.key,
    required this.selectedId,
    required this.onSelect,
    this.collapsed = true,
    this.onCollapsedChanged,
    this.onLogout,
    this.badges = const <String, int>{},
    this.user = const MlSidebarUser(
      name: 'jean',
      email: 'jean@cyberhouse.co.za',
    ),
    this.brand = const MlBrand(),
    this.tokens,
    this.autoCollapseOnNavigate = true,
  });

  final String selectedId;
  final ValueChanged<String> onSelect;

  final bool collapsed;
  final ValueChanged<bool>? onCollapsedChanged;

  final VoidCallback? onLogout;
  final Map<String, int> badges;
  final MlSidebarUser user;
  final MlBrand brand;
  final MlGlass? tokens;

  /// CPS collapses the rail after every navigation. Turn off if your shell
  /// would rather keep it open.
  final bool autoCollapseOnNavigate;

  @override
  State<MineLinkAppSidebar> createState() => _MineLinkAppSidebarState();
}

class _MineLinkAppSidebarState extends State<MineLinkAppSidebar> {
  /// Lags [widget.collapsed] so expanded content only renders once the width
  /// animation has progressed far enough to fit it.
  bool _contentExpanded = false;

  final Set<String> _openSections = <String>{};
  final TextEditingController _search = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _contentExpanded = !widget.collapsed;
    if (widget.selectedId.contains('.')) {
      _openSections.add(widget.selectedId.split('.').first);
    }
  }

  @override
  void didUpdateWidget(covariant MineLinkAppSidebar old) {
    super.didUpdateWidget(old);
    if (old.collapsed != widget.collapsed) _syncContent();
  }

  @override
  void dispose() {
    _search.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _syncContent() {
    if (widget.collapsed) {
      // Collapsing: drop content immediately so nothing is clipped mid-animation.
      setState(() {
        _contentExpanded = false;
        _openSections.clear();
        _query = '';
        _search.clear();
      });
    } else {
      Future<void>.delayed(MlSidebarMetrics.contentLag, () {
        if (mounted && !widget.collapsed) {
          setState(() => _contentExpanded = true);
        }
      });
    }
  }

  void _setCollapsed(bool v) => widget.onCollapsedChanged?.call(v);
  void _toggle() => _setCollapsed(!widget.collapsed);

  void _toggleSection(String id) => setState(
      () => _openSections.contains(id) ? _openSections.remove(id) : _openSections.add(id));

  /// Navigate, then auto-collapse — the CPS behaviour.
  void _navigate(String id) {
    widget.onSelect(id);
    if (widget.autoCollapseOnNavigate && !widget.collapsed) {
      _setCollapsed(true);
    }
  }

  void _openSearch() {
    _setCollapsed(false);
    Future<void>.delayed(const Duration(milliseconds: 240), () {
      if (mounted) _searchFocus.requestFocus();
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.tokens ?? MlGlass.of(context);
    final compact =
        MediaQuery.sizeOf(context).width < MlSidebarMetrics.compactBreakpoint;

    // Width follows the raw flag; content follows the lagged one.
    final widthExpanded = compact ? false : !widget.collapsed;
    final expanded = compact ? false : _contentExpanded;
    final width = widthExpanded
        ? MlSidebarMetrics.expandedWidth
        : MlSidebarMetrics.collapsedWidth;

    final divider = t.accent.withValues(alpha: t.isDark ? 0.16 : 0.20);

    return AnimatedContainer(
      duration: mlScreenMotion(context, MlSidebarMetrics.expandDuration),
      curve: MlSidebarMetrics.expandCurve,
      width: width,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: const Alignment(-1.15, -1.05),
          end: const Alignment(1.1, 1.15),
          colors: t.isDark
              ? [t.bg0, t.panel, t.bg0]
              : [t.panel, t.bg1, t.panel],
          stops: const [0.04, 0.42, 1.0],
        ),
        border: Border(right: BorderSide(color: divider)),
      ),
      clipBehavior: Clip.hardEdge,
      child: RepaintBoundary(
        child: Column(
          children: [
            _BrandHeader(
              tokens: t,
              brand: widget.brand,
              expanded: expanded,
              compact: compact,
              onToggle: _toggle,
            ),
            const SizedBox(height: 2),
            _Rule(color: divider),
            const SizedBox(height: 4),

            // Dashboard sits above the search field, as Home does in CPS.
            _NavTile(
              tokens: t,
              icon: MlNav.dashboard.icon,
              label: MlNav.dashboard.label,
              selected: widget.selectedId == MlNav.dashboard.id,
              expanded: expanded,
              onTap: () => _navigate(MlNav.dashboard.id),
            ),

            _SearchField(
              tokens: t,
              expanded: expanded,
              controller: _search,
              focusNode: _searchFocus,
              onChanged: (v) => setState(() => _query = v),
              onExpandRequest: _openSearch,
            ),

            _Rule(color: divider),
            const SizedBox(height: 4),

            Expanded(
              child: (_query.trim().isNotEmpty && expanded)
                  ? _SearchResults(
                      tokens: t,
                      query: _query,
                      onTap: (id) {
                        _navigate(id);
                        setState(() {
                          _query = '';
                          _search.clear();
                        });
                      },
                    )
                  : ListView(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      children: _mainNav(t, expanded),
                    ),
            ),

            if (_query.trim().isEmpty) ...[
              _Rule(color: divider),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: _footerNav(t, expanded),
                ),
              ),
            ],

            _Rule(color: divider),
            _BottomBar(
              tokens: t,
              expanded: expanded,
              compact: compact,
              onToggle: _toggle,
              onLogout: widget.onLogout,
            ),
            _Rule(color: divider),
            _UserFooter(
              tokens: t,
              user: widget.user,
              expanded: expanded,
            ),
          ],
        ),
      ),
    );
  }

  // -- nav builders --------------------------------------------------------

  List<Widget> _mainNav(MlGlass t, bool expanded) {
    final out = <Widget>[];
    for (final item in MlNav.main) {
      if (item.section != null) {
        out.add(expanded
            ? _SectionLabel(tokens: t, label: item.section!)
            : _RailGap(color: t.line2));
      }
      out.add(_tileFor(t, item, expanded));
    }
    return out;
  }

  List<Widget> _footerNav(MlGlass t, bool expanded) =>
      MlNav.footer.map((i) => _tileFor(t, i, expanded)).toList();

  Widget _tileFor(MlGlass t, MlNavItem item, bool expanded) {
    if (item.hasChildren) {
      return _DropdownSection(
        tokens: t,
        item: item,
        expanded: expanded,
        open: _openSections.contains(item.id),
        selectedId: widget.selectedId,
        badges: widget.badges,
        onToggle: () {
          if (expanded) {
            _toggleSection(item.id);
          } else {
            // No parent screen to land on — open the rail and the section.
            _setCollapsed(false);
            setState(() => _openSections.add(item.id));
          }
        },
        onChildTap: _navigate,
      );
    }
    return _NavTile(
      tokens: t,
      icon: item.icon,
      label: item.label,
      selected: widget.selectedId == item.id,
      expanded: expanded,
      badge: widget.badges[item.id],
      onTap: () => _navigate(item.id),
    );
  }
}

// ===========================================================================
// Rules and labels
// ===========================================================================

class _Rule extends StatelessWidget {
  const _Rule({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) =>
      Divider(height: 1, thickness: 1, color: color);
}

class _RailGap extends StatelessWidget {
  const _RailGap({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        child: Container(height: 1, color: color),
      );
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.tokens, required this.label});

  final MlGlass tokens;
  final String label;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(18, 14, 12, 6),
        child: Text(
          label.toUpperCase(),
          style: TextStyle(
            fontFamily: MlGlass.sans,
            fontSize: 9,
            letterSpacing: 1.6,
            fontWeight: FontWeight.w600,
            color: tokens.inkLo,
          ),
        ),
      );
}

// ===========================================================================
// Brand header — control #1 (collapse) and #2 (expand)
// ===========================================================================

class _BrandHeader extends StatelessWidget {
  const _BrandHeader({
    required this.tokens,
    required this.brand,
    required this.expanded,
    required this.compact,
    required this.onToggle,
  });

  final MlGlass tokens;
  final MlBrand brand;
  final bool expanded;
  final bool compact;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: expanded
            ? const EdgeInsets.fromLTRB(14, 20, 14, 4)
            : const EdgeInsets.symmetric(vertical: 16),
        child: expanded ? _expandedHeader() : _collapsedHeader(),
      ),
    );
  }

  Widget _mark({required bool small}) {
    final t = tokens;
    final onDark = t.isDark;
    // The lockup renders at the console rail's own sizes — 92px expanded /
    // 38px collapsed (MlBrand.classicLogoHeight/classicIconSize), off the same
    // four brand files the rest of the app uses — so the brand reads
    // identically whichever sidebar is on. The drop's own 86/40 are ignored.
    // +8 leaves the 4px inset below intact so the accent glow still extends
    // past the artwork rather than cropping it.
    final h = (small ? brand.iconSize : brand.logoHeight) + 8;

    return SizedBox(
      width: small ? 52 : 156,
      height: h,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Accent glow behind the mark — the CPS radial backdrop.
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -0.08),
                  radius: small ? 0.9 : 1.05,
                  colors: [
                    t.accent.withValues(alpha: small ? 0.16 : 0.20),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(4),
            child: Image.asset(
              small
                  ? brand.icon(onDarkSurface: onDark)
                  : brand.logo(onDarkSurface: onDark),
              fit: BoxFit.contain,
              filterQuality: FilterQuality.medium,
              semanticLabel: small ? 'MineLink' : 'MineLink Technologies',
              errorBuilder: (_, __, ___) => Center(
                child: Text(
                  small ? 'ML' : 'MineLink',
                  style: TextStyle(
                    fontFamily: MlGlass.sans,
                    fontSize: small ? 15 : 24,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    color: t.inkHi,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _expandedHeader() {
    return SizedBox(
      height: 104,
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          Align(alignment: Alignment.topCenter, child: _mark(small: false)),
          if (!compact)
            Positioned(
              top: 2,
              right: 0,
              child: _ControlButton(
                tokens: tokens,
                icon: Icons.chevron_left_rounded,
                tooltip: 'Collapse sidebar',
                onTap: onToggle,
              ),
            ),
        ],
      ),
    );
  }

  Widget _collapsedHeader() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Center(child: _mark(small: true)),
        if (!compact) ...[
          const SizedBox(height: 10),
          _ControlButton(
            tokens: tokens,
            icon: Icons.chevron_right_rounded,
            tooltip: 'Expand sidebar',
            iconSize: 18,
            onTap: onToggle,
          ),
        ],
      ],
    );
  }
}

/// The bordered accent square used by controls #1 and #2.
class _ControlButton extends StatefulWidget {
  const _ControlButton({
    required this.tokens,
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.iconSize = 20,
  });

  final MlGlass tokens;
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final double iconSize;

  @override
  State<_ControlButton> createState() => _ControlButtonState();
}

class _ControlButtonState extends State<_ControlButton> {
  bool _h = false;

  @override
  Widget build(BuildContext context) {
    final t = widget.tokens;
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _h = true),
        onExit: (_) => setState(() => _h = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: mlScreenMotion(context, const Duration(milliseconds: 140)),
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: _h
                  ? t.accent.withValues(alpha: 0.16)
                  : (t.isDark ? t.panel : t.bg1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: t.accent.withValues(alpha: 0.55),
                width: 1.2,
              ),
            ),
            child: Icon(widget.icon, size: widget.iconSize, color: t.accent),
          ),
        ),
      ),
    );
  }
}

// ===========================================================================
// Search
// ===========================================================================

class _SearchField extends StatefulWidget {
  const _SearchField({
    required this.tokens,
    required this.expanded,
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onExpandRequest,
  });

  final MlGlass tokens;
  final bool expanded;
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final VoidCallback onExpandRequest;

  @override
  State<_SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<_SearchField> {
  bool _h = false;

  @override
  Widget build(BuildContext context) {
    final t = widget.tokens;

    if (!widget.expanded) {
      return Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: MlSidebarMetrics.itemMarginH, vertical: 4),
        child: Tooltip(
          message: 'Search',
          waitDuration: const Duration(milliseconds: 400),
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            onEnter: (_) => setState(() => _h = true),
            onExit: (_) => setState(() => _h = false),
            child: GestureDetector(
              onTap: widget.onExpandRequest,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                height: MlSidebarMetrics.itemHeight,
                decoration: BoxDecoration(
                  color: _h ? t.inkHi.withValues(alpha: 0.06) : Colors.transparent,
                  borderRadius:
                      BorderRadius.circular(MlSidebarMetrics.itemRadius),
                ),
                child: Icon(Icons.search_rounded,
                    size: MlSidebarMetrics.iconSize, color: t.inkMid),
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(
          MlSidebarMetrics.itemMarginH, 6, MlSidebarMetrics.itemMarginH, 6),
      child: SizedBox(
        height: 38,
        child: TextField(
          controller: widget.controller,
          focusNode: widget.focusNode,
          onChanged: widget.onChanged,
          style: TextStyle(
              fontFamily: MlGlass.sans, fontSize: 12.5, color: t.inkHi),
          cursorColor: t.accent,
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: t.inkHi.withValues(alpha: 0.04),
            hintText: 'Search the console',
            hintStyle: TextStyle(
                fontFamily: MlGlass.sans, fontSize: 12.5, color: t.inkLo),
            prefixIcon: Icon(Icons.search_rounded, size: 16, color: t.inkMid),
            prefixIconConstraints:
                const BoxConstraints(minWidth: 36, minHeight: 36),
            suffixIcon: widget.controller.text.isEmpty
                ? null
                : IconButton(
                    icon: Icon(Icons.close_rounded, size: 15, color: t.inkMid),
                    splashRadius: 13,
                    onPressed: () {
                      widget.controller.clear();
                      widget.onChanged('');
                    },
                  ),
            contentPadding: const EdgeInsets.symmetric(vertical: 9),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: t.line2),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: t.line2),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: t.accent.withValues(alpha: 0.6)),
            ),
          ),
        ),
      ),
    );
  }
}

class _SearchResults extends StatelessWidget {
  const _SearchResults({
    required this.tokens,
    required this.query,
    required this.onTap,
  });

  final MlGlass tokens;
  final String query;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    final t = tokens;
    final q = query.toLowerCase().trim();
    final hits = <MlNavItem>[];

    void walk(MlNavItem i) {
      if (i.label.toLowerCase().contains(q)) hits.add(i);
      for (final c in i.children) {
        walk(c);
      }
    }

    walk(MlNav.dashboard);
    for (final i in MlNav.main) {
      walk(i);
    }
    for (final i in MlNav.footer) {
      walk(i);
    }

    if (hits.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(18, 24, 18, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('No match',
                style: TextStyle(
                    fontFamily: MlGlass.sans,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: t.inkHi)),
            const SizedBox(height: 6),
            Text('Nothing in the console is called "$query".',
                style: TextStyle(
                    fontFamily: MlGlass.sans,
                    fontSize: 11.5,
                    height: 1.45,
                    color: t.inkMid)),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 4),
      children: hits
          .map((i) => _NavTile(
                tokens: t,
                icon: i.icon,
                label: i.label,
                selected: false,
                expanded: true,
                onTap: () => onTap(i.id),
              ))
          .toList(),
    );
  }
}

// ===========================================================================
// Tiles
// ===========================================================================

class _NavTile extends StatefulWidget {
  const _NavTile({
    required this.tokens,
    required this.icon,
    required this.label,
    required this.selected,
    required this.expanded,
    required this.onTap,
    this.badge,
  });

  final MlGlass tokens;
  final IconData icon;
  final String label;
  final bool selected;
  final bool expanded;
  final VoidCallback onTap;
  final int? badge;

  @override
  State<_NavTile> createState() => _NavTileState();
}

class _NavTileState extends State<_NavTile> {
  bool _h = false;

  @override
  Widget build(BuildContext context) {
    final t = widget.tokens;

    final body = GestureDetector(
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        height: MlSidebarMetrics.itemHeight,
        padding: widget.expanded
            ? const EdgeInsets.symmetric(
                horizontal: MlSidebarMetrics.itemPaddingH)
            : EdgeInsets.zero,
        decoration: BoxDecoration(
          color: widget.selected
              ? t.accent.withValues(alpha: 0.13)
              : _h
                  ? t.inkHi.withValues(alpha: 0.06)
                  : Colors.transparent,
          borderRadius: BorderRadius.circular(MlSidebarMetrics.itemRadius),
          border: Border.all(
            color: widget.selected
                ? t.accent.withValues(alpha: 0.32)
                : Colors.transparent,
          ),
        ),
        clipBehavior: Clip.hardEdge,
        child: Row(
          children: [
            if (!widget.expanded)
              Expanded(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Icon(widget.icon,
                        size: MlSidebarMetrics.iconSize,
                        color: widget.selected ? t.accent : t.inkMid),
                    if (widget.badge != null)
                      Positioned(
                        top: 6,
                        right: 12,
                        child: Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                              color: t.accent, shape: BoxShape.circle),
                        ),
                      ),
                  ],
                ),
              )
            else ...[
              Icon(widget.icon,
                  size: MlSidebarMetrics.iconSize,
                  color: widget.selected ? t.accent : t.inkMid),
              const SizedBox(width: MlSidebarMetrics.iconLabelGap),
              Expanded(
                child: Text(
                  widget.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: MlGlass.sans,
                    fontSize: 13,
                    letterSpacing: -0.1,
                    fontWeight:
                        widget.selected ? FontWeight.w600 : FontWeight.w400,
                    color: widget.selected
                        ? t.inkHi
                        : t.inkHi.withValues(alpha: 0.82),
                  ),
                ),
              ),
              if (widget.badge != null) _Badge(tokens: t, count: widget.badge!),
            ],
          ],
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: MlSidebarMetrics.itemMarginH,
        vertical: MlSidebarMetrics.itemGap,
      ),
      child: MouseRegion(
        onEnter: (_) => setState(() => _h = true),
        onExit: (_) => setState(() => _h = false),
        child: widget.expanded
            ? body
            : Tooltip(
                message: widget.label,
                waitDuration: const Duration(milliseconds: 400),
                child: body,
              ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.tokens, required this.count});

  final MlGlass tokens;
  final int count;

  @override
  Widget build(BuildContext context) {
    final t = tokens;
    return Container(
      constraints: const BoxConstraints(minWidth: 22),
      height: 18,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: t.accent.withValues(alpha: 0.16),
        border: Border.all(color: t.accent.withValues(alpha: 0.35)),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        style: TextStyle(
          fontFamily: MlGlass.mono,
          fontSize: 10,
          height: 1,
          fontWeight: FontWeight.w700,
          color: t.accent2,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

// ===========================================================================
// Dropdown section
// ===========================================================================

class _DropdownSection extends StatefulWidget {
  const _DropdownSection({
    required this.tokens,
    required this.item,
    required this.expanded,
    required this.open,
    required this.selectedId,
    required this.badges,
    required this.onToggle,
    required this.onChildTap,
  });

  final MlGlass tokens;
  final MlNavItem item;
  final bool expanded;
  final bool open;
  final String selectedId;
  final Map<String, int> badges;
  final VoidCallback onToggle;
  final ValueChanged<String> onChildTap;

  @override
  State<_DropdownSection> createState() => _DropdownSectionState();
}

class _DropdownSectionState extends State<_DropdownSection> {
  bool _h = false;

  @override
  Widget build(BuildContext context) {
    final t = widget.tokens;
    final item = widget.item;
    final childSelected =
        item.children.any((c) => c.id == widget.selectedId);
    final active = widget.selectedId == item.id || childSelected;
    final badge = widget.badges[item.id];

    final parent = GestureDetector(
      onTap: widget.onToggle,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        height: MlSidebarMetrics.itemHeight,
        padding: EdgeInsets.symmetric(
            horizontal:
                widget.expanded ? MlSidebarMetrics.itemPaddingH : 0),
        decoration: BoxDecoration(
          color: active
              ? t.accent.withValues(alpha: 0.13)
              : _h
                  ? t.inkHi.withValues(alpha: 0.06)
                  : Colors.transparent,
          borderRadius: BorderRadius.circular(MlSidebarMetrics.itemRadius),
          border: Border.all(
            color: active ? t.accent.withValues(alpha: 0.32) : Colors.transparent,
          ),
        ),
        clipBehavior: Clip.hardEdge,
        child: Row(
          children: [
            if (!widget.expanded)
              Expanded(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Icon(item.icon,
                        size: MlSidebarMetrics.iconSize,
                        color: active ? t.accent : t.inkMid),
                    if (badge != null)
                      Positioned(
                        top: 6,
                        right: 12,
                        child: Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                              color: t.accent, shape: BoxShape.circle),
                        ),
                      ),
                    Positioned(
                      right: 5,
                      bottom: 6,
                      child: Icon(Icons.chevron_right_rounded,
                          size: 11, color: t.inkLo),
                    ),
                  ],
                ),
              )
            else ...[
              Icon(item.icon,
                  size: MlSidebarMetrics.iconSize,
                  color: active ? t.accent : t.inkMid),
              const SizedBox(width: MlSidebarMetrics.iconLabelGap),
              Expanded(
                child: Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: MlGlass.sans,
                    fontSize: 13,
                    letterSpacing: -0.1,
                    fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                    color: t.inkHi,
                  ),
                ),
              ),
              if (badge != null) ...[
                _Badge(tokens: t, count: badge),
                const SizedBox(width: 6),
              ],
              AnimatedRotation(
                turns: widget.open ? 0.5 : 0.0,
                duration: mlScreenMotion(context, MlSidebarMetrics.dropdownDuration),
                child:
                    Icon(Icons.expand_more_rounded, size: 18, color: t.accent),
              ),
              const SizedBox(width: 2),
            ],
          ],
        ),
      ),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: MlSidebarMetrics.itemMarginH,
            vertical: MlSidebarMetrics.itemGap,
          ),
          child: MouseRegion(
            onEnter: (_) => setState(() => _h = true),
            onExit: (_) => setState(() => _h = false),
            child: widget.expanded
                ? parent
                : Tooltip(
                    message: item.label,
                    waitDuration: const Duration(milliseconds: 400),
                    child: parent,
                  ),
          ),
        ),
        if (widget.expanded)
          ClipRect(
            child: AnimatedSize(
              duration: mlScreenMotion(context, MlSidebarMetrics.dropdownDuration),
              curve: Curves.easeInOutCubic,
              alignment: Alignment.topCenter,
              child: widget.open
                  ? Padding(
                      padding: const EdgeInsets.only(
                        left: MlSidebarMetrics.itemMarginH +
                            MlSidebarMetrics.childIndent,
                        right: MlSidebarMetrics.itemMarginH,
                        bottom: 4,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: item.children
                            .map((c) => _ChildTile(
                                  tokens: t,
                                  item: c,
                                  selected: widget.selectedId == c.id,
                                  badge: widget.badges[c.id],
                                  onTap: () => widget.onChildTap(c.id),
                                ))
                            .toList(),
                      ),
                    )
                  : const SizedBox(width: double.infinity, height: 0),
            ),
          ),
      ],
    );
  }
}

class _ChildTile extends StatefulWidget {
  const _ChildTile({
    required this.tokens,
    required this.item,
    required this.selected,
    required this.onTap,
    this.badge,
  });

  final MlGlass tokens;
  final MlNavItem item;
  final bool selected;
  final VoidCallback onTap;
  final int? badge;

  @override
  State<_ChildTile> createState() => _ChildTileState();
}

class _ChildTileState extends State<_ChildTile> {
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
          height: MlSidebarMetrics.childItemHeight,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: widget.selected
                ? t.accent.withValues(alpha: 0.13)
                : _h
                    ? t.inkHi.withValues(alpha: 0.06)
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          clipBehavior: Clip.hardEdge,
          child: Row(
            children: [
              Icon(widget.item.icon,
                  size: MlSidebarMetrics.childIconSize,
                  color: widget.selected
                      ? t.accent
                      : t.inkMid.withValues(alpha: 0.75)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: MlGlass.sans,
                    fontSize: 12,
                    fontWeight:
                        widget.selected ? FontWeight.w600 : FontWeight.w400,
                    color: (widget.selected || _h)
                        ? t.inkHi
                        : t.inkHi.withValues(alpha: 0.65),
                  ),
                ),
              ),
              if (widget.badge != null)
                _Badge(tokens: t, count: widget.badge!),
            ],
          ),
        ),
      ),
    );
  }
}

// ===========================================================================
// Bottom bar — sign out + control #3
// ===========================================================================

class _BottomBar extends StatefulWidget {
  const _BottomBar({
    required this.tokens,
    required this.expanded,
    required this.compact,
    required this.onToggle,
    this.onLogout,
  });

  final MlGlass tokens;
  final bool expanded;
  final bool compact;
  final VoidCallback onToggle;
  final VoidCallback? onLogout;

  @override
  State<_BottomBar> createState() => _BottomBarState();
}

class _BottomBarState extends State<_BottomBar> {
  bool _hLogout = false;
  bool _hToggle = false;

  @override
  Widget build(BuildContext context) {
    final t = widget.tokens;
    final danger = t.bad;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          MouseRegion(
            cursor: SystemMouseCursors.click,
            onEnter: (_) => setState(() => _hLogout = true),
            onExit: (_) => setState(() => _hLogout = false),
            child: GestureDetector(
              onTap: widget.onLogout,
              child: AnimatedContainer(
                duration: mlScreenMotion(context, const Duration(milliseconds: 140)),
                width: double.infinity,
                height: 36,
                decoration: BoxDecoration(
                  color: danger.withValues(alpha: _hLogout ? 0.18 : 0.10),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: danger.withValues(alpha: 0.38)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.logout_rounded, size: 16, color: danger),
                    if (widget.expanded) ...[
                      const SizedBox(width: 8),
                      Text('Sign out',
                          style: TextStyle(
                            fontFamily: MlGlass.sans,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: danger,
                          )),
                    ],
                  ],
                ),
              ),
            ),
          ),
          if (!widget.compact) ...[
            const SizedBox(height: 6),
            MouseRegion(
              cursor: SystemMouseCursors.click,
              onEnter: (_) => setState(() => _hToggle = true),
              onExit: (_) => setState(() => _hToggle = false),
              child: GestureDetector(
                onTap: widget.onToggle,
                child: AnimatedContainer(
                  duration: mlScreenMotion(context, const Duration(milliseconds: 140)),
                  width: double.infinity,
                  height: 30,
                  decoration: BoxDecoration(
                    color: _hToggle
                        ? t.accent.withValues(alpha: 0.14)
                        : (t.isDark ? t.panel : t.bg1),
                    borderRadius: BorderRadius.circular(7),
                    border: Border.all(
                        color: t.accent.withValues(alpha: 0.55), width: 1.2),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AnimatedRotation(
                        turns: widget.expanded ? 0.0 : 0.5,
                        duration: mlScreenMotion(context, MlSidebarMetrics.expandDuration),
                        child: Icon(Icons.chevron_left_rounded,
                            size: 18, color: t.accent),
                      ),
                      if (widget.expanded) ...[
                        const SizedBox(width: 4),
                        Text('Collapse',
                            style: TextStyle(
                                fontFamily: MlGlass.sans,
                                fontSize: 11,
                                color: t.accent)),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ===========================================================================
// User footer
// ===========================================================================

class _UserFooter extends StatelessWidget {
  const _UserFooter({
    required this.tokens,
    required this.user,
    required this.expanded,
  });

  final MlGlass tokens;
  final MlSidebarUser user;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final t = tokens;

    final avatar = Container(
      width: expanded ? 32 : 36,
      height: expanded ? 32 : 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [t.accent, t.accent.withValues(alpha: 0.55)],
        ),
      ),
      child: Text(
        user.initial,
        style: TextStyle(
          fontFamily: MlGlass.sans,
          fontSize: expanded ? 13 : 14,
          fontWeight: FontWeight.w800,
          color: t.isDark ? MlTokens.inkOnAccent : MlTokens.inkOnFill,
        ),
      ),
    );

    return MlSidebarUserChip(
      user: user,
      accent: t.accent,
      child: Padding(
        padding:
            EdgeInsets.symmetric(horizontal: expanded ? 14 : 0, vertical: 10),
        child: expanded
          ? Row(
              children: [
                avatar,
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(user.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: MlGlass.sans,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            height: 1.2,
                            color: t.inkHi,
                          )),
                      const SizedBox(height: 2),
                      Text(user.email,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: MlGlass.mono,
                            fontSize: 9.5,
                            color: t.inkLo,
                          )),
                    ],
                  ),
                ),
                if (user.online)
                  Container(
                    width: 8,
                    height: 8,
                    decoration:
                        BoxDecoration(color: t.good, shape: BoxShape.circle),
                  ),
              ],
            )
          : Center(
              child: Tooltip(
                message: user.name,
                child: avatar,
              ),
            ),
      ),
    );
  }
}
