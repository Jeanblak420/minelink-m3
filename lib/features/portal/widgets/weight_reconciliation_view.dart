import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter_application_1/core/design/tokens/m3/ml_typography.dart';
import 'package:flutter_application_1/features/portal/models/recon_dispute.dart';
import 'package:flutter_application_1/features/portal/models/trip_reconciliation.dart';
import 'package:flutter_application_1/features/portal/services/dispute_service.dart';
import 'package:flutter_application_1/features/portal/services/recon_exporter.dart';
import 'package:flutter_application_1/features/portal/services/reconciliation_service.dart';
import 'package:flutter_application_1/features/portal/widgets/dispute_widgets.dart';
import 'package:flutter_application_1/core/design/components/ml_components.dart';
import 'package:flutter_application_1/features/portal/widgets/pod_photo_link.dart';
import 'package:flutter_application_1/features/portal/utils/variance_severity.dart';
import 'package:flutter_application_1/core/utils/friendly_error.dart';

/// Side B — the system-computed weight reconciliation (CLAUDE.md §4): per trip,
/// the mine Net Weight loaded (authoritative) vs the delivered tons at offload,
/// with the variance (lost/stolen/swapped mass). Reusable across the buyer,
/// mine and transporter reconciliation screens; server-side scoping decides
/// which trips each party sees.
class WeightReconciliationView extends ConsumerWidget {
  const WeightReconciliationView({super.key, required this.companyId});

  final String companyId;


  static String _t(double? v) => v == null ? '—' : '${v.toStringAsFixed(2)} t';

  /// Export columns (also used as the Side B original snapshot for the
  /// two-version round-trip in ReconUploadsPanel).
  static const exportHeaders = [
    'REFERENCE',
    'TRUCK REGISTRATION NO',
    'PRODUCT',
    'SOURCE',
    'CUSTOMER',
    'TRANSPORTER',
    'MINE NET (t)',
    'DELIVERED (t)',
    'VARIANCE (t)',
    'STATUS',
  ];

  static List<List<String>> exportRows(List<TripReconciliation> rows) => [
        for (final r in rows)
          [
            r.reference ?? '',
            r.truckReg ?? '',
            r.commodity ?? '',
            r.sourceName ?? '',
            r.customerName ?? '',
            r.transporterName ?? '',
            r.mineNetTons?.toStringAsFixed(2) ?? '',
            r.deliveredTons?.toStringAsFixed(2) ?? '',
            r.variance?.toStringAsFixed(2) ?? '',
            r.tripStatus ?? '',
          ],
      ];

