import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_application_1/core/utils/safe_ref.dart';
import 'package:flutter_application_1/features/portal/models/stockpile_entry.dart';
import 'package:flutter_application_1/features/portal/portal_colors.dart';
import 'package:flutter_application_1/features/portal/providers/lifecycle_provider.dart';
import 'package:flutter_application_1/features/portal/screens/stockpile_audit_screen.dart';
import 'package:flutter_application_1/features/portal/utils/portal_company_resolution.dart';
import 'package:flutter_application_1/features/portal/widgets/premium_overview_widgets.dart';
import 'package:flutter_application_1/features/portal/widgets/stockpile_docs_dialog.dart';
import 'package:flutter_application_1/features/portal/widgets/stockpile_widgets.dart';
import 'package:flutter_application_1/features/portal/widgets/portal_company_required.dart';
import 'package:flutter_application_1/core/design/tokens/ml_tokens.dart';
import 'package:flutter_application_1/core/design/components/ml_tile_grid.dart';
import 'package:flutter_application_1/core/utils/friendly_error.dart';

/// Premium drill-down for the overview "Stockpile levels" tile: one card per
/// stockpile with its current (remaining) balance and per-pile actions, plus
/// access to the full stockpile audit trail.
class StockpileDetailScreen extends ConsumerWidget {
  const StockpileDetailScreen({super.key});

  void _snack(BuildContext context, String message) {
    // Callers reach here after an await, so the screen may already be gone;
    // `ScaffoldMessenger.of` would then throw on a deactivated ancestor.
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _addTons(
    BuildContext context,
    WidgetRef ref,
    String companyId,
    StockpileEntry pile,
  ) async {
    final tons = await showAddTonsDialog(context, pile);
    if (tons == null) return;
    try {
      await ref.read(lifecycleServiceProvider).addTons(pile.id, tons);
      ref.invalidateIfMounted(stockpilesProvider(companyId));
      ref.invalidateIfMounted(stockpileLedgerDbProvider(companyId));
      if (context.mounted) {
        _snack(context, '${tons.toStringAsFixed(2)} t added to ${pile.name}.');
      }
    } catch (e) {
      if (context.mounted) _snack(context, 'Could not add tons. ${friendlyError(e)}');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final companyId = resolvePortalCompanyId(ref);
    if (companyId == null) {
      return const Scaffold(body: PortalCompanyRequired());
    }
    final stockpiles =
        ref.watch(stockpilesProvider(companyId)).valueOrNull ?? const [];
    final totalBalance = stockpiles.fold<double>(0, (a, s) => a + s.tons);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Stockpile levels'),
        backgroundColor: MlSemantic.of(context).surfaceApp,
        foregroundColor: MlSemantic.of(context).textStrong,
        actions: [
          IconButton(
            tooltip: 'Audit trail',
            icon: const Icon(Icons.history_rounded),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const StockpileAuditScreen()),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // The label is Flexible and the figure is not, deliberately.
                // A Row gives non-flex children unbounded width, so a Text's
                // ellipsis never engages (CLAUDE.md §10.4) — this overflowed by
                // 23px at 360px wide and DEFAULT text scale, i.e. for anyone
                // opening this on a phone. Flexing the label lets it ellipsize;
                // the tonnage is the one thing on this line that must never be
                // truncated, so it keeps its intrinsic width.
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        'Remaining on hand',
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      formatTons(totalBalance),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: PortalColors.accent,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (stockpiles.isEmpty)
                  OverviewHeroTile(
                    title: 'No stockpiles yet',
                    icon: Icons.layers_outlined,
                    child: Text(
                      'Stockpiles allocated to buyers (from the Supervisor view) '
                      'will appear here with their remaining balances and actions.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  )
                else
                  MlTileGrid.columns(
                    columnsFor: (w) => w > 980 ? 3 : (w > 620 ? 2 : 1),
                    children: [
                      for (final s in stockpiles)
                        Builder(
                          builder: (context) => StockpileCard(
                            pile: s,
                            onAddTons: () =>
                                _addTons(context, ref, companyId, s),
                            onUploadResults: () => showStockpileDocsDialog(
                              context,
                              ref,
                              supplierCompanyId: companyId,
                              pile: s,
                              kind: 'lab_result',
                            ),
                            onUploadPicture: () => showStockpileDocsDialog(
                              context,
                              ref,
                              supplierCompanyId: companyId,
                              pile: s,
                              kind: 'picture',
                            ),
                          ),
                        ),
                    ],
                  ),
                const SizedBox(height: 24),
                // Flexible so the button cannot exceed the page: with 18px of
                // horizontal padding either side, an icon and this label, it
                // overflowed by 26px at 360px wide and text scale 1.3. Flexing
                // bounds it and lets the label ellipsize instead.
                Row(
                  children: [
                    Flexible(
                      child: OutlinedButton.icon(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const StockpileAuditScreen(),
                          ),
                        ),
                        icon: const Icon(Icons.receipt_long_outlined, size: 18),
                        label: const Text(
                          'View audit trail',
                          overflow: TextOverflow.ellipsis,
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 14,
                          ),
                          side: BorderSide(
                            color: MlSemantic.of(context).borderCard,
                          ),
                        ),
                      ),
                    ),
                    // "Request testing" removed: lab/quality test requests are
                    // not yet a scoped feature — a dead "coming soon" action was
                    // hidden rather than shown (AUDIT_FINDINGS item 3).
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
