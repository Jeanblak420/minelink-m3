import 'package:latlong2/latlong.dart';

import 'package:flutter_application_1/features/portal/models/nav_route.dart'
    show decodePolyline5;
import 'package:flutter_application_1/features/portal/models/trip_status.dart';
import 'package:flutter_application_1/features/portal/utils/maps_link.dart';

/// One active trip with its latest GPS sample, as returned by the
/// `list_live_trip_positions` RPC (party-scoped). `lat`/`lng` are null until
/// the driver's first ping lands.
class LiveTripPosition {
  final String tripId;
  final TripStatus status;
  final String? vehicleId;
  final String? truckReg;
  final String? transporterName;
  final String? supplierName;
  final String? buyerName;
  final String? loadingPoint;
  final String? offloadingPoint;
  final double? lat;
  final double? lng;
  final double? heading;
  final double? speedKmh;
  final DateTime? recordedAt;

  /// Assigned driver(s) for the truck, comma-joined, primary first.
  final String? driverName;

  /// The primary driver's WhatsApp/contact number.
  final String? driverPhone;

  /// The instant the truck last dropped below the "moving" threshold; null
  /// while it is still moving. Backs the "standing still for X" readout.
  final DateTime? stationarySince;

  // --- Trip timeline (2026-07-17 telemetry sharing) ---
  final DateTime? tripCreatedAt;
  final DateTime? arrivedAt;
  final DateTime? loadingAt;
  final DateTime? loadedAt;
  final DateTime? leftAt;
  final DateTime? offloadedAt;

  // --- Driver navigation mirror (trip_nav_state via the feed) ---
  final String? navInstruction;
  final DateTime? navEta;
  final DateTime? navOriginalEta;
  final int? navTimeLeftS;
  final int? navDistanceLeftM;
  final double? navSpeedKmh;
  final DateTime? navStartedAt;
  final String? navRoutePolyline;
  final DateTime? navUpdatedAt;

  const LiveTripPosition({
    required this.tripId,
    required this.status,
    this.vehicleId,
    this.truckReg,
    this.transporterName,
    this.supplierName,
    this.buyerName,
    this.loadingPoint,
    this.offloadingPoint,
    this.lat,
    this.lng,
    this.heading,
    this.speedKmh,
    this.recordedAt,
    this.driverName,
    this.driverPhone,
    this.stationarySince,
    this.tripCreatedAt,
    this.arrivedAt,
    this.loadingAt,
    this.loadedAt,
    this.leftAt,
    this.offloadedAt,
    this.navInstruction,
    this.navEta,
    this.navOriginalEta,
    this.navTimeLeftS,
    this.navDistanceLeftM,
    this.navSpeedKmh,
    this.navStartedAt,
    this.navRoutePolyline,
    this.navUpdatedAt,
  });

  static DateTime? _dt(dynamic v) =>
      v is String && v.isNotEmpty ? DateTime.tryParse(v) : null;

  factory LiveTripPosition.fromJson(Map<String, dynamic> json) {
    final recorded = json['recorded_at'] as String?;
    final stationary = json['stationary_since'] as String?;
    return LiveTripPosition(
      tripId: json['trip_id'] as String,
      status: TripStatus.parse(json['trip_status'] as String?),
      vehicleId: json['vehicle_id'] as String?,
      truckReg: json['truck_reg'] as String?,
      transporterName: json['transporter_name'] as String?,
      supplierName: json['supplier_name'] as String?,
      buyerName: json['buyer_name'] as String?,
      loadingPoint: json['loading_point'] as String?,
      offloadingPoint: json['offloading_point'] as String?,
      lat: (json['lat'] as num?)?.toDouble(),
      lng: (json['lng'] as num?)?.toDouble(),
      heading: (json['heading'] as num?)?.toDouble(),
      speedKmh: (json['speed_kmh'] as num?)?.toDouble(),
      recordedAt: recorded == null ? null : DateTime.parse(recorded),
      driverName: json['driver_name'] as String?,
      driverPhone: json['driver_phone'] as String?,
      stationarySince: stationary == null ? null : DateTime.parse(stationary),
      tripCreatedAt: _dt(json['trip_created_at']),
      arrivedAt: _dt(json['arrived_at']),
      loadingAt: _dt(json['loading_at']),
      loadedAt: _dt(json['loaded_at']),
      leftAt: _dt(json['left_at']),
      offloadedAt: _dt(json['offloaded_at']),
      navInstruction: json['nav_instruction'] as String?,
      navEta: _dt(json['nav_eta']),
      navOriginalEta: _dt(json['nav_original_eta']),
      navTimeLeftS: (json['nav_time_left_s'] as num?)?.toInt(),
      navDistanceLeftM: (json['nav_distance_left_m'] as num?)?.toInt(),
      navSpeedKmh: (json['nav_speed_kmh'] as num?)?.toDouble(),
      navStartedAt: _dt(json['nav_started_at']),
      navRoutePolyline: json['nav_route_polyline'] as String?,
      navUpdatedAt: _dt(json['nav_updated_at']),
    );
  }

