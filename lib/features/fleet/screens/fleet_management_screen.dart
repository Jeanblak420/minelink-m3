import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_application_1/features/fleet/providers/fleet_provider.dart';
import 'package:flutter_application_1/features/fleet/models/fleet_vehicle_model.dart';
import 'package:flutter_application_1/features/auth/models/user_type.dart';
import 'package:flutter_application_1/features/auth/providers/auth_state.dart';
import 'package:flutter_application_1/features/company/providers/company_provider.dart';
import 'package:flutter_application_1/features/employee/providers/employee_provider.dart';
import 'package:flutter_application_1/features/fleet/widgets/add_vehicle_form.dart';
import 'package:flutter_application_1/features/fleet/widgets/edit_vehicle_dialog.dart';
import 'package:flutter_application_1/features/fleet/widgets/driver_assignment_dialog.dart';
import 'package:flutter_application_1/features/fleet/widgets/fleet_vehicle_table.dart';
import 'package:flutter_application_1/core/design/components/ml_components.dart';
import 'package:flutter_application_1/features/tour/widgets/tour_target.dart';
import 'package:flutter_application_1/features/tour/examples/fleet_management_keys.dart';

class FleetManagementScreen extends ConsumerWidget {
  const FleetManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final companyState = ref.watch(companyProvider);
    final employeeState = ref.watch(employeeProvider);

    // Determine if the user is authorized to access this screen
    final bool isAuthorized = _isUserAuthorized(
      authState,
      companyState,
      employeeState,
    );

    // NO `Scaffold(appBar:)` anywhere below — every route that reaches this
    // screen is a leaf of the portal `ShellRoute`, whose top bar already
    // carries the section name, so its own bar printed "Fleet Management" a
    // second time directly underneath. Photographed 2026-08-21.
    if (!isAuthorized) {
      return const MlEmptyState(
        icon: Icons.lock_outline_rounded,
        title: 'Fleet management',
        message:
            'You are not authorized to access the fleet management system. '
            'Only Transporter companies with Admin or Management roles can '
            'access this feature.',
      );
    }

    // Get the company ID
    final String? companyId = _getCompanyId(companyState, employeeState);

    if (companyId == null) {
      return const MlEmptyState(
        icon: Icons.domain_disabled_outlined,
        title: 'Fleet management',
        message: 'Company information not available.',
      );
    }

