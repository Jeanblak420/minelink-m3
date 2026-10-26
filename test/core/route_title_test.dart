// S5-12 — the two route→title tables are now one resolver.
//
// The two tables covered disjoint route spaces (`/super-admin/**` against
// everything else), so unifying them is a dispatch rather than a merge of
// conflicting mappings — and that is exactly what makes it checkable: the
// resolver must return, for every route either table used to handle, the
// string that table returned.
//
// Every expectation below was read off the pre-merge source
// (`_SuperAdminShellLayoutState._titleForPath` / `_subtitleForPath` and
// `portalShellSectionTitle`), not off the new resolver. Written that way round
// deliberately: a test written by reading the code it tests asserts that the
// code does what it does.
//
// The ordering cases are the ones that matter. Both tables lean on `contains`
// and `startsWith`, so several routes match more than one rule and only the
// order picks the winner — a reordered branch is the plausible edit here, and
// it does not fail to compile.
//
// ## Nine console subtitles have deliberately moved on from the carry-over
//
// The pre-merge table gave nine routes the generic "Platform management" —
// organizations, register-company, audit-logs, the three request inboxes,
// token-requests, token-history and settings. That is a line about the console
// printed on a screen, and it said nothing about any of them. They now carry a
// clause each, and the expectations here were updated to match rather than
// pinned to the old string: this file exists to catch UNINTENDED drift, and a
// deliberate improvement recorded in the same commit is not that.
//
// The change came out of `every_console_route_is_named_test.dart`, which found
// 21 console routes with no title at all and 29 with no subtitle. Everything
// else below is still the verbatim carry-over.

import 'package:flutter_application_1/core/routing/ml_route_title.dart';
import 'package:flutter_application_1/core/routing/notifications_manage_route.dart';
import 'package:flutter_test/flutter_test.dart';

MlRouteTitle _t(String path, {MlPortalTabs tabs = MlPortalTabs.empty}) =>
    mlRouteTitle(Uri.parse(path), tabs: tabs);

