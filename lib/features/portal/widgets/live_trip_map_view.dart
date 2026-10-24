import 'package:flutter_application_1/core/design/tokens/m3/ml_shape.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_animations/flutter_map_animations.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:flutter_application_1/core/design/tokens/m3/ml_typography.dart';
import 'package:flutter_application_1/core/widgets/osm_tile_layer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import 'package:flutter_application_1/features/portal/models/live_trip_position.dart';
import 'package:flutter_application_1/features/portal/models/mine_hazard.dart';
import 'package:flutter_application_1/features/portal/models/trip_status.dart';
import 'package:flutter_application_1/features/portal/providers/hazard_provider.dart';
import 'package:flutter_application_1/features/portal/providers/live_tracking_provider.dart';
import 'package:flutter_application_1/features/portal/widgets/live_truck_marker.dart';
import 'package:flutter_application_1/features/portal/widgets/map_fit.dart';
import 'package:flutter_application_1/core/design/components/ml_components.dart';
import 'package:flutter_application_1/core/time/ml_time.dart';

/// The live-map page header's count, from the same rule the map uses: a truck
/// is "reporting" only when it has a GPS fix ([LiveTripPosition.hasFix]).
///
/// The header used to count every active trip, so one scheduled trip whose
/// driver had not shared GPS read "1 truck reporting" directly above the map's
/// "No GPS fixes yet." When some trips have no fix, both numbers are given.
String liveMapReportingMeta(List<LiveTripPosition> trips) {
  final reporting = trips.where((t) => t.hasFix).length;
  if (reporting == trips.length) {
    return mlCount(reporting, 'truck reporting', 'trucks reporting');
  }
  return '${mlCount(trips.length, 'active trip', 'active trips')} · '
      '$reporting reporting GPS';
}

/// Live trip map (§4 Live GPS tracking): every active trip the caller may see,
/// with its truck's latest position, refreshed over realtime as driver pings
/// land. [companyId] scopes to that org's trips; null is the platform-wide
/// super-admin view. Shared by the org portals and the super-admin screen.
class LiveTripMapView extends ConsumerStatefulWidget {
  final String? companyId;

  const LiveTripMapView({super.key, required this.companyId});

  @override
  ConsumerState<LiveTripMapView> createState() => _LiveTripMapViewState();
}

