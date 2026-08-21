// ============================================================================
// Portal navigation — the sectioned destination tree (P7-01 … P7-14)
// ----------------------------------------------------------------------------
// This file replaces the *model* half of `portal_navigation.dart`. That file is
// a flat `List<PortalTabItem>` of pre-constructed widgets consumed by a
// `LazyIndexedStack` at the single URL `/home`, which has three consequences
// the client has now reported twice as "the nav menus have the wrong stuff in
// them":
//
//   1. No destination has an address. Deep links, bookmarks, browser
//      back/forward and web refresh cannot work, and the router's own
//      `/portal/*` hierarchy — built separately, as inbound aliases for an
//      external system — is unreachable from the app.
//   2. The list is flat, so there are no sections, no grouping and no
//      collapsed-rail flyouts, and the rail's search box can only match
//      top-level labels.
//   3. Every org type's list ends with employee-roster tabs (`Admin`,
//      `Management`, `Workspace` / `Mine-Supplier`) — including, on a mine, a
//      tab named after the operator's own org type that shows staff.
//
// The model here is deliberately **pure data**: no widgets, no providers, no
// `BuildContext`. A tree is a value, so it can be unit-tested outright, and the
// router's role guard can read the same tree the rail renders rather than
// keeping a second copy of the role model in sync by hand (P7-07 / P4-09 —
// today those two disagree).
//
// ## The node type has moved to `core/design/nav/` — as this comment planned
//
// What used to stand here explained why the node type was local: `MlNavItem`
// carried no route, and importing it would have pointed the portal at the
// console. It ended "…until that extraction happens and the two can merge from
// a shared home rather than across a feature boundary."
//
// The M3 redesign is that extraction. The model now lives at
// `lib/core/design/nav/ml_nav_node.dart` as `MlNavNode` / `MlNavBadge`, the
// console builds its tree in the same model, and one shell renders both.
//
// The two names below are **aliases**, not copies. Everything that referred to
// `PortalNavNode` — the router's role guard, the badge providers, the tests —
// keeps working unchanged, and there is exactly one class.
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_application_1/core/design/nav/ml_nav_node.dart';
import 'package:flutter_application_1/features/auth/models/user_type.dart';

export 'package:flutter_application_1/core/design/nav/ml_nav_node.dart';

/// The portal's name for [MlNavNode]. One class, two names, no duplication.
typedef PortalNavNode = MlNavNode;

/// The portal's name for [MlNavBadge].
typedef PortalNavBadge = MlNavBadge;

/// Builds the navigation tree for one (org type, role) pair.
///
/// [role] is null for a **company account** — the owner login, which sees the
/// org's full tree. An *employee* whose role has not been assigned yet never
/// reaches this function: `resolvePortalTabs` returns the waiting screen for
/// them, because handing that user a tree was the privilege escalation closed
/// in `f9add87` (they were being given the complete owner console).
///
/// Rules held here, from `PLAN.md` §4.2:
///   * Nothing appears that the role cannot use. The router guard reads this
///     same tree, so the sidebar and the guard cannot drift apart.
///   * No org type sees a destination named after its own org type.
///   * Every leaf carries a route that resolves.
List<PortalNavNode> portalNavTree({
  required OrgType orgType,
  required UserRole? role,
}) {
  switch (orgType) {
    case OrgType.mineSupplier:
      return _mineTree(role);
    case OrgType.buyer:
      return _buyerTree(role);
    case OrgType.transporter:
      return _transporterTree(role);
  }
}

/// Where a session at [orgType] holding [role] should **land** after signing
/// in — the first leaf of that role's own tree.
///
/// Read off the tree rather than listed here, for the same reason
/// [portalRouteAllowedForRole] is: a second table of landing addresses is a
/// second thing to keep in step, and this one would be invisible when it
/// drifted. A role added to a tree gets a correct landing for free.
///
/// It also lands each role where they actually work rather than on a generic
/// hub: a security guard opens on the gate, a load controller on the
/// weighbridge, an admin on the dashboard.
///
/// **`/home` is deliberately not a possible answer.** No tree names it. Left
/// unredirected it renders `EmployeeDashboardTab` — four identity cards
/// (Role · Company · Status · Alerts) and two chips — as the first screen every
/// company user sees after signing in, while the rail beside it highlights
/// "Dashboard" and the real dashboard sits one address away, unvisited.
String portalLandingRoute({
  required OrgType orgType,
  required UserRole? role,
}) {
  for (final leaf in portalNavTree(orgType: orgType, role: role)
      .expand((n) => n.leaves)) {
    final route = leaf.route;
    if (route != null) return route;
  }
  // Unreachable by construction — every branch of every tree ends with at
  // least `_personalTail`, and `_minimalTree` exists precisely so that an
  // unsupported role still gets a rail. Stated rather than asserted so a future
  // empty branch degrades to the profile screen instead of throwing on sign-in.
  return '/profile';
}

