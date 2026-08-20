import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_application_1/core/config/supabase_config.dart';
import 'package:flutter_application_1/core/utils/safe_ref.dart';
import 'package:flutter_application_1/features/auth/providers/auth_state.dart';
import 'package:flutter_application_1/features/company/providers/company_provider.dart';
import 'package:flutter_application_1/features/employee/providers/employee_provider.dart';
import 'package:flutter_application_1/features/super_admin/providers/super_admin_providers.dart';
import 'package:flutter_application_1/features/super_admin/widgets/token_access_details.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:flutter_application_1/core/utils/platform_utils.dart';
import 'package:flutter_application_1/core/utils/image_provider_utils.dart';
import 'package:flutter_application_1/features/employee/widgets/document_upload_widget.dart';
import 'package:flutter_application_1/core/legal/legal_documents.dart';
import 'package:flutter_application_1/features/profile/widgets/change_password_section.dart';
import 'package:flutter_application_1/features/profile/widgets/company_token_requests_panel.dart';
import 'package:flutter_application_1/features/profile/widgets/deactivate_account_card.dart';
import 'package:flutter_application_1/features/profile/widgets/profile_signature_card.dart';
import 'package:flutter_application_1/features/portal/widgets/company_locations_section.dart';
import 'package:flutter_application_1/core/design/components/ml_components.dart';
import 'package:flutter_application_1/features/profile_setup/providers/profile_setup_provider.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_application_1/core/utils/friendly_error.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  Future<Map<String, dynamic>?>? _ownerProfileQuery;
  String? _ownerProfileForUserId;

  final _formKey = GlobalKey<FormState>();

  // Company controllers
  final _companyNameController = TextEditingController();
  final _companyWhatsappController = TextEditingController();
  final _ceoFirstNameController = TextEditingController();
  final _ceoLastNameController = TextEditingController();

  // Employee controllers
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _employeeWhatsappController = TextEditingController();
  final _idNumberController = TextEditingController();
  final _passportOrWorkersPermitController = TextEditingController();
  final _licenseDocumentController = TextEditingController();

  File? _imageFile;
  Uint8List? _webImageBytes;
  String? _fileName;
  final _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    // Use a post-frame callback to ensure the widget tree is built before accessing providers
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeControllers();
    });
  }

  @override
  void dispose() {
    _companyNameController.dispose();
    _companyWhatsappController.dispose();
    _ceoFirstNameController.dispose();
    _ceoLastNameController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _employeeWhatsappController.dispose();
    _idNumberController.dispose();
    _passportOrWorkersPermitController.dispose();
    _licenseDocumentController.dispose();
    super.dispose();
  }

  // Helper method to get the appropriate image provider for company profile
  ImageProvider? _getCompanyImageProvider(dynamic company) {
    if (_webImageBytes != null) {
      return MemoryImage(_webImageBytes!);
    } else if (_imageFile != null) {
      return FileImage(_imageFile!);
    } else if (company.logoUrl != null) {
      return imageProviderFromString(company.logoUrl);
    }
    return null;
  }

  // Helper method to get the appropriate image provider for employee profile
  ImageProvider? _getEmployeeImageProvider(dynamic employee) {
    if (_webImageBytes != null) {
      return MemoryImage(_webImageBytes!);
    } else if (_imageFile != null) {
      return FileImage(_imageFile!);
    } else if (employee.profilePhotoUrl != null) {
      return CachedNetworkImageProvider(employee.profilePhotoUrl!);
    }
    return null;
  }

  void _initializeControllers() {
    final authState = ref.read(authStateProvider);

    if (authState.userType?.isCompany == true) {
      final company = ref.read(companyProvider).company;
      if (company != null) {
        setState(() {
          _companyNameController.text = company.companyName;
          _companyWhatsappController.text = company.whatsappNumber;
          _ceoFirstNameController.text = company.ceoFirstName ?? '';
          _ceoLastNameController.text = company.ceoLastName ?? '';
        });
      }
    } else if (authState.userType?.isEmployee == true) {
      final employee = ref.read(employeeProvider).employee;
      if (employee != null) {
        setState(() {
          _firstNameController.text = employee.firstName;
          _lastNameController.text = employee.lastName;
          _employeeWhatsappController.text = employee.whatsappNumber;
          _idNumberController.text = employee.idNumber ?? '';
          _passportOrWorkersPermitController.text =
              employee.passportOrWorkersPermit ?? '';
          _licenseDocumentController.text = employee.licenseDocument ?? '';
        });
      }
    }
  }

  void _ensureOwnerProfileFuture(String userId) {
    if (_ownerProfileForUserId != userId) {
      _ownerProfileForUserId = userId;
      _ownerProfileQuery = SupabaseConfig.client
          .from('profiles')
          .select('email, display_name')
          .eq('id', userId)
          .maybeSingle();
    }
  }

  Future<void> _pickImage() async {
    final pickedFile = await _imagePicker.pickImage(
      source: ImageSource.gallery,
    );

    if (pickedFile != null) {
      if (mounted) {
        setState(() {
          _fileName = pickedFile.name;

          if (PlatformUtils.isWeb) {
            // For web platform
            pickedFile.readAsBytes().then((bytes) {
              _webImageBytes = bytes;
            });
          } else {
            // For mobile/desktop platforms
            _imageFile = File(pickedFile.path);
          }
        });
      }
    }
  }

  Future<void> _updateCompanyProfile() async {
    if (!_formKey.currentState!.validate()) return;
    final messenger = ScaffoldMessenger.maybeOf(context);

    try {
      final data = {
        'company_name': _companyNameController.text,
        'whatsapp_number': _companyWhatsappController.text,
        'ceo_first_name': _ceoFirstNameController.text,
        'ceo_last_name': _ceoLastNameController.text,
      };

      await ref.read(companyProvider.notifier).updateCompanyProfile(data);

      if (PlatformUtils.isWeb && _webImageBytes != null && _fileName != null) {
        await ref
            .read(companyProvider.notifier)
            .uploadCompanyLogo(_webImageBytes!, _fileName!);
      } else if (!PlatformUtils.isWeb && _imageFile != null) {
        final bytes = await _imageFile!.readAsBytes();
        await ref
            .read(companyProvider.notifier)
            .uploadCompanyLogo(bytes, _imageFile!.path.split('/').last);
      }

      ref.invalidateIfMounted(myProfileSetupProvider);

      if (!(messenger?.mounted ?? false)) {
        return;
      }

      messenger!.clearSnackBars();
      messenger.showSnackBar(
        const SnackBar(content: Text('Profile updated successfully')),
      );
    } catch (error) {
      if (!(messenger?.mounted ?? false)) {
        return;
      }

      messenger!.clearSnackBars();
      messenger.showSnackBar(
        SnackBar(content: Text('Failed to update company profile. ${friendlyError(error)}')),
      );
    }
  }

  Future<void> _updateEmployeeProfile() async {
    if (!_formKey.currentState!.validate()) return;
    final messenger = ScaffoldMessenger.maybeOf(context);

    final employee = ref.read(employeeProvider).employee;
    if (employee == null) return;

    final data = {
      'first_name': _firstNameController.text,
      'last_name': _lastNameController.text,
      'whatsapp_number': _employeeWhatsappController.text,
    };

    // Add ID number only if South African citizen
    if (employee.isSouthAfricanCitizen && _idNumberController.text.isNotEmpty) {
      data['id_number'] = _idNumberController.text;
    }

    // Add passport number only if not South African citizen
    if (!employee.isSouthAfricanCitizen &&
        _passportOrWorkersPermitController.text.isNotEmpty) {
      data['passport_or_workers_permit'] =
          _passportOrWorkersPermitController.text;
    }

    await ref.read(employeeProvider.notifier).updateEmployeeProfile(data);

    // Handle image upload based on platform
    if (PlatformUtils.isWeb && _webImageBytes != null && _fileName != null) {
      // For web platform
      await ref
          .read(employeeProvider.notifier)
          .uploadProfilePhoto(_webImageBytes!, _fileName!);
    } else if (!PlatformUtils.isWeb && _imageFile != null) {
      // For mobile/desktop platforms
      final bytes = await _imageFile!.readAsBytes();
      await ref
          .read(employeeProvider.notifier)
          .uploadProfilePhoto(bytes, _imageFile!.path.split('/').last);
    }

    // Name/ID/photo feed the account-setup checklist — refresh it.
    ref.invalidateIfMounted(myProfileSetupProvider);

    if (messenger?.mounted ?? false) {
      messenger!.clearSnackBars();
      messenger.showSnackBar(
        const SnackBar(content: Text('Profile updated successfully')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final companyState = ref.watch(companyProvider);
    final employeeState = ref.watch(employeeProvider);
    final title = authState.userType?.isCompany == true
        ? companyState.company?.companyName ?? 'Company Profile'
        : employeeState.employee?.fullName ?? 'My Profile';
    final subtitle = authState.userType?.isCompany == true
        ? 'Update company identity, leadership details, and brand assets.'
        : 'Keep your personal details, documents, and account information current.';

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color.alphaBlend(
                Theme.of(context).colorScheme.primary.withAlpha(24),
                Theme.of(context).scaffoldBackgroundColor,
              ),
              Theme.of(context).scaffoldBackgroundColor,
              Color.alphaBlend(
                Theme.of(context).colorScheme.tertiary.withAlpha(16),
                Theme.of(context).scaffoldBackgroundColor,
              ),
            ],
          ),
        ),
        child: SafeArea(
          top: false,
          child: Align(
            alignment: Alignment.topCenter,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 940),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    MlCard(
                      hero: true,
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              MlStatusBadge(
                                label: authState.userType?.isCompany == true
                                    ? 'Company workspace'
                                    : 'Employee workspace',
                                tone: MlTone.accent,
                              ),
                              const MlStatusBadge(
                                label: 'Live profile',
                                tone: MlTone.done,
                                dot: true,
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Text(
                            title,
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          MlCard.heroTitleRule(),
                          Text(
                            subtitle,
                            style: Theme.of(context).textTheme.bodyLarge
                                ?.copyWith(color: MlSemantic.of(context).textMuted),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    const _AccountSetupLinkCard(),
                    const SizedBox(height: 18),
                    if ((authState.user?.email ?? '').trim().isNotEmpty) ...[
                      const ChangePasswordSection(),
                      const SizedBox(height: 18),
                    ],
                    const ProfileSignatureCard(),
                    const SizedBox(height: 18),
                    authState.userType?.isCompany == true
                        ? _buildCompanyProfileForm()
                        : _buildEmployeeProfileForm(),
                    // Company locations (spec 2026-07-16 §3): named collection
                    // points; the primary auto-routes drivers.
                    if (authState.userType?.isCompany == true &&
                        companyState.company?.id != null) ...[
                      const SizedBox(height: 18),
                      CompanyLocationsSection(
                          companyId: companyState.company!.id),
                    ],
                    // The documents this account agreed to at sign-in.
                    //
                    // The sign-in screen links them, but somebody already
                    // signed in had no way back to them at all — which is the
                    // same gap in a quieter form: you can only be held to terms
                    // you can re-read.
                    const SizedBox(height: 18),
                    const _LegalCard(),
                    // Portal roles never see the super-admin shell, so this
                    // has to be reachable here too — account_security_screen
                    // carries the other copy for the super-admin surface.
                    const SizedBox(height: 18),
                    const DeactivateAccountCard(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _readOnlyProfileRow(
    BuildContext context, {
    required String label,
    required String value,
  }) {
    final variant = Theme.of(context).colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 152,
            child: Text(label, style: TextStyle(color: variant)),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompanyAccessTokenSection(String companyId) {
    final tokensAsync = ref.watch(organizationTokensProvider(companyId));
    return tokensAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
      error: (_, __) => const SizedBox.shrink(),
      data: (tokens) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: TokenAccessDetailsSection(
            activeToken: pickActiveSerialToken(tokens),
            companyFallback: null,
          ),
        );
      },
    );
  }

  Widget _buildCompanyProfileForm() {
    final state = ref.watch(companyProvider);
    final company = state.company;

    if (company == null) {
      return const Center(child: CircularProgressIndicator());
    }

    _ensureOwnerProfileFuture(company.userId);

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Stack(
              children: [
                CircleAvatar(
                  radius: 60,
                  backgroundColor: Colors.transparent,
                  backgroundImage: _getCompanyImageProvider(company),
                  child:
                      company.logoUrl == null &&
                          _imageFile == null &&
                          _webImageBytes == null
                      ? Icon(Icons.business,
                          size: 60, color: MlSemantic.of(context).textFaint)
                      : null,
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: CircleAvatar(
                    backgroundColor: MlTokens.accent,
                    radius: 20,
                    child: IconButton(
                      icon: const Icon(
                        Icons.camera_alt,
                        color: MlTokens.inkOnFill,
                        size: 20,
                      ),
                      onPressed: _pickImage,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          MlSectionTitle('Company Information',
              icon: Icons.apartment_rounded,
              // The org type and the fact that some of this is issued rather
              // than entered — the company reference and the org type are
              // both system-owned and cannot be edited here (S8-11).
              meta: '${company.orgType.name} · reference is read-only',
              margin: EdgeInsets.zero),
          const SizedBox(height: 16),
          TextFormField(
            controller: _companyNameController,
            decoration: const InputDecoration(
              labelText: 'Company Name',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.business),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter company name';
              }
              return null;
            },
            // Add attributes for browser autofill
            autofillHints: const [AutofillHints.organizationName],
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _companyWhatsappController,
            decoration: const InputDecoration(
              labelText: 'WhatsApp Number',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.phone),
            ),
            keyboardType: TextInputType.phone,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter WhatsApp number';
              }
              return null;
            },
            // Add attributes for browser autofill
            autofillHints: const [AutofillHints.telephoneNumber],
          ),
          const SizedBox(height: 16),
          TextFormField(
            initialValue: company.orgType.label,
            decoration: const InputDecoration(
              labelText: 'Organization Type',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.category),
            ),
            readOnly: true,
            enabled: false,
          ),
          const SizedBox(height: 24),
          const MlSectionTitle('Account owner (login)',
              icon: Icons.person_rounded,
              // Every field in this block is issued by auth, not entered.
              meta: 'Read-only',
              margin: EdgeInsets.zero),
          const SizedBox(height: 8),
          FutureBuilder<Map<String, dynamic>?>(
            future: _ownerProfileQuery,
            builder: (context, snapshot) {
              final authEmail = ref.watch(authStateProvider).user?.email;
              final email = (snapshot.data?['email'] as String?)?.trim();
              final resolvedEmail =
                  (email != null && email.isNotEmpty) ? email : authEmail ?? '—';
              final dn = (snapshot.data?['display_name'] as String?)?.trim();
              final resolvedName = (dn != null && dn.isNotEmpty)
                  ? dn
                  : (resolvedEmail.contains('@')
                      ? resolvedEmail.split('@').first
                      : '—');
              final contact = company.whatsappNumber.trim().isNotEmpty
                  ? company.whatsappNumber.trim()
                  : '—';
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _readOnlyProfileRow(
                    context,
                    label: 'Owner name',
                    value: resolvedName,
                  ),
                  _readOnlyProfileRow(
                    context,
                    label: 'Owner email',
                    value: resolvedEmail,
                  ),
                  _readOnlyProfileRow(
                    context,
                    label: 'Owner contact No.',
                    value: contact,
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      'Linked to the login account that registered this company.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                          ),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),
          _buildCompanyAccessTokenSection(company.id),
          const SizedBox(height: 16),
          CompanyTokenRequestsPanel(companyId: company.id),
          const SizedBox(height: 16),
          MlSectionTitle('CEO Information',
              icon: Icons.workspace_premium_rounded,
              // Whether the CEO's name has actually been captured. The
              // paragraph below tells a non-CEO to fill this in and sign out;
              // the meta says whether anyone has.
              meta: (company.ceoFirstName ?? '').trim().isEmpty
                  ? 'Not captured'
                  : 'Captured',
              margin: EdgeInsets.zero),
          const SizedBox(height: 8),
          Text(
            'This account is only meant to be used by the company\'s CEO. Should you not be the CEO, please IMMEDIATELY sign out after you\'ve added the First and Last name of your Company\'s CEO.',
            style: TextStyle(
              color: MlTone.error.colors(Theme.of(context).brightness).fg,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _ceoFirstNameController,
                  decoration: const InputDecoration(
                    labelText: 'CEO First Name',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter CEO first name';
                    }
                    return null;
                  },
                  // Add attributes for browser autofill
                  autofillHints: const [AutofillHints.givenName],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextFormField(
                  controller: _ceoLastNameController,
                  decoration: const InputDecoration(
                    labelText: 'CEO Last Name',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter CEO last name';
                    }
                    return null;
                  },
                  // Add attributes for browser autofill
                  autofillHints: const [AutofillHints.familyName],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: FilledButton(
              onPressed: state.isLoading ? null : _updateCompanyProfile,
              child: state.isLoading
                  ? LoadingAnimationWidget.staggeredDotsWave(
                      color: MlTokens.inkOnFill,
                      size: 30,
                    )
                  : const Text('Update Profile'),
            ),
          ),
          if (state.error != null) ...[
            const SizedBox(height: 16),
            Text(
              state.error!,
              style: TextStyle(
                color: MlTone.error.colors(Theme.of(context).brightness).fg,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmployeeProfileForm() {
    final state = ref.watch(employeeProvider);
    final employee = state.employee;

    if (employee == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Stack(
              children: [
                CircleAvatar(
                  radius: 60,
                  backgroundColor: Colors.transparent,
                  backgroundImage: _getEmployeeImageProvider(employee),
                  child:
                      employee.profilePhotoUrl == null &&
                          _imageFile == null &&
                          _webImageBytes == null
                      ? Icon(Icons.person,
                          size: 60, color: MlSemantic.of(context).textFaint)
                      : null,
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: CircleAvatar(
                    backgroundColor: MlTokens.accent,
                    radius: 20,
                    child: IconButton(
                      icon: const Icon(
                        Icons.camera_alt,
                        color: MlTokens.inkOnFill,
                        size: 20,
                      ),
                      onPressed: _pickImage,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const MlSectionTitle('Personal Information',
              icon: Icons.person_rounded,
              meta: 'Editable',
              margin: EdgeInsets.zero),
          const SizedBox(height: 16),
          TextFormField(
            controller: _firstNameController,
            decoration: const InputDecoration(
              labelText: 'First Name',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.person),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter first name';
              }
              return null;
            },
            // Add attributes for browser autofill
            autofillHints: const [AutofillHints.givenName],
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _lastNameController,
            decoration: const InputDecoration(
              labelText: 'Last Name',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.person),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter last name';
              }
              return null;
            },
            // Add attributes for browser autofill
            autofillHints: const [AutofillHints.familyName],
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _employeeWhatsappController,
            decoration: const InputDecoration(
              labelText: 'WhatsApp Number',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.phone),
            ),
            keyboardType: TextInputType.phone,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter WhatsApp number';
              }
              return null;
            },
            // Add attributes for browser autofill
            autofillHints: const [AutofillHints.telephoneNumber],
          ),
          const SizedBox(height: 16),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Citizenship Status',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Choose the identity documents that apply to this employee.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment<bool>(
                          value: true,
                          icon: Icon(Icons.flag_outlined),
                          label: Text('South African'),
                        ),
                        ButtonSegment<bool>(
                          value: false,
                          icon: Icon(Icons.public_outlined),
                          label: Text('Foreign National'),
                        ),
                      ],
                      selected: {employee.isSouthAfricanCitizen},
                      showSelectedIcon: false,
                      onSelectionChanged: (selection) async {
                        final value = selection.first;
                        if (value == employee.isSouthAfricanCitizen) {
                          return;
                        }

                        await ref
                            .read(employeeProvider.notifier)
                            .updateEmployeeProfile({
                              'is_south_african_citizen': value,
                            });
                        // Citizenship flips which identity documents the
                        // account-setup checklist requires (ID vs
                        // passport + work visa) — refresh it.
                        ref.invalidateIfMounted(myProfileSetupProvider);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Conditional fields based on citizenship
          if (employee.isSouthAfricanCitizen) ...[
            // South African citizen fields
            TextFormField(
              controller: _idNumberController,
              decoration: const InputDecoration(
                labelText: 'ID Number',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.badge),
                hintText: 'Enter your South African ID number',
              ),
              // ID number is optional, so no validator
            ),
            const SizedBox(height: 16),
            DocumentUploadWidget(
              documentType: DocumentType.idDocument,
              existingDocumentUrl: employee.idDocumentUrl,
            ),
          ] else ...[
            // Non-South African citizen fields
            TextFormField(
              controller: _passportOrWorkersPermitController,
              decoration: const InputDecoration(
                labelText: 'Passport Number',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.document_scanner),
                hintText: 'Enter your passport number',
              ),
              // Passport number is optional, so no validator
            ),
            const SizedBox(height: 16),
            DocumentUploadWidget(
              documentType: DocumentType.passport,
              existingDocumentUrl: employee.passportDocumentUrl,
            ),
            const SizedBox(height: 16),
            DocumentUploadWidget(
              documentType: DocumentType.workVisa,
              existingDocumentUrl: employee.workVisaDocumentUrl,
            ),
          ],

          const SizedBox(height: 16),
          DocumentUploadWidget(
            documentType: DocumentType.license,
            existingDocumentUrl: employee.licenseDocumentUrl,
          ),
          if (state.company != null) ...[
            const SizedBox(height: 16),
            TextFormField(
              initialValue: state.company!.companyName,
              decoration: const InputDecoration(
                labelText: 'Company',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.business),
              ),
              readOnly: true,
              enabled: false,
            ),
          ],
          if (employee.role != null) ...[
            const SizedBox(height: 16),
            TextFormField(
              initialValue: employee.role!.label,
              decoration: const InputDecoration(
                labelText: 'Role',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.work),
              ),
              readOnly: true,
              enabled: false,
            ),
          ],
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: FilledButton(
              onPressed: state.isLoading ? null : _updateEmployeeProfile,
              child: state.isLoading
                  ? LoadingAnimationWidget.staggeredDotsWave(
                      color: MlTokens.inkOnFill,
                      size: 30,
                    )
                  : const Text('Update Profile'),
            ),
          ),
          if (state.error != null) ...[
            const SizedBox(height: 16),
            Text(
              state.error!,
              style: TextStyle(
                color: MlTone.error.colors(Theme.of(context).brightness).fg,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Entry card into the guided account-setup checklist, with the live
/// completion percentage. Shown for every account type.
class _AccountSetupLinkCard extends ConsumerWidget {
  const _AccountSetupLinkCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final semantic = MlSemantic.of(context);
    final brightness = Theme.of(context).brightness;
    final setup = ref.watch(myProfileSetupProvider).valueOrNull;
    if (setup != null && !setup.isApplicable) return const SizedBox.shrink();

    final summary = setup?.summary;
    final needsWork = summary?.needsAttention ?? false;
    final tone = summary == null
        ? MlTone.accent
        : (summary.expiredCount > 0
            ? MlTone.error
            : needsWork
                ? MlTone.warn
                : MlTone.done);

    final subtitle = summary == null
        ? 'Personal details, documents, medicals & signature'
        : needsWork
            ? [
                if (summary.missingCount > 0)
                  '${summary.missingCount} required item${summary.missingCount == 1 ? '' : 's'} missing',
                if (summary.expiredCount > 0)
                  '${summary.expiredCount} expired',
                if (summary.expiringCount > 0)
                  '${summary.expiringCount} expiring soon',
              ].join(' · ')
            : 'Everything is complete and up to date';

    return MlCard(
      padding: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(MlTokens.rMd),
        onTap: () => context.go('/account-setup'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              MlIconWell(icon: Icons.checklist_rounded, tone: tone, size: 42),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Account setup',
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: semantic.textMuted),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              if (summary != null)
                Text('${summary.completionPercent}%',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: tone.colors(brightness).fg)),
              const SizedBox(width: 6),
              Icon(Icons.chevron_right_rounded, color: semantic.textFaint),
            ],
          ),
        ),
      ),
    );
  }
}

/// Links to the documents this account agreed to at sign-in.
class _LegalCard extends StatelessWidget {
  const _LegalCard();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return MlCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const MlSectionTitle('Legal',
              icon: Icons.gavel_outlined, meta: '3 documents'),
          const SizedBox(height: 6),
          Text(
            'What you agreed to when you signed in.',
            style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 10),
          for (final doc in LegalDocument.all)
            ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              leading: const Icon(Icons.description_outlined, size: 18),
              title: Text(doc.title),
              trailing: const Icon(Icons.chevron_right, size: 18),
              onTap: () => showLegalDocument(context, doc),
            ),
        ],
      ),
    );
  }
}
