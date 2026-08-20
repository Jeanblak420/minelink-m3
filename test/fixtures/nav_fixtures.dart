// A destination and a route, so the driver's navigation screen can be looked at.
//
// It is the only screen in this product used while moving, and it had no picture
// of any kind. Three things stood between it and one, and all three are seams
// rather than fakes:
//
//   * **GPS** — `test_helpers/fake_geolocator.dart`, through the plugin's own
//     federated platform interface.
//   * **The destination** — `CompanyLocationService.tripNavDestination` calls an
//     RPC. Subclassed here; the provider is a plain `Provider`, so the override
//     is a value.
//   * **The route** — `RoutingService` was CONSTRUCTED at the call site, so
//     there was no way to hand the screen a route at all. It now comes from
//     `routingServiceProvider`; see that file for why that is a fix rather than
//     a test accommodation.
//
// The geography is real: the Iron Hills demo mine near Steelpoort, and a short
// haul south-east along the R555. The route below is a hand-written polyline of
// a real road corridor rather than a straight line, because a straight line
// through the veld would photograph as a design that does not follow roads.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import 'package:flutter_application_1/features/portal/models/company_location.dart';
import 'package:flutter_application_1/features/portal/models/nav_route.dart';
import 'package:flutter_application_1/features/portal/providers/company_location_provider.dart';
import 'package:flutter_application_1/features/portal/providers/routing_provider.dart';
import 'package:flutter_application_1/features/portal/services/company_location_service.dart';
import 'package:flutter_application_1/features/portal/services/routing_service.dart';

/// Where the truck is standing when the render is taken.
const LatLng kNavTruck = LatLng(-24.7395, 30.1918);

/// Where it is going — the booked collection point, not a company address.
const LatLng kNavDestination = LatLng(-24.7208, 30.2260);

/// The corridor between them, roughly following the R555.
const List<LatLng> kNavRoutePoints = [
  LatLng(-24.7395, 30.1918),
  LatLng(-24.7381, 30.1963),
  LatLng(-24.7364, 30.2009),
  LatLng(-24.7340, 30.2051),
  LatLng(-24.7311, 30.2088),
  LatLng(-24.7284, 30.2129),
  LatLng(-24.7261, 30.2173),
  LatLng(-24.7236, 30.2214),
  LatLng(-24.7208, 30.2260),
];

/// Four manoeuvres, so the banner has a real instruction and the step list has
/// something to count down to. Distances add up to [kNavRoute]'s total.
final NavRoute kNavRoute = NavRoute(
  points: kNavRoutePoints,
  distanceM: 6120,
  durationS: 612,
  encoded: encodePolyline5(kNavRoutePoints),
  steps: const [
    NavStep(
      maneuver: NavManeuver.depart,
      roadName: 'Dwarsrivier Road',
      distanceM: 900,
      durationS: 96,
      location: LatLng(-24.7395, 30.1918),
    ),
    NavStep(
      maneuver: NavManeuver.turnLeft,
      roadName: 'R555',
      distanceM: 3400,
      durationS: 320,
      location: LatLng(-24.7340, 30.2051),
    ),
    NavStep(
      maneuver: NavManeuver.turnRight,
      roadName: 'Iron Hills Access Road',
      distanceM: 1620,
      durationS: 176,
      location: LatLng(-24.7236, 30.2214),
    ),
    NavStep(
      maneuver: NavManeuver.arrive,
      roadName: 'Iron Hills Mining — collection point',
      distanceM: 200,
      durationS: 20,
      location: kNavDestination,
    ),
  ],
);

/// A [CompanyLocationService] that answers the nav RPC from the fixture.
///
/// `found: true` with a `point` is the honest shape for a booked `?q=lat,lng`
/// link — the case CLAUDE.md says "always wins: it is an exact point somebody
/// picked for this load" — so the screen renders its confident banner rather
/// than the "this pin is a company address" warning. The warning state is worth
/// a picture too; it needs `found: false` and a `fallbackPoint`.
class FixtureCompanyLocationService extends CompanyLocationService {
  FixtureCompanyLocationService({this.destination});

  final NavDestination? destination;

  @override
  Future<NavDestination> tripNavDestination(String tripId,
          {required bool offloadLeg}) async =>
      destination ??
      const NavDestination(
        found: true,
        point: kNavDestination,
        label: 'Iron Hills Mining — collection point',
        // The server's own vocabulary: `request` is a `?q=lat,lng` link on the
        // booking, and `get_trip_nav_destination` emits exactly this string.
        // The first draft said `request_link`, which no code path produces —
        // and the destination bar's `switch` fell through to its default and
        // printed the place name twice.
        source: 'request',
        pointName: 'Iron Hills Mining — collection point',
      );
}

/// A [RoutingService] that answers from the fixture instead of calling Valhalla.
///
/// [route] is returned VERBATIM, null included — null is the degraded state the
/// screen has to handle when both routing engines are unreachable, and it is a
/// state worth photographing. An earlier version wrote `route ?? kNavRoute`
/// here, which quietly made the no-route render identical to the routed one:
/// two goldens of the same thing, one of them labelled as evidence for
/// something it did not show.
class FixtureRoutingService extends RoutingService {
  FixtureRoutingService({this.route});

  final NavRoute? route;

  @override
  Future<NavRoute?> fetchRoute(LatLng from, LatLng to,
          {List<LatLng> avoidLocations = const [], http.Client? client}) async =>
      route;
}

/// Everything the navigation screen needs to draw a route.
///
/// Pass `route: null` to photograph the degraded state instead — the screen
/// falls back to bearing-and-distance mode, which is a real thing a driver sees
/// when Valhalla and OSRM are both unreachable and is worth its own picture.
List<Override> navigationOverrides({
  NavRoute? route = _useDefaultRoute,
  NavDestination? destination,
}) =>
    [
      companyLocationServiceProvider.overrideWithValue(
        FixtureCompanyLocationService(destination: destination),
      ),
      routingServiceProvider.overrideWithValue(
        FixtureRoutingService(
          route: identical(route, _useDefaultRoute) ? kNavRoute : route,
        ),
      ),
    ];

/// Sentinel: "the caller said nothing", as distinct from "the caller said null".
/// Without it there is no way to ask for the no-route state, because the default
/// and the explicit null look the same.
const NavRoute _useDefaultRoute = NavRoute(
  points: [],
  distanceM: 0,
  durationS: 0,
  steps: [],
);
