import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter_application_1/core/design/components/ml_components.dart';
import 'package:flutter_application_1/core/design/tokens/m3/ml_typography.dart';
import 'package:flutter_application_1/core/utils/friendly_error.dart';
import 'package:flutter_application_1/features/super_admin/data/models/login_methods.dart';
import 'package:flutter_application_1/features/super_admin/providers/super_admin_providers.dart';

/// Opens [EditLoginDialog] for one user and saves through
/// `SuperAdminRepository.updateUserCredentials` (the `admin-update-user` edge
/// function, which re-checks `is_platform_admin()` server-side, refuses any
/// change that would leave the user no way to sign in, and audits it).
/// Reports the outcome in a snackbar; [onSaved] runs after a successful save
/// so the caller can refresh its data.
///
/// The user's methods are read from the server when the dialog opens
/// (`admin_login_methods`), not taken from the caller: the email on a card is
/// `profiles.email` and the number is `employees.whatsapp_number`, and neither
/// is the truth about what someone can sign in with.
///
/// Shared by every place a super global admin can reach a person — the
/// company page's Users list and account-owner section, and the employee
/// profile — so there is one dialog and one save path.
Future<void> showAdminEditLogin(
  BuildContext context,
  WidgetRef ref, {
  required String userId,
  required String name,
  VoidCallback? onSaved,
}) async {
  final who = name.trim().isEmpty ? 'this user' : name.trim();
  final repo = ref.read(superAdminRepositoryProvider);
  // Started now, listened to by the dialog once it builds. `ignore()` keeps a
  // read that fails before then from surfacing as an unhandled error; the
  // dialog still receives the failure and says so.
  final methods = repo.getLoginMethods(userId)..ignore();
  final edit = await showDialog<LoginEdit>(
    context: context,
    builder: (dialogContext) => EditLoginDialog(name: who, methods: methods),
  );
  if (edit == null || edit.isEmpty || !context.mounted) return;
  // The round trip can take several seconds (edge-function cold start), and
  // the dialog has already closed — say something is happening.
  final messenger = ScaffoldMessenger.of(context);
  messenger.showSnackBar(SnackBar(
    content: Text('Saving login details for $who…'),
    duration: const Duration(minutes: 1),
  ));
  try {
    final changed = await repo.updateUserCredentials(
      userId: userId,
      password: edit.password,
      email: edit.email,
      phone: edit.phone,
      removeEmail: edit.removeEmail,
      removePhone: edit.removePhone,
      primary: edit.primary,
    );
    onSaved?.call();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(changed.isEmpty
            ? 'Nothing changed for $who'
            : 'Saved for $who: ${loginChangeSummary(changed)}'),
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

/// Super-admin dialog for one user's sign-in: which methods are on (email,
/// WhatsApp number — any or both), which one is primary, and the password
/// they share.
///
/// Rules the dialog holds (the server holds them too):
///   * at least one method stays on — the last one's switch cannot be turned
///     off;
///   * the primary is always a method that is on; switching the primary off
///     moves it to the other;
///   * an empty password means "keep the current one".
///
/// The dialog pops with its own context, never the caller's: the console is a
/// GoRouter `ShellRoute`, so popping with the screen's context removes the
/// PAGE (see `test/widgets/dialog_pops_the_dialog_test.dart`).
class EditLoginDialog extends StatefulWidget {
  final String name;
  final Future<LoginMethods> methods;
  const EditLoginDialog({super.key, required this.name, required this.methods});

  @override
  State<EditLoginDialog> createState() => _EditLoginDialogState();
}

class _EditLoginDialogState extends State<EditLoginDialog> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _passwordFocus = FocusNode();
  final _confirmFocus = FocusNode();
  bool _showPassword = false;

  LoginMethods? _loaded;
  Object? _loadError;
  bool _emailOn = false;
  bool _phoneOn = false;
  String _primary = 'email';

  @override
  void initState() {
    super.initState();
    widget.methods.then((m) {
      if (!mounted) return;
      setState(() {
        _loaded = m;
        _emailOn = m.hasEmail;
        _phoneOn = m.hasWhatsapp;
        _email.text = m.email ?? '';
        _phone.text = m.phone == null ? '' : localWhatsappNumber(m.phone!);
        _primary = m.primary;
      });
    }, onError: (Object e) {
      if (mounted) setState(() => _loadError = e);
    });
  }

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

  void _setEmailOn(bool on) => setState(() {
        _emailOn = on;
        if (!on && _primary == 'email') _primary = 'whatsapp';
        if (on && !_phoneOn) _primary = 'email';
      });

  void _setPhoneOn(bool on) => setState(() {
        _phoneOn = on;
        if (!on && _primary == 'whatsapp') _primary = 'email';
        if (on && !_emailOn) _primary = 'whatsapp';
      });

  static String _digits(String v) => v.replaceAll(RegExp(r'\D'), '');

  /// The same comparison the server makes: `0821234567` and `+27821234567`
  /// are one number.
  static String _e164(String v) {
    var d = _digits(v);
    if (d.startsWith('0')) d = '27${d.substring(1)}';
    return d;
  }

  void _submit(BuildContext dialogContext) {
    final m = _loaded;
    if (m == null) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final email = _email.text.trim();
    final phone = _phone.text.trim();
    final password = _password.text;

    final edit = LoginEdit(
      password: password.isEmpty ? null : password,
      email: _emailOn && email.toLowerCase() != (m.email ?? '').toLowerCase()
          ? email
          : null,
      removeEmail: !_emailOn && m.hasEmail,
      phone: _phoneOn && _e164(phone) != _e164(m.phone ?? '') ? phone : null,
      removePhone: !_phoneOn && m.phone != null,
      primary: _primary != m.primary ? _primary : null,
    );
    Navigator.pop(dialogContext, edit.isEmpty ? null : edit);
  }

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final m = _loaded;

    Widget content;
    if (_loadError != null) {
      content = Text(
        'Could not read their login details: ${friendlyError(_loadError!)}',
        style: context.mlText.bodyMedium
            .copyWith(color: Theme.of(context).colorScheme.error),
      );
    } else if (m == null) {
      content = const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(child: CircularProgressIndicator()),
      );
    } else {
      final onlyEmail = _emailOn && !_phoneOn;
      final onlyPhone = _phoneOn && !_emailOn;
      content = Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '${widget.name} signs in with any method switched on below, '
                'using one password. They are not notified — tell them '
                'their new details yourself.',
                style: context.mlText.bodyMedium.copyWith(color: muted),
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Sign in with email'),
                subtitle: onlyEmail
                    ? const Text('Their only way in — add WhatsApp to turn this off')
                    : null,
                value: _emailOn,
                onChanged: onlyEmail ? null : _setEmailOn,
              ),
              if (_emailOn) ...[
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
                    if (t.isEmpty) return 'Enter their email address';
                    if (t.toLowerCase().endsWith('@wa.mineralguide.com')) {
                      return 'That is an internal WhatsApp login address';
                    }
                    return RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(t)
                        ? null
                        : 'Enter a valid email address';
                  },
                ),
                const SizedBox(height: 8),
              ],
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Sign in with WhatsApp number'),
                subtitle: onlyPhone
                    ? const Text('Their only way in — add an email to turn this off')
                    : const Text('Number + password, or a WhatsApp code'),
                value: _phoneOn,
                onChanged: onlyPhone ? null : _setPhoneOn,
              ),
              if (_phoneOn) ...[
                TextFormField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  onFieldSubmitted: (_) => _passwordFocus.requestFocus(),
                  decoration: const InputDecoration(
                    labelText: 'WhatsApp number',
                    hintText: 'e.g. 082 123 4567',
                    prefixIcon: Icon(Icons.phone_rounded),
                  ),
                  validator: (v) => _digits(v ?? '').length >= 9
                      ? null
                      : 'Enter a valid phone number',
                ),
                const SizedBox(height: 8),
              ],
              if (_emailOn && _phoneOn) ...[
                const SizedBox(height: 8),
                Text('Primary sign-in', style: context.mlText.labelLarge),
                const SizedBox(height: 6),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                        value: 'email',
                        icon: Icon(Icons.alternate_email_rounded),
                        label: Text('Email')),
                    ButtonSegment(
                        value: 'whatsapp',
                        icon: Icon(Icons.phone_rounded),
                        label: Text('WhatsApp')),
                  ],
                  selected: {_primary},
                  onSelectionChanged: (s) => setState(() => _primary = s.first),
                ),
                const SizedBox(height: 4),
                Text(
                  'Primary is the one they are told to sign in with; the '
                  'other works just the same.',
                  style: context.mlText.bodySmall.copyWith(color: muted),
                ),
              ],
              const SizedBox(height: 16),
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
                    icon: Icon(_showPassword
                        ? Icons.visibility_off_rounded
                        : Icons.visibility_rounded),
                    onPressed: () =>
                        setState(() => _showPassword = !_showPassword),
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
                  validator: (v) => (v ?? '') == _password.text
                      ? null
                      : 'Passwords do not match',
                ),
              ),
            ],
          ),
        ),
      );
    }

    return AlertDialog(
      title: Text('Login for ${widget.name}'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: content,
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
            onPressed: m == null ? null : () => _submit(dialogContext),
            child: const Text('Save changes'),
          ),
        ),
      ],
    );
  }
}