/// True when a session at [orgType] holding [role] may open [path].
///
/// This is the guard half of P7-07 / P4-09: **the router and the rail read the
/// same tree**, so the sidebar and the route guard cannot drift apart. They do
/// today — once `org_type` matched, any employee could deep-link any
/// `/portal/{org}/*` route, so a security guard with a two-entry sidebar could
/// type their way into the weighbridge, the recon tables or the employee
/// roster.
///
/// The rule is deliberately **subtractive** rather than a whitelist:
///
///   * allowed if [path] is, or sits under, one of this role's own leaves —
///     which is what keeps detail routes working (`…/trips/:id/waybill` sits
///     under `…/trips`, `…/stockpiles/:id` under `…/stockpiles`);
///   * denied if it is, or sits under, a leaf the org's **full** tree names
///     and this role's does not — the actual escalation being closed;
///   * otherwise allowed.
///
/// That last clause matters. A whitelist would also block the deep-link
/// aliases that no tree names but that screens legitimately push —
/// `accept-route/:routeId`, `allocate-fleet/:routeId`, `drop-off/:tripId`,
/// `gate`, `minerals`, `loads`, `transactions` — and breaking the transporter's
/// accept flow to tighten a guard would trade one fault for a worse one. Those
/// paths stay reachable by anyone already inside the right org section, which
/// is no weaker than today.
///
/// This is UX-adjacent defence in depth, not the security boundary. The
/// boundary is RLS, and P4-09 is not closed until the same rule is expressed
/// there — a blocked route still leaves the RPC callable.
bool portalRouteAllowedForRole({
  required OrgType orgType,
  required UserRole? role,
  required String path,
}) {
  bool covers(String route) => path == route || path.startsWith('$route/');

  final mine = portalNavTree(orgType: orgType, role: role)
      .expand((n) => n.leaves)
      .map((l) => l.route!)
      .toSet();
  if (mine.any(covers)) return true;

  final full = portalNavTree(orgType: orgType, role: null)
      .expand((n) => n.leaves)
      .map((l) => l.route!)
      .toSet();
  return !full.where((r) => !mine.contains(r)).any(covers);
}

/// True when [role] holds the org's full tree: the company account itself
/// (null), or an admin / management employee.
///
/// The org-level roles (`mineSupplier` / `buyer` / `transporter`) appear on a
/// company account's own profile row rather than on an employee, and are
/// treated the same way.
bool _isFullAccess(UserRole? role) =>
    role == null ||
    role == UserRole.admin ||
    role == UserRole.management ||
    role == UserRole.mineSupplier ||
    role == UserRole.buyer ||
    role == UserRole.transporter;

// ---------------------------------------------------------------------------
// Settings — identical on all three org types, differing only in the `{org}`
// segment of the two routes that are portal-scoped.
// ---------------------------------------------------------------------------

PortalNavNode _settings(String org) => PortalNavNode.group(
      label: 'Settings',
      icon: Icons.settings_outlined,
      children: [
        PortalNavNode.leaf(
          label: 'My profile',
          icon: Icons.person_outline_rounded,
          route: '/portal/$org/profile',
        ),
        const PortalNavNode.leaf(
          label: 'Account & security',
          icon: Icons.lock_outline_rounded,
          route: '/account-security',
        ),
        const PortalNavNode.leaf(
          label: 'Appearance',
          icon: Icons.palette_outlined,
          route: '/appearance',
        ),
        PortalNavNode.leaf(
          label: 'Notifications',
          icon: Icons.notifications_none_rounded,
          route: '/portal/$org/notifications',
          badge: PortalNavBadge.unreadNotifications,
        ),
      ],
    );

