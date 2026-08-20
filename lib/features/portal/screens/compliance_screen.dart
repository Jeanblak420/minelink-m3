import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:flutter_application_1/core/utils/safe_ref.dart';
import 'package:flutter_application_1/core/widgets/multi_file_drop_picker.dart';
import 'package:flutter_application_1/features/fleet/providers/fleet_provider.dart';
import 'package:flutter_application_1/features/portal/models/compliance_document.dart';
import 'package:flutter_application_1/features/portal/services/compliance_service.dart';
import 'package:flutter_application_1/features/portal/utils/portal_company_resolution.dart';
import 'package:flutter_application_1/core/design/components/ml_components.dart';
import 'package:flutter_application_1/features/profile_setup/providers/profile_setup_provider.dart';
import 'package:flutter_application_1/features/portal/widgets/portal_company_required.dart';
import 'package:flutter_application_1/core/utils/friendly_error.dart';

/// Compliance register: every expiring document this company manages — vehicles
/// (registration, COF, licence disc, insurance/GIT), drivers (licence, PrDP,
/// induction) and the company itself (mining right, DMRE return, permits). Each
/// row shows a live expiry status; a daily job reminds management before expiry.
class ComplianceScreen extends ConsumerWidget {
  const ComplianceScreen({super.key});

  static final _dateFmt = DateFormat('dd MMM yyyy');

  MlTone _tone(ComplianceStatus s) => switch (s) {
    ComplianceStatus.valid => MlTone.done,
    ComplianceStatus.expiring => MlTone.warn,
    ComplianceStatus.expired => MlTone.error,
    ComplianceStatus.noExpiry => MlTone.neutral,
  };

  IconData _ownerIcon(ComplianceOwnerType t) => switch (t) {
    ComplianceOwnerType.vehicle => Icons.local_shipping_outlined,
    ComplianceOwnerType.employee => Icons.badge_outlined,
    ComplianceOwnerType.company => Icons.business_outlined,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final companyId = resolvePortalCompanyId(ref);
    if (companyId == null) {
      return const PortalCompanyRequired();
    }
    final async = ref.watch(complianceDocumentsProvider(companyId));

    return MlPageBody(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Actions live in MlPageHeader's own `actions` slot, not a Row wrapped
          // around it. That slot makes the title and the actions siblings in one
          // Wrap, so an action drops under the title when the row runs out of
          // width -- which it does on a phone, and at an accessibility text size
          // on a tablet. A Row gives an unflexed button unbounded width instead
          // (CLAUDE.md 10.4), and a button cannot ellipsize its way out: clamping
          // one truncates its hit target, not merely its label.
          MlPageHeader(
            title: 'Compliance',
            meta: async.valueOrNull == null
                ? null
                : mlCount(async.value!.length, 'document'),
            description:
                'Track licences, permits and certificates for your '
                'vehicles, drivers and the company. Management is reminded '
                'before anything expires.',
            actions: [
              IconButton(
                tooltip: 'Refresh',
                onPressed: () =>
                    ref.invalidate(complianceDocumentsProvider(companyId)),
                icon: const Icon(Icons.refresh_rounded),
              ),
              MlButton.primary(
                label: 'Add document',
                icon: Icons.add_rounded,
                compact: true,
                onPressed: () =>
                    showComplianceDocDialog(context, ref, companyId: companyId),
              ),
            ],
          ),
          const SizedBox(height: 16),
          async.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => MlLoadFailure(
              subject: 'the compliance documents',
              error: e,
              onRetry: () =>
                  ref.invalidate(complianceDocumentsProvider(companyId)),
            ),
            data: (docs) {
              final expired = docs
                  .where((d) => d.status == ComplianceStatus.expired)
                  .length;
              final expiring = docs
                  .where((d) => d.status == ComplianceStatus.expiring)
                  .length;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _SummaryChip(
                        label: 'Expired',
                        value: '$expired',
                        tone: MlTone.error,
                      ),
                      _SummaryChip(
                        label: 'Expiring ≤30 days',
                        value: '$expiring',
                        tone: MlTone.warn,
                      ),
                      _SummaryChip(
                        label: 'Total',
                        value: '${docs.length}',
                        tone: MlTone.accent,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (docs.isEmpty)
                    MlEmptyState(
                      icon: Icons.verified_user_outlined,
                      title: 'No documents yet',
                      message:
                          'Add a vehicle licence disc, a driver PrDP, a mining '
                          'right or any other document with an expiry date to '
                          'start tracking it.',
                    )
                  else
                    for (final d in docs) ...[
                      _DocCard(
                        doc: d,
                        companyId: companyId,
                        tone: _tone(d.status),
                        ownerIcon: _ownerIcon(d.ownerType),
                        dateFmt: _dateFmt,
                      ),
                      const SizedBox(height: 10),
                    ],
                ],
              );
            },
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  final String label;
  final String value;
  final MlTone tone;
  const _SummaryChip({
    required this.label,
    required this.value,
    required this.tone,
  });

  @override
  Widget build(BuildContext context) {
    final c = tone.colors(Theme.of(context).brightness);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: tone.well(Theme.of(context).brightness),
        borderRadius: BorderRadius.circular(MlTokens.rMd),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: TextStyle(
              fontFamily: MlTokens.fontMono,
              fontWeight: FontWeight.w800,
              fontSize: 18,
              color: c.fg,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(fontWeight: FontWeight.w600, color: c.fg),
          ),
        ],
      ),
    );
  }
}

