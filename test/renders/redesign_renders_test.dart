// Renders the redesign to PNGs you can actually look at.
//
// The app needs a Supabase session to reach the console, so a browser visit
// only ever shows the login screen. These goldens render the real screens —
// real widgets, real fonts, real fixture data — inside the real shell, so the
// design can be judged without credentials and without a device.
//
// Regenerate:
//
//     flutter test test/renders --update-goldens
//
// Output lands in docs/redesign/renders/.
//
// This is a RENDER test, not an assertion test. It is expected to be updated
// whenever the design changes on purpose; the layout sweeps in test/widgets are
// what actually fail on a regression. Keeping the two apart matters — a golden
// that fails on every intentional change teaches people to regenerate without
// looking, which is worse than having no golden at all.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
// `hide UserIdentity`: gotrue exports a class of the same name, and this file
// wants the design system's.
import 'package:supabase_flutter/supabase_flutter.dart' hide UserIdentity;

import 'package:flutter_application_1/core/design/shell/ml_app_shell.dart';
import 'package:flutter_application_1/core/design/shell/ml_rail_blocks.dart';
import 'package:flutter_application_1/core/routing/ml_route_title.dart';
import 'package:flutter_application_1/core/theme/app_theme.dart';
import 'package:flutter_application_1/core/routing/route_not_found_screen.dart';
import 'package:flutter_application_1/core/time/ml_time.dart';
import 'package:flutter_application_1/core/widgets/osm_tile_layer.dart';
import 'package:flutter_map/flutter_map.dart' show NetworkTileProvider;
import 'package:flutter_application_1/core/widgets/user_identity_flyout.dart';
import 'package:flutter_application_1/features/auth/models/user_type.dart';
import 'package:flutter_application_1/features/auth/screens/login_screen.dart';
import 'package:flutter_application_1/features/auth/screens/forgot_password_screen.dart';
import 'package:flutter_application_1/features/auth/screens/reset_password_screen.dart';
import 'package:flutter_application_1/features/auth/screens/whatsapp_otp_screen.dart';
import 'package:flutter_application_1/features/auth/screens/mandatory_password_change_screen.dart';
import 'package:flutter_application_1/features/employee/screens/company_selection_screen.dart';
import 'package:flutter_application_1/features/super_admin/screens/expired_access_screen.dart';
import 'package:flutter_application_1/features/company/screens/company_employees_screen.dart';
import 'package:flutter_application_1/features/employee/screens/employee_profile_screen.dart';
import 'package:flutter_application_1/features/company/screens/company_list_screen.dart';
import 'package:flutter_application_1/features/employee/screens/employee_grid_screen.dart';
import 'package:flutter_application_1/features/portal/screens/portal_tons_out_screen.dart';
import 'package:flutter_application_1/features/portal/screens/portal_tons_out_search_screen.dart';
import 'package:flutter_application_1/features/portal/screens/transporter_request_tracking_screen.dart';
import 'package:flutter_application_1/features/home/screens/home_screen.dart';
import 'package:flutter_application_1/features/super_admin/screens/super_admin_company_mirror_screen.dart';
import 'package:flutter_application_1/features/portal/screens/portal_trips_screen.dart';
import 'package:flutter_application_1/features/portal/screens/live_trip_map_screen.dart';
import 'package:flutter_application_1/features/portal/screens/mine_supplier_buyers_detail_screen.dart';
import 'package:flutter_application_1/features/portal/screens/driver_app_screen.dart';
import 'package:flutter_application_1/features/super_admin/screens/transporters_overview_v2_screen.dart';
import 'package:flutter_application_1/features/fleet/screens/fleet_management_screen.dart';
import 'package:flutter_application_1/features/operations/screens/operations_hub_screen.dart';
import 'package:flutter_application_1/features/chat/screens/communications_hub_screen.dart';
import 'package:flutter_application_1/features/chat/screens/messages_screen.dart';
import 'package:flutter_application_1/features/chat/screens/chat_screen.dart';
import 'package:flutter_application_1/features/chat/widgets/chat_dock.dart';
import 'package:flutter_application_1/features/notifications/screens/notification_screen.dart';
import 'package:flutter_application_1/features/notifications/screens/notification_management_screen.dart';
import 'package:flutter_application_1/features/profile/screens/profile_screen.dart';
import 'package:flutter_application_1/features/profile/screens/account_security_screen.dart';
import 'package:flutter_application_1/features/portal/screens/appearance_theme_screen.dart';
import 'package:flutter_application_1/features/company/screens/employee_register_screen.dart';
import 'package:flutter_application_1/features/portal/screens/buyer_portal_dashboard_screen.dart';
import 'package:flutter_application_1/features/portal/screens/buyer_loads_value_screen.dart';
import 'package:flutter_application_1/features/portal/screens/buyer_waybills_screen.dart';
import 'package:flutter_application_1/features/portal/screens/buyer_requests_screen.dart';
import 'package:flutter_application_1/features/portal/screens/buyer_routes_mines_screen.dart';
import 'package:flutter_application_1/features/portal/screens/buyer_truck_locations_screen.dart';
import 'package:flutter_application_1/features/portal/screens/mine_locations_screen.dart';
import 'package:flutter_application_1/features/portal/screens/stockpile_detail_screen.dart';
import 'package:flutter_application_1/features/portal/screens/stockpile_audit_screen.dart';
import 'package:flutter_application_1/features/portal/screens/tons_out_detail_screen.dart';
import 'package:flutter_application_1/features/portal/screens/transporter_drivers_screen.dart';
import 'package:flutter_application_1/features/portal/screens/fuel_costs_screen.dart';
import 'package:flutter_application_1/features/portal/screens/compliance_screen.dart';
import 'package:flutter_application_1/features/portal/screens/drop_off_screen.dart';
import 'package:flutter_application_1/features/portal/screens/portal_own_company_screen.dart';
import 'package:flutter_application_1/features/portal/screens/request_transportation_screen.dart';
import 'package:flutter_application_1/features/portal/screens/portal_trip_detail_screen.dart';
import 'package:flutter_application_1/features/portal/widgets/waybill_modal.dart';
import 'package:flutter_application_1/features/portal/screens/mine_supplier_truck_locations_screen.dart';
import 'package:flutter_application_1/features/portal/screens/transporter_truck_locations_screen.dart';
import 'package:flutter_application_1/features/portal/screens/earnings_screen.dart';
import 'package:flutter_application_1/features/portal/screens/mine_production_screen.dart';
import 'package:flutter_application_1/features/portal/screens/mine_quality_screen.dart';
import 'package:flutter_application_1/features/portal/screens/supervisor_view_screen.dart';
import 'package:flutter_application_1/features/portal/screens/transporter_maintenance_screen.dart';
import 'package:flutter_application_1/features/portal/screens/transporter_routes_screen.dart';
import 'package:flutter_application_1/features/portal/screens/trucks_on_route_screen.dart';
import 'package:flutter_application_1/features/portal/screens/driver_navigation_screen.dart';
import 'package:flutter_application_1/features/portal/screens/driver_routes_screen.dart';
import 'package:flutter_application_1/features/portal/screens/load_controller_screen.dart';
import 'package:flutter_application_1/features/portal/screens/security_checkin_screen.dart';
import 'package:flutter_application_1/features/portal/screens/buyer_reconciliations_screen.dart';
import 'package:flutter_application_1/features/portal/screens/mine_reconciliations_screen.dart';
import 'package:flutter_application_1/features/portal/screens/mine_supplier_portal_dashboard_screen.dart';
import 'package:flutter_application_1/features/portal/screens/transporter_reconciliations_screen.dart';
import 'package:flutter_application_1/features/super_admin/screens/recon_tables_screen.dart';
import 'package:flutter_application_1/features/super_admin/screens/request_review_screen.dart';
import 'package:flutter_application_1/features/super_admin/screens/dispute_inbox_screen.dart';
import 'package:flutter_application_1/features/super_admin/screens/organization_management_screen.dart';
import 'package:flutter_application_1/features/super_admin/screens/targets_platform_screen.dart';
import 'package:flutter_application_1/features/super_admin/screens/targets_org_type_screen.dart';
import 'package:flutter_application_1/features/super_admin/screens/targets_company_screen.dart';
import 'package:flutter_application_1/features/super_admin/screens/platform_users_screen.dart';
import 'package:flutter_application_1/features/super_admin/screens/audit_logs_screen.dart';
import 'package:flutter_application_1/features/super_admin/screens/token_history_screen.dart';
import 'package:flutter_application_1/features/super_admin/screens/organization_detail_screen.dart';
import 'package:flutter_application_1/features/super_admin/screens/available_routes_screen.dart';
import 'package:flutter_application_1/features/super_admin/screens/route_marketplace_screen.dart';
import 'package:flutter_application_1/features/super_admin/screens/crash_reports_screen.dart';
import 'package:flutter_application_1/features/super_admin/screens/account_deactivations_screen.dart';
import 'package:flutter_application_1/features/super_admin/screens/live_map_screen.dart';
import 'package:flutter_application_1/features/super_admin/screens/super_admin_dashboard_v2_screen.dart';
import 'package:flutter_application_1/features/super_admin/screens/transporter_leaderboard_screen.dart';
import 'package:flutter_application_1/features/super_admin/screens/chat_connections_screen.dart';
import 'package:flutter_application_1/features/super_admin/screens/driver_limit_requests_screen.dart';
import 'package:flutter_application_1/features/super_admin/screens/platform_admin_settings_screen.dart';
import 'package:flutter_application_1/features/super_admin/screens/register_company_screen.dart';
import 'package:flutter_application_1/features/super_admin/screens/user_preferences_screen.dart';
import 'package:flutter_application_1/features/super_admin/screens/request_tracking_screen.dart';
import 'package:flutter_application_1/features/super_admin/screens/token_requests_screen.dart';
import 'package:flutter_application_1/features/super_admin/screens/margin_ledger_screen.dart';
import 'package:flutter_application_1/features/super_admin/screens/super_admin_org_insights_screen.dart';
import 'package:flutter_application_1/features/portal/screens/transporter_portal_dashboard_screen.dart';
import 'package:flutter_application_1/features/portal/nav/portal_nav.dart';
import 'package:flutter_application_1/features/profile_setup/screens/profile_setup_screen.dart';
import 'package:flutter_application_1/features/super_admin/nav/console_nav.dart';
import 'package:flutter_application_1/features/super_admin/widgets/insights_v2/minelink_screen_dashboard.dart';

import '../fixtures/console_capture_fixtures.dart';
import '../fixtures/employee_profile_fixtures.dart';
import '../fixtures/console_tail_fixtures.dart';
import '../fixtures/ml_sample_data.dart';
import '../fixtures/nav_fixtures.dart';
import '../fixtures/portal_capture_fixtures.dart';
import '../fixtures/portal_tail_fixtures.dart';
import '../fixtures/shared_tail_fixtures.dart';
import '../fixtures/screen_fixtures.dart';
import '../test_helpers/fake_geolocator.dart';
import '../test_helpers/fake_path_provider.dart';
import '../test_helpers/real_fonts.dart';
import '../test_helpers/render_pumps.dart';
import 'low_contrast_report.dart';

/// Screen class name -> the console route that builds it, read off the router.
///
/// ## Why the harness is not allowed to write its own chrome any more
///
/// Every console render used to be built with `selectedRoute: '/super-admin'`,
/// `title: 'Global Admin'` and `subtitle: 'Platform overview'` passed by hand.
/// Three separate things were wrong with that, and all three were invisible
/// **because the picture is the evidence and the frame is part of it**:
///
///  * The running app produces `Global Admin · Dashboard` /
///    `Full system overview · Live · updated just now` for that route. So a
///    hundred pictures showed a top bar the product does not have.
///  * The rail highlighted **Dashboard** on every one of them — including the
///    audit log, the margin ledger and the crash reports. A reader checking
///    "does the rail show where I am" got yes, always, wrongly.
///  * And because the chrome was a literal rather than a resolution, no render
///    could ever have caught the 21 console routes whose top bar really did
///    read "Platform Admin / Platform management". Driving the built web app
///    is what found those, and this is the change that lets a picture find the
///    next one.
///
/// So `console()` no longer takes a title at all: it takes a route, defaults
/// it by looking the body's own class up in `app_router.dart`, and resolves
/// the chrome through `mlRouteTitle` exactly as `MlAppShell` does in the app.
///
/// Parsed from source rather than hand-listed for the reason
/// `tool/unphotographed_screens.py` gives for doing the same: an inventory
/// kept by hand drifts, and this one would drift silently into another
/// mislabelled frame.
final Map<String, String> _consoleRouteByScreen = () {
  final src = File('lib/core/routing/app_router.dart').readAsStringSync();
  final map = <String, String>{};
  // `path:` then, within the same GoRoute block, the screen classes its
  // builder can return. The window stops at the next `path:` so a builder
  // never claims the following route's screens.
  final routeStarts = RegExp(
    r"""path:\s*'(/super-admin[^']*)'""",
  ).allMatches(src).toList();
  for (var i = 0; i < routeStarts.length; i++) {
    final m = routeStarts[i];
    final end = i + 1 < routeStarts.length
        ? routeStarts[i + 1].start
        : src.length;
    final block = src.substring(m.end, end);
    final path = m
        .group(1)!
        .replaceAll(':orgType', 'transporter')
        .replaceAll(':companyId', 'c-1')
        .replaceAll(':orgId', 'o-1')
        .replaceAll(':type', 'transportation');
    for (final s in RegExp(
      r'\b([A-Z][A-Za-z0-9_]*Screen)\b',
    ).allMatches(block)) {
      // First route wins: a screen mounted at two paths keeps the one the
      // router declares first, which is the canonical one in every case here.
      map.putIfAbsent(s.group(1)!, () => path);
    }
  }
  return map;
}();

