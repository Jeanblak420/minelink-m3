import 'package:flutter_application_1/core/design/tokens/m3/ml_shape.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application_1/features/portal/models/tons_out_entry.dart';
import 'package:flutter_application_1/features/portal/portal_colors.dart';
import 'package:flutter_application_1/features/portal/widgets/premium_overview_widgets.dart';
import 'package:flutter_application_1/features/portal/utils/tons_out_filter.dart';
import 'package:intl/intl.dart';
import 'package:flutter_application_1/core/time/ml_time.dart';
import 'package:flutter_application_1/core/design/components/ml_components.dart';

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

  static final _dateFmt = DateFormat('dd/MM/yyyy');
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
            title: 'Tons out',
            meta: mlCount(widget.entries.length, 'load'),
            description: 'Every load dispatched, searchable by truck, '
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
                '${rows.length} of ${widget.entries.length} loads',
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
            dateFmt: _dateFmt,
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
    final items = <(String, String, double)>[
      ('D', 'Last 24h', summary.daily),
      ('W', 'Last 7 days', summary.weekly),
      ('M', 'Last 30 days', summary.monthly),
      ('Y', 'Last 365 days', summary.yearly),
      ('T', 'All time', summary.total),
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
                child: _SummaryBox(
                    code: it.$1, label: it.$2, value: formatTons(it.$3)),
              ),
          ],
        );
      },
    );
  }
}

class _SummaryBox extends StatelessWidget {
  final String code;
  final String label;
  final String value;
  const _SummaryBox({required this.code, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            MlSemantic.of(context).surfaceCard,
            Color.alphaBlend(
                PortalColors.accent.withValues(alpha: 0.16), scheme.surface),
          ],
        ),
        borderRadius: MlShape.radiusLarge,
        border: Border.all(color: MlSemantic.of(context).borderCard),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 24,
                height: 24,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: PortalColors.accent.withValues(alpha: 0.16),
                  borderRadius: MlShape.radiusSmall,
                ),
                child: Text(code,
                    style: textTheme.labelMedium?.copyWith(
                        color: PortalColors.accent, fontWeight: FontWeight.w800)),
              ),
              const SizedBox(width: 8),
              // Flexible so the caption can ellipsize. The code badge beside it
              // is a fixed 24px, so without this the Row had no give at all and
              // overflowed at text scale 1.3 on a 360px phone. The badge keeps
              // its size — it is the thing that identifies the tile.
              Flexible(
                child: Text(label,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: MlType.figure(
                  color: scheme.onSurface, size: MlTokens.fsH1),
            ),
          ),
        ],
      ),
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
          Row(
            children: [
              Icon(Icons.filter_alt_outlined,
                  size: 18, color: PortalColors.accent),
              const SizedBox(width: 8),
              Text('Filters',
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 240,
                child: TextField(
                  controller: searchController,
                  onChanged: (v) => onChanged(filter.copyWith(search: v)),
                  decoration: InputDecoration(
                    isDense: true,
                    prefixIcon: const Icon(Icons.search, size: 18),
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
                child: Text('Net mass',
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant)),
              ),
              const SizedBox(width: 8),
              Text(
                '${massRange.start.toStringAsFixed(0)}t – ${massRange.end.toStringAsFixed(0)}t',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(fontWeight: FontWeight.w700),
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
      width: 200,
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
                child: Text(o, overflow: TextOverflow.ellipsis)),
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
        final now = DateTime.now();
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
  final DateFormat dateFmt;
  final NumberFormat massFmt;

  const _ResultsTable({
    required this.rows,
    required this.filter,
    required this.onSort,
    required this.dateFmt,
    required this.massFmt,
  });

  int _sortIndex() => TonsOutSortField.values.indexOf(filter.sortField);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final massCellColor = MlTokens.waybillMassTint.withValues(alpha: 0.45);

    DataColumn col(String label, TonsOutSortField field, {bool numeric = false}) {
      return DataColumn(
        label: Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
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
            Icon(Icons.search_off_rounded,
                size: 36, color: scheme.onSurfaceVariant),
            const SizedBox(height: 8),
            Text('No loads match the current filters.',
                style: TextStyle(color: scheme.onSurfaceVariant)),
          ],
        ),
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
      child: MlWideTable(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minWidth: MediaQuery.of(context).size.width - 64,
          ),
          child: DataTable(
            sortColumnIndex: _sortIndex(),
            sortAscending: filter.ascending,
            headingRowColor: WidgetStatePropertyAll(
              PortalColors.accent.withValues(alpha: 0.12),
            ),
            headingTextStyle: TextStyle(
              fontWeight: FontWeight.w800,
              color: scheme.onSurface,
            ),
            columns: [
              col('Date', TonsOutSortField.date),
              col('Time', TonsOutSortField.time),
              col('Transporter', TonsOutSortField.transporter),
              col('Truck Reg No', TonsOutSortField.truckReg),
              col('Destination', TonsOutSortField.destination),
              col('Product', TonsOutSortField.product),
              col('Customer', TonsOutSortField.customer),
              col('Net Mass', TonsOutSortField.netMass, numeric: true),
            ],
            rows: [
              for (final e in rows)
                DataRow(cells: [
                  DataCell(Text(dateFmt.format(e.date))),
                  DataCell(Text(e.time)),
                  DataCell(Text(e.transporter)),
                  DataCell(Text(e.truckReg)),
                  DataCell(Text(e.destination)),
                  DataCell(Text(e.product)),
                  DataCell(Text(e.customer)),
                  DataCell(
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: massCellColor,
                        borderRadius: MlShape.radiusSmall,
                      ),
                      child: Text(massFmt.format(e.netMass),
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                ]),
            ],
          ),
        ),
      ),
    );
  }
}
