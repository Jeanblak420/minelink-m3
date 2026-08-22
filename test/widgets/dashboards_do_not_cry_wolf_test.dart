// A dashboard must not tell its reader a feed is broken while it is still
// reading it.
//
// Driven in a browser as `roadhaul.admin` on 2026-08-22, on a clean sign-in,
// the transporter dashboard came up with SEVEN failure states at once:
//
//     — Tons moved        earnings feed unavailable
//     — Revenue           earnings feed unavailable
//     — Trucks on route   fleet status unavailable
//     — Fleet utilisation fleet status unavailable
//     Earnings unavailable      The trip-earnings feed could not be read.
//     Fleet status unavailable  The vehicle availability feed could not be read.
//     Trips unavailable         The trip-earnings feed could not be read.
//
// …and then filled in by itself, with no reload and no retry: 235 t, R184,611,
// 2 trucks on route, 67% utilisation. Nothing had gone wrong. Both RPCs
// returned HTTP 200 with real rows — captured from the network panel, which is
// what made it worth chasing rather than dismissing as a backend blip.
//
// The cause is one line repeated: a dashboard reads `feed.valueOrNull`, which
// collapses "still reading" and "could not read" into the same null, and every
// widget downstream treats that null as failure. The three dashboards' own
// source has carried a comment naming this trap since 2026-08-21 — it was
// written when the MINE's stockpile ring did the same thing to a mine owner —
// and the fix at the time was applied to that one card. The KPI band of all
// three dashboards, and six more panels, were left in it.
//
// So this test is written against the CLASS, not the card: mount each of the
// three role dashboards with every feed pending, and fail if any failure
// vocabulary is on screen.
//
// ## It has to fail in BOTH directions
//
// A test that only checks "no error words while loading" passes if somebody
// deletes the error states altogether — which would be worse, because a feed
// that genuinely cannot be read would then say nothing at all. The second
// group mounts the same dashboards with every feed THROWING and requires the
// failure wording to appear.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/core/theme/app_theme.dart';
import 'package:flutter_application_1/features/fleet/providers/fleet_provider.dart';
import 'package:flutter_application_1/features/portal/providers/lifecycle_provider.dart';
import 'package:flutter_application_1/features/portal/providers/request_provider.dart';
import 'package:flutter_application_1/features/portal/screens/buyer_portal_dashboard_screen.dart';
import 'package:flutter_application_1/features/portal/screens/mine_supplier_portal_dashboard_screen.dart';
import 'package:flutter_application_1/features/portal/screens/transporter_portal_dashboard_screen.dart';
import 'package:flutter_application_1/features/portal/services/earnings_service.dart';
import 'package:flutter_application_1/features/portal/services/buyer_value_service.dart';
import 'package:flutter_application_1/features/portal/services/dispute_service.dart';

import 'package:flutter_application_1/features/portal/widgets/dashboard/portal_dashboard_kit.dart';

import 'package:flutter_application_1/features/auth/models/user_type.dart';

import '../fixtures/portal_capture_fixtures.dart';
import '../fixtures/portal_tail_fixtures.dart';
import '../fixtures/screen_fixtures.dart';
import '../test_helpers/frozen_clock.dart';
import '../test_helpers/real_fonts.dart';
import '../test_helpers/test_supabase.dart';

/// The words a dashboard is only allowed to say once a read has actually
/// failed. Matched case-insensitively as substrings.
const _failureWords = <String>[
  'unavailable',
  'could not be read',
  'could not read',
];

/// A future that never answers — a read still in flight.
Future<T> _pending<T>() => Completer<T>().future;

/// Overrides that put every feed the three dashboards read into [state].
///
/// Appended AFTER `portalCaptureOverrides()`, whose data these replace: the
/// dashboards need the rest of that fixture (the logistics snapshot gates the
/// mine's whole body behind a spinner) or the page under test never renders.
List<Override> _feedOverrides({required bool throwing}) {
  Future<List<T>> feed<T>() =>
      throwing ? Future<List<T>>.error(StateError('boom')) : _pending();
  return [
    // transporter
    tripEarningsProvider.overrideWith((ref, _) => feed()),
    fleetStatusProvider.overrideWith((ref, _) => feed()),
    // mine
    stockpilesProvider.overrideWith((ref, _) => feed()),
    mineInboundTripsProvider.overrideWith((ref, _) => feed()),
    // buyer
    buyerTripValuesProvider.overrideWith((ref, _) => feed()),
    // shared
    companyRequestsProvider.overrideWith((ref, _) => feed()),
    reconDisputesProvider.overrideWith((ref, _) => feed()),
  ];
}

/// Every `Text` currently on screen whose content contains one of [words].
List<String> _textsMatching(List<String> words) {
  final found = <String>[];
  for (final word in words) {
    final f = find.textContaining(RegExp(word, caseSensitive: false));
    for (final e in f.evaluate()) {
      final w = e.widget;
      if (w is Text && w.data != null) found.add(w.data!);
    }
  }
  return found;
}

