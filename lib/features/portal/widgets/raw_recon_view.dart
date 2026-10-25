import 'package:flutter_application_1/core/design/tokens/m3/ml_shape.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter_application_1/core/design/tokens/m3/ml_typography.dart';
import 'package:flutter_application_1/features/portal/models/raw_recon_row.dart';
import 'package:flutter_application_1/features/portal/services/recon_exporter.dart';
import 'package:flutter_application_1/features/portal/services/reconciliation_service.dart';
import 'package:flutter_application_1/core/design/components/ml_components.dart';
import 'package:flutter_application_1/core/design/shell/ml_window_class.dart';
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
    this.cardsOnPhone = false,
  });

  final String? companyId;

  /// On a phone, one card per load — every column as a label beside its
  /// value — instead of the 14-column grid behind a sideways scroll (admin
  /// phone audit, 2026-10-24). Opt-in: the super-admin recon tables use it.
  final bool cardsOnPhone;

  /// Optional deep-link transporter pre-filter (phase-2 nav merge T4, the
  /// `/portal/{org}/tons-out/:transporterId` glue): applied once when it
  /// matches a transporter name in the loaded rows (case-insensitive);
  /// otherwise ignored so the view falls back to "All".
  final String? initialTransporter;

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
        // `calendarDay` / `calendarClock`, NOT `MlTime.day` / `MlTime.clock`:
        // `RawReconRow` runs `MlTime.sast` at parse, so these fields are
        // already South African wall clocks and converting again would add the
        // reader's own offset back on. See `MlTime.sast`'s doc — it is the
        // identity in South Africa and two hours out everywhere else, which is
        // why the export looked right here for weeks.
        MlTime.calendarDay(r.tripDate),
        r.timeIn == null ? '' : MlTime.calendarClock(r.timeIn!),
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
        r.timeOut == null ? '' : MlTime.calendarClock(r.timeOut!),
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
  /// has for it, in plain English ("Net mass · last 7 days").
  ///
  /// S6-21. The windows are **rolling**, which is what §4 specifies — "a row
  /// of live summary cards showing **rolling** NET MASS totals". The labels
  /// did not say so, and on 2026-08-16 that was measurably misleading: Iron
  /// Hills' "Month" card read **664.02 t** while August's actual tonnage was
  /// **277.52 t**. A mine manager reading a card headed "Month" on the 16th
  /// takes it for the calendar month and is out by 2.4x. The figure was never
  /// wrong; the label was silent about which thirty days it meant.
  static const _statCaption = <String, String>{
    'Day': 'Net mass · last 24 hours',
    'Week': 'Net mass · last 7 days',
    'Month': 'Net mass · last 30 days',
    'Year': 'Net mass · last 365 days',
    'Total': 'Net mass · all time',
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
          // The action goes in the header's own slot rather than a Row wrapped
          // around it: a Row hands an unflexed button UNBOUNDED width
          // (CLAUDE.md 10.4) and squeezes the Expanded title to whatever is
          // left, which on a phone is less than the title needs. The slot
          // drops the action under the title instead.
          MlSectionTitle(
            'Recon table (raw records)',
            meta: async.valueOrNull == null
                ? null
                : mlCount(async.value!.length, 'row'),
            icon: Icons.table_rows_outlined,
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
                    // `MlTileGrid`, not a hand-rolled breakpoint.
                    //
                    // This was `cols = maxWidth > 700 ? visible.length :
                    // (visible.length / 2).ceil().clamp(1, 3)` — the seventeenth
                    // copy of the shape MlTileGrid was extracted to end, and the
                    // one that survived the sweep. On a 380px phone with all
                    // five periods showing it chose THREE columns of 120px, and
                    // an `MlStatCard` is 92px of tone bar, icon well and padding
                    // before a single character of text. Photographed 2026-08-20
                    // on `screen-recon-tables-phone-dark`: five cards showing an
                    // icon and the letters D, W, M, Y, T — the tonnage figure
                    // ellipsised away to nothing, on the screen whose entire
                    // purpose is that figure.
                    //
                    // `minTileWidth` rather than a ladder: it "cannot produce a
                    // tile narrower than its content", which is the property
                    // this needed and the reason MlTileGrid's own doc calls it
                    // the one to reach for. 220 is measured, not chosen — it
                    // leaves 128px for the text column, and `Total` is
                    // `103.22 t` in the display face. It reproduces the existing
                    // five-across desktop row exactly and gives one column on a
                    // phone, which is what every other stat grid in the portal
                    // already does.
                    MlTileGrid(
                      minTileWidth: 220,
                      gap: 10,
                      children: [
                        for (final s in _statOrder)
                          if (_visibleStats.contains(s))
                            MlStatCard(
                              label: s,
                              value: '${(stats[s] ?? 0).toStringAsFixed(2)} t',
                              caption: _statCaption[s],
                              icon: s == 'Total'
                                  ? Icons.functions_rounded
                                  : Icons.scale_outlined,
                              tone: s == 'Total' ? MlTone.accent : MlTone.done,
                            ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _filter(
                        'Transporter',
                        all: 'All transporters',
                        _transporter,
                        transporters,
                        (v) => setState(() => _transporter = v),
                      ),
                      _filter(
                        'Product',
                        all: 'All products',
                        _product,
                        products,
                        (v) => setState(() => _product = v),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _ExcelReconTable(
                    rows: filtered,
                    cards: widget.cardsOnPhone &&
                        MlWindowClass.of(context).usesBottomNav,
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
                      style: context.mlText.code(
                        color: semantic.textStrong,
                        size: 14,
                        weight: FontWeight.w700,
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

  /// [all] is the "no filter" item's own wording. It was `'All $label'`,
  /// which read "All Transporter" and "All Product" — the field's singular
  /// label pressed into a plural sentence. Same family as "Every load what
  /// was hauled". Phase 3 pass, 2026-08-23.
  Widget _filter(
    String label,
    String? value,
    List<String> options,
    ValueChanged<String?> onChanged, {
    required String all,
  }) {
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
          DropdownMenuItem<String?>(value: null, child: Text(all)),
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
  const _ExcelReconTable({
    required this.rows,
    this.onWaybillTap,
    this.onPodTap,
    this.cards = false,
  });

  final List<RawReconRow> rows;

  /// One card per load instead of the grid (see [RawReconView.cardsOnPhone]).
  final bool cards;

  /// Tapping a WAYBILL NUMBER opens the real linked waybill (§4). Null-safe:
  /// only rows that actually carry a waybill number render as a link.
  final void Function(RawReconRow row)? onWaybillTap;

  /// Tapping the POD cell opens the driver's proof-of-delivery photo. Only
  /// rows with an uploaded POD photo render as a link.
  final void Function(RawReconRow row)? onPodTap;

  static const _cols = <_ReconCol>[
    _ReconCol('Date', flex: 20),
    // 15, not 12: at the table's own minimum a flex-12 column is ~60px,
    // and "TIME-IN" broke at its hyphen into "TIME-" over "IN" — a legal
    // break the mid-word test allowed. Phase 3 pass, 2026-08-23.
    _ReconCol('Time-in', flex: 15, mono: true),
    _ReconCol('Waybill', flex: 24, mono: true, code: true),
    _ReconCol('Transporter', flex: 26),
    // 20, not 16: a code column injects zero-width breaks so a long value
    // wraps rather than overflows, and at flex 16 every SA registration
    // ("CK 84 RT GP") wrapped to "CK 84 RT" over "GP" at the table's own
    // minimum — a plate in two pieces, in the column that identifies the
    // truck. Wide enough now for the longest plate the fixture draws.
    _ReconCol('Truck', flex: 20, mono: true, code: true),
    _ReconCol('Destination', flex: 26),
    _ReconCol('Product', flex: 20),
    _ReconCol('Source', flex: 22),
    _ReconCol('Customer', flex: 24),
    _ReconCol('Net mass', flex: 16, mono: true, right: true),
    _ReconCol('Delivered', flex: 16, mono: true, right: true),
    _ReconCol('Variance', flex: 16, mono: true, right: true),
    _ReconCol('POD', flex: 10),
    _ReconCol('Time-out', flex: 15, mono: true),
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
    double? netMass, {
    Alignment align = Alignment.centerRight,
  }) {
    final severity = varianceSeverityOf(
      varianceTons: variance,
      netTons: netMass,
    );
    // Balanced and not-comparable both render as plain text: a tinted pill on
    // every row would make the tint meaningless, which is the fault this
    // shared classifier was extracted to fix.
    if (severity == VarianceSeverity.balanced ||
        severity == VarianceSeverity.notComparable) {
      return _valueText(semantic, col, value);
    }
    final colors = varianceTone(severity).colors(Theme.of(context).brightness);
    return Align(
      alignment: align,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: colors.bg,
          borderRadius: BorderRadius.circular(MlTokens.rSm),
        ),
        child: Text(
          value,
          textAlign: TextAlign.right,
          style: context.mlText.code(
            color: colors.fg,
            size: 12,
            weight: FontWeight.w700,
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
    if (cards) return _cards(context, semantic);
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
                  style: context.mlText.overline.copyWith(
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

    // `MlWideTable`, which was extracted FROM this widget's own scroll view and
    // then never came back to it. One implementation, so a fix to the thumb's
    // contrast or its bottom padding reaches this table too.
    //
    // 1320, not the 1120 this carried. At 1120 the fourteen columns are squeezed
    // to the point where Flutter breaks INSIDE words rather than between them:
    // photographed 2026-08-20 on a 1600px desktop, the header read
    // "DELIVER / ED", "VARIAN / CE" and "PO / D", and the Manganese row read
    // "Manganes / e". Nothing overflowed — a wrapped cell is a cell that fits —
    // so no sweep and no overflow capture ever saw it.
    //
    // 1480 is MEASURED, and the first two guesses were both wrong. "DELIVERED"
    // is the widest single word in the header and sits in a flex-16 column of a
    // 260-flex table; arithmetic said 1284, and at 1284 it still broke, because
    // the estimate ignored the overline's letter-spacing and the cell padding.
    // `recon_table_legibility_test.dart` renders the table AT its own minimum —
    // a narrow viewport, where the scroll view sizes it to exactly `minWidth` —
    // so the boundary itself is what gets checked rather than some width that
    // happens to be wider than it.
    //
    // The consequence is that this table now scrolls on a 1600px window as well
    // as on a phone, and that is the right trade: `MlWideTable`'s own doc says a
    // wide register "cannot be made to fit a laptop and should not be truncated
    // to try", and a scrollbar that says so beats a header nobody can read.
    // 🚨 AND IT SCALES WITH THE TEXT. 1480 is measured AT TEXT SCALE 1.0, and
    // a fixed pixel floor under a user-controlled type size is the same fault
    // `MlDataTable._effectiveMinWidth` documents in as many words — it took
    // `kPlateColumnMinWidth` literally once and overflowed six screens at 1.3.
    //
    // Measured 2026-08-23, this table at its own minimum: at scale 1.0 no time
    // cell wraps; at 1.3 and at 2.0, SIXTEEN of them do, and `12:35` renders as
    // `12:3` over `5`. Found on Jean's own handset, which runs a raised font
    // size — the header fix of 2026-08-20 solved the same class one size up and
    // left the figure fixed.
    //
    // Same conservative direction as the sibling: over-paying a little on width
    // costs a few pixels of horizontal scroll on a table that already scrolls.
    //
    // 1550 since 2026-08-23: the two time columns went from flex 12 to 15
    // so "TIME-IN" stops breaking at its hyphen, and Truck from 16 to 20 so
    // a registration stays whole, which took the table's flex from 260 to
    // 270 — and at 1480 that cost "DELIVERED" the few pixels it had. The
    // floor scales with the flex it was measured against;
    // recon_table_legibility_test.dart checks it at the boundary.
    final scale = MediaQuery.textScalerOf(context).scale(16) / 16;
    return MlWideTable(minWidth: 1550 * scale, child: table);
  }

  TableRow _row(
    BuildContext context,
    MlSemantic semantic,
    RawReconRow r,
    int index,
  ) {
    // §4: DATE displays only on the first row of each date group.
    // Already a South African wall clock — see the note on `csvRows`.
    final date = MlTime.calendarDay(r.tripDate);
    final prevDate =
        index == 0 ? null : MlTime.calendarDay(rows[index - 1].tripDate);
    final showDate = date != prevDate;

    String time(DateTime? t) => t == null ? '—' : MlTime.calendarClock(t);

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
                ? _podLink(context, values[col], r)
                : col == _colVariance
                ? _varianceText(
                    context,
                    semantic,
                    _cols[col],
                    values[col],
                    r.varianceTons,
                    r.netMass,
                  )
                : _valueText(semantic, _cols[col], values[col]),
          ),
      ],
    );
  }

  /// The phone layout: a card per load, a line per column, the same cells the
  /// grid draws (waybill and POD links, the tinted variance). Each card shows
  /// its own date — the grid's "date on the first row of the day" grouping
  /// does not survive being split into cards.
  Widget _cards(BuildContext context, MlSemantic semantic) {
    String time(DateTime? t) => t == null ? '—' : MlTime.calendarClock(t);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final r in rows)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(MlTokens.rLg),
              border: Border.all(color: semantic.borderCard),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 7,
              children: [
                for (var col = 0; col < _cols.length; col++)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 2,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 2, right: 10),
                          child: Text(
                            _cols[col].label.toUpperCase(),
                            style: context.mlText.overline.copyWith(
                              color: semantic.textFaint,
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: _cardValue(context, semantic, r, col, time),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _cardValue(BuildContext context, MlSemantic semantic, RawReconRow r,
      int col, String Function(DateTime?) time) {
    final c = _cols[col];
    // Left-aligned in a card: the grid right-aligns figures to line up a
    // column of them, and a card has no column.
    final left = _ReconCol(c.label, flex: c.flex, mono: c.mono, code: c.code);
    final value = switch (col) {
      0 => MlTime.calendarDay(r.tripDate),
      1 => time(r.timeIn),
      2 => r.waybillNumber ?? '—',
      3 => r.transporterName ?? '—',
      4 => r.truckReg ?? '—',
      5 => r.destination ?? '—',
      6 => r.product ?? '—',
      7 => r.sourceName ?? '—',
      8 => r.customerName ?? '—',
      9 => r.netMass == null ? '—' : '${r.netMass!.toStringAsFixed(2)} t',
      10 => r.deliveredTons == null
          ? '—'
          : '${r.deliveredTons!.toStringAsFixed(2)} t',
      11 => r.varianceTons == null
          ? '—'
          : '${r.varianceTons!.toStringAsFixed(2)} t',
      12 => r.podPhotoPath == null ? '—' : 'View',
      _ => time(r.timeOut),
    };
    if (col == _colWaybill && onWaybillTap != null && r.waybillNumber != null) {
      return _waybillLink(semantic, left, value, r);
    }
    if (col == _colPod && onPodTap != null && r.podPhotoPath != null) {
      return _podLink(context, value, r);
    }
    if (col == _colVariance) {
      return _varianceText(
          context, semantic, left, value, r.varianceTons, r.netMass,
          align: Alignment.centerLeft);
    }
    return _valueText(semantic, left, value);
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
      borderRadius: MlShape.radiusExtraSmall,
      child: Text(
        display,
        softWrap: true,
        style: TextStyle(
          fontFamily: MlTokens.fontMono,
          fontSize: 13,
          fontWeight: FontWeight.w700,
          height: 1.25,
          // `semantic.accentInk`, not `MlTokens.accent`. The accent is the
          // FILL — the value that goes behind `inkOnAccent` — and using it as
          // ink is `#22D3EE` on white, **1.81:1**. Every waybill number in
          // this table was a link nobody could read in light mode, measured
          // 2026-08-21 on `screen-recon-tables-desktop-light`.
          color: semantic.accentInk,
          decoration: TextDecoration.underline,
          decorationColor: semantic.accentInk,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }

  Widget _podLink(BuildContext context, String value, RawReconRow r) {
    // `accentInk`, for the reason written on `_waybillLink` above: the
    // accent is a FILL, and as ink on white it is 1.81:1. The waybill cell
    // was fixed on 2026-08-21; this link beside it was not (Phase 3 pass,
    // 2026-08-23).
    final semantic = MlSemantic.of(context);
    return InkWell(
      onTap: () => onPodTap!(r),
      borderRadius: MlShape.radiusExtraSmall,
      child: Text(
        value,
        softWrap: true,
        style: context.mlText.titleSmall.copyWith(
          color: semantic.accentInk,
          fontWeight: FontWeight.w700,
          height: 1.25,
          decoration: TextDecoration.underline,
          decorationColor: semantic.accentInk,
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
        fontSize: 13,
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
