import 'package:flutter_application_1/core/routing/notifications_inbox_route.dart';

/// Nav **id** → console route.
///
/// Ids are what the dashboard's tiles emit — `'orgs.expired'`, `'live-map'` —
/// rather than paths, so a tile does not have to know an address. This map is
/// where an id becomes a destination.
///
/// It lived inside `widgets/sidebar/console_sidebar_bridge.dart`, the glue for
/// three vendored sidebar skins that the M3 redesign removed. The dashboard
/// needs the map and never needed the skins, so it moves here beside the
/// navigation tree it belongs with.
///
/// Ids absent from this map either have no destination of their own (a group
/// parent opens its children) or are actions rather than destinations.
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
/// `about`, which is an action rather than a destination.
const Set<String> consoleNavActionOrGroupIds = <String>{
  'insights',
  'tokens',
  'requests',
  'settings',
  'about',
};
