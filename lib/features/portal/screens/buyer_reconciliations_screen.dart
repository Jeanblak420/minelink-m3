import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_application_1/features/portal/models/logistics_models.dart';
import 'package:flutter_application_1/features/portal/portal_colors.dart';
import 'package:flutter_application_1/features/portal/providers/logistics_provider.dart';
import 'package:flutter_application_1/features/portal/services/dispute_service.dart';
import 'package:flutter_application_1/features/portal/services/logistics_service.dart'
    show CompanyPin;
import 'package:flutter_application_1/features/portal/models/trip_reconciliation.dart';
import 'package:flutter_application_1/features/portal/services/reconciliation_service.dart';
import 'package:flutter_application_1/features/portal/services/recon_exporter.dart';
import 'package:flutter_application_1/features/portal/utils/portal_company_resolution.dart';
import 'package:flutter_application_1/core/design/components/ml_components.dart';
import 'package:flutter_application_1/features/portal/widgets/premium_overview_widgets.dart';
import 'package:flutter_application_1/features/portal/widgets/raw_recon_view.dart';
import 'package:flutter_application_1/features/portal/widgets/recon_uploads_panel.dart';
import 'package:flutter_application_1/features/portal/widgets/weight_reconciliation_view.dart';
import 'package:flutter_application_1/features/portal/widgets/portal_company_required.dart';
import 'package:flutter_application_1/core/time/ml_time.dart';
import 'package:flutter_application_1/features/tour/widgets/tour_target.dart';
import 'package:flutter_application_1/features/tour/examples/buyer_reconciliations_keys.dart';

/// Buyer "Tons & reconciliations" (§7.3): tonnage windowed by D/W/M/Y/T,
/// filterable by source (mine) and product, with the reconciliation batches to
/// view / download.
class BuyerReconciliationsScreen extends ConsumerStatefulWidget {
  const BuyerReconciliationsScreen({super.key});

  @override
  ConsumerState<BuyerReconciliationsScreen> createState() =>
      _BuyerReconciliationsScreenState();
}

