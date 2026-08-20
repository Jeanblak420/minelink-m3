// Fixtures that get a gated screen far enough to render something.
//
// Several screens short-circuit before they lay anything out: a company gate, a
// null session, a workspace that has not reached `ready`. A sweep over one of
// those passes at every width and every text scale having rendered a spinner,
// which is the trap CLAUDE.md §10.5 names — and it is not hypothetical here:
// measured 2026-08-20, EIGHT of nineteen screens painted fewer than three text
// runs and four painted nothing at all.
//
// Everything here is obviously fake — 'FIXTURE-' ids, a 2020 timestamp — so a
// figure from this file could never be mistaken for real data if one leaked
// into a render. Nothing here is a mock in the behavioural sense: these are
// values, and the screens run their real logic over them.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import 'package:flutter_application_1/features/auth/models/user_type.dart';
import 'package:flutter_application_1/features/auth/providers/auth_state.dart';
import 'package:flutter_application_1/features/auth/services/auth_service.dart';
import 'package:flutter_application_1/features/auth/services/device_verification_store.dart';
import 'package:flutter_application_1/features/company/models/company_model.dart';
import 'package:flutter_application_1/features/company/providers/company_access_provider.dart';
import 'package:flutter_application_1/features/company/providers/company_provider.dart';
import 'package:flutter_application_1/features/company/services/company_database_service.dart';
import 'package:flutter_application_1/features/company/services/company_service.dart';
import 'package:flutter_application_1/features/employee/models/employee_model.dart';
import 'package:flutter_application_1/features/employee/providers/employee_provider.dart';
import 'package:flutter_application_1/features/employee/services/employee_service.dart';
import 'package:flutter_application_1/features/notifications/services/notification_service.dart';
import 'package:flutter_application_1/features/portal/portal_navigation.dart';
import 'package:flutter_application_1/features/portal/providers/portal_workspace_provider.dart';
import 'package:flutter_application_1/features/profile/providers/account_email_provider.dart';
import 'package:flutter_application_1/features/profile_setup/models/profile_setup.dart';
import 'package:flutter_application_1/features/profile_setup/providers/profile_setup_provider.dart';

final DateTime _fixtureDate = DateTime.utc(2020, 1, 1);

/// A transporter, because that org type unlocks the most tabs and therefore the
/// widest layouts — the ones most likely to overflow.
Company fixtureCompany() => Company(
      id: 'FIXTURE-company',
      userId: 'FIXTURE-user',
      companyName: 'Fixture Haulage (Pty) Ltd',
      whatsappNumber: '+27000000000',
      orgType: OrgType.transporter,
      createdAt: _fixtureDate,
      physicalAddress: '1 Fixture Road, Fixtureville, Gauteng',
    );

Employee fixtureEmployee({
  UserRole role = UserRole.admin,
  String id = 'FIXTURE-employee',
  String firstName = 'Fixture',
  String lastName = 'Operator',
}) =>
    Employee(
      id: id,
      userId: 'FIXTURE-user',
      firstName: firstName,
      lastName: lastName,
      whatsappNumber: '+27000000000',
      companyId: 'FIXTURE-company',
      role: role,
      status: 'active',
      createdAt: _fixtureDate,
    );

/// A small roster, so a screen that lists employees lays out more than one row.
List<Employee> fixtureRoster() => [
      fixtureEmployee(),
      fixtureEmployee(
          id: 'FIXTURE-employee-2',
          firstName: 'Second',
          lastName: 'Driver',
          role: UserRole.driver),
      fixtureEmployee(
          id: 'FIXTURE-employee-3',
          firstName: 'Third',
          lastName: 'Controller',
          role: UserRole.controllerWB),
    ];

// ---------------------------------------------------------------------------
// The two notifiers everything else is gated behind
// ---------------------------------------------------------------------------

/// A [CompanyNotifier] whose state cannot be cleared.
///
/// ## Why a subclass and not a value override
///
/// `companyProvider` is a `StateNotifierProvider<CompanyNotifier, CompanyState>`,
/// so an override has to return a `CompanyNotifier` — a different class will
/// not type-check, and there is no `overrideWithValue` for the state itself.
///
/// ## Why the state has to be PINNED
///
/// `CompanyNotifier`'s constructor registers an auth listener with
/// `fireImmediately: true`. That callback runs SYNCHRONOUSLY inside the super
/// constructor, before this subclass's body, and with no session it takes the
/// `user == null` branch straight to `clearContext()` — which sets
/// `CompanyState()`. So the order is: super clears, this body sets the fixture,
/// and anything later must not undo it. `_pinned` is what makes the last part
/// true; without it a late auth event would wipe the fixture mid-test and the
/// failure would look like a flake.
class FixtureCompanyNotifier extends CompanyNotifier {
  FixtureCompanyNotifier(
    super.companyService,
    super.companyDatabaseService,
    super.notificationService,
    super.authStateNotifier, {
    required CompanyState fixture,
  }) {
    state = fixture;
    _pinned = true;
  }