  bool get hasFix => lat != null && lng != null;

  /// Whether the latest ping reports the truck moving (≥ 5 km/h). Null speed
  /// means the device did not report motion — treat as unknown, not stopped.
  bool get isMoving => speedKmh != null && speedKmh! >= 5;

  /// True only when we can positively say the truck is standing still: a fix
  /// exists and the latest speed is a real reading below the moving threshold.
  bool get isStationary => hasFix && speedKmh != null && speedKmh! < 5;

  /// How long the truck has been standing still, when known.
  Duration? get stationaryFor {
    if (!isStationary || stationarySince == null) return null;
    final d = DateTime.now().difference(stationarySince!);
    return d.isNegative ? Duration.zero : d;
  }

  LatLng? get point => hasFix ? LatLng(lat!, lng!) : null;

  /// Where the truck is heading at its current lifecycle stage: the loading
  /// point until it has left the mine, the offloading point after.
  String? get destinationText =>
      status.step < TripStatus.leftMine.step ? loadingPoint : offloadingPoint;

  /// The destination as coordinates — only when the request stored a
  /// `?q=lat,lng` maps link rather than plain text.
  LatLng? get destinationPoint => latLngFromMapsLink(destinationText);

  /// Straight-line distance to the destination, when both ends are known.
  double? get distanceToDestinationKm {
    final from = point;
    final to = destinationPoint;
    if (from == null || to == null) return null;
    return const Distance().as(LengthUnit.Kilometer, from, to);
  }

  /// ETA from the reported speed over the straight-line distance; null while
  /// stationary or when speed/destination is unknown (< 5 km/h ≈ parked).
  Duration? get eta {
    final km = distanceToDestinationKm;
    final v = speedKmh;
    if (km == null || v == null || v < 5) return null;
    return Duration(seconds: (km / v * 3600).round());
  }

  // --- Navigation mirror helpers (2026-07-17) ---

  /// Whether the driver's nav telemetry is present and fresh enough to show
  /// (the driver navigated within the last 30 minutes of this feed row).
  bool get hasFreshNav =>
      navUpdatedAt != null &&
      DateTime.now().difference(navUpdatedAt!) < const Duration(minutes: 30);

  /// The exact route line the driver is following, decoded for the map.
  List<LatLng> get navRoutePoints {
    final enc = navRoutePolyline;
    if (enc == null || enc.isEmpty) return const [];
    try {
      return decodePolyline5(enc);
    } catch (_) {
      return const [];
    }
  }

  /// How far past (positive) or ahead of (negative) the driver's ORIGINAL
  /// ETA the current ETA sits — "how much longer than his original eta".
  Duration? get etaOverrun {
    final cur = navEta, base = navOriginalEta;
    if (cur == null || base == null) return null;
    return cur.difference(base);
  }

  /// When the journey started: navigation start when known, else the moment
  /// the trip was scheduled.
  DateTime? get startedAt => navStartedAt ?? tripCreatedAt;
}
