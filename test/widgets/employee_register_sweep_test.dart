// Layout + behaviour sweep for the shared Employee Register (P7-27…P7-35).
//
// The register is the first screen promoted out of the super-admin console into
// the portal, so it is the first one that has to survive BOTH chromes: the
// console's fixed navy palette and the portal's light and dark themes, at every
// width and every text scale a user can set.
//
// It is also densely packed with the two shapes CLAUDE.md §10.4 names as the
// repeat offenders — `Wrap`s of chips inside `Row`s, and a four-cell stat strip
// with fixed dividers — so the sweep is not decorative.
//
// ⚠ The fonts are loaded for real. `flutter test` otherwise renders in a
// fallback font where **every glyph is one em wide**, which both invents
// overflows that do not exist and hides ones that do (CLAUDE.md §7).

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FontLoader;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/core/design/tokens/ml_tokens.dart';
import 'package:flutter_application_1/features/auth/models/user_type.dart';
import 'package:flutter_application_1/features/chat/providers/chat_presence_provider.dart';
import 'package:flutter_application_1/features/company/models/company_model.dart';
import 'package:flutter_application_1/features/company/screens/employee_register_screen.dart';
import 'package:flutter_application_1/features/company/services/employee_register_service.dart';
import 'package:flutter_application_1/features/employee/models/employee_model.dart';
import 'package:flutter_application_1/features/profile_setup/models/profile_setup.dart';
import 'package:flutter_application_1/features/profile_setup/providers/profile_setup_provider.dart';

Future<void> _loadFont(String family, List<String> files) async {
  final loader = FontLoader(family);
  var loaded = false;
  for (final f in files) {
    final file = File('assets/fonts/$f');
    if (!file.existsSync()) continue;
    loaded = true;
    loader.addFont(file.readAsBytes().then((b) => ByteData.sublistView(b)));
  }
  if (loaded) await loader.load();
}

const _widths = <double>[1600, 1280, 1024, 430];
const _scales = <double>[0.85, 1.0, 1.15, 1.3];

final _now = DateTime(2026, 8, 11, 9);

Company _company(OrgType orgType) => Company(
      id: 'c0000000-0000-4000-8000-000000000001',
      userId: 'u0000000-0000-4000-8000-000000000001',
      companyName: 'Iron Hills Mining Proprietary Limited',
      whatsappNumber: '+27 82 000 0000',
      orgType: orgType,
      createdAt: DateTime(2024, 1, 1),
    );

Employee _employee({
  required String id,
  required String userId,
  required String first,
  required String last,
  UserRole? role,
  bool dismissed = false,
  String? status,
  String? licenseUrl,
}) =>
    Employee(
      id: id,
      userId: userId,
      firstName: first,
      lastName: last,
      whatsappNumber: '+27 82 555 0101',
      companyId: 'c0000000-0000-4000-8000-000000000001',
      role: role,
      status: status,
      createdAt: DateTime(2024, 6, 1),
      isDismissed: dismissed,
      licenseDocumentUrl: licenseUrl,
    );