  bool _pinned = false;

  @override
  set state(CompanyState value) {
    if (_pinned) return;
    super.state = value;
  }
}

/// An [EmployeeNotifier] whose state cannot be cleared — same reasoning as
/// [FixtureCompanyNotifier], except that `EmployeeNotifier` assigns
/// `EmployeeState()` inline rather than through a `clearContext()` method, so
/// there is nothing to override but the setter.
class FixtureEmployeeNotifier extends EmployeeNotifier {
  FixtureEmployeeNotifier(
    super.employeeService,
    super.companyService,
    super.authStateNotifier, {
    required EmployeeState fixture,
  }) {
    state = fixture;
    _pinned = true;
  }

  bool _pinned = false;

  @override
  set state(EmployeeState value) {
    if (_pinned) return;
    super.state = value;
  }
}

/// An [AuthStateNotifier] whose state cannot be cleared.
///
/// Same pinning as the two above, and needed for the same reason: its
/// constructor calls `_initialize()`, which subscribes to
/// `onAuthStateChange` and will push a signed-out state over the fixture the
/// moment the dummy Supabase instance reports one.
class FixtureAuthStateNotifier extends AuthStateNotifier {
  FixtureAuthStateNotifier(
    super.authService,
    super.deviceStore, {
    super.ref,
    required AuthState fixture,
  }) {
    state = fixture;
    _pinned = true;
  }

  bool _pinned = false;

  @override
  set state(AuthState value) {
    if (_pinned) return;
    super.state = value;
  }
}

/// A signed-in gotrue [supabase.User].
///
/// `operations_hub` and `communications_hub` both short-circuit to a spinner
/// on `authState.user == null`, so nothing downstream of that gate had ever
/// been laid out — including the whole operations tab set, which is the part
/// of the product a weighbridge controller spends the day in.
supabase.User fixtureUser() => supabase.User(
      id: 'FIXTURE-user',
      appMetadata: const {},
      userMetadata: const {},
      aud: 'authenticated',
      email: 'operator@fixture.co.za',
      createdAt: _fixtureDate.toIso8601String(),
      role: 'authenticated',
    );

/// The auth gate. [userType] decides which branch the company/employee
/// notifiers' own auth handlers would take, so it is kept consistent with
/// whichever of [companyOverride] / [employeeOverride] is in play.
Override authOverride({UserType userType = UserType.company}) {
  return authStateProvider.overrideWith((ref) => FixtureAuthStateNotifier(
        ref.watch(authServiceProvider),
        ref.watch(deviceVerificationStoreProvider),
        ref: ref,
        fixture: AuthState(user: fixtureUser(), userType: userType),
      ));
}

/// The company gate: a company, its roster, and whether this user manages it.
///
/// [canManageEmployees] selects which branch of `CompanyEmployeesScreen`
/// renders, and **both are real user-facing states**: managers get the roster,
/// everyone else gets the restricted notice.
Override companyOverride({bool canManageEmployees = true}) {
  return companyProvider.overrideWith((ref) => FixtureCompanyNotifier(
        ref.watch(companyServiceProvider),
        ref.watch(companyDatabaseServiceProvider),
        ref.watch(notificationServiceProvider),
        ref.watch(authStateProvider.notifier),
        fixture: CompanyState(
          company: fixtureCompany(),
          employees: fixtureRoster(),
          canManageEmployees: canManageEmployees,
        ),
      ));
}

/// The employee gate. `fleet_management` resolves its company id from EITHER
/// this or [companyOverride], so both are supplied wherever it matters.
Override employeeOverride({UserRole role = UserRole.admin}) {
  return employeeProvider.overrideWith((ref) => FixtureEmployeeNotifier(
        ref.watch(employeeServiceProvider),
        ref.watch(companyServiceProvider),
        ref.watch(authStateProvider.notifier),
        fixture: EmployeeState(
          employee: fixtureEmployee(role: role),
          company: fixtureCompany(),
        ),
      ));
}

/// `companyAccessProvider` is a plain `Provider`, so it can simply be handed a
/// value.
Override companyAccessOverride({bool canManageEmployees = true}) {
  return companyAccessProvider.overrideWithValue(
    CompanyAccessContext(
      company: fixtureCompany(),
      visibleEmployees: fixtureRoster(),
      currentEmployee: fixtureEmployee(),
      isCompanyAccount: true,
      canManageEmployees: canManageEmployees,
    ),
  );
}

