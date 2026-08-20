// A `GeolocatorPlatform` that reports a truck standing on a road.
//
// `DriverNavigationScreen` is the only screen in this product a person looks at
// while moving, and until 2026-08-20 there was no picture of it. Its whole life
// is driven by four static `Geolocator` calls, every one of which needs a
// device: is the service on, do we have permission, where are we, and a stream
// of fixes. In a widget test each one throws `MissingPluginException`, the
// screen sets `_fatal` and renders "Navigation needs your location." — a real
// state, and not the one worth photographing.
//
// This is the plugin's OWN seam, not a hole cut in it: `geolocator` ships a
// federated platform interface exactly so the platform half can be replaced.
// Nothing in `lib/` changes to accommodate it.
//
// It deliberately reports a truck that is STATIONARY on the first fix. The
// screen glides the puck between fixes and rotates the camera with the heading,
// so a moving fake would make the render depend on when the frame happened to
// land — and a golden that cannot reproduce is not evidence.
import 'dart:async';

import 'package:geolocator_platform_interface/geolocator_platform_interface.dart';

class FakeGeolocatorPlatform extends GeolocatorPlatform {
  FakeGeolocatorPlatform({
    required this.latitude,
    required this.longitude,
    this.heading = 42,
    this.speedMps = 0,
  });

  final double latitude;
  final double longitude;
  final double heading;
  final double speedMps;

  /// Installs this as the platform implementation for the rest of the test.
  static FakeGeolocatorPlatform install({
    required double latitude,
    required double longitude,
    double heading = 42,
    double speedMps = 0,
  }) {
    final fake = FakeGeolocatorPlatform(
      latitude: latitude,
      longitude: longitude,
      heading: heading,
      speedMps: speedMps,
    );
    GeolocatorPlatform.instance = fake;
    return fake;
  }

  Position get _position => Position(
        latitude: latitude,
        longitude: longitude,
        // A FIXED instant. `DateTime.now()` here would put a different
        // timestamp in every regeneration, and the screen stamps its HUD from
        // the fix.
        timestamp: DateTime.utc(2026, 8, 15, 9, 30),
        accuracy: 5,
        altitude: 1480,
        altitudeAccuracy: 3,
        heading: heading,
        headingAccuracy: 5,
        speed: speedMps,
        speedAccuracy: 1,
      );

  @override
  Future<bool> isLocationServiceEnabled() async => true;

  @override
  Future<LocationPermission> checkPermission() async =>
      LocationPermission.whileInUse;

  @override
  Future<LocationPermission> requestPermission() async =>
      LocationPermission.whileInUse;

  @override
  Future<Position> getCurrentPosition({LocationSettings? locationSettings}) async =>
      _position;

  @override
  Future<Position?> getLastKnownPosition({
    bool forceLocationManager = false,
  }) async =>
      _position;

  /// One fix, then silence.
  ///
  /// A repeating stream would keep the smooth-motion controller running and the
  /// camera rotating forever, which `pumpAndSettle` cannot survive and a golden
  /// cannot pin down.
  @override
  Stream<Position> getPositionStream({LocationSettings? locationSettings}) =>
      Stream<Position>.value(_position);

  @override
  Future<bool> openAppSettings() async => true;

  @override
  Future<bool> openLocationSettings() async => true;
}
