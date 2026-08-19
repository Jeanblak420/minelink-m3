import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_application_1/features/notifications/services/notification_service.dart';
import 'package:flutter_application_1/features/notifications/models/notification_model.dart';
import 'package:flutter_application_1/features/fleet/models/fleet_vehicle_model.dart';
import 'package:flutter_application_1/features/auth/models/user_type.dart';
import 'package:flutter_application_1/features/employee/services/employee_service.dart';
import 'package:flutter_application_1/features/company/services/company_service.dart';
import 'package:flutter_application_1/features/employee/models/employee_model.dart';
import 'package:flutter_application_1/core/utils/logger.dart';

/// Service for creating fleet-related notifications
class FleetNotificationService {
  final NotificationService _notificationService;
  final EmployeeService _employeeService;
  final CompanyService _companyService;
  final Logger _logger = LoggerFactory.getLogger('FleetNotificationService');

  FleetNotificationService(
    this._notificationService,
    this._employeeService,
    this._companyService,
  );

  /// Create a notification when a vehicle is added to the fleet
  /// Returns true if all notifications were sent successfully, false otherwise
  Future<bool> notifyVehicleAdded({
    required String companyId,
    required String vehicleRegistrationNumber,
    required String actionedById,
    required String actionedByName,
  }) async {
    try {
      // Get all users who should receive this notification
      final recipients = await _getCompanyRecipients(companyId);

      // Create notifications for each recipient
      for (final recipient in recipients) {
        await _notificationService.createActionedNotification(
          userId: recipient.userId,
          title: 'New Vehicle Added',
          message:
              'Vehicle $vehicleRegistrationNumber has been added to the fleet by $actionedByName.',
          type: NotificationType.fleetVehicleAdded,
          companyId: companyId,
          actionedBy: actionedByName,
          actionedById: actionedById,
          roleScope: recipient.roleScope,
          orgType: recipient.orgType,
          metadata: {
            'vehicle_registration_number': vehicleRegistrationNumber,
            'actioned_by': actionedByName,
            'actioned_by_id': actionedById,
          },
        );
      }
      return true;
    } catch (e) {
      _logger.e('Error creating vehicle added notification', e);
      return false;
    }
  }

  /// Create a notification when a driver is assigned to a vehicle
  /// Returns true if all notifications were sent successfully, false otherwise
  Future<bool> notifyDriverAssigned({
    required String companyId,
    required FleetVehicle vehicle,
    required String driverId,
    required String driverName,
    required String actionedById,
    required String actionedByName,
  }) async {
    try {
      // Get all users who should receive this notification
      final recipients = await _getCompanyRecipients(companyId);

      // Create notifications for each recipient
      for (final recipient in recipients) {
        await _notificationService.createActionedNotification(
          userId: recipient.userId,
          title: 'Driver Assigned',
          message:
              '$driverName has been assigned to vehicle ${vehicle.vehicleRegistrationNumber} by $actionedByName.',
          type: NotificationType.fleetDriverAssigned,
          companyId: companyId,
          actionedBy: actionedByName,
          actionedById: actionedById,
          roleScope: recipient.roleScope,
          orgType: recipient.orgType,
          metadata: {
            'vehicle_id': vehicle.id,
            'vehicle_registration_number': vehicle.vehicleRegistrationNumber,
            'driver_id': driverId,
            'driver_name': driverName,
            'actioned_by': actionedByName,
            'actioned_by_id': actionedById,
          },
        );
      }

      // Also notify the driver
      await _notificationService.createActionedNotification(
        userId: driverId,
        title: 'Vehicle Assignment',
        message:
            'You have been assigned to vehicle ${vehicle.vehicleRegistrationNumber}.',
        type: NotificationType.fleetDriverAssigned,
        companyId: companyId,
        actionedBy: actionedByName,
        actionedById: actionedById,
        metadata: {
          'vehicle_id': vehicle.id,
          'vehicle_registration_number': vehicle.vehicleRegistrationNumber,
        },
      );
      return true;
    } catch (e) {
      _logger.e('Error creating driver assigned notification', e);
      return false;
    }
  }

