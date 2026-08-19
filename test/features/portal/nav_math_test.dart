import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'package:flutter_application_1/features/portal/models/nav_route.dart';
import 'package:flutter_application_1/features/portal/utils/nav_math.dart';

void main() {
  const route = [LatLng(0, 0), LatLng(0, 0.01), LatLng(0.01, 0.01)];

  test('projectOnRoute snaps onto the first segment and measures progress', () {
    final r = projectOnRoute(route, const LatLng(0.0001, 0.005)); // ~11m north
    expect(r.segIndex, 0);
    expect(r.offRouteM, closeTo(11.1, 2.0));
    expect(r.traveledM, closeTo(556.0, 15.0)); // half of ~1113m
    expect(r.snapped.latitude, closeTo(0, 1e-6));
  });

  test('projectOnRoute clamps to vertices at the ends', () {
    final before = projectOnRoute(route, const LatLng(0, -0.01));
    expect(before.traveledM, closeTo(0, 1.0));
    final after = projectOnRoute(route, const LatLng(0.02, 0.01));
    expect(after.traveledM, closeTo(2226.0, 30.0)); // full length
  });

  test('stepStartOffsets + currentStepIndex advance as the truck travels', () {
    const steps = [
      NavStep(
          maneuver: NavManeuver.depart,
          roadName: 'A',
          distanceM: 1113,
          durationS: 60,
          location: LatLng(0, 0)),
      NavStep(
          maneuver: NavManeuver.turnLeft,
          roadName: 'B',
          distanceM: 1113,
          durationS: 60,
          location: LatLng(0, 0.01)),
      NavStep(
          maneuver: NavManeuver.arrive,
          roadName: '',
          distanceM: 0,
          durationS: 0,
          location: LatLng(0.01, 0.01)),
    ];
    final offsets = stepStartOffsets(route, steps);
    expect(offsets.length, 3);
    expect(offsets[0], closeTo(0, 1.0));
    expect(offsets[1], closeTo(1113, 20.0));
    // Mid first segment → approaching the turn (step 1).
    expect(currentStepIndex(offsets, 556), 1);
    // Past the turn → approaching arrival (step 2).
    expect(currentStepIndex(offsets, 1200), 2);
    // Past everything → clamps to last step.
    expect(currentStepIndex(offsets, 99999), 2);
  });

  test('off-route / arrival thresholds and remaining meters', () {
    expect(isOffRoute(49), isFalse);
    expect(isOffRoute(51), isTrue);
    expect(hasArrived(const LatLng(0, 0), const LatLng(0, 0.001)), isTrue); // ~111m
    expect(hasArrived(const LatLng(0, 0), const LatLng(0, 0.002)), isFalse); // ~222m
    expect(remainingMeters(1000, 400), 600);
    expect(remainingMeters(1000, 1400), 0);
  });
}
