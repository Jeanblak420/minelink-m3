// An employee's managed-company context survives an auth re-sync.
//
// `CompanyNotifier` listens to every `AuthState` emission. For an employee —
// an admin or manager whose company context the portal shell loads through
// `loadManagedCompanyContext` — that listener used to `clearContext()` on
// EVERY emission, and `AuthState` re-emits whenever the user's own `profiles`
// row changes, which the chat presence heartbeat does every 45 s. So every
// 45 s an admin's company context went to null, `portalWorkspaceProvider`
// left `ready`, and the whole portal body was torn down and rebuilt: the
// dashboard re-read its feeds, the chat dock closed, scroll and form state
// were lost. Owners never saw it — they are company users on the other path.
//
// Driven on 2026-08-23 as ironhills.admin: semantics node count 142 → 6 →
// 31 → 129 three times in 90 s, each paired with a "Synced auth state" line.
//
// Sabotage: put `|| !isCompanyUser` back on the clearing branch and the first
// case fails; the other three stay green, which is what proves the context is
// still cleared when it should be — a different user, or a sign-out.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import 'package:flutter_application_1/features/auth/models/user_type.dart';
import 'package:flutter_application_1/features/auth/providers/auth_state.dart';
import 'package:flutter_application_1/features/auth/services/auth_service.dart';
import 'package:flutter_application_1/features/auth/services/device_verification_store.dart';
import 'package:flutter_application_1/features/company/providers/company_provider.dart';
import 'package:flutter_application_1/features/company/services/company_database_service.dart';
import 'package:flutter_application_1/features/company/services/company_service.dart';
import 'package:flutter_application_1/features/notifications/services/notification_service.dart';

import '../../fixtures/screen_fixtures.dart';
import '../../test_helpers/test_supabase.dart';

/// An auth notifier the TEST drives. Its constructor's `_initialize()` would
/// otherwise push the dummy Supabase instance's signed-out state over ours.
class _DrivenAuth extends AuthStateNotifier {
  _DrivenAuth(super.authService, super.deviceStore);

  bool _open = false;

  void emit(AuthState s) {
    _open = true;
    state = s;
    _open = false;
  }

  @override
  set state(AuthState value) {
    if (!_open) return;
    super.state = value;
  }
}

/// Lets the test put a loaded managed context in place without dialling.
class _SeedableCompanyNotifier extends CompanyNotifier {
  _SeedableCompanyNotifier(
    super.companyService,
    super.companyDatabaseService,
    super.notificationService,
    super.authStateNotifier,
  );

  void seed(CompanyState s) => state = s;
}

supabase.User _user(String id) => supabase.User(
      id: id,
      appMetadata: const {},
      userMetadata: const {'user_type': 'employee'},
      aud: 'authenticated',
      email: '$id@fixture.co.za',
      createdAt: DateTime(2026, 8, 23).toIso8601String(),
      role: 'authenticated',
    );

AuthState _employee(String id) =>
    AuthState(user: _user(id), userType: UserType.employee, isLoading: false);

void main() {
  setUpAll(ensureTestSupabaseInitialized);

  late ProviderContainer container;
  late _DrivenAuth auth;
  late _SeedableCompanyNotifier company;

  setUp(() {
    container = ProviderContainer();
    auth = _DrivenAuth(
      container.read(authServiceProvider),
      container.read(deviceVerificationStoreProvider),
    );
    company = _SeedableCompanyNotifier(
      container.read(companyServiceProvider),
      container.read(companyDatabaseServiceProvider),
      container.read(notificationServiceProvider),
      auth,
    );
  });

  tearDown(() {
    company.dispose();
    auth.dispose();
    container.dispose();
  });

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  CompanyState managed() => CompanyState(
        company: fixtureCompany(orgType: OrgType.mineSupplier),
        canManageEmployees: true,
      );

  test('a re-sync for the SAME employee keeps the managed context',
      () async {
    auth.emit(_employee('admin-1'));
    await settle();
    company.seed(managed());

    // What the profiles heartbeat produces: the same user, emitted again.
    auth.emit(_employee('admin-1'));
    await settle();

    expect(company.state.company, isNotNull,
        reason: 'the context was wiped by a heartbeat, not by a sign-out');
    expect(company.state.canManageEmployees, isTrue);
  });

  test('a DIFFERENT employee signing in clears it', () async {
    auth.emit(_employee('admin-1'));
    await settle();
    company.seed(managed());

    auth.emit(_employee('admin-2'));
    await settle();

    expect(company.state.company, isNull);
  });

  test('signing out clears it', () async {
    auth.emit(_employee('admin-1'));
    await settle();
    company.seed(managed());

    auth.emit(AuthState());
    await settle();

    expect(company.state.company, isNull);
  });

  test('an employee arriving after a sign-out starts clean', () async {
    auth.emit(_employee('admin-1'));
    await settle();
    company.seed(managed());
    auth.emit(AuthState());
    await settle();

    auth.emit(_employee('admin-1'));
    await settle();

    expect(company.state.company, isNull,
        reason: 'the shell reloads the context; nothing stale survives');
  });
}