/// One member per role bucket, plus the worst cases the card can hold: a very
/// long name, a member whose `is_dismissed` column is true (which must now
/// render exactly like any other member — the feature is gone, the column is
/// not), a member with no signature (P7-35) and one whose presence never
/// resolved.
List<RegisterMember> _members() {
  final e = <(Employee, MemberPresence?)>[
    (
      _employee(
        id: 'e0000000-0000-4000-8000-000000000001',
        userId: 'u0000000-0000-4000-8000-000000000001',
        first: 'Nomvula',
        last: 'Mthembu-Vandenberghe',
        role: UserRole.admin,
      ),
      MemberPresence(
        userId: 'u0000000-0000-4000-8000-000000000001',
        lastSeenAt: _now,
        hasSignature: true,
      ),
    ),
    (
      _employee(
        id: 'e0000000-0000-4000-8000-000000000002',
        userId: 'u0000000-0000-4000-8000-000000000002',
        first: 'Sipho',
        last: 'Radebe',
        role: UserRole.management,
        status: 'pending',
      ),
      MemberPresence(
        userId: 'u0000000-0000-4000-8000-000000000002',
        lastSeenAt: null,
        hasSignature: false,
      ),
    ),
    (
      _employee(
        id: 'e0000000-0000-4000-8000-000000000003',
        userId: 'u0000000-0000-4000-8000-000000000003',
        first: 'Johannes',
        last: 'van der Merwe',
        role: UserRole.supervisorForeman,
      ),
      MemberPresence(
        userId: 'u0000000-0000-4000-8000-000000000003',
        lastSeenAt: null,
        hasSignature: false,
      ),
    ),
    (
      _employee(
        id: 'e0000000-0000-4000-8000-000000000004',
        userId: 'u0000000-0000-4000-8000-000000000004',
        first: 'Thandeka',
        last: 'Nkosi',
        role: UserRole.controllerWB,
      ),
      null, // presence unresolved — must render neither "on file" nor "missing"
    ),
    (
      _employee(
        id: 'e0000000-0000-4000-8000-000000000005',
        userId: 'u0000000-0000-4000-8000-000000000005',
        first: 'Pieter',
        last: 'Botha',
        role: UserRole.security,
      ),
      MemberPresence(
        userId: 'u0000000-0000-4000-8000-000000000005',
        lastSeenAt: null,
        hasSignature: true,
      ),
    ),
    (
      _employee(
        id: 'e0000000-0000-4000-8000-000000000006',
        userId: 'u0000000-0000-4000-8000-000000000006',
        first: 'Lungile',
        last: 'Mahlangu',
        role: UserRole.driver,
        licenseUrl: 'https://example.invalid/licence.pdf',
      ),
      MemberPresence(
        userId: 'u0000000-0000-4000-8000-000000000006',
        lastSeenAt: null,
        hasSignature: false,
      ),
    ),
    (
      _employee(
        id: 'e0000000-0000-4000-8000-000000000007',
        userId: 'u0000000-0000-4000-8000-000000000007',
        first: 'Refilwe',
        last: 'Sekhukhune-Modiselle',
        role: UserRole.driver,
        // `employees.is_dismissed` survives the dismissal-feature removal --
        // 19 functions read it, including `is_company_staff` -- so the register
        // must still render such a member NORMALLY, with no special chip. That
        // property is owned by `portal_workspace_removed_employee_test.dart`,
        // which scans lib/ and test/ for any dismissal surface; duplicating it
        // here would only add noise to its offender list.
        dismissed: true,
      ),
      MemberPresence(
        userId: 'u0000000-0000-4000-8000-000000000007',
        lastSeenAt: null,
        hasSignature: false,
      ),
    ),
    (
      _employee(
        id: 'e0000000-0000-4000-8000-000000000008',
        userId: 'u0000000-0000-4000-8000-000000000008',
        first: 'Unassigned',
        last: 'Employee',
      ),
      null,
    ),
  ];
  return [for (final (emp, pres) in e) RegisterMember(emp, pres)];
}

/// KPIs on every group, including the `null` percentage that must render as a
/// muted dash rather than 0%.
RegisterKpiBundle _kpis() => RegisterKpiBundle(
      const {
        RegisterRoleGroups.admins: RegisterKpi(
          'RECONS CLOSED',
          42,
          '3 reconciliation disputes open',
        ),
        RegisterRoleGroups.supervisors: RegisterKpi(
          'STOCKPILES UPDATED',
          null,
          'no stockpiles with product',
        ),
        RegisterRoleGroups.loadControllers: RegisterKpi(
          'LOADS RECORDED',
          88,
          '1 truck arrived, load not recorded',
        ),
        RegisterRoleGroups.security: RegisterKpi(
          'ARRIVALS CLOSED OUT',
          61,
          '4 trucks arrived, not marked left',
        ),
        RegisterRoleGroups.drivers: RegisterKpi(
          'PODS UPLOADED',
          100,
          '0 trips missing POD',
        ),
      },
      [
        RegisterComplianceDoc(
          ownerType: 'employee',
          ownerId: 'e0000000-0000-4000-8000-000000000006',
          docType: 'drivers_licence',
          expiresAt: _now.add(const Duration(days: 12)),
        ),
        RegisterComplianceDoc(
          ownerType: 'company',
          ownerId: null,
          docType: 'mining_right',
          expiresAt: _now.add(const Duration(days: 5)),
        ),
      ],
    );

