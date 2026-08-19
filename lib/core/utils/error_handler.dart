import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';
import 'dart:io';
import 'package:flutter_application_1/core/design/tokens/ml_tokens.dart';

class ErrorHandler {
  static String getErrorMessage(dynamic error) {
    // First check for specific error messages we want to pass through directly
    if (error is Exception || error is Error) {
      final errorString = error.toString();

      // Check for specific error messages we want to pass through
      if (errorString.contains('This email is already registered')) {
        return 'This email is already registered. Please use a different email or try logging in.';
      }

      if (errorString.contains('already initialized')) {
        return 'There was a problem with the application initialization. Please refresh the page and try again.';
      }

      if (errorString.contains('Failed to create user profile')) {
        return 'Failed to create user profile. Please try again or contact support.';
      }
    }

    // Then handle specific error types
    if (error is AuthException) {
      return _handleAuthError(error);
    } else if (error is PostgrestException) {
      return _handlePostgrestError(error);
    } else if (error is StorageException) {
      return _handleStorageError(error);
    } else if (error is SocketException) {
      return 'Network connection error. Please check your internet connection.';
    } else if (error is TimeoutException) {
      return 'The operation timed out. Please try again.';
    } else if (error is FormatException) {
      return 'Invalid data format. Please check your input.';
    } else if (error is AssertionError) {
      return 'There was a problem with the application. Please refresh the page and try again.';
    } else {
      // For any other errors, check if it's a string we can use
      final errorString = error.toString();
      if (errorString.contains('Exception:')) {
        // Extract the message after "Exception:"
        final message = errorString.split('Exception:').last.trim();
        if (message.isNotEmpty &&
            !message.contains('An unexpected error occurred')) {
          return message;
        }
      }

      return 'An unexpected error occurred. Please try again.';
    }
  }

  static Exception handleSupabaseError(dynamic error) {
    final errorMessage = getErrorMessage(error);
    return Exception(errorMessage);
  }

  static String _handleAuthError(AuthException error) {
    // ignore: avoid_print
    print('AuthException details:');
    // ignore: avoid_print
    print('- Message: ${error.message}');
    // ignore: avoid_print
    print('- Status Code: ${error.statusCode}');
    // ignore: avoid_print
    print('- Error Code: ${error.code}');

    // First check for specific error codes
    if (error.code == 'user_already_exists') {
      return 'This email is already registered. Please use a different email or try logging in.';
    }

    // Then check for specific messages
    switch (error.message) {
      case 'Invalid login credentials':
        return 'Invalid email or password. Please try again.';
      case 'Email not confirmed':
        return 'Please confirm your email before logging in.';
      case 'User already registered':
        return 'This email is already registered. Please use a different email or try logging in.';
      case 'Password should be at least 6 characters':
        return 'Password should be at least 6 characters.';
      default:
        // If we don't have a specific handler, check for common patterns
        final lowerCaseMessage = error.message.toLowerCase();
        if (lowerCaseMessage.contains('already registered') ||
            lowerCaseMessage.contains('already exists') ||
            lowerCaseMessage.contains('email already exists') ||
            lowerCaseMessage.contains('duplicate key value') ||
            lowerCaseMessage.contains('unique constraint')) {
          return 'This email is already registered. Please use a different email or try logging in.';
        }
        return error.message;
    }
  }

  static String _handlePostgrestError(PostgrestException error) {
    // ignore: avoid_print
    print('PostgrestException details:');
    // ignore: avoid_print
    print('- Code: ${error.code}');
    // ignore: avoid_print
    print('- Message: ${error.message}');
    // ignore: avoid_print
    print('- Details: ${error.details}');
    // ignore: avoid_print
    print('- Hint: ${error.hint}');

    if (error.message.contains('duplicate key')) {
      return 'This record already exists.';
    } else if (error.message.contains('foreign key constraint')) {
      return 'This operation cannot be completed due to related records. Details: ${error.details}';
    } else if (error.message.contains('not found')) {
      return 'The requested record was not found.';
    } else if (error.message.contains('permission denied')) {
      return 'You do not have permission to perform this action.';
    } else if (error.message.contains('invalid input syntax')) {
      return 'Invalid data format. Please check your input. Details: ${error.details}';
    } else if (error.message.contains('violates check constraint')) {
      return 'The data does not meet the required conditions. Details: ${error.details}';
    } else if (error.message.contains('violates not-null constraint')) {
      return 'Required fields cannot be empty. Details: ${error.details}';
    } else if (error.message.contains('connection error')) {
      return 'Unable to connect to the database. Please check your internet connection.';
    } else if (error.message.contains('timeout')) {
      return 'The operation timed out. Please try again.';
    } else if (error.code == '404') {
      return 'Resource not found: The table or endpoint does not exist.';
    } else if (error.code == '422') {
      return 'Unprocessable entity: The request data is invalid. Details: ${error.details}';
    } else if (error.code == '403') {
      return 'Forbidden: You do not have permission to access this resource.';
    } else if (error.code == '401') {
      return 'Unauthorized: Please sign in to access this resource.';
    } else {
      return 'Database error: ${error.message}. Details: ${error.details}';
    }
  }

  static String _handleStorageError(StorageException error) {
    if (error.statusCode == '413') {
      return 'The file is too large. Please upload a smaller file.';
    } else if (error.statusCode == '415') {
      return 'Unsupported file type. Please upload a different file.';
    } else if (error.statusCode == '401' || error.statusCode == '403') {
      return 'You do not have permission to access this file.';
    } else if (error.statusCode == '404') {
      return 'The requested file was not found.';
    } else if (error.statusCode == '409') {
      return 'A file with this name already exists.';
    } else if (error.statusCode == '500') {
      return 'A server error occurred. Please try again later.';
    } else {
      return 'Storage error: ${error.message}';
    }
  }

  static void showErrorSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: MlTokens.red600,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'Dismiss',
          textColor: MlTokens.inkOnFill,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  static void showSuccessSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: MlTokens.green600,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'Dismiss',
          textColor: MlTokens.inkOnFill,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  static Future<bool> showRetryDialog(
    BuildContext context,
    String title,
    String message,
  ) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(false);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop(true);
              },
              child: const Text('Retry'),
            ),
          ],
        );
      },
    );

    return result ?? false;
  }
}
