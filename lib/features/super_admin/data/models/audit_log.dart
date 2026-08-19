/// Represents a platform audit log entry
class AuditLog {
  final String id;
  final String actorUserId;
  final String actorEmail;
  final String actorPlatformRole;
  final String actionType;
  final String targetType;
  final String? targetId;
  final String? targetName;
  final String? organizationId;
  final String? organizationName;
  final String? organizationType;
  final String description;
  final Map<String, dynamic>? beforeData;
  final Map<String, dynamic>? afterData;
  final String? ipAddress;
  final String? deviceInfo;
  final DateTime createdAt;

  const AuditLog({
    required this.id,
    required this.actorUserId,
    required this.actorEmail,
    required this.actorPlatformRole,
    required this.actionType,
    required this.targetType,
    this.targetId,
    this.targetName,
    this.organizationId,
    this.organizationName,
    this.organizationType,
    required this.description,
    this.beforeData,
    this.afterData,
    this.ipAddress,
    this.deviceInfo,
    required this.createdAt,
  });

  factory AuditLog.fromJson(Map<String, dynamic> json) {
    return AuditLog(
      id: json['id'] as String,
      actorUserId: json['actor_user_id'] as String? ?? '',
      actorEmail: json['actor_email'] as String? ?? '',
      actorPlatformRole: json['actor_platform_role'] as String? ?? '',
      actionType: json['action_type'] as String,
      targetType: json['target_type'] as String,
      targetId: json['target_id'] as String?,
      targetName: json['target_name'] as String?,
      organizationId: json['organization_id'] as String?,
      organizationName: json['organization_name'] as String?,
      organizationType: json['organization_type'] as String?,
      description: json['description'] as String,
      beforeData: json['before_data'] as Map<String, dynamic>?,
      afterData: json['after_data'] as Map<String, dynamic>?,
      ipAddress: json['ip_address'] as String?,
      deviceInfo: json['device_info'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

/// Standard audit action types
class AuditActionTypes {
  static const String tokenGenerated = 'TOKEN_GENERATED';
  static const String tokenRevoked = 'TOKEN_REVOKED';
  static const String tokenExpired = 'TOKEN_EXPIRED';
  static const String companySuspended = 'COMPANY_SUSPENDED';
  static const String companyReactivated = 'COMPANY_REACTIVATED';
  static const String seatLimitUpdated = 'SEAT_LIMIT_UPDATED';
  static const String seatRequestApproved = 'SEAT_REQUEST_APPROVED';
  static const String seatRequestRejected = 'SEAT_REQUEST_REJECTED';
  static const String userAssignedToSeat = 'USER_ASSIGNED_TO_SEAT';
  static const String userRemovedFromSeat = 'USER_REMOVED_FROM_SEAT';
  static const String organizationProfileUpdated = 'ORGANIZATION_PROFILE_UPDATED';
  static const String tokenRequestSubmitted = 'TOKEN_REQUEST_SUBMITTED';
  static const String tokenRequestClaimed = 'TOKEN_REQUEST_CLAIMED';
  static const String tokenRequestReleased = 'TOKEN_REQUEST_RELEASED';
  static const String tokenRequestApproved = 'TOKEN_REQUEST_APPROVED';
  static const String tokenRequestRejected = 'TOKEN_REQUEST_REJECTED';

  /// Actions shown on the Token history screen (per org-type tab).
  static const List<String> tokenHistoryActions = [
    tokenGenerated,
    tokenRevoked,
    tokenExpired,
    seatLimitUpdated,
    seatRequestApproved,
    seatRequestRejected,
    tokenRequestSubmitted,
    tokenRequestClaimed,
    tokenRequestReleased,
    tokenRequestApproved,
    tokenRequestRejected,
  ];
}
