import 'package:flutter/material.dart';
import 'package:flutter_application_1/features/auth/models/user_type.dart';
import 'package:flutter_application_1/core/design/tokens/ml_tokens.dart';
import 'package:flutter_application_1/core/utils/ml_count.dart';

enum NotificationType {
  employeeRequest,
  roleAssigned,
  requestDeclined,
  roleConfirmation,
  profileUpdate,
  userManagement,
  securityAlert,
  controllerAction,
  adminAction,
  managementAction,
  fleetVehicleAdded,
  fleetDriverAssigned,
  fleetDriverUnassigned,
  fleetVehicleStatusChanged,
  tokenExpiringSoon,
  tokenRequestCreated,
  tokenRequestClaimed,
  tokenRequestReleased,
  tokenRequestHandled,

  /// A weight reconciliation event on a trip: a material variance surfaced at
  /// completion, a dispute raised, a reply on one, or a resolution (P8-30).
  /// Wire string is `recon_dispute` — see [fromString] on why the two differ.
  reconDispute,
  general;

  /// Convert a stored `notifications.type` string to a [NotificationType].
  ///
  /// ⚠ **The wire strings are not all camelCase.** This table carries both
  /// conventions and always has: `userManagement` and `tokenExpiringSoon` sit
  /// alongside `stockpile_prepare`, `truck_checked_in`, `truck_loaded`,
  /// `stockpile_depleted` and `recon_dispute`. The camelCase ones came from
  /// Dart, the snake_case ones from the SQL workflow functions.
  ///
  /// The match is therefore made on a normalised form — case-folded with
  /// separators removed — so `recon_dispute` resolves to [reconDispute]. An
  /// exact `e.name == value` comparison silently sent every snake_case type to
  /// [general], which is why a high-importance weight discrepancy would have
  /// arrived looking like any other message.
  ///
  /// ⬜ **Still falling through to [general], and deliberately not invented
  /// here:** `stockpile_prepare`, `truck_checked_in`, `truck_loaded` and
  /// `stockpile_depleted` (16 live rows). They have no enum member, and adding
  /// four members with guessed icons and role-relevance is P10-14's job, not
  /// this change's. Recorded in To-Do's.md so it is a known gap rather than a
  /// silent one.
  static NotificationType fromString(String? value) {
    if (value == null) return NotificationType.general;

    String normalise(String s) =>
        s.toLowerCase().replaceAll(RegExp(r'[_\-\s]'), '');

    final target = normalise(value);
    for (final e in NotificationType.values) {
      if (normalise(e.name) == target) return e;
    }
    return NotificationType.general;
  }

  String get label {
    switch (this) {
      case NotificationType.employeeRequest:
        return 'Employee Request';
      case NotificationType.roleAssigned:
        return 'Role Assigned';
      case NotificationType.requestDeclined:
        return 'Request Declined';
      case NotificationType.roleConfirmation:
        return 'Role Confirmation';
      case NotificationType.profileUpdate:
        return 'Profile Update';
      case NotificationType.userManagement:
        return 'User Management';
      case NotificationType.securityAlert:
        return 'Security Alert';
      case NotificationType.controllerAction:
        return 'Controller Action';
      case NotificationType.adminAction:
        return 'Admin Action';
      case NotificationType.managementAction:
        return 'Management Action';
      case NotificationType.fleetVehicleAdded:
        return 'Vehicle Added';
      case NotificationType.fleetDriverAssigned:
        return 'Driver Assigned';
      case NotificationType.fleetDriverUnassigned:
        return 'Driver Unassigned';
      case NotificationType.fleetVehicleStatusChanged:
        return 'Vehicle Status Changed';
      case NotificationType.tokenExpiringSoon:
        return 'Token expiring soon';
      case NotificationType.tokenRequestCreated:
        return 'Token request';
      case NotificationType.tokenRequestClaimed:
        return 'Token request in progress';
      case NotificationType.tokenRequestReleased:
        return 'Token request released';
      case NotificationType.tokenRequestHandled:
        return 'Token request update';
      case NotificationType.reconDispute:
        return 'Weight reconciliation';
      case NotificationType.general:
        return 'General';
    }
  }

