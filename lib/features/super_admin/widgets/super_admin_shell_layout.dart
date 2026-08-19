import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_application_1/core/layout/app_breakpoints.dart';
import 'package:flutter_application_1/core/routing/ml_route_title.dart';
import 'package:flutter_application_1/core/navigation/app_sidebar_prefs.dart';
import 'package:flutter_application_1/core/theme/app_theme.dart';
import 'package:flutter_application_1/core/design/tokens/ml_tokens.dart';
import 'package:flutter_application_1/core/design/tokens/ml_rail_tokens.dart';
import 'package:flutter_application_1/core/navigation/nav_back.dart';
import 'package:flutter_application_1/core/navigation/nav_history_provider.dart';
import 'package:flutter_application_1/core/widgets/app_navigation_back_button.dart';
import 'package:flutter_application_1/core/widgets/minelink_logo.dart';
import 'package:flutter_application_1/core/widgets/nav_history_recorder.dart';
import 'package:flutter_application_1/core/widgets/user_identity_flyout.dart';
import 'package:flutter_application_1/features/auth/providers/auth_state.dart';
import 'package:flutter_application_1/features/chat/widgets/chat_dock.dart';
import 'package:flutter_application_1/features/auth/services/logout_service.dart';
import 'package:flutter_application_1/core/routing/notifications_inbox_route.dart';
import 'package:flutter_application_1/features/notifications/widgets/animated_notification_bell.dart';
import 'package:flutter_application_1/features/portal/providers/request_provider.dart';
import 'package:flutter_application_1/core/design/tokens/ui_prefs.dart';
import 'package:flutter_application_1/features/super_admin/providers/super_admin_providers.dart';
import 'package:flutter_application_1/features/super_admin/widgets/sidebar/console_sidebar_bridge.dart';
import 'package:flutter_application_1/core/design/shell/workspace_canvas.dart';
import 'package:flutter_application_1/core/design/shell/ml_home_chip.dart';
import 'package:flutter_application_1/core/layout/text_scale.dart';


/// Desktop-style shell: navy sidebar, light workspace, animated content swap.
///
/// Wraps the workspace in [AppTheme.lightTheme] so [ColorScheme] and text styles
/// always match this shell’s light workspace (defense in depth if app theme
/// brightness ever changes). Avoids light glyphs on light surfaces.
class SuperAdminShellLayout extends ConsumerStatefulWidget {
  final Widget child;

  const SuperAdminShellLayout({super.key, required this.child});

  @override
  ConsumerState<SuperAdminShellLayout> createState() =>
      _SuperAdminShellLayoutState();
}

class _SuperAdminShellLayoutState extends ConsumerState<SuperAdminShellLayout> {
  bool _sidebarExpanded = true;

  @override
  void initState() {
    super.initState();
    AppSidebarPrefs.readSuperAdminExpanded().then((v) {
      if (mounted) setState(() => _sidebarExpanded = v);
    });
  }

  void _setSidebarExpanded(bool value) {
    setState(() => _sidebarExpanded = value);
    AppSidebarPrefs.writeSuperAdminExpanded(value);
  }

  /// Console theme from the per-user preferences: base light/dark theme with
  /// the chosen accent applied, plus the high-contrast strengthening.
  static ThemeData _consoleTheme(UiPrefs prefs) {
    final base = prefs.darkMode ? AppTheme.darkTheme : AppTheme.lightTheme;
    var cs = base.colorScheme.copyWith(
      primary: prefs.accent.color,
      secondary: prefs.accent.color,
    );
    if (prefs.highContrast) {
      cs = cs.copyWith(
        onSurface: prefs.darkMode ? MlTokens.inkOnFill : MlTokens.slate950,
        onSurfaceVariant: prefs.darkMode
            ? mlConsoleHcOnSurfaceVariantDark
            : mlConsoleHcOnSurfaceVariantLight,
        outlineVariant: prefs.darkMode
            ? mlConsoleHcOutlineDark
            : mlConsoleHcOutlineLight,
      );
    }
    return base.copyWith(
      colorScheme: cs,
      // Console screens sit on the shell's painted workspace canvas (deep
      // navy in dark, dotted cool-gray in light). Child Scaffolds must be
      // transparent or their theme background hides that canvas.
      scaffoldBackgroundColor: Colors.transparent,
    );
  }

  @override
  Widget build(BuildContext context) {
    final prefs = ref.watch(uiPrefsProvider);
    final isDark = prefs.darkMode;
    final media = MediaQuery.of(context);
    return MediaQuery(
      // Accessibility (Settings → User Preferences): per-user text size and
      // bold-text — themes and widgets pick these up via MediaQuery.
      //
      // Both COMPOSE with the platform rather than replacing it. Bold text
      // always did; text size did not, so an admin at 200% got 130% and
      // everyone who never touched the slider got 100% — the OS setting
      // discarded, not capped. See lib/core/layout/text_scale.dart.
      data: media.copyWith(
        textScaler: mlTextScaler(media.textScaler, prefs.textScale),
        boldText: media.boldText || prefs.boldText,
      ),
      child: _buildThemed(prefs, isDark),
    );
  }

