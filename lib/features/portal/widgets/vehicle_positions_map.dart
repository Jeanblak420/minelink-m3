import 'package:flutter_application_1/core/design/tokens/m3/ml_shape.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:flutter_application_1/core/widgets/osm_tile_layer.dart';
import 'package:flutter_application_1/features/portal/models/logistics_models.dart';
import 'package:flutter_application_1/features/portal/widgets/map_fit.dart';
import 'package:flutter_application_1/core/design/components/ml_components.dart';
import 'package:latlong2/latlong.dart';

/// OpenStreetMap preview of [positions] (newest samples first is fine).
///
/// When [highlightVehicleId] is set, that vehicle's marker is drawn larger and
/// in an accent colour so a trip tapped elsewhere in the app stands out — this
/// backs the global "click a trip → highlight that truck" rule.
class VehiclePositionsMap extends StatefulWidget {
  final List<VehiclePositionRecord> positions;
  final double? height;
  final String? highlightVehicleId;

  const VehiclePositionsMap({
    super.key,
    required this.positions,
    this.height = 240,
    this.highlightVehicleId,
  });

  @override
  State<VehiclePositionsMap> createState() => _VehiclePositionsMapState();
}

class _VehiclePositionsMapState extends State<VehiclePositionsMap> {
  /// Owned by the State, not built per frame: a controller recreated in
  /// `build` would hand the zoom buttons a different map every rebuild, and
  /// `MlMapControls` subscribes to its event stream once in `initState`.
  final _controller = MapController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final positions = widget.positions;
    final height = widget.height;
    final highlightVehicleId = widget.highlightVehicleId;
    if (positions.isEmpty) return const SizedBox.shrink();

    final pts = positions.map((p) => LatLng(p.lat, p.lng)).toList();
    // Guard against identical/degenerate GPS samples, which would otherwise
    // give flutter_map an Infinity fit zoom and crash tile rendering.
    final fit = safeCoordinatesFit(pts, padding: const EdgeInsets.all(28));

    // Design-system tones (matches the truck-locations rail selection colour):
    // in-transit blue for the fleet, brand accent for the highlighted truck.
    final brightness = Theme.of(context).brightness;
    final primary = MlTone.transit.colors(brightness).fg;
    final highlight = MlTokens.accent;

    final map = ClipRRect(
      borderRadius: MlShape.radiusMedium,
      child: FlutterMap(
        mapController: _controller,
        options: MapOptions(
          // Not flutter_map's near-white default: see mlMapBackground.
          backgroundColor: mlMapBackground(context),
          initialCameraFit: fit,
          interactionOptions: const InteractionOptions(
            flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
          ),
          // Press and hold to ask where a truck is standing (jean,
          // 2026-08-22). `from` is null: this map does not know where the
          // person reading it is.
          onLongPress: (tapPosition, point) =>
              showMlDroppedPin(context, point: point),
        ),
        children: [
          mlOsmTiles(context),
          // Fleet markers cluster into count bubbles when trucks crowd the
          // same area; the highlighted truck stays outside the cluster so it
          // is always individually visible.
          MarkerClusterLayerWidget(
            options: MarkerClusterLayerOptions(
              maxClusterRadius: 46,
              size: const Size(42, 42),
              alignment: Alignment.center,
              markers: [
                for (final p in positions)
                  if (p.vehicleId != highlightVehicleId)
                    Marker(
                      point: LatLng(p.lat, p.lng),
                      width: 40,
                      height: 40,
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.local_shipping_rounded,
                        color: primary,
                        size: 32,
                      ),
                    ),
              ],
              builder: (context, markers) => DecoratedBox(
                decoration: BoxDecoration(
                  color: primary,
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
              // Draw the highlighted truck last so it sits on top.
              for (final p in positions)
                if (p.vehicleId == highlightVehicleId)
                  Marker(
                    point: LatLng(p.lat, p.lng),
                    width: 52,
                    height: 52,
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.local_shipping_rounded,
                      color: highlight,
                      size: 44,
                    ),
                  ),
            ],
          ),
          mlMapScaleBar(context),
          mlMapAttribution(),
        ],
      ),
    );

    final withControls = Stack(
      children: [
        Positioned.fill(child: map),
        Positioned(
          right: 0,
          bottom: 0,
          child: MlMapControls(
            controller: _controller,
            // This map excludes rotation, so a compass could only point north.
            allowRotation: false,
            // There is no "me" on a fleet overview -- only trucks.
            onRecenter: null,
            onOverview: () => _controller.fitCamera(fit),
            overviewTooltip: 'Fit every truck on screen',
            // Clear of the attribution mark in the same corner.
            padding: const EdgeInsets.only(right: 8, bottom: 44),
          ),
        ),
      ],
    );

    return height == null
        ? SizedBox.expand(child: withControls)
        : SizedBox(height: height, child: withControls);
  }
}
