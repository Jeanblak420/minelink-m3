import 'dart:async';
import 'dart:io';

import 'package:flutter_application_1/core/services/database_migration_service.dart';
import 'package:flutter_application_1/core/services/database_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../test_helpers/test_supabase.dart';

/// Stands in for the real RPC so these tests exercise the bootstrap policy,
/// not the network.
class _FakeDatabaseService extends DatabaseService {
  _FakeDatabaseService({this.status, this.error, this.hang = false});

  final Map<String, dynamic>? status;
  final Object? error;

  /// Never completes — a request that hangs rather than failing.
  final bool hang;
  int calls = 0;

  @override
  Future<Map<String, dynamic>> getRuntimePlatformStatus() async {
    calls++;
    if (hang) return Completer<Map<String, dynamic>>().future;
    final failure = error;
    if (failure != null) throw failure;
    return status!;
  }
}

Map<String, dynamic> _ready() => <String, dynamic>{
  'ready': true,
  'missing_capabilities': <String>[],
};

/// `get_runtime_platform_status` is granted to `authenticated` only
/// (migration 20260810161500), so an anon caller gets exactly this.
PostgrestException _permissionDenied() => PostgrestException(
  message: 'permission denied for function get_runtime_platform_status',
  code: '42501',
);

void main() {
  setUpAll(ensureTestSupabaseInitialized);

  group('DatabaseMigrationService.runMigrations', () {
    test('does not run, or block startup, when nobody is signed in', () async {
      final db = _FakeDatabaseService(error: _permissionDenied());

      await expectLater(
        DatabaseMigrationService(db, hasSession: () => false).runMigrations(),
        completes,
      );
      expect(
        db.calls,
        0,
        reason: 'the check needs a session; it should not be attempted as anon',
      );
    });

    test(
      'does not block startup when the caller may not run the check',
      () async {
        // Stale/expired persisted session, or a project where the grant is
        // missing. Blocking here would strand the user on the bootstrap error
        // screen with no route to the login screen that would fix it.
        final db = _FakeDatabaseService(error: _permissionDenied());

        await expectLater(
          DatabaseMigrationService(db, hasSession: () => true).runMigrations(),
          completes,
        );
        expect(db.calls, 1);
      },
    );

    test('still fails when the project is missing capabilities', () async {
      final db = _FakeDatabaseService(
        status: <String, dynamic>{
          'ready': false,
          'missing_capabilities': <String>['realtime:profiles'],
        },
      );

      await expectLater(
        DatabaseMigrationService(db, hasSession: () => true).runMigrations(),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('realtime:profiles'),
          ),
        ),
      );
    });

    test('still fails when the project does not have the RPC at all', () async {
      // PGRST202 is the one code that is a definite no rather than a failure to
      // ask: the function is absent from the connected project. Detecting that
      // is what this preflight is for, so it must stay fatal.
      final db = _FakeDatabaseService(
        error: PostgrestException(
          message:
              'Could not find the function public.get_runtime_platform_status '
              'in the schema cache',
          code: 'PGRST202',
        ),
      );

      await expectLater(
        DatabaseMigrationService(db, hasSession: () => true).runMigrations(),
        throwsA(isA<Exception>()),
      );
    });

    // --- "could not ask" must never block startup ---------------------------
    //
    // The class contract said this all along and honoured it for 42501 only.
    // Each case below stranded every affected user on the full-screen bootstrap
    // error with nothing but a Retry button.
    for (final c in <({String name, Object error})>[
      (
        // Reproduced live 2026-08-16: applying a migration while the app was
        // open dropped it to the error screen. PostgREST rebuilds its schema
        // cache after every DDL statement, so this fires on ordinary deploys.
        name: 'PostgREST is reloading its schema cache after a deploy',
        error: PostgrestException(
          message: 'Could not query the database for the schema cache. Retrying.',
          code: 'PGRST002',
        ),
      ),
      (
        // The remedy is the login screen, which the error screen hides.
        name: 'the persisted JWT has expired',
        error: PostgrestException(message: 'JWT expired', code: 'PGRST301'),
      ),
      (
        name: 'the database connection dropped',
        error: PostgrestException(message: 'connection error', code: '08006'),
      ),
      (
        // A driver on a haul road with no signal. A cached session would have
        // got them into their trip; instead the app refused to start.
        name: 'there is no network at all',
        error: const SocketException('Failed host lookup'),
      ),
    ]) {
      test('does not block startup when ${c.name}', () async {
        final db = _FakeDatabaseService(error: c.error);

        await expectLater(
          DatabaseMigrationService(db, hasSession: () => true).runMigrations(),
          completes,
        );
        expect(db.calls, 1);
      });
    }

    test('does not hang forever when the request never returns', () async {
      // The failure a try/catch cannot see. Observed live on 2026-08-16:
      // `get_runtime_platform_status` sat pending for over a minute while the
      // splash read "Starting MineLink…" with no error and no way out.
      final db = _FakeDatabaseService(hang: true);

      await expectLater(
        DatabaseMigrationService(db, hasSession: () => true)
            .runMigrations()
            // Generous next to the 8s timeout under test, tight enough that a
            // regression fails the suite rather than stalling it.
            .timeout(const Duration(seconds: 20)),
        completes,
      );
      expect(db.calls, 1);
    }, timeout: const Timeout(Duration(seconds: 30)));

    test('passes a healthy project', () async {
      final db = _FakeDatabaseService(status: _ready());

      await expectLater(
        DatabaseMigrationService(db, hasSession: () => true).runMigrations(),
        completes,
      );
      expect(db.calls, 1);
    });
  });
}