    // Get the fleet provider for this company
    final fleetProviderInstance = ref.watch(fleetProvider(companyId));

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
            child: MlPageHeader(
              title: 'Fleet management',
              description:
                  'Every vehicle registered to this company, and '
                  'whether it is available, on route or in maintenance.',
              // THE PRIMARY ACTION BELONGS IN THE HEADER, not in a
              // `FloatingActionButton` over the bottom-right corner.
              //
              // No other screen in this product has one. A FAB is Material's
              // own answer, but this console's answer — the reference's, and
              // every other register's — is a primary button in the page
              // header beside the page's name, where the reader is already
              // looking when they decide to add something. The FAB also sat
              // ON TOP of the last row of the register at phone width, and
              // its only label was a tooltip, which a touch device never
              // shows.
              actions: [
                MlButton.ghost(
                  label: 'Refresh',
                  icon: Icons.refresh,
                  compact: true,
                  onPressed: () => ref
                      .read(fleetProvider(companyId).notifier)
                      .loadFleetVehicles(),
                ),
                TourTarget(
                  id: 'transporter.fleet.add_vehicle',
                  targetKey: FleetManagementTourKeys.addVehicle,
                  child: MlButton.primary(
                    label: 'Add vehicle',
                    icon: Icons.add_rounded,
                    compact: true,
                    onPressed: () =>
                        _showAddVehicleDialog(context, ref, companyId),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _buildBody(context, ref, fleetProviderInstance, companyId),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    WidgetRef ref,
    FleetState fleetState,
    String companyId,
  ) {
    if (fleetState.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (fleetState.error != null) {
      // Was a raw `Text('Error: $error')` in `Colors.red`. It did at least
      // carry a retry — one of the 4 in 27 that did — but it named nothing,
      // put the thrown string in front of the user, and used a literal red
      // that does not move between themes. `MlLoadFailure` renders through
      // `friendlyError`, titles itself "Could not load the fleet", and cannot
      // be constructed without a way out of it.
      return Center(
        child: MlLoadFailure(
          subject: 'the fleet',
          error: fleetState.error,
          onRetry: () {
            ref.read(fleetProvider(companyId).notifier).loadFleetVehicles();
          },
        ),
      );
    }

    if (fleetState.vehicles.isEmpty) {
      return MlEmptyState(
        icon: Icons.local_shipping_outlined,
        title: 'No vehicles in your fleet yet.',
        message:
            'Register your first truck to upload its truck pack, driver details and documents.',
        action: MlButton.primary(
          label: 'Register truck',
          icon: Icons.add_rounded,
          onPressed: () => _showAddVehicleDialog(context, ref, companyId),
        ),
      );
    }

    // READ ONCE, USED TWICE — by the stat cards and by the register's rows.
    //
    // It used to be watched inside a `Builder` that wrapped the cards alone,
    // and the table decided each row's status from `assignedDriverId`
    // instead. Two sources, one question, and they disagreed on this very
    // screen (see `FleetVehicleTable.statusByVehicleId`). Reading it here is
    // what makes them agree by construction rather than by coincidence.
    final fleetStatuses = ref.watch(fleetStatusProvider(companyId)).valueOrNull;
    final statusByVehicleId = fleetStatuses == null
        ? null
        : {for (final s in fleetStatuses) s.vehicleId: s};

    return RefreshIndicator(
      onRefresh: () async {
        await ref.read(fleetProvider(companyId).notifier).loadFleetVehicles();
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Fleet summary — kit KPI stat row.
            //
            // Read from `fleetStatusProvider`, NOT from the driver-assignment
            // flags on the vehicle rows: availability in this product is
            // derived from active trips server-side, and the two are not the
            // same question. Null while the read is in flight, which renders
            // as "—" rather than as a confident zero.
            TourTarget(
              id: 'transporter.fleet.status',
              targetKey: FleetManagementTourKeys.statusCards,
              child: Builder(
                builder: (context) {
                  final rows = fleetStatuses;
                  final onRoute = rows?.where((v) => v.onRoute).length;
                  final available = rows?.where((v) => v.available).length;
                  final inMaintenance = rows
                      ?.where((v) => v.inMaintenance)
                      .length;
                  // `MlTileGrid`, NOT a seventeenth hand-rolled ladder.
                  //
                  // This one read `cols = w > 900 ? 4 : 2` and therefore NEVER
                  // REACHED ONE COLUMN. On a 412px phone that leaves each card
                  // 183px, of which `MlStatCard` spends ~92 on its tone bar,
                  // icon well and padding — so the mono captions broke inside
                  // the token: `carrying_a_lo / ad`, `excludes_1_in /
                  // _maintenance`, `not_in_servic / e`. Nothing overflowed, so
                  // no sweep saw it; photographed on `screen-fleet-phone-dark`.
                  //
                  // The component's own doc names this exact shape as duplicated
                  // in sixteen files with breakpoints that disagree screen to
                  // screen (980/620 here, 900/560 there) for tiles of the same
                  // size. A MINIMUM TILE WIDTH says the thing that is actually
                  // true — a stat card needs ~260px to hold a figure and a
                  // caption — and has no arbitrary breakpoint to disagree with
                  // anyone else's.
                  return MlTileGrid(
                    minTileWidth: 260,
                    children: [
                      MlStatCard(
                        label: 'Total fleet',
                        value: '${fleetState.vehicles.length}',
                        icon: Icons.local_shipping_outlined,
                        tone: MlTone.accent,
                        caption: 'All vehicles',
                      ),
                      // ON ROUTE AND AVAILABLE ARE DERIVED FROM ACTIVE TRIPS, not
                      // from whether a driver happens to be rostered. They used to
                      // read `hasAssignedDriver`, under the labels "On Trip /
                      // Assigned" and "Available", and on 2026-08-22 that put every
                      // one of Roadhaul's three trucks in the WRONG bucket: the two
                      // carrying loads to Johannesburg have no driver row, so they
                      // counted as Available, while the one parked truck has a
                      // driver and counted as On Trip. "Available" is the number an
                      // admin allocates from.
                      //
                      // `fleetStatusProvider` is the same server-derived source the
                      // Trucks on route screen and the dashboard already read
                      // (`list_transporter_fleet_status`, CLAUDE.md §4), so all
                      // three now agree by construction rather than by coincidence
                      // — and since 2026-08-23 the REGISTER'S OWN ROWS read it too.
                      MlStatCard(
                        label: 'On route',
                        value: onRoute == null ? '—' : '$onRoute',
                        icon: Icons.bolt_outlined,
                        tone: MlTone.transit,
                        caption: 'Carrying a load',
                      ),
                      MlStatCard(
                        label: 'Available',
                        value: available == null ? '—' : '$available',
                        icon: Icons.check_circle_outline,
                        tone: MlTone.done,
                        // A truck in maintenance is active, not on a route,
                        // and NOT allocatable. Without saying so the four
                        // cards stop adding up to the total and the reader
                        // has no way to see why.
                        caption: (inMaintenance ?? 0) > 0
                            ? 'Excludes $inMaintenance in maintenance'
                            : 'Ready to allocate',
                      ),
                      MlStatCard(
                        label: 'Inactive',
                        value: '${fleetState.inactiveVehicles.length}',
                        icon: Icons.do_not_disturb_on_outlined,
                        tone: MlTone.warn,
                        caption: 'Not in service',
                      ),
                    ],
                  );
                },
              ),
            ),

            const SizedBox(height: 24),

            // Active Fleet List
            TourTarget(
              id: 'transporter.fleet.register',
              targetKey: FleetManagementTourKeys.fleetRegister,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  MlSectionTitle(
                    'Fleet register',
                    icon: Icons.local_shipping_outlined,
                    meta: mlCount(
                      fleetState.activeVehicles.length,
                      'active vehicle',
                    ),
                  ),
                  SizedBox(
                    width: double.infinity,
                    child: FleetVehicleTable(
                      vehicles: fleetState.activeVehicles,
                      statusByVehicleId: statusByVehicleId,
                      onEditVehicle: (vehicle) => _showEditVehicleDialog(
                        context,
                        ref,
                        vehicle,
                        companyId,
                      ),
                      onAssignDriver: (vehicle) => _showAssignDriverDialog(
                        context,
                        ref,
                        vehicle,
                        companyId,
                      ),
                      onUnassignDriver: (vehicle) => _showUnassignDriverDialog(
                        context,
                        ref,
                        vehicle,
                        companyId,
                      ),
                      onRemoveVehicle: (vehicle) => _showMarkAsInactiveDialog(
                        context,
                        ref,
                        vehicle,
                        companyId,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Only show inactive vehicles section if there are any
            if (fleetState.inactiveVehicles.isNotEmpty) ...[
              const SizedBox(height: 32),

              // Inactive Vehicles
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  MlSectionTitle(
                    'Inactive vehicles',
                    icon: Icons.do_not_disturb_on_outlined,
                    meta: mlCount(
                      fleetState.inactiveVehicles.length,
                      'vehicle',
                    ),
                  ),
                  SizedBox(
                    width: double.infinity,
                    child: FleetVehicleTable(
                      vehicles: fleetState.inactiveVehicles,
                      showDriver: false,
                      onEditVehicle: (vehicle) => _showEditVehicleDialog(
                        context,
                        ref,
                        vehicle,
                        companyId,
                      ),
                      onReactivateVehicle: (vehicle) =>
                          _showReactivateVehicleDialog(
                            context,
                            ref,
                            vehicle,
                            companyId,
                          ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showEditVehicleDialog(
    BuildContext context,
    WidgetRef ref,
    FleetVehicle vehicle,
    String companyId,
  ) {
    showDialog(
      context: context,
      builder: (context) =>
          EditVehicleDialog(companyId: companyId, vehicle: vehicle),
    );
  }

  void _showAddVehicleDialog(
    BuildContext context,
    WidgetRef ref,
    String companyId,
  ) {
    showDialog(
      context: context,
      builder: (context) => AddVehicleForm(companyId: companyId),
    );
  }

  void _showAssignDriverDialog(
    BuildContext context,
    WidgetRef ref,
    FleetVehicle vehicle,
    String companyId,
  ) {
    // First load available drivers
    ref.read(fleetProvider(companyId).notifier).loadAvailableDrivers();

    showDialog(
      context: context,
      builder: (context) =>
          DriverAssignmentDialog(vehicle: vehicle, companyId: companyId),
    );
  }

  void _showUnassignDriverDialog(
    BuildContext context,
    WidgetRef ref,
    FleetVehicle vehicle,
    String companyId,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unassign driver'),
        content: Text(
          'Are you sure you want to unassign ${vehicle.driverFullName} from this vehicle?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              ref
                  .read(fleetProvider(companyId).notifier)
                  .unassignDriver(vehicle.id);
              Navigator.of(context).pop();
            },
            style: FilledButton.styleFrom(
              backgroundColor: MlTone.error
                  .colors(Theme.of(context).brightness)
                  .fg,
            ),
            child: const Text('Unassign'),
          ),
        ],
      ),
    );
  }

  void _showMarkAsInactiveDialog(
    BuildContext context,
    WidgetRef ref,
    FleetVehicle vehicle,
    String companyId,
  ) {
    final hasDriver = vehicle.hasAssignedDriver;
    final driverName = vehicle.driverFullName;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mark vehicle as inactive'),
        content: hasDriver
            ? Text(
                'Are you sure you want to mark vehicle ${vehicle.vehicleRegistrationNumber} as inactive? By marking this vehicle as inactive, you will remove $driverName from this vehicle.',
              )
            : Text(
                'Are you sure you want to mark vehicle ${vehicle.vehicleRegistrationNumber} as inactive?',
              ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('No'),
          ),
          FilledButton(
            onPressed: () {
              ref
                  .read(fleetProvider(companyId).notifier)
                  .markVehicleAsInactive(vehicle.id);
              Navigator.of(context).pop();

              // Show success message
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Vehicle marked as inactive successfully'),
                ),
              );
            },
            style: FilledButton.styleFrom(
              backgroundColor: MlTone.error
                  .colors(Theme.of(context).brightness)
                  .fg,
            ),
            child: const Text('Yes'),
          ),
        ],
      ),
    );
  }

  void _showReactivateVehicleDialog(
    BuildContext context,
    WidgetRef ref,
    FleetVehicle vehicle,
    String companyId,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reactivate vehicle'),
        content: Text(
          'Are you sure you want to reactivate vehicle ${vehicle.vehicleRegistrationNumber}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('No'),
          ),
          FilledButton(
            onPressed: () {
              ref
                  .read(fleetProvider(companyId).notifier)
                  .markVehicleAsActive(vehicle.id);
              Navigator.of(context).pop();

              // Show success message
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Vehicle reactivated successfully'),
                ),
              );
            },
            child: const Text('Yes'),
          ),
        ],
      ),
    );
  }

  bool _isUserAuthorized(
    AuthState authState,
    CompanyState companyState,
    EmployeeState employeeState,
  ) {
    // For company users
    if (companyState.company != null) {
      return companyState.company!.orgType == OrgType.transporter;
    }

    // For employee users
    if (employeeState.employee != null &&
        employeeState.employee!.role != null) {
      // Check if employee belongs to a transporter company and has admin or management role
      final isTransporterCompany =
          employeeState.company?.orgType == OrgType.transporter;
      final hasAdminRole =
          employeeState.employee!.role == UserRole.admin ||
          employeeState.employee!.role == UserRole.management;

      return isTransporterCompany && hasAdminRole;
    }

    return false;
  }

  String? _getCompanyId(
    CompanyState companyState,
    EmployeeState employeeState,
  ) {
    // For company users
    if (companyState.company != null) {
      return companyState.company!.id;
    }

    // For employee users
    if (employeeState.employee != null &&
        employeeState.employee!.companyId != null) {
      return employeeState.employee!.companyId;
    }

    return null;
  }
}