void main() {
  _noOrphanGoldensTest();

  // If the regex behind `_consoleRouteByScreen` ever stops matching — a
  // reformat, a renamed field, `path :` with a space — every console render
  // falls back to '/super-admin' and quietly goes back to captioning the whole
  // console "Global Admin · Dashboard" with the Dashboard rail item lit. That
  // is the exact failure this map was added to end, and it would look like 100
  // passing renders. So it is asserted, not assumed.
  test('the render harness can still read routes out of the router', () {
    expect(_consoleRouteByScreen.length, greaterThan(20));
    expect(_consoleRouteByScreen['AuditLogsScreen'], '/super-admin/audit-logs');
    expect(
      _consoleRouteByScreen['MarginLedgerScreen'],
      '/super-admin/margin-ledger',
    );
    // And the chrome it resolves is the app's, not a literal.
    expect(
      mlRouteTitle(Uri.parse('/super-admin/audit-logs')).title,
      'Audit logs',
    );
  });

  setUpAll(() async {
    await loadRealFonts();
    final icons = await loadMaterialIcons();
    // A render nobody can read is not evidence. Say so loudly rather than
    // quietly producing a grid of hollow squares and calling it a screenshot.
    if (!icons) {
      // ignore: avoid_print
      print(
        'WARNING: MaterialIcons not found in the SDK cache — every icon in '
        'these renders will be an empty box.',
      );
    }
    SharedPreferences.setMockInitialValues({});
    // `flutter_map`'s tile cache asks path_provider for a directory before it
    // will even conclude a tile is unavailable, and the MissingPluginException
    // that follows fails the TEST from an async gap rather than the widget.
    installFakePathProvider();
    // And keep `flutter_cache_manager` out of the maps entirely.
    //
    // The disk-backed tile provider holds a housekeeping timer on its
    // `CacheStore`, and a pending timer fails the test AFTER the body has
    // run - with the golden already on disk. The console's live map tripped
    // it the first time it was rendered, and the phone frame passed only
    // because it asks for fewer tiles, which is the shape of a flake rather
    // than a pass. `NetworkTileProvider` is flutter_map's own and is what
    // this app already ships on web.
    mlTileProviderOverride = NetworkTileProvider.new;
    addTearDown(() => mlTileProviderOverride = null);
    // FREEZE THE CLOCK.
    //
    // The driver's navigation HUD prints an ETA, which is a real clock time, so
    // its golden changed every minute and could never match twice. Every time
    // in this product comes through `MlTime` (CLAUDE.md §7.1), so one hook
    // settles it for every screen that shows a relative date, a rolling window
    // or a countdown — not just this one.
    //
    // `kCaptureNow` is the same instant the portal fixtures are stamped from,
    // so "5 days ago" in a render means five days from the data beside it.
    MlTime.debugClock = () => kCaptureNow;
    addTearDown(() => MlTime.debugClock = null);
    await Supabase.initialize(
      url: 'http://localhost:54321',
      anonKey: 'render-test-key',
    );
  });

  /// The console inside the real shell.
  ///
  /// [body] defaults to the platform dashboard. Pass another console screen to
  /// photograph it with the real rail, top bar and canvas around it — which is
  /// the whole point, since Jean's brief is about "the placement of everything"
  /// and a console screen out of its chrome is not that.
  Widget console({
    required Brightness brightness,
    bool railExpanded = true,
    Widget? body,
    List<Override> extraOverrides = const [],
  }) {
    // The route this body is really mounted at, and therefore the rail item
    // that should be lit and the chrome the app would draw. See
    // `_consoleRouteByScreen` for why none of this is written by hand.
    final route = body == null
        ? '/super-admin'
        : (_consoleRouteByScreen[body.runtimeType.toString()] ??
              '/super-admin');
    final chrome = mlRouteTitle(Uri.parse(route));

    return ProviderScope(
      overrides: [...companyScopeOverrides(), ...extraOverrides],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.build(brightness),
        home: MlAppShell(
          tree: consoleNavTree(),
          selectedRoute: route,
          onNavigate: (_) {},
          title: chrome.title,
          subtitle: chrome.subtitle ?? '',
          expanded: railExpanded,
          onExpandedChanged: (_) {},
          badgeCounts: const {
            MlNavBadge.pendingRequests: 4,
            MlNavBadge.openDisputes: 2,
            MlNavBadge.unreadNotifications: 7,
          },
          leading: const BackButton(),
          railHeader: MlRailBrand(
            expanded: railExpanded,
            subtitle: 'GLOBAL ADMIN',
            onTap: () {},
          ),
          railFooter: MlRailIdentity(
            expanded: railExpanded,
            identity: const UserIdentity(
              name: 'Jean Blak',
              email: 'jean@cyberhouse.co.za',
              roleLabel: 'Super Admin',
            ),
            onOpenProfile: () {},
          ),
          actions: [
            IconButton(
              onPressed: () {},
              icon: const Icon(Icons.notifications_outlined),
            ),
            IconButton(
              onPressed: () {},
              icon: const Icon(Icons.more_vert_rounded),
            ),
          ],
          // Explicit fixture data. These four used to DEFAULT to MlSampleData,
          // which is how fabricated platform totals could reach a real admin
          // (P9-03). A render test is a legitimate caller of sample data — so
          // it says so, out loud, at the call site.
          child:
              body ??
              MineLinkDashboardScreen(
                orgAggregates: MlSampleData.orgAggregates,
                pendingRequests: MlSampleData.pendingRequests,
                registry: MlSampleData.registry,
                recentOrgs: MlSampleData.recentOrgs,
              ),
        ),
      ),
    );
  }

  /// [act] runs after the tree has settled and before the picture is taken.
  ///
  /// Some screens only show their real content once something is SELECTED — the
  /// request inboxes are a list until a row is opened, and the whole
  /// due-diligence gate CLAUDE.md §4 describes lives in the panel underneath.
  /// A render of the unselected state photographs the index, not the screen.
  Future<void> shoot(
    WidgetTester tester,
    Widget widget,
    Size size,
    String name, {
    Future<void> Function(WidgetTester tester)? act,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // Capture EVERYTHING the framework throws, then REPORT it and still write
    // the image.
    //
    // The point of this file is to produce something to look at. A render that
    // refuses to exist because the screen inside it overflows tells you less
    // than the picture of it overflowing — and the picture is what makes the
    // fault arguable. The layout sweeps in test/widgets are what fail the
    // build; this one documents.
    //
    // IT USED TO CAPTURE A WHITELIST OF FOUR PHRASES and forward the rest to
    // `previousOnError`, where `tester.takeException()` swallowed them and the
    // golden was written anyway. That hid two real defects in two days, both of
    // them assertions thrown on EVERY BUILD in debug:
    //
    //   * a `Spacer` inside a `Wrap` on the organisations registry --
    //     "Incorrect use of ParentDataWidget" -- found only because a widget
    //     test on the same screen happened to report it;
    //   * a `ListTile` inside a coloured `Container` on the organisation-detail
    //     status banner -- "ListTile background color or ink splashes may be
    //     invisible" -- found only because a NEW widget test tripped over it.
    //
    // Both times the repair was to add the phrase, and both times that left the
    // next unknown class of error just as invisible. A whitelist is the wrong
    // shape for "tell me what went wrong": report everything and let a reader
    // decide what matters.
    final captured = <String>[];
    final previousOnError = FlutterError.onError;
    FlutterError.onError = (d) =>
        captured.add(d.exception.toString().split('\n').first);

    // Wrapped so the pixels can be read back. `matchesGoldenFile` captures
    // its own image internally and hands it to a comparator; the contrast
    // report below needs the same pixels IN the test, which means a boundary
    // of our own. It changes nothing about what is drawn.
    final captureKey = GlobalKey();
    await tester.pumpWidget(RepaintBoundary(key: captureKey, child: widget));
    // The whole settle schedule, and the reasoning behind every step of it,
    // lives in `test/test_helpers/render_pumps.dart` — shared with the test
    // that proves the schedule is long enough, so the two cannot drift.
    await pumpForCapture(tester);

    if (act != null) {
      await act(tester);
      await pumpForCapture(tester);
    }

    FlutterError.onError = previousOnError;
    tester.takeException();

    if (captured.isNotEmpty) {
      // ignore: avoid_print
      print(
        'RENDER NOTE [$name] ${captured.length} framework error(s) at '
        '${size.width.toInt()}x${size.height.toInt()}:',
      );
      for (final c in captured.toSet()) {
        // ignore: avoid_print
        print('  - $c');
      }
    }

    // AND THIS ONE FAILS, unlike the two reports below it.
    //
    // The file's header says the three checks deliberately report rather than
    // fail, and for a truncation that is right — six of them are intentional
    // and a check that fails on an intentional case teaches people to add
    // exclusions. A framework error is not like that. There is no deliberate
    // one, the documented state is zero, and a picture taken while the
    // framework was throwing is not evidence of anything.
    //
    // It stayed at "reported" until 2026-08-21, when the company mirror was
    // found throwing **21 errors on every desktop render** — a `LayoutBuilder`
    // inside `IntrinsicHeight`, immediately under a comment saying a
    // LayoutBuilder cannot go there. It had been printing that on every run
    // for the whole phase.
    //
    // It was missed because every reading of this output had been piped
    // through `tail`, and this render is not last. Reporting only works if
    // somebody reads the report; failing does not need anybody.
    expect(
      captured,
      isEmpty,
      reason:
          'the framework threw while rendering "$name" — the picture was '
          'still written, but it is a picture of a broken layout',
    );

    // AND EVERY STRING THAT WAS CUT OFF.
    //
    // A truncation is a VALID layout: nothing throws, no sweep fails, and the
    // golden is written happily. It is also the single most productive fault
    // family this phase has had — "Leaderboard — …", "WAYBILLS CLO…",
    // "TONS 4,382.…", "Invoiced am…", "Save empty weight — truck goes t…",
    // "net_mass · last_7_da…", every row of the phone trips list — all found
    // by looking at one picture at a time and none of them by a test.
    //
    // `didExceedMaxLines` is the paragraph's own answer to "did I have to cut
    // this", so the harness can ask it of EVERY render at once.
    //
    // REPORTED, NOT FAILED, for the same reason the framework errors above
    // are: some truncations are deliberate, and a render file that fails on
    // those teaches people to add exclusions rather than to look. The list is
    // the reading material; the judgement stays human.
    //
    // The report started at 137 strings and 122 survived the first pass at it.
    // Working the list with the widths above brought it to SIX, and those six
    // are deliberate:
    //
    //   * three CRASH-REPORT messages on `screen-crash-reports-phone-dark`.
    //     An exception string has no bounded length — one of them is a
    //     `PlatformException(channel-error, …, null, null)` — and the card is
    //     a preview that opens onto the full text and the stack.
    //   * three MESSAGE PREVIEWS on `screen-messages-desktop-dark`. A preview
    //     line is meant to be a glance at a message you open to read; the
    //     conversation NAME above it is the part that had to survive, and it
    //     takes two lines now.
    //
    // Everything else was a fault, and most of them were invisible in the
    // picture: a 6px table cell reads as an empty column, not as a cut
    // waybill number.
    // AND EVERY FAILURE STATE STILL ON THE SCREEN.
    //
    // "A SCREEN THAT PHOTOGRAPHS AN ERROR CARD IS NOT A SCREEN PHOTOGRAPHED"
    // has been in the handoff's §5 since the company profile did it, and it
    // happened again anyway: `screen-employee-profile-desktop-dark` read
    // "Could not load profile · The server refused the request" for four
    // sessions and was counted in the 93/93 the whole time. Nobody opened it.
    //
    // A person forgets to look. This does not. `MlLoadFailure` is the ONE
    // widget every read failure in this product renders through — that is what
    // it was extracted for — so finding it in the tree is finding the fault.
    // `PortalCompanyRequired` is the other one: a screen that could not
    // resolve a company and is asking the viewer to pick one.
    //
    // Reported rather than failed, like the cut list: a render may legitimately
    // BE a failure state (`screen-expired-access-desktop-dark` is one on
    // purpose). The list is what makes the accidental ones visible.
    // BY WIDGET **AND** BY TEXT.
    //
    // The widget check alone was written first and did not catch the case it
    // was written for: the employee profile hand-built its own error card
    // rather than using `MlLoadFailure`, so the tree contained no widget with
    // that name. Proven by sabotage — removing the fixture and watching the
    // report stay silent — which is the only reason this second half exists.
    //
    // The phrases are the ones the product's failure vocabulary actually uses,
    // plus the two exception class names that must never reach a person.
    const failureText = [
      'Could not load',
      'could not be read',
      'refused the request',
      'PostgrestException',
      'AuthException',
      'Something went wrong',
    ];
    final failures = <String>{};
    void visitFail(Element e) {
      final n = e.widget.runtimeType.toString();
      if (n == 'MlLoadFailure' || n == 'PortalCompanyRequired') failures.add(n);
      final ro = e.renderObject;
      if (ro is RenderParagraph && !ro.debugNeedsLayout && ro.hasSize) {
        final t = ro.text.toPlainText();
        for (final phrase in failureText) {
          if (t.contains(phrase)) failures.add('"$t"');
        }
      }
      e.visitChildren(visitFail);
    }

    tester.allElements.first.visitAncestorElements((a) {
      visitFail(a);
      return false;
    });
    if (failures.isNotEmpty) {
      // ignore: avoid_print
      print(
        'FAILURE STATE [$name] ${failures.join(', ')} — is this render '
        'meant to be a failure, or is a provider unstubbed?',
      );
    }

    // Keyed by string, valued by WHERE it was cut and how much room it had.
    //
    // The list on its own sent me hunting for "Roadhaul Logistics" through four
    // renders of a screen that draws it in three different places. A width and
    // the nearest few named ancestors turn "somewhere on this page" into a
    // file to open.
    final cut = <String, String>{};
    void visitCut(Element e) {
      final ro = e.renderObject;
      // `hasSize` first, and it is not defensive noise: a paragraph inside a
      // subtree that was built but never laid out (a `LayoutBuilder` branch
      // that lost, an offstage route) throws "RenderBox was not laid out" the
      // moment it is asked, and the throw comes out of the RENDER, not out of
      // the report.
      if (ro is RenderParagraph &&
          !ro.debugNeedsLayout &&
          ro.hasSize &&
          ro.didExceedMaxLines) {
        // The ancestor trail, filtered to the names a person can grep for:
        // the app's own widgets, not the forty framework wrappers between
        // them.
        final trail = <String>[];
        e.visitAncestorElements((a) {
          final n = a.widget.runtimeType.toString();
          if (n.startsWith('Ml') ||
              n.startsWith('_') ||
              n.endsWith('Screen') ||
              n.endsWith('Card') ||
              n.endsWith('Table') ||
              n.endsWith('Tile') ||
              n.endsWith('Row')) {
            if (trail.isEmpty || trail.last != n) trail.add(n);
          }
          return trail.length < 4;
        });
        cut[ro.text.toPlainText()] =
            '${ro.size.width.toStringAsFixed(0)}px  ${trail.join(' < ')}';
      }
      e.visitChildren(visitCut);
    }

    tester.allElements.first.visitAncestorElements((a) {
      visitCut(a);
      return false;
    });
    if (cut.isNotEmpty) {
      // ignore: avoid_print
      print(
        'CUT OFF [$name] ${cut.length} string(s) at '
        '${size.width.toInt()}x${size.height.toInt()}:',
      );
      for (final entry in cut.entries) {
        // ignore: avoid_print
        print('  ~ ${entry.key}');
        // ignore: avoid_print
        print('      ${entry.value}');
      }
    }

    // AND EVERY STRING THAT IS TOO FAINT TO READ, MEASURED OFF THE PIXELS.
    //
    // `test/design/token_contrast_test.dart` measures every colour PAIR the
    // design system can produce, in both brightnesses, and it is the right
    // shape for what it covers. Its own header explains the limit: it reasons
    // that "a screen cannot have a light-mode colour fault of its own; it can
    // only inherit one from a token pair".
    //
    // That is not true, and the leaderboard's winner card disproved it — rank,
    // tonnage and share drawn at **2.2:1** on a gradient the widget builds
    // itself out of two colours that are each fine on the surfaces the palette
    // knows about. A pair audit cannot see a ground that no token names.
    //
    // So this one measures what was PAINTED. For every paragraph: take the
    // pixels inside its box, call the most common colour the ground, call the
    // pixels furthest from it the ink, and report the WEAKEST ink against that
    // ground. Reading it back from the raster is what makes gradients, alpha
    // stacks, sheens, shadows and images all just work — none of them has to
    // be modelled, because they have already happened.
    //
    // Three details that are load-bearing:
    //
    //  * **The weakest ink, not the strongest.** A gradient wordmark has a
    //    readable end and a less readable one, and the less readable one is
    //    the one a person struggles with.
    //  * **Only glyph CORES count.** Anti-aliased edges sit between ink and
    //    ground by construction; counting them would report every string on
    //    the screen as failing. The cut is at half the maximum distance from
    //    the ground.
    //  * **The threshold follows WCAG's own definition of large text** —
    //    3:1 at >=24px, or >=18.66px bold; 4.5:1 otherwise — computed from the
    //    paragraph's real style and the ambient text scaler, not assumed.
    //
    // REPORTED, not failed, like the cut list above it: a decorative watermark
    // and a disabled control are both meant to be faint, and a check that
    // fails on those teaches people to add exclusions rather than to look.
    final faint = await reportLowContrast(tester, captureKey, name, size);
    // REPORTED like the two above it, and RATCHETED unlike them. There are
    // 1,859 of these and clearing that is not a commit — but a screen getting
    // fainter than it already is should not pass quietly either. The baseline
    // is per render, so it can only shrink.
    expectNoNewLowContrast(name, faint.length);

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../../docs/redesign/renders/$name.png'),
    );
  }

  /// Every portal fixture there is: the tail set first, the capture set on top.
  ///
  /// Both lists exist and neither is a superset. A render that passed only
  /// `portalCaptureOverrides()` left every provider that lives in the tail set
  /// UNOVERRIDDEN — reaching a real Supabase client, failing, and photographing
  /// a zero or an "Unknown company" as though the product had produced it.
  /// Three reconciliation renders read "Unknown company → Unknown company" that
  /// way, and the earnings screen printed "Costs R0" beside two trips that had
  /// costs.
  ///
  /// ORDER MATTERS AND THIS ORDER IS DELIBERATE: where both lists override the
  /// same provider the LAST one wins, so the capture set — the one these
  /// renders were built against — keeps its value, and the tail set only fills
  /// what nothing else was answering.
  List<Override> allPortalOverrides() => [
    ...portalTailOverrides(),
    ...portalCaptureOverrides(),
  ];

  /// A portal shell for one org type and role.
  ///
  /// The BODY is deliberately an empty-state placeholder rather than a real
  /// portal dashboard. Those screens need a company, a session and live
  /// providers; rendering one here would show a spinner or an error, and a
  /// picture of an error state is not a picture of the design.
  ///
  /// What these renders are FOR is the thing Jean actually asked about — "the
  /// placement of everything" — which is the shell: the rail, its grouping and
  /// ordering for that role, the top bar, the workspace canvas, and how all of
  /// it reflows onto a phone. That is real in every one of these, and it is
  /// exactly what differs between the four roles.
  Widget portal({
    required Brightness brightness,
    required OrgType orgType,
    required UserRole? role,
    required String title,
    required String subtitle,
    required String roleLabel,
    required String selectedRoute,
    bool railExpanded = true,
  }) {
    final tree = portalNavTree(orgType: orgType, role: role);
    return ProviderScope(
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.build(brightness),
        home: MlAppShell(
          tree: tree,
          selectedRoute: selectedRoute,
          onNavigate: (_) {},
          title: title,
          subtitle: subtitle,
          expanded: railExpanded,
          onExpandedChanged: (_) {},
          badgeCounts: const {
            MlNavBadge.pendingRequests: 2,
            MlNavBadge.unreadNotifications: 5,
          },
          railHeader: MlRailBrand(
            expanded: railExpanded,
            subtitle: roleLabel.toUpperCase(),
            onTap: () {},
          ),
          railFooter: MlRailIdentity(
            expanded: railExpanded,
            identity: UserIdentity(
              name: 'Fixture Operator',
              email: 'operator@fixture.co.za',
              roleLabel: roleLabel,
            ),
            onOpenProfile: () {},
          ),
          actions: [
            IconButton(
              onPressed: () {},
              icon: const Icon(Icons.notifications_outlined),
            ),
          ],
          child: const _PortalBodyPlaceholder(),
        ),
      ),
    );
  }

  /// The login screen — the only screen in the product every single user sees,
  /// and the only one that had no picture.
  Widget login(Brightness brightness) => ProviderScope(
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.build(brightness),
      home: const LoginScreen(),
    ),
  );

  /// One of login's neighbours, bare — these four are TOP-LEVEL routes, not
  /// leaves of either shell, so there is no rail and no top bar around them.
  Widget bareAuth(Widget child, {List<Override> overrides = const []}) =>
      ProviderScope(
        overrides: overrides,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.build(Brightness.dark),
          home: child,
        ),
      );

  group('auth', () {
    testWidgets('login desktop dark', (tester) async {
      await shoot(
        tester,
        login(Brightness.dark),
        const Size(1440, 1000),
        'login-desktop-dark',
      );
    });
    testWidgets('login phone dark', (tester) async {
      await shoot(
        tester,
        login(Brightness.dark),
        const Size(412, 915),
        'login-phone-dark',
      );
    });

    // LOGIN'S NEIGHBOURS.
    //
    // Every one of these is reached by somebody who is already stuck — locked
    // out, mid-recovery, or holding a password they were told to change — and
    // none of them had ever been rendered at any width.

    testWidgets('forgot password — phone dark', (tester) async {
      await shoot(
        tester,
        bareAuth(const ForgotPasswordScreen()),
        const Size(412, 915),
        'screen-forgot-password-phone-dark',
      );
    });

    testWidgets('forgot password — desktop dark', (tester) async {
      await shoot(
        tester,
        bareAuth(const ForgotPasswordScreen()),
        const Size(1440, 900),
        'screen-forgot-password-desktop-dark',
      );
    });

    // THE NOT-FOUND SCREEN. Until 2026-08-22 this was go_router's own default
    // — a bare app bar and the raw text "GoException: no routes for location:
    // /...". It is a screen a real user reaches from a stale link, and it had
    // never been photographed because it belongs to a package rather than to
    // a route in this app, so `unphotographed_screens.py` cannot see it.
    testWidgets('route not found — desktop dark', (tester) async {
      await shoot(
        tester,
        bareAuth(
          RouteNotFoundScreen(
            location: '/portal/buyer/this-route-does-not-exist',
            onGoBack: () {},
          ),
        ),
        const Size(1440, 900),
        'screen-route-not-found-desktop-dark',
      );
    });

    testWidgets('route not found — phone dark', (tester) async {
      await shoot(
        tester,
        bareAuth(
          RouteNotFoundScreen(
            location: '/portal/buyer/this-route-does-not-exist',
            onGoBack: () {},
          ),
        ),
        const Size(412, 915),
        'screen-route-not-found-phone-dark',
      );
    });

    testWidgets('whatsapp otp — phone dark', (tester) async {
      await shoot(
        tester,
        bareAuth(const WhatsAppOtpScreen(whatsappNumber: '+27 82 000 0001')),
        const Size(412, 915),
        'screen-whatsapp-otp-phone-dark',
      );
    });

    testWidgets('mandatory password change — phone dark', (tester) async {
      await shoot(
        tester,
        bareAuth(const MandatoryPasswordChangeScreen()),
        const Size(412, 915),
        'screen-mandatory-password-change-phone-dark',
      );
    });

    // THE PAGE A CUSTOMER LANDS ON FROM A PASSWORD-RESET EMAIL.
    //
    // It had never been rendered and no test mentioned it, and it was
    // invisible to `tool/unphotographed_screens.py` too: `/reset-password`
    // returns `ForgotPasswordScreen` when the URL carries no token, and the
    // tool took the first screen class it found after `builder:`. The tool
    // reads the whole builder now.
    testWidgets('reset password — phone dark', (tester) async {
      await shoot(
        tester,
        bareAuth(const ResetPasswordScreen(resetToken: 'FIXTURE-token')),
        const Size(412, 915),
        'screen-reset-password-phone-dark',
      );
    });

    testWidgets('reset password — desktop dark', (tester) async {
      await shoot(
        tester,
        bareAuth(const ResetPasswordScreen(resetToken: 'FIXTURE-token')),
        const Size(1440, 900),
        'screen-reset-password-desktop-dark',
      );
    });

    testWidgets('company selection — phone dark', (tester) async {
      await shoot(
        tester,
        bareAuth(
          const CompanySelectionScreen(),
          overrides: [
            authOverride(),
            // `withDirectory` — WITHOUT it this photographs "No companies
            // found", and a screen whose whole design is a list of companies
            // is not photographed by a picture of it having none.
            employeeOverride(withDirectory: true),
          ],
        ),
        const Size(412, 915),
        'screen-company-selection-phone-dark',
      );
    });

    // The empty state as well, which is a real state: an account whose
    // WhatsApp number is on no company's roster.
    testWidgets('company selection, nothing to join — phone dark', (
      tester,
    ) async {
      await shoot(
        tester,
        bareAuth(
          const CompanySelectionScreen(),
          overrides: companyScopeOverrides(),
        ),
        const Size(412, 915),
        'screen-company-selection-empty-phone-dark',
      );
    });
  });

  /// A REAL screen inside the real portal shell.
  ///
  /// Distinct from [portal], which renders the shell around a labelled
  /// placeholder. That one exists to show the rail and the reflow; this one
  /// exists to show the screens themselves, and it became possible only when
  /// `test/fixtures/screen_fixtures.dart` learned to supply the company, the
  /// session and the roster each of these gates on. Before that they rendered
  /// spinners and error lines — measured: eight of nineteen painted fewer than
  /// three text runs, and `fleet_management` painted "Company information not
  /// available."
  ///
  /// The data is obviously fake — Fixture Haulage, FIXTURE- ids, a 2020
  /// timestamp — so nothing in these images can be mistaken for a real
  /// company's figures. What is real is every pixel of layout, type, colour
  /// and shape.
  /// [title] is the WORKSPACE (the company) and [subtitle] is the SECTION.
  ///
  /// THE TWO ARE COMPOSED HERE, NOT PASSED STRAIGHT THROUGH, because the real
  /// shell is the other way round. `PortalShellLayout` builds its top bar as
  ///
  ///     title:    sectionTitle                       // "Messages"
  ///     subtitle: '$workspaceName · $operator · $role'
  ///
  /// and this helper used to hand `MlAppShell` the workspace as the title and
  /// the section as the subtitle — so every portal render showed a bar the
  /// product never draws, with the two lines swapped. That matters beyond
  /// tidiness: judging "is this screen's own app bar a duplicate of the
  /// shell's?" from a picture requires the picture to show the shell's real
  /// title, and it did not. Found 2026-08-21 while photographing the shared
  /// tail, where five screens turned out to be repeating the section name the
  /// bar above them was already carrying.
  Widget screen({
    required Brightness brightness,
    required Widget child,
    required String title,
    required String subtitle,
    required OrgType orgType,
    required UserRole role,
    required String selectedRoute,
    bool railExpanded = true,
    List<Override> extraOverrides = const [],
  }) {
    return ProviderScope(
      overrides: [
        ...companyScopeOverrides(role: role, orgType: orgType),
        ...extraOverrides,
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.build(brightness),
        home: MlAppShell(
          tree: portalNavTree(orgType: orgType, role: role),
          selectedRoute: selectedRoute,
          onNavigate: (_) {},
          title: subtitle,
          subtitle: '$title · Fixture Operator · ${role.label}',
          expanded: railExpanded,
          onExpandedChanged: (_) {},
          badgeCounts: const {
            MlNavBadge.pendingRequests: 2,
            MlNavBadge.unreadNotifications: 5,
          },
          // The role's OWN label, not a hardcoded 'ADMIN'.
          //
          // It was hardcoded, so the Load Controller's weighbridge and the
          // guard's gate both photographed with a rail reading ADMIN over an
          // identity card reading Admin — a picture of a permission level that
          // is not the one the screen belongs to. The rail's role line is the
          // one piece of chrome that tells a reader whose screen they are
          // looking at, and it was the piece that lied.
          railHeader: MlRailBrand(
            expanded: railExpanded,
            subtitle: role.label.toUpperCase(),
            onTap: () {},
          ),
          railFooter: MlRailIdentity(
            expanded: railExpanded,
            identity: UserIdentity(
              name: 'Fixture Operator',
              email: 'operator@fixture.co.za',
              roleLabel: role.label,
            ),
            onOpenProfile: () {},
          ),
          actions: [
            IconButton(
              onPressed: () {},
              icon: const Icon(Icons.notifications_outlined),
            ),
          ],
          child: child,
        ),
      ),
    );
  }

  group('real screens, real layout', () {
    // Fleet management, the operations hub and the communications hub were
    // DELIBERATELY ABSENT here until 2026-08-20, and the reason is worth
    // keeping because the fix is not what it looked like.
    //
    // All three reached the network while BUILDING: `FleetNotifier`,
    // `OperationsNotifier` and `CommunicationsNotifier` each loaded and opened
    // realtime channels from their CONSTRUCTORS. Against the dummy localhost
    // instance these tests use that is a real socket attempt, and it leaves a
    // pending timer — so a golden failed on "A Timer is still pending even
    // after the widget tree was disposed", which was a true statement rather
    // than a harness artefact. A sweep survives it (it pumps and ends) while
    // `expectLater(matchesGoldenFile)` keeps the body alive long enough for the
    // invariant check to see the timer.
    //
    // The note here said this needed "a Supabase transport fake". It did not.
    // It needed the notifiers to be CONSTRUCTIBLE without a network, which is
    // `start()` — a seam that matters outside tests too, since a notifier that
    // dials out from its constructor cannot serve a preview or a print view.
    // Pumping past the retry never helps, and that is still true: the reconnect
    // reschedules itself, so each pump creates another timer.
    //
    // AND THE 895px WAS THE WORDMARK. This note used to record "Pixel test
    // failed, 0.04%, 895px" as something hunted as an animation. It was
    // `Image.asset` — the rail's MineLink mark, which resolves only if it is
    // already in the global image cache, which depends on whether an earlier
    // test in the file happened to draw it. `shoot()` precaches every image
    // now, and these renders are order-independent. A failing comparison can
    // still mask a failing test; this one WAS the failing test.

    testWidgets('profile setup — desktop light', (tester) async {
      await shoot(
        tester,
        screen(
          brightness: Brightness.light,
          child: const ProfileSetupScreen(),
          title: 'Fixture Haulage',
          subtitle: 'Profile setup',
          orgType: OrgType.transporter,
          role: UserRole.driver,
          selectedRoute: '/portal/driver',
          extraOverrides: [profileSetupOverride()],
        ),
        const Size(1400, 1500),
        'screen-profile-setup-desktop-light',
      );
    });

    testWidgets('company employees — desktop dark', (tester) async {
      await shoot(
        tester,
        screen(
          brightness: Brightness.dark,
          child: const CompanyEmployeesScreen(),
          title: 'Fixture Haulage',
          subtitle: 'People',
          orgType: OrgType.transporter,
          role: UserRole.admin,
          selectedRoute: '/portal/transporter',
        ),
        const Size(1600, 1200),
        'screen-employees-desktop-dark',
      );
    });

    testWidgets('fleet management — desktop dark', (tester) async {
      await shoot(
        tester,
        screen(
          brightness: Brightness.dark,
          child: const FleetManagementScreen(),
          title: 'Fixture Haulage',
          subtitle: 'Fleet',
          orgType: OrgType.transporter,
          role: UserRole.admin,
          selectedRoute: '/portal/transporter',
          // The capture fixtures, so the register shows the THREE fleet states
          // this screen exists for. Without them `fleetStatusProvider` and
          // `vehicleDriversProvider` reject, every truck renders "Unassigned"
          // and the on-route/in-maintenance treatments — the derived states
          // CLAUDE.md §4 describes — are absent from the picture entirely.
          extraOverrides: allPortalOverrides(),
        ),
        const Size(1600, 1400),
        'screen-fleet-desktop-dark',
      );
    });

    testWidgets('fleet management — desktop light', (tester) async {
      await shoot(
        tester,
        screen(
          brightness: Brightness.light,
          child: const FleetManagementScreen(),
          title: 'Fixture Haulage',
          subtitle: 'Fleet',
          orgType: OrgType.transporter,
          role: UserRole.admin,
          selectedRoute: '/portal/transporter',
          // The capture fixtures, so the register shows the THREE fleet states
          // this screen exists for. Without them `fleetStatusProvider` and
          // `vehicleDriversProvider` reject, every truck renders "Unassigned"
          // and the on-route/in-maintenance treatments — the derived states
          // CLAUDE.md §4 describes — are absent from the picture entirely.
          extraOverrides: allPortalOverrides(),
        ),
        const Size(1600, 1400),
        'screen-fleet-desktop-light',
      );
    });

    testWidgets('operations hub — desktop dark', (tester) async {
      await shoot(
        tester,
        screen(
          brightness: Brightness.dark,
          child: const OperationsHubScreen(),
          title: 'Fixture Haulage',
          subtitle: 'Operations',
          orgType: OrgType.transporter,
          role: UserRole.admin,
          selectedRoute: '/portal/transporter',
          extraOverrides: [operationsOverride()],
        ),
        const Size(1600, 1200),
        'screen-operations-hub-desktop-dark',
      );
    });

    testWidgets('communications hub — desktop dark', (tester) async {
      await shoot(
        tester,
        screen(
          brightness: Brightness.dark,
          child: const CommunicationsHubScreen(),
          title: 'Fixture Haulage',
          subtitle: 'Communications',
          orgType: OrgType.transporter,
          role: UserRole.admin,
          selectedRoute: '/portal/transporter',
          extraOverrides: [communicationsOverride()],
        ),
        const Size(1600, 1200),
        'screen-communications-hub-desktop-dark',
      );
    });

    testWidgets('employee profile — desktop dark', (tester) async {
      await shoot(
        tester,
        screen(
          brightness: Brightness.dark,
          child: const EmployeeProfileScreen(
            employeeId: 'FIXTURE-employee',
            canManage: true,
            inPortal: true,
          ),
          title: 'Fixture Haulage',
          subtitle: 'People',
          orgType: OrgType.transporter,
          role: UserRole.admin,
          selectedRoute: '/portal/transporter',
          // Without these the screen photographed "Could not load profile ·
          // The server refused the request" and was counted as photographed.
          extraOverrides: employeeProfileOverrides(),
        ),
        const Size(1600, 1400),
        'screen-employee-profile-desktop-dark',
      );
    });

    testWidgets('employee profile — phone dark', (tester) async {
      await shoot(
        tester,
        screen(
          brightness: Brightness.dark,
          child: const EmployeeProfileScreen(
            employeeId: 'FIXTURE-employee',
            canManage: true,
            inPortal: true,
          ),
          title: 'Fixture Haulage',
          subtitle: 'People',
          orgType: OrgType.transporter,
          role: UserRole.admin,
          selectedRoute: '/portal/transporter',
          extraOverrides: employeeProfileOverrides(),
        ),
        const Size(412, 3844),
        'screen-employee-profile-phone-dark',
      );
    });

    // The phone is where the reflow work of this phase actually shows.
    testWidgets('company employees — phone dark', (tester) async {
      await shoot(
        tester,
        screen(
          brightness: Brightness.dark,
          child: const CompanyEmployeesScreen(),
          title: 'Fixture Haulage',
          subtitle: 'People',
          orgType: OrgType.transporter,
          role: UserRole.admin,
          selectedRoute: '/portal/transporter',
        ),
        const Size(412, 934),
        'screen-employees-phone-dark',
      );
    });

    // Fleet and Operations on a phone. A transporter's admin runs the fleet
    // from a truck stop; the operations hub is the tab set a weighbridge
    // controller lives in. Both were desktop-only.
    testWidgets('fleet management — phone dark', (tester) async {
      await shoot(
        tester,
        screen(
          brightness: Brightness.dark,
          child: const FleetManagementScreen(),
          title: 'Fixture Haulage',
          subtitle: 'Fleet',
          orgType: OrgType.transporter,
          role: UserRole.admin,
          selectedRoute: '/portal/transporter',
          extraOverrides: allPortalOverrides(),
        ),
        const Size(412, 1536),
        'screen-fleet-phone-dark',
      );
    });

    testWidgets('operations hub — phone dark', (tester) async {
      await shoot(
        tester,
        screen(
          brightness: Brightness.dark,
          child: const OperationsHubScreen(),
          title: 'Fixture Haulage',
          subtitle: 'Operations',
          orgType: OrgType.transporter,
          role: UserRole.admin,
          selectedRoute: '/portal/transporter',
          extraOverrides: [operationsOverride()],
        ),
        const Size(412, 1165),
        'screen-operations-hub-phone-dark',
      );
    });

    testWidgets('profile setup — phone dark', (tester) async {
      await shoot(
        tester,
        screen(
          brightness: Brightness.dark,
          child: const ProfileSetupScreen(),
          title: 'Fixture Haulage',
          subtitle: 'Profile setup',
          orgType: OrgType.transporter,
          role: UserRole.driver,
          selectedRoute: '/portal/driver',
          extraOverrides: [profileSetupOverride()],
        ),
        const Size(412, 1529),
        'screen-profile-setup-phone-dark',
      );
    });
  });

  // -------------------------------------------------------------------------
  // THE REST OF THE WORKING DAY.
  //
  // Every screen in this group is swept with rows by
  // `portal_overflow_sweep_test.dart`, which is what fails a build. These are
  // the pictures — the thing a sweep cannot give you, and the thing every
  // defect this phase was found by.
  group('the rest of the working day', () {
    testWidgets('mine production — desktop dark', (tester) async {
      await shoot(
        tester,
        screen(
          brightness: Brightness.dark,
          child: const MineProductionScreen(),
          title: 'Fixture Chrome Mine',
          subtitle: 'Production',
          orgType: OrgType.mineSupplier,
          role: UserRole.admin,
          selectedRoute: '/portal/mine/production',
          extraOverrides: allPortalOverrides(),
        ),
        const Size(1600, 2000),
        'screen-mine-production-desktop-dark',
      );
    });

    testWidgets('mine quality — desktop dark', (tester) async {
      await shoot(
        tester,
        screen(
          brightness: Brightness.dark,
          child: const MineQualityScreen(),
          title: 'Fixture Chrome Mine',
          subtitle: 'Quality',
          orgType: OrgType.mineSupplier,
          role: UserRole.admin,
          selectedRoute: '/portal/mine/quality',
          extraOverrides: allPortalOverrides(),
        ),
        const Size(1600, 1500),
        'screen-mine-quality-desktop-dark',
      );
    });

    // The supervisor's stockpiles: the +30t collect-ready flow CLAUDE.md §4
    // describes, with one pile over the threshold and one under it.
    testWidgets('supervisor & stockpiles — desktop dark', (tester) async {
      await shoot(
        tester,
        screen(
          brightness: Brightness.dark,
          child: const SupervisorViewScreen(),
          title: 'Fixture Chrome Mine',
          subtitle: 'Supervisor',
          orgType: OrgType.mineSupplier,
          role: UserRole.supervisorForeman,
          selectedRoute: '/portal/mine/stockpiles',
          extraOverrides: allPortalOverrides(),
        ),
        const Size(1600, 1600),
        'screen-supervisor-stockpiles-desktop-dark',
      );
    });

    testWidgets('transporter routes & dispatches — desktop dark', (
      tester,
    ) async {
      await shoot(
        tester,
        screen(
          brightness: Brightness.dark,
          child: const TransporterRoutesScreen(),
          title: 'Fixture Haulage',
          subtitle: 'Routes & dispatches',
          orgType: OrgType.transporter,
          role: UserRole.admin,
          selectedRoute: '/portal/transporter/routes',
          extraOverrides: allPortalOverrides(),
        ),
        const Size(1600, 1500),
        'screen-transporter-routes-desktop-dark',
      );
    });

    testWidgets('transporter maintenance — desktop dark', (tester) async {
      await shoot(
        tester,
        screen(
          brightness: Brightness.dark,
          child: const TransporterMaintenanceScreen(),
          title: 'Fixture Haulage',
          subtitle: 'Maintenance',
          orgType: OrgType.transporter,
          role: UserRole.admin,
          selectedRoute: '/portal/transporter/maintenance',
          extraOverrides: allPortalOverrides(),
        ),
        const Size(1600, 1600),
        'screen-transporter-maintenance-desktop-dark',
      );
    });

    testWidgets('earnings — desktop dark', (tester) async {
      await shoot(
        tester,
        screen(
          brightness: Brightness.dark,
          child: const EarningsScreen(),
          title: 'Fixture Haulage',
          subtitle: 'Earnings',
          orgType: OrgType.transporter,
          role: UserRole.admin,
          selectedRoute: '/portal/transporter/earnings',
          extraOverrides: allPortalOverrides(),
        ),
        const Size(1600, 1900),
        'screen-earnings-desktop-dark',
      );
    });

    // Light, and the buyer's money screen: the one place a customer reads
    // invoice variance, and the light theme's densest table.
    testWidgets('buyer loads & value — desktop light', (tester) async {
      await shoot(
        tester,
        screen(
          brightness: Brightness.light,
          child: const BuyerLoadsValueScreen(),
          title: 'Fixture Metals',
          subtitle: 'Loads & value',
          orgType: OrgType.buyer,
          role: UserRole.admin,
          selectedRoute: '/portal/buyer/loads-value',
          extraOverrides: allPortalOverrides(),
        ),
        const Size(1600, 1700),
        'screen-buyer-loads-value-desktop-light',
      );
    });

    testWidgets('trucks on route — phone dark', (tester) async {
      await shoot(
        tester,
        screen(
          brightness: Brightness.dark,
          child: const TrucksOnRouteScreen(),
          title: 'Fixture Haulage',
          subtitle: 'Trucks on route',
          orgType: OrgType.transporter,
          role: UserRole.admin,
          selectedRoute: '/portal/transporter/trucks-on-route',
          extraOverrides: allPortalOverrides(),
        ),
        const Size(412, 1044),
        'screen-trucks-on-route-phone-dark',
      );
    });
  });

  // -------------------------------------------------------------------------
  // THE MINE FLOOR.
  //
  // Security's gate screen and the Load Controller's weighbridge are where the
  // tonnage this whole product reconciles is actually created, and neither had
  // ever been photographed. Both read `mineInboundTripsProvider`, which
  // `portalCaptureOverrides()` has supplied since it was written — `kInboundTrips`
  // holds one truck at each stage the floor sees, so the queue is not four rows
  // of the same pill.
  //
  // Rendered as a MINE, not as the default transporter fixture: these screens
  // belong to a mine's own staff, and a rail that says "Mine workspace" over a
  // company whose org type is `transporter` is a picture of a state that cannot
  // exist. `fixtureCompany(orgType:)` is what makes that honest.
  //
  // Phone-first, because that is how both are used — a guard at a boom and a
  // controller at a weighbridge window, one-handed, outdoors. Security's screen
  // is explicitly built for it (`maxWidth: 520`, its own compact header);
  // the controller's is the desktop-shaped `MlPageBody`, so it gets both.
  group('the mine floor', () {
    testWidgets('security check-in — phone dark', (tester) async {
      await shoot(
        tester,
        screen(
          brightness: Brightness.dark,
          child: const SecurityCheckinScreen(),
          title: 'Fixture Chrome Mine',
          subtitle: 'Gate',
          orgType: OrgType.mineSupplier,
          role: UserRole.security,
          selectedRoute: '/portal/mine/gate',
          extraOverrides: allPortalOverrides(),
        ),
        const Size(412, 2151),
        'screen-security-checkin-phone-dark',
      );
    });

    // The same screen in GATE MODE, where the departure section leads. It is a
    // different screen to the guard checking trucks OUT at end of shift, and
    // `focusDepartures` is the only thing that differs — so if the ordering ever
    // silently stops applying, this is the picture that shows it.
    testWidgets('security check-in — gate mode, desktop dark', (tester) async {
      await shoot(
        tester,
        screen(
          brightness: Brightness.dark,
          child: const SecurityCheckinScreen(focusDepartures: true),
          title: 'Fixture Chrome Mine',
          subtitle: 'Gate — check-out',
          orgType: OrgType.mineSupplier,
          role: UserRole.security,
          selectedRoute: '/portal/mine/gate',
          extraOverrides: allPortalOverrides(),
        ),
        const Size(1400, 1600),
        'screen-security-checkin-desktop-dark',
      );
    });

    testWidgets('load controller — desktop dark', (tester) async {
      await shoot(
        tester,
        screen(
          brightness: Brightness.dark,
          child: const LoadControllerScreen(),
          title: 'Fixture Chrome Mine',
          subtitle: 'Weighbridge',
          orgType: OrgType.mineSupplier,
          role: UserRole.controllerWB,
          selectedRoute: '/portal/mine/weighbridge',
          extraOverrides: allPortalOverrides(),
        ),
        const Size(1600, 1500),
        'screen-load-controller-desktop-dark',
      );
    });

    testWidgets('load controller — desktop light', (tester) async {
      await shoot(
        tester,
        screen(
          brightness: Brightness.light,
          child: const LoadControllerScreen(),
          title: 'Fixture Chrome Mine',
          subtitle: 'Weighbridge',
          orgType: OrgType.mineSupplier,
          role: UserRole.controllerWB,
          selectedRoute: '/portal/mine/weighbridge',
          extraOverrides: allPortalOverrides(),
        ),
        const Size(1600, 1500),
        'screen-load-controller-desktop-light',
      );
    });

    testWidgets('load controller — phone dark', (tester) async {
      await shoot(
        tester,
        screen(
          brightness: Brightness.dark,
          child: const LoadControllerScreen(),
          title: 'Fixture Chrome Mine',
          subtitle: 'Weighbridge',
          orgType: OrgType.mineSupplier,
          role: UserRole.controllerWB,
          selectedRoute: '/portal/mine/weighbridge',
          extraOverrides: allPortalOverrides(),
        ),
        const Size(412, 1681),
        'screen-load-controller-phone-dark',
      );
    });
  });

  // -------------------------------------------------------------------------
  // RECONCILIATION — the widest tables in the product.
  //
  // The recon table's eleven columns are fixed by CLAUDE.md §4 and cannot be
  // made to fit a phone, which makes these the screens `MlWideTable` exists
  // for. None had ever been photographed, and the fixtures they need did not
  // exist: `rawReconRowsProvider`, `tripReconciliationsProvider`,
  // `loadQualityProvider` and `reconUploadPairsProvider` all rejected, so the
  // whole tab was four error cards.
  //
  // The fixture rows are deliberately awkward — two dates (so the DATE-blanking
  // on repeat rows is visible at all), two transporters (so the filter has
  // something to filter), one load with no delivered weight and therefore a
  // null variance, and one with no quality certificate.
  group('reconciliation', () {
    testWidgets('recon tables — console, desktop dark', (tester) async {
      await shoot(
        tester,
        console(
          brightness: Brightness.dark,
          body: const ReconTablesScreen(),
          extraOverrides: allPortalOverrides(),
        ),
        const Size(1600, 1700),
        'screen-recon-tables-desktop-dark',
      );
    });

    testWidgets('recon tables — console, desktop light', (tester) async {
      await shoot(
        tester,
        console(
          brightness: Brightness.light,
          body: const ReconTablesScreen(),
          extraOverrides: allPortalOverrides(),
        ),
        const Size(1600, 1700),
        'screen-recon-tables-desktop-light',
      );
    });

    testWidgets('recon tables — console, phone dark', (tester) async {
      await shoot(
        tester,
        console(
          brightness: Brightness.dark,
          body: const ReconTablesScreen(),
          extraOverrides: allPortalOverrides(),
        ),
        const Size(412, 2327),
        'screen-recon-tables-phone-dark',
      );
    });

    testWidgets('mine reconciliations — desktop dark', (tester) async {
      await shoot(
        tester,
        screen(
          brightness: Brightness.dark,
          child: const MineReconciliationsScreen(),
          title: 'Fixture Chrome Mine',
          subtitle: 'Reconciliations',
          orgType: OrgType.mineSupplier,
          role: UserRole.admin,
          selectedRoute: '/portal/mine/reconciliations',
          // The TAIL overrides too: the reconciliation screens read
          // `partnerCompaniesProvider` to turn party ids into names, and
          // without it every card read "Unknown company".
          extraOverrides: allPortalOverrides(),
        ),
        const Size(1600, 1700),
        'screen-mine-reconciliations-desktop-dark',
      );
    });

    // Light, because the recon tables are where the light theme is most likely
    // to be used in an office and least likely to have been looked at.
    testWidgets('transporter reconciliations — desktop light', (tester) async {
      await shoot(
        tester,
        screen(
          brightness: Brightness.light,
          child: const TransporterReconciliationsScreen(),
          title: 'Fixture Haulage',
          subtitle: 'Reconciliations',
          orgType: OrgType.transporter,
          role: UserRole.admin,
          selectedRoute: '/portal/transporter/reconciliations',
          // The TAIL overrides too: the reconciliation screens read
          // `partnerCompaniesProvider` to turn party ids into names, and
          // without it every card read "Unknown company".
          extraOverrides: allPortalOverrides(),
        ),
        const Size(1600, 1500),
        'screen-transporter-reconciliations-desktop-light',
      );
    });

    testWidgets('buyer reconciliations — phone dark', (tester) async {
      await shoot(
        tester,
        screen(
          brightness: Brightness.dark,
          child: const BuyerReconciliationsScreen(),
          title: 'Fixture Metals',
          subtitle: 'Reconciliations',
          orgType: OrgType.buyer,
          role: UserRole.admin,
          selectedRoute: '/portal/buyer/reconciliations',
          // The TAIL overrides too: the reconciliation screens read
          // `partnerCompaniesProvider` to turn party ids into names, and
          // without it every card read "Unknown company".
          extraOverrides: allPortalOverrides(),
        ),
        const Size(412, 4322),
        'screen-buyer-reconciliations-phone-dark',
      );
    });
  });

  // -------------------------------------------------------------------------
  // The three role dashboards, WITH DATA.
  //
  // These are the screens the product is actually used through, and until now
  // none of them had a picture. The `portal — one shell, four roles` group
  // above renders the shell around a labelled placeholder, and the placeholder
  // says so on the image: "The dashboards need a live session; a picture of
  // their loading state would not be a picture of the design." That was true
  // and it was also the whole workspace missing from the record.
  //
  // What changed is not a Supabase fake. `test/fixtures/portal_capture_
  // fixtures.dart` already overrode every portal data provider — the seam is
  // the provider, not the transport — and it was only ever wired into the
  // design-REFERENCE capture. Pointing the redesign renders at the same
  // fixtures is all it took.
  //
  // Deliberately not uniform, per that file's own note: one stockpile is over
  // its collect threshold and one is not, one truck is on route and one is
  // available, one load carries a quality penalty, one dispute is open. A
  // fixture where every row looks the same hides exactly the states a design
  // has to handle.
  group('portal dashboards — the workspace, with data', () {
    testWidgets('transporter dashboard — desktop dark', (tester) async {
      await shoot(
        tester,
        screen(
          brightness: Brightness.dark,
          child: const TransporterPortalDashboardScreen(),
          title: 'Fixture Haulage',
          subtitle: 'Transporter workspace',
          orgType: OrgType.transporter,
          role: UserRole.admin,
          selectedRoute: '/portal/transporter',
          extraOverrides: allPortalOverrides(),
        ),
        const Size(1600, 1900),
        'dash-transporter-desktop-dark',
      );
    });

    testWidgets('mine dashboard — desktop dark', (tester) async {
      await shoot(
        tester,
        screen(
          brightness: Brightness.dark,
          child: const MineSupplierPortalDashboardScreen(),
          title: 'Iron Hills Mining',
          subtitle: 'Mine workspace',
          orgType: OrgType.mineSupplier,
          role: UserRole.admin,
          selectedRoute: '/portal/mine',
          extraOverrides: allPortalOverrides(),
        ),
        const Size(1600, 1900),
        'dash-mine-desktop-dark',
      );
    });

    // Light, because the buyer portal is the one place the light theme gets
    // looked at on a data-dense screen, and a theme nobody photographs is a
    // theme nobody checks.
    testWidgets('buyer dashboard — desktop light', (tester) async {
      await shoot(
        tester,
        screen(
          brightness: Brightness.light,
          child: const BuyerPortalDashboardScreen(),
          title: 'Fixture Metals',
          subtitle: 'Buyer workspace',
          orgType: OrgType.buyer,
          role: UserRole.admin,
          selectedRoute: '/portal/buyer',
          extraOverrides: allPortalOverrides(),
        ),
        const Size(1600, 1900),
        'dash-buyer-desktop-light',
      );
    });

    // THE SAME THREE DASHBOARDS ON A PHONE.
    //
    // These are the screens every customer lands on, and until now all three
    // had only ever been photographed at 1600px. A mine supervisor and a
    // transporter's admin both open this on a handset; the desktop picture says
    // nothing about whether the tile grid, the stat cards or the queues reflow.
    testWidgets('transporter dashboard — phone dark', (tester) async {
      await shoot(
        tester,
        screen(
          brightness: Brightness.dark,
          child: const TransporterPortalDashboardScreen(),
          title: 'Fixture Haulage',
          subtitle: 'Transporter workspace',
          orgType: OrgType.transporter,
          role: UserRole.admin,
          selectedRoute: '/portal/transporter',
          extraOverrides: allPortalOverrides(),
        ),
        const Size(412, 2916),
        'dash-transporter-phone-dark',
      );
    });

    testWidgets('mine dashboard — phone dark', (tester) async {
      await shoot(
        tester,
        screen(
          brightness: Brightness.dark,
          child: const MineSupplierPortalDashboardScreen(),
          title: 'Fixture Chrome Mine',
          subtitle: 'Mine workspace',
          orgType: OrgType.mineSupplier,
          role: UserRole.admin,
          selectedRoute: '/portal/mine',
          extraOverrides: allPortalOverrides(),
        ),
        const Size(412, 3259),
        'dash-mine-phone-dark',
      );
    });

    testWidgets('buyer dashboard — phone light', (tester) async {
      await shoot(
        tester,
        screen(
          brightness: Brightness.light,
          child: const BuyerPortalDashboardScreen(),
          title: 'Fixture Metals',
          subtitle: 'Buyer workspace',
          orgType: OrgType.buyer,
          role: UserRole.admin,
          selectedRoute: '/portal/buyer',
          extraOverrides: allPortalOverrides(),
        ),
        const Size(412, 2851),
        'dash-buyer-phone-light',
      );
    });

    // The driver's Trip screen on a phone — the only screen in this product
    // that is used one-handed, standing next to a truck.
    testWidgets('driver trip — phone dark', (tester) async {
      await shoot(
        tester,
        screen(
          brightness: Brightness.dark,
          child: const DriverRoutesScreen(),
          title: 'Fixture Haulage',
          subtitle: 'Trip',
          orgType: OrgType.transporter,
          role: UserRole.driver,
          selectedRoute: '/portal/driver',
          extraOverrides: allPortalOverrides(),
        ),
        const Size(412, 1078),
        'dash-driver-trip-phone-dark',
      );
    });

    testWidgets('driver trip — phone light', (tester) async {
      await shoot(
        tester,
        screen(
          brightness: Brightness.light,
          child: const DriverRoutesScreen(),
          title: 'Fixture Haulage',
          subtitle: 'Trip',
          orgType: OrgType.transporter,
          role: UserRole.driver,
          selectedRoute: '/portal/driver',
          extraOverrides: allPortalOverrides(),
        ),
        const Size(412, 1078),
        'dash-driver-trip-phone-light',
      );
    });
  });

  // -------------------------------------------------------------------------
  // DRIVER NAVIGATION — the only screen in this product used while moving.
  //
  // It had no picture of any kind, and three things stood between it and one:
  // GPS, the destination RPC and the routing service. All three are seams now
  // (`test/fixtures/nav_fixtures.dart` explains each), and the third —
  // `routingServiceProvider` — is a change in `lib/`, because `RoutingService()`
  // was constructed at the call site and there was no way to hand this screen a
  // route at all.
  //
  // NOT inside `MlAppShell`: navigation is full-bleed by design. A driver
  // holding a phone at a boom gate gets the map and the instruction banner and
  // nothing else, and putting a rail around it here would photograph a screen
  // that does not exist.
  //
  // ⚠️ THE MAP TILES ARE BLANK, and that is not a fault in the design. Tiles
  // come from OpenStreetMap over HTTP, and `flutter_test` answers every request
  // with a 400 — so the canvas under the route is the empty-tile colour. What
  // IS real here is everything drawn on top of it: the route line, the truck
  // puck, the instruction banner, the destination bar and the HUD. The tiles
  // are the one part of this screen that still needs a device.
  // -------------------------------------------------------------------------
  // THE DRIVER APP SHELL.
  //
  // `DriverAppScreen` is the three-tab driver app (Dashboard · Trip · Profile)
  // and `PortalShellLayout` renders it BARE for a driver employee — the driver
  // app draws its own chrome. So this one is not wrapped in `MlAppShell`:
  // doing so would photograph two navigations stacked on one phone, which is
  // not what a driver sees.
  //
  // Its three tabs are three routes (`/portal/driver/home`, `/trip`,
  // `/profile`) and none had ever been rendered. `DriverRoutesScreen` — the
  // Trip tab's BODY — had, which is how the shell around it went unlooked-at.
  group('the driver app', () {
    // DISMISS THE SETUP PROMPT before photographing the screen underneath.
    //
    // `ProfileSetupBanner` pops a once-per-session dialog whenever a required
    // compliance item is outstanding, and the fixture account has one — which
    // is the honest fixture (a finished account renders the shortest, least
    // informative version of every one of these surfaces). So the first thing
    // any driver render sees is a modal over the page. The dialog gets its own
    // picture below; these three want what is behind it.
    Future<void> dismissSetupPrompt(WidgetTester tester) async {
      final later = find.widgetWithText(TextButton, 'Later');
      if (later.evaluate().isEmpty) return;
      await tester.tap(later.first);
      await tester.pump();
    }

    Future<void> shootDriver(
      WidgetTester tester,
      int tab,
      String name, {
      Size size = const Size(412, 1500),
      Future<void> Function(WidgetTester tester)? act,
      List<Override> extra = const [],
    }) => shoot(
      tester,
      ProviderScope(
        overrides: [
          ...companyScopeOverrides(role: UserRole.driver),
          ...portalCaptureOverrides(),
          ...portalTailOverrides(),
          // `sharedTailOverrides` for ONE widget: the driver dashboard
          // carries an `AnimatedNotificationBell`, and `notificationProvider`
          // un-overridden opens a real socket. That is not a slow render —
          // the connect attempt outlives the widget tree and fails the test
          // with "A Timer is still pending", after the golden is written.
          ...sharedTailOverrides(),
          // A driver's outstanding setup is their OWN — licence, PrDP,
          // medical. `sharedTailOverrides` supplies the company-admin
          // state (`audience: 'company'`), and the prompt dialog keys its
          // title off that field, so without this it told a driver to
          // "Complete your company account setup".
          ...driverProfileSetupOverride(),
          ...extra,
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.build(Brightness.dark),
          home: DriverAppScreen(initialTab: tab),
        ),
      ),
      size,
      name,
      act: act ?? dismissSetupPrompt,
    );

    testWidgets('dashboard tab — phone dark', (tester) async {
      await shootDriver(
        tester,
        0,
        'screen-driver-app-dashboard-phone-dark',
        size: const Size(412, 1550),
      );
    });

    testWidgets('trip tab — phone dark', (tester) async {
      await shootDriver(
        tester,
        1,
        'screen-driver-app-trip-phone-dark',
        size: const Size(412, 1150),
      );
    });

    testWidgets('profile tab — phone dark', (tester) async {
      await shootDriver(
        tester,
        2,
        'screen-driver-app-profile-phone-dark',
        size: const Size(412, 1100),
      );
    });

    // A driver on a tablet, which is a real thing in a cab.
    testWidgets('dashboard tab — tablet dark', (tester) async {
      await shootDriver(
        tester,
        0,
        'screen-driver-app-dashboard-tablet-dark',
        size: const Size(1024, 1500),
      );
    });

    // The same tab for a driver who HAS delivered this week, because the
    // fixture driver has one trip and it is still en route — so the week chart
    // above photographs its empty state and its populated state is drawn by
    // nothing. Two completed loads, three and five days back.
    testWidgets('dashboard tab, a week with deliveries — phone dark', (
      tester,
    ) async {
      await shootDriver(
        tester,
        0,
        'screen-driver-app-dashboard-delivered-phone-dark',
        size: const Size(412, 1600),
        extra: driverDeliveredWeekOverride(),
      );
    });

    // And the prompt itself — the first thing a driver with an outstanding
    // compliance item sees when they open the app, and one of the dialogs
    // §4.2 lists as never photographed.
    testWidgets('account setup prompt — phone dark', (tester) async {
      await shootDriver(
        tester,
        0,
        'screen-account-setup-prompt-phone-dark',
        size: const Size(412, 915),
        act: (_) async {},
      );
    });
  });

  group('driver navigation', () {
    testWidgets('navigating — phone dark', (tester) async {
      FakeGeolocatorPlatform.install(
        latitude: kNavTruck.latitude,
        longitude: kNavTruck.longitude,
      );
      await shoot(
        tester,
        ProviderScope(
          overrides: [
            ...companyScopeOverrides(role: UserRole.driver),
            ...portalCaptureOverrides(),
            ...navigationOverrides(),
          ],
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.build(Brightness.dark),
            home: const DriverNavigationScreen(tripId: 't-3'),
          ),
        ),
        const Size(412, 915),
        'screen-driver-navigation-phone-dark',
      );
    });

    // THE HAZARD REPORT SHEET — what a driver fills in from the road.
    //
    // §4.2 listed it as never photographed. It is opened from the navigation
    // screen's own control, so this is the whole path: a driver mid-route taps
    // "Report a hazard" and gets the type, the severity and a description.
    testWidgets('reporting a hazard — phone dark', (tester) async {
      FakeGeolocatorPlatform.install(
        latitude: kNavTruck.latitude,
        longitude: kNavTruck.longitude,
      );
      await shoot(
        tester,
        ProviderScope(
          overrides: [
            ...companyScopeOverrides(role: UserRole.driver),
            ...portalCaptureOverrides(),
            ...navigationOverrides(),
          ],
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.build(Brightness.dark),
            home: const DriverNavigationScreen(tripId: 't-3'),
          ),
        ),
        const Size(412, 915),
        'screen-hazard-report-phone-dark',
        act: (tester) async {
          final f = find.byTooltip('Report a hazard');
          if (f.evaluate().isEmpty) return;
          await tester.tap(f.first, warnIfMissed: false);
          await tester.pumpAndSettle();
        },
      );
    });

    // The degraded state, which CLAUDE.md lists as built behaviour and which
    // nobody had looked at either: Valhalla and OSRM both unreachable, so the
    // screen falls back to bearing-and-distance with no turn list. A driver in
    // a bad-signal valley gets this one, and it is the picture that says
    // whether "graceful degradation" is graceful.
    testWidgets('no route available — phone dark', (tester) async {
      FakeGeolocatorPlatform.install(
        latitude: kNavTruck.latitude,
        longitude: kNavTruck.longitude,
      );
      await shoot(
        tester,
        ProviderScope(
          overrides: [
            ...companyScopeOverrides(role: UserRole.driver),
            ...portalCaptureOverrides(),
            ...navigationOverrides(route: null),
          ],
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.build(Brightness.dark),
            home: const DriverNavigationScreen(tripId: 't-3'),
          ),
        ),
        const Size(412, 915),
        'screen-driver-navigation-no-route-phone-dark',
      );
    });
  });

  group('portal — one shell, four roles', () {
    testWidgets('transporter desktop dark', (tester) async {
      await shoot(
        tester,
        portal(
          brightness: Brightness.dark,
          orgType: OrgType.transporter,
          role: UserRole.admin,
          title: 'Fixture Haulage',
          subtitle: 'Transporter workspace',
          roleLabel: 'Admin',
          selectedRoute: '/portal/transporter',
        ),
        // Tall enough for the whole rail. At 1400 the last group was
        // clipped mid-item -- it scrolls in the app, but in a PICTURE a
        // half-drawn row reads as a layout bug rather than as a scroll.
        const Size(1600, 1750),
        'portal-transporter-desktop-dark',
      );
    });

    testWidgets('mine / supplier desktop dark', (tester) async {
      await shoot(
        tester,
        portal(
          brightness: Brightness.dark,
          orgType: OrgType.mineSupplier,
          role: UserRole.admin,
          title: 'Iron Hills Mining',
          subtitle: 'Mine workspace',
          roleLabel: 'Admin',
          selectedRoute: '/portal/mine',
        ),
        // Tall enough for the whole rail. At 1400 the last group was
        // clipped mid-item -- it scrolls in the app, but in a PICTURE a
        // half-drawn row reads as a layout bug rather than as a scroll.
        const Size(1600, 1750),
        'portal-mine-desktop-dark',
      );
    });

    testWidgets('buyer desktop light', (tester) async {
      await shoot(
        tester,
        portal(
          brightness: Brightness.light,
          orgType: OrgType.buyer,
          role: UserRole.admin,
          title: 'Fixture Metals',
          subtitle: 'Buyer workspace',
          roleLabel: 'Admin',
          selectedRoute: '/portal/buyer',
        ),
        // Tall enough for the whole rail. At 1400 the last group was
        // clipped mid-item -- it scrolls in the app, but in a PICTURE a
        // half-drawn row reads as a layout bug rather than as a scroll.
        const Size(1600, 1750),
        'portal-buyer-desktop-light',
      );
    });

    testWidgets('driver phone — the rail becomes a bottom bar', (tester) async {
      await shoot(
        tester,
        portal(
          brightness: Brightness.dark,
          orgType: OrgType.transporter,
          role: UserRole.driver,
          title: 'Fixture Haulage',
          subtitle: 'Driver',
          roleLabel: 'Driver',
          selectedRoute: '/portal/driver',
        ),
        const Size(412, 915),
        'portal-driver-phone-dark',
      );
    });

    testWidgets('transporter phone — the same tree, reflowed', (tester) async {
      await shoot(
        tester,
        portal(
          brightness: Brightness.dark,
          orgType: OrgType.transporter,
          role: UserRole.admin,
          title: 'Fixture Haulage',
          subtitle: 'Transporter workspace',
          roleLabel: 'Admin',
          selectedRoute: '/portal/transporter',
        ),
        const Size(412, 915),
        'portal-transporter-phone-dark',
      );
    });
  });

  // -------------------------------------------------------------------------
  // The console's OWN screens, inside the console's chrome.
  //
  // Everything in the `console` group below photographs the platform dashboard.
  // These are the two screens an admin spends money and judgement in — the
  // margin ledger (the platform's private pricing record, which no other party
  // may ever see) and the per-org-type insights board.
  //
  // Their fixtures are in `console_capture_fixtures.dart`, kept apart from the
  // portal's on purpose: a console fixture is the platform's view of everybody,
  // which is exactly the data that must never leak into a portal render.
  group('the console spends money here', () {
    testWidgets('margin ledger — desktop dark', (tester) async {
      await shoot(
        tester,
        console(
          brightness: Brightness.dark,
          body: const MarginLedgerScreen(),
          extraOverrides: consoleCaptureOverrides(),
        ),
        const Size(1600, 1500),
        'screen-margin-ledger-desktop-dark',
      );
    });

    testWidgets('margin ledger — desktop light', (tester) async {
      await shoot(
        tester,
        console(
          brightness: Brightness.light,
          body: const MarginLedgerScreen(),
          extraOverrides: consoleCaptureOverrides(),
        ),
        const Size(1600, 1500),
        'screen-margin-ledger-desktop-light',
      );
    });

    testWidgets('margin ledger — phone dark', (tester) async {
      await shoot(
        tester,
        console(
          brightness: Brightness.dark,
          body: const MarginLedgerScreen(),
          extraOverrides: consoleCaptureOverrides(),
        ),
        const Size(412, 915),
        'screen-margin-ledger-phone-dark',
      );
    });

    testWidgets('org insights — transporters, desktop dark', (tester) async {
      await shoot(
        tester,
        console(
          brightness: Brightness.dark,
          body: const SuperAdminOrgInsightsScreen(orgType: 'transporter'),
          extraOverrides: [
            ...consoleCaptureOverrides(),
            // The board reads the raw recon rows for its own derivations, so it
            // needs the portal fixture too. Without it half the screen renders
            // from an empty list and the picture is of a quiet month rather
            // than of the design.
            ...portalCaptureOverrides(),
          ],
        ),
        const Size(1600, 2100),
        'screen-org-insights-desktop-dark',
      );
    });

    // The TRANSPORTER org type does not get the screen above.
    // `/super-admin/insights/transporter` routes to the v2 overview instead
    // (the 2026-08-09 "Replacing old views and screens" drop), so the picture
    // named `screen-org-insights-*` is of the layout buyers and mines get and
    // of a screen no admin reaches for transporters. The one they DO reach
    // had never been rendered at any width.
    testWidgets('transporters overview v2 — desktop dark', (tester) async {
      await shoot(
        tester,
        console(
          brightness: Brightness.dark,
          body: const TransportersOverviewV2Screen(),
          extraOverrides: [
            ...consoleCaptureOverrides(),
            ...portalCaptureOverrides(),
          ],
        ),
        const Size(1600, 2000),
        'screen-transporters-overview-v2-desktop-dark',
      );
    });

    testWidgets('transporters overview v2 — desktop light', (tester) async {
      await shoot(
        tester,
        console(
          brightness: Brightness.light,
          body: const TransportersOverviewV2Screen(),
          extraOverrides: [
            ...consoleCaptureOverrides(),
            ...portalCaptureOverrides(),
          ],
        ),
        const Size(1600, 2000),
        'screen-transporters-overview-v2-desktop-light',
      );
    });

    testWidgets('transporters overview v2 — phone dark', (tester) async {
      await shoot(
        tester,
        console(
          brightness: Brightness.dark,
          body: const TransportersOverviewV2Screen(),
          extraOverrides: [
            ...consoleCaptureOverrides(),
            ...portalCaptureOverrides(),
          ],
        ),
        const Size(412, 4344),
        'screen-transporters-overview-v2-phone-dark',
      );
    });
  });

  // -------------------------------------------------------------------------
  // THE REQUEST INBOXES — where every trip in this product begins.
  //
  // CLAUDE.md §4 is emphatic that these are four separate queues keyed by the
  // requesting org's type, and that the admin sees "a clean, non-editable
  // rendering of exactly what was submitted". None had ever been photographed,
  // and the fixture they needed did not exist.
  //
  // `kAdminTransportRequests` carries FOUR STAGES of the request lifecycle —
  // requested, resubmitted, sent-back and linked — because the inbox filters by
  // status, colours by status and offers a different action per status. A
  // fixture sitting on one value photographs one fifth of the screen. The
  // sent-back and resubmitted rows also carry a real `adminNotes`, which is the
  // revision loop's whole content and renders nowhere else.
  group('requests — the four inboxes', () {
    testWidgets('mine/supplier transport — desktop dark', (tester) async {
      await shoot(
        tester,
        console(
          brightness: Brightness.dark,
          body: const RequestReviewScreen(
            requestType: 'transportation',
            origin: 'mine',
          ),
          extraOverrides: allPortalOverrides(),
        ),
        const Size(1600, 1700),
        'screen-requests-mine-transport-desktop-dark',
      );
    });

    testWidgets('buyer transport — desktop dark', (tester) async {
      await shoot(
        tester,
        console(
          brightness: Brightness.dark,
          body: const RequestReviewScreen(
            requestType: 'transportation',
            origin: 'buyer',
          ),
          extraOverrides: allPortalOverrides(),
        ),
        const Size(1600, 1700),
        'screen-requests-buyer-transport-desktop-dark',
      );
    });

    testWidgets('requested product — desktop dark', (tester) async {
      await shoot(
        tester,
        console(
          brightness: Brightness.dark,
          body: const RequestReviewScreen(requestType: 'product'),
          extraOverrides: allPortalOverrides(),
        ),
        const Size(1600, 1500),
        'screen-requests-product-desktop-dark',
      );
    });

    // The buyer-request inbox is the one with attachments on it — two lab PDFs
    // and a stockpile photo — so it is the one that shows whether an admin can
    // actually open what a mine sent.
    testWidgets('requested buyers — desktop dark', (tester) async {
      await shoot(
        tester,
        console(
          brightness: Brightness.dark,
          body: const RequestReviewScreen(requestType: 'buyer'),
          extraOverrides: allPortalOverrides(),
        ),
        const Size(1600, 1500),
        'screen-requests-buyers-desktop-dark',
      );
    });

    // A REQUEST OPEN, which is the screen rather than its index.
    //
    // Everything CLAUDE.md §4 describes about linking — the mine picker, the
    // pricing where the admin enters a margin in Rand, the resulting
    // transporter price, and the ordered due-diligence gate before a
    // transporter may be chosen — lives in the panel that appears once a row is
    // selected. The four renders above photograph the queue; this one
    // photographs the work.
    testWidgets('a request open — the linking panel, desktop dark', (
      tester,
    ) async {
      await shoot(
        tester,
        console(
          brightness: Brightness.dark,
          body: const RequestReviewScreen(
            requestType: 'transportation',
            origin: 'buyer',
          ),
          extraOverrides: allPortalOverrides(),
        ),
        const Size(1600, 2000),
        'screen-request-detail-desktop-dark',
        act: (tester) async {
          // The `requested` row — the one an admin would actually pick up.
          await tester.tap(find.textContaining('Iron Hills Mining').first);
        },
      );
    });

    // THE DISPATCH STEP, which no test and no render had ever reached.
    //
    // It only appears once a request is `approved`, and until this session no
    // fixture request had that status — so everything CLAUDE.md §4 specifies
    // about linking (select a mine, enter the admin's margin in Rand, see the
    // resulting transporter price, then the ordered due-diligence gate) was
    // unreachable. The queue said "Approved 0" and the panel stopped at
    // Approve / Decline / Send back.
    testWidgets('a request approved — the dispatch step, desktop dark', (
      tester,
    ) async {
      await shoot(
        tester,
        console(
          brightness: Brightness.dark,
          body: const RequestReviewScreen(
            requestType: 'transportation',
            origin: 'buyer',
          ),
          extraOverrides: [
            ...portalCaptureOverrides(),
            ...portalTailOverrides(),
          ],
        ),
        const Size(1600, 2000),
        'screen-request-dispatch-desktop-dark',
        act: (tester) async {
          final row = find.textContaining('Maputo Port');
          if (row.evaluate().isEmpty) return;
          await tester.tap(row.first);
          await tester.pumpAndSettle();
        },
      );
    });

    // THE DUE-DILIGENCE GATE — the flow CLAUDE.md §4 specifies most exactly,
    // and the one nothing had ever driven.
    //
    // Five dialogs in order: a preview of what the transporter receives ->
    // "are you sure the information is correct?" -> a GREEN TICKABLE checkbox
    // reading "Due diligence done correctly, accurately and accepted" ->
    // "are you 100% sure?" -> a final confirm naming the transporter and the
    // mine. Nothing dispatches until all five are answered.
    //
    // Reaching it means doing what an admin does: pick the mine, type the
    // agreed price and the margin, tick a transporter, then press the button.
    // The `act` below is long for that reason, and it is the point — it proves
    // the whole chain is wired, not just that a dialog widget lays out.
    Future<void> openTheGate(WidgetTester tester) async {
      final row = find.textContaining('Maputo Port');
      if (row.evaluate().isEmpty) return;
      await tester.tap(row.first);
      await tester.pumpAndSettle();

      final mine = find.text('Iron Hills Mining');
      if (mine.evaluate().isEmpty) return;
      await tester.ensureVisible(mine.last);
      await tester.pumpAndSettle();
      await tester.tap(mine.last, warnIfMissed: false);
      await tester.pumpAndSettle();

      final agreed = find.widgetWithText(TextField, 'Agreed price / ton');
      final margin = find.widgetWithText(TextField, 'Your margin / ton');
      if (agreed.evaluate().isEmpty || margin.evaluate().isEmpty) return;
      await tester.enterText(agreed.first, '820');
      await tester.enterText(margin.first, '65');
      await tester.pumpAndSettle();

      final carrier = find.text('Roadhaul Logistics');
      if (carrier.evaluate().isEmpty) return;
      await tester.ensureVisible(carrier.last);
      await tester.pumpAndSettle();
      await tester.tap(carrier.last, warnIfMissed: false);
      await tester.pumpAndSettle();

      final send = find.text('Review & send to transporter');
      if (send.evaluate().isEmpty) return;
      await tester.ensureVisible(send.first);
      await tester.pumpAndSettle();
      await tester.tap(send.first, warnIfMissed: false);
      await tester.pumpAndSettle();
    }

    testWidgets('the due-diligence gate, step 1 — preview, desktop dark', (
      tester,
    ) async {
      await shoot(
        tester,
        console(
          brightness: Brightness.dark,
          body: const RequestReviewScreen(
            requestType: 'transportation',
            origin: 'buyer',
          ),
          extraOverrides: [
            ...portalCaptureOverrides(),
            ...portalTailOverrides(),
          ],
        ),
        const Size(1600, 1400),
        'screen-due-diligence-preview-desktop-dark',
        act: openTheGate,
      );
    });

    // Step 3, the tick. Two dialogs further in: "Approve and send", then
    // "Yes" to the first confirm.
    testWidgets('the due-diligence gate, step 3 — the tick, desktop dark', (
      tester,
    ) async {
      await shoot(
        tester,
        console(
          brightness: Brightness.dark,
          body: const RequestReviewScreen(
            requestType: 'transportation',
            origin: 'buyer',
          ),
          extraOverrides: [
            ...portalCaptureOverrides(),
            ...portalTailOverrides(),
          ],
        ),
        const Size(1600, 1400),
        'screen-due-diligence-tick-desktop-dark',
        act: (tester) async {
          await openTheGate(tester);
          for (final label in ['Approve and send', 'Yes']) {
            final f = find.text(label);
            if (f.evaluate().isEmpty) return;
            await tester.tap(f.first, warnIfMissed: false);
            await tester.pumpAndSettle();
          }
        },
      );
    });

    // …and TICKED, because §4 asks for "a green tickable checkbox" and the
    // colour is the half a picture of the unticked state cannot show. It also
    // shows `Continue` changing from disabled to enabled, which is the gate
    // actually gating.
    testWidgets('the due-diligence gate, step 3 ticked — desktop dark', (
      tester,
    ) async {
      await shoot(
        tester,
        console(
          brightness: Brightness.dark,
          body: const RequestReviewScreen(
            requestType: 'transportation',
            origin: 'buyer',
          ),
          extraOverrides: [
            ...portalCaptureOverrides(),
            ...portalTailOverrides(),
          ],
        ),
        const Size(1600, 1400),
        'screen-due-diligence-ticked-desktop-dark',
        act: (tester) async {
          await openTheGate(tester);
          for (final label in ['Approve and send', 'Yes']) {
            final f = find.text(label);
            if (f.evaluate().isEmpty) return;
            await tester.tap(f.first, warnIfMissed: false);
            await tester.pumpAndSettle();
          }
          // SCOPED TO THE DIALOG. `find.byType(Checkbox)` also matches the
          // three transporter checkboxes on the panel BEHIND the modal, and
          // tapping one of those lands on the barrier and closes the gate —
          // which is what the first attempt photographed.
          final box = find.descendant(
            of: find.byType(AlertDialog),
            matching: find.byType(Checkbox),
          );
          if (box.evaluate().isEmpty) return;
          await tester.tap(box.first, warnIfMissed: false);
          await tester.pumpAndSettle();
        },
      );
    });

    testWidgets('mine/supplier transport — phone dark', (tester) async {
      await shoot(
        tester,
        console(
          brightness: Brightness.dark,
          body: const RequestReviewScreen(
            requestType: 'transportation',
            origin: 'mine',
          ),
          extraOverrides: allPortalOverrides(),
        ),
        const Size(412, 915),
        'screen-requests-mine-transport-phone-dark',
      );
    });
  });

  // -------------------------------------------------------------------------
  // THE CONSOLE'S TAIL — the registry, the queues and the targets board.
  //
  // Every one of these had been swept and none had been LOOKED AT, and the
  // strike rate on unlooked-at screens this phase has been 100%.
  //
  // The targets board is the one with the most stated rules to break:
  // CLAUDE.md §4 says a dial with no target reads "Not set" and never "0", an
  // unreached horizon renders dashed and grey and never red, and the org-type
  // chart draws a DAILY PACE rather than the month's figure. All three are
  // things a picture can check and a sweep cannot.
  group('the console tail', () {
    testWidgets('targets — platform, desktop dark', (tester) async {
      await shoot(
        tester,
        console(
          brightness: Brightness.dark,
          body: const TargetsPlatformScreen(),
          extraOverrides: allPortalOverrides(),
        ),
        const Size(1600, 1900),
        'screen-targets-platform-desktop-dark',
      );
    });

    testWidgets('targets — platform, desktop light', (tester) async {
      await shoot(
        tester,
        console(
          brightness: Brightness.light,
          body: const TargetsPlatformScreen(),
          extraOverrides: allPortalOverrides(),
        ),
        const Size(1600, 1900),
        'screen-targets-platform-desktop-light',
      );
    });

    // The targets board on a phone. Its "All months" list is the one remaining
    // hand-rolled flex table in `lib/` — four `Expanded` columns, no
    // `MlWideTable` — and the registry beside it was blank at this width for
    // exactly that reason.
    testWidgets('targets — platform, phone dark', (tester) async {
      await shoot(
        tester,
        console(
          brightness: Brightness.dark,
          body: const TargetsPlatformScreen(),
          extraOverrides: allPortalOverrides(),
        ),
        const Size(412, 4407),
        'screen-targets-platform-phone-dark',
      );
    });

    // The other two target SCOPES.
    //
    // The platform board is the one that had a picture, and it is the one
    // scope with NO selector. The org-type screen adds a three-pill switch and
    // the company screen adds a search field plus up to twelve company pills —
    // which is precisely why `TargetsPage`'s half-viewport cap exists: the
    // band on those two is a paragraph, a selector AND a four-figure stats row,
    // and it was the org-type one that crossed the line first.
    //
    // The company pills carry a real organisation name, so
    // `consoleCaptureOverrides()` is installed alongside the portal ones —
    // without `organizationsProvider` the picker renders "Search 0
    // organizations" and no pills at all, which is a picture of an empty
    // registry rather than of this screen.
    testWidgets('targets — org type, desktop dark', (tester) async {
      await shoot(
        tester,
        console(
          brightness: Brightness.dark,
          body: const TargetsOrgTypeScreen(orgType: TargetOrgType.transporter),
          extraOverrides: [
            ...consoleCaptureOverrides(),
            ...portalCaptureOverrides(),
          ],
        ),
        const Size(1600, 1900),
        'screen-targets-org-type-desktop-dark',
      );
    });

    testWidgets('targets — org type, phone dark', (tester) async {
      await shoot(
        tester,
        console(
          brightness: Brightness.dark,
          body: const TargetsOrgTypeScreen(orgType: TargetOrgType.transporter),
          extraOverrides: [
            ...consoleCaptureOverrides(),
            ...portalCaptureOverrides(),
          ],
        ),
        // 4,533 rather than the platform board's 4,340. The whole screen is
        // one scroll and this board's band carries a three-pill selector the
        // platform one does not, so it starts lower and ends lower.
        //
        // MEASURED, not reasoned about. The first attempt added the band's
        // extra height (56px, from the scroll extent in a bare Scaffold) and
        // came out 173px short, which put the last four months of the target
        // history under the bottom bar - a picture of a screen that looks
        // finished. The number that works is taken from a deliberately
        // oversized frame: render at 6,200, find the last row of painted
        // content (4,391), add the 142px the pinned bottom bar occupies.
        const Size(412, 4589),
        'screen-targets-org-type-phone-dark',
      );
    });

    // A company SELECTED, not the picker's empty state. `o4` is
    // "Consolidated Mineral Offtake & Logistics Holdings" — the longest name
    // in the registry, and the one the console sweep has used since Phase 2 to
    // find rigid layouts. It is both the band's title and one of the pills.
    testWidgets('targets — company, desktop dark', (tester) async {
      await shoot(
        tester,
        console(
          brightness: Brightness.dark,
          body: const TargetsCompanyScreen(companyId: 'o4'),
          extraOverrides: [
            ...consoleCaptureOverrides(),
            ...portalCaptureOverrides(),
          ],
        ),
        const Size(1600, 1900),
        'screen-targets-company-desktop-dark',
      );
    });

    testWidgets('targets — company, phone dark', (tester) async {
      await shoot(
        tester,
        console(
          brightness: Brightness.dark,
          body: const TargetsCompanyScreen(companyId: 'o4'),
          extraOverrides: [
            ...consoleCaptureOverrides(),
            ...portalCaptureOverrides(),
          ],
        ),
        // Same measurement as the org-type frame above: content ends at
        // 4,510 in a 6,200 frame, plus the 142px bottom bar. The company band
        // is the tallest of the three - a search field and five pills.
        const Size(412, 4757),
        'screen-targets-company-phone-dark',
      );
    });

    testWidgets('organizations — desktop dark', (tester) async {
      await shoot(
        tester,
        console(
          brightness: Brightness.dark,
          body: const OrganizationManagementScreen(),
          extraOverrides: consoleCaptureOverrides(),
        ),
        const Size(1600, 1500),
        'screen-organizations-desktop-dark',
      );
    });

    testWidgets('organizations — desktop light', (tester) async {
      await shoot(
        tester,
        console(
          brightness: Brightness.light,
          body: const OrganizationManagementScreen(),
          extraOverrides: consoleCaptureOverrides(),
        ),
        const Size(1600, 1500),
        'screen-organizations-desktop-light',
      );
    });

    testWidgets('token requests — desktop dark', (tester) async {
      await shoot(
        tester,
        console(
          brightness: Brightness.dark,
          body: const TokenRequestsScreen(),
          extraOverrides: consoleCaptureOverrides(),
        ),
        const Size(1600, 1500),
        'screen-token-requests-desktop-dark',
      );
    });

    testWidgets('disputes — desktop dark', (tester) async {
      await shoot(
        tester,
        console(
          brightness: Brightness.dark,
          body: const DisputeInboxScreen(),
          extraOverrides: allPortalOverrides(),
        ),
        const Size(1600, 1400),
        'screen-disputes-desktop-dark',
      );
    });

    testWidgets('organizations — phone dark', (tester) async {
      await shoot(
        tester,
        console(
          brightness: Brightness.dark,
          body: const OrganizationManagementScreen(),
          extraOverrides: consoleCaptureOverrides(),
        ),
        const Size(412, 1174),
        'screen-organizations-phone-dark',
      );
    });
  });

  // -------------------------------------------------------------------------
  // THE REST OF THE CONSOLE — every screen that still had no picture.
  //
  // All of these were already SWEPT for overflow, and most of them were swept
  // against the dummy Supabase, which means they were swept EMPTY. An empty
  // table has no long company name to break a row, no six-figure Rand figure
  // to ellipsise and no plate pill to push over. `console_tail_fixtures.dart`
  // is what makes these real, and every list in it carries the row a uniform
  // fixture would never have.
  // -------------------------------------------------------------------------
  group('the rest of the console', () {
    List<Override> tail() => [
      ...consoleCaptureOverrides(),
      ...portalCaptureOverrides(),
      ...consoleTailOverrides(),
      ...consoleLastOverrides(),
    ];

    /// A console screen, dark by default.
    ///
    /// [brightness] exists because this helper made a light render impossible
    /// to ask for: it hard-coded dark, and everything that went through it —
    /// the platform dashboard, the leaderboard, request tracking, the live
    /// map, crash reports — had no light picture at all.
    Future<void> shootConsole(
      WidgetTester tester,
      Widget body,
      Size size,
      String name, {
      Brightness brightness = Brightness.dark,
    }) => shoot(
      tester,
      console(brightness: brightness, body: body, extraOverrides: tail()),
      size,
      name,
    );

    testWidgets('request tracking — desktop dark', (tester) async {
      await shootConsole(
        tester,
        const RequestTrackingScreen(),
        const Size(1600, 1500),
        'screen-request-tracking-desktop-dark',
      );
    });

    testWidgets('request tracking — desktop light', (tester) async {
      await shootConsole(
        tester,
        const RequestTrackingScreen(),
        const Size(1600, 1500),
        'screen-request-tracking-desktop-light',
        brightness: Brightness.light,
      );
    });

    testWidgets('request tracking — phone dark', (tester) async {
      await shootConsole(
        tester,
        const RequestTrackingScreen(),
        const Size(412, 1343),
        'screen-request-tracking-phone-dark',
      );
    });

    testWidgets('platform users — desktop dark', (tester) async {
      await shootConsole(
        tester,
        const PlatformUsersScreen(),
        const Size(1600, 1600),
        'screen-platform-users-desktop-dark',
      );
    });

    testWidgets('platform users — phone dark', (tester) async {
      await shootConsole(
        tester,
        const PlatformUsersScreen(),
        const Size(412, 1327),
        'screen-platform-users-phone-dark',
      );
    });

    testWidgets('audit logs — desktop dark', (tester) async {
      await shootConsole(
        tester,
        const AuditLogsScreen(),
        const Size(1600, 1600),
        'screen-audit-logs-desktop-dark',
      );
    });

    testWidgets('audit logs — phone dark', (tester) async {
      await shootConsole(
        tester,
        const AuditLogsScreen(),
        const Size(412, 1629),
        'screen-audit-logs-phone-dark',
      );
    });

    // EXPANDED, not collapsed. Every event on this screen lives inside the
    // group tile, so a picture of the closed list photographs one card and
    // proves nothing about the thing the screen is for.
    Future<void> openFirstGroup(WidgetTester tester) async {
      final tile = find.byType(ExpansionTile);
      if (tile.evaluate().isEmpty) return;
      await tester.tap(tile.first);
      await tester.pump();
    }

    testWidgets('token history — desktop dark', (tester) async {
      await shoot(
        tester,
        console(
          brightness: Brightness.dark,
          body: const TokenHistoryScreen(),
          extraOverrides: tail(),
        ),
        const Size(1600, 1600),
        'screen-token-history-desktop-dark',
        act: openFirstGroup,
      );
    });

    testWidgets('token history — phone dark', (tester) async {
      await shoot(
        tester,
        console(
          brightness: Brightness.dark,
          body: const TokenHistoryScreen(),
          extraOverrides: tail(),
        ),
        const Size(412, 1230),
        'screen-token-history-phone-dark',
        act: openFirstGroup,
      );
    });

    testWidgets('organization detail — desktop dark', (tester) async {
      await shootConsole(
        tester,
        const OrganizationDetailScreen(organizationId: 'o4'),
        const Size(1600, 1800),
        'screen-organization-detail-desktop-dark',
      );
    });

    testWidgets('organization detail — phone dark', (tester) async {
      await shootConsole(
        tester,
        const OrganizationDetailScreen(organizationId: 'o4'),
        const Size(412, 1755),
        'screen-organization-detail-phone-dark',
      );
    });

    testWidgets('available routes — desktop dark', (tester) async {
      await shootConsole(
        tester,
        const AvailableRoutesScreen(),
        const Size(1600, 1500),
        'screen-available-routes-desktop-dark',
      );
    });

    testWidgets('available routes — phone dark', (tester) async {
      await shootConsole(
        tester,
        const AvailableRoutesScreen(),
        const Size(412, 1421),
        'screen-available-routes-phone-dark',
      );
    });

    testWidgets('route marketplace — desktop dark', (tester) async {
      await shootConsole(
        tester,
        const RouteMarketplaceScreen(),
        const Size(1600, 1300),
        'screen-route-marketplace-desktop-dark',
      );
    });

    testWidgets('crash reports — desktop dark', (tester) async {
      await shootConsole(
        tester,
        const CrashReportsScreen(),
        const Size(1600, 1500),
        'screen-crash-reports-desktop-dark',
      );
    });

    testWidgets('crash reports — phone dark', (tester) async {
      await shootConsole(
        tester,
        const CrashReportsScreen(),
        const Size(412, 915),
        'screen-crash-reports-phone-dark',
      );
    });

    testWidgets('crash reports — desktop light', (tester) async {
      await shootConsole(
        tester,
        const CrashReportsScreen(),
        const Size(1600, 1500),
        'screen-crash-reports-desktop-light',
        brightness: Brightness.light,
      );
    });

    testWidgets('account deactivations — desktop dark', (tester) async {
      await shootConsole(
        tester,
        const AccountDeactivationsScreen(),
        const Size(1600, 1400),
        'screen-account-deactivations-desktop-dark',
      );
    });

    testWidgets('account deactivations — phone dark', (tester) async {
      await shootConsole(
        tester,
        const AccountDeactivationsScreen(),
        const Size(412, 996),
        'screen-account-deactivations-phone-dark',
      );
    });

    // The tiles are blank in every render — `flutter_test` answers every HTTP
    // request with a 400, and OpenStreetMap is HTTP. The pins, the cards, the
    // status pills and the whole layout around them are real.
    testWidgets('live map — desktop dark', (tester) async {
      await shootConsole(
        tester,
        const LiveMapScreen(),
        const Size(1600, 1300),
        'screen-live-map-desktop-dark',
      );
    });

    testWidgets('live map — desktop light', (tester) async {
      await shootConsole(
        tester,
        const LiveMapScreen(),
        const Size(1600, 1300),
        'screen-live-map-desktop-light',
        brightness: Brightness.light,
      );
    });

    testWidgets('live map — phone dark', (tester) async {
      await shootConsole(
        tester,
        const LiveMapScreen(),
        const Size(412, 1177),
        'screen-live-map-phone-dark',
      );
    });

    // --- The seven the console had left ---------------------------------
    //
    // `/super-admin` itself among them: the platform dashboard the console
    // group photographs is `MineLinkDashboardScreen`, the v2 insights board.
    // `SuperAdminDashboardV2Screen` is the screen the ROUTE builds, and
    // nothing had ever rendered it.

    testWidgets('platform dashboard v2 — desktop dark', (tester) async {
      await shootConsole(
        tester,
        const SuperAdminDashboardV2Screen(),
        const Size(1600, 2000),
        'screen-super-admin-dashboard-v2-desktop-dark',
      );
    });

    testWidgets('platform dashboard v2 — desktop light', (tester) async {
      await shootConsole(
        tester,
        const SuperAdminDashboardV2Screen(),
        const Size(1600, 2000),
        'screen-super-admin-dashboard-v2-desktop-light',
        brightness: Brightness.light,
      );
    });

    testWidgets('platform dashboard v2 — phone dark', (tester) async {
      await shootConsole(
        tester,
        const SuperAdminDashboardV2Screen(),
        const Size(412, 4695),
        'screen-super-admin-dashboard-v2-phone-dark',
      );
    });

    testWidgets('transporter leaderboard — desktop dark', (tester) async {
      await shootConsole(
        tester,
        const TransporterLeaderboardScreen(),
        const Size(1600, 1400),
        'screen-transporter-leaderboard-desktop-dark',
      );
    });

    testWidgets('transporter leaderboard — desktop light', (tester) async {
      await shootConsole(
        tester,
        const TransporterLeaderboardScreen(),
        const Size(1600, 1400),
        'screen-transporter-leaderboard-desktop-light',
        brightness: Brightness.light,
      );
    });

    testWidgets('transporter leaderboard — phone dark', (tester) async {
      await shootConsole(
        tester,
        const TransporterLeaderboardScreen(),
        const Size(412, 2007),
        'screen-transporter-leaderboard-phone-dark',
      );
    });

    testWidgets('chat connections — desktop dark', (tester) async {
      await shootConsole(
        tester,
        const ChatConnectionsScreen(),
        const Size(1600, 1400),
        'screen-chat-connections-desktop-dark',
      );
    });

    testWidgets('chat connections — phone dark', (tester) async {
      await shootConsole(
        tester,
        const ChatConnectionsScreen(),
        const Size(412, 2007),
        'screen-chat-connections-phone-dark',
      );
    });

    testWidgets('driver limit requests — desktop dark', (tester) async {
      await shootConsole(
        tester,
        const DriverLimitRequestsScreen(),
        const Size(1600, 1100),
        'screen-driver-limit-requests-desktop-dark',
      );
    });

    testWidgets('driver limit requests — phone dark', (tester) async {
      await shootConsole(
        tester,
        const DriverLimitRequestsScreen(),
        const Size(412, 937),
        'screen-driver-limit-requests-phone-dark',
      );
    });

    testWidgets('platform settings — desktop dark', (tester) async {
      await shootConsole(
        tester,
        const PlatformAdminSettingsScreen(),
        const Size(1600, 1100),
        'screen-platform-settings-desktop-dark',
      );
    });

    testWidgets('register company — desktop dark', (tester) async {
      await shootConsole(
        tester,
        const RegisterCompanyScreen(),
        const Size(1600, 1500),
        'screen-register-company-desktop-dark',
      );
    });

    testWidgets('register company — phone dark', (tester) async {
      await shootConsole(
        tester,
        const RegisterCompanyScreen(),
        const Size(412, 1009),
        'screen-register-company-phone-dark',
      );
    });

    testWidgets('user preferences — desktop dark', (tester) async {
      await shootConsole(
        tester,
        const UserPreferencesScreen(),
        const Size(1600, 1500),
        'screen-user-preferences-desktop-dark',
      );
    });

    testWidgets('user preferences — phone dark', (tester) async {
      await shootConsole(
        tester,
        const UserPreferencesScreen(),
        const Size(412, 1112),
        'screen-user-preferences-phone-dark',
      );
    });

    // THE COMPANY MIRROR — a platform admin looking at one company's workspace
    // read-only. §4.5 listed it as one of two console screens with no fixtures
    // at all; the other (the employee register) has since been photographed.
    testWidgets('company mirror — desktop dark', (tester) async {
      await shoot(
        tester,
        console(
          brightness: Brightness.dark,
          body: const SuperAdminCompanyMirrorScreen(companyId: 'o4'),
          extraOverrides: [...tail(), ...companyMirrorOverrides()],
        ),
        const Size(1600, 1800),
        'screen-company-mirror-desktop-dark',
      );
    });

    testWidgets('company mirror — phone dark', (tester) async {
      await shoot(
        tester,
        console(
          brightness: Brightness.dark,
          body: const SuperAdminCompanyMirrorScreen(companyId: 'o4'),
          extraOverrides: [...tail(), ...companyMirrorOverrides()],
        ),
        const Size(412, 3830),
        'screen-company-mirror-phone-dark',
      );
    });
  });

  // -------------------------------------------------------------------------
  // THE PORTAL TAIL.
  //
  // The screens a company actually spends its week in that had never been
  // photographed: the buyer's waybills, requests and routes; the mine's saved
  // locations; the tons-out and trip detail views; the stockpile ledger; the
  // three truck-location maps; the transporter's drivers, fuel costs,
  // compliance and own-company pages; and the request form itself.
  //
  // `portalTailOverrides()` is what makes them real — see
  // `test/fixtures/portal_tail_fixtures.dart`.
  group('the portal tail', () {
    List<Override> tail() => [
      ...portalCaptureOverrides(),
      ...portalTailOverrides(),
    ];

    Future<void> shootPortal(
      WidgetTester tester,
      Widget body,
      Size size,
      String name, {
      required OrgType orgType,
      required String title,
      required String subtitle,
      required String selectedRoute,
      UserRole role = UserRole.admin,
      Brightness brightness = Brightness.dark,
      Future<void> Function(WidgetTester tester)? act,
      List<Override> extra = const [],
    }) => shoot(
      tester,
      screen(
        brightness: brightness,
        child: body,
        title: title,
        subtitle: _barTitle(selectedRoute, subtitle),
        orgType: orgType,
        role: role,
        selectedRoute: selectedRoute,
        extraOverrides: [...tail(), ...extra],
      ),
      size,
      name,
      act: act,
    );

    // --- The buyer's own three -------------------------------------------

    testWidgets('buyer waybills — phone dark', (tester) async {
      await shootPortal(
        tester,
        const BuyerWaybillsScreen(),
        const Size(412, 1050),
        'screen-buyer-waybills-phone-dark',
        orgType: OrgType.buyer,
        title: 'Fixture Metals',
        subtitle: 'Waybills',
        selectedRoute: '/portal/buyer/waybills',
      );
    });

    testWidgets('buyer waybills — desktop dark', (tester) async {
      await shootPortal(
        tester,
        const BuyerWaybillsScreen(),
        const Size(1600, 1100),
        'screen-buyer-waybills-desktop-dark',
        orgType: OrgType.buyer,
        title: 'Fixture Metals',
        subtitle: 'Waybills',
        selectedRoute: '/portal/buyer/waybills',
      );
    });

    testWidgets('buyer requests — phone dark', (tester) async {
      await shootPortal(
        tester,
        const BuyerRequestsScreen(),
        const Size(412, 1929),
        'screen-buyer-requests-phone-dark',
        orgType: OrgType.buyer,
        title: 'Fixture Metals',
        subtitle: 'Requests',
        selectedRoute: '/portal/buyer/requests',
      );
    });

    testWidgets('buyer requests — desktop dark', (tester) async {
      await shootPortal(
        tester,
        const BuyerRequestsScreen(),
        const Size(1600, 2000),
        'screen-buyer-requests-desktop-dark',
        orgType: OrgType.buyer,
        title: 'Fixture Metals',
        subtitle: 'Requests',
        selectedRoute: '/portal/buyer/requests',
      );
    });

    testWidgets('buyer routes & mines — phone dark', (tester) async {
      await shootPortal(
        tester,
        const BuyerRoutesMinesScreen(),
        const Size(412, 915),
        'screen-buyer-routes-mines-phone-dark',
        orgType: OrgType.buyer,
        title: 'Fixture Metals',
        subtitle: 'Routes & mines',
        selectedRoute: '/portal/buyer/routes',
      );
    });

    testWidgets('buyer routes & mines — desktop dark', (tester) async {
      await shootPortal(
        tester,
        const BuyerRoutesMinesScreen(),
        const Size(1600, 1100),
        'screen-buyer-routes-mines-desktop-dark',
        orgType: OrgType.buyer,
        title: 'Fixture Metals',
        subtitle: 'Routes & mines',
        selectedRoute: '/portal/buyer/routes',
      );
    });

    // --- The three truck-location maps ------------------------------------
    //
    // One panel, three sets of copy and three different scopes. The tiles are
    // blank for the reason the console's live map records; the rail of GPS
    // samples, the pins and the whole reflow are real.

    testWidgets('buyer truck locations — desktop dark', (tester) async {
      await shootPortal(
        tester,
        const BuyerTruckLocationsScreen(),
        const Size(1600, 1100),
        'screen-buyer-truck-locations-desktop-dark',
        orgType: OrgType.buyer,
        title: 'Fixture Metals',
        subtitle: 'Truck locations',
        selectedRoute: '/portal/buyer/truck-locations',
      );
    });

    testWidgets('buyer truck locations — phone dark', (tester) async {
      await shootPortal(
        tester,
        const BuyerTruckLocationsScreen(),
        const Size(412, 957),
        'screen-buyer-truck-locations-phone-dark',
        orgType: OrgType.buyer,
        title: 'Fixture Metals',
        subtitle: 'Truck locations',
        selectedRoute: '/portal/buyer/truck-locations',
      );
    });

    testWidgets('mine truck locations — desktop dark', (tester) async {
      await shootPortal(
        tester,
        const MineSupplierTruckLocationsScreen(),
        const Size(1600, 1100),
        'screen-mine-truck-locations-desktop-dark',
        orgType: OrgType.mineSupplier,
        title: 'Fixture Minerals',
        subtitle: 'Truck locations',
        selectedRoute: '/portal/mine/truck-locations',
      );
    });

    testWidgets('transporter truck locations — desktop dark', (tester) async {
      await shootPortal(
        tester,
        const TransporterTruckLocationsScreen(),
        const Size(1600, 1100),
        'screen-transporter-truck-locations-desktop-dark',
        orgType: OrgType.transporter,
        title: 'Fixture Haulage',
        subtitle: 'Truck locations',
        selectedRoute: '/portal/transporter/truck-locations',
      );
    });

    // --- The mine's own tail -----------------------------------------------

    testWidgets('mine locations — phone dark', (tester) async {
      await shootPortal(
        tester,
        const MineLocationsScreen(),
        const Size(412, 1358),
        'screen-mine-locations-phone-dark',
        orgType: OrgType.mineSupplier,
        title: 'Fixture Minerals',
        subtitle: 'Locations',
        selectedRoute: '/portal/mine/locations',
      );
    });

    testWidgets('mine locations — desktop dark', (tester) async {
      await shootPortal(
        tester,
        const MineLocationsScreen(),
        const Size(1600, 1300),
        'screen-mine-locations-desktop-dark',
        orgType: OrgType.mineSupplier,
        title: 'Fixture Minerals',
        subtitle: 'Locations',
        selectedRoute: '/portal/mine/locations',
      );
    });

    testWidgets('stockpile detail — phone dark', (tester) async {
      await shootPortal(
        tester,
        const StockpileDetailScreen(),
        const Size(412, 1642),
        'screen-stockpile-detail-phone-dark',
        orgType: OrgType.mineSupplier,
        role: UserRole.supervisorForeman,
        title: 'Fixture Minerals',
        subtitle: 'Stockpiles',
        selectedRoute: '/portal/mine/stockpiles',
      );
    });

    testWidgets('stockpile detail — desktop dark', (tester) async {
      await shootPortal(
        tester,
        const StockpileDetailScreen(),
        const Size(1600, 1200),
        'screen-stockpile-detail-desktop-dark',
        orgType: OrgType.mineSupplier,
        role: UserRole.supervisorForeman,
        title: 'Fixture Minerals',
        subtitle: 'Stockpiles',
        selectedRoute: '/portal/mine/stockpiles',
      );
    });

    // The audit trail builds its OWN `Scaffold` with an `AppBar` — it is
    // pushed as a route rather than shown in the workspace — so it is
    // photographed standalone rather than inside the shell.
    testWidgets('stockpile audit — phone dark', (tester) async {
      await shoot(
        tester,
        ProviderScope(
          overrides: [
            ...companyScopeOverrides(
              role: UserRole.supervisorForeman,
              orgType: OrgType.mineSupplier,
            ),
            ...tail(),
          ],
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.build(Brightness.dark),
            home: const StockpileAuditScreen(),
          ),
        ),
        const Size(412, 1069),
        'screen-stockpile-audit-phone-dark',
      );
    });

    testWidgets('stockpile audit — desktop dark', (tester) async {
      await shoot(
        tester,
        ProviderScope(
          overrides: [
            ...companyScopeOverrides(
              role: UserRole.supervisorForeman,
              orgType: OrgType.mineSupplier,
            ),
            ...tail(),
          ],
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.build(Brightness.dark),
            home: const StockpileAuditScreen(),
          ),
        ),
        const Size(1600, 1200),
        'screen-stockpile-audit-desktop-dark',
      );
    });

    // --- Tons out, and one trip --------------------------------------------

    testWidgets('tons-out detail — phone dark', (tester) async {
      await shootPortal(
        tester,
        TonsOutDetailScreen(entries: kTonsOut),
        const Size(412, 1625),
        'screen-tons-out-detail-phone-dark',
        orgType: OrgType.mineSupplier,
        title: 'Fixture Minerals',
        subtitle: 'Tons out',
        selectedRoute: '/portal/mine/tons-out',
      );
    });

    testWidgets('tons-out detail — desktop dark', (tester) async {
      await shootPortal(
        tester,
        TonsOutDetailScreen(entries: kTonsOut),
        const Size(1600, 1600),
        'screen-tons-out-detail-desktop-dark',
        orgType: OrgType.mineSupplier,
        title: 'Fixture Minerals',
        subtitle: 'Tons out',
        selectedRoute: '/portal/mine/tons-out',
      );
    });

    // `t-2` deliberately: the trip that is EN ROUTE, with a dispatch, a route
    // and a transaction behind it. `t-3` has no net tonnage yet and would
    // photograph the half-filled state instead.
    testWidgets('trip detail — phone dark', (tester) async {
      await shootPortal(
        tester,
        const PortalTripDetailScreen(tripId: 't-2'),
        const Size(412, 915),
        'screen-trip-detail-phone-dark',
        orgType: OrgType.buyer,
        title: 'Fixture Metals',
        subtitle: 'Trip',
        selectedRoute: '/portal/buyer/trips/t-2',
      );
    });

    testWidgets('trip detail — desktop dark', (tester) async {
      await shootPortal(
        tester,
        const PortalTripDetailScreen(tripId: 't-2'),
        const Size(1600, 1100),
        'screen-trip-detail-desktop-dark',
        orgType: OrgType.buyer,
        title: 'Fixture Metals',
        subtitle: 'Trip',
        selectedRoute: '/portal/buyer/trips/t-2',
      );
    });

    // --- The transporter's own tail ---------------------------------------

    testWidgets('transporter drivers — phone dark', (tester) async {
      await shootPortal(
        tester,
        const TransporterDriversScreen(),
        const Size(412, 1207),
        'screen-transporter-drivers-phone-dark',
        orgType: OrgType.transporter,
        title: 'Fixture Haulage',
        subtitle: 'Drivers',
        selectedRoute: '/portal/transporter/drivers',
      );
    });

    testWidgets('transporter drivers — desktop dark', (tester) async {
      await shootPortal(
        tester,
        const TransporterDriversScreen(),
        const Size(1600, 1300),
        'screen-transporter-drivers-desktop-dark',
        orgType: OrgType.transporter,
        title: 'Fixture Haulage',
        subtitle: 'Drivers',
        selectedRoute: '/portal/transporter/drivers',
      );
    });

    testWidgets('fuel & operating costs — phone dark', (tester) async {
      await shootPortal(
        tester,
        const FuelCostsScreen(),
        const Size(412, 2232),
        'screen-fuel-costs-phone-dark',
        orgType: OrgType.transporter,
        title: 'Fixture Haulage',
        subtitle: 'Fuel & costs',
        selectedRoute: '/portal/transporter/fuel-costs',
      );
    });

    testWidgets('fuel & operating costs — desktop dark', (tester) async {
      await shootPortal(
        tester,
        const FuelCostsScreen(),
        const Size(1600, 1900),
        'screen-fuel-costs-desktop-dark',
        orgType: OrgType.transporter,
        title: 'Fixture Haulage',
        subtitle: 'Fuel & costs',
        selectedRoute: '/portal/transporter/fuel-costs',
      );
    });

    testWidgets('compliance — phone dark', (tester) async {
      await shootPortal(
        tester,
        const ComplianceScreen(),
        const Size(412, 1196),
        'screen-compliance-phone-dark',
        orgType: OrgType.transporter,
        title: 'Fixture Haulage',
        subtitle: 'Compliance',
        selectedRoute: '/portal/transporter/compliance',
      );
    });

    testWidgets('compliance — desktop dark', (tester) async {
      await shootPortal(
        tester,
        const ComplianceScreen(),
        const Size(1600, 1500),
        'screen-compliance-desktop-dark',
        orgType: OrgType.transporter,
        title: 'Fixture Haulage',
        subtitle: 'Compliance',
        selectedRoute: '/portal/transporter/compliance',
      );
    });

    // INSIDE THE SHELL, and that is not a stylistic choice.
    //
    // `/portal/transporter/drop-off/:tripId` is a leaf of the portal
    // `ShellRoute`, so `PortalShellLayout` supplies the `Scaffold` — and this
    // screen has no `Material` of its own. Rendered bare as `home:` the first
    // time, its page title came out in Flutter's *"fallback style; consider
    // putting your text in a Material"* — yellow, double-underlined, on an
    // unpainted background. That was the HARNESS being wrong about where the
    // screen lives, not the screen; a picture taken outside a screen's real
    // chrome is a picture of something the product never shows.
    testWidgets('drop-off — phone dark', (tester) async {
      await shootPortal(
        tester,
        const DropOffScreen(tripId: 't-2'),
        const Size(412, 915),
        'screen-drop-off-phone-dark',
        orgType: OrgType.transporter,
        title: 'Fixture Haulage',
        subtitle: 'Drop-off point',
        selectedRoute: '/portal/transporter/drop-off/t-2',
      );
    });

    testWidgets('own company — desktop dark', (tester) async {
      await shootPortal(
        tester,
        const PortalOwnCompanyScreen(),
        const Size(1600, 1500),
        'screen-own-company-desktop-dark',
        orgType: OrgType.transporter,
        title: 'Fixture Haulage',
        subtitle: 'Company',
        selectedRoute: '/portal/transporter/company',
      );
    });

    testWidgets('own company — phone dark', (tester) async {
      await shootPortal(
        tester,
        const PortalOwnCompanyScreen(),
        const Size(412, 915),
        'screen-own-company-phone-dark',
        orgType: OrgType.transporter,
        title: 'Fixture Haulage',
        subtitle: 'Company',
        selectedRoute: '/portal/transporter/company',
      );
    });

    // The request form itself, PREFILLED from an assigned available route —
    // which is the state §4 describes ("assigned routes pre-fill the Request
    // Route form"), and the only one that photographs a filled form rather
    // than a page of empty fields.
    testWidgets('request transportation — phone dark', (tester) async {
      await shoot(
        tester,
        ProviderScope(
          overrides: [
            ...companyScopeOverrides(orgType: OrgType.buyer),
            ...tail(),
          ],
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.build(Brightness.dark),
            home: RequestTransportationScreen(
              prefill: kMyAvailableRoutes.first,
            ),
          ),
        ),
        const Size(412, 1837),
        'screen-request-transportation-phone-dark',
      );
    });

    testWidgets('request transportation — desktop dark', (tester) async {
      await shoot(
        tester,
        ProviderScope(
          overrides: [
            ...companyScopeOverrides(orgType: OrgType.buyer),
            ...tail(),
          ],
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.build(Brightness.dark),
            home: RequestTransportationScreen(
              prefill: kMyAvailableRoutes.first,
            ),
          ),
        ),
        const Size(1600, 1800),
        'screen-request-transportation-desktop-dark',
      );
    });

    // --- The last four portal leaves ---------------------------------------

    testWidgets('search loads — desktop dark', (tester) async {
      await shootPortal(
        tester,
        const PortalTonsOutSearchScreen(),
        const Size(1600, 1400),
        'screen-tons-out-search-desktop-dark',
        orgType: OrgType.mineSupplier,
        title: 'Fixture Minerals',
        subtitle: 'Search loads',
        selectedRoute: '/portal/mine/tons-out-search',
      );
    });

    testWidgets('search loads — phone dark', (tester) async {
      await shootPortal(
        tester,
        const PortalTonsOutSearchScreen(),
        const Size(412, 1721),
        'screen-tons-out-search-phone-dark',
        orgType: OrgType.mineSupplier,
        title: 'Fixture Minerals',
        subtitle: 'Search loads',
        selectedRoute: '/portal/mine/tons-out-search',
      );
    });

    testWidgets('transporter request tracking — desktop dark', (tester) async {
      await shootPortal(
        tester,
        const TransporterRequestTrackingScreen(),
        const Size(1600, 1200),
        'screen-transporter-request-tracking-desktop-dark',
        orgType: OrgType.transporter,
        title: 'Fixture Haulage',
        subtitle: 'Request tracking',
        selectedRoute: '/portal/transporter/request-tracking',
      );
    });

    testWidgets('transporter request tracking — phone dark', (tester) async {
      await shootPortal(
        tester,
        const TransporterRequestTrackingScreen(),
        const Size(412, 915),
        'screen-transporter-request-tracking-phone-dark',
        orgType: OrgType.transporter,
        title: 'Fixture Haulage',
        subtitle: 'Request tracking',
        selectedRoute: '/portal/transporter/request-tracking',
      );
    });

    // The deep-link loader for `/companies/:orgType/:id/details`, which
    // resolves the company by id when nothing was passed in `extra`. Its own
    // picture, because the tool that keeps this inventory could not see it
    // either — `builder:` returns two different screens there.
    testWidgets('company details, deep-linked — desktop dark', (tester) async {
      await shootPortal(
        tester,
        const CompanyDetailsLoaderScreen(companyId: 'co-roadhaul'),
        const Size(1600, 1000),
        'screen-company-details-loader-desktop-dark',
        orgType: OrgType.transporter,
        title: 'Fixture Haulage',
        subtitle: 'Companies',
        selectedRoute: '/portal/transporter',
      );
    });

    // `/home` — the portal's tab host. It is a `LazyIndexedStack` and nothing
    // else, so what this picture PROVES is narrow and worth saying: that the
    // tab bodies mount, and that the page sits on the shell's canvas rather
    // than painting a ground of its own (it used to paint
    // `scaffoldBackgroundColor`, one step lighter). The tab BODIES are the
    // fixture's labelled placeholders — the real ones are the dashboards, and
    // they have their own renders.
    testWidgets('home tab host — desktop dark', (tester) async {
      await shootPortal(
        tester,
        const HomeTabBodyScreen(),
        const Size(1600, 900),
        'screen-home-tab-host-desktop-dark',
        orgType: OrgType.transporter,
        title: 'Fixture Haulage',
        subtitle: 'Dashboard',
        selectedRoute: '/home',
        extra: [portalWorkspaceOverride()],
      );
    });

    // --- The platform registry pages, reached from the portal shell -------
    //
    // `/companies/:orgType`, `/companies/:orgType/:id/details` and
    // `/employees/:companyId` are leaves of the portal `ShellRoute` and had
    // never been rendered at any width by anything. Three of them had their
    // own `Scaffold(appBar:)` removed in the previous commit on the strength
    // of reading the router, with no picture taken afterwards.

    // The licence pages. `/expired-access` is a leaf of the portal shell and
    // is where "What does this mean?" leads from the notice bar — the one
    // screen dedicated to explaining a lapsed token, and it had no picture in
    // either of its two states.
    testWidgets('expired access, lapsed — desktop dark', (tester) async {
      await shoot(
        tester,
        screen(
          brightness: Brightness.dark,
          child: const ExpiredAccessScreen(),
          title: 'Fixture Haulage',
          subtitle: 'Access expired',
          orgType: OrgType.transporter,
          role: UserRole.admin,
          selectedRoute: '/portal/transporter',
          extraOverrides: [...tail(), ...expiredCompanyOverride()],
        ),
        const Size(1600, 1000),
        'screen-expired-access-desktop-dark',
      );
    });

    testWidgets('expired access, lapsed — phone dark', (tester) async {
      await shoot(
        tester,
        screen(
          brightness: Brightness.dark,
          child: const ExpiredAccessScreen(),
          title: 'Fixture Haulage',
          subtitle: 'Access expired',
          orgType: OrgType.transporter,
          role: UserRole.admin,
          selectedRoute: '/portal/transporter',
          extraOverrides: [...tail(), ...expiredCompanyOverride()],
        ),
        const Size(412, 1320),
        'screen-expired-access-phone-dark',
      );
    });

    // …and the same page for a company whose licence is fine, which is what
    // anybody who taps through out of curiosity gets.
    testWidgets('expired access, in good standing — desktop dark', (
      tester,
    ) async {
      await shootPortal(
        tester,
        const ExpiredAccessScreen(),
        const Size(1600, 1000),
        'screen-expired-access-ok-desktop-dark',
        orgType: OrgType.transporter,
        title: 'Fixture Haulage',
        subtitle: 'Access expired',
        selectedRoute: '/portal/transporter',
      );
    });

    testWidgets('company registry — desktop dark', (tester) async {
      await shootPortal(
        tester,
        const CompanyListScreen(
          orgType: OrgType.transporter,
          title: 'Transporters',
        ),
        const Size(1600, 1000),
        'screen-company-registry-desktop-dark',
        orgType: OrgType.transporter,
        title: 'Fixture Haulage',
        // `mlRouteTitle` gives `/companies/…` the section name "Companies" and
        // `/employees/…` "Employees". Those, not the page's own heading — a
        // render that echoes the heading into the bar invents a duplicated
        // title the product never draws, which is the exact fault that hid
        // thirteen real ones for 118 renders.
        subtitle: 'Companies',
        selectedRoute: '/portal/transporter',
      );
    });

    testWidgets('company registry — phone dark', (tester) async {
      await shootPortal(
        tester,
        const CompanyListScreen(
          orgType: OrgType.transporter,
          title: 'Transporters',
        ),
        const Size(412, 915),
        'screen-company-registry-phone-dark',
        orgType: OrgType.transporter,
        title: 'Fixture Haulage',
        subtitle: 'Companies',
        selectedRoute: '/portal/transporter',
      );
    });

    testWidgets('company details — desktop dark', (tester) async {
      await shootPortal(
        tester,
        CompanyDetailsScreen(company: kCompanyRegistry.first),
        const Size(1600, 1000),
        'screen-company-details-desktop-dark',
        orgType: OrgType.transporter,
        title: 'Fixture Haulage',
        subtitle: 'Companies',
        selectedRoute: '/portal/transporter',
      );
    });

    testWidgets('company details — phone dark', (tester) async {
      await shootPortal(
        tester,
        CompanyDetailsScreen(company: kCompanyRegistry.first),
        const Size(412, 915),
        'screen-company-details-phone-dark',
        orgType: OrgType.transporter,
        title: 'Fixture Haulage',
        subtitle: 'Companies',
        selectedRoute: '/portal/transporter',
      );
    });

    testWidgets('employee grid — desktop dark', (tester) async {
      await shootPortal(
        tester,
        const EmployeeGridScreen(
          companyId: 'co-transporter',
          companyName: 'Fixture Haulage',
        ),
        const Size(1600, 1000),
        'screen-employee-grid-desktop-dark',
        orgType: OrgType.transporter,
        title: 'Fixture Haulage',
        subtitle: 'Employees',
        selectedRoute: '/portal/transporter',
      );
    });

    // --- The five operational screens nothing had rendered ---------------

    testWidgets('tons out — desktop dark', (tester) async {
      await shootPortal(
        tester,
        const PortalTonsOutScreen(),
        const Size(1600, 1150),
        'screen-tons-out-desktop-dark',
        orgType: OrgType.mineSupplier,
        title: 'Fixture Minerals',
        subtitle: 'Tons out',
        selectedRoute: '/portal/mine/tons-out',
      );
    });

    testWidgets('tons out — phone dark', (tester) async {
      await shootPortal(
        tester,
        const PortalTonsOutScreen(),
        const Size(412, 1891),
        'screen-tons-out-phone-dark',
        orgType: OrgType.mineSupplier,
        title: 'Fixture Minerals',
        subtitle: 'Tons out',
        selectedRoute: '/portal/mine/tons-out',
      );
    });

    testWidgets('trips — desktop dark', (tester) async {
      await shootPortal(
        tester,
        const PortalTripsScreen(basePath: '/portal/mine/trips'),
        const Size(1600, 1000),
        'screen-trips-desktop-dark',
        orgType: OrgType.mineSupplier,
        title: 'Fixture Minerals',
        subtitle: 'Trips',
        selectedRoute: '/portal/mine/trips',
      );
    });

    testWidgets('trips — phone dark', (tester) async {
      await shootPortal(
        tester,
        const PortalTripsScreen(basePath: '/portal/mine/trips'),
        const Size(412, 915),
        'screen-trips-phone-dark',
        orgType: OrgType.mineSupplier,
        title: 'Fixture Minerals',
        subtitle: 'Trips',
        selectedRoute: '/portal/mine/trips',
      );
    });

    testWidgets('live trip map — desktop dark', (tester) async {
      await shootPortal(
        tester,
        const LiveTripMapScreen(),
        const Size(1600, 1000),
        'screen-live-trip-map-desktop-dark',
        orgType: OrgType.transporter,
        title: 'Fixture Haulage',
        subtitle: 'Live map',
        selectedRoute: '/portal/transporter/live-map',
      );
    });

    testWidgets('live trip map — phone dark', (tester) async {
      await shootPortal(
        tester,
        const LiveTripMapScreen(),
        const Size(412, 963),
        'screen-live-trip-map-phone-dark',
        orgType: OrgType.transporter,
        title: 'Fixture Haulage',
        subtitle: 'Live map',
        selectedRoute: '/portal/transporter/live-map',
      );
    });

    testWidgets('mine buyers — desktop dark', (tester) async {
      await shootPortal(
        tester,
        const MineSupplierBuyersDetailScreen(),
        const Size(1600, 1000),
        'screen-mine-buyers-desktop-dark',
        orgType: OrgType.mineSupplier,
        title: 'Fixture Minerals',
        subtitle: 'Buyers',
        selectedRoute: '/portal/mine/buyers',
      );
    });

    testWidgets('mine buyers — phone dark', (tester) async {
      await shootPortal(
        tester,
        const MineSupplierBuyersDetailScreen(),
        const Size(412, 1163),
        'screen-mine-buyers-phone-dark',
        orgType: OrgType.mineSupplier,
        title: 'Fixture Minerals',
        subtitle: 'Buyers',
        selectedRoute: '/portal/mine/buyers',
      );
    });

    testWidgets('employee grid — phone dark', (tester) async {
      await shootPortal(
        tester,
        const EmployeeGridScreen(
          companyId: 'co-transporter',
          companyName: 'Fixture Haulage',
        ),
        const Size(412, 915),
        'screen-employee-grid-phone-dark',
        orgType: OrgType.transporter,
        title: 'Fixture Haulage',
        subtitle: 'Employees',
        selectedRoute: '/portal/transporter',
      );
    });
  });

  // ==========================================================================
  // THE SHARED TAIL
  // ==========================================================================
  //
  // The screens every org type and every role reaches through the same route:
  // messages, the chat thread, notifications, the notification manager, the
  // profile, account security, appearance, and the employee register. Nothing
  // had ever photographed any of them, which is how eight of them came to sit
  // inside the portal `ShellRoute` building their own `Scaffold(appBar:)`.
  group('the shared tail', () {
    // `portalTailOverrides` too, for the one provider the profile reaches into
    // from outside its own feature: `CompanyLocationsSection` reads
    // `companyLocationsProvider`, and without it the profile photographs a red
    // "Could not load your saved locations" in the middle of the page.
    List<Override> shared() => [
      ...portalCaptureOverrides(),
      ...portalTailOverrides(),
      ...sharedTailOverrides(),
    ];

    Future<void> shootShared(
      WidgetTester tester,
      Widget body,
      Size size,
      String name, {
      OrgType orgType = OrgType.transporter,
      String title = 'Fixture Haulage',
      required String subtitle,
      required String selectedRoute,
      UserRole role = UserRole.admin,
      Brightness brightness = Brightness.dark,
      List<Override> extra = const [],
      Future<void> Function(WidgetTester tester)? act,
    }) => shoot(
      tester,
      screen(
        brightness: brightness,
        child: body,
        title: title,
        subtitle: _barTitle(selectedRoute, subtitle),
        orgType: orgType,
        role: role,
        selectedRoute: selectedRoute,
        extraOverrides: [...shared(), ...extra],
      ),
      size,
      name,
      act: act,
    );

    // --- messages ---------------------------------------------------------

    testWidgets('messages — desktop dark', (tester) async {
      await shootShared(
        tester,
        const MessagesScreen(),
        const Size(1600, 1000),
        'screen-messages-desktop-dark',
        subtitle: 'Messages',
        selectedRoute: '/messages',
      );
    });

    testWidgets('messages — phone dark', (tester) async {
      await shootShared(
        tester,
        const MessagesScreen(),
        const Size(412, 915),
        'screen-messages-phone-dark',
        subtitle: 'Messages',
        selectedRoute: '/messages',
      );
    });

    // The contacts half of the sidebar, which is a different list with
    // different grouping and the only place the blocked-contact pill appears.
    testWidgets('messages — people tab, desktop dark', (tester) async {
      await shootShared(
        tester,
        const MessagesScreen(),
        const Size(1600, 1000),
        'screen-messages-people-desktop-dark',
        subtitle: 'Messages',
        selectedRoute: '/messages',
        act: (tester) async {
          await tester.tap(find.text('People'));
          await tester.pump();
        },
      );
    });

    // --- the chat thread ---------------------------------------------------

    testWidgets('chat thread — desktop dark', (tester) async {
      await shootShared(
        tester,
        ChatScreen(
          chatRoom: fixtureChatScreenArgs().chatRoom,
          currentUserId: fixtureChatScreenArgs().currentUserId,
          currentUserName: fixtureChatScreenArgs().currentUserName,
          participants: fixtureChatScreenArgs().participants,
        ),
        const Size(1600, 1000),
        'screen-chat-thread-desktop-dark',
        subtitle: 'Chat',
        selectedRoute: '/chat/fixture-room-1',
      );
    });

    testWidgets('chat thread — phone dark', (tester) async {
      await shootShared(
        tester,
        ChatScreen(
          chatRoom: fixtureChatScreenArgs().chatRoom,
          currentUserId: fixtureChatScreenArgs().currentUserId,
          currentUserName: fixtureChatScreenArgs().currentUserName,
          participants: fixtureChatScreenArgs().participants,
        ),
        const Size(412, 915),
        'screen-chat-thread-phone-dark',
        subtitle: 'Chat',
        selectedRoute: '/chat/fixture-room-1',
      );
    });

    // --- notifications -----------------------------------------------------

    testWidgets('notifications — phone dark', (tester) async {
      await shootShared(
        tester,
        const NotificationScreen(),
        const Size(412, 1462),
        'screen-notifications-phone-dark',
        subtitle: 'Notifications',
        selectedRoute: '/notifications',
      );
    });

    testWidgets('notifications — desktop dark', (tester) async {
      await shootShared(
        tester,
        const NotificationScreen(),
        const Size(1600, 1400),
        'screen-notifications-desktop-dark',
        subtitle: 'Notifications',
        selectedRoute: '/notifications',
      );
    });

    testWidgets('notification manager — desktop dark', (tester) async {
      await shootShared(
        tester,
        const NotificationManagementScreen(title: 'All notifications'),
        const Size(1600, 1400),
        'screen-notification-manager-desktop-dark',
        subtitle: 'All notifications',
        selectedRoute: '/notifications/manage?title=All%20notifications',
      );
    });

    testWidgets('notification manager — phone dark', (tester) async {
      await shootShared(
        tester,
        const NotificationManagementScreen(title: 'All notifications'),
        const Size(412, 1398),
        'screen-notification-manager-phone-dark',
        subtitle: 'All notifications',
        selectedRoute: '/notifications/manage?title=All%20notifications',
      );
    });

    // --- the profile -------------------------------------------------------

    testWidgets('profile — phone dark', (tester) async {
      await shootShared(
        tester,
        const ProfileScreen(),
        const Size(412, 3955),
        'screen-profile-phone-dark',
        subtitle: 'My profile',
        selectedRoute: '/profile',
      );
    });

    testWidgets('profile — desktop dark', (tester) async {
      await shootShared(
        tester,
        const ProfileScreen(),
        const Size(1600, 2600),
        'screen-profile-desktop-dark',
        subtitle: 'My profile',
        selectedRoute: '/profile',
      );
    });

    // --- account security --------------------------------------------------

    testWidgets('account security — phone dark', (tester) async {
      await shootShared(
        tester,
        const AccountSecurityScreen(),
        const Size(412, 1429),
        'screen-account-security-phone-dark',
        subtitle: 'Account & security',
        selectedRoute: '/account-security',
      );
    });

    testWidgets('account security — desktop dark', (tester) async {
      await shootShared(
        tester,
        const AccountSecurityScreen(),
        const Size(1600, 1200),
        'screen-account-security-desktop-dark',
        subtitle: 'Account & security',
        selectedRoute: '/account-security',
      );
    });

    // --- appearance & theme ------------------------------------------------
    //
    // A MINE, because the two premium-theme sections are mine/supplier-only and
    // a transporter photographs one card of the three.

    testWidgets('appearance — phone dark', (tester) async {
      await shootShared(
        tester,
        const AppearanceThemeScreen(),
        const Size(412, 1283),
        'screen-appearance-phone-dark',
        orgType: OrgType.mineSupplier,
        title: 'Fixture Chrome Mine',
        subtitle: 'Appearance',
        selectedRoute: '/appearance',
        extra: [portalWorkspaceOverride(isMineSupplier: true)],
      );
    });

    testWidgets('appearance — desktop light', (tester) async {
      await shootShared(
        tester,
        const AppearanceThemeScreen(),
        const Size(1600, 1200),
        'screen-appearance-desktop-light',
        orgType: OrgType.mineSupplier,
        title: 'Fixture Chrome Mine',
        subtitle: 'Appearance',
        selectedRoute: '/appearance',
        brightness: Brightness.light,
        extra: [portalWorkspaceOverride(isMineSupplier: true)],
      );
    });

    // --- the employee register ---------------------------------------------

    testWidgets('employee register — phone dark', (tester) async {
      await shootShared(
        tester,
        const PortalEmployeeRegisterScreen(),
        const Size(412, 3910),
        'screen-employee-register-phone-dark',
        subtitle: 'Employee register',
        selectedRoute: '/portal/transporter/register',
      );
    });

    testWidgets('employee register — desktop dark', (tester) async {
      await shootShared(
        tester,
        const PortalEmployeeRegisterScreen(),
        const Size(1600, 2600),
        'screen-employee-register-desktop-dark',
        subtitle: 'Employee register',
        selectedRoute: '/portal/transporter/register',
      );
    });
  });

  // ==========================================================================
  // THE CHAT DOCK — the surface every user actually touches
  // ==========================================================================
  //
  // The coverage here was INVERTED, and this group is the correction.
  //
  // `MessagesScreen` has no rail entry at all and is reachable only when a
  // licence token is expiring; it had four shots. `ChatScreen` has one entry,
  // a card tap on the Communications hub; it had two. The dock is mounted on
  // EVERY portal screen and EVERY console screen — it is the chat of this
  // product — and it had NONE. Reactions, tap-to-scroll reply quotes and the
  // unread separator exist nowhere else and had never been photographed.
  //
  // It had none for a structural reason rather than an oversight: the dock is
  // mounted by `PortalShellLayout`, and this harness builds `MlAppShell`
  // directly, so no render has ever had a dock in its tree. It has to be
  // mounted deliberately, and it is opened the way a user opens it — by
  // tapping the launcher disc and then a conversation — so these pictures also
  // prove the launcher is there, is hittable, and reaches the thread.
  group('the chat dock', () {
    List<Override> dock() => [
      ...companyScopeOverrides(),
      ...sharedTailOverrides(),
      ...chatDockOverrides(),
    ];

    /// Mounts a dock over an empty page, opens it, and optionally walks into a
    /// conversation.
    ///
    /// The body underneath is deliberately plain: the subject is the panel,
    /// and a dashboard behind it would only make the picture harder to read.
    Future<void> shootDock(
      WidgetTester tester,
      Size size,
      String name, {
      Brightness brightness = Brightness.dark,
      String? openConversation,
      List<Override> extra = const [],
    }) => shoot(
      tester,
      ProviderScope(
        overrides: [...dock(), ...extra],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.build(brightness),
          home: const ChatDock(child: Scaffold(body: SizedBox.expand())),
        ),
      ),
      size,
      name,
      act: (tester) async {
        await tester.tap(find.byKey(const ValueKey('chat-dock-launcher')));
        await pumpForCapture(tester);
        if (openConversation != null) {
          await tester.tap(find.text(openConversation).first);
          await pumpForCapture(tester);
        }
      },
    );

    // ⚠️ THREE DELIBERATE CUT-OFFS live in this group, one per list render:
    // the group conversation's preview, "Seal 4 on CK 84 RT GP would not close
    // — swapped it." A conversation row shows one line of the last message and
    // ellipsises the rest; that is what the row is for. It takes the whole-app
    // CUT OFF count from 6 to 9, and all nine are this kind.
    //
    // What these renders found that was NOT deliberate is recorded in
    // `test/design/chat_palette_contrast_test.dart`: thirteen of the eighteen
    // palettes were painting text below 4.5:1, including every outgoing
    // message on the DEFAULT palette, plus an unread badge at 3.76:1 and a
    // reaction chip at 1.78:1. None of it was reachable before the dock had a
    // picture.

    // The conversations list — the dock's own landing view, with a group, a
    // DM, an org group and an ended conversation in it.
    testWidgets('dock — conversations, desktop dark', (tester) async {
      await shootDock(tester, const Size(1600, 1000), 'dock-list-desktop-dark');
    });

    testWidgets('dock — conversations, phone dark', (tester) async {
      await shootDock(tester, const Size(412, 915), 'dock-list-phone-dark');
    });

    testWidgets('dock — conversations, desktop light', (tester) async {
      await shootDock(
        tester,
        const Size(1600, 1000),
        'dock-list-desktop-light',
        brightness: Brightness.light,
      );
    });

    // The thread. This is the picture that did not exist: reply quotes over
    // both grounds, an attachment, reactions, delivery ticks and the unread
    // separator, none of which any other render has ever shown.
    testWidgets('dock — thread, desktop dark', (tester) async {
      await shootDock(
        tester,
        const Size(1600, 1000),
        'dock-thread-desktop-dark',
        openConversation: 'Thandi Mokoena',
      );
    });

    testWidgets('dock — thread, phone dark', (tester) async {
      await shootDock(
        tester,
        const Size(412, 915),
        'dock-thread-phone-dark',
        openConversation: 'Thandi Mokoena',
      );
    });

    testWidgets('dock — thread, desktop light', (tester) async {
      await shootDock(
        tester,
        const Size(1600, 1000),
        'dock-thread-desktop-light',
        brightness: Brightness.light,
        openConversation: 'Thandi Mokoena',
      );
    });

    // Someone typing. A live-only state that no still has ever caught, and the
    // one the thread's own layout is most likely to be surprised by, because
    // it appears BELOW the last bubble and pushes the composer.
    testWidgets('dock — thread with someone typing, desktop dark', (
      tester,
    ) async {
      await shootDock(
        tester,
        const Size(1600, 1000),
        'dock-thread-typing-desktop-dark',
        openConversation: 'Thandi Mokoena',
        extra: chatDockOverrides(typing: const {'Thandi Mokoena'}),
      );
    });
  });

  // ==========================================================================
  // THE DIALOGS
  // ==========================================================================
  //
  // §4.2 of the handoff: `test/test_helpers/dialog_sweep.dart` already sweeps
  // these for overflow and for silent truncation at 8 widths x 6 text scales.
  // What was missing is PICTURES — and every screen photographed in this phase
  // has turned up something a sweep cannot see.
  //
  // Each one is opened the way a user opens it, by TAPPING ITS TRIGGER on the
  // real host screen. That is slower to write than constructing the dialog
  // directly and it proves one more thing: that the control which opens it is
  // there, is enabled, and reaches this dialog.
  group('the dialogs', () {
    List<Override> tail() => [
      ...companyScopeOverrides(),
      ...portalCaptureOverrides(),
      ...portalTailOverrides(),
      ...sharedTailOverrides(),
    ];

    /// Taps the first widget whose text is [label], then settles.
    ///
    /// Returns without tapping when the trigger is absent, and the render then
    /// photographs the screen rather than the dialog — which is why every one
    /// of these is LOOKED AT rather than counted.
    Future<void> Function(WidgetTester) tap(String label) =>
        (WidgetTester tester) async {
          final f = find.text(label);
          if (f.evaluate().isEmpty) return;
          await tester.ensureVisible(f.first);
          await tester.pumpAndSettle();
          await tester.tap(f.first, warnIfMissed: false);
          await tester.pumpAndSettle();
        };

    Future<void> shootDialog(
      WidgetTester tester,
      Widget body,
      String trigger,
      Size size,
      String name, {
      required OrgType orgType,
      required UserRole role,
      required String title,
      required String subtitle,
      required String selectedRoute,
      List<Override> extra = const [],
    }) => shoot(
      tester,
      screen(
        brightness: Brightness.dark,
        child: body,
        title: title,
        subtitle: subtitle,
        orgType: orgType,
        role: role,
        selectedRoute: selectedRoute,
        extraOverrides: [...tail(), ...extra],
      ),
      size,
      name,
      act: tap(trigger),
    );

    testWidgets('log fuel — phone dark', (tester) async {
      await shootDialog(
        tester,
        const FuelCostsScreen(),
        'Log fuel',
        const Size(412, 915),
        'dialog-log-fuel-phone-dark',
        orgType: OrgType.transporter,
        role: UserRole.admin,
        title: 'Fixture Haulage',
        subtitle: 'Fuel & costs',
        selectedRoute: '/portal/transporter/fuel-costs',
      );
    });

    testWidgets('log cost — phone dark', (tester) async {
      await shootDialog(
        tester,
        const FuelCostsScreen(),
        'Log cost',
        const Size(412, 915),
        'dialog-log-cost-phone-dark',
        orgType: OrgType.transporter,
        role: UserRole.admin,
        title: 'Fixture Haulage',
        subtitle: 'Fuel & costs',
        selectedRoute: '/portal/transporter/fuel-costs',
      );
    });

    testWidgets('add document — phone dark', (tester) async {
      await shootDialog(
        tester,
        const ComplianceScreen(),
        'Add document',
        const Size(412, 915),
        'dialog-add-document-phone-dark',
        orgType: OrgType.transporter,
        role: UserRole.admin,
        title: 'Fixture Haulage',
        subtitle: 'Compliance',
        selectedRoute: '/portal/transporter/compliance',
      );
    });

    testWidgets('quality spec — phone dark', (tester) async {
      await shootDialog(
        tester,
        const MineQualityScreen(),
        'Edit spec',
        const Size(412, 915),
        'dialog-quality-spec-phone-dark',
        orgType: OrgType.mineSupplier,
        role: UserRole.admin,
        title: 'Fixture Minerals',
        subtitle: 'Quality',
        selectedRoute: '/portal/mine/quality',
      );
    });

    // The quality CERTIFICATE, which is a different dialog from the spec
    // above: the spec is the contract the route is judged against, the
    // certificate is one delivered load's lab result and the penalty it earns.
    testWidgets('quality certificate — phone dark', (tester) async {
      await shootDialog(
        tester,
        const MineQualityScreen(),
        'Attach',
        const Size(412, 915),
        'dialog-quality-cert-phone-dark',
        orgType: OrgType.mineSupplier,
        role: UserRole.admin,
        title: 'Fixture Minerals',
        subtitle: 'Quality',
        selectedRoute: '/portal/mine/quality',
      );
    });

    testWidgets('invoice capture — phone dark', (tester) async {
      await shootDialog(
        tester,
        const BuyerLoadsValueScreen(),
        'Invoice',
        const Size(412, 915),
        'dialog-invoice-capture-phone-dark',
        orgType: OrgType.buyer,
        role: UserRole.admin,
        title: 'Fixture Metals',
        subtitle: 'Loads & value',
        selectedRoute: '/portal/buyer/loads-value',
      );
    });

    testWidgets('record load — phone dark', (tester) async {
      await shootDialog(
        tester,
        const LoadControllerScreen(),
        'Record Load',
        const Size(412, 915),
        'dialog-record-load-phone-dark',
        orgType: OrgType.mineSupplier,
        role: UserRole.controllerWB,
        title: 'Fixture Minerals',
        subtitle: 'Load controller',
        selectedRoute: '/portal/mine/weighbridge',
      );
    });

    testWidgets('new chat group — phone dark', (tester) async {
      await shootDialog(
        tester,
        const MessagesScreen(),
        'New group',
        const Size(412, 915),
        'dialog-new-chat-group-phone-dark',
        orgType: OrgType.transporter,
        role: UserRole.admin,
        title: 'Fixture Haulage',
        subtitle: 'Messages',
        selectedRoute: '/messages',
      );
    });

    // THE WAYBILL MODAL, in the state a reader most needs to understand.
    //
    // WHAT THIS PROVES AND WHAT IT DOES NOT. The modal's body is a
    // `PdfPreview`, which rasterises through the platform's PDF engine — that
    // does not exist under `flutter_test`, so a picture of the document itself
    // is not obtainable here. The waybill's own LAYOUT is covered instead by
    // `waybill_pdf_test.dart` and was rasterised against the reference image
    // `assets/Varsiwave waybil 2l.png` in an earlier phase.
    //
    // What IS here is the chrome nobody had looked at: the header, the
    // waybill number, the copy-link control S6-27 added, Close, and the empty
    // state a trip with no waybill yet shows — which is the state a load
    // controller sees before the second weigh, and therefore the one most
    // likely to be met by surprise.
    testWidgets('waybill modal, none yet — phone dark', (tester) async {
      await shoot(
        tester,
        ProviderScope(
          overrides: companyScopeOverrides(),
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.build(Brightness.dark),
            home: Consumer(
              builder: (context, ref, _) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    child: const Text('Open waybill'),
                    onPressed: () => showWaybillModal(
                      context,
                      ref,
                      tripId: 't-2',
                      waybillNumber: 'TRP-000124',
                      fetch: (_, __) async => null,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const Size(412, 915),
        'dialog-waybill-none-phone-dark',
        act: (tester) async {
          final f = find.text('Open waybill');
          if (f.evaluate().isEmpty) return;
          await tester.tap(f.first, warnIfMissed: false);
          await tester.pumpAndSettle();
        },
      );
    });

    testWidgets('add vehicle — phone dark', (tester) async {
      await shoot(
        tester,
        screen(
          brightness: Brightness.dark,
          child: const FleetManagementScreen(),
          title: 'Fixture Haulage',
          subtitle: 'Fleet management',
          orgType: OrgType.transporter,
          role: UserRole.admin,
          selectedRoute: '/portal/transporter/fleet',
          extraOverrides: tail(),
        ),
        const Size(412, 915),
        'dialog-add-vehicle-phone-dark',
        act: (tester) async {
          // A FAB with a tooltip, not a labelled button.
          final f = find.byTooltip('Add Vehicle');
          if (f.evaluate().isEmpty) return;
          await tester.tap(f.first, warnIfMissed: false);
          await tester.pumpAndSettle();
        },
      );
    });
  });

  group('console', () {
    testWidgets('desktop dark — expanded rail', (tester) async {
      await shoot(
        tester,
        console(brightness: Brightness.dark),
        const Size(1600, 1900),
        'console-desktop-dark',
      );
    });

    testWidgets('desktop light — expanded rail', (tester) async {
      await shoot(
        tester,
        console(brightness: Brightness.light),
        const Size(1600, 1900),
        'console-desktop-light',
      );
    });

    testWidgets('desktop dark — collapsed rail', (tester) async {
      await shoot(
        tester,
        console(brightness: Brightness.dark, railExpanded: false),
        const Size(1600, 1900),
        'console-desktop-dark-rail-collapsed',
      );
    });

    testWidgets('medium — the rail narrows, nothing is removed', (
      tester,
    ) async {
      await shoot(
        tester,
        console(brightness: Brightness.dark),
        const Size(760, 1400),
        'console-medium-dark',
      );
    });

    testWidgets('phone dark — bottom bar and drawer', (tester) async {
      await shoot(
        tester,
        console(brightness: Brightness.dark),
        const Size(412, 915),
        'console-phone-dark',
      );
    });

    testWidgets('phone light', (tester) async {
      await shoot(
        tester,
        console(brightness: Brightness.light),
        const Size(412, 915),
        'console-phone-light',
      );
    });
  });
}

/// Stands in for a portal dashboard in the shell renders.
///
/// It says what it is, on the image, so nobody can mistake one of these for a
/// screenshot of a working dashboard.
class _PortalBodyPlaceholder extends StatelessWidget {
  const _PortalBodyPlaceholder();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.dashboard_customize_outlined,
              size: 44,
              color: scheme.onSurfaceVariant,
            ),
            const SizedBox(height: 14),
            Text(
              'Workspace body',
              textAlign: TextAlign.center,
              style: text.titleMedium?.copyWith(color: scheme.onSurface),
            ),
            const SizedBox(height: 6),
            Text(
              'These renders are of the SHELL — the rail, its grouping for '
              'this role, the top bar and the canvas. The dashboards need a '
              'live session; a picture of their loading state would not be a '
              'picture of the design.',
              textAlign: TextAlign.center,
              style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

/// Every PNG in `docs/redesign/renders/` must be one this file still produces.
///
/// An orphan golden is a stale picture with nobody to update it: it survives
/// `--update-goldens`, it survives review, and it goes on being the answer when
/// somebody asks what a screen looks like. Three screens were dropped from this
/// file for leaving pending timers, and one of their images stayed behind —
/// which is exactly how a render that no longer reflects the app becomes the
/// one people look at.
void _noOrphanGoldensTest() {
  test('no golden in docs/redesign/renders/ is orphaned', () {
    final source = File(
      'test/renders/redesign_renders_test.dart',
    ).readAsStringSync();
    final dir = Directory('docs/redesign/renders');
    final orphans = <String>[];
    for (final f in dir.listSync().whereType<File>()) {
      final name = f.uri.pathSegments.last;
      if (!name.endsWith('.png')) continue;
      final stem = name.substring(0, name.length - 4);
      if (!source.contains("'$stem'")) orphans.add(name);
    }
    expect(
      orphans,
      isEmpty,
      reason:
          'These images are in docs/redesign/renders/ but nothing here '
          'generates them any more, so nothing will ever update them:\n'
          '  ${orphans.join('\n  ')}\n'
          'Delete them, or restore the test that made them.',
    );
  });
}

/// The top bar a render photographs must be the one the router would draw.
///
/// Every `shootPortal` / `shootShared` call types its bar title by hand, and a
/// hand-typed copy of something the code computes drifts the moment the code
/// changes. It did: the 2026-08-22 route-name pass renamed eight destinations,
/// and three fixtures went on photographing the old names — a picture that
/// says a screen is called something it is no longer called is worse than no
/// picture, because it reads as evidence.
///
/// So the fixture's string is now CHECKED against `mlRouteTitle`, the resolver
/// the real top bar uses, and the render is evidence of the actual name.
///
/// [_barTitleExempt] is for the routes whose real title depends on session
/// state the resolver is not given — the section dashboards, whose bar names
/// the active TAB. Each one names the reason.
const Map<String, String> _barTitleExempt = {
  '/portal/mine': 'bar names the active tab; the resolver has no tab set',
  '/portal/buyer': 'bar names the active tab; the resolver has no tab set',
  '/portal/transporter':
      'bar names the active tab; the resolver has no tab set',
  '/portal/driver': 'bar names the active tab; the resolver has no tab set',
  '/home': 'bar names the active tab; the resolver has no tab set',
};

String _barTitle(String selectedRoute, String subtitle) {
  if (_barTitleExempt.containsKey(selectedRoute)) return subtitle;
  final resolved = mlRouteTitle(Uri.parse(selectedRoute)).title;
  expect(
    subtitle,
    resolved,
    reason:
        'the fixture photographs "$subtitle" in the top bar of $selectedRoute, '
        'but the router resolves that route to "$resolved". Change the '
        'fixture, or add $selectedRoute to _barTitleExempt with a reason.',
  );
  return resolved;
}