void main() {
  group('console routes keep the titles the console table gave them', () {
    const cases = <String, (String, String)>{
      '/super-admin': (
        'Global Admin · Dashboard',
        'Full system overview · Live · updated just now',
      ),
      '/super-admin/insights/transporter': (
        'Organization insights',
        'This month (South African time) · monthly rollups per company',
      ),
      '/super-admin/insights/transporter/company/abc': (
        'Company workspace',
        'Read-only mirror · filter & export where available',
      ),
      '/super-admin/chat-links': (
        'Chat links',
        'Link companies so their people can message each other',
      ),
      '/super-admin/organizations': (
        'Organizations',
        'Every registered company, its seats and its token expiry',
      ),
      '/super-admin/register-company': (
        'Register company',
        'Create a company and issue its first access token',
      ),
      '/super-admin/audit-logs': (
        'Audit logs',
        'Who did what, and when · newest first',
      ),
      '/super-admin/requests/transportation': (
        'Requested routes',
        'Route and transporter requests awaiting review',
      ),
      '/super-admin/requests/product': (
        'Requested product',
        'Buyers asking for a product listing',
      ),
      '/super-admin/requests/buyer': (
        'Requested buyers',
        'Mines asking for buyer connections and roster access',
      ),
      '/super-admin/token-requests': (
        'Token requests',
        'Access tokens awaiting your approval',
      ),
      '/super-admin/token-history': (
        'Token history',
        'Every token ever issued, renewed or revoked',
      ),
      '/super-admin/notifications': (
        'Notifications',
        'Platform alerts and token activity',
      ),
      '/super-admin/account-security': (
        'Account security',
        'Update your email sign-in password',
      ),
      '/super-admin/preferences': (
        'User preferences',
        'Appearance, display & accessibility · saved to your account only',
      ),
      '/super-admin/settings': (
        'Platform settings',
        'Platform-wide configuration',
      ),
      '/super-admin/navigation-setup': (
        'Navigation setup',
        "Adding a mine's own haul roads to turn-by-turn navigation",
      ),
      // "Request tracking logs", not "Request's Tracking Logs" — the
      // possessive was misplaced and the title case sat against every
      // sentence-case label on the console (Phase 3 pass, 2026-08-23).
      '/super-admin/request-tracking': (
        'Request tracking logs',
        'Every request, and where it has got to',
      ),
      '/super-admin/anything-unmapped': (
        'Platform Admin',
        'Platform management',
      ),
    };

    cases.forEach((path, expected) {
      test(path, () {
        expect(_t(path), MlRouteTitle(expected.$1, expected.$2));
      });
    });

    test('/leaderboard wins over the generic insights title', () {
      // The insights rule matches this path too. The pre-merge table put the
      // leaderboard branch first with a comment saying why: otherwise the page
      // claims to be the overview it was opened from.
      expect(
        _t('/super-admin/insights/transporter/leaderboard').title,
        'Leaderboard',
      );
    });

    test('a company workspace wins over the generic insights title', () {
      expect(
        _t('/super-admin/insights/buyer/company/x').title,
        'Company workspace',
      );
    });

    test('the console always has a subtitle; the portal never does', () {
      expect(_t('/super-admin/organizations').subtitle, isNotNull);
      expect(_t('/profile').subtitle, isNull);
      expect(_t('/portal/mine/weighbridge').subtitle, isNull);
    });
  });

  group('portal routes keep the titles the portal table gave them', () {
    const aliases = <String, String>{
      // "Security gate" since 2026-08-22, not bare "Security": that word
      // sits a group away from the real destination "Account & security", and
      // `_legacyTabLabels` already had to map the old tab name onto it.
      '/portal/mine/security': 'Security gate',
      '/portal/mine/gate': 'Gate control',
      // "Load controller" since 2026-08-21, not "Weighbridge" — the rail's own
      // label for this destination, and the bar's old one was the word the
      // SAME role's OTHER rail item uses ("Weighbridge records"). Deliberate,
      // recorded in `every_portal_route_is_named_test.dart` along with the
      // fourteen other routes where the two vocabularies differ.
      '/portal/mine/weighbridge': 'Load controller',
      '/portal/mine/stockpiles': 'Stockpiles',
      '/portal/mine/minerals': 'Operations hub',
      '/portal/mine/loads': 'Operations hub',
      '/portal/mine/transactions': 'Operations hub',
      '/portal/mine/tons-out': 'Tons out',
      '/portal/buyer/reconciliations': 'Reconciliations',
      '/portal/buyer/requests': 'Requests',
      '/portal/buyer/orders': 'Orders',
      '/portal/mine/locations': 'Locations',
      '/portal/transporter/live-map': 'Live map',
      '/portal/mine/employees': 'Employees',
      '/portal/mine/company': 'Company',
      '/portal/mine/notifications': 'Notifications',
      // "My profile" since 2026-08-22 — the rail's word, and the only thing
      // separating it from "Company" one leaf away.
      '/portal/mine/profile': 'My profile',
      '/portal/buyer/waybills': 'Waybills',
      // Settled 2026-08-22: the bar now uses the RAIL's word for these four.
      // "Vehicles" because the rail leaf sits inside a group already called
      // "Fleet"; sentence case because this map is sentence case everywhere
      // else; plural because the screen lists a company's drivers.
      '/portal/transporter/fleet': 'Vehicles',
      '/portal/transporter/trucks-on-route': 'Trucks on route',
      '/portal/transporter/maintenance': 'Maintenance',
      '/portal/transporter/drivers': 'Drivers',
      '/portal/mine/trips': 'Trips',
      '/portal/driver/home': 'Dashboard',
      '/portal/driver/trip': 'Trip',
      '/portal/mine/not-a-real-segment': 'Workspace',
    };

    aliases.forEach((path, expected) {
      test(path, () => expect(_t(path).title, expected));
    });

    const plain = <String, String>{
      '/profile': 'My profile',
      '/company-employees': 'Employees',
      '/notifications': 'Notifications',
      '/fleet-management': 'Fleet management',
      // "Appearance" since 2026-08-22: "& theme" named one control on a page
      // that also carries text scale, density and reduce-motion.
      '/appearance': 'Appearance',
      '/communications': 'Communications',
      '/company-selection': 'Choose company',
      '/expired-access': 'Access expired',
      '/operations': 'Operations hub',
      '/operations/weighbridge': 'Operations hub',
      '/companies/123': 'Companies',
      '/employees/123': 'Employees',
      // A person's page is about a person, not about the grid it was
      // reached from. Both used to read "Team grid".
      '/employees/123/456/details': 'Employee profile',
      '/chat/123': 'Chat',
      // These three render inside the portal shell, so the bar is on screen.
      // The table above listed `/super-admin/account-security` but not the
      // plain one, so the suite stayed green while a mine admin opening
      // Account & security or Messages saw a top bar reading "Workspace".
      // Found by driving the built web app, not by reading the resolver.
      '/account-security': 'Account & security',
      '/account-setup': 'Account setup',
      '/messages': 'Messages',
      '/something-unmapped': 'Workspace',
    };

    plain.forEach((path, expected) {
      test(path, () => expect(_t(path).title, expected));
    });

    test('a deep alias takes the segment, not the tail', () {
      // `/portal/mine/tons-out/<transporterId>` is one screen, not two.
      expect(_t('/portal/mine/tons-out/abc-123').title, 'Tons out');
      expect(_t('/portal/driver/trip/xyz').title, 'Trip');
    });
  });

  group('the portal titles that depend on the sidebar', () {
    const mine = MlPortalTabs(['Overview', 'Security', 'Controller'], 1);
    const buyer = MlPortalTabs(['Dashboard', 'Requests'], 0);

    test('/home takes the active tab, by the name the menu gives it', () {
      // The tab is still called 'Security'; the menu calls the same place
      // "Security gate", and the bar follows the menu (S25 walk, 2026-10-26).
      expect(_t('/home', tabs: mine).title, 'Security gate');
      expect(
        _t(
          '/home',
          tabs: const MlPortalTabs(['Overview', 'Security', 'Controller'], 2),
        ).title,
        'Load controller',
      );
      expect(_t('/home', tabs: buyer).title, 'Dashboard');
    });

    test('a section dashboard takes Overview, or Dashboard where there is no '
        'Overview', () {
      expect(_t('/portal/mine', tabs: mine).title, 'Overview');
      expect(_t('/portal/buyer', tabs: buyer).title, 'Dashboard');
    });

    test('with no tabs at all it falls back rather than throwing', () {
      // An employee whose role has not been assigned has a one-item rail; a
      // workspace whose org type has not resolved has none. Neither may crash
      // the shell over a title.
      expect(_t('/home').title, 'Workspace');
      expect(_t('/portal/mine').title, 'Overview');
      expect(
        _t('/home', tabs: const MlPortalTabs(['Profile'], 5)).title,
        'Workspace',
      );
      expect(
        _t('/home', tabs: const MlPortalTabs(['Profile'], -1)).title,
        'Workspace',
      );
    });
  });

  group('the notifications-manage route', () {
    test('takes its title from the query string when one is given', () {
      expect(
        _t('/notifications/manage?title=Token%20requests').title,
        'Token requests',
      );
    });

    test('falls back to Notifications for a blank or absent title', () {
      expect(_t('/notifications/manage').title, 'Notifications');
      expect(_t('/notifications/manage?title=').title, 'Notifications');
      expect(_t('/notifications/manage?title=%20%20').title, 'Notifications');
    });

    test('the resolver\'s literal path matches the route that owns it', () {
      // The resolver states the path as a literal so `core/routing/` stays
      // free of feature imports. This is what stops the two drifting.
      expect(mlNotificationsManagePath, NotificationsManageRoute.path);
    });
  });
}
