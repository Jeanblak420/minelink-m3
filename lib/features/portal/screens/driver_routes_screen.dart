import 'package:flutter_application_1/core/design/tokens/m3/ml_shape.dart';
import 'package:cross_file/cross_file.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_application_1/core/design/tokens/m3/ml_typography.dart';
import 'package:flutter_application_1/core/utils/safe_ref.dart';
import 'package:flutter_application_1/features/employee/providers/employee_provider.dart';
import 'package:flutter_application_1/features/fleet/models/fleet_vehicle_model.dart';
import 'package:flutter_application_1/features/fleet/models/vehicle_driver.dart';
import 'package:flutter_application_1/features/fleet/providers/fleet_provider.dart';
import 'package:flutter_application_1/features/portal/models/logistics_models.dart';
import 'package:flutter_application_1/features/portal/models/transportation_request.dart';
import 'package:flutter_application_1/features/portal/models/trip_status.dart';
import 'package:flutter_application_1/features/portal/providers/lifecycle_provider.dart';
import 'package:flutter_application_1/features/portal/providers/logistics_provider.dart';
import 'package:flutter_application_1/features/portal/services/trip_waybill_builder.dart';
import 'package:flutter_application_1/features/portal/services/waybill_pdf.dart';
import 'package:flutter_application_1/features/portal/providers/request_provider.dart';
import 'package:flutter_application_1/features/portal/utils/portal_company_resolution.dart';
import 'package:flutter_application_1/features/portal/services/reconciliation_service.dart';
import 'package:flutter_application_1/features/portal/widgets/driver_live_tracking_card.dart';
import 'package:flutter_application_1/features/portal/widgets/driver_resolution_error.dart';
import 'package:flutter_application_1/features/portal/widgets/pod_photo_link.dart';
import 'package:flutter_application_1/core/design/components/ml_components.dart';
import 'package:flutter_application_1/features/portal/widgets/photo_capture_field.dart';
import 'package:flutter_application_1/features/portal/widgets/portal_company_required.dart';
import 'package:flutter_application_1/core/utils/friendly_error.dart';
import 'package:flutter_application_1/features/profile/widgets/signature_required_prompt.dart';
import 'package:flutter_application_1/core/time/ml_time.dart';
import 'package:flutter_application_1/features/portal/widgets/premium_overview_widgets.dart'
    show formatTons;

/// Driver app (§6): the routes/trips for the driver's assigned truck, a load
/// counter, and an "Upload POD + tons" action that finalises a delivery through
/// the lifecycle cascade (LifecycleService.recordPod).
class DriverRoutesScreen extends ConsumerWidget {
  const DriverRoutesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final companyId = resolvePortalCompanyId(ref);
    if (companyId == null) {
      return const PortalCompanyRequired();
    }
    final employee = ref.watch(employeeProvider).employee;
    final fleet = ref.watch(fleetProvider(companyId));
    final assignmentsAsync = ref.watch(vehicleDriversProvider(companyId));
    final dispatchesAsync = ref.watch(transporterDispatchesProvider(companyId));
    final async = ref.watch(logisticsSnapshotProvider(companyId));

