import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_application_1/features/portal/providers/logistics_provider.dart';
import 'package:flutter_application_1/features/portal/providers/truck_highlight_provider.dart';
import 'package:flutter_application_1/features/portal/utils/portal_company_resolution.dart';
import 'package:flutter_application_1/features/portal/widgets/truck_locations_panel.dart';
import 'package:flutter_application_1/features/portal/widgets/portal_company_required.dart';
import 'package:flutter_application_1/core/design/components/ml_components.dart';

class BuyerTruckLocationsScreen extends ConsumerWidget {
  const BuyerTruckLocationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final companyId = resolvePortalCompanyId(ref);
    if (companyId == null) {
      return const PortalCompanyRequired();
    }

    final async = ref.watch(logisticsSnapshotProvider(companyId));
    final highlight = ref.watch(highlightedVehicleProvider);

    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => MlLoadFailure(
          subject: 'the truck locations',
          error: e,
          onRetry: () => ref.invalidate(logisticsSnapshotProvider(companyId)),
      ),
      data: (snap) => MlPageBody(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            MlPageHeader(
              title: 'Truck locations',
              meta: mlCount(snap.positions.length, 'truck reporting',
                  'trucks reporting'),
              description:
                  'Latest GPS samples you are allowed to see: rows appear when a vehicle is on a trip '
                  'linked to a transaction where your company is the buyer (plus future supplier rules).',
              padding: EdgeInsets.zero,
            ),
            const SizedBox(height: 20),
            TruckLocationsPanel(
              positions: snap.positions,
              plateByVehicleId: {
                for (final t in snap.trips)
                  if (t.vehicleId != null &&
                      t.truckReg != null &&
                      t.truckReg!.isNotEmpty)
                    t.vehicleId!: t.truckReg!,
              },
              highlight: highlight,
              onSelect: (id) =>
                  ref.read(highlightedVehicleProvider.notifier).state = id,
              onClearHighlight: () =>
                  ref.read(highlightedVehicleProvider.notifier).state = null,
              emptyMessage:
                  'Trucks appear here when a vehicle is on a trip linked to one '
                  'of your transactions. GPS is updated when drivers report via '
                  'the Driver App.',
            ),
          ],
        ),
      ),
    );
  }
}
