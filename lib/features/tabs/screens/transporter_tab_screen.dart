import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_application_1/features/auth/models/user_type.dart';
import 'package:flutter_application_1/features/company/providers/company_provider.dart';
import 'package:flutter_application_1/features/employee/providers/employee_provider.dart';
import 'package:flutter_application_1/features/fleet/providers/fleet_provider.dart';
import 'package:flutter_application_1/features/notifications/providers/notification_provider.dart';
import 'package:flutter_application_1/features/notifications/widgets/notification_button_tab.dart';
import 'package:flutter_application_1/features/tabs/widgets/operations_workspace.dart';

class TransporterTabScreen extends ConsumerWidget {
  const TransporterTabScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final companyState = ref.watch(companyProvider);
    final employeeState = ref.watch(employeeProvider);
    final notificationState = ref.watch(notificationProvider);
    final companyId =
        companyState.company?.id ?? employeeState.employee?.companyId;
    final fleetState = companyId != null
        ? ref.watch(fleetProvider(companyId))
        : null;

    return OperationsWorkspace(
      title: 'Transporter Workspace',
      subtitle: companyState.company == null && employeeState.company == null
          ? 'Load your transporter company to manage live fleet and driver records.'
          : 'Manage live fleet, driver assignments, and readiness from one workspace.',
      metrics: [
        WorkspaceMetric(
          label: 'Vehicles',
          value: (fleetState?.vehicles.length ?? 0).toString(),
          icon: Icons.local_shipping_outlined,
        ),
        WorkspaceMetric(
          label: 'Active fleet',
          value: (fleetState?.activeVehicles.length ?? 0).toString(),
          icon: Icons.directions_car_filled_outlined,
        ),
        WorkspaceMetric(
          label: 'Assigned',
          value: (fleetState?.assignedVehicles.length ?? 0).toString(),
          icon: Icons.assignment_ind_outlined,
        ),
        WorkspaceMetric(
          label: 'Unread',
          value: notificationState.unreadCount.toString(),
          icon: Icons.notifications_outlined,
        ),
      ],
      actions: [
        WorkspaceAction(
          label: 'Fleet Management',
          icon: Icons.local_shipping_outlined,
          onPressed: companyId == null
              ? null
              : () => context.go('/fleet-management'),
          isPrimary: true,
        ),
        WorkspaceAction(
          label: 'Manage Employees',
          icon: Icons.groups_outlined,
          onPressed: () => context.go('/company-employees'),
        ),
        WorkspaceAction(
          label: 'Operations Hub',
          icon: Icons.inventory_2_outlined,
          onPressed: companyId == null
              ? null
              : () => context.go('/operations?tab=loads'),
        ),
        WorkspaceAction(
          label: 'Communications',
          icon: Icons.forum_outlined,
          onPressed: companyId == null
              ? null
              : () => context.go('/communications'),
        ),
      ],
      sectionTitle: 'Fleet Readiness',
      sectionTrailing: const NotificationButtonTab(role: UserRole.transporter),
      items: (fleetState?.activeVehicles ?? []).take(6).map((vehicle) {
        return WorkspaceItem(
          title: vehicle.vehicleRegistrationNumber,
          subtitle: vehicle.hasAssignedDriver
              ? 'Driver: ${vehicle.driverFullName}'
              : 'No driver assigned yet',
          icon: Icons.local_shipping_outlined,
          trailing: vehicle.isActive ? 'Active' : 'Inactive',
        );
      }).toList(),
      emptyTitle: 'No fleet vehicles yet',
      emptyMessage:
          'Add vehicles and assign drivers from Fleet Management to start live transporter operations.',
      emptyIcon: Icons.local_shipping_outlined,
    );
  }
}
