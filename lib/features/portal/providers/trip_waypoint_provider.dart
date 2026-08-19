import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter_application_1/features/portal/models/trip_waypoint.dart';
import 'package:flutter_application_1/features/portal/services/trip_waypoint_service.dart';

final tripWaypointServiceProvider =
    Provider<TripWaypointService>((ref) => TripWaypointService());

/// A trip's mine-nav waypoints in sequence order. Empty when the mine never
/// configured its anchors — consumers render nothing in that case (the
/// waypoint layer is strictly additive to navigation).
final tripWaypointsProvider = FutureProvider.autoDispose
    .family<List<TripWaypoint>, String>((ref, tripId) {
  return ref.watch(tripWaypointServiceProvider).forTrip(tripId);
});
