import 'package:flutter/material.dart';
import 'package:flutter_application_1/core/utils/dialog_utils.dart';
import 'package:flutter_application_1/core/widgets/m3_dropdown_field.dart';
import 'package:flutter_application_1/features/auth/models/user_type.dart';
import 'package:flutter_application_1/features/auth/utils/whatsapp_identity.dart';
import 'package:flutter_application_1/features/employee/models/employee_model.dart';

class CompanyEmployeeFormResult {
  final String email;
  final String password;
  final String firstName;
  final String lastName;
  final String whatsappNumber;
  final UserRole role;

  const CompanyEmployeeFormResult({
    this.email = '',
    this.password = '',
    required this.firstName,
    required this.lastName,
    required this.whatsappNumber,
    required this.role,
  });
}

class CompanyEmployeeFormDialog extends StatefulWidget {
  final OrgType orgType;
  final Employee? employee;

  const CompanyEmployeeFormDialog({
    super.key,
    required this.orgType,
    this.employee,
  });

  bool get isCreateMode => employee == null;

  @override
  State<CompanyEmployeeFormDialog> createState() =>
      _CompanyEmployeeFormDialogState();
}

class _CompanyEmployeeFormDialogState extends State<CompanyEmployeeFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _passwordController;
  late final TextEditingController _firstNameController;
  late final TextEditingController _lastNameController;
  late final TextEditingController _whatsappController;
  late UserRole _selectedRole;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    final employee = widget.employee;

    _passwordController = TextEditingController();
    _firstNameController = TextEditingController(
      text: employee?.firstName ?? '',
    );
    _lastNameController = TextEditingController(text: employee?.lastName ?? '');
    _whatsappController = TextEditingController(
      text: employee?.whatsappNumber ?? '',
    );

    _selectedRole =
        employee?.role ?? UserRole.getDefaultRoleForOrgType(widget.orgType);
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _whatsappController.dispose();
    super.dispose();
  }

  void _submit() {
    final formState = _formKey.currentState;
    if (formState == null || !formState.validate()) {
      return;
    }

    final whatsappNumber = _whatsappController.text.trim();
    Navigator.of(context).pop(
      CompanyEmployeeFormResult(
        // No email is collected: admin-created users are identified by their
        // WhatsApp number. A deterministic synthetic email is derived from it
        // so the existing auth-user creation keeps working until WhatsApp OTP
        // login lands. See whatsapp_identity.dart.
        email: whatsappAuthEmail(whatsappNumber),
        password: _passwordController.text,
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        whatsappNumber: whatsappNumber,
        role: _selectedRole,
      ),
    );
  }

  String? _validateWhatsapp(String? value) {
    final raw = value?.trim() ?? '';
    if (raw.isEmpty) {
      return 'WhatsApp number is required';
    }
    if (normalizeWhatsappNumber(raw).length < 6) {
      return 'Enter a valid WhatsApp number';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (!widget.isCreateMode) {
      return null;
    }

    if ((value ?? '').length < 6) {
      return 'Password must be at least 6 characters';
    }

    return null;
  }

  String? _validateRequired(String? value, String fieldName) {
    if ((value ?? '').trim().isEmpty) {
      return '$fieldName is required';
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final roles = UserRole.getRolesForOrgType(widget.orgType);

    return AlertDialog(
      // Material spends 40px a side on dialog margin plus 24px of content
      // padding, which leaves a 320px phone 192px of form — and every field
      // here also carries a prefixIcon worth ~48px more. Measured 2026-08-18:
      // "WhatsApp Number" was ellipsised at 320px at the SMALLEST text size the
      // app offers, and "First Name" / "Last Name" went at the largest.
      insetPadding: DialogUtils.adaptiveInsetPadding(context),
      contentPadding: DialogUtils.adaptiveContentPadding(context),
      title: Text(widget.isCreateMode ? 'Add User' : 'Edit User'),
      content: SizedBox(
        width: DialogUtils.contentMaxWidth(context, maxWidth: 420),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _whatsappController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    // Short label, detail in helper text: a floating
                    // InputDecoration label is always one line and always
                    // ellipsises, so a long one is simply unreadable on a
                    // phone. Helper text wraps.
                    labelText: 'WhatsApp',
                    helperText: 'Mobile number',
                    helperMaxLines: 2,
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                  validator: _validateWhatsapp,
                ),
                const SizedBox(height: 12),
                if (widget.isCreateMode) ...[
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                      ),
                    ),
                    validator: _validatePassword,
                  ),
                  const SizedBox(height: 12),
                ],
                TextFormField(
                  controller: _firstNameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'First Name',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  validator: (value) => _validateRequired(value, 'First name'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _lastNameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Last Name',
                    prefixIcon: Icon(Icons.badge_outlined),
                  ),
                  validator: (value) => _validateRequired(value, 'Last name'),
                ),
                const SizedBox(height: 12),
                M3DropdownField<UserRole>(
                  initialValue: _selectedRole,
                  label: 'Role',
                  leadingIcon: const Icon(
                    Icons.admin_panel_settings_outlined,
                  ),
                  entries: roles.map((role) {
                    return DropdownMenuEntry<UserRole>(
                      value: role,
                      label: role.label,
                    );
                  }).toList(),
                  onSelected: (value) {
                    if (value != null) {
                      setState(() {
                        _selectedRole = value;
                      });
                    }
                  },
                  validator: (value) =>
                      value == null ? 'Role is required' : null,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(widget.isCreateMode ? 'Create User' : 'Save Changes'),
        ),
      ],
    );
  }
}