ProfileSetup _setup({
  required int percent,
  int missing = 0,
  int expiring = 0,
  int expired = 0,
  String? audience = 'employee',
}) =>
    ProfileSetup(
      audience: audience,
      items: const [],
      summary: ProfileSetupSummary(
        totalItems: 10,
        completeItems: percent ~/ 10,
        requiredTotal: 5,
        requiredComplete: 5 - missing,
        completionPercent: percent,
        missingRequired: [for (var i = 0; i < missing; i++) 'item_$i'],
        missingCount: missing,
        expiringCount: expiring,
        expiredCount: expired,
      ),
    );

/// One state per member, so the chip's whole vocabulary is on screen at once:
/// finished, part-finished, expired, renewals-due, and the two cases that must
/// print NOTHING rather than guess — an account with no setup to complete, and
/// a read the server refused.
///
/// Every percentage is distinct on purpose: it makes each chip findable by its
/// own label, so a colour assertion can name the member it belongs to.
final _setupOverrides = <Override>[
  employeeProfileSetupProvider('e0000000-0000-4000-8000-000000000001')
      .overrideWith((ref) async => _setup(percent: 100)),
  employeeProfileSetupProvider('e0000000-0000-4000-8000-000000000002')
      .overrideWith((ref) async => _setup(percent: 40, missing: 3)),
  employeeProfileSetupProvider('e0000000-0000-4000-8000-000000000003')
      .overrideWith((ref) async => _setup(percent: 80, expired: 1)),
  employeeProfileSetupProvider('e0000000-0000-4000-8000-000000000004')
      .overrideWith((ref) async => _setup(percent: 90, expiring: 2)),
  employeeProfileSetupProvider('e0000000-0000-4000-8000-000000000005')
      .overrideWith((ref) async => _setup(percent: 0, missing: 5)),
  employeeProfileSetupProvider('e0000000-0000-4000-8000-000000000006')
      .overrideWith((ref) async => _setup(percent: 60, missing: 2)),
  // No employee/company profile behind the account — nothing to complete, so
  // no chip. `completion_percent` is 100 in that payload and printing it would
  // credit the member with a setup they were never asked to do.
  employeeProfileSetupProvider('e0000000-0000-4000-8000-000000000007')
      .overrideWith((ref) async => _setup(percent: 100, audience: null)),
  // What `get_profile_setup` raises for a caller it will not answer. The row
  // must survive it; only the chip is lost.
  employeeProfileSetupProvider('e0000000-0000-4000-8000-000000000008')
      .overrideWith((ref) async => throw Exception('Not authorized')),
];

/// One member online, one seen 10 minutes ago (Away), the rest Offline — so
/// all three presence states render in every sweep.
final _presenceOverrides = <Override>[
  onlineUsersProvider.overrideWithValue(
    const {'u0000000-0000-4000-8000-000000000001'},
  ),
  presenceLastSeenProvider.overrideWithValue({
    'u0000000-0000-4000-8000-000000000003':
        DateTime.now().subtract(const Duration(minutes: 10)),
  }),
];

const _consoleNavy = MlSemantic.custom(
  surfaceApp: Color(0xFF0A101D),
  surfaceCard: Color(0xFF0D1526),
  surfaceRaised: Color(0x0AFFFFFF),
  surfaceSunken: Color(0xFF080D18),
  textStrong: Color(0xFFF1F5F9),
  textBody: Color(0xFFCBD5E1),
  textMuted: Color(0xFF7E8CA6),
  textFaint: Color(0xFF5D6D8C),
  borderSubtle: Color(0x1494A3B8),
  borderCard: Color(0x1F94A3B8),
  borderStrong: Color(0x3D94A3B8),
  borderAccent: Color(0x6B00B5D8),
  divider: Color(0x1F94A3B8),
);

List<Override> _overrides(Company company) => [
      // Presence talks to a live realtime channel; without these the screen
      // throws on `Supabase.instance` and every assertion below would be made
      // against an error state.
      ..._presenceOverrides,
      // Without these every card's setup read reaches the real service, whose
      // client field throws on an uninitialised Supabase — the chip would be
      // absent from every sweep and the layout it adds would go unswept.
      ..._setupOverrides,
      companyRegisterProvider(company.id).overrideWith((ref) async =>
          _members()),
      companyDriverTrucksProvider(company.id).overrideWith((ref) async => {
            'e0000000-0000-4000-8000-000000000006': 'CA 123-456 GP',
          }),
      companyRegisterKpisProvider((id: company.id, org: company.orgType))
          .overrideWith((ref) async => _kpis()),
    ];