    // Surface a failed assignment/dispatch resolution as an error with retry —
    // never a silent "no truck assigned" that hides an RLS/network failure.
    if (assignmentsAsync.hasError || dispatchesAsync.hasError) {
      return DriverResolutionError(
        onRetry: () {
          ref.invalidate(vehicleDriversProvider(companyId));
          ref.invalidate(transporterDispatchesProvider(companyId));
          ref.invalidate(logisticsSnapshotProvider(companyId));
        },
      );
    }
    if (assignmentsAsync.isLoading || dispatchesAsync.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    final assignments = assignmentsAsync.requireValue;
    final myVehicle = employee == null
        ? null
        : _assignedVehicle(fleet.activeVehicles, assignments, employee.id);
    final dispatches = dispatchesAsync.requireValue;
    final routeByDispatch = {for (final d in dispatches) d.dispatchId: d};

    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => DriverResolutionError(
        onRetry: () => ref.invalidate(logisticsSnapshotProvider(companyId)),
      ),
      data: (snap) {
        final myTrips = myVehicle == null
            ? <TripRecord>[]
            : snap.trips.where((t) => t.vehicleId == myVehicle.id).toList()
          ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        final delivered = myTrips
            .where((t) => TripStatus.parse(t.status) == TripStatus.completed)
            .toList();
        final active =
            myTrips.where((t) => TripStatus.parse(t.status).isActive).toList();
        final tonsCarried = myTrips.fold<double>(
            0, (sum, t) => sum + (t.netTons ?? 0));
        // The hero "Current Trip" card follows the driver-mobile mockup: it
        // shows the most-recently-updated active trip; any further active trips
        // still list below so nothing is lost.
        final current = active.isEmpty ? null : active.first;
        final currentReq = current?.dispatchId == null
            ? null
            : routeByDispatch[current!.dispatchId]?.request;

        return MlPageBody(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Compact trip stats (kept from the original driver screen) —
              // laid out to fit a phone without truncating.
              _DriverStatsStrip(
                loads: myTrips.where((t) => t.netTons != null).length,
                delivered: delivered.length,
                tons: formatTons(tonsCarried),
              ),
              if (myVehicle != null) ...[
                const SizedBox(height: 14),
                DriverLiveTrackingCard(hasActiveTrip: active.isNotEmpty),
              ],
              const SizedBox(height: 18),
              // Hero: Current Trip (mockup) — plate, commodity, route timeline,
              // and the driver's lifecycle actions.
              _CurrentTripCard(
                trip: current,
                request: currentReq,
                vehicle: myVehicle,
                onNavigate: current == null
                    ? null
                    : () =>
                        context.push('/portal/driver/navigate/${current.id}'),
                onDirections: currentReq == null
                    ? null
                    : () => _directions(context, current!, currentReq),
                onStartRoute: () =>
                    _startRoute(context, ref, current!, companyId),
                onArrivedLoading: () => _setStatus(context, ref, current!,
                    companyId, TripStatus.arrivedAtMine, 'Marked arrived at loading.'),
                onArrivedOffloading: () =>
                    _arrivedAtOffload(context, ref, current!, companyId),
                onUploadPod: () => _uploadPod(context, ref, current!, companyId),
              ),
              // Any additional active trips (rare — >1 truck load in flight).
              if (active.length > 1) ...[
                const SizedBox(height: 22),
                MlSectionTitle('Other active trips',
                    icon: Icons.local_shipping_outlined,
                    meta: mlCount(active.length - 1, 'trip')),
                for (final t in active.skip(1))
                  _TripCard(
                    trip: t,
                    routeLabel: t.dispatchId == null
                        ? null
                        : routeByDispatch[t.dispatchId]?.request.routeLabel,
                    onStartRoute: () => _startRoute(context, ref, t, companyId),
                    onUploadPod: () => _uploadPod(context, ref, t, companyId),
                  ),
              ],
              // Recent trips (kept) — mockup-style rows.
              if (delivered.isNotEmpty) ...[
                const SizedBox(height: 22),
                _RecentTripsCard(
                  trips: delivered.take(10).toList(),
                  companyId: companyId,
                  requestFor: (t) => t.dispatchId == null
                      ? null
                      : routeByDispatch[t.dispatchId]?.request,
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  FleetVehicle? _assignedVehicle(
    List<FleetVehicle> vehicles,
    List<VehicleDriver> assignments,
    String employeeId,
  ) {
    // driver_assignments is authoritative under multi-driver: the embedded
    // fleet_vehicles mirror only carries the PRIMARY (oldest) driver, so a
    // truck's 2nd+ driver would otherwise see "no truck assigned".
    for (final a in assignments) {
      if (a.driverEmployeeId == employeeId) {
        for (final v in vehicles) {
          if (v.id == a.vehicleId) return v;
        }
      }
    }
    for (final v in vehicles) {
      if (v.assignedDriverEmployeeId == employeeId) return v;
    }
    return null;
  }

  /// §4 Driver row: "opens app, views assigned route, starts navigation" —
  /// moves the scheduled trip to En Route to Load.
  Future<void> _startRoute(
    BuildContext context,
    WidgetRef ref,
    TripRecord trip,
    String companyId,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(lifecycleServiceProvider)
          .setTripStatus(trip.id, TripStatus.enRouteToLoad);
      ref.invalidateIfMounted(logisticsSnapshotProvider(companyId));
      messenger.showSnackBar(const SnackBar(
          content: Text('Trip started — you are en route to load. Turn on '
              'Live location sharing so the parties can follow your truck.')));
    } catch (e) {
      messenger
          .showSnackBar(SnackBar(content: Text('Could not start the trip. ${friendlyError(e)}')));
    }
  }

  /// Advances the trip lifecycle for the driver's "Arrived at loading /
  /// offloading" actions (arrived_at_mine / offloaded), keeping every party's
  /// live view in sync via the same cascade the mine and buyer read.
  Future<void> _setStatus(
    BuildContext context,
    WidgetRef ref,
    TripRecord trip,
    String companyId,
    TripStatus status,
    String doneMessage,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(lifecycleServiceProvider).setTripStatus(trip.id, status);
      ref.invalidateIfMounted(logisticsSnapshotProvider(companyId));
      messenger.showSnackBar(SnackBar(content: Text(doneMessage)));
    } catch (e) {
      messenger
          .showSnackBar(SnackBar(content: Text('Could not update the trip. ${friendlyError(e)}')));
    }
  }

  /// "Arrived at offloading": tells the buyer the truck is there, and stamps
  /// the time — without claiming the load is off it.
  ///
  /// This used to call `setTripStatus(offloaded)`. `offloaded` means the
  /// cargo is on the ground and it is the status the POD collapse writes
  /// alongside `completed`; setting it on arrival closed the delivery in the
  /// buyer's and the mine's view with no delivered tonnage and no photo behind
  /// it. `set_trip_status` now refuses that outright, so the two halves agree.
  Future<void> _arrivedAtOffload(
    BuildContext context,
    WidgetRef ref,
    TripRecord trip,
    String companyId,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(lifecycleServiceProvider).markArrivedAtOffload(trip.id);
      ref.invalidateIfMounted(logisticsSnapshotProvider(companyId));
      messenger.showSnackBar(const SnackBar(
          content: Text('Arrival logged — the buyer has been told you are '
              'there. Upload the POD once you are unloaded and weighed.')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(
          content: Text('Could not log your arrival. ${friendlyError(e)}')));
    }
  }

  /// Opens turn-by-turn directions to the driver's current target — the
  /// loading point until the truck is loaded, then the offloading point.
  Future<void> _directions(
    BuildContext context,
    TripRecord trip,
    TransportationRequest request,
  ) async {
    final status = TripStatus.parse(trip.status);
    final target = status.step >= TripStatus.loaded.step
        ? request.offloadingPoint
        : request.loadingPoint;
    final messenger = ScaffoldMessenger.of(context);
    if (target == null || target.trim().isEmpty) {
      messenger.showSnackBar(
          const SnackBar(content: Text('No destination on this trip yet.')));
      return;
    }
    final uri = Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=${Uri.encodeComponent(target)}');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      messenger.showSnackBar(
          const SnackBar(content: Text('Could not open maps.')));
    }
  }

  Future<void> _uploadPod(
    BuildContext context,
    WidgetRef ref,
    TripRecord trip,
    String companyId,
  ) async {
    // S8-10. `get_trip_waybill` regenerates the slip with the driver's
    // signature in its RECEIVED BY block at this moment. Asked BEFORE the POD
    // dialog, not after: a driver who wants to add a signature should not have
    // to re-enter the tonnage and re-take the photo to do it.
    final signature = await ensureSignatureBeforeSigning(
      context, ref,
      action: 'record this delivery',
      waybillBlock: 'RECEIVED BY',
    );
    if (signature != SignaturePromptOutcome.proceedUnsigned &&
        signature != SignaturePromptOutcome.alreadySigned) {
      return;
    }
    if (!context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final result = await showDialog<({double tons, XFile photo})>(
      context: context,
      builder: (_) => _PodDialog(trip: trip),
    );
    if (result == null) return;
    final lifecycle = ref.read(lifecycleServiceProvider);
    String? photoPath;
    try {
      // P10-D7 (client ruling, 2026-08-12): the photo is EVIDENCE, and proof of
      // delivery must require proof. It used to be optional here — which is the
      // whole reason the pod_photos bucket had never held a single file — so the
      // record type carries a non-nullable XFile and the optionality cannot come
      // back by omission. `record_pod` refuses a POD whose photo is missing from
      // the bucket, so this upload must land before the RPC is called.
      photoPath = await lifecycle.uploadPodPhoto(
        companyId: companyId,
        name: result.photo.name,
        bytes: await result.photo.readAsBytes(),
      );
      await lifecycle.recordPod(
        tripId: trip.id,
        deliveredTons: result.tons,
        photoUrl: photoPath,
      );
      ref.invalidate(logisticsSnapshotProvider(companyId));
      messenger.showSnackBar(SnackBar(
          content: Text('Proof of delivery recorded — '
              '${formatTons(result.tons)} delivered with photo. '
              'Trip completed.')));
      // Regenerate the waybill with the driver's signature auto-placed in the
      // RECEIVED block (§4) and open the signed copy.
      await _previewSignedWaybill(ref, trip.id);
    } catch (e) {
      // The POD didn't record — remove the just-uploaded photo.
      if (photoPath != null) {
        await lifecycle.deletePhotos('pod_photos', [photoPath]);
      }
      messenger.showSnackBar(SnackBar(content: Text('Could not record POD. ${friendlyError(e)}')));
    }
  }

  /// Rebuilds the waybill from `get_trip_waybill` (both dispatch and received
  /// blocks) and opens the print-ready signed copy. Best-effort — a failure
  /// here never undoes the recorded POD.
  Future<void> _previewSignedWaybill(WidgetRef ref, String tripId) async {
    try {
      final waybill = await buildTripWaybill(ref, tripId);
      if (waybill != null) await WaybillPreviewer.preview(waybill);
    } catch (_) {
      // Signed-copy preview is a convenience; ignore failures.
    }
  }
}

/// Compact driver trip stats — three evenly-spaced value/label cells in one
/// card, so nothing truncates on a phone (the old 3-across icon cards did).
class _DriverStatsStrip extends StatelessWidget {
  final int loads;
  final int delivered;
  final String tons;
  const _DriverStatsStrip(
      {required this.loads, required this.delivered, required this.tons});

  @override
  Widget build(BuildContext context) {
    final semantic = MlSemantic.of(context);
    Widget cell(String value, String label) => Expanded(
          child: Column(
            children: [
              Text(value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.mlText.titleLarge.copyWith(
                    color: semantic.textStrong,
                    fontWeight: FontWeight.w800,
                  )),
              const SizedBox(height: 2),
              Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.mlText.bodyMedium.copyWith(
                    color: semantic.textMuted,
                  )),
            ],
          ),
        );
    Widget divider() =>
        Container(width: 1, height: 34, color: semantic.divider);
    return MlCard(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      child: Row(
        children: [
          cell('$loads', 'Loads'),
          divider(),
          cell('$delivered', 'Delivered'),
          divider(),
          cell(tons, 'Tons'),
        ],
      ),
    );
  }
}

/// Hero "Current Trip" card (driver-mobile mockup): plate + commodity, a
/// From→To route timeline, and the driver's lifecycle actions (Directions,
/// Arrived at loading, Arrived at offloading, Upload POD). All actions map to
/// the same trip-lifecycle cascade the rest of the app reads.
class _CurrentTripCard extends StatelessWidget {
  final TripRecord? trip;
  final TransportationRequest? request;
  final FleetVehicle? vehicle;
  final VoidCallback? onNavigate;
  final VoidCallback? onDirections;
  final VoidCallback? onStartRoute;
  final VoidCallback? onArrivedLoading;
  final VoidCallback? onArrivedOffloading;
  final VoidCallback? onUploadPod;
  const _CurrentTripCard({
    required this.trip,
    this.request,
    this.vehicle,
    this.onNavigate,
    this.onDirections,
    this.onStartRoute,
    this.onArrivedLoading,
    this.onArrivedOffloading,
    this.onUploadPod,
  });

