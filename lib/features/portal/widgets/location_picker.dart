import 'package:flutter_application_1/core/design/tokens/m3/ml_shape.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_application_1/core/design/tokens/m3/ml_typography.dart';
import 'package:flutter_application_1/core/widgets/osm_tile_layer.dart';
import 'package:latlong2/latlong.dart';

import 'package:flutter_application_1/features/portal/services/place_search_service.dart';
import 'package:flutter_application_1/features/portal/utils/maps_link.dart';
import 'package:flutter_application_1/core/utils/friendly_error.dart';

/// The corrected universal map link (CLAUDE.md §4): always the `?q=` form.
/// NOT the malformed `https://google.com{lat},${lng}` — do not revert this.
String googleMapsLink(double lat, double lng) =>
    'https://www.google.com/maps?q=$lat,$lng';

/// Opens a free (OpenStreetMap tiles + Nominatim/Photon search) location
/// picker. Returns a [googleMapsLink] for the chosen point, or null if
/// cancelled.
Future<String?> showLocationPickerDialog(
  BuildContext context, {
  String? initial,
  @visibleForTesting PlaceSearchService? searchService,
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => LocationPickerDialog(
      initial: initial,
      searchService: searchService,
    ),
  );
}

@visibleForTesting
class LocationPickerDialog extends StatefulWidget {
  final String? initial;
  final PlaceSearchService? searchService;
  const LocationPickerDialog({super.key, this.initial, this.searchService});

  @override
  State<LocationPickerDialog> createState() => _LocationPickerDialogState();
}

class _LocationPickerDialogState extends State<LocationPickerDialog> {
  final _mapController = MapController();
  final _search = TextEditingController();
  late final PlaceSearchService _places =
      widget.searchService ?? PlaceSearchService();
  Timer? _debounce;
  List<PlaceHit> _results = const [];
  bool _searching = false;
  String? _error;

  /// The query whose search came back with nothing. Without this the dialog
  /// rendered an empty list and no message, so "Nominatim knows no such place"
  /// looked identical to "still typing" and to "broken".
  String? _noMatchesFor;

  /// Only the newest search may write state. A slow earlier response used to be
  /// able to land after a newer one and overwrite it with stale results.
  int _searchSeq = 0;

  LatLng? _pin;

  static const _saCenter = LatLng(-29.0, 24.0); // South Africa default view

  @override
  void initState() {
    super.initState();
    _pin = latLngFromMapsLink(widget.initial);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    _mapController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String q) {
    _debounce?.cancel();
    if (q.trim().length < 3) {
      setState(() {
        _results = const [];
        _noMatchesFor = null;
        _error = null;
      });
      return;
    }
    // Nominatim usage policy: <= 1 request/second. Debounce generously.
    _debounce = Timer(
      const Duration(milliseconds: 1100),
      () => _runSearch(q.trim()),
    );
  }

  Future<void> _runSearch(String q) async {
    final seq = ++_searchSeq;
    setState(() {
      _searching = true;
      _error = null;
      _noMatchesFor = null;
    });
    try {
      final hits = await _places.search(q);
      if (!mounted || seq != _searchSeq) return;
      setState(() {
        _results = hits;
        _searching = false;
        // An empty list is an ANSWER, and has to look like one.
        _noMatchesFor = hits.isEmpty ? q : null;
      });
    } catch (e) {
      if (!mounted || seq != _searchSeq) return;
      setState(() {
        _searching = false;
        _error = 'Could not search. ${friendlyError(e)}';
        _results = const [];
        _noMatchesFor = null;
      });
    }
  }

