import 'package:flutter_application_1/core/design/tokens/m3/ml_shape.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_application_1/core/utils/safe_ref.dart';
import 'package:flutter_application_1/features/fleet/models/fleet_vehicle_status.dart';
import 'package:flutter_application_1/features/fleet/providers/fleet_provider.dart';
import 'package:flutter_application_1/features/portal/models/logistics_models.dart';
import 'package:flutter_application_1/features/portal/models/transportation_request.dart';
import 'package:flutter_application_1/features/portal/models/trip_status.dart';
import 'package:flutter_application_1/features/portal/portal_colors.dart';
import 'package:flutter_application_1/features/portal/providers/logistics_provider.dart';
import 'package:flutter_application_1/features/portal/providers/request_provider.dart';
import 'package:flutter_application_1/features/portal/widgets/premium_overview_widgets.dart';
import 'package:flutter_application_1/core/design/tokens/ml_tokens.dart';
import 'package:flutter_application_1/core/utils/friendly_error.dart';

/// Per-route delivery metrics derived from the trips created off a dispatch.
class RouteMetrics {
  final int totalTrips;
  final int activeTrips;
  final int loads; // trips that have a recorded net load
  final double tonsDelivered;

  const RouteMetrics({
    required this.totalTrips,
    required this.activeTrips,
    required this.loads,
    required this.tonsDelivered,
  });

  factory RouteMetrics.fromTrips(Iterable<TripRecord> trips) {
    var active = 0, loads = 0;
    var tons = 0.0;
    for (final t in trips) {
      if (TripStatus.parse(t.status).isActive) active++;
      if (t.netTons != null) {
        loads++;
        tons += t.netTons!;
      }
    }
    return RouteMetrics(
      totalTrips: trips.length,
      activeTrips: active,
      loads: loads,
      tonsDelivered: tons,
    );
  }
}

/// Compact marketplace / accepted-route card.
class DispatchRouteCard extends StatelessWidget {
  final DispatchedRoute route;
  final VoidCallback onTap;
  const DispatchRouteCard({super.key, required this.route, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final r = route.request;
    final chips = <String>[
      if (r.commodity != null) r.commodity!,
      if (r.numSlots != null) '${r.numSlots} trucks',
      if (r.distance != null) r.distance!,
      if (r.rate != null) r.rate!,
    ];
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: MlSemantic.of(context).surfaceCard,
        borderRadius: MlShape.radiusLarge,
        border: Border.all(color: MlSemantic.of(context).borderCard),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: MlShape.radiusLarge,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(r.routeLabel,
                          style: const TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 16)),
                    ),
                    _DispatchStatusChip(status: route.status),
                  ],
                ),
                if (chips.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [for (final c in chips) _MiniChip(text: c)],
                  ),
                ],
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(Icons.touch_app_outlined,
                        size: 15, color: scheme.onSurfaceVariant),
                    const SizedBox(width: 6),
                    Text(
                      route.isOpen ? 'Tap to review & accept' : 'Tap for route detail',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniChip extends StatelessWidget {
  final String text;
  const _MiniChip({required this.text});
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: PortalColors.accent.withValues(alpha: 0.10),
        borderRadius: MlShape.radiusLargeIncreased,
      ),
      child: Text(text,
          style: Theme.of(context)
              .textTheme
              .labelSmall
              ?.copyWith(color: scheme.onSurface, fontWeight: FontWeight.w600)),
    );
  }
}

class _DispatchStatusChip extends StatelessWidget {
  final DispatchStatus status;
  const _DispatchStatusChip({required this.status});
  @override
  Widget build(BuildContext context) {
    late final Color c;
    late final String label;
    switch (status) {
      case DispatchStatus.accepted:
        c = MlTokens.green800;
        label = 'Accepted';
        break;
      case DispatchStatus.declined:
        c = MlTokens.red700;
        label = 'Declined';
        break;
      case DispatchStatus.dispatched:
        c = PortalColors.accent;
        label = 'Available';
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.14),
        borderRadius: MlShape.radiusLargeIncreased,
      ),
      child: Text(label,
          style: TextStyle(color: c, fontWeight: FontWeight.w700, fontSize: 12)),
    );
  }
}

/// Bottom-sheet detail for a dispatched route (§5.2). Shows every field; for an
/// open route, exposes Accept (assign trucks) / Decline; for an accepted route,
/// shows per-route metrics and its active trips (tap a trip → highlight on map).
Future<void> showDispatchedRouteDetailSheet({
  required BuildContext context,
  required WidgetRef ref,
  required DispatchedRoute route,
  required String companyId,
  List<TripRecord> trips = const [],
  void Function(TripRecord trip)? onTrackTrip,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) {
      return _RouteDetailSheet(
        route: route,
        companyId: companyId,
        trips: trips,
        onTrackTrip: onTrackTrip,
      );
    },
  );
}

class _RouteDetailSheet extends ConsumerWidget {
  final DispatchedRoute route;
  final String companyId;
  final List<TripRecord> trips;
  final void Function(TripRecord trip)? onTrackTrip;

