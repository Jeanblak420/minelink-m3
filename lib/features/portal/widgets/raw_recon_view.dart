import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:flutter_application_1/features/portal/models/raw_recon_row.dart';
import 'package:flutter_application_1/features/portal/services/recon_exporter.dart';
import 'package:flutter_application_1/features/portal/services/reconciliation_service.dart';
import 'package:flutter_application_1/features/portal/widgets/ml/ml.dart';
import 'package:flutter_application_1/features/portal/widgets/pod_photo_link.dart';
import 'package:flutter_application_1/features/portal/widgets/waybill_modal.dart';
import 'package:flutter_application_1/features/portal/utils/variance_severity.dart';
import 'package:flutter_application_1/core/utils/friendly_error.dart';
import 'package:flutter_application_1/core/time/ml_time.dart';

/// The recon table (CLAUDE.md §4 "Recon tables" + Reconciliations Side A):
/// every truck's check-in → check-out as captured, in the canonical column
/// order, with
///  - live full-word period stat cards (Day · Week · Month · Year · Total of
///    NET MASS) each with an always-available Show/Hide toggle,
///  - a Filter control (transporter → the "transporter-based" view of the
///    same data; product),
///  - DATE shown only on the first row of each date group,
///  - an auto-summed `Total Tons =` footer,
///  - Excel/CSV/PDF export.
///
/// [companyId] null = every row the caller may see (the super-admin's
/// combined table); otherwise server-side scoping already limits rows to the
/// company's own loop, so the combined/transporter split is the transporter
/// filter here.
class RawReconView extends ConsumerStatefulWidget {
  const RawReconView({
    super.key,
    required this.companyId,
    this.initialTransporter,
  });

  final String? companyId;

  /// Optional deep-link transporter pre-filter (phase-2 nav merge T4, the
  /// `/portal/{org}/tons-out/:transporterId` glue): applied once when it
  /// matches a transporter name in the loaded rows (case-insensitive);
  /// otherwise ignored so the view falls back to "All".
  final String? initialTransporter;

  static final _dateFmt = DateFormat('dd MMM yyyy');
  static final _timeFmt = DateFormat('HH:mm');

  static const csvHeaders = [
    'DATE',
    'TIME-IN',
    'WAYBILL NUMBER',
    'TRANSPORTER NAME',
    'TRUCK REGISTRATION NO',
    'DESTINATION',
    'PRODUCT',
    'SOURCE',
    'CUSTOMER',
    'NET MASS',
    'DELIVERED',
    'VARIANCE',
    'POD',
    'TIME-OUT',
  ];

  static List<List<String>> csvRows(List<RawReconRow> rows) => [
    for (final r in rows)
      [
        _dateFmt.format(MlTime.sast(r.tripDate)),
        r.timeIn == null ? '' : _timeFmt.format(MlTime.sast(r.timeIn!)),
        r.waybillNumber ?? '',
        r.transporterName ?? '',
        r.truckReg ?? '',
        r.destination ?? '',
        r.product ?? '',
        r.sourceName ?? '',
        r.customerName ?? '',
        r.netMass?.toStringAsFixed(2) ?? '',
        r.deliveredTons?.toStringAsFixed(2) ?? '',
        // Blank, not 0.00, when the two weights are not comparable — an
        // exported spreadsheet is where a fabricated zero does the most damage,
        // because it is summed downstream without the reader ever seeing that
        // no delivery weight was captured.
        r.varianceTons?.toStringAsFixed(2) ?? '',
        r.podPhotoPath == null ? '' : 'Yes',
        r.timeOut == null ? '' : _timeFmt.format(MlTime.sast(r.timeOut!)),
      ],
  ];

  @override
  ConsumerState<RawReconView> createState() => _RawReconViewState();
}

class _RawReconViewState extends ConsumerState<RawReconView> {
  String? _transporter;
  String? _product;

  /// One-shot [RawReconView.initialTransporter], consumed on the first data
  /// build once row transporter names are known.
  String? _pendingInitialTransporter;

  @override
  void initState() {
    super.initState();
    _pendingInitialTransporter = widget.initialTransporter;
  }

