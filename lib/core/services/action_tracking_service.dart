import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_application_1/features/notifications/services/notification_service.dart';
import 'package:flutter_application_1/features/notifications/models/notification_model.dart';
import 'package:flutter_application_1/features/auth/models/user_type.dart';
import 'package:flutter_application_1/features/employee/services/employee_service.dart';
import 'package:flutter_application_1/features/company/services/company_service.dart';
import 'package:flutter_application_1/features/employee/models/employee_model.dart';
import 'package:flutter_application_1/features/auth/models/app_user.dart';
import 'package:flutter_application_1/core/utils/logger.dart';
import 'package:flutter_application_1/core/time/ml_time.dart';

/// Service for tracking user actions and automatically creating notifications
class ActionTrackingService {
  final NotificationService _notificationService;
  final EmployeeService _employeeService;
  final CompanyService _companyService;
  final _logger = LoggerFactory.getLogger('ActionTrackingService');

  ActionTrackingService(
    this._notificationService,
    this._employeeService,
    this._companyService,
  );

  /// Track a user action and create appropriate notifications
  ///
  /// Parameters:
  /// - actionType: The type of action being performed (use NotificationType)
  /// - actionTitle: A short title for the action
  /// - actionDescription: A detailed description of the action
  /// - actionedBy: The user performing the action
  /// - companyId: The company ID related to the action
  /// - targetUserId: Optional - The user ID of the target user (if applicable)
  /// - targetEntityId: Optional - The ID of the target entity (e.g., vehicle ID, employee ID)
  /// - metadata: Optional - Additional data related to the action
  Future<void> trackAction({
    required NotificationType actionType,
    required String actionTitle,
    required String actionDescription,
    required AppUser actionedBy,
    required String companyId,
    String? targetUserId,
    String? targetEntityId,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      // Get all users who should receive this notification based on role
      final recipients = await _getRecipientsForAction(
        actionType: actionType,
        companyId: companyId,
        targetUserId: targetUserId,
      );

      // Create a timestamp for all notifications.
      //
      // `MlTime.instant()`, so the ISO string carries an offset. A device-local
      // DateTime writes a NAIVE string, which Postgres reads in the session
      // zone -- the stamp every audit notification carries in its metadata was
      // two hours out on every SAST device. Found by the split-form rule added
      // to `tool/one_clock_check.py` the same day the chat's send path was
      // fixed for exactly this.
      final formattedTimestamp = MlTime.instant().toIso8601String();

      // Get the user's full name or email
      final actionedByName = actionedBy.fullName.isNotEmpty
          ? actionedBy.fullName
          : actionedBy.email ?? 'Unknown User';

      // Create notifications for each recipient
      for (final recipient in recipients) {
        await _notificationService.createActionedNotification(
          userId: recipient.userId,
          title: actionTitle,
          message: actionDescription,
          type: actionType,
          companyId: companyId,
          actionedBy: actionedByName,
          actionedById: actionedBy.userId,
          roleScope: recipient.roleScope,
          orgType: recipient.orgType,
          metadata: {
            ...?metadata,
            'action_type': actionType.name,
            'actioned_by': actionedBy.userId,
            'actioned_by_name': actionedByName,
            if (targetUserId != null) 'target_user_id': targetUserId,
            if (targetEntityId != null) 'target_entity_id': targetEntityId,
            'timestamp': formattedTimestamp,
          },
        );
      }

      // If there's a specific target user, also send them a notification
      if (targetUserId != null &&
          !recipients.any((r) => r.userId == targetUserId)) {
        await _notificationService.createActionedNotification(
          userId: targetUserId,
          title: actionTitle,
          message: actionDescription,
          type: actionType,
          companyId: companyId,
          actionedBy: actionedByName,
          actionedById: actionedBy.userId,
          metadata: {
            ...?metadata,
            'action_type': actionType.name,
            'actioned_by': actionedBy.userId,
            'actioned_by_name': actionedByName,
            'timestamp': formattedTimestamp,
          },
        );
      }
    } catch (e) {
      // Log error but don't crash the app
      // ignore: avoid_print
      print('Error tracking action: $e');
    }
  }

  /// Get all users who should receive notifications for a specific action
  Future<List<_NotificationRecipient>> _getRecipientsForAction({
    required NotificationType actionType,
    required String companyId,
    String? targetUserId,
  }) async {
    final recipients = <_NotificationRecipient>[];

    try {
      // Get company owner
      final company = await _companyService.getCompanyById(companyId);
      {
        recipients.add(
          _NotificationRecipient(
            userId: company.userId,
            roleScope: null, // Company owner sees all notifications
            orgType: company.orgType.name,
          ),
        );
      }

      // Get employees based on role requirements
      final employeesData = await _employeeService.getEmployeesByCompanyId(
        companyId,
      );

      // Convert Map<String, dynamic> to Employee objects
      for (final employeeData in employeesData) {
        // Convert the map to an Employee object
        final employee = Employee.fromJson(employeeData);

        // Skip the target user if they're an employee (they'll get a direct notification)
        if (employee.userId == targetUserId) continue;

        // Check if this employee should receive the notification based on role
        if (_shouldReceiveNotification(actionType, employee.role)) {
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
      // Log error but don't crash the app
      _logger.e('Error getting notification recipients', e);
    }

    return recipients;
  }

  /// Determine if a user with a specific role should receive a notification
  bool _shouldReceiveNotification(NotificationType actionType, UserRole? role) {
    if (role == null) return false;

    // Management sees everything
    if (role == UserRole.management) return true;

    // Admin sees most things except management-specific actions
    if (role == UserRole.admin) {
      return actionType != NotificationType.managementAction;
    }

    // Controller sees controller-specific actions
    if (role == UserRole.controllerWB) {
      return actionType == NotificationType.controllerAction;
    }

    // Security sees security-specific actions
    if (role == UserRole.security) {
      return actionType == NotificationType.securityAlert;
    }

    // Drivers see driver-specific actions
    if (role == UserRole.driver) {
      return actionType == NotificationType.fleetDriverAssigned ||
          actionType == NotificationType.fleetDriverUnassigned ||
          actionType == NotificationType.fleetVehicleStatusChanged;
    }

    // Default case - regular employees only see actions that directly affect them
    return false;
  }
}

/// Helper class to store recipient information
class _NotificationRecipient {
  final String userId;
  final String? roleScope;
  final String? orgType;

  _NotificationRecipient({required this.userId, this.roleScope, this.orgType});
}

/// Provider for the ActionTrackingService
final actionTrackingServiceProvider = Provider<ActionTrackingService>((ref) {
  return ActionTrackingService(
    ref.watch(notificationServiceProvider),
    ref.watch(employeeServiceProvider),
    ref.watch(companyServiceProvider),
  );
});
