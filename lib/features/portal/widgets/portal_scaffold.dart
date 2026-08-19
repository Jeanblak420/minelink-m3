import 'package:flutter/material.dart';
import 'package:flutter_application_1/core/layout/app_breakpoints.dart';
import 'package:flutter_application_1/core/design/tokens/ml_tokens.dart';
import 'package:flutter_application_1/core/utils/image_provider_utils.dart';
import 'package:flutter_application_1/core/widgets/user_identity_flyout.dart';
import 'package:flutter_application_1/features/portal/nav/portal_nav.dart';
import 'package:flutter_application_1/core/design/tokens/ml_mine_premium_theme.dart';
import 'package:flutter_application_1/core/design/tokens/ml_rail_tokens.dart';

/// Responsive MineLink portal chrome: persistent navy-gradient sidebar (wide),
/// drawer (narrow). Ported from `ui_kits/shared/shell.jsx` — gradient rail,
/// serif gradient wordmark, sidebar search, blue-tinted active tiles,
/// utility/settings groups, orange logout, user card.
class PortalScaffold extends StatelessWidget {
  static const double sidebarBreakpoint = AppBreakpoints.sidebarBreakpoint;
  static const double _sidebarWidthExpanded = MlTokens.sidebarWidth;
  static const double _sidebarWidthCollapsed = MlTokens.sidebarWidthCollapsed;

  /// Minimum inner width before showing labels (avoids overflow while animating).
  static const double _sidebarLabelMinWidth = 140;

  /// The sectioned destination tree for this (org type, role) — see
  /// `portal/nav/portal_nav.dart`. Groups render as expandable dropdowns when
  /// the rail is expanded and as overlay flyouts when it is collapsed.
  final List<PortalNavNode> nav;

  /// The current location's path. Selection is resolved by longest matching
  /// leaf route, so a detail page (`/portal/mine/trips/:id`) keeps its parent
  /// destination (`…/trips`) highlighted.
  final String selectedRoute;

  /// Navigates to a leaf's route. The rail deals in URLs, not indices: the old
  /// contract set a tab index and pushed every destination to `/home`.
  final void Function(String route) onNavigate;

  /// Live queue sizes for the badge sources a leaf can name. Missing or zero
  /// renders nothing; a group header shows the sum of its children.
  final Map<PortalNavBadge, int> badgeCounts;

  final Widget body;
  final PreferredSizeWidget appBar;
  final bool navLocked;
  final GlobalKey<ScaffoldState>? scaffoldKey;
  final bool sidebarExpanded;
  final ValueChanged<bool> onSidebarExpandedChanged;

  /// Shown in the sidebar header under the wordmark (typically the company name).
  final String? sidebarBrandTitle;

  /// Signed-in operator for the sidebar user card (hidden when null).
  final String? userName;

  /// Secondary line on the user card (email or role label).
  final String? userMeta;

  /// The signed-in address. Shown on the user card's hover panel rather than
  /// on the chip itself, which already spends its second line on [userMeta].
  final String? userEmail;

  /// Uploaded profile image for the user card (company logo / profile photo).
  /// Null falls back to initials.
  final String? userAvatarUrl;

  final VoidCallback? onLogout;
  final VoidCallback? onNotifications;
  final bool notificationsBadge;
  final VoidCallback? onProfile;
  final VoidCallback? onToggleTheme;

  /// Opens the dedicated Appearance & theme page from the sidebar.
  final VoidCallback? onAppearance;

  /// When set (mine/supplier + a premium direction chosen), the sidebar chrome
  /// adopts this palette so it matches the rest of the themed mine UI.
  final MinePremiumPalette? premiumPalette;

  /// Floating action anchored bottom-right of the content area (chat FAB).
  final Widget? floatingAction;

  /// Optional bottom navigation bar, shown only on the narrow (mobile) layout.
  /// Used to give the Driver role a phone-style Dashboard / Trip / Profile bar
  /// while the drawer still holds the full destination list.
  final Widget? bottomNav;

