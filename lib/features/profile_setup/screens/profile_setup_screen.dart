import 'package:flutter/material.dart';
import 'package:flutter_application_1/core/time/ml_time.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import 'package:flutter_application_1/core/utils/safe_ref.dart';
import 'package:flutter_application_1/core/widgets/multi_file_drop_picker.dart';
import 'package:flutter_application_1/features/company/providers/company_provider.dart';
import 'package:flutter_application_1/features/employee/providers/employee_provider.dart';
import 'package:flutter_application_1/core/design/components/ml_components.dart';
import 'package:flutter_application_1/features/profile/services/signature_service.dart';
import 'package:flutter_application_1/features/profile/widgets/profile_signature_card.dart';
import 'package:flutter_application_1/features/profile_setup/models/profile_setup.dart';
import 'package:flutter_application_1/features/profile_setup/providers/profile_setup_provider.dart';
import 'package:flutter_application_1/features/profile_setup/services/profile_setup_service.dart';
import 'package:flutter_application_1/core/utils/friendly_error.dart';

/// Guided "complete your account setup" checklist for every account —
/// employees of every role and company owners, all org types. Items and
/// completion state come from `get_profile_setup`; documents (with expiry
/// dates) land in the compliance register so the employer's Compliance tab and
/// the daily expiry reminders keep working off the same records.
class ProfileSetupScreen extends ConsumerWidget {
  const ProfileSetupScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final semantic = MlSemantic.of(context);
    final async = ref.watch(myProfileSetupProvider);

    // NO `Scaffold(appBar:)` — `/account-setup` is a leaf of the portal
    // `ShellRoute`, whose top bar already reads "Account setup".
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => MlEmptyState(
        icon: Icons.error_outline_rounded,
        title: 'Could not load your account setup',
        message: friendlyError(e),
        action: MlButton.primary(
          label: 'Retry',
          icon: Icons.refresh_rounded,
          onPressed: () => ref.invalidate(myProfileSetupProvider),
        ),
      ),
      data: (setup) {
        if (!setup.isApplicable) {
          return const MlEmptyState(
            icon: Icons.verified_user_outlined,
            title: 'Nothing to complete',
            message:
                'This account has no employee or company profile that needs setting up.',
          );
        }
        return Align(
          alignment: Alignment.topCenter,
          child: RefreshIndicator(
            onRefresh: () async => ref.invalidate(myProfileSetupProvider),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 940),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _ProgressHero(setup: setup),
                    const SizedBox(height: 18),
                    for (final category in setup.categories) ...[
                      Builder(builder: (_) {
                        final inCat = setup.itemsIn(category);
                        final done = inCat
                            .where((i) => i.status == SetupItemStatus.complete)
                            .length;
                        return MlSectionTitle(
                          category.label,
                          icon: _categoryIcon(category),
                          // Progress within this category, not overall — the
                          // hero above already carries the overall figure,
                          // and repeating it here would say nothing new.
                          meta: '$done of ${inCat.length} complete',
                        );
                      }),
                      for (final item in setup.itemsIn(category)) ...[
                        _ItemCard(setup: setup, item: item),
                        const SizedBox(height: 10),
                      ],
                      const SizedBox(height: 8),
                    ],
                    const SizedBox(height: 8),
                    Text(
                      'Documents you add here are stored in your company\'s '
                      'compliance register. You and your company are '
                      'reminded automatically before anything expires.',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: semantic.textFaint),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

IconData _categoryIcon(SetupCategory c) => switch (c) {
      SetupCategory.personal => Icons.person_outline_rounded,
      SetupCategory.identity => Icons.badge_outlined,
      SetupCategory.medical => Icons.medical_services_outlined,
      SetupCategory.licences => Icons.card_membership_outlined,
      SetupCategory.certifications => Icons.workspace_premium_outlined,
      SetupCategory.company => Icons.business_outlined,
    };

IconData _itemIcon(ProfileSetupItem item) => switch (item.kind) {
      SetupItemKind.field => Icons.edit_note_rounded,
      SetupItemKind.document => Icons.description_outlined,
      SetupItemKind.signature => Icons.draw_rounded,
      SetupItemKind.photo => Icons.photo_camera_outlined,
    };

MlTone _statusTone(ProfileSetupItem item) => switch (item.status) {
      SetupItemStatus.complete => MlTone.done,
      SetupItemStatus.expiring => MlTone.warn,
      SetupItemStatus.needsExpiry => MlTone.warn,
      SetupItemStatus.expired => MlTone.error,
      SetupItemStatus.missing =>
        item.isRequired ? MlTone.warn : MlTone.neutral,
    };

class _ProgressHero extends StatelessWidget {
  const _ProgressHero({required this.setup});
  final ProfileSetup setup;

  @override
  Widget build(BuildContext context) {
    final semantic = MlSemantic.of(context);
    final brightness = Theme.of(context).brightness;
    final s = setup.summary;
    final done = !s.hasOutstandingRequired;
    final tone = done
        ? (s.expiringCount > 0 ? MlTone.warn : MlTone.done)
        : (s.expiredCount > 0 ? MlTone.error : MlTone.warn);

    final parts = <String>[
      '${s.requiredComplete} of ${s.requiredTotal} required items complete',
      if (s.missingCount > 0) '${s.missingCount} still required',
      if (s.expiredCount > 0) '${s.expiredCount} expired',
      if (s.expiringCount > 0) '${s.expiringCount} expiring soon',
    ];

    return MlCard(
      hero: true,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              MlIconWell(
                icon: done
                    ? Icons.verified_user_outlined
                    : Icons.assignment_late_outlined,
                tone: tone,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      done
                          ? 'Your account setup is complete'
                          : 'Complete your account setup',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      parts.join(' · '),
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: semantic.textMuted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${s.completionPercent}%',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: tone.colors(brightness).fg,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(MlTokens.rPill),
            child: LinearProgressIndicator(
              value: s.completionPercent / 100,
              minHeight: 8,
              backgroundColor: semantic.surfaceSunken,
              valueColor:
                  AlwaysStoppedAnimation(tone.colors(brightness).fg),
            ),
          ),
        ],
      ),
    );
  }
}

class _ItemCard extends ConsumerWidget {
  const _ItemCard({required this.setup, required this.item});
  final ProfileSetup setup;
  final ProfileSetupItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final semantic = MlSemantic.of(context);
    final tone = _statusTone(item);
    final meta = _metaLine();