  @override
  Widget build(BuildContext context) {
    final semantic = MlSemantic.of(context);
    final textTheme = Theme.of(context).textTheme;
    final titleStyle = context.mlText.titleLarge.copyWith(
      color: semantic.textStrong,
      fontWeight: FontWeight.w800,
    );

    if (trip == null) {
      return MlCard(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Current Trip', style: titleStyle),
            const SizedBox(height: 12),
            MlEmptyState(
              icon: Icons.local_shipping_outlined,
              title: vehicle == null
                  ? 'No truck assigned yet.'
                  : 'No active trip.',
              message: vehicle == null
                  ? 'Ask your manager to assign you a truck — your load will appear here once a route is dispatched.'
                  : 'When your admin assigns you a load, it shows here with directions and one-tap arrival + POD actions.',
            ),
          ],
        ),
      );
    }

    final t = trip!;
    final status = TripStatus.parse(t.status);
    final reg = t.truckReg ?? vehicle?.vehicleRegistrationNumber ?? '—';
    final commodity = request?.commodity;
    final from = request?.loadingPoint;
    final to = request?.offloadingPoint;
    final arrivedLoadingDone = status.step >= TripStatus.arrivedAtMine.step;
    // Arrival at the offload point is its own timestamp now, not a status:
    // the trip stays en_route_to_offload until the POD closes it. Reading the
    // status here would have shown a ✓ only once the load was already
    // delivered, which is after the button stops meaning anything.
    final arrivedOffloadingDone =
        t.arrivedAtOffloadAt != null || status.step >= TripStatus.offloaded.step;
    final canPod = status.step >= TripStatus.loaded.step;

