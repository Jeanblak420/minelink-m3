import 'package:flutter/material.dart';

import 'package:flutter_application_1/core/design/nav/ml_nav_node.dart';
import 'package:flutter_application_1/core/routing/notifications_inbox_route.dart';

/// The super-admin console's destination tree.
///
/// Extracted from `super_admin_shell_layout.dart`, where these thirty
/// destinations were a hand-built widget tree written out **twice** — once for
/// the expanded rail and once for the collapsed one — across roughly 570 lines.
/// The two copies had to be kept in step by hand, and a destination added to
/// one and forgotten in the other simply vanished at that width with nothing to
/// catch it.
///
/// As data it is a value: unit-testable, searchable, and renderable by the same
/// [MlNavRail] the portal uses. Adding a destination is now one line that
/// appears at every width by construction.
///
/// ## Two things that were in the old rail and are deliberately not here
///
/// **"Search"** was a nav tile whose `onTap` went to `/super-admin/organizations` —
/// the same address as the "Organizations" tile three rows below it. It was a
/// second entry point to one destination, wearing a magnifying glass. The rail
/// now has a real filter box at the top (`MlNavRail.showSearch`) that searches
/// the tree itself, including nested destinations, which is what the tile
/// looked like it did.
///
/// **"About"** called `showAboutDialog`. It is an action, not a destination —
/// it has no address, nothing can link to it, and the back button cannot
/// return from it. Every leaf in this model carries a route that resolves, and
/// that rule is what keeps dead entries out of navigation by construction. It
/// now lives in the top bar's overflow menu, where the app's other actions are.
List<MlNavNode> consoleNavTree() => <MlNavNode>[
  // Overview — the front page and the platform-wide live map.
  //
  // A group rather than two loose leaves: ruled by jean on 2026-08-22,
  // "none of them shouldn't have a parent, all should have a parent". Both
  // of these answer the same question — what is happening on the platform
  // right now — which is why they are the two that belong together.
  const MlNavNode.group(
    label: 'Overview',
    icon: Icons.dashboard_outlined,
    selectedIcon: Icons.dashboard_rounded,
    children: [
      MlNavNode.leaf(
        label: 'Dashboard',
        icon: Icons.dashboard_outlined,
        selectedIcon: Icons.dashboard_rounded,
        route: '/super-admin',
      ),
      MlNavNode.leaf(
        label: 'Live map',
        icon: Icons.gps_fixed_outlined,
        selectedIcon: Icons.gps_fixed_rounded,
        route: '/super-admin/live-map',
      ),
    ],
  ),

  // ---- Insights ----
  const MlNavNode.group(
    label: 'Insights',
    icon: Icons.insights_outlined,
    selectedIcon: Icons.insights_rounded,
    children: [
      MlNavNode.leaf(
        label: 'Transporters',
        icon: Icons.local_shipping_outlined,
        selectedIcon: Icons.local_shipping_rounded,
        route: '/super-admin/insights/transporter',
      ),
      MlNavNode.leaf(
        label: 'Buyers',
        icon: Icons.shopping_bag_outlined,
        selectedIcon: Icons.shopping_bag_rounded,
        route: '/super-admin/insights/buyer',
      ),
      MlNavNode.leaf(
        label: 'Mines / Suppliers',
        icon: Icons.landscape_outlined,
        selectedIcon: Icons.landscape_rounded,
        route: '/super-admin/insights/mineSupplier',
      ),
      // Targets was MISSING from the classic rail entirely.
      //
      // `/super-admin/targets` is a registered route with a built screen
      // (CLAUDE.md §4 records it as 🟢 Built and says it lives "under
      // Insights"), and `consoleNavRoutes` has mapped its three ids all
      // along — but the default sidebar never listed it. The only ways in
      // were a dashboard tile or switching to one of the alternate sidebar
      // skins. An admin on the default rail could not navigate to the
      // targets console at all.
      //
      // Found by turning the rail into data and diffing the routes it
      // names against the routes the router registers. That is the
      // argument for the model in one line: thirty destinations written
      // out twice by hand hid a missing one; a list did not.
      MlNavNode.leaf(
        label: 'Targets',
        icon: Icons.track_changes_outlined,
        selectedIcon: Icons.track_changes_rounded,
        route: '/super-admin/targets',
      ),
    ],
  ),

  // ---- Requests: the four inboxes, plus their support screens ----
  const MlNavNode.group(
    label: 'Requests',
    icon: Icons.assignment_outlined,
    selectedIcon: Icons.assignment_rounded,
    children: [
      MlNavNode.leaf(
        label: 'Mine/Supplier transport',
        icon: Icons.factory_outlined,
        selectedIcon: Icons.factory_rounded,
        route: '/super-admin/requests/transportation-mine',
        badge: MlNavBadge.pendingRequests,
      ),
      MlNavNode.leaf(
        label: 'Buyer transport',
        icon: Icons.alt_route_outlined,
        selectedIcon: Icons.alt_route_rounded,
        route: '/super-admin/requests/transportation-buyer',
        badge: MlNavBadge.pendingRequests,
      ),
      MlNavNode.leaf(
        label: 'Requested product',
        icon: Icons.inventory_2_outlined,
        selectedIcon: Icons.inventory_2_rounded,
        route: '/super-admin/requests/product',
        badge: MlNavBadge.pendingRequests,
      ),
      MlNavNode.leaf(
        label: 'Requested buyers',
        icon: Icons.group_add_outlined,
        selectedIcon: Icons.group_add_rounded,
        route: '/super-admin/requests/buyer',
        badge: MlNavBadge.pendingRequests,
      ),
      MlNavNode.leaf(
        label: "Request's Tracking Logs",
        icon: Icons.track_changes_outlined,
        selectedIcon: Icons.track_changes_rounded,
        route: '/super-admin/request-tracking',
      ),
      MlNavNode.leaf(
        label: 'Transporter Driver limits',
        icon: Icons.groups_outlined,
        selectedIcon: Icons.groups_rounded,
        route: '/super-admin/driver-limits',
      ),
    ],
  ),

  // ---- Organisations, access and the audit trail ----
  const MlNavNode.group(
    label: 'Tokens & Seats',
    shortLabel: 'Access',
    icon: Icons.vpn_key_outlined,
    selectedIcon: Icons.vpn_key_rounded,
    children: [
      MlNavNode.leaf(
        label: 'Organizations',
        icon: Icons.business_outlined,
        selectedIcon: Icons.business_rounded,
        route: '/super-admin/organizations',
      ),
      MlNavNode.leaf(
        label: 'Token requests',
        icon: Icons.key_outlined,
        selectedIcon: Icons.key_rounded,
        route: '/super-admin/token-requests',
      ),
      MlNavNode.leaf(
        label: 'Token history',
        icon: Icons.timeline_outlined,
        selectedIcon: Icons.timeline_rounded,
        route: '/super-admin/token-history',
      ),
      MlNavNode.leaf(
        label: 'Audit logs',
        icon: Icons.history_outlined,
        selectedIcon: Icons.history_rounded,
        route: '/super-admin/audit-logs',
      ),
      MlNavNode.leaf(
        label: 'Crash reports',
        icon: Icons.bug_report_outlined,
        selectedIcon: Icons.bug_report_rounded,
        route: '/super-admin/crash-reports',
      ),
      MlNavNode.leaf(
        label: 'Account deactivations',
        icon: Icons.person_off_outlined,
        selectedIcon: Icons.person_off_rounded,
        route: '/super-admin/account-deactivations',
      ),
    ],
  ),

  // WAS "the flat, high-traffic destinations" — eight leaves at the
  // same level as the groups around them, which is the shape jean ruled
  // out on 2026-08-22: everything in the sidebar gets a parent.
  //
  // The three group names are the portal's own, so an admin who has just
  // been looking at a company's rail finds the same words here.
  const MlNavNode.group(
    label: 'Reconciliation',
    icon: Icons.balance_outlined,
    selectedIcon: Icons.balance_rounded,
    children: [
      MlNavNode.leaf(
        label: 'Recon tables',
        icon: Icons.table_rows_outlined,
        selectedIcon: Icons.table_rows_rounded,
        route: '/super-admin/recon-tables',
      ),
      MlNavNode.leaf(
        label: 'Margin ledger History',
        shortLabel: 'Margins',
        icon: Icons.receipt_long_outlined,
        selectedIcon: Icons.receipt_long_rounded,
        route: '/super-admin/margin-ledger',
      ),
      MlNavNode.leaf(
        label: 'Disputes',
        icon: Icons.gavel_outlined,
        selectedIcon: Icons.gavel_rounded,
        route: '/super-admin/disputes',
        badge: MlNavBadge.openDisputes,
      ),
    ],
  ),
  const MlNavNode.group(
    label: 'Routes',
    icon: Icons.alt_route_outlined,
    selectedIcon: Icons.alt_route_rounded,
    children: [
      MlNavNode.leaf(
        label: 'Available routes',
        icon: Icons.alt_route_outlined,
        selectedIcon: Icons.alt_route_rounded,
        route: '/super-admin/available-routes',
      ),
      MlNavNode.leaf(
        label: 'Route marketplace',
        icon: Icons.storefront_outlined,
        selectedIcon: Icons.storefront_rounded,
        route: '/super-admin/route-marketplace',
      ),
    ],
  ),
  MlNavNode.group(
    label: 'Communications',
    icon: Icons.campaign_outlined,
    selectedIcon: Icons.campaign_rounded,
    children: [
      const MlNavNode.leaf(
        label: 'Chat links',
        icon: Icons.hub_outlined,
        selectedIcon: Icons.hub_rounded,
        route: '/super-admin/chat-links',
      ),
      MlNavNode.leaf(
        label: 'Notifications',
        icon: Icons.notifications_outlined,
        selectedIcon: Icons.notifications_rounded,
        route: NotificationsInboxRoute.superAdminPath,
        badge: MlNavBadge.unreadNotifications,
      ),
    ],
  ),

  // ---- Settings ----
  const MlNavNode.group(
    label: 'Settings',
    icon: Icons.settings_outlined,
    selectedIcon: Icons.settings_rounded,
    children: [
      MlNavNode.leaf(
        label: 'Account security',
        icon: Icons.lock_outline_rounded,
        selectedIcon: Icons.lock_rounded,
        route: '/super-admin/account-security',
      ),
      MlNavNode.leaf(
        label: 'User Preferences',
        icon: Icons.palette_outlined,
        selectedIcon: Icons.palette_rounded,
        route: '/super-admin/preferences',
      ),
      MlNavNode.leaf(
        label: 'Platform settings',
        icon: Icons.tune_outlined,
        selectedIcon: Icons.tune_rounded,
        route: '/super-admin/settings',
      ),
    ],
  ),
];
