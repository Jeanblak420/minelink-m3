// The portal's tail: the screens a company works in that had never been
// rendered.
//
// The twin of `test/features/super_admin/console_tail_test.dart`, and it
// exists for the same reason — everything asserted here was found by looking
// at a picture, and none of it failed anything before. A raw enum value is a
// perfectly valid string; a mislabelled count is a perfectly valid number; a
// heading made of three punctuation marks is a perfectly valid heading.
//
// Found 2026-08-21, first render of each screen:
//
//   * The buyer's Routes & Mines captioned both of its linked mines
//     **"mineSupplier"** — `companies.org_type` verbatim, the same defect
//     `controllerWB` was on the console — and headed its route list
//     "4 route records" while showing two routes, because it counted the
//     snapshot's TRANSACTIONS.
//   * The buyer's Waybills grouped a transaction with no route metadata under
//     a heading of **"— → —"**, and counted it in "3 routes".
//   * The allocated-truck chips on a linked request ran **156px** past a 412px
//     phone: a `Row` inside a `Wrap`, laid out against unbounded width, so
//     nothing could ellipsise (CLAUDE.md §10.4).
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:flutter_map/flutter_map.dart' show NetworkTileProvider;

import 'package:flutter_application_1/core/theme/app_theme.dart';
import 'package:flutter_application_1/core/widgets/osm_tile_layer.dart';
import 'package:flutter_application_1/core/time/ml_time.dart';
import 'package:flutter_application_1/features/portal/screens/buyer_requests_screen.dart';
import 'package:flutter_application_1/features/portal/screens/buyer_truck_locations_screen.dart';
import 'package:flutter_application_1/features/portal/screens/buyer_routes_mines_screen.dart';
import 'package:flutter_application_1/features/portal/screens/buyer_waybills_screen.dart';
import 'package:flutter_application_1/features/portal/screens/mine_locations_screen.dart';
import 'package:flutter_application_1/features/portal/screens/portal_trip_detail_screen.dart';
import 'package:flutter_application_1/features/portal/screens/stockpile_audit_screen.dart';
import 'package:flutter_application_1/features/portal/screens/tons_out_detail_screen.dart';

import '../../fixtures/portal_capture_fixtures.dart';
import '../../fixtures/portal_tail_fixtures.dart';
import '../../fixtures/screen_fixtures.dart';
import '../../test_helpers/fake_path_provider.dart';
import '../../test_helpers/real_fonts.dart';
import '../../test_helpers/render_pumps.dart';

