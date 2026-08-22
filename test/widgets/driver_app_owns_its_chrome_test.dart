// The driver's app draws its own chrome. The portal shell must not draw it
// again on top.
//
// `DriverAppScreen` is a complete shell — its own scaffold, its own
// Dashboard · Trip · Profile bottom bar, its own `ProfileSetupBanner`. So
// `PortalShellLayout` returns it BARE (inside a `ChatDock`, see
// `driver_can_reach_chat_test.dart`) instead of wrapping it in the rail, the
// top bar and the banners every other role gets.
//
// It decided that with an exact-match set of three paths:
//
//     const {'/portal/driver/home', '/portal/driver/trip',
//            '/portal/driver/profile'}.contains(shellPath)
//
// `/portal/driver/trip/:id/waybill` renders that same `DriverAppScreen` — the
// Trip tab, with the signed waybill opened over it — and is not one of those
// three strings. Driven in a browser as the real driver on 2026-08-22, one
// navigation after recording a POD, it came back with:
//
//   * the account-setup banner drawn TWICE, one directly above the other,
//     each with its own "Complete now" button
//   * the portal rail down the left AND the driver's own bottom bar underneath
//
// Photographed. Nothing caught it: the render harness builds `MlAppShell`
// directly and never mounts `PortalShellLayout`, and every widget test of the
// driver screens builds `DriverAppScreen` on its own — the same blind spot
// that hid the missing chat dock from the same shell two sessions ago.
//
// A list of three strings cannot see a fourth route being added. So this reads
// the ROUTER, works out which driver routes render the driver app, and asserts
// the predicate agrees — which is a rule about what a route SHOWS rather than
// about what it is spelled.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/features/portal/widgets/portal_shell_layout.dart';

/// Every `/portal/driver/...` route the router mounts, with its builder body.
///
/// go_router declares these as `GoRoute(path: '...', builder: ...)`, so the
/// body is everything between the path literal and the closing of that route.
Map<String, String> _driverRoutes() {
  final src = File('lib/core/routing/app_router.dart').readAsStringSync();
  final out = <String, String>{};
  final re = RegExp(r"path: '(/portal/driver/[^']*)',");
  for (final m in re.allMatches(src)) {
    final path = m.group(1)!;
    // The builder for this route: from the path literal to the next `path:`
    // literal, or 900 characters, whichever comes first. Generous on purpose —
    // over-reading can only make the DriverAppScreen test STRICTER, never
    // looser, because a false positive would demand bare chrome for a route
    // that does not need it and fail loudly.
    final start = m.end;
    final nextPath = src.indexOf("path: '", start);
    final end = nextPath < 0
        ? (start + 900).clamp(0, src.length)
        : nextPath.clamp(0, (start + 900).clamp(0, src.length));
    out[path] = src.substring(start, end);
  }
  return out;
}

void main() {
  test('the router really does declare driver routes', () {
    // A regex that stops matching would make this file pass by testing
    // nothing.
    expect(_driverRoutes().length, greaterThanOrEqualTo(5));
  });

  test('every route that renders the driver app is rendered bare', () {
    final wrong = <String>[];
    for (final entry in _driverRoutes().entries) {
      final rendersDriverApp = entry.value.contains('DriverAppScreen(');
      if (!rendersDriverApp) continue;
      // `/portal/driver/navigate/:tripId` is outside the shell entirely, so
      // the predicate never sees it — but it does not render the driver app
      // either, so it never reaches here.
      if (!driverAppOwnsChrome(entry.key)) {
        wrong.add('${entry.key} renders DriverAppScreen but '
            'driverAppOwnsChrome() says false, so PortalShellLayout will wrap '
            "it in the portal's rail, top bar and ProfileSetupBanner — on top "
            'of the ones the driver app already draws');
      }
    }
    expect(wrong, isEmpty, reason: wrong.join('\n'));
  });

  test('a route that does NOT render the driver app keeps the shell', () {
    final wrong = <String>[];
    for (final entry in _driverRoutes().entries) {
      if (entry.value.contains('DriverAppScreen(')) continue;
      if (driverAppOwnsChrome(entry.key)) {
        wrong.add('${entry.key} does not render the driver app, but '
            'driverAppOwnsChrome() says true — it will be rendered with no '
            'rail, no top bar and no way back');
      }
    }
    expect(wrong, isEmpty, reason: wrong.join('\n'));
  });

  test('the predicate itself', () {
    // The three the old set held.
    expect(driverAppOwnsChrome('/portal/driver/home'), isTrue);
    expect(driverAppOwnsChrome('/portal/driver/trip'), isTrue);
    expect(driverAppOwnsChrome('/portal/driver/profile'), isTrue);
    // The one it did not, and the fault this file exists for.
    expect(
      driverAppOwnsChrome('/portal/driver/trip/927cbf1b/waybill'),
      isTrue,
      reason: 'this is the exact path that came back with two account-setup '
          'banners and two navigations on 2026-08-22',
    );
    // An ordinary page under the same prefix, which NEEDS the shell.
    expect(driverAppOwnsChrome('/portal/driver/notifications'), isFalse);
    // And nothing outside the driver's own space.
    expect(driverAppOwnsChrome('/portal/mine/trips/t-1'), isFalse);
    expect(driverAppOwnsChrome('/home'), isFalse);
    // Not a prefix match on the whole driver space: `/portal/driver/tripwise`
    // would be a different route, and `startsWith('/portal/driver/trip')`
    // without the slash would silently claim it.
    expect(driverAppOwnsChrome('/portal/driver/tripwise'), isFalse);
  });
}