void main() {
  // Real fonts, or every metric here is a fallback font's (CLAUDE.md §7).
  setUpAll(loadRealFonts);
  // `portalTailOverrides()` builds repositories whose constructors reach for
  // `SupabaseConfig.client`, so an instance has to exist even though nothing
  // here dials out. Pointed at a dummy host by the helper.
  setUpAll(ensureTestSupabaseInitialized);
  // The capture fixtures date every row relative to `kCaptureNow`, and these
  // dashboards bucket by rolling window off `MlTime.now()`. Without this the
  // file would pass for a few days and then go off with nothing changed but
  // the calendar — held by the `capture-fixture-without-a-frozen-clock` guard,
  // which caught this file on the run it was written.
  setUp(freezeCaptureClock);

  Future<List<String>> render(
    WidgetTester tester,
    Widget dashboard, {
    required bool throwing,
    required OrgType orgType,
  }) async {
    tester.view.physicalSize = const Size(1600, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // NESTED SCOPES, not one list with duplicate entries.
    //
    // `portalCaptureOverrides()` already overrides these same providers with
    // DATA. Listing both in one `overrides:` is not a documented way to say
    // "mine wins", and it does not behave like one: with the fixtures last the
    // loading half passed over fixture data (a check that cannot fail), and
    // with them first it passed for the opposite reason. An inner scope wins
    // for everything below it and falls through to the outer for everything
    // else, which is exactly what is wanted — the dashboards need the rest of
    // that fixture (the mine's whole body is gated behind the logistics
    // snapshot) or the page under test never renders at all.
    await tester.pumpWidget(ProviderScope(
      overrides: [
        // Without these the dashboards resolve NO company and render
        // "Company not loaded" — nothing else at all. The first run of this
        // test dumped an empty widget tree and would have passed its
        // no-error-words assertion over a blank page.
        authOverride(userType: UserType.employee),
        companyOverride(orgType: orgType),
        employeeOverride(orgType: orgType),
        ...portalTailOverrides(),
        ...portalCaptureOverrides(),
      ],
      // The app's own theme, not stock Material's — see
      // `test-renders-under-the-app-theme`.
      child: MaterialApp(
        theme: AppTheme.darkTheme,
        home: ProviderScope(
          overrides: _feedOverrides(throwing: throwing),
          child: dashboard,
        ),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // A provider that throws is a legitimate state here — the whole point of
    // the second group — so its exceptions are DRAINED rather than suppressed.
    //
    // Overriding `FlutterError.onError` and restoring it in a tearDown does
    // not work: the binding asserts that a test which overrode it either put
    // it back before `expect()` or handled every error, and the restore
    // happens too late. `takeException()` is the supported way, and it returns
    // one error per call, so it is drained in a loop.
    while (tester.takeException() != null) {}

    return _textsMatching(_failureWords);
  }


  final dashboards = <String, ({Widget Function() build, OrgType org})>{
    'transporter': (
      build: () => const TransporterPortalDashboardScreen(),
      org: OrgType.transporter
    ),
    'mine': (
      build: () => const MineSupplierPortalDashboardScreen(),
      org: OrgType.mineSupplier
    ),
    'buyer': (
      build: () => const BuyerPortalDashboardScreen(),
      org: OrgType.buyer
    ),
  };

  group('a feed still in flight is not reported as broken', () {
    dashboards.forEach((name, d) {
      testWidgets('$name dashboard', (tester) async {
        final cried = await render(tester, d.build(), throwing: false, orgType: d.org);
        // POSITIVE EVIDENCE FIRST. Without this the assertion below passes
        // over a dashboard full of fixture DATA — no error words, no loading
        // words, nothing pending at all — which is exactly how the first
        // version of this test passed while proving nothing.
        expect(
          _textsMatching(const [kPortalKpiLoadingReason, 'Reading ']),
          isNotEmpty,
          reason: 'the $name dashboard is supposed to be mid-read here and is '
              'not saying so anywhere — the pending overrides are probably not '
              'taking effect, so the check below is testing nothing.',
        );
        expect(
          cried,
          isEmpty,
          reason: 'the $name dashboard tells its reader a feed has FAILED '
              'while it is still being read:\n  ${cried.join('\n  ')}\n'
              'Pass the feed\'s `AsyncValue.isFirstLoad` through — '
              '`PortalKpi.loading` for a tile, `portalFeedPending()` for a '
              'panel. `valueOrNull` cannot tell the two apart.',
        );
      });
    });
  });

  group('a feed that really did fail still says so', () {
    // Without this half, deleting every error state passes the group above —
    // and a dashboard that says nothing when a read fails is worse than one
    // that cries wolf.
    dashboards.forEach((name, d) {
      testWidgets('$name dashboard', (tester) async {
        final said = await render(tester, d.build(), throwing: true, orgType: d.org);
        expect(
          said,
          isNotEmpty,
          reason: 'every feed on the $name dashboard is erroring and the page '
              'says nothing about it. The loading/failed split must keep the '
              'FAILED half.',
        );
        // AND THE SYMMETRIC HALF. `isNotEmpty` above is satisfied by any
        // failure text anywhere, so it survives a change that silences one
        // BAND while the others still speak — proved by sabotage: making the
        // KPI tile always print the loading reason left this group green
        // because the panels underneath still said "unavailable".
        //
        // A feed that has failed must not claim to be still reading, which is
        // the exact mirror of the group above and cannot be satisfied by a
        // neighbour.
        final stillClaimingToRead =
            _textsMatching(const [kPortalKpiLoadingReason, 'Reading ']);
        expect(
          stillClaimingToRead,
          isEmpty,
          reason: 'every feed on the $name dashboard has FAILED, and it is '
              'still telling its reader it is loading: '
              '${stillClaimingToRead.join(", ")}',
        );
      });
    });
  });
}
