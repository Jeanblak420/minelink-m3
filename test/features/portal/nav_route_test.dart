import 'dart:convert';

import 'package:flutter/material.dart' show Icons;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';

import 'package:flutter_application_1/features/portal/models/nav_route.dart';
import 'package:flutter_application_1/features/portal/services/routing_service.dart';

void main() {
  test('decodePolyline5 decodes the canonical Google example', () {
    // Reference vector from the polyline algorithm docs.
    final pts = decodePolyline5('_p~iF~ps|U_ulLnnqC_mqNvxq`@');
    expect(pts.length, 3);
    expect(pts[0].latitude, closeTo(38.5, 1e-5));
    expect(pts[0].longitude, closeTo(-120.2, 1e-5));
    expect(pts[2].latitude, closeTo(43.252, 1e-5));
    expect(pts[2].longitude, closeTo(-126.453, 1e-5));
  });

  test('NavManeuver.parse maps OSRM type/modifier and falls back to unknown',
      () {
    expect(NavManeuver.parse('turn', 'left'), NavManeuver.turnLeft);
    expect(NavManeuver.parse('turn', 'slight right'), NavManeuver.slightRight);
    expect(NavManeuver.parse('roundabout', null), NavManeuver.roundabout);
    expect(NavManeuver.parse('arrive', null), NavManeuver.arrive);
    expect(NavManeuver.parse('weird-new-osrm-type', null), NavManeuver.unknown);
    expect(NavManeuver.turnLeft.icon, Icons.turn_left_rounded);
  });

  test('NavStep.instruction wording', () {
    const step = NavStep(
        maneuver: NavManeuver.turnLeft,
        roadName: 'R59',
        distanceM: 400,
        durationS: 30,
        location: LatLng(0, 0));
    expect(step.instruction, 'Turn left onto R59');
    const round = NavStep(
        maneuver: NavManeuver.roundabout,
        roadName: 'N4',
        distanceM: 100,
        durationS: 10,
        location: LatLng(0, 0),
        exit: 2);
    expect(round.instruction, 'At the roundabout, take exit 2 onto N4');
  });

  test('fetchRoute parses a Valhalla response (primary engine)', () async {
    final body = jsonEncode({
      'trip': {
        'summary': {'length': 12.3, 'time': 900.0}, // km, seconds
        'legs': [
          {
            // Decoded at 1e6 (Valhalla precision) this yields >= 2 points.
            'shape': '_p~iF~ps|U_ulLnnqC',
            'maneuvers': [
              {
                'type': 1,
                'street_names': ['R59'],
                'length': 12.3,
                'time': 900,
                'begin_shape_index': 0,
              },
              {
                'type': 4,
                'length': 0.0,
                'time': 0,
                'begin_shape_index': 1,
              },
            ],
          },
        ],
      },
    });
    final client = MockClient((req) async {
      // Valhalla is the primary engine: a POST to /route.
      expect(req.method, 'POST');
      expect(req.url.path, endsWith('/route'));
      return http.Response(body, 200);
    });
    final r = await RoutingService().fetchRoute(
        const LatLng(38.5, -120.2), const LatLng(40.7, -120.95),
        client: client);
    expect(r, isNotNull);
    expect(r!.distanceM, closeTo(12300, 1)); // 12.3 km -> metres
    expect(r.durationS, closeTo(900, 0.01));
    expect(r.points.length, greaterThanOrEqualTo(2));
    expect(r.steps.length, 2);
    expect(r.encoded, isNotEmpty); // re-encoded to precision-5
  });

  test('fetchRoute falls back to OSRM when Valhalla fails, and parses it',
      () async {
    final body = jsonEncode({
      'code': 'Ok',
      'routes': [
        {
          'geometry': '_p~iF~ps|U_ulLnnqC',
          'distance': 1234.5,
          'duration': 600.0,
          'legs': [
            {
              'steps': [
                {
                  'maneuver': {
                    'type': 'depart',
                    'modifier': null,
                    'location': [-120.2, 38.5]
                  },
                  'name': 'R59',
                  'distance': 1000.0,
                  'duration': 500.0,
                },
                {
                  'maneuver': {
                    'type': 'arrive',
                    'modifier': null,
                    'location': [-120.95, 40.7]
                  },
                  'name': '',
                  'distance': 0.0,
                  'duration': 0.0,
                },
              ],
            },
          ],
        },
      ],
    });
    var osrmHit = false;
    final client = MockClient((req) async {
      if (req.method == 'POST' && req.url.path.endsWith('/route')) {
        // Force the Valhalla primary to fail so the OSRM fallback runs.
        return http.Response('{}', 503);
      }
      // OSRM fallback GET.
      osrmHit = true;
      expect(req.url.path, contains('/route/v1/driving/'));
      expect(req.url.queryParameters['steps'], 'true');
      return http.Response(body, 200);
    });
    final r = await RoutingService().fetchRoute(
        const LatLng(38.5, -120.2), const LatLng(40.7, -120.95),
        client: client);
    expect(osrmHit, isTrue);
    expect(r, isNotNull);
    expect(r!.distanceM, closeTo(1234.5, 0.01));
    expect(r.steps.length, 2);
    expect(r.steps.first.maneuver, NavManeuver.depart);
    expect(r.steps.first.roadName, 'R59');
    expect(r.points.first.latitude, closeTo(38.5, 1e-5));
  });

  test('fetchRoute returns null on non-Ok / network error', () async {
    final bad = MockClient((_) async => http.Response('{"code":"NoRoute"}', 200));
    expect(
        await RoutingService()
            .fetchRoute(const LatLng(0, 0), const LatLng(1, 1), client: bad),
        isNull);
    final err = MockClient((_) async => throw http.ClientException('down'));
    expect(
        await RoutingService()
            .fetchRoute(const LatLng(0, 0), const LatLng(1, 1), client: err),
        isNull);
  });
}
