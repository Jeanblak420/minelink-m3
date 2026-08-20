import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter_application_1/core/utils/safe_ref.dart';
import 'package:flutter_application_1/features/fleet/models/fleet_vehicle_model.dart';
import 'package:flutter_application_1/features/fleet/models/fleet_vehicle_status.dart';
import 'package:flutter_application_1/features/fleet/providers/fleet_provider.dart';
import 'package:flutter_application_1/features/fleet/widgets/driver_assignment_dialog.dart';
import 'package:flutter_application_1/features/portal/models/trip_status.dart';
import 'package:flutter_application_1/features/portal/utils/portal_company_resolution.dart';
import 'package:flutter_application_1/core/design/components/ml_components.dart';
import 'package:flutter_application_1/features/portal/widgets/portal_company_required.dart';

/// Transporter "Trucks On Route" (CLAUDE.md §4): every truck currently on an
/// active route, shown with its assigned driver and the route it's running.
/// Trucks return to Available automatically when their trip completes.
class TrucksOnRouteScreen extends ConsumerWidget {
  const TrucksOnRouteScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final companyId = resolvePortalCompanyId(ref);
    if (companyId == null) {
      return const PortalCompanyRequired();
    }
    final async = ref.watch(fleetStatusProvider(companyId));

    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => MlLoadFailure(
          subject: 'the trucks on route',
          error: e,
          onRetry: () => ref.invalidate(fleetStatusProvider(companyId)),
      ),
      data: (statuses) {
        final onRoute = statuses.where((s) => s.onRoute).toList();
        final availableCount = statuses.where((s) => s.available).length;

        return MlPageBody(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        MlPageHeader(
                          title: 'Trucks On Route',
                          meta: '${mlCount(onRoute.length, 'truck')} on route · '
                              '$availableCount available',
                          description:
                              'Trucks currently running a route, with their driver. '
                              'A truck returns to Available when its trip completes.',
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Refresh',
                    onPressed: () =>
                        ref.invalidate(fleetStatusProvider(companyId)),
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              LayoutBuilder(builder: (context, c) {
                final cols = c.maxWidth > 620 ? 3 : 1;
                const gap = 14.0;
                final w = cols == 1
                    ? c.maxWidth
                    : (c.maxWidth - gap * (cols - 1)) / cols;
                final tiles = [
                  MlStatCard(
                    label: 'On Route',
                    value: '${onRoute.length}',
                    icon: Icons.local_shipping_outlined,
                    tone: MlTone.transit,
                  ),
                  MlStatCard(
                    label: 'Available',
                    value: '$availableCount',
                    icon: Icons.check_circle_outline,
                    tone: MlTone.done,
                  ),
                  MlStatCard(
                    label: 'Fleet total',
                    value: '${statuses.length}',
                    icon: Icons.grid_view_outlined,
                    tone: MlTone.neutral,
                  ),
                ];
                return Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: [
                    for (final t in tiles) SizedBox(width: w, child: t),
                  ],
                );
              }),
              const SizedBox(height: 20),
              if (onRoute.isEmpty)
                MlCard(
                  child: const MlEmptyState(
                    icon: Icons.local_shipping_outlined,
                    title: 'No trucks are on a route.',
                    message:
                        'When you accept a route and assign trucks, they appear '
                        'here with their driver until the trip completes.',
                  ),
                )
              else
                for (final s in onRoute) ...[
                  _OnRouteCard(status: s, companyId: companyId),
                  const SizedBox(height: 12),
                ],
              const SizedBox(height: 60),
            ],
          ),
        );
      },
    );
  }
}

class _OnRouteCard extends ConsumerWidget {
  final FleetVehicleStatus status;
  final String companyId;
  const _OnRouteCard({required this.status, required this.companyId});

