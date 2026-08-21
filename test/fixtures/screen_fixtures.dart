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
import 'package:flutter_application_1/features/company/models/company_directory_entry.dart';
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
import 'package:flutter_application_1/features/fleet/models/fleet_vehicle_model.dart';
import 'package:flutter_application_1/features/fleet/providers/fleet_provider.dart';
import 'package:flutter_application_1/features/notifications/services/notification_service.dart';
import 'package:flutter_application_1/features/chat/providers/communications_provider.dart';
import 'package:flutter_application_1/features/operations/models/operations_models.dart';
import 'package:flutter_application_1/features/operations/providers/operations_provider.dart';
import 'package:flutter_application_1/features/portal/portal_navigation.dart';
import 'package:flutter_application_1/features/portal/providers/portal_workspace_provider.dart';
import 'package:flutter_application_1/features/profile/providers/account_email_provider.dart';
import 'package:flutter_application_1/features/profile_setup/models/profile_setup.dart';
import 'package:flutter_application_1/features/profile_setup/providers/profile_setup_provider.dart';

/// The date this fixture company and its people were registered.
///
/// 2024, not 2020-01-01. It is DISPLAYED — the company profile's "Created At"
/// row shows it in a card, and a platform whose today is August 2026 showing a
/// company created "01 Jan 2020 · 02:00" reads as an epoch default rather than
/// a registration. A believable date costs nothing and stops the picture
/// lying.
final DateTime _fixtureDate = DateTime.utc(2024, 3, 18, 7, 40);

