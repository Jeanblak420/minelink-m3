// The portal's top bar has to call a destination what the rail calls it.
//
// The console half of this rule was enforced on 2026-08-21 after 21 of its 38
// routes fell off the bottom of the title ladder. The portal half was never
// checked, and driving the mine portal in a browser the same day found the
// same class immediately: the rail said **Load controller**, the top bar said
// **Weighbridge**, and the page under both was headed **Mine Control**. Three
// names for one destination — and "Weighbridge" is the word the SAME role's
// OTHER rail item uses ("Weighbridge records"), so the bar was not merely
// vague, it pointed at the neighbour.
//
// This walks every tree the product builds — three org types times every role
// — and compares `mlRouteTitle` against the rail's own label for the same
// route.
//
// ## Where they are allowed to differ, and why
//
// The resolver has no ROLE. That is deliberate: it is called from the router,
// which knows a path and a tab set and nothing about who is signed in. So a
// route the rail labels differently per role can only be given one name here,
// and `_allowedDivergence` records each of those with the reason. Everything
// else must agree.
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/core/routing/ml_route_title.dart';
import 'package:flutter_application_1/features/auth/models/user_type.dart';
import 'package:flutter_application_1/features/portal/nav/portal_nav.dart';

/// route -> why the bar does not use the rail's exact label.
///
/// This is an INVENTORY, not an excuse list. Every entry names both strings so
/// a reader can judge it, and the test at the bottom fails if one of them
/// quietly comes into line — an allow-list that outlives its reasons is how a
/// check stops covering things.
///
/// Sweeping every tree the product builds found **23 disagreements across 15
/// routes**. Exactly one of them was a fault rather than a choice —
/// `/portal/mine/weighbridge` read "Weighbridge" while the rail said "Load
/// controller" AND the same role's other rail item is "Weighbridge records",
/// so the bar named the neighbour. That one is fixed in the resolver.
///
/// The rest are two reasonable names for one page, and they are recorded
/// rather than changed because renaming them is a vocabulary decision across
/// the whole portal — "Vehicles" or "Fleet management", "Announcements" or
/// "Communications" — and `route_title_test.dart` pins the current set as the
/// vocabulary carried over from the shipping app. Deciding that is Jean's,
/// and it is now a list of fifteen rather than something nobody had counted.
const _allowedDivergence = <String, String>{
  // The bar names the active TAB here, not the rail item: the section root
  // resolves through `MlPortalTabs.landingLabel`, which is per-session state
  // the rail does not carry. With no tabs supplied it falls back to
  // "Overview".
  '/portal/mine': 'rail "Dashboard" / bar the active tab, "Overview" by default',
  '/portal/buyer': 'rail "Dashboard" / bar the active tab',
  '/portal/transporter': 'rail "Dashboard" / bar the active tab',
  '/portal/driver': 'rail "Dashboard" / bar the active tab',

  // One screen the rail names three ways by role — "Operations hub" for an
  // admin, "Incidents & gate checks" for a guard, "Weighbridge records" for a
  // controller. The resolver has no role, so it takes the neutral name, which
  // is also what the three aliases resolve to.
  '/portal/mine/operations': 'rail varies by role / bar "Operations Hub"',
  '/portal/buyer/operations': 'same screen, same reason',
  '/portal/transporter/operations': 'same screen, same reason',
  '/portal/driver/operations': 'same screen, same reason',

  // ── The eleven "longer in the rail, shorter in the bar" routes are GONE
  //    too — settled by Jean on 2026-08-22, the same way the four below were.
  //
  //    The rule he chose was "the clearer of the two strings, per pair", so
  //    the winner is sometimes the rail's and sometimes the bar's rather than
  //    one side always yielding:
  //
  //      mine/stockpiles   rail "Supervisor & stockpiles" -> "Stockpiles"
  //      mine/security     bar  "Security"                -> "Security gate"
  //      mine/locations    rail "Mine locations"          -> "Locations"
  //      */tons-out        rail "Recon tables (tons out)" -> "Tons out"
  //      */company         rail "Company profile"         -> "Company"
  //      */profile         bar  "Profile"                 -> "My profile"
  //      /communications   rail "Announcements"           -> "Communications"
  //      /appearance       bar  "Appearance & theme"      -> "Appearance"
  //
  //    Two of them were the "names the neighbour" fault this file's header
  //    describes, not merely two reasonable names: bar "Security" sits a group
  //    away from the real destination "Account & security", and bar "Profile"
  //    sits a leaf away from "Company". Three surfaces carried a third name
  //    for a route on this list and were brought in too — the appearance
  //    page's own heading, the mine dashboard's "Recon tables" shortcut (which
  //    named the SIBLING route "Reconciliations"), and `_legacyTabLabels`.
  //
  //    What is left below is divergent BY DESIGN, and both groups are the same
  //    cause: the resolver has no role and no session. It cannot know which
  //    tab a dashboard is showing, and it cannot know which of three names a
  //    role gives `/operations`.

  // The four where the bar was not shorter but a DIFFERENT word are GONE —
  // decided by Jean on 2026-08-22 and made to agree rather than recorded:
  //
  //   fleet            bar "Fleet management" -> "Vehicles". The rail leaf
  //                    sits inside a group already called "Fleet", so the old
  //                    bar title read as Fleet > Fleet.
  //   drivers          bar "Driver" -> "Drivers". The screen lists a
  //                    company's drivers.
  //   trucks-on-route  bar "Trucks On Route" -> "Trucks on route". It was the
  //                    title map's only Title Case entry.
  //   trip             RAIL "My routes" -> "Trip", the other direction: the
  //                    driver's bottom nav is Dashboard - Trip - Profile, so
  //                    the bar already had the word the driver taps.
  //
  // Fifteen routes became eleven, and every remaining one is the same shape:
  // longer in the rail, shorter in the bar, because the rail has a column and
  // the bar shares a line.
};

