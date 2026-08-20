import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter_application_1/features/portal/services/routing_service.dart';

/// The routing engine, reached through a provider rather than constructed at
/// the call site.
///
/// `DriverNavigationScreen` said `RoutingService().fetchRoute(...)` inline, and
/// that one word — the constructor — is what kept the only screen a driver
/// looks at while moving out of every picture ever taken of this product. There
/// is no way to hand a `RoutingService()` a route, so the screen could not be
/// rendered anywhere without a live Valhalla or OSRM host, which a widget test
/// does not have and a golden must never depend on.
///
/// This is the same seam, and the same reasoning, as `FleetNotifier.start()`:
/// a component that dials out from a place nobody can reach cannot serve a
/// preview, a print view, a render or a test. The running app is unchanged —
/// the default is exactly what the call site used to build.
final routingServiceProvider =
    Provider<RoutingService>((ref) => RoutingService());
