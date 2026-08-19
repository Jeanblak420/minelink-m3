import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_application_1/core/config/supabase_config.dart';
import 'package:flutter_application_1/core/utils/logger.dart';
import 'package:flutter_application_1/features/auth/models/user_type.dart';
import 'package:flutter_application_1/features/company/models/company_model.dart';
import 'package:flutter_application_1/features/employee/models/employee_model.dart';
import 'package:flutter_application_1/features/notifications/models/notification_model.dart';
import 'package:flutter_application_1/features/notifications/services/notification_validator.dart';
import 'package:flutter_application_1/core/time/ml_time.dart';

class NotificationService {
  final _supabase = SupabaseConfig.client;
  final _uuid = const Uuid();
  final Logger _logger = LoggerFactory.getLogger('NotificationService');

  Future<List<AppNotification>> getNotificationsForUser(String userId) async {
    try {
      final response = await _supabase
          .from('notifications')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => AppNotification.fromJson(json))
          .toList();
    } catch (e) {
      // Rethrow so the provider sets its error state and the inbox's error +
      // Retry UI fires, instead of a failed query looking like "no notifications".
      _logger.e('Error fetching notifications', e);
      rethrow;
    }
  }

  /// The caller's inbox, via the `list_my_notifications` RPC (S8-7 / P10-13).
  ///
  /// This used to be `.eq('user_id', userId)` plus a client-side role filter,
  /// which made the hierarchy a **narrowing filter on rows you had already been
  /// sent** — so "management sees everyone below them" only held where the
  /// sender happened to write management a copy. Measured on production:
  /// `truck_checked_in` and `truck_loaded` reached exactly one person, so
  /// management never saw them. No client-side filter can fix a row that was
  /// never written.
  ///
  /// The server now decides entitlement and returns **one row per event**,
  /// deduplicating the copies a fanned-out event produces. The role hierarchy
  /// lives only in `notification_scopes_for_role()`; keeping a second copy here
  /// is what let the two drift in the first place.
  ///
  /// [role] and [orgType] are retained for call-site compatibility and are no
  /// longer used to filter — the caller's identity is resolved server-side,
  /// where it cannot be spoofed by passing someone else's role.
  Future<List<AppNotification>> getNotificationsForManagementScreen(
    String userId,
    UserRole? role,
    OrgType? orgType,
  ) async {
    try {
      final response = await _supabase.rpc('list_my_notifications');
      return ((response as List?) ?? const [])
          .map((json) =>
              AppNotification.fromJson(Map<String, dynamic>.from(json as Map)))
          .toList();
    } catch (e) {
      _logger.e('Error fetching notifications for management screen', e);
      rethrow;
    }
  }

  Future<int> getUnreadNotificationsCount(String userId) async {
    try {
      final response = await _supabase
          .from('notifications')
          .select('id')
          .eq('user_id', userId)
          .eq('is_read', false);
      return (response as List).length;
    } catch (e) {
      _logger.e('Error fetching unread notifications count', e);
      return 0;
    }
  }

  Future<void> markNotificationReadStatus(
    String notificationId,
    bool isRead,
  ) async {
    try {
      await _supabase.rpc(
        'set_notification_read',
        params: {
          'target_notification_id': notificationId,
          'read_state': isRead,
        },
      );
    } catch (e) {
      _logger.e('Error updating notification read status', e);
    }
  }

  Future<void> markNotificationAsRead(String notificationId) async {
    await markNotificationReadStatus(notificationId, true);
  }

  Future<void> markAllNotificationsAsRead(String userId) async {
    try {
      await _supabase.rpc('mark_all_notifications_read');
    } catch (e) {
      _logger.e('Error marking all notifications as read', e);
    }
  }

  Future<void> _createNotificationViaRpc({
    required String userId,
    required String title,
    required String message,
    required NotificationType type,
    String? companyId,
    String? employeeId,
    String? actionedBy,
    String? actionedById,
    String? roleScope,
    String? orgType,
    NotificationImportance importance = NotificationImportance.normal,
    Map<String, dynamic>? metadata,
  }) async {
    final validatedJson = await NotificationValidator.validateNotification({
      'id': _uuid.v4(),
      'user_id': userId,
      'company_id': companyId,
      'employee_id': employeeId,
      'title': title,
      'message': message,
      'type': type.name,
      'is_read': false,
      'created_at': DateTime.now().toUtc().toIso8601String(),
      'actioned_by': actionedBy,
      'actioned_by_id': actionedById,
      'role_scope': roleScope,
      'org_type': orgType,
      'importance': importance.name,
      'metadata': metadata ?? <String, dynamic>{},
    });

    await _supabase.rpc(
      'create_actioned_notification',
      params: {
        'target_user_id': validatedJson['user_id'],
        'notification_title': validatedJson['title'],
        'notification_message': validatedJson['message'],
        'notification_type': validatedJson['type'],
        'target_company_id': validatedJson['company_id'],
        'target_employee_id': validatedJson['employee_id'],
        'notification_actioned_by': validatedJson['actioned_by'],
        'notification_actioned_by_id': validatedJson['actioned_by_id'],
        'notification_role_scope': validatedJson['role_scope'],
        'notification_org_type': validatedJson['org_type'],
        'notification_importance': validatedJson['importance'],
        'notification_metadata': validatedJson['metadata'],
      },
    );
  }

  Future<void> createNotificationFromJson(
    Map<String, dynamic> notificationJson,
  ) async {
    await _createNotificationViaRpc(
      userId: notificationJson['user_id'] as String,
      title: notificationJson['title'] as String,
      message: notificationJson['message'] as String,
      type: NotificationType.fromString(notificationJson['type']),
      companyId: notificationJson['company_id'] as String?,
      employeeId: notificationJson['employee_id'] as String?,
      actionedBy: notificationJson['actioned_by'] as String?,
      actionedById: notificationJson['actioned_by_id'] as String?,
      roleScope: notificationJson['role_scope'] as String?,
      orgType: notificationJson['org_type'] as String?,
      importance: NotificationImportance.fromString(
        notificationJson['importance'] as String?,
      ),
      metadata: Map<String, dynamic>.from(
        (notificationJson['metadata'] as Map?) ?? const <String, dynamic>{},
      ),
    );
  }

  Future<void> createEmployeeRequestNotification({
    required String companyId,
    required String companyUserId,
    required Employee employee,
  }) async {
    try {
      await createActionedNotification(
        userId: companyUserId,
        companyId: companyId,
        employeeId: employee.id,
        title: 'New Employee Request',
        message: '${employee.fullName} has requested to join your company.',
        type: NotificationType.employeeRequest,
        actionedBy: employee.fullName,
        actionedById: employee.userId,
        metadata: {
          'employee_id': employee.id,
          'employee_name': employee.fullName,
          'timestamp': DateTime.now().toUtc().toIso8601String(),
        },
      );
    } catch (e) {
      _logger.e('Error creating employee request notification', e);
    }
  }

  Future<void> createRoleAssignedNotification({
    required String employeeId,
    required String employeeUserId,
    required Company company,
    required String roleName,
  }) async {
    try {
      await createActionedNotification(
        userId: employeeUserId,
        companyId: company.id,
        employeeId: employeeId,
        title: 'Role Assigned',
        message:
            'You have been assigned the $roleName role at ${company.companyName}.',
        type: NotificationType.roleAssigned,
        orgType: company.orgType.name,
        importance: NotificationImportance.high,
        metadata: {
          'company_id': company.id,
          'company_name': company.companyName,
          'role_name': roleName,
        },
      );
    } catch (e) {
      _logger.e('Error creating role assigned notification', e);
    }
  }

  Future<void> createRequestDeclinedNotification({
    required String employeeId,
    required String employeeUserId,
    required Company company,
  }) async {
    try {
      await createActionedNotification(
        userId: employeeUserId,
        companyId: company.id,
        employeeId: employeeId,
        title: 'Request Declined',
        message:
            'Oops! ${company.companyName} has declined your request to join their company. If this was an error, please contact management or re-select the company you are employed with.',
        type: NotificationType.requestDeclined,
        orgType: company.orgType.name,
        importance: NotificationImportance.high,
        metadata: {
          'company_id': company.id,
          'company_name': company.companyName,
        },
      );
    } catch (e) {
      _logger.e('Error creating request declined notification', e);
    }
  }

  Future<void> createRoleConfirmationNotification({
    required String companyUserId,
    required String companyId,
    required String employeeId,
    required String employeeName,
    required String roleName,
  }) async {
    try {
      await createActionedNotification(
        userId: companyUserId,
        companyId: companyId,
        employeeId: employeeId,
        title: 'Role Assigned Confirmation',
        message:
            'You have successfully assigned the $roleName role to $employeeName.',
        type: NotificationType.roleConfirmation,
        metadata: {
          'employee_id': employeeId,
          'employee_name': employeeName,
          'role_name': roleName,
        },
      );
    } catch (e) {
      _logger.e('Error creating role confirmation notification', e);
    }
  }

  @Deprecated(
    'Use markNotificationReadStatus instead - notifications should not be deleted from the database',
  )
  Future<void> deleteNotification(String notificationId) async {
    _logger.w(
      'Attempted to delete notification $notificationId. Operation blocked.',
    );
  }

  Future<void> createActionedNotification({
    required String userId,
    required String title,
    required String message,
    required NotificationType type,
    String? companyId,
    String? employeeId,
    String? actionedBy,
    String? actionedById,
    String? roleScope,
    String? orgType,
    NotificationImportance importance = NotificationImportance.normal,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final isValidUser = await NotificationValidator.isValidUserId(userId);
      if (!isValidUser) {
        _logger.w('Cannot create notification: User ID $userId does not exist');
        return;
      }

      await _createNotificationViaRpc(
        userId: userId,
        title: title,
        message: message,
        type: type,
        companyId: companyId,
        employeeId: employeeId,
        actionedBy: actionedBy,
        actionedById: actionedById,
        roleScope: roleScope,
        orgType: orgType,
        importance: importance,
        metadata: metadata,
      );
    } catch (e) {
      _logger.e('Error creating actioned notification', e);
    }
  }

  Future<void> createProfileUpdateNotification({
    required String updatedUserId,
    required String updaterUserId,
    required String updaterName,
    required String updatedUserName,
    required String fieldUpdated,
  }) async {
    try {
      final isSelfUpdate = updatedUserId == updaterUserId;
      final updatedOrgType = await _getOrgTypeFromUserId(updatedUserId);
      final updaterOrgType = isSelfUpdate
          ? updatedOrgType
          : await _getOrgTypeFromUserId(updaterUserId);

      if (isSelfUpdate) {
        await createActionedNotification(
          userId: updatedUserId,
          title: 'Profile Update',
          message: 'You changed your $fieldUpdated',
          type: NotificationType.profileUpdate,
          orgType: updatedOrgType,
        );
        return;
      }

      await createActionedNotification(
        userId: updatedUserId,
        title: 'Profile Update',
        message: '$updaterName changed your $fieldUpdated',
        type: NotificationType.profileUpdate,
        actionedBy: updaterName,
        actionedById: updaterUserId,
        orgType: updatedOrgType,
      );

      await createActionedNotification(
        userId: updaterUserId,
        title: 'User Management',
        message: '$updaterName changed $updatedUserName\'s $fieldUpdated',
        type: NotificationType.userManagement,
        roleScope: UserRole.admin.name,
        actionedBy: updaterName,
        actionedById: updaterUserId,
        orgType: updaterOrgType,
      );
    } catch (e) {
      _logger.e('Error creating profile update notification', e);
    }
  }

  /// Notification time on the clock at the mine.
  ///
  /// This has now been three things. It started as
  /// `utcTime.add(const Duration(hours: 2))` — SAST hardcoded as arithmetic,
  /// which produced a value still flagged UTC, so `DateFormat` formatted a
  /// shifted instant as though no shift had happened.
  ///
  /// It was then `toLocal()`, argued for on the grounds that MineLink might one
  /// day operate outside South Africa. Jean settled that on 2026-08-17: it does
  /// not, and one basis is what the product needs. `toLocal()` also made the
  /// screen's own claim — "All timestamps use UTC+02:00 Harare, Pretoria" —
  /// false for anyone whose device said otherwise.
  ///
  /// [MlTime] is the third and, unlike the first, is both correct and honestly
  /// typed: it returns a wall clock, not a shifted instant wearing a UTC flag.
  /// If MineLink ever does leave South Africa, `ml_time.dart` is the one edit.
  String formatTimestamp(DateTime timestamp) =>
      DateFormat('MMM d, yyyy, h:mm a').format(MlTime.sast(timestamp));

  Future<String?> _getOrgTypeFromUserId(String userId) async {
    try {
      final company = await _supabase
          .from('companies')
          .select('org_type')
          .eq('user_id', userId)
          .maybeSingle();

      final companyOrgType = company?['org_type'] as String?;
      if (companyOrgType != null && companyOrgType.isNotEmpty) {
        return companyOrgType;
      }

      final employee = await _supabase
          .from('employees')
          .select('company_id')
          .eq('user_id', userId)
          .maybeSingle();

      final companyId = employee?['company_id'] as String?;
      if (companyId == null || companyId.isEmpty) {
        return null;
      }

      final employeeCompany = await _supabase
          .from('companies')
          .select('org_type')
          .eq('id', companyId)
          .maybeSingle();

      return employeeCompany?['org_type'] as String?;
    } catch (e) {
      _logger.w('Could not resolve org type for user $userId: $e');
      return null;
    }
  }

  Future<void> createNotification({
    required String userId,
    required String title,
    required String message,
    required NotificationType type,
    String? companyId,
    String? employeeId,
    String? actionedBy,
    String? actionedById,
    NotificationImportance importance = NotificationImportance.normal,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      await createActionedNotification(
        userId: userId,
        title: title,
        message: message,
        type: type,
        companyId: companyId,
        employeeId: employeeId,
        actionedBy: actionedBy,
        actionedById: actionedById,
        importance: importance,
        metadata: {...?metadata, 'timestamp': DateTime.now().toUtc().toIso8601String()},
      );
    } catch (e) {
      _logger.e('Error creating notification', e);
    }
  }
}

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});
