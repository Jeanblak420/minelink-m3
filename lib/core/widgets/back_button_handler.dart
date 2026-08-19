import 'package:flutter/material.dart';
import 'package:flutter_application_1/core/utils/dialog_utils.dart';
import 'package:flutter_application_1/core/utils/logger.dart';

/// A widget that handles back button presses with confirmation
/// to prevent accidental logout or navigation
class BackButtonHandler extends StatelessWidget {
  final Widget child;
  final String title;
  final String message;
  final bool enabled;
  final VoidCallback? onBackConfirmed;
  static final _logger = LoggerFactory.getLogger('BackButtonHandler');

  const BackButtonHandler({
    super.key,
    required this.child,
    this.title = 'Confirm Navigation',
    this.message =
        'Are you sure you want to go back? This will log you out of the application.',
    this.enabled = true,
    this.onBackConfirmed,
  });

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;

    // Use a custom back button handler with BackButtonListener
    return BackButtonListener(
      onBackButtonPressed: () async {
        // Check if context is still mounted before showing dialog
        if (!context.mounted) return true;

        try {
          final confirmed = await DialogUtils.showConfirmationDialog(
            context: context,
            title: title,
            message: message,
            confirmText: 'Yes, Go Back',
            cancelText: 'Stay Here',
          );

          // Check again if context is still mounted after dialog closes
          if (!context.mounted) return true;

          if (confirmed) {
            if (onBackConfirmed != null) {
              onBackConfirmed!();
            }
            return true; // Allow pop
          }
          return false; // Prevent pop
        } catch (e) {
          // Handle any errors that might occur during the async operation
          _logger.e('Error in BackButtonHandler', e);
          return false; // Prevent pop on error
        }
      },
      child: child,
    );
  }
}