void main() {
  test('the rail really does produce routes', () {
    // A tree walk that finds nothing would pass this file by testing nothing —
    // the same failure mode a grep that matches nothing has.
    var routes = 0;
    for (final orgType in OrgType.values) {
      for (final role in <UserRole?>[null, ...UserRole.values]) {
        routes += portalNavTree(orgType: orgType, role: role)
            .expand((n) => n.leaves)
            .where((l) => l.route != null)
            .length;
      }
    }
    expect(routes, greaterThan(50));
  });

  test('every rail destination is named the same way in the top bar', () {
    final disagreements = <String>{};

    for (final orgType in OrgType.values) {
      for (final role in <UserRole?>[null, ...UserRole.values]) {
        for (final leaf
            in portalNavTree(orgType: orgType, role: role).expand((n) => n.leaves)) {
          final route = leaf.route;
          if (route == null) continue;
          if (route.startsWith('/super-admin')) continue;
          if (_allowedDivergence.containsKey(route)) continue;

          final resolved = mlRouteTitle(Uri.parse(route)).title;
          if (resolved != leaf.label) {
            disagreements.add(
              '$route\n      rail: "${leaf.label}"\n      bar:  "$resolved"',
            );
          }
        }
      }
    }

    expect(
      disagreements,
      isEmpty,
      reason: 'the rail and the top bar call these destinations different '
          'things:\n  ${disagreements.join('\n  ')}',
    );
  });

  test('the documented divergences are still divergent', () {
    // If one of these ever comes into line, the entry is dead weight and the
    // reason it records has stopped being true. An allow-list that outlives
    // its reasons is how a check quietly stops covering things.
    for (final entry in _allowedDivergence.entries) {
      final resolved = mlRouteTitle(Uri.parse(entry.key)).title;
      final labels = <String>{};
      for (final orgType in OrgType.values) {
        for (final role in <UserRole?>[null, ...UserRole.values]) {
          for (final leaf in portalNavTree(orgType: orgType, role: role)
              .expand((n) => n.leaves)) {
            if (leaf.route == entry.key) labels.add(leaf.label);
          }
        }
      }
      if (labels.isEmpty) continue; // route not in any tree for this org type
      expect(
        labels.length > 1 || !labels.contains(resolved),
        isTrue,
        reason: '${entry.key} is exempted as "${entry.value}" but the rail now '
            'agrees with the bar — remove the exemption.',
      );
    }
  });
}
