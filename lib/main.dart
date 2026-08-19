import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_application_1/app.dart';
import 'package:flutter_application_1/core/config/place_index_config.dart';
import 'package:flutter_application_1/core/config/supabase_config.dart';
import 'package:flutter_application_1/core/push/push_service.dart';
import 'package:flutter_application_1/core/routing/initial_location.dart';
import 'package:flutter_application_1/core/telemetry/crash_reporter.dart';
import 'package:flutter_application_1/core/telemetry/error_screen_widget.dart';
import 'package:flutter_application_1/core/telemetry/supabase_reporting_sink.dart';
import 'package:flutter_application_1/core/mcp/repositories/company_repository.dart';
import 'package:flutter_application_1/core/mcp/repositories/employee_repository.dart';
import 'package:flutter_application_1/core/services/database_migration_service.dart';
import 'package:flutter_application_1/core/services/database_service.dart';
import 'package:flutter_application_1/core/constants/app_branding.dart';
import 'package:flutter_application_1/core/theme/app_theme.dart';
import 'package:flutter_application_1/core/utils/logger.dart';
import 'package:flutter_application_1/core/widgets/minelink_logo.dart';
import 'package:flutter_application_1/core/design/tokens/ml_tokens.dart';

final _logger = LoggerFactory.getLogger('Main');

// Global providers for repositories
final companyRepositoryProvider = Provider<CompanyRepository>((ref) {
  return CompanyRepository();
});

final employeeRepositoryProvider = Provider<EmployeeRepository>((ref) {
  return EmployeeRepository();
});

void main() async {
  // First, so that anything below is itself covered. The app had NO global
  // error handling at all — no `FlutterError.onError`, no
  // `PlatformDispatcher.onError`, no `runZonedGuarded`, no
  // `ErrorWidget.builder` — so in release an uncaught async error vanished into
  // a console nobody was attached to, and a widget that threw showed the user
  // Flutter's grey box. The first anyone heard of a failure was the client
  // phoning, with nothing to look at when they did (S9-1).
  //
  // Which telemetry VENDOR to send these to is the client's call and is
  // untouched here: `crashReporter.useSink(...)` is the one line that changes.
  installCrashHandlers(errorWidgetBuilder: mlErrorWidgetBuilder);

  runGuarded(() {
    WidgetsFlutterBinding.ensureInitialized();
    // BEFORE runApp, and that is the whole point. `_BootstrapApp` mounts a
    // plain MaterialApp while Supabase initialises, which is enough for Flutter
    // to normalise the address bar back to the origin — so by the time
    // `MaterialApp.router` exists, the route the user actually opened is gone.
    // Measured: `/#/portal/mine/tons-out` here, bare `/` at router
    // construction.
    captureInitialLocation(Uri.base);
    runApp(const _BootstrapApp());
  });
}

Future<void> _initializeApplication() async {
  try {
    await SupabaseConfig.initialize();
    // Swap the boot-time sink now that there is a database to talk to.
    //
    // installCrashHandlers() ran first, on the in-memory LoggingReportingSink,
    // and that ordering is deliberate: telemetry that needs Supabase to be up
    // cannot be the thing that catches Supabase failing to come up. The
    // in-memory history is swapped, not lost — the reports that arrived during
    // bootstrap were already logged.
    //
    // app_version is a nice-to-have tag on a crash row, not boot-critical —
    // same precedent as PlaceIndexConfig.initialize() three lines below:
    // swallow, degrade, never fail (or hang) the boot over it.
    String? appVersion;
    try {
      appVersion = (await PackageInfo.fromPlatform()).version;
    } catch (e) {
      _logger.w(
        'PackageInfo.fromPlatform() failed; crash reports will omit app_version: $e',
      );
    }
    crashReporter.useSink(SupabaseReportingSink(appVersion: appVersion));
    // Push notifications. See PushService's doc comment: there is no
    // Firebase project yet, so this lands in an unavailable state and the
    // app behaves exactly as it did before push existed — never allowed to
    // fail the boot, same contract as PlaceIndexConfig.initialize() below.
    await pushService.initialise(appVersion: appVersion);
    _wirePushRegistration();
    // The SECOND Supabase project (Mine-Link_Extra_Data) — reference data only,
    // currently the Overture place index behind the location picker. Resolved
    // here so the first search does not pay for it.
    //
    // Deliberately NOT allowed to fail the boot: it swallows its own errors and
    // leaves PlaceIndexConfig.client null, which makes address search fall
    // through to Nominatim exactly as it did before that table existed. A
    // reference lookup being unavailable must never cost the whole app — and it
    // is on the free plan, so it can pause after ~7 quiet days.
    await PlaceIndexConfig.initialize();
    await DatabaseMigrationService(DatabaseService()).runMigrations();
    if (SupabaseConfig.client.auth.currentSession == null) {
      _verifyRuntimeAfterSignIn();
    }
  } catch (e) {
    _logger.e('Fatal error during app initialization: $e');
    rethrow;
  }
}

