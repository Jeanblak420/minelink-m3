import 'package:supabase_flutter/supabase_flutter.dart';

/// Short, user-facing text for Supabase Auth failures.
String authErrorMessage(Object error) {
  if (error is AuthException) {
    switch (error.code) {
      case 'same_password':
        return 'Your new password must be different from the temporary password you used to sign in.';
      case 'weak_password':
        return 'Choose a stronger password (at least 8 characters).';
      case 'invalid_credentials':
        return 'Sign-in failed. Check your email and password.';
      default:
        if (error.message.trim().isNotEmpty) return error.message.trim();
    }
  }
  return error.toString();
}
