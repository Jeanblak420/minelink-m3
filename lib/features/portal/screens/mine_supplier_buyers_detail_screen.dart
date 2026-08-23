import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_application_1/features/operations/models/operations_models.dart';
import 'package:flutter_application_1/features/portal/models/logistics_models.dart';
import 'package:flutter_application_1/features/portal/portal_colors.dart';
import 'package:flutter_application_1/features/portal/models/stockpile_entry.dart';
import 'package:flutter_application_1/features/portal/providers/lifecycle_provider.dart';
import 'package:flutter_application_1/features/portal/providers/logistics_provider.dart';
import 'package:flutter_application_1/features/portal/services/logistics_service.dart';
import 'package:flutter_application_1/features/portal/utils/mine_supplier_overview_metrics.dart';
import 'package:flutter_application_1/features/portal/utils/portal_company_resolution.dart';
import 'package:flutter_application_1/core/design/components/ml_components.dart';
import 'package:flutter_application_1/features/portal/widgets/partner_load_error.dart';
import 'package:flutter_application_1/features/portal/widgets/premium_overview_widgets.dart';
import 'package:flutter_application_1/features/portal/widgets/request_dialogs.dart';
import 'package:flutter_application_1/features/portal/widgets/portal_company_required.dart';
import 'package:intl/intl.dart';
import 'package:flutter_application_1/core/time/ml_time.dart';

/// One buyer aggregated for the mine: outbound tons + allocated stockpile
/// balance, keyed by company id where known (falls back to the buyer label
/// used on stockpile allocations).
class _BuyerRow {
  final String? companyId;
  final String name;
  final double tonsOut;
  final double allocated;

  const _BuyerRow({
    this.companyId,
    required this.name,
    required this.tonsOut,
    required this.allocated,
  });
}

/// Mine/Supplier "Buyers" detail (§3.4): searchable buyer list with tons out;
/// selecting a buyer populates a full panel below — tons D/W/M/Y/T,
/// reconciliations, and a live-generated invoice.
class MineSupplierBuyersDetailScreen extends ConsumerStatefulWidget {
  /// Optionally focus a single buyer on open (from an overview buyer card).
  final String? focusBuyerName;

  const MineSupplierBuyersDetailScreen({super.key, this.focusBuyerName});

  @override
  ConsumerState<MineSupplierBuyersDetailScreen> createState() =>
      _MineSupplierBuyersDetailScreenState();
}

