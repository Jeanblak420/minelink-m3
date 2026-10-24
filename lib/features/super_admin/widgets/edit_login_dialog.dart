import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter_application_1/core/design/components/ml_components.dart';
import 'package:flutter_application_1/core/design/tokens/m3/ml_typography.dart';
import 'package:flutter_application_1/core/utils/friendly_error.dart';
import 'package:flutter_application_1/features/super_admin/providers/super_admin_providers.dart';

/// Only the fields the admin actually changed; `null` means "leave as is".
typedef LoginEdit = ({String? password, String? email, String? phone});

/// Opens [EditLoginDialog] for one user and saves through
/// `SuperAdminRepository.updateUserCredentials` (the `admin-update-user` edge
/// function, which re-checks `is_platform_admin()` server-side and audits the
/// change). Reports the outcome in a snackbar; [onSaved] runs after a
/// successful save so the caller can refresh its data.
///
/// Shared by every place a super global admin can reach a person — the
/// company page's Users list and account-owner section, and the employee
/// profile — so there is one dialog and one save path, not three.
Future<void> showAdminEditLogin(
  BuildContext context,
  WidgetRef ref, {
  required String userId,
  required String name,
  String currentEmail = '',
  String currentPhone = '',
  bool whatsappOnly = false,
  VoidCallback? onSaved,
}) async {
  final who = name.trim().isEmpty ? 'this user' : name.trim();
  final edit = await showDialog<LoginEdit>(
    context: context,
    builder: (dialogContext) => EditLoginDialog(
      name: who,
      currentEmail: whatsappOnly ? '' : currentEmail,
      currentPhone: currentPhone,
      whatsappOnly: whatsappOnly,
    ),
  );
  if (edit == null || !context.mounted) return;
  // The round trip can take several seconds (edge-function cold start), and
  // the dialog has already closed — say something is happening.
  final messenger = ScaffoldMessenger.of(context);
  messenger.showSnackBar(SnackBar(
    content: Text('Saving login details for $who…'),
    duration: const Duration(minutes: 1),
  ));
  try {
    final changed = await ref.read(superAdminRepositoryProvider).updateUserCredentials(
          userId: userId,
          password: edit.password,
          email: edit.email,
          phone: edit.phone,
        );
    onSaved?.call();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(changed.isEmpty
            ? 'Nothing changed for $who'
            : 'Updated ${changed.join(', ')} for $who'),
      ));
  } catch (e) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text('Could not update $who: ${friendlyError(e)}'),
        backgroundColor: MlTokens.red600,
      ));
  }
}

/// Super-admin dialog to change one user's password, email and/or phone.
///
/// Email and phone start filled in with the current values; the password
/// fields start empty and an empty password means "keep the current one".
///
/// A WhatsApp-only account ([whatsappOnly]) has no real email — its login
/// email is a synthetic `wa-…@wa.mineralguide.com` derived from the number,
/// which the edge function moves along with the number. Showing that address
/// as an editable field would invite somebody to "correct" it, so the field is
/// hidden and the dialog says how the user signs in instead.
///
/// The dialog pops with its own context, never the caller's: the console is a
/// GoRouter `ShellRoute`, so popping with the screen's context removes the
/// PAGE (see `test/widgets/dialog_pops_the_dialog_test.dart`).
class EditLoginDialog extends StatefulWidget {
  final String name;
  final String currentEmail;
  final String currentPhone;
  final bool whatsappOnly;
  const EditLoginDialog({
    super.key,
    required this.name,
    required this.currentEmail,
    required this.currentPhone,
    this.whatsappOnly = false,
  });

  @override
  State<EditLoginDialog> createState() => _EditLoginDialogState();
}

