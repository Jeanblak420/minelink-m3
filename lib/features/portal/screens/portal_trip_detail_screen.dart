import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter_application_1/features/operations/models/operations_models.dart';
import 'package:flutter_application_1/features/portal/models/logistics_models.dart';
import 'package:flutter_application_1/features/portal/models/trip_status.dart';
import 'package:flutter_application_1/features/portal/providers/logistics_provider.dart';
import 'package:flutter_application_1/features/portal/utils/portal_company_resolution.dart';
import 'package:flutter_application_1/features/portal/utils/trip_status_tone.dart';
import 'package:flutter_application_1/features/portal/widgets/ml/ml.dart';
import 'package:flutter_application_1/features/portal/widgets/portal_company_required.dart';
import 'package:flutter_application_1/features/portal/widgets/waybill_modal.dart';
import 'package:flutter_application_1/core/utils/friendly_error.dart';
import 'package:flutter_application_1/core/design/components/ml_page_body.dart';
import 'package:flutter_application_1/core/time/ml_time.dart';

// Extracted from `app_router.dart` (P4-01…P4-07). It was declared inside
// the router itself, which is why it had no screen file and no test.
/// Thin trip DETAIL for `/portal/{org}/trips/:id` (phase-2 T5): the trip's
/// lifecycle status + linked-transaction facts from the existing snapshot,
/// with "View waybill" opening the existing [showWaybillModal] flow
/// (server-authoritative `get_trip_waybill`). No ML port.
class PortalTripDetailScreen extends ConsumerWidget {
  const PortalTripDetailScreen({super.key, required this.tripId});

  final String tripId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final companyId = resolvePortalCompanyId(ref);
    if (companyId == null) {
      return const PortalCompanyRequired(subject: 'this trip');
    }
    return ref.watch(logisticsSnapshotProvider(companyId)).when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => MlEmptyState(
            icon: Icons.error_outline,
            title: 'Could not load this trip',
            message: friendlyError(e),
            action: MlButton.tonal(
              label: 'Try again',
              icon: Icons.refresh_rounded,
              onPressed: () =>
                  ref.invalidate(logisticsSnapshotProvider(companyId)),
            ),
          ),
          data: (snap) {
            TripRecord? trip;
            for (final t in snap.trips) {
              if (t.id == tripId) {
                trip = t;
                break;
              }
            }
            if (trip == null) {
              return const Center(
                child: MlEmptyState(
                  icon: Icons.local_shipping_outlined,
                  title: 'Trip not found',
                  message:
                      'This trip is not on one of your company\'s transactions.',
                ),
              );
            }
            OperationTransaction? txn;
            for (final w in snap.waybills) {
              if (w.id == trip.transactionId) {
                txn = w;
                break;
              }
            }
            return _tripDetailBody(context, ref, trip, txn);
          },
        );
  }

  Widget _tripDetailBody(
    BuildContext context,
    WidgetRef ref,
    TripRecord trip,
    OperationTransaction? txn,
  ) {
    final semantic = MlSemantic.of(context);
    final status = TripStatus.parse(trip.status);
    final tone = tripStatusTone(status);
    final meta = txn?.metadata ?? const <String, dynamic>{};
    final localizations = MaterialLocalizations.of(context);
    final facts = <(String, String)>[
      if (txn != null) ('Waybill number', txn.referenceNumber),
      if (trip.truckReg != null) ('Truck registration', trip.truckReg!),
      if (meta['commodity'] is String && (meta['commodity'] as String).isNotEmpty)
        ('Product', meta['commodity'] as String),
      if (meta['offloading_point'] is String &&
          (meta['offloading_point'] as String).isNotEmpty)
        ('Destination', meta['offloading_point'] as String),
      if (trip.netTons != null)
        ('Net mass', '${trip.netTons!.toStringAsFixed(2)} t'),
      (
        'Updated',
        '${localizations.formatShortDate(trip.updatedAt)} '
            '${localizations.formatTimeOfDay(TimeOfDay.fromDateTime(MlTime.sast(trip.updatedAt)))}',
      ),
    ];
    return MlPageBody(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  trip.truckReg ?? 'Trip ${trip.id.substring(0, 8)}…',
                  // A plate is a code, not a numeral — mono, and tabular so
                  // the digits do not shift width between one reg and the
                  // next in a list. It was already mono; the tabular figures
                  // are what `MlType.code` adds (S5-7).
                  style: MlType.code(
                    color: MlSemantic.of(context).textStrong,
                    size: MlTokens.fsH1,
                    weight: FontWeight.w800,
                  ),
                ),
              ),
              MlStatusBadge(label: status.label, tone: tone, dot: true),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: semantic.surfaceCard,
              borderRadius: BorderRadius.circular(MlTokens.rLg),
              border: Border.all(color: semantic.borderCard),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final (label, value) in facts)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 160,
                          child: Text(
                            label,
                            style: TextStyle(
                              color: semantic.textMuted,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            value,
                            style: TextStyle(
                              color: semantic.textStrong,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 6),
                FilledButton.icon(
                  onPressed: () => showWaybillModal(
                    context,
                    ref,
                    tripId: trip.id,
                    waybillNumber: txn?.referenceNumber,
                  ),
                  icon: const Icon(Icons.receipt_long_outlined, size: 18),
                  label: const Text('View waybill'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 60),
        ],
      ),
    );
  }
}
