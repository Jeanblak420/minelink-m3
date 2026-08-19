import 'package:flutter/material.dart' show IconData, Icons;
import 'package:latlong2/latlong.dart';

/// OSRM maneuver types/modifiers folded to a UI-friendly enum. Tolerant parse
/// per the repo's wire-enum rule — unknown wire values never crash the UI.
enum NavManeuver {
  depart,
  turnLeft,
  turnRight,
  slightLeft,
  slightRight,
  sharpLeft,
  sharpRight,
  uturn,
  merge,
  onRamp,
  offRamp,
  fork,
  roundabout,
  exitRoundabout,
  continueStraight,
  newName,
  arrive,
  unknown;

  static NavManeuver parse(String? type, String? modifier) {
    switch (type) {
      case 'depart':
        return NavManeuver.depart;
      case 'arrive':
        return NavManeuver.arrive;
      case 'merge':
        return NavManeuver.merge;
      case 'on ramp':
        return NavManeuver.onRamp;
      case 'off ramp':
        return NavManeuver.offRamp;
      case 'fork':
        return NavManeuver.fork;
      case 'roundabout':
      case 'rotary':
        return NavManeuver.roundabout;
      case 'exit roundabout':
      case 'exit rotary':
        return NavManeuver.exitRoundabout;
      case 'new name':
        return NavManeuver.newName;
      case 'continue':
        return _byModifier(modifier, NavManeuver.continueStraight);
      case 'turn':
      case 'end of road':
        return _byModifier(modifier, NavManeuver.continueStraight);
      default:
        return NavManeuver.unknown;
    }
  }

  static NavManeuver _byModifier(String? m, NavManeuver fallback) {
    switch (m) {
      case 'left':
        return NavManeuver.turnLeft;
      case 'right':
        return NavManeuver.turnRight;
      case 'slight left':
        return NavManeuver.slightLeft;
      case 'slight right':
        return NavManeuver.slightRight;
      case 'sharp left':
        return NavManeuver.sharpLeft;
      case 'sharp right':
        return NavManeuver.sharpRight;
      case 'uturn':
        return NavManeuver.uturn;
      case 'straight':
        return NavManeuver.continueStraight;
      default:
        return fallback;
    }
  }

  IconData get icon {
    switch (this) {
      case NavManeuver.depart:
        return Icons.navigation_rounded;
      case NavManeuver.turnLeft:
        return Icons.turn_left_rounded;
      case NavManeuver.turnRight:
        return Icons.turn_right_rounded;
      case NavManeuver.slightLeft:
        return Icons.turn_slight_left_rounded;
      case NavManeuver.slightRight:
        return Icons.turn_slight_right_rounded;
      case NavManeuver.sharpLeft:
        return Icons.turn_sharp_left_rounded;
      case NavManeuver.sharpRight:
        return Icons.turn_sharp_right_rounded;
      case NavManeuver.uturn:
        return Icons.u_turn_left_rounded;
      case NavManeuver.merge:
        return Icons.merge_rounded;
      case NavManeuver.onRamp:
        return Icons.ramp_right_rounded;
      case NavManeuver.offRamp:
        return Icons.exit_to_app_rounded;
      case NavManeuver.fork:
        return Icons.fork_right_rounded;
      case NavManeuver.roundabout:
        return Icons.roundabout_right_rounded;
      case NavManeuver.exitRoundabout:
        return Icons.roundabout_right_rounded;
      case NavManeuver.continueStraight:
        return Icons.straight_rounded;
      case NavManeuver.newName:
        return Icons.straight_rounded;
      case NavManeuver.arrive:
        return Icons.sports_score_rounded;
      case NavManeuver.unknown:
        return Icons.navigation_outlined;
    }
  }
}

class NavStep {
  final NavManeuver maneuver;
  final String roadName;
  final double distanceM; // step length
  final double durationS;
  final LatLng location; // where the maneuver happens
  final int? exit; // roundabout exit number

  const NavStep({
    required this.maneuver,
    required this.roadName,
    required this.distanceM,
    required this.durationS,
    required this.location,
    this.exit,
  });