/// The personal tail every restricted role gets: their own record and the
/// documents they are chased for. Never the org's.
List<PortalNavNode> _personalTail(String org) => [
      PortalNavNode.leaf(
        label: 'Compliance',
        // One word, ten letters, broken mid-word in the phone's 72px
        // slot. "Docs" is what the screen holds — certificates, licences
        // and permits with expiry dates — and it is short enough that no
        // phone this product supports has to break it.
        shortLabel: 'Docs',
        icon: Icons.verified_user_outlined,
        route: '/portal/$org/compliance',
        badge: PortalNavBadge.expiringCompliance,
      ),
      PortalNavNode.leaf(
        label: 'My profile',
        icon: Icons.person_outline_rounded,
        route: '/portal/$org/profile',
      ),
    ];

// ---------------------------------------------------------------------------
// Mine / supplier
// ---------------------------------------------------------------------------

List<PortalNavNode> _mineTree(UserRole? role) {
  // Security guard: the gate, and the hub tab that gate checks and security
  // incidents are actually written to. `OperationsAccessPolicy.canCreate`
  // authorises this role for both tables, but its sidebar has been exactly
  // [Security, Profile] and the only links to the hub lived in two orphaned
  // tab screens — which is the entire reason `security_incidents` holds 0 rows
  // and `gate_checks` holds 1 (P7-18).
  if (role == UserRole.security) {
    return [
      const PortalNavNode.leaf(
        label: 'Security gate',
        icon: Icons.security_rounded,
        route: '/portal/mine/security',
        badge: PortalNavBadge.arrivalsAwaitingCheckIn,
      ),
      const PortalNavNode.leaf(
        label: 'Incidents & gate checks',
        // Three lines in a 72px bottom-bar slot at 360px, and the third was
        // clipped away by the bar. The full label is still what the rail, the
        // drawer and the bar's long-press tooltip say.
        shortLabel: 'Incidents',
        icon: Icons.report_gmailerrorred_outlined,
        route: '/portal/mine/operations',
      ),
      ..._personalTail('mine'),
    ];
  }

  // Load controller: the weighbridge, the hub tab they write records to, and
  // — pending P8-15 — no history of their own loads yet.
  if (role == UserRole.controllerWB) {
    return [
      const PortalNavNode.leaf(
        label: 'Load controller',
        icon: Icons.tune_rounded,
        route: '/portal/mine/weighbridge',
        badge: PortalNavBadge.loadsAwaitingWeigh,
      ),
      const PortalNavNode.leaf(
        label: 'Weighbridge records',
        // Two long words: at the console's top text scale (1.3) neither fits a
        // 72px bottom-bar slot, so Flutter breaks INSIDE a word and the label
        // needs three lines. The full label is what the rail, the drawer and
        // the bar's long-press tooltip say.
        shortLabel: 'Records',
        icon: Icons.scale_outlined,
        route: '/portal/mine/operations',
      ),
      ..._personalTail('mine'),
    ];
  }

  // Supervisor / foreman: fills the order stockpile and records production.
  // Truck locations is new for this role and is the point — they could not see
  // which trucks were inbound to collect the pile they were filling.
  if (role == UserRole.supervisorForeman) {
    return [
      const PortalNavNode.leaf(
        label: 'Dashboard',
        icon: Icons.dashboard_outlined,
        route: '/portal/mine',
      ),
      const PortalNavNode.leaf(
        label: 'Supervisor & stockpiles',
        // Same three-line clipping as "Incidents & gate checks" above.
        // "Stockpiles" rather than "Supervisor": it names the thing this
        // destination is for, and the person reading it already is the
        // supervisor.
        shortLabel: 'Stockpiles',
        icon: Icons.supervisor_account_outlined,
        route: '/portal/mine/stockpiles',
      ),
      const PortalNavNode.leaf(
        label: 'Production',
        icon: Icons.terrain_outlined,
        route: '/portal/mine/production',
      ),
      const PortalNavNode.leaf(
        label: 'Truck locations',
        // Same as "Weighbridge records" above — "locations" alone overruns a
        // 72px slot at text scale 1.3 and the label takes three lines.
        shortLabel: 'Trucks',
        icon: Icons.map_outlined,
        route: '/portal/mine/truck-locations',
      ),
      const PortalNavNode.leaf(
        label: 'Reconciliations',
        icon: Icons.balance_outlined,
        route: '/portal/mine/reconciliations',
      ),
      ..._personalTail('mine'),
    ];
  }

  if (!_isFullAccess(role)) {
    return _minimalTree('mine');
  }

  return [
    const PortalNavNode.leaf(
      label: 'Dashboard',
      icon: Icons.dashboard_outlined,
      route: '/portal/mine',
    ),
    const PortalNavNode.group(
      label: 'Operations',
      icon: Icons.precision_manufacturing_outlined,
      children: [
        PortalNavNode.leaf(
          label: 'Supervisor & stockpiles',
          icon: Icons.supervisor_account_outlined,
          route: '/portal/mine/stockpiles',
        ),
        PortalNavNode.leaf(
          label: 'Production',
          icon: Icons.terrain_outlined,
          route: '/portal/mine/production',
        ),
        PortalNavNode.leaf(
          label: 'Quality',
          icon: Icons.science_outlined,
          route: '/portal/mine/quality',
        ),
        PortalNavNode.leaf(
          label: 'Security gate',
          icon: Icons.security_rounded,
          route: '/portal/mine/security',
          badge: PortalNavBadge.arrivalsAwaitingCheckIn,
        ),
        PortalNavNode.leaf(
          label: 'Load controller',
          icon: Icons.tune_rounded,
          route: '/portal/mine/weighbridge',
          badge: PortalNavBadge.loadsAwaitingWeigh,
        ),
        PortalNavNode.leaf(
          label: 'Operations hub',
          icon: Icons.widgets_outlined,
          route: '/portal/mine/operations',
        ),
      ],
    ),
    const PortalNavNode.group(
      label: 'Logistics',
      icon: Icons.local_shipping_outlined,
      children: [
        PortalNavNode.leaf(
          label: 'Requests',
          icon: Icons.assignment_outlined,
          route: '/portal/mine/requests',
          badge: PortalNavBadge.pendingRequests,
        ),
        PortalNavNode.leaf(
          label: 'Buyers',
          icon: Icons.handshake_outlined,
          route: '/portal/mine/buyers',
        ),
        PortalNavNode.leaf(
          label: 'Trips',
          icon: Icons.route_outlined,
          route: '/portal/mine/trips',
        ),
        PortalNavNode.leaf(
          label: 'Live map',
          icon: Icons.gps_fixed_rounded,
          route: '/portal/mine/live-map',
        ),
        PortalNavNode.leaf(
          label: 'Truck locations',
          icon: Icons.map_outlined,
          route: '/portal/mine/truck-locations',
        ),
        // A hard dependency of driver navigation: `get_trip_nav_destination`
        // resolves the collection point from here, and the screen has been
        // routed but unreachable since it was built (P4-20).
        PortalNavNode.leaf(
          label: 'Mine locations',
          icon: Icons.place_outlined,
          route: '/portal/mine/locations',
        ),
      ],
    ),
    const PortalNavNode.group(
      label: 'Reconciliation',
      // ONE WORD, and 14 letters of it. The phone's bottom bar gives a
      // destination a 72-90px slot and `NavigationBar` does not ellipsize,
      // so the full label wrapped between two letters — "Reconciliatio"
      // over an orphaned "n" sitting on the bar's bottom edge.
      // Photographed 2026-08-21, the first time a phone render carried
      // this tree. "Recon" is not an abbreviation invented for the bar:
      // it is the word this product already uses for the thing
      // (CLAUDE.md §4 — "recon table", "recon rows"), and
      // "Recon tables (tons out)" is a leaf of this very group. The full
      // label stays on the long-press tooltip and in the drawer.
      shortLabel: 'Recon',
      icon: Icons.balance_outlined,
      children: [
        PortalNavNode.leaf(
          label: 'Reconciliations',
          icon: Icons.balance_outlined,
          route: '/portal/mine/reconciliations',
        ),
        PortalNavNode.leaf(
          label: 'Recon tables (tons out)',
          icon: Icons.table_chart_outlined,
          route: '/portal/mine/tons-out',
        ),
        // The same loads, searchable and sortable. Its screen had every one of
        // those controls built and no way to reach a single row until
        // 2026-08-17 — see `tons_out_mapping.dart`.
        PortalNavNode.leaf(
          label: 'Search loads',
          icon: Icons.manage_search_outlined,
          route: '/portal/mine/tons-out-search',
        ),
      ],
    ),
    _company('mine'),
    _settings('mine'),
  ];
}