  /// Create a notification when a driver is unassigned from a vehicle
  /// Returns true if all notifications were sent successfully, false otherwise
  Future<bool> notifyDriverUnassigned({
    required String companyId,
    required FleetVehicle vehicle,
    required String driverId,
    required String driverName,
    required String actionedById,
    required String actionedByName,
  }) async {
    try {
      // Get all users who should receive this notification
      final recipients = await _getCompanyRecipients(companyId);

      // Create notifications for each recipient
      for (final recipient in recipients) {
        await _notificationService.createActionedNotification(
          userId: recipient.userId,
          title: 'Driver Unassigned',
          message:
              '$driverName has been unassigned from vehicle ${vehicle.vehicleRegistrationNumber} by $actionedByName.',
          type: NotificationType.fleetDriverUnassigned,
          companyId: companyId,
          actionedBy: actionedByName,
          actionedById: actionedById,
          roleScope: recipient.roleScope,
          orgType: recipient.orgType,
          metadata: {
            'vehicle_id': vehicle.id,
            'vehicle_registration_number': vehicle.vehicleRegistrationNumber,
            'driver_id': driverId,
            'driver_name': driverName,
            'actioned_by': actionedByName,
            'actioned_by_id': actionedById,
          },
        );
      }

      // Also notify the driver
      await _notificationService.createActionedNotification(
        userId: driverId,
        title: 'Vehicle Unassignment',
        message:
            'You have been unassigned from vehicle ${vehicle.vehicleRegistrationNumber}.',
        type: NotificationType.fleetDriverUnassigned,
        companyId: companyId,
        actionedBy: actionedByName,
        actionedById: actionedById,
        metadata: {
          'vehicle_id': vehicle.id,
          'vehicle_registration_number': vehicle.vehicleRegistrationNumber,
        },
      );
      return true;
    } catch (e) {
      _logger.e('Error creating driver unassigned notification', e);
      return false;
    }
  }

  /// Create a notification when a vehicle's status is changed
  /// Returns true if all notifications were sent successfully, false otherwise
  Future<bool> notifyVehicleStatusChanged({
    required String companyId,
    required FleetVehicle vehicle,
    required bool isActive,
    required String actionedById,
    required String actionedByName,
  }) async {
    try {
      // Get all users who should receive this notification
      final recipients = await _getCompanyRecipients(companyId);

      final statusText = isActive ? 'active' : 'inactive';

      // Create notifications for each recipient
      for (final recipient in recipients) {
        await _notificationService.createActionedNotification(
          userId: recipient.userId,
          title: 'Vehicle Status Changed',
          message:
              'Vehicle ${vehicle.vehicleRegistrationNumber} has been marked as $statusText by $actionedByName.',
          type: NotificationType.fleetVehicleStatusChanged,
          companyId: companyId,
          actionedBy: actionedByName,
          actionedById: actionedById,
          roleScope: recipient.roleScope,
          orgType: recipient.orgType,
          metadata: {
            'vehicle_id': vehicle.id,
            'vehicle_registration_number': vehicle.vehicleRegistrationNumber,
            'is_active': isActive,
            'actioned_by': actionedByName,
            'actioned_by_id': actionedById,
          },
        );
      }

      // If the vehicle had a driver and is now inactive, notify the driver
      if (!isActive &&
          vehicle.hasAssignedDriver &&
          vehicle.assignedDriverId != null) {
        await _notificationService.createActionedNotification(
          userId: vehicle.assignedDriverId!,
          title: 'Vehicle Status Changed',
          message:
              'Vehicle ${vehicle.vehicleRegistrationNumber} that was assigned to you has been marked as inactive.',
          type: NotificationType.fleetVehicleStatusChanged,
          companyId: companyId,
          actionedBy: actionedByName,
          actionedById: actionedById,
          metadata: {
            'vehicle_id': vehicle.id,
            'vehicle_registration_number': vehicle.vehicleRegistrationNumber,
            'is_active': isActive,
          },
        );
      }
      return true;
    } catch (e) {
      _logger.e('Error creating vehicle status changed notification', e);
      return false;
    }
  }

  /// Helper method to get all users in a company who should receive notifications
  Future<List<_NotificationRecipient>> _getCompanyRecipients(
    String companyId,
  ) async {
    final recipients = <_NotificationRecipient>[];

    try {
      // Get company owner
      final company = await _companyService.getCompanyById(companyId);
      recipients.add(
        _NotificationRecipient(
          userId: company.userId,
          roleScope: null, // Company owner sees all notifications
          orgType: company.orgType.name,
        ),
      );

      // Get management and admin employees
      final employeesData = await _employeeService.getEmployeesByCompanyId(
        companyId,
      );
      for (final employeeData in employeesData) {
        // Convert the Map to an Employee object
        final employee = Employee.fromJson(employeeData);

        // Only include employees with roles that should see notifications
        if (employee.role == UserRole.management ||
            employee.role == UserRole.admin) {
          recipients.add(
            _NotificationRecipient(
              userId: employee.userId,
              roleScope: employee.role?.name,
              orgType: company.orgType.name,
            ),
          );
        }
      }
    } catch (e) {
      _logger.e('Error getting notification recipients', e);
    }

    return recipients;
  }
}

/// Helper class to store recipient information
class _NotificationRecipient {
  final String userId;
  final String? roleScope;
  final String? orgType;

  _NotificationRecipient({required this.userId, this.roleScope, this.orgType});
}

/// Provider for the FleetNotificationService
final fleetNotificationServiceProvider = Provider<FleetNotificationService>((
  ref,
) {
  return FleetNotificationService(
    ref.watch(notificationServiceProvider),
    ref.watch(employeeServiceProvider),
    ref.watch(companyServiceProvider),
  );
});