  /// "Turn left onto R59" / "At the roundabout, take exit 2" / "You have arrived".
  String get instruction {
    final onto = roadName.isEmpty ? '' : ' onto $roadName';
    switch (maneuver) {
      case NavManeuver.depart:
        return 'Head out$onto';
      case NavManeuver.turnLeft:
        return 'Turn left$onto';
      case NavManeuver.turnRight:
        return 'Turn right$onto';
      case NavManeuver.slightLeft:
        return 'Keep slightly left$onto';
      case NavManeuver.slightRight:
        return 'Keep slightly right$onto';
      case NavManeuver.sharpLeft:
        return 'Sharp left$onto';
      case NavManeuver.sharpRight:
        return 'Sharp right$onto';
      case NavManeuver.uturn:
        return 'Make a U-turn$onto';
      case NavManeuver.merge:
        return 'Merge$onto';
      case NavManeuver.onRamp:
        return 'Take the ramp$onto';
      case NavManeuver.offRamp:
        return 'Take the exit$onto';
      case NavManeuver.fork:
        return 'Keep to the fork$onto';
      case NavManeuver.roundabout:
        return exit == null
            ? 'Enter the roundabout$onto'
            : 'At the roundabout, take exit $exit$onto';
      case NavManeuver.exitRoundabout:
        return 'Exit the roundabout$onto';
      case NavManeuver.continueStraight:
        return 'Continue straight$onto';
      case NavManeuver.newName:
        return 'Continue$onto';
      case NavManeuver.arrive:
        return 'You have arrived';
      case NavManeuver.unknown:
        return roadName.isEmpty ? 'Continue' : 'Continue$onto';
    }
  }

  factory NavStep.fromOsrm(Map<String, dynamic> json) {
    final m = (json['maneuver'] as Map?) ?? const {};
    final loc = (m['location'] as List?) ?? const [0.0, 0.0];
    return NavStep(
      maneuver: NavManeuver.parse(m['type'] as String?, m['modifier'] as String?),
      roadName: (json['name'] as String?) ?? '',
      distanceM: ((json['distance'] as num?) ?? 0).toDouble(),
      durationS: ((json['duration'] as num?) ?? 0).toDouble(),
      location: LatLng((loc[1] as num).toDouble(), (loc[0] as num).toDouble()),
      exit: (m['exit'] as num?)?.toInt(),
    );
  }

  /// Builds a step from a Valhalla maneuver. Valhalla speaks numeric type
  /// codes, kilometers, and shape indices; they are folded onto the same
  /// OSRM-style type/modifier strings [NavManeuver.parse] already understands
  /// so banner text and voice coaching stay identical between engines.
  /// [shape] is the leg's decoded geometry (see [decodeValhallaShape6]).
  factory NavStep.fromValhalla(Map<String, dynamic> json, List<LatLng> shape) {
    final typeCode = ((json['type'] as num?) ?? 0).toInt();
    final rawIx = ((json['begin_shape_index'] as num?) ?? 0).toInt();
    final ix = shape.isEmpty ? 0 : rawIx.clamp(0, shape.length - 1);
    final names = json['street_names'] as List?;
    return NavStep(
      maneuver: NavManeuver.parse(
          _valhallaManeuverType(typeCode), _valhallaManeuverModifier(typeCode)),
      roadName: (names == null || names.isEmpty) ? '' : '${names.first}',
      distanceM: ((json['length'] as num?) ?? 0).toDouble() * 1000, // km → m
      durationS: ((json['time'] as num?) ?? 0).toDouble(),
      location: shape.isEmpty ? const LatLng(0, 0) : shape[ix],
      exit: (json['roundabout_exit_count'] as num?)?.toInt(),
    );
  }
}

/// Coarse OSRM-style category for a Valhalla numeric maneuver type (same
/// mapping the ML donor used, feeding [NavManeuver.parse]).
String _valhallaManeuverType(int t) {
  if (t == 1 || t == 2 || t == 3) return 'depart';
  if (t == 4 || t == 5 || t == 6) return 'arrive';
  if (t == 26 || t == 27) return 'roundabout';
  if (t == 9 || t == 10 || t == 11 || t == 12 || t == 18) return 'turn';
  if (t == 13 || t == 14 || t == 15 || t == 16 || t == 19) return 'turn';
  return 'continue';
}

/// Left/right modifier for a Valhalla numeric maneuver type, or null.
String? _valhallaManeuverModifier(int t) {
  if (t == 9 || t == 10 || t == 11 || t == 12 || t == 18) return 'right';
  if (t == 13 || t == 14 || t == 15 || t == 16 || t == 19) return 'left';
  return null;
}

class NavRoute {
  final List<LatLng> points;
  final double distanceM;
  final double durationS;
  final List<NavStep> steps;

  /// Raw precision-5 encoded geometry as returned by OSRM — published to
  /// `trip_nav_state` so watchers can draw the exact route the driver sees.
  final String? encoded;

  const NavRoute({
    required this.points,
    required this.distanceM,
    required this.durationS,
    required this.steps,
    this.encoded,
  });
}