// ---------------------------------------------------------------------------
// Buyer
// ---------------------------------------------------------------------------

List<PortalNavNode> _buyerTree(UserRole? role) {
  // `UserRole.getRolesForOrgType(buyer)` yields admin and management only, so
  // any other role on a buyer company is a data fault rather than a supported
  // configuration. Give it the minimal tree rather than an empty rail.
  if (!_isFullAccess(role)) return _minimalTree('buyer');

  return [
    const PortalNavNode.leaf(
      label: 'Dashboard',
      icon: Icons.dashboard_outlined,
      route: '/portal/buyer',
    ),
    const PortalNavNode.group(
      label: 'Procurement',
      // Same fault as Reconciliation: one word, eleven letters, broken
      // mid-word in a 72px slot at 360px. The bar navigates a group to
      // its FIRST LEAF, and this group's first leaf is Requests — so the
      // short form names exactly where the tap lands rather than
      // inventing a vocabulary for the bar.
      shortLabel: 'Requests',
      icon: Icons.shopping_bag_outlined,
      children: [
        PortalNavNode.leaf(
          label: 'Requests',
          icon: Icons.assignment_outlined,
          route: '/portal/buyer/requests',
          badge: PortalNavBadge.pendingRequests,
        ),
        PortalNavNode.leaf(
          label: 'Routes & mines',
          icon: Icons.alt_route_outlined,
          route: '/portal/buyer/routes',
        ),
      ],
    ),
    const PortalNavNode.group(
      label: 'Deliveries',
      icon: Icons.local_shipping_outlined,
      children: [
        PortalNavNode.leaf(
          label: 'Waybills',
          icon: Icons.description_outlined,
          route: '/portal/buyer/waybills',
        ),
        PortalNavNode.leaf(
          label: 'Loads & value',
          icon: Icons.payments_outlined,
          route: '/portal/buyer/loads-value',
        ),
        PortalNavNode.leaf(
          label: 'Trips',
          icon: Icons.route_outlined,
          route: '/portal/buyer/trips',
        ),
        PortalNavNode.leaf(
          label: 'Live map',
          icon: Icons.gps_fixed_rounded,
          route: '/portal/buyer/live-map',
        ),
        PortalNavNode.leaf(
          label: 'Truck locations',
          icon: Icons.map_outlined,
          route: '/portal/buyer/truck-locations',
        ),
      ],
    ),
    const PortalNavNode.group(
      label: 'Reconciliation',
      // ONE WORD, and 14 letters of it. The phone's bottom bar gives a
      // destination a 72-90px slot and `NavigationBar` does not ellipsize,
      // so the full label wrapped between two letters — "Reconciliatio"
      // over an orphaned "n" sitting on the bar's bottom edge.
      // Photographed 2026-08-21, the first time a phone render carried
      // this tree. "Recon" is not an abbreviation invented for the bar:
      // it is the word this product already uses for the thing
      // (CLAUDE.md §4 — "recon table", "recon rows"), and
      // "Recon tables (tons out)" is a leaf of this very group. The full
      // label stays on the long-press tooltip and in the drawer.
      shortLabel: 'Recon',
      icon: Icons.balance_outlined,
      children: [
        PortalNavNode.leaf(
          label: 'Reconciliations',
          icon: Icons.balance_outlined,
          route: '/portal/buyer/reconciliations',
        ),
        PortalNavNode.leaf(
          label: 'Recon tables (tons out)',
          icon: Icons.table_chart_outlined,
          route: '/portal/buyer/tons-out',
        ),
        // The same loads, searchable and sortable. Its screen had every one of
        // those controls built and no way to reach a single row until
        // 2026-08-17 — see `tons_out_mapping.dart`.
        PortalNavNode.leaf(
          label: 'Search loads',
          icon: Icons.manage_search_outlined,
          route: '/portal/buyer/tons-out-search',
        ),
      ],
    ),
    _company('buyer'),
    _settings('buyer'),
  ];
}

