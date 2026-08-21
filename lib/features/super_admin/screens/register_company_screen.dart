import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_application_1/core/config/supabase_config.dart';
import 'package:flutter_application_1/core/utils/safe_ref.dart';
import 'package:flutter_application_1/core/utils/validators.dart';
import 'package:flutter_application_1/features/auth/models/user_type.dart';
import 'package:flutter_application_1/features/super_admin/providers/super_admin_providers.dart';
import 'package:flutter_application_1/features/super_admin/utils/edge_function_errors.dart';
import 'package:flutter_application_1/core/design/components/ml_components.dart';
import 'package:flutter_application_1/core/utils/friendly_error.dart';

/// Register a new company (auth user + company row) as platform admin, then continue with token/seats on org detail.
class RegisterCompanyScreen extends ConsumerStatefulWidget {
  const RegisterCompanyScreen({super.key});

  @override
  ConsumerState<RegisterCompanyScreen> createState() => _RegisterCompanyScreenState();
}

class _RegisterCompanyScreenState extends ConsumerState<RegisterCompanyScreen> {
  final _formKey = GlobalKey<FormState>();
  final _companyName = TextEditingController();
  final _whatsapp = TextEditingController();
  final _ceoFirst = TextEditingController();
  final _ceoLast = TextEditingController();
  final _email = TextEditingController();
  final _tempPassword = TextEditingController();
  OrgType _orgType = OrgType.mineSupplier;
  bool _busy = false;
  bool _genPassword = true;

  @override
  void dispose() {
    _companyName.dispose();
    _whatsapp.dispose();
    _ceoFirst.dispose();
    _ceoLast.dispose();
    _email.dispose();
    _tempPassword.dispose();
    super.dispose();
  }