  const PortalScaffold({
    super.key,
    required this.nav,
    required this.selectedRoute,
    required this.onNavigate,
    this.badgeCounts = const <PortalNavBadge, int>{},
    required this.body,
    required this.appBar,
    required this.navLocked,
    required this.sidebarExpanded,
    required this.onSidebarExpandedChanged,
    this.sidebarBrandTitle,
    this.scaffoldKey,
    this.userName,
    this.userMeta,
    this.userEmail,
    this.userAvatarUrl,
    this.onLogout,
    this.onNotifications,
    this.notificationsBadge = false,
    this.onProfile,
    this.onToggleTheme,
    this.onAppearance,
    this.premiumPalette,
    this.floatingAction,
    this.bottomNav,
  });

  /// True when [route] is a destination this session may open.
  ///
  /// While an employee waits for a role assignment the rail is locked to their
  /// own record, matching the overlay's promise that "you can only access your
  /// Profile". The router enforces the same rule against a deep link — this is
  /// the UX half.
  static bool _permitted(bool navLocked, String route) =>
      !navLocked || route.endsWith('/profile') || route == '/account-security';

  void _select(BuildContext context, String route) {
    if (!_permitted(navLocked, route)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please wait for role assignment.')),
      );
      return;
    }
    onNavigate(route);
    if (scaffoldKey?.currentState?.isDrawerOpen == true) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final showSidebar = width >= sidebarBreakpoint;

    final sidebar = _PortalSidebar(
      nav: nav,
      selectedRoute: selectedRoute,
      badgeCounts: badgeCounts,
      navLocked: navLocked,
      expanded: sidebarExpanded,
      brandTitle: sidebarBrandTitle,
      userName: userName,
      userMeta: userMeta,
      userEmail: userEmail,
      userAvatarUrl: userAvatarUrl,
      onLogout: onLogout,
      onNotifications: onNotifications,
      notificationsBadge: notificationsBadge,
      onProfile: onProfile,
      onToggleTheme: onToggleTheme,
      onAppearance: onAppearance,
      premiumPalette: premiumPalette,
      onToggleExpanded: () => onSidebarExpandedChanged(!sidebarExpanded),
      onSelect: (route) => _select(context, route),
    );

    final content = floatingAction == null
        ? body
        : Stack(
            children: [
              body,
              Positioned(right: 26, bottom: 26, child: floatingAction!),
            ],
          );

    if (showSidebar) {
      return Scaffold(
        key: scaffoldKey,
        body: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            sidebar,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Bound the app bar to its preferred height: as a non-flex
                  // Column child it would otherwise receive unbounded height,
                  // which breaks an AppBar that carries a `bottom` divider.
                  SizedBox(
                    height: appBar.preferredSize.height,
                    child: Material(elevation: 0, child: appBar),
                  ),
                  // Semantics boundary: the body hosts a nested (ShellRoute)
                  // Navigator whose ModalRoute carries BlockSemantics, which
                  // drops the semantics of everything painted before it — here
                  // the sidebar and this in-body app bar (they paint first in
                  // Row/Column order, unlike Scaffold's appBar slot which
                  // paints after the body). A boundary contains the blocking
                  // inside the body, keeping navigation reachable by assistive
                  // tech. See test/widgets/portal_scaffold_semantics_test.dart.
                  Expanded(
                    child: Semantics(container: true, child: content),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      key: scaffoldKey,
      appBar: appBar,
      drawer: Drawer(
        width: sidebarExpanded ? 288 : 84,
        child: SafeArea(child: sidebar),
      ),
      body: content,
      bottomNavigationBar: bottomNav,
    );
  }
}

class _PortalSidebar extends StatefulWidget {
  final List<PortalNavNode> nav;
  final String selectedRoute;
  final Map<PortalNavBadge, int> badgeCounts;
  final bool navLocked;
  final bool expanded;
  final String? brandTitle;
  final String? userName;
  final String? userMeta;
  final String? userEmail;
  final String? userAvatarUrl;
  final VoidCallback? onLogout;
  final VoidCallback? onNotifications;
  final bool notificationsBadge;
  final VoidCallback? onProfile;
  final VoidCallback? onToggleTheme;
  final VoidCallback? onAppearance;
  final MinePremiumPalette? premiumPalette;
  final VoidCallback onToggleExpanded;
  final ValueChanged<String> onSelect;

