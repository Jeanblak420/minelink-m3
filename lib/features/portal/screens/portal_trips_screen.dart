import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:flutter_application_1/features/operations/models/operations_models.dart';
import 'package:flutter_application_1/features/portal/models/logistics_models.dart';
import 'package:flutter_application_1/features/portal/models/trip_status.dart';
import 'package:flutter_application_1/features/portal/providers/logistics_provider.dart';
import 'package:flutter_application_1/features/portal/utils/portal_company_resolution.dart';
import 'package:flutter_application_1/features/portal/utils/trip_status_tone.dart';
import 'package:flutter_application_1/core/design/components/ml_components.dart';
import 'package:flutter_application_1/features/portal/widgets/portal_company_required.dart';
import 'package:flutter_application_1/core/utils/friendly_error.dart';
import 'package:flutter_application_1/core/time/ml_time.dart';

// Extracted from `app_router.dart` (P4-01…P4-07). It was declared inside
// the router itself, which is why it had no screen file and no test.
/// Thin trips LIST for `/portal/{mine,buyer,transporter}/trips` (phase-2 T5).
/// No ML port: renders the org's trips from the SAME party-scoped
/// [logisticsSnapshotProvider] the portal dashboards use, styled with
/// MlTokens. Tapping a trip opens `$basePath/:id` (thin detail below).
class PortalTripsScreen extends ConsumerWidget {
  const PortalTripsScreen({super.key, required this.basePath});

  /// The org-scoped trips route this list lives under, e.g.
  /// `/portal/mine/trips` — detail links are built from it.
  final String basePath;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final companyId = resolvePortalCompanyId(ref);
    if (companyId == null) {
      return const PortalCompanyRequired(subject: 'trips');
    }
    final semantic = MlSemantic.of(context);
    return ref.watch(logisticsSnapshotProvider(companyId)).when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => MlEmptyState(
            icon: Icons.error_outline,
            title: 'Could not load trips',
            message: friendlyError(e),
            action: MlButton.tonal(
              label: 'Try again',
              icon: Icons.refresh_rounded,
              onPressed: () =>
                  ref.invalidate(logisticsSnapshotProvider(companyId)),
            ),
          ),
          data: (snap) {
            final trips = snap.trips;
            final txnById = <String, OperationTransaction>{
              for (final w in snap.waybills) w.id: w,
            };
            return MlPageBody(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  MlPageHeader(
                    title: 'Trips',
                    meta: mlCount(trips.length, 'trip'),
                    description:
                        'Every trip on this company\'s transactions, newest first. '
                        'Open a trip for its detail and linked waybill.',
                  ),
                  const SizedBox(height: 16),
                  if (trips.isEmpty)
                    const MlEmptyState(
                      icon: Icons.local_shipping_outlined,
                      title: 'No trips yet',
                      message:
                          'Trips appear here once a linked route is dispatched.',
                    )
                  else
                    Container(
                      decoration: BoxDecoration(
                        color: semantic.surfaceCard,
                        borderRadius: BorderRadius.circular(MlTokens.rLg),
                        border: Border.all(color: semantic.borderCard),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: trips.length,
                        separatorBuilder: (_, __) =>
                            Divider(height: 1, color: semantic.borderCard),
                        itemBuilder: (context, i) => _PortalTripRow(
                          trip: trips[i],
                          transaction: txnById[trips[i].transactionId],
                          onTap: () =>
                              context.go('$basePath/${trips[i].id}'),
                        ),
                      ),
                    ),
                  const SizedBox(height: 60),
                ],
              ),
            );
          },
        );
  }
}

class _PortalTripRow extends StatelessWidget {
  const _PortalTripRow({
    required this.trip,
    required this.transaction,
    required this.onTap,
  });

  final TripRecord trip;
  final OperationTransaction? transaction;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final semantic = MlSemantic.of(context);
    final brightness = Theme.of(context).brightness;
    final status = TripStatus.parse(trip.status);
    final tone = tripStatusTone(status);
    final reference = transaction?.referenceNumber;
    final commodity = transaction?.metadata['commodity'] as String?;
    final net = trip.netTons;
    final subtitle = [
      if (reference != null && reference.isNotEmpty) reference,
      if (commodity != null && commodity.isNotEmpty) commodity,
      if (net != null) '${net.toStringAsFixed(2)} t',
      'Updated ${MlTime.day(trip.updatedAt)}',
    ].join(' · ');
    return ListTile(
      onTap: onTap,
      leading: Icon(Icons.local_shipping_outlined,
          color: tone.colors(brightness).fg),
      title: Text(
        trip.truckReg ?? reference ?? 'Trip ${trip.id.substring(0, 8)}…',
        style: TextStyle(
          fontFamily: MlTokens.fontMono,
          fontWeight: FontWeight.w700,
          color: semantic.textStrong,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
      subtitle: Text(subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: semantic.textMuted)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          MlStatusBadge(label: status.label, tone: tone),
          const SizedBox(width: 8),
          Icon(Icons.chevron_right_rounded, color: semantic.textFaint),
        ],
      ),
    );
  }
}