void main() {
  setUpAll(() async {
    await _loadFont('PlusJakartaSans', [
      'PlusJakartaSans-Regular.ttf',
      'PlusJakartaSans-Medium.ttf',
      'PlusJakartaSans-SemiBold.ttf',
      'PlusJakartaSans-Bold.ttf',
      'PlusJakartaSans-ExtraBold.ttf',
    ]);
    await _loadFont('JetBrainsMono', [
      'JetBrainsMono-Regular.ttf',
      'JetBrainsMono-Medium.ttf',
      'JetBrainsMono-Bold.ttf',
    ]);
    await _loadFont('Fraunces', [
      'Fraunces-Medium.ttf',
      'Fraunces-MediumItalic.ttf',
      'Fraunces-SemiBold.ttf',
    ]);
  });

  Future<void> pumpRegister(
    WidgetTester tester, {
    required Company company,
    required Brightness brightness,
    required bool embedded,
    MlSemantic? palette,
    double scale = 1.0,
    bool boldText = false,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: _overrides(company),
        child: MaterialApp(
          theme: ThemeData(brightness: brightness),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(scale),
              boldText: boldText,
            ),
            child: child!,
          ),
          home: embedded
              ? Scaffold(
                  body: EmployeeRegisterScreen(
                    company: company,
                    embedded: true,
                  ),
                )
              : EmployeeRegisterScreen(
                  company: company,
                  palette: palette,
                  brightness: palette == null ? null : Brightness.dark,
                ),
        ),
      ),
    );
    await tester.pump(); // resolve the overridden futures
    await tester.pump(const Duration(milliseconds: 400));
  }

  Future<void> sweep(
    WidgetTester tester, {
    required Company company,
    required Brightness brightness,
    required bool embedded,
    MlSemantic? palette,
    bool boldText = false,
  }) async {
    for (final width in _widths) {
      for (final scale in _scales) {
        tester.view.physicalSize = Size(width, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        // The full FlutterErrorDetails, not `takeException()` — the latter
        // drops the "relevant error-causing widget" line, the only part that
        // says where to fix it.
        final captured = <FlutterErrorDetails>[];
        final previousOnError = FlutterError.onError;
        FlutterError.onError = captured.add;

        await pumpRegister(
          tester,
          company: company,
          brightness: brightness,
          embedded: embedded,
          palette: palette,
          scale: scale,
          boldText: boldText,
        );

        FlutterError.onError = previousOnError;
        tester.takeException();

        final faults = captured.where((d) {
          final s = d.exception.toString();
          return s.contains('overflowed') ||
              s.contains('forces an infinite') ||
              s.contains('BoxConstraints');
        }).toList();

        expect(
          faults,
          isEmpty,
          reason: '${company.orgType.name} register '
              '(${embedded ? 'portal' : 'console'}, ${brightness.name}) at '
              '${width.toInt()}px × $scale${boldText ? ' bold' : ''}: '
              '${faults.map((f) => f.exception).join('; ')}',
        );

        // A clean sweep over an error state or an empty fixture proves
        // nothing (CLAUDE.md §10.5). Assert the register actually rendered.
        expect(
          find.text('TOTAL STAFF'),
          findsOneWidget,
          reason: 'register did not render its data at '
              '${width.toInt()}px × $scale',
        );
      }
    }
  }

  for (final orgType in OrgType.values) {
    testWidgets('${orgType.name} — portal register survives width × text scale '
        '(dark)', (tester) async {
      await sweep(
        tester,
        company: _company(orgType),
        brightness: Brightness.dark,
        embedded: true,
      );
    });

    testWidgets('${orgType.name} — portal register survives width × text scale '
        '(light)', (tester) async {
      await sweep(
        tester,
        company: _company(orgType),
        brightness: Brightness.light,
        embedded: true,
      );
    });
  }

  testWidgets('portal register survives bold text', (tester) async {
    await sweep(
      tester,
      company: _company(OrgType.mineSupplier),
      brightness: Brightness.light,
      embedded: true,
      boldText: true,
    );
  });

  testWidgets('console register survives width × text scale on its own navy',
      (tester) async {
    await sweep(
      tester,
      company: _company(OrgType.mineSupplier),
      brightness: Brightness.dark,
      embedded: false,
      palette: _consoleNavy,
    );
  });

  // -------------------------------------------------------------------------
  // What the screen must actually SAY — a green layout sweep over a screen that
  // renders the wrong thing proves nothing.
  // -------------------------------------------------------------------------

  testWidgets('renders every role group and its live KPI', (tester) async {
    tester.view.physicalSize = const Size(1600, 3600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await pumpRegister(
      tester,
      company: _company(OrgType.mineSupplier),
      brightness: Brightness.dark,
      embedded: true,
    );

    for (final title in [
      RegisterRoleGroups.admins,
      RegisterRoleGroups.supervisors,
      RegisterRoleGroups.loadControllers,
      RegisterRoleGroups.security,
      RegisterRoleGroups.drivers,
      'Other roles',
    ]) {
      expect(find.text(title), findsOneWidget, reason: title);
    }

    // A KPI with nothing to count renders a muted dash, never 0%.
    expect(find.text('—'), findsOneWidget);
    expect(find.text('42%'), findsOneWidget);
    expect(find.text('no stockpiles with product'), findsOneWidget);
  });

  testWidgets('P7-35 — signature state is present, missing, or silent',
      (tester) async {
    tester.view.physicalSize = const Size(1600, 3600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await pumpRegister(
      tester,
      company: _company(OrgType.mineSupplier),
      brightness: Brightness.dark,
      embedded: true,
    );

    // 2 of the 8 fixtures have one, 4 do not, and 2 have no presence row at
    // all — those two must claim neither, because "we could not look" is not
    // the same as "they have not signed".
    expect(find.text('Signature on file'), findsNWidgets(2));
    expect(find.text('No signature'), findsNWidgets(4));
  });

  testWidgets('every member carries their OWN setup figure, or none at all',
      (tester) async {
    tester.view.physicalSize = const Size(1600, 3600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await pumpRegister(
      tester,
      company: _company(OrgType.mineSupplier),
      brightness: Brightness.dark,
      embedded: true,
    );

    // Per-person, not per-viewer: six members, six different numbers. One
    // figure repeated across the register would mean the card is rendering
    // whoever is signed in.
    for (final label in [
      'Setup 100%',
      'Setup 90%',
      'Setup 80%',
      'Setup 60%',
      'Setup 40%',
      'Setup 0%',
    ]) {
      expect(find.text(label), findsOneWidget, reason: label);
    }

    // 8 fixtures, 6 chips: the account with nothing to complete and the one
    // whose read was refused print nothing rather than a number nobody can
    // stand behind.
    expect(find.textContaining('Setup '), findsNWidgets(6));

    Color colourOf(String label) =>
        tester.widget<Text>(find.text(label)).style!.color!;

    const dark = Brightness.dark;
    expect(colourOf('Setup 100%'), MlTone.done.colors(dark).fg,
        reason: 'finished reads green');
    expect(colourOf('Setup 80%'), MlTone.error.colors(dark).fg,
        reason: 'an expired document reads red even at 80%');
    expect(colourOf('Setup 40%'), MlTone.atMine.colors(dark).fg,
        reason: 'required items still missing reads amber');
    expect(colourOf('Setup 90%'), MlTone.atMine.colors(dark).fg,
        reason: 'renewals due reads amber, not green');
  });

  testWidgets('a presence denial fails the register instead of rendering it '
      'offline', (tester) async {
    tester.view.physicalSize = const Size(1600, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final company = _company(OrgType.buyer);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ..._presenceOverrides,
          // What `list_company_member_presence` raises for a non-manager.
          companyRegisterProvider(company.id).overrideWith(
            (ref) async => throw Exception(
              'not authorised to read member presence for company ${company.id}',
            ),
          ),
          companyDriverTrucksProvider(company.id)
              .overrideWith((ref) async => const <String, String>{}),
          companyRegisterKpisProvider((id: company.id, org: company.orgType))
              .overrideWith((ref) async => _kpis()),
        ],
        child: MaterialApp(
          theme: ThemeData(brightness: ThemeData.dark().brightness),
          home: Scaffold(
            body: EmployeeRegisterScreen(company: company, embedded: true),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Could not load the employee register'), findsOneWidget);
    expect(find.text('TOTAL STAFF'), findsNothing);
  });
}