/// ---------------------------------------------------------------------------
/// Polyline codec — ARITHMETIC ONLY. Do not reintroduce bitwise operators here.
///
/// On the web a Dart `int` is a JavaScript double, and Dart's bitwise operators
/// are specified to work on **unsigned 32-bit** values there. `~` is the one
/// that bites: on the VM `~5` is `-6`, and under dart2js it is `4294967290`.
/// The zig-zag step of every polyline decoder in the world is written
/// `~(result >> 1)`, so this file decoded every route into another universe the
/// moment it ran in a browser — measured 2026-08-16 against a live Valhalla
/// reply for an Iron Hills → Fourways haul:
///
/// | runtime | first point            | path length  |
/// |---------|------------------------|--------------|
/// | Dart VM | (-26.085138, 28.050087)| 10.0 km      |
/// | dart2js | (4268.882158, 28.05)   | 599 295.4 km |
///
/// What that cost, driven in the real app as the driver: no route line on the
/// map at all, `ETA/Time left/Distance/vs plan` all dead, a turn banner reading
/// "In 2194.2 km — At the roundabout, take exit 1" on a 10 km trip, and — worst,
/// because it leaves the device — `trip_nav_state.route_polyline` published as
/// 13 characters of junk (`sbpfmXab|iD??`) with `distance_left_m = 0`, which is
/// what every mine/buyer/transporter live map draws.
///
/// The existing VM-only test suite was green throughout. That is the trap
/// CLAUDE.md §10.5 describes, one layer down: a green test on the wrong runtime.
///
/// The fix is to stop using bitwise operators at all. `+`, `*`, `%` and `~/`
/// on integers are exact and identical on both runtimes up to 2^53, which is
/// nine orders of magnitude more headroom than a 1e6-scaled coordinate needs.
/// ---------------------------------------------------------------------------

/// Zig-zag decode: even → +n/2, odd → −(n+1)/2. The arithmetic twin of
/// `(n & 1) != 0 ? ~(n >> 1) : (n >> 1)`, minus the web trap.
int _zigZagDecode(int n) => n % 2 != 0 ? -((n + 1) ~/ 2) : n ~/ 2;

/// Zig-zag encode: the exact inverse of [_zigZagDecode].
int _zigZagEncode(int delta) => delta < 0 ? -delta * 2 - 1 : delta * 2;

/// Shared body of the two precision variants: [scale] is 1e5 (OSRM) or 1e6
/// (Valhalla).
List<LatLng> _decodePolyline(String encoded, double scale) {
  final points = <LatLng>[];
  var index = 0, lat = 0, lng = 0;
  while (index < encoded.length) {
    for (final isLng in const [false, true]) {
      // `multiplier` is 32^groupIndex — the arithmetic form of `1 << shift`,
      // which would wrap past 32 bits on the web for a long run of chunks.
      var multiplier = 1, result = 0, b = 0x20;
      while (b >= 0x20) {
        if (index >= encoded.length) break; // truncated input: stop, don't throw
        b = encoded.codeUnitAt(index++) - 63;
        result += (b % 32) * multiplier;
        multiplier *= 32;
      }
      final delta = _zigZagDecode(result);
      if (isLng) {
        lng += delta;
      } else {
        lat += delta;
      }
    }
    points.add(LatLng(lat / scale, lng / scale));
  }
  return points;
}

/// Decodes a precision-5 encoded polyline (OSRM default geometry encoding).
List<LatLng> decodePolyline5(String encoded) => _decodePolyline(encoded, 1e5);

/// Decodes a Valhalla-encoded shape. Valhalla uses the same polyline algorithm
/// but at **1e6 precision** — never feed its shapes to [decodePolyline5]
/// (or vice versa): the result would be off by a factor of 10.
List<LatLng> decodeValhallaShape6(String encoded) =>
    _decodePolyline(encoded, 1e6);

/// Encodes points as a precision-5 polyline (the exact inverse of
/// [decodePolyline5]). Used to re-encode Valhalla geometry so
/// `trip_nav_state.route_polyline` — and every watcher decoding it — stays
/// precision-5 regardless of which engine produced the route.
String encodePolyline5(List<LatLng> points) {
  final out = StringBuffer();
  var lastLat = 0, lastLng = 0;
  void write(int delta) {
    var v = _zigZagEncode(delta);
    // v is non-negative from here, so `% 32` and `~/ 32` are the plain
    // arithmetic equivalents of `& 0x1f` and `>> 5`, and `0x20 | x` for x < 32
    // is simply `0x20 + x`.
    while (v >= 0x20) {
      out.writeCharCode(0x20 + (v % 32) + 63);
      v = v ~/ 32;
    }
    out.writeCharCode(v + 63);
  }

  for (final p in points) {
    final lat = (p.latitude * 1e5).round();
    final lng = (p.longitude * 1e5).round();
    write(lat - lastLat);
    write(lng - lastLng);
    lastLat = lat;
    lastLng = lng;
  }
  return out.toString();
}
