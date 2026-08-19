import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_application_1/features/portal/providers/logistics_provider.dart';
import 'package:flutter_application_1/features/portal/utils/portal_company_resolution.dart';
import 'package:flutter_application_1/features/portal/providers/truck_highlight_provider.dart';
import 'package:flutter_application_1/features/portal/widgets/truck_locations_panel.dart';
import 'package:flutter_application_1/features/portal/widgets/portal_company_required.dart';
import 'package:flutter_application_1/core/design/components/ml_page_body.dart';
import 'package:flutter_application_1/features/portal/widgets/ml/ml.dart';
import 'package:flutter_application_1/core/design/components/ml_page_header.dart';

/// Same underlying data as truck locations; focused table for dispatchers.
class TransporterTruckPositionsScreen extends ConsumerWidget {
  const TransporterTruckPositionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final companyId = resolvePortalCompanyId(ref);
    if (companyId == null) {
      return const PortalCompanyRequired();
    }

    final async = ref.watch(logisticsSnapshotProvider(companyId));

    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => MlLoadFailure(
          subject: 'the truck positions',
          error: e,
          onRetry: () => ref.invalidate(logisticsSnapshotProvider(companyId)),
      ),
      data: (snap) => MlPageBody(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            MlPageHeader(
              title: 'Truck positions',
              meta: mlCount(snap.positions.length, 'position'),
              description:
                  'Row-level view of the newest coordinates per eligible vehicle.',
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
              highlight: ref.watch(highlightedVehicleProvider),
              onSelect: (id) =>
                  ref.read(highlightedVehicleProvider.notifier).state = id,
              onClearHighlight: () =>
                  ref.read(highlightedVehicleProvider.notifier).state = null,
              emptyMessage:
                  'GPS is updated when trucks report from location via the Driver App.',
            ),
          ],
        ),
      ),
    );
  }
}
