import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter_application_1/core/design/tokens/m3/ml_typography.dart';
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
// The action goes in the header's own slot, not a Row wrapped around
              // it: a Row hands an unflexed action UNBOUNDED width (CLAUDE.md
              // 10.4) and squeezes the Expanded title to whatever is left. The
              // slot drops the action under the title instead.
              MlPageHeader(
                // Sentence case, like the rest of the product — and like
                // the app bar directly above it, which already read
                // `Trucks on route`. The screen spelled its own name two
                // ways in one picture.
                title: 'Trucks on route',
                meta: '${mlCount(onRoute.length, 'truck')} on route · '
                    '$availableCount available',
                description:
                    'Trucks currently running a route, with their driver. '
                    'A truck returns to Available when its trip completes.',
                actions: [
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
                    label: 'On route',
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
              style: context.mlText.labelSmall.copyWith(
                color: semantic.textFaint,
                fontWeight: FontWeight.w400,
                letterSpacing: 0.7,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.mlText.titleSmall.copyWith(
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
          mainAxisSize: MainAxisSize.min,
          children: [
            const MlIconWell(
              icon: Icons.local_shipping_outlined,
              tone: MlTone.transit,
              size: 48,
              radius: 12,
            ),
            const SizedBox(width: 14),
            // `Flexible`, because a plate pill is fixed content in a `Row`.
            //
            // A non-flex child of a Row is laid out against UNBOUNDED width
            // (CLAUDE.md §10.4, first rule), so the pill's own
            // `overflow: ellipsis` never engaged and it ran 21px past the card
            // at 360px × text scale 1.3 — a 48px icon well plus 14px plus a
            // registration at 1.3 does not fit 188px, and something has to
            // give. Ellipsising a plate is a real loss; painting the overflow
            // stripe over the badge beside it loses the same characters AND
            // the neighbour.
            //
            // Third time this exact shape has bitten this session — the recon
            // and quality tables were the other two, and they are fixed by
            // `MlColumn.minWidth` because a table can widen. A card cannot.
            Flexible(child: MlPlatePill(status.registration, fontSize: 14)),
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
                        style: context.mlText.bodyMedium.copyWith(
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

        // A truck that already has a driver still needs a way to the same
        // dialog: it is the only place a SECOND driver (two by default, five
        // with the super-admin's approval — CLAUDE.md §4) can be added from,
        // and until 2026-08-23 this card offered the dialog only while the
        // truck had nobody on it, and the Fleet row only offered Unassign.
        // Driven and measured: "1/2 drivers assigned" could not be reached
        // from any screen once the first driver was on.
        final manage = status.hasDriver
            ? Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: MlButton.outline(
                    label: 'Manage drivers',
                    icon: Icons.manage_accounts_outlined,
                    compact: true,
                    onPressed: () => _assignDriver(context, ref),
                  ),
                ),
              )
            : null;

        if (narrow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // MEASURED, NOT SPLIT BY FLEX — because the badge is not short.
              //
              // This was `Row(Expanded(identity), badge)`, and an unflexed
              // child of a Row takes its natural width FIRST: the badge was
              // served before the plate, and the plate got the remainder.
              // With `ON ROUTE` in it that was invisible; the moment the
              // fixture stopped lying about which truck was on route the
              // badge read `EN ROUTE TO OFFLOAD`, and on a 412px phone at
              // text scale 1.0 the plate rendered `JD 22 PL …` — the row's
              // identity, ellipsised, to make room for its own subtitle. At
              // 360 × 1.6 the identity Row was squeezed to 41.3px and
              // overflowed by 21.
              //
              // `MlHeaderLayout` is the same fit rule the two page headers
              // use: share a row when `identity + gap + badge` fits, and
              // otherwise give the badge its own row underneath. A plate is
              // never traded for a status word again, and a status word is
              // never truncated to keep a plate.
              MlHeaderLayout(
                title: identity,
                tools: Align(
                  // `widthFactor: 1` so the loose measuring pass sees the
                  // badge's own width; without it an Align expands to the
                  // constraint and the fit test could never pass.
                  alignment: Alignment.centerLeft,
                  widthFactor: 1,
                  child: badge,
                ),
              ),
              const SizedBox(height: 12),
              fields,
              if (warning != null) warning else if (manage != null) manage,
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
            if (warning != null) warning else if (manage != null) manage,
          ],
        );
      }),
    );
  }
}