  const _PortalSidebar({
    required this.nav,
    required this.selectedRoute,
    required this.badgeCounts,
    required this.navLocked,
    required this.expanded,
    required this.brandTitle,
    required this.userName,
    required this.userMeta,
    required this.userEmail,
    required this.userAvatarUrl,
    required this.onLogout,
    required this.onNotifications,
    required this.notificationsBadge,
    required this.onProfile,
    required this.onToggleTheme,
    required this.onAppearance,
    required this.premiumPalette,
    required this.onToggleExpanded,
    required this.onSelect,
  });

  @override
  State<_PortalSidebar> createState() => _PortalSidebarState();
}

class _PortalSidebarState extends State<_PortalSidebar> {
  final TextEditingController _search = TextEditingController();

  /// Group labels the user has explicitly collapsed.
  ///
  /// Tracked as the *exceptions* rather than as the open set, so a group
  /// containing the current route auto-opens on arrival (P7-03) without
  /// fighting a deliberate collapse: closing "Fleet" keeps it closed while you
  /// move around inside it.
  final Set<String> _closed = <String>{};

  static const _wordmark = 'MineLink';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  /// The deepest leaf route that prefixes the current location.
  ///
  /// Longest-match, so `/portal/mine/trips/abc/waybill` selects `…/trips` and
  /// `/portal/mine/stockpiles/:id` selects `…/stockpiles`. Exact equality alone
  /// would leave every detail page with no highlight at all.
  String? get _activeRoute {
    String? best;
    for (final leaf in widget.nav.expand((n) => n.leaves)) {
      final route = leaf.route!;
      final isMatch = widget.selectedRoute == route ||
          widget.selectedRoute.startsWith('$route/');
      if (isMatch && (best == null || route.length > best.length)) {
        best = route;
      }
    }
    return best;
  }

  /// The badge integer for one leaf: null when it names no queue, and null
  /// rather than `0` when the queue is empty — an empty queue is not news.
  int? _badge(PortalNavNode leaf) {
    final source = leaf.badge;
    if (source == null) return null;
    final count = widget.badgeCounts[source] ?? 0;
    return count > 0 ? count : null;
  }

  /// A group header's badge: the sum of its children's (P7-04). A collapsed
  /// group must still show that something inside it needs attention.
  int? _groupBadge(PortalNavNode group) {
    var total = 0;
    for (final leaf in group.leaves) {
      total += _badge(leaf) ?? 0;
    }
    return total > 0 ? total : null;
  }

