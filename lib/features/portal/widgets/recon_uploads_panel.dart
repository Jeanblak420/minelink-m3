import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:flutter_application_1/core/design/tokens/m3/ml_typography.dart';
import 'package:flutter_application_1/core/services/storage_asset_service.dart';
import 'package:flutter_application_1/core/utils/safe_ref.dart';
import 'package:flutter_application_1/core/widgets/multi_file_drop_picker.dart';
import 'package:flutter_application_1/features/portal/models/raw_recon_row.dart';
import 'package:flutter_application_1/features/portal/models/trip_reconciliation.dart';
import 'package:flutter_application_1/features/portal/services/recon_exporter.dart';
import 'package:flutter_application_1/features/portal/services/reconciliation_service.dart';
import 'package:flutter_application_1/core/design/components/ml_components.dart';
import 'package:flutter_application_1/features/portal/widgets/raw_recon_view.dart';
import 'package:flutter_application_1/features/portal/widgets/weight_reconciliation_view.dart';
import 'package:flutter_application_1/core/utils/friendly_error.dart';
import 'package:flutter_application_1/core/time/ml_time.dart';

/// The export→edit→re-upload round-trip (CLAUDE.md §4): per side (A raw /
/// B reconciled) the system retains exactly TWO versions — the original
/// system snapshot (immutable, taken at first upload) and the latest edited
/// upload (replaced by each new upload). Both shown side by side, labelled.
///
/// Uploading is allowed for the initiating org's admins and the super-admin;
/// the server rejects everyone else (save_recon_upload + storage RLS). Set
/// [canEdit] false for non-initiator parties (e.g. the transporter) so the
/// upload control is hidden and the panel reads as view-only, matching the
/// server rule.
class ReconUploadsPanel extends ConsumerStatefulWidget {
  const ReconUploadsPanel({
    super.key,
    required this.companyId,
    this.canEdit = true,
  });

  final String companyId;
  final bool canEdit;

  @override
  ConsumerState<ReconUploadsPanel> createState() => _ReconUploadsPanelState();
}

class _ReconUploadsPanelState extends ConsumerState<ReconUploadsPanel> {
  bool _busy = false;

  String _buildOriginalCsv(String side) {
    if (side == 'A') {
      final rows =
          ref.read(rawReconRowsProvider(widget.companyId)).valueOrNull ??
          const <RawReconRow>[];
      return ReconExporter.buildCsv(
        RawReconView.csvHeaders,
        RawReconView.csvRows(rows),
      );
    }
    final rows =
        ref.read(tripReconciliationsProvider(widget.companyId)).valueOrNull ??
        const <TripReconciliation>[];
    return ReconExporter.buildCsv(
      WeightReconciliationView.exportHeaders,
      WeightReconciliationView.exportRows(rows),
    );
  }