  void _select(LatLng p, {double zoom = 14}) {
    setState(() {
      _pin = p;
      _results = const [];
    });
    // Move AFTER the rebuild this setState schedules, not during it.
    //
    // The first pick changes the dialog's layout: the results list collapses
    // and the "Selected: lat, lng" line appears, so the map's `Expanded` is a
    // different height in the very next frame. Moving synchronously dispatched
    // the camera change against the pre-resize map, and the resize itself emits
    // no tile-update event — so nothing was ever requested for the final
    // camera. Measured in a browser 2026-08-17: **zero** tile requests in the
    // four seconds after the first pick (a pin on flat grey), then twenty
    // requests, all HTTP 200, the instant a single wheel event reached the map.
    // Every subsequent pick worked, because by then the layout no longer moved
    // — which is why this only ever broke the one pick that matters.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _mapController.move(p, zoom);
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 640),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.location_on_outlined),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text('Pick product location',
                        style:
                            TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _search,
                onChanged: _onSearchChanged,
                textInputAction: TextInputAction.search,
                onSubmitted: (v) {
                  _debounce?.cancel();
                  if (v.trim().length >= 3) _runSearch(v.trim());
                },
                decoration: InputDecoration(
                  isDense: true,
                  hintText: 'Search an address, or paste a Google Maps link…',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searching
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2)),
                        )
                      : null,
                  border: const OutlineInputBorder(),
                ),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(_error!,
                      style: context.mlText.bodySmall.copyWith(
                        color: scheme.error,
                      )),
                ),
              // The results are for a BROADER query than the one typed, because
              // nothing matched the full one. Saying so is the difference
              // between "here is your address" and "here is the area it is in".
              if (_results.isNotEmpty && _results.first.matchedQuery != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    'No exact match — showing results for '
                    '“${_results.first.matchedQuery}”. For the precise point, '
                    'paste the place’s Google Maps link or long-press the map.',
                    style: context.mlText.bodySmall.copyWith(
                      color: scheme.tertiary,
                    ),
                  ),
                ),
              if (_results.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(top: 6),
                  constraints: const BoxConstraints(maxHeight: 150),
                  decoration: BoxDecoration(
                    border: Border.all(color: scheme.outlineVariant),
                    borderRadius: MlShape.radiusSmall,
                  ),
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      for (final p in _results)
                        ListTile(
                          dense: true,
                          leading: const Icon(Icons.place_outlined, size: 18),
                          title: Text(p.label,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 13)),
                          onTap: () {
                            _search.text = p.label.split(',').first;
                            _select(p.point);
                          },
                        ),
                    ],
                  ),
                ),
              if (_noMatchesFor != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    PlaceSearchService.looksLikeLink(_noMatchesFor!)
                        ? 'That link did not carry a location. Open it in '
                            'Google Maps, then copy the link from the address '
                            'bar and paste it here.'
                        : 'No matches for “$_noMatchesFor”. Open-map data may '
                            'not have this building — search the street, or '
                            'find the place in Google Maps and paste its link '
                            'here for an exact pin.',
                    style: context.mlText.bodySmall.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              const SizedBox(height: 10),
              Text('Long-press the map to drop a pin, or paste “lat, lng”.',
                  style:
                      context.mlText.bodySmall.copyWith(
                        color: scheme.onSurfaceVariant,
                      )),
              const SizedBox(height: 6),
              Expanded(
                child: ClipRRect(
                  borderRadius: MlShape.radiusMedium,
                  child: FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: _pin ?? _saCenter,
                      initialZoom: _pin != null ? 14 : 5,
                      onLongPress: (_, latLng) =>
                          setState(() => _pin = latLng),
                      interactionOptions: const InteractionOptions(
                        flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                      ),
                    ),
                    children: [
                      mlOsmTileLayer(),
                      // Always present, empty when there is no pin. Adding and
                      // removing a layer reshuffles FlutterMap's unkeyed child
                      // list, which is churn the tile layer has no reason to
                      // sit through every time somebody picks a place.
                      MarkerLayer(
                        markers: [
                          if (_pin != null)
                            Marker(
                              point: _pin!,
                              width: 44,
                              height: 44,
                              alignment: Alignment.topCenter,
                              child: Icon(Icons.location_on,
                                  color: scheme.error, size: 40),
                            ),
                        ],
                      ),
                      mlMapAttribution(),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // A fixed slot, present whether or not there is a pin. Letting
              // this line appear only after the first pick resized the map in
              // the same frame as the camera move, which is what left the very
              // first pin sitting on a blank grey square.
              SizedBox(
                height: 16,
                child: Text(
                  _pin == null
                      ? 'No location picked yet.'
                      : 'Selected: ${_pin!.latitude.toStringAsFixed(5)}, '
                          '${_pin!.longitude.toStringAsFixed(5)}',
                  style:
                      context.mlText.bodySmall.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: _pin == null
                        ? null
                        : () => Navigator.of(context).pop(
                            googleMapsLink(_pin!.latitude, _pin!.longitude)),
                    icon: const Icon(Icons.check_rounded, size: 18),
                    label: const Text('Use this location'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