    return MlCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MlIconWell(icon: _itemIcon(item), tone: tone, size: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      item.label,
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    MlStatusBadge(label: item.status.label, tone: tone),
                    if (!item.isRequired)
                      Text(
                        'Recommended',
                        style: Theme.of(context)
                            .textTheme
                            .labelSmall
                            ?.copyWith(color: semantic.textFaint),
                      ),
                  ],
                ),
                if (item.description != null &&
                    item.description!.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    item.description!,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: semantic.textMuted),
                  ),
                ],
                if (meta != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    meta,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: item.status == SetupItemStatus.expired
                              ? MlTone.error
                                  .colors(Theme.of(context).brightness)
                                  .fg
                              : semantic.textFaint,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          MlButton.primary(
            label: _actionLabel(),
            compact: true,
            onPressed: () => _onAction(context, ref),
          ),
        ],
      ),
    );
  }

  String? _metaLine() {
    if (item.kind == SetupItemKind.document) {
      if (item.expiresAt != null) {
        final date = DateFormat('dd MMM yyyy').format(item.expiresAt!);
        final days = item.daysToExpiry;
        if (days == null) return 'Expires $date';
        if (days < 0) {
          final overdue = -days;
          return 'Expired $date · $overdue day${overdue == 1 ? '' : 's'} overdue';
        }
        if (days == 0) return 'Expires today';
        return 'Expires $date · in $days day${days == 1 ? '' : 's'}';
      }
      if (item.status == SetupItemStatus.needsExpiry) {
        return item.source == 'legacy_url'
            ? 'Uploaded previously — add the expiry date so we can remind you in time'
            : 'On record without an expiry date — add it so we can remind you in time';
      }
    }
    return null;
  }

  String _actionLabel() => switch (item.status) {
        SetupItemStatus.missing => 'Add',
        SetupItemStatus.needsExpiry => 'Fix',
        SetupItemStatus.expired => 'Renew',
        SetupItemStatus.expiring => 'Renew',
        SetupItemStatus.complete => 'Update',
      };

  Future<void> _onAction(BuildContext context, WidgetRef ref) async {
    switch (item.kind) {
      case SetupItemKind.signature:
        final saved = await showSignatureCaptureDialog(context);
        if (saved == true) {
          ref
            ..invalidate(mySignatureUrlProvider)
            ..invalidate(myProfileSetupProvider);
        }
        return;
      case SetupItemKind.photo:
        await _pickAndUploadPhoto(context, ref);
        return;
      case SetupItemKind.field:
        final saved = await showDialog<bool>(
          context: context,
          builder: (_) => _FieldEditDialog(setup: setup, item: item),
        );
        if (saved == true) ref.invalidateIfMounted(myProfileSetupProvider);
        return;
      case SetupItemKind.document:
        if (setup.isEmployee && setup.companyId == null) {
          ScaffoldMessenger.maybeOf(context)?.showSnackBar(const SnackBar(
            content: Text(
                'Link to a company first — documents are stored in your company\'s compliance register.'),
          ));
          return;
        }
        final saved = await showDialog<bool>(
          context: context,
          builder: (_) => _DocumentDialog(setup: setup, item: item),
        );
        if (saved == true) ref.invalidateIfMounted(myProfileSetupProvider);
        return;
    }
  }

  Future<void> _pickAndUploadPhoto(BuildContext context, WidgetRef ref) async {
    final picked = await ImagePicker()
        .pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    try {
      if (setup.isCompany) {
        await ref
            .read(companyProvider.notifier)
            .uploadCompanyLogo(bytes, picked.name);
      } else {
        await ref
            .read(employeeProvider.notifier)
            .uploadProfilePhoto(bytes, picked.name);
      }
      ref.invalidateIfMounted(myProfileSetupProvider);
      if (context.mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(
            content: Text(setup.isCompany
                ? 'Company logo updated'
                : 'Profile photo updated')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
            SnackBar(content: Text('Could not upload the photo. ${friendlyError(e)}')));
      }
    }
  }
}