// ---------------------------------------------------------------------------
// Transporter
// ---------------------------------------------------------------------------

List<PortalNavNode> _transporterTree(UserRole? role) {
  // Driver: the mobile-first shell. On a narrow layout the portal renders the
  // self-chromed driver app with its own Dashboard / Trip / Profile bottom
  // bar; this tree is what the drawer and the desktop rail show.
  //
  // Navigation and Drop-off are deliberately absent: both need a live
  // `:tripId` and belong to the trip in hand, so they are reached from the
  // Trip screen's lifecycle actions rather than from a static rail entry that
  // could not know which trip it meant.
  if (role == UserRole.driver) {
    return [
      const PortalNavNode.leaf(
        label: 'Dashboard',
        icon: Icons.dashboard_outlined,
        route: '/portal/driver/home',
      ),
      const PortalNavNode.leaf(
        // "Trip", not "My routes". The driver's BOTTOM NAV is
        // Dashboard · Trip · Profile (CLAUDE.md §4), so "Trip" is already the
        // word this driver taps every day; the rail was the odd one out.
        label: 'Trip',
        icon: Icons.alt_route_outlined,
        route: '/portal/driver/trip',
      ),
      const PortalNavNode.leaf(
        label: 'Live map',
        icon: Icons.gps_fixed_rounded,
        route: '/portal/transporter/live-map',
      ),
      PortalNavNode.leaf(
        label: 'Compliance',
        // One word, ten letters, broken mid-word in the phone's 72px
        // slot. "Docs" is what the screen holds — certificates, licences
        // and permits with expiry dates — and it is short enough that no
        // phone this product supports has to break it.
        shortLabel: 'Docs',
        icon: Icons.verified_user_outlined,
        route: '/portal/transporter/compliance',
        badge: PortalNavBadge.expiringCompliance,
      ),
      const PortalNavNode.leaf(
        label: 'My profile',
        icon: Icons.person_outline_rounded,
        route: '/portal/driver/profile',
      ),
    ];
  }

  if (!_isFullAccess(role)) return _minimalTree('transporter');

  return [
    const PortalNavNode.leaf(
      label: 'Dashboard',
      icon: Icons.dashboard_outlined,
      route: '/portal/transporter',
    ),
    const PortalNavNode.group(
      label: 'Operations',
      icon: Icons.precision_manufacturing_outlined,
      children: [
        // Accepting a dispatch and allocating trucks to it both happen here,
        // through `showDispatchedRouteDetailSheet` on the dashboard's
        // Available-routes section. `accept-route/:routeId` and
        // `allocate-fleet/:routeId` are deep-link aliases that need an id, so
        // they are not static rail entries (P8-10 / P8-11).
        PortalNavNode.leaf(
          label: 'Routes & dispatches',
          icon: Icons.route_outlined,
          route: '/portal/transporter/routes',
          badge: PortalNavBadge.unacceptedDispatches,
        ),
        PortalNavNode.leaf(
          label: 'Trucks on route',
          icon: Icons.local_shipping_outlined,
          route: '/portal/transporter/trucks-on-route',
        ),
        PortalNavNode.leaf(
          label: 'Trips',
          icon: Icons.timeline_outlined,
          route: '/portal/transporter/trips',
        ),
      ],
    ),
    const PortalNavNode.group(
      label: 'Fleet',
      icon: Icons.fire_truck_outlined,
      children: [
        PortalNavNode.leaf(
          label: 'Vehicles',
          icon: Icons.directions_bus_outlined,
          route: '/portal/transporter/fleet',
        ),
        PortalNavNode.leaf(
          label: 'Drivers',
          icon: Icons.badge_outlined,
          route: '/portal/transporter/drivers',
        ),
        PortalNavNode.leaf(
          label: 'Maintenance',
          icon: Icons.build_circle_outlined,
          route: '/portal/transporter/maintenance',
          badge: PortalNavBadge.maintenanceDue,
        ),
      ],
    ),
    const PortalNavNode.group(
      label: 'Money',
      icon: Icons.payments_outlined,
      children: [
        PortalNavNode.leaf(
          label: 'Earnings',
          icon: Icons.trending_up_rounded,
          route: '/portal/transporter/earnings',
        ),
        PortalNavNode.leaf(
          label: 'Fuel & costs',
          icon: Icons.local_gas_station_outlined,
          route: '/portal/transporter/fuel-costs',
        ),
      ],
    ),
    const PortalNavNode.group(
      label: 'Tracking',
      icon: Icons.gps_fixed_rounded,
      children: [
        PortalNavNode.leaf(
          label: 'Live map',
          icon: Icons.gps_fixed_rounded,
          route: '/portal/transporter/live-map',
        ),
        // `Truck positions` used to sit alongside this as a separate tab
        // reading the same provider and rendering the same panel (P1-13 /
        // P7-17). One entry, not two.
        PortalNavNode.leaf(
          label: 'Truck locations',
          icon: Icons.map_outlined,
          route: '/portal/transporter/truck-locations',
        ),
        PortalNavNode.leaf(
          label: 'Request tracking',
          icon: Icons.track_changes_outlined,
          route: '/portal/transporter/request-tracking',
        ),
      ],
    ),
    const PortalNavNode.group(
      label: 'Reconciliation',
      // ONE WORD, and 14 letters of it. The phone's bottom bar gives a
      // destination a 72-90px slot and `NavigationBar` does not ellipsize,
      // so the full label wrapped between two letters — "Reconciliatio"
      // over an orphaned "n" sitting on the bar's bottom edge.
      // Photographed 2026-08-21, the first time a phone render carried
      // this tree. "Recon" is not an abbreviation invented for the bar:
      // it is the word this product already uses for the thing
      // (CLAUDE.md §4 — "recon table", "recon rows"), and
      // "Recon tables (tons out)" is a leaf of this very group. The full
      // label stays on the long-press tooltip and in the drawer.
      shortLabel: 'Recon',
      icon: Icons.balance_outlined,
      children: [
        PortalNavNode.leaf(
          label: 'Reconciliations',
          icon: Icons.balance_outlined,
          route: '/portal/transporter/reconciliations',
        ),
        PortalNavNode.leaf(
          label: 'Recon tables (tons out)',
          icon: Icons.table_chart_outlined,
          route: '/portal/transporter/tons-out',
        ),
        // The same loads, searchable and sortable. Its screen had every one of
        // those controls built and no way to reach a single row until
        // 2026-08-17 — see `tons_out_mapping.dart`.
        PortalNavNode.leaf(
          label: 'Search loads',
          icon: Icons.manage_search_outlined,
          route: '/portal/transporter/tons-out-search',
        ),
      ],
    ),
    _company('transporter'),
    _settings('transporter'),
  ];
}

