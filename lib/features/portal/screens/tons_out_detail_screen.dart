import 'package:flutter_application_1/core/design/tokens/m3/ml_shape.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application_1/features/portal/models/tons_out_entry.dart';
import 'package:flutter_application_1/features/portal/portal_colors.dart';
import 'package:flutter_application_1/features/portal/widgets/premium_overview_widgets.dart';
import 'package:flutter_application_1/features/portal/utils/tons_out_filter.dart';
import 'package:intl/intl.dart';
import 'package:flutter_application_1/core/time/ml_time.dart';
import 'package:flutter_application_1/core/design/components/ml_components.dart';
import 'package:flutter_application_1/core/design/tokens/m3/ml_typography.dart';
import 'package:flutter_application_1/core/design/shell/ml_window_class.dart';

/// Premium drill-down for the overview "Tons out" tile: rolling-window summary
/// boxes plus a fully filterable / sortable dispatch table.
class TonsOutDetailScreen extends StatefulWidget {
  final List<TonsOutEntry> entries;

  const TonsOutDetailScreen({super.key, required this.entries});

  @override
  State<TonsOutDetailScreen> createState() => _TonsOutDetailScreenState();
}

class _TonsOutDetailScreenState extends State<TonsOutDetailScreen> {
  TonsOutFilter _filter = const TonsOutFilter();
  final _searchController = TextEditingController();

  late final double _massFloor;
  late final double _massCeil;
  late RangeValues _massRange;

  static final _massFmt = NumberFormat('#,##0.00');

  @override
  void initState() {
    super.initState();
    final masses = widget.entries.map((e) => e.netMass);
    _massFloor = (masses.isEmpty ? 0 : masses.reduce((a, b) => a < b ? a : b))
        .floorToDouble();
    _massCeil = (masses.isEmpty ? 100 : masses.reduce((a, b) => a > b ? a : b))
        .ceilToDouble();
    _massRange = RangeValues(_massFloor, _massCeil);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _update(TonsOutFilter next) => setState(() => _filter = next);

  void _clear() {
    _searchController.clear();
    setState(() {
      _filter = const TonsOutFilter();
      _massRange = RangeValues(_massFloor, _massCeil);
    });
  }

  void _onSort(TonsOutSortField field) {
    final asc = _filter.sortField == field ? !_filter.ascending : true;
    _update(_filter.copyWith(sortField: field, ascending: asc));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final rows = TonsOutQuery.apply(widget.entries, _filter);
    final summary = TonsOutQuery.summarise(rows, now: MlTime.now());

    // NO SCAFFOLD, AND NO APP BAR.
    //
    // This screen is reached through `PortalTonsOutSearchScreen`, which sits
    // on a portal `ShellRoute` — so the shell has already drawn a top bar
    // carrying the company's name, and a second `AppBar` reading "Tons out"
    // landed directly underneath it. Two bars and two titles, in the first
    // 150px of a phone, which is the scarcest space in the product.
    // Photographed 2026-08-21, the first render of this screen.
    //
    // `MlPageBody` + `MlPageHeader` is what every other portal screen uses,
    // and it also gives the page the meta line and the sentence of
    // description a bare `AppBar` had nowhere to put.
    return MlPageBody(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MlPageHeader(
            // The rail entry and the app bar both say "Search loads"; this
            // header said "Tons out", the name of the screen next door.
            title: 'Search loads',
            meta: mlCount(widget.entries.length, 'load'),
            description:
                'Every load dispatched, searchable by truck, '
                'transporter, product, customer, date and net mass.',
          ),
          const SizedBox(height: 4),
          _SummaryStrip(summary: summary),
          const SizedBox(height: 20),
          _FilterBar(
            entries: widget.entries,
            filter: _filter,
            searchController: _searchController,
            massFloor: _massFloor,
            massCeil: _massCeil,
            massRange: _massRange,
            onChanged: _update,
            onMassRangeChanged: (r) => setState(() {
              _massRange = r;
              _filter = _filter.copyWith(
                minMass: r.start <= _massFloor ? null : r.start,
                maxMass: r.end >= _massCeil ? null : r.end,
              );
            }),
            onClear: _clear,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Text(
                '${rows.length} of ${mlCount(widget.entries.length, 'load')}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              if (_filter.hasActiveFilters)
                TextButton.icon(
                  onPressed: _clear,
                  icon: const Icon(Icons.filter_alt_off_outlined, size: 18),
                  label: const Text('Clear filters'),
                ),
            ],
          ),
          const SizedBox(height: 8),
          _ResultsTable(
            rows: rows,
            filter: _filter,
            onSort: _onSort,
            massFmt: _massFmt,
          ),
          const SizedBox(height: 60),
        ],
      ),
    );
  }
}