  /// Severity comes from the shared classifier so Side A and Side B cannot
  /// paint the same load differently.
  ///
  /// This used to be a flat `variance > 0.05 t` → error. On the live data that
  /// flagged **all 35** reconciled loads as errors — every one is short by
  /// ≤ 0.20 t on ~35 t, about 0.57%, which is ordinary weighbridge scatter. A
  /// red that fires on every row is not a signal, it is wallpaper. Severity is
  /// now a percentage of the load: see `variance_severity.dart`.
  MlTone _varianceTone(double? v, double? netTons) => varianceTone(
        varianceSeverityOf(varianceTons: v, netTons: netTons),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(tripReconciliationsProvider(companyId));
    final disputesAsync = ref.watch(reconDisputesProvider(companyId));
    final semantic = MlSemantic.of(context);

    return MlCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Two actions in MlSectionTitle's single `action` slot, gathered
          // into a Wrap so they can still fall to a second line. A Row around
          // the header would hand them UNBOUNDED width (CLAUDE.md §10.4) and
          // squeeze the title to whatever was left.
          MlSectionTitle(
            'Weight reconciliation',
            meta: async.valueOrNull == null
                ? null
                : mlCount(async.value!.length, 'delivered load'),
            icon: Icons.compare_arrows_rounded,
            margin: EdgeInsets.zero,
            action: Wrap(spacing: 8, runSpacing: 8, children: [
              async.maybeWhen(
                data: (rows) {
                  final delivered = rows.where((r) => r.isDelivered).toList();
                  final loaded =
                      rows.fold<double>(0, (s, r) => s + (r.mineNetTons ?? 0));
                  final deliveredT = delivered.fold<double>(
                      0, (s, r) => s + (r.deliveredTons ?? 0));
                  final variance = delivered.fold<double>(
                      0, (s, r) => s + (r.variance ?? 0));
                  return MlButton.outline(
                    label: 'Export',
                    icon: Icons.download_outlined,
                    compact: true,
                    onPressed: () => ReconExporter.pickFormatAndExport(
                      context,
                      title: 'Reconciliations — Side B (reconciled)',
                      filenameBase: 'recon_side_b',
                      headers: exportHeaders,
                      rows: exportRows(rows),
                      summary: {
                        'Loaded (mine net)': _t(loaded),
                        'Delivered': _t(deliveredT),
                        'Net variance': _t(variance),
                      },
                    ),
                  );
                },
                orElse: () => const SizedBox.shrink(),
              ),
              IconButton(
                tooltip: 'Refresh',
                onPressed: () =>
                    ref.invalidate(tripReconciliationsProvider(companyId)),
                icon: const Icon(Icons.refresh_rounded, size: 20),
              ),
            ]),
          ),
          const SizedBox(height: 4),
          Text(
            'System cross-check: mine Net Weight loaded (authoritative) vs '
            'delivered tons at offload. Variance is the mass lost en route.',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: semantic.textMuted),
          ),
          const SizedBox(height: 14),
          async.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 28),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => Text('Could not load reconciliation. ${friendlyError(e)}',
                style: TextStyle(color: semantic.textMuted)),
            data: (rows) {
              if (rows.isEmpty) {
                return MlEmptyState(
                  icon: Icons.compare_arrows_rounded,
                  title: 'Nothing to reconcile yet.',
                  message:
                      'Rows appear once trucks are loaded; variance is computed '
                      'when the driver uploads proof of delivery.',
                );
              }
              // Current dispute per trip (list is newest-first; at most one is
              // active at a time — take the newest as the row's state).
              final disputesByTrip = <String, ReconDispute>{};
              for (final x
                  in (disputesAsync.asData?.value ?? const <ReconDispute>[])) {
                disputesByTrip.putIfAbsent(x.tripId, () => x);
              }
              final delivered = rows.where((r) => r.isDelivered).toList();
              final totalLoaded = rows.fold<double>(
                  0, (s, r) => s + (r.mineNetTons ?? 0));
              final totalDelivered = delivered.fold<double>(
                  0, (s, r) => s + (r.deliveredTons ?? 0));
              final totalVariance = delivered.fold<double>(
                  0, (s, r) => s + (r.variance ?? 0));
              // The denominator for the TOTAL's severity is the loaded mass of
              // the delivered rows only — `totalLoaded` includes loads still on
              // the road, which have no variance yet and would dilute the
              // percentage toward zero.
              final deliveredLoaded = delivered.fold<double>(
                  0, (s, r) => s + (r.mineNetTons ?? 0));

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LayoutBuilder(builder: (context, c) {
                    final cols = c.maxWidth > 620 ? 3 : 1;
                    const gap = 12.0;
                    final w = cols == 1
                        ? c.maxWidth
                        : (c.maxWidth - gap * (cols - 1)) / cols;
                    final tiles = [
                      MlStatCard(
                        label: 'Loaded (mine net)',
                        value: _t(totalLoaded),
                        icon: Icons.scale_outlined,
                        tone: MlTone.accent,
                      ),
                      MlStatCard(
                        label: 'Delivered',
                        value: _t(totalDelivered),
                        icon: Icons.local_shipping_outlined,
                        tone: MlTone.transit,
                      ),
                      MlStatCard(
                        label: 'Net variance',
                        value: _t(totalVariance),
                        icon: Icons.compare_arrows_rounded,
                        tone: _varianceTone(totalVariance, deliveredLoaded),
                      ),
                    ];
                    return Wrap(
                      spacing: gap,
                      runSpacing: gap,
                      children: [
                        for (final t in tiles) SizedBox(width: w, child: t),
                      ],
                    );
                  }),
                  const SizedBox(height: 16),
                  MlDataTable(
                    columns: const [
                      MlColumn('Truck', flex: 3),
                      MlColumn('Source', flex: 3),
                      MlColumn('Customer', flex: 3),
                      MlColumn('Mine net', flex: 2, align: TextAlign.right),
                      MlColumn('Delivered', flex: 2, align: TextAlign.right),
                      MlColumn('Variance', flex: 2, align: TextAlign.right),
                      MlColumn('POD', flex: 1, align: TextAlign.center),
                      MlColumn('Dispute', flex: 2, align: TextAlign.center),
                    ],
                    rows: [
                      for (final r in rows)
                        [
                          _truckCell(context, r),
                          _text(context, r.sourceName ?? '—'),
                          _text(context, r.customerName ?? '—'),
                          _mono(context, _t(r.mineNetTons)),
                          _mono(context,
                              r.isDelivered ? _t(r.deliveredTons) : 'Pending',
                              muted: !r.isDelivered),
                          _varianceCell(context, r),
                          PodPhotoIcon(path: r.podPhotoPath),
                          _DisputeCell(
                            row: r,
                            dispute: disputesByTrip[r.tripId],
                            companyId: companyId,
                          ),
                        ],
                    ],
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _truckCell(BuildContext context, TripReconciliation r) {
    return Row(
      children: [
        MlPlatePill(r.truckReg ?? '—', fontSize: 12),
        if (r.commodity != null) ...[
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              r.commodity!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.mlText.bodySmall.copyWith(
                color: MlSemantic.of(context).textMuted,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _text(BuildContext context, String text) => Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: context.mlText.bodyMedium.copyWith(
          color: MlSemantic.of(context).textBody,
        ),
      );

  Widget _mono(BuildContext context, String text, {bool muted = false}) => Text(
        text,
        textAlign: TextAlign.right,
        maxLines: 1,
        style: context.mlText.code(
          color: muted ? MlSemantic.of(context).textFaint : MlSemantic.of(context).textStrong,
          size: 13,
          weight: FontWeight.w600,
        ),
      );

  Widget _varianceCell(BuildContext context, TripReconciliation r) {
    if (!r.isDelivered) {
      return _mono(context, '—', muted: true);
    }
    final tone = _varianceTone(r.variance, r.mineNetTons)
        .colors(Theme.of(context).brightness);
    final v = r.variance ?? 0;
    final sign = v > 0 ? '−' : (v < 0 ? '+' : '');
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: tone.bg,
          borderRadius: BorderRadius.circular(MlTokens.rSm),
        ),
        child: Text(
          '$sign${v.abs().toStringAsFixed(2)} t',
          style: context.mlText.code(
            color: tone.fg,
            size: 13,
            weight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

/// The dispute affordance per variance row: a status chip that opens the
/// dispute detail if one exists, or a "Dispute" button to raise one on a
/// delivered trip. Undelivered trips (no variance yet) show a muted dash.
class _DisputeCell extends ConsumerWidget {
  final TripReconciliation row;
  final ReconDispute? dispute;
  final String companyId;
  const _DisputeCell({
    required this.row,
    required this.dispute,
    required this.companyId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = dispute;
    if (d != null) {
      return Center(
        child: InkWell(
          borderRadius: BorderRadius.circular(MlTokens.rPill),
          onTap: () => showDisputeDetailDialog(
            context,
            ref,
            dispute: d,
            isAdmin: false,
            companyId: companyId,
          ),
          child: DisputeStatusChip(d.status),
        ),
      );
    }
    if (!row.isDelivered) {
      return Center(
        child: Text('—',
            style: TextStyle(color: MlSemantic.of(context).textFaint)),
      );
    }
    return Center(
      child: MlButton.ghost(
        label: 'Dispute',
        icon: Icons.flag_outlined,
        compact: true,
        onPressed: () => showRaiseDisputeDialog(
          context,
          ref,
          tripId: row.tripId,
          companyId: companyId,
          reference: row.reference,
          variance: row.variance,
        ),
      ),
    );
  }
}