void main() {
  setUpAll(() async {
    await loadRealFonts();
    SharedPreferences.setMockInitialValues({});
    // The truck-locations screens draw a `flutter_map`. Without these two the
    // tile cache asks path_provider for a directory before it will even
    // conclude a tile is unavailable, and the `MissingPluginException` that
    // follows fails the TEST from an async gap rather than the widget — with
    // the assertions already passed. Same pair the render harness installs,
    // and for the same reason.
    installFakePathProvider();
    mlTileProviderOverride = NetworkTileProvider.new;
    addTearDown(() => mlTileProviderOverride = null);
    // The fixtures are stamped from `kCaptureNow`, and these screens print
    // relative dates off it. Without freezing the clock the assertions would
    // be against the wall clock and would rot by the day.
    MlTime.debugClock = () => kCaptureNow;
    addTearDown(() => MlTime.debugClock = null);
    await Supabase.initialize(
      url: 'http://localhost:54321',
      anonKey: 'portal-tail',
    );
  });

  /// Pumps [screen] and returns every overflow the framework reported.
  ///
  /// The handler is restored before returning, NOT in an `addTearDown` —
  /// tear-downs run after the body's `expect`s and the binding then asserts
  /// *"a test overrode FlutterError.onError but failed to return it"*, which
  /// times the whole file out at ten minutes.
  Future<List<String>> pump(
    WidgetTester tester,
    Widget screen, {
    double width = 412,
    double height = 2600,
  }) async {
    final overflows = <String>[];
    final previous = FlutterError.onError;
    FlutterError.onError = (details) {
      final message = details.exception.toString();
      if (message.contains('overflowed')) {
        overflows.add(message.split('\n').first);
      } else {
        previous?.call(details);
      }
    };

    tester.view.physicalSize = Size(width, height);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(ProviderScope(
      overrides: [
        ...companyScopeOverrides(),
        ...portalCaptureOverrides(),
        ...portalTailOverrides(),
      ],
      child: MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(body: screen),
      ),
    ));
    await pumpForCapture(tester);
    FlutterError.onError = previous;
    return overflows;
  }

  /// Every string this screen actually paints, `Text` and `TextSpan` alike.
  ///
  /// `find.text` cannot see a `TextSpan` (HANDOFF §5), and several of these
  /// screens build a line as spans of one paragraph — so walking
  /// `RenderParagraph` is the only way to ask "does `mineSupplier` appear
  /// anywhere on this screen".
  List<String> painted(WidgetTester tester) {
    final out = <String>[];
    void visit(Element e) {
      final ro = e.renderObject;
      if (ro is RenderParagraph) out.add(ro.text.toPlainText());
      e.visitChildren(visit);
    }

    tester.allElements.first.visitAncestorElements((a) {
      visit(a);
      return false;
    });
    return out;
  }

  /// Every string on screen that was CUT OFF — laid out past its line limit
  /// and finished with an ellipsis.
  ///
  /// [painted] cannot see this. `RenderParagraph.text.toPlainText()` returns
  /// the whole string whichever part of it was drawn, so an assertion that a
  /// name "appears on screen" passes happily while the reader sees
  /// "Main Gate …". Measured the hard way: that assertion survived reverting
  /// the fix it was written for.
  ///
  /// `didExceedMaxLines` is the paragraph's own answer to "did I have to
  /// truncate", which is the question.
  List<String> truncated(WidgetTester tester) {
    final out = <String>[];
    void visit(Element e) {
      final ro = e.renderObject;
      if (ro is RenderParagraph && ro.didExceedMaxLines) {
        out.add(ro.text.toPlainText());
      }
      e.visitChildren(visit);
    }

    tester.allElements.first.visitAncestorElements((a) {
      visit(a);
      return false;
    });
    return out;
  }

  /// The wire values that must never reach a reader.
  ///
  /// The same list the console holds, because the two sides read the same
  /// columns. Substring matching, because they appear inside sentences —
  /// "Iron Hills Mining · mineSupplier" is the shape the fault took.
  const wireVocabulary = <String>[
    'controllerWB',
    'supervisorForeman',
    'mineSupplier',
    'in_progress',
    'en_route_to_offload',
    'arrived_at_mine',
    'left_mine',
  ];

  void expectNoWireVocabulary(WidgetTester tester, String where) {
    final leaks = <String>[];
    for (final line in painted(tester)) {
      for (final wire in wireVocabulary) {
        if (line.contains(wire)) leaks.add('"$line" contains `$wire`');
      }
    }
    expect(leaks, isEmpty,
        reason: '$where is showing Postgres\'s vocabulary to a customer:\n'
            '${leaks.join('\n')}\n'
            'Org types go through `OrgType.labelFor`, roles through '
            '`UserRole.labelFor`, trip statuses through `TripStatus.parse().label`, '
            'other statuses through `MlStatusBadge.humaniseStatus`.');
  }

  // ------------------------------------------------------- routes and mines

  testWidgets('Routes & Mines names its partners in English', (tester) async {
    await pump(tester, const BuyerRoutesMinesScreen(), height: 1400);
    expectNoWireVocabulary(tester, "the buyer's Routes & Mines");
  });

  testWidgets('and its header counts ROUTES, not transactions', (tester) async {
    await pump(tester, const BuyerRoutesMinesScreen(), height: 1400);
    // `kLogistics` deliberately holds two routes and four transactions, so a
    // header counting the wrong list says "4" beside two cards. The two
    // numbers being different is the whole point of the fixture.
    expect(kLogistics.routes.length, isNot(kLogistics.waybills.length),
        reason: 'the fixture no longer distinguishes routes from '
            'transactions, so this test cannot fail.');
    final lines = painted(tester);
    expect(lines.any((l) => l.contains('2 routes')), isTrue,
        reason: 'the Routes & Mines header does not say "2 routes" for the '
            'two routes it draws. It said "4 route records" — the count of '
            'the snapshot\'s transactions — until 2026-08-21.\n'
            'Painted: ${lines.take(12).join(' | ')}');
  });

  // -------------------------------------------------------------- waybills

  testWidgets('Waybills names the unrouted group rather than punctuating it',
      (tester) async {
    await pump(tester, const BuyerWaybillsScreen(), height: 1600);
    final lines = painted(tester);
    expect(lines.any((l) => l.trim() == '— → —'), isFalse,
        reason: 'a transaction with no loading or offloading point is heading '
            'its own group with three punctuation marks, which reads as a '
            'rendering failure rather than as a state.\n'
            'Painted: ${lines.take(20).join(' | ')}');
    expect(lines.any((l) => l.contains('Not linked to a route yet')), isTrue,
        reason: 'the unrouted transaction has no named group at all.');
  });

  testWidgets('and counts only the real routes in its header', (tester) async {
    await pump(tester, const BuyerWaybillsScreen(), height: 1600);
    final lines = painted(tester);
    // Four transactions across two real routes plus one unrouted.
    expect(lines.any((l) => l.contains('4 waybills · 2 routes')), isTrue,
        reason: 'the header counts the unrouted group as a route. It read '
            '"4 waybills · 3 routes" until 2026-08-21.\n'
            'Painted: ${lines.take(12).join(' | ')}');
  });

  // ------------------------------------------------------- truck locations

  testWidgets('the GPS list says how OLD each sample is', (tester) async {
    await pump(tester, const BuyerTruckLocationsScreen(),
        width: 1400, height: 1100);
    final lines = painted(tester);
    // `kPositions` reports at 4 minutes, 21 minutes and 9 hours. The column
    // printed `dd MMM`, so all three read "15 Aug" — one string, three very
    // different answers, on the screen whose whole subject is freshness.
    for (final expected in const ['4m', '21m', '9h']) {
      expect(lines.any((l) => l.trim() == expected), isTrue,
          reason: 'the truck-locations list does not show "$expected" for the '
              'sample recorded that long ago. Three trucks reporting minutes '
              'and hours apart all printed the same DATE until 2026-08-21.\n'
              'Painted: ${lines.take(20).join(' | ')}');
    }
  });

  // ------------------------------------------------------- the mine's tail

  testWidgets('an anchor point states its own NAME on a phone', (tester) async {
    await pump(tester, const MineLocationsScreen(), height: 1900);
    // The row was icon + title + badge + button on ONE line, and at 412px that
    // left the title about 85px — so every anchor read "Main Gate …" /
    // "Weighbridge …", the name truncated back to the word the row already
    // says, on the screen whose whole job is naming these three points.
    //
    // `truncated`, not `painted`: the paragraph still HOLDS the whole name
    // when it is ellipsised, so asking whether the string is on screen is not
    // asking anything. Proved by reverting the fix and watching that version
    // of this test pass.
    final cut = truncated(tester)
        .where((l) =>
            l.contains('Main Gate') ||
            l.contains('Weighbridge') ||
            l.contains('Loading Point') ||
            l.contains('Beside the workshop') ||
            l.contains('R37'))
        .toList();
    expect(cut, isEmpty,
        reason: 'the anchor rows are truncating what they exist to say:\n'
            '  ${cut.join('\n  ')}');
  });

  testWidgets('and an unpinned anchor shows the address it DOES have',
      (tester) async {
    await pump(tester, const MineLocationsScreen(), height: 1900);
    final lines = painted(tester);
    // `kMineAnchors` gives the Weighbridge a name and an address but no
    // coordinate. The row used to fall through to the generic description, so
    // the address the mine had typed in appeared nowhere on the screen.
    expect(lines.any((l) => l.contains('Beside the workshop')), isTrue,
        reason: 'the unpinned anchor is showing boilerplate instead of the '
            'address it holds.\nPainted: ${lines.take(20).join(' | ')}');
  });

  testWidgets('the stockpile audit names the buyer once', (tester) async {
    await pump(tester, const StockpileAuditScreen(), height: 1700);
    final lines = painted(tester);
    final doubled = lines
        .where((l) =>
            'Atlas Buyer Group'.allMatches(l).length > 1 ||
            'Northvale Alloys'.allMatches(l).length > 1)
        .toList();
    expect(doubled, isEmpty,
        reason: 'an order pile is NAMED after its buyer, so appending the '
            'buyer again gives "Loaded out · Order pile · Atlas Buyer Group · '
            'Atlas Buyer Group" — three lines of a phone to say one thing:\n'
            '${doubled.join('\n')}');
  });

  testWidgets('the tons-out cards carry their unit', (tester) async {
    await pump(tester, TonsOutDetailScreen(entries: kTonsOut), height: 2300);
    final lines = painted(tester);
    // 6 loads summing to 197.70 t. The card printed `198` — no unit, and
    // rounded, so it disagreed with the table under it about the same figure.
    expect(lines.any((l) => l.trim() == '197.7 t'), isTrue,
        reason: 'the All-time card is not showing "197.7 t". It printed a bare '
            'rounded number on a screen called Tons out until 2026-08-21.\n'
            'Painted: ${lines.take(24).join(' | ')}');
  });

  testWidgets('the trip detail says both ends of the haul, and says WHEN in '
      'one vocabulary', (tester) async {
    await pump(tester, const PortalTripDetailScreen(tripId: 't-2'),
        height: 1500);
    final lines = painted(tester);
    expect(lines.any((l) => l.contains('Iron Hills Mining')), isTrue,
        reason: 'the trip detail names the destination and not the source, so '
            'a load can be read here without knowing which mine it left.');
    // `t-2` is stamped two hours before `kCaptureNow` (09:30 UTC), i.e.
    // 07:30 UTC = 09:30 SAST on 15 Aug.
    expect(lines.any((l) => l.contains('15 Aug 2026 · 09:30')), isTrue,
        reason: 'the Updated row is not in the product\'s one timestamp '
            'vocabulary. It used `MaterialLocalizations`, which is the '
            'READER\'S locale — and it took the DATE from the raw UTC instant '
            'while taking the TIME from SAST.\n'
            'Painted: ${lines.take(20).join(' | ')}');
    expect(lines.any((l) => l.contains('Truck registration')), isFalse,
        reason: 'the plate is the hero at the top of this screen; the fact '
            'table repeated it as its second row.');
  });

  // -------------------------------------------------------------- requests

  for (final width in const [360.0, 412.0]) {
    testWidgets('the Requests screen stays inside its cards at '
        '${width.toInt()}px', (tester) async {
      final overflows =
          await pump(tester, const BuyerRequestsScreen(), width: width);
      expect(overflows, isEmpty,
          reason: 'the buyer\'s Requests screen overflows '
              '${overflows.length} time(s). The allocated-truck chips are a '
              '`Row` inside a `Wrap` again — unbounded width, so nothing '
              'ellipsises and the chip simply runs off the card '
              '(CLAUDE.md §10.4).\n  ${overflows.join('\n  ')}');
    });
  }

  testWidgets('and every allocated-truck chip fits the card it is in',
      (tester) async {
    await pump(tester, const BuyerRequestsScreen());
    // The DETAIL line, not the plate.
    //
    // The plate leads the chip, so its own rectangle is inside the screen even
    // when everything after it has run off the card — measured: with the fix
    // reverted this assertion still passed on `CK 84 RT GP` while the row
    // overflowed by 156px. What runs off is the transporter/driver/status
    // line, so that is what has to be measured.
    // Scoped by the DRIVER names, which only the chip carries. Matching on
    // "Roadhaul Logistics" alone also catches the Transporters column of the
    // request-tracking table, and that one lives inside a 1200px-wide
    // horizontally-scrolled viewport where a right edge past 412 is correct.
    final detail = find.textContaining('S. Nkosi');
    expect(detail, findsWidgets,
        reason: 'the allocated-truck chips are not on screen, so this test is '
            'measuring nothing.');
    for (final element in detail.evaluate()) {
      final rect = tester.getRect(find.byElementPredicate((x) => x == element));
      expect(rect.right, lessThan(412),
          reason: 'an allocated-truck chip reaches ${rect.right}px on a 412px '
              'screen. A `Row` inside a `Wrap` is laid out against unbounded '
              'width, so its `Text` never ellipsises.');
    }
  });
}
