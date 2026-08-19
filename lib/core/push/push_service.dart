import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'package:flutter_application_1/core/push/device_token_repository.dart';
import 'package:flutter_application_1/core/routing/app_router.dart';
import 'package:flutter_application_1/core/utils/logger.dart';

/// Background message entry point, per the `firebase_messaging` contract:
/// **top-level (or static) function only**, annotated `@pragma('vm:entry-point')`
/// so the tree-shaker/AOT compiler keeps it — the plugin invokes it by name in
/// a separate background isolate that has not run any of this app's `main()`.
///
/// That isolate has not called [Firebase.initializeApp] either, so this does
/// it again for itself. Wrapped in try/catch for the same reason
/// [PushService.initialise] is: on a machine/CI with no Firebase project this
/// throws, and a background isolate crashing on every silent push would be
/// far worse than the missing feature it is standing in for.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
  } catch (_) {
    // No Firebase project configured — see PushService's doc comment. There
    // is nothing to do with a background message that could not have
    // arrived without a configured project anyway.
  }
}

/// Push notifications, and the fact that they are allowed to be absent.
///
/// There is no Firebase project yet. `google-services.json` and
/// `GoogleService-Info.plist` are gitignored and not in this repo, so on every
/// machine and in CI this service initialises into an unavailable state and
/// the app behaves exactly as it did before push existed.
///
/// That is the same contract `PlaceIndexConfig` has for the extras project: a
/// capability that can be missing must degrade, not throw. See docs/push-setup.md
/// for the artifacts that turn it on.
///
/// ## Testability
///
/// [isConfigured], [register] and [unregister] are injectable seams so the
/// degradation path — the property that matters most — is provable in
/// `flutter test` without ever touching the real Firebase plugin channels
/// (which are not mocked there and would throw `MissingPluginException`,
/// which is a *different* failure from "no Firebase project" and would prove
/// nothing about it).
class PushService {
  PushService({
    bool Function()? isConfigured,
    DeviceTokenRepository? repository,
    Future<void> Function(String token, String platform, String? appVersion)?
    register,
    Future<void> Function(String token)? unregister,
  }) : _isConfigured = isConfigured ?? (() => true),
       _repository = repository ?? DeviceTokenRepository(),
       _register = register,
       _unregister = unregister;

  static final _logger = LoggerFactory.getLogger('Push');

  final bool Function() _isConfigured;
  final DeviceTokenRepository _repository;
  final Future<void> Function(String token, String platform, String? appVersion)?
  _register;
  final Future<void> Function(String token)? _unregister;

  bool _available = false;

  /// True once Firebase has genuinely initialised on this device. False on a
  /// machine/CI with no Firebase project, or before [initialise] runs.
  bool get isAvailable => _available;

  String? _currentToken;
  String? _appVersion;

  StreamSubscription<String>? _tokenRefreshSub;
  StreamSubscription<RemoteMessage>? _foregroundSub;
  StreamSubscription<RemoteMessage>? _openedAppSub;

  /// Sets up push, or lands cleanly in an unavailable state. Never throws —
  /// every failure path (no config, no Firebase project, a plugin exception)
  /// is caught here and turns into `isAvailable == false`, exactly the state
  /// this repo is in today on every machine.
  Future<void> initialise({String? appVersion}) async {
    _appVersion = appVersion;

    if (!_isConfigured()) {
      _logger.i(
        'Push not configured (no Firebase project) — notifications will '
        'stay in-app only, same as before this feature existed.',
      );
      _available = false;
      return;
    }

    try {
      // Guarded rather than called unconditionally: `_BootstrapApp` retries
      // the whole boot on failure (main.dart's "Retry" button), and
      // `Firebase.initializeApp()` a second time for the same default app
      // throws `[core/duplicate-app]` — which would otherwise turn a retry
      // into a false "push unavailable" even when the first attempt already
      // succeeded.
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }

      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      final settings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        // iOS: ask provisionally (silent, no prompt) rather than demanding
        // the loud pre-permission dialog on first launch; the OS still lets
        // the user upgrade from Settings once a real notification lands.
        provisional: true,
      );
      _logger.i(
        'Notification permission: ${settings.authorizationStatus}',
      );

      _tokenRefreshSub = FirebaseMessaging.instance.onTokenRefresh.listen((
        token,
      ) {
        _currentToken = token;
        unawaited(_pushToken(token));
      });