  @override
  Widget build(BuildContext context) {
    final expanded = widget.expanded;
    final palette = widget.premiumPalette;

    return AnimatedContainer(
      duration: MlTokens.durSlow,
      curve: MlTokens.easeOutCubic,
      width: expanded
          ? PortalScaffold._sidebarWidthExpanded
          : PortalScaffold._sidebarWidthCollapsed,
      decoration: palette == null
          ? BoxDecoration(
              // The portal rail. This is the one place a rail token belongs.
              gradient: mlPortalRailGradient,
              border: Border(
                  right: BorderSide(color: MlRailTokens.navy.border)),
            )
          : BoxDecoration(
              // Themed mine sidebar: a subtle vertical wash from the panel
              // surface down to the background, with the palette's hairline.
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color.alphaBlend(palette.panelHi, palette.bg),
                  palette.bg,
                ],
              ),
              border: Border(right: BorderSide(color: palette.border)),
            ),
      child: Material(
        color: Colors.transparent,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final showLabels = expanded &&
                constraints.maxWidth >= PortalScaffold._sidebarLabelMinWidth;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _brand(showLabels),
                Expanded(child: _nav(showLabels)),
                _footer(showLabels),
                if (widget.userName != null) _userCard(showLabels),
              ],
            );
          },
        ),
      ),
    );
  }

  // ---- Brand block ----
  Widget _brand(bool showLabels) {
    const gradient = LinearGradient(
      colors: [MlTokens.wordmarkGradientStart, MlTokens.wordmarkGradientEnd],
    );

    final collapseChip = _ChipButton(
      icon: showLabels ? Icons.chevron_left_rounded : Icons.chevron_right_rounded,
      tooltip: showLabels ? 'Collapse sidebar' : 'Expand sidebar',
      onTap: widget.onToggleExpanded,
    );

    if (!showLabels) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(8, 20, 8, 12),
        child: Column(
          children: [
            collapseChip,
            const SizedBox(height: 12),
            ShaderMask(
              shaderCallback: (r) => gradient.createShader(r),
              child: Text(
                _wordmark.characters.first,
                style: const TextStyle(
                  fontFamily: MlTokens.fontSerif,
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  color: MlTokens.inkOnFill,
                  height: 1,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final subtitle = widget.brandTitle?.trim();
    final parts = (subtitle == null || subtitle.isEmpty)
        ? const <String>[]
        : subtitle.split(' ');

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 22, 16, 14),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ShaderMask(
                shaderCallback: (r) => gradient.createShader(r),
                child: const Text(
                  _wordmark,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: MlTokens.fontSerif,
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.1,
                    color: MlTokens.inkOnFill,
                    height: 1.1,
                  ),
                ),
              ),
              if (parts.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: parts.first,
                        style: TextStyle(color: MlRailTokens.navy.inkStrong),
                      ),
                      if (parts.length > 1)
                        TextSpan(
                          text: ' ${parts.skip(1).join(' ')}',
                          style: const TextStyle(color: MlPortalRail.ink55),
                        ),
                    ],
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: MlTokens.fontSans,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.6,
                  ),
                ),
              ],
            ],
          ),
          Positioned(top: 0, right: 0, child: collapseChip),
        ],
      ),
    );
  }

  // ---- Nav ----
  //
  // The rail renders the tree from `portal_nav.dart` rather than a flat tab
  // list. There is no separate utility/settings block any more: Notifications,
  // My profile, Account & security and Appearance are leaves under Settings ▾
  // in the tree itself, so they carry routes, participate in search and cannot
  // drift out of step with the router the way a hand-built second list did.
  Widget _nav(bool showLabels) {
    final query = _search.text;
    final active = _activeRoute;

    // Search filters the WHOLE tree including nested leaves — the flat list
    // could only ever match top-level labels (P7-06).
    final visible = widget.nav
        .map((n) => n.filtered(query))
        .whereType<PortalNavNode>()
        .toList(growable: false);

    final entries = <Widget>[];

    // The first destination (always the dashboard) stays above the search box.
    var rest = visible;
    if (visible.isNotEmpty && !visible.first.isGroup) {
      entries.add(_leafTile(visible.first, showLabels, active));
      rest = visible.sublist(1);
    }

    if (showLabels) {
      entries.add(Padding(
        padding: const EdgeInsets.fromLTRB(2, 8, 2, 10),
        child: _SidebarSearch(
          controller: _search,
          onChanged: (_) => setState(() {}),
        ),
      ));
      entries.add(Container(
        height: 1,
        margin: const EdgeInsets.fromLTRB(2, 0, 2, 10),
        color: MlRailTokens.navy.hover,
      ));
    } else {
      entries.add(const SizedBox(height: 8));
    }

    for (final node in rest) {
      entries.addAll(_nodeTiles(node, showLabels, active, searching: query.trim().isNotEmpty));
    }

    if (visible.isEmpty && showLabels) {
      entries.add(const Padding(
        padding: EdgeInsets.fromLTRB(14, 18, 14, 8),
        child: Text(
          'Nothing matches that.',
          style: TextStyle(
            fontFamily: MlTokens.fontSans,
            fontSize: 12.5,
            color: mlRailSearchInk,
          ),
        ),
      ));
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 10),
      children: entries,
    );
  }

  /// One top-level node: a leaf tile, or a group header plus — when open — its
  /// children. A collapsed rail renders the group as a single icon that opens
  /// an overlay flyout instead.
  List<Widget> _nodeTiles(
    PortalNavNode node,
    bool showLabels,
    String? active, {
    required bool searching,
  }) {
    if (!node.isGroup) {
      return [_leafTile(node, showLabels, active)];
    }

    final holdsActive =
        active != null && node.leaves.any((l) => l.route == active);

    if (!showLabels) {
      return [
        _CollapsedNavGroup(
          group: node,
          activeRoute: active,
          badge: _groupBadge(node),
          leafBadge: _badge,
          enabled: (route) => PortalScaffold._permitted(widget.navLocked, route),
          onSelect: widget.onSelect,
        ),
      ];
    }

    // Auto-open by route prefix, and always while a search is narrowing the
    // tree — a hit hidden inside a shut group is a hit the user cannot see.
    final open = searching || holdsActive || !_closed.contains(node.label);

    return [
      _NavTile(
        icon: node.icon,
        label: node.label,
        selected: false,
        disabled: false,
        showLabel: true,
        badge: _groupBadge(node),
        trailing: Icon(
          open ? Icons.expand_less_rounded : Icons.expand_more_rounded,
          size: 18,
          color: MlRailTokens.navy.inkFaint,
        ),
        onTap: () => setState(() {
          if (!_closed.remove(node.label)) _closed.add(node.label);
        }),
      ),
      if (open)
        for (final child in node.children)
          _leafTile(child, true, active, indent: true),
    ];
  }

  Widget _leafTile(
    PortalNavNode leaf,
    bool showLabels,
    String? active, {
    bool indent = false,
  }) {
    final route = leaf.route!;
    final disabled = !PortalScaffold._permitted(widget.navLocked, route);
    return _NavTile(
      icon: leaf.icon,
      label: leaf.label,
      selected: route == active,
      disabled: disabled,
      showLabel: showLabels,
      indent: indent && showLabels,
      badge: _badge(leaf),
      onTap: disabled ? null : () => widget.onSelect(route),
    );
  }

  // ---- Footer: logout + collapse ----
  Widget _footer(bool showLabels) {
    return Padding(
      padding: EdgeInsets.fromLTRB(showLabels ? 14 : 10, 4, showLabels ? 14 : 10, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.onLogout != null) ...[
            _FooterButton(
              icon: Icons.logout_rounded,
              label: showLabels ? 'Logout' : null,
              tooltip: 'Logout',
              foreground: MlTokens.orange500,
              background: MlPortalRail.logoutWash,
              border: MlPortalRail.logoutBorder,
              onTap: widget.onLogout!,
            ),
            const SizedBox(height: 8),
          ],
          _FooterButton(
            icon: showLabels
                ? Icons.chevron_left_rounded
                : Icons.chevron_right_rounded,
            label: showLabels ? 'Collapse' : null,
            tooltip: showLabels ? 'Collapse sidebar' : 'Expand sidebar',
            foreground: MlRailTokens.navy.cbtnFg,
            background: MlRailTokens.navy.tileSelBgSub,
            border: MlPortalRail.collapseBorder,
            onTap: widget.onToggleExpanded,
          ),
        ],
      ),
    );
  }

  // ---- User card ----
  Widget _userCard(bool showLabels) {
    final name = widget.userName!.trim();
    final initials = name.isEmpty
        ? '?'
        : name
            .split(RegExp(r'\s+'))
            .take(2)
            .map((w) => w.characters.first.toUpperCase())
            .join();

    final avatarImage = imageProviderFromString(widget.userAvatarUrl);

    final avatar = Stack(
      clipBehavior: Clip.none,
      children: [
        CircleAvatar(
          radius: 19,
          backgroundColor: MlTokens.accent.withValues(alpha: 0.24),
          backgroundImage: avatarImage,
          child: avatarImage == null
              ? Text(
                  initials,
                  style: const TextStyle(
                    fontFamily: MlTokens.fontSans,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: MlTokens.cyan100,
                  ),
                )
              : null,
        ),
        Positioned(
          right: -1,
          bottom: -1,
          child: Container(
            width: 11,
            height: 11,
            decoration: BoxDecoration(
              color: MlTokens.green500,
              shape: BoxShape.circle,
              border: Border.all(color: MlTokens.navy800, width: 2),
            ),
          ),
        ),
      ],
    );

    final cardBody = showLabels
        ? Row(
            children: [
              avatar,
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: MlTokens.fontSans,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: MlTokens.inkOnFill,
                      ),
                    ),
                    if (widget.userMeta != null)
                      Text(
                        widget.userMeta!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: MlTokens.fontSans,
                          fontSize: 11.5,
                          color: MlPortalRail.ink70,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          )
        : Center(
            child: Tooltip(
              message: widget.userMeta == null
                  ? name
                  : '$name · ${widget.userMeta}',
              child: avatar,
            ),
          );

    final padding = EdgeInsets.symmetric(
        horizontal: showLabels ? 16 : 8, vertical: 13);

    // Hovering names the person in full — the chip's own second line is the
    // role label, so the address is only ever visible here — and offers the
    // three things anyone opens this chip for. Tapping still goes straight to
    // the profile, exactly as it did before the card existed.
    final actions = <UserIdentityAction>[
      if (widget.onProfile != null)
        UserIdentityAction(
          icon: Icons.person_outline_rounded,
          label: 'My profile',
          onTap: widget.onProfile!,
        ),
      UserIdentityAction(
        icon: Icons.shield_outlined,
        label: 'Account & security',
        onTap: () => widget.onSelect('/account-security'),
      ),
      if (widget.onAppearance != null)
        UserIdentityAction(
          icon: Icons.palette_outlined,
          label: 'Appearance & theme',
          onTap: widget.onAppearance!,
        ),
      if (widget.onLogout != null)
        UserIdentityAction(
          icon: Icons.logout_rounded,
          label: 'Sign out',
          onTap: widget.onLogout!,
          danger: true,
        ),
    ];

    return Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: MlRailTokens.navy.div)),
      ),
      child: UserIdentityFlyout(
        user: UserIdentity(
          name: name,
          email: widget.userEmail ?? '',
          roleLabel: widget.userMeta,
          avatarUrl: widget.userAvatarUrl,
        ),
        onOpenProfile: widget.onProfile,
        actions: actions,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onProfile,
            child: Padding(padding: padding, child: cardBody),
          ),
        ),
      ),
    );
  }
}

