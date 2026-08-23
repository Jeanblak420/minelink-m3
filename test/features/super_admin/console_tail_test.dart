// The console's tail: the screens that had never been rendered.
//
// Everything asserted here was found by looking at a picture on 2026-08-21, and
// none of it failed anything before: an overflow paints a debug stripe and is
// silently clipped in release, and a raw enum value is a perfectly valid string.
//
//   * The audit log's action badge was unflexed in a `Row`, so "COMPANY
//     SUSPENDED" ran **20px past the card** at 412px while what was left of the
//     entry read "Suspended for non-payment; t…" — CLAUDE.md §10.4 again. And
//     the organisation line under it had no bound at all, so "Consolidated
//     Mineral Offtake & Logistics Holdings" simply ran off the edge without
//     even ellipsising.
//   * `controllerWB` appeared verbatim on the account-deactivations queue —
//     Postgres's vocabulary on an admin's screen, and the same defect the
//     token-requests screen was fixed for two commits earlier. The platform
//     users list beside it said "Load Controller" for the same person.
//   * The token history said **TOKEN_GENERATED** where the audit log said
//     "Token Generated" for the identical row, and captioned every group with
//     `org o1` — a database key.
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:flutter_application_1/core/design/components/ml_components.dart';
import 'package:flutter_application_1/core/design/tokens/ml_tokens.dart';
import 'package:flutter_application_1/core/theme/app_theme.dart';
import 'package:flutter_application_1/core/time/ml_time.dart';
import 'package:flutter_application_1/features/super_admin/screens/account_deactivations_screen.dart';
import 'package:flutter_application_1/features/super_admin/screens/audit_logs_screen.dart';
import 'package:flutter_application_1/features/super_admin/screens/available_routes_screen.dart';
import 'package:flutter_application_1/features/super_admin/screens/driver_limit_requests_screen.dart';
import 'package:flutter_application_1/features/super_admin/screens/organization_detail_screen.dart';
import 'package:flutter_application_1/features/super_admin/screens/platform_users_screen.dart';
import 'package:flutter_application_1/features/super_admin/screens/super_admin_company_mirror_screen.dart';
import 'package:flutter_application_1/core/design/tokens/ml_control_room_palette.dart';
import 'package:flutter_application_1/features/super_admin/screens/token_history_screen.dart';

import '../../fixtures/console_capture_fixtures.dart';
import '../../fixtures/console_tail_fixtures.dart';
import '../../fixtures/portal_capture_fixtures.dart';
import '../../fixtures/screen_fixtures.dart';
import '../../test_helpers/real_fonts.dart';