class _SummaryStrip extends StatelessWidget {
  final TonsOutSummary summary;
  const _SummaryStrip({required this.summary});

  @override
  Widget build(BuildContext context) {
    // ROLLING windows, and the label has to say so.
    //
    // These are the same five windows `RawReconView` shows, and the same trap:
    // a card headed "Monthly" reads as the calendar month. On 2026-08-16 Iron
    // Hills' 30-day figure was 664.02 t while August's actual tonnage was
    // 277.52 t — a manager reading "Monthly" on the 16th is out by 2.4x. The
    // recon view was fixed (S6-21); this screen still carried the old labels
    // because nothing could reach it to notice.
    //
    // THE REFERENCE STAT CARD, as `RawReconView` draws these same five
    // windows one rail entry up — full-word label, mono caption, left tone
    // bar, icon well. Until 2026-08-23 this screen drew its own
    // `_SummaryBox`: a cyan gradient on all five tiles, a 24px letter badge
    // and no tone bar — a second stat-card vocabulary, and the accent spent
    // five times on a screen where the reference spends it once
    // (design-reference §4, §5.5). Found by two reviewers.
    final items = <(String, String, double)>[
      ('Day', 'Net mass · last 24 hours', summary.daily),
      ('Week', 'Net mass · last 7 days', summary.weekly),
      ('Month', 'Net mass · last 30 days', summary.monthly),
      ('Year', 'Net mass · last 365 days', summary.yearly),
      ('Total', 'Net mass · all time', summary.total),
    ];
    return LayoutBuilder(
      builder: (context, c) {
        const gap = 12.0;
        final cols = c.maxWidth > 760 ? 5 : (c.maxWidth > 420 ? 3 : 2);
        final w = (c.maxWidth - gap * (cols - 1)) / cols;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final it in items)
              SizedBox(
                width: w,
                // `formatTons`, the product's one tonnage formatter.
                //
                // These cards printed a bare `198` on a screen titled
                // Tons out, beside a table whose every mass carries two
                // decimals and a stockpile screen three taps away that
                // writes `128.4 / 200 t`. And `.round()` threw the
                // decimals away, so the All-time card read 198 for a
                // register summing to 197.70 — the same figure, said two
                // ways, on one screen (photographed 2026-08-21).
                child: MlStatCard(
                  label: it.$1,
                  caption: it.$2,
                  value: formatTons(it.$3),
                  icon: it.$1 == 'Total'
                      ? Icons.functions_rounded
                      : Icons.scale_outlined,
                  tone: it.$1 == 'Total' ? MlTone.accent : MlTone.done,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _FilterBar extends StatelessWidget {
  final List<TonsOutEntry> entries;
  final TonsOutFilter filter;
  final TextEditingController searchController;
  final double massFloor;
  final double massCeil;
  final RangeValues massRange;
  final ValueChanged<TonsOutFilter> onChanged;
  final ValueChanged<RangeValues> onMassRangeChanged;
  final VoidCallback onClear;

  const _FilterBar({
    required this.entries,
    required this.filter,
    required this.searchController,
    required this.massFloor,
    required this.massCeil,
    required this.massRange,
    required this.onChanged,
    required this.onMassRangeChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MlSemantic.of(context).surfaceCard,
        borderRadius: MlShape.radiusLarge,
        border: Border.all(color: MlSemantic.of(context).borderCard),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // A section heading, not a 14px sans ExtraBold row.
          const MlSectionTitle(
            'Filters',
            icon: Icons.filter_alt_outlined,
            margin: EdgeInsets.only(bottom: 12),
          ),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                // 340, and the icon's box shrunk to fit it.
                //
                // This was 240, then 300, and the hint was still cut at BOTH
                // 1600 and 412 — a fixed width around text does not care how
                // wide the window is, and neither did my two guesses at it.
                // The part that kept being missed: `prefixIcon` is given a
                // 48x48 minimum whatever size the icon inside it is, so an
                // 18px magnifier was eating 48px and the 34-character hint
                // was left ~230px of a 300px box. Constraining the icon to
                // 34px returns 14px, and 340 gives the text ~282px.
                width: 340,
                child: TextField(
                  controller: searchController,
                  onChanged: (v) => onChanged(filter.copyWith(search: v)),
                  decoration: InputDecoration(
                    isDense: true,
                    prefixIcon: const Icon(Icons.search, size: 18),
                    prefixIconConstraints: const BoxConstraints(
                      minWidth: 34,
                      minHeight: 34,
                    ),
                    hintText: 'Search reg, transporter, customer…',
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
              _DropdownFilter(
                label: 'Transporter',
                value: filter.transporter,
                options: TonsOutQuery.distinct(entries, (e) => e.transporter),
                onChanged: (v) => onChanged(filter.copyWith(transporter: v)),
              ),
              _DropdownFilter(
                label: 'Destination',
                value: filter.destination,
                options: TonsOutQuery.distinct(entries, (e) => e.destination),
                onChanged: (v) => onChanged(filter.copyWith(destination: v)),
              ),
              _DropdownFilter(
                label: 'Product',
                value: filter.product,
                options: TonsOutQuery.distinct(entries, (e) => e.product),
                onChanged: (v) => onChanged(filter.copyWith(product: v)),
              ),
              _DropdownFilter(
                label: 'Customer',
                value: filter.customer,
                options: TonsOutQuery.distinct(entries, (e) => e.customer),
                onChanged: (v) => onChanged(filter.copyWith(customer: v)),
              ),
              _DateRangeField(
                range: filter.dateRange,
                onChanged: (r) => onChanged(filter.copyWith(dateRange: r)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Icon + "Net mass" + the range read-out. The label flexes and the
          // range does not: the numbers are what the slider below is being set
          // to, so truncating them would leave the control unreadable. Without
          // this the row overflowed by 10px at 360px / text scale 1.3.
          Row(
            children: [
              Icon(Icons.scale_outlined, size: 16, color: PortalColors.accent),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  'Net mass',
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${massRange.start.toStringAsFixed(0)}t – ${massRange.end.toStringAsFixed(0)}t',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          RangeSlider(
            values: massRange,
            min: massFloor,
            max: massCeil,
            divisions: (massCeil - massFloor).clamp(1, 100).toInt(),
            activeColor: PortalColors.accent,
            labels: RangeLabels(
              massRange.start.toStringAsFixed(1),
              massRange.end.toStringAsFixed(1),
            ),
            onChanged: onMassRangeChanged,
          ),
        ],
      ),
    );
  }
}

class _DropdownFilter extends StatelessWidget {
  final String label;
  final String? value;
  final List<String> options;
  final ValueChanged<String?> onChanged;

  const _DropdownFilter({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      // 240. A dropdown lays its ITEMS out to size itself, so the options are
      // real laid-out text even while the menu is shut — which is how
      // "Roadhaul Logistics" (143px at the dropdown's 16px style) was caught
      // being cut in a 140px box on all four tons-out renders, desktop
      // included. Nobody would have seen it until they opened the menu to
      // choose that transporter.
      width: 240,
      child: DropdownButtonFormField<String?>(
        initialValue: value,
        isExpanded: true,
        decoration: InputDecoration(
          isDense: true,
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        items: [
          const DropdownMenuItem<String?>(value: null, child: Text('All')),
          for (final o in options)
            DropdownMenuItem<String?>(
              value: o,
              child: Text(o, overflow: TextOverflow.ellipsis),
            ),
        ],
        onChanged: onChanged,
      ),
    );
  }
}

class _DateRangeField extends StatelessWidget {
  final DateTimeRange? range;
  final ValueChanged<DateTimeRange?> onChanged;
  const _DateRangeField({required this.range, required this.onChanged});

  static final _fmt = DateFormat('dd MMM');

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final label = range == null
        ? 'Date range'
        : '${_fmt.format(range!.start)} – ${_fmt.format(range!.end)}';
    return OutlinedButton.icon(
      onPressed: () async {
        // A picker's bounds are days a person reads and submits, so they
        // come off the pit clock like every other date in this product. Only
        // the year is used here, so it is the first two hours of 1 January
        // that this would get wrong — but the rule does not have exceptions
        // for how rarely it bites.
        final now = MlTime.now();
        final picked = await showDateRangePicker(
          context: context,
          firstDate: DateTime(now.year - 3),
          lastDate: DateTime(now.year + 1),
          initialDateRange: range,
        );
        if (picked != null) onChanged(picked);
      },
      onLongPress: () => onChanged(null),
      icon: const Icon(Icons.date_range_outlined, size: 18),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: scheme.onSurface,
        side: BorderSide(color: MlSemantic.of(context).borderCard),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }
}

class _ResultsTable extends StatelessWidget {
  final List<TonsOutEntry> rows;
  final TonsOutFilter filter;
  final ValueChanged<TonsOutSortField> onSort;
  final NumberFormat massFmt;

  const _ResultsTable({
    required this.rows,
    required this.filter,
    required this.onSort,
    required this.massFmt,
  });

  /// A figure or a clock in a column: JetBrainsMono (design-reference §3).
  Widget _mono(BuildContext context, String text) => Text(
        text,
        style: context.mlText.code(
          color: MlSemantic.of(context).textStrong,
          size: MlTokens.fsBody - 1,
        ),
      );

  int _sortIndex() => TonsOutSortField.values.indexOf(filter.sortField);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final semantic = MlSemantic.of(context);

    // Column heads in the reference's vocabulary — uppercase, letterspaced,
    // muted (the same `overline` `MlDataTable` uses) — on a plain surface,
    // not a sans-ExtraBold title-case head on an accent-tinted band. The
    // sort affordance is what keeps this a `DataTable`.
    DataColumn col(
      String label,
      TonsOutSortField field, {
      bool numeric = false,
    }) {
      return DataColumn(
        label: Text(
          label.toUpperCase(),
          style: context.mlText.overline.copyWith(color: semantic.textMuted),
        ),
        numeric: numeric,
        onSort: (_, __) => onSort(field),
      );
    }

    if (rows.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 48),
        decoration: BoxDecoration(
          color: MlSemantic.of(context).surfaceCard,
          borderRadius: MlShape.radiusLarge,
          border: Border.all(color: MlSemantic.of(context).borderCard),
        ),
        child: Column(
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 36,
              color: scheme.onSurfaceVariant,
            ),
            const SizedBox(height: 8),
            Text(
              'No loads match the current filters.',
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      );
    }

    // On a phone, one card per load (Jean's go-ahead, 2026-10-24). The cards
    // have no column heads to tap, so the sort the heads carry moves to a
    // "Sort by" field and a direction button, through the same [onSort].
    if (MlWindowClass.of(context).usesBottomNav) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _PhoneSort(filter: filter, onSort: onSort),
          const SizedBox(height: 8),
          MlCard(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: MlDataTable(
              cardsOnPhone: true,
              columns: [
                for (final (label, _) in _phoneFields) MlColumn(label),
              ],
              rows: [
                for (final e in rows)
                  [
                    Text(MlTime.calendarDay(e.date)),
                    _mono(context, e.time),
                    Text(e.transporter),
                    MlPlatePill(e.truckReg, fontSize: 12),
                    Text(e.destination),
                    Text(e.product),
                    Text(e.customer),
                    _mono(context, '${massFmt.format(e.netMass)} t'),
                  ],
              ],
            ),
          ),
        ],
      );
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: MlShape.radiusLarge,
        border: Border.all(color: MlSemantic.of(context).borderCard),
      ),
      clipBehavior: Clip.antiAlias,
      // The table fills ITS CARD, measured by a LayoutBuilder — not
      // `MediaQuery.size.width - 64`, which is the WINDOW, sidebar included:
      // that forced the table ~276px wider than its card on a 1600px desktop
      // and scrolled the Net mass column — the figure the screen exists for
      // — out of the golden. `MlWideTable` still scrolls it on a phone.
      child: LayoutBuilder(
        builder: (context, c) => MlWideTable(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: c.maxWidth.isFinite ? c.maxWidth : 0,
            ),
            child: _table(context, scheme, col),
          ),
        ),
      ),
    );
  }

  Widget _table(
    BuildContext context,
    ColorScheme scheme,
    DataColumn Function(String, TonsOutSortField, {bool numeric}) col,
  ) {
    return DataTable(
          sortColumnIndex: _sortIndex(),
          sortAscending: filter.ascending,
          headingRowColor: WidgetStatePropertyAll(scheme.surface),
          dividerThickness: 1,
          columns: [
            col('Date', TonsOutSortField.date),
            // It is the check-OUT clock (`timeOut ?? timeIn`), and the recon
            // table beside this screen heads its columns TIME-IN / TIME-OUT;
            // a bare "Time" here read 34–57 minutes later than the recon
            // table's TIME-IN for the same waybill, with nothing to say why.
            col('Time out', TonsOutSortField.time),
            col('Transporter', TonsOutSortField.transporter),
            col('Truck reg', TonsOutSortField.truckReg),
            col('Destination', TonsOutSortField.destination),
            col('Product', TonsOutSortField.product),
            col('Customer', TonsOutSortField.customer),
            col('Net mass', TonsOutSortField.netMass, numeric: true),
          ],
          rows: [
            for (final e in rows)
              DataRow(
                cells: [
                  // `15 Aug 2026`, as the Tons out table beside it — not
                  // `15/08/2026` on one screen and `15 Aug 2026` on the next.
                  // `calendarDay`: `e.date` is already a South African
                  // calendar day (CLAUDE.md §7.1), FORMATTED, never converted.
                  DataCell(Text(MlTime.calendarDay(e.date))),
                  DataCell(_mono(context, e.time)),
                  DataCell(Text(e.transporter)),
                  // The plate as the product prints every plate.
                  DataCell(MlPlatePill(e.truckReg, fontSize: 12)),
                  DataCell(Text(e.destination)),
                  DataCell(Text(e.product)),
                  DataCell(Text(e.customer)),
                  // Mono, untinted: the peach `waybillMassTint` was a second
                  // accent on the one figure column (design-reference §5.2).
                  DataCell(_mono(context, '${massFmt.format(e.netMass)} t')),
                ],
              ),
          ],
        );
  }
}

/// The results' fields, in column order, with the sort each one carries.
const _phoneFields = <(String, TonsOutSortField)>[
  ('Date', TonsOutSortField.date),
  ('Time out', TonsOutSortField.time),
  ('Transporter', TonsOutSortField.transporter),
  ('Truck reg', TonsOutSortField.truckReg),
  ('Destination', TonsOutSortField.destination),
  ('Product', TonsOutSortField.product),
  ('Customer', TonsOutSortField.customer),
  ('Net mass', TonsOutSortField.netMass),
];

/// "Sort by" for the phone's cards. Picking a field, or the direction
/// button, goes through the same toggle a column head does: the same field
/// again flips the direction, a new field starts ascending.
class _PhoneSort extends StatelessWidget {
  const _PhoneSort({required this.filter, required this.onSort});

  final TonsOutFilter filter;
  final ValueChanged<TonsOutSortField> onSort;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          // Re-keyed on the field: `initialValue` is read once, and Reset
          // changes the sort from outside.
          child: KeyedSubtree(
            key: ValueKey(filter.sortField),
            child: DropdownButtonFormField<TonsOutSortField>(
              key: const ValueKey('tons-out-sort-field'),
              isExpanded: true,
              initialValue: filter.sortField,
              decoration: const InputDecoration(
                labelText: 'Sort by',
                isDense: true,
              ),
              items: [
                for (final (label, field) in _phoneFields)
                  DropdownMenuItem(value: field, child: Text(label)),
              ],
              onChanged: (f) {
                if (f != null && f != filter.sortField) onSort(f);
              },
            ),
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          key: const ValueKey('tons-out-sort-direction'),
          tooltip: filter.ascending ? 'Ascending' : 'Descending',
          onPressed: () => onSort(filter.sortField),
          icon: Icon(filter.ascending
              ? Icons.arrow_upward_rounded
              : Icons.arrow_downward_rounded),
        ),
      ],
    );
  }
}
