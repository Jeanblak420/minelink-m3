import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'package:flutter_application_1/features/portal/widgets/map_fit.dart';

/// Regression tests for the "Unsupported operation: Infinity or NaN toInt"
/// crash on the truck-location / live maps.
///
/// flutter_map's CameraFit.coordinates derives its zoom by dividing the
/// viewport by the *span* of the coordinates. When every sample sits on the
/// same spot (a parked truck re-sending the same GPS fix, or a single sample)
/// that span is zero, the zoom becomes Infinity, and — unless a finite maxZoom
/// clamps it — that Infinity reaches tile rendering and crashes.
///
/// The old code only capped zoom when `points.length == 1`, so several
/// identical points slipped through. These tests pin the real invariant: the
/// cap must be a finite number for ANY degenerate cluster, whatever its size.
void main() {
  group('safeCoordinatesMaxZoom', () {
    test('is finite for a single point', () {
      final z = safeCoordinatesMaxZoom([const LatLng(-26.0333, 27.9986)]);
      expect(z, isNotNull);
      expect(z!.isFinite, isTrue);
    });

    test('is finite for several identical points (the reported crash)', () {
      // Three samples all at the exact same coordinate, as seen in the bug.
      final pts = List.filled(3, const LatLng(-26.0333, 27.9986));
      final z = safeCoordinatesMaxZoom(pts);
      expect(z, isNotNull);
      expect(z!.isFinite, isTrue);
      expect(z, lessThanOrEqualTo(18));
    });

    test('is finite for an empty list', () {
      final z = safeCoordinatesMaxZoom(const <LatLng>[]);
      expect(z, isNotNull);
      expect(z!.isFinite, isTrue);
    });

    test('still returns a finite cap for genuinely spread-out points', () {
      final pts = const [
        LatLng(-26.2041, 28.0473), // Johannesburg
        LatLng(-25.7479, 28.2293), // Pretoria
      ];
      final z = safeCoordinatesMaxZoom(pts);
      expect(z, isNotNull);
      expect(z!.isFinite, isTrue);
    });
  });
}
