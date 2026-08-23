import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:flutter_application_1/core/design/tokens/m3/ml_typography.dart';
import 'package:flutter_application_1/core/utils/safe_ref.dart';
import 'package:flutter_application_1/features/portal/models/load_quality.dart';
import 'package:flutter_application_1/features/portal/services/quality_service.dart';
import 'package:flutter_application_1/features/portal/services/recon_exporter.dart';
import 'package:flutter_application_1/core/design/components/ml_components.dart';
import 'package:flutter_application_1/features/portal/widgets/quality_cert_dialog.dart';
import 'package:flutter_application_1/core/utils/friendly_error.dart';

/// The per-load quality table (CLAUDE.md §4 quality certificates): each
/// delivered load with its structured certificate (Cr₂O₃ % / moisture % /
/// sizing), the contract spec it is judged against, and the penalty outputs —
/// payable tons and grade factor. Reused by the mine (editable: attach/edit
/// certificates), the buyer (view), and the super-admin combined view
/// ([companyId] null). Server-side scoping decides which loads are visible.
class LoadQualityTable extends ConsumerWidget {
  const LoadQualityTable({
    super.key,
    required this.companyId,
    this.canEdit = false,
    this.supplierCompanyId,
  });

  /// Scope company (null = the platform admin's combined view).
  final String? companyId;

  /// True on the mine's screen: rows show Attach/Edit certificate actions.
  final bool canEdit;

  /// The mine's company id used for certificate file uploads. Required when
  /// [canEdit] is true.
  final String? supplierCompanyId;

  static String _t(double? v) => v == null ? '—' : '${v.toStringAsFixed(2)} t';
  static String _p(double? v) => v == null ? '—' : '${v.toStringAsFixed(1)}%';

  static const exportHeaders = [
    'REFERENCE',
    'TRUCK REGISTRATION NO',
    'PRODUCT',
    'SOURCE',
    'CUSTOMER',
    'NET (t)',
    'DELIVERED (t)',
    'CR2O3 %',
    'SPEC CR2O3 %',
    'MOISTURE %',
    'SPEC MAX MOISTURE %',
    'SIZING',
    'PAYABLE (t)',
    'GRADE FACTOR',
    'CERTIFICATE',
  ];

