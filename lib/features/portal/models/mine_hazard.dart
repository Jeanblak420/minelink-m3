/// A reported hazard (blasting zone, pothole, slow haulage, road closure) on
/// or near a haul road. Rows live in the plain-lat/lng `mine_hazards` table
/// (migration 20260726090100 — NO PostGIS geom) and radius queries go through
/// the `get_nearby_hazards(lat, lng, radius_meters)` RPC, which also returns a
/// computed `distance_meters` per row.
class MineHazard {
  /// Serial integer PK of `mine_hazards`.
  final int id;
  final String hazardType; // blasting | pothole | slow_haulage | road_closure
  final String severity; // low | medium | critical
  final String description;
  final double latitude;
  final double longitude;

  /// Distance from the query point — only meaningful on rows returned by
  /// `get_nearby_hazards`; 0 elsewhere.
  final double distanceMeters;
  final DateTime? reportedAt;
  final DateTime? expiresAt;

  /// The mine this hazard concerns (`mine_hazards.mine_company_id`).
  ///
  /// Decides both who may publish it and which drivers receive it: only that
  /// mine's owner/admin/management and drivers with a trip to it that has not
  /// yet left, per the RLS policies in migration 20260816220000. Nullable here
  /// only because rows read through older cached payloads may not carry it;
  /// the column itself is NOT NULL.
  final String? mineCompanyId;

  const MineHazard({
    required this.id,
    required this.hazardType,
    this.severity = 'medium',
    this.description = '',
    required this.latitude,
    required this.longitude,
    this.distanceMeters = 0,
    this.reportedAt,
    this.expiresAt,
    this.mineCompanyId,
  });

  /// Still in force (no expiry, or expiry in the future).
  bool get isActive =>
      expiresAt == null || expiresAt!.isAfter(DateTime.now().toUtc());

  /// Critical hazards (blasting zones) feed routing avoid-zones.
  bool get isCritical => severity == 'critical';

  String get typeLabel {
    switch (hazardType) {
      case 'blasting':
        return 'Blasting Zone';
      case 'pothole':
        return 'Pothole';
      case 'slow_haulage':
        return 'Slow Haulage';
      case 'road_closure':
        return 'Road Closure';
      default:
        return hazardType;
    }
  }

  /// Distance formatted for display (e.g. "350 m", "1.2 km").
  String get distanceLabel => distanceMeters < 1000
      ? '${distanceMeters.round()} m'
      : '${(distanceMeters / 1000).toStringAsFixed(1)} km';

  factory MineHazard.fromJson(Map<String, dynamic> json) => MineHazard(
        id: (json['id'] as num?)?.toInt() ??
            int.tryParse('${json['id']}') ??
            0,
        hazardType: (json['hazard_type'] as String?) ?? 'unknown',
        severity: (json['severity'] as String?) ?? 'medium',
        description: (json['description'] as String?) ?? '',
        latitude: (json['latitude'] as num?)?.toDouble() ?? 0,
        longitude: (json['longitude'] as num?)?.toDouble() ?? 0,
        distanceMeters: (json['distance_meters'] as num?)?.toDouble() ?? 0,
        reportedAt: json['reported_at'] != null
            ? DateTime.tryParse('${json['reported_at']}')
            : null,
        expiresAt: json['expires_at'] != null
            ? DateTime.tryParse('${json['expires_at']}')
            : null,
        mineCompanyId: json['mine_company_id'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'hazard_type': hazardType,
        'severity': severity,
        'description': description,
        'latitude': latitude,
        'longitude': longitude,
        'distance_meters': distanceMeters,
        'reported_at': reportedAt?.toIso8601String(),
        'expires_at': expiresAt?.toIso8601String(),
        'mine_company_id': mineCompanyId,
      };
}