class _DocCard extends ConsumerWidget {
  final ComplianceDocument doc;
  final String companyId;
  final MlTone tone;
  final IconData ownerIcon;
  final DateFormat dateFmt;
  const _DocCard({
    required this.doc,
    required this.companyId,
    required this.tone,
    required this.ownerIcon,
    required this.dateFmt,
  });

  String _expiryText() {
    final d = doc;
    if (d.expiresAt == null) return 'No expiry date';
    final base = dateFmt.format(d.expiresAt!);
    final days = d.daysToExpiry;
    if (days == null) return base;
    if (days < 0) return '$base · ${-days} day(s) overdue';
    if (days == 0) return '$base · today';
    return '$base · in $days day(s)';
  }

  Future<void> _openFile(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final url = await ref
        .read(complianceServiceProvider)
        .resolveFileUrl(doc.filePath!);
    if (url == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not open the file.')),
      );
      return;
    }
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete document?'),
        content: Text('Remove "${doc.displayTitle}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          MlButton.danger(
            label: 'Delete',
            compact: true,
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(complianceServiceProvider).delete(doc.id);
      ref.invalidateIfMounted(complianceDocumentsProvider(companyId));
      ref.invalidateIfMounted(complianceDocumentsProvider(null));
      messenger.showSnackBar(
        const SnackBar(content: Text('Document deleted.')),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final semantic = MlSemantic.of(context);
    final d = doc;
    return MlCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MlIconWell(icon: ownerIcon, tone: tone, size: 44),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      d.displayTitle,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: semantic.textStrong,
                      ),
                    ),
                    MlStatusBadge(label: d.status.label, tone: tone),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  '${d.ownerName ?? d.ownerType.label}'
                  '${d.docNumber != null ? ' · ${d.docNumber}' : ''}',
                  style: TextStyle(fontSize: 13, color: semantic.textBody),
                ),
                const SizedBox(height: 2),
                Text(
                  _expiryText(),
                  style: TextStyle(fontSize: 12.5, color: semantic.textMuted),
                ),
                if (d.notes != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    d.notes!,
                    style: TextStyle(fontSize: 12.5, color: semantic.textFaint),
                  ),
                ],
              ],
            ),
          ),
          if (d.filePath != null)
            IconButton(
              tooltip: 'Open file',
              icon: const Icon(Icons.attachment_rounded, size: 20),
              onPressed: () => _openFile(context, ref),
            ),
          IconButton(
            tooltip: 'Edit',
            icon: const Icon(Icons.edit_outlined, size: 20),
            onPressed: () => showComplianceDocDialog(
              context,
              ref,
              companyId: companyId,
              existing: d,
            ),
          ),
          IconButton(
            tooltip: 'Delete',
            icon: const Icon(Icons.delete_outline_rounded, size: 20),
            onPressed: () => _confirmDelete(context, ref),
          ),
        ],
      ),
    );
  }
}

/// Add / edit a compliance document.
Future<void> showComplianceDocDialog(
  BuildContext context,
  WidgetRef ref, {
  required String companyId,
  ComplianceDocument? existing,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) =>
        _ComplianceDocDialog(companyId: companyId, existing: existing),
  );
}