/// Inline editor for `field`-kind items. The field set is keyed off the
/// requirement item_key, matching the server's completion checks.
class _FieldEditDialog extends ConsumerStatefulWidget {
  const _FieldEditDialog({required this.setup, required this.item});
  final ProfileSetup setup;
  final ProfileSetupItem item;

  @override
  ConsumerState<_FieldEditDialog> createState() => _FieldEditDialogState();
}

class _FieldEditDialogState extends ConsumerState<_FieldEditDialog> {
  final _primary = TextEditingController();
  final _secondary = TextEditingController();
  DateTime? _date;
  String? _grade;
  bool _saving = false;
  String? _error;

  bool get _isDateField =>
      widget.item.itemKey == 'date_of_birth' ||
      widget.item.itemKey == 'employment_start_date';
  bool get _isTwoFields =>
      widget.item.itemKey == 'emergency_contact' ||
      widget.item.itemKey == 'ceo_names';
  bool get _isGrade => widget.item.itemKey == 'psira_grade';

  @override
  void initState() {
    super.initState();
    // Prefill from current state where we have it locally.
    final emp = ref.read(employeeProvider).employee;
    final co = ref.read(companyProvider).company;
    switch (widget.item.itemKey) {
      case 'date_of_birth':
        _date = emp?.dateOfBirth;
      case 'employment_start_date':
        _date = emp?.employmentStartDate;
      case 'residential_address':
        _primary.text = emp?.residentialAddress ?? '';
      case 'contact_email':
        _primary.text = emp?.contactEmail ?? '';
      case 'license_codes':
        _primary.text = emp?.licenseCodes ?? '';
      case 'psira_grade':
        _grade = emp?.psiraGrade;
      case 'emergency_contact':
        _primary.text = emp?.emergencyContactName ?? '';
        _secondary.text = emp?.emergencyContactPhone ?? '';
      case 'ceo_names':
        _primary.text = co?.ceoFirstName ?? '';
        _secondary.text = co?.ceoLastName ?? '';
      case 'support_email':
        _primary.text = co?.supportContactEmail ?? '';
      case 'registration_number':
        _primary.text = co?.registrationNumber ?? '';
      case 'vat_number':
        _primary.text = co?.vatNumber ?? '';
      case 'physical_address':
        _primary.text = co?.physicalAddress ?? '';
    }
  }

  @override
  void dispose() {
    _primary.dispose();
    _secondary.dispose();
    super.dispose();
  }

  (String, String?) get _fieldLabels => switch (widget.item.itemKey) {
        'emergency_contact' => ('Contact name', 'Contact phone number'),
        'ceo_names' => ('CEO first name', 'CEO last name'),
        'residential_address' => ('Residential address', null),
        'contact_email' => ('Email address', null),
        'license_codes' => ('Licence codes (e.g. C1, EC)', null),
        'support_email' => ('Support email address', null),
        'registration_number' => ('Registration number', null),
        'vat_number' => ('VAT number', null),
        'physical_address' => ('Business address', null),
        _ => (widget.item.label, null),
      };

