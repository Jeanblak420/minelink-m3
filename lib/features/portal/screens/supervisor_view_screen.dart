import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_application_1/core/utils/safe_ref.dart';
import 'package:flutter_application_1/features/portal/models/stockpile_entry.dart';
import 'package:flutter_application_1/features/portal/portal_colors.dart';
import 'package:flutter_application_1/features/portal/providers/lifecycle_provider.dart';
import 'package:flutter_application_1/features/portal/providers/logistics_provider.dart';
import 'package:flutter_application_1/features/portal/providers/portal_tab_index_provider.dart';
import 'package:flutter_application_1/features/portal/screens/loading_activity_detail_screen.dart';
import 'package:flutter_application_1/features/portal/utils/mine_supplier_overview_metrics.dart';
import 'package:flutter_application_1/features/portal/utils/portal_company_resolution.dart';
import 'package:flutter_application_1/core/design/components/ml_components.dart';
import 'package:flutter_application_1/features/portal/widgets/premium_overview_widgets.dart';
import 'package:flutter_application_1/features/portal/widgets/stockpile_docs_dialog.dart';
import 'package:flutter_application_1/features/portal/widgets/stockpile_widgets.dart';
import 'package:flutter_application_1/features/portal/widgets/portal_company_required.dart';
import 'package:flutter_application_1/core/time/ml_time.dart';

/// Supervisor's main view for a Mine/Supplier org. Supervisors manage
/// stockpiles (add tons, add new stockpiles, upload results/pictures), open
/// the full loading-activity view, and see a minimal, non-clickable tons-out
/// snapshot (they cannot drill into the full tons-out detail like the mine).
class SupervisorViewScreen extends ConsumerStatefulWidget {
  const SupervisorViewScreen({super.key});

  @override
  ConsumerState<SupervisorViewScreen> createState() =>
      _SupervisorViewScreenState();
}

class _SupervisorViewScreenState extends ConsumerState<SupervisorViewScreen> {
  String? _focusClearScheduledFor;