/// 26×26 rounded chip button used for the brand-row collapse control.
class _ChipButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _ChipButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          width: 26,
          height: 26,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: MlRailTokens.navy.btnBg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: MlRailTokens.navy.btnBd),
          ),
          child: Icon(icon, size: 16, color: MlPortalRail.inkIcon),
        ),
      ),
    );
  }
}

class _SidebarSearch extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  const _SidebarSearch({required this.controller, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        cursorColor: MlTokens.sidebarActiveBlue,
        style: const TextStyle(
          fontFamily: MlTokens.fontSans,
          fontSize: 12.5,
          color: MlPortalRail.inkSearch,
        ),
        decoration: InputDecoration(
          isDense: true,
          filled: true,
          fillColor: MlRailTokens.navy.searchBg,
          hintText: 'Search...',
          hintStyle: const TextStyle(
            fontFamily: MlTokens.fontSans,
            fontSize: 12.5,
            color: mlRailSearchInk,
          ),
          prefixIcon:
              const Icon(Icons.search, size: 16, color: mlRailSearchInk),
          prefixIconConstraints:
              const BoxConstraints(minWidth: 34, minHeight: 16),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: MlRailTokens.navy.searchBd),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: MlTokens.sidebarActiveBlue),
          ),
        ),
      ),
    );
  }
}

