/// Canonical trip lifecycle (§2) shared across Mine, Buyer, Transporter and
/// Driver views. Values match the `trips.status` strings written by the
/// cascade RPCs (set_trip_status / record_truck_load / record_pod).
enum TripStatus {
  scheduled,
  enRouteToLoad,
  arrivedAtMine,
  loading,
  loaded,
  leftMine,
  enRouteToOffload,
  offloaded,
  completed,
  cancelled;

  /// The exact string persisted in `trips.status`.
  String get wire {
    switch (this) {
      case TripStatus.scheduled:
        return 'scheduled';
      case TripStatus.enRouteToLoad:
        return 'en_route_to_load';
      case TripStatus.arrivedAtMine:
        return 'arrived_at_mine';
      case TripStatus.loading:
        return 'loading';
      case TripStatus.loaded:
        return 'loaded';
      case TripStatus.leftMine:
        return 'left_mine';
      case TripStatus.enRouteToOffload:
        return 'en_route_to_offload';
      case TripStatus.offloaded:
        return 'offloaded';
      case TripStatus.completed:
        return 'completed';
      case TripStatus.cancelled:
        return 'cancelled';
    }
  }

  /// Human label for chips/lists.
  String get label {
    switch (this) {
      case TripStatus.scheduled:
        return 'Scheduled';
      case TripStatus.enRouteToLoad:
        return 'En route to load';
      case TripStatus.arrivedAtMine:
        return 'Arrived at mine';
      case TripStatus.loading:
        return 'Loading';
      case TripStatus.loaded:
        return 'Loaded';
      case TripStatus.leftMine:
        return 'Left mine';
      case TripStatus.enRouteToOffload:
        return 'En route to offload';
      case TripStatus.offloaded:
        return 'Offloaded';
      case TripStatus.completed:
        return 'Completed';
      case TripStatus.cancelled:
        return 'Cancelled';
    }
  }

  /// Ordered position in the lifecycle (cancelled sorts last).
  int get step => this == TripStatus.cancelled ? 99 : index;

  bool get isActive =>
      this != TripStatus.completed && this != TripStatus.cancelled;

  /// Tolerant parse of a raw `trips.status` string, mapping the legacy values
  /// still present in older rows onto the canonical lifecycle.
  static TripStatus parse(String? raw) {
    switch ((raw ?? '').toLowerCase()) {
      case 'scheduled':
      case 'draft':
        return TripStatus.scheduled;
      case 'en_route_to_load':
      case 'en_route':
      case 'inbound':
        return TripStatus.enRouteToLoad;
      case 'arrived_at_mine':
        return TripStatus.arrivedAtMine;
      case 'loading':
        return TripStatus.loading;
      case 'loaded':
        return TripStatus.loaded;
      case 'left_mine':
        return TripStatus.leftMine;
      case 'en_route_to_offload':
      case 'in_transit':
      case 'active':
        return TripStatus.enRouteToOffload;
      case 'offloaded':
      case 'delivered':
        return TripStatus.offloaded;
      case 'completed':
        return TripStatus.completed;
      case 'cancelled':
        return TripStatus.cancelled;
      default:
        return TripStatus.scheduled;
    }
  }
}
