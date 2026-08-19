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
import 'package:flutter_application_1/features/portal/widgets/ml/ml.dart';

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

    if (!isAuthorized) {
      return Scaffold(
        appBar: AppBar(title: const Text('Fleet Management')),
        body: const Center(
          child: Text(
            'You are not authorized to access the Fleet Management system.\n'
            'Only Transporter companies with Admin or Management roles can access this feature.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    // Get the company ID
    final String? companyId = _getCompanyId(companyState, employeeState);

    if (companyId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Fleet Management')),
        body: const Center(child: Text('Company information not available.')),
      );
    }

    // Get the fleet provider for this company
    final fleetProviderInstance = ref.watch(fleetProvider(companyId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Fleet Management'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.read(fleetProvider(companyId).notifier).loadFleetVehicles();
            },
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _buildBody(context, ref, fleetProviderInstance, companyId),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddVehicleDialog(context, ref, companyId),
        tooltip: 'Add Vehicle',
        child: const Icon(Icons.add),
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
          label: 'Register Truck',
          icon: Icons.add_rounded,
          onPressed: () => _showAddVehicleDialog(context, ref, companyId),
        ),
      );
    }

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
            LayoutBuilder(builder: (context, c) {
              final w = c.maxWidth;
              const gap = 14.0;
              final cols = w > 900 ? 4 : 2;
              final itemW = (w - gap * (cols - 1)) / cols;
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  SizedBox(
                      width: itemW,
                      child: MlStatCard(
                          label: 'Total Fleet',
                          value: '${fleetState.vehicles.length}',
                          icon: Icons.local_shipping_outlined,
                          tone: MlTone.accent)),
                  SizedBox(
                      width: itemW,
                      child: MlStatCard(
                          label: 'On Trip / Assigned',
                          value: '${fleetState.assignedVehicles.length}',
                          icon: Icons.bolt_outlined,
                          tone: MlTone.transit)),
                  SizedBox(
                      width: itemW,
                      child: MlStatCard(
                          label: 'Available',
                          value: '${fleetState.unassignedVehicles.length}',
                          icon: Icons.check_circle_outline,
                          tone: MlTone.done)),
                  SizedBox(
                      width: itemW,
                      child: MlStatCard(
                          label: 'Inactive',
                          value: '${fleetState.inactiveVehicles.length}',
                          icon: Icons.do_not_disturb_on_outlined,
                          tone: MlTone.warn)),
                ],
              );
            }),

            const SizedBox(height: 24),

            // Active Fleet List
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                MlSectionTitle('Fleet Register',
                    icon: Icons.local_shipping_outlined,
                    meta: mlCount(
                        fleetState.activeVehicles.length, 'active vehicle')),
                SizedBox(
                  width: double.infinity,
                  child: FleetVehicleTable(
                    vehicles: fleetState.activeVehicles,
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

            // Only show inactive vehicles section if there are any
            if (fleetState.inactiveVehicles.isNotEmpty) ...[
              const SizedBox(height: 32),

              // Inactive Vehicles
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  MlSectionTitle('Inactive Vehicles',
                      icon: Icons.do_not_disturb_on_outlined,
                      meta: mlCount(
                          fleetState.inactiveVehicles.length, 'vehicle')),
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
      builder: (context) => EditVehicleDialog(
        companyId: companyId,
        vehicle: vehicle,
      ),
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
        title: const Text('Unassign Driver'),
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
              backgroundColor:
                  MlTone.error.colors(Theme.of(context).brightness).fg,
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
        title: const Text('Mark Vehicle as Inactive'),
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
              backgroundColor:
                  MlTone.error.colors(Theme.of(context).brightness).fg,
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
        title: const Text('Reactivate Vehicle'),
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
