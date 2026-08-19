import 'package:latlong2/latlong.dart';

import 'package:flutter_application_1/features/portal/utils/maps_link.dart';

/// A named, company-managed map point (spec 2026-07-16 §2/§3). The primary
/// location is the automatic driver-navigation fallback destination.
class CompanyLocation {
  final String id;
  final String companyId;
  final String name;
  final String mapLink; // universal 'https://www.google.com/maps?q=lat,lng'
  final bool isPrimary;

  const CompanyLocation({
    required this.id,
    required this.companyId,
    required this.name,
    required this.mapLink,
    required this.isPrimary,
  });

  LatLng? get point => latLngFromMapsLink(mapLink);

  factory CompanyLocation.fromJson(Map<String, dynamic> json) =>
      CompanyLocation(
        id: json['id'] as String,
        companyId: json['company_id'] as String,
        name: (json['name'] as String?) ?? '',
        mapLink: (json['map_link'] as String?) ?? '',
        isPrimary: (json['is_primary'] as bool?) ?? false,
      );
}

/// Result of `get_trip_nav_destination`: where the driver should drive for the
/// current leg, and where that answer came from.
///
/// [source] is one of `request` (a `?q=lat,lng` link on the request itself),
/// `address` (the request names a place in words — geocode [address]),
/// `company_location` (the request named no point, so the party company's
/// primary pin is the best answer), `geocoded` (this client resolved
/// [pointName]) or `none`.
///
/// [pointName] and [fallbackPoint] are the 2026-08-17 fix. Before it, a
/// request naming "Durban Port" came back as the buyer's Rosebank office with
/// `found: true`, so no client ever geocoded the words it had been given.
/// The server now reports both and the client decides, in this order:
/// coordinate on the request → geocode [pointName] → [fallbackPoint].
class NavDestination {
  final bool found;
  final LatLng? point;
  final String label;
  final String source;
  final String? address;

  /// The loading/offloading point exactly as the request words it. This is the
  /// driver's actual instruction, so it is what the nav screen shows.
  final String? pointName;

  /// The party company's primary saved location — a last resort, never the
  /// answer while the request names somewhere.
  final LatLng? fallbackPoint;
  final String? fallbackLabel;

  const NavDestination({
    required this.found,
    this.point,
    required this.label,
    required this.source,
    this.address,
    this.pointName,
    this.fallbackPoint,
    this.fallbackLabel,
  });

  /// True when the coordinate in use is NOT the place the request named — the
  /// driver is being sent to a company pin instead, and has to be told so.
  bool get isCompanyFallback =>
      source == 'company_location' && (pointName ?? '').trim().isNotEmpty;

  NavDestination copyWith({
    bool? found,
    LatLng? point,
    String? label,
    String? source,
  }) =>
      NavDestination(
        found: found ?? this.found,
        point: point ?? this.point,
        label: label ?? this.label,
        source: source ?? this.source,
        address: address,
        pointName: pointName,
        fallbackPoint: fallbackPoint,
        fallbackLabel: fallbackLabel,
      );

  factory NavDestination.fromJson(Map<String, dynamic> json) {
    final lat = (json['lat'] as num?)?.toDouble();
    final lng = (json['lng'] as num?)?.toDouble();
    final fb = json['fallback'];
    final fbMap = fb is Map ? Map<String, dynamic>.from(fb) : null;
    final fbLat = (fbMap?['lat'] as num?)?.toDouble();
    final fbLng = (fbMap?['lng'] as num?)?.toDouble();
    return NavDestination(
      found: (json['found'] as bool?) ?? false,
      point: (lat != null && lng != null) ? LatLng(lat, lng) : null,
      label: (json['label'] as String?) ?? 'Destination',
      source: (json['source'] as String?) ?? 'none',
      address: json['address'] as String?,
      pointName: json['point_name'] as String?,
      fallbackPoint:
          (fbLat != null && fbLng != null) ? LatLng(fbLat, fbLng) : null,
      fallbackLabel: fbMap?['label'] as String?,
    );
  }
}