    return MlCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('Current Trip', style: titleStyle)),
              MlStatusBadge.forStatus(status.label, dot: true),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const MlIconWell(
                  icon: Icons.local_shipping,
                  tone: MlTone.accent,
                  size: 60,
                  radius: 16),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    MlPlatePill(reg, fontSize: 16),
                    if (commodity != null) ...[
                      const SizedBox(height: 4),
                      Text(commodity,
                          style: textTheme.bodyMedium
                              ?.copyWith(color: semantic.textMuted)),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (from != null || to != null) ...[
            const SizedBox(height: 16),
            _RouteTimeline(from: from, to: to),
          ],
          const SizedBox(height: 16),
          // "Start route" FIRST while the trip is scheduled. It is the action
          // the lifecycle is waiting on — it is what puts the truck on every
          // other party's live map — and it used to sit third, below Navigate
          // and Directions, so the driver's first tap was the one that does
          // not tell anybody they have left.
          if (status == TripStatus.scheduled && onStartRoute != null) ...[
            MlButton.go(
                label: 'Start route',
                icon: Icons.play_arrow_rounded,
                expand: true,
                onPressed: onStartRoute),
            const SizedBox(height: 10),
          ],
          // In-app turn-by-turn navigation (spec 2026-07-16 §4) — primary
          // action; the external-maps "Directions" stays as a fallback.
          if (onNavigate != null) ...[
            MlButton.go(
                label: 'Navigate',
                icon: Icons.navigation_rounded,
                expand: true,
                onPressed: onNavigate),
            const SizedBox(height: 10),
          ],
          if (onDirections != null) ...[
            MlButton.primary(
                label: 'Directions',
                icon: Icons.near_me_rounded,
                expand: true,
                onPressed: onDirections),
            const SizedBox(height: 10),
          ],
          // The ICON carries the done state, not a `✓` appended to the label.
          //
          // These read "Arrived at loading ✓" until 2026-08-20, and U+2713 is
          // not in Plus Jakarta Sans. On a handset the platform's fallback
          // chain supplies it, so it looked fine wherever anyone had looked —
          // and it came out as a tofu box the first time the driver's Trip
          // screen was rendered anywhere else. A brand font cannot be assumed
          // to carry a symbol, and a filled-vs-outline check is how M3 says
          // "this step is done" anyway.
          MlButton.outline(
            label: 'Arrived at loading',
            icon: arrivedLoadingDone
                ? Icons.check_circle_rounded
                : Icons.check_circle_outline,
            expand: true,
            onPressed: (!arrivedLoadingDone &&
                    status.isActive &&
                    status.step < TripStatus.loaded.step)
                ? onArrivedLoading
                : null,
          ),
          const SizedBox(height: 10),
          MlButton.outline(
            label: 'Arrived at offloading',
            icon: arrivedOffloadingDone
                ? Icons.check_circle_rounded
                : Icons.check_circle_outline,
            expand: true,
            onPressed:
                (!arrivedOffloadingDone && status.step >= TripStatus.loaded.step)
                    ? onArrivedOffloading
                    : null,
          ),
          const SizedBox(height: 10),
          MlButton.go(
            label: 'Upload POD',
            icon: Icons.cloud_upload_outlined,
            expand: true,
            onPressed: canPod ? onUploadPod : null,
          ),
        ],
      ),
    );
  }
}