  Future<void> _submit(bool allowed) async {
    if (!_formKey.currentState!.validate()) return;
    if (!allowed) return;

    setState(() => _busy = true);
    try {
      final body = <String, dynamic>{
        'company_name': _companyName.text.trim(),
        'whatsapp_number': _whatsapp.text.trim(),
        'org_type': _orgType.name,
        'ceo_first_name': _ceoFirst.text.trim(),
        'ceo_last_name': _ceoLast.text.trim(),
        'owner_email': _email.text.trim().toLowerCase(),
      };
      if (!_genPassword && _tempPassword.text.trim().isNotEmpty) {
        body['temporary_password'] = _tempPassword.text.trim();
      }

      final res = await SupabaseConfig.client.functions.invoke(
        'super-admin-create-company',
        body: body,
      );

      final data = res.data;
      if (data is! Map) {
        throw Exception('Unexpected response');
      }
      final map = Map<String, dynamic>.from(data);
      if (map['error'] != null) {
        throw Exception(map['error'].toString());
      }
      if (map['success'] != true) {
        throw Exception('Registration failed');
      }

      final companyId = map['company_id'] as String?;
      final companyName = map['company_name'] as String? ?? '';
      final ownerEmail = map['owner_email'] as String? ?? '';
      final tempPwd = map['temporary_password'] as String? ?? '';

      if (!mounted || companyId == null) return;

      await _showHandoffDialog(
        context: context,
        companyName: companyName,
        ownerEmail: ownerEmail,
        temporaryPassword: tempPwd,
        companyId: companyId,
      );

      ref.invalidateIfMounted(organizationsProvider);
      ref.invalidateIfMounted(organizationsGroupedProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(edgeFunctionErrorMessage(e)),
            backgroundColor: MlTokens.red600,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _showHandoffDialog({
    required BuildContext context,
    required String companyName,
    required String ownerEmail,
    required String temporaryPassword,
    required String companyId,
  }) async {
    final message = StringBuffer()
      ..writeln('Welcome — your company account is ready.')
      ..writeln()
      ..writeln('Company: $companyName')
      ..writeln('Login email: $ownerEmail')
      ..writeln('Temporary password: $temporaryPassword')
      ..writeln()
      ..writeln('Sign in with the MineLink app using the email and password above.')
      ..writeln()
      ..writeln('On first sign-in you will be asked to set a new password.')
      ..writeln('That password must be different from this temporary one.')
      ..writeln('Your platform administrator will activate your subscription (token & seats) next.');

    final text = message.toString();

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Company registered'),
        content: SingleChildScrollView(
          child: SelectableText(text, style: const TextStyle(fontSize: 13, height: 1.4)),
        ),
        actions: [
          OutlinedButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: text));
              if (ctx.mounted) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('Message copied to clipboard')),
                );
              }
            },
            icon: const Icon(Icons.copy_rounded),
            label: const Text('Copy message'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              context.go('/super-admin/organization/$companyId');
            },
            child: const Text('Open company (token & seats)'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final roleAsync = ref.watch(currentPlatformRoleProvider);

    // Every super global admin has full rights, including registering companies.
    final allowed = roleAsync.maybeWhen(
      data: (role) => role.isSuperAdmin,
      orElse: () => false,
    );

    return roleAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => MlEmptyState(
        icon: Icons.error_outline,
        title: 'Could not load',
        message: friendlyError(e),
      ),
      data: (_) {
        if (!allowed) {
          return const MlEmptyState(
            icon: Icons.lock_outline,
            title: 'Permission required',
            message:
                'You do not have permission to register new companies. Only the platform super admins can register companies.',
          );
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => context.go('/super-admin'),
                    icon: const Icon(Icons.arrow_back_rounded, size: 18),
                    label: const Text('Back to console'),
                  ),
                ),
                // A HEADING. This page opened with a back link and then a
                // sentence in third person — the only console screen with no
                // title on it at all. Photographed 2026-08-21. `MlPageHeader`
                // is what every other one uses, and the sentence is its
                // description rather than a stray paragraph.
                MlPageHeader(
                  title: 'Register a company',
                  description:
                      'Creates a company login. After this, open the company '
                      'to generate a serial token, set seats, and validity '
                      'days.',
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _companyName,
                  decoration: const InputDecoration(
                    labelText: 'Company name',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                  enabled: !_busy,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _whatsapp,
                  decoration: const InputDecoration(
                    labelText: 'WhatsApp number',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                  enabled: !_busy,
                ),
                const SizedBox(height: 12),
                InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Organization type',
                    border: OutlineInputBorder(),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<OrgType>(
                      value: _orgType,
                      isExpanded: true,
                      items: OrgType.values
                          .map(
                            (o) => DropdownMenuItem(
                              value: o,
                              child: Text(o.label),
                            ),
                          )
                          .toList(),
                      onChanged: _busy
                          ? null
                          : (v) {
                              if (v != null) setState(() => _orgType = v);
                            },
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _ceoFirst,
                        decoration: const InputDecoration(
                          labelText: 'CEO first name',
                          border: OutlineInputBorder(),
                        ),
                        enabled: !_busy,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _ceoLast,
                        decoration: const InputDecoration(
                          labelText: 'CEO last name',
                          border: OutlineInputBorder(),
                        ),
                        enabled: !_busy,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _email,
                  decoration: const InputDecoration(
                    labelText: 'Owner login email',
                    border: OutlineInputBorder(),
                    helperText: 'The company signs in with this email',
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: Validators.validateEmail,
                  enabled: !_busy,
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  title: const Text('Generate temporary password'),
                  subtitle: const Text('Turn off to set your own (min. 8 characters)'),
                  value: _genPassword,
                  onChanged: _busy
                      ? null
                      : (v) => setState(() {
                          _genPassword = v;
                        }),
                ),
                if (!_genPassword)
                  TextFormField(
                    controller: _tempPassword,
                    decoration: const InputDecoration(
                      labelText: 'Temporary password',
                      border: OutlineInputBorder(),
                    ),
                    obscureText: true,
                    validator: (v) {
                      if (_genPassword) return null;
                      if (v == null || v.length < 8) {
                        return 'At least 8 characters';
                      }
                      return null;
                    },
                    enabled: !_busy,
                  ),
                const SizedBox(height: 24),
                MlButton.primary(
                  label: _busy ? 'Creating…' : 'Create company account',
                  expand: true,
                  onPressed: _busy ? null : () => _submit(allowed),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
