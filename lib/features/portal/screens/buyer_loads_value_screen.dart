import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:flutter_application_1/core/design/tokens/m3/ml_typography.dart';
import 'package:flutter_application_1/core/utils/safe_ref.dart';
import 'package:flutter_application_1/features/portal/models/buyer_load_value.dart';
import 'package:flutter_application_1/features/portal/services/buyer_value_service.dart';
import 'package:flutter_application_1/features/portal/services/recon_exporter.dart';
import 'package:flutter_application_1/features/portal/services/reconciliation_service.dart';
import 'package:flutter_application_1/features/portal/utils/portal_company_resolution.dart';
import 'package:flutter_application_1/features/portal/widgets/load_quality_table.dart';
import 'package:flutter_application_1/core/design/components/ml_components.dart';
import 'package:flutter_application_1/features/portal/widgets/pod_photo_link.dart';
import 'package:flutter_application_1/features/portal/widgets/portal_company_required.dart';
import 'package:flutter_application_1/core/utils/friendly_error.dart';
import 'package:flutter_application_1/core/time/ml_time.dart';

/// Buyer "Loads & value" (CLAUDE.md §4 buyer money layer): every load in Rand
/// — the agreed rate × loaded / delivered / quality-adjusted payable tons —
/// with the invoice the buyer captured per load and its variance, so
/// delivered money vs invoiced money finally reconciles. Includes the
/// read-only quality certificate view (the mine attaches, the buyer sees).
class BuyerLoadsValueScreen extends ConsumerWidget {
  const BuyerLoadsValueScreen({super.key});

  static final _num = NumberFormat('#,##0.00');
  static final _dateFmt = DateFormat('dd MMM yyyy');

  static String money(double? v, String currency) {
    if (v == null) return '—';
    final sym = currency == 'ZAR' ? 'R' : '$currency ';
    return '$sym${_num.format(v)}';
  }

  static String _t(double? v) => v == null ? '—' : '${v.toStringAsFixed(2)} t';

  static const exportHeaders = [
    'REFERENCE',
    'TRUCK REGISTRATION NO',
    'PRODUCT',
    'SOURCE',
    'TRANSPORTER',
    'NET (t)',
    'DELIVERED (t)',
    'RATE (R/t)',
    'LOADED VALUE (R)',
    'DELIVERED VALUE (R)',
    'PAYABLE (t)',
    'PAYABLE VALUE (R)',
    'INVOICE NO',
    'INVOICED (R)',
    'INVOICE VARIANCE (R)',
    'INVOICE DATE',
  ];

  static List<List<String>> exportRows(List<BuyerLoadValue> rows) => [
    for (final r in rows)
      [
        r.reference ?? '',
        r.truckReg ?? '',
        r.commodity ?? '',
        r.sourceName ?? '',
        r.transporterName ?? '',
        r.netTons?.toStringAsFixed(2) ?? '',
        r.deliveredTons?.toStringAsFixed(2) ?? '',
        r.ratePerTon?.toStringAsFixed(2) ?? '',
        r.loadedValue?.toStringAsFixed(2) ?? '',
        r.deliveredValue?.toStringAsFixed(2) ?? '',
        r.payableTons?.toStringAsFixed(2) ?? '',
        r.payableValue?.toStringAsFixed(2) ?? '',
        r.invoiceNumber ?? '',
        r.invoicedAmount?.toStringAsFixed(2) ?? '',
        r.invoiceVariance?.toStringAsFixed(2) ?? '',
        r.invoiceDate == null ? '' : _dateFmt.format(r.invoiceDate!),
      ],
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final companyId = resolvePortalCompanyId(ref);
    if (companyId == null) {
      return const PortalCompanyRequired();
    }
    final async = ref.watch(buyerTripValuesProvider(companyId));

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
            title: 'Loads & value',
            meta: async.valueOrNull == null
                ? null
                : mlCount(async.value!.length, 'load'),
            description:
                'Every load in Rand: your agreed rate × loaded, '
                'delivered and quality-adjusted payable tons — '
                'reconciled against the invoices you capture per load.',
            actions: [
              async.maybeWhen(
                data: (rows) => MlButton.outline(
                  label: 'Export',
                  icon: Icons.download_outlined,
                  compact: true,
                  onPressed: () => ReconExporter.pickFormatAndExport(
                    context,
                    title: 'Loads & value — delivered vs invoiced',
                    filenameBase: 'buyer_loads_value',
                    headers: exportHeaders,
                    rows: exportRows(rows),
                  ),
                ),
                orElse: () => const SizedBox.shrink(),
              ),
              IconButton(
                tooltip: 'Refresh',
                onPressed: () =>
                    ref.invalidate(buyerTripValuesProvider(companyId)),
                icon: const Icon(Icons.refresh_rounded),
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
              subject: 'the load values',
              error: e,
              onRetry: () => ref.invalidate(buyerTripValuesProvider(companyId)),
            ),
            data: (rows) => _Body(rows: rows, companyId: companyId),
          ),
          const SizedBox(height: 16),
          // Quality certificates on this buyer's loads (mine attaches, buyer
          // views) — the payable-tons basis for the values above.
          LoadQualityTable(companyId: companyId),
          const SizedBox(height: 60),
        ],
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  final List<BuyerLoadValue> rows;
  final String companyId;
  const _Body({required this.rows, required this.companyId});

