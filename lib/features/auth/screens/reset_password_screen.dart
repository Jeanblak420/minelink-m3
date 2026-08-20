import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_application_1/features/auth/providers/auth_state.dart';
import 'package:flutter_application_1/features/auth/widgets/auth_shell.dart';
import 'package:flutter_application_1/core/utils/validators.dart';
import 'package:flutter_application_1/core/routing/app_router.dart';
import 'package:flutter_application_1/core/utils/logger.dart';
import 'package:flutter_application_1/core/design/components/ml_components.dart';

class ResetPasswordScreen extends ConsumerStatefulWidget {
  final String resetToken;

  const ResetPasswordScreen({super.key, required this.resetToken});

  @override
  ConsumerState<ResetPasswordScreen> createState() =>
      _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _logger = LoggerFactory.getLogger('ResetPasswordScreen');
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  bool _resetSuccess = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void initState() {
    super.initState();
    // Log the reset token for debugging
    _logger.d(
      'ResetPasswordScreen initialized with token: ${widget.resetToken}',
    );
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      _logger.d('Submitting password reset with token: ${widget.resetToken}');

      // Check if the token is valid
      if (widget.resetToken.isEmpty) {
        throw Exception(
          'Invalid reset token. Please request a new password reset link.',
        );
      }

      await ref
          .read(authStateProvider.notifier)
          .updatePassword(widget.resetToken, _passwordController.text);

      _logger.i('Password reset successful');
      if (mounted) {
        setState(() {
          _resetSuccess = true;
        });
      }
    } catch (e) {
      _logger.e('Error resetting password', e);

      // Format the error message for better user experience
      String errorMessage;
      if (e.toString().contains('Exception:')) {
        // Extract the message after "Exception:"
        errorMessage = e.toString().split('Exception:').last.trim();
      } else if (e.toString().contains('Invalid or expired')) {
        errorMessage =
            'Your password reset link has expired. Please request a new one.';
      } else if (e.toString().contains('Invalid token')) {
        errorMessage =
            'Invalid reset link. Please request a new password reset link.';
      } else {
        errorMessage =
            'An error occurred while resetting your password. Please try again or request a new reset link.';
      }

      if (mounted) {
        setState(() {
          _errorMessage = errorMessage;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthShell(
      title: _resetSuccess ? 'Password Updated' : 'Create New Password',
      subtitle: _resetSuccess
          ? 'Your password has been reset. You can sign in again now.'
          : 'Choose a strong password for your account.',
      showBackButton: true,
      onBack: () => AppRouter.router.go('/login'),
      child: _resetSuccess ? _buildSuccessMessage() : _buildForm(),
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: AutofillGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _passwordController,
              decoration: InputDecoration(
                labelText: 'New Password',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility_off : Icons.visibility,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscurePassword = !_obscurePassword;
                    });
                  },
                ),
              ),
              obscureText: _obscurePassword,
              validator: Validators.validatePassword,
              autofillHints: const [AutofillHints.newPassword],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _confirmPasswordController,
              decoration: InputDecoration(
                labelText: 'Confirm New Password',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureConfirmPassword
                        ? Icons.visibility_off
                        : Icons.visibility,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscureConfirmPassword = !_obscureConfirmPassword;
                    });
                  },
                ),
              ),
              obscureText: _obscureConfirmPassword,
              validator: (value) {
                if (value != _passwordController.text) {
                  return 'Passwords do not match';
                }
                return null;
              },
              autofillHints: const [AutofillHints.newPassword],
            ),
            const SizedBox(height: 24),
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                  children: [
                    Text(
                      _errorMessage!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    // If the error is about an invalid or expired token, show a button to request a new one
                    if (_errorMessage!.contains('expired') ||
                        _errorMessage!.contains('invalid') ||
                        _errorMessage!.contains('Invalid'))
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: TextButton(
                          onPressed: () =>
                              AppRouter.router.go('/forgot-password'),
                          child: const Text('Request New Reset Link'),
                        ),
                      ),
                  ],
                ),
              ),
            MlButton.primary(
              label: _isLoading ? 'Resetting…' : 'Reset Password',
              expand: true,
              onPressed: _isLoading ? null : _submit,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuccessMessage() {
    final semantic = MlSemantic.of(context);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const MlIconWell(
          icon: Icons.check_circle_outline,
          tone: MlTone.done,
          size: 64,
        ),
        const SizedBox(height: 16),
        Text(
          'Your password has been reset successfully. You can now log in with your new password.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: MlTokens.fontSans,
            fontSize: MlTokens.fsBody,
            height: 1.5,
            color: semantic.textBody,
          ),
        ),
        const SizedBox(height: 24),
        MlButton.primary(
          label: 'Go to Login',
          expand: true,
          onPressed: () => AppRouter.router.go('/login'),
        ),
      ],
    );
  }
}