class _BuyerReconciliationsScreenState
    extends ConsumerState<BuyerReconciliationsScreen> {
  String? _source; // loading_point
  String? _product; // commodity

  @override
  Widget build(BuildContext context) {
    final companyId = resolvePortalCompanyId(ref);
    if (companyId == null) {
      return const PortalCompanyRequired();
    }
    final async = ref.watch(logisticsSnapshotProvider(companyId));
    // Party ids -> names, so a reconciliation card can say who it is
    // between instead of printing three UUIDs. A failed partner read
    // leaves the map empty and the card says "Unknown company", which is
    // honest; it never prints the id.
    final nameById = <String, String>{
      for (final p
          in ref
                  .watch(
                    partnerCompaniesProvider((
                      companyId: companyId,
                      orgFilter: '',
                    )),
                  )
                  .valueOrNull ??
              const <CompanyPin>[])
        p.id: p.name,
    };

    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => MlLoadFailure(
        subject: 'the reconciliations',
        error: e,
        onRetry: () => ref.invalidate(logisticsSnapshotProvider(companyId)),
      ),
      data: (snap) {
        // Index the buyer's transactions for source/product lookup per trip.
        final txnById = {for (final w in snap.waybills) w.id: w};
        String sourceOf(TripRecord t) =>
            (txnById[t.transactionId]?.metadata['loading_point'] as String?) ??
            '—';
        String productOf(TripRecord t) =>
            (txnById[t.transactionId]?.metadata['commodity'] as String?) ??
            'Unspecified product';

        final buyerTrips = snap.trips
            .where((t) => txnById.containsKey(t.transactionId))
            .toList();
        final sources = {for (final t in buyerTrips) sourceOf(t)}.toList()
          ..sort();
        final products = {for (final t in buyerTrips) productOf(t)}.toList()
          ..sort();

        final filtered = buyerTrips.where((t) {
          if (_source != null && sourceOf(t) != _source) return false;
          if (_product != null && productOf(t) != _product) return false;
          return true;
        }).toList();
        final tons = _windows(filtered, MlTime.now());

        return MlPageBody(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              MlPageHeader(
                title: 'Reconciliations',
                meta:
                    '${mlCount(filtered.length, 'trip')} shown · '
                    '${buyerTrips.length} total',
                description:
                    'View recons by mine, route or overall — filter delivered tonnage '
                    'by source and product, then view or download batches.',
              ),
              const SizedBox(height: 16),
              WeightReconciliationView(companyId: companyId),
              const SizedBox(height: 16),
              RawReconView(companyId: companyId),
              const SizedBox(height: 16),
              ReconUploadsPanel(companyId: companyId),
              const SizedBox(height: 20),
              TourTarget(
                id: 'buyer.reconciliations.summary',
                targetKey: BuyerReconciliationsTourKeys.summaryCards,
                child: LayoutBuilder(
                  builder: (context, c) {
                    final w = c.maxWidth;
                    const gap = 14.0;
                    final cols = w > 720 ? 4 : 2;
                    final itemW = (w - gap * (cols - 1)) / cols;
                    final pending = snap.reconciliations
                        .where(
                          (r) => r.status == 'draft' || r.status == 'pending',
                        )
                        .length;
                    // Real, actionable disputes (open / under review) on this
                    // buyer's trips — wired to the recon_disputes workflow.
                    final disputed =
                        ref
                            .watch(reconDisputesProvider(companyId))
                            .asData
                            ?.value
                            .where((d) => d.status.isActive)
                            .length ??
                        0;
                    return Wrap(
                      spacing: gap,
                      runSpacing: gap,
                      children: [
                        SizedBox(
                          width: itemW,
                          child: MlStatCard(
                            label: 'Total records',
                            value: '${snap.reconciliations.length}',
                            icon: Icons.receipt_long_outlined,
                            tone: MlTone.accent,
                          ),
                        ),
                        SizedBox(
                          width: itemW,
                          child: MlStatCard(
                            label: 'Pending',
                            value: '$pending',
                            icon: Icons.schedule_outlined,
                            tone: MlTone.atMine,
                          ),
                        ),
                        SizedBox(
                          width: itemW,
                          child: MlStatCard(
                            label: 'Disputed',
                            value: '$disputed',
                            icon: Icons.error_outline_rounded,
                            tone: MlTone.warn,
                          ),
                        ),
                        SizedBox(
                          width: itemW,
                          child: MlStatCard(
                            // THIS FIGURE IS THE MINE'S NET, NOT THE
                            // DELIVERED TONS.
                            //
                            // `_windows` sums `TripRecord.netTons`, which
                            // CLAUDE.md §4 defines as the weight loaded at
                            // source and calls the authoritative figure for
                            // recon and billing; the delivered tonnage is a
                            // SEPARATE field, stored so the variance between
                            // them is visible. Labelling the loaded figure
                            // "delivered" collapses the one distinction this
                            // screen exists to make — and it did so directly
                            // below a card that spells it out: "Loaded (mine
                            // net) 103.22 t" over "Delivered 70.70 t" over
                            // "Net variance". Same screen, same scroll.
                            //
                            // So the label moves to the figure rather than
                            // the figure to the label, and it borrows the
                            // words `WeightReconciliationView` already uses.
                            label: 'Loaded (mine net)',
                            value: formatTons(tons.total),
                            icon: Icons.trending_up_rounded,
                            tone: MlTone.done,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              TourTarget(
                id: 'buyer.reconciliations.filters',
                targetKey: BuyerReconciliationsTourKeys.filters,
                child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _filter(
                      'Source',
                      'All sources',
                      _source,
                      sources,
                      (v) => setState(() => _source = v),
                    ),
                    _filter(
                      'Product',
                      'All products',
                      _product,
                      products,
                      (v) => setState(() => _product = v),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              TourTarget(
                id: 'buyer.reconciliations.tons',
                targetKey: BuyerReconciliationsTourKeys.tonsOverview,
                child: OverviewHeroTile(
                  // The same figure as the stat card above, and the same
                  // correction — `tons` is mine net throughout this screen.
                  title: 'Loaded (mine net)',
                  icon: Icons.scale_outlined,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AnimatedTons(
                        value: tons.total,
                        style: MlType.figure(
                          color: PortalColors.accent,
                          size: MlTokens.fsH1,
                        ),
                      ),
                      const SizedBox(height: 10),
                      MetricBreakdownRow(label: 'Daily (D)', value: tons.daily),
                      MetricBreakdownRow(
                        label: 'Weekly (W)',
                        value: tons.weekly,
                      ),
                      MetricBreakdownRow(
                        label: 'Monthly (M)',
                        value: tons.monthly,
                      ),
                      MetricBreakdownRow(
                        label: 'Yearly (Y)',
                        value: tons.yearly,
                      ),
                      MetricBreakdownRow(
                        label: 'Total (T)',
                        value: tons.total,
                        emphasize: true,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              TourTarget(
                id: 'buyer.reconciliations.batches',
                targetKey: BuyerReconciliationsTourKeys.batches,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    MlSectionTitle(
                      'Reconciliation batches',
                      icon: Icons.balance_outlined,
                      meta: mlCount(
                        snap.reconciliations.length,
                        'batch',
                        'batches',
                      ),
                    ),
                    if (snap.reconciliations.isEmpty)
                      MlCard(
                        child: MlEmptyState(
                          icon: Icons.balance_outlined,
                          title: 'No reconciliation batches yet.',
                          message:
                              'Batches are seeded automatically as trucks are loaded and delivered.',
                        ),
                      )
                    else
                      for (final r in snap.reconciliations)
                        _ReconCard(
                          recon: r,
                          companyId: companyId,
                          nameById: nameById,
                        ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// A filter dropdown. [all] names the "no filter" option — passed in
  /// rather than composed, because `'All $label'` produced "All Source"
  /// and "All Product". `raw_recon_view.dart`, on this same screen, has
  /// said "All products" since it was written.
  Widget _filter(
    String label,
    String all,
    String? value,
    List<String> options,
    ValueChanged<String?> onChanged,
  ) {
    return SizedBox(
      width: 240,
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

  TonsOutWindowsLite _windows(List<TripRecord> trips, DateTime now) {
    final dayAgo = now.subtract(const Duration(days: 1));
    final weekAgo = now.subtract(const Duration(days: 7));
    final monthAgo = now.subtract(const Duration(days: 30));
    final yearAgo = now.subtract(const Duration(days: 365));
    double d = 0, w = 0, m = 0, y = 0, total = 0;
    for (final t in trips) {
      final q = t.netTons;
      if (q == null) continue;
      final at = t.updatedAt;
      total += q;
      if (at.isAfter(yearAgo)) y += q;
      if (at.isAfter(monthAgo)) m += q;
      if (at.isAfter(weekAgo)) w += q;
      if (at.isAfter(dayAgo)) d += q;
    }
    return TonsOutWindowsLite(d, w, m, y, total);
  }
}

class TonsOutWindowsLite {
  final double daily, weekly, monthly, yearly, total;
  const TonsOutWindowsLite(
    this.daily,
    this.weekly,
    this.monthly,
    this.yearly,
    this.total,
  );
}

/// One reconciliation batch: who it is between, what it is worth, and a
/// download that is actually the reconciliation (P8-07).
class _ReconCard extends ConsumerWidget {
  final ReconciliationRecord recon;
  final String companyId;

  /// Resolves the party company ids to names. Without it the card printed raw
  /// UUIDs at the user, which is the label-vs-data fault in its purest form:
  /// the label said "Supplier", the value was `8b7fe004-ab9a-…`.
  final Map<String, String> nameById;

  const _ReconCard({
    required this.recon,
    required this.companyId,
    required this.nameById,
  });

  String _party(String? id) {
    if (id == null || id.isEmpty) return 'Not set';
    return nameById[id] ?? 'Unknown company';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: MlCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const MlIconWell(
                  icon: Icons.balance_outlined,
                  size: 40,
                  radius: 11,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${_party(recon.supplierCompanyId)} → '
                        '${_party(recon.buyerCompanyId)}',
                        // TWO lines: mine AND buyer, the two parties this
                        // reconciliation is BETWEEN, in a 143px card header on
                        // a phone.
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Hauled by ${_party(recon.transporterCompanyId)}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                // The badge and the date are the TRAILING pair, and both
                // were unflexed — so at 360 px and text scale 2.0 they
                // demanded their natural width side by side and ran 21 px
                // past the card, however far the `Expanded` title gave way.
                //
                // `Flexible` so the pair can shrink, `Wrap` so that when it
                // does the date drops under the badge instead of either being
                // ellipsised. This Row is inside a `Column` of bounded width,
                // so a flex child here is safe — unlike the load controller's
                // identity row, which is dropped into a shrink-wrapped Row.
                Flexible(
                  child: Wrap(
                    alignment: WrapAlignment.end,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 10,
                    runSpacing: 4,
                    children: [
                      MlStatusBadge.forStatus(recon.status),
                      Text(
                        MlTime.day(recon.updatedAt),
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            // A `Wrap`, not a `Row`: two unflexed buttons ran 32 px past
            // the card at 360 px and text scale 2.0. Neither label can be
            // ellipsised — a button that cannot say what it does is worse
            // than a taller card — so the second one drops to its own line.
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                MlButton.outline(
                  label: 'View',
                  icon: Icons.visibility_outlined,
                  compact: true,
                  onPressed: () => _showDetail(context, ref),
                ),
                MlButton.outline(
                  label: 'Download',
                  icon: Icons.download_outlined,
                  compact: true,
                  onPressed: () => _download(context, ref),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Exports the reconciliation itself (P8-07).
  ///
  /// This used to export **six key/value rows**: the batch's own primary key,
  /// its status, a date, and the three party company UUIDs. Nothing a
  /// reconciliation is for — not one load, not one tonnage, no variance — and
  /// three of the six values were raw UUIDs under labels that read as company
  /// names.
  ///
  /// It now emits the Side B rows for this company, through the SAME
  /// `WeightReconciliationView.exportHeaders` / `exportRows` the on-screen
  /// table renders, so the export and the screen cannot disagree. That carries
  /// reference, truck, product, source, customer, transporter, mine net,
  /// delivered and **variance** per load.
  void _download(BuildContext context, WidgetRef ref) {
    final rows = ref.read(tripReconciliationsProvider(companyId)).valueOrNull;
    if (rows == null || rows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Nothing to export yet — no reconciled loads on this batch.',
          ),
        ),
      );
      return;
    }
    final supplier = _party(recon.supplierCompanyId);
    final buyer = _party(recon.buyerCompanyId);
    ReconExporter.pickFormatAndExport(
      context,
      title: 'Reconciliation · $supplier → $buyer',
      filenameBase:
          'reconciliation_'
          '${supplier.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_')}',
      headers: WeightReconciliationView.exportHeaders,
      rows: WeightReconciliationView.exportRows(rows),
    );
  }

  /// The batch, in words (P8-21).
  ///
  /// This printed `recon.supplierCompanyId` under a label reading "Supplier" —
  /// a raw UUID presented as a company name. It now resolves the names and
  /// adds what a reconciliation is actually about: how many loads are on it and
  /// how the two weights compare.
  void _showDetail(BuildContext context, WidgetRef ref) {
    final rows =
        ref.read(tripReconciliationsProvider(companyId)).valueOrNull ??
        const <TripReconciliation>[];
    final delivered = rows.where((r) => r.deliveredTons != null).toList();
    final loaded = delivered.fold<double>(
      0,
      (a, r) => a + (r.mineNetTons ?? 0),
    );
    final arrived = delivered.fold<double>(
      0,
      (a, r) => a + (r.deliveredTons ?? 0),
    );
    final variance = delivered.fold<double>(0, (a, r) => a + (r.variance ?? 0));
    String t(double v) => '${v.toStringAsFixed(2)} t';

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Reconciliation detail'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _kv(context, 'Status', recon.status),
            _kv(context, 'Updated', MlTime.stamp(recon.updatedAt)),
            _kv(context, 'Supplier', _party(recon.supplierCompanyId)),
            _kv(context, 'Transporter', _party(recon.transporterCompanyId)),
            _kv(context, 'Buyer', _party(recon.buyerCompanyId)),
            const Divider(height: 20),
            // Dashes, not zeros, when nothing has been delivered yet: an
            // unreconciled batch has no tonnage, which is not the same as a
            // batch that reconciled to nothing.
            _kv(
              context,
              'Loads reconciled',
              delivered.isEmpty ? '—' : '${delivered.length} of ${rows.length}',
            ),
            _kv(context, 'Mine net', delivered.isEmpty ? '—' : t(loaded)),
            _kv(context, 'Delivered', delivered.isEmpty ? '—' : t(arrived)),
            _kv(context, 'Variance', delivered.isEmpty ? '—' : t(variance)),
          ],
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

  Widget _kv(BuildContext context, String k, String v) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            k,
            style: TextStyle(color: MlSemantic.of(context).textMuted),
          ),
        ),
        Expanded(child: Text(v)),
      ],
    ),
  );
}
