// Every route the PORTAL mounts has to say what it is in the top bar.
//
// ## Why this exists when two other files already look at portal titles
//
// `every_portal_route_is_named_test.dart` walks the **rail** and checks that
// the bar agrees with it. That is a real check and it caught a real fault, but
// it can only see destinations the rail has a leaf for — and the rail is a
// menu, not the router. Every detail page, every deep link and every screen
// reached by a button rather than a menu item is invisible to it.
//
// `every_console_route_is_named_test.dart` reads `app_router.dart` and sweeps
// the console's half for the generic "Platform Admin" fallback. Its own header
// explains why a route sweep and not another picture: the render harness
// supplies the chrome by hand, so 225 pictures can all show a top bar the
// running app never draws.
//
// Nobody had run the console's sweep over the PORTAL's half. Doing it on
// 2026-08-22 found `/portal/transporter/drop-off/:tripId` resolving to
// **"Workspace"** — the generic fallback, on the screen where a transporter
// sets the final waypoint of a live trip. It is not in any rail, so the rail
// walk could not see it, and its render photographed a hand-typed "Drop-off"
// that the app has never produced.
//
// It also found the family the employee grid was already fixed for: a page
// about ONE thing named after the list it was opened from. `/portal/mine/trips/
// t-2` — a single trip — announced itself as "Trips", and the waybill under it
// did the same.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/core/routing/ml_route_title.dart';

/// What `_portalTitle` falls back to when nothing on the ladder matches. Not
/// importable — it is a private literal — so it is copied here and pinned by
/// the sabotage test at the bottom.
const _fallback = 'Workspace';

/// Routes that legitimately resolve to the fallback, with the reason.
///
/// An inventory, not an excuse list: the test at the bottom fails if one of
/// these stops falling through, so an entry cannot outlive its reason.
///
/// Every entry here is a route that draws NO top bar, so there is no title to
/// get wrong. They are listed rather than filtered by prefix so that a new
/// chrome-less route has to be justified one line at a time.
const Map<String, String> _allowedFallback = {
  '/login': 'auth screen — full-screen, outside the portal shell',
  '/forgot-password': 'auth screen — full-screen, outside the portal shell',
  '/reset-password': 'auth screen — full-screen, outside the portal shell',
  '/whatsapp-otp': 'auth screen — full-screen, outside the portal shell',
  '/mandatory-password-change':
      'auth gate — full-screen, outside the portal shell',
  // The router says so in as many words: "/portal/driver/navigate/:tripId
  // stays outside the shell entirely (fullscreen nav)".
  '/portal/driver/navigate/t-1':
      'turn-by-turn navigation — full-screen, outside the portal shell',
  // The bar names the ACTIVE TAB here, which is per-session state the resolver
  // is not given. `every_portal_route_is_named_test.dart` records the same
  // exemption for the four section dashboards, for the same reason.
  '/home': 'bar names the active tab; the resolver has no tab set',
};

/// Every non-console `path: '/…'` literal in the router, with `:params`
/// replaced by plausible values so the resolver sees a real path.
///
/// go_router declares child routes as bare segments (`path: 'details'`), so
/// only the literals that start with `/` are whole paths — the rest are joined
/// to a parent this regex cannot see, and are covered by their parent's entry.
List<String> _portalRoutePaths() {
  final src = File('lib/core/routing/app_router.dart').readAsStringSync();
  final found = RegExp(r"""path:\s*'(/[^']*)'""")
      .allMatches(src)
      .map((m) => m.group(1)!)
      .where((p) => !p.startsWith('/super-admin'))
      .toSet()
      .toList()
    ..sort();

  return found
      .map((p) => p
          .replaceAll(':tripId', 't-1')
          .replaceAll(':routeId', 'r-1')
          .replaceAll(':companyId', 'c-1')
          .replaceAll(':employeeId', 'e-1')
          .replaceAll(':orgType', 'transporter')
          .replaceAll(':id', 'x-1'))
      .toList();
}

