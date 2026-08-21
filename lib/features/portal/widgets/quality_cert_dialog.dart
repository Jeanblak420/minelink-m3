import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter_application_1/core/design/tokens/m3/ml_typography.dart';
import 'package:flutter_application_1/core/widgets/multi_file_drop_picker.dart';
import 'package:flutter_application_1/features/portal/models/load_quality.dart';
import 'package:flutter_application_1/features/portal/services/quality_service.dart';
import 'package:flutter_application_1/core/design/components/ml_components.dart';
import 'package:flutter_application_1/core/utils/friendly_error.dart';

/// Attach/edit the quality certificate on a delivered load (mine side):
/// structured Cr2O3 % / moisture % / sizing + the lab certificate file
/// (PDF or photo), uploaded to the private `quality_certs` bucket and written
/// through the server-validated `set_load_quality_cert` RPC.
Future<bool> showQualityCertDialog(
  BuildContext context,
  WidgetRef ref, {
  required LoadQualityRow row,
  required String supplierCompanyId,
}) async {
  final saved = await showDialog<bool>(
    context: context,
    builder: (_) => _QualityCertDialog(
      row: row,
      supplierCompanyId: supplierCompanyId,
    ),
  );
  return saved == true;
}

class _QualityCertDialog extends ConsumerStatefulWidget {
  final LoadQualityRow row;
  final String supplierCompanyId;
  const _QualityCertDialog({
    required this.row,
    required this.supplierCompanyId,
  });

  @override
  ConsumerState<_QualityCertDialog> createState() => _QualityCertDialogState();
}

class _QualityCertDialogState extends ConsumerState<_QualityCertDialog> {
  late final TextEditingController _cr2o3;
  late final TextEditingController _moisture;
  late final TextEditingController _sizing;
  late final TextEditingController _notes;
  List<PickedRequestFile> _files = const [];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _cr2o3 = TextEditingController(
        text: widget.row.cr2o3Pct?.toStringAsFixed(2) ?? '');
    _moisture = TextEditingController(
        text: widget.row.moisturePct?.toStringAsFixed(2) ?? '');
    _sizing = TextEditingController(text: widget.row.sizing ?? '');
    _notes = TextEditingController(text: widget.row.certNotes ?? '');
  }

  @override
  void dispose() {
    _cr2o3.dispose();
    _moisture.dispose();
    _sizing.dispose();
    _notes.dispose();
    super.dispose();
  }

  double? _pct(TextEditingController c, String label) {
    final t = c.text.trim();
    if (t.isEmpty) return null;
    final v = double.tryParse(t);
    if (v == null || v < 0 || v > 100) {
      throw FormatException('$label must be a percentage between 0 and 100.');
    }
    return v;
  }

  Future<void> _save() async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final double? cr2o3;
    final double? moisture;
    try {
      cr2o3 = _pct(_cr2o3, 'Cr₂O₃ %');
      moisture = _pct(_moisture, 'Moisture %');
    } on FormatException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
      return;
    }
    final sizing = _sizing.text.trim();
    if (cr2o3 == null &&
        moisture == null &&
        sizing.isEmpty &&
        _files.isEmpty &&
        widget.row.certPath == null) {
      messenger.showSnackBar(const SnackBar(
          content: Text(
              'Enter at least one quality value or attach the certificate file.')));
      return;
    }

    setState(() => _saving = true);
    final service = ref.read(qualityServiceProvider);
    try {
      String? certPath;
      String? fileName;
      if (_files.isNotEmpty) {
        final f = _files.first;
        certPath = await service.uploadCertFile(
          supplierCompanyId: widget.supplierCompanyId,
          tripId: widget.row.tripId,
          name: f.name,
          bytes: f.bytes,
        );
        fileName = f.name;
      }
      await service.setLoadQualityCert(
        tripId: widget.row.tripId,
        cr2o3Pct: cr2o3,
        moisturePct: moisture,
        sizing: sizing.isEmpty ? null : sizing,
        notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
        certPath: certPath,
        fileName: fileName,
      );
      navigator.pop(true);
    } catch (e) {
      if (mounted) setState(() => _saving = false);
      messenger.showSnackBar(
          SnackBar(content: Text('Could not save the certificate. ${friendlyError(e)}')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final semantic = MlSemantic.of(context);
    final r = widget.row;
    return AlertDialog(
      title: const Text('Quality certificate'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // A Wrap: the plate takes its own width first and this line —
              // waybill, commodity and tonnage, which is how the load being
              // certified is identified — takes what is left, which on a phone
              // was 170px of the 205 it needs.
              Wrap(
                spacing: 8,
                runSpacing: 2,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  MlPlatePill(r.truckReg ?? '—', fontSize: 12),
                  Text(
                    [
                      if (r.reference != null) r.reference!,
                      if (r.commodity != null) r.commodity!,
                      if (r.netTons != null)
                        '${r.netTons!.toStringAsFixed(2)} t',
                    ].join(' · '),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: context.mlText.bodyMedium.copyWith(
                      color: semantic.textMuted,
                    ),
                  ),
                ],
              ),
              if (r.specCr2o3Pct != null ||
                  r.specMoistureMaxPct != null ||
                  r.specSizing != null) ...[
                const SizedBox(height: 10),
                Text(
                  'Contract spec: '
                  '${r.specCr2o3Pct != null ? 'Cr₂O₃ ≥ ${r.specCr2o3Pct}% ' : ''}'
                  '${r.specMoistureMaxPct != null ? '· moisture ≤ ${r.specMoistureMaxPct}% ' : ''}'
                  '${r.specSizing != null ? '· sizing ${r.specSizing}' : ''}',
                  style: context.mlText.bodySmall.copyWith(
                    color: semantic.textMuted,
                  ),
                ),
              ],
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _cr2o3,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Cr₂O₃ %',
                        border: OutlineInputBorder(),
                        suffixText: '%',
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _moisture,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Moisture %',
                        border: OutlineInputBorder(),
                        suffixText: '%',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _sizing,
                decoration: const InputDecoration(
                  labelText: 'Sizing',
                  hintText: 'e.g. 6–15 mm lumpy / −1 mm fines',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _notes,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Notes (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              MultiFileDropPicker(
                label: r.certPath == null
                    ? 'Lab certificate (PDF or photo)'
                    : 'Replace certificate file (current: '
                        '${r.certFileName ?? 'attached'})',
                hint: 'Drop the lab certificate here or click to browse',
                files: _files,
                allowMultiple: false,
                allowedExtensions: const ['pdf', 'png', 'jpg', 'jpeg', 'webp'],
                onChanged: (f) => setState(() => _files = f),
              ),
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
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save certificate'),
        ),
      ],
    );
  }
}