      _foregroundSub = FirebaseMessaging.onMessage.listen((message) {
        _logger.i('Foreground push received: ${message.messageId}');
      });

      _openedAppSub = FirebaseMessaging.onMessageOpenedApp.listen(_handleTap);

      final initialMessage = await FirebaseMessaging.instance
          .getInitialMessage();
      if (initialMessage != null) {
        _handleTap(initialMessage);
      }

      _available = true;
    } catch (e, st) {
      _logger.w('Firebase initialisation failed; push unavailable: $e');
      _logger.d('$st');
      _available = false;
    }
  }

  /// Fetches this device's FCM token and registers it. A no-op when
  /// [isAvailable] is false — there is no token to fetch and nothing to call.
  Future<void> registerCurrentDevice() async {
    if (!_available) return;
    try {
      final token =
          _currentToken ?? await FirebaseMessaging.instance.getToken();
      if (token == null) {
        _logger.w('No FCM token available to register.');
        return;
      }
      _currentToken = token;
      await _pushToken(token);
    } catch (e) {
      _logger.w('registerCurrentDevice failed: $e');
    }
  }

  /// Deletes this device's token server-side, e.g. on sign-out. A no-op when
  /// [isAvailable] is false or no token has been seen yet.
  Future<void> unregisterCurrentDevice() async {
    if (!_available) return;
    final token = _currentToken;
    if (token == null) return;
    try {
      if (_unregister != null) {
        await _unregister(token);
      } else {
        await _repository.unregister(token);
      }
    } catch (e) {
      _logger.w('unregisterCurrentDevice failed: $e');
    }
  }

  Future<void> _pushToken(String token) async {
    final platform = _platformString();
    if (platform == null) {
      // Desktop/other — `device_tokens.platform` CHECKs
      // ('android','ios','web') only, so there is nowhere to send this.
      return;
    }
    try {
      if (_register != null) {
        await _register(token, platform, _appVersion);
      } else {
        await _repository.register(token, platform, _appVersion);
      }
    } catch (e) {
      _logger.w('Device token registration failed: $e');
    }
  }

  /// Deep-link handling for a tapped notification. `push-fanout` (the edge
  /// function) carries `data.route` / `data.nav_tab`, reusing the exact
  /// `metadata.nav_tab` / `metadata.route` convention the in-app notification
  /// list already reads (`notification_screen.dart`) — see
  /// `supabase/functions/push-fanout/index.ts`.
  ///
  /// `route` is routed through [AppRouter.router] directly, which needs no
  /// `BuildContext`. `nav_tab` (a named portal tab, e.g. "My routes") is only
  /// resolvable against the signed-in user's live `portalWorkspaceProvider`
  /// tab list, which needs a Riverpod `ProviderContainer` this service does
  /// not have — there is no app-wide container in this codebase (see
  /// `notification_screen.dart`, which does this from inside a widget via
  /// `ref`). So a `nav_tab`-only push opens the portal home rather than the
  /// exact tab; still strictly better than doing nothing with the tap.
  void _handleTap(RemoteMessage message) {
    final route = message.data['route'];
    if (route != null && route.startsWith('/')) {
      AppRouter.router.go(route);
      return;
    }
    final navTab = message.data['nav_tab'];
    if (navTab != null) {
      _logger.i(
        'Push tap named tab "$navTab"; opening /home (exact-tab focus needs '
        'a BuildContext this service does not have).',
      );
      AppRouter.router.go('/home');
    }
  }

  String? _platformString() {
    if (kIsWeb) return 'web';
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.iOS:
        return 'ios';
      default:
        return null;
    }
  }

  /// Cancels the live subscriptions. Not called anywhere yet — push runs for
  /// the app's whole lifetime today — but present so a future caller (e.g. a
  /// test harness, or a future "sign out fully tears down push" path) has
  /// somewhere to put that without inventing it fresh.
  Future<void> dispose() async {
    await _tokenRefreshSub?.cancel();
    await _foregroundSub?.cancel();
    await _openedAppSub?.cancel();
    _tokenRefreshSub = null;
    _foregroundSub = null;
    _openedAppSub = null;
  }
}

/// App-wide singleton, mirroring the plain-singleton shape `crashReporter`
/// already uses in `core/telemetry/crash_reporter.dart` — this app has no
/// global `ProviderContainer` to hang a Riverpod provider off outside the
/// widget tree, and `main()` needs to reach this before `ProviderScope` exists.
final pushService = PushService();
