import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter_application_1/core/config/supabase_config.dart';

/// The signed-in account's id as a stream: now, then on every sign-in and
/// sign-out.
final sessionUserIdStreamProvider = StreamProvider<String?>((ref) async* {
  final auth = SupabaseConfig.client.auth;
  yield auth.currentUser?.id;
  yield* auth.onAuthStateChange.map((e) => e.session?.user.id);
});

/// The signed-in account's id, following sign-in and sign-out.
///
/// For any app-lifetime provider that works FOR a user. Reading
/// `auth.currentUser` in such a provider's body captures whoever was signed in
/// when it was first built and keeps them for the life of the app: on one
/// device, the next person to sign in inherits the last one. Found on the
/// emulator walk, 2026-10-24 (Account & security named the previous user);
/// the chat providers had the same shape. Watch this instead, and the
/// provider is rebuilt for the new account.
///
/// Before the stream's first event it falls back to the session as it is now.
/// Changes only when the id changes, so a token refresh rebuilds nothing.
final sessionUserIdProvider = Provider<String?>((ref) {
  return ref.watch(sessionUserIdStreamProvider.select(
      (a) => a.hasValue ? a.value : _currentUserIdOrNull()));
});

String? _currentUserIdOrNull() {
  try {
    return SupabaseConfig.client.auth.currentUser?.id;
  } catch (_) {
    return null; // no client yet (start-up, tests)
  }
}
