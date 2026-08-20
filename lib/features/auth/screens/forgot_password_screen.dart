import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_application_1/core/utils/friendly_error.dart';
import 'package:flutter_application_1/features/auth/providers/auth_state.dart';
import 'package:flutter_application_1/features/auth/widgets/auth_shell.dart';
import 'package:flutter_application_1/core/utils/validators.dart';
import 'package:flutter_application_1/core/routing/app_router.dart';
import 'package:flutter_application_1/core/design/components/ml_components.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  bool _emailSent = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await ref
          .read(authStateProvider.notifier)
          .resetPassword(_emailController.text);
      if (mounted) {
        setState(() {
          _emailSent = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          // Was `e.toString()`, verbatim. Driving the app while the auth service
          // was unreachable put **"Exception: The operation timed out. Please
          // try again."** on screen — the Dart prefix and all, on the recovery
          // screen somebody reaches when they are already stuck.
          //
          // `friendlyError` never echoes its input: every branch returns a fixed
          // sentence, so nothing a server says can reach the page through here.
          _errorMessage = friendlyError(e);
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
      title: _emailSent ? 'Check Your Email' : 'Forgot Password?',
      subtitle: _emailSent
          ? 'We sent a secure reset link to your email address.'
          : 'Enter the email address linked to your account and we’ll send you password reset instructions.',
      showBackButton: true,
      onBack: () {
        if (AppRouter.router.canPop()) {
          AppRouter.router.pop();
        } else {
          AppRouter.router.go('/login');
        }
      },
      child: _emailSent ? _buildSuccessMessage() : _buildForm(),
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
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Email',
                prefixIcon: Icon(Icons.email_outlined),
              ),
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.done,
              autocorrect: false,
              enableSuggestions: false,
              onFieldSubmitted: (_) => _submit(),
              validator: Validators.validateEmail,
              // Add autofill hints for email
              autofillHints: const [
                AutofillHints.email,
                AutofillHints.username,
              ],
            ),
            const SizedBox(height: 16),
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  _errorMessage!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                  textAlign: TextAlign.center,
                ),
              ),
            MlButton.primary(
              label: _isLoading ? 'Sending…' : 'Send Reset Instructions',
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
          icon: Icons.mark_email_read_outlined,
          tone: MlTone.done,
          size: 64,
        ),
        const SizedBox(height: 16),
        Text(
          'We\'ve sent password reset instructions to your email address. Click the link in the email to set a new password.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: MlTokens.fontSans,
            fontSize: MlTokens.fsBody,
            height: 1.5,
            color: semantic.textBody,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'If you don\'t see the email, check your spam folder or try again.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: MlTokens.fontSans,
            fontSize: MlTokens.fsBodySm,
            color: semantic.textMuted,
          ),
        ),
        const SizedBox(height: 24),
        MlButton.primary(
          label: 'Return to Login',
          expand: true,
          onPressed: () => AppRouter.router.go('/login'),
        ),
      ],
    );
  }
}