class _MineSupplierBuyersDetailScreenState
    extends ConsumerState<MineSupplierBuyersDetailScreen> {
  final _search = TextEditingController();
  String? _selectedName;

  @override
  void initState() {
    super.initState();
    _selectedName = widget.focusBuyerName;
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  /// Merges partner-company buyers, waybill tonnage and stockpile allocations
  /// into one de-duplicated, tonnage-sorted list.
  List<_BuyerRow> _buyers(
    LogisticsSnapshot snap,
    List<CompanyPin> partners,
    List<StockpileEntry> stockpiles,
  ) {
    final nameById = {for (final p in partners) p.id: p.name};
    final tonsByBuyer = MineSupplierOverviewMetrics.buyerTonnage(
      snap.waybills,
      nameById: nameById,
    );

    final byName = <String, _BuyerRow>{};
    void put(String name, {String? id, double tons = 0, double alloc = 0}) {
      final existing = byName[name];
      byName[name] = _BuyerRow(
        companyId: id ?? existing?.companyId,
        name: name,
        tonsOut: (existing?.tonsOut ?? 0) + tons,
        allocated: (existing?.allocated ?? 0) + alloc,
      );
    }

    for (final p in partners) {
      put(p.name, id: p.id);
    }
    for (final t in tonsByBuyer) {
      put(t.name, id: t.companyId, tons: t.tons);
    }
    for (final s in stockpiles) {
      final b = s.buyer;
      if (b == null || b.isEmpty) continue;
      put(b, id: s.buyerCompanyId, alloc: s.tons);
    }

    final rows = byName.values.toList()
      ..sort((a, b) => b.tonsOut.compareTo(a.tonsOut));
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    final companyId = resolvePortalCompanyId(ref);
    if (companyId == null) {
      return const PortalCompanyRequired();
    }

    final logistics = ref.watch(logisticsSnapshotProvider(companyId));
    // The partner read IS this screen's list, so its failure cannot be
    // resolved with `.valueOrNull ?? []` — that renders a confident empty
    // Buyers page out of an RLS denial or a dead network (P2-09).
    final partnersAsync = ref.watch(
        // `'buyer'`, the wire spelling — the same one `companies.org_type`
        // holds and `buyer_routes_mines_screen.dart` passes for
        // `'mineSupplier'`. It said `'Buyer'`, which works only because
        // `listPartnerCompanies` lowercases both sides, and which is enough to
        // make anything matching the argument exactly resolve to the wrong
        // list without erroring.
        partnerCompaniesProvider((companyId: companyId, orgFilter: 'buyer')));
    final stockpiles =
        ref.watch(stockpilesProvider(companyId)).valueOrNull ?? const [];

    // NO `Scaffold(appBar:)` — `/portal/mine/buyers` is a leaf of the portal
    // `ShellRoute`, whose top bar already reads "Buyers".
    return logistics.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => MlLoadFailure(
          subject: 'your buyers',
          error: e,
          onRetry: () => ref.invalidate(logisticsSnapshotProvider(companyId)),
      ),
      data: (snap) {
        if (partnersAsync.hasError) {
          return PartnerLoadError(
            companyId: companyId,
            orgFilter: 'buyer',
            error: partnersAsync.error!,
            subject: 'buyers',
          );
        }
        if (partnersAsync.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        final partners = partnersAsync.value ?? const <CompanyPin>[];
        final all = _buyers(snap, partners, stockpiles);
        final q = _search.text.trim().toLowerCase();
        final rows = q.isEmpty
            ? all
            : all
                .where((r) => r.name.toLowerCase().contains(q))
                .toList(growable: false);
        final selected = _selectedName == null
            ? null
            : all.firstWhere(
                (r) => r.name == _selectedName,
                orElse: () => _BuyerRow(name: _selectedName!, tonsOut: 0, allocated: 0),
              );

        return MlPageBody(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // A PAGE opens with `MlPageHeader`. This one opened with a
              // SECTION head and a hand-rolled `Text` under it — the
              // shape `MlPageHeader` exists to end (see its own doc
              // comment): a smaller editorial title indented by a
              // section icon, a description that is not part of the
              // header and therefore not laid out with it, and tools
              // that follow `MlSectionTitle`'s rules rather than the
              // measuring header's — which on a phone stranded the meta
              // at the LEFT margin under the title. Every other portal
              // page in this pass reads title · description · meta ·
              // actions.
              MlPageHeader(
                title: 'Buyers',
                description:
                    'Tonnage shipped per buyer, with recons and invoicing.',
                meta: rows.length == all.length
                    ? mlCount(all.length, 'buyer')
                    : '${rows.length} of ${all.length} shown',
                actions: [
                  MlButton.primary(
                    label: 'Request buyers',
                    icon: Icons.group_add_outlined,
                    compact: true,
                    onPressed: () =>
                        showBuyersRequestDialog(context, ref, companyId),
                  ),
                ],
                padding: EdgeInsets.zero,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _search,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  isDense: true,
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Search buyers…',
                ),
              ),
              const SizedBox(height: 16),
              if (all.isEmpty)
                _empty(context)
              else ...[
                LayoutBuilder(builder: (context, c) {
                  final w = c.maxWidth;
                  final cols = w > 980 ? 3 : (w > 620 ? 2 : 1);
                  const gap = 14.0;
                  final itemW =
                      cols <= 1 ? w : (w - gap * (cols - 1)) / cols;
                  return Wrap(
                    spacing: gap,
                    runSpacing: gap,
                    children: [
                      for (final r in rows)
                        SizedBox(
                          width: itemW,
                          child: BuyerOverviewCard(
                            name: r.name,
                            tons: r.tonsOut,
                            onRecons: () => showBuyerRecons(
                                context, r.name, _buyerReconsFor(snap, r)),
                            onInvoice: () => showBuyerInvoice(
                                context, r.name, _buyerWaybillsFor(snap, r)),
                            onDetails: () => setState(() => _selectedName =
                                r.name == _selectedName ? null : r.name),
                          ),
                        ),
                    ],
                  );
                }),
                if (selected != null) ...[
                  const SizedBox(height: 24),
                  _BuyerPanel(snap: snap, buyer: selected),
                ],
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _empty(BuildContext context) {
    return OverviewHeroTile(
      title: 'No buyers yet',
      icon: Icons.handshake_outlined,
      child: Text(
        'Buyers connected through your transactions or stockpile allocations '
        'will appear here with their tonnage, recons and invoicing.',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
      ),
    );
  }

}

/// Waybills attributable to [buyer] (by company id where known).
List<OperationTransaction> _buyerWaybillsFor(
    LogisticsSnapshot snap, _BuyerRow buyer) {
  if (buyer.companyId == null) return const [];
  return snap.waybills
      .where((w) => w.buyerCompanyId == buyer.companyId)
      .toList();
}

/// Reconciliations attributable to [buyer].
List<ReconciliationRecord> _buyerReconsFor(
    LogisticsSnapshot snap, _BuyerRow buyer) {
  if (buyer.companyId == null) return const [];
  return snap.reconciliations
      .where((r) => r.buyerCompanyId == buyer.companyId)
      .toList();
}

/// Live-generated invoice dialog for a buyer's shipped loads.
void showBuyerInvoice(BuildContext context, String buyerName,
    List<OperationTransaction> waybills) {
  final fmt = NumberFormat('#,##0.00');
  final total = waybills.fold<double>(0, (a, w) => a + w.netTonsOut);
  showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text('Invoice · $buyerName'),
      content: SizedBox(
        width: 420,
        child: waybills.isEmpty
            ? const Text(
                'No shipped loads to invoice for this buyer yet. Loads appear '
                'here once trucks have been loaded against this buyer.')
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${mlCount(waybills.length, 'load')} · '
                      '${fmt.format(total)} t total'),
                  const Divider(),
                  Flexible(
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          for (final w in waybills)
                            ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              title: Text(w.referenceNumber),
                              trailing: Text('${fmt.format(w.netTonsOut)} t'),
                              subtitle: Text(MlTime.day(w.updatedAt)),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Close'),
        ),
      ],
    ),
  );
}

/// Reconciliation list dialog for a buyer.
void showBuyerRecons(BuildContext context, String buyerName,
    List<ReconciliationRecord> recons) {
  showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text('Recons · $buyerName'),
      content: SizedBox(
        width: 420,
        child: recons.isEmpty
            ? const Text('No reconciliations for this buyer yet.')
            : SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final r in recons)
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.balance_outlined),
                        title: Text('Recon ${r.id.substring(0, 8)}…'),
                        subtitle: Text('Status: ${r.status}'),
                      ),
                  ],
                ),
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Close'),
        ),
      ],
    ),
  );
}

