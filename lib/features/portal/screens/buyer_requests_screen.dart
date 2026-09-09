import 'package:flutter_application_1/core/design/tokens/m3/ml_shape.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_application_1/core/design/tokens/m3/ml_typography.dart';
import 'package:flutter_application_1/features/portal/models/transportation_request.dart';
import 'package:flutter_application_1/features/portal/models/trip_status.dart';
import 'package:flutter_application_1/features/portal/providers/request_provider.dart';
import 'package:flutter_application_1/features/portal/screens/request_transportation_screen.dart';
import 'package:flutter_application_1/features/portal/utils/portal_company_resolution.dart';
import 'package:flutter_application_1/features/portal/utils/request_grouping.dart';
import 'package:flutter_application_1/features/portal/widgets/available_routes_section.dart';
import 'package:flutter_application_1/features/portal/widgets/order_fill_line.dart';
import 'package:flutter_application_1/core/design/components/ml_components.dart';
import 'package:flutter_application_1/features/portal/widgets/request_attachment_chips.dart';
import 'package:flutter_application_1/features/portal/widgets/request_dialogs.dart';
import 'package:flutter_application_1/features/portal/widgets/request_tracking_view.dart';
import 'package:flutter_application_1/features/portal/widgets/portal_company_required.dart';
import 'package:flutter_application_1/features/tour/widgets/tour_target.dart';
import 'package:flutter_application_1/features/tour/examples/buyer_requests_keys.dart';
import 'package:flutter_application_1/core/utils/friendly_error.dart';
import 'package:flutter_application_1/core/time/ml_time.dart';