void main() {
  setUpAll(() async {
    await loadRealFonts();
    SharedPreferences.setMockInitialValues({});
    // Freeze the clock at the instant the fixtures are stamped from, exactly
    // as the render harness does. Every relative date and countdown on these
    // screens is measured from it, so without this the assertions below would
    // be against the wall clock and would rot by the day.
    MlTime.debugClock = () => kCaptureNow;
    addTearDown(() => MlTime.debugClock = null);
    await Supabase.initialize(
      url: 'http://localhost:54321',
      anonKey: 'console-tail',
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
    double height = 2400,
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
        ...consoleCaptureOverrides(),
        ...portalCaptureOverrides(),
        ...consoleTailOverrides(),
        ...consoleLastOverrides(),
        ...companyMirrorOverrides(),
      ],
      child: MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(body: screen),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 900));
    FlutterError.onError = previous;
    return overflows;
  }

  /// Every string this screen actually paints, `Text` and `TextSpan` alike.
  ///
  /// `find.text` cannot see a `TextSpan` (CLAUDE.md §5), and several of these
  /// screens build their lines as spans of one paragraph — so walking
  /// `RenderParagraph` is the only way to ask "does the word `controllerWB`
  /// appear anywhere on this screen".
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

  /// The wire values that must never reach a reader.
  ///
  /// Substring matching, because they appear inside sentences — "Iron Hills
  /// Mining · controllerWB" is the shape the fault took.
  const wireVocabulary = <String>[
    'controllerWB',
    'supervisorForeman',
    'mineSupplier',
    'TOKEN_GENERATED',
    'TOKEN_REVOKED',
    'COMPANY_SUSPENDED',
    'USER_ASSIGNED_TO_SEAT',
    'in_progress',
    'seat_expansion',
    'token_renewal',
  ];

  void expectNoWireVocabulary(WidgetTester tester, String where) {
    final leaks = <String>[];
    for (final line in painted(tester)) {
      for (final wire in wireVocabulary) {
        if (line.contains(wire)) leaks.add('"$line" contains `$wire`');
      }
    }
    expect(leaks, isEmpty,
        reason: '$where is showing Postgres\'s vocabulary to an admin:\n'
            '${leaks.join('\n')}\n'
            'Roles go through `UserRole.labelFor`, audit actions through '
            '`AuditLog.actionLabel`, statuses through '
            '`MlStatusBadge.humaniseStatus`.');
  }

  // ------------------------------------------------------------------ audit
  for (final width in const [360.0, 412.0]) {
    testWidgets('the audit log stays inside its cards at ${width.toInt()}px',
        (tester) async {
      final overflows = await pump(tester, const AuditLogsScreen(),
          width: width, height: 2600);
      expect(overflows, isEmpty,
          reason: 'the audit log overflows ${overflows.length} time(s). The '
              'action badge is unflexed beside the description again: below '
              '380px it belongs on its own line, not squeezing a two-line '
              'entry into a third of the card.');
    });
  }

  testWidgets('and the audit log opens in the shared page header',
      (tester) async {
    // 'Audit Logs' was 16px PlusJakartaSans ExtraBold set by hand, title-
    // cased against the app bar's 'Audit logs', with a bare download icon
    // and no description or count. Found 2026-08-23 in the Phase 3 pass.
    await pump(tester, const AuditLogsScreen(), width: 1600, height: 1600);
    final header = find.byType(MlPageHeader);
    expect(header, findsOneWidget);
    final title = tester.widget<Text>(
        find.descendant(of: header, matching: find.text('Audit logs')));
    expect(title.style?.fontFamily, MlTokens.fontSerif);
    expect(find.text('Audit Logs'), findsNothing,
        reason: 'the title is title-cased again');
    expect(tester.widget<MlPageHeader>(header).meta, matches(r'^\d+ entr'));
  });

  testWidgets('and the organisation on an audit entry ellipsises',
      (tester) async {
    await pump(tester, const AuditLogsScreen(), height: 2600);
    final org = find.text(kLongOrgName);
    expect(org, findsWidgets, reason: 'the long-named org is not on screen.');
    final widths = org
        .evaluate()
        .map((e) => tester.getRect(find.byElementPredicate((x) => x == e)).width)
        .toList();
    for (final w in widths) {
      expect(w, lessThan(412),
          reason: 'the organisation line is $w px wide inside a 412px screen, '
              'so it is laid out against an unbounded constraint and its '
              'ellipsis can never engage.');
    }
  });

  testWidgets('and the badge is a kicker on a phone, beside the entry on a '
      'console', (tester) async {
    await pump(tester, const AuditLogsScreen(), height: 2600);
    final badge = tester.getRect(find.text('TOKEN GENERATED').first);
    final entry = tester
        .getRect(find.text('Issued a 365-day serial token with 5 seats.').first);
    expect(badge.bottom, lessThanOrEqualTo(entry.top + 1),
        reason: 'at 412px the badge is still beside the entry.');

    await pump(tester, const AuditLogsScreen(), width: 1600, height: 1600);
    final wideBadge = tester.getRect(find.text('TOKEN GENERATED').first);
    final wideEntry = tester
        .getRect(find.text('Issued a 365-day serial token with 5 seats.').first);
    expect(wideBadge.left, greaterThan(wideEntry.right),
        reason: 'the badge dropped onto its own line at 1600px, where there '
            'is room for both. Stacking everywhere is not the fix.');
  });

  // ------------------------------------------------------------ vocabulary
  testWidgets('account deactivations name the role in English',
      (tester) async {
    await pump(tester, const AccountDeactivationsScreen(), height: 2600);
    expectNoWireVocabulary(tester, 'the account deactivations queue');
    // The positive half: the fixture's `controllerWB` has to appear AS
    // something, or this test passes on a screen that renders nothing.
    expect(find.textContaining('Load Controller'), findsWidgets);
  });

  testWidgets('and the deactivations queue opens in the shared page header, '
      'with its actions on the right', (tester) async {
    // Two drifts found 2026-08-23 in the Phase 3 pass: a hand-rolled 16px
    // sans title (every other console screen opens through MlPageHeader),
    // and Approve / Reject hanging at the card's far left under the icon
    // well, where the reference (and the request-review card) put a card's
    // actions on the right.
    await pump(tester, const AccountDeactivationsScreen(),
        width: 1600, height: 1600);
    final header = find.byType(MlPageHeader);
    expect(header, findsOneWidget);
    expect(
        tester
            .widget<Text>(find.descendant(
                of: header, matching: find.text('Account deactivations')))
            .style
            ?.fontFamily,
        MlTokens.fontSerif);
    final card = find.ancestor(
        of: find.text('Sipho Dlamini'), matching: find.byType(MlCard));
    final cardRect = tester.getRect(card.first);
    final reject = tester.getRect(find.widgetWithText(MlButton, 'Reject').first);
    // The last control sits inside the card's 14px padding, flush right.
    expect(reject.right, closeTo(cardRect.right - 14, 1.5),
        reason: 'the action row is not right-aligned inside its card');
  });

  testWidgets('an available route puts its actions on the right of the title',
      (tester) async {
    // The actions rode inline after the title in one Wrap and Unassign sat
    // alone at the bottom left; the reference places a card's actions on
    // the right. Phase 3 pass, 2026-08-23. Geometry: the last action's
    // right edge is the card's content edge, and the title is not beside
    // it on the narrow layout.
    await pump(tester, const AvailableRoutesScreen(), width: 1600, height: 1600);
    final card = find
        .ancestor(of: find.text('RT-0042'), matching: find.byType(Container))
        .first;
    final cardRect = tester.getRect(card);
    final transit = tester.getRect(find.widgetWithText(MlButton, 'Transit 18 h'));
    // Unassign is the last control on an assigned route — in the action
    // row, not stranded below the card text.
    final unassign = tester.getRect(find.widgetWithText(MlButton, 'Unassign'));
    expect(unassign.right, closeTo(cardRect.right - 16, 1.5),
        reason: 'the actions are not right-aligned inside the card');
    expect(unassign.top, closeTo(transit.top, 1));
    final title = tester.getRect(find.text('RT-0042'));
    expect(title.top, closeTo(transit.top, 14),
        reason: 'at 1600px the title and the actions share the top row');
  });

  testWidgets('a driver-limit request puts its decision on the right',
      (tester) async {
    // Identity, timestamp, Approve / Decline and the status pill all rode
    // in one Wrap, so the decision floated mid-row wherever the text ended.
    // Phase 3 pass, 2026-08-23. Also the title: "Transporter driver
    // limits", not a capital D mid-label.
    await pump(tester, const DriverLimitRequestsScreen(),
        width: 1600, height: 1200);
    expect(find.text('Transporter driver limits'), findsOneWidget);
    final card = find
        .ancestor(of: find.text('Roadhaul Logistics'),
            matching: find.byType(Container))
        .first;
    final cardRect = tester.getRect(card);
    final decline = tester.getRect(find.widgetWithText(MlButton, 'Decline'));
    expect(decline.right, closeTo(cardRect.right - 16, 1.5),
        reason: 'the decision is not right-aligned inside its row');
    final badge = tester.getRect(find.text('APPROVED'));
    final badgeCard = tester.getRect(find
        .ancestor(of: find.text('Northline Carriers'),
            matching: find.byType(Container))
        .first);
    expect(badge.right, lessThan(badgeCard.right - 16 + 1.5));
    expect(badge.right, greaterThan(badgeCard.right - 40),
        reason: 'the status pill is not at the right edge of its row');
  });

  testWidgets('the company mirror speaks the reference type and tones',
      (tester) async {
    // Phase 3 pass, 2026-08-23. The mirror was transcribed from its own
    // mock before the reference was designated: a 32px sans ExtraBold
    // title, 16px sans ExtraBold card headings, a sky-blue interactive
    // accent beside the console's cyan, and a BUYER badge in that blue
    // where the reference's tone table says violet.
    await pump(tester, const SuperAdminCompanyMirrorScreen(companyId: 'o4'),
        width: 1600, height: 1800);
    Text textOf(String t) => tester.widget<Text>(find.text(t).first);
    expect(textOf('Consolidated Mineral Offtake & Logistics Holdings')
        .style?.fontFamily, MlTokens.fontSerif,
        reason: 'the page title is not in the display face');
    for (final h in ['Operational snapshot', 'Tons moved · last 7 days',
        'Fleet activity map']) {
      expect(textOf(h).style?.fontFamily, MlTokens.fontSerif,
          reason: '"$h" is not in the display face');
    }
    // The org badge: a Container whose border is the violet tone.
    final badge = tester.widget<Container>(find
        .ancestor(of: find.text('Buyer'), matching: find.byType(Container))
        .first);
    final deco = badge.decoration as BoxDecoration;
    expect(deco.border!.top.color.toARGB32() & 0xFFFFFF,
        MlControlRoom.violet.toARGB32() & 0xFFFFFF,
        reason: 'the BUYER badge is not violet');
  });

  testWidgets('platform users name the role in English', (tester) async {
    await pump(tester, const PlatformUsersScreen(), height: 2600);
    expectNoWireVocabulary(tester, 'the platform users list');
    expect(find.textContaining('Load Controller'), findsWidgets);
    expect(find.textContaining('Supervisor/Foreman'), findsWidgets);
  });

  testWidgets('and the platform-users title is the shared page header',
      (tester) async {
    // This screen set its title in 16px PlusJakartaSans ExtraBold by hand
    // while every other console screen opens in the Fraunces display face
    // through MlPageHeader — found 2026-08-23 in the Phase 3 pass against
    // the reference's section-header pattern. The header also carries the
    // count on the right, where the reference puts it.
    await pump(tester, const PlatformUsersScreen(), width: 1600, height: 1600);
    final header = find.byType(MlPageHeader);
    expect(header, findsOneWidget,
        reason: 'the title is hand-rolled again instead of MlPageHeader');
    final title = tester.widget<Text>(find.descendant(
        of: header, matching: find.text('Platform users')));
    expect(title.style?.fontFamily, MlTokens.fontSerif,
        reason: 'the page title is not in the display face');
    expect(tester.widget<MlPageHeader>(header).meta, matches(r'^\d+ users?$'),
        reason: 'the user count is missing from the header meta');
  });

  testWidgets('token history names the action in English, and no database key',
      (tester) async {
    await pump(tester, const TokenHistoryScreen(), height: 2600);
    // Open the group; every event lives inside it.
    await tester.tap(find.byType(ExpansionTile).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expectNoWireVocabulary(tester, 'the token history');
    // Sentence case since 2026-08-21, not title case. This assertion's job is
    // the one in the test's name — English rather than `TOKEN_GENERATED` — and
    // both forms satisfy it; the capitalisation changed because title-casing
    // every word also capitalised "To" and "Of" elsewhere in the same table
    // ("User Assigned To Seat"). See `AuditLog.labelForAction`.
    // The first tab is Transporters, and since 2026-08-23 the fixture only
    // hands a tab the events of its own org type — so this is Roadhaul's
    // seat assignment, not a mine's token (which used to sit here because
    // every fixture log shared one organizationId).
    expect(find.text('User assigned to seat'), findsWidgets,
        reason: 'the action type is being printed raw again.');
    expect(find.text('USER_ASSIGNED_TO_SEAT'), findsNothing);
    // `org o1` was the subtitle. A database key is not a fact about a company.
    for (final line in painted(tester)) {
      expect(line.contains('org o1'), isFalse,
          reason: 'the group caption is printing a database id: "$line".');
    }
  });

  testWidgets('and each token-history tab lists only its own org type',
      (tester) async {
    // The fixture used to give every log organizationId 'o1' and ignore the
    // org-type key, so the Transporters tab opened on "Iron Hills Mining ·
    // 9 events · Mine/Supplier" with Atlas Buyer Group's approval inside it.
    await pump(tester, const TokenHistoryScreen(), width: 1600, height: 1600);
    expect(find.text('Roadhaul Logistics'), findsOneWidget);
    expect(find.text('Iron Hills Mining'), findsNothing,
        reason: 'a mine is listed under the Transporters tab');
    expect(find.text('Mines / Suppliers'), findsOneWidget,
        reason: 'the tab spells the plural differently from the nav group');
  });

  testWidgets('and the token-history screen says what it is', (tester) async {
    await pump(tester, const TokenHistoryScreen(), width: 1600, height: 1200);
    expect(find.text('Token history'), findsOneWidget,
        reason: 'this screen opened straight onto a tab bar with no title, '
            'which no other console screen does.');
  });

  // ------------------------------------------------------- the org detail
  testWidgets('the organisation banner says what its number is',
      (tester) async {
    await pump(tester, const OrganizationDetailScreen(organizationId: 'o4'),
        width: 1600, height: 1800);
    expect(find.text('Status: Suspended'), findsOneWidget);
    expect(find.textContaining('Token expires in'), findsWidgets,
        reason: 'the countdown is the bare subtitle of a status banner again, '
            'so a suspended company reads "Status: Suspended / 308d 9h 9m 29s" '
            '— a figure in the position that explains the line above it, '
            'explaining nothing.');
  });

  testWidgets('and its section headings are the reference section title',
      (tester) async {
    // Company · Account owner · Seats · Access token · Chat connections were
    // PlusJakartaSans ExtraBold set by hand — the portal's pre-reference
    // heading — on a console screen whose neighbours head every section in
    // Fraunces through MlSectionTitle. Found 2026-08-23 in the Phase 3 pass.
    await pump(tester, const OrganizationDetailScreen(organizationId: 'o4'),
        width: 1600, height: 1800);
    for (final title in const [
      'Company',
      'Account owner (login)',
      'Seats',
      'Access token',
      'Chat connections',
    ]) {
      final heading = find.descendant(
          of: find.byType(MlSectionTitle), matching: find.text(title));
      expect(heading, findsOneWidget,
          reason: '"$title" is not an MlSectionTitle heading');
      expect(tester.widget<Text>(heading).style?.fontFamily,
          MlTokens.fontSerif,
          reason: '"$title" is not in the display face');
    }
  });

  testWidgets('and every key/value row shares one value column',
      (tester) async {
    // Two private _InfoRow copies — the screen's own and the shared token
    // widget's — had 160px and 168px label columns, so the value column
    // stepped 8px right between "Seats" and "Access token". Geometry, not
    // overflow: nothing threw.
    await pump(tester, const OrganizationDetailScreen(organizationId: 'o4'),
        width: 1600, height: 1800);
    double valueX(String value) =>
        tester.getTopLeft(find.text(value).first).dx;
    final company = valueX('Johannes Oosthuizen');
    expect(valueX('365 days'), closeTo(company, 0.5),
        reason: 'the Access token rows start their values at a different x '
            'from the Company rows');
  });

  testWidgets('and the countdown is not measured against the device clock',
      (tester) async {
    // The fixture token expires 314 days after `kCaptureNow`. Read off
    // `DateTime.now()` the figure moves every second and the golden could
    // never match twice; read off `MlTime.instant()` it is this, exactly.
    await pump(tester, const OrganizationDetailScreen(organizationId: 'o4'),
        width: 1600, height: 1800);
    expect(find.textContaining('314 days'), findsWidgets,
        reason: 'the token countdown is not being measured from the frozen '
            'clock, so it cannot be photographed and it is the device\'s '
            'opinion of the hour (CLAUDE.md §7.1).');
  });
}
