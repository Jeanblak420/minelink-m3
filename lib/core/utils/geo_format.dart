import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

/// How a coordinate, a distance and a direction are written wherever the
/// product shows one to a person.
///
/// These are pure functions on purpose. Everything they answer — "where is
/// this?", "how far?", "which way?" — used to be either absent or computed
/// inline inside a widget, which is how the driver's HUD and the telemetry
/// published to every watcher were once able to disagree about the same trip.
/// One place, unit-tested, no `BuildContext`.
///
/// ⚠️ **Arithmetic only, never bitwise** — CLAUDE.md §10.6. Dart's bitwise
/// operators are unsigned 32-bit under dart2js, and every number here can be
/// negative (a southern latitude, a western longitude, a bearing difference).

/// Six decimal places — about 11 cm at the equator, and the convention every
/// mapping tool round-trips without argument.
///
/// Always signed and always padded, so two coordinates line up in a column and
/// `-25.7` never renders beside `-25.746100` looking like a different kind of
/// number. South African latitudes are negative, which is exactly the case a
/// naive `toString()` gets visually wrong.
String mlLatLngText(LatLng p) =>
    '${p.latitude.toStringAsFixed(6)}, ${p.longitude.toStringAsFixed(6)}';

/// The initial great-circle bearing from [a] to [b], in degrees `[0, 360)`.
///
/// Normalised by adding a full turn before the modulo: `%` on a negative
/// double returns a negative result in Dart, so `atan2`'s `-90°` would come
/// back as `-90` rather than `270` and every westward heading would read as a
/// compass point on the wrong side.
double mlBearingDeg(LatLng a, LatLng b) {
  const rad = math.pi / 180;
  final lat1 = a.latitude * rad;
  final lat2 = b.latitude * rad;
  final dLon = (b.longitude - a.longitude) * rad;
  final y = math.sin(dLon) * math.cos(lat2);
  final x =
      math.cos(lat1) * math.sin(lat2) -
      math.sin(lat1) * math.cos(lat2) * math.cos(dLon);
  final deg = math.atan2(y, x) / rad;
  return (deg + 360) % 360;
}

/// The sixteen-point compass name for [degrees].
///
/// Sixteen rather than eight because a driver reading "NE" for anything from
/// 22° to 67° is being told very little; sixteen puts every answer within
/// 11.25° of the truth, which is the resolution a person can actually act on.
String mlCompassPoint(double degrees) {
  const points = <String>[
    'N', 'NNE', 'NE', 'ENE', 'E', 'ESE', 'SE', 'SSE', //
    'S', 'SSW', 'SW', 'WSW', 'W', 'WNW', 'NW', 'NNW', //
  ];
  final normalised = (degrees % 360 + 360) % 360;
  // 22.5° per point, and the FIRST point straddles north — so the offset is
  // half a segment, not zero. Without it 350° reads "NNW" instead of "N".
  final index = ((normalised + 11.25) / 22.5).floor() % 16;
  return points[index];
}

/// A distance a person reads at a glance.
///
/// Metres below a kilometre, one decimal of a kilometre above it — the same
/// two rules the driver's navigation HUD has always used, lifted here so the
/// map and the HUD cannot drift apart.
String mlDistanceText(double meters) {
  if (meters.isNaN || meters.isInfinite) return '—';
  final m = meters.abs();
  if (m < 1000) return '${m.round()} m';
  return '${(m / 1000).toStringAsFixed(1)} km';
}

/// Where [to] is, relative to [from], as a driver would say it out loud.
///
/// `"12.4 km NE of you"`. Returns null when [from] is unknown, because
/// "12.4 km NE" of nothing is not a fact.
String? mlRelativePositionText(LatLng? from, LatLng to) {
  if (from == null) return null;
  final metres = const Distance().as(LengthUnit.Meter, from, to);
  // Under ~15 m the bearing is noise — a GPS fix is not that precise, and
  // "3 m SSW of you" claims a resolution the hardware does not have.
  if (metres < 15) return 'where you are standing';
  return '${mlDistanceText(metres.toDouble())} '
      '${mlCompassPoint(mlBearingDeg(from, to))} of you';
}
