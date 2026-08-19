/// Represents a serial token generated for an organization
class SerialToken {
  final String id;
  final String organizationId;
  final String organizationName;
  final String organizationType;
  final String tokenHash;
  final String tokenPreview;
  final int validDays;
  final DateTime issuedAt;
  final DateTime expiresAt;
  final int seatLimit;
  final String status; // active, expired, revoked, replaced
  final String generatedByUserId;
  final String generatedByEmail;
  final String generatedByPlatformRole;
  final String? revokedBy;
  final DateTime? revokedAt;
  final String? revokeReason;
  final DateTime createdAt;
  final DateTime updatedAt;

  const SerialToken({
    required this.id,
    required this.organizationId,
    required this.organizationName,
    required this.organizationType,
    required this.tokenHash,
    required this.tokenPreview,
    required this.validDays,
    required this.issuedAt,
    required this.expiresAt,
    required this.seatLimit,
    required this.status,
    required this.generatedByUserId,
    required this.generatedByEmail,
    required this.generatedByPlatformRole,
    this.revokedBy,
    this.revokedAt,
    this.revokeReason,
    required this.createdAt,
    required this.updatedAt,
  });

  factory SerialToken.fromJson(Map<String, dynamic> json) {
    return SerialToken(
      id: json['id'] as String,
      organizationId: json['organization_id'] as String,
      organizationName: json['organization_name'] as String,
      organizationType: json['organization_type'] as String,
      tokenHash: json['token_hash'] as String,
      tokenPreview: json['token_preview'] as String,
      validDays: json['valid_days'] as int,
      issuedAt: DateTime.parse(json['issued_at'] as String),
      expiresAt: DateTime.parse(json['expires_at'] as String),
      seatLimit: json['seat_limit'] as int,
      status: json['status'] as String,
      generatedByUserId: json['generated_by_user_id'] as String,
      generatedByEmail: json['generated_by_email'] as String,
      generatedByPlatformRole: json['generated_by_platform_role'] as String,
      revokedBy: json['revoked_by'] as String?,
      revokedAt: json['revoked_at'] != null
          ? DateTime.parse(json['revoked_at'] as String)
          : null,
      revokeReason: json['revoke_reason'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  bool get isActive => status == 'active';
  bool get isExpired => status == 'expired' || expiresAt.isBefore(DateTime.now());

  int get daysRemaining {
    final remaining = expiresAt.difference(DateTime.now()).inDays;
    return remaining < 0 ? 0 : remaining;
  }

  bool get isExpiringSoon => daysRemaining <= 7 && daysRemaining > 0;
}
