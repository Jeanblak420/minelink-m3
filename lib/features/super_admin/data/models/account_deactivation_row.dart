/// One row from `list_account_deactivation_requests` (migration
/// `20260819110000` / fix round `20260819115000`) — the platform-admin
/// console queue for user-initiated account deactivation requests.
///
/// Nothing this feature does deletes anything (spec s1.1, Jean's ruling
/// 2026-08-19): a request is reviewed, applied (`deactivate_account`, which
/// only bans sign-in) or reversed (`reactivate_account`).
///
/// [isCompanyOwner] and [activeTrips] are informational blocker chips for a
/// human reviewer, not enforced refusals — `review_account_deactivation_
/// request` does not refuse an owner's request, and an active trip never
/// blocks one either. The nightly backstop
/// (`apply_due_account_deactivations_job`) deliberately skips a request whose
/// requester owns a company, so an `approved` row with [isCompanyOwner] true
/// sits stuck forever until a platform admin acts — see
/// [AccountDeactivationRow.isBlockedApproved].
class AccountDeactivationRow {
  final String id;
  final String userId;
  final String displayName;
  final String? email;
  final String? companyName;
  final String? role;
  final String? reason;
  final String status;
  final DateTime requestedAt;
  final DateTime autoApplyAt;
  final String? reviewNote;
  final DateTime? deactivatedAt;
  final bool isCompanyOwner;
  final int activeTrips;

  const AccountDeactivationRow({
    required this.id,
    required this.userId,
    required this.displayName,
    this.email,
    this.companyName,
    this.role,
    this.reason,
    required this.status,
    required this.requestedAt,
    required this.autoApplyAt,
    this.reviewNote,
    this.deactivatedAt,
    required this.isCompanyOwner,
    required this.activeTrips,
  });

  factory AccountDeactivationRow.fromJson(Map<String, dynamic> json) {
    return AccountDeactivationRow(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      displayName:
          (json['display_name'] as String?)?.trim().isNotEmpty == true
              ? json['display_name'] as String
              : (json['email'] as String? ?? 'Unknown user'),
      email: json['email'] as String?,
      companyName: json['company_name'] as String?,
      role: json['role'] as String?,
      reason: json['reason'] as String?,
      status: json['status'] as String? ?? 'pending',
      requestedAt: DateTime.parse(json['requested_at'] as String),
      autoApplyAt: DateTime.parse(json['auto_apply_at'] as String),
      reviewNote: json['review_note'] as String?,
      deactivatedAt: json['deactivated_at'] == null
          ? null
          : DateTime.parse(json['deactivated_at'] as String),
      isCompanyOwner: json['is_company_owner'] as bool? ?? false,
      activeTrips: json['active_trips'] as int? ?? 0,
    );
  }

  bool get isPending => status == 'pending';
  bool get isApproved => status == 'approved';
  bool get isDeactivated => status == 'deactivated';

  /// Approved, but the nightly backstop will never apply it: the requester
  /// owns a company, and `apply_due_account_deactivations_job` excludes that
  /// case from its selection query rather than retrying it forever (see the
  /// migration's own header). In the data this looks identical to an
  /// `approved` row simply waiting for tonight's run; in meaning it is the
  /// opposite — nothing will ever move it forward without a human.
  bool get isBlockedApproved => isApproved && isCompanyOwner;
}
