import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_application_1/core/config/supabase_config.dart';
import 'package:flutter_application_1/core/routing/app_router.dart';
import 'package:flutter_application_1/core/utils/auth_error_message.dart';
import 'package:flutter_application_1/core/utils/validators.dart';
import 'package:flutter_application_1/features/portal/widgets/ml/ml.dart';

/// Shown after login when `profiles.must_change_password` is true (platform-registered company).
class MandatoryPasswordChangeScreen extends ConsumerStatefulWidget {
  const MandatoryPasswordChangeScreen({super.key});

  @override
  ConsumerState<MandatoryPasswordChangeScreen> createState() =>
      _MandatoryPasswordChangeScreenState();
}

class _MandatoryPasswordChangeScreenState
    extends ConsumerState<MandatoryPasswordChangeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _p1 = TextEditingController();
  final _p2 = TextEditingController();
  bool _obscure1 = true;
  bool _obscure2 = true;
  bool _busy = false;
  String? _inlineError;

  @override
  void dispose() {
    _p1.dispose();
    _p2.dispose();
    super.dispose();
  }

  String? _validateNewPassword(String? value) {
    final base = Validators.validatePassword(value);
    if (base != null) return base;
    if (value != null && value.length < 8) {
      return 'Use at least 8 characters for your new password';
    }
    return null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_p1.text != _p2.text) {
      setState(() => _inlineError = 'Passwords do not match.');
      return;
    }

    setState(() {
      _busy = true;
      _inlineError = null;
    });
    try {
      final user = SupabaseConfig.client.auth.currentUser;
      if (user == null) {
        if (mounted) context.go('/login');
        return;
      }

      await SupabaseConfig.client.auth.updateUser(
        UserAttributes(password: _p1.text),
      );

      try {
        await SupabaseConfig.client.from('profiles').update({
          'must_change_password': false,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        }).eq('id', user.id);
      } catch (_) {
        await SupabaseConfig.client.rpc('clear_must_change_password_for_self');
      }

      AppRouter.clearProfileGateCache();
      await SupabaseConfig.client.auth.refreshSession();

      if (!mounted) return;
      context.go('/home');
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _inlineError = authErrorMessage(e));
    } catch (e) {
      if (!mounted) return;
      setState(() => _inlineError = authErrorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final semantic = MlSemantic.of(context);
    final errTone = MlTone.error.colors(Theme.of(context).brightness);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Center(
                      child: MlIconWell(
                        icon: Icons.lock_reset_rounded,
                        tone: MlTone.accent,
                        size: 64,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Set a new password',
                      style: TextStyle(
                        fontFamily: MlTokens.fontSans,
                        fontSize: MlTokens.fsH2,
                        fontWeight: FontWeight.w800,
                        color: semantic.textStrong,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Your company account was created by a platform administrator. '
                      'You signed in with a temporary password — now choose a personal password '
                      'you will use from now on.',
                      style: TextStyle(
                        fontFamily: MlTokens.fontSans,
                        color: semantic.textMuted,
                        height: 1.45,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Container(
                      decoration: BoxDecoration(
                        color: MlTone.accent.well(Theme.of(context).brightness),
                        borderRadius: BorderRadius.circular(MlTokens.rMd),
                        border: Border.all(color: semantic.borderAccent),
                      ),
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.info_outline, size: 20, color: MlTokens.accent),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Your new password must be different from the temporary password '
                              'you just used to sign in.',
                              style: TextStyle(
                                fontFamily: MlTokens.fontSans,
                                fontSize: 13,
                                height: 1.4,
                                color: semantic.textBody,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_inlineError != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        decoration: BoxDecoration(
                          color: errTone.bg,
                          borderRadius: BorderRadius.circular(MlTokens.rMd),
                          border: Border.all(
                            color: errTone.fg.withValues(alpha: 0.3),
                          ),
                        ),
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          _inlineError!,
                          style: TextStyle(
                            fontFamily: MlTokens.fontSans,
                            color: errTone.fg,
                            fontSize: 13,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _p1,
                      obscureText: _obscure1,
                      decoration: InputDecoration(
                        labelText: 'New password',
                        helperText: 'At least 8 characters, not your temporary password',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(_obscure1 ? Icons.visibility_off : Icons.visibility),
                          onPressed: () => setState(() => _obscure1 = !_obscure1),
                        ),
                      ),
                      validator: _validateNewPassword,
                      enabled: !_busy,
                      onChanged: (_) {
                        if (_inlineError != null) setState(() => _inlineError = null);
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _p2,
                      obscureText: _obscure2,
                      decoration: InputDecoration(
                        labelText: 'Confirm new password',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(_obscure2 ? Icons.visibility_off : Icons.visibility),
                          onPressed: () => setState(() => _obscure2 = !_obscure2),
                        ),
                      ),
                      validator: _validateNewPassword,
                      enabled: !_busy,
                      onChanged: (_) {
                        if (_inlineError != null) setState(() => _inlineError = null);
                      },
                    ),
                    const SizedBox(height: 28),
                    MlButton.primary(
                      label: _busy ? 'Saving…' : 'Continue',
                      expand: true,
                      onPressed: _busy ? null : _submit,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