/// `portalWorkspaceProvider` is a plain `Provider` too.
///
/// The tab bodies are placeholders rather than the real screens: those have
/// their own sweeps, and nesting them here would mean this fixture's failures
/// were really theirs.
Override portalWorkspaceOverride() {
  return portalWorkspaceProvider.overrideWithValue(
    const PortalWorkspaceModel(
      phase: PortalWorkspacePhase.ready,
      workspaceName: 'Fixture Haulage (Pty) Ltd',
      operatorName: 'Fixture Operator',
      roleLabel: 'Admin',
      tabs: [
        PortalTabItem('Overview', Icons.dashboard_outlined,
            Center(child: Text('Overview tab body'))),
        PortalTabItem('Earnings', Icons.payments_outlined,
            Center(child: Text('Earnings tab body'))),
        PortalTabItem('Fleet', Icons.local_shipping_outlined,
            Center(child: Text('Fleet tab body'))),
      ],
    ),
  );
}

/// The signed-in account's email.
///
/// This override only became possible when `AccountSecurityScreen` stopped
/// reading `SupabaseConfig.client.auth.currentUser` inside its own `build` —
/// see `accountEmailProvider`. A widget that reaches into a global singleton
/// cannot be handed a different answer, which is why that screen rendered one
/// error line in every test while its sweep reported it green at every width.
Override accountEmailOverride({String? email = 'operator@fixture.co.za'}) =>
    accountEmailProvider.overrideWithValue(email);

/// A profile-setup state with something in every category, so the screen lays
/// out its list, its progress and its per-item states rather than an empty
/// shell.
///
/// The mix is deliberate: one complete, one missing, one expiring. A fixture
/// where everything is complete renders the shortest possible screen, which is
/// the one least likely to overflow — and therefore the least useful one to
/// sweep.
Override profileSetupOverride() {
  ProfileSetupItem item(
    String key,
    String label,
    SetupCategory category,
    SetupItemKind kind,
    SetupItemStatus status, {
    bool required = true,
    int order = 0,
    DateTime? expiresAt,
    int? daysToExpiry,
  }) =>
      ProfileSetupItem(
        itemKey: key,
        label: label,
        description: 'Fixture item for $label',
        category: category,
        kind: kind,
        isRequired: required,
        requiresExpiry: expiresAt != null,
        requiresFile: kind == SetupItemKind.document,
        sortOrder: order,
        status: status,
        filePresent: status == SetupItemStatus.complete,
        expiresAt: expiresAt,
        daysToExpiry: daysToExpiry,
      );

  final items = <ProfileSetupItem>[
    item('full_name', 'Full name', SetupCategory.personal, SetupItemKind.field,
        SetupItemStatus.complete, order: 1),
    item('id_document', 'ID document', SetupCategory.identity,
        SetupItemKind.document, SetupItemStatus.missing, order: 2),
    item('signature', 'Signature', SetupCategory.identity,
        SetupItemKind.signature, SetupItemStatus.complete, order: 3),
    item('medical', 'Medical certificate', SetupCategory.medical,
        SetupItemKind.document, SetupItemStatus.expiring,
        order: 4,
        expiresAt: DateTime.utc(2020, 3, 1),
        daysToExpiry: 12),
    item('licence', 'Driving licence', SetupCategory.licences,
        SetupItemKind.document, SetupItemStatus.expired,
        order: 5, expiresAt: DateTime.utc(2020, 1, 15), daysToExpiry: -4),
    item('hazmat', 'Hazmat certificate', SetupCategory.certifications,
        SetupItemKind.document, SetupItemStatus.missing,
        required: false, order: 6),
  ];

  final missing = items
      .where((i) => i.isRequired && i.status != SetupItemStatus.complete)
      .map((i) => i.label)
      .toList();

  return myProfileSetupProvider.overrideWith((ref) async => ProfileSetup(
        audience: 'employee',
        subjectId: 'FIXTURE-employee',
        orgType: 'transporter',
        role: 'driver',
        companyId: 'FIXTURE-company',
        isSaCitizen: true,
        items: items,
        summary: ProfileSetupSummary(
          totalItems: items.length,
          completeItems:
              items.where((i) => i.status == SetupItemStatus.complete).length,
          requiredTotal: items.where((i) => i.isRequired).length,
          requiredComplete: items
              .where((i) => i.isRequired && i.status == SetupItemStatus.complete)
              .length,
          completionPercent: 40,
          missingRequired: missing,
          missingCount: missing.length,
          expiringCount:
              items.where((i) => i.status == SetupItemStatus.expiring).length,
          expiredCount:
              items.where((i) => i.status == SetupItemStatus.expired).length,
        ),
      ));
}

/// Everything a company-side screen needs to get past its gates.
///
/// Screens differ in which gate they hit first — `fleet_management` resolves a
/// company id from either notifier, `operations_hub` and `communications_hub`
/// read both plus the auth state — so handing over the whole set is both
/// simpler and closer to what a signed-in user actually has.
List<Override> companyScopeOverrides({
  bool canManageEmployees = true,
  UserRole role = UserRole.admin,
}) =>
    [
      authOverride(),
      companyOverride(canManageEmployees: canManageEmployees),
      employeeOverride(role: role),
      companyAccessOverride(canManageEmployees: canManageEmployees),
    ];
