/// Employee profile detail view — providers + realtime plumbing.
///
/// Read providers are granular so realtime events invalidate only what
/// changed. `employeeProfileRealtimeProvider` opens filtered postgres_changes
/// channels over EVERY source the profile renders (employees row, profiles
/// row, company-scoped activity tables, documents, disputes, assignments —
/// all in the supabase_realtime publication since the 2026-08-03 migration)
/// and debounce-invalidates the read providers. RLS (WALRUS) limits events to
/// rows the subscriber can see.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:flutter_application_1/core/config/supabase_config.dart';
import 'package:flutter_application_1/core/utils/logger.dart';
import 'package:flutter_application_1/features/employee/services/employee_profile_service.dart';

final _log = LoggerFactory.getLogger('EmployeeProfileRealtime');

final employeeProfileServiceProvider =
    Provider<EmployeeProfileService>((ref) => EmployeeProfileService());

/// Identity + company + supervisor + register siblings for one employee.
final employeeProfileBundleProvider = FutureProvider.autoDispose
    .family<EmployeeProfileBundle, String>((ref, employeeId) {
  ref.watch(_profileRefreshProvider(employeeId));
  return ref.read(employeeProfileServiceProvider).loadBundle(employeeId);
});

/// The three per-role productivity metrics (real counts + 7-day sparklines).
final employeeProfileMetricsProvider = FutureProvider.autoDispose
    .family<List<ProfileMetric>, String>((ref, employeeId) async {
  ref.watch(_activityRefreshProvider(employeeId));
  final bundle = await ref.watch(employeeProfileBundleProvider(employeeId).future);
  return ref.read(employeeProfileServiceProvider).loadMetrics(bundle);
});

/// Merged, deep-linked last-24h activity feed.
final employeeProfileActivityProvider = FutureProvider.autoDispose
    .family<List<ProfileActivityItem>, String>((ref, employeeId) async {
  ref.watch(_activityRefreshProvider(employeeId));
  final bundle = await ref.watch(employeeProfileBundleProvider(employeeId).future);
  return ref.read(employeeProfileServiceProvider).loadActivity(bundle);
});

/// Documents (legacy slots + compliance) and the derived live flags.
final employeeProfileDocsProvider = FutureProvider.autoDispose
    .family<ProfileDocsAndFlags, String>((ref, employeeId) async {
  ref.watch(_docsRefreshProvider(employeeId));
  final bundle = await ref.watch(employeeProfileBundleProvider(employeeId).future);
  return ref.read(employeeProfileServiceProvider).loadDocsAndFlags(bundle);
});

/// Real location context (mine site / latest driver GPS fix).
final employeeProfileLocationProvider = FutureProvider.autoDispose
    .family<({String? name, double? lat, double? lng, DateTime? at}), String>(
        (ref, employeeId) async {
  ref.watch(_activityRefreshProvider(employeeId));
  final bundle = await ref.watch(employeeProfileBundleProvider(employeeId).future);
  return ref.read(employeeProfileServiceProvider).loadLocation(bundle);
});

// ---------------------------------------------------------------------------
// Realtime: bump-counters the read providers watch. The realtime provider
// (and its polling fallback) bump these; watching providers auto-refetch.
// ---------------------------------------------------------------------------

final _profileRefreshProvider =
    StateProvider.autoDispose.family<int, String>((ref, _) => 0);
final _activityRefreshProvider =
    StateProvider.autoDispose.family<int, String>((ref, _) => 0);
final _docsRefreshProvider =
    StateProvider.autoDispose.family<int, String>((ref, _) => 0);

/// Live wall-clock of the last realtime/polling refresh — drives the
/// "Live · Synced Xs ago" pill honestly.
final employeeProfileSyncedAtProvider =
    StateProvider.autoDispose.family<DateTime, String>((ref, _) => DateTime.now());

