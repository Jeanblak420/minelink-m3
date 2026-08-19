// ============================================================================
// Portal navigation badges — the live queue counts behind the rail (P7-05)
// ----------------------------------------------------------------------------
// `portal_nav.dart` names a badge's SOURCE and never a number, so the tree
// stays a pure value. This file is where a source becomes an integer.
//
// Three rules hold throughout, and they are the reason this is a separate file
// rather than a handful of `ref.watch` calls in the shell:
//
//   1. **A badge agrees with the screen it points at.** Each count reads the
//      same provider the destination renders, so the rail and the page can
//      never disagree about how much work is waiting.
//   2. **Only what the tree asks for is queried.** A driver's rail must not
//      fire the mine's inbound-trips query. The needed set is derived from the
//      session's own tree, and nothing outside it is watched.
//   3. **Loading and error resolve to no badge, never to zero.** A count that
//      failed to load is not "nothing waiting" — that conflation is the same
//      class of fault as the empty partner list that hid an RLS denial.
// ============================================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter_application_1/features/auth/models/user_type.dart';
import 'package:flutter_application_1/features/fleet/providers/maintenance_providers.dart';
import 'package:flutter_application_1/features/notifications/providers/notification_provider.dart';
import 'package:flutter_application_1/features/portal/models/compliance_document.dart';
import 'package:flutter_application_1/features/portal/models/recon_dispute.dart';
import 'package:flutter_application_1/features/portal/models/transportation_request.dart';
import 'package:flutter_application_1/features/portal/nav/portal_nav.dart';
import 'package:flutter_application_1/features/portal/providers/lifecycle_provider.dart';
import 'package:flutter_application_1/features/portal/providers/request_provider.dart';
import 'package:flutter_application_1/features/portal/services/compliance_service.dart';
import 'package:flutter_application_1/features/portal/services/dispute_service.dart';

/// Identifies whose rail is being counted.
typedef PortalBadgeScope = ({
  OrgType orgType,
  UserRole? role,
  String companyId,
});

/// Live queue sizes for every badge the session's tree actually names.
///
/// Keys are absent rather than zero when a source is still loading or has
/// failed; the rail renders nothing for a missing or zero entry.
final portalNavBadgeCountsProvider = Provider.autoDispose
    .family<Map<PortalNavBadge, int>, PortalBadgeScope>((ref, scope) {
  final needed = <PortalNavBadge>{
    for (final leaf in portalNavTree(orgType: scope.orgType, role: scope.role)
        .expand((n) => n.leaves))
      if (leaf.badge != null) leaf.badge!,
  };

  final counts = <PortalNavBadge, int>{};
  void put(PortalNavBadge badge, int? count) {
    if (count != null && count > 0) counts[badge] = count;
  }

  if (needed.contains(PortalNavBadge.unreadNotifications)) {
    put(PortalNavBadge.unreadNotifications,
        ref.watch(notificationProvider).unreadCount);
  }

  if (needed.contains(PortalNavBadge.pendingRequests)) {
    // Only `sent_back` counts. `requested` and `resubmitted` are sitting with
    // the platform admin — nothing for this org to do — and counting them
    // would reproduce the console's own "Pending requests" fault, where
    // `listForAdmin` has no status filter and every request ever raised is
    // reported as pending (P9-02).
    //
    // Reads the same provider the Requests screen renders, so the badge and
    // the page agree. ⚠ That provider filters on `buyer_company_id` for a mine
    // too, which is the semantics corruption P3-46 describes; when that is
    // fixed, this count follows the screen's fix rather than needing its own.
    put(
      PortalNavBadge.pendingRequests,
      ref.watch(companyRequestsProvider(scope.companyId)).valueOrNull?.where((r) {
        return r.status == RequestStatus.sentBack;
      }).length,
    );
  }

  if (needed.contains(PortalNavBadge.unacceptedDispatches)) {
    put(
      PortalNavBadge.unacceptedDispatches,
      ref
          .watch(transporterDispatchesProvider(scope.companyId))
          .valueOrNull
          ?.where((d) => d.status == DispatchStatus.dispatched)
          .length,
    );
  }

  if (needed.contains(PortalNavBadge.openDisputes)) {
    // `open` and `under_review` are both unresolved — a dispute someone is
    // already looking at is still a dispute this org is waiting on.
    put(
      PortalNavBadge.openDisputes,
      ref
          .watch(reconDisputesProvider(scope.companyId))
          .valueOrNull
          ?.where((d) =>
              d.status == DisputeStatus.open ||
              d.status == DisputeStatus.underReview)
          .length,
    );
  }

  if (needed.contains(PortalNavBadge.expiringCompliance)) {
    // Expired counts alongside expiring: a lapsed certificate is more urgent
    // than one about to lapse, and dropping it would make the badge fall
    // silent at exactly the moment it matters.
    put(
      PortalNavBadge.expiringCompliance,
      ref
          .watch(complianceDocumentsProvider(scope.companyId))
          .valueOrNull
          ?.where((d) =>
              d.status == ComplianceStatus.expiring ||
              d.status == ComplianceStatus.expired)
          .length,
    );
  }

  // Both mine-floor queues come off one read. `isInbound` is scheduled or on
  // the way and not yet checked in; `isOnSite` is checked in and not yet
  // loaded — the two halves of the gate-to-weighbridge handover.
  final needsInbound = needed.contains(PortalNavBadge.arrivalsAwaitingCheckIn) ||
      needed.contains(PortalNavBadge.loadsAwaitingWeigh);
  if (needsInbound) {
    final trips = ref.watch(mineInboundTripsProvider(scope.companyId)).valueOrNull;
    put(PortalNavBadge.arrivalsAwaitingCheckIn,
        trips?.where((t) => t.isInbound).length);
    put(PortalNavBadge.loadsAwaitingWeigh,
        trips?.where((t) => t.isOnSite).length);
  }

  if (needed.contains(PortalNavBadge.maintenanceDue)) {
    // `dueSoon` mirrors the server-side `notify_service_due_job` predicate, so
    // the badge, the Maintenance screen and the nightly reminder all agree on
    // what "due" means.
    put(
      PortalNavBadge.maintenanceDue,
      ref
          .watch(fleetMaintenanceProvider(scope.companyId))
          .valueOrNull
          ?.schedules
          .where((s) => s.dueSoon)
          .length,
    );
  }

  return counts;
});
