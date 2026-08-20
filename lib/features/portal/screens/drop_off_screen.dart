import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import 'package:flutter_application_1/core/utils/safe_ref.dart';
import 'package:flutter_application_1/features/portal/models/trip_waypoint.dart';
import 'package:flutter_application_1/features/portal/providers/trip_waypoint_provider.dart';
import 'package:flutter_application_1/features/portal/utils/maps_link.dart';
import 'package:flutter_application_1/features/portal/widgets/location_picker.dart';
import 'package:flutter_application_1/core/design/components/ml_components.dart';
import 'package:flutter_application_1/core/utils/friendly_error.dart';

/// `/portal/transporter/drop-off/:tripId` (phase-5 T8, design §3.5) — set or
/// move a trip's final drop-off waypoint (waypoint 6 of the MG→WB→LP→WB→MG→
/// drop-off sequence) via the `set_drop_off_waypoint` RPC. Point comes from
/// the shared free OSM location picker; the address is plain text. Strictly
/// additive bookkeeping: the drop-off waypoint never drives `TripStatus`.
class DropOffScreen extends ConsumerStatefulWidget {
  final String tripId;
  const DropOffScreen({required this.tripId, super.key});

  @override
  ConsumerState<DropOffScreen> createState() => _DropOffScreenState();
}

class _DropOffScreenState extends ConsumerState<DropOffScreen> {
  final _address = TextEditingController();
  LatLng? _point;
  bool _prefilled = false;
  bool _saving = false;

  @override
  void dispose() {
    _address.dispose();
    super.dispose();
  }

  TripWaypoint? _dropOffOf(List<TripWaypoint> waypoints) {
    for (final w in waypoints) {
      if (w.locationType == WaypointType.dropOff) return w;
    }
    return null;
  }

  /// Seed the form from the existing drop-off waypoint, once. Runs during
  /// build but never calls setState — the current build already uses the
  /// assigned values.
  void _prefillFrom(List<TripWaypoint> waypoints) {
    if (_prefilled) return;
    _prefilled = true;
    final drop = _dropOffOf(waypoints);
    if (drop == null) return;
    if (drop.hasCoordinates) {
      _point = LatLng(drop.latitude, drop.longitude);
    }
    if (drop.address.trim().isNotEmpty) _address.text = drop.address;
  }

  Future<void> _pickOnMap() async {
    final picked = await showLocationPickerDialog(
      context,
      initial: _point == null
          ? null
          : googleMapsLink(_point!.latitude, _point!.longitude),
    );
    final p = latLngFromMapsLink(picked);
    if (p != null && mounted) setState(() => _point = p);
  }

  Future<void> _save() async {
    final messenger = ScaffoldMessenger.of(context);
    final p = _point;
    if (p == null) {
      messenger.showSnackBar(const SnackBar(
          content: Text('Pick the drop-off point on the map first.')));
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(tripWaypointServiceProvider).setDropOff(
            tripId: widget.tripId,
            lat: p.latitude,
            lng: p.longitude,
            address: _address.text.trim(),
          );
      ref.invalidateIfMounted(tripWaypointsProvider(widget.tripId));
      messenger
          .showSnackBar(const SnackBar(content: Text('Drop-off point saved.')));
    } catch (e) {
      messenger.showSnackBar(
          SnackBar(content: Text('Could not save the drop-off point. ${friendlyError(e)}')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final semantic = MlSemantic.of(context);
    final async = ref.watch(tripWaypointsProvider(widget.tripId));
    final waypoints = async.valueOrNull;
    if (waypoints != null) _prefillFrom(waypoints);
    final drop = waypoints == null ? null : _dropOffOf(waypoints);
    final isSet = drop?.hasCoordinates ?? false;

    return MlPageBody(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MlPageHeader(
            title: 'Drop-off point',
            // Not a count — this screen holds one waypoint, and whether it
            // is pinned yet is the fact worth carrying in the meta slot.
            meta: waypoints == null
                ? null
                : (isSet ? 'Drop-off pinned' : 'Not pinned yet'),
            description:
                'Confirm where this load was delivered, then record the '
                'proof of delivery.',
          ),
          MlCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  MlIconWell(
                      icon: Icons.where_to_vote_outlined,
                      tone: isSet ? MlTone.done : MlTone.neutral,
                      size: 40,
                      radius: 12),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Final drop-off for this trip',
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: semantic.textStrong)),
                        Text(
                            'The last stop of the trip\'s waypoint sequence — '
                            'where the load is delivered.',
                            style: TextStyle(
                                fontSize: 12.5, color: semantic.textMuted)),
                      ],
                    ),
                  ),
                ]),
                const SizedBox(height: 14),
                if (async.isLoading && waypoints == null)
                  const Padding(
                      padding: EdgeInsets.all(18),
                      child: Center(child: CircularProgressIndicator()))
                else ...[
                  // Current drop-off (if set) — mono coordinates + address.
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: semantic.surfaceSunken,
                      borderRadius: BorderRadius.circular(MlTokens.rSm),
                    ),
                    child: Text(
                      isSet
                          ? 'Current: ${drop!.latitude.toStringAsFixed(6)}, '
                              '${drop.longitude.toStringAsFixed(6)}'
                              '${drop.address.trim().isNotEmpty ? ' · ${drop.address}' : ''}'
                          : 'No drop-off point set for this trip yet.',
                      style: TextStyle(
                          fontFamily:
                              isSet ? MlTokens.fontMono : MlTokens.fontSans,
                          fontSize: 12,
                          color: semantic.textMuted),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _address,
                    decoration: const InputDecoration(
                      labelText: 'Address (optional)',
                      hintText: 'Street address or site description',
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (_point != null) ...[
                    Text(
                        'Selected point: '
                        '${_point!.latitude.toStringAsFixed(6)}, '
                        '${_point!.longitude.toStringAsFixed(6)}',
                        style: TextStyle(
                            fontFamily: MlTokens.fontMono,
                            fontSize: 11.5,
                            color: semantic.textMuted,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          )),
                    const SizedBox(height: 10),
                  ],
                  // Wrap, not Row. These two buttons overflowed by 22px at
                  // 360px wide — and at text scale 0.85, the SMALLEST setting,
                  // so it overflowed at every scale. This is the driver's
                  // drop-off screen: "Save drop-off" being pushed off the right
                  // edge of a phone is the POD not getting recorded. They stack
                  // onto a second line instead.
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      MlButton.outline(
                          label:
                              _point == null ? 'Pick on map' : 'Change on map',
                          icon: Icons.map_outlined,
                          onPressed: _saving ? null : _pickOnMap),
                      MlButton.go(
                          label: _saving ? 'Saving…' : 'Save drop-off',
                          icon: Icons.check_rounded,
                          onPressed: _saving ? null : _save),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 60),
        ],
      ),
    );
  }
}
