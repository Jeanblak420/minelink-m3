import 'package:flutter_application_1/features/auth/models/user_type.dart';

/// Enum representing the different stages of employee approval process.
///
/// The dismissal stages (`dismissalInitiated`, `dismissalAppeal`,
/// `dismissalFinalDecision`, `accountDeletionScheduled`) were removed with the
/// dismissal feature — client ruling, 2026-08-11. `employee_status_history`
/// holds 0 rows in any of those states and, since migration `20260811180000`
/// dropped the three dismissal RPCs, nothing can write one. The four values
/// remain in `employee_status_history_status_check` and are catalogued for
/// removal in To-Do's.md P12-28, which needs the client.
enum EmployeeApprovalStatus {
  requestSent,
  requestViewed,
  employeeApproved,
  roleAssigned,
  requestDeclined;

  /// Canonical database value for this status.
  /// The app still keeps the legacy enum symbols for compatibility with older code paths,
  /// but all persistence should use these snake_case values.
  String get dbValue {
    switch (this) {
      case EmployeeApprovalStatus.requestSent:
        return 'company_requested';
      case EmployeeApprovalStatus.requestViewed:
      case EmployeeApprovalStatus.employeeApproved:
        return 'request_approved';
      case EmployeeApprovalStatus.roleAssigned:
        return 'role_assigned';
      case EmployeeApprovalStatus.requestDeclined:
        return 'request_declined';
    }
  }

  /// Parse a status from the canonical database values, while still accepting legacy names.
  static EmployeeApprovalStatus fromDbValue(String? value) {
    final normalized = (value ?? '').trim();

    switch (normalized) {
      case 'company_requested':
      case 'requestSent':
        return EmployeeApprovalStatus.requestSent;
      case 'request_approved':
      case 'requestViewed':
      case 'employeeApproved':
        return EmployeeApprovalStatus.employeeApproved;
      case 'role_assigned':
      case 'roleAssigned':
        return EmployeeApprovalStatus.roleAssigned;
      case 'request_declined':
      case 'requestDeclined':
        return EmployeeApprovalStatus.requestDeclined;
      default:
        return EmployeeApprovalStatus.requestSent;
    }
  }

  String get label {
    switch (this) {
      case EmployeeApprovalStatus.requestSent:
        return 'Company request submitted';
      case EmployeeApprovalStatus.requestViewed:
        return 'Request approved';
      case EmployeeApprovalStatus.employeeApproved:
        return 'Request approved';
      case EmployeeApprovalStatus.roleAssigned:
        return 'Role assigned';
      case EmployeeApprovalStatus.requestDeclined:
        return 'Request declined';
    }
  }

  String get description {
    switch (this) {
      case EmployeeApprovalStatus.requestSent:
        return 'Your company request has been submitted and is waiting for approval.';
      case EmployeeApprovalStatus.requestViewed:
        return 'Your request has been approved and is waiting for role assignment.';
      case EmployeeApprovalStatus.employeeApproved:
        return 'Your request has been approved and is waiting for role assignment.';
      case EmployeeApprovalStatus.roleAssigned:
        return 'Your role has been assigned and you can now use the app.';
      case EmployeeApprovalStatus.requestDeclined:
        return 'Your company request has been declined. You may select another company.';
    }
  }
}

/// Model for tracking employee status history
class EmployeeStatusHistory {
  final String id;
  final String employeeId;
  final String? companyId;
  final EmployeeApprovalStatus status;
  final String statusKey;
  final DateTime timestamp;
  final String? actionedById;
  final String? actionedByName;
  final UserRole? assignedRole;

  EmployeeStatusHistory({
    required this.id,
    required this.employeeId,
    this.companyId,
    required this.status,
    String? statusKey,
    required this.timestamp,
    this.actionedById,
    this.actionedByName,
    this.assignedRole,
  }) : statusKey = statusKey ?? status.dbValue;

  factory EmployeeStatusHistory.fromJson(Map<String, dynamic> json) {
    final statusKey = (json['status'] ?? '').toString();
    return EmployeeStatusHistory(
      id: json['id'],
      employeeId: json['employee_id'],
      companyId: json['company_id'],
      status: EmployeeApprovalStatus.fromDbValue(statusKey),
      statusKey: statusKey,
      timestamp: DateTime.parse(json['timestamp']),
      actionedById: json['actioned_by_id'],
      actionedByName: json['actioned_by_name'],
      assignedRole: UserRole.tryParse(json['assigned_role'] as String?),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'employee_id': employeeId,
      'company_id': companyId,
      'status': statusKey.isNotEmpty ? statusKey : status.dbValue,
      'timestamp': timestamp.toIso8601String(),
      'actioned_by_id': actionedById,
      'actioned_by_name': actionedByName,
      'assigned_role': assignedRole?.name,
    };
  }

  bool get isCompanyRequested =>
      statusKey == 'company_requested' ||
      status == EmployeeApprovalStatus.requestSent;

  bool get isRequestApproved =>
      statusKey == 'request_approved' ||
      status == EmployeeApprovalStatus.employeeApproved ||
      status == EmployeeApprovalStatus.requestViewed;

  bool get isRequestDeclined =>
      statusKey == 'request_declined' ||
      status == EmployeeApprovalStatus.requestDeclined;

  bool get isRoleAssigned =>
      statusKey == 'role_assigned' ||
      status == EmployeeApprovalStatus.roleAssigned;

  String get displayTitle {
    switch (statusKey) {
      case 'company_requested':
        return 'Company Request Submitted';
      case 'request_approved':
        return 'Request Approved';
      case 'request_declined':
        return 'Request Declined';
      case 'role_assigned':
        return 'Role Assigned';
      default:
        return status.label;
    }
  }

  String get displayDescription {
    switch (statusKey) {
      case 'company_requested':
        return 'The employee has requested to join the company.';
      case 'request_approved':
        return 'The company approved the request and is assigning a role.';
      case 'request_declined':
        return 'The company declined the request to join.';
      case 'role_assigned':
        return 'A role has been assigned and the employee can use the app.';
      default:
        return status.description;
    }
  }
}