class _NavTile extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final bool disabled;
  final bool showLabel;
  final bool indent;

  /// Queue size, or null for none. An integer, not a dot: "3 loads waiting"
  /// is actionable and "something is waiting" is not (P7-04).
  final int? badge;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _NavTile({
    required this.icon,
    required this.label,
    required this.selected,
    required this.disabled,
    required this.showLabel,
    this.indent = false,
    this.badge,
    this.trailing,
    required this.onTap,
  });

  @override
  State<_NavTile> createState() => _NavTileState();
}

class _NavTileState extends State<_NavTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final selected = widget.selected;
    final disabled = widget.disabled;

    final fg = disabled
        ? MlPortalRail.inkDisabled
        : selected
            ? MlRailTokens.navy.inkStrong
            : MlRailTokens.navy.ink;
    final iconColor = disabled
        ? MlPortalRail.inkDisabled
        : selected
            ? MlTokens.inkOnFill
            : MlRailTokens.navy.ink;

    final decoration = BoxDecoration(
      color: selected
          ? MlRailTokens.navy.tileSelBg
          : _hovered && !disabled
              ? MlRailTokens.navy.hover
              : Colors.transparent,
      borderRadius: BorderRadius.circular(MlTokens.rMd),
      border: Border.all(
        color: selected ? MlRailTokens.navy.tileSelBd : Colors.transparent,
      ),
    );

    Widget content;
    if (widget.showLabel) {
      content = Row(
        children: [
          if (selected)
            Container(
              width: 3,
              height: 20,
              margin: const EdgeInsets.only(right: 9),
              decoration: BoxDecoration(
                color: MlTokens.sidebarActiveBlue,
                borderRadius: BorderRadius.circular(2),
              ),
            )
          else
            const SizedBox(width: 12),
          Icon(widget.icon, size: widget.indent ? 18 : 21, color: iconColor),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              widget.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: MlTokens.fontSans,
                fontSize: widget.indent ? 13.5 : 14.5,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: fg,
              ),
            ),
          ),
          if (widget.badge != null) _NavBadge(count: widget.badge!),
          if (widget.trailing != null) widget.trailing!,
        ],
      );
    } else {
      content = Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Icon(widget.icon, size: 21, color: iconColor),
          if (widget.badge != null)
            Positioned(
              top: -6,
              right: -10,
              child: _NavBadge(count: widget.badge!, ringed: true),
            ),
        ],
      );
    }

    final tile = MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: InkWell(
        borderRadius: BorderRadius.circular(MlTokens.rMd),
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          padding: widget.showLabel
              ? EdgeInsets.fromLTRB(
                  widget.indent ? 30 : 0, widget.indent ? 9 : 10, 12,
                  widget.indent ? 9 : 10)
              : const EdgeInsets.symmetric(vertical: 11),
          decoration: decoration,
          child: content,
        ),
      ),
    );

    final padded = Padding(padding: const EdgeInsets.only(bottom: 3), child: tile);

    if (!widget.showLabel && widget.onTap != null) {
      return Tooltip(
        message: widget.badge == null
            ? widget.label
            : '${widget.label} · ${widget.badge}',
        waitDuration: const Duration(milliseconds: 400),
        child: padded,
      );
    }
    return padded;
  }
}

