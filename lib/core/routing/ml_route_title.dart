/// **The** route → page-title resolver. One table, both shells (S5-12).
///
/// There were two, in the two shells, and they had already begun to disagree
/// on the routes they both cover. `/notifications` is "Notifications" in the
/// portal's table and "Notifications" in the console's — but the console's is
/// matched by `path.contains('/notifications')` and the portal's by an exact
/// `case`, so `/portal/mine/notifications` hits one and `/super-admin/x/
/// notifications` the other, and nothing said they had to stay in step. A new
/// route needed adding to whichever table its shell happened to use, and the
/// only way to find out which was to open both.
///
/// The two route spaces really are disjoint — `/super-admin/**` against
/// everything else — so unifying them is a dispatch, not a merge of
/// conflicting mappings. That is why this could be done without changing a
/// single title: `test/core/route_title_test.dart` asserts the resolver
/// returns, for every route either table used to handle, exactly what that
/// table returned.
///
/// ## Why the portal half takes its tab labels as an argument
///
/// The portal's title for a section dashboard is *the label of the active
/// sidebar tab*, and the tab set differs per org type — a mine's Overview is
/// not a buyer's Dashboard. That is genuinely per-session state, so it is
/// injected as [MlPortalTabs] rather than reached for. Passing a
/// `List<String>` rather than the feature's own `PortalTabItem` keeps this
/// file free of any `features/` import, which is the whole reason it can live
/// in `core/` and be shared by both shells.
library;

/// A resolved title, and the console's second line where it has one.
class MlRouteTitle {
  /// The page title in the top bar.
  final String title;

  /// The line under it. Only the console draws one; null everywhere else.
  final String? subtitle;

  const MlRouteTitle(this.title, [this.subtitle]);

  @override
  bool operator ==(Object other) =>
      other is MlRouteTitle &&
      other.title == title &&
      other.subtitle == subtitle;

  @override
  int get hashCode => Object.hash(title, subtitle);

  @override
  String toString() =>
      subtitle == null ? 'MlRouteTitle($title)' : 'MlRouteTitle($title, $subtitle)';
}

/// The portal sidebar's state, as much of it as a title needs.
class MlPortalTabs {
  /// Tab labels in sidebar order.
  final List<String> labels;

  /// Index of the tab `/home` is currently showing, or -1.
  final int homeIndex;

  const MlPortalTabs(this.labels, this.homeIndex);

  static const empty = MlPortalTabs(<String>[], -1);

  String? get homeLabel =>
      homeIndex >= 0 && homeIndex < labels.length ? labels[homeIndex] : null;

  /// The org's landing tab: Overview on a mine or transporter, Dashboard on a
  /// buyer or an employee shell.
  String? get landingLabel {
    if (labels.contains('Overview')) return 'Overview';
    if (labels.contains('Dashboard')) return 'Dashboard';
    return null;
  }
}

/// The `/portal/{org}` section prefixes whose deep aliases carry the title of
/// the screen they mirror (phase-2 nav merge T3).
const List<String> mlPortalSectionPrefixes = [
  '/portal/mine',
  '/portal/buyer',
  '/portal/transporter',
  '/portal/driver',
];

/// First path segment after a `/portal/{org}` prefix ('' for the section
/// dashboard itself), or null when [path] is not a portal-section path.
String? mlPortalAliasSegment(String path) {
  for (final prefix in mlPortalSectionPrefixes) {
    if (path == prefix) return '';
    if (path.startsWith('$prefix/')) {
      final rest = path.substring(prefix.length + 1);
      final slash = rest.indexOf('/');
      return slash < 0 ? rest : rest.substring(0, slash);
    }
  }
  return null;
}

