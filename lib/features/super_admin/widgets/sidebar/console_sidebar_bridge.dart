import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:flutter_application_1/core/routing/notifications_inbox_route.dart';
import 'package:flutter_application_1/features/auth/providers/auth_state.dart';
import 'package:flutter_application_1/features/auth/services/logout_service.dart';
import 'package:flutter_application_1/features/notifications/providers/notification_provider.dart';
import 'package:flutter_application_1/features/portal/providers/request_provider.dart';
import 'package:flutter_application_1/core/design/tokens/ui_prefs.dart';
import 'package:flutter_application_1/core/widgets/user_identity_flyout.dart';
import 'package:flutter_application_1/features/super_admin/providers/super_admin_providers.dart';

import 'console_palette_tokens.dart';
import 'minelink_sidebar_app.dart';
import 'minelink_sidebar_core.dart';
import 'minelink_sidebar_haul.dart';
import 'minelink_sidebar_weighbridge.dart';

/// Glue between the vendored sidebar skins ([HaulSidebar],
/// [WeighbridgeSidebar]) and this app: nav ids ↔ go_router paths, live badge
/// counts, the signed-in admin, and sign-out.
///
/// The skins own no routing knowledge — they emit an id, this file decides
/// where it goes. Routes are NOT changed by any of this; only the navigation
/// chrome is.

/// Nav id → console route. Ids absent from this map either have no
/// destination of their own (group parents open their children) or are handled
/// as an action — currently only `about`, which opens the about dialog.
const Map<String, String> consoleNavRoutes = <String, String>{
  'dashboard': '/super-admin',
  'insights.transporters': '/super-admin/insights/transporter',
  'insights.buyers': '/super-admin/insights/buyer',
  'insights.mines': '/super-admin/insights/mineSupplier',
  'insights.targets': '/super-admin/targets',
  'insights.targets-org-type': '/super-admin/targets/org-type',
  'insights.targets-company': '/super-admin/targets/company',
  'tokens.organizations': '/super-admin/organizations',
  'tokens.requests': '/super-admin/token-requests',
  'tokens.history': '/super-admin/token-history',
  'tokens.audit': '/super-admin/audit-logs',
  'platform.crashReports': '/super-admin/crash-reports',
  'platform.accountDeactivations': '/super-admin/account-deactivations',
  // The transportation inbox is split by requesting-org type; these are the
  // canonical paths (`/requests/mine-transport` is only a redirect alias).
  'requests.mine-transport': '/super-admin/requests/transportation-mine',
  'requests.buyer-transport': '/super-admin/requests/transportation-buyer',
  'requests.product': '/super-admin/requests/product',
  'requests.buyers': '/super-admin/requests/buyer',
  'requests.tracking-logs': '/super-admin/request-tracking',
  'requests.driver-limits': '/super-admin/driver-limits',
  'margin-ledger': '/super-admin/margin-ledger',
  'recon-tables': '/super-admin/recon-tables',
  'disputes': '/super-admin/disputes',
  'routes-available': '/super-admin/available-routes',
  'route-marketplace': '/super-admin/route-marketplace',
  'chat-links': '/super-admin/chat-links',
  'live-map': '/super-admin/live-map',
  'notifications': NotificationsInboxRoute.superAdminPath,
  'settings.security': '/super-admin/account-security',
  'settings.preferences': '/super-admin/preferences',
  'settings.platform': '/super-admin/settings',
};

/// Ids that deliberately have no route: expandable group parents, plus
/// `about` (an action, not a destination).
const Set<String> consoleNavActionOrGroupIds = <String>{
  'insights',
  'tokens',
  'requests',
  'settings',
  'about',
};

bool _isUnder(String location, String prefix) =>
    location == prefix || location.startsWith('$prefix/');