/// An integer queue count on a nav tile.
///
/// Sized by its content rather than to a fixed width: the console had a
/// fixed-width badge column that overflowed as soon as a user nudged
/// `textScale` past 1.0, and the same trap applies here (CLAUDE.md §10.4).
class _NavBadge extends StatelessWidget {
  final int count;

  /// Draws a rail-coloured ring so the badge stays legible when it overhangs
  /// an icon on the collapsed rail.
  final bool ringed;

  const _NavBadge({required this.count, this.ringed = false});

  @override
  Widget build(BuildContext context) {
    final label = count > 99 ? '99+' : '$count';
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
        decoration: BoxDecoration(
          color: MlTokens.accent,
          borderRadius: BorderRadius.circular(MlTokens.rPill),
          border: ringed
              ? Border.all(color: MlTokens.navy800, width: 2)
              : null,
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: MlTokens.fontMono,
            fontSize: 11,
            height: 1.25,
            fontWeight: FontWeight.w700,
            color: MlPortalRail.inkOnAccentChip,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
      ),
    );
  }
}

/// A group on the **collapsed** rail: one icon that opens its children in an
/// overlay flyout (P7-03).
///
/// Without this a collapsed rail either hides every nested destination or
/// flattens the tree back into the undifferentiated list the rebuild exists to
/// replace. Built on [MenuAnchor] so dismissal, focus traversal and
/// screen-reader semantics are the framework's rather than hand-rolled.
class _CollapsedNavGroup extends StatelessWidget {
  final PortalNavNode group;
  final String? activeRoute;
  final int? badge;
  final int? Function(PortalNavNode leaf) leafBadge;
  final bool Function(String route) enabled;
  final ValueChanged<String> onSelect;

