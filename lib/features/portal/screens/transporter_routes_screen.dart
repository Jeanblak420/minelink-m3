import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_application_1/features/portal/models/logistics_models.dart';
import 'package:flutter_application_1/features/portal/models/transportation_request.dart';
import 'package:flutter_application_1/features/portal/models/trip_status.dart';
import 'package:flutter_application_1/features/portal/providers/logistics_provider.dart';
import 'package:flutter_application_1/features/portal/providers/request_provider.dart';
import 'package:flutter_application_1/features/portal/providers/truck_highlight_provider.dart';
import 'package:flutter_application_1/features/portal/utils/portal_company_resolution.dart';
import 'package:flutter_application_1/features/portal/utils/portal_dashboard_navigation.dart';
import 'package:flutter_application_1/features/portal/widgets/dispatch_route_widgets.dart';
import 'package:flutter_application_1/features/portal/widgets/order_fill_line.dart';
import 'package:flutter_application_1/core/design/components/ml_components.dart';
import 'package:flutter_application_1/features/portal/widgets/portal_company_required.dart';

/// Transporter "Routes & dispatches" (§5.2/5.4): routes **waiting on this
/// company's acceptance**, the routes it has accepted with their per-route
/// metrics and trips, and a live active-trips list. Tapping a trip highlights
/// that truck on the Truck locations map.
///
/// The waiting section is not decoration. Until 2026-08-17 a dispatched route
/// appeared on NO screen in the transporter portal: this one filtered to
/// accepted only, the dashboard's "Dispatches to accept — 2 waiting" tile
/// linked here, and the empty state sent the reader to an "Overview
/// marketplace" that does not exist. The only way in was the deep link on the
/// notification (`/portal/transporter/accept-route/:routeId`), so a transporter
/// who dismissed or missed that notification could not accept the work at all —
/// while the rail badge went on counting it. Driven and confirmed against the
/// live app, signed in as `roadhaul.admin`, with two dispatches pending.
class TransporterRoutesScreen extends ConsumerWidget {
  const TransporterRoutesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final companyId = resolvePortalCompanyId(ref);
    if (companyId == null) {
      return const PortalCompanyRequired();
    }

    final async = ref.watch(logisticsSnapshotProvider(companyId));
    final dispatches =
        ref.watch(transporterDispatchesProvider(companyId)).asData?.value ??
            const <DispatchedRoute>[];
    final accepted = dispatches.where((d) => d.isAccepted).toList();
    final waiting = dispatches
        .where((d) => d.status == DispatchStatus.dispatched)
        .toList()
      ..sort((a, b) => b.dispatchedAt.compareTo(a.dispatchedAt));

    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => MlLoadFailure(
          subject: 'your routes',
          error: e,
          onRetry: () => ref.invalidate(logisticsSnapshotProvider(companyId)),
      ),
      data: (snap) {
        List<TripRecord> tripsFor(String dispatchId) =>
            snap.trips.where((t) => t.dispatchId == dispatchId).toList();
        final activeTrips = snap.trips
            .where((t) => TripStatus.parse(t.status).isActive)
            .toList();
        final routeByDispatch = {for (final d in accepted) d.dispatchId: d};

        void track(TripRecord trip) {
          if (trip.vehicleId == null) return;
          ref.read(highlightedVehicleProvider.notifier).state = trip.vehicleId;
          openPortalTabByLabel(ref, context, 'Truck locations');
        }

        return MlPageBody(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              MlPageHeader(
                title: 'Routes',
                // "accepted" is an adjective here, so it cannot go through
                // mlCount — that pluralises by appending an "s" and rendered
                // "3 accepteds" in the live app.
                meta: waiting.isEmpty
                    ? mlCount(accepted.length, 'accepted route')
                    : '${waiting.length} waiting · ${accepted.length} accepted',
                description: 'Routes dispatched to you, the ones you have '
                    'accepted, and their live trips.',
              ),
              const SizedBox(height: 16),
              // Waiting on you — first, because it is the only thing on this
              // page with a deadline attached to it.
              if (waiting.isNotEmpty) ...[
                MlSectionTitle('Waiting on your acceptance',
                    icon: Icons.assignment_turned_in_outlined,
                    meta: mlCount(waiting.length, 'route')),
                for (final route in waiting) ...[
                  DispatchRouteCard(
                    route: route,
                    onTap: () => showDispatchedRouteDetailSheet(
                      context: context,
                      ref: ref,
                      route: route,
                      companyId: companyId,
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                const SizedBox(height: 24),
              ],
              MlSectionTitle('Accepted routes',
                  icon: Icons.alt_route_rounded,
                  meta: mlCount(accepted.length, 'route')),
              if (accepted.isEmpty)
                MlCard(
                  child: MlEmptyState(
                    icon: Icons.alt_route_rounded,
                    title: 'No accepted routes yet.',
                    message: waiting.isEmpty
                        ? 'When the MineLink admin dispatches a route to you it '
                            'appears here first, waiting on your acceptance.'
                        : 'Open a route above and accept it to create its trips.',
                  ),
                )
              else
                for (final route in accepted) ...[
                  DispatchRouteCard(
                    route: route,
                    onTap: () => showDispatchedRouteDetailSheet(
                      context: context,
                      ref: ref,
                      route: route,
                      companyId: companyId,
                      trips: tripsFor(route.dispatchId),
                      onTrackTrip: (trip) {
                        Navigator.of(context).pop();
                        track(trip);
                      },
                    ),
                  ),
                  // Live stockpile fill at the mine — so the transporter only
                  // sends trucks once there is a full load ready to collect.
                  OrderFillLine(requestId: route.request.id),
                  const SizedBox(height: 8),
                ],
              const SizedBox(height: 24),
              MlSectionTitle('Active trips',
                  icon: Icons.local_shipping_outlined,
                  meta: mlCount(activeTrips.length, 'trip')),
              if (activeTrips.isEmpty)
                MlCard(
                  child: MlEmptyState(
                    icon: Icons.local_shipping_outlined,
                    title: 'No active trips right now.',
                    message:
                        'Trips appear here while your trucks are on the move.',
                  ),
                )
              else
                MlCard(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    children: [
                      for (var i = 0; i < activeTrips.length; i++) ...[
                        if (i > 0)
                          Divider(
                              height: 1,
                              color: MlSemantic.of(context).divider),
                        Builder(builder: (context) {
                          final t = activeTrips[i];
                          final route = t.dispatchId == null
                              ? null
                              : routeByDispatch[t.dispatchId];
                          return _ActiveTripTile(
                            trip: t,
                            routeLabel: route?.request.routeLabel,
                            onTrack:
                                t.vehicleId == null ? null : () => track(t),
                          );
                        }),
                      ],
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _ActiveTripTile extends StatelessWidget {
  final TripRecord trip;
  final String? routeLabel;
  final VoidCallback? onTrack;
  const _ActiveTripTile({required this.trip, this.routeLabel, this.onTrack});

  @override
  Widget build(BuildContext context) {
    final status = TripStatus.parse(trip.status);
    return ListTile(
      leading: const MlIconWell(
          icon: Icons.local_shipping_outlined, size: 38, radius: 11),
      title: Text(trip.truckReg ?? 'Trip ${trip.id.substring(0, 6)}…',
          style: const TextStyle(
            fontFamily: MlTokens.fontMono,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
            fontFeatures: [FontFeature.tabularFigures()],
          )),
      subtitle: Text(
        [
          if (routeLabel != null) routeLabel!,
          status.label,
        ].join(' · '),
        style: TextStyle(color: MlSemantic.of(context).textMuted),
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