  Future<void> _save() async {
    final key = widget.item.itemKey;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      if (_isDateField && _date == null) {
        throw Exception('Please pick a date.');
      }
      if (_isGrade && (_grade == null || _grade!.isEmpty)) {
        throw Exception('Please choose your grade.');
      }
      if (!_isDateField && !_isGrade && _primary.text.trim().isEmpty) {
        throw Exception('Please fill in the field.');
      }
      if (_isTwoFields && _secondary.text.trim().isEmpty) {
        throw Exception('Please fill in both fields.');
      }

      String? d(DateTime? v) => v?.toIso8601String().substring(0, 10);
      if (widget.setup.isCompany) {
        final data = switch (key) {
          'ceo_names' => {
              'ceo_first_name': _primary.text.trim(),
              'ceo_last_name': _secondary.text.trim(),
            },
          'support_email' => {'support_contact_email': _primary.text.trim()},
          'registration_number' => {
              'registration_number': _primary.text.trim()
            },
          'vat_number' => {'vat_number': _primary.text.trim()},
          'physical_address' => {'physical_address': _primary.text.trim()},
          _ => <String, dynamic>{},
        };
        if (data.isEmpty) throw Exception('Unknown field.');
        await ref.read(companyProvider.notifier).updateCompanyProfile(data);
      } else {
        final data = switch (key) {
          'date_of_birth' => {'date_of_birth': d(_date)},
          'employment_start_date' => {'employment_start_date': d(_date)},
          'residential_address' => {
              'residential_address': _primary.text.trim()
            },
          'contact_email' => {'contact_email': _primary.text.trim()},
          'license_codes' => {'license_codes': _primary.text.trim()},
          'psira_grade' => {'psira_grade': _grade},
          'emergency_contact' => {
              'emergency_contact_name': _primary.text.trim(),
              'emergency_contact_phone': _secondary.text.trim(),
            },
          _ => <String, dynamic>{},
        };
        if (data.isEmpty) throw Exception('Unknown field.');
        await ref.read(employeeProvider.notifier).updateEmployeeProfile(data);
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = '$e'.replaceFirst('Exception: ', '');
        });
      }
    }
  }

  Future<void> _pickDate() async {
    final isDob = widget.item.itemKey == 'date_of_birth';
    final now = MlTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? (isDob ? DateTime(now.year - 30) : now),
      firstDate: DateTime(isDob ? 1930 : 1970),
      lastDate: now,
    );
    if (picked != null && mounted) setState(() => _date = picked);
  }

  @override
  Widget build(BuildContext context) {
    final semantic = MlSemantic.of(context);
    final (primaryLabel, secondaryLabel) = _fieldLabels;
    return AlertDialog(
      // Cold-phone audit 2026-08-18: this dialog holds input fields and did
      // not scroll, so at a large text size on a narrow phone its content
      // overflowed the viewport and the fields below the fold could not be
      // reached. Measured at 133px of clipped content on the token
      // generator, which is the same shape. `scrollable` only engages when
      // the content exceeds the space, so it is inert on a desktop.
      scrollable: true,
      title: Text(widget.item.label),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.item.description != null) ...[
              Text(
                widget.item.description!,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: semantic.textMuted),
              ),
              const SizedBox(height: 12),
            ],
            if (_isDateField)
              OutlinedButton.icon(
                onPressed: _saving ? null : _pickDate,
                icon: const Icon(Icons.event_rounded, size: 18),
                label: Text(_date == null
                    ? 'Pick a date'
                    : DateFormat('dd MMM yyyy').format(_date!)),
              )
            else if (_isGrade)
              DropdownButtonFormField<String>(
                // A DropdownButtonFormField lays its selected item out at its NATURAL
                // width and sizes to the WIDEST item in the list, so one long option
                // decides the control's width whatever is selected (CLAUDE.md §10.4).
                isExpanded: true,
                initialValue: _grade,
                decoration: const InputDecoration(labelText: 'PSIRA grade'),
                items: const [
                  DropdownMenuItem(value: 'A', child: Text('Grade A')),
                  DropdownMenuItem(value: 'B', child: Text('Grade B')),
                  DropdownMenuItem(value: 'C', child: Text('Grade C')),
                  DropdownMenuItem(value: 'D', child: Text('Grade D')),
                  DropdownMenuItem(value: 'E', child: Text('Grade E')),
                ],
                onChanged:
                    _saving ? null : (v) => setState(() => _grade = v),
              )
            else ...[
              TextField(
                controller: _primary,
                enabled: !_saving,
                maxLines: widget.item.itemKey.contains('address') ? 3 : 1,
                keyboardType: widget.item.itemKey.contains('email')
                    ? TextInputType.emailAddress
                    : (widget.item.itemKey == 'emergency_contact'
                        ? TextInputType.name
                        : TextInputType.text),
                decoration: InputDecoration(labelText: primaryLabel),
              ),
              if (_isTwoFields) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _secondary,
                  enabled: !_saving,
                  keyboardType:
                      widget.item.itemKey == 'emergency_contact'
                          ? TextInputType.phone
                          : TextInputType.name,
                  decoration: InputDecoration(labelText: secondaryLabel),
                ),
              ],
            ],
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(
                _error!,
                style: TextStyle(
                  color: MlTone.error.colors(Theme.of(context).brightness).fg,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Save'),
        ),
      ],
    );
  }
}

