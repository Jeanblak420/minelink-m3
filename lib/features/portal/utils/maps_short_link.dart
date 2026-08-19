import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import 'package:flutter_application_1/core/config/supabase_config.dart';
import 'package:flutter_application_1/core/utils/logger.dart';
import 'package:flutter_application_1/features/portal/utils/maps_link.dart';

final _log = LoggerFactory.getLogger('MapsShortLink');

/// Extracts a point from a full (already-expanded) Google Maps URL.
/// Priority: `!3d{lat}!4d{lng}` place pin (authoritative) → `?q=lat,lng`
/// → `@lat,lng` viewport centre (weakest). Returns null when nothing parses.
LatLng? latLngFromExpandedMapsUrl(String url) {
  final pin =
      RegExp(r'!3d(-?\d+(?:\.\d+)?)!4d(-?\d+(?:\.\d+)?)').firstMatch(url);
  if (pin != null) {
    final p = _validated(pin.group(1)!, pin.group(2)!);
    if (p != null) return p;
  }
  final q = latLngFromMapsLink(url);
  if (q != null) return q;
  final at = RegExp(r'@(-?\d+(?:\.\d+)?),(-?\d+(?:\.\d+)?)').firstMatch(url);
  if (at != null) return _validated(at.group(1)!, at.group(2)!);
  return null;
}

LatLng? _validated(String latS, String lngS) {
  final lat = double.tryParse(latS);
  final lng = double.tryParse(lngS);
  if (lat == null || lng == null) return null;
  if (lat < -90 || lat > 90 || lng < -180 || lng > 180) return null;
  return LatLng(lat, lng);
}

/// Asks the `resolve-maps-link` edge function to follow the link for us.
///
/// This exists because the WEB build cannot follow a short link at all:
/// maps.app.goo.gl sends no CORS headers, so the request fails before any
/// redirect can be read — measured in Chrome at the app's own origin,
/// "TypeError: Failed to fetch" for both a plain fetch and redirect:"manual".
/// Native builds could do it locally, but they take the same path so there is
/// one behaviour to reason about; the local walk below remains the fallback.
///
/// Returns null on any failure, including no session — never throws.
Future<LatLng?> _resolveViaServer(String link) async {
  try {
    final res = await SupabaseConfig.client.functions
        .invoke('resolve-maps-link', body: {'link': link})
        .timeout(const Duration(seconds: 15));
    final data = res.data;
    if (data is! Map) return null;
    final lat = (data['lat'] as num?)?.toDouble();
    final lng = (data['lng'] as num?)?.toDouble();
    if (lat == null || lng == null) return null;
    if (lat < -90 || lat > 90 || lng < -180 || lng > 180) return null;
    return LatLng(lat, lng);
  } catch (e) {
    _log.w('server could not resolve maps link: $e');
    return null;
  }
}

/// Resolves ANY Google Maps link — long, `?q=`, or short `maps.app.goo.gl` —
/// to a point. Short links are expanded server-side, falling back to following
/// the redirect chain locally (no API key needed either way). Returns null on
/// failure; never throws.
Future<LatLng?> resolveMapsLink(String link, {http.Client? client}) async {
  final trimmed = link.trim();
  final direct = latLngFromExpandedMapsUrl(trimmed);
  if (direct != null) return direct;

  final uri = Uri.tryParse(trimmed);
  if (uri == null || !uri.hasScheme) return null;

  final viaServer = await _resolveViaServer(trimmed);
  if (viaServer != null) return viaServer;

  final c = client ?? http.Client();
  try {
    // Walk redirects manually so we can parse coordinates out of each hop's
    // Location header (google.com URLs 200 with a JS page — the coords live
    // in the URL itself, so headers are all we need).
    var current = uri;
    for (var hop = 0; hop < 5; hop++) {
      final req = http.Request('GET', current)..followRedirects = false;
      final res = await c.send(req).timeout(const Duration(seconds: 12));
      final location = res.headers['location'];
      if (location == null) break;
      final next = Uri.parse(location);
      final resolved = next.hasScheme ? next : current.resolveUri(next);
      final p = latLngFromExpandedMapsUrl(resolved.toString());
      if (p != null) return p;
      current = resolved;
    }
  } catch (e) {
    _log.w('Could not resolve maps link: $e');
  } finally {
    if (client == null) c.close();
  }
  return null;
}