  Future<void> _openPath(String path) async {
    final url = await ref
        .read(storageAssetServiceProvider)
        .resolveReconDocUrl(path);
    if (url == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open the file.')),
        );
      }
      return;
    }
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  Future<void> _uploadEdited(String side) async {
    final files = <PickedRequestFile>[];
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text('Upload edited copy — Side $side'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'The original system export is kept unchanged; this upload '
                  'replaces only the previous edited copy.',
                  style: context.mlText.bodyMedium.copyWith(
                    color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 14),
                MultiFileDropPicker(
                  label: 'Edited reconciliation (Excel / CSV / PDF)',
                  hint: 'Drag & drop the edited file here, or click to browse.',
                  icon: Icons.upload_file_outlined,
                  allowMultiple: false,
                  allowedExtensions: const ['xlsx', 'xls', 'csv', 'pdf'],
                  files: files,
                  onChanged: (next) => setState(() {
                    files
                      ..clear()
                      ..addAll(next);
                  }),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: files.isEmpty
                  ? null
                  : () => Navigator.of(ctx).pop(true),
              child: const Text('Upload'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || files.isEmpty) return;

    if (mounted) setState(() => _busy = true);
    try {
      await ref
          .read(reconciliationServiceProvider)
          .saveEditedUpload(
            companyId: widget.companyId,
            side: side,
            fileName: files.first.name,
            bytes: files.first.bytes,
            buildOriginalCsv: () => _buildOriginalCsv(side),
          );
      ref.invalidateIfMounted(reconUploadPairsProvider(widget.companyId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Edited copy saved for Side $side.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(friendlyError(e))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final semantic = MlSemantic.of(context);
    final async = ref.watch(reconUploadPairsProvider(widget.companyId));

    return MlCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // The action goes in the header's own slot rather than a Row wrapped
          // around it: a Row hands an unflexed button UNBOUNDED width
          // (CLAUDE.md 10.4) and squeezes the Expanded title to whatever is
          // left, which on a phone is less than the title needs. The slot
          // drops the action under the title instead.
          MlSectionTitle(
            'Edited versions',
            meta: async.valueOrNull == null
                ? null
                : mlCount(async.value!.length, 'upload'),
            icon: Icons.history_edu_outlined,
            margin: EdgeInsets.zero,
            action: IconButton(
              tooltip: 'Refresh',
              onPressed: () =>
                  ref.invalidate(reconUploadPairsProvider(widget.companyId)),
              icon: const Icon(Icons.refresh_rounded, size: 20),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            widget.canEdit
                ? 'Export a side, edit it externally, then re-upload. The '
                      'original is never overwritten — the system keeps it next '
                      'to your latest edited copy for future enquiries.'
                : 'View-only: only the org that initiated the flow (or MineLink) '
                      'can upload edited reconciliations. You can open the '
                      'original and any edited copies here.',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: semantic.textMuted),
          ),
          const SizedBox(height: 14),
          async.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => Text(
              'Could not load versions. ${friendlyError(e)}',
              style: TextStyle(color: semantic.textMuted),
            ),
            data: (pairs) {
              final bySide = {for (final p in pairs) p.side: p};
              return Column(
                children: [
                  _sideRow(context, 'A', 'Raw (Side A)', bySide['A']),
                  const Divider(height: 22),
                  _sideRow(context, 'B', 'Reconciled (Side B)', bySide['B']),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _sideRow(
    BuildContext context,
    String side,
    String label,
    ReconUploadPair? pair,
  ) {
    final semantic = MlSemantic.of(context);

    final title = Text(
      label,
      style: context.mlText.titleSmall.copyWith(
        color: semantic.textStrong,
        fontWeight: FontWeight.w700,
      ),
    );

    final versions = pair == null
        ? Text(
            'No edited copy uploaded yet.',
            style: context.mlText.bodyMedium.copyWith(
              color: semantic.textFaint,
            ),
          )
        : Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ActionChip(
                avatar: const Icon(Icons.lock_outline, size: 15),
                label: Text(
                  'Original — ${MlTime.stamp(pair.originalCreatedAt)}',
                  style: const TextStyle(fontSize: 12),
                ),
                onPressed: () => _openPath(pair.originalPath),
              ),
              if (pair.editedPath != null)
                ActionChip(
                  avatar: const Icon(Icons.edit_outlined, size: 15),
                  label: Text(
                    'Edited — uploaded ${pair.editedUploadedAt == null ? '—' : MlTime.stamp(pair.editedUploadedAt!)}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  onPressed: () => _openPath(pair.editedPath!),
                ),
            ],
          );

    final action = widget.canEdit
        ? MlButton.outline(
            label: 'Upload edited',
            icon: Icons.upload_outlined,
            compact: true,
            onPressed: _busy ? null : () => _uploadEdited(side),
          )
        : null;

    // ── Below this it stacks. ─────────────────────────────────────────────
    //
    // This was one `Row`: a `SizedBox(width: 150)` label, an `Expanded` middle,
    // and an UNFLEXED "Upload edited" button. A non-flex child of a Row is laid
    // out against unbounded width (CLAUDE.md §10.4), so 150 + 10 + ~150 of
    // button leaves the Expanded nothing on a phone and the row simply runs
    // over — measured 2026-08-20 at 360px: 22px at text scale 1.0 and 50px at
    // 1.3, on the mine's, the buyer's and the transporter's Reconciliations
    // screens at once.
    //
    // No sweep had seen it because `reconUploadPairsProvider` had no fixture:
    // with no version pairs the panel renders one short sentence, which cannot
    // overflow. The row only exists once there is something to reconcile.
    //
    // The threshold scales with the type, the same way `MlSectionTitle`'s does.
    // A fixed breakpoint under a user-controlled text size is only right at one
    // setting — see the bottom navigation bar for the same fault at a larger
    // scale.
    return LayoutBuilder(
      builder: (context, c) {
        final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
        if (c.maxWidth < 520 * scale) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              title,
              const SizedBox(height: 8),
              versions,
              if (action != null) ...[
                const SizedBox(height: 10),
                Align(alignment: Alignment.centerLeft, child: action),
              ],
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 150, child: title),
            Expanded(child: versions),
            if (action != null) ...[
              const SizedBox(width: 10),
              action,
            ],
          ],
        );
      },
    );
  }
}