// ---------------------------------------------------------------------------
// Shared sections
// ---------------------------------------------------------------------------

/// Company ▾ — the same destinations on every org type.
///
/// `Employee register` landed 2026-08-11 (P7-27…P7-33). It is the read side of
/// Employees: role-grouped, live presence, driver → truck, per-group KPIs
/// counted from real rows. It sits behind `is_company_manager` in Postgres —
/// `employees` by RLS and `list_company_member_presence` by a `42501` raise —
/// so the rail entry and the router guard are UX, not the boundary. This group
/// is already restricted to the full-access roles.
PortalNavNode _company(String org) => PortalNavNode.group(
      label: 'Company',
      icon: Icons.domain_outlined,
      children: [
        PortalNavNode.leaf(
          label: 'Employees',
          icon: Icons.groups_outlined,
          route: '/portal/$org/employees',
        ),
        PortalNavNode.leaf(
          label: 'Employee register',
          icon: Icons.badge_outlined,
          route: '/portal/$org/register',
        ),
        PortalNavNode.leaf(
          label: 'Compliance',
          icon: Icons.verified_user_outlined,
          route: '/portal/$org/compliance',
          badge: PortalNavBadge.expiringCompliance,
        ),
        // 920 built lines that no route reached: `/communications` and
        // `/messages` both rendered `MessagesScreen`, so company announcements
        // were unreachable in their entirety (P4-18).
        const PortalNavNode.leaf(
          label: 'Announcements',
          icon: Icons.campaign_outlined,
          route: '/communications',
        ),
        PortalNavNode.leaf(
          label: 'Company profile',
          icon: Icons.business_outlined,
          route: '/portal/$org/company',
        ),
      ],
    );

/// The fallback for a role that is not a supported configuration for its org
/// type — their own record and nothing else.
///
/// Never an empty list: an empty rail reads as a broken app rather than a
/// restricted one, and leaves no way to reach sign-out.
List<PortalNavNode> _minimalTree(String org) => [
      PortalNavNode.leaf(
        label: 'Dashboard',
        icon: Icons.dashboard_outlined,
        route: '/portal/$org',
      ),
      ..._personalTail(org),
    ];