  Widget _buildThemed(UiPrefs prefs, bool isDark) {
    return Theme(
      data: _consoleTheme(prefs),
      child: Builder(
        builder: (context) {
          final width = MediaQuery.sizeOf(context).width;
          final useDrawer = width < AppBreakpoints.sidebarBreakpoint;
          final compactTopBar = width < 560;
          final goState = GoRouterState.of(context);
          final location = goState.uri.path;
          final navLocation = NavLocation(
            path: location,
            query: goState.uri.queryParameters,
          );
          final isRootScreen = location == '/super-admin';

          // Which of the three sidebars this admin chose (Settings → User
          // Preferences → Console sidebar). Routes are identical for all
          // three; only the chrome differs.
          Widget sidebar() => prefs.sidebar == ConsoleSidebarSkin.classic
              ? _SidebarNav(
                  location: location,
                  expanded: _sidebarExpanded,
                  onToggleRailExpanded: () =>
                      _setSidebarExpanded(!_sidebarExpanded),
                )
              : ConsoleSkinSidebar(
                  skin: prefs.sidebar,
                  location: location,
                  collapsed: !_sidebarExpanded,
                  onCollapsedChanged: (v) => _setSidebarExpanded(!v),
                );

          final shell = Scaffold(
            // Design canvases: deep navy in dark mode, the cool blue-gray
            // "premium surface" under white cards in light mode.
            backgroundColor:
                isDark ? mlConsoleCanvasDark : mlConsoleCanvasLight,
            drawer: useDrawer
                ? Drawer(
                    width: prefs.sidebar == ConsoleSidebarSkin.classic
                        ? (_sidebarExpanded ? 280 : 80)
                        : consoleSidebarWidth(
                            prefs.sidebar,
                            collapsed: !_sidebarExpanded,
                            windowWidth: width,
                          ),
                    child: sidebar(),
                  )
                : null,
            body: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!useDrawer) sidebar(),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Material(
                        // Design app bar: the card surface in both modes —
                        // white above the light canvas, raised navy
                        // (#111C30) above the dark one.
                        color: isDark
                            ? MlSemantic.from(Brightness.dark).surfaceCard
                            : MlSemantic.from(Brightness.light).surfaceCard,
                        elevation: 0,
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(
                            width >= AppBreakpoints.sidebarBreakpoint ? 24 : 12,
                            12,
                            16,
                            12,
                          ),
                          child: Row(
                            children: [
                              if (useDrawer)
                                IconButton(
                                  tooltip: 'Open navigation menu',
                                  icon: const Icon(Icons.menu_rounded),
                                  onPressed: () =>
                                      Scaffold.of(context).openDrawer(),
                                ),
                              const AppNavigationBackButton(),
                              if (!compactTopBar) ...[
                                MlHomeChip(
                                  onTap: () => context.go('/super-admin'),
                                ),
                                const SizedBox(width: 14),
                              ] else
                                const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    _TopBarTitle(path: location),
                                    Text(
                                      _subtitleForPath(location),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontFamily: mlConsoleSans,
                                        fontSize: 12,
                                        color: mlRailSearchInk,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (compactTopBar)
                                PopupMenuButton<String>(
                                  tooltip: 'More',
                                  icon: const Icon(Icons.more_vert_rounded),
                                  onSelected: (value) {
                                    switch (value) {
                                      case 'notif':
                                        context.go(
                                          NotificationsInboxRoute
                                              .superAdminPath,
                                        );
                                        return;
                                      case 'out':
                                        LogoutService.logoutWithConfirmation(
                                          context,
                                          ref,
                                        );
                                        return;
                                      default:
                                        return;
                                    }
                                  },
                                  itemBuilder: (ctx) => const [
                                    PopupMenuItem(
                                      value: 'notif',
                                      child: Text('Notifications'),
                                    ),
                                    PopupMenuItem(
                                      value: 'out',
                                      child: Text('Sign out'),
                                    ),
                                  ],
                                )
                              else ...[
                                if (width >= 980) ...[
                                  _TopBarSearch(
                                    onTap: () => context.go(
                                      '/super-admin/organizations',
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  const _LivePill(),
                                  const SizedBox(width: 8),
                                ],
                                // Theme/appearance controls live in
                                // Settings → User Preferences (per-user),
                                // not as a top-bar toggle.
                                IconTheme.merge(
                                  // Design: the bell reads at body-ink
                                  // strength on the card-surface app bar.
                                  data: IconThemeData(
                                    color: isDark
                                        ? MlRailTokens.navy.inkStrong
                                        : MlRailTokens.light.ink,
                                  ),
                                  child: const AnimatedNotificationBell(),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const Divider(height: 1),
                      // Semantics boundary: the child hosts the nested
                      // (ShellRoute) Navigator whose ModalRoute carries
                      // BlockSemantics, which drops the semantics of everything
                      // painted before it — here the sidebar and this top bar
                      // (they paint first in Row/Column order). The boundary
                      // contains the blocking inside the body so navigation
                      // stays reachable by assistive tech. Same fix as
                      // portal_scaffold.dart; see
                      // test/widgets/portal_scaffold_semantics_test.dart.
                      Expanded(
                        child: Semantics(
                          container: true,
                          child: CustomPaint(
                            // Design workspace canvas: light mode floats the
                            // white cards on a cool-gray surface with soft
                            // brand washes + a 24px engineering dot-grid;
                            // dark mode is the flat deep navy.
                            painter: MlWorkspaceCanvasPainter(
                              dark: isDark,
                              texture: prefs.canvasTexture,
                            ),
                            child: NavHistoryRecorder(
                              key: ValueKey(navLocation.fullLocation),
                              location: navLocation,
                              isRoot: isRootScreen,
                              child: widget.child,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );

          return PopScope(
            canPop: false,
            onPopInvokedWithResult: (didPop, _) {
              if (didPop) return;
              if (ref.read(navHistoryProvider.notifier).canGoBack) {
                navigateBack(context, ref);
              }
            },
            child: ChatDock(child: shell),
          );
        },
      ),
    );
  }

  /// The console's page title and its second line.
  ///
  /// Both tables moved to `core/routing/ml_route_title.dart` at S5-12, where
  /// the portal's live too — one place to add a route, instead of two that had
  /// already started to disagree about which one owned `/notifications`.
  static String _titleForPath(String path) =>
      mlRouteTitle(Uri.parse(path)).title;

  static String _subtitleForPath(String path) =>
      mlRouteTitle(Uri.parse(path)).subtitle ?? '';
}

/// Top-bar page title. On the root console it renders "Global Admin · " with
/// the second word "Dashboard" in the editorial serif italic accent, matching
/// the design's header; every other route falls back to a plain bold title.
class _TopBarTitle extends StatelessWidget {
  final String path;
  const _TopBarTitle({required this.path});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final base = Theme.of(context).textTheme.titleLarge!.copyWith(
      fontWeight: FontWeight.w800,
      color: cs.onSurface,
    );
    final isRoot = path == '/super-admin';
    if (isRoot) {
      // Design META.overview: the whole title is the editorial serif at 24px
      // w500, with "Dashboard" italic in the accent-ink (blue on light,
      // ice-blue on dark — design `--accent-ink`).
      final dark = Theme.of(context).brightness == Brightness.dark;
      final serifBase = TextStyle(
        fontFamily: MlTokens.fontSerif,
        fontSize: 24,
        fontWeight: FontWeight.w500,
        letterSpacing: -0.24,
        height: 1.15,
        color: cs.onSurface,
      );
      return RichText(
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        text: TextSpan(
          children: [
            TextSpan(text: 'Global Admin · ', style: serifBase),
            TextSpan(
              text: 'Dashboard',
              style: serifBase.copyWith(
                fontStyle: FontStyle.italic,
                color: dark ? mlRailAccentLift : mlRailAccent,
              ),
            ),
          ],
        ),
      );
    }
    return Text(
      _SuperAdminShellLayoutState._titleForPath(path),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: base,
    );
  }
}

/// Top-bar home button — a bordered box with a dashboard glyph that returns to
/// the console root (design's app-bar home control).
class _SidebarNav extends ConsumerStatefulWidget {
  final String location;
  final bool expanded;
  final VoidCallback? onToggleRailExpanded;

  const _SidebarNav({
    required this.location,
    required this.expanded,
    this.onToggleRailExpanded,
  });

  @override
  ConsumerState<_SidebarNav> createState() => _SidebarNavState();
}

class _SidebarNavState extends ConsumerState<_SidebarNav> {
  late bool _insights;
  late bool _tokens;
  late bool _requests;
  late bool _settings;

  @override
  void initState() {
    super.initState();
    // Auto-open the group that contains the active route.
    final loc = widget.location;
    _insights = loc.startsWith('/super-admin/insights');
    _tokens =
        loc.contains('/organizations') ||
        loc.contains('/token-requests') ||
        loc.contains('/token-history');
    _requests = loc.contains('/requests/') || loc.contains('/driver-limits');
    _settings =
        loc.contains('/account-security') ||
        loc.contains('/preferences') ||
        loc.endsWith('/settings');
  }

  bool _active(String prefix) =>
      widget.location == prefix || widget.location.startsWith('$prefix/');

  void _go(String path) {
    context.go(path);
    Scaffold.maybeOf(context)?.closeDrawer();
  }

  @override
  Widget build(BuildContext context) {
    final expanded = widget.expanded;
    final w = expanded ? 274.0 : 78.0;

    // Live counts for the nav badges.
    final stats = ref.watch(dashboardStatsProvider).valueOrNull;
    final orgCount = (stats?['totalCompanies'] as int?) ?? 0;
    final tokenCount = (stats?['openTokenRequests'] as int?) ?? 0;
    int q(String t) =>
        ref.watch(adminRequestQueueProvider(t)).valueOrNull?.length ?? 0;
    // Per-child request counts so each badge sits next to the row it belongs to
    // (the parent "Requests" badge is just their sum). The transportation inbox
    // is split by requesting-org type: mine/supplier vs buyer.
    final transportationReqs =
        ref.watch(adminRequestQueueProvider('transportation')).valueOrNull ??
        const [];
    final mineTransportCount = transportationReqs
        .where((r) => r.isFromMine)
        .length;
    final buyerTransportCount = transportationReqs
        .where((r) => !r.isFromMine)
        .length;
    final productReqCount = q('product');
    final buyerReqCount = q('buyer');
    final reqCount =
        mineTransportCount +
        buyerTransportCount +
        productReqCount +
        buyerReqCount;

    final sb = MlRailTokens.of(context);
    return Material(
      color: Colors.transparent,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        width: w,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: sb.bg,
          ),
          border: Border(right: BorderSide(color: sb.border)),
          boxShadow: sb.dark
              ? null
              : const [
                  // Design: the light rail casts depth onto the canvas.
                  BoxShadow(
                    color: mlRailLightShadow,
                    blurRadius: 30,
                    offset: Offset(12, 0),
                    spreadRadius: -20,
                  ),
                ],
        ),
        // Lay the rail content out at its TARGET width and clip while the
        // AnimatedContainer is mid-animation — otherwise expanded rows are
        // squeezed into the animating (narrow) width and overflow on every
        // frame of the expand transition.
        child: DefaultTextStyle.merge(
          // Design console sans (Sora) across the rail's labels.
          style: const TextStyle(fontFamily: mlConsoleSans),
          child: ClipRect(
            child: OverflowBox(
              alignment: Alignment.topLeft,
              minWidth: w,
              maxWidth: w,
              child: SafeArea(
                child: Column(
                  children: [
                    _SidebarHeader(
                      expanded: expanded,
                      onToggleRailExpanded: widget.onToggleRailExpanded,
                    ),
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.symmetric(
                          vertical: 4,
                          horizontal: 8,
                        ),
                        children: [
                          _NavTile(
                            expanded: expanded,
                            icon: Icons.dashboard_outlined,
                            label: 'Dashboard',
                            selected: widget.location == '/super-admin',
                            onTap: () => _go('/super-admin'),
                          ),
                          if (expanded) ...[
                            Padding(
                              padding: const EdgeInsets.fromLTRB(2, 8, 2, 10),
                              child: _SidebarSearch(
                                onTap: () => _go('/super-admin/organizations'),
                              ),
                            ),
                            Container(
                              height: 1,
                              margin: const EdgeInsets.fromLTRB(2, 0, 2, 10),
                              color: sb.div,
                            ),
                          ] else ...[
                            // Search keeps its slot in the collapsed rail so icon
                            // count + placement mirror the expanded sidebar.
                            _NavTile(
                              expanded: expanded,
                              icon: Icons.search_rounded,
                              label: 'Search',
                              selected: false,
                              onTap: () => _go('/super-admin/organizations'),
                            ),
                            Container(
                              height: 1,
                              margin: const EdgeInsets.fromLTRB(8, 2, 8, 8),
                              color: sb.div,
                            ),
                          ],
                          // ── Insights group ──
                          if (expanded)
                            _NavGroup(
                              icon: Icons.insights_outlined,
                              label: 'Insights',
                              open: _insights,
                              active: widget.location.startsWith(
                                '/super-admin/insights',
                              ),
                              onToggle: () =>
                                  setState(() => _insights = !_insights),
                            )
                          else
                            _CollapsedNavGroup(
                              icon: Icons.insights_outlined,
                              label: 'Insights',
                              active: widget.location.startsWith(
                                '/super-admin/insights',
                              ),
                              items: [
                                _FlyoutItem(
                                  icon: Icons.local_shipping_outlined,
                                  label: 'Transporters',
                                  selected: _active(
                                    '/super-admin/insights/transporter',
                                  ),
                                  onTap: () =>
                                      _go('/super-admin/insights/transporter'),
                                ),
                                _FlyoutItem(
                                  icon: Icons.shopping_bag_outlined,
                                  label: 'Buyers',
                                  selected: _active(
                                    '/super-admin/insights/buyer',
                                  ),
                                  onTap: () =>
                                      _go('/super-admin/insights/buyer'),
                                ),
                                _FlyoutItem(
                                  icon: Icons.landscape_outlined,
                                  label: 'Mines / Suppliers',
                                  selected: _active(
                                    '/super-admin/insights/mineSupplier',
                                  ),
                                  onTap: () =>
                                      _go('/super-admin/insights/mineSupplier'),
                                ),
                              ],
                            ),
                          if (expanded && _insights) ...[
                            _NavTile(
                              expanded: expanded,
                              icon: Icons.local_shipping_outlined,
                              label: 'Transporters',
                              selected: _active(
                                '/super-admin/insights/transporter',
                              ),
                              indent: expanded ? 12 : 0,
                              onTap: () =>
                                  _go('/super-admin/insights/transporter'),
                            ),
                            _NavTile(
                              expanded: expanded,
                              icon: Icons.shopping_bag_outlined,
                              label: 'Buyers',
                              selected: _active('/super-admin/insights/buyer'),
                              indent: expanded ? 12 : 0,
                              onTap: () => _go('/super-admin/insights/buyer'),
                            ),
                            _NavTile(
                              expanded: expanded,
                              icon: Icons.landscape_outlined,
                              label: 'Mines / Suppliers',
                              selected: _active(
                                '/super-admin/insights/mineSupplier',
                              ),
                              indent: expanded ? 12 : 0,
                              onTap: () =>
                                  _go('/super-admin/insights/mineSupplier'),
                            ),
                          ],
                          // ── Tokens & Seats group ──
                          if (expanded)
                            _NavGroup(
                              icon: Icons.vpn_key_outlined,
                              label: 'Tokens & Seats',
                              badge: tokenCount,
                              open: _tokens,
                              active:
                                  _active('/super-admin/organizations') ||
                                  _active('/super-admin/token-requests') ||
                                  _active('/super-admin/token-history') ||
                                  _active('/super-admin/audit-logs') ||
                                  _active('/super-admin/crash-reports') ||
                                  _active(
                                    '/super-admin/account-deactivations',
                                  ),
                              onToggle: () =>
                                  setState(() => _tokens = !_tokens),
                            )
                          else
                            _CollapsedNavGroup(
                              icon: Icons.vpn_key_outlined,
                              label: 'Tokens & Seats',
                              badge: tokenCount,
                              active:
                                  _active('/super-admin/organizations') ||
                                  _active('/super-admin/token-requests') ||
                                  _active('/super-admin/token-history') ||
                                  _active('/super-admin/audit-logs') ||
                                  _active('/super-admin/crash-reports') ||
                                  _active(
                                    '/super-admin/account-deactivations',
                                  ),
                              items: [
                                _FlyoutItem(
                                  icon: Icons.business_rounded,
                                  label: 'Organizations',
                                  badge: orgCount,
                                  selected: _active(
                                    '/super-admin/organizations',
                                  ),
                                  onTap: () =>
                                      _go('/super-admin/organizations'),
                                ),
                                _FlyoutItem(
                                  icon: Icons.vpn_key_rounded,
                                  label: 'Token requests',
                                  badge: tokenCount,
                                  selected: _active(
                                    '/super-admin/token-requests',
                                  ),
                                  onTap: () =>
                                      _go('/super-admin/token-requests'),
                                ),
                                _FlyoutItem(
                                  icon: Icons.timeline_rounded,
                                  label: 'Token history',
                                  selected: _active(
                                    '/super-admin/token-history',
                                  ),
                                  onTap: () =>
                                      _go('/super-admin/token-history'),
                                ),
                                _FlyoutItem(
                                  icon: Icons.history_rounded,
                                  label: 'Audit logs',
                                  selected: _active('/super-admin/audit-logs'),
                                  onTap: () => _go('/super-admin/audit-logs'),
                                ),
                                _FlyoutItem(
                                  icon: Icons.bug_report_outlined,
                                  label: 'Crash reports',
                                  selected: _active(
                                    '/super-admin/crash-reports',
                                  ),
                                  onTap: () =>
                                      _go('/super-admin/crash-reports'),
                                ),
                                _FlyoutItem(
                                  icon: Icons.person_off_outlined,
                                  label: 'Account deactivations',
                                  selected: _active(
                                    '/super-admin/account-deactivations',
                                  ),
                                  onTap: () => _go(
                                    '/super-admin/account-deactivations',
                                  ),
                                ),
                              ],
                            ),
                          if (expanded && _tokens) ...[
                            _NavTile(
                              expanded: expanded,
                              icon: Icons.business_rounded,
                              label: 'Organizations',
                              badge: orgCount,
                              selected: _active('/super-admin/organizations'),
                              indent: expanded ? 12 : 0,
                              onTap: () => _go('/super-admin/organizations'),
                            ),
                            _NavTile(
                              expanded: expanded,
                              icon: Icons.vpn_key_rounded,
                              label: 'Token requests',
                              selected: _active('/super-admin/token-requests'),
                              indent: expanded ? 12 : 0,
                              onTap: () => _go('/super-admin/token-requests'),
                            ),
                            _NavTile(
                              expanded: expanded,
                              icon: Icons.timeline_rounded,
                              label: 'Token history',
                              selected: _active('/super-admin/token-history'),
                              indent: expanded ? 12 : 0,
                              onTap: () => _go('/super-admin/token-history'),
                            ),
                            _NavTile(
                              expanded: expanded,
                              icon: Icons.history_rounded,
                              label: 'Audit logs',
                              selected: _active('/super-admin/audit-logs'),
                              indent: expanded ? 12 : 0,
                              onTap: () => _go('/super-admin/audit-logs'),
                            ),
                            _NavTile(
                              expanded: expanded,
                              icon: Icons.bug_report_outlined,
                              label: 'Crash reports',
                              selected: _active('/super-admin/crash-reports'),
                              indent: expanded ? 12 : 0,
                              onTap: () => _go('/super-admin/crash-reports'),
                            ),
                            _NavTile(
                              expanded: expanded,
                              icon: Icons.person_off_outlined,
                              label: 'Account deactivations',
                              selected: _active(
                                '/super-admin/account-deactivations',
                              ),
                              indent: expanded ? 12 : 0,
                              onTap: () =>
                                  _go('/super-admin/account-deactivations'),
                            ),
                          ],
                          // ── Requests group ──
                          if (expanded)
                            _NavGroup(
                              icon: Icons.assignment_outlined,
                              label: 'Requests',
                              badge: reqCount,
                              open: _requests,
                              active:
                                  _active('/super-admin/requests') ||
                                  _active('/super-admin/driver-limits'),
                              onToggle: () =>
                                  setState(() => _requests = !_requests),
                            )
                          else
                            _CollapsedNavGroup(
                              icon: Icons.assignment_outlined,
                              label: 'Requests',
                              badge: reqCount,
                              active:
                                  _active('/super-admin/requests') ||
                                  _active('/super-admin/driver-limits'),
                              items: [
                                _FlyoutItem(
                                  icon: Icons.factory_outlined,
                                  label: 'Mine/Supplier transport',
                                  badge: mineTransportCount,
                                  selected: _active(
                                    '/super-admin/requests/transportation-mine',
                                  ),
                                  onTap: () => _go(
                                    '/super-admin/requests/transportation-mine',
                                  ),
                                ),
                                _FlyoutItem(
                                  icon: Icons.alt_route_outlined,
                                  label: 'Buyer transport',
                                  badge: buyerTransportCount,
                                  selected: _active(
                                    '/super-admin/requests/transportation-buyer',
                                  ),
                                  onTap: () => _go(
                                    '/super-admin/requests/transportation-buyer',
                                  ),
                                ),
                                _FlyoutItem(
                                  icon: Icons.inventory_2_outlined,
                                  label: 'Requested product',
                                  badge: productReqCount,
                                  selected: _active(
                                    '/super-admin/requests/product',
                                  ),
                                  onTap: () =>
                                      _go('/super-admin/requests/product'),
                                ),
                                _FlyoutItem(
                                  icon: Icons.group_add_outlined,
                                  label: 'Requested buyers',
                                  badge: buyerReqCount,
                                  selected: _active(
                                    '/super-admin/requests/buyer',
                                  ),
                                  onTap: () =>
                                      _go('/super-admin/requests/buyer'),
                                ),
                                _FlyoutItem(
                                  icon: Icons.track_changes_outlined,
                                  label: "Request's Tracking Logs",
                                  selected: _active(
                                    '/super-admin/request-tracking',
                                  ),
                                  onTap: () =>
                                      _go('/super-admin/request-tracking'),
                                ),
                                _FlyoutItem(
                                  icon: Icons.groups_outlined,
                                  label: 'Transporter Driver limits',
                                  selected: _active(
                                    '/super-admin/driver-limits',
                                  ),
                                  onTap: () =>
                                      _go('/super-admin/driver-limits'),
                                ),
                              ],
                            ),
                          if (expanded && _requests) ...[
                            _NavTile(
                              expanded: expanded,
                              icon: Icons.factory_outlined,
                              label: 'Mine/Supplier transport',
                              badge: mineTransportCount,
                              selected: _active(
                                '/super-admin/requests/transportation-mine',
                              ),
                              indent: expanded ? 12 : 0,
                              onTap: () => _go(
                                '/super-admin/requests/transportation-mine',
                              ),
                            ),
                            _NavTile(
                              expanded: expanded,
                              icon: Icons.alt_route_outlined,
                              label: 'Buyer transport',
                              badge: buyerTransportCount,
                              selected: _active(
                                '/super-admin/requests/transportation-buyer',
                              ),
                              indent: expanded ? 12 : 0,
                              onTap: () => _go(
                                '/super-admin/requests/transportation-buyer',
                              ),
                            ),
                            _NavTile(
                              expanded: expanded,
                              icon: Icons.inventory_2_outlined,
                              label: 'Requested product',
                              badge: productReqCount,
                              selected: _active(
                                '/super-admin/requests/product',
                              ),
                              indent: expanded ? 12 : 0,
                              onTap: () => _go('/super-admin/requests/product'),
                            ),
                            _NavTile(
                              expanded: expanded,
                              icon: Icons.group_add_outlined,
                              label: 'Requested buyers',
                              badge: buyerReqCount,
                              selected: _active('/super-admin/requests/buyer'),
                              indent: expanded ? 12 : 0,
                              onTap: () => _go('/super-admin/requests/buyer'),
                            ),
                            _NavTile(
                              expanded: expanded,
                              icon: Icons.track_changes_outlined,
                              label: "Request's Tracking Logs",
                              selected: _active(
                                '/super-admin/request-tracking',
                              ),
                              indent: expanded ? 12 : 0,
                              onTap: () => _go('/super-admin/request-tracking'),
                            ),
                            _NavTile(
                              expanded: expanded,
                              icon: Icons.groups_outlined,
                              label: 'Transporter Driver limits',
                              selected: _active('/super-admin/driver-limits'),
                              indent: expanded ? 12 : 0,
                              onTap: () => _go('/super-admin/driver-limits'),
                            ),
                          ],
                          _NavTile(
                            expanded: expanded,
                            icon: Icons.receipt_long_outlined,
                            label: 'Margin ledger History',
                            selected: _active('/super-admin/margin-ledger'),
                            onTap: () => _go('/super-admin/margin-ledger'),
                          ),
                          _NavTile(
                            expanded: expanded,
                            icon: Icons.table_rows_outlined,
                            label: 'Recon tables',
                            selected: _active('/super-admin/recon-tables'),
                            onTap: () => _go('/super-admin/recon-tables'),
                          ),
                          _NavTile(
                            expanded: expanded,
                            icon: Icons.gavel_outlined,
                            label: 'Disputes',
                            selected: _active('/super-admin/disputes'),
                            onTap: () => _go('/super-admin/disputes'),
                          ),
                          _NavTile(
                            expanded: expanded,
                            icon: Icons.alt_route_outlined,
                            label: 'Available routes',
                            selected: _active('/super-admin/available-routes'),
                            onTap: () => _go('/super-admin/available-routes'),
                          ),
                          _NavTile(
                            expanded: expanded,
                            icon: Icons.storefront_outlined,
                            label: 'Route marketplace',
                            selected: _active('/super-admin/route-marketplace'),
                            onTap: () => _go('/super-admin/route-marketplace'),
                          ),
                          _NavTile(
                            expanded: expanded,
                            icon: Icons.hub_outlined,
                            label: 'Chat links',
                            selected: _active('/super-admin/chat-links'),
                            onTap: () => _go('/super-admin/chat-links'),
                          ),
                          _NavTile(
                            expanded: expanded,
                            icon: Icons.gps_fixed_rounded,
                            label: 'Live map',
                            selected: _active('/super-admin/live-map'),
                            onTap: () => _go('/super-admin/live-map'),
                          ),
                        ],
                      ),
                    ),
                    // ── Utility section, pinned to the bottom of the rail
                    // (design uses a flex spacer to push these down). ──
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            height: 1,
                            margin: const EdgeInsets.fromLTRB(2, 4, 2, 6),
                            color: sb.div,
                          ),
                          _NavTile(
                            expanded: expanded,
                            icon: Icons.notifications_outlined,
                            label: 'Notifications',
                            selected: _active(
                              NotificationsInboxRoute.superAdminPath,
                            ),
                            onTap: () =>
                                _go(NotificationsInboxRoute.superAdminPath),
                          ),
                          _NavTile(
                            expanded: expanded,
                            icon: Icons.info_outline_rounded,
                            label: 'About',
                            selected: false,
                            onTap: () => showAboutDialog(
                              context: context,
                              applicationName: 'MineLink',
                              applicationVersion: 'Super Admin Console',
                            ),
                          ),
                          if (expanded)
                            _NavGroup(
                              icon: Icons.settings_outlined,
                              label: 'Settings',
                              open: _settings,
                              active:
                                  _active('/super-admin/account-security') ||
                                  _active('/super-admin/preferences') ||
                                  _active('/super-admin/settings'),
                              onToggle: () =>
                                  setState(() => _settings = !_settings),
                            )
                          else
                            _CollapsedNavGroup(
                              icon: Icons.settings_outlined,
                              label: 'Settings',
                              active:
                                  _active('/super-admin/account-security') ||
                                  _active('/super-admin/preferences') ||
                                  _active('/super-admin/settings'),
                              items: [
                                _FlyoutItem(
                                  icon: Icons.lock_outline_rounded,
                                  label: 'Account security',
                                  selected: _active(
                                    '/super-admin/account-security',
                                  ),
                                  onTap: () =>
                                      _go('/super-admin/account-security'),
                                ),
                                _FlyoutItem(
                                  icon: Icons.palette_outlined,
                                  label: 'User Preferences',
                                  selected: _active('/super-admin/preferences'),
                                  onTap: () => _go('/super-admin/preferences'),
                                ),
                                _FlyoutItem(
                                  icon: Icons.tune_rounded,
                                  label: 'Platform settings',
                                  selected: _active('/super-admin/settings'),
                                  onTap: () => _go('/super-admin/settings'),
                                ),
                              ],
                            ),
                          if (expanded && _settings) ...[
                            _NavTile(
                              expanded: expanded,
                              icon: Icons.lock_outline_rounded,
                              label: 'Account security',
                              selected: _active(
                                '/super-admin/account-security',
                              ),
                              indent: expanded ? 12 : 0,
                              onTap: () => _go('/super-admin/account-security'),
                            ),
                            _NavTile(
                              expanded: expanded,
                              icon: Icons.palette_outlined,
                              label: 'User Preferences',
                              selected: _active('/super-admin/preferences'),
                              indent: expanded ? 12 : 0,
                              onTap: () => _go('/super-admin/preferences'),
                            ),
                            _NavTile(
                              expanded: expanded,
                              icon: Icons.tune_rounded,
                              label: 'Platform settings',
                              selected: _active('/super-admin/settings'),
                              indent: expanded ? 12 : 0,
                              onTap: () => _go('/super-admin/settings'),
                            ),
                          ],
                        ],
                      ),
                    ),
                    _SidebarFooter(
                      expanded: expanded,
                      onCollapse: widget.onToggleRailExpanded,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Expandable sidebar group header with an optional count badge and a
/// disclosure chevron (design's grouped nav: Tokens & Seats, Requests…).
class _NavGroup extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool open;
  final bool active;
  final int? badge;
  final VoidCallback onToggle;
  const _NavGroup({
    required this.icon,
    required this.label,
    required this.open,
    required this.active,
    required this.onToggle,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    final sb = MlRailTokens.of(context);
    // Design: a group header only takes the "selected" look when it is closed
    // AND contains the active route (open groups stay neutral).
    final hi = active && !open;
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Material(
        color: hi ? sb.tileSelBg : Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: hi ? BorderSide(color: sb.tileSelBd) : BorderSide.none,
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          hoverColor: sb.hover,
          onTap: onToggle,
          child: Container(
            decoration: hi
                ? BoxDecoration(
                    border: Border(
                      left: BorderSide(color: sb.accent, width: 3),
                    ),
                  )
                : null,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Icon(icon, color: hi ? sb.inkStrong : sb.ink, size: 21),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: hi ? sb.inkStrong : sb.ink,
                      fontWeight: FontWeight.w600,
                      fontSize: 14.5,
                    ),
                  ),
                ),
                if (badge != null && badge! > 0) ...[
                  _NavBadge(count: badge!),
                  const SizedBox(width: 8),
                ],
                Icon(
                  open ? Icons.expand_less : Icons.expand_more,
                  color: sb.inkFaint,
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One row inside a collapsed-rail group flyout.
class _FlyoutItem {
  final IconData icon;
  final String label;
  final int? badge;
  final bool selected;
  final VoidCallback onTap;
  const _FlyoutItem({
    required this.icon,
    required this.label,
    this.badge,
    required this.selected,
    required this.onTap,
  });
}

/// Collapsed-rail counterpart of [_NavGroup]: a single icon tile in the same
/// position as the expanded group header, marked with a small chevron so it
/// reads as a dropdown. Hovering OR clicking it opens a flyout with the
/// group's children, so the collapsed rail mirrors the expanded dropdowns
/// one-for-one instead of flattening every child into the rail.
class _CollapsedNavGroup extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool active;
  final int? badge;
  final List<_FlyoutItem> items;
  const _CollapsedNavGroup({
    required this.icon,
    required this.label,
    required this.active,
    this.badge,
    required this.items,
  });

  @override
  State<_CollapsedNavGroup> createState() => _CollapsedNavGroupState();
}

class _CollapsedNavGroupState extends State<_CollapsedNavGroup> {
  final LayerLink _link = LayerLink();
  OverlayEntry? _entry;
  Timer? _closeTimer;
  bool _overTile = false;
  bool _overMenu = false;

  @override
  void dispose() {
    _closeTimer?.cancel();
    _removeEntry();
    super.dispose();
  }

  void _removeEntry() {
    _entry?.remove();
    _entry = null;
  }

  /// Close shortly after the pointer leaves both the tile and the flyout —
  /// the grace period lets the cursor travel across the gap between them.
  void _scheduleClose() {
    _closeTimer?.cancel();
    _closeTimer = Timer(const Duration(milliseconds: 220), () {
      if (!_overTile && !_overMenu) _removeEntry();
    });
  }

  void _show() {
    if (_entry != null) return;
    final sb = MlRailTokens.of(context);
    _entry = OverlayEntry(
      builder: (_) => Positioned(
        width: 252,
        child: CompositedTransformFollower(
          link: _link,
          showWhenUnlinked: false,
          targetAnchor: Alignment.topRight,
          followerAnchor: Alignment.topLeft,
          offset: const Offset(8, -4),
          child: MouseRegion(
            onEnter: (_) {
              _overMenu = true;
              _closeTimer?.cancel();
            },
            onExit: (_) {
              _overMenu = false;
              _scheduleClose();
            },
            child: Material(
              color: sb.flyoutBg,
              elevation: 10,
              shadowColor: mlRailFlyoutShadow,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(color: sb.border),
              ),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
                      child: Text(
                        widget.label.toUpperCase(),
                        style: TextStyle(
                          fontFamily: mlConsoleSans,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.1,
                          color: sb.inkFaint,
                        ),
                      ),
                    ),
                    for (final it in widget.items)
                      InkWell(
                        borderRadius: BorderRadius.circular(10),
                        hoverColor: sb.tileSelBg,
                        onTap: () {
                          _removeEntry();
                          it.onTap();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 9,
                          ),
                          decoration: it.selected
                              ? BoxDecoration(
                                  color: sb.tileSelBg,
                                  borderRadius: BorderRadius.circular(10),
                                )
                              : null,
                          child: Row(
                            children: [
                              Icon(
                                it.icon,
                                size: 18,
                                color: it.selected ? sb.inkStrong : sb.ink,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  it.label,
                                  style: TextStyle(
                                    fontFamily: mlConsoleSans,
                                    fontSize: 13.5,
                                    fontWeight: it.selected
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    color: it.selected ? sb.inkStrong : sb.ink,
                                  ),
                                ),
                              ),
                              if ((it.badge ?? 0) > 0) ...[
                                const SizedBox(width: 10),
                                _NavBadge(count: it.badge!),
                              ],
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    Overlay.of(context).insert(_entry!);
  }

  @override
  Widget build(BuildContext context) {
    final sb = MlRailTokens.of(context);
    return CompositedTransformTarget(
      link: _link,
      child: MouseRegion(
        onEnter: (_) {
          _overTile = true;
          _closeTimer?.cancel();
          _show();
        },
        onExit: (_) {
          _overTile = false;
          _scheduleClose();
        },
        child: Padding(
          padding: const EdgeInsets.only(bottom: 3),
          child: Material(
            color: widget.active ? sb.tileSelBg : Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: widget.active
                  ? BorderSide(color: sb.tileSelBd)
                  : BorderSide.none,
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              hoverColor: sb.hover,
              onTap: () => _entry == null ? _show() : _removeEntry(),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 10,
                ),
                child: Center(
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Icon(
                        widget.icon,
                        color: widget.active ? sb.inkStrong : sb.ink,
                        size: 21,
                      ),
                      // Dropdown affordance: a small chevron marks this icon
                      // as a group that opens a flyout.
                      Positioned(
                        right: -11,
                        top: 3,
                        child: Icon(
                          Icons.chevron_right_rounded,
                          size: 14,
                          color: sb.inkFaint,
                        ),
                      ),
                      // Count carries over as a small accent dot so the badge
                      // information isn't lost when the rail is collapsed.
                      if ((widget.badge ?? 0) > 0)
                        Positioned(
                          right: -5,
                          top: -6,
                          child: Container(
                            width: 9,
                            height: 9,
                            decoration: BoxDecoration(
                              color: MlTokens.accent,
                              shape: BoxShape.circle,
                              border: Border.all(color: sb.solid, width: 1.5),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Small cyan pill count badge used on nav rows (design: accent bg, dark text).
class _NavBadge extends StatelessWidget {
  final int count;
  const _NavBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 20),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: MlTokens.accent,
        borderRadius: BorderRadius.all(Radius.circular(999)),
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        style: const TextStyle(
          color: MlTokens.inkOnAccent,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

/// Sidebar brand header: the official MineLink Technologies logo (transparent
/// background, as supplied) with "SUPER ADMIN CONSOLE" beneath and a boxed
/// collapse control top-right.
class _SidebarHeader extends StatelessWidget {
  final bool expanded;
  final VoidCallback? onToggleRailExpanded;
  const _SidebarHeader({required this.expanded, this.onToggleRailExpanded});

  Widget _collapseBtn(MlRailTokens sb) {
    return Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: sb.btnBg,
        border: Border.all(color: sb.btnBd),
      ),
      child: IconButton(
        padding: EdgeInsets.zero,
        iconSize: 16,
        style: IconButton.styleFrom(foregroundColor: sb.inkMuted),
        icon: Icon(
          expanded ? Icons.chevron_left_rounded : Icons.chevron_right_rounded,
        ),
        onPressed: onToggleRailExpanded,
        tooltip: expanded ? 'Collapse sidebar' : 'Expand sidebar',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sb = MlRailTokens.of(context);
    if (!expanded) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(8, 20, 8, 12),
        child: Column(
          children: [
            if (onToggleRailExpanded != null) _collapseBtn(sb),
            const SizedBox(height: 12),
            // Brand mark per theme: black/gold chain on the light rail,
            // white/gold on navy (design `.ml-logo-light/-dark` swap).
            MineLinkMark(size: 38, onDark: sb.dark),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 22, 16, 14),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Brand lockup per theme (design `.ml-logo-light/-dark` swap).
              MineLinkLogo(height: 92, onDark: sb.dark),
              const SizedBox(height: 8),
              RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: 'SUPER',
                      style: TextStyle(
                        fontFamily: mlConsoleSans,
                        color: sb.inkStrong,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.4,
                      ),
                    ),
                    TextSpan(
                      text: ' ADMIN CONSOLE',
                      style: TextStyle(
                        fontFamily: mlConsoleSans,
                        color: sb.inkFaint,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (onToggleRailExpanded != null)
            Positioned(top: -2, right: 0, child: _collapseBtn(sb)),
        ],
      ),
    );
  }
}

/// Sidebar search entry — visual field mirroring the design; opens the
/// organizations list where company/user search lives.
class _SidebarSearch extends StatelessWidget {
  final VoidCallback onTap;
  const _SidebarSearch({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final sb = MlRailTokens.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 11),
        decoration: BoxDecoration(
          color: sb.searchBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: sb.searchBd),
        ),
        child: Row(
          children: [
            Icon(Icons.search, size: 16, color: sb.inkMuted),
            const SizedBox(width: 8),
            Text(
              'Search…',
              style: TextStyle(fontSize: 12.5, color: sb.inkMuted),
            ),
          ],
        ),
      ),
    );
  }
}

/// Sidebar footer: Logout action and the signed-in admin's identity (design's
/// bottom profile block).
class _SidebarFooter extends ConsumerWidget {
  final bool expanded;
  final VoidCallback? onCollapse;
  const _SidebarFooter({required this.expanded, this.onCollapse});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sb = MlRailTokens.of(context);
    final user = ref.watch(authStateProvider).user;
    final email = user?.email ?? '';
    final metaName = user?.userMetadata?['full_name'] as String?;
    final name = (metaName != null && metaName.trim().isNotEmpty)
        ? metaName.trim()
        : (email.contains('@') ? email.split('@').first : 'Super Admin');
    final initials = name
        .trim()
        .split(RegExp(r'[\s.]+'))
        .where((e) => e.isNotEmpty)
        .take(2)
        .map((e) => e[0])
        .join()
        .toUpperCase();

    final avatar = SizedBox(
      width: 38,
      height: 38,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [mlRailAccent, MlTokens.accent]),
              shape: BoxShape.circle,
            ),
            child: Text(
              initials.isEmpty ? 'A' : initials,
              style: const TextStyle(
                color: MlTokens.inkOnFill,
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
          ),
          // online dot
          Positioned(
            right: -1,
            bottom: -1,
            child: Container(
              width: 11,
              height: 11,
              decoration: BoxDecoration(
                color: MlTokens.green500,
                shape: BoxShape.circle,
                border: Border.all(color: sb.solid, width: 2),
              ),
            ),
          ),
        ],
      ),
    );

    Widget pill({
      required IconData icon,
      required String label,
      required Color color,
      VoidCallback? onTap,
    }) {
      return Material(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(11),
        child: InkWell(
          borderRadius: BorderRadius.circular(11),
          onTap: onTap,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 11),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(11),
              border: Border.all(color: color.withValues(alpha: 0.28)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: color, size: 18),
                if (expanded) ...[
                  const SizedBox(width: 9),
                  Text(
                    label,
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w700,
                      fontSize: 13.5,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          pill(
            icon: Icons.logout_rounded,
            label: 'Logout',
            color: MlTokens.orange500,
            onTap: () => LogoutService.logoutWithConfirmation(context, ref),
          ),
          if (onCollapse != null && expanded) ...[
            const SizedBox(height: 8),
            pill(
              icon: Icons.chevron_left_rounded,
              label: 'Collapse',
              color: sb.cbtnFg,
              onTap: onCollapse,
            ),
          ],
          const SizedBox(height: 12),
          Container(
            height: 1,
            color: sb.div,
            margin: const EdgeInsets.only(bottom: 12),
          ),
          // Hover shows the identity card (full address, role, quick
          // actions); the click itself still goes straight to the profile, so
          // nothing that worked before needs a second step. The Tooltip is
          // gone — it and the card would fire on the same hover.
          UserIdentityFlyout(
            user: UserIdentity(
              name: name,
              email: email,
              roleLabel: 'Super Admin',
            ),
            accent: MlTokens.accent,
            onOpenProfile: () => context.go('/super-admin/account-security'),
            actions: [
              UserIdentityAction(
                icon: Icons.shield_outlined,
                label: 'Profile & account security',
                onTap: () => context.go('/super-admin/account-security'),
              ),
              UserIdentityAction(
                icon: Icons.tune_rounded,
                label: 'User preferences',
                onTap: () => context.go('/super-admin/preferences'),
              ),
              UserIdentityAction(
                icon: Icons.logout_rounded,
                label: 'Sign out',
                onTap: () => LogoutService.logoutWithConfirmation(context, ref),
                danger: true,
              ),
            ],
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(11),
              child: InkWell(
                borderRadius: BorderRadius.circular(11),
                hoverColor: sb.hover,
                onTap: () => context.go('/super-admin/account-security'),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 4,
                  ),
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
                                  Text(
                                    name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: sb.inkStrong,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                    ),
                                  ),
                                  Text(
                                    email,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: sb.inkMuted,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        )
                      : avatar,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  final bool expanded;
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final double indent;
  final int? badge;

  const _NavTile({
    required this.expanded,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.indent = 0,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    final sb = MlRailTokens.of(context);
    final indented = indent > 0;
    final bg = selected
        ? (indented ? sb.tileSelBgSub : sb.tileSelBg)
        : Colors.transparent;
    final tile = Padding(
      padding: EdgeInsets.only(left: indent),
      child: Material(
        color: bg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: (selected && !indented)
              ? BorderSide(color: sb.tileSelBd)
              : BorderSide.none,
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          hoverColor: sb.hover,
          onTap: onTap,
          child: Container(
            decoration: (selected && !indented)
                ? BoxDecoration(
                    border: Border(
                      left: BorderSide(color: sb.accent, width: 3),
                    ),
                  )
                : null,
            padding: EdgeInsets.symmetric(
              horizontal: expanded ? 12 : 6,
              vertical: 10,
            ),
            child: Row(
              mainAxisAlignment: expanded
                  ? MainAxisAlignment.start
                  : MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  color: selected ? sb.inkStrong : sb.ink,
                  size: indented ? 18 : 21,
                ),
                if (expanded) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        color: selected ? sb.inkStrong : sb.ink,
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.w500,
                        fontSize: indented ? 13.5 : 14.5,
                      ),
                    ),
                  ),
                  if (badge != null && badge! > 0) _NavBadge(count: badge!),
                ],
              ],
            ),
          ),
        ),
      ),
    );
    if (!expanded) {
      return Tooltip(
        message: label,
        waitDuration: const Duration(milliseconds: 400),
        child: tile,
      );
    }
    return tile;
  }
}

/// Top-bar quick search — visual entry point that opens the organizations
/// list (companies/users search lives there). Mirrors the design's ⌘K field.
class _TopBarSearch extends StatelessWidget {
  final VoidCallback onTap;
  const _TopBarSearch({required this.onTap});

  // Design HeaderActions: #657795 search ink in both themes.
  static const _searchInk = mlRailSearchInk;

  @override
  Widget build(BuildContext context) {
    final s = MlSemantic.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(11),
      onTap: onTap,
      child: Container(
        width: 280,
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: s.surfaceApp,
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: s.borderStrong),
        ),
        child: Row(
          children: [
            const Icon(Icons.search, size: 16, color: _searchInk),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Search companies, users, requests...',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: mlConsoleSans,
                  fontSize: 12.5,
                  color: _searchInk,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                border: Border.all(color: s.borderStrong),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                '⌘K',
                style: TextStyle(
                  fontFamily: MlTokens.fontMono,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: _searchInk,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A small green "Live" status pill for the top bar.
class _LivePill extends StatelessWidget {
  const _LivePill();

  @override
  Widget build(BuildContext context) {
    // Design: status-done bg/fg tokens, #22C55E dot, 12.5/700, 7×13 padding.
    final tone = MlTone.done.colors(Theme.of(context).brightness);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
      decoration: BoxDecoration(
        color: tone.bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _PulseDot(color: MlTokens.green500),
          const SizedBox(width: 6),
          Text(
            'Live',
            style: TextStyle(
              fontFamily: mlConsoleSans,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: tone.fg,
            ),
          ),
        ],
      ),
    );
  }
}

class _PulseDot extends StatelessWidget {
  final Color color;
  const _PulseDot({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
