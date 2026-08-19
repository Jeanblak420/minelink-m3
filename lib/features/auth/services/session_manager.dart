import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_application_1/core/routing/app_router.dart';
import 'package:flutter_application_1/features/auth/providers/auth_state.dart';
import 'package:flutter_application_1/core/config/supabase_config.dart';
import 'package:flutter_application_1/core/services/cache_service.dart';
import 'package:flutter_application_1/features/auth/services/session_manager_browser_bridge.dart';

/// A service to manage session state across app restarts and browser refreshes
class SessionManager {
  final Ref _ref;
  final SessionManagerBrowserBridge _browserBridge =
      SessionManagerBrowserBridge();
  Timer? _sessionCheckTimer;
  Timer? _securityCheckTimer;
  bool _isInitialized = false;
  String? _lastKnownUserId;

  SessionManager(this._ref);

  /// Initialize the session manager
  void initialize() {
    if (_isInitialized) return;
    _isInitialized = true;

    // Set up periodic session check (every 5 minutes)
    _sessionCheckTimer = Timer.periodic(const Duration(minutes: 5), (_) async {
      await _checkSessionValidity();
    });

    // Set up more frequent security checks (every 10 seconds)
    _securityCheckTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _performSecurityChecks();
    });

    // Initialize last known user ID
    _initializeLastKnownUserId();

    // Delay web-specific initialization to avoid circular dependencies
    if (kIsWeb) {
      _registerJsCallbacks();
      Future.microtask(_checkForRedirectFlag);
    }
  }

  /// Initialize the last known user ID from cache
  Future<void> _initializeLastKnownUserId() async {
    try {
      _lastKnownUserId = await CacheService.getCurrentUserId();
      debugPrint(
        'SessionManager: Initialized with last known user ID: $_lastKnownUserId',
      );
    } catch (e) {
      debugPrint('SessionManager: Error initializing last known user ID: $e');
    }
  }

  /// Dispose resources
  void dispose() {
    _sessionCheckTimer?.cancel();
    _securityCheckTimer?.cancel();
    _browserBridge.dispose();
  }

  /// Perform security checks to prevent unauthorized profile access
  Future<void> _performSecurityChecks() async {
    try {
      // Get current auth state
      final authState = _ref.read(authStateProvider);
      if (authState.user == null) {
        // Not logged in, nothing to check
        return;
      }

      // Get current user ID from cache
      final currentUserId = await CacheService.getCurrentUserId();

      // Check if user ID has changed without proper logout
      if (_lastKnownUserId != null &&
          currentUserId != null &&
          _lastKnownUserId != currentUserId &&
          authState.user?.id != currentUserId) {
        debugPrint(
          'SECURITY ALERT: User ID changed from $_lastKnownUserId to $currentUserId without proper logout!',
        );
        debugPrint('Auth state user ID: ${authState.user?.id}');

        await _forceLogoutToLogin(
          reason: 'Unexpected cached user mismatch detected',
        );
        return;
      }

      // Check if auth state user ID matches cached user ID
      if (authState.user != null &&
          currentUserId != null &&
          authState.user!.id != currentUserId) {
        debugPrint(
          'SECURITY ALERT: Auth state user ID (${authState.user!.id}) does not match cached user ID ($currentUserId)!',
        );

        await _forceLogoutToLogin(
          reason: 'Cached session user does not match authenticated user',
        );
        return;
      }

      // Update last known user ID if needed
      if (currentUserId != null && _lastKnownUserId != currentUserId) {
        _lastKnownUserId = currentUserId;
        debugPrint(
          'SessionManager: Updated last known user ID to: $_lastKnownUserId',
        );
      }
    } catch (e) {
      debugPrint('Error performing security checks: $e');
    }
  }

  /// Check if the session is still valid and refresh if needed
  Future<void> _checkSessionValidity() async {
    try {
      final currentUser = SupabaseConfig.client.auth.currentUser;
      final currentSession = SupabaseConfig.client.auth.currentSession;
      final authState = _ref.read(authStateProvider);

      // If we have no user or session, but the auth state says we're logged in
      if (authState.user != null &&
          (currentUser == null || currentSession == null)) {
        debugPrint('Session appears invalid, attempting to recover');

        // Try to recover the session from storage before signing out
        try {
          // This will trigger Supabase to try to recover the session from storage
          await SupabaseConfig.client.auth.refreshSession();

          // Check if recovery was successful
          final refreshedUser = SupabaseConfig.client.auth.currentUser;
          if (refreshedUser != null) {
            debugPrint('Session recovered successfully');
            return;
          } else {
            debugPrint('Session recovery failed, signing out');
            await _forceLogoutToLogin(reason: 'Session recovery failed');
          }
        } catch (refreshError) {
          debugPrint('Error refreshing session: $refreshError');
          await _forceLogoutToLogin(
            reason: 'Session refresh failed after invalid session state',
          );
        }
      }

      // Check if session is about to expire (within 10 minutes)
      if (currentSession != null) {
        final expiresAt = DateTime.fromMillisecondsSinceEpoch(
          currentSession.expiresAt! * 1000,
        );
        final now = DateTime.now();
        final difference = expiresAt.difference(now);

        if (difference.inMinutes < 10) {
          debugPrint(
            'Session about to expire in ${difference.inMinutes} minutes, refreshing',
          );

          // Proactively refresh the session
          try {
            await SupabaseConfig.client.auth.refreshSession();
            debugPrint('Session refreshed successfully');
          } catch (refreshError) {
            debugPrint('Error refreshing session: $refreshError');
          }
        }
      }
    } catch (e) {
      debugPrint('Error checking session validity: $e');
    }
  }

  /// Check for redirect flag in session storage (web only)
  void _checkForRedirectFlag() {
    if (!kIsWeb) return;
    final redirectPath = _browserBridge.consumeRedirectPath();
    if (redirectPath == null || redirectPath.isEmpty) {
      return;
    }

    debugPrint(
      'SessionManager: Consumed browser redirect flag -> $redirectPath',
    );
    AppRouter.router.go(redirectPath);
  }

  /// Register callbacks for JavaScript to call
  void _registerJsCallbacks() {
    if (!kIsWeb) return;
    _browserBridge.initialize(
      onSessionExpired: () async {
        debugPrint('SessionManager: Browser session expiry event received');
        await _forceLogoutToLogin(
          reason: 'Browser session expired',
          clearBrowserState: false,
        );
      },
    );
  }

  /// Force a redirect to the login screen
  Future<void> forceLoginRedirect(
    BuildContext context, {
    String? reason,
  }) async {
    debugPrint(
      'Force login redirect requested${reason != null ? ": $reason" : ""}',
    );

    // Clear all cache first
    await CacheService.clearAllCache();

    // Sign out the user
    await _ref.read(authStateProvider.notifier).signOut();

    if (kIsWeb) {
      await _browserBridge.clearSessionState();
    }

    // Navigate to login screen if context is still mounted
    if (context.mounted) {
      GoRouter.of(context).go('/login');
    } else {
      // Fallback if context is not mounted
      AppRouter.router.go('/login');
    }
  }

  Future<void> _forceLogoutToLogin({
    String? reason,
    bool clearBrowserState = true,
  }) async {
    debugPrint(
      'SessionManager: forcing logout${reason != null ? ' ($reason)' : ''}',
    );

    try {
      await _ref.read(authStateProvider.notifier).signOut();
    } catch (e) {
      debugPrint('SessionManager: signOut during forced logout failed: $e');
      await CacheService.clearAllCache();
    }

    if (kIsWeb && clearBrowserState) {
      await _browserBridge.clearSessionState();
    }

    AppRouter.router.go('/login');
  }
}

/// Provider for the SessionManager
final sessionManagerProvider = Provider<SessionManager>((ref) {
  final manager = SessionManager(ref);

  // Use a post-initialization callback to avoid circular dependencies
  // This ensures the manager is initialized after all providers are set up
  WidgetsBinding.instance.addPostFrameCallback((_) {
    manager.initialize();
  });

  return manager;
});