class _ComplianceDocDialog extends ConsumerStatefulWidget {
  final String companyId;
  final ComplianceDocument? existing;
  const _ComplianceDocDialog({required this.companyId, this.existing});

  @override
  ConsumerState<_ComplianceDocDialog> createState() =>
      _ComplianceDocDialogState();
}

class _ComplianceDocDialogState extends ConsumerState<_ComplianceDocDialog> {
  late ComplianceOwnerType _ownerType;
  String? _ownerId;
  late String _docType; // wire, or '__other__'
  final _otherType = TextEditingController();
  final _title = TextEditingController();
  final _docNumber = TextEditingController();
  final _notes = TextEditingController();
  DateTime? _issued;
  DateTime? _expires;
  List<PickedRequestFile> _files = const [];
  bool _busy = false;

  static final _fmt = DateFormat('dd MMM yyyy');

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _ownerType = e?.ownerType ?? ComplianceOwnerType.vehicle;
    _ownerId =
        e?.ownerId ??
        (_ownerType == ComplianceOwnerType.company ? widget.companyId : null);
    final suggested = _ownerType.suggestedDocTypes.map((x) => x.key).toSet();
    _docType = e == null
        ? _ownerType.suggestedDocTypes.first.key
        : (suggested.contains(e.docType) ? e.docType : '__other__');
    if (_docType == '__other__' && e != null) _otherType.text = e.docType;
    _title.text = e?.title ?? '';
    _docNumber.text = e?.docNumber ?? '';
    _notes.text = e?.notes ?? '';
    _issued = e?.issuedAt;
    _expires = e?.expiresAt;
  }

  @override
  void dispose() {
    _otherType.dispose();
    _title.dispose();
    _docNumber.dispose();
    _notes.dispose();
    super.dispose();
  }

  void _onOwnerTypeChanged(ComplianceOwnerType t) {
    setState(() {
      _ownerType = t;
      _ownerId = t == ComplianceOwnerType.company ? widget.companyId : null;
      _docType = t.suggestedDocTypes.first.key;
    });
  }

  Future<void> _pickDate({required bool issued}) async {
    final now = DateTime.now();
    final initial = (issued ? _issued : _expires) ?? now;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 20),
      lastDate: DateTime(now.year + 30),
    );
    if (picked != null) {
      if (mounted) {
        setState(() {
          if (issued) {
            _issued = picked;
          } else {
            _expires = picked;
          }
        });
      }
    }
  }

  Future<void> _save() async {
    final docType = _docType == '__other__' ? _otherType.text.trim() : _docType;
    if (docType.isEmpty) {
      _err('Please choose or name a document type.');
      return;
    }
    if (_ownerId == null) {
      _err(
        'Please choose which ${_ownerType.label.toLowerCase()} this is for.',
      );
      return;
    }
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      final svc = ref.read(complianceServiceProvider);
      String? filePath = widget.existing?.filePath;
      if (_files.isNotEmpty) {
        filePath = await svc.uploadFile(
          widget.companyId,
          _files.first.bytes,
          _files.first.name,
        );
      }
      await svc.upsert(
        companyId: widget.companyId,
        ownerType: _ownerType,
        ownerId: _ownerId!,
        docType: docType,
        expiresAt: _expires,
        id: widget.existing?.id,
        title: _title.text.trim().isEmpty ? null : _title.text.trim(),
        docNumber: _docNumber.text.trim().isEmpty
            ? null
            : _docNumber.text.trim(),
        issuedAt: _issued,
        filePath: filePath,
        notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      );
      ref.invalidateIfMounted(complianceDocumentsProvider(widget.companyId));
      ref.invalidateIfMounted(complianceDocumentsProvider(null));
      // Compliance docs feed the account-setup completion state (own banner,
      // employer card, register chips) — refresh those too.
      ref.invalidateIfMounted(myProfileSetupProvider);
      ref.invalidateIfMounted(employeeProfileSetupProvider);
      navigator.pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            widget.existing == null ? 'Document added.' : 'Document updated.',
          ),
        ),
      );
    } catch (e) {
      if (mounted) setState(() => _busy = false);
      messenger.showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }

  void _err(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Widget _ownerPicker() {
    switch (_ownerType) {
      case ComplianceOwnerType.company:
        return const InputDecorator(
          decoration: InputDecoration(labelText: 'For'),
          child: Text('This company'),
        );
      case ComplianceOwnerType.vehicle:
        final vehicles = ref.watch(fleetProvider(widget.companyId)).vehicles;
        return DropdownButtonFormField<String>(
          initialValue: _ownerId,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Vehicle'),
          items: [
            for (final v in vehicles)
              DropdownMenuItem(
                value: v.id,
                child: Text(v.vehicleRegistrationNumber),
              ),
          ],
          onChanged: _busy ? null : (v) => setState(() => _ownerId = v),
        );
      case ComplianceOwnerType.employee:
        final async = ref.watch(
          complianceEmployeeOptionsProvider(widget.companyId),
        );
        return async.when(
          loading: () => const LinearProgressIndicator(),
          error: (e, _) =>
              Text('Could not load employees. ${friendlyError(e)}'),
          data: (opts) => DropdownButtonFormField<String>(
            initialValue: _ownerId,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Employee / driver'),
            items: [
              for (final o in opts)
                DropdownMenuItem(value: o.id, child: Text(o.label)),
            ],
            onChanged: _busy ? null : (v) => setState(() => _ownerId = v),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final docTypes = _ownerType.suggestedDocTypes;
    return AlertDialog(
      title: Text(widget.existing == null ? 'Add document' : 'Edit document'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DropdownButtonFormField<ComplianceOwnerType>(
                initialValue: _ownerType,
                decoration: const InputDecoration(
                  labelText: 'This document is for',
                ),
                items: [
                  for (final t in ComplianceOwnerType.values)
                    DropdownMenuItem(value: t, child: Text(t.label)),
                ],
                onChanged: _busy
                    ? null
                    : (t) => _onOwnerTypeChanged(t ?? _ownerType),
              ),
              const SizedBox(height: 12),
              _ownerPicker(),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _docType,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Document type'),
                items: [
                  for (final e in docTypes)
                    DropdownMenuItem(value: e.key, child: Text(e.value)),
                  const DropdownMenuItem(
                    value: '__other__',
                    child: Text('Other…'),
                  ),
                ],
                onChanged: _busy
                    ? null
                    : (v) => setState(() => _docType = v ?? _docType),
              ),
              if (_docType == '__other__') ...[
                const SizedBox(height: 8),
                TextField(
                  controller: _otherType,
                  enabled: !_busy,
                  decoration: const InputDecoration(
                    labelText: 'Document type name',
                  ),
                ),
              ],
              const SizedBox(height: 12),
              TextField(
                controller: _title,
                enabled: !_busy,
                decoration: const InputDecoration(
                  labelText: 'Title / label (optional)',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _docNumber,
                enabled: !_busy,
                decoration: const InputDecoration(
                  labelText: 'Document number (optional)',
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _DateField(
                      label: 'Issued (optional)',
                      value: _issued,
                      fmt: _fmt,
                      onTap: _busy ? null : () => _pickDate(issued: true),
                      onClear: _busy
                          ? null
                          : () => setState(() => _issued = null),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _DateField(
                      label: 'Expires',
                      value: _expires,
                      fmt: _fmt,
                      onTap: _busy ? null : () => _pickDate(issued: false),
                      onClear: _busy
                          ? null
                          : () => setState(() => _expires = null),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _notes,
                enabled: !_busy,
                minLines: 1,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Notes (optional)',
                ),
              ),
              const SizedBox(height: 12),
              MultiFileDropPicker(
                label: 'Attach file (optional)',
                hint: 'PDF, image or scan — one file',
                files: _files,
                onChanged: (f) => setState(() => _files = f),
                allowMultiple: false,
                enabled: !_busy,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        MlButton.primary(
          label: _busy ? 'Saving…' : 'Save',
          compact: true,
          onPressed: _busy ? null : _save,
        ),
      ],
    );
  }
}

class _DateField extends StatelessWidget {
  final String label;
  final DateTime? value;
  final DateFormat fmt;
  final VoidCallback? onTap;
  final VoidCallback? onClear;
  const _DateField({
    required this.label,
    required this.value,
    required this.fmt,
    required this.onTap,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: value == null
              ? const Icon(Icons.calendar_today_outlined, size: 18)
              : IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: onClear,
                ),
        ),
        child: Text(value == null ? 'Not set' : fmt.format(value!)),
      ),
    );
  }
}
