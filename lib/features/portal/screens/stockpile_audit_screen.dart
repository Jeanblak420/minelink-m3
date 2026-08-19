import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_application_1/features/portal/models/stockpile_transaction.dart';
import 'package:flutter_application_1/features/portal/portal_colors.dart';
import 'package:flutter_application_1/features/portal/providers/lifecycle_provider.dart';
import 'package:flutter_application_1/features/portal/providers/stockpile_ledger_provider.dart'
    show StockpileLedgerState;
import 'package:flutter_application_1/features/portal/utils/portal_company_resolution.dart';
import 'package:flutter_application_1/features/portal/widgets/premium_overview_widgets.dart';
import 'package:flutter_application_1/features/portal/widgets/portal_company_required.dart';
import 'package:intl/intl.dart';
import 'package:flutter_application_1/core/design/tokens/ml_tokens.dart';
import 'package:flutter_application_1/core/time/ml_time.dart';

/// Permanent stockpile audit trail: per-buyer balances and the full,
/// append-only history of allocations, additions and confirmed-load
/// deductions — every ton traceable from allocation to truck.
class StockpileAuditScreen extends ConsumerWidget {
  const StockpileAuditScreen({super.key});

  static final _ts = DateFormat('dd MMM yyyy · HH:mm');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final companyId = resolvePortalCompanyId(ref);
    if (companyId == null) {
      return const Scaffold(body: PortalCompanyRequired());
    }
    final ledger = ref.watch(stockpileLedgerDbProvider(companyId)).valueOrNull ??
        const StockpileLedgerState();

    final buyers = <String>{for (final s in ledger.stockpiles) s.buyer ?? ''}
      ..removeWhere((b) => b.isEmpty);
    final buyerList = buyers.toList()..sort();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Stockpile audit trail'),
        backgroundColor: MlSemantic.of(context).surfaceApp,
        foregroundColor: MlSemantic.of(context).textStrong,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Buyer allocations',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                for (final b in buyerList) _BuyerBalanceCard(buyer: b, ledger: ledger),
                const SizedBox(height: 24),
                Text('Transactions',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text('Newest first · append-only',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant)),
                const SizedBox(height: 12),
                if (ledger.transactions.isEmpty)
                  Text('No transactions yet.',
                      style: TextStyle(color: scheme.onSurfaceVariant))
                else
                  Container(
                    decoration: BoxDecoration(
                      color: scheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      border:
                          Border.all(color: MlSemantic.of(context).borderCard),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        for (var i = 0; i < ledger.transactions.length; i++) ...[
                          if (i > 0) const Divider(height: 1),
                          _TxnRow(txn: ledger.transactions[i], ts: _ts),
                        ],
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BuyerBalanceCard extends StatelessWidget {
  final String buyer;
  final StockpileLedgerState ledger;
  const _BuyerBalanceCard({required this.buyer, required this.ledger});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final piles = ledger.forBuyer(buyer);
    final remaining = ledger.buyerBalance(buyer);
    // Allocated/added totals and loaded-out come from the audit trail.
    double allocated = 0, loadedOut = 0;
    for (final t in ledger.transactions.where((t) => t.buyer == buyer)) {
      if (t.type == StockpileTxnType.deduction) {
        loadedOut += t.magnitude;
      } else {
        allocated += t.magnitude;
      }
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
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
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MlSemantic.of(context).borderCard),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.handshake_outlined,
                  size: 18, color: PortalColors.accent),
              const SizedBox(width: 8),
              Text(buyer,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800)),
              const Spacer(),
              Text('${piles.length} stockpile${piles.length == 1 ? '' : 's'}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _Stat(label: 'Allocated', value: formatTons(allocated)),
              _Stat(label: 'Loaded out', value: formatTons(loadedOut)),
              _Stat(
                label: 'Remaining',
                value: formatTons(remaining),
                emphasize: true,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final bool emphasize;
  const _Stat(
      {required this.label, required this.value, this.emphasize = false});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant)),
          const SizedBox(height: 2),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: emphasize ? PortalColors.accent : scheme.onSurface,
                ),
          ),
        ],
      ),
    );
  }
}

class _TxnRow extends StatelessWidget {
  final StockpileTransaction txn;
  final DateFormat ts;
  const _TxnRow({required this.txn, required this.ts});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isOut = txn.type == StockpileTxnType.deduction;
    final color = isOut ? MlTokens.red700 : MlTokens.green800;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isOut ? Icons.south_rounded : Icons.north_rounded,
              size: 18,
              color: color,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${txn.type.label} · ${txn.stockpileName} · ${txn.buyer}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  '${ts.format(MlTime.sast(txn.at))}'
                  '${txn.truckReg != null ? ' · truck ${txn.truckReg}' : ''}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${txn.delta >= 0 ? '+' : '−'}${formatTons(txn.magnitude)}',
                style: TextStyle(fontWeight: FontWeight.w800, color: color),
              ),
              Text('bal ${formatTons(txn.balanceAfter)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant)),
            ],
          ),
        ],
      ),
    );
  }
}