/// Resolves [uri] to its title, and its subtitle where the shell draws one.
///
/// [tabs] is only consulted for the portal's `/home` and section-dashboard
/// routes; every other route resolves from the path alone, which is what lets
/// the console call this without a tab set.
MlRouteTitle mlRouteTitle(Uri uri, {MlPortalTabs tabs = MlPortalTabs.empty}) {
  final path = uri.path;
  if (path == '/super-admin' || path.startsWith('/super-admin/')) {
    return MlRouteTitle(_consoleTitle(path), _consoleSubtitle(path));
  }
  return MlRouteTitle(_portalTitle(uri, tabs));
}

// ---------------------------------------------------------------------------
// Console — `/super-admin/**`. Carried across verbatim from
// `_SuperAdminShellLayoutState._titleForPath` / `_subtitleForPath`.
// ---------------------------------------------------------------------------

/// ## Twenty-one routes used to fall off the bottom of this ladder
///
/// Driven in a browser as the platform admin on 2026-08-21, the targets screen
/// had a top bar reading "Platform Admin / Platform management" over a page
/// headed "Platform targets". It was not alone: 21 of the console's 38 routes
/// hit the `return 'Platform Admin'` below, and 29 hit the matching subtitle
/// fallback — margin ledger, recon tables, disputes, crash reports, the live
/// map, account deactivations, seat requests, tons out, the marketplace, all
/// five targets screens. Half the console announced itself by the name of the
/// console.
///
/// One was worse than unnamed. `/super-admin/requests/transportation-buyer` is
/// the BUYER TRANSPORT inbox, and `path.contains('/requests/buyer')` matched
/// it first and titled it **"Requested buyers"** — the name of a different
/// inbox, one screen away in the same rail group. A missing name is a gap; a
/// confidently wrong one is a lie, and the router already carries a note about
/// this same ladder doing the same thing to an unknown request type.
///
/// The names below are the RAIL's own labels (`console_nav.dart`), so the bar
/// and the rail agree about what a destination is called — the same rule the
/// portal half of this file adopted when it had this fault.
///
/// `test/core/every_console_route_is_named_test.dart` reads the router and
/// fails on any route that reaches either fallback, so a new console route
/// cannot be added without naming it.
String _consoleTitle(String path) {
  if (path == '/super-admin' || path.contains('/dashboard-v2')) {
    return 'Global Admin · Dashboard';
  }
  if (path.startsWith('/super-admin/insights/') && path.contains('/company/')) {
    return 'Company workspace';
  }
  // Before the generic insights title below, which would otherwise claim this
  // page is the overview it was opened from.
  if (path.endsWith('/leaderboard')) return 'Leaderboard';
  if (path.startsWith('/super-admin/insights/') &&
      !path.contains('/company/')) {
    return 'Organization insights';
  }

  // Targets: three independent scopes (CLAUDE.md §4 "the scope rule"), and the
  // bar has to say WHICH, because the three screens are otherwise identical
  // and a platform target is not a rollup of the others.
  if (path.contains('/targets/org-type')) return 'Org-type targets';
  if (path.contains('/targets/company')) return 'Company targets';
  if (path.contains('/targets')) return 'Platform targets';

  if (path.contains('/chat-links')) return 'Chat links';
  if (path.contains('/organizations')) return 'Organizations';
  // Singular — one organization, not the roster. It does NOT contain
  // "/organizations", so it never reached the line above.
  if (path.contains('/organization/')) return 'Organization';
  if (path.contains('/register-company')) return 'Register company';
  if (path.contains('/users')) return 'Platform users';
  if (path.contains('/audit-logs')) return 'Audit logs';
  if (path.contains('/crash-reports')) return 'Crash reports';
  if (path.contains('/account-deactivations')) return 'Account deactivations';

  // The two transport inboxes FIRST — both contain '/requests/transportation',
  // and the buyer one also contains '/requests/buyer'.
  if (path.contains('/requests/transportation-mine')) {
    return 'Mine/Supplier transport';
  }
  if (path.contains('/requests/transportation-buyer')) {
    return 'Buyer transport';
  }
  if (path.contains('/requests/mine-transport')) return 'Mine/Supplier transport';
  if (path.contains('/requests/buyer-transport')) return 'Buyer transport';
  if (path.contains('/requests/transportation')) return 'Requested routes';
  if (path.contains('/requests/product')) return 'Requested product';
  if (path.contains('/requests/buyer')) return 'Requested buyers';

  // '/request-tracking' has no '/requests/' in it, so it never collided with
  // the block above — it simply was not listed.
  if (path.contains('/request-tracking')) return "Request's Tracking Logs";
  if (path.contains('/driver-limits')) return 'Transporter Driver limits';
  if (path.contains('/margin-ledger')) return 'Margin ledger History';
  if (path.contains('/recon-tables')) return 'Recon tables';
  if (path.contains('/disputes')) return 'Disputes';
  if (path.contains('/tons-out')) return 'Tons out';
  if (path.contains('/available-routes')) return 'Available routes';
  if (path.contains('/route-marketplace')) return 'Route marketplace';
  if (path.contains('/live-map')) return 'Live map';
  if (path.contains('/seat-requests')) return 'Seat requests';

  if (path.contains('/token-requests')) return 'Token requests';
  if (path.contains('/token-history')) return 'Token history';
  if (path.contains('/notifications')) return 'Notifications';
  if (path.contains('/account-security')) return 'Account security';
  if (path.contains('/preferences')) return 'User Preferences';
  if (path.endsWith('/settings')) return 'Platform settings';
  return 'Platform Admin';
}

