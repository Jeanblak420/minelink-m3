import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter_application_1/core/design/tokens/m3/ml_typography.dart';
import 'package:flutter_application_1/features/operations/models/operations_models.dart';
import 'package:flutter_application_1/features/portal/models/logistics_models.dart';
import 'package:flutter_application_1/features/portal/models/trip_status.dart';
import 'package:flutter_application_1/features/portal/providers/logistics_provider.dart';
import 'package:flutter_application_1/features/portal/utils/portal_company_resolution.dart';
import 'package:flutter_application_1/features/portal/utils/trip_status_tone.dart';
import 'package:flutter_application_1/core/design/components/ml_components.dart';
import 'package:flutter_application_1/features/portal/widgets/portal_company_required.dart';
import 'package:flutter_application_1/features/portal/widgets/waybill_modal.dart';
import 'package:flutter_application_1/core/utils/friendly_error.dart';
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
    // (label, value, isCode) — a CODE or a FIGURE is mono, everything
    // else is the body face. `docs/design-reference.md` §5.3: Fraunces for
    // display numerals, JetBrainsMono for figures in columns,
    // PlusJakartaSans elsewhere. `TRP-000123` and `34.90 t` were both
    // PlusJakartaSans w600 here — the same drift `4ef7ee1` fixed on
    // `MetricBreakdownRow`, and the plate two lines above this table is
    // already `MlType.code`. A waybill number that reads in one face on
    // the recon table and another here is one reference, two products.
    final facts = <(String, String, bool)>[
      if (txn != null) ('Waybill number', txn.referenceNumber, true),
      // NOT "Truck registration". The plate is the hero at the top of this
      // screen, in 32px mono; repeating it as the second row of the fact table
      // spent a line saying what the reader had already read.
      if (meta['commodity'] is String && (meta['commodity'] as String).isNotEmpty)
        ('Product', meta['commodity'] as String, false),
      // SOURCE and DESTINATION, not destination alone. The recon table names
      // both for every load and this screen named half of it, so a trip could
      // be read here without knowing which mine it came out of.
      if (meta['loading_point'] is String &&
          (meta['loading_point'] as String).isNotEmpty)
        ('Source', meta['loading_point'] as String, false),
      if (meta['offloading_point'] is String &&
          (meta['offloading_point'] as String).isNotEmpty)
        ('Destination', meta['offloading_point'] as String, false),
      if (trip.netTons != null)
        ('Net mass', '${trip.netTons!.toStringAsFixed(2)} t', true),
      // THE DATE CAME FROM UTC AND THE TIME FROM SAST.
      //
      // `formatShortDate(trip.updatedAt)` formatted the raw instant while the
      // line beside it converted, so a trip updated at 01:30 SAST — 23:30 UTC
      // the previous day — printed the previous day's date next to 01:30. That
      // is the fault CLAUDE.md §7.1 was written for, on the screen that says
      // when a load moved. It was also the READER'S LOCALE: an American
      // buyer's screen said `8/15/2026 9:30 AM` where a South African's said
      // `15/08/2026 09:30`, for the same load.
      ('Updated', MlTime.stamp(trip.updatedAt), false),
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
          // A CARD, AND A CARD SAYS WHAT IT IS.
          //
          // This was a hand-rolled `Container` repainting `MlCard`'s own
          // surface, radius and border by hand, with no heading at all —
          // so the one panel on the screen floated under the plate
          // unlabelled. `MlCard` + `MlSectionTitle` is what every other
          // panel in the portal is.
          //
          // NO META, deliberately. §5.4 asks every section for one, and 15
          // of the 63 section titles in this product correctly have none:
          // there is no count here, and every fact worth putting in a meta
          // is already a row below it. This pass has found a meta that
          // counted the wrong thing four times; inventing one here would
          // be the fifth.
          MlCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const MlSectionTitle(
                  'Trip facts',
                  margin: EdgeInsets.only(bottom: 14),
                ),
                for (final (label, value, isCode) in facts)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // The label column RIDES THE TEXT SCALER.
                        //
                        // It was a flat 160px under a per-user type size, which
                        // is the fault `MlColumn.minWidth` was written for one
                        // table over: at 1.0 it over-paid (the longest label
                        // here, "Waybill number", wants about 100px) and at the
                        // 1.3 ceiling it squeezed the VALUE column instead —
                        // the half a reader is here for.
                        SizedBox(
                          width: MediaQuery.textScalerOf(context).scale(120),
                          child: Text(
                            label,
                            style: context.mlText.bodyMedium.copyWith(
                              color: semantic.textMuted,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            value,
                            style: isCode
                                ? MlType.code(
                                    color: semantic.textStrong,
                                    size: MlTokens.fsBody,
                                    weight: FontWeight.w600,
                                  )
                                : context.mlText.bodyMedium.copyWith(
                                    color: semantic.textStrong,
                                    fontWeight: FontWeight.w600,
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 6),
                // Stock Material on a redesigned screen — the same drift
                // the Requests screen's two buttons carried, in the same
                // pass. `MlButton` is the product's button.
                MlButton.primary(
                  label: 'View waybill',
                  icon: Icons.receipt_long_outlined,
                  compact: true,
                  onPressed: () => showWaybillModal(
                    context,
                    ref,
                    tripId: trip.id,
                    waybillNumber: txn?.referenceNumber,
                  ),
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