void main() {
  test('the router really does declare portal routes', () {
    // A regex that stops matching would make this whole file pass by testing
    // nothing — the same failure mode as a grep that matches nothing.
    expect(_portalRoutePaths().length, greaterThan(60));
  });

  test('no portal route falls through to the generic title', () {
    final unnamed = <String>[];
    for (final path in _portalRoutePaths()) {
      if (_allowedFallback.containsKey(path)) continue;
      if (mlRouteTitle(Uri.parse(path)).title == _fallback) unnamed.add(path);
    }

    expect(
      unnamed,
      isEmpty,
      reason: 'these portal routes show "$_fallback" in the top bar instead '
          'of their own name:\n  ${unnamed.join('\n  ')}',
    );
  });

  test('the documented fallbacks still fall back', () {
    for (final entry in _allowedFallback.entries) {
      expect(
        mlRouteTitle(Uri.parse(entry.key)).title,
        _fallback,
        reason: '${entry.key} is exempted as "${entry.value}" but it now '
            'resolves to a real name — remove the exemption.',
      );
    }
  });

  test('a detail page is not named after the list it came from', () {
    // The fault the employee grid was already fixed for, in the family the
    // portal has most of: `/employees/123/456/details` read "Team grid" on a
    // page about one person. A trip detail page read "Trips".
    expect(mlRouteTitle(Uri.parse('/portal/mine/trips')).title, 'Trips');
    expect(mlRouteTitle(Uri.parse('/portal/mine/trips/t-1')).title, 'Trip');
    // The waybill route wraps the trip-detail screen and opens the document as
    // a MODAL over it, so the bar behind it is still the trip's — NOT
    // "Waybill", which is what this test asserted before the route's builder
    // was read.
    expect(
      mlRouteTitle(Uri.parse('/portal/mine/trips/t-1/waybill')).title,
      'Trip',
    );
    expect(mlRouteTitle(Uri.parse('/portal/buyer/trips/t-1')).title, 'Trip');
    expect(
      mlRouteTitle(Uri.parse('/portal/transporter/trips/t-1')).title,
      'Trip',
    );
    expect(
      mlRouteTitle(Uri.parse('/portal/mine/employees/e-1')).title,
      'Employee profile',
    );
    expect(
      mlRouteTitle(Uri.parse('/portal/mine/stockpiles/s-1')).title,
      'Stockpile',
    );
    // …and the LISTS keep their plural names.
    expect(mlRouteTitle(Uri.parse('/portal/mine/employees')).title, 'Employees');
    expect(
      mlRouteTitle(Uri.parse('/portal/mine/stockpiles')).title,
      'Stockpiles',
    );
    // A filter is not a detail page: this is the same table scoped to one
    // transporter, so it keeps the table's name.
    expect(
      mlRouteTitle(Uri.parse('/portal/mine/tons-out/tr-1')).title,
      'Tons out',
    );
  });

  test('the three routes that read "Workspace" are named', () {
    // Found by this file on 2026-08-22. Two of them are on the transporter's
    // accept-and-crew deep-link path.
    expect(
      mlRouteTitle(Uri.parse('/portal/transporter/drop-off/t-1')).title,
      'Drop-off point',
    );
    expect(
      mlRouteTitle(Uri.parse('/portal/transporter/allocate-fleet/r-1')).title,
      'Vehicles',
    );
    // The alias drops its :routeId and shows the transporter dashboard, so it
    // takes the dashboard's own title — the active tab, or its landing label.
    expect(
      mlRouteTitle(
        Uri.parse('/portal/transporter/accept-route/r-1'),
        tabs: const MlPortalTabs(['Overview', 'Routes'], 0),
      ).title,
      'Overview',
    );
  });

  test('the fallback is still the fallback', () {
    // The constant at the top is a copy of a private literal. If the wording
    // changes, the sweep above silently stops looking for anything — so pin
    // the copy against a path the router deliberately does NOT mount.
    expect(
      mlRouteTitle(Uri.parse('/portal/mine/not-a-real-route')).title,
      _fallback,
    );
  });
}