  static const _tolerance = 0.005; // R — treat sub-cent variance as balanced

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final semantic = MlSemantic.of(context);
    if (rows.isEmpty) {
      return const MlEmptyState(
        icon: Icons.payments_outlined,
        title: 'No priced loads yet',
        message:
            'Loads appear here in Rand once trucks are weighed on a '
            'dispatched order with pricing set.',
      );
    }
    final currency = rows.first.currency;
    final deliveredValue = rows.fold<double>(
      0,
      (s, r) => s + (r.deliveredValue ?? 0),
    );
    final payableValue = rows.fold<double>(
      0,
      (s, r) => s + (r.payableValue ?? 0),
    );
    final invoiced = rows.fold<double>(
      0,
      (s, r) => s + (r.invoicedAmount ?? 0),
    );
    final withInvoice = rows.where((r) => r.hasInvoice).toList();
    final variance = withInvoice.fold<double>(
      0,
      (s, r) => s + (r.invoiceVariance ?? 0),
    );
    final unpriced = rows.where((r) => !r.isPriced).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, c) {
            final cols = c.maxWidth > 900 ? 4 : (c.maxWidth > 560 ? 2 : 1);
            const gap = 12.0;
            final w = cols == 1
                ? c.maxWidth
                : (c.maxWidth - gap * (cols - 1)) / cols;
            final tiles = [
              MlStatCard(
                label: 'Delivered value',
                value: BuyerLoadsValueScreen.money(deliveredValue, currency),
                icon: Icons.local_shipping_outlined,
                tone: MlTone.accent,
              ),
              MlStatCard(
                label: 'Payable value',
                value: BuyerLoadsValueScreen.money(payableValue, currency),
                icon: Icons.verified_outlined,
                tone: MlTone.done,
              ),
              MlStatCard(
                label: 'Invoiced',
                value: BuyerLoadsValueScreen.money(invoiced, currency),
                icon: Icons.receipt_long_outlined,
                tone: MlTone.transit,
              ),
              MlStatCard(
                label: 'Invoice variance',
                value: BuyerLoadsValueScreen.money(variance, currency),
                icon: Icons.compare_arrows_rounded,
                tone: variance.abs() <= _tolerance
                    ? MlTone.done
                    : (variance > 0 ? MlTone.error : MlTone.warn),
              ),
            ];
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [for (final t in tiles) SizedBox(width: w, child: t)],
            );
          },
        ),
        if (unpriced > 0) ...[
          const SizedBox(height: 10),
          Text(
            '${mlCount(unpriced, 'load')} ${unpriced == 1 ? 'has' : 'have'} '
            'no rate yet — pricing is set when the '
            'MineLink admin links the order.',
            style: context.mlText.bodyMedium.copyWith(color: semantic.textMuted),
          ),
        ],
        const SizedBox(height: 16),
        MlCard(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              MlSectionTitle(
                'Per-load values & invoices',
                meta:
                    '${mlCount(rows.length, 'load')} · '
                    '${rows.where((r) => r.invoicedAmount != null).length} invoiced',
                icon: Icons.payments_outlined,
                margin: EdgeInsets.zero,
              ),
              const SizedBox(height: 4),
              Text(
                'Variance = invoiced amount − the load\'s payable value '
                '(quality-adjusted when a certificate exists, else the '
                'delivered value). Red = over-invoiced.',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: semantic.textMuted),
              ),
              const SizedBox(height: 14),
              MlDataTable(
                columns: const [
                  MlColumn('Truck', flex: 3, minWidth: kPlateColumnMinWidth),
                  MlColumn('Source', flex: 2),
                  MlColumn('Delivered', flex: 2, align: TextAlign.right),
                  MlColumn('Rate', flex: 2, align: TextAlign.right),
                  MlColumn('Value', flex: 2, align: TextAlign.right),
                  MlColumn('Invoice', flex: 3),
                  MlColumn('Variance', flex: 2, align: TextAlign.right),
                  MlColumn('POD', flex: 1, align: TextAlign.center),
                  MlColumn('', flex: 2),
                ],
                rows: [
                  for (final r in rows)
                    [
                      _truckCell(context, r),
                      _text(context, r.sourceName ?? '—'),
                      _mono(
                        context,
                        r.isDelivered
                            ? BuyerLoadsValueScreen._t(r.deliveredTons)
                            : 'Pending',
                        muted: !r.isDelivered,
                      ),
                      _mono(
                        context,
                        r.ratePerTon == null
                            ? '—'
                            : '${BuyerLoadsValueScreen.money(r.ratePerTon, r.currency)}/t',
                        muted: r.ratePerTon == null,
                      ),
                      _valueCell(context, r),
                      _invoiceCell(context, r),
                      _varianceCell(context, r),
                      _PodCellLookup(row: r, companyId: companyId),
                      Center(
                        child: MlButton.ghost(
                          label: r.hasInvoice ? 'Edit' : 'Invoice',
                          icon: r.hasInvoice
                              ? Icons.edit_outlined
                              : Icons.receipt_long_outlined,
                          compact: true,
                          onPressed: () =>
                              _recordInvoice(context, ref, r, companyId),
                        ),
                      ),
                    ],
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Plate and commodity — side by side when they fit, stacked when they do
  /// not. Same fault, same fix as the reconciliation table: the column is
  /// sized for the PLATE, so a `Row` left the commodity nothing.
  Widget _truckCell(BuildContext context, BuyerLoadValue r) {
    return Wrap(
      spacing: 8,
      runSpacing: 2,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        MlPlatePill(r.truckReg ?? '—', fontSize: 12),
        if (r.commodity != null)
          Text(
            r.commodity!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.mlText.bodySmall.copyWith(
              color: MlSemantic.of(context).textMuted,
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

  /// The load's Rand value: payable when quality-adjusted (tooltip shows the
  /// unadjusted delivered value), else delivered, else loaded.
  Widget _valueCell(BuildContext context, BuyerLoadValue r) {
    final v = r.payableValue ?? r.deliveredValue ?? r.loadedValue;
    if (v == null) return _mono(context, '—', muted: true);
    final adjusted =
        r.payableValue != null &&
        r.deliveredValue != null &&
        (r.payableValue! - r.deliveredValue!).abs() > 0.005;
    final cell = _mono(context, BuyerLoadsValueScreen.money(v, r.currency));
    if (!adjusted) return cell;
    return Tooltip(
      message:
          'Quality-adjusted from '
          '${BuyerLoadsValueScreen.money(r.deliveredValue, r.currency)} '
          '(payable ${r.payableTons?.toStringAsFixed(2)} t'
          '${r.gradeFactor != null ? ' × grade ${r.gradeFactor!.toStringAsFixed(3)}' : ''})',
      child: cell,
    );
  }

  Widget _invoiceCell(BuildContext context, BuyerLoadValue r) {
    final semantic = MlSemantic.of(context);
    if (!r.hasInvoice) {
      return Text(
        'Not captured',
        style: context.mlText.bodyMedium.copyWith(color: semantic.textFaint),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          r.invoiceNumber ?? '—',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: context.mlText.code(
            color: semantic.textStrong,
            size: 12,
            weight: FontWeight.w700,
          ),
        ),
        Text(
          BuyerLoadsValueScreen.money(r.invoicedAmount, r.currency),
          style: context.mlText.bodySmall.copyWith(color: semantic.textMuted),
        ),
      ],
    );
  }

  Widget _varianceCell(BuildContext context, BuyerLoadValue r) {
    final v = r.invoiceVariance;
    if (v == null) return _mono(context, '—', muted: true);
    final tone = v.abs() <= _tolerance
        ? MlTone.done
        : (v > 0 ? MlTone.error : MlTone.warn);
    final colors = tone.colors(Theme.of(context).brightness);
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: colors.bg,
          borderRadius: BorderRadius.circular(MlTokens.rSm),
        ),
        child: Text(
          '${v > 0 ? '+' : ''}${BuyerLoadsValueScreen.money(v, r.currency)}',
          style: context.mlText.code(
            color: colors.fg,
            size: 12,
            weight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Future<void> _recordInvoice(
    BuildContext context,
    WidgetRef ref,
    BuyerLoadValue r,
    String companyId,
  ) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _InvoiceDialog(row: r, buyerCompanyId: companyId),
    );
    if (saved == true) {
      ref.invalidateIfMounted(buyerTripValuesProvider(companyId));
    }
  }
}

/// POD lookup via the party-scoped recon rows (same source as the recon
/// screens) so the buyer can open the delivery photo next to the money.
class _PodCellLookup extends ConsumerWidget {
  final BuyerLoadValue row;
  final String companyId;
  const _PodCellLookup({required this.row, required this.companyId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recons = ref
        .watch(tripReconciliationsProvider(companyId))
        .asData
        ?.value;
    String? path;
    for (final r in recons ?? const []) {
      if (r.tripId == row.tripId) {
        path = r.podPhotoPath;
        break;
      }
    }
    return PodPhotoIcon(path: path);
  }
}

class _InvoiceDialog extends ConsumerStatefulWidget {
  final BuyerLoadValue row;
  final String buyerCompanyId;
  const _InvoiceDialog({required this.row, required this.buyerCompanyId});

  @override
  ConsumerState<_InvoiceDialog> createState() => _InvoiceDialogState();
}

class _InvoiceDialogState extends ConsumerState<_InvoiceDialog> {
  late final TextEditingController _number;
  late final TextEditingController _amount;
  late final TextEditingController _tons;
  late final TextEditingController _notes;
  // `MlTime.now()`, not the device clock. CLAUDE.md 7.1: never
  // `DateTime.now()` for anything a user reads as a date. This value is
  // a DATE the operator picks and submits, so on a laptop left on UTC it
  // pre-filled YESTERDAY between midnight and 02:00 SAST -- which is
  // night shift, the hours this screen exists for.
  DateTime _date = MlTime.now();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final r = widget.row;
    _number = TextEditingController(text: r.invoiceNumber ?? '');
    _amount = TextEditingController(
      text: r.invoicedAmount?.toStringAsFixed(2) ?? '',
    );
    _tons = TextEditingController(
      text: r.invoicedTons?.toStringAsFixed(2) ?? '',
    );
    _notes = TextEditingController();
    if (r.invoiceDate != null) _date = r.invoiceDate!;
  }

  @override
  void dispose() {
    _number.dispose();
    _amount.dispose();
    _tons.dispose();
    _notes.dispose();
    super.dispose();
  }

  Widget _amountField() => TextField(
        controller: _amount,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
        ],
        decoration: const InputDecoration(
          labelText: 'Invoiced amount',
          border: OutlineInputBorder(),
          prefixText: 'R ',
        ),
      );

  Widget _tonsField() => TextField(
        controller: _tons,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
        ],
        decoration: const InputDecoration(
          labelText: 'Invoiced tons (optional)',
          border: OutlineInputBorder(),
          suffixText: 't',
        ),
      );

  Future<void> _save() async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final number = _number.text.trim();
    final amount = double.tryParse(_amount.text.trim());
    if (number.isEmpty || amount == null || amount < 0) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Enter the invoice number and a valid amount.'),
        ),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await ref
          .read(buyerValueServiceProvider)
          .saveInvoice(
            tripId: widget.row.tripId,
            buyerCompanyId: widget.buyerCompanyId,
            invoiceNumber: number,
            invoicedAmount: amount,
            invoicedTons: double.tryParse(_tons.text.trim()),
            invoiceDate: _date,
            notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
          );
      navigator.pop(true);
    } catch (e) {
      if (mounted) setState(() => _saving = false);
      messenger.showSnackBar(
        SnackBar(
          content: Text('Could not save the invoice. ${friendlyError(e)}'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final semantic = MlSemantic.of(context);
    final r = widget.row;
    return AlertDialog(
      title: const Text('Record invoice'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                [
                  if (r.reference != null) r.reference!,
                  if (r.truckReg != null) r.truckReg!,
                  if (r.deliveredTons != null)
                    'delivered ${r.deliveredTons!.toStringAsFixed(2)} t',
                ].join(' · '),
                style: context.mlText.bodyMedium.copyWith(
                  color: semantic.textMuted,
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _number,
                decoration: const InputDecoration(
                  labelText: 'Invoice number',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              // TWO FIELDS SIDE BY SIDE ONLY WHERE THEY FIT.
              //
              // At 412px each `Expanded` got ~130px and both floating labels
              // were cut — "Invoiced am…" and "Invoiced ton…". A form field
              // whose label does not say what it is asking for is worse than a
              // taller form. Photographed 2026-08-21.
              //
              // 380 is the dialog's own content width at 412; below that they
              // stack.
              LayoutBuilder(builder: (context, c) {
                if (c.maxWidth < 380) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _amountField(),
                      const SizedBox(height: 12),
                      _tonsField(),
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: _amountField()),
                    const SizedBox(width: 10),
                    Expanded(child: _tonsField()),
                  ],
                );
              }),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                icon: const Icon(Icons.event_outlined, size: 18),
                label: Text(
                  'Invoice date: ${DateFormat('dd MMM yyyy').format(_date)}',
                ),
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _date,
                    firstDate: DateTime(2020),
                    lastDate: MlTime.now().add(const Duration(days: 1)),
                  );
                  if (picked != null && mounted) setState(() => _date = picked);
                },
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
              : const Text('Save invoice'),
        ),
      ],
    );
  }
}
