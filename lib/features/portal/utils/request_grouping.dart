import 'package:flutter_application_1/features/portal/models/transportation_request.dart';

/// Buckets for the submitter's grouped Requests list, in priority order:
/// what needs the submitter's action first, then what's waiting on the admin,
/// then approved/dispatched work, then finished requests.
enum RequestGroup { needsAction, pendingReview, active, closed }

extension RequestGroupDisplay on RequestGroup {
  String get title => switch (this) {
        RequestGroup.needsAction => 'Needs your action',
        RequestGroup.pendingReview => 'Pending review',
        RequestGroup.active => 'Active',
        RequestGroup.closed => 'Closed',
      };
}

/// One rendered section: a [group] and the requests that fall in it (order
/// preserved from the source list).
class RequestSection {
  final RequestGroup group;
  final List<TransportationRequest> requests;

  const RequestSection({required this.group, required this.requests});
}

/// The group a single request belongs to.
///
/// - `sentBack` → needsAction (the submitter must edit + resubmit)
/// - `requested` / `resubmitted` → pendingReview (awaiting the admin)
/// - `approved` / `linked` → active
/// - `declined` → closed
RequestGroup groupForStatus(RequestStatus status) {
  if (status.buyerCanEdit) return RequestGroup.needsAction; // sentBack
  if (status.awaitingReview) return RequestGroup.pendingReview;
  if (status == RequestStatus.approved || status == RequestStatus.linked) {
    return RequestGroup.active;
  }
  return RequestGroup.closed; // declined
}

/// Groups [requests] into ordered [RequestSection]s (needsAction →
/// pendingReview → active → closed). Order WITHIN each group is preserved from
/// [requests] (the provider returns them newest-updated first). Empty groups
/// are omitted so the UI never renders a header with nothing under it.
List<RequestSection> groupRequestsByStatus(
  List<TransportationRequest> requests,
) {
  final byGroup = <RequestGroup, List<TransportationRequest>>{};
  for (final r in requests) {
    byGroup.putIfAbsent(groupForStatus(r.status), () => []).add(r);
  }
  return [
    for (final g in RequestGroup.values)
      if ((byGroup[g] ?? const []).isNotEmpty)
        RequestSection(group: g, requests: byGroup[g]!),
  ];
}