  static List<List<String>> exportRows(List<LoadQualityRow> rows) => [
    for (final r in rows)
      [
        r.reference ?? '',
        r.truckReg ?? '',
        r.commodity ?? '',
        r.sourceName ?? '',
        r.customerName ?? '',
        r.netTons?.toStringAsFixed(2) ?? '',
        r.deliveredTons?.toStringAsFixed(2) ?? '',
        r.cr2o3Pct?.toStringAsFixed(2) ?? '',
        r.specCr2o3Pct?.toStringAsFixed(2) ?? '',
        r.moisturePct?.toStringAsFixed(2) ?? '',
        r.specMoistureMaxPct?.toStringAsFixed(2) ?? '',
        r.sizing ?? '',
        r.payableTons?.toStringAsFixed(2) ?? '',
        r.gradeFactor?.toStringAsFixed(4) ?? '',
        r.certPath == null ? '' : (r.certFileName ?? 'attached'),
      ],
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(loadQualityProvider(companyId));
    final semantic = MlSemantic.of(context);

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
            'Load quality certificates',
            // Counts certificates, not loads: "2 certificates" used to sit
            // directly above "1 of 2 loads certified" (Phase 3, 2026-08-23).
            meta: async.valueOrNull == null
                ? null
                : mlCount(
                    async.value!.where((r) => r.hasCert).length,
                    'certificate',
                  ),
            icon: Icons.science_outlined,
            margin: EdgeInsets.zero,
            action: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                async.maybeWhen(
                  data: (rows) => MlButton.outline(
                    label: 'Export',
                    icon: Icons.download_outlined,
                    compact: true,
                    onPressed: () => ReconExporter.pickFormatAndExport(
                      context,
                      title: 'Load quality certificates',
                      filenameBase: 'load_quality',
                      headers: exportHeaders,
                      rows: exportRows(rows),
                    ),
                  ),
                  orElse: () => const SizedBox.shrink(),
                ),
                IconButton(
                  tooltip: 'Refresh',
                  onPressed: () =>
                      ref.invalidate(loadQualityProvider(companyId)),
                  icon: const Icon(Icons.refresh_rounded, size: 20),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            canEdit
                ? 'Attach the lab certificate to each delivered load: Cr₂O₃ %, '
                      'moisture % and sizing against the contract spec. Excess '
                      'moisture and low grade reduce the payable tons.'
                : 'Each delivered load\'s certified quality vs the contract '
                      'spec, with the payable-tons penalty calc.',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: semantic.textMuted),
          ),
          const SizedBox(height: 14),
          async.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 28),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => Text(
              'Could not load quality data. ${friendlyError(e)}',
              style: TextStyle(color: semantic.textMuted),
            ),
            data: (rows) {
              if (rows.isEmpty) {
                return MlEmptyState(
                  icon: Icons.science_outlined,
                  title: 'No loaded trips yet.',
                  message:
                      'Loads appear here once trucks are weighed at the '
                      'weighbridge; the mine then attaches each load\'s '
                      'quality certificate.',
                );
              }
              final certified = rows.where((r) => r.hasCert).length;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$certified of ${mlCount(rows.length, 'load')} certified',
                    style: context.mlText.titleSmall.copyWith(
                      color: semantic.textMuted,
                    ),
                  ),
                  const SizedBox(height: 10),
                  MlDataTable(
                    columns: [
                      const MlColumn('Truck', flex: 3, minWidth: kPlateColumnMinWidth),
                      // flex 3: "Manganese" is 75px at bodyMedium and a flex-2 column of
                      // this table is 76px wide on a phone, so the longest
                      // commodity name the platform hauls sat one pixel inside
                      // its cell and was cut anyway.
                      const MlColumn('Product', flex: 3),
                      const MlColumn('Net', flex: 2, align: TextAlign.right),
                      const MlColumn('Cr₂O₃', flex: 2, align: TextAlign.right),
                      const MlColumn(
                        'Moisture',
                        flex: 2,
                        align: TextAlign.right,
                      ),
                      const MlColumn('Sizing', flex: 2),
                      const MlColumn(
                        'Payable',
                        flex: 2,
                        align: TextAlign.right,
                      ),
                      const MlColumn('Cert', flex: 1, align: TextAlign.center),
                      // flex 3: this column holds a compact ghost button whose label is
                      // "Attach" or "Edit" beside a 16px icon. At flex 2 it was
                      // 76px and both labels were cut — a button that cannot
                      // say what it does.
                      if (canEdit) const MlColumn('', flex: 3),
                    ],
                    rows: [
                      for (final r in rows)
                        [
                          _truckCell(context, r),
                          _text(context, r.commodity ?? '—'),
                          _mono(context, _t(r.netTons)),
                          _pctCell(
                            context,
                            r.cr2o3Pct,
                            r.specCr2o3Pct,
                            belowIsBad: true,
                          ),
                          _pctCell(
                            context,
                            r.moisturePct,
                            r.specMoistureMaxPct,
                            belowIsBad: false,
                          ),
                          _text(context, r.sizing ?? '—'),
                          _payableCell(context, r),
                          _CertCell(row: r),
                          if (canEdit)
                            Center(
                              child: MlButton.ghost(
                                label: r.hasCert ? 'Edit' : 'Attach',
                                icon: r.hasCert
                                    ? Icons.edit_outlined
                                    : Icons.attach_file_rounded,
                                compact: true,
                                onPressed: () async {
                                  final saved = await showQualityCertDialog(
                                    context,
                                    ref,
                                    row: r,
                                    supplierCompanyId:
                                        supplierCompanyId ?? companyId!,
                                  );
                                  if (saved) {
                                    ref.invalidateIfMounted(
                                      loadQualityProvider(companyId),
                                    );
                                  }
                                },
                              ),
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

  /// Plate and waybill reference — side by side when they fit, stacked when
  /// they do not.
  ///
  /// This was a `Row`. The column declares `kPlateColumnMinWidth` (120px),
  /// which is what the PLATE needs — so the pill took its 106px, the reference
  /// beside it was left **6px**, and `TRP-000123` was drawn as an ellipsis.
  /// Photographed on `screen-recon-tables-phone-dark` and
  /// `screen-buyer-reconciliations-phone-dark` 2026-08-21; the waybill number
  /// is the one field on that row a person looks up by.
  ///
  /// A `Wrap`, not a wider minimum: raising the column's minimum to fit both
  /// would push this eight-column table's scroll floor past 1100px and start it
  /// scrolling on a desktop that has room for it today.
  Widget _truckCell(BuildContext context, LoadQualityRow r) {
    return Wrap(
      spacing: 8,
      runSpacing: 2,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        MlPlatePill(r.truckReg ?? '—', fontSize: 12),
        if (r.reference != null)
          Text(
            r.reference!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.mlText.code(
              color: MlSemantic.of(context).textMuted,
              size: 12,
              weight: FontWeight.w400,
            ),
          ),
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

  /// Actual vs spec percentage: tinted red/amber when the value breaches the
  /// contract spec ([belowIsBad] true = grade must reach spec; false =
  /// moisture must stay under spec).
  Widget _pctCell(
    BuildContext context,
    double? actual,
    double? spec, {
    required bool belowIsBad,
  }) {
    if (actual == null) return _mono(context, '—', muted: true);
    final brightness = Theme.of(context).brightness;
    MlTone tone = MlTone.neutral;
    if (spec != null) {
      final breach = belowIsBad ? actual < spec : actual > spec;
      tone = breach ? MlTone.error : MlTone.done;
    }
    final colors = tone.colors(brightness);
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: colors.bg,
          borderRadius: BorderRadius.circular(MlTokens.rSm),
        ),
        child: Text(
          '${_p(actual)}${spec != null ? ' / ${_p(spec)}' : ''}',
          style: context.mlText.code(
            color: colors.fg,
            size: 12,
            weight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _payableCell(BuildContext context, LoadQualityRow r) {
    if (r.payableTons == null) {
      // A DASH, not the delivered tonnage under a Payable heading.
      //
      // `list_load_quality` returns NULL for `payable_tons` whenever the load
      // has no moisture reading — no certificate, no penalty, nothing to
      // compute. This cell used to fill that gap with `deliveredTons ?? netTons`
      // and mute it, which is a DIFFERENT QUANTITY wearing the same heading and
      // the same format.
      //
      // Photographed on the live mine Quality screen, 2026-08-23, under a
      // header reading `0 of 35 loads certified` and a Moisture column that was
      // `—` on every row:
      //
      //     TRUCK      NET        MOISTURE   PAYABLE
      //     S6W001GP   34.20 t    —          34.05 t
      //     KVK007MP   31.80 t    —          34.90 t    <- payable ABOVE net
      //
      // Payable is defined as the tonnage reduced by an excess-moisture
      // penalty, so it can never exceed the mine net. The second row is the
      // delivered figure, and nothing on the screen said so.
      //
      // `exportRows` already writes an empty cell here, so the spreadsheet and
      // the screen were telling a mine two different things about the same
      // load. The dash is the export's answer, in the vocabulary the rest of
      // the product uses for a figure with nothing behind it.
      return _mono(context, '—', muted: true);
    }
    final penalised = (r.excessMoisturePct != null) || r.isBelowGradeSpec;
    final tone = penalised ? MlTone.warn : MlTone.done;
    final colors = tone.colors(Theme.of(context).brightness);
    return Align(
      alignment: Alignment.centerRight,
      child: Tooltip(
        message: [
          if (r.excessMoisturePct != null)
            '−${r.excessMoisturePct!.toStringAsFixed(1)}% excess moisture',
          if (r.gradeFactor != null)
            'grade factor ${r.gradeFactor!.toStringAsFixed(3)}',
        ].join(' · '),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          decoration: BoxDecoration(
            color: colors.bg,
            borderRadius: BorderRadius.circular(MlTokens.rSm),
          ),
          child: Text(
            _t(r.payableTons),
            style: context.mlText.code(
              color: colors.fg,
              size: 12,
              weight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

/// Opens the load's lab certificate file (private `quality_certs` bucket) via
/// a short-lived signed URL — party-scoped by the storage RLS.
class _CertCell extends ConsumerWidget {
  final LoadQualityRow row;
  const _CertCell({required this.row});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (row.certPath == null) {
      return Center(
        child: Text(
          '—',
          style: TextStyle(color: MlSemantic.of(context).textFaint),
        ),
      );
    }
    return IconButton(
      tooltip:
          'Open certificate'
          '${row.certFileName != null ? ' (${row.certFileName})' : ''}',
      icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
      visualDensity: VisualDensity.compact,
      onPressed: () async {
        final messenger = ScaffoldMessenger.of(context);
        try {
          final url = await ref
              .read(qualityServiceProvider)
              .resolveCertUrl(row.certPath);
          if (url == null) {
            messenger.showSnackBar(
              const SnackBar(content: Text('Could not open the certificate.')),
            );
            return;
          }
          await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
        } catch (_) {
          messenger.showSnackBar(
            const SnackBar(content: Text('Could not open the certificate.')),
          );
        }
      },
    );
  }
}