/// Which nav id the current router location represents, so the skin can mark
/// the active row. Falls back to `dashboard` on the console root and to an
/// empty id (nothing highlighted) on a route outside the tree.
String consoleNavIdForLocation(String location) {
  if (location == '/super-admin') return 'dashboard';

  // Longest-prefix-wins: check the alias forms and the deeper paths first so
  // e.g. `/requests/buyer-transport` never matches `/requests/buyer`.
  const ordered = <String, String>{
    '/super-admin/requests/transportation-mine': 'requests.mine-transport',
    '/super-admin/requests/mine-transport': 'requests.mine-transport',
    '/super-admin/requests/transportation-buyer': 'requests.buyer-transport',
    '/super-admin/requests/buyer-transport': 'requests.buyer-transport',
    '/super-admin/requests/product': 'requests.product',
    '/super-admin/requests/buyer': 'requests.buyers',
    '/super-admin/request-tracking': 'requests.tracking-logs',
    '/super-admin/driver-limits': 'requests.driver-limits',
    '/super-admin/insights/transporter': 'insights.transporters',
    '/super-admin/insights/buyer': 'insights.buyers',
    '/super-admin/insights/mineSupplier': 'insights.mines',
    // The two scoped targets screens sit *under* `/targets`, so they have to
    // be tested before it or every one of them highlights the platform row.
    '/super-admin/targets/org-type': 'insights.targets-org-type',
    '/super-admin/targets/company': 'insights.targets-company',
    '/super-admin/targets': 'insights.targets',
    '/super-admin/organizations': 'tokens.organizations',
    '/super-admin/token-requests': 'tokens.requests',
    '/super-admin/token-history': 'tokens.history',
    '/super-admin/audit-logs': 'tokens.audit',
    '/super-admin/crash-reports': 'platform.crashReports',
    '/super-admin/account-deactivations': 'platform.accountDeactivations',
    '/super-admin/margin-ledger': 'margin-ledger',
    '/super-admin/recon-tables': 'recon-tables',
    '/super-admin/disputes': 'disputes',
    '/super-admin/available-routes': 'routes-available',
    '/super-admin/route-marketplace': 'route-marketplace',
    '/super-admin/chat-links': 'chat-links',
    '/super-admin/live-map': 'live-map',
    '/super-admin/account-security': 'settings.security',
    '/super-admin/preferences': 'settings.preferences',
    '/super-admin/settings': 'settings.platform',
    '/super-admin/notifications': 'notifications',
  };

  for (final entry in ordered.entries) {
    if (_isUnder(location, entry.key)) return entry.value;
  }
  return '';
}

/// Rail width for the chosen skin — the Drawer needs a concrete number in
/// narrow layouts (in wide layouts the skin sizes itself inside the Row).
///
/// Both palettes of a layout are the same width: the MineLink variants
/// `copyWith` colours only, so geometry comes from the drop's own tokens.
double consoleSidebarWidth(
  ConsoleSidebarSkin skin, {
  required bool collapsed,
  double? windowWidth,
}) {
  if (skin.isApp) {
    // The app rail forces itself collapsed below its compact breakpoint, so
    // the width reported here has to agree — otherwise the drawer hosting it
    // reserves 260px for a 68px rail and leaves dead space beside it.
    final forcedCompact = windowWidth != null &&
        windowWidth < MlSidebarMetrics.compactBreakpoint;
    return (collapsed || forcedCompact)
        ? MlSidebarMetrics.collapsedWidth
        : MlSidebarMetrics.expandedWidth;
  }
  if (skin.isHaul) {
    // Haul detaches into a floating capsule: rail + its 10px margin a side.
    return collapsed
        ? HaulTokens.dark.railWidth + 20
        : HaulTokens.dark.expandedWidth;
  }
  if (skin.isWeighbridge) {
    return collapsed
        ? WeighbridgeTokens.light.railWidth
        : WeighbridgeTokens.light.expandedWidth;
  }
  return collapsed ? 78 : 274;
}

/// Renders the chosen alternate skin, fed with real routes, counts and user.
///
/// Handles all four drop-derived skins (both layouts × both palettes); the
/// classic rail stays in `super_admin_shell_layout.dart`, which decides which
/// of the five to build.
class ConsoleSkinSidebar extends ConsumerWidget {
  final ConsoleSidebarSkin skin;
  final String location;
  final bool collapsed;
  final ValueChanged<bool> onCollapsedChanged;

  const ConsoleSkinSidebar({
    super.key,
    required this.skin,
    required this.location,
    required this.collapsed,
    required this.onCollapsedChanged,
  });

