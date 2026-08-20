import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter_application_1/core/config/supabase_config.dart';

/// The signed-in account's email address, trimmed, or null when there is none.
///
/// ## Why this provider exists
///
/// `AccountSecurityScreen` read `SupabaseConfig.client.auth.currentUser?.email`
/// **inside its `build`**. That breaks the rule in `CLAUDE.md` §6 — *"Screens
/// and providers must not call `SupabaseConfig.client` directly"* — and the
/// cost was not theoretical: a widget that reaches into a global singleton
/// cannot be handed a different answer, so the screen was untestable. It
/// rendered one line ("No email address is associated with this session…") in
/// every test, and the layout sweep that covered it was passing over an error
/// state at every width and every text scale.
///
/// A provider is the seam. The screen watches this; a test overrides it.
///
/// Deliberately a plain `Provider` rather than a `StreamProvider` over
/// `onAuthStateChange`: the screen is only reachable behind the router's auth
/// gate, so the session cannot vanish underneath it without the whole route
/// being torn down first. A stream here would add a rebuild path with nothing
/// to rebuild for.
final accountEmailProvider = Provider<String?>((ref) {
  final email = SupabaseConfig.client.auth.currentUser?.email?.trim();
  return (email == null || email.isEmpty) ? null : email;
});
