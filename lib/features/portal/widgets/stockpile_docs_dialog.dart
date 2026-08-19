import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:flutter_application_1/core/services/storage_asset_service.dart';
import 'package:flutter_application_1/core/utils/safe_ref.dart';
import 'package:flutter_application_1/core/widgets/multi_file_drop_picker.dart';
import 'package:flutter_application_1/features/portal/models/stockpile_entry.dart';
import 'package:flutter_application_1/features/portal/providers/lifecycle_provider.dart';
import 'package:flutter_application_1/core/utils/friendly_error.dart';

/// Upload + view stockpile documents of one [kind] ('lab_result' | 'picture').
///
/// Lists the stockpile's existing docs of that kind (each opens a short-lived
/// signed URL) and lets a stockpile writer add more via the shared
/// [MultiFileDropPicker]. Files land in the private `request_docs` bucket;
/// metadata rows in `stockpile_docs`. Wired from the "Upload results" / "Upload
/// picture" actions on the stockpile card (was a dead "coming soon" stub).
Future<void> showStockpileDocsDialog(
  BuildContext context,
  WidgetRef ref, {
  required String supplierCompanyId,
  required StockpileEntry pile,
  required String kind,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => _StockpileDocsDialog(
      supplierCompanyId: supplierCompanyId,
      pile: pile,
      kind: kind,
    ),
  );
}

class _StockpileDocsDialog extends ConsumerStatefulWidget {
  final String supplierCompanyId;
  final StockpileEntry pile;
  final String kind;

  const _StockpileDocsDialog({
    required this.supplierCompanyId,
    required this.pile,
    required this.kind,
  });

  @override
  ConsumerState<_StockpileDocsDialog> createState() =>
      _StockpileDocsDialogState();
}

class _StockpileDocsDialogState extends ConsumerState<_StockpileDocsDialog> {
  var _files = <PickedRequestFile>[];
  var _uploading = false;

  bool get _isPicture => widget.kind == 'picture';
  String get _title => _isPicture ? 'Pictures' : 'Lab results';

  /// Strip the `<uuid>_` prefix the uploader adds, showing the original name.
  static String _displayName(String path) {
    final base = path.split('/').last;
    return base.replaceFirst(RegExp(r'^[0-9a-fA-F-]{36}_'), '');
  }

  Future<void> _open(String path) async {
    final url =
        await ref.read(storageAssetServiceProvider).resolveRequestDocUrl(path);
    if (url == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open the document.')),
        );
      }
      return;
    }
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  Future<void> _upload() async {
    if (_files.isEmpty) return;
    setState(() => _uploading = true);
    try {
      await ref.read(lifecycleServiceProvider).uploadStockpileDocs(
            supplierCompanyId: widget.supplierCompanyId,
            stockpileId: widget.pile.id,
            kind: widget.kind,
            files: [for (final f in _files) (name: f.name, bytes: f.bytes)],
          );
      ref.invalidateIfMounted(stockpileDocsProvider(widget.pile.id));
      if (mounted) {
        setState(() {
          _files = [];
          _uploading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$_title uploaded to ${widget.pile.name}.')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _uploading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not upload. ${friendlyError(e)}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final docsAsync = ref.watch(stockpileDocsProvider(widget.pile.id));
    return AlertDialog(
      title: Text('$_title · ${widget.pile.name}'),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _isPicture
                    ? 'Photos of this stockpile. Uploaded pictures are listed '
                        'below and open in your browser.'
                    : 'Lab-result PDFs / reports for this stockpile. Uploaded '
                        'documents are listed below and open in your browser.',
                style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 14),
              docsAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: LinearProgressIndicator(),
                ),
                error: (e, _) => Text(
                  'Could not load documents. ${friendlyError(e)}',
                  style: TextStyle(color: cs.error),
                ),
                data: (all) {
                  final docs =
                      all.where((d) => d.kind == widget.kind).toList();
                  if (docs.isEmpty) {
                    return Text(
                      'No ${_title.toLowerCase()} uploaded yet.',
                      style: TextStyle(color: cs.onSurfaceVariant),
                    );
                  }
                  return Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final d in docs)
                        ActionChip(
                          avatar: Icon(
                            _isPicture
                                ? Icons.image_outlined
                                : Icons.picture_as_pdf_outlined,
                            size: 16,
                          ),
                          label: Text(
                            _displayName(d.storagePath),
                            style: const TextStyle(fontSize: 12),
                          ),
                          onPressed: () => _open(d.storagePath),
                        ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),
              MultiFileDropPicker(
                label: _isPicture
                    ? 'Add pictures'
                    : 'Add lab results / reports (PDF)',
                hint: _isPicture
                    ? 'Drag & drop images here, or click to browse.'
                    : 'Drag & drop PDFs here, or click to browse.\n'
                        'Multiple files allowed.',
                icon: _isPicture
                    ? Icons.add_photo_alternate_outlined
                    : Icons.picture_as_pdf_outlined,
                allowMultiple: true,
                allowedExtensions: _isPicture
                    ? const ['png', 'jpg', 'jpeg', 'webp', 'heic']
                    : const ['pdf'],
                files: _files,
                enabled: !_uploading,
                onChanged: (next) => setState(() => _files = next),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _uploading ? null : () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
        FilledButton.icon(
          onPressed: (_uploading || _files.isEmpty) ? null : _upload,
          icon: _uploading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.upload_rounded, size: 18),
          label: Text(_uploading ? 'Uploading…' : 'Upload'),
        ),
      ],
    );
  }
}
