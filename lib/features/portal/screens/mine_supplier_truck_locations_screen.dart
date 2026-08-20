import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_application_1/features/portal/providers/logistics_provider.dart';
import 'package:flutter_application_1/features/portal/providers/truck_highlight_provider.dart';
import 'package:flutter_application_1/features/portal/utils/portal_company_resolution.dart';
import 'package:flutter_application_1/features/portal/widgets/truck_locations_panel.dart';
import 'package:flutter_application_1/features/portal/widgets/portal_company_required.dart';
import 'package:flutter_application_1/core/design/components/ml_components.dart';

/// Mine/Supplier live truck locations (§3.6): map with truck pins plus a list
/// of the latest GPS samples for vehicles on trips linked to this mine.
///
/// [highlightVehicleId] lets a trip tapped elsewhere in the app open this
/// screen with that truck pre-selected on the map.
class MineSupplierTruckLocationsScreen extends ConsumerWidget {
  final String? highlightVehicleId;

  const MineSupplierTruckLocationsScreen({super.key, this.highlightVehicleId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final companyId = resolvePortalCompanyId(ref);
    if (companyId == null) {
      return const PortalCompanyRequired();
    }

    final async = ref.watch(logisticsSnapshotProvider(companyId));
    // Explicit param wins; otherwise honour the global "track this truck" pick.
    final highlight = highlightVehicleId ?? ref.watch(highlightedVehicleProvider);

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
                  'Live GPS for trucks on trips loading at or leaving your mine. '
                  'Tap a truck anywhere in the app to highlight it here.',
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
              onClearHighlight: highlightVehicleId == null
                  ? () => ref
                      .read(highlightedVehicleProvider.notifier)
                      .state = null
                  : null,
              emptyMessage:
                  'Vehicles appear once they are on an active trip for your '
                  'mine. GPS is updated when drivers report via the Driver App.',
            ),
          ],
        ),
      ),
    );
  }
}
