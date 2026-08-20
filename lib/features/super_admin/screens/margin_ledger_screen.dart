import 'package:flutter_application_1/core/design/tokens/m3/ml_shape.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:flutter_application_1/core/config/supabase_config.dart';
import 'package:flutter_application_1/core/design/tokens/m3/ml_typography.dart';
import 'package:flutter_application_1/features/portal/services/recon_exporter.dart';
import 'package:flutter_application_1/core/design/components/ml_components.dart';
import 'package:flutter_application_1/core/utils/friendly_error.dart';
import 'package:flutter_application_1/core/time/ml_time.dart';

/// One row of the super-admin margin ledger (from `list_margin_ledger`).
class MarginLedgerEntry {
  final String id;
  final String requestId;
  final String? routeNumber;
  final String? supplierName;
  final String? buyerName;
  final String? transporterName;
  final String? commodity;
  final String? loadingPoint;
  final String? offloadingPoint;
  final double agreedPricePerTon;
  final double adminMarginPerTon;
  final double transporterPricePerTon;
  final String currency;
  final double tonsMoved;
  final DateTime createdAt;

  const MarginLedgerEntry({
    required this.id,
    required this.requestId,
    required this.supplierName,
    this.routeNumber,
    this.buyerName,
    this.transporterName,
    this.commodity,
    this.loadingPoint,
    this.offloadingPoint,
    required this.agreedPricePerTon,
    required this.adminMarginPerTon,
    required this.transporterPricePerTon,
    required this.currency,
    required this.tonsMoved,
    required this.createdAt,
  });

  /// Your cut × the weighbridge tons actually moved on this route so far.
  double get marginEarned => adminMarginPerTon * tonsMoved;

  static String? _s(dynamic v) {
    final s = (v as String?)?.trim();
    return (s == null || s.isEmpty) ? null : s;
  }

  factory MarginLedgerEntry.fromJson(Map<String, dynamic> j) =>
      MarginLedgerEntry(
        id: j['id'] as String,
        requestId: j['request_id'] as String,
        routeNumber: _s(j['route_number']),
        supplierName: _s(j['supplier_name']),
        buyerName: _s(j['buyer_name']),
        transporterName: _s(j['transporter_name']),
        commodity: _s(j['commodity']),
        loadingPoint: _s(j['loading_point']),
        offloadingPoint: _s(j['offloading_point']),
        agreedPricePerTon: (j['agreed_price_per_ton'] as num?)?.toDouble() ?? 0,
        adminMarginPerTon: (j['admin_margin_per_ton'] as num?)?.toDouble() ?? 0,
        transporterPricePerTon:
            (j['transporter_price_per_ton'] as num?)?.toDouble() ?? 0,
        currency: (j['currency'] as String?) ?? 'ZAR',
        tonsMoved: (j['tons_moved'] as num?)?.toDouble() ?? 0,
        createdAt: DateTime.parse(j['created_at'] as String),
      );
}

