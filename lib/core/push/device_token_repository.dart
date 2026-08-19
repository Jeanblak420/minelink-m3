import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:flutter_application_1/core/config/supabase_config.dart';

/// Talks to `public.device_tokens` through the two RPCs that guard it —
/// never the table directly, and never `SupabaseConfig.client` from a widget
/// (Task 9 shipped that violation once already and needed a fix round).
///
/// `register_device_token(p_token, p_platform, p_app_version)` upserts on
/// `token`, re-pointing `user_id` if the device changed hands (a shared depot
/// tablet is a real case). `unregister_device_token(p_token)` deletes only
/// the caller's own row — RLS on `device_tokens` restricts SELECT to
/// `user_id = auth.uid()`, and both RPCs are `security definer` scoped to
/// `auth.uid()` internally, so there is nothing here to authorise client-side.
class DeviceTokenRepository {
  DeviceTokenRepository({SupabaseClient? client}) : _injectedClient = client;

  final SupabaseClient? _injectedClient;

  // Resolved lazily, on first use, rather than in the constructor. A
  // `DeviceTokenRepository()` can legitimately be constructed before
  // `Supabase.initialize()` has run — [PushService]'s degraded (unavailable)
  // path never calls a repository method at all, and must not be made to
  // throw just by *existing* on a machine/CI with no session yet.
  SupabaseClient get _client => _injectedClient ?? SupabaseConfig.client;

  /// Registers or refreshes this device's push token. Returns the row id.
  Future<String> register(
    String token,
    String platform,
    String? appVersion,
  ) async {
    final id = await _client.rpc(
      'register_device_token',
      params: {
        'p_token': token,
        'p_platform': platform,
        'p_app_version': appVersion,
      },
    );
    return id as String;
  }

  /// Deletes this device's token. A no-op if it was never registered or
  /// belongs to a different signed-in user (the RPC scopes the delete to
  /// `auth.uid()`).
  Future<void> unregister(String token) async {
    await _client.rpc('unregister_device_token', params: {'p_token': token});
  }
}