/// A transporter by default, because that org type unlocks the most tabs and
/// therefore the widest layouts — the ones most likely to overflow.
///
/// [orgType] is a parameter because the mine-floor screens (Security's gate, the
/// Load Controller's weighbridge) belong to a MINE, and a render whose rail says
/// "Iron Hills Mining" while the company behind it is a haulier is a picture of
/// a state that cannot exist. The company **id** does not change with it —
/// everything downstream keys off `FIXTURE-company`, and the fixture providers
/// are overridden family-wide so the id is ignored anyway.
Company fixtureCompany({
  OrgType orgType = OrgType.transporter,
  String? companyName,
}) =>
    Company(
      id: 'FIXTURE-company',
      userId: 'FIXTURE-user',
      companyName: companyName ??
          switch (orgType) {
            OrgType.transporter => 'Fixture Haulage (Pty) Ltd',
            OrgType.mineSupplier => 'Fixture Chrome Mine (Pty) Ltd',
            OrgType.buyer => 'Fixture Metals (Pty) Ltd',
          },
      whatsappNumber: '+27000000000',
      orgType: orgType,
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

  /// A no-op, because the real one calls the network.
  ///
  /// `CompanySelectionScreen` fires this from a post-frame callback, and
  /// `listCompanyDirectory()` against the dummy Supabase instance a render
  /// harness uses is a real socket attempt whose retry outlives the widget
  /// tree. Pinning `state` stops the RESULT reaching the fixture; it does not
  /// stop the CALL. Measured 2026-08-21: the render hung past two minutes.
  @override
  Future<void> loadAvailableCompanies() async {}
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

/// An [AuthStateNotifier] with NO session, for handing to a notifier whose
/// constructor's auth listener would otherwise dial out.
///
/// `NotificationNotifier` is the case this exists for: its listener runs with
/// `fireImmediately: true`, and on a signed-in state it loads from the network
/// and then opens a realtime channel — unconditionally, from a private method
/// there is no seam in. A channel opened against the render harness's dummy
/// Supabase instance leaves a connect timer that outlives the widget tree and
/// fails the golden AFTER it has been written.
///
/// The `user == null` branch is the one that returns before doing either. The
/// state such a notifier would have loaded is supplied to it directly instead,
/// so nothing is being hidden — only the dialling.
AuthStateNotifier signedOutAuthNotifier(Ref ref) => FixtureAuthStateNotifier(
      ref.watch(authServiceProvider),
      ref.watch(deviceVerificationStoreProvider),
      fixture: AuthState(),
    );

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
Override companyOverride({
  bool canManageEmployees = true,
  OrgType orgType = OrgType.transporter,
}) {
  return companyProvider.overrideWith((ref) => FixtureCompanyNotifier(
        ref.watch(companyServiceProvider),
        ref.watch(companyDatabaseServiceProvider),
        ref.watch(notificationServiceProvider),
        ref.watch(authStateProvider.notifier),
        fixture: CompanyState(
          company: fixtureCompany(orgType: orgType),
          employees: fixtureRoster(),
          canManageEmployees: canManageEmployees,
        ),
      ));
}

/// The employee gate. `fleet_management` resolves its company id from EITHER
/// this or [companyOverride], so both are supplied wherever it matters.
Override employeeOverride({
  UserRole role = UserRole.admin,
  OrgType orgType = OrgType.transporter,
  bool withDirectory = false,
}) {
  return employeeProvider.overrideWith((ref) => FixtureEmployeeNotifier(
        ref.watch(employeeServiceProvider),
        ref.watch(companyServiceProvider),
        ref.watch(authStateProvider.notifier),
        fixture: EmployeeState(
          employee: fixtureEmployee(role: role),
          company: fixtureCompany(orgType: orgType),
          availableCompanies:
              withDirectory ? kJoinableCompanies : const [],
        ),
      ));
}

/// What `/company-selection` lists — the companies an unlinked user may join.
///
/// Empty by default, because every other screen that reads `employeeProvider`
/// has a company already and a stray directory would be noise. The selection
/// screen asks for it: without it, the one screen whose whole design IS this
/// list photographs its "No companies found" empty state, which CLAUDE.md
/// §10.5 says is not the screen photographed at all.
///
/// One of each org type and one name long enough to make the row decide what
/// to do about it.
///
/// **No `logoUrl`.** A URL that does not resolve is a tempting fixture — it is
/// the state a broken logo is really in — but the render harness precaches
/// every image, and a network fetch to an unreachable host does not fail fast:
/// it hangs, and takes the whole render FILE down with it after two minutes.
/// Measured 2026-08-21.
const List<CompanyDirectoryEntry> kJoinableCompanies = [
  CompanyDirectoryEntry(
    id: 'co-transporter',
    companyName: 'Fixture Haulage (Pty) Ltd',
    orgType: OrgType.transporter,
  ),
  CompanyDirectoryEntry(
    id: 'co-mine',
    companyName: 'Iron Hills Mining',
    orgType: OrgType.mineSupplier,
  ),
  CompanyDirectoryEntry(
    id: 'co-buyer',
    companyName: 'Atlas Buyer Group',
    orgType: OrgType.buyer,
  ),
  CompanyDirectoryEntry(
    id: 'co-longname',
    companyName: 'Highveld Bulk Commodity Carriers & Logistics',
    orgType: OrgType.transporter,
  ),
];

/// `companyAccessProvider` is a plain `Provider`, so it can simply be handed a
/// value.
Override companyAccessOverride({
  bool canManageEmployees = true,
  OrgType orgType = OrgType.transporter,
  UserRole role = UserRole.admin,
}) {
  return companyAccessProvider.overrideWithValue(
    CompanyAccessContext(
      company: fixtureCompany(orgType: orgType),
      visibleEmployees: fixtureRoster(),
      currentEmployee: fixtureEmployee(role: role),
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
/// [isMineSupplier] is a parameter because the appearance screen's two premium
/// theme sections are mine/supplier-only — a transporter photographs one card
/// of three and the whole `MineThemeDirection` picker is absent.
Override portalWorkspaceOverride({bool isMineSupplier = false}) {
  return portalWorkspaceProvider.overrideWithValue(
    PortalWorkspaceModel(
      phase: PortalWorkspacePhase.ready,
      isMineSupplier: isMineSupplier,
      workspaceName: 'Fixture Haulage (Pty) Ltd',
      operatorName: 'Fixture Operator',
      roleLabel: 'Admin',
      tabs: const [
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
  OrgType orgType = OrgType.transporter,
}) =>
    [
      authOverride(),
      companyOverride(
          canManageEmployees: canManageEmployees, orgType: orgType),
      employeeOverride(role: role, orgType: orgType),
      companyAccessOverride(
          canManageEmployees: canManageEmployees,
          orgType: orgType,
          role: role),
      fleetOverride(),
    ];

// ---------------------------------------------------------------------------
// Fleet
// ---------------------------------------------------------------------------

/// The fixture fleet — four trucks, ONE namespace.
///
/// The ids and registrations here match `kFleetStatus` and the trips in
/// `portal_capture_fixtures.dart` exactly, and that is the point. The two
/// fixture files used to describe two different fleets — `FIXTURE-vehicle-1`
/// was a Scania on `CK 84 RT GP` in one and `veh-1` was a Freightliner on the
/// same plate in the other — so a screen that read the fleet from one and its
/// trips from the other resolved nothing. The driver's Trip screen is exactly
/// that screen: it finds the driver's truck in the fleet and then filters trips
/// by that truck's **id**. It rendered "Couldn't load your trip".
///
/// `veh-2` is the one with a live trip (`t-2`, en route to offload) and the one
/// [vehicleDriversOverride] assigns the fixture driver to, so the driver hero
/// has something in it. `veh-4` is the truck in maintenance.
List<FleetVehicle> fixtureFleet() => [
      FleetVehicle(
        id: 'veh-1',
        companyId: 'FIXTURE-company',
        createdAt: _fixtureDate,
        vehicleRegistrationNumber: 'CK 84 RT GP',
        vehicleMake: 'Freightliner',
        vehicleType: 'Interlink',
        vehicleYearModel: 2021,
        vehicleOdometerKm: 412300,
        firstTrailerRegs: 'CK 85 RT GP',
        secondTrailerRegs: 'CK 86 RT GP',
        // `assignedDriverId` AND the name. The fleet register's Assigned /
        // Unassigned chip reads `vehicle.assignedDriverId != null` and nothing
        // else, so a fixture carrying only the name described a truck with a
        // driver whose assignment did not exist — a state the real data cannot
        // hold. Every truck in the register photographed as "Unassigned",
        // which is half the badge and the wrong half. Found 2026-08-20 when
        // the fleet screen was first rendered at phone width.
        assignedDriverId: 'emp-1',
        driverFirstName: 'Sipho',
        driverLastName: 'Ndlovu',
      ),
      FleetVehicle(
        id: 'veh-2',
        companyId: 'FIXTURE-company',
        createdAt: _fixtureDate,
        vehicleRegistrationNumber: 'JD 22 PL MP',
        vehicleMake: 'Scania',
        vehicleType: 'Side tipper',
        vehicleYearModel: 2019,
        vehicleOdometerKm: 688140,
        firstTrailerRegs: 'JD 23 PL MP',
        assignedDriverId: 'emp-2',
        driverFirstName: 'Thandi',
        driverLastName: 'Mokoena',
      ),
      FleetVehicle(
        id: 'veh-3',
        companyId: 'FIXTURE-company',
        createdAt: _fixtureDate,
        vehicleRegistrationNumber: 'BX 09 LM NW',
        vehicleMake: 'Volvo',
        vehicleType: 'Flat deck',
        vehicleYearModel: 2023,
        vehicleOdometerKm: 91500,
      ),
      // In maintenance — the third fleet state (CLAUDE.md §4), derived from an
      // open out-of-service record rather than a flag. `kMaintenance` carries
      // the record that puts it there.
      FleetVehicle(
        id: 'veh-4',
        companyId: 'FIXTURE-company',
        createdAt: _fixtureDate,
        vehicleRegistrationNumber: 'MN 07 PL GP',
        vehicleMake: 'MAN',
        vehicleType: 'Tautliner',
        vehicleYearModel: 2020,
        vehicleOdometerKm: 254880,
      ),
    ];

/// A [FleetNotifier] whose state is pinned, like the three above.
///
/// Without this the fleet screen sits on `isLoading` and renders a
/// `CircularProgressIndicator` — which is not only an empty picture but a
/// NON-DETERMINISTIC one: the spinner's arc lands at a slightly different angle
/// depending on microtask ordering, so a golden of it fails against itself. A
/// render that cannot reproduce is not evidence.
///
/// It simply **does not call `start()`**, which is what keeps it off the
/// network. Until 2026-08-20 `FleetNotifier` loaded and subscribed from its
/// constructor, so this subclass inherited both no matter what it did
/// afterwards: `super(...)` runs first. The realtime channel's reconnect timer
/// then outlived every golden of this screen — a sweep pumps and ends, but
/// `expectLater` keeps a golden's body alive long enough for the framework's
/// pending-timer check to fire. That is why fleet management had no picture.
class FixtureFleetNotifier extends FleetNotifier {
  FixtureFleetNotifier(
    super.fleetService,
    super.ref,
    super.companyId, {
    required FleetState fixture,
  }) {
    state = fixture;
    _pinned = true;
  }

  bool _pinned = false;

  @override
  set state(FleetState value) {
    if (_pinned) return;
    super.state = value;
  }

  /// Refuses to start, so nothing here reaches the network.
  ///
  /// Overridden rather than merely left uncalled: `fleetOverride` is not the
  /// only thing that can build one of these, and a fixture that quietly began
  /// dialling out because some other code path called `start()` would put the
  /// pending timer back with nothing to say where it came from.
  @override
  void start() {}
}

/// The fleet for the fixture company.
Override fleetOverride() {
  return fleetProvider.overrideWith((ref, companyId) => FixtureFleetNotifier(
        ref.watch(fleetServiceProvider),
        ref,
        companyId,
        fixture: FleetState(vehicles: fixtureFleet()),
      ));
}

// ---------------------------------------------------------------------------
// Operations
// ---------------------------------------------------------------------------

/// An [OperationsNotifier] that never dials out and holds a fixed state.
///
/// Same arrangement as [FixtureFleetNotifier], and it became possible for the
/// same reason: `OperationsNotifier` used to `refresh()` and open its realtime
/// channels from its constructor, so the operations hub could not be
/// constructed without a network and therefore could not be photographed. The
/// seam is `start()`, which this refuses.
class FixtureOperationsNotifier extends OperationsNotifier {
  FixtureOperationsNotifier(
    super.service,
    super.scope, {
    required OperationsState fixture,
  }) {
    state = fixture;
    _pinned = true;
  }

  bool _pinned = false;

  @override
  set state(OperationsState value) {
    if (_pinned) return;
    super.state = value;
  }

  @override
  void start() {}
}

/// The operations hub's state for the fixture company.
///
/// The fleet and the roster are populated and the ledgers are not, on purpose.
/// A fixture where every tab is full hides the empty states, and an empty state
/// is a design that has to be looked at like any other — this project has
/// already shipped one screen whose empty state nobody had seen.
Override operationsOverride() {
  return operationsProvider.overrideWith(
    (ref, scope) => FixtureOperationsNotifier(
      ref.watch(operationsServiceProvider),
      scope,
      fixture: OperationsState(
        employees: [
          fixtureEmployee(),
          fixtureEmployee(
            id: 'FIXTURE-employee-2',
            firstName: 'Second',
            lastName: 'Driver',
            role: UserRole.driver,
          ),
        ],
        vehicles: fixtureFleet(),
        isLoading: false,
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Communications
// ---------------------------------------------------------------------------

/// A [CommunicationsNotifier] that never dials out and holds a fixed state.
///
/// The third of these, after [FixtureFleetNotifier] and
/// [FixtureOperationsNotifier], and the third notifier whose constructor used
/// to reach the network. Refuses `start()`.
class FixtureCommunicationsNotifier extends CommunicationsNotifier {
  FixtureCommunicationsNotifier(
    super.service,
    super.scope, {
    required CommunicationsState fixture,
  }) {
    state = fixture;
    _pinned = true;
  }

  bool _pinned = false;

  @override
  set state(CommunicationsState value) {
    if (_pinned) return;
    super.state = value;
  }

  @override
  void start() {}
}

/// The communications hub's state for the fixture company.
///
/// Two announcements at DIFFERENT importances, because the card is toned and
/// badged by that field — a fixture where both were `normal` would render one
/// treatment twice and show nothing about the other two. The chat side is left
/// empty on purpose so its empty state is in the picture as well.
Override communicationsOverride() {
  return communicationsProvider.overrideWith(
    (ref, scope) => FixtureCommunicationsNotifier(
      ref.watch(communicationsServiceProvider),
      scope,
      fixture: CommunicationsState(
        company: fixtureCompany(),
        employees: [
          fixtureEmployee(),
          fixtureEmployee(
            id: 'FIXTURE-employee-2',
            firstName: 'Second',
            lastName: 'Driver',
            role: UserRole.driver,
          ),
        ],
        announcements: [
          BroadcastUpdate(
            id: 'FIXTURE-broadcast-1',
            event: 'company_broadcast',
            createdBy: 'FIXTURE-user',
            // A real recent date, not `_fixtureDate`.
            //
            // `_fixtureDate` is 2020-01-01, which is fine for a row nobody
            // reads a date off — and these are ANNOUNCEMENTS, whose date is
            // half of what they say. The communications hub photographed two
            // live notices both stamped "01 Jan 2020 · 02:00" beside a product
            // whose today is August 2026, which reads as a defect in the
            // product rather than a placeholder in a fixture.
            timestamp: DateTime.utc(2026, 8, 14, 16, 12),
            payload: const {
              'title': 'Weighbridge offline 06:00–08:00 Saturday',
              'message': 'Calibration. Hold loads at the gate; Security will '
                  'check trucks in as normal and the queue will clear from 08:00.',
              'importance': 'high',
            },
          ),
          BroadcastUpdate(
            id: 'FIXTURE-broadcast-2',
            event: 'company_broadcast',
            createdBy: 'FIXTURE-user',
            timestamp: DateTime.utc(2026, 8, 11, 6, 45),
            payload: const {
              'title': 'New seal supplier from Monday',
              'message': 'Same serial format. Report any seal that will not '
                  'close to the Load Controller before the truck is loaded.',
              'importance': 'normal',
            },
          ),
        ],
        isLoading: false,
      ),
    ),
  );
}
