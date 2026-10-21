import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_application_1/core/config/supabase_config.dart';
import 'package:flutter_application_1/core/services/cache_service.dart';
import 'package:flutter_application_1/core/utils/error_handler.dart';
import 'package:flutter_application_1/core/utils/logger.dart';
import 'package:flutter_application_1/features/auth/models/user_type.dart';
import 'package:flutter_application_1/features/auth/utils/whatsapp_identity.dart';

class AuthService {
  final _supabase = SupabaseConfig.client;
  final _logger = LoggerFactory.getLogger('AuthService');

  String _buildDisplayName(UserType userType, Map<String, dynamic> profile) {
    if (userType.isCompany) {
      return (profile['company_name'] as String? ?? '').trim();
    }

    final firstName = (profile['first_name'] as String? ?? '').trim();
    final lastName = (profile['last_name'] as String? ?? '').trim();
    return '$firstName $lastName'.trim();
  }

  Future<void> _completeSignup({
    required UserType userType,
    required Map<String, dynamic> profile,
  }) async {
    if (userType.isCompany) {
      await _supabase.rpc(
        'complete_company_signup',
        params: {
          'company_name': profile['company_name'],
          'whatsapp_number': profile['whatsapp_number'],
          'org_type': profile['org_type'],
          'ceo_first_name': profile['ceo_first_name'],
          'ceo_last_name': profile['ceo_last_name'],
        },
      );
      return;
    }

    await _supabase.rpc(
      'complete_employee_signup',
      params: {
        'first_name': profile['first_name'],
        'last_name': profile['last_name'],
        'whatsapp_number': profile['whatsapp_number'],
        'is_south_african_citizen': profile['is_south_african_citizen'] ?? true,
        'id_number': profile['id_number'],
        'passport_or_workers_permit': profile['passport_or_workers_permit'],
        'license_document': profile['license_document'],
      },
    );
  }

  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required UserType userType,
    required Map<String, dynamic> profile,
  }) async {
    try {
      _logger.i('Starting signup process for ${userType.name}');
      _logger.d('Profile data: $profile');

      if (userType == UserType.employee) {
        await CacheService.clearEmployeeCache();
      }

      final displayName = _buildDisplayName(userType, profile);

      final response = await _supabase.auth.signUp(
        email: email,
        password: password,
        data: {'user_type': userType.name, 'display_name': displayName},
      );

      if (response.user == null) {
        throw Exception(
          'Failed to create user account. Please try again with a different email.',
        );
      }

      await _completeSignup(userType: userType, profile: profile);

      _logger.i('Signup completed successfully');
      return response;
    } catch (e) {
      final errorString = e.toString().toLowerCase();
      if (errorString.contains('already registered') ||
          errorString.contains('user_already_exists') ||
          errorString.contains('email already exists') ||
          errorString.contains(
            'duplicate key value violates unique constraint',
          )) {
        throw Exception(
          'This email is already registered. Please use a different email or try logging in.',
        );
      }

      if (e is AuthException) {
        throw Exception(e.message);
      }

      _logger.e('Signup error: $e');
      throw _handleError(e);
    }
  }

  /// How long any single auth call may take before it is reported as a failure.
  ///
  /// Without it, a stalled auth service leaves the sign-in button reading
  /// **"Signing in…" forever** — no error, no way to retry, nothing to tell the
  /// user whether their password was even wrong. Observed on 2026-08-16:
  /// `POST /auth/v1/token?grant_type=password` sat `pending` indefinitely while
  /// the screen said "Signing in…".
  ///
  /// Twenty seconds is generous for an auth round trip on a bad mobile
  /// connection — which the drivers this ships to will be on — and short enough
  /// that the user gets an answer rather than a spinner.
  static const authTimeout = Duration(seconds: 20);

  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    try {
      return await _supabase.auth
          .signInWithPassword(
            email: email.trim().toLowerCase(),
            password: password,
          )
          .timeout(authTimeout);
    } on TimeoutException {
      // Deliberately NOT "wrong password". The request never got an answer, so
      // the one thing we know is that we do not know — and telling somebody
      // their password is wrong when it may be right sends them off resetting a
      // credential that works.
      throw Exception(
        'Signing in is taking longer than expected. Check your connection and '
        'try again — your password has not been rejected.',
      );
    } catch (e) {
      throw _handleError(e);
    }
  }

  /// Sends a WhatsApp OTP to [whatsappNumber] via Supabase phone auth.
  /// Supabase generates the code and fires the Send-SMS hook, which delivers
  /// it over WhatsApp via the Meta Cloud API (configured in Edge Function).
  ///
  /// [shouldCreateUser] is false: these accounts are created only by the admin
  /// flow, so an unknown number must NOT silently create a new account
  /// (prevents account enumeration / accidental signups).
  Future<void> sendWhatsappOtp(String whatsappNumber) async {
    final phone = whatsappToE164(whatsappNumber);
    if (phone.isEmpty) {
      throw Exception('Enter a valid WhatsApp number.');
    }
    try {
      await _supabase.auth
          .signInWithOtp(phone: phone, shouldCreateUser: false)
          .timeout(authTimeout);
    } on TimeoutException {
      // Rethrown with its TYPE intact. `_handleError` would wrap it in a plain
      // Exception, and `friendlyError` — which is what the screens call — keys
      // its good sentence ("The server took too long to respond") off the type.
      // Wrapping it costs the user the one message that says what happened.
      rethrow;
    } catch (e) {
      throw _handleError(e);
    }
  }

  /// Verifies the WhatsApp OTP [token] for [whatsappNumber], establishing a
  /// session on success.
  Future<AuthResponse> verifyWhatsappOtp({
    required String whatsappNumber,
    required String token,
  }) async {
    final phone = whatsappToE164(whatsappNumber);
    try {
      return await _supabase.auth
          .verifyOTP(phone: phone, token: token.trim(), type: OtpType.sms)
          .timeout(authTimeout);
    } on TimeoutException {
      rethrow;
    } catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> signOut() async {
    try {
      // A sign-out that hangs is worse than one that fails: the user is
      // trying to LEAVE, often on somebody else's device. The local session is
      // cleared either way by `onAuthStateChange`, so an unanswered request
      // must not hold them on screen.
      await _supabase.auth.signOut().timeout(authTimeout);
    } on TimeoutException {
      rethrow;
    } catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> resetPassword(String email) async {
    try {
      final baseUrl = Uri.base.toString();

      String resetUrl;
      if (baseUrl.contains('?')) {
        resetUrl = baseUrl.split('?')[0];
      } else if (baseUrl.contains('#')) {
        resetUrl = baseUrl.split('#')[0];
      } else {
        resetUrl = baseUrl;
      }

      if (!resetUrl.endsWith('/')) {
        resetUrl += '/';
      }

      resetUrl += '#/reset-password';

      await _supabase.auth
          .resetPasswordForEmail(email, redirectTo: resetUrl)
          .timeout(authTimeout);
    } on TimeoutException {
      rethrow;
    } catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> updatePassword(String resetToken, String newPassword) async {
    try {
      try {
        final response = await _supabase.auth.verifyOTP(
          type: OtpType.recovery,
          token: resetToken,
        );

        if (response.session == null) {
          throw Exception(
            'Failed to verify reset token. Please request a new password reset link.',
          );
        }
      } catch (_) {
        throw Exception(
          'Invalid or expired reset token. Please request a new password reset link.',
        );
      }

      await _supabase.auth.updateUser(UserAttributes(password: newPassword));
    } catch (e) {
      throw _handleError(e);
    }
  }

  Future<UserType?> getUserType(String userId) async {
    try {
      final profile = await _supabase
          .from('profiles')
          .select('user_type')
          .eq('id', userId)
          .maybeSingle();

      final profileUserType = profile?['user_type'] as String?;
      if (profileUserType == UserType.company.name) {
        return UserType.company;
      }
      if (profileUserType == UserType.employee.name) {
        return UserType.employee;
      }

      final companyResults = await _supabase
          .from('companies')
          .select('id')
          .eq('user_id', userId);
      if (companyResults.isNotEmpty) {
        return UserType.company;
      }

      final employeeResults = await _supabase
          .from('employees')
          .select('id')
          .eq('user_id', userId);
      if (employeeResults.isNotEmpty) {
        return UserType.employee;
      }

      return null;
    } catch (e) {
      _logger.e('Error determining user type: ${e.toString()}');
      return null;
    }
  }

  Exception _handleError(dynamic error) {
    final errorMessage = ErrorHandler.getErrorMessage(error);
    return Exception(errorMessage);
  }

  Future<bool> checkIfUserExists(String email) async {
    try {
      final response = await _supabase.rpc(
        'check_email_registered',
        params: {'target_email': email.trim().toLowerCase()},
      );
      return response == true;
    } catch (e) {
      _logger.w('Error checking whether email exists: $e');
      return false;
    }
  }
}

final authServiceProvider = Provider<AuthService>((ref) => AuthService());
