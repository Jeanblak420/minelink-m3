import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_application_1/core/utils/dialog_utils.dart';
import 'package:flutter_application_1/features/auth/providers/auth_state.dart';
import 'package:flutter_application_1/core/routing/app_router.dart';
import 'package:flutter_application_1/core/utils/friendly_error.dart';
import 'package:flutter_application_1/core/design/tokens/ml_tokens.dart';

/// Service to handle logout operations with confirmation
class LogoutService {
  /// Shows a confirmation dialog and logs out if confirmed
  /// Returns true if logout was performed, false otherwise
  static Future<bool> logoutWithConfirmation(
    BuildContext context,
    WidgetRef ref,
  ) async {
    // First check if context is still mounted
    if (!context.mounted) {
      debugPrint('Context not mounted in logoutWithConfirmation');
      return false;
    }

    try {
      // Show confirmation dialog
      final confirmed = await DialogUtils.showConfirmationDialog(
        context: context,
        title: 'Logout Confirmation',
        message: 'Are you sure you want to log out?',
        confirmText: 'Yes, Logout',
        cancelText: 'Cancel',
        confirmColor: MlTokens.red600,
      );

      // Check again if context is still mounted after dialog
      if (!context.mounted) {
        debugPrint('Context no longer mounted after confirmation dialog');
        return false;
      }

      // If user confirmed, perform logout
      if (confirmed) {
        try {
          await ref.read(authStateProvider.notifier).signOut();
        } catch (signOutError) {
          debugPrint('Error during sign out: $signOutError');
          // Continue with navigation even if sign out had an error
        }
        // Ensure navigation to login screen
        if (context.mounted) {
          AppRouter.router.go('/login');
        }

        return true;
      }

      return false;
    } catch (e) {
      // Handle any errors during logout
      debugPrint('Error during logout: $e');

      // Show error message to user
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error logging out. ${friendlyError(e)}'),
            backgroundColor: MlTokens.red600,
          ),
        );
      }

      return false;
    }
  }
}
