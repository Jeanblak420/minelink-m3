import 'package:latlong2/latlong.dart';

import 'package:flutter_application_1/features/portal/models/nav_route.dart';

const _d = Distance();

/// Nearest point on [route] to [pos]: segment index, snapped point,
/// perpendicular distance (m) and cumulative distance from the route start
/// to the snapped point (m). Equirectangular projection per segment — fine
/// at truck-route scale.
({int segIndex, LatLng snapped, double offRouteM, double traveledM})
    projectOnRoute(List<LatLng> route, LatLng pos) {
  assert(route.length >= 2);
  var bestSeg = 0;
  var bestSnap = route.first;
  var bestDist = double.infinity;
  var bestTraveled = 0.0;
  var cumul = 0.0;
  for (var i = 0; i < route.length - 1; i++) {
    final a = route[i], b = route[i + 1];
    final t = _projT(a, b, pos);
    final snap = LatLng(
      a.latitude + (b.latitude - a.latitude) * t,
      a.longitude + (b.longitude - a.longitude) * t,
    );
    final dist = _d.as(LengthUnit.Meter, pos, snap);
    if (dist < bestDist) {
      bestDist = dist;
      bestSeg = i;
      bestSnap = snap;
      bestTraveled = cumul + _d.as(LengthUnit.Meter, a, snap);
    }
    cumul += _d.as(LengthUnit.Meter, a, b);
  }
  return (
    segIndex: bestSeg,
    snapped: bestSnap,
    offRouteM: bestDist,
    traveledM: bestTraveled
  );
}

double _projT(LatLng a, LatLng b, LatLng p) {
  final ax = a.longitude, ay = a.latitude;
  final dx = b.longitude - ax, dy = b.latitude - ay;
  final len2 = dx * dx + dy * dy;
  if (len2 == 0) return 0;
  final t = ((p.longitude - ax) * dx + (p.latitude - ay) * dy) / len2;
  return t.clamp(0.0, 1.0);
}

/// Metres-from-route-start of each step's maneuver point (monotone,
/// clamped). Precompute once per fetched route.
List<double> stepStartOffsets(List<LatLng> route, List<NavStep> steps) {
  final out = <double>[];
  var last = 0.0;
  for (final s in steps) {
    final p = projectOnRoute(route, s.location);
    last = p.traveledM < last ? last : p.traveledM;
    out.add(last);
  }
  return out;
}

/// The step whose maneuver the driver is approaching: the first step whose
/// start offset is still ahead of [traveledM] (with 25m of slack so the
/// banner flips right as the truck passes the maneuver).
int currentStepIndex(List<double> stepStartM, double traveledM) {
  for (var i = 0; i < stepStartM.length; i++) {
    if (stepStartM[i] > traveledM + 25) return i;
  }
  return stepStartM.isEmpty ? 0 : stepStartM.length - 1;
}

double remainingMeters(double totalM, double traveledM) =>
    (totalM - traveledM).clamp(0.0, double.infinity);

bool isOffRoute(double offRouteM) => offRouteM > 50;

bool hasArrived(LatLng pos, LatLng dest) =>
    _d.as(LengthUnit.Meter, pos, dest) < 150;
