import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_application_1/features/auth/models/user_type.dart';
import 'package:flutter_application_1/features/employee/providers/employee_provider.dart';
import 'package:flutter_application_1/features/fleet/models/fleet_vehicle_model.dart';
import 'package:flutter_application_1/features/fleet/models/vehicle_driver.dart';
import 'package:flutter_application_1/features/fleet/providers/fleet_provider.dart';
import 'package:flutter_application_1/features/notifications/providers/notification_provider.dart';
import 'package:flutter_application_1/features/notifications/widgets/notification_button_tab.dart';
import 'package:flutter_application_1/features/tabs/widgets/operations_workspace.dart';

class DriverTabScreen extends ConsumerWidget {
  const DriverTabScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final employeeState = ref.watch(employeeProvider);
    final notificationState = ref.watch(notificationProvider);
    final employee = employeeState.employee;
    final company = employeeState.company;
    final companyId = employee?.companyId;
    final fleetState = companyId != null
        ? ref.watch(fleetProvider(companyId))
        : null;
    final assignmentsAsync = companyId != null
        ? ref.watch(vehicleDriversProvider(companyId))
        : null;
    final assignments =
        assignmentsAsync?.asData?.value ?? const <VehicleDriver>[];
    final assignmentHasError = assignmentsAsync?.hasError ?? false;
    final assignedVehicle = employee == null
        ? null
        : _findAssignedVehicle(
            fleetState?.activeVehicles ?? const [],
            assignments,
            employee.id,
          );
    final uploadedDocumentCount = [
      employee?.idDocumentUrl,
      employee?.passportDocumentUrl,
      employee?.workVisaDocumentUrl,
      employee?.licenseDocumentUrl,
    ].whereType<String>().where((value) => value.isNotEmpty).length;

    return OperationsWorkspace(
      title: 'Driver Workspace',
      subtitle: company == null
          ? 'Link to a transporter company to access your live driver workspace.'
          : 'View your real driver assignment, document readiness, and company access.',
      metrics: [
        WorkspaceMetric(
          label: 'Company',
          value: company?.companyName ?? 'Not linked',
          icon: Icons.business_outlined,
        ),
        WorkspaceMetric(
          label: 'Assignment',
          value: assignmentHasError
              ? 'Unavailable'
              : (assignedVehicle?.vehicleRegistrationNumber ?? 'None'),
          icon: Icons.local_shipping_outlined,
        ),
        WorkspaceMetric(
          label: 'Documents',
          value: uploadedDocumentCount.toString(),
          icon: Icons.folder_outlined,
        ),
        WorkspaceMetric(
          label: 'Unread',
          value: notificationState.unreadCount.toString(),
          icon: Icons.notifications_outlined,
        ),
      ],
      actions: [
        WorkspaceAction(
          label: 'Update Profile',
          icon: Icons.person_outline,
          onPressed: () => context.go('/profile'),
          isPrimary: true,
        ),
        WorkspaceAction(
          label: 'Notifications',
          icon: Icons.notifications_outlined,
          onPressed: () => context.go('/notifications'),
        ),
        WorkspaceAction(
          label: 'Loads Console',
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
      sectionTitle: 'Driver Readiness',
      sectionTrailing: const NotificationButtonTab(role: UserRole.driver),
      items: [
        if (assignedVehicle != null)
          WorkspaceItem(
            title: assignedVehicle.vehicleRegistrationNumber,
            subtitle:
                'Assigned vehicle${assignedVehicle.firstTrailerRegs != null ? ' • Trailer ${assignedVehicle.firstTrailerRegs}' : ''}',
            icon: Icons.local_shipping_outlined,
            trailing: 'Assigned',
          ),
        WorkspaceItem(
          title: 'Company access',
          subtitle:
              company?.companyName ??
              'You still need to be linked to a company.',
          icon: Icons.link_outlined,
          trailing: employee?.status == 'active'
              ? 'Active'
              : _formatStatus(employee?.status),
        ),
        WorkspaceItem(
          title: 'Document uploads',
          subtitle:
              '$uploadedDocumentCount file${uploadedDocumentCount == 1 ? '' : 's'} uploaded to your profile.',
          icon: Icons.folder_outlined,
          trailing: uploadedDocumentCount > 0 ? 'Ready' : 'Pending',
        ),
      ],
      emptyTitle: 'No driver records yet',
      emptyMessage:
          'Once your company link and vehicle assignment are active, they will appear here with real data.',
      emptyIcon: Icons.drive_eta_outlined,
    );
  }

  String _formatStatus(String? status) {
    switch (status) {
      case 'pending_company':
        return 'Pending company';
      case 'pending_role':
        return 'Pending role';
      case 'active':
        return 'Active';
      case 'rejected':
        return 'Declined';
      case 'inactive':
        return 'Inactive';
      case 'suspended':
        return 'Suspended';
      default:
        return 'Unknown';
    }
  }

  FleetVehicle? _findAssignedVehicle(
    List<FleetVehicle> vehicles,
    List<VehicleDriver> assignments,
    String employeeId,
  ) {
    // driver_assignments is authoritative under multi-driver: the embedded
    // mirror only carries the primary driver, hiding a truck's 2nd+ driver.
    for (final a in assignments) {
      if (a.driverEmployeeId == employeeId) {
        for (final vehicle in vehicles) {
          if (vehicle.id == a.vehicleId) return vehicle;
        }
      }
    }
    for (final vehicle in vehicles) {
      if (vehicle.assignedDriverEmployeeId == employeeId) {
        return vehicle;
      }
    }
    return null;
  }
}