  /// Live counts, keyed by nav id. A key is only present when its count is
  /// above zero — the skins render "no key" as no badge, and a row of zeroes
  /// is noise.
  Map<String, int> _badges(WidgetRef ref) {
    final stats = ref.watch(dashboardStatsProvider).valueOrNull;
    final orgCount = (stats?['totalCompanies'] as int?) ?? 0;
    final tokenCount = (stats?['openTokenRequests'] as int?) ?? 0;

    // Sidebar badges count work WAITING, so `awaitingReview` only -- the raw
    // list carries approved, linked and declined requests for the inbox's
    // history and counting those made every request ever raised look
    // outstanding (P9-02).
    final transportationReqs =
        (ref.watch(adminRequestQueueProvider('transportation')).valueOrNull ??
                const [])
            .where((r) => r.status.awaitingReview)
            .toList();
    final mineTransport = transportationReqs.where((r) => r.isFromMine).length;
    final buyerTransport = transportationReqs.where((r) => !r.isFromMine).length;
    final product = ref.watch(adminPendingRequestCountProvider('product')) ?? 0;
    final buyers = ref.watch(adminPendingRequestCountProvider('buyer')) ?? 0;

    final out = <String, int>{};
    void put(String id, int count) {
      if (count > 0) out[id] = count;
    }

    put('tokens.organizations', orgCount);
    put('tokens.requests', tokenCount);
    put('tokens', tokenCount);
    put('requests.mine-transport', mineTransport);
    put('requests.buyer-transport', buyerTransport);
    put('requests.product', product);
    put('requests.buyers', buyers);
    put('requests', mineTransport + buyerTransport + product + buyers);
    // The app rail shows a count on Notifications; feed it the real unread
    // figure the bell already uses rather than leaving it blank.
    put('notifications', ref.watch(notificationProvider).unreadCount);
    return out;
  }

  void _select(BuildContext context, String id) {
    if (id == 'about') {
      Scaffold.maybeOf(context)?.closeDrawer();
      showAboutDialog(
        context: context,
        applicationName: 'MineLink',
        applicationVersion: 'Super Admin Console',
      );
      return;
    }
    final path = consoleNavRoutes[id];
    if (path == null) return;
    context.go(path);
    Scaffold.maybeOf(context)?.closeDrawer();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authUser = ref.watch(authStateProvider).user;
    final email = authUser?.email ?? '';
    final metaName = authUser?.userMetadata?['full_name'] as String?;
    final name = (metaName != null && metaName.trim().isNotEmpty)
        ? metaName.trim()
        : (email.contains('@') ? email.split('@').first : 'Super Admin');

    final badges = _badges(ref);
    final selectedId = consoleNavIdForLocation(location);
    void onSelect(String id) => _select(context, id);
    void onLogout() => LogoutService.logoutWithConfirmation(context, ref);

    // Where "their profile" is for a platform admin. NOT `/profile`: that
    // screen is built around a company and an employee record, and a super
    // admin has neither — it would render the portal shell over a page of
    // empty company fields. `/super-admin/account-security` is the surface
    // that actually holds this person's own account (password, sessions,
    // signature, deactivation), and it is already where the classic rail's
    // chip goes, so all four skins now agree.
    void openProfile() {
      context.go(consoleNavRoutes['settings.security']!);
      Scaffold.maybeOf(context)?.closeDrawer();
    }

    final user = MlSidebarUser(
      name: name,
      email: email,
      roleLabel: 'Super Admin',
      onOpenProfile: openProfile,
      actions: [
        UserIdentityAction(
          icon: Icons.shield_outlined,
          label: 'Profile & account security',
          onTap: openProfile,
        ),
        UserIdentityAction(
          icon: Icons.tune_rounded,
          label: 'User preferences',
          onTap: () => _select(context, 'settings.preferences'),
        ),
        UserIdentityAction(
          icon: Icons.logout_rounded,
          label: 'Sign out',
          onTap: onLogout,
          danger: true,
        ),
      ],
    );

    // Null for the gold originals — those resolve their own palette from the
    // theme brightness. The MineLink variants get app-token colours built
    // around the admin's chosen accent.
    final tokens = MlPaletteSidebarTokens.forSkin(
      skin,
      dark: Theme.of(context).brightness == Brightness.dark,
      accent: ref.watch(uiPrefsProvider.select((p) => p.accent)),
    );

    if (skin.isApp) {
      return MineLinkAppSidebar(
        selectedId: selectedId,
        onSelect: onSelect,
        onLogout: onLogout,
        collapsed: collapsed,
        onCollapsedChanged: onCollapsedChanged,
        badges: badges,
        user: user,
      );
    }
    if (skin.isHaul) {
      return HaulSidebar(
        selectedId: selectedId,
        onSelect: onSelect,
        onLogout: onLogout,
        collapsed: collapsed,
        onCollapsedChanged: onCollapsedChanged,
        badges: badges,
        user: user,
        tokens: tokens,
      );
    }
    if (skin.isWeighbridge) {
      return WeighbridgeSidebar(
        selectedId: selectedId,
        onSelect: onSelect,
        onLogout: onLogout,
        collapsed: collapsed,
        onCollapsedChanged: onCollapsedChanged,
        badges: badges,
        user: user,
        tokens: tokens,
      );
    }
    // The classic rail is built by the shell itself; this widget is only
    // constructed for the drop-derived skins.
    return const SizedBox.shrink();
  }
}
