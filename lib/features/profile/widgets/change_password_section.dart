import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_application_1/core/config/supabase_config.dart';
import 'package:flutter_application_1/core/design/components/ml_components.dart';
import 'package:flutter_application_1/core/utils/validators.dart';
import 'package:flutter_application_1/core/utils/friendly_error.dart';
import 'package:flutter_application_1/features/profile/providers/account_email_provider.dart';

/// Voluntary password change for any signed-in user with an email + password identity.
///
/// Verifies the current password via [signInWithPassword], then applies [updateUser].
///
/// ## It watches [accountEmailProvider], and that is the whole point
///
/// This widget decides whether to exist at all from the account's email — no
/// email, no password identity, nothing to change. It used to read that from
/// `SupabaseConfig.client.auth.currentUser` **inside its own `build`**, which
/// is the exact call `accountEmailProvider` was created to remove from
/// `AccountSecurityScreen`. The screen was fixed and the section it delegates
/// to was not, so the two disagreed about the same question from two different
/// sources — and because a global singleton cannot be overridden, THE ONLY
/// PASSWORD-CHANGE UI IN THE PRODUCT rendered `SizedBox.shrink()` in every
/// test and every render that has ever existed. Photographed 2026-08-21: the
/// account-security page opened on a signature card, and nobody could tell
/// from the picture that a card was missing.
class ChangePasswordSection extends ConsumerStatefulWidget {
  const ChangePasswordSection({super.key});

  @override
  ConsumerState<ChangePasswordSection> createState() =>
      _ChangePasswordSectionState();
}

class _ChangePasswordSectionState extends ConsumerState<ChangePasswordSection> {
  final _formKey = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  bool _obscureCurrent = true;
  bool _obscureNext = true;
  bool _obscureConfirm = true;
  bool _busy = false;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_next.text != _confirm.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('New password and confirmation do not match')),
      );
      return;
    }
    if (_current.text == _next.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('New password must be different from your current password')),
      );
      return;
    }

    final email = ref.read(accountEmailProvider);
    if (email == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No email address on this session — password change is unavailable.')),
      );
      return;
    }

    final messenger = ScaffoldMessenger.maybeOf(context);
    setState(() => _busy = true);
    try {
      await SupabaseConfig.client.auth.signInWithPassword(
        email: email,
        password: _current.text,
      );
      await SupabaseConfig.client.auth.updateUser(
        UserAttributes(password: _next.text),
      );
      await SupabaseConfig.client.auth.refreshSession();

      if (!mounted) return;
      _current.clear();
      _next.clear();
      _confirm.clear();
      messenger?.clearSnackBars();
      messenger?.showSnackBar(
        const SnackBar(content: Text('Password updated successfully')),
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      messenger?.clearSnackBars();
      messenger?.showSnackBar(
        SnackBar(content: Text(e.message.isNotEmpty ? e.message : 'Could not update password')),
      );
    } catch (e) {
      if (!mounted) return;
      messenger?.clearSnackBars();
      messenger?.showSnackBar(
        SnackBar(content: Text('Could not update password. ${friendlyError(e)}')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = ref.watch(accountEmailProvider);
    if (email == null) {
      return const SizedBox.shrink();
    }

    // `MlCard` + `MlSectionTitle`, like the two cards it sits between.
    //
    // It was a Material `Card` with a hand-built icon-and-`titleMedium` row, so
    // on the account & security page the password card had a different
    // background, a different border and a heading in a different TYPEFACE from
    // the Signature and Deactivate cards directly under it — three cards, two
    // design languages. Nobody had seen that, because until the same day this
    // widget never rendered at all (see the class comment).
    return MlCard(
      padding: const EdgeInsets.all(20),
      child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              MlSectionTitle(
                'Change password',
                icon: Icons.lock_outline_rounded,
                subtitle: 'For $email — enter your current password, then '
                    'choose a new one.',
                margin: EdgeInsets.zero,
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _current,
                obscureText: _obscureCurrent,
                enabled: !_busy,
                decoration: InputDecoration(
                  labelText: 'Current password',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.password_rounded),
                  suffixIcon: IconButton(
                    tooltip: _obscureCurrent ? 'Show' : 'Hide',
                    icon: Icon(_obscureCurrent ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                    onPressed: () => setState(() => _obscureCurrent = !_obscureCurrent),
                  ),
                ),
                validator: Validators.validatePassword,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _next,
                obscureText: _obscureNext,
                enabled: !_busy,
                decoration: InputDecoration(
                  labelText: 'New password',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.lock_reset_rounded),
                  suffixIcon: IconButton(
                    tooltip: _obscureNext ? 'Show' : 'Hide',
                    icon: Icon(_obscureNext ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                    onPressed: () => setState(() => _obscureNext = !_obscureNext),
                  ),
                ),
                validator: Validators.validatePassword,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _confirm,
                obscureText: _obscureConfirm,
                enabled: !_busy,
                decoration: InputDecoration(
                  labelText: 'Confirm new password',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.check_circle_outline_rounded),
                  suffixIcon: IconButton(
                    tooltip: _obscureConfirm ? 'Show' : 'Hide',
                    icon: Icon(_obscureConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                    onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                  ),
                ),
                validator: Validators.validatePassword,
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _busy ? null : _submit,
                  child: _busy
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Update password'),
                ),
              ),
            ],
          ),
        ),
    );
  }
}