/// From→To vertical route timeline (cyan origin dot → green destination dot).
class _RouteTimeline extends StatelessWidget {
  final String? from;
  final String? to;
  const _RouteTimeline({this.from, this.to});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: MlShape.radiusLarge,
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Column(
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: _Dot(MlTokens.cyan650),
                ),
                Expanded(
                  child: Container(
                    width: 2,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    color: scheme.outlineVariant,
                  ),
                ),
                const _Dot(MlTokens.green600),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _stop(context, 'From', from ?? '—'),
                  const SizedBox(height: 14),
                  _stop(context, 'To', to ?? '—'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stop(BuildContext context, String label, String value) {
    final semantic = MlSemantic.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: semantic.textMuted)),
        Text(value,
            style: context.mlText.titleMedium.copyWith(
              color: semantic.textStrong,
              fontWeight: FontWeight.w800,
            )),
      ],
    );
  }
}

class _Dot extends StatelessWidget {
  final Color color;
  const _Dot(this.color);
  @override
  Widget build(BuildContext context) => Container(
      width: 13,
      height: 13,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle));
}

/// Recent (completed) trips list, mockup-style rows. Each delivered trip
/// carries a "View POD" affordance so the driver can re-open the proof of
/// delivery photo they captured — the same photo the mine, buyer, transporter
/// and platform admin see on their recon tables.
class _RecentTripsCard extends ConsumerWidget {
  final List<TripRecord> trips;
  final String companyId;
  final TransportationRequest? Function(TripRecord) requestFor;
  const _RecentTripsCard({
    required this.trips,
    required this.companyId,
    required this.requestFor,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final semantic = MlSemantic.of(context);
    // Party-scoped recon rows already carry each trip's POD photo path.
    final podByTrip = <String, String>{};
    final recons =
        ref.watch(tripReconciliationsProvider(companyId)).asData?.value;
    for (final r in recons ?? const []) {
      final p = r.podPhotoPath;
      if (p != null) podByTrip[r.tripId] = p;
    }
    return MlCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Recent Trips',
              style: context.mlText.titleMedium.copyWith(
                color: semantic.textStrong,
                fontWeight: FontWeight.w800,
              )),
          const SizedBox(height: 8),
          for (var i = 0; i < trips.length; i++)
            _row(context, trips[i],
                divided: i > 0, podPhotoPath: podByTrip[trips[i].id]),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, TripRecord t,
      {required bool divided, String? podPhotoPath}) {
    final semantic = MlSemantic.of(context);
    final req = requestFor(t);
    // `MlTime.day` and `MlTime.clock`, not a private month table and a
    // hand-padded clock. This was the fourth copy of the same date formatter
    // in `lib/`, and the only one of the four that kept the year — so the
    // driver's history and the three dashboards spelled the same moment two
    // different ways.
    final date = MlTime.day(t.updatedAt);
    final time = MlTime.clock(t.updatedAt);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: divided
          ? BoxDecoration(
              border: Border(top: BorderSide(color: semantic.divider)))
          : null,
      child: Row(
        children: [
          const MlIconWell(
              icon: Icons.check_circle,
              tone: MlTone.done,
              size: 44,
              radius: 12),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                MlPlatePill(t.truckReg ?? '—', fontSize: 12),
                const SizedBox(height: 3),
                if (req != null)
                  // TWO lines. A route label is an IDENTITY — where the load
                  // came from and where it went — and one line at 412dp cuts
                  // it mid-word: on the emulator against live data it read
                  // "Iron Hills Mining - pri…", which names neither end of the
                  // trip it is labelling.
                  //
                  // The render set never showed it because the fixture's route
                  // labels are short; the live ones are "Iron Hills Mining —
                  // primary collection point → Richards Bay Dry Bulk Terminal,
                  // Berth 704".
                  Text(req.routeLabel,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: semantic.textMuted)),
                Text('$date · $time',
                    style: context.mlText.code(
                        color: semantic.textMuted,
                        size: 12,
                        weight: FontWeight.w400)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (podPhotoPath != null) PodPhotoIcon(path: podPhotoPath),
          MlStatusBadge.forStatus('Completed'),
        ],
      ),
    );
  }
}

