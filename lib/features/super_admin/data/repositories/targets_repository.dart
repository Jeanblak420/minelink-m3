import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:flutter_application_1/core/utils/logger.dart';
import 'package:flutter_application_1/features/super_admin/data/models/target_scope.dart';
import 'package:flutter_application_1/features/super_admin/widgets/insights_v2/minelink_targets_core.dart';

/// The only place the targets tables are talked to.
///
/// Every method is an RPC. The tables themselves carry a SELECT grant and no
/// write grant at all, so there is no direct-write path to be tempted by: the
/// closed-month and locked-cycle rules live in Postgres triggers and would
/// reject one anyway. See
/// `supabase/migrations/20260808120000_targets_and_cycles.sql`.
class TargetsRepository {
  TargetsRepository(this._client);

  final SupabaseClient _client;

  static final _log = LoggerFactory.getLogger('TargetsRepository');

  /// Months, the open cycle and any closed cycles for [scope].
  ///
  /// [plannedMonths] is how far past the current month to offer for planning —
  /// without future months there is nothing to plan against.
  Future<MlTargetsData> fetch(TargetScope scope, {int plannedMonths = 6}) async {
    final res = await _client.rpc<dynamic>(
      'get_targets_state',
      params: {...scope.rpcArgs, 'p_planned_months': plannedMonths},
    );
    if (res is! Map) {
      throw StateError('get_targets_state returned ${res.runtimeType}');
    }
    return TargetsPayload.parse(Map<String, dynamic>.from(res));
  }

  /// Set one month's target. The server refuses a month that has closed.
  Future<void> setMonthTarget(
    TargetScope scope,
    String period,
    double tons,
  ) async {
    _log.i('set month target $scope $period = $tons');
    await _client.rpc<void>(
      'set_monthly_target',
      params: {...scope.rpcArgs, 'p_period': period, 'p_tons': tons},
    );
  }

  /// Stage one horizon. Nothing is committed until [lockCycle].
  Future<void> setHorizonDraft(
    TargetScope scope,
    String horizon,
    double tons,
  ) async {
    _log.i('set horizon draft $scope $horizon = $tons');
    await _client.rpc<void>(
      'set_cycle_draft',
      params: {...scope.rpcArgs, 'p_horizon': horizon, 'p_tons': tons},
    );
  }

  /// Commit all six horizons for twelve months. The server refuses a partial
  /// set and refuses to re-lock an already locked cycle.
  Future<void> lockCycle(TargetScope scope, Map<String, double> targets) async {
    _log.i('lock cycle $scope');
    await _client.rpc<void>(
      'lock_target_cycle',
      params: {...scope.rpcArgs, 'p_targets': targets},
    );
  }

  /// Close the finished cycle (freezing its actuals) and open the next.
  /// The server refuses before the twelve months are up.
  Future<void> startNewCycle(TargetScope scope) async {
    _log.i('start new cycle $scope');
    await _client.rpc<void>('start_new_target_cycle', params: scope.rpcArgs);
  }
}
