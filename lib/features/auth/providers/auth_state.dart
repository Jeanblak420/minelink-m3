import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import 'package:flutter_application_1/core/config/supabase_config.dart';
import 'package:flutter_application_1/core/services/cache_service.dart';
import 'package:flutter_application_1/features/auth/models/user_type.dart';
import 'package:flutter_application_1/core/routing/app_router.dart';
import 'package:flutter_application_1/features/auth/services/auth_service.dart';
import 'package:flutter_application_1/features/auth/services/device_verification_store.dart';
import 'package:flutter_application_1/core/navigation/nav_history_provider.dart';

const _unset = Object();

class AuthState {
  final supabase.User? user;
  final UserType? userType;
  final bool isLoading;
  final String? error;

  AuthState({this.user, this.userType, this.isLoading = false, this.error});

  AuthState copyWith({
    Object? user = _unset,
    Object? userType = _unset,
    bool? isLoading,
    Object? error = _unset,
  }) {
    return AuthState(
      user: identical(user, _unset) ? this.user : user as supabase.User?,
      userType: identical(userType, _unset)
          ? this.userType
          : userType as UserType?,
      isLoading: isLoading ?? this.isLoading,
      error: identical(error, _unset) ? this.error : error as String?,
    );
  }
}

class AuthStateNotifier extends StateNotifier<AuthState> {
  final AuthService _authService;
  final DeviceVerificationStore _deviceStore;
  final Ref? _ref;
  late final StreamSubscription<supabase.AuthState> _authSubscription;
  supabase.RealtimeChannel? _profileChannel;
  String? _profileSubscriptionUserId;

  AuthStateNotifier(this._authService, this._deviceStore, {Ref? ref})
      : _ref = ref,
        super(AuthState(isLoading: true)) {
    _initialize();
  }

  Future<void> _initialize() async {
    _authSubscription = SupabaseConfig.client.auth.onAuthStateChange.listen((
      authState,
    ) async {
      if (!mounted) {
        return;
      }
      await _syncAuthState(
        authState.session?.user,
        fallbackUserType: _userTypeFromMetadata(authState.session?.user),
      );
    });

    await _syncAuthState(
      SupabaseConfig.client.auth.currentUser,
      fallbackUserType: _userTypeFromMetadata(
        SupabaseConfig.client.auth.currentUser,
      ),
    );
  }

  UserType? _userTypeFromMetadata(supabase.User? user) {
    final metadataUserType = user?.userMetadata?['user_type'];
    if (metadataUserType == UserType.company.name) {
      return UserType.company;
    }
    if (metadataUserType == UserType.employee.name) {
      return UserType.employee;
    }
    return null;
  }

