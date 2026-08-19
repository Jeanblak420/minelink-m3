import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:flutter_application_1/core/config/supabase_config.dart';
import 'package:flutter_application_1/core/utils/logger.dart';
import 'package:flutter_application_1/features/profile/models/account_deactivation_request.dart';

/// The only file that touches `SupabaseConfig.client` (and, for
/// [SupabaseAccountDeactivationService], `SupabaseConfig.client.auth`) for
/// account deactivation — screens and the card go through this interface
/// instead (CLAUDE.md §6).
///
/// Wraps `request_account_deactivation`, `cancel_account_deactivation_request`,
/// `my_account_deactivation_request`, and the `signInWithPassword` re-auth
/// step. Every `PostgrestException` is rethrown as
/// [AccountDeactivationException] with the SQLSTATE intact, so callers branch
/// on `code` (`MLD01` / `MLD02` / `AUTH_FAILED` / `AUTH_NO_EMAIL`) and never
/// on wording.
abstract class AccountDeactivationService {
  /// The caller's own open or most-recently-decided request, or `null` if
  /// they have never asked (or their last request was cancelled / already
  /// applied — see the model doc on which statuses this can return).
  Future<AccountDeactivationRequest?> current();

  /// Re-authenticates the caller by verifying [password] against the current
  /// session's own email, via `signInWithPassword`.
  ///
  /// This is NOT a second access-control check — the RPCs are already
  /// `security definer`, keyed off the caller's own `auth.uid()` from the
  /// session established at sign-in, and that is the real authorization
  /// boundary. What THIS guards against is different: an **unattended,
  /// already-signed-in session** — a shared depot tablet, a driver's phone
  /// left on a seat — which carries a perfectly valid JWT and `auth.uid()`
  /// but is not necessarily being operated by the account's owner right now.
  /// On a platform where devices are shared by design, that is a real gap,
  /// and it is the entire reason this step exists.
  ///
  /// Throws `AUTH_FAILED` on a wrong password, `AUTH_NO_EMAIL` if the current
  /// session has no email to verify against.
  Future<void> reauthenticate(String password);

  /// Opens a new deactivation request. Throws `MLD01` if the caller owns a
  /// company, `MLD02` if one is already open.
  Future<void> request(String? reason);

  /// Withdraws the caller's own `pending` request. Throws `MLD02` if there is
  /// none, or if it has already been approved (an admin has acted).
  Future<void> cancel();
}

class SupabaseAccountDeactivationService implements AccountDeactivationService {
  SupabaseAccountDeactivationService({SupabaseClient? client})
      : _client = client ?? SupabaseConfig.client;

  final SupabaseClient _client;
  static final _log = LoggerFactory.getLogger('AccountDeactivationService');

  @override
  Future<AccountDeactivationRequest?> current() async {
    try {
      final result = await _client.rpc('my_account_deactivation_request');
      if (result == null) return null;
      return AccountDeactivationRequest.fromJson(
        Map<String, dynamic>.from(result as Map),
      );
    } on PostgrestException catch (e) {
      _log.w('my_account_deactivation_request failed: ${e.message}');
      throw AccountDeactivationException(e.code ?? '', e.message);
    }
  }

  @override
  Future<void> reauthenticate(String password) async {
    final email = _client.auth.currentUser?.email?.trim();
    if (email == null || email.isEmpty) {
      throw const AccountDeactivationException(
        'AUTH_NO_EMAIL',
        'No email address is associated with this session.',
      );
    }
    try {
      await _client.auth.signInWithPassword(email: email, password: password);
    } on AuthException catch (e) {
      _log.w('Re-auth failed before a deactivation request: ${e.message}');
      throw AccountDeactivationException('AUTH_FAILED', e.message);
    }
  }

  @override
  Future<void> request(String? reason) async {
    try {
      await _client.rpc(
        'request_account_deactivation',
        params: {'p_reason': reason},
      );
    } on PostgrestException catch (e) {
      _log.w('request_account_deactivation failed: ${e.message}');
      throw AccountDeactivationException(e.code ?? '', e.message);
    }
  }

  @override
  Future<void> cancel() async {
    try {
      await _client.rpc('cancel_account_deactivation_request');
    } on PostgrestException catch (e) {
      _log.w('cancel_account_deactivation_request failed: ${e.message}');
      throw AccountDeactivationException(e.code ?? '', e.message);
    }
  }
}