String _consoleSubtitle(String path) {
  if (path == '/super-admin' || path.contains('/dashboard-v2')) {
    return 'Full system overview · Live · updated just now';
  }
  if (path.startsWith('/super-admin/insights/') && path.contains('/company/')) {
    return 'Read-only mirror · filter & export where available';
  }
  if (path.startsWith('/super-admin/insights/') &&
      !path.contains('/company/')) {
    // NOT "(device calendar)", which is what this said until 2026-08-21 and
    // was read on a live console before anybody noticed it was false. The
    // window is `MlTime.now()` — the Africa/Johannesburg month (CLAUDE.md
    // §7.1) — so it is the same month for every reader whatever their laptop
    // is set to, and that is the whole point of the one-clock rule. Telling an
    // admin the number depends on their device is precisely the misconception
    // §7.1 exists to end, and it was printed in the chrome of the screen the
    // number is on. The wording matches the notification screen's, which is
    // the product's existing user-facing phrase for this.
    return 'This month (South African time) · monthly rollups per company';
  }
  if (path.contains('/chat-links')) {
    return 'Link companies so their people can message each other';
  }
  if (path.contains('/account-security')) {
    return 'Update your email sign-in password';
  }
  if (path.contains('/preferences')) {
    return 'Appearance, display & accessibility · saved to your account only';
  }
  if (path.contains('/notifications')) {
    return 'Platform alerts and token activity';
  }

  // The 29 that reached "Platform management" — a line that describes the
  // console rather than the screen, and so said nothing at all on the screen
  // it was printed on. Each one says what this page is FOR, in a clause, which
  // is what the four above it already did.
  //
  // Ordered exactly like `_consoleTitle`: the three targets scopes before the
  // bare `/targets`, and the two transport inboxes before the generic
  // transportation match, for the same collisions.
  if (path.contains('/targets/org-type')) {
    return 'One commitment per organization type · independent of the others';
  }
  if (path.contains('/targets/company')) {
    return 'One commitment per company · independent of the others';
  }
  if (path.contains('/targets')) {
    return 'Every organisation combined · monthly goals and the 12-month cycle';
  }
  if (path.contains('/organizations')) {
    return 'Every registered company, its seats and its token expiry';
  }
  if (path.contains('/organization/')) {
    return 'One company · seats, people and token history';
  }
  if (path.contains('/register-company')) {
    return 'Create a company and issue its first access token';
  }
  if (path.contains('/users')) {
    return 'Every person with an account, across all organizations';
  }
  if (path.contains('/audit-logs')) {
    return 'Who did what, and when · newest first';
  }
  if (path.contains('/crash-reports')) {
    return 'Errors reported by the app itself · grouped by fingerprint';
  }
  if (path.contains('/account-deactivations')) {
    return 'Requests to deactivate an account, and the accounts already held';
  }
  if (path.contains('/requests/transportation-mine') ||
      path.contains('/requests/mine-transport')) {
    return 'Mines and suppliers asking for trucks · approve, send back or link';
  }
  if (path.contains('/requests/transportation-buyer') ||
      path.contains('/requests/buyer-transport')) {
    return 'Buyers asking for trucks · approve, send back or link';
  }
  if (path.contains('/requests/transportation')) {
    return 'Route and transporter requests awaiting review';
  }
  if (path.contains('/requests/product')) {
    return 'Buyers asking for a product listing';
  }
  if (path.contains('/requests/buyer')) {
    return 'Mines asking for buyer connections and roster access';
  }
  if (path.contains('/request-tracking')) {
    return 'Every request, and where it has got to';
  }
  if (path.contains('/driver-limits')) {
    return 'Requests to put more than two drivers on one truck · max five';
  }
  if (path.contains('/margin-ledger')) {
    return 'Agreed price, your cut and the transporter price, per route';
  }
  if (path.contains('/recon-tables')) {
    return 'Every load from every transporter, combined · exportable';
  }
  if (path.contains('/disputes')) {
    return 'Weight and delivery disagreements raised by a party';
  }
  if (path.contains('/tons-out')) {
    return 'Weighbridge movements out of the mines';
  }
  if (path.contains('/available-routes')) {
    return 'Learned routes you can assign to an organization to pre-fill';
  }
  if (path.contains('/route-marketplace')) {
    return 'Every route every transporter runs · admin-only until published';
  }
  if (path.contains('/live-map')) {
    return 'Trucks reporting position right now, across every trip';
  }
  if (path.contains('/seat-requests')) {
    return 'Companies asking for more seats than their token allows';
  }
  if (path.contains('/token-requests')) {
    return 'Access tokens awaiting your approval';
  }
  if (path.contains('/token-history')) {
    return 'Every token ever issued, renewed or revoked';
  }
  if (path.endsWith('/settings')) {
    return 'Platform-wide configuration';
  }
  return 'Platform management';
}

