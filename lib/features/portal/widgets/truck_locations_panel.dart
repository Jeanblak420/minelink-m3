import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_application_1/features/portal/models/logistics_models.dart';
import 'package:flutter_application_1/core/design/components/ml_components.dart';
import 'package:flutter_application_1/features/portal/widgets/vehicle_positions_map.dart';
import 'package:flutter_application_1/core/time/ml_time.dart';

/// Kit truck-locations layout (buyer / transporter / mine share it):
/// a left rail listing each vehicle's newest GPS sample and a large map —
/// or the honest "No trucks have GPS coordinates recorded" empty panel.
/// Tapping a row highlights that truck on the map via [onSelect].
class TruckLocationsPanel extends StatelessWidget {
  final List<VehiclePositionRecord> positions;
  final String? highlight;
  final ValueChanged<String>? onSelect;
  final VoidCallback? onClearHighlight;
  final String emptyTitle;
  final String emptyMessage;

  /// vehicleId → number plate (registration). Supplied by callers from the
  /// trips they can see, so the list shows a real plate instead of a raw UUID
  /// fragment. Falls back to a short id when a vehicle has no known plate.
  final Map<String, String> plateByVehicleId;

  const TruckLocationsPanel({
    super.key,
    required this.positions,
    this.highlight,
    this.onSelect,
    this.onClearHighlight,
    this.plateByVehicleId = const {},
    this.emptyTitle = 'No trucks have GPS coordinates recorded.',
    this.emptyMessage =
        'GPS is updated when drivers report via the Driver App.',
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final wide = c.maxWidth >= 880;
        final map = _map(context, wide ? null : 300);

        if (positions.isEmpty) return map;

        final list = _list(context, wide);
        if (wide) {
          return SizedBox(
            height: 560,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(width: 300, child: list),
                const SizedBox(width: 14),
                Expanded(child: map),
              ],
            ),
          );
        }
        return Column(children: [map, const SizedBox(height: 14), list]);
      },
    );
  }

  Widget _map(BuildContext context, double? height) {
    if (positions.isEmpty) {
      final emptyHeight = height ?? 560;
      return MlMapCanvas(
        height: emptyHeight < 380 ? 380 : emptyHeight,
        child: MlEmptyState(
          icon: Icons.local_shipping_outlined,
          title: emptyTitle,
          message: emptyMessage,
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: height == null ? MainAxisSize.max : MainAxisSize.min,
      children: [
        if (height == null)
          Expanded(
            child: VehiclePositionsMap(
              positions: positions,
              height: null,
              highlightVehicleId: highlight,
            ),
          )
        else
          VehiclePositionsMap(
            positions: positions,
            height: height,
            highlightVehicleId: highlight,
          ),
        if (highlight != null && onClearHighlight != null)
          TextButton.icon(
            onPressed: onClearHighlight,
            icon: const Icon(Icons.clear_all_rounded, size: 16),
            label: const Text('Clear highlight'),
          ),
      ],
    );
  }

  Widget _list(BuildContext context, bool scrollable) {
    final semantic = MlSemantic.of(context);
    final rows = [
      for (var i = 0; i < positions.length; i++) _row(context, positions[i], i),
    ];

    return MlCard(
      padding: const EdgeInsets.all(8),
      child: scrollable
          ? ListView(children: rows)
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < rows.length; i++) ...[
                  if (i > 0) Divider(height: 1, color: semantic.divider),
                  rows[i],
                ],
              ],
            ),
    );
  }

  Widget _row(BuildContext context, VehiclePositionRecord p, int index) {
    final semantic = MlSemantic.of(context);
    final selected = highlight != null && p.vehicleId == highlight;
    final plate = plateByVehicleId[p.vehicleId];
    final id = (plate != null && plate.trim().isNotEmpty)
        ? plate.toUpperCase()
        : (p.vehicleId.length <= 8
            ? p.vehicleId.toUpperCase()
            : p.vehicleId.substring(0, 8).toUpperCase());

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(MlTokens.rMd),
        onTap: onSelect == null ? null : () => onSelect!(p.vehicleId),
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
          child: Row(
            children: [
              MlIconWell(
                icon: selected
                    ? Icons.my_location_rounded
                    : Icons.local_shipping_outlined,
                tone: selected ? MlTone.accent : MlTone.transit,
                size: 36,
                radius: 10,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    MlPlatePill(id, fontSize: 12),
                    const SizedBox(height: 3),
                    Text(
                      '${p.lat.toStringAsFixed(4)}, ${p.lng.toStringAsFixed(4)}',
                      style: TextStyle(
                        fontFamily: MlTokens.fontMono,
                        fontSize: 11.5,
                        color: semantic.textMuted,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                DateFormat('dd MMM').format(MlTime.sast(p.recordedAt)),
                style: TextStyle(
                  fontFamily: MlTokens.fontMono,
                  fontSize: 11.5,
                  color: semantic.textFaint,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