/// Live-location sharing control (§4 Live GPS tracking): the driver turns it
/// on and the reporter pings every 30 seconds — in the background too — until
/// the trip completes, at which point it stops itself.
class _TripCard extends StatelessWidget {
  final TripRecord trip;
  final String? routeLabel;
  final VoidCallback? onStartRoute;
  final VoidCallback? onUploadPod;
  const _TripCard(
      {required this.trip, this.routeLabel, this.onStartRoute, this.onUploadPod});

  @override
  Widget build(BuildContext context) {
    final semantic = MlSemantic.of(context);
    final status = TripStatus.parse(trip.status);
    // A scheduled trip starts with the driver heading to the loading point.
    final canStart = onStartRoute != null && status == TripStatus.scheduled;
    // POD is meaningful once the truck is at least loaded.
    final canPod = onUploadPod != null && status.step >= TripStatus.loaded.step;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: MlCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(routeLabel ?? 'Trip ${trip.id.substring(0, 6)}…',
                      style: const TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 16)),
                ),
                MlStatusBadge.forStatus(status.label),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              [
                if (trip.truckReg != null) trip.truckReg!,
                if (trip.netTons != null) 'Loaded ${formatTons(trip.netTons!)}',
              ].join(' · '),
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: semantic.textMuted),
            ),
            if (canStart) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: MlButton.go(
                  label: 'Start route',
                  icon: Icons.navigation_outlined,
                  compact: true,
                  onPressed: onStartRoute,
                ),
              ),
            ],
            if (canPod) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: MlButton.go(
                  label: 'Upload POD + tons',
                  icon: Icons.cloud_upload_outlined,
                  compact: true,
                  onPressed: onUploadPod,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Proof-of-delivery capture: delivered tons + the offload photo.
///
/// P10-D7 (client ruling, 2026-08-12): the photo is **mandatory**. A driver
/// cannot complete a delivery without one — this is the evidence a weight
/// dispute under P8-30 is argued over, and without it a POD proves nothing.
/// The same rule is enforced in `record_pod`, which refuses a POD whose photo
/// is not actually present in the `pod_photos` bucket; this dialog is the UX
/// half, so the driver is stopped before the upload rather than after it.
class _PodDialog extends StatefulWidget {
  final TripRecord trip;
  const _PodDialog({required this.trip});
  @override
  State<_PodDialog> createState() => _PodDialogState();
}

class _PodDialogState extends State<_PodDialog> {
  final _tons = TextEditingController();
  XFile? _photo;

  @override
  void initState() {
    super.initState();
    if (widget.trip.netTons != null) {
      _tons.text = widget.trip.netTons!.toStringAsFixed(2);
    }
  }

  @override
  void dispose() {
    _tons.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      // Cold-phone audit 2026-08-18: this dialog holds input fields and did
      // not scroll, so at a large text size on a narrow phone its content
      // overflowed the viewport and the fields below the fold could not be
      // reached. Measured at 133px of clipped content on the token
      // generator, which is the same shape. `scrollable` only engages when
      // the content exceeds the space, so it is inert on a desktop.
      scrollable: true,
      title: const Text('Proof of delivery'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Confirm the tons delivered and capture the offload photo. '
              'The photo is required — it is the proof in proof of delivery.',
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 12),
          TextField(
            controller: _tons,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
            ],
            decoration: const InputDecoration(
              labelText: 'Delivered tons',
              border: OutlineInputBorder(),
              suffixText: 't',
            ),
          ),
          const SizedBox(height: 12),
          PhotoCaptureField(
            label: 'POD / offload photo',
            onChanged: (f) => setState(() => _photo = f),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final tons = double.tryParse(_tons.text.trim());
            if (tons == null || tons <= 0) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('Enter the delivered tons first.')));
              return;
            }
            // P10-D7: no photo, no POD. Said out loud rather than by dimming
            // the button — a driver standing at an offload point needs to know
            // WHY they cannot submit, not merely that they cannot.
            final photo = _photo;
            if (photo == null) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text(
                      'Capture the offload photo — a delivery cannot be '
                      'recorded without proof.')));
              return;
            }
            Navigator.of(context).pop((tons: tons, photo: photo));
          },
          child: const Text('Submit POD'),
        ),
      ],
    );
  }
}