  void _snack(String message) {
    // Every caller reaches here after an await, so the screen may already be
    // gone; `ScaffoldMessenger.of` would then throw on a deactivated ancestor.
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _addTons(String companyId, StockpileEntry pile) async {
    final tons = await showAddTonsDialog(context, pile);
    if (tons == null) return;
    try {
      final newBalance =
          await ref.read(lifecycleServiceProvider).addTons(pile.id, tons);
      ref.invalidateIfMounted(stockpilesProvider(companyId));
      ref.invalidateIfMounted(stockpileLedgerDbProvider(companyId));
      if (mounted) {
        final loads = (newBalance / 30).floor();
        _snack('${tons.toStringAsFixed(2)} t added to ${pile.name} — '
            'now ${newBalance.toStringAsFixed(0)} t'
            '${loads > 0 ? ' · ${mlCount(loads, 'load')} ready to collect' : ''}.');
      }
    } catch (e) {
      // The RPC raises a readable message (e.g. order-cap exceeded); surface it.
      if (mounted) _snack(_readableError(e));
    }
  }

  String _readableError(Object e) {
    final s = e.toString();
    final marker = s.indexOf(':');
    final msg = marker >= 0 && marker < s.length - 1
        ? s.substring(marker + 1).trim()
        : s;
    return msg.isEmpty ? 'Could not add tons.' : msg;
  }

  @override
  Widget build(BuildContext context) {
    final companyId = resolvePortalCompanyId(ref);
    if (companyId == null) {
      return const PortalCompanyRequired();
    }
    final logistics = ref.watch(logisticsSnapshotProvider(companyId));
    final stockpiles =
        ref.watch(stockpilesProvider(companyId)).valueOrNull ?? const [];

    // A notification may have asked us to focus a specific stockpile. Highlight
    // it, then clear the request so the ring fades after a moment.
    final focusId = ref.watch(pendingStockpileFocusProvider);
    if (focusId != null && focusId != _focusClearScheduledFor) {
      _focusClearScheduledFor = focusId;
      Future.delayed(const Duration(milliseconds: 2800), () {
        if (mounted && ref.read(pendingStockpileFocusProvider) == focusId) {
          ref.read(pendingStockpileFocusProvider.notifier).state = null;
        }
      });
    }

    return logistics.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => MlLoadFailure(
          subject: 'the supervisor view',
          error: e,
          onRetry: () => ref.invalidate(logisticsSnapshotProvider(companyId)),
      ),
      data: (snap) {
        final tons = MineSupplierOverviewMetrics.tonsOut(
          snap.waybills,
          now: MlTime.now(),
        );

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  MlPageHeader(
                    title: 'Supervisor',
                    meta: mlCount(stockpiles.length, 'stockpile'),
                    description:
                        'Manage stockpiles and monitor loading activity.',
                    padding: EdgeInsets.only(bottom: 20),
                  ),

                  // Stockpile levels. Stockpiles are created by the system when
                  // the super-admin dispatches an order — the supervisor fills
                  // them, they cannot create them freely.
                  MlSectionTitle(
                    'Stockpile levels',
                    icon: Icons.layers_outlined,
                    meta: mlCount(stockpiles.length, 'stockpile'),
                  ),
                  if (stockpiles.isEmpty)
                    OverviewHeroTile(
                      title: 'No stockpiles yet',
                      icon: Icons.layers_outlined,
                      child: Text(
                        'Order stockpiles appear here automatically when the '
                        'MineLink admin dispatches a buyer order to this mine — '
                        'each capped at the ordered tonnage; add product as it '
                        'arrives on site and the buyer & transporter are alerted '
                        'every full load. Your own ROM/production piles are '
                        'created on the Production tab and also show here.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color:
                                  Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                      ),
                    )
                  else
                  LayoutBuilder(
                    builder: (context, c) {
                      final w = c.maxWidth;
                      final cols = w > 980 ? 3 : (w > 620 ? 2 : 1);
                      const gap = 14.0;
                      final itemWidth =
                          cols <= 1 ? w : (w - gap * (cols - 1)) / cols;
                      return Wrap(
                        spacing: gap,
                        runSpacing: gap,
                        children: [
                          for (final s in stockpiles)
                            SizedBox(
                              width: itemWidth,
                              child: StockpileCard(
                                pile: s,
                                highlight: focusId != null && s.id == focusId,
                                onAddTons: () => _addTons(companyId, s),
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
                      );
                    },
                  ),
                  const SizedBox(height: 28),

                  // Loading activity (clickable -> full view).
                  _LoadingActivityButton(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const LoadingActivityDetailScreen(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Minimal, non-clickable tons-out snapshot.
                  _MinimalTonsOut(tons: tons),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _LoadingActivityButton extends StatelessWidget {
  final VoidCallback onTap;
  const _LoadingActivityButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return OverviewHeroTile(
      title: 'Loading activity',
      icon: Icons.local_shipping_outlined,
      onTap: onTap,
      child: Text(
        'Open the full loading activity — incoming and scheduled trucks.',
        style:
            Theme.of(context).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
      ),
    );
  }
}

/// Read-only tons-out snapshot. No onTap, no drill-down — supervisors only get
/// the minimal overview.
class _MinimalTonsOut extends StatelessWidget {
  final TonsOutWindows tons;
  const _MinimalTonsOut({required this.tons});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return OverviewHeroTile(
      title: 'Tons out',
      icon: Icons.outbound_outlined,
      badge: const OverviewPlaceholderBadge(label: 'view only'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Total',
              style:
                  textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
          AnimatedTons(
            value: tons.total,
            style: MlType.figure(
                color: PortalColors.accent, size: MlTokens.fsH1),
          ),
          const SizedBox(height: 12),
          MetricBreakdownRow(label: 'Daily (D)', value: tons.daily),
          MetricBreakdownRow(label: 'Weekly (W)', value: tons.weekly),
          MetricBreakdownRow(label: 'Monthly (M)', value: tons.monthly),
          MetricBreakdownRow(label: 'Yearly (Y)', value: tons.yearly),
        ],
      ),
    );
  }
}
