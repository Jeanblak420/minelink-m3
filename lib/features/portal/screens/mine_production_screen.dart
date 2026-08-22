import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:flutter_application_1/core/design/tokens/m3/ml_typography.dart';
import 'package:flutter_application_1/core/utils/safe_ref.dart';
import 'package:flutter_application_1/features/portal/models/production_entry.dart';
import 'package:flutter_application_1/features/portal/models/stockpile_entry.dart';
import 'package:flutter_application_1/features/portal/utils/production_metrics.dart';
import 'package:flutter_application_1/features/portal/providers/lifecycle_provider.dart';
import 'package:flutter_application_1/features/portal/services/production_service.dart';
import 'package:flutter_application_1/features/portal/services/recon_exporter.dart';
import 'package:flutter_application_1/features/portal/utils/portal_company_resolution.dart';
import 'package:flutter_application_1/core/design/components/ml_components.dart';
import 'package:flutter_application_1/features/portal/widgets/stockpile_widgets.dart';
import 'package:flutter_application_1/features/portal/widgets/portal_company_required.dart';
import 'package:flutter_application_1/core/utils/friendly_error.dart';
import 'package:flutter_application_1/core/time/ml_time.dart';

/// Mine "Production" screen (CLAUDE.md §4 production vs dispatch):
///  - record tons MINED per day (pit/section, commodity), optionally landing
///    the tonnage on one of the mine's own ROM/production piles;
///  - production vs dispatch report — mined vs weighbridge net out, yield %
///    and pit-to-port loss over a selectable window;
///  - create + manage the mine's own production piles (order stockpiles stay
///    system-created and capped).
class MineProductionScreen extends ConsumerStatefulWidget {
  const MineProductionScreen({super.key});

  @override
  ConsumerState<MineProductionScreen> createState() =>
      _MineProductionScreenState();
}

class _MineProductionScreenState extends ConsumerState<MineProductionScreen> {
  int _days = 30;

  static final _dateFmt = DateFormat('dd MMM yyyy');

  static String _t(double v) => '${v.toStringAsFixed(2)} t';

