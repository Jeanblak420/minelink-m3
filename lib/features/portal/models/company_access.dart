/// Whether the signed-in user's company may still act, and — when it may not —
/// everything the UI needs to say so in plain words.
///
/// Backed by the `get_my_company_access` RPC, whose `is_active` is the **same**
/// `public.is_company_active()` the write policies consult. That is the point
/// of routing every explanation through one model: the banner, the disabled
/// actions and the router redirect cannot drift from what the database will
/// actually permit.
///
/// Before this existed there was nowhere to ask. `CompanyMCP` carries no
/// `status` and no `token_expires_at`, so when token expiry started being
/// enforced (migration `20260815094000`) the block landed **silently** — writes
/// failed with a row-level-security error and nothing on screen explained why
/// or what to do about it.
library;

import 'package:flutter_application_1/core/time/ml_time.dart';

class CompanyAccess {
  const CompanyAccess({
    required this.isActive,
    required this.isPlatformAdmin,
    this.companyId,
    this.companyName,
    this.orgType,
    this.status,
    this.tokenExpiresAt,
    this.daysSinceExpiry,
  });

  /// May this company act? False once the token has expired (and also while a
  /// company is still `pendingActivation` or is `suspended`).
  final bool isActive;

  /// Platform admins belong to no company and are never restricted.
  final bool isPlatformAdmin;

  final String? companyId;
  final String? companyName;
  final String? orgType;

  /// `active` · `expired` · `suspended` · `pendingActivation`.
  final String? status;
  final DateTime? tokenExpiresAt;

  /// Whole days since the token lapsed; null while it is still valid.
  final int? daysSinceExpiry;

  /// True when the reason for being restricted is a lapsed token, as opposed to
  /// a company that has not been activated yet or has been suspended. The three
  /// need different wording — only this one is fixed by renewing.
  bool get isExpired => status == 'expired';

  /// True when the company simply has not been activated yet. Says "activate",
  /// not "renew" — telling somebody to renew something they never had is the
  /// kind of small wrongness that makes a product feel untrustworthy.
  bool get isPendingActivation => status == 'pendingActivation';

  bool get isSuspended => status == 'suspended';

  /// Whether a restriction notice should be shown at all.
  bool get isRestricted => !isActive && !isPlatformAdmin && companyId != null;

  /// A short headline for the notice bar. Written per status rather than
  /// shared, because "renew", "activate" and "contact us" are genuinely
  /// different instructions.
  String get headline {
    if (isExpired) return 'Your MineLink token has expired';
    if (isPendingActivation) return 'Your MineLink token is not active yet';
    if (isSuspended) return 'Your MineLink access is suspended';
    return 'Your MineLink access is limited';
  }

  /// One calm sentence saying what is still possible. Deliberately leads with
  /// what the user CAN do — a notice that only lists refusals reads as a wall
  /// and invites a support call that the next sentence would have prevented.
  String get explanation {
    // The "ask" varies with the status and must not be shared blindly. Written
    // shared first, which had a never-activated company being told to "request
    // a renewal" — renewing something they never had. Caught by
    // expiry_notice_test.dart, which asserts the word `renew` never reaches
    // pendingActivation copy.
    final ask = isPendingActivation ? 'request activation' : 'request a renewal';
    final stillCan =
        'You can still view your records, message MineLink, $ask and log a '
        'support ticket.';
    if (isExpired) {
      final when = tokenExpiresAt == null ? null : _formatDate(tokenExpiresAt!);
      final days = daysSinceExpiry;
      final since = when == null
          ? 'Your token has expired.'
          : days != null && days > 0
              ? 'Your token expired on $when — $days ${days == 1 ? 'day' : 'days'} ago.'
              : 'Your token expired on $when.';
      return '$since $stillCan Anything that changes a record needs a renewed '
          'token.';
    }
    if (isPendingActivation) {
      return 'This company has not been activated yet. $stillCan Anything that '
          'changes a record needs an active token.';
    }
    if (isSuspended) {
      return 'This company\'s access has been suspended. $stillCan Message '
          'MineLink to find out what is needed to lift it.';
    }
    return stillCan;
  }

  /// The tooltip a blocked control shows. Short, because it sits on hover next
  /// to the thing it is explaining, and the full story is in the notice bar.
  String get blockedActionTooltip {
    if (isExpired) return 'Needs a renewed token — your token has expired.';
    if (isPendingActivation) {
      return 'Needs an active token — this company is not activated yet.';
    }
    if (isSuspended) return 'Unavailable while access is suspended.';
    return 'Unavailable while your access is limited.';
  }

  /// `2026-04-23` → `23 April 2026`. Local formatting rather than `intl` so the
  /// model stays dependency-free and usable from a test without a locale.
  static String _formatDate(DateTime d) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    final local = MlTime.sast(d);
    return '${local.day} ${months[local.month - 1]} ${local.year}';
  }

  /// Permissive on a malformed or missing row: a UI that wrongly believes it is
  /// blocked is worse than one that lets the database refuse the write. RLS is
  /// the real boundary; this model only explains it.
  factory CompanyAccess.fromJson(Map<String, dynamic> json) {
    final expires = json['token_expires_at'] as String?;
    return CompanyAccess(
      isActive: (json['is_active'] as bool?) ?? true,
      isPlatformAdmin: (json['is_platform_admin'] as bool?) ?? false,
      companyId: json['company_id'] as String?,
      companyName: json['company_name'] as String?,
      orgType: json['org_type'] as String?,
      status: json['status'] as String?,
      tokenExpiresAt: expires == null ? null : DateTime.tryParse(expires),
      daysSinceExpiry: (json['days_since_expiry'] as num?)?.toInt(),
    );
  }

  /// The state assumed when the answer is not known yet or could not be
  /// fetched — unrestricted, for the reason given on [fromJson].
  static const unrestricted =
      CompanyAccess(isActive: true, isPlatformAdmin: false);
}
