import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import 'package:flutter_application_1/core/config/supabase_config.dart';
import 'package:flutter_application_1/core/utils/logger.dart';
import 'package:flutter_application_1/features/portal/services/live_tracking_service.dart';
import 'package:flutter_application_1/core/utils/friendly_error.dart';

enum TripReportingStatus { off, starting, active, error }

/// Driver-side live-location reporter (§4 Live GPS tracking): while the
/// driver's truck has an active trip, sends a ping every [pingInterval]
/// through `record_vehicle_position`.
///
/// The geolocator stream keeps positions fresh — and on Android runs the
/// foreground service that keeps pings flowing while the app is backgrounded
/// (iOS rides UIBackgroundModes=location) — while a fixed timer guarantees the
/// 30-second cadence even when the truck is stationary. The reporter stops
/// itself when the RPC says there is no longer an active trip (or no truck),
/// so trackers never outlive the trip.
class TripPositionReporter extends ChangeNotifier {
  TripPositionReporter(this._service);

  static const pingInterval = Duration(seconds: 30);

  final LiveTrackingService _service;
  final _log = LoggerFactory.getLogger('TripPositionReporter');

  TripReportingStatus _status = TripReportingStatus.off;
  String? _message;
  DateTime? _lastPingAt;
  Position? _latest;
  StreamSubscription<Position>? _sub;
  Timer? _timer;
  bool _sending = false;

  TripReportingStatus get status => _status;
  String? get message => _message;
  DateTime? get lastPingAt => _lastPingAt;
  bool get isActive => _status == TripReportingStatus.active;
  bool get isBusy =>
      _status == TripReportingStatus.starting ||
      _status == TripReportingStatus.active;

  Future<void> start() async {
    if (isBusy) return;
    _set(TripReportingStatus.starting, 'Requesting location permission…');
    try {
      if (!kIsWeb && !await Geolocator.isLocationServiceEnabled()) {
        _set(TripReportingStatus.error,
            'Turn on location services (GPS) on this device first.');
        return;
      }
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        _set(
          TripReportingStatus.error,
          'Location permission denied — allow location for MineLink in your '
          'device settings, then try again.',
        );
        return;
      }
      _sub = Geolocator.getPositionStream(locationSettings: _settings())
          .listen((p) => _latest = p, onError: (Object e) {
        _log.w('position stream error: $e');
      });
      _timer = Timer.periodic(pingInterval, (_) => _send());
      _set(TripReportingStatus.active, 'Waiting for the first GPS fix…');
      await _send();
    } catch (e) {
      _log.e('could not start live tracking', e);
      await _teardown();
      _set(TripReportingStatus.error, 'Could not start GPS tracking. ${friendlyError(e)}');
    }
  }

  Future<void> stop({String? message}) async {
    await _teardown();
    _set(TripReportingStatus.off, message);
  }

  LocationSettings _settings() {
    if (!kIsWeb && Platform.isAndroid) {
      return AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 0,
        intervalDuration: pingInterval,
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: 'MineLink live tracking',
          notificationText:
              'Sharing your truck position for the active trip.',
          enableWakeLock: true,
        ),
      );
    }
    if (!kIsWeb && (Platform.isIOS || Platform.isMacOS)) {
      return AppleSettings(
        accuracy: LocationAccuracy.high,
        activityType: ActivityType.automotiveNavigation,
        distanceFilter: 0,
        pauseLocationUpdatesAutomatically: false,
        showBackgroundLocationIndicator: true,
      );
    }
    return const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 0,
    );
  }

  Future<void> _send() async {
    if (_sending || _status != TripReportingStatus.active) return;
    // Stop cleanly on sign-out — otherwise the ping RPC just fails forever.
    if (SupabaseConfig.client.auth.currentUser == null) {
      await stop(message: 'Signed out — live tracking stopped.');
      return;
    }
    _sending = true;
    try {
      final p = _latest ?? await Geolocator.getCurrentPosition();
      final res = await _service.recordPosition(
        lat: p.latitude,
        lng: p.longitude,
        heading: p.heading.isFinite && p.heading >= 0 ? p.heading : null,
        speedKmh: p.speed.isFinite && p.speed >= 0 ? p.speed * 3.6 : null,
        accuracyM: p.accuracy.isFinite ? p.accuracy : null,
      );
      if (res['recorded'] == true) {
        _lastPingAt = DateTime.now();
        _set(TripReportingStatus.active, null);
      } else if (res['reason'] == 'no_active_trip') {
        await stop(message: 'No active trip — live tracking stopped.');
      } else if (res['reason'] == 'no_vehicle') {
        await stop(message: 'No truck is assigned to you — tracking stopped.');
      }
    } catch (e) {
      // Transient failure (network drop, cold GPS): keep the reporter alive
      // and let the next tick retry.
      _log.w('position ping failed: $e');
    } finally {
      _sending = false;
    }
  }

  Future<void> _teardown() async {
    _timer?.cancel();
    _timer = null;
    await _sub?.cancel();
    _sub = null;
    _latest = null;
  }

  void _set(TripReportingStatus status, String? message) {
    _status = status;
    _message = message;
    notifyListeners();
  }

  @override
  void dispose() {
    _teardown();
    super.dispose();
  }
}