  @override
  void didUpdateWidget(covariant RawReconView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialTransporter != oldWidget.initialTransporter) {
      _pendingInitialTransporter = widget.initialTransporter;
    }
  }

  /// Which period cards are displayed. Hiding never touches the data —
  /// display only (§4).
  final Set<String> _visibleStats = {'Day', 'Week', 'Month', 'Year', 'Total'};

  static const _statOrder = ['Day', 'Week', 'Month', 'Year', 'Total'];

  /// What each card actually measures, in the caption slot the card already
  /// has for it (`docs/design-reference.md` §4 — mono, lowercase, underscored;
  /// the widget's own doc gives `net_mass · all_time` as the example).
  ///
  /// S6-21. The windows are **rolling**, which is what §4 specifies — "a row
  /// of live summary cards showing **rolling** NET MASS totals". The labels
  /// did not say so, and on 2026-08-16 that was measurably misleading: Iron
  /// Hills' "Month" card read **664.02 t** while August's actual tonnage was
  /// **277.52 t**. A mine manager reading a card headed "Month" on the 16th
  /// takes it for the calendar month and is out by 2.4x. The figure was never
  /// wrong; the label was silent about which thirty days it meant.
  static const _statCaption = <String, String>{
    'Day': 'net_mass · last_24h',
    'Week': 'net_mass · last_7_days',
    'Month': 'net_mass · last_30_days',
    'Year': 'net_mass · last_365_days',
    'Total': 'net_mass · all_time',
  };

  DateTime _rowTime(RawReconRow r) => r.timeOut ?? r.tripDate;

  Map<String, double> _windows(List<RawReconRow> rows) {
    // Windows measured from the mine's clock, the same one the rows are
    // parsed onto and `ml_day()` buckets on server-side.
    final now = MlTime.now();
    double day = 0, week = 0, month = 0, year = 0, total = 0;
    for (final r in rows) {
      final q = r.netMass;
      if (q == null) continue;
      final at = _rowTime(r);
      total += q;
      if (at.isAfter(now.subtract(const Duration(days: 365)))) year += q;
      if (at.isAfter(now.subtract(const Duration(days: 30)))) month += q;
      if (at.isAfter(now.subtract(const Duration(days: 7)))) week += q;
      if (at.isAfter(now.subtract(const Duration(days: 1)))) day += q;
    }
    return {
      'Day': day,
      'Week': week,
      'Month': month,
      'Year': year,
      'Total': total,
    };
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(rawReconRowsProvider(widget.companyId));
    final semantic = MlSemantic.of(context);

    return MlCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: MlSectionTitle(
                  'Recon table (raw records)',
                  meta: async.valueOrNull == null
                      ? null
                      : mlCount(async.value!.length, 'row'),
                  icon: Icons.table_rows_outlined,
                  margin: EdgeInsets.zero,
                ),
              ),
              async.maybeWhen(
                data: (rows) => MlButton.outline(
                  label: 'Export',
                  icon: Icons.download_outlined,
                  compact: true,
                  onPressed: () {
                    // Period stat cards are all-time over ALL rows (§4); the
                    // table + its total are the filtered view.
                    final stats = _windows(rows);
                    ReconExporter.pickFormatAndExport(
                      context,
                      title: 'Recon table — raw records',
                      filenameBase: 'recon_table',
                      headers: RawReconView.csvHeaders,
                      rows: RawReconView.csvRows(_filtered(rows)),
                      filters: {
                        'Transporter': _transporter ?? 'All',
                        'Product': _product ?? 'All',
                      },
                      summary: {
                        for (final s in _statOrder)
                          s: '${(stats[s] ?? 0).toStringAsFixed(2)} t',
                      },
                    );
                  },
                ),
                orElse: () => const SizedBox.shrink(),
              ),
              IconButton(
                tooltip: 'Refresh',
                onPressed: () =>
                    ref.invalidate(rawReconRowsProvider(widget.companyId)),
                icon: const Icon(Icons.refresh_rounded, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Every check-in → check-out exactly as captured. Filter by '
            'transporter for the transporter-based view of the same data.',
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
              'Could not load raw records. ${friendlyError(e)}',
              style: TextStyle(color: semantic.textMuted),
            ),
            data: (rows) {
              if (rows.isEmpty) {
                return MlEmptyState(
                  icon: Icons.table_rows_outlined,
                  title: 'No raw records yet.',
                  message:
                      'Rows appear as soon as trips are created and captured.',
                );
              }
              // Consume the deep-link transporter pre-filter once real row
              // names are available (name match only — unknown values are
              // dropped so the dropdown never receives a foreign value).
              if (_pendingInitialTransporter != null) {
                final want = _pendingInitialTransporter!.trim().toLowerCase();
                _pendingInitialTransporter = null;
                for (final r in rows) {
                  final name = r.transporterName;
                  if (name != null && name.toLowerCase() == want) {
                    _transporter = name;
                    break;
                  }
                }
              }
              final filtered = _filtered(rows);
              // Period-total cards are all-time over ALL rows (§4: Total must
              // always show the real cumulative) — the transporter/product
              // filter scopes only the table + its footer below.
              final stats = _windows(rows);
              final transporters = {
                for (final r in rows)
                  if (r.transporterName != null) r.transporterName!,
              }.toList()..sort();
              final products = {
                for (final r in rows)
                  if (r.product != null) r.product!,
              }.toList()..sort();

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Show/Hide toggles — full-word labels per §4.
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final s in _statOrder)
                        FilterChip(
                          label: Text(s, style: const TextStyle(fontSize: 12)),
                          selected: _visibleStats.contains(s),
                          visualDensity: VisualDensity.compact,
                          onSelected: (on) => setState(() {
                            on ? _visibleStats.add(s) : _visibleStats.remove(s);
                          }),
                        ),
                    ],
                  ),
                  if (_visibleStats.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    LayoutBuilder(
                      builder: (context, c) {
                        final visible = [
                          for (final s in _statOrder)
                            if (_visibleStats.contains(s)) s,
                        ];
                        final cols = c.maxWidth > 700
                            ? visible.length
                            : (visible.length / 2).ceil().clamp(1, 3);
                        const gap = 10.0;
                        final w = (c.maxWidth - gap * (cols - 1)) / cols;
                        return Wrap(
                          spacing: gap,
                          runSpacing: gap,
                          children: [
                            for (final s in visible)
                              SizedBox(
                                width: w,
                                child: MlStatCard(
                                  label: s,
                                  value:
                                      '${(stats[s] ?? 0).toStringAsFixed(2)} t',
                                  caption: _statCaption[s],
                                  icon: s == 'Total'
                                      ? Icons.functions_rounded
                                      : Icons.scale_outlined,
                                  tone: s == 'Total'
                                      ? MlTone.accent
                                      : MlTone.done,
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ],
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _filter(
                        'Transporter',
                        _transporter,
                        transporters,
                        (v) => setState(() => _transporter = v),
                      ),
                      _filter(
                        'Product',
                        _product,
                        products,
                        (v) => setState(() => _product = v),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _ExcelReconTable(
                    rows: filtered,
                    onWaybillTap: (row) => showWaybillModal(
                      context,
                      ref,
                      tripId: row.tripId,
                      waybillNumber: row.waybillNumber,
                    ),
                    onPodTap: (row) =>
                        openPodPhoto(context, ref, row.podPhotoPath!),
                  ),
                  const SizedBox(height: 10),
                  // Auto-maintained footer (§4): recomputed on every rebuild.
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      'Total Tons = ${_totalTons(filtered).toStringAsFixed(2)}',
                      style: TextStyle(
                        fontFamily: MlTokens.fontMono,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: semantic.textStrong,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  List<RawReconRow> _filtered(List<RawReconRow> rows) => [
    for (final r in rows)
      if ((_transporter == null || r.transporterName == _transporter) &&
          (_product == null || r.product == _product))
        r,
  ];

  double _totalTons(List<RawReconRow> rows) =>
      rows.fold<double>(0, (s, r) => s + (r.netMass ?? 0));

  Widget _filter(
    String label,
    String? value,
    List<String> options,
    ValueChanged<String?> onChanged,
  ) {
    return SizedBox(
      width: 230,
      child: DropdownButtonFormField<String?>(
        initialValue: value,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
        items: [
          DropdownMenuItem<String?>(value: null, child: Text('All $label')),
          for (final o in options)
            DropdownMenuItem<String?>(value: o, child: Text(o)),
        ],
        onChanged: onChanged,
      ),
    );
  }

}

/// Column spec for the Excel-style recon grid.
class _ReconCol {
  const _ReconCol(
    this.label, {
    required this.flex,
    this.mono = false,
    this.code = false,
    this.right = false,
  });

  final String label;

  /// Proportional width — the grid fills the card and distributes width by
  /// these weights, so all 11 columns are always visible (no clipping).
  final double flex;

  /// Monospaced (codes, tonnages).
  final bool mono;

  /// A code/identifier (waybill, reg) with no natural break points — inject
  /// zero-width breaks so long values wrap inside the cell instead of
  /// overflowing.
  final bool code;

  /// Right-align (numeric NET MASS).
  final bool right;
}

/// The recon table rendered as a real spreadsheet-style grid: full gridlines
/// on every cell, a shaded header row, and cells that **wrap** their content
/// rather than truncating — nothing is ever cut off. Columns fill the card
/// width; on genuinely narrow viewports the whole grid scrolls horizontally
/// (with a visible scrollbar) at a sensible minimum width.
class _ExcelReconTable extends StatelessWidget {
  const _ExcelReconTable({required this.rows, this.onWaybillTap, this.onPodTap});

  final List<RawReconRow> rows;

  /// Tapping a WAYBILL NUMBER opens the real linked waybill (§4). Null-safe:
  /// only rows that actually carry a waybill number render as a link.
  final void Function(RawReconRow row)? onWaybillTap;

  /// Tapping the POD cell opens the driver's proof-of-delivery photo. Only
  /// rows with an uploaded POD photo render as a link.
  final void Function(RawReconRow row)? onPodTap;

  static const _cols = <_ReconCol>[
    _ReconCol('Date', flex: 20),
    _ReconCol('Time-in', flex: 12, mono: true),
    _ReconCol('Waybill', flex: 24, mono: true, code: true),
    _ReconCol('Transporter', flex: 26),
    _ReconCol('Truck', flex: 16, mono: true, code: true),
    _ReconCol('Destination', flex: 26),
    _ReconCol('Product', flex: 20),
    _ReconCol('Source', flex: 22),
    _ReconCol('Customer', flex: 24),
    _ReconCol('Net mass', flex: 16, mono: true, right: true),
    _ReconCol('Delivered', flex: 16, mono: true, right: true),
    _ReconCol('Variance', flex: 16, mono: true, right: true),
    _ReconCol('POD', flex: 10),
    _ReconCol('Time-out', flex: 12, mono: true),
  ];

  /// Column positions the row builder needs to treat specially. Named rather
  /// than written as literals: two columns were inserted before POD when
  /// variance landed, and a hardcoded `col == 10` would have silently started
  /// rendering the POD link on the Variance cell.
  static const _colWaybill = 2;
  static const _colVariance = 11;
  static const _colPod = 12;

  /// The variance cell, tinted by severity (P3-13).
  ///
  /// Positive variance is mass that left the mine and did not arrive. The
  /// thresholds live in `variance_severity.dart` and are shared with the Side B
  /// reconciliation view, so one load cannot be amber on one screen and red on
  /// the other.
  Widget _varianceText(
    BuildContext context,
    MlSemantic semantic,
    _ReconCol col,
    String value,
    double? variance,
    double? netMass,
  ) {
    final severity =
        varianceSeverityOf(varianceTons: variance, netTons: netMass);
    // Balanced and not-comparable both render as plain text: a tinted pill on
    // every row would make the tint meaningless, which is the fault this
    // shared classifier was extracted to fix.
    if (severity == VarianceSeverity.balanced ||
        severity == VarianceSeverity.notComparable) {
      return _valueText(semantic, col, value);
    }
    final colors = varianceTone(severity).colors(Theme.of(context).brightness);
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: colors.bg,
          borderRadius: BorderRadius.circular(MlTokens.rSm),
        ),
        child: Text(
          value,
          textAlign: TextAlign.right,
          style: TextStyle(
            fontFamily: MlTokens.fontMono,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: colors.fg,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ),
    );
  }

  /// Insert zero-width spaces so unbreakable codes wrap at any point rather
  /// than overflowing their column.
  static const _zwsp = '​';
  static String _breakable(String s) => s.split('').join(_zwsp);

  @override
  Widget build(BuildContext context) {
    final semantic = MlSemantic.of(context);
    final gridline = semantic.borderStrong;

    final table = Table(
      border: TableBorder.all(color: gridline, width: 1),
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      columnWidths: {
        for (var i = 0; i < _cols.length; i++)
          i: FlexColumnWidth(_cols[i].flex),
      },
      children: [
        // Header row — shaded, UPPERCASE, letter-spaced.
        TableRow(
          decoration: BoxDecoration(color: semantic.surfaceSunken),
          children: [
            for (final c in _cols)
              _cell(
                Text(
                  c.label.toUpperCase(),
                  textAlign: c.right ? TextAlign.right : TextAlign.left,
                  style: TextStyle(
                    fontFamily: MlTokens.fontSans,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: semantic.textFaint,
                  ),
                ),
              ),
          ],
        ),
        for (var i = 0; i < rows.length; i++)
          _row(context, semantic, rows[i], i),
      ],
    );

    return LayoutBuilder(
      builder: (context, c) {
        const minTableWidth = 1120.0;
        if (c.maxWidth >= minTableWidth) return table;
        return Scrollbar(
          thumbVisibility: true,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(bottom: 8),
            child: SizedBox(width: minTableWidth, child: table),
          ),
        );
      },
    );
  }

  TableRow _row(
    BuildContext context,
    MlSemantic semantic,
    RawReconRow r,
    int index,
  ) {
    // §4: DATE displays only on the first row of each date group.
    final date = RawReconView._dateFmt.format(MlTime.sast(r.tripDate));
    final prevDate = index == 0
        ? null
        : RawReconView._dateFmt.format(MlTime.sast(rows[index - 1].tripDate));
    final showDate = date != prevDate;

    String time(DateTime? t) =>
        t == null ? '—' : RawReconView._timeFmt.format(MlTime.sast(t));

    final values = <String>[
      showDate ? date : '',
      time(r.timeIn),
      r.waybillNumber ?? '—',
      r.transporterName ?? '—',
      r.truckReg ?? '—',
      r.destination ?? '—',
      r.product ?? '—',
      r.sourceName ?? '—',
      r.customerName ?? '—',
      r.netMass == null ? '—' : '${r.netMass!.toStringAsFixed(2)} t',
      r.deliveredTons == null
          ? '—'
          : '${r.deliveredTons!.toStringAsFixed(2)} t',
      // A dash, never 0.00: null variance means one of the two weights is
      // missing, so the load has not been reconciled — which is a different
      // statement from "it reconciled exactly".
      r.varianceTons == null ? '—' : '${r.varianceTons!.toStringAsFixed(2)} t',
      r.podPhotoPath == null ? '—' : 'View',
      time(r.timeOut),
    ];

    // Subtle zebra striping for spreadsheet legibility.
    final striped = index.isOdd;
    return TableRow(
      decoration: BoxDecoration(
        color: striped ? semantic.surfaceSunken.withValues(alpha: 0.35) : null,
      ),
      children: [
        for (var col = 0; col < _cols.length; col++)
          _cell(
            // WAYBILL NUMBER → the real waybill when this row has one.
            // POD → the driver's proof-of-delivery photo when one was
            // uploaded. VARIANCE → tinted by how much mass went missing.
            col == _colWaybill &&
                    onWaybillTap != null &&
                    r.waybillNumber != null
                ? _waybillLink(semantic, _cols[col], values[col], r)
                : col == _colPod && onPodTap != null && r.podPhotoPath != null
                    ? _podLink(values[col], r)
                    : col == _colVariance
                        ? _varianceText(context, semantic, _cols[col],
                            values[col], r.varianceTons, r.netMass)
                        : _valueText(semantic, _cols[col], values[col]),
          ),
      ],
    );
  }

  Widget _waybillLink(
    MlSemantic semantic,
    _ReconCol c,
    String value,
    RawReconRow r,
  ) {
    final display = c.code && value != '—' ? _breakable(value) : value;
    return InkWell(
      onTap: () => onWaybillTap!(r),
      borderRadius: BorderRadius.circular(4),
      child: Text(
        display,
        softWrap: true,
        style: TextStyle(
          fontFamily: MlTokens.fontMono,
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
          height: 1.25,
          color: MlTokens.accent,
          decoration: TextDecoration.underline,
          decorationColor: MlTokens.accent,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }

  Widget _podLink(String value, RawReconRow r) {
    return InkWell(
      onTap: () => onPodTap!(r),
      borderRadius: BorderRadius.circular(4),
      child: Text(
        value,
        softWrap: true,
        style: TextStyle(
          fontFamily: MlTokens.fontSans,
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
          height: 1.25,
          color: MlTokens.accent,
          decoration: TextDecoration.underline,
          decorationColor: MlTokens.accent,
        ),
      ),
    );
  }

  Widget _valueText(MlSemantic semantic, _ReconCol c, String value) {
    final display = c.code && value != '—' ? _breakable(value) : value;
    return Text(
      display,
      textAlign: c.right ? TextAlign.right : TextAlign.left,
      // No maxLines / no ellipsis → content wraps and is always fully shown.
      softWrap: true,
      style: TextStyle(
        fontFamily: c.mono ? MlTokens.fontMono : MlTokens.fontSans,
        fontSize: 12.5,
        fontWeight: c.mono ? FontWeight.w600 : FontWeight.w500,
        height: 1.25,
        color: c.right || c.mono ? semantic.textStrong : semantic.textBody,
      ),
    );
  }

  Widget _cell(Widget child) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
        child: child,
      );
}