// ---------------------------------------------------------------------------
// Portal — everything else. Carried across verbatim from
// `portalShellSectionTitle`.
// ---------------------------------------------------------------------------

/// Path prefix of the notifications-manage route.
///
/// Duplicated as a literal rather than imported so this file stays free of
/// feature imports; `route_title_test.dart` asserts it equals
/// `NotificationsManageRoute.path`, so the two cannot drift.
const String mlNotificationsManagePath = '/notifications/manage';

String _portalTitle(Uri uri, MlPortalTabs tabs) {
  final path = uri.path;
  if (path == '/home') {
    final label = tabs.homeLabel;
    if (label != null) return label;
  }
  if (path.startsWith(mlNotificationsManagePath)) {
    final t = uri.queryParameters['title'];
    if (t != null && t.trim().isNotEmpty) return t.trim();
    return 'Notifications';
  }
  // Deep `/portal/{org}/...` aliases: the title mirrors the target screen and
  // is the same across org types.
  final segment = mlPortalAliasSegment(path);
  if (segment != null) {
    if (segment.isEmpty) return tabs.landingLabel ?? 'Overview';
    // `routes` is the one segment whose meaning genuinely differs by org, so
    // it is resolved before the shared switch rather than given one label that
    // is wrong on one of them. A buyer browses the mines that serve a route; a
    // transporter accepts dispatches on one.
    if (segment == 'routes') {
      return path.startsWith('/portal/buyer')
          ? 'Routes & mines'
          : 'Routes & dispatches';
    }
    return switch (segment) {
      'security' => 'Security',
      'gate' => 'Gate control',
      // "Load controller", which is what the rail calls it, NOT "Weighbridge".
      //
      // Driven as a mine owner in a browser on 2026-08-21: the rail said Load
      // controller, the bar said Weighbridge, and the page under both was
      // headed "Mine Control". Three names for one destination — and the bar's
      // was the worst of the three, because "Weighbridge records" is the SAME
      // role's OTHER rail item. The bar was not vague, it named the
      // neighbour.
      'weighbridge' => 'Load controller',
      'stockpiles' => 'Stockpiles',
      'minerals' || 'loads' || 'transactions' => 'Operations Hub',
      // `/portal/mine/operations` is one screen the rail names three ways by
      // role — "Operations hub" for an admin, "Incidents & gate checks" for a
      // guard, "Weighbridge records" for a controller. The resolver has no
      // role, so it takes the neutral name, which is also the one the three
      // aliases above already resolve to.
      'operations' => 'Operations Hub',
      'tons-out' => 'Tons out',
      'tons-out-search' => 'Search loads',
      'reconciliations' => 'Reconciliations',
      'requests' => 'Requests',
      'orders' => 'Orders',
      'locations' => 'Locations',
      'live-map' => 'Live map',
      'truck-locations' => 'Truck locations',
      'employees' => 'Employees',
      'register' => 'Employee register',
      'compliance' => 'Compliance',
      'company' => 'Company',
      'notifications' => 'Notifications',
      'profile' => 'Profile',
      'waybills' => 'Waybills',
      'fleet' => 'Fleet management',
      'trucks-on-route' => 'Trucks On Route',
      'maintenance' => 'Maintenance',
      'drivers' => 'Driver',
      'trips' => 'Trips',
      'production' => 'Production',
      'quality' => 'Quality',
      'buyers' => 'Buyers',
      'earnings' => 'Earnings',
      'fuel-costs' => 'Fuel & costs',
      'loads-value' => 'Loads & value',
      'request-tracking' => 'Request tracking',
      'home' => 'Dashboard', // /portal/driver/home
      'trip' => 'Trip', // /portal/driver/trip[...]
      _ => 'Workspace',
    };
  }
  switch (path) {
    case '/profile':
      return 'Profile';
    case '/company-employees':
      return 'Employees';
    case '/notifications':
      return 'Notifications';
    case '/fleet-management':
      return 'Fleet management';
    case '/appearance':
      return 'Appearance & theme';
    case '/communications':
      return 'Communications';
    case '/company-selection':
      return 'Choose company';
    case '/expired-access':
      return 'Access expired';
    // These three render inside the portal shell, so their top bar is visible —
    // and without a case here they fell to the `Workspace` default below.
    // Driven in a browser as the mine admin: `/account-security` and
    // `/messages` both showed a top bar reading "Workspace" while the other 30
    // routes of that role showed their real names. The labels match what the
    // rail calls each destination, so the bar and the rail agree.
    case '/account-security':
      return 'Account & security';
    case '/account-setup':
      return 'Account setup';
    case '/messages':
      return 'Messages';
    default:
      if (path.startsWith('/operations')) return 'Operations Hub';
      if (path.startsWith('/companies/')) return 'Companies';
      // "Employees", the word every other surface uses — `/company-employees`
      // above, the `employees` portal alias, the rail. This read **"Team
      // grid"**, which is the name of the WIDGET, and it was the top bar on
      // BOTH the roster and a single person's profile page: a page about one
      // employee announced itself as a grid. Photographed 2026-08-21.
      if (path.startsWith('/employees/')) {
        return path.endsWith('/details') ? 'Employee profile' : 'Employees';
      }
      if (path.startsWith('/chat/')) return 'Chat';
      return 'Workspace';
  }
}
