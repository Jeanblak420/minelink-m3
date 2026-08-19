/// Configurable mine navigation anchor (Main Gate / Weighbridge / Loading
/// Point). One active row per type per mine in `mine_locations` — distinct
/// from the generic named `company_locations` points (phase-5 design §2).
enum MineLocationType {
  mainGate,
  weighbridge,
  loadingPoint;

  /// The exact string persisted in `mine_locations.location_type`.
  String get wire {
    switch (this) {
      case MineLocationType.mainGate:
        return 'main_gate';
      case MineLocationType.weighbridge:
        return 'weighbridge';
      case MineLocationType.loadingPoint:
        return 'loading_point';
    }
  }

  String get label {
    switch (this) {
      case MineLocationType.mainGate:
        return 'Main Gate';
      case MineLocationType.weighbridge:
        return 'Weighbridge';
      case MineLocationType.loadingPoint:
        return 'Loading Point';
    }
  }

  /// Tolerant parse per the repo's wire-enum rule — unknown wire values never
  /// crash the UI (the DB check constraint only admits the three canonical
  /// values, so the fallback is defensive).
  static MineLocationType parse(String? raw) {
    final normalized =
        (raw ?? '').trim().toLowerCase().replaceAll(RegExp(r'[\s-]+'), '_');
    for (final value in MineLocationType.values) {
      if (value.wire == normalized) return value;
    }
    return MineLocationType.mainGate;
  }
}

/// A row of the live `mine_locations` table (migration 20260726090000).
class MineLocation {
  final String id;
  final String mineCompanyId;
  final MineLocationType locationType;
  final String name;
  final String address;
  final double? latitude;
  final double? longitude;
  final String? mapLink;

  /// Optional link into the existing `company_locations` system.
  final String? companyLocationId;
  final bool isActive;
  final DateTime? createdAt;

  const MineLocation({
    required this.id,
    required this.mineCompanyId,
    required this.locationType,
    this.name = '',
    this.address = '',
    this.latitude,
    this.longitude,
    this.mapLink,
    this.companyLocationId,
    this.isActive = true,
    this.createdAt,
  });

  /// True when this anchor can be placed on a map / routed to.
  bool get hasCoordinates => latitude != null && longitude != null;

  factory MineLocation.fromJson(Map<String, dynamic> json) => MineLocation(
        id: '${json['id']}',
        mineCompanyId: '${json['mine_company_id']}',
        locationType: MineLocationType.parse(json['location_type'] as String?),
        name: (json['name'] as String?) ?? '',
        address: (json['address'] as String?) ?? '',
        latitude: (json['latitude'] as num?)?.toDouble(),
        longitude: (json['longitude'] as num?)?.toDouble(),
        mapLink: json['map_link'] as String?,
        companyLocationId: json['company_location_id'] as String?,
        isActive: json['is_active'] != false,
        createdAt: json['created_at'] != null
            ? DateTime.tryParse('${json['created_at']}')
            : null,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'mine_company_id': mineCompanyId,
        'location_type': locationType.wire,
        'name': name,
        'address': address,
        'latitude': latitude,
        'longitude': longitude,
        'map_link': mapLink,
        'company_location_id': companyLocationId,
        'is_active': isActive,
        if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      };
}