  void _snack(String message) {
    // Every caller reaches here after an await, so the screen may already be
    // gone; `ScaffoldMessenger.of` would then throw on a deactivated ancestor.
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final companyId = resolvePortalCompanyId(ref);
    if (companyId == null) {
      return const PortalCompanyRequired();
    }
    final semantic = MlSemantic.of(context);
    final reportAsync = ref.watch(
      productionReportProvider((companyId: companyId, days: _days)),
    );
    final entriesAsync = ref.watch(productionEntriesProvider(companyId));
    final stockpiles =
        ref.watch(stockpilesProvider(companyId)).valueOrNull ?? const [];
    final productionPiles = stockpiles.where((s) => s.isProduction).toList();

    return MlPageBody(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // The action goes in MlPageHeader's own `actions` slot rather than a
          // Row wrapped around it. That slot lays the title and the actions
          // out as siblings in one Wrap, so the button drops under the title
          // when the row runs out of width — which on a 360px phone at text
          // scale 2.0 it does, by 15px. A Row gives an unflexed button
          // unbounded width instead (CLAUDE.md §10.4), and a button cannot
          // ellipsize its way out: clamping it truncates the hit target, not
          // just the label.
          MlPageHeader(
            title: 'Production',
            meta: mlCount(productionPiles.length, 'ROM pile'),
            description:
                'Record what the pit produces, keep your own ROM piles, '
                'and see mined vs dispatched — yield and pit-to-port '
                'loss at a glance.',
            padding: EdgeInsets.zero,
            actions: [
              MlButton.primary(
                label: 'Record production',
                icon: Icons.add_chart_outlined,
                onPressed: () => _recordProduction(companyId, productionPiles),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Window selector + yield stat cards.
          Wrap(
            spacing: 6,
            children: [
              for (final (label, days) in const [
                ('7 days', 7),
                ('30 days', 30),
                ('90 days', 90),
                ('Year', 365),
              ])
                ChoiceChip(
                  label: Text(label, style: const TextStyle(fontSize: 12)),
                  selected: _days == days,
                  visualDensity: VisualDensity.compact,
                  onSelected: (_) => setState(() => _days = days),
                ),
            ],
          ),
          const SizedBox(height: 12),
          reportAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 28),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => MlLoadFailure(
              subject: 'the production report',
              error: e,
              onRetry: () => ref.invalidate(
                productionReportProvider((companyId: companyId, days: _days)),
              ),
            ),
            data: (days) => _ReportSection(
              days: days,
              windowDays: _days,
              onExport: () => ReconExporter.pickFormatAndExport(
                context,
                title: 'Production vs dispatch — last ${mlCount(_days, 'day')}',
                filenameBase: 'production_vs_dispatch',
                headers: const [
                  'DATE',
                  'MINED (t)',
                  'DISPATCHED (t)',
                  'DAY LOSS (t)',
                ],
                rows: [
                  for (final d in days)
                    [
                      _dateFmt.format(d.day),
                      d.minedTons.toStringAsFixed(2),
                      d.dispatchedTons.toStringAsFixed(2),
                      (d.minedTons - d.dispatchedTons).toStringAsFixed(2),
                    ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // The mine's own ROM/production piles.
          // MlSectionTitle's own `action` slot, not a Row wrapped around it.
          // The Row gave the button UNBOUNDED width and squeezed the Expanded
          // title to whatever was left — at 360px and text scale 2.0 that was
          // less than the 22px icon and its 10px gap, so the title's own row
          // overflowed by 25px. The slot knows how to move the action under
          // the title instead.
          MlSectionTitle(
            'ROM / production piles',
            meta: mlCount(productionPiles.length, 'pile'),
            icon: Icons.terrain_outlined,
            margin: EdgeInsets.zero,
            action: MlButton.outline(
              label: 'Add production pile',
              icon: Icons.add_rounded,
              compact: true,
              onPressed: () => _createPile(companyId),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Your own piles — separate from the capped order stockpiles the '
            'system creates per buyer order.',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: semantic.textMuted),
          ),
          const SizedBox(height: 12),
          if (productionPiles.isEmpty)
            MlCard(
              child: MlEmptyState(
                icon: Icons.terrain_outlined,
                title: 'No production piles yet.',
                message:
                    'Create a ROM/production pile to represent what the pit '
                    'has produced on site.',
              ),
            )
          else
            MlTileGrid.columns(
              columnsFor: (w) => w > 980 ? 3 : (w > 620 ? 2 : 1),
              children: [
                for (final p in productionPiles)
                  _ProductionPileCard(
                    pile: p,
                    onAddTons: () => _addTons(companyId, p),
                  ),
              ],
            ),
          const SizedBox(height: 24),

          // Recent tons-mined entries.
          MlSectionTitle(
            'Production log',
            icon: Icons.history_rounded,
            meta: entriesAsync.valueOrNull == null
                ? null
                : mlCount(entriesAsync.value!.length, 'entry', 'entries'),
          ),
          entriesAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => Text(
              'Could not load entries. ${friendlyError(e)}',
              style: TextStyle(color: semantic.textMuted),
            ),
            data: (entries) {
              if (entries.isEmpty) {
                return MlCard(
                  child: MlEmptyState(
                    icon: Icons.history_rounded,
                    title: 'Nothing recorded yet.',
                    message:
                        'Use "Record production" to log the tons mined each '
                        'day — the report above compares it against tons '
                        'dispatched.',
                  ),
                );
              }
              final pileNames = {for (final s in stockpiles) s.id: s.name};
              return MlCard(
                padding: const EdgeInsets.all(18),
                child: MlDataTable(
                  columns: const [
                    MlColumn('Date', flex: 2),
                    MlColumn('Tons', flex: 2, align: TextAlign.right),
                    MlColumn('Commodity', flex: 2),
                    MlColumn('Pit / section', flex: 2),
                    MlColumn('Pile', flex: 2),
                    MlColumn('Notes', flex: 3),
                  ],
                  rows: [
                    for (final e in entries)
                      [
                        Text(
                          _dateFmt.format(e.entryDate),
                          style: context.mlText.bodyMedium.copyWith(
                            color: semantic.textBody,
                          ),
                        ),
                        Text(
                          _t(e.tons),
                          textAlign: TextAlign.right,
                          style: context.mlText.code(
                            color: semantic.textStrong,
                            size: 13,
                            weight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          e.commodity ?? '—',
                          style: context.mlText.bodyMedium.copyWith(
                            color: semantic.textBody,
                          ),
                        ),
                        Text(
                          e.pitSection ?? '—',
                          style: context.mlText.bodyMedium.copyWith(
                            color: semantic.textBody,
                          ),
                        ),
                        Text(
                          e.stockpileId == null
                              ? '—'
                              : (pileNames[e.stockpileId] ?? '—'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.mlText.bodyMedium.copyWith(
                            color: semantic.textMuted,
                          ),
                        ),
                        Text(
                          e.notes ?? '—',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.mlText.bodyMedium.copyWith(
                            color: semantic.textMuted,
                          ),
                        ),
                      ],
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 60),
        ],
      ),
    );
  }

  Future<void> _recordProduction(
    String companyId,
    List<StockpileEntry> productionPiles,
  ) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _RecordProductionDialog(
        companyId: companyId,
        productionPiles: productionPiles,
      ),
    );
    if (saved == true) {
      ref.invalidateIfMounted(productionEntriesProvider(companyId));
      ref.invalidateIfMounted(
        productionReportProvider((companyId: companyId, days: _days)),
      );
      ref.invalidateIfMounted(stockpilesProvider(companyId));
      _snack('Production recorded.');
    }
  }

  Future<void> _createPile(String companyId) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _CreatePileDialog(companyId: companyId),
    );
    if (saved == true) {
      ref.invalidateIfMounted(stockpilesProvider(companyId));
      _snack('Production pile created.');
    }
  }

  Future<void> _addTons(String companyId, StockpileEntry pile) async {
    final tons = await showAddTonsDialog(context, pile);
    if (tons == null) return;
    try {
      final newBalance = await ref
          .read(lifecycleServiceProvider)
          .addTons(pile.id, tons);
      ref.invalidateIfMounted(stockpilesProvider(companyId));
      _snack(
        '${tons.toStringAsFixed(2)} t added to ${pile.name} — now '
        '${newBalance.toStringAsFixed(0)} t.',
      );
    } catch (e) {
      _snack('Could not add tons. ${friendlyError(e)}');
    }
  }
}

class _ReportSection extends StatelessWidget {
  final List<ProductionDispatchDay> days;
  final int windowDays;
  final VoidCallback onExport;
  const _ReportSection({
    required this.days,
    required this.windowDays,
    required this.onExport,
  });

  static final _dateFmt = DateFormat('dd MMM');

  @override
  Widget build(BuildContext context) {
    final semantic = MlSemantic.of(context);
    final mined = days.fold<double>(0, (s, d) => s + d.minedTons);
    final dispatched = days.fold<double>(0, (s, d) => s + d.dispatchedTons);
    // One object, so yield and loss cannot disagree about whether the window
    // has an answer in it — see [ProductionYield] for the day they did.
    final measure = ProductionYield(
      minedTons: mined,
      dispatchedTons: dispatched,
    );
    final yieldPct = measure.yieldPercent;
    final loss = measure.lossTons;

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
                label: 'Mined',
                value: '${mined.toStringAsFixed(2)} t',
                icon: Icons.terrain_outlined,
                tone: MlTone.accent,
              ),
              MlStatCard(
                label: 'Dispatched',
                value: '${dispatched.toStringAsFixed(2)} t',
                icon: Icons.local_shipping_outlined,
                tone: MlTone.transit,
              ),
              MlStatCard(
                label: 'Yield',
                value: yieldPct == null
                    ? '—'
                    : '${yieldPct.toStringAsFixed(1)}%',
                icon: Icons.percent_rounded,
                tone: yieldPct == null
                    ? MlTone.neutral
                    : (yieldPct >= 85 ? MlTone.done : MlTone.warn),
              ),
              MlStatCard(
                label: 'Pit-to-port loss',
                // Nothing recorded means no loss to state. Printing
                // `mined - dispatched` here reported "-771.32 t" IN GREEN on a
                // window where the pit had recorded nothing at all.
                value: loss == null ? '—' : '${loss.toStringAsFixed(2)} t',
                icon: Icons.trending_down_rounded,
                tone: loss == null
                    ? MlTone.neutral
                    : (loss > 0 ? MlTone.warn : MlTone.done),
              ),
            ];
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [for (final t in tiles) SizedBox(width: w, child: t)],
            );
          },
        ),
        const SizedBox(height: 12),
        MlCard(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              MlSectionTitle(
                'Daily — last ${mlCount(windowDays, 'day')}',
                meta:
                    '${mined.toStringAsFixed(2)} t mined · '
                    '${dispatched.toStringAsFixed(2)} t dispatched',
                icon: Icons.calendar_view_day_outlined,
                margin: EdgeInsets.zero,
                action: MlButton.outline(
                  label: 'Export',
                  icon: Icons.download_outlined,
                  compact: true,
                  onPressed: onExport,
                ),
              ),
              const SizedBox(height: 12),
              if (days.isEmpty)
                MlEmptyState(
                  icon: Icons.calendar_view_day_outlined,
                  title: 'No activity in this window.',
                  message:
                      'Record production and load trucks to build the '
                      'mined-vs-dispatched picture.',
                )
              else
                MlDataTable(
                  columns: const [
                    MlColumn('Date', flex: 2),
                    MlColumn('Mined', flex: 2, align: TextAlign.right),
                    MlColumn('Dispatched', flex: 2, align: TextAlign.right),
                    MlColumn('Day balance', flex: 2, align: TextAlign.right),
                  ],
                  rows: [
                    for (final d in days.reversed)
                      [
                        Text(
                          _dateFmt.format(d.day),
                          style: context.mlText.bodyMedium.copyWith(
                            color: semantic.textBody,
                          ),
                        ),
                        _mono(context, '${d.minedTons.toStringAsFixed(2)} t'),
                        _mono(
                          context,
                          '${d.dispatchedTons.toStringAsFixed(2)} t',
                        ),
                        _balanceCell(context, d.minedTons - d.dispatchedTons),
                      ],
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _mono(BuildContext context, String text) => Text(
    text,
    textAlign: TextAlign.right,
    style: context.mlText.code(
      color: MlSemantic.of(context).textStrong,
      size: 13,
      weight: FontWeight.w600,
    ),
  );

  Widget _balanceCell(BuildContext context, double v) {
    final tone = v.abs() < 0.005
        ? MlTone.neutral
        : (v > 0 ? MlTone.done : MlTone.warn);
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
          '${v > 0 ? '+' : ''}${v.toStringAsFixed(2)} t',
          style: context.mlText.code(
            color: colors.fg,
            size: 12,
            weight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

/// A ROM/production pile card: balance + structured grade summary + Add tons.
class _ProductionPileCard extends StatelessWidget {
  final StockpileEntry pile;
  final VoidCallback onAddTons;
  const _ProductionPileCard({required this.pile, required this.onAddTons});

  @override
  Widget build(BuildContext context) {
    final semantic = MlSemantic.of(context);
    return MlCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const MlIconWell(
                icon: Icons.terrain_outlined,
                tone: MlTone.done,
                size: 40,
                radius: 11,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pile.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: semantic.textStrong,
                      ),
                    ),
                    Text(
                      'ROM / production pile',
                      style: context.mlText.bodySmall.copyWith(
                        color: semantic.textFaint,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '${pile.tons.toStringAsFixed(2)} t',
            style: context.mlText.code(
              color: semantic.textStrong,
              size: 22,
              weight: FontWeight.w800,
            ),
          ),
          if (pile.mineral != null || pile.grade != null) ...[
            const SizedBox(height: 4),
            Text(
              [
                if (pile.mineral != null) pile.mineral!,
                if (pile.grade != null) pile.grade!,
              ].join(' · '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.mlText.bodyMedium.copyWith(
                color: semantic.textMuted,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: MlButton.outline(
              label: 'Add tons',
              icon: Icons.add_rounded,
              compact: true,
              onPressed: onAddTons,
            ),
          ),
        ],
      ),
    );
  }
}

class _RecordProductionDialog extends ConsumerStatefulWidget {
  final String companyId;
  final List<StockpileEntry> productionPiles;
  const _RecordProductionDialog({
    required this.companyId,
    required this.productionPiles,
  });

  @override
  ConsumerState<_RecordProductionDialog> createState() =>
      _RecordProductionDialogState();
}

class _RecordProductionDialogState
    extends ConsumerState<_RecordProductionDialog> {
  final _tons = TextEditingController();
  final _commodity = TextEditingController();
  final _pit = TextEditingController();
  final _notes = TextEditingController();
  // `MlTime.now()`, not the device clock. CLAUDE.md 7.1: never
  // `DateTime.now()` for anything a user reads as a date. This value is
  // a DATE the operator picks and submits, so on a laptop left on UTC it
  // pre-filled YESTERDAY between midnight and 02:00 SAST -- which is
  // night shift, the hours this screen exists for.
  DateTime _date = MlTime.now();
  String? _pileId;
  bool _saving = false;

  @override
  void dispose() {
    _tons.dispose();
    _commodity.dispose();
    _pit.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final tons = double.tryParse(_tons.text.trim());
    if (tons == null || tons <= 0) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Enter the tons mined first.')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await ref
          .read(productionServiceProvider)
          .recordProduction(
            companyId: widget.companyId,
            tons: tons,
            entryDate: _date,
            commodity: _commodity.text.trim().isEmpty
                ? null
                : _commodity.text.trim(),
            pitSection: _pit.text.trim().isEmpty ? null : _pit.text.trim(),
            stockpileId: _pileId,
            notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
          );
      navigator.pop(true);
    } catch (e) {
      if (mounted) setState(() => _saving = false);
      messenger.showSnackBar(
        SnackBar(
          content: Text('Could not record production. ${friendlyError(e)}'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Record production'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _tons,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                ],
                decoration: const InputDecoration(
                  labelText: 'Tons mined',
                  border: OutlineInputBorder(),
                  suffixText: 't',
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                icon: const Icon(Icons.event_outlined, size: 18),
                label: Text('Date: ${DateFormat('dd MMM yyyy').format(_date)}'),
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _date,
                    firstDate: MlTime.now().subtract(const Duration(days: 365)),
                    lastDate: MlTime.now(),
                  );
                  if (picked != null && mounted) setState(() => _date = picked);
                },
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _commodity,
                      decoration: const InputDecoration(
                        labelText: 'Commodity',
                        hintText: 'e.g. Chrome ore',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _pit,
                      decoration: const InputDecoration(
                        labelText: 'Pit / section',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String?>(
                initialValue: _pileId,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Add onto production pile (optional)',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('Log only — no pile'),
                  ),
                  for (final p in widget.productionPiles)
                    DropdownMenuItem<String?>(
                      value: p.id,
                      child: Text('${p.name} (${p.tons.toStringAsFixed(0)} t)'),
                    ),
                ],
                onChanged: (v) => setState(() => _pileId = v),
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
              : const Text('Record'),
        ),
      ],
    );
  }
}

class _CreatePileDialog extends ConsumerStatefulWidget {
  final String companyId;
  const _CreatePileDialog({required this.companyId});

  @override
  ConsumerState<_CreatePileDialog> createState() => _CreatePileDialogState();
}

class _CreatePileDialogState extends ConsumerState<_CreatePileDialog> {
  final _name = TextEditingController();
  final _mineral = TextEditingController();
  final _cr2o3 = TextEditingController();
  final _moisture = TextEditingController();
  final _sizing = TextEditingController();
  final _opening = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _mineral.dispose();
    _cr2o3.dispose();
    _moisture.dispose();
    _sizing.dispose();
    _opening.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final name = _name.text.trim();
    if (name.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Give the pile a name first.')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await ref
          .read(productionServiceProvider)
          .createProductionPile(
            companyId: widget.companyId,
            name: name,
            openingTons: double.tryParse(_opening.text.trim()) ?? 0,
            mineral: _mineral.text.trim().isEmpty ? null : _mineral.text.trim(),
            cr2o3Pct: double.tryParse(_cr2o3.text.trim()),
            moisturePct: double.tryParse(_moisture.text.trim()),
            sizing: _sizing.text.trim().isEmpty ? null : _sizing.text.trim(),
          );
      navigator.pop(true);
    } catch (e) {
      if (mounted) setState(() => _saving = false);
      messenger.showSnackBar(
        SnackBar(
          content: Text('Could not create the pile. ${friendlyError(e)}'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New ROM / production pile'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _name,
                decoration: const InputDecoration(
                  labelText: 'Pile name',
                  hintText: 'e.g. ROM Pad North',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _mineral,
                      decoration: const InputDecoration(
                        labelText: 'Mineral',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _opening,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Opening tons',
                        border: OutlineInputBorder(),
                        suffixText: 't',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _cr2o3,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
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
                        decimal: true,
                      ),
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
                  labelText: 'Sizing (optional)',
                  hintText: 'e.g. 6–15 mm lumpy',
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
              : const Text('Create pile'),
        ),
      ],
    );
  }
}