/// "Requests" — raise a transportation request and track its review status
/// (§7.5). Sent-back requests can be re-opened, edited and resubmitted.
///
/// Shared by buyers and (with [isMine]) mines/suppliers — the transportation
/// form is identical for both (§4 Request 1); only the second action differs:
/// buyers request products, mines request buyers.
class BuyerRequestsScreen extends ConsumerWidget {
  final bool isMine;
  const BuyerRequestsScreen({super.key, this.isMine = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final companyId = resolvePortalCompanyId(ref);
    if (companyId == null) {
      return const PortalCompanyRequired();
    }
    final mirror = portalMirrorActive(ref);
    final async = ref.watch(companyRequestsProvider(companyId));

    return Stack(
      children: [
        async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => MlLoadFailure(
            subject: 'your requests',
            error: e,
            onRetry: () => ref.invalidate(companyRequestsProvider(companyId)),
          ),
          data: (requests) => MlPageBody(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                MlPageHeader(
                  title: 'Requests',
                  meta: mlCount(requests.length, 'request'),
                  // A MINE DOES NOT REQUEST PRODUCTS. This sentence had no
                  // `isMine` branch, so the mine's own Requests screen
                  // named a request type it cannot raise and omitted the
                  // one it can — while the class doc four lines above says
                  // "buyers request products, mines request buyers" and the
                  // button under it said the same. §4 Request 2 is buyer
                  // only; Request 3 is mine/supplier only.
                  description: isMine
                      ? 'Raise transportation and buyer requests to the MineLink '
                            'representative and track their review.'
                      : 'Raise transportation and product requests to the MineLink '
                            'representative and track their review.',
                  // The screen's own actions belong to its header. They sat
                  // in a left `Wrap` BELOW it as stock Material — a
                  // `FilledButton.tonalIcon` next to a `FilledButton.icon`,
                  // two button languages side by side and neither of them
                  // the product's — with the header's own right end empty.
                  // Quieter first, so the org-specific action keeps the
                  // right edge it already had and matches the Buyers page.
                  actions: mirror
                      ? const []
                      : [
                          TourTarget(
                            id: 'requests.transportation',
                            targetKey:
                                BuyerRequestsTourKeys.transportationAction,
                            child: MlButton.tonal(
                              label: 'Request transportation',
                              icon: Icons.local_shipping_outlined,
                              compact: true,
                              onPressed: () =>
                                  _openForm(context, ref, companyId),
                            ),
                          ),
                          if (isMine)
                            TourTarget(
                              id: 'requests.primary_action',
                              targetKey: BuyerRequestsTourKeys.primaryAction,
                              child: MlButton.primary(
                                label: 'Request buyers',
                                icon: Icons.group_add_outlined,
                                compact: true,
                                onPressed: () => showBuyersRequestDialog(
                                  context,
                                  ref,
                                  companyId,
                                ),
                              ),
                            )
                          else
                            TourTarget(
                              id: 'requests.primary_action',
                              targetKey: BuyerRequestsTourKeys.primaryAction,
                              child: MlButton.primary(
                                label: 'Request products',
                                icon: Icons.add_shopping_cart_outlined,
                                compact: true,
                                onPressed: () => showProductRequestDialog(
                                  context,
                                  ref,
                                  companyId,
                                ),
                              ),
                            ),
                        ],
                ),
                const SizedBox(height: 16),
                TourTarget(
                  id: 'requests.available_routes',
                  targetKey: BuyerRequestsTourKeys.availableRoutes,
                  child: AvailableRoutesSection(
                    companyId: companyId,
                    enabled: !mirror,
                  ),
                ),
                TourTarget(
                  id: 'requests.list',
                  targetKey: BuyerRequestsTourKeys.requestsList,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (requests.isEmpty)
                        MlCard(
                          child: MlEmptyState(
                            icon: Icons.local_shipping_outlined,
                            title: 'No requests yet.',
                            message:
                                'Tap "Request transportation" to send your first request.',
                          ),
                        )
                      else
                        for (final section in groupRequestsByStatus(
                          requests,
                        )) ...[
                          _RequestSectionHeader(
                            group: section.group,
                            count: section.requests.length,
                          ),
                          for (final r in section.requests)
                            _RequestCard(
                              request: r,
                              onReopen: (mirror || !r.status.buyerCanEdit)
                                  ? null
                                  : () => _openForm(
                                      context,
                                      ref,
                                      companyId,
                                      existing: r,
                                    ),
                            ),
                        ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                TourTarget(
                  id: 'requests.tracking',
                  targetKey: BuyerRequestsTourKeys.tracking,
                  child: RequestTrackingView(companyId: companyId),
                ),
                const SizedBox(height: 80),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Sent-back requests reopen in the form they were created with: the
  /// transportation screen for route requests, the shared product/buyer
  /// dialog (pre-filled, resubmitting on send) for the other two types (§4).
  void _openForm(
    BuildContext context,
    WidgetRef ref,
    String companyId, {
    TransportationRequest? existing,
  }) {
    switch (existing?.requestType) {
      case 'product':
        showProductRequestDialog(context, ref, companyId, existing: existing);
      case 'buyer':
        showBuyersRequestDialog(context, ref, companyId, existing: existing);
      default:
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => RequestTransportationScreen(existing: existing),
          ),
        );
    }
  }
}

/// Header above each status group in the requests list — an accent icon, the
/// group title, and a count pill. Pulls pending/sent-back requests out of the
/// flat recency list so they stand out.
class _RequestSectionHeader extends StatelessWidget {
  final RequestGroup group;
  final int count;
  const _RequestSectionHeader({required this.group, required this.count});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (IconData icon, Color color) = switch (group) {
      RequestGroup.needsAction => (
        Icons.assignment_late_outlined,
        scheme.error,
      ),
      RequestGroup.pendingReview => (
        Icons.hourglass_top_outlined,
        scheme.tertiary,
      ),
      RequestGroup.active => (Icons.check_circle_outline, scheme.primary),
      RequestGroup.closed => (
        Icons.inventory_2_outlined,
        scheme.onSurfaceVariant,
      ),
    };
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Text(
            group.title.toUpperCase(),
            style: context.mlText.labelMedium.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: MlShape.pill,
            ),
            child: Text(
              '$count',
              style: context.mlText.labelMedium.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  final TransportationRequest request;
  final VoidCallback? onReopen;
  const _RequestCard({required this.request, this.onReopen});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final r = request;
    final title = switch (r.requestType) {
      'product' => r.commodity ?? 'Product request',
      'buyer' =>
        r.commodity != null ? '${r.commodity} · buyers' : 'Buyer request',
      _ => '${r.loadingPoint ?? '—'} → ${r.offloadingPoint ?? '—'}',
    };
    final typeLabel = switch (r.requestType) {
      'product' => 'Product',
      'buyer' => 'Buyers',
      _ => 'Transport',
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: MlCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: scheme.secondaryContainer,
                    borderRadius: MlShape.radiusSmall,
                  ),
                  child: Text(
                    typeLabel,
                    style: context.mlText.labelSmall.copyWith(
                      color: scheme.onSecondaryContainer,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    title,
                    // TWO lines: for a transport request the title IS the
                    // route — "Iron Hills Mining → Richards Bay" is 230px at
                    // 16px and this card gives it 175px between a type pill
                    // and a status badge.
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                ),
                MlStatusBadge(label: r.status.label, tone: _toneFor(r.status)),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              [
                if (r.requestType == 'transportation' && r.commodity != null)
                  r.commodity,
                if (r.tonsAvailable != null)
                  mlCountText(r.tonsAvailable, 'ton'),
                if (r.requestType == 'product' && r.offloadingPoint != null)
                  '→ ${r.offloadingPoint}',
                if (r.paymentTerms != null) r.paymentTerms,
                if (r.isOngoing)
                  'Ongoing'
                else if (r.startingDate != null)
                  'from ${MlTime.calendarDay(r.startingDate!)}',
              ].whereType<String>().join(' · '),
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
            if (r.status == RequestStatus.sentBack && r.adminNotes != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: scheme.tertiaryContainer.withValues(alpha: 0.4),
                  borderRadius: MlShape.radiusMedium,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.assignment_return_outlined, size: 18),
                    const SizedBox(width: 8),
                    Expanded(child: Text(r.adminNotes!)),
                  ],
                ),
              ),
            ],
            // The requester's own attachments (lab PDFs / product image).
            if (r.labResultPaths.isNotEmpty || r.productImagePath != null) ...[
              const SizedBox(height: 10),
              RequestAttachmentChips(request: r),
            ],
            // Once linked, show the trucks the transporter committed (§4) and
            // the live stockpile fill the mine is preparing for this order.
            if (r.status == RequestStatus.linked) ...[
              const SizedBox(height: 10),
              _AllocatedTrucksSection(requestId: r.id),
              OrderFillLine(requestId: r.id),
            ],
            if (onReopen != null) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: MlButton.tonal(
                  label: 'Edit & resubmit',
                  icon: Icons.edit_outlined,
                  compact: true,
                  onPressed: onReopen,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static MlTone _toneFor(RequestStatus status) {
    switch (status) {
      case RequestStatus.approved:
      case RequestStatus.linked:
        return MlTone.done;
      case RequestStatus.declined:
        return MlTone.error;
      case RequestStatus.sentBack:
        return MlTone.warn;
      case RequestStatus.resubmitted:
        return MlTone.atMine;
      case RequestStatus.requested:
        return MlTone.transit;
    }
  }
}

/// The trucks (and drivers) the transporter allocated to a linked request —
/// buyer-visible per §4. Empty until the transporter accepts the route.
class _AllocatedTrucksSection extends ConsumerWidget {
  final String requestId;
  const _AllocatedTrucksSection({required this.requestId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final async = ref.watch(allocatedTrucksProvider(requestId));

    return async.when(
      loading: () => const SizedBox(
        height: 24,
        child: Align(
          alignment: Alignment.centerLeft,
          child: SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
      error: (e, _) => Text(
        'Could not load allocated trucks. ${friendlyError(e)}',
        style: context.mlText.bodySmall.copyWith(
          color: scheme.onSurfaceVariant,
        ),
      ),
      data: (trucks) {
        if (trucks.isEmpty) {
          return Text(
            'Allocated trucks: none yet — the transporter has not accepted '
            'the route.',
            style: context.mlText.bodyMedium.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ALLOCATED TRUCKS',
              style: context.mlText.labelSmall.copyWith(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.7,
              ),
            ),
            const SizedBox(height: 6),
            // A `Wrap` lays its children out against UNBOUNDED width, so the
            // `Row` inside each chip took its natural size and the plate,
            // transporter, drivers and status ran straight off the card —
            // measured at 156px past a 412px phone, with the request's own
            // status badge pushed off the screen behind it (CLAUDE.md §10.4,
            // photographed 2026-08-21). Nothing ellipsised, because an
            // ellipsis needs a bound to engage against.
            //
            // `LayoutBuilder` supplies the bound the `Wrap` does not, and the
            // detail line is `Flexible` inside it so a long crew list
            // shortens rather than shoving the plate out. The plate itself is
            // never truncated: it is the identifier.
            LayoutBuilder(
              builder: (context, c) {
                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final t in trucks)
                      ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: c.maxWidth),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: scheme.surfaceContainerHighest.withValues(
                              alpha: 0.5,
                            ),
                            borderRadius: MlShape.radiusMedium,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              MlPlatePill(t.truckReg ?? '—', fontSize: 12),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  [
                                    if (t.transporterName != null)
                                      t.transporterName!,
                                    if (t.drivers != null) t.drivers!,
                                    TripStatus.parse(t.tripStatus).label,
                                  ].join(' · '),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: context.mlText.bodySmall.copyWith(
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        );
      },
    );
  }
}
