/// The current user's own account-deactivation request, as read back by
/// `my_account_deactivation_request()`.
///
/// Only three statuses are ever returned to the requester's own card —
/// `pending`, `approved`, `rejected` (the RPC filters to exactly those; see
/// `supabase/migrations/20260819100000_account_deactivation_requests.sql`).
/// `deactivated` / `reactivated` / `cancelled` happen to the row but are not
/// surfaced back to `my_account_deactivation_request()`, so a card built
/// against this model never has to render them.
class AccountDeactivationRequest {
  const AccountDeactivationRequest({
    required this.status,
    required this.requestedAt,
    this.autoApplyAt,
    this.reviewNote,
  });

  /// `pending` | `approved` | `rejected`.
  final String status;

  /// When the user asked. A raw instant — pass through `MlTime.sast` before
  /// display, never format directly (CLAUDE.md §7.1).
  final DateTime requestedAt;

  /// When an un-reviewed request auto-applies (30 days after [requestedAt]).
  /// Null once a request has been reviewed either way — the review is the
  /// event that matters at that point, not the backstop that never fired.
  final DateTime? autoApplyAt;

  /// The platform admin's reason, mandatory on a rejection.
  final String? reviewNote;

  factory AccountDeactivationRequest.fromJson(Map<String, dynamic> json) {
    final requestedRaw = json['requested_at'] as String?;
    if (requestedRaw == null) {
      // `requested_at` is `not null` in Postgres (see the migration cited
      // above), so this is a data-integrity violation, not a normal case to
      // paper over. No fallback to a device wall-clock read here — CLAUDE.md
      // §7.1 is categorical about `DateTime.now()`, and a fabricated "now"
      // would look like a real requested-at date and silently mislead
      // whoever reads it (the same failure class as the fabricated `28.0k`
      // target line the design doc calls out). Fail loudly instead.
      throw FormatException(
        'my_account_deactivation_request() returned a row with no '
        'requested_at: $json',
      );
    }
    final autoApplyRaw = json['auto_apply_at'] as String?;
    return AccountDeactivationRequest(
      status: (json['status'] as String?)?.trim() ?? 'pending',
      requestedAt: DateTime.parse(requestedRaw),
      autoApplyAt: autoApplyRaw != null ? DateTime.parse(autoApplyRaw) : null,
      reviewNote: (json['review_note'] as String?)?.trim().isEmpty ?? true
          ? null
          : (json['review_note'] as String?)?.trim(),
    );
  }

  bool get isPending => status == 'pending';
  bool get isApproved => status == 'approved';
  bool get isRejected => status == 'rejected';
}

/// Thrown with the Postgres SQLSTATE intact.
///
/// The card branches on [code], never on [message]. Matching on wording is
/// what `getErrorCode` in `supabase/functions/company-user-admin/index.ts`
/// exists to avoid: the branch breaks silently the moment somebody edits the
/// sentence. Known codes: `MLD01` (caller owns a company), `MLD02` (a request
/// is already in progress, or there is none to cancel). `AUTH_FAILED` /
/// `AUTH_NO_EMAIL` come from [AccountDeactivationService.reauthenticate], not
/// from Postgres — see that method's doc for what they guard against.
class AccountDeactivationException implements Exception {
  const AccountDeactivationException(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => 'AccountDeactivationException($code: $message)';
}