  const _RouteDetailSheet({
    required this.route,
    required this.companyId,
    required this.trips,
    this.onTrackTrip,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final r = route.request;
    final metrics = RouteMetrics.fromTrips(trips);
    final hours = r.operatingHours24h
        ? '24 hours'
        : (r.operatingStart != null && r.operatingEnd != null
            ? '${r.operatingStart} – ${r.operatingEnd}'
            : null);
    final start = r.isOngoing
        ? (r.startingDate != null
            ? 'Ongoing from ${MaterialLocalizations.of(context).formatFullDate(r.startingDate!)}'
            : 'Ongoing')
        : (r.startingDate != null
            ? MaterialLocalizations.of(context).formatFullDate(r.startingDate!)
            : null);

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.88,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(r.routeLabel,
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.w800)),
                  ),
                  _DispatchStatusChip(status: route.status),
                  IconButton(
                    tooltip: 'Close',
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _detailGrid(context, {
                'Route ID': route.routeNumber,
                'Commodity': r.commodity,
                'Distance': r.distance,
                'Tons available': r.tonsAvailable,
                'Number of Trucks Required': r.numSlots,
                'Your price / ton': route.transporterPricePerTon != null
                    ? 'R ${route.transporterPricePerTon!.toStringAsFixed(2)}'
                    : null,
                'Rate': r.rate,
                'Payment terms': r.paymentTerms,
                'Diesel': r.diesel,
                'Contract duration': r.contractDuration,
                'Operating hours': hours,
                // The transporter fits the seals and their driver is blocked at
                // the weighbridge without them, so the condition belongs on the
                // sheet they accept from. The platform admin's due-diligence
                // preview named it and this did not: the only reason a
                // transporter knew was if the mine happened to type "SEALED
                // LOAD" into the free-text notes.
                'Seals': r.sealRequired
                    ? 'Required — every load needs a number and a photo per seal'
                    : 'Not required',
                'Starting date': start,
                'End date': (!r.isOngoing && r.endingDate != null)
                    ? MaterialLocalizations.of(context)
                        .formatFullDate(r.endingDate!)
                    : null,
                'Loading point': r.loadingPoint,
                'Offloading point': r.offloadingPoint,
              }),
              if (r.routeNotes != null && r.routeNotes!.trim().isNotEmpty) ...[
                const SizedBox(height: 14),
                Text('Notes',
                    style: Theme.of(context)
                        .textTheme
                        .labelMedium
                        ?.copyWith(color: scheme.onSurfaceVariant)),
                const SizedBox(height: 4),
                Text(r.routeNotes!),
              ],
              if (route.isAccepted) ...[
                const SizedBox(height: 20),
                _MetricsStrip(metrics: metrics),
                const SizedBox(height: 16),
                Text('Trips',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                if (trips.isEmpty)
                  Text('No trips on this route yet.',
                      style: TextStyle(color: scheme.onSurfaceVariant))
                else
                  for (final t in trips) _TripRow(trip: t, onTrack: onTrackTrip),
              ],
              if (route.isOpen) ...[
                const SizedBox(height: 22),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _decline(context, ref),
                        icon: const Icon(Icons.close_rounded, size: 18),
                        label: const Text('Decline'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: MlTokens.accent,
                          foregroundColor: MlTokens.navy950,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: () => _accept(context, ref),
                        icon: const Icon(Icons.check_circle_outline, size: 18),
                        label: const Text('Accept & assign trucks'),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailGrid(BuildContext context, Map<String, String?> fields) {
    final entries =
        fields.entries.where((e) => e.value != null && e.value!.trim().isNotEmpty);
    return LayoutBuilder(builder: (context, c) {
      final twoCol = c.maxWidth > 460;
      final width = twoCol ? (c.maxWidth - 16) / 2 : c.maxWidth;
      return Wrap(
        spacing: 16,
        runSpacing: 12,
        children: [
          for (final e in entries)
            SizedBox(width: width, child: _DetailField(label: e.key, value: e.value!)),
        ],
      );
    });
  }

  Future<void> _accept(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final assigned = await showDialog<List<String>>(
      context: context,
      builder: (_) => _AssignTrucksDialog(route: route, companyId: companyId),
    );
    if (assigned == null || assigned.isEmpty) return;
    try {
      await ref
          .read(requestServiceProvider)
          .acceptDispatch(route.dispatchId, assigned);
      ref.invalidateIfMounted(transporterDispatchesProvider(companyId));
      ref.invalidateIfMounted(logisticsSnapshotProvider(companyId));
      ref.invalidateIfMounted(fleetStatusProvider(companyId));
      if (navigator.canPop()) navigator.pop();
      messenger.showSnackBar(SnackBar(
          content: Text(
              'Route accepted — ${assigned.length} trip(s) created and scheduled.')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Could not accept route. ${friendlyError(e)}')));
    }
  }

  Future<void> _decline(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Decline route?'),
        content: const Text('This route will be removed from your marketplace.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Decline')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(requestServiceProvider).declineDispatch(route.dispatchId);
      ref.invalidateIfMounted(transporterDispatchesProvider(companyId));
      if (navigator.canPop()) navigator.pop();
      messenger.showSnackBar(const SnackBar(content: Text('Route declined.')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Could not decline. ${friendlyError(e)}')));
    }
  }
}

class _DetailField extends StatelessWidget {
  final String label;
  final String value;
  const _DetailField({required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: scheme.onSurfaceVariant)),
        const SizedBox(height: 2),
        Text(value,
            style: Theme.of(context)
                .textTheme
                .bodyLarge
                ?.copyWith(fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _MetricsStrip extends StatelessWidget {
  final RouteMetrics metrics;
  const _MetricsStrip({required this.metrics});
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _metric(context, 'Tons delivered', formatTons(metrics.tonsDelivered)),
        _metric(context, 'Loads', '${metrics.loads}'),
        _metric(context, 'Active trips', '${metrics.activeTrips}'),
      ],
    );
  }

  Widget _metric(BuildContext context, String label, String value) {
    final scheme = Theme.of(context).colorScheme;
    return Expanded(
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        decoration: BoxDecoration(
          color: MlSemantic.of(context).surfaceCard,
          borderRadius: MlShape.radiusLarge,
          border: Border.all(color: MlSemantic.of(context).borderCard),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800, color: PortalColors.accent)),
            const SizedBox(height: 2),
            Text(label,
                style: Theme.of(context)
                    .textTheme
                    .labelSmall
                    ?.copyWith(color: scheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}

class _TripRow extends StatelessWidget {
  final TripRecord trip;
  final void Function(TripRecord trip)? onTrack;
  const _TripRow({required this.trip, this.onTrack});
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final status = TripStatus.parse(trip.status);
    final canTrack = onTrack != null && trip.vehicleId != null;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.local_shipping_outlined),
      title: Text(trip.truckReg ?? 'Truck ${trip.transactionId.substring(0, 6)}…'),
      subtitle: Text(
        [
          status.label,
          if (trip.netTons != null) formatTons(trip.netTons!),
        ].join(' · '),
        style: TextStyle(color: scheme.onSurfaceVariant),
      ),
      trailing: canTrack
          ? TextButton.icon(
              onPressed: () => onTrack!(trip),
              icon: const Icon(Icons.location_on_outlined, size: 16),
              label: const Text('Track'),
            )
          : null,
    );
  }
}

/// Truck picker for accepting a route (§4). Lists ONLY available trucks — an
/// active truck not already on a route — and caps the selection at the route's
/// "Number of Trucks Required". Each ticked truck becomes one scheduled trip and
/// moves to On Route.
class _AssignTrucksDialog extends ConsumerStatefulWidget {
  final DispatchedRoute route;
  final String companyId;
  const _AssignTrucksDialog({required this.route, required this.companyId});

  @override
  ConsumerState<_AssignTrucksDialog> createState() => _AssignTrucksDialogState();
}

class _AssignTrucksDialogState extends ConsumerState<_AssignTrucksDialog> {
  final _selected = <String>{};

  /// Number of Trucks Required (from the request), or null if unspecified.
  int? get _required {
    final n = int.tryParse(widget.route.request.numSlots?.trim() ?? '');
    return (n != null && n > 0) ? n : null;
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(fleetStatusProvider(widget.companyId));
    final required = _required;

    return AlertDialog(
      title: const Text('Assign available trucks'),
      content: SizedBox(
        width: 440,
        child: async.when(
          loading: () => const SizedBox(
              height: 120, child: Center(child: CircularProgressIndicator())),
          error: (e, _) => Text('Could not load your fleet. ${friendlyError(e)}'),
          data: (statuses) {
            final available = statuses.where((s) => s.available).toList();
            // Drop any selections that are no longer available.
            _selected.removeWhere(
                (id) => !available.any((s) => s.vehicleId == id));

            if (available.isEmpty) {
              return const Text(
                'No available trucks. Every truck is either already on a route '
                'or inactive. A truck frees up automatically when its trip is '
                'completed — or add vehicles in Fleet management.');
            }
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  required != null
                      ? 'This route needs $required truck(s). '
                          '${_selected.length}/$required selected.'
                      : 'Tick the available trucks to commit '
                          '(${_selected.length} selected).',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      for (final s in available) _truckTile(s, required),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _selected.isEmpty
              ? null
              : () => Navigator.of(context).pop(_selected.toList()),
          child: Text('Accept ${_selected.length} truck(s)'),
        ),
      ],
    );
  }

  Widget _truckTile(FleetVehicleStatus s, int? required) {
    final selected = _selected.contains(s.vehicleId);
    // At the required cap, unselected trucks are disabled so the count can't
    // be exceeded.
    final atCap = required != null && !selected && _selected.length >= required;
    return CheckboxListTile(
      contentPadding: EdgeInsets.zero,
      controlAffinity: ListTileControlAffinity.leading,
      value: selected,
      onChanged: atCap
          ? null
          : (on) => setState(() {
                if (on ?? false) {
                  _selected.add(s.vehicleId);
                } else {
                  _selected.remove(s.vehicleId);
                }
              }),
      title: Text(s.registration),
      subtitle: Text(
        '${s.driversLabel} · ${s.driverCount}/${s.maxDrivers} drivers',
      ),
    );
  }
}