/// Past-invoices placeholder dialog (invoice persistence pending).
void showBuyerPastInvoices(BuildContext context, String buyerName) {
  showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text('Past invoices · $buyerName'),
      content: const SizedBox(
        width: 420,
        child: Text(
          'No saved invoices yet. Generated invoices will be archived here '
          'once invoice persistence is enabled.',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Close'),
        ),
      ],
    ),
  );
}

/// Full per-buyer panel: tonnage windows, recons, and invoicing.
class _BuyerPanel extends StatelessWidget {
  final LogisticsSnapshot snap;
  final _BuyerRow buyer;

  const _BuyerPanel({required this.snap, required this.buyer});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final waybills = _buyerWaybillsFor(snap, buyer);
    final recons = _buyerReconsFor(snap, buyer);
    final tons = MineSupplierOverviewMetrics.tonsOut(waybills, now: MlTime.now());

    return OverviewHeroTile(
      title: buyer.name,
      icon: Icons.account_circle_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Tons out',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant)),
          AnimatedTons(
            value: tons.total,
            style: MlType.figure(
                color: PortalColors.accent, size: MlTokens.fsH1),
          ),
          const SizedBox(height: 8),
          MetricBreakdownRow(label: 'Daily (D)', value: tons.daily),
          MetricBreakdownRow(label: 'Weekly (W)', value: tons.weekly),
          MetricBreakdownRow(label: 'Monthly (M)', value: tons.monthly),
          MetricBreakdownRow(label: 'Yearly (Y)', value: tons.yearly),
          MetricBreakdownRow(label: 'Total (T)', value: tons.total, emphasize: true),
          const Divider(height: 28),
          Text('Reconciliations',
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          if (recons.isEmpty)
            Text('No reconciliations for this buyer yet.',
                style: TextStyle(color: scheme.onSurfaceVariant))
          else
            for (final r in recons)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.balance_outlined),
                title: Text('Recon ${r.id.substring(0, 8)}…'),
                subtitle: Text('Status: ${r.status} · '
                    '${MlTime.day(r.updatedAt)}'),
              ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.tonalIcon(
                onPressed: () => showBuyerInvoice(context, buyer.name, waybills),
                icon: const Icon(Icons.receipt_long_outlined, size: 18),
                label: const Text('Generate invoice'),
              ),
              OutlinedButton.icon(
                onPressed: recons.isEmpty
                    ? null
                    : () => showBuyerRecons(context, buyer.name, recons),
                icon: const Icon(Icons.download_rounded, size: 18),
                label: const Text('View recons'),
              ),
              OutlinedButton.icon(
                onPressed: () => showBuyerPastInvoices(context, buyer.name),
                icon: const Icon(Icons.history_rounded, size: 18),
                label: const Text('Past invoices'),
              ),
            ],
          ),
        ],
      ),
    );
  }

}
