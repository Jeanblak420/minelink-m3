import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import 'package:flutter_application_1/core/utils/logger.dart';
import 'package:flutter_application_1/features/portal/models/nav_route.dart';

/// Free, key-less OSRM routing (spec 2026-07-16 §1). Overridable so a
/// self-hosted OSRM (or compatible service) can replace the public demo
/// server without a code change: --dart-define=OSRM_BASE_URL=...
const kOsrmBaseUrl = String.fromEnvironment('OSRM_BASE_URL',
    defaultValue: 'https://router.project-osrm.org');

/// Valhalla routing host (phase-5 design §1). Primary engine: truck costing
/// and `exclude_locations` (hazard avoid-zones) that OSRM cannot honour.
/// Overridable for a self-hosted instance:
/// --dart-define=VALHALLA_BASE_URL=...
const kValhallaBaseUrl = String.fromEnvironment('VALHALLA_BASE_URL',
    defaultValue: 'https://valhalla1.openstreetmap.de');

class RoutingService {
  static final _log = LoggerFactory.getLogger('RoutingService');

  /// Driving route with turn-by-turn steps. Valhalla-primary (truck costing;
  /// [avoidLocations] applied as `exclude_locations`), falling back to the
  /// original OSRM path — which cannot honour avoid zones — and finally to
  /// null on ANY failure, at which point the nav screen degrades to
  /// bearing/distance mode.
  Future<NavRoute?> fetchRoute(LatLng from, LatLng to,
      {List<LatLng> avoidLocations = const [], http.Client? client}) async {
    final c = client ?? http.Client();
    try {
      final valhalla = await _fetchValhalla(c, from, to, avoidLocations);
      if (valhalla != null) return valhalla;
      if (avoidLocations.isNotEmpty) {
        _log.w('Valhalla unavailable — OSRM fallback, '
            '${avoidLocations.length} avoid zones not applied');
      }
      return await _fetchOsrm(c, from, to);
    } finally {
      if (client == null) c.close();
    }
  }

  /// Valhalla POST /route with truck costing. Returns null on any failure or
  /// empty/short geometry so [fetchRoute] can fall through to OSRM. The
  /// resulting geometry is RE-ENCODED to precision-5 ([encodePolyline5]) so
  /// `trip_nav_state.route_polyline` stays byte-compatible with every
  /// existing precision-5 watcher.
  Future<NavRoute?> _fetchValhalla(http.Client c, LatLng from, LatLng to,
      List<LatLng> avoidLocations) async {
    final body = <String, dynamic>{
      'locations': [
        {'lat': from.latitude, 'lon': from.longitude},
        {'lat': to.latitude, 'lon': to.longitude},
      ],
      'costing': 'truck',
      'costing_options': {
        'truck': {'weight': 40.0, 'height': 4.5},
      },
      'units': 'kilometers',
      if (avoidLocations.isNotEmpty)
        'exclude_locations': [
          for (final z in avoidLocations)
            {'lat': z.latitude, 'lon': z.longitude},
        ],
    };
    try {
      final res = await c
          .post(
            Uri.parse('$kValhallaBaseUrl/route'),
            headers: const {
              'Content-Type': 'application/json',
              // Fair-use identifier requested by the FOSSGIS demo server.
              'X-Client-Id': 'minelink',
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 12));
      if (res.statusCode != 200) {
        _log.w('Valhalla HTTP ${res.statusCode}');
        return null;
      }
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      final trip = json['trip'] as Map<String, dynamic>?;
      final legs = (trip?['legs'] as List?) ?? const [];
      if (trip == null || legs.isEmpty) {
        _log.w('Valhalla returned no legs');
        return null;
      }

      // Concatenate all legs (a two-location request yields exactly one, but
      // be tolerant). Steps index into their own leg's shape.
      final points = <LatLng>[];
      final steps = <NavStep>[];
      for (final leg in legs) {
        final l = Map<String, dynamic>.from(leg as Map);
        final shape = decodeValhallaShape6((l['shape'] as String?) ?? '');
        for (final m in (l['maneuvers'] as List? ?? const [])) {
          steps.add(
              NavStep.fromValhalla(Map<String, dynamic>.from(m as Map), shape));
        }
        points.addAll(shape);
      }
      if (points.length < 2) {
        _log.w('Valhalla returned an empty shape');
        return null;
      }

      final summary = trip['summary'] as Map<String, dynamic>?;
      return NavRoute(
        points: points,
        distanceM: ((summary?['length'] as num?) ?? 0).toDouble() * 1000,
        durationS: ((summary?['time'] as num?) ?? 0).toDouble(),
        steps: steps,
        encoded: encodePolyline5(points), // precision-5 for trip_nav_state
      );
    } catch (e) {
      _log.w('Valhalla route failed: $e');
      return null;
    }
  }

  /// The original OSRM GET path, unchanged — the regression-free fallback.
  Future<NavRoute?> _fetchOsrm(http.Client c, LatLng from, LatLng to) async {
    final url = Uri.parse('$kOsrmBaseUrl/route/v1/driving/'
        '${from.longitude},${from.latitude};${to.longitude},${to.latitude}'
        '?overview=full&geometries=polyline&steps=true&alternatives=false');
    try {
      final res = await c.get(url).timeout(const Duration(seconds: 12));
      if (res.statusCode != 200) {
        _log.w('OSRM HTTP ${res.statusCode}');
        return null;
      }
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      if (json['code'] != 'Ok') {
        _log.w('OSRM code ${json['code']}');
        return null;
      }
      final route = (json['routes'] as List).first as Map<String, dynamic>;
      final legs = (route['legs'] as List?) ?? const [];
      final steps = <NavStep>[
        for (final leg in legs)
          for (final s in ((leg as Map)['steps'] as List? ?? const []))
            NavStep.fromOsrm(Map<String, dynamic>.from(s as Map)),
      ];
      return NavRoute(
        points: decodePolyline5(route['geometry'] as String),
        distanceM: ((route['distance'] as num?) ?? 0).toDouble(),
        durationS: ((route['duration'] as num?) ?? 0).toDouble(),
        steps: steps,
        encoded: route['geometry'] as String,
      );
    } catch (e) {
      _log.w('OSRM route failed: $e');
      return null;
    }
  }
}
