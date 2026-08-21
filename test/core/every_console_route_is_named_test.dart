// Every route the console mounts has to say what it is in the top bar.
//
// ## Why this reads the router instead of holding its own list
//
// Driving the redesign in a browser on 2026-08-21 as the platform admin, the
// targets screen's top bar read:
//
//     Platform Admin
//     Platform management
//
// while the page under it was headed "Platform targets". `_consoleTitle` is a
// ladder of `path.contains(...)` with `return 'Platform Admin'` at the bottom,
// and `/super-admin/targets` was not on the ladder. Nor were nineteen other
// routes — margin ledger, recon tables, disputes, crash reports, the live map,
// account deactivations, the two transport inboxes, all five targets screens.
// Half the console announced itself by the name of the console.
//
// **No render could have caught it.** `test/renders/redesign_renders_test.dart`
// builds its shell with `title:` and `subtitle:` passed by hand — the render
// harness supplies the chrome instead of resolving it — so all 218 pictures
// show a top bar that the running app does not produce. That is the second
// time this exact gap has bitten (see §5 of the handoff, "A RENDER HARNESS CAN
// LIE ABOUT THE CHROME"), which is why the pin is a route sweep and not
// another picture.
//
// A hand-kept list of paths would go stale the first time somebody adds a
// route — the same failure one level up. So this reads `app_router.dart` and
// takes whatever is in it.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/core/routing/ml_route_title.dart';

/// What `_consoleTitle` and `_consoleSubtitle` fall back to. Not importable —
/// they are private — so they are named here and asserted to still BE the
/// fallback by the sabotage test at the bottom.
const _titleFallback = 'Platform Admin';
const _subtitleFallback = 'Platform management';

/// Every `path: '/super-admin…'` literal in the router, with `:params`
/// replaced by a plausible value so the resolver sees a real path.
List<String> _consoleRoutePaths() {
  final src = File('lib/core/routing/app_router.dart').readAsStringSync();
  final found = RegExp(r"""path:\s*'(/super-admin[^']*)'""")
      .allMatches(src)
      .map((m) => m.group(1)!)
      .toSet()
      .toList()
    ..sort();

  return found.map((p) {
    // `:orgType` has to be a real org type — the insights title only claims a
    // path that looks like one, and substituting "x" everywhere would make
    // this test pass for the wrong reason.
    return p
        .replaceAll(':orgType', 'transporter')
        .replaceAll(':companyId', 'c-1')
        .replaceAll(':orgId', 'o-1')
        .replaceAll(':type', 'transportation');
  }).toList();
}

void main() {
  test('the router really does declare console routes', () {
    // If the regex ever stops matching — a reformat, a renamed field — this
    // whole file would pass by testing nothing. Same failure mode as a grep
    // that matches nothing, and the reason `release_guards.dart` has a
    // selftest.
    expect(_consoleRoutePaths().length, greaterThan(30));
  });

  test('no console route falls through to the generic title', () {
    final unnamed = <String>[];
    for (final path in _consoleRoutePaths()) {
      final resolved = mlRouteTitle(Uri.parse(path));
      if (resolved.title == _titleFallback) unnamed.add(path);
    }

    expect(
      unnamed,
      isEmpty,
      reason: 'these console routes show "$_titleFallback" in the top bar '
          'instead of their own name:\n  ${unnamed.join('\n  ')}',
    );
  });

  test('no console route falls through to the generic subtitle', () {
    final unnamed = <String>[];
    for (final path in _consoleRoutePaths()) {
      final resolved = mlRouteTitle(Uri.parse(path));
      if (resolved.subtitle == _subtitleFallback) unnamed.add(path);
    }

    expect(
      unnamed,
      isEmpty,
      reason: 'these console routes show "$_subtitleFallback" under their '
          'title, which says nothing about the screen:\n  '
          '${unnamed.join('\n  ')}',
    );
  });

  test('a console title is never the same as its subtitle', () {
    for (final path in _consoleRoutePaths()) {
      final r = mlRouteTitle(Uri.parse(path));
      expect(
        r.subtitle,
        isNot(equals(r.title)),
        reason: '$path repeats its title as its own subtitle',
      );
    }
  });

  test('the two fallbacks are still the fallbacks', () {
    // The constants at the top of this file are copies of two private string
    // literals. If somebody changes the fallback wording, the sweep above
    // silently stops looking for anything — so pin the copies against a path
    // that is deliberately NOT a route: nothing in the router mounts
    // `/super-admin/not-a-real-route`, so it must land on both fallbacks.
    final r = mlRouteTitle(Uri.parse('/super-admin/not-a-real-route'));
    expect(r.title, _titleFallback);
    expect(r.subtitle, _subtitleFallback);
  });
}