  /// Open the same dialog the Fleet screen uses, on the truck this card is for.
  ///
  /// The capability already existed — it was just not reachable from where the
  /// problem is visible. "No driver assigned" was printed here while the only
  /// Assign Driver button lived on `/portal/transporter/fleet`, so the one
  /// screen that tells you a truck is running without a driver was the one
  /// screen that could not do anything about it.
  Future<void> _assignDriver(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final notifier = ref.read(fleetProvider(companyId).notifier);

    // This screen watches `fleetStatusProvider`, which carries the on-route
    // rows but not the `FleetVehicle` the dialog needs — so the fleet list and
    // the selectable drivers are both loaded first. Awaited, not fired and
    // forgotten: an unawaited load is how the dialog would open empty.
    await notifier.loadFleetVehicles();
    await notifier.loadAvailableDrivers();

    // Guard BEFORE the read, not after it: `ref.read` on a disposed widget
    // throws `StateError`, so checking afterwards is checking too late.
    if (!context.mounted) return;

    FleetVehicle? vehicle;
    for (final v in ref.read(fleetProvider(companyId)).vehicles) {
      if (v.id == status.vehicleId) { vehicle = v; break; }
    }
    if (vehicle == null) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text('${status.registration} is not in the fleet list any '
              'more. Open Fleet to check it.'),
        ));
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (_) =>
          DriverAssignmentDialog(vehicle: vehicle!, companyId: companyId),
    );
    ref.invalidateIfMounted(fleetStatusProvider(companyId));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final semantic = MlSemantic.of(context);
    final tripLabel = status.tripStatus == null
        ? 'On route'
        : TripStatus.parse(status.tripStatus).label;

    Widget field(String label, String value) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label.toUpperCase(),
              style: TextStyle(
                fontFamily: MlTokens.fontSans,
                fontSize: 11,
                letterSpacing: 0.7,
                color: semantic.textFaint,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: MlTokens.fontSans,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: semantic.textStrong,
              ),
            ),
          ],
        );

    final route = [
      if (status.loadingPoint != null) status.loadingPoint,
      if (status.offloadingPoint != null) status.offloadingPoint,
    ].whereType<String>().join(' → ');

    return MlCard(
      padding: const EdgeInsets.all(16),
      child: LayoutBuilder(builder: (context, c) {
        final narrow = c.maxWidth < 640;
        final identity = Row(
          children: [
            const MlIconWell(
              icon: Icons.local_shipping_outlined,
              tone: MlTone.transit,
              size: 48,
              radius: 12,
            ),
            const SizedBox(width: 14),
            MlPlatePill(status.registration, fontSize: 14),
          ],
        );
        final fields = Wrap(
          spacing: 26,
          runSpacing: 10,
          children: [
            field('Drivers', status.driversLabel),
            if (status.buyerName != null) field('Customer', status.buyerName!),
            if (status.commodity != null) field('Product', status.commodity!),
            if (route.isNotEmpty) field('Route', route),
          ],
        );
        final badge = MlStatusBadge.forStatus(tripLabel);

        // A truck can be accepted onto a route, arrive, load and leave the gate
        // with nobody rostered on it — nothing in `accept_request_dispatch`
        // requires a driver. The trip then cannot be closed from the driver
        // app, because there is no driver to open it. Say so, and let it be
        // fixed from here.
        final warning = status.hasDriver
            ? null
            : Container(
                margin: const EdgeInsets.only(top: 14),
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: MlTone.warn.well(Theme.of(context).brightness),
                  borderRadius: BorderRadius.circular(MlTokens.rSm),
                ),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Icon(Icons.person_off_outlined,
                        size: 18,
                        color: MlTone.warn
                            .colors(Theme.of(context).brightness)
                            .fg),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 460),
                      child: Text(
                        'No driver is assigned to this truck. It cannot report '
                        'its position or upload a proof of delivery until one is.',
                        style: TextStyle(
                          fontFamily: MlTokens.fontSans,
                          fontSize: 12.5,
                          color: semantic.textStrong,
                        ),
                      ),
                    ),
                    MlButton.outline(
                      label: 'Assign driver',
                      icon: Icons.person_add_alt_1_outlined,
                      compact: true,
                      onPressed: () => _assignDriver(context, ref),
                    ),
                  ],
                ),
              );

        if (narrow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: identity),
                  badge,
                ],
              ),
              const SizedBox(height: 12),
              fields,
              if (warning != null) warning,
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                identity,
                const SizedBox(width: 18),
                Expanded(child: fields),
                const SizedBox(width: 12),
                badge,
              ],
            ),
            if (warning != null) warning,
          ],
        );
      }),
    );
  }
}