  /// Determines if this notification type is relevant for a specific role
  bool isRelevantForRole(UserRole? role) {
    if (role == null) return false;

    switch (this) {
      case NotificationType.securityAlert:
        return role == UserRole.security ||
            role == UserRole.admin ||
            role == UserRole.management;
      case NotificationType.controllerAction:
        return role == UserRole.controllerWB ||
            role == UserRole.admin ||
            role == UserRole.management;
      case NotificationType.adminAction:
        return role == UserRole.admin || role == UserRole.management;
      case NotificationType.managementAction:
        return role == UserRole.management;
      // Fleet notifications are relevant for management, admin, and drivers
      case NotificationType.fleetVehicleAdded:
      case NotificationType.fleetVehicleStatusChanged:
        return role == UserRole.management || role == UserRole.admin;
      case NotificationType.fleetDriverAssigned:
      case NotificationType.fleetDriverUnassigned:
        return role == UserRole.management ||
            role == UserRole.admin ||
            role == UserRole.driver;
      case NotificationType.tokenExpiringSoon:
      case NotificationType.tokenRequestCreated:
      case NotificationType.tokenRequestClaimed:
      case NotificationType.tokenRequestReleased:
      case NotificationType.tokenRequestHandled:
        return true;
      // A weight discrepancy is a commercial matter for the people who answer
      // for the load, not for the gate or the weighbridge floor. The server
      // already addresses these to owner + admin + management only
      // (notify_company_management); this keeps the client's role filter from
      // widening what the server deliberately narrowed.
      case NotificationType.reconDispute:
        return role == UserRole.admin || role == UserRole.management;
      // These notification types are relevant for all roles
      case NotificationType.employeeRequest:
      case NotificationType.roleAssigned:
      case NotificationType.requestDeclined:
      case NotificationType.roleConfirmation:
      case NotificationType.profileUpdate:
      case NotificationType.userManagement:
      case NotificationType.general:
        return true;
    }
  }
}

enum NotificationImportance {
  normal,
  high,
  extreme;

  /// Convert string to NotificationImportance
  static NotificationImportance fromString(String? value) {
    if (value == null) return NotificationImportance.normal;

    try {
      return NotificationImportance.values.firstWhere(
        (e) => e.name == value,
        orElse: () => NotificationImportance.normal,
      );
    } catch (e) {
      return NotificationImportance.normal;
    }
  }

  String get label {
    switch (this) {
      case NotificationImportance.normal:
        return 'Normal';
      case NotificationImportance.high:
        return 'High';
      case NotificationImportance.extreme:
        return 'EXTREME IMPORTANCE';
    }
  }

  Color get color {
    switch (this) {
      case NotificationImportance.normal:
        return MlTokens.blue600;
      case NotificationImportance.high:
        return MlTokens.orange500;
      case NotificationImportance.extreme:
        return MlTokens.red600;
    }
  }
}

class AppNotification {
  final String id;
  final String userId;
  final String? companyId;
  final String? employeeId;
  final String title;
  final String message;
  final NotificationType type;
  final bool isRead;
  final DateTime createdAt;
  final String?
  actionedBy; // Full name of user who performed the action (Step 26)
  final String? actionedById; // ID of user who performed the action
  final String? roleScope; // Which role(s) should see this notification
  final String? orgType; // Organization type for filtering (Step 19)
  final NotificationImportance
  importance; // Importance level of the notification
  final Map<String, dynamic>? metadata;

  AppNotification({
    required this.id,
    required this.userId,
    this.companyId,
    this.employeeId,
    required this.title,
    required this.message,
    required this.type,
    this.isRead = false,
    required this.createdAt,
    this.actionedBy,
    this.actionedById,
    this.roleScope,
    this.orgType,
    this.importance = NotificationImportance.normal,
    this.metadata,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'],
      userId: json['user_id'],
      companyId: json['company_id'],
      employeeId: json['employee_id'],
      title: json['title'],
      // Repaired on the way in, not at each render site. The collect alert is
      // composed in Postgres and stored finished — "2 full load(s) ready" —
      // and `supabase/` is frozen in this fork, so this is the boundary where
      // the app can fix it once for every surface that shows a notification.
      message: mlRepairParentheticalPlural(json['message'] as String? ?? ''),
      type: NotificationType.fromString(json['type']),
      isRead: json['is_read'] ?? false,
      createdAt: DateTime.parse(json['created_at']),
      actionedBy: json['actioned_by'],
      actionedById: json['actioned_by_id'],
      roleScope: json['role_scope'],
      orgType: json['org_type'],
      importance: NotificationImportance.fromString(json['importance']),
      metadata: json['metadata'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'company_id': companyId,
      'employee_id': employeeId,
      'title': title,
      'message': message,
      'type': type.name,
      'is_read': isRead,
      'created_at': createdAt.toIso8601String(),
      'actioned_by': actionedBy,
      'actioned_by_id': actionedById,
      'role_scope': roleScope,
      'org_type': orgType,
      'importance': importance.name,
      'metadata': metadata,
    };
  }

  AppNotification copyWith({
    String? id,
    String? userId,
    String? companyId,
    String? employeeId,
    String? title,
    String? message,
    NotificationType? type,
    bool? isRead,
    DateTime? createdAt,
    String? actionedBy,
    String? actionedById,
    String? roleScope,
    String? orgType,
    NotificationImportance? importance,
    Map<String, dynamic>? metadata,
  }) {
    return AppNotification(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      companyId: companyId ?? this.companyId,
      employeeId: employeeId ?? this.employeeId,
      title: title ?? this.title,
      message: message ?? this.message,
      type: type ?? this.type,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
      actionedBy: actionedBy ?? this.actionedBy,
      actionedById: actionedById ?? this.actionedById,
      roleScope: roleScope ?? this.roleScope,
      orgType: orgType ?? this.orgType,
      importance: importance ?? this.importance,
      metadata: metadata ?? this.metadata,
    );
  }
}