class _LiveTripMapViewState extends ConsumerState<LiveTripMapView>
    with TickerProviderStateMixin {
  String? _highlightTripId;

  /// Smooth camera moves (flutter_map_animations) — selecting a truck glides
  /// the map to it instead of jumping.
  late final AnimatedMapController _camera = AnimatedMapController(
    vsync: this,
    duration: const Duration(milliseconds: 550),
    curve: Curves.easeOutCubic,
  );

  @override
  void dispose() {
    _camera.dispose();
    super.dispose();
  }

  void _selectTrip(LiveTripPosition? t) {
    setState(() => _highlightTripId = t?.tripId);
    final point = t?.point;
    if (point != null) {
      _camera.animateTo(dest: point);
    }
  }

  /// What the "centre on" control goes back to, or null if there is nothing to
  /// go back to.
  ///
  /// The selected truck if one is selected; otherwise the ONLY truck, when
  /// there is exactly one. That second case is the driver's own: a driver
  /// watching this map has one active trip, so the button reads as "put me
  /// back on my truck" without this widget having to work out who is looking
  /// at it — which it cannot do honestly, because [LiveTripPosition] carries a
  /// driver's NAME and not their user id.
  LatLng? _focusPoint(List<LiveTripPosition> withFix) {
    for (final t in withFix) {
      if (t.tripId == _highlightTripId) return t.point;
    }
    if (withFix.length == 1) return withFix.first.point;
    return null;
  }

  /// Press and hold anywhere to ask where that is (jean, 2026-08-22).
  ///
  /// `from` is deliberately null here. This map is watched by mine, buyer and
  /// transporter office staff as well as by drivers, and the viewer's own
  /// position is not among the things it knows — so "12.4 km NE **of you**"
  /// would be a claim about somebody who might be sitting in Johannesburg.
  /// A coordinate on its own cannot be wrong.
  void _droppedPin(LatLng point) {
    showMlDroppedPin(context, point: point);
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(liveTripPositionsProvider(widget.companyId));
    return async.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => MlCard(
        child: MlLoadFailure(
          icon: Icons.wifi_off_rounded,
          subject: 'the live map',
          error: e,
          onRetry: () =>
              ref.invalidate(liveTripPositionsProvider(widget.companyId)),
        ),
      ),
      data: (trips) {
        if (trips.isEmpty) {
          return MlMapCanvas(
            height: 420,
            child: const MlEmptyState(
              icon: Icons.local_shipping_outlined,
              title: 'No active trips right now.',
              message:
                  'Trucks appear here the moment a trip is scheduled; their '
                  'position goes live once the driver starts sharing GPS.',
            ),
          );
        }
        return _panel(context, trips);
      },
    );
  }

  Widget _panel(BuildContext context, List<LiveTripPosition> trips) {
    final withFix = trips.where((t) => t.hasFix).toList();
    return LayoutBuilder(
      builder: (context, c) {
        final wide = c.maxWidth >= 880;
        final map = _map(context, trips, withFix, wide ? null : 320.0);
        final rail = _rail(context, trips, scrollable: wide);
        if (wide) {
          return SizedBox(
            height: 560,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(width: 330, child: rail),
                const SizedBox(width: 14),
                Expanded(child: map),
              ],
            ),
          );
        }
        return Column(children: [map, const SizedBox(height: 14), rail]);
      },
    );
  }

  Widget _map(
    BuildContext context,
    List<LiveTripPosition> trips,
    List<LiveTripPosition> withFix,
    double? height,
  ) {
    if (withFix.isEmpty) {
      return MlMapCanvas(
        height: height,
        child: const MlEmptyState(
          icon: Icons.gps_off_outlined,
          title: 'No GPS fixes yet.',
          message:
              'Positions appear as soon as a driver turns on live location '
              'sharing.',
        ),
      );
    }

    final highlighted = withFix
        .where((t) => t.tripId == _highlightTripId)
        .toList();
    final dest = highlighted.isEmpty
        ? null
        : highlighted.first.destinationPoint;
    // The exact route the driver's navigation is following (2026-07-17
    // telemetry sharing) — drawn when fresh, else a straight bearing line.
    final navRoute = highlighted.isEmpty || !highlighted.first.hasFreshNav
        ? const <LatLng>[]
        : highlighted.first.navRoutePoints;
    final pts = [for (final t in withFix) t.point!, if (dest != null) dest];
    final brightness = Theme.of(context).brightness;
    final destColor = MlTone.error.colors(brightness).fg;
    // Active hazards (blasting zones, closures…) the drivers route around —
    // shown so watchers see the full operating picture. Degrades to nothing.
    final hazards = ref
        .watch(activeHazardsProvider)
        .maybeWhen(data: (h) => h, orElse: () => const <MineHazard>[]);

    final map = ClipRRect(
      borderRadius: MlShape.radiusMedium,
      child: FlutterMap(
        mapController: _camera.mapController,
        options: MapOptions(
          // Not flutter_map's near-white default: see mlMapBackground.
          backgroundColor: mlMapBackground(context),
          // Guard against identical/degenerate GPS samples, which would
          // otherwise give flutter_map an Infinity fit zoom and crash tile
          // rendering.
          initialCameraFit: safeCoordinatesFit(
            pts,
            padding: const EdgeInsets.all(32),
          ),
          interactionOptions: const InteractionOptions(
            flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
          ),
          onLongPress: (tapPosition, point) => _droppedPin(point),
        ),
        children: [
          mlOsmTiles(context),
          if (navRoute.length >= 2)
            // Mirror of the driver's actual navigation route.
            PolylineLayer(
              polylines: [
                Polyline(
                  points: navRoute,
                  strokeWidth: 6,
                  color: MlTokens.navy700,
                ),
                Polyline(
                  points: navRoute,
                  strokeWidth: 3.5,
                  color: MlTokens.accent,
                ),
              ],
            )
          else if (dest != null && highlighted.first.point != null)
            PolylineLayer(
              polylines: [
                Polyline(
                  points: [highlighted.first.point!, dest],
                  strokeWidth: 2.5,
                  color: destColor.withValues(alpha: 0.7),
                ),
              ],
            ),
          if (hazards.isNotEmpty)
            MarkerLayer(
              markers: [
                for (final h in hazards)
                  Marker(
                    point: LatLng(h.latitude, h.longitude),
                    width: 34,
                    height: 34,
                    alignment: Alignment.center,
                    child: _hazardMarker(context, h, brightness),
                  ),
              ],
            ),
          // Trucks cluster into count bubbles when they crowd (dozens of
          // vehicles stay readable); tapping a cluster zooms into it.
          MarkerClusterLayerWidget(
            options: MarkerClusterLayerOptions(
              maxClusterRadius: 46,
              size: const Size(44, 44),
              alignment: Alignment.center,
              markers: [
                for (final t in withFix)
                  if (t.tripId != _highlightTripId)
                    Marker(
                      point: t.point!,
                      width: 44,
                      height: 44,
                      alignment: Alignment.center,
                      child: LiveTruckMarker(
                        trip: t,
                        onTap: () => _selectTrip(t),
                      ),
                    ),
              ],
              builder: (context, markers) => DecoratedBox(
                decoration: BoxDecoration(
                  color: MlTokens.accent,
                  shape: BoxShape.circle,
                  border: Border.all(color: MlTokens.inkOnFill, width: 2.5),
                  boxShadow: const [
                    BoxShadow(color: MlTokens.mapControlShadow, blurRadius: 8),
                  ],
                ),
                child: Center(
                  child: Text(
                    '${markers.length}',
                    style: const TextStyle(
                      color: MlTokens.inkOnFill,
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ),
          ),
          MarkerLayer(
            markers: [
              if (dest != null)
                Marker(
                  point: dest,
                  width: 40,
                  height: 40,
                  alignment: Alignment.topCenter,
                  child: Icon(Icons.flag_rounded, color: destColor, size: 30),
                ),
              // The highlighted truck sits on top, outside the cluster.
              for (final t in highlighted)
                Marker(
                  point: t.point!,
                  width: 56,
                  height: 56,
                  alignment: Alignment.center,
                  child: LiveTruckMarker(
                    trip: t,
                    highlighted: true,
                    onTap: () => _selectTrip(null),
                  ),
                ),
            ],
          ),
          mlMapScaleBar(context),
          mlMapAttribution(),
        ],
      ),
    );

    // The controls sit OVER the map, not inside it: a `FlutterMap` child is
    // laid out against the map's own coordinate space and would be dragged
    // around with the tiles.
    final withControls = Stack(
      children: [
        Positioned.fill(child: map),
        Positioned(
          right: 0,
          bottom: 0,
          child: MlMapControls(
            controller: _camera.mapController,
            // Rotation is excluded from this map's interaction flags, so a
            // compass here could only ever point north — see [allowRotation].
            allowRotation: false,
            // Clear of the attribution mark, which sits in this corner.
            // Measured on `screen-live-trip-map-phone-dark.png`: the credit
            // occupies roughly the bottom 34px of the map and the disc was
            // painting over it.
            padding: const EdgeInsets.only(right: 10, bottom: 44),
            hasFix: true,
            recenterTooltip: withFix.length == 1
                ? 'Centre on the truck'
                : 'Centre on the selected truck',
            // ABSENT rather than disabled when there is nothing to centre on.
            //
            // A fleet map with two trucks and none selected has no "me" — and
            // the first render of this showed a permanently crossed-out
            // location button, which reads as a broken control rather than an
            // inapplicable one. It appears the moment a truck is selected, and
            // is always there for a driver, who has exactly one.
            onRecenter: _focusPoint(withFix) == null
                ? null
                : () {
                    final p = _focusPoint(withFix);
                    if (p != null) _camera.animateTo(dest: p);
                  },
            onOverview: withFix.isEmpty
                ? null
                : () => _camera.mapController.fitCamera(
                    safeCoordinatesFit([
                      for (final t in withFix) t.point!,
                      if (dest != null) dest,
                    ], padding: const EdgeInsets.all(46)),
                  ),
            overviewTooltip: 'Fit every truck on screen',
          ),
        ),
      ],
    );

    return height == null
        ? SizedBox.expand(child: withControls)
        : SizedBox(height: height, child: withControls);
  }

  MlTone _hazardTone(MineHazard h) {
    switch (h.severity) {
      case 'critical':
        return MlTone.error;
      case 'low':
        return MlTone.neutral;
      default:
        return MlTone.warn;
    }
  }

  Widget _hazardMarker(BuildContext context, MineHazard h, Brightness b) {
    final tone = _hazardTone(h).colors(b);
    return Tooltip(
      message: h.description.isEmpty
          ? h.typeLabel
          : '${h.typeLabel} — ${h.description}',
      child: Container(
        decoration: BoxDecoration(
          color: tone.bg,
          shape: BoxShape.circle,
          border: Border.all(color: tone.fg, width: 2),
        ),
        child: Icon(Icons.warning_amber_rounded, color: tone.fg, size: 18),
      ),
    );
  }

  Widget _rail(
    BuildContext context,
    List<LiveTripPosition> trips, {
    required bool scrollable,
  }) {
    final semantic = MlSemantic.of(context);
    final rows = [for (final t in trips) _row(context, t)];
    // Separated in both branches and headed with its count — the desktop
    // ListView ran its rows together (design-reference §4, §5.4). Phase 3
    // mine pass, 2026-08-23.
    // No meta: the page header above already counts the live trips.
    const head = MlSectionTitle(
      'Trips',
      margin: EdgeInsets.fromLTRB(8, 4, 8, 4),
    );
    return MlCard(
      padding: const EdgeInsets.all(8),
      child: scrollable
          ? Column(
              children: [
                head,
                Expanded(
                  child: ListView.separated(
                    itemCount: rows.length,
                    separatorBuilder: (_, __) =>
                        Divider(height: 1, color: semantic.divider),
                    itemBuilder: (_, i) => rows[i],
                  ),
                ),
              ],
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                head,
                for (var i = 0; i < rows.length; i++) ...[
                  if (i > 0) Divider(height: 1, color: semantic.divider),
                  rows[i],
                ],
              ],
            ),
    );
  }

  Widget _row(BuildContext context, LiveTripPosition t) {
    final semantic = MlSemantic.of(context);
    final selected = t.tripId == _highlightTripId;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(MlTokens.rMd),
        onTap: () => _selectTrip(selected ? null : t),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? MlTokens.accent.withValues(alpha: 0.08)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(MlTokens.rMd),
            border: Border.all(
              color: selected ? MlTokens.cyan200 : Colors.transparent,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // THE PLATE IS THE TRUCK; THE PILL IS THE TYPE SCALE'S SIZE;
              // AND EVERY ROW IN THIS LIST HAS THE SAME SHAPE.
              //
              // This row was `[well] [Expanded(identity)] [SizedBox(112) >
              // FittedBox(scaleDown, badge)]`. Three shapes were tried before
              // this one, and each failure is why the next was needed:
              //
              //  1. The `FittedBox` SHRANK a pill whose label did not fit
              //     112px, so `screen-live-trip-map-desktop-dark` drew `EN
              //     ROUTE TO OFFLOAD` in visibly smaller type than the
              //     `LOADING` beneath it — two pills, one list, two type
              //     sizes, decided by how long the words are. It also undid
              //     the reader's own text scale: raise it and the box stays
              //     112px (§5.6; CLAUDE.md §10.4, a fixed width around text).
              //     `ml_empty_state.dart` records the same verdict about
              //     `FittedBox`.
              //  2. Taking the `FittedBox` away on its own then cost the
              //     IDENTITY instead: in this ~330px panel a full-size pill
              //     left the `Expanded` too little and the plate ellipsised to
              //     `JD 22 …`. A plate cut in half is worse than a small pill
              //     — it is WHICH TRUCK this is.
              //  3. `MlHeaderLayout` fixed both by measuring per row, and then
              //     TWO ROWS WITH THE SAME STATUS LAID OUT DIFFERENTLY. The
              //     arithmetic says why: well 34 + gap 10 + identity ≈110 +
              //     gap 12 + `EN ROUTE TO OFFLOAD` ≈150 lands within a few
              //     pixels of the panel's width, so whether a row shares its
              //     line comes down to how wide the transporter's NAME is.
              //     `RH 128 GP / Roadhaul Logistics` stacked and `NL 004 MP /
              //     Northline Carriers` did not, in adjacent rows, both `EN
              //     ROUTE TO OFFLOAD`.
              //
              // A list of like things should not change shape on a few pixels
              // of somebody's company name. The pill takes its own line,
              // always, flush right: uniform, the plate never cut, the pill
              // never shrunk, and one line taller only on the rows that could
              // have fitted — which the measurement showed are the minority
              // and the marginal ones.
              Row(
                children: [
                  MlIconWell(
                    icon: t.hasFix
                        ? Icons.local_shipping_rounded
                        : Icons.gps_off_outlined,
                    tone: t.hasFix ? MlTone.transit : MlTone.neutral,
                    size: 34,
                    radius: 10,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (t.truckReg != null)
                          MlPlatePill(t.truckReg!, fontSize: 12)
                        else
                          Text(
                            'Trip ${t.tripId.substring(0, 6)}…',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        const SizedBox(height: 3),
                        Text(
                          t.transporterName ?? '—',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.mlText.bodySmall.copyWith(
                            color: semantic.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              // `SizedBox(width: infinity)` because a `Wrap` sizes to its
              // content, and an alignment with no free space does nothing
              // (CLAUDE.md §10.4). `Wrap` rather than `Align` so a future
              // second pill wraps rather than overflows.
              SizedBox(
                width: double.infinity,
                child: Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 8,
                  runSpacing: 6,
                  children: [MlStatusBadge.forStatus(t.status.label)],
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _journeyLine(t),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: context.mlText.bodySmall.copyWith(
                  color: semantic.textMuted,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _gpsLine(t),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.mlText.code(
                  color: semantic.textFaint,
                  size: 11,
                  weight: FontWeight.w400,
                ),
              ),
              // Full driver-navigation mirror + trip timeline (2026-07-17):
              // what the driver sees, for everyone allowed to watch the trip.
              if (selected) _detail(context, t),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detail(BuildContext context, LiveTripPosition t) {
    final semantic = MlSemantic.of(context);
    final brightness = Theme.of(context).brightness;

    Widget stat(String value, String label, {Color? color}) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: context.mlText.code(
            color: color ?? semantic.textStrong,
            size: 14,
            weight: FontWeight.w800,
          ),
        ),
        Text(
          label,
          style: context.mlText.labelSmall.copyWith(
            color: semantic.textMuted,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );

    // Live nav numbers — the same four the driver's HUD shows.
    String eta = '—', mins = '—', dist = '—', speed = '—';
    if (t.hasFreshNav) {
      if (t.navEta != null) eta = MlTime.clock(t.navEta!);
      if (t.navTimeLeftS != null) {
        mins = '${(t.navTimeLeftS! / 60).ceil()} min';
      }
      if (t.navDistanceLeftM != null) {
        final m = t.navDistanceLeftM!;
        dist = m < 1000 ? '$m m' : '${(m / 1000).toStringAsFixed(1)} km';
      }
      speed = '${(t.navSpeedKmh ?? t.speedKmh ?? 0).round()}';
    } else if (t.speedKmh != null) {
      speed = '${t.speedKmh!.round()}';
    }

    // "How much longer than his original ETA" — the overrun vs plan.
    String plan = '—';
    Color? planColor;
    final over = t.etaOverrun;
    if (over != null) {
      final m = over.inMinutes;
      if (m >= 2) {
        plan = '+$m min';
        planColor = MlTone.error.colors(brightness).fg;
      } else if (m <= -2) {
        plan = '$m min';
        planColor = MlTone.done.colors(brightness).fg;
      } else {
        plan = 'on time';
        planColor = MlTone.done.colors(brightness).fg;
      }
    }

    final stationary = t.stationaryFor;

    Widget timelineRow(String label, DateTime? at, {String? suffix}) {
      if (at == null) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Row(
          children: [
            SizedBox(
              width: 92,
              child: Text(
                label,
                style: context.mlText.labelSmall.copyWith(
                  color: semantic.textMuted,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
            Expanded(
              child: Text(
                '${MlTime.clock(at)}${suffix ?? ''}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.mlText.code(
                  color: semantic.textStrong,
                  size: 11,
                  weight: FontWeight.w400,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (t.hasFreshNav && (t.navInstruction ?? '').isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: MlTokens.accent.withValues(alpha: 0.10),
                borderRadius: MlShape.radiusSmall,
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.turn_right_rounded,
                    size: 15,
                    color: MlTokens.accent,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      t.navInstruction!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: context.mlText.labelMedium.copyWith(
                        color: semantic.textStrong,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              stat(eta, 'ETA'),
              stat(mins, 'Time left'),
              stat(dist, 'Distance'),
              stat(speed, 'km/h'),
              stat(plan, 'vs plan', color: planColor),
            ],
          ),
          if (stationary != null && stationary.inMinutes >= 1)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                children: [
                  Icon(
                    Icons.pause_circle_outline,
                    size: 14,
                    color: MlTone.warn.colors(brightness).fg,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    'Not moving for ${_dur(stationary)}',
                    style: context.mlText.labelSmall.copyWith(
                      color: MlTone.warn.colors(brightness).fg,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 8),
          Divider(height: 1, color: semantic.divider),
          const SizedBox(height: 6),
          timelineRow('Started', t.startedAt),
          timelineRow('Arrived mine', t.arrivedAt),
          timelineRow('Loading', t.loadingAt),
          timelineRow('Loaded', t.loadedAt),
          timelineRow('Left mine', t.leftAt),
          timelineRow('Offloaded', t.offloadedAt),
          timelineRow(
            'Now',
            // `MlTime.instant()`, not `DateTime.now()`: this row is the only
            // one in the timeline that is not read off the trip, and it was
            // the DEVICE's clock sitting in a column of server timestamps. It
            // also honours `MlTime.debugClock`, so a render of this panel is
            // reproducible instead of changing every minute.
            MlTime.instant(),
            suffix: t.hasFix
                ? ' · at ${t.lat!.toStringAsFixed(4)}, ${t.lng!.toStringAsFixed(4)}'
                      '${t.recordedAt != null ? ' (updated ${_ago(t.recordedAt!)})' : ''}'
                : ' · no GPS fix yet',
          ),
        ],
      ),
    );
  }

  String _dur(Duration d) {
    if (d.inMinutes < 60) return '${d.inMinutes} min';
    return '${d.inHours} h ${d.inMinutes % 60} min';
  }

  String _journeyLine(LiveTripPosition t) {
    final headingToMine = t.status.step < TripStatus.leftMine.step;
    final dest = t.destinationText;
    final label = headingToMine ? 'To mine' : 'To offload';
    if (dest == null || dest.isEmpty) return '$label · destination not set';
    return '$label · $dest';
  }

  String _gpsLine(LiveTripPosition t) {
    if (!t.hasFix) return 'Awaiting first GPS ping';
    final parts = <String>[];
    final km = t.distanceToDestinationKm;
    if (km != null) parts.add('${km.toStringAsFixed(1)} km to go');
    final eta = t.eta;
    if (eta != null) {
      // `MlTime.now()`, not `DateTime.now()` — CLAUDE.md §7.1. This line built
      // the arrival time off the READER'S DEVICE and printed it as a clock
      // time, so a buyer, mine or admin whose machine was not on South African
      // time read an ETA out by their own offset, on the screen whose whole
      // subject is when a truck gets there. Everything else in this file was
      // already going through `MlTime.sast`; this one was missed, and
      // `one_clock_check.py` could not see it because no calendar field is
      // read off the value — it goes straight into a formatter.
      final arrive = MlTime.now().add(eta);
      parts.add('ETA ${MlTime.calendarClock(arrive)}');
    }
    final at = t.recordedAt;
    if (at != null) parts.add('updated ${_ago(at)}');
    return parts.isEmpty ? 'Live' : parts.join(' · ');
  }

  String _ago(DateTime at) => MlTime.ago(at);
}
