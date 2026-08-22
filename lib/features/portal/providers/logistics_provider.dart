import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_application_1/features/portal/services/logistics_service.dart';

final logisticsServiceProvider = Provider<LogisticsService>((ref) => LogisticsService());

/// Ticks on every trip/transaction movement for this company — see
/// [LogisticsService.watchLifecycle] for the fault this closes.
///
/// Nothing should read the VALUE. It exists to be watched, and it is public
/// only so a test can override it with a stream it controls —
/// `logistics_snapshot_refetches_test.dart` drives a tick and asserts the
/// snapshot is re-read, which is the whole fix.
final logisticsLifecycleTickProvider =
    StreamProvider.autoDispose.family<int, String>((ref, companyId) {
  final svc = ref.watch(logisticsServiceProvider);
  return svc.watchLifecycle(companyId);
});

final logisticsSnapshotProvider =
    FutureProvider.autoDispose.family<LogisticsSnapshot, String>((ref, companyId) async {
  // Re-reads whenever a trip or transaction moves, INCLUDING when somebody
  // else moves it. Without this the snapshot was taken when the screen
  // mounted and never again: on 2026-08-22 security marked a truck left site
  // at 04:33 and the driver's own Trip screen still read EN ROUTE TO LOAD at
  // 04:37, with `Arrived at offloading` dimmed — so the driver could not
  // finish the load without killing the app.
  //
  // Watching the stream is what re-runs this future; the value is not used.
  // `autoDispose` on both means the channel closes with the last screen.
  ref.watch(logisticsLifecycleTickProvider(companyId));
  final svc = ref.watch(logisticsServiceProvider);
  return svc.loadForCompany(companyId);
});

final partnerCompaniesProvider = FutureProvider.autoDispose
    .family<List<CompanyPin>, ({String companyId, String orgFilter})>((ref, args) async {
  final svc = ref.watch(logisticsServiceProvider);
  return svc.listPartnerCompanies(args.companyId, orgFilter: args.orgFilter);
});