  Future<void> _syncAuthState(
    supabase.User? user, {
    UserType? fallbackUserType,
  }) async {
    if (user == null) {
      AppRouter.clearProfileGateCache();
      await _profileChannel?.unsubscribe();
      _profileChannel = null;
      _profileSubscriptionUserId = null;
      await CacheService.clearCurrentUserCache();
      if (!mounted) {
        return;
      }
      state = AuthState();
      return;
    }

    try {
      AppRouter.clearProfileGateCache();
      final resolvedFallback = fallbackUserType ?? _userTypeFromMetadata(user);
      final userType =
          resolvedFallback ?? await _authService.getUserType(user.id);

      await CacheService.setCurrentUserId(user.id);
      debugPrint(
        'AuthStateNotifier: Synced auth state for user ID: ${user.id}',
      );

      if (!mounted) {
        return;
      }

      _subscribeToProfileChanges(user.id);

      state = state.copyWith(
        user: user,
        userType: userType,
        isLoading: false,
        error: null,
      );
    } catch (e) {
      debugPrint('AuthStateNotifier: Error syncing auth state: $e');
      if (!mounted) {
        return;
      }
      state = state.copyWith(
        user: user,
        userType: fallbackUserType,
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  void _subscribeToProfileChanges(String userId) {
    if (_profileSubscriptionUserId == userId && _profileChannel != null) {
      return;
    }

    _profileChannel?.unsubscribe();
    _profileSubscriptionUserId = userId;
    _profileChannel = SupabaseConfig.client.channel('profile-$userId')
      ..onPostgresChanges(
        event: supabase.PostgresChangeEvent.all,
        schema: 'public',
        table: 'profiles',
        filter: supabase.PostgresChangeFilter(
          type: supabase.PostgresChangeFilterType.eq,
          column: 'id',
          value: userId,
        ),
        callback: (_) async {
          final currentUser = SupabaseConfig.client.auth.currentUser;
          if (currentUser == null) {
            return;
          }

          await _syncAuthState(
            currentUser,
            fallbackUserType: _userTypeFromMetadata(currentUser),
          );
        },
      )
      ..subscribe();
  }

  Future<void> signUp({
    required String email,
    required String password,
    required UserType userType,
    required Map<String, dynamic> profile,
  }) async {
    try {
      await CacheService.clearAllCache();

      debugPrint(
        'AuthStateNotifier: Starting signUp process for email: $email',
      );
      state = state.copyWith(isLoading: true, error: null);

      final response = await _authService.signUp(
        email: email,
        password: password,
        userType: userType,
        profile: profile,
      );

      if (response.user == null) {
        throw Exception('Failed to sign up: No user returned');
      }

      await _syncAuthState(response.user, fallbackUserType: userType);
    } catch (e) {
      debugPrint('AuthStateNotifier: Error in signUp: $e');
      await CacheService.clearAllCache();

      String errorMessage;
      if (e.toString().contains('This email is already registered')) {
        errorMessage =
            'This email is already registered. Please use a different email or try logging in.';
      } else if (e.toString().contains('already initialized')) {
        errorMessage =
            'There was a problem with the application. Please refresh the page and try again.';
      } else if (e.toString().contains('Exception:')) {
        errorMessage = e.toString().split('Exception:').last.trim();
        if (errorMessage.isEmpty ||
            errorMessage.contains('An unexpected error occurred')) {
          errorMessage = 'An unexpected error occurred. Please try again.';
        }
      } else {
        errorMessage = 'An unexpected error occurred. Please try again.';
      }

      state = state.copyWith(isLoading: false, error: errorMessage);
    }
  }

  Future<void> signIn({required String email, required String password}) async {
    try {
      await CacheService.clearAllCache();

      state = state.copyWith(isLoading: true, error: null);
      debugPrint('AuthStateNotifier: Starting sign in for email: $email');

      final response = await _authService.signIn(
        email: email,
        password: password,
      );

      if (response.user == null) {
        throw Exception('Failed to sign in: No user returned');
      }

      await _syncAuthState(
        response.user,
        fallbackUserType: _userTypeFromMetadata(response.user),
      );
    } catch (e) {
      debugPrint('AuthStateNotifier: Error during sign in: $e');
      await CacheService.clearAllCache();

      var errorMessage = e.toString();
      if (errorMessage.contains('Exception:')) {
        errorMessage = errorMessage.split('Exception:').last.trim();
      }
      if (errorMessage.isEmpty) {
        errorMessage = 'Unable to sign in right now. Please try again.';
      }

      state = state.copyWith(isLoading: false, error: errorMessage);
    }
  }

  Future<void> sendWhatsappOtp(String whatsappNumber) async {
    try {
      state = state.copyWith(isLoading: true, error: null);
      await _authService.sendWhatsappOtp(whatsappNumber);
      state = state.copyWith(isLoading: false);
    } catch (e) {
      var msg = e.toString();
      if (msg.contains('Exception:')) msg = msg.split('Exception:').last.trim();
      state = state.copyWith(isLoading: false, error: msg);
      rethrow;
    }
  }

  Future<bool> verifyWhatsappOtp({
    required String whatsappNumber,
    required String token,
  }) async {
    try {
      state = state.copyWith(isLoading: true, error: null);
      final response = await _authService.verifyWhatsappOtp(
        whatsappNumber: whatsappNumber,
        token: token,
      );
      if (response.user == null) {
        throw Exception('Verification failed. Please try again.');
      }
      await _deviceStore.markVerified(DateTime.now());
      AppRouter.clearProfileGateCache();
      await _syncAuthState(
        response.user,
        fallbackUserType: _userTypeFromMetadata(response.user),
      );
      return true;
    } catch (e) {
      var msg = e.toString();
      if (msg.contains('Exception:')) msg = msg.split('Exception:').last.trim();
      if (msg.isEmpty) msg = 'Invalid or expired code. Please try again.';
      state = state.copyWith(isLoading: false, error: msg);
      return false;
    }
  }

  Future<void> signOut() async {
    _ref?.read(navHistoryProvider.notifier).reset();
    try {
      debugPrint('AuthStateNotifier: Starting sign out process');
      state = state.copyWith(isLoading: true, error: null);

      final userId = state.user?.id;
      if (userId != null) {
        await CacheService.clearUserCache(userId);
      }

      await CacheService.clearCurrentUserId();
      await _authService.signOut();
      await CacheService.clearAllCache();

      state = AuthState();
    } catch (e) {
      debugPrint('AuthStateNotifier: Error during sign out: $e');

      try {
        await CacheService.clearAllCache();
      } catch (cacheError) {
        debugPrint(
          'AuthStateNotifier: Error clearing cache during sign out: $cacheError',
        );
      }

      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> resetPassword(String email) async {
    try {
      state = state.copyWith(isLoading: true, error: null);
      await _authService.resetPassword(email);
      state = state.copyWith(isLoading: false);
    } catch (e) {
      String errorMessage;
      if (e.toString().contains('Exception:')) {
        errorMessage = e.toString().split('Exception:').last.trim();
        if (errorMessage.isEmpty ||
            errorMessage.contains('An unexpected error occurred')) {
          errorMessage =
              'An error occurred while sending the password reset email. Please try again.';
        }
      } else {
        errorMessage =
            'An error occurred while sending the password reset email. Please try again.';
      }

      state = state.copyWith(isLoading: false, error: errorMessage);
      rethrow;
    }
  }

  Future<void> updatePassword(String resetToken, String newPassword) async {
    try {
      state = state.copyWith(isLoading: true, error: null);
      await _authService.updatePassword(resetToken, newPassword);
      state = state.copyWith(isLoading: false);
    } catch (e) {
      String errorMessage;
      if (e.toString().contains('Exception:')) {
        errorMessage = e.toString().split('Exception:').last.trim();
        if (errorMessage.isEmpty ||
            errorMessage.contains('An unexpected error occurred')) {
          errorMessage =
              'An error occurred while updating your password. Please try again or request a new password reset link.';
        }
      } else if (e.toString().contains('Invalid JWT')) {
        errorMessage =
            'Your password reset link has expired. Please request a new password reset link.';
      } else if (e.toString().contains('Invalid user')) {
        errorMessage =
            'Invalid user. Please request a new password reset link.';
      } else {
        errorMessage =
            'An error occurred while updating your password. Please try again or request a new password reset link.';
      }

      state = state.copyWith(isLoading: false, error: errorMessage);
      rethrow;
    }
  }

  void setError(String errorMessage) {
    state = state.copyWith(error: errorMessage, isLoading: false);
  }

  void clearError() {
    state = state.copyWith(error: null);
  }

  Future<Map<String, dynamic>?> getEmployeeData(String userId) async {
    try {
      final supabaseClient = SupabaseConfig.client;

      final result = await supabaseClient
          .from('employees')
          .select()
          .eq('user_id', userId)
          .single();

      return result;
    } catch (e) {
      debugPrint('AuthStateNotifier: Error getting employee data: $e');
      return null;
    }
  }

  @override
  void dispose() {
    _profileChannel?.unsubscribe();
    _authSubscription.cancel();
    super.dispose();
  }
}

final authStateProvider = StateNotifierProvider<AuthStateNotifier, AuthState>((
  ref,
) {
  return AuthStateNotifier(
    ref.watch(authServiceProvider),
    ref.watch(deviceVerificationStoreProvider),
    ref: ref,
  );
});
