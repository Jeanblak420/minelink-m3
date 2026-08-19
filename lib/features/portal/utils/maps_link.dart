import 'package:latlong2/latlong.dart';

/// Extract a [LatLng] from the universal `?q=lat,lng` Google Maps link the
/// location picker saves (CLAUDE.md §4); returns null for plain-text values,
/// so free-typed locations simply don't resolve to a point.
LatLng? latLngFromMapsLink(String? s) {
  if (s == null) return null;
  final m = RegExp(r'[?&]q=(-?\d+(?:\.\d+)?),(-?\d+(?:\.\d+)?)').firstMatch(s);
  if (m == null) return null;
  final lat = double.tryParse(m.group(1)!);
  final lng = double.tryParse(m.group(2)!);
  if (lat == null || lng == null) return null;
  if (lat < -90 || lat > 90 || lng < -180 || lng > 180) return null;
  return LatLng(lat, lng);
}
