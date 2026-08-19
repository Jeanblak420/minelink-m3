import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_application_1/features/auth/providers/auth_state.dart'
    as app_auth;
import 'package:flutter_application_1/core/routing/app_router.dart';
import 'package:flutter_application_1/core/config/supabase_config.dart';
import 'package:flutter_application_1/features/auth/services/session_manager.dart';

// Import the authStateProvider
import 'package:flutter_application_1/features/auth/providers/auth_state.dart'
    show authStateProvider;

class AuthStateListener extends ConsumerStatefulWidget {
  final Widget child;

  const AuthStateListener({super.key, required this.child});

  @override
  ConsumerState<AuthStateListener> createState() => _AuthStateListenerState();
}

class _AuthStateListenerState extends ConsumerState<AuthStateListener>
    with WidgetsBindingObserver {
  final _supabase = SupabaseConfig.client;
  bool _isResuming = false;

  @override
  void initState() {
    super.initState();

    // Register for app lifecycle events
    WidgetsBinding.instance.addObserver(this);

    // Add a post-frame callback to ensure the context is ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAuthState();

      // Initialize the session manager
      ref.read(sessionManagerProvider);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Handle app lifecycle changes
    if (state == AppLifecycleState.resumed && !_isResuming) {
      _isResuming = true;

      // Check auth state when app is resumed
      debugPrint('App resumed, checking auth state');
      // Use async method with Future to handle the async operation
      Future.microtask(() async {
        await _verifyAuthState();

        // Reset flag after verification completes
        _isResuming = false;
      });
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      // App is going to background or being closed
      debugPrint('App paused or detached');

      // For web, we handle this in JavaScript
      if (!kIsWeb) {
        // For mobile, we can perform cleanup here
        // This is a good place to save any important state
      }
    }
  }

  void _checkAuthState() {
    // Let GoRouter handle navigation based on auth state
  }

  /// How long a sign-out on the session-mismatch path may take before the app
  /// navigates to `/login` anyway. Long enough for a healthy round trip, short
  /// enough that a lost signal does not look like a frozen app.
  static const _signOutBudget = Duration(seconds: 5);

  /// Signs out, waiting up to [_signOutBudget]. Never throws and never hangs,
  /// so the caller's `go('/login')` always runs.
  Future<void> _signOutBounded() async {
    try {
      await ref
          .read(authStateProvider.notifier)
          .signOut()
          .timeout(_signOutBudget, onTimeout: () {});
    } catch (e) {
      debugPrint('Error during sign out: $e');
    }
  }

  // Verify that the auth state in the provider matches the actual Supabase session
  Future<void> _verifyAuthState() async {
    try {
      final authState = ref.read(authStateProvider);
      final currentUser = _supabase.auth.currentUser;
      final currentSession = _supabase.auth.currentSession;

      // If provider says we're logged in but Supabase says we're not
      if (authState.user != null &&
          (currentUser == null || currentSession == null)) {
        debugPrint(
          'Session mismatch detected: Provider has user but Supabase does not',
        );

        // Try to recover the session before signing out
        try {
          debugPrint('Attempting to recover session...');
          await _supabase.auth.refreshSession();

          // Check if recovery was successful
          final refreshedUser = _supabase.auth.currentUser;
          if (refreshedUser != null) {
            debugPrint('Session recovered successfully');
            return;
          } else {
            debugPrint('Session recovery failed, signing out');
            // Session expired or was invalidated, sign out properly.
            //
            // Awaited deliberately. signOut() clears the cached profile and
            // only resets AuthState on its *last* line; the router's redirect
            // reads both. Firing it unawaited navigated to /login while
            // `state.user` was still populated, so the auth-gated redirect
            // could bounce straight back into the portal on a dead session.
            //
            // Bounded, though: this whole branch runs *because* the session or
            // the connection is already suspect, and signOut() ends in a
            // network call to /logout. An unbounded await would strand a
            // driver who has lost signal on a stale screen — worse than the
            // race it fixes. Five seconds, then navigate regardless.
            await _signOutBounded();
            // Redirect to login
            AppRouter.router.go('/login');
          }
        } catch (refreshError) {
          debugPrint('Error refreshing session: $refreshError');
          // Only sign out if refresh explicitly failed
          await _signOutBounded();
          // Redirect to login
          AppRouter.router.go('/login');
        }
      }
    } catch (e) {
      debugPrint('Error verifying auth state: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<app_auth.AuthState>(authStateProvider, (
      app_auth.AuthState? previous,
      app_auth.AuthState current,
    ) {
      // GoRouter handles the redirect via refreshListenable
    });

    return widget.child;
  }
}