class _EditLoginDialogState extends State<EditLoginDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _email = TextEditingController(text: widget.currentEmail);
  late final _phone = TextEditingController(text: widget.currentPhone);
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _passwordFocus = FocusNode();
  final _confirmFocus = FocusNode();
  bool _showPassword = false;

  @override
  void dispose() {
    _email.dispose();
    _phone.dispose();
    _password.dispose();
    _confirm.dispose();
    _passwordFocus.dispose();
    _confirmFocus.dispose();
    super.dispose();
  }

  void _submit(BuildContext dialogContext) {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final email = _email.text.trim();
    final phone = _phone.text.trim();
    final password = _password.text;
    final edit = (
      password: password.isEmpty ? null : password,
      email: widget.whatsappOnly ||
              email.isEmpty ||
              email.toLowerCase() == widget.currentEmail.toLowerCase()
          ? null
          : email,
      phone: phone.isEmpty || phone == widget.currentPhone ? null : phone,
    );
    if (edit.password == null && edit.email == null && edit.phone == null) {
      Navigator.pop(dialogContext);
      return;
    }
    Navigator.pop(dialogContext, edit);
  }

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return AlertDialog(
      title: Text('Login details for ${widget.name}'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  widget.whatsappOnly
                      ? 'This account signs in with its WhatsApp number and a '
                          'password. Change either here. Fields you leave as '
                          'they are stay unchanged. The user is not notified — '
                          'tell them their new details yourself.'
                      : 'Change any of these. Fields you leave as they are stay '
                          'unchanged. The user is not notified — tell them '
                          'their new details yourself.',
                  style: context.mlText.bodyMedium.copyWith(color: muted),
                ),
                const SizedBox(height: 16),
                if (!widget.whatsappOnly) ...[
                  TextFormField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    autocorrect: false,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.alternate_email_rounded),
                    ),
                    validator: (v) {
                      final t = v?.trim() ?? '';
                      if (t.isEmpty) return null;
                      return RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(t)
                          ? null
                          : 'Enter a valid email address';
                    },
                  ),
                  const SizedBox(height: 12),
                ],
                TextFormField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  onFieldSubmitted: (_) => _passwordFocus.requestFocus(),
                  decoration: const InputDecoration(
                    labelText: 'Phone / WhatsApp number',
                    hintText: 'e.g. 082 123 4567',
                    prefixIcon: Icon(Icons.phone_rounded),
                  ),
                  validator: (v) {
                    final digits = (v ?? '').replaceAll(RegExp(r'\D'), '');
                    if (digits.isEmpty) return null;
                    return digits.length >= 9 ? null : 'Enter a valid phone number';
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _password,
                  focusNode: _passwordFocus,
                  obscureText: !_showPassword,
                  // On a phone the keyboard hides the Confirm field once it
                  // opens (found resetting a password on a Galaxy S25 Ultra,
                  // 2026-10-24): Next moves there, and scrolls it into view.
                  // Explicitly — the default "next" lands on the show-password
                  // eye, which sits between the two fields.
                  textInputAction: TextInputAction.next,
                  onFieldSubmitted: (_) => _confirmFocus.requestFocus(),
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: InputDecoration(
                    labelText: 'New password',
                    helperText: 'Leave empty to keep the current password',
                    // One line ellipsised it to "…the current pass…" at phone
                    // width (seen on the emulator, 2026-10-22).
                    helperMaxLines: 2,
                    prefixIcon: const Icon(Icons.lock_reset_rounded),
                    suffixIcon: IconButton(
                      tooltip: _showPassword ? 'Hide password' : 'Show password',
                      icon: Icon(_showPassword ? Icons.visibility_off_rounded : Icons.visibility_rounded),
                      onPressed: () => setState(() => _showPassword = !_showPassword),
                    ),
                  ),
                  validator: (v) {
                    final t = v ?? '';
                    if (t.isEmpty) return null;
                    return t.length >= 6 ? null : 'At least 6 characters';
                  },
                ),
                const SizedBox(height: 12),
                Builder(
                  builder: (dialogContext) => TextFormField(
                  controller: _confirm,
                  focusNode: _confirmFocus,
                  obscureText: !_showPassword,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _submit(dialogContext),
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: const InputDecoration(
                    labelText: 'Confirm new password',
                    prefixIcon: Icon(Icons.lock_outline_rounded),
                  ),
                  validator: (v) =>
                      (v ?? '') == _password.text ? null : 'Passwords do not match',
                ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        Builder(
          builder: (dialogContext) => TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
        ),
        Builder(
          builder: (dialogContext) => FilledButton(
            onPressed: () => _submit(dialogContext),
            child: const Text('Save changes'),
          ),
        ),
      ],
    );
  }
}
