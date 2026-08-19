import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_application_1/core/design/tokens/ml_tokens.dart';
import 'package:flutter_application_1/features/portal/models/logistics_models.dart';
import 'package:flutter_application_1/features/portal/models/trip_status.dart';
import 'package:flutter_application_1/features/portal/portal_colors.dart';
import 'package:flutter_application_1/features/portal/providers/truck_highlight_provider.dart';
import 'package:flutter_application_1/features/portal/utils/buyer_products.dart';
import 'package:flutter_application_1/features/portal/utils/portal_dashboard_navigation.dart';
import 'package:flutter_application_1/features/portal/widgets/premium_overview_widgets.dart';
import 'package:flutter_application_1/core/time/ml_time.dart';

/// A "My products" tile for the buyer dashboard (§7.1).
class BuyerProductTile extends StatelessWidget {
  final BuyerProduct product;
  final VoidCallback onTap;
  const BuyerProductTile({super.key, required this.product, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tons = product.tonsWindows(MlTime.now());
    return OverviewHeroTile(
      title: product.name,
      icon: Icons.diamond_outlined,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Tons received',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant)),
          AnimatedTons(
            value: tons.total,
            style: MlType.figure(
                color: PortalColors.accent, size: MlTokens.fsH1),
          ),
          const SizedBox(height: 8),
          Text(
            '${product.trips.length} trip(s) · ${product.loads} load(s) · '
            '${product.supplierIds.length} source(s)',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

/// Per-product detail (§7.2): tons D/W/M/Y/T, trucks/trips (tap to track),
/// active trips, and navigation to waybills / reconciliations.
Future<void> showBuyerProductDetailSheet({
  required BuildContext context,
  required WidgetRef ref,
  required BuyerProduct product,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _BuyerProductSheet(product: product, ref: ref),
  );
}

class _BuyerProductSheet extends StatelessWidget {
  final BuyerProduct product;
  final WidgetRef ref;
  const _BuyerProductSheet({required this.product, required this.ref});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tons = product.tonsWindows(MlTime.now());
    final active = product.activeTrips;

    void track(TripRecord trip) {
      if (trip.vehicleId == null) return;
      ref.read(highlightedVehicleProvider.notifier).state = trip.vehicleId;
      Navigator.of(context).pop();
      openPortalTabByLabel(ref, context, 'Truck locations');
    }

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.88),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(product.name,
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.w800)),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text('Tons received',
                  style: Theme.of(context)
                      .textTheme
                      .labelMedium
                      ?.copyWith(color: scheme.onSurfaceVariant)),
              AnimatedTons(
                value: tons.total,
                style: MlType.figure(
                    color: PortalColors.accent, size: MlTokens.fsH1),
              ),
              const SizedBox(height: 8),
              MetricBreakdownRow(label: 'Daily (D)', value: tons.daily),
              MetricBreakdownRow(label: 'Weekly (W)', value: tons.weekly),
              MetricBreakdownRow(label: 'Monthly (M)', value: tons.monthly),
              MetricBreakdownRow(label: 'Yearly (Y)', value: tons.yearly),
              MetricBreakdownRow(
                  label: 'Total (T)', value: tons.total, emphasize: true),
              const SizedBox(height: 18),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _action(context, Icons.description_outlined, 'View waybills',
                      () {
                    Navigator.of(context).pop();
                    openPortalTabByLabel(ref, context, 'Waybills');
                  }),
                  _action(context, Icons.balance_outlined, 'View / download recons',
                      () {
                    Navigator.of(context).pop();
                    openPortalTabByLabel(ref, context, 'Reconciliations');
                  }),
                ],
              ),
              const SizedBox(height: 20),
              Text('Active trips',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              if (active.isEmpty)
                Text('No active trips for this product.',
                    style: TextStyle(color: scheme.onSurfaceVariant))
              else
                for (final t in active)
                  _TripRow(trip: t, onTrack: () => track(t)),
              const SizedBox(height: 16),
              Text('All trips',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              if (product.trips.isEmpty)
                Text('No trips yet for this product.',
                    style: TextStyle(color: scheme.onSurfaceVariant))
              else
                for (final t in product.trips)
                  _TripRow(
                      trip: t,
                      onTrack: t.vehicleId == null ? null : () => track(t)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _action(
      BuildContext context, IconData icon, String label, VoidCallback onTap) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label),
    );
  }
}

class _TripRow extends StatelessWidget {
  final TripRecord trip;
  final VoidCallback? onTrack;
  const _TripRow({required this.trip, this.onTrack});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final status = TripStatus.parse(trip.status);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.local_shipping_outlined),
      title: Text(trip.truckReg ?? 'Trip ${trip.id.substring(0, 6)}…'),
      subtitle: Text(
        [
          status.label,
          if (trip.netTons != null) formatTons(trip.netTons!),
        ].join(' · '),
        style: TextStyle(color: scheme.onSurfaceVariant),
      ),
      trailing: onTrack == null
          ? null
          : TextButton.icon(
              onPressed: onTrack,
              icon: const Icon(Icons.location_on_outlined, size: 16),
              label: const Text('Track'),
            ),
    );
  }
}