StreamSubscription<AuthState>? _runtimeVerificationSubscription;

/// The runtime capability check needs a session, so a signed-out boot skips it.
/// Run it once as soon as somebody signs in, otherwise the check silently never
/// happens for the sessions that start from the login screen.
///
/// Log-only by design: a user who has just signed in is not thrown back to the
/// bootstrap error screen.
void _verifyRuntimeAfterSignIn() {
  _runtimeVerificationSubscription?.cancel();
  _runtimeVerificationSubscription = SupabaseConfig.client.auth.onAuthStateChange
      .listen((state) async {
        if (state.event != AuthChangeEvent.signedIn) return;
        await _runtimeVerificationSubscription?.cancel();
        _runtimeVerificationSubscription = null;
        try {
          await DatabaseMigrationService(DatabaseService()).runMigrations();
        } catch (e) {
          _logger.e('Runtime database verification failed after sign-in: $e');
        }
      });
}

StreamSubscription<AuthState>? _pushAuthSubscription;

/// Registers/unregisters this device's push token with `sign-in`/`sign-out`,
/// via the same `onAuthStateChange` stream `_verifyRuntimeAfterSignIn` uses.
///
/// Runs for the whole app lifetime (unlike `_verifyRuntimeAfterSignIn`, which
/// cancels itself after firing once) — sign-out can happen any number of
/// times in one app session, and each one must unregister the token before
/// the next sign-in re-registers it.
///
/// Both `registerCurrentDevice()`/`unregisterCurrentDevice()` are no-ops when
/// `PushService.isAvailable` is false (no Firebase project), so this is safe
/// to wire unconditionally.
void _wirePushRegistration() {
  final currentSession = SupabaseConfig.client.auth.currentSession;
  if (currentSession != null) {
    // Already signed in when push initialised (e.g. a restored session) —
    // onAuthStateChange only fires on a *change*, so this boot's sign-in
    // would otherwise never register a token.
    unawaited(pushService.registerCurrentDevice());
  }

  _pushAuthSubscription?.cancel();
  _pushAuthSubscription = SupabaseConfig.client.auth.onAuthStateChange.listen((
    state,
  ) {
    switch (state.event) {
      case AuthChangeEvent.signedIn:
        unawaited(pushService.registerCurrentDevice());
      case AuthChangeEvent.signedOut:
        unawaited(pushService.unregisterCurrentDevice());
      default:
        break;
    }
  });
}

class _BootstrapApp extends StatefulWidget {
  const _BootstrapApp();

  @override
  State<_BootstrapApp> createState() => _BootstrapAppState();
}

class _BootstrapAppState extends State<_BootstrapApp> {
  late Future<void> _initializationFuture;

  @override
  void initState() {
    super.initState();
    _initializationFuture = _initializeApplication();
  }

  void _retryInitialization() {
    setState(() {
      _initializationFuture = _initializeApplication();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _initializationFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return _BootstrapShell(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  MineLinkLogo(height: 128),
                  SizedBox(height: 28),
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Starting ${AppBranding.appName}...'),
                ],
              ),
            ),
          );
        }

        if (snapshot.hasError) {
          return _BootstrapShell(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const MineLinkLogo(height: 96),
                      const SizedBox(height: 20),
                      const Icon(
                        Icons.error_outline,
                        color: MlTokens.red600,
                        size: 48,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'There was a problem starting the application. Please check your configuration and internet connection, then try again.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        snapshot.error.toString(),
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: _retryInitialization,
                          child: const Text('Retry'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }

        return const ProviderScope(child: App());
      },
    );
  }
}

class _BootstrapShell extends StatelessWidget {
  final Widget child;

  const _BootstrapShell({required this.child});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppBranding.appName,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.dark,
      debugShowCheckedModeBanner: false,
      home: Scaffold(body: child),
    );
  }
}