/// Super-admin-only: all recorded margins (RLS-gated by list_margin_ledger).
final marginLedgerProvider =
    FutureProvider.autoDispose<List<MarginLedgerEntry>>((ref) async {
      final rows = await SupabaseConfig.client.rpc('list_margin_ledger');
      return (rows as List)
          .map((e) => MarginLedgerEntry.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    });

/// Margin ledger — the super-admin's private record of pricing per linked route:
/// agreed price, the admin's cut, and the resulting transporter price (CLAUDE.md
/// §4). Only the platform admin can see this. Filterable per mine (source) with
/// a live TOTALS row over whatever is in view.
class MarginLedgerScreen extends ConsumerStatefulWidget {
  const MarginLedgerScreen({super.key});

  @override
  ConsumerState<MarginLedgerScreen> createState() => _MarginLedgerScreenState();
}

class _MarginLedgerScreenState extends ConsumerState<MarginLedgerScreen> {
  static final _dateFmt = DateFormat('dd MMM yyyy · HH:mm');
  static final _num = NumberFormat('#,##0.00');
  static final _tonsFmt = NumberFormat('#,##0.0');

  /// Mine (source) name the table is scoped to; null = all mines.
  String? _mineFilter;

  String _money(double v, String currency) =>
      '${currency == 'ZAR' ? 'R' : currency} ${_num.format(v)}';

  /// Export columns — the ledger fields the screen shows (§4 margin ledger).
  /// Prices are plain numbers so the exporter's TOTAL row can sum them; the
  /// currency rides in its own column.
  static const List<String> exportHeaders = [
    'Date',
    'Route ID',
    'Mine (source)',
    'Buyer',
    'Transporter',
    'Commodity',
    'Loading point',
    'Offloading point',
    'Tons moved',
    'Agreed price / ton',
    'Admin cut / ton',
    'Transporter price / ton',
    'Margin earned',
    'Currency',
  ];

  /// One export row per ledger entry, mirroring the on-screen table order.
  static List<List<String>> exportRows(List<MarginLedgerEntry> entries) => [
    for (final e in entries)
      [
        _dateFmt.format(MlTime.sast(e.createdAt)),
        e.routeNumber ?? '—',
        e.supplierName ?? '—',
        e.buyerName ?? '—',
        e.transporterName ?? '—',
        e.commodity ?? '—',
        e.loadingPoint ?? '—',
        e.offloadingPoint ?? '—',
        e.tonsMoved.toStringAsFixed(1),
        e.agreedPricePerTon.toStringAsFixed(2),
        e.adminMarginPerTon.toStringAsFixed(2),
        e.transporterPricePerTon.toStringAsFixed(2),
        e.marginEarned.toStringAsFixed(2),
        e.currency,
      ],
  ];

  List<MarginLedgerEntry> _visible(List<MarginLedgerEntry> entries) =>
      _mineFilter == null
      ? entries
      : entries.where((e) => e.supplierName == _mineFilter).toList();

  @override
  Widget build(BuildContext context) {
    final semantic = MlSemantic.of(context);
    final async = ref.watch(marginLedgerProvider);

    return MlPageBody(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MlPageHeader(
            title: 'Margin ledger History',
            meta: async.valueOrNull == null
                ? null
                : mlCount(
                    _visible(async.value!).length,
                    'route priced',
                    'routes priced',
                  ),
            description:
                'Your private record of pricing on each linked route. '
                'Transporters never see your margin — only their price.',
            actions: [
              async.maybeWhen(
                data: (entries) {
                  final visible = _visible(entries);
                  final earned = visible.fold(
                    0.0,
                    (s, e) => s + e.marginEarned,
                  );
                  return MlButton.outline(
                    label: 'Export',
                    icon: Icons.download_outlined,
                    compact: true,
                    onPressed: () => ReconExporter.pickFormatAndExport(
                      context,
                      title: _mineFilter == null
                          ? 'Margin ledger'
                          : 'Margin ledger — $_mineFilter',
                      filenameBase: 'margin_ledger',
                      headers: exportHeaders,
                      rows: exportRows(visible),
                      summary: {
                        'Routes priced': '${visible.length}',
                        if (_mineFilter != null) 'Mine (source)': _mineFilter!,
                        'Tons moved': _tonsFmt.format(
                          visible.fold(0.0, (s, e) => s + e.tonsMoved),
                        ),
                        'Margin earned': 'R ${_num.format(earned)}',
                      },
                    ),
                  );
                },
                orElse: () => const SizedBox.shrink(),
              ),
              IconButton(
                tooltip: 'Refresh',
                onPressed: () => ref.invalidate(marginLedgerProvider),
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
          const SizedBox(height: 12),
          async.maybeWhen(
            data: (entries) => _mineFilterPill(context, entries),
            orElse: () => const SizedBox.shrink(),
          ),
          const SizedBox(height: 12),
          async.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => MlEmptyState(
              icon: Icons.error_outline,
              title: 'Could not load the ledger',
              message: friendlyError(e),
            ),
            data: (entries) {
              final visible = _visible(entries);
              if (visible.isEmpty) {
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 44),
                  decoration: BoxDecoration(
                    color: semantic.surfaceCard,
                    borderRadius: BorderRadius.circular(MlTokens.rXl),
                    border: Border.all(color: semantic.borderCard),
                  ),
                  child: MlEmptyState(
                    icon: Icons.receipt_long_outlined,
                    title: _mineFilter == null
                        ? 'No pricing recorded yet'
                        : 'No priced routes at this mine',
                    message: _mineFilter == null
                        ? 'Margins appear here once you link and dispatch a '
                              'route with pricing.'
                        : 'Choose another mine, or "All mines" to see every '
                              'priced route.',
                  ),
                );
              }
              return _table(context, visible);
            },
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  /// "All mines ▾" selector — scopes the table (and its totals + export) to
  /// the mine (source) where the priced routes take place.
  Widget _mineFilterPill(
    BuildContext context,
    List<MarginLedgerEntry> entries,
  ) {
    final semantic = MlSemantic.of(context);
    final accent = MlTone.accent.colors(Theme.of(context).brightness).fg;

    final mines = <String, int>{};
    for (final e in entries) {
      final m = e.supplierName;
      if (m != null) mines[m] = (mines[m] ?? 0) + 1;
    }
    final names = mines.keys.toList()..sort();
    final focused = _mineFilter != null;

    return PopupMenuButton<String>(
      tooltip: 'Filter by the mine where these routes take place',
      color: semantic.surfaceCard,
      shape: RoundedRectangleBorder(
        borderRadius: MlShape.radiusMedium,
        side: BorderSide(color: semantic.borderCard),
      ),
      onSelected: (v) => setState(() => _mineFilter = v.isEmpty ? null : v),
      itemBuilder: (_) => [
        PopupMenuItem<String>(
          value: '',
          height: 38,
          child: Row(
            children: [
              Icon(
                focused ? Icons.circle_outlined : Icons.check_rounded,
                size: 14,
                color: focused ? semantic.textFaint : accent,
              ),
              const SizedBox(width: 9),
              Text(
                'All mines',
                style: context.mlText.titleSmall.copyWith(
                  color: focused ? semantic.textStrong : accent,
                  fontWeight: focused ? FontWeight.w600 : FontWeight.w800,
                ),
              ),
              const Spacer(),
              Text(
                '${entries.length}',
                style: context.mlText.code(
                  color: semantic.textFaint,
                  size: 11,
                  weight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
        const PopupMenuDivider(),
        for (final name in names)
          PopupMenuItem<String>(
            value: name,
            height: 38,
            child: Row(
              children: [
                Icon(
                  name == _mineFilter
                      ? Icons.check_rounded
                      : Icons.circle_outlined,
                  size: 14,
                  color: name == _mineFilter ? accent : semantic.textFaint,
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.mlText.titleSmall.copyWith(
                      color: name == _mineFilter ? accent : semantic.textStrong,
                      fontWeight: name == _mineFilter ? FontWeight.w800 : FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '${mines[name]}',
                  style: context.mlText.code(
                    color: semantic.textFaint,
                    size: 11,
                    weight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
        decoration: BoxDecoration(
          color: focused
              ? accent.withValues(alpha: 0.12)
              : semantic.surfaceCard,
          borderRadius: MlShape.pill,
          border: Border.all(
            color: focused
                ? accent.withValues(alpha: 0.55)
                : semantic.borderCard,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.terrain_outlined,
              size: 15,
              color: focused ? accent : semantic.textFaint,
            ),
            const SizedBox(width: 7),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 240),
              child: Text(
                _mineFilter ?? 'All mines',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.mlText.titleSmall.copyWith(
                  color: semantic.textStrong,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 5),
            Icon(
              Icons.expand_more_rounded,
              size: 16,
              color: focused ? accent : semantic.textFaint,
            ),
          ],
        ),
      ),
    );
  }

  Widget _table(BuildContext context, List<MarginLedgerEntry> visible) {
    final semantic = MlSemantic.of(context);
    final totalTons = visible.fold(0.0, (s, e) => s + e.tonsMoved);
    final totalAgreed = visible.fold(0.0, (s, e) => s + e.agreedPricePerTon);
    final totalCut = visible.fold(0.0, (s, e) => s + e.adminMarginPerTon);
    final totalTransporter = visible.fold(
      0.0,
      (s, e) => s + e.transporterPricePerTon,
    );
    final totalEarned = visible.fold(0.0, (s, e) => s + e.marginEarned);
    final currencies = visible.map((e) => e.currency).toSet();
    final totCur = currencies.length == 1 ? currencies.first : 'ZAR';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: semantic.surfaceCard,
        borderRadius: BorderRadius.circular(MlTokens.rXl),
        border: Border.all(color: semantic.borderCard),
        boxShadow: MlTokens.shadowSm,
      ),
      child: MlDataTable(
        minWidth: 1180,
        columns: const [
          MlColumn('Date', flex: 3),
          MlColumn('Route', flex: 3),
          MlColumn('Mine (source)', flex: 4),
          MlColumn('Transporter · buyer', flex: 3),
          MlColumn('Tons moved', flex: 2, align: TextAlign.right),
          MlColumn('Agreed / ton', flex: 2, align: TextAlign.right),
          MlColumn('Your cut / ton', flex: 2, align: TextAlign.right),
          MlColumn('Transporter / ton', flex: 2, align: TextAlign.right),
          MlColumn('Margin earned', flex: 2, align: TextAlign.right),
        ],
        rows: [
          for (final e in visible)
            [
              _cell(context, _dateFmt.format(MlTime.sast(e.createdAt))),
              _cell2(context, e.routeNumber ?? '—', e.commodity),
              _cell2(
                context,
                e.supplierName ?? '—',
                (e.loadingPoint != null || e.offloadingPoint != null)
                    ? '${e.loadingPoint ?? '—'} → ${e.offloadingPoint ?? '—'}'
                    : null,
              ),
              _cell2(
                context,
                e.transporterName ?? '—',
                e.buyerName == null ? null : 'for ${e.buyerName}',
              ),
              _mono(
                context,
                e.tonsMoved <= 0 ? '—' : '${_tonsFmt.format(e.tonsMoved)} t',
              ),
              _mono(context, _money(e.agreedPricePerTon, e.currency)),
              _mono(
                context,
                _money(e.adminMarginPerTon, e.currency),
                tone: MlTone.done,
              ),
              _mono(context, _money(e.transporterPricePerTon, e.currency)),
              _mono(
                context,
                e.tonsMoved <= 0 ? '—' : _money(e.marginEarned, e.currency),
                tone: e.tonsMoved <= 0 ? null : MlTone.done,
              ),
            ],
          // TOTALS — every column summed over the rows in view (respects the
          // mine filter). Per-ton sums are the plain column totals requested;
          // "margin earned" is the genuinely meaningful money total.
          [
            _cell2(
              context,
              'TOTALS',
              '${visible.length} route'
                  '${visible.length == 1 ? '' : 's'}',
              strong: true,
            ),
            const SizedBox.shrink(),
            const SizedBox.shrink(),
            const SizedBox.shrink(),
            _mono(context, '${_tonsFmt.format(totalTons)} t', strong: true),
            _mono(context, _money(totalAgreed, totCur), strong: true),
            _mono(
              context,
              _money(totalCut, totCur),
              tone: MlTone.done,
              strong: true,
            ),
            _mono(context, _money(totalTransporter, totCur), strong: true),
            _mono(
              context,
              _money(totalEarned, totCur),
              tone: MlTone.done,
              strong: true,
            ),
          ],
        ],
      ),
    );
  }

  Widget _cell(BuildContext context, String text, {bool strong = false}) {
    final semantic = MlSemantic.of(context);
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: context.mlText.titleSmall.copyWith(
        color: strong ? semantic.textStrong : semantic.textBody,
        fontWeight: strong ? FontWeight.w700 : FontWeight.w400,
      ),
    );
  }

  /// Two-line identity cell: strong top line + faint detail line.
  Widget _cell2(
    BuildContext context,
    String top,
    String? sub, {
    bool strong = true,
  }) {
    final semantic = MlSemantic.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          top,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: context.mlText.titleSmall.copyWith(
            color: strong ? semantic.textStrong : semantic.textBody,
            fontWeight: strong ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
        if (sub != null) ...[
          const SizedBox(height: 2),
          Text(
            sub,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.mlText.labelSmall.copyWith(
              color: semantic.textFaint,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ],
    );
  }

  Widget _mono(
    BuildContext context,
    String text, {
    MlTone? tone,
    bool strong = false,
  }) {
    final color = tone == null
        ? MlSemantic.of(context).textStrong
        : tone.colors(Theme.of(context).brightness).fg;
    return Text(
      text,
      textAlign: TextAlign.right,
      maxLines: 1,
      style: TextStyle(
        fontFamily: MlTokens.fontMono,
        fontSize: strong ? 14 : 13.5,
        fontWeight: strong ? FontWeight.w800 : FontWeight.w700,
        color: color,
      ),
    );
  }
}
