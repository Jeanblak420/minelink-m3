import 'package:flutter_application_1/features/auth/models/user_type.dart';

/// Company token / seat request (platform queue).
class TokenRequest {
  final String id;
  final String organizationId;
  final String organizationName;
  final String organizationType;
  final String requestKind;
  final int currentSeatLimit;
  final int currentSeatsUsed;
  final int requestedExtraSeats;
  final int requestedNewTotal;
  final String reason;
  final String requestedByUserId;
  final String requestedByEmail;
  final String status;
  final String? currentTokenId;
  final int? requestedValidDays;
  final String? handlingUserId;
  final DateTime? handlingStartedAt;
  final String? handlingDisplayName;
  final String? reviewedByUserId;
  final String? reviewedByEmail;
  final DateTime? reviewedAt;
  final String? reviewNote;
  final DateTime createdAt;
  final DateTime updatedAt;

  const TokenRequest({
    required this.id,
    required this.organizationId,
    required this.organizationName,
    required this.organizationType,
    required this.requestKind,
    required this.currentSeatLimit,
    required this.currentSeatsUsed,
    required this.requestedExtraSeats,
    required this.requestedNewTotal,
    required this.reason,
    required this.requestedByUserId,
    required this.requestedByEmail,
    required this.status,
    this.currentTokenId,
    this.requestedValidDays,
    this.handlingUserId,
    this.handlingStartedAt,
    this.handlingDisplayName,
    this.reviewedByUserId,
    this.reviewedByEmail,
    this.reviewedAt,
    this.reviewNote,
    required this.createdAt,
    required this.updatedAt,
  });

  factory TokenRequest.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic>? handler;
    final h = json['handler'];
    if (h is Map<String, dynamic>) {
      handler = h;
    } else if (json['profiles'] is Map<String, dynamic>) {
      handler = json['profiles'] as Map<String, dynamic>;
    }

    return TokenRequest(
      id: json['id'] as String,
      organizationId: json['organization_id'] as String,
      organizationName: json['organization_name'] as String,
      organizationType: json['organization_type'] as String,
      requestKind: json['request_kind'] as String? ?? 'seat_expansion',
      currentSeatLimit: json['current_seat_limit'] as int,
      currentSeatsUsed: json['current_seats_used'] as int,
      requestedExtraSeats: json['requested_extra_seats'] as int,
      requestedNewTotal: json['requested_new_total'] as int,
      reason: json['reason'] as String? ?? '',
      requestedByUserId: json['requested_by_user_id'] as String,
      requestedByEmail: json['requested_by_email'] as String? ?? '',
      status: json['status'] as String,
      currentTokenId: json['current_token_id'] as String?,
      requestedValidDays: json['requested_valid_days'] as int?,
      handlingUserId: json['handling_user_id'] as String?,
      handlingStartedAt: json['handling_started_at'] != null
          ? DateTime.parse(json['handling_started_at'] as String)
          : null,
      handlingDisplayName: handler != null
          ? ((handler['display_name'] as String?)?.trim().isNotEmpty == true
              ? handler['display_name'] as String
              : handler['email'] as String?)
          : null,
      reviewedByUserId: json['reviewed_by_user_id'] as String?,
      reviewedByEmail: json['reviewed_by_email'] as String?,
      reviewedAt: json['reviewed_at'] != null
          ? DateTime.parse(json['reviewed_at'] as String)
          : null,
      reviewNote: json['review_note'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  bool get isPending => status == 'pending';
  bool get isInProgress => status == 'in_progress';
  bool get isApproved => status == 'approved';
  bool get isRejected => status == 'rejected';

  /// [organizationType] as a person reads it.
  ///
  /// The raw value is the wire string — `mineSupplier`, `buyer`, `transporter`
  /// — and the token-requests screen printed it straight, in both the list row
  /// and the detail sheet: "Seat expansion · mineSupplier". Every other surface
  /// in the product goes through a label (`OrgType.label`,
  /// `RequestCompanyInfo.orgTypeLabel`), so this was the one screen showing an
  /// admin the database's vocabulary. Found 2026-08-20 by photographing it.
  ///
  /// Falls back to the raw value rather than to a dash: an unknown org type is
  /// something to see, not something to hide.
  String get organizationTypeLabel =>
      OrgType.tryParse(organizationType)?.label ?? organizationType;

  String get requestKindLabel {
    switch (requestKind) {
      case 'token_renewal':
        return 'Token renewal';
      case 'new_token':
        return 'New token';
      case 'seat_expansion':
      default:
        return 'Seat expansion';
    }
  }
}
