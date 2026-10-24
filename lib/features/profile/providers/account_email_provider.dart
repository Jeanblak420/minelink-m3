import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter_application_1/features/auth/providers/auth_state.dart';

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
/// ## It follows the session — it used to read it once
///
/// This was a plain `Provider` over `currentUser`, on the reasoning that the
/// screen sits behind the router's auth gate. But a provider lives in the
/// app's root container, not in the route: it was computed on first read and
/// then cached for the life of the app. Found on the emulator walk
/// (2026-10-24): signed in as a transporter manager, the change-password card
/// read "For role.walk.sec…" — the user who had signed in on that device two
/// sign-ins earlier — and `ChangePasswordSection` would have checked the
/// "current password" against that previous account. It now follows
/// [authStateProvider], which tracks every sign-in and sign-out.
final accountEmailProvider = Provider<String?>((ref) {
  final email = ref.watch(accountEmailSourceProvider)?.trim();
  return (email == null || email.isEmpty) ? null : email;
});

/// The raw email of whoever is signed in, from [authStateProvider]. Its own
/// provider so a test can drive sign-ins without a live auth client.
final accountEmailSourceProvider = Provider<String?>(
  (ref) => ref.watch(authStateProvider.select((s) => s.user?.email)),
);