/// Add/renew one of MY documents: optional title/number/issued date, expiry
/// date (enforced when the requirement carries one), and the file itself.
class _DocumentDialog extends ConsumerStatefulWidget {
  const _DocumentDialog({required this.setup, required this.item});
  final ProfileSetup setup;
  final ProfileSetupItem item;

  @override
  ConsumerState<_DocumentDialog> createState() => _DocumentDialogState();
}

class _DocumentDialogState extends ConsumerState<_DocumentDialog> {
  final _docNumber = TextEditingController();
  DateTime? _issuedAt;
  DateTime? _expiresAt;
  List<PickedRequestFile> _files = const [];
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _expiresAt = widget.item.expiresAt;
  }

  @override
  void dispose() {
    _docNumber.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool expiry}) async {
    final now = MlTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: expiry ? (_expiresAt ?? now) : (_issuedAt ?? now),
      firstDate: DateTime(now.year - 20),
      lastDate: DateTime(now.year + 30),
    );
    if (picked != null) {
      if (mounted) setState(() => expiry ? _expiresAt = picked : _issuedAt = picked);
    }
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      if (widget.item.requiresExpiry && _expiresAt == null) {
        throw Exception(
            'Please add the expiry date — it drives the renewal reminders.');
      }
      final isRenewal = widget.item.documentId == null ||
          widget.item.status == SetupItemStatus.expired;
      if (_files.isEmpty && !widget.item.filePresent && widget.item.requiresFile) {
        throw Exception('Please attach the document file.');
      }
      final service = ref.read(profileSetupServiceProvider);
      String? filePath;
      final companyId = widget.setup.companyId;
      if (_files.isNotEmpty) {
        if (companyId == null) {
          throw Exception('Link to a company before uploading documents.');
        }
        filePath = await service.uploadFile(
            companyId, _files.first.bytes, _files.first.name);
      }
      await service.upsertMyDocument(
        docType: widget.item.itemKey,
        // Renewing an expired document creates a fresh record so the history
        // stays; otherwise update in place.
        id: isRenewal ? null : widget.item.documentId,
        docNumber:
            _docNumber.text.trim().isEmpty ? null : _docNumber.text.trim(),
        issuedAt: _issuedAt,
        expiresAt: _expiresAt,
        filePath: filePath,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = '$e'.replaceFirst('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final semantic = MlSemantic.of(context);
    String dateLabel(DateTime? d, String hint) =>
        d == null ? hint : DateFormat('dd MMM yyyy').format(d);

    return AlertDialog(
      title: Text(widget.item.label),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.item.description != null) ...[
                Text(
                  widget.item.description!,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: semantic.textMuted),
                ),
                const SizedBox(height: 12),
              ],
              TextField(
                controller: _docNumber,
                enabled: !_saving,
                decoration: const InputDecoration(
                  labelText: 'Document / certificate number (optional)',
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed:
                          _saving ? null : () => _pickDate(expiry: false),
                      icon: const Icon(Icons.event_available_rounded,
                          size: 18),
                      label: Text(dateLabel(_issuedAt, 'Issued date')),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed:
                          _saving ? null : () => _pickDate(expiry: true),
                      icon: const Icon(Icons.event_busy_rounded, size: 18),
                      label: Text(dateLabel(
                        _expiresAt,
                        widget.item.requiresExpiry
                            ? 'Expiry date (required)'
                            : 'Expiry date',
                      )),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              MultiFileDropPicker(
                label: 'Document file',
                hint: 'PDF or photo of the document',
                allowMultiple: false,
                allowedExtensions: const ['pdf', 'png', 'jpg', 'jpeg', 'webp'],
                files: _files,
                enabled: !_saving,
                onChanged: (f) => setState(() => _files = f),
              ),
              if (widget.item.filePresent && _files.isEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  'A file is already on record — attach a new one only to replace it.',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: semantic.textFaint),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(
                  _error!,
                  style: TextStyle(
                    color:
                        MlTone.error.colors(Theme.of(context).brightness).fg,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Save'),
        ),
      ],
    );
  }
}
