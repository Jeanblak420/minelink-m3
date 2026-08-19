import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:flutter_application_1/core/config/supabase_config.dart';
import 'package:flutter_application_1/core/utils/logger.dart';
import 'package:flutter_application_1/features/portal/models/trip_waypoint.dart';

/// Data access for `security_confirmations` (phase-5 design §2.3) — the
/// two-party (driver + mine security) gate confirmations for a trip's
/// arrival and exit. Writes go straight to the table (RLS gates: assigned
/// driver, the mine's staff, platform admin); upserts target the live
/// `unique(trip_id, confirmation_type)` constraint so driver/security
/// confirms are idempotent. Strictly ADDITIVE bookkeeping: confirmations
/// never advance `TripStatus` — the `set_trip_status` cascade stays the
/// authoritative lifecycle.
class SecurityConfirmationService {
  static final _log = LoggerFactory.getLogger('SecurityConfirmationService');
  final SupabaseClient _client = SupabaseConfig.client;

  static const _table = 'security_confirmations';

  /// The live table's unique constraint — the upsert conflict target.
  static const _conflictTarget = 'trip_id,confirmation_type';

  /// Both confirmation rows (arrival + exit) for a trip — either may be
  /// absent until the corresponding gate event is first confirmed.
  Future<List<SecurityConfirmation>> forTrip(String tripId) async {
    final rows = await _client
        .from(_table)
        .select()
        .eq('trip_id', tripId)
        .order('confirmation_type', ascending: true);
    return [
      for (final r in rows)
        SecurityConfirmation.fromJson(Map<String, dynamic>.from(r)),
    ];
  }

  /// One confirmation row by trip + type, or null when it doesn't exist yet.
  Future<SecurityConfirmation?> get(
      String tripId, SecurityConfirmationType type) async {
    final row = await _client
        .from(_table)
        .select()
        .eq('trip_id', tripId)
        .eq('confirmation_type', type.wire)
        .maybeSingle();
    return row == null ? null : SecurityConfirmation.fromJson(row);
  }

  /// Driver-side confirm: upsert the row (insert when missing) with
  /// `driver_confirmed` + `driver_confirmed_at` set. Idempotent — re-running
  /// simply re-asserts the driver's confirmation.
  Future<SecurityConfirmation> driverConfirm(
      String tripId, SecurityConfirmationType type) async {
    _log.i('Driver confirming ${type.wire} for trip $tripId');
    final row = await _client
        .from(_table)
        .upsert({
          'trip_id': tripId,
          'confirmation_type': type.wire,
          'driver_confirmed': true,
          'driver_confirmed_at': DateTime.now().toUtc().toIso8601String(),
        }, onConflict: _conflictTarget)
        .select()
        .single();
    return SecurityConfirmation.fromJson(row);
  }

  /// Security-side confirm: upsert the row with `security_confirmed`,
  /// `security_confirmed_at` and `security_user_id` set. [securityUserId]
  /// defaults to the signed-in user (the guard tapping Confirm).
  Future<SecurityConfirmation> securityConfirm(
      String tripId, SecurityConfirmationType type,
      {String? securityUserId}) async {
    final userId = securityUserId ?? _client.auth.currentUser?.id;
    _log.i('Security ($userId) confirming ${type.wire} for trip $tripId');
    final row = await _client
        .from(_table)
        .upsert({
          'trip_id': tripId,
          'confirmation_type': type.wire,
          'security_confirmed': true,
          'security_confirmed_at': DateTime.now().toUtc().toIso8601String(),
          'security_user_id': userId,
        }, onConflict: _conflictTarget)
        .select()
        .single();
    return SecurityConfirmation.fromJson(row);
  }

  /// The mine security queue: confirmations for the mine's trips that
  /// security hasn't signed off yet (`get_mine_pending_confirmations` RPC,
  /// SECURITY DEFINER, mine-staff scoped).
  Future<List<SecurityConfirmation>> pendingForMine(
      String mineCompanyId) async {
    final rows = await _client.rpc('get_mine_pending_confirmations',
        params: {'p_mine_id': mineCompanyId});
    return [
      for (final r in (rows as List? ?? const []))
        SecurityConfirmation.fromJson(Map<String, dynamic>.from(r as Map)),
    ];
  }
}
