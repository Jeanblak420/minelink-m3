import 'package:flutter/material.dart';

/// Utility class for common dialog operations
class DialogUtils {
  /// Max width for [AlertDialog] content on the current screen (caps desktop, fits phones).
  static double contentMaxWidth(
    BuildContext context, {
    double maxWidth = 520,
    double horizontalInset = 48,
    double minWidth = 280,
  }) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    return (screenWidth - horizontalInset).clamp(minWidth, maxWidth);
  }

  /// Margin to leave around an [AlertDialog], narrower on a small phone.
  ///
  /// Material's default is 40px of margin on each side, which is generous on a
  /// desktop and ruinous on a 320px phone: 80px of the screen is spent on
  /// margin before the dialog's own 24px content padding, leaving **192px** of
  /// a 320px screen for the form. Measured on the fleet vehicle dialogs, that
  /// was enough to ellipsise "2nd trailer registration" at the SMALLEST text
  /// size the app offers — a field label unreadable with no accessibility
  /// setting involved at all.
  ///
  /// 16px is the Material spec's own margin for a compact window class.
  static EdgeInsets adaptiveInsetPadding(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 480;
    return EdgeInsets.symmetric(horizontal: narrow ? 16 : 40, vertical: 24);
  }

  /// [AlertDialog.contentPadding], tightened horizontally on a small phone for
  /// the same reason as [adaptiveInsetPadding]. Vertical spacing is unchanged.
  static EdgeInsets adaptiveContentPadding(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 480;
    return EdgeInsets.fromLTRB(narrow ? 16 : 24, 20, narrow ? 16 : 24, 24);
  }

  /// Stacks primary/cancel on narrow screens to avoid [AlertDialog] action overflow.
  static List<Widget> adaptiveDialogActions({
    required BuildContext context,
    required VoidCallback onCancel,
    required Widget primary,
    String cancelText = 'Cancel',
  }) {
    final narrow = MediaQuery.sizeOf(context).width < 480;
    final cancel = TextButton(onPressed: onCancel, child: Text(cancelText));
    if (narrow) {
      return [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              primary,
              const SizedBox(height: 8),
              cancel,
            ],
          ),
        ),
      ];
    }
    return [cancel, primary];
  }

  /// Shows a confirmation dialog with Yes/No options
  /// Returns true if user confirms, false otherwise
  static Future<bool> showConfirmationDialog({
    required BuildContext context,
    required String title,
    required String message,
    String confirmText = 'Yes',
    String cancelText = 'No',
    Color? confirmColor,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false, // User must tap a button to close dialog
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(cancelText),
            ),
            TextButton(
              style: confirmColor != null
                  ? TextButton.styleFrom(foregroundColor: confirmColor)
                  : null,
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(confirmText),
            ),
          ],
        );
      },
    );

    return result ?? false;
  }
}
