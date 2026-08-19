import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:flutter_application_1/core/config/supabase_config.dart';
import 'package:flutter_application_1/features/super_admin/data/models/target_scope.dart';
import 'package:flutter_application_1/features/super_admin/data/repositories/targets_controller.dart';
import 'package:flutter_application_1/features/super_admin/data/repositories/targets_repository.dart';
import 'package:flutter_application_1/features/super_admin/widgets/insights_v2/minelink_targets_core.dart';

final targetsRepositoryProvider = Provider<TargetsRepository>(
  (ref) => TargetsRepository(SupabaseConfig.client),
);

/// Lets a writer ask a live feed to re-read, without invalidating it.
///
/// Invalidating an [targetsProvider] would rebuild it — which means tearing
/// down its realtime channel and opening a new one. A dial fires on every
/// arrow-key nudge, so that would resubscribe a websocket per keypress.
/// Registering the feed's own refresh here keeps the subscription up and just
/// re-runs the query.
class TargetsFeedRegistry {
  final Map<TargetScope, void Function()> _feeds = <TargetScope, void Function()>{};

  void register(TargetScope scope, void Function() refresh) =>
      _feeds[scope] = refresh;

  void unregister(TargetScope scope) => _feeds.remove(scope);

  /// No-op when nothing is listening to that scope — the next listener reads
  /// fresh anyway.
  void refresh(TargetScope scope) => _feeds[scope]?.call();
}

final targetsFeedRegistryProvider =
    Provider<TargetsFeedRegistry>((ref) => TargetsFeedRegistry());

/// The write path for a scope. Debounces dial edits and re-reads the feed once
/// each write settles — see [TargetsController].
final targetsControllerProvider =
    Provider.autoDispose.family<TargetsController, TargetScope>((ref, scope) {
  final registry = ref.watch(targetsFeedRegistryProvider);
  final controller = TargetsController(
    repository: ref.watch(targetsRepositoryProvider),
    scope: scope,
    onSettled: () => registry.refresh(scope),
  );
  // Keeps the controller alive while its screen is open, so a debounced write
  // is not disposed out from under the user between keystrokes.
  ref.onDispose(controller.dispose);
  return controller;
});

/// Live targets for one scope.
///
/// Re-reads `get_targets_state` whenever anything it is derived from changes:
/// the two targets tables (someone else's edit, or the nightly cycle-close
/// job) and `trips` / `transactions` (the weighbridge net mass the actuals are
/// computed from, so a load recorded at the mine moves the dials here without
/// a refresh).
///
/// The two feeds get different debounces on purpose. A target edit is the
/// user's own action and should land immediately; trip traffic is somebody
/// else's and can be coalesced, or a busy day at the weighbridge would have
/// this screen re-querying continuously.
final targetsProvider =
    StreamProvider.autoDispose.family<MlTargetsData, TargetScope>((ref, scope) {
  final repo = ref.watch(targetsRepositoryProvider);
  final controller = StreamController<MlTargetsData>();

  var disposed = false;
  var inFlight = false;
  var repeat = false;
  Timer? fast;
  Timer? slow;

  Future<void> fetch() async {
    if (disposed) return;
    if (inFlight) {
      // A change landed mid-request; the result in flight predates it, so run
      // again once it settles rather than showing a stale figure.
      repeat = true;
      return;
    }
    inFlight = true;
    try {
      final data = await repo.fetch(scope);
      if (!disposed) controller.add(data);
    } catch (e, st) {
      if (!disposed) controller.addError(e, st);
    } finally {
      inFlight = false;
      if (repeat && !disposed) {
        repeat = false;
        unawaited(fetch());
      }
    }
  }

  void run() {
    fast?.cancel();
    slow?.cancel();
    unawaited(fetch());
  }

  void scheduleFast() {
    fast?.cancel();
    fast = Timer(const Duration(milliseconds: 200), run);
  }

  void scheduleSlow() {
    if (slow?.isActive ?? false) return;
    slow = Timer(const Duration(seconds: 2), run);
  }

  unawaited(fetch());

  // A write can ask for an immediate re-read without costing a resubscribe.
  ref.watch(targetsFeedRegistryProvider).register(scope, run);

  final channel = SupabaseConfig.client.channel('targets:$scope')
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'monthly_targets',
      callback: (_) => scheduleFast(),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'target_cycles',
      callback: (_) => scheduleFast(),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'trips',
      callback: (_) => scheduleSlow(),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'transactions',
      callback: (_) => scheduleSlow(),
    )
    ..subscribe();

  ref.onDispose(() {
    disposed = true;
    fast?.cancel();
    slow?.cancel();
    ref.read(targetsFeedRegistryProvider).unregister(scope);
    SupabaseConfig.client.removeChannel(channel);
    controller.close();
  });

  return controller.stream;
});