  const _CollapsedNavGroup({
    required this.group,
    required this.activeRoute,
    required this.badge,
    required this.leafBadge,
    required this.enabled,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final holdsActive =
        activeRoute != null && group.leaves.any((l) => l.route == activeRoute);

    return MenuAnchor(
      alignmentOffset: const Offset(8, 0),
      style: MenuStyle(
        backgroundColor: const WidgetStatePropertyAll(MlTokens.navy800),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(MlTokens.rMd),
            side: BorderSide(color: MlRailTokens.navy.btnBd),
          ),
        ),
      ),
      menuChildren: [
        for (final leaf in group.children)
          MenuItemButton(
            onPressed:
                enabled(leaf.route!) ? () => onSelect(leaf.route!) : null,
            leadingIcon: Icon(
              leaf.icon,
              size: 18,
              color: leaf.route == activeRoute
                  ? MlTokens.inkOnFill
                  : MlRailTokens.navy.ink,
            ),
            trailingIcon: leafBadge(leaf) == null
                ? null
                : _NavBadge(count: leafBadge(leaf)!),
            child: Text(
              leaf.label,
              style: TextStyle(
                fontFamily: MlTokens.fontSans,
                fontSize: 13.5,
                fontWeight: leaf.route == activeRoute
                    ? FontWeight.w700
                    : FontWeight.w500,
                color: MlRailTokens.navy.ink,
              ),
            ),
          ),
      ],
      builder: (context, controller, child) => _NavTile(
        icon: group.icon,
        label: group.label,
        selected: holdsActive,
        disabled: false,
        showLabel: false,
        badge: badge,
        onTap: () =>
            controller.isOpen ? controller.close() : controller.open(),
      ),
    );
  }
}

class _FooterButton extends StatefulWidget {
  final IconData icon;
  final String? label;
  final String tooltip;
  final Color foreground;
  final Color background;
  final Color border;
  final VoidCallback onTap;

  const _FooterButton({
    required this.icon,
    required this.label,
    required this.tooltip,
    required this.foreground,
    required this.background,
    required this.border,
    required this.onTap,
  });

  @override
  State<_FooterButton> createState() => _FooterButtonState();
}

class _FooterButtonState extends State<_FooterButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final button = MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: InkWell(
        borderRadius: BorderRadius.circular(11),
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: EdgeInsets.symmetric(
              vertical: widget.label != null ? 10 : 9,
              horizontal: widget.label != null ? 12 : 0),
          decoration: BoxDecoration(
            color: _hovered
                ? widget.background.withValues(
                    alpha: (widget.background.a * 2).clamp(0.0, 1.0))
                : widget.background,
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: widget.border),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon, size: 19, color: widget.foreground),
              if (widget.label != null) ...[
                const SizedBox(width: 9),
                Text(
                  widget.label!,
                  style: TextStyle(
                    fontFamily: MlTokens.fontSans,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: widget.foreground,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );

    if (widget.label == null) {
      return Tooltip(message: widget.tooltip, child: button);
    }
    return button;
  }
}
