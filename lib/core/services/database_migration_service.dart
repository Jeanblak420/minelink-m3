import 'package:flutter_application_1/core/config/supabase_config.dart';
import 'package:flutter_application_1/core/services/database_service.dart';
import 'package:flutter_application_1/core/utils/error_handler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_application_1/core/utils/logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Verifies that the live database has the server-managed capabilities the app
/// depends on before runtime features are used.
///
/// This is a preflight against a *misconfigured project*, so it may block
/// startup when the answer is a definite no. It must never block startup when
/// it simply could not ask — the login screen it would hide is the remedy for
/// most of those cases. `get_runtime_platform_status` is granted to
/// `authenticated` only (migration 20260810161500), so signed-out boots cannot
/// ask at all.
class DatabaseMigrationService {
  final DatabaseService _databaseService;
  final bool Function() _hasSession;
  final _logger = LoggerFactory.getLogger('DatabaseMigrationService');

  DatabaseMigrationService(this._databaseService, {bool Function()? hasSession})
    : _hasSession = hasSession ?? _sessionFromSupabase;

  static bool _sessionFromSupabase() =>
      SupabaseConfig.client.auth.currentSession != null;

  /// The ONE PostgREST code that is a **definite no** rather than a failure to
  /// ask: the function is not in the schema cache, i.e. the connected project
  /// genuinely does not have the RPC. Catching that is the entire reason this
  /// preflight exists, so it stays fatal.
  ///
  /// Everything else — including a schema-cache reload, an expired JWT, a
  /// dropped connection or no network at all — is "could not ask", and the
  /// class contract above says in as many words that startup must never block
  /// on those. Only `42501` was ever honoured, and the gap was not theoretical:
  ///
  /// · **`PGRST002`** — PostgREST rebuilds its schema cache after every DDL
  ///   statement, and any request landing inside that window gets it. So it
  ///   fires on *ordinary deploys*: a migration lands, and every user booting
  ///   in the next few seconds is stranded on the full-screen bootstrap error
  ///   with nothing but a Retry button. Reproduced live on 2026-08-16 by
  ///   applying a migration while the app was open — the whole app dropped to
  ///   the error screen reading "Could not query the database for the schema
  ///   cache. Retrying.", which is PostgREST saying it is already fixing
  ///   itself.
  /// · **`PGRST301`** — JWT expired or not yet valid. The remedy is the login
  ///   screen, which this error hides.
  /// · **`08006` / transport failures** — no route to the host, DNS down, TLS
  ///   refused, a timeout. This matters most for the users the product is
  ///   actually for: a driver opening the app on a haul road with no signal was
  ///   shown "There was a problem starting the application" instead of the
  ///   login screen, when a cached session would have got them into their trip.
  ///   An app that refuses to start because the network is down is worse than
  ///   one that starts and says it is offline.
  static const _projectIsMisconfigured = <String>{'PGRST202'};

  /// How long the preflight may take before it is treated as unanswered.
  ///
  /// Without this the app hangs on its splash **forever**. Observed live on
  /// 2026-08-16: `get_runtime_platform_status` sat `pending` for over a minute
  /// while the screen read "Starting MineLink…" with no error, no retry and no
  /// way out but closing the tab. A request that never returns is the one
  /// failure mode a `try`/`catch` cannot see, and a mobile network drops
  /// connections that way as a matter of course.
  ///
  /// Eight seconds is far longer than the call takes when the project is
  /// healthy, and far shorter than a user's patience with a blank screen. On
  /// expiry the answer is "could not ask", which per the contract above means
  /// carry on into the app — where every screen states its own errors rather
  /// than hiding behind one splash.
  static const _askTimeout = Duration(seconds: 8);

  Future<void> runMigrations() async {
    if (!_hasSession()) {
      _logger.i(
        'Skipping runtime database verification: no signed-in session. '
        'get_runtime_platform_status is granted to `authenticated` only, so '
        'this runs once the user signs in.',
      );
      return;
    }

    // The `try` wraps ONLY the asking. The readiness decision is taken after
    // it, deliberately: with `throw Exception(...)` inside the block, the
    // catch-all below swallowed the one failure this preflight exists to
    // report, and the project-is-misconfigured path silently became a no-op.
    final Map<String, dynamic> status;
    try {
      _logger.i('Verifying runtime database capabilities...');
      status = await _databaseService
          .getRuntimePlatformStatus()
          .timeout(_askTimeout);
    } on PostgrestException catch (e) {
      if (_projectIsMisconfigured.contains(e.code)) {
        _logger.e('Error verifying runtime database capabilities', e);
        throw ErrorHandler.handleSupabaseError(e);
      }
      _logger.e(
        'Could not verify runtime database capabilities (${e.code}). '
        'Continuing to the app.',
        e,
      );
      return;
    } catch (e) {
      _logger.e(
        'Could not reach the database to verify runtime capabilities. '
        'Continuing to the app.',
        e,
      );
      return;
    }

    final ready = status['ready'] == true;
    final missingCapabilities = List<String>.from(
      (status['missing_capabilities'] as List?) ?? const <String>[],
    );

    // We asked and the answer was no. This is the only fatal outcome.
    if (!ready) {
      throw Exception(
        'The connected Supabase project is missing required runtime '
        'capabilities: ${missingCapabilities.join(', ')}',
      );
    }

    _logger.i('Runtime database verification completed successfully.');
  }
}

/// Provider for the DatabaseMigrationService
final databaseMigrationServiceProvider = Provider<DatabaseMigrationService>((
  ref,
) {
  final databaseService = ref.watch(databaseServiceProvider);
  return DatabaseMigrationService(databaseService);
});
