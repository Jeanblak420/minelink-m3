import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_application_1/features/portal/models/available_route.dart';
import 'package:flutter_application_1/features/portal/models/request_tracking.dart';
import 'package:flutter_application_1/features/portal/models/transportation_request.dart';
import 'package:flutter_application_1/features/portal/services/request_service.dart';

final requestServiceProvider =
    Provider<RequestService>((ref) => RequestService());

/// Every request THIS company raised, whatever its org type (newest first).
///
/// ⚠ Named for the company that *raised* the request, not for a buyer. A mine
/// raises requests too — *Request Transporter/Routes* is identical for both org
/// types and *Request Buyer* is mine-only — and both land in the same column,
/// `transportation_requests.buyer_company_id`, which is the **requester** key
/// and is `not null` on every row. `supplier_company_id` is a different thing
/// entirely: the mine the platform admin *links* at dispatch.
///
/// This provider was called `buyerRequestsProvider` and the service method
/// `listForBuyer`, which read as an org-type filter and is exactly what led an
/// audit to raise a false release blocker (P3-46) claiming a mine could not
/// submit a request at all. It can, and always could — `is_company_staff`
/// tests employment, never org type. Proven end to end 2026-08-11.
final companyRequestsProvider = FutureProvider.autoDispose
    .family<List<TransportationRequest>, String>((ref, companyId) async {
  return ref.watch(requestServiceProvider).listForRequester(companyId);
});

/// Request tracking for every involved party (null key = platform-wide,
/// super-admin). A request completes when all of its trips are completed.
final requestTrackingProvider = FutureProvider.autoDispose
    .family<List<RequestTrackingRow>, String?>((ref, companyId) async {
  return ref.watch(requestServiceProvider).listRequestTracking(companyId);
});

/// Available routes the super-admin assigned to this org (§4) — selecting
/// one auto-fills the Request Route form.
final myAvailableRoutesProvider = FutureProvider.autoDispose
    .family<List<AvailableRoute>, String>((ref, companyId) async {
  return ref.watch(requestServiceProvider).listMyAvailableRoutes(companyId);
});

/// Trucks the transporter allocated to a request (one per accepted trip),
/// keyed by request id. Visible to the linked buyer/mine (§4).
final allocatedTrucksProvider = FutureProvider.autoDispose
    .family<List<AllocatedTruck>, String>((ref, requestId) async {
  return ref.watch(requestServiceProvider).listAllocatedTrucks(requestId);
});

/// Platform-admin review queue, keyed by request type
/// (transportation | product | buyer).
final adminRequestQueueProvider = FutureProvider.autoDispose
    .family<List<TransportationRequest>, String>((ref, requestType) async {
  return ref.watch(requestServiceProvider).listForAdmin(requestType: requestType);
});

/// How many requests of this type are genuinely **awaiting the platform
/// admin** — `requested` or `resubmitted` (P9-02).
///
/// `adminRequestQueueProvider(...).length` is NOT that number: the inbox needs
/// closed requests to show history, so the list carries approved, linked and
/// declined ones too. Three call sites read `.length` and labelled it "Pending
/// requests", which meant the console reported every request ever raised as
/// outstanding work. The filter now lives here once, next to the list it
/// corrects, rather than at each call site where it can be forgotten again.
final adminPendingRequestCountProvider = Provider.autoDispose
    .family<int?, String>((ref, requestType) {
  // Null while loading or on error — never 0. "Nothing waiting" and "we could
  // not find out" are different statements, and only one of them is good news.
  return ref
      .watch(adminRequestQueueProvider(requestType))
      .valueOrNull
      ?.where((r) => r.status.awaitingReview)
      .length;
});

/// Routes dispatched to a transporter — marketplace + accepted (§5).
final transporterDispatchesProvider = FutureProvider.autoDispose
    .family<List<DispatchedRoute>, String>((ref, companyId) async {
  return ref.watch(requestServiceProvider).listTransporterDispatches(companyId);
});

/// Which transporter(s) a request was actually dispatched to.
///
/// Read by the console's linked-request panel, which is history rather than an
/// in-progress selection and so must come from the record, not from the local
/// picker state that is reset every time a row is opened.
final requestDispatchedTransportersProvider = FutureProvider.autoDispose
    .family<Set<String>, String>((ref, requestId) async {
  return ref
      .watch(requestServiceProvider)
      .listDispatchedTransporterIds(requestId);
});

/// Transporter companies for the admin's dispatch picker (§8.3/8.4).
final transporterCompaniesProvider = FutureProvider.autoDispose
    .family<List<({String id, String name})>, void>((ref, _) async {
  return ref.watch(requestServiceProvider).listTransporters();
});

/// MineSupplier companies for the representative's supplier picker (§8.4).
final mineCompaniesProvider = FutureProvider.autoDispose
    .family<List<({String id, String name})>, void>((ref, _) async {
  return ref.watch(requestServiceProvider).listMines();
});

/// Buyer companies for the representative's buying-company picker.
///
/// Needed to turn a mine's "Requested buyers" enquiry into a real order: the
/// admin names the buyer the mine is being introduced to.
final buyerCompaniesProvider = FutureProvider.autoDispose
    .family<List<({String id, String name})>, void>((ref, _) async {
  return ref.watch(requestServiceProvider).listBuyers();
});
