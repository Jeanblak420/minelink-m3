import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_application_1/core/config/supabase_config.dart';
import 'package:flutter_application_1/core/utils/validators.dart';
import 'package:flutter_application_1/core/utils/friendly_error.dart';

/// Voluntary password change for any signed-in user with an email + password identity.
///
/// Verifies the current password via [signInWithPassword], then applies [updateUser].
class ChangePasswordSection extends StatefulWidget {
  const ChangePasswordSection({super.key});

  @override
  State<ChangePasswordSection> createState() => _ChangePasswordSectionState();
}

class _ChangePasswordSectionState extends State<ChangePasswordSection> {
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

    final email = SupabaseConfig.client.auth.currentUser?.email?.trim();
    if (email == null || email.isEmpty) {
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
    final email = SupabaseConfig.client.auth.currentUser?.email?.trim();
    if (email == null || email.isEmpty) {
      return const SizedBox.shrink();
    }

    final cs = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: cs.outlineVariant.withAlpha(180)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.lock_outline_rounded, color: cs.primary),
                  const SizedBox(width: 10),
                  Text(
                    'Change password',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'For $email — enter your current password, then choose a new one.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
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
      ),
    );
  }
}
