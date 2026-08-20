import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
import 'package:flutter_application_1/core/utils/friendly_error.dart';

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
                  description:
                      'Raise transportation and product requests to the MineLink '
                      'representative and track their review.',
                ),
                if (!mirror) ...[
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      FilledButton.tonalIcon(
                        onPressed: () => _openForm(context, ref, companyId),
                        icon: const Icon(
                          Icons.local_shipping_outlined,
                          size: 18,
                        ),
                        label: const Text('Request transportation'),
                      ),
                      if (isMine)
                        FilledButton.icon(
                          onPressed: () =>
                              showBuyersRequestDialog(context, ref, companyId),
                          icon: const Icon(Icons.group_add_outlined, size: 18),
                          label: const Text('Request buyers'),
                        )
                      else
                        FilledButton.icon(
                          onPressed: () =>
                              showProductRequestDialog(context, ref, companyId),
                          icon: const Icon(
                            Icons.add_shopping_cart_outlined,
                            size: 18,
                          ),
                          label: const Text('Request products'),
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 16),
                AvailableRoutesSection(companyId: companyId, enabled: !mirror),
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
                  for (final section in groupRequestsByStatus(requests)) ...[
                    _RequestSectionHeader(
                      group: section.group,
                      count: section.requests.length,
                    ),
                    for (final r in section.requests)
                      _RequestCard(
                        request: r,
                        onReopen: (mirror || !r.status.buyerCanEdit)
                            ? null
                            : () =>
                                _openForm(context, ref, companyId, existing: r),
                      ),
                  ],
                const SizedBox(height: 16),
                RequestTrackingView(companyId: companyId),
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
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
              color: color,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: color,
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
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    typeLabel,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: scheme.onSecondaryContainer,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
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
                if (r.tonsAvailable != null) '${r.tonsAvailable} tons',
                if (r.requestType == 'product' && r.offloadingPoint != null)
                  '→ ${r.offloadingPoint}',
                if (r.paymentTerms != null) r.paymentTerms,
                if (r.isOngoing)
                  'Ongoing'
                else if (r.startingDate != null)
                  'from ${MaterialLocalizations.of(context).formatShortDate(r.startingDate!)}',
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
                  borderRadius: BorderRadius.circular(10),
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
        style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
      ),
      data: (trucks) {
        if (trucks.isEmpty) {
          return Text(
            'Allocated trucks: none yet — the transporter has not accepted '
            'the route.',
            style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ALLOCATED TRUCKS',
              style: TextStyle(
                fontSize: 11,
                letterSpacing: 0.7,
                fontWeight: FontWeight.w700,
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final t in trucks)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest.withValues(
                        alpha: 0.5,
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        MlPlatePill(t.truckReg ?? '—', fontSize: 11.5),
                        const SizedBox(width: 8),
                        Text(
                          [
                            if (t.transporterName != null) t.transporterName!,
                            if (t.drivers != null) t.drivers!,
                            TripStatus.parse(t.tripStatus).label,
                          ].join(' · '),
                          style: TextStyle(
                            fontSize: 12,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }
}
