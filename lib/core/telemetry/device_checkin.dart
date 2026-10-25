/// A daily "this install is here, and can write" for each signed-in device.
///
/// Added on Jean's go-ahead, 2026-10-24. Nothing had reached `crash_reports`
/// since 17 Oct and nothing could say whether that meant no crashes or no
/// way to report one. This calls `record_device_checkin` (migration
/// `20261024140000`) through the same authenticated path the crash sink
/// writes on, so the Crash reports page can list which devices are checking
/// in and which have gone quiet.
///
/// It runs when the app starts, when someone signs in, and when the app comes
/// back to the front — but sends at most once in [interval]. The server also
/// ignores a repeat inside the hour, so a fault here cannot become a stream of
/// writes on a 500 MB free-plan project.
///
/// Like the crash sink, it never throws: a check-in that fails is simply tried
/// again next time, and is not recorded as done.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'package:flutter_application_1/core/config/supabase_config.dart';

class DeviceCheckin {
  DeviceCheckin({
    required this.appVersion,
    String? platform,
    Future<SharedPreferences> Function()? prefs,
    DateTime Function()? clock,
    String? Function()? userId,
    Future<void> Function(Map<String, dynamic> params)? post,
  })  : platform = platform ?? _platform,
        _prefs = prefs ?? SharedPreferences.getInstance,
        _clock = clock ?? DateTime.now,
        _userId = userId ?? _currentUserId,
        _post = post ?? _defaultPost;

  /// Once a day, with room for an app that is opened at slightly different
  /// times each morning.
  static const interval = Duration(hours: 20);

  /// This install's id. Kept through sign-out — see
  /// `CacheService.clearAllCache` — because the table is one row per install.
  static const idKey = 'device_checkin.id';
  static const _lastKey = 'device_checkin.last';

  final String? appVersion;
  final String platform;
  final Future<SharedPreferences> Function() _prefs;
  final DateTime Function() _clock;
  final String? Function() _userId;
  final Future<void> Function(Map<String, dynamic> params) _post;

  Future<void>? _inFlight;
  StreamSubscription<Object?>? _authSub;
  AppLifecycleListener? _lifecycle;

  static String get _platform => kIsWeb ? 'web' : defaultTargetPlatform.name;

  static String? _currentUserId() {
    try {
      return SupabaseConfig.client.auth.currentUser?.id;
    } catch (_) {
      return null;
    }
  }

  static Future<void> _defaultPost(Map<String, dynamic> params) =>
      SupabaseConfig.client.rpc('record_device_checkin', params: params);

  /// Starts checking in: now, on every sign-in, and on every return to the
  /// app. Called once from `main()`.
  void start() {
    unawaited(checkInIfDue());
    try {
      _authSub = SupabaseConfig.client.auth.onAuthStateChange.listen((e) {
        if (e.session != null) unawaited(checkInIfDue());
      });
    } catch (_) {
      // No client yet — the start-up and resume calls still cover it.
    }
    _lifecycle = AppLifecycleListener(
      onResume: () => unawaited(checkInIfDue()),
    );
  }

  void dispose() {
    _authSub?.cancel();
    _lifecycle?.dispose();
  }

  /// Checks in if someone is signed in and [interval] has passed since the
  /// last check-in that got through. Never throws.
  Future<void> checkInIfDue() =>
      _inFlight ??= _checkIn().whenComplete(() => _inFlight = null);

  Future<void> _checkIn() async {
    try {
      if (_userId() == null) return;
      final prefs = await _prefs();
      final now = _clock();
      final last = DateTime.tryParse(prefs.getString(_lastKey) ?? '');
      if (last != null && now.difference(last) < interval) return;

      var id = prefs.getString(idKey);
      if (id == null || id.length < 8) {
        id = const Uuid().v4();
        await prefs.setString(idKey, id);
      }
      await _post({
        'p_device_id': id,
        'p_platform': platform,
        'p_app_version': appVersion,
      });
      await prefs.setString(_lastKey, now.toUtc().toIso8601String());
    } catch (e) {
      // The same deliberate silence as the crash sink: a check-in failure is
      // never itself reported, and the next call tries again.
      debugPrint('DeviceCheckin: not sent ($e)');
    }
  }
}