/// Opens the realtime channels for one profile. Watch it from the screen; it
/// tears the channels down when the screen goes away (autoDispose).
final employeeProfileRealtimeProvider =
    Provider.autoDispose.family<void, String>((ref, employeeId) {
  final client = SupabaseConfig.client;
  final channels = <RealtimeChannel>[];
  Timer? debounce;

  void bump(AutoDisposeStateProvider<int> Function(String) family) {
    // Debounce bursts (a trip update fires several column events at once).
    debounce?.cancel();
    debounce = Timer(const Duration(milliseconds: 400), () {
      ref.read(family(employeeId).notifier).update((v) => v + 1);
      ref
          .read(employeeProfileSyncedAtProvider(employeeId).notifier)
          .state = DateTime.now();
    });
  }

  void subscribe() async {
    // Need company/user scope first — best-effort; presence still works.
    try {
      final bundle = await ref.read(employeeProfileServiceProvider).loadBundle(employeeId);
      final uid = bundle.person.employee.userId;
      final cid = bundle.company.id;

      final ch = client.channel('employee-profile-$employeeId')
        ..onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'employees',
          filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq, column: 'id', value: employeeId),
          callback: (_) => bump(_profileRefreshProvider.call),
        )
        ..onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'profiles',
          filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq, column: 'id', value: uid),
          callback: (_) => bump(_profileRefreshProvider.call),
        )
        ..onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'gate_checks',
          filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq, column: 'company_id', value: cid),
          callback: (_) => bump(_activityRefreshProvider.call),
        )
        ..onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'weighbridge_records',
          filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq, column: 'company_id', value: cid),
          callback: (_) => bump(_activityRefreshProvider.call),
        )
        ..onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'security_incidents',
          filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq, column: 'company_id', value: cid),
          callback: (_) => bump(_activityRefreshProvider.call),
        )
        ..onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq, column: 'company_id', value: cid),
          callback: (_) => bump(_activityRefreshProvider.call),
        )
        // trips/vehicle_positions carry no company column — RLS (WALRUS)
        // already limits events to rows this subscriber can see.
        ..onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'trips',
          callback: (_) => bump(_activityRefreshProvider.call),
        )
        ..onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'vehicle_positions',
          callback: (_) => bump(_activityRefreshProvider.call),
        )
        ..onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'fleet_vehicles',
          filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq, column: 'company_id', value: cid),
          callback: (_) => bump(_activityRefreshProvider.call),
        )
        ..onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'companies',
          filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq, column: 'id', value: cid),
          callback: (_) => bump(_profileRefreshProvider.call),
        )
        ..onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'compliance_documents',
          filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq, column: 'company_id', value: cid),
          callback: (_) => bump(_docsRefreshProvider.call),
        )
        ..onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'driver_assignments',
          filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq, column: 'company_id', value: cid),
          callback: (_) => bump(_activityRefreshProvider.call),
        )
        // The remaining sources carry no company column — RLS (WALRUS)
        // already limits their events to rows this subscriber can see.
        ..onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'pod_uploads',
          callback: (_) => bump(_activityRefreshProvider.call),
        )
        ..onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'stockpile_transactions',
          callback: (_) => bump(_activityRefreshProvider.call),
        )
        ..onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'recon_disputes',
          callback: (_) => bump(_activityRefreshProvider.call),
        )
        ..onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'transportation_requests',
          callback: (_) => bump(_activityRefreshProvider.call),
        )
        ..onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'request_dispatches',
          callback: (_) => bump(_activityRefreshProvider.call),
        )
        ..subscribe();
      channels.add(ch);
    } catch (e) {
      // Realtime is a freshness optimisation, not the data path — the profile
      // still loads and still refreshes on navigation. Logged, never swallowed
      // (P0-11 / S1-7): a silent failure here looks exactly like "nothing is
      // happening on this account", which is the hardest fault class to spot.
      _log.w('profile realtime subscribe failed, falling back to manual refresh: $e');
    }
  }

  subscribe();

  ref.onDispose(() {
    debounce?.cancel();
    for (final ch in channels) {
      try {
        client.removeChannel(ch);
      } catch (e) {
        _log.d('removeChannel on dispose: $e');
      }
    }
  });
});
