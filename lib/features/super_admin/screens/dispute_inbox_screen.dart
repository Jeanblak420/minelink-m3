import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter_application_1/core/design/tokens/m3/ml_typography.dart';
import 'package:flutter_application_1/features/portal/models/recon_dispute.dart';
import 'package:flutter_application_1/features/portal/services/dispute_service.dart';
import 'package:flutter_application_1/features/portal/widgets/dispute_widgets.dart';
import 'package:flutter_application_1/core/design/components/ml_components.dart';
import 'package:flutter_application_1/core/utils/friendly_error.dart';
import 'package:flutter_application_1/core/time/ml_time.dart';

/// The disputes the Active/All segment is currently showing.
///
/// Both the header's count and the list below read THIS, and that is the whole
/// point of it being a function. Until 2026-08-22 the header counted `all` and
/// the list rendered the filtered subset, so the console read
/// **"1 dispute"** directly above **"No open disputes"** — the platform's only
/// dispute was resolved, and the Active tab correctly hid it. Two readers of
/// one list, each applying its own rule, is how a header comes to contradict
/// the thing it is a header for.
List<ReconDispute> visibleDisputes(
  List<ReconDispute> all, {
  required bool activeOnly,
}) => activeOnly ? all.where((d) => d.status.isActive).toList() : all;

/// Super-admin reconciliation-dispute inbox. Lists every dispute raised across
/// the platform (list_recon_disputes with a null company scope) so the admin
/// can triage, review, and resolve/reject each one.
class DisputeInboxScreen extends ConsumerStatefulWidget {
  const DisputeInboxScreen({super.key});

  @override
  ConsumerState<DisputeInboxScreen> createState() => _DisputeInboxScreenState();
}

class _DisputeInboxScreenState extends ConsumerState<DisputeInboxScreen> {
  bool _activeOnly = true;

  @override
  Widget build(BuildContext context) {
    final semantic = MlSemantic.of(context);
    final async = ref.watch(reconDisputesProvider(null));
    final loaded = async.valueOrNull;
    final shown = loaded == null
        ? null
        : visibleDisputes(loaded, activeOnly: _activeOnly);

    return MlPageBody(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MlPageHeader(
            title: 'Reconciliation disputes',
            meta: shown == null
                ? null
                : mlCount(
                    shown.length,
                    _activeOnly ? 'open dispute' : 'dispute',
                  ),
            description:
                'Every dispute a mine, buyer or transporter raised on a '
                "trip's weight reconciliation. Review, resolve or reject.",
            actions: [
              IconButton(
                tooltip: 'Refresh',
                onPressed: () => ref.invalidate(reconDisputesProvider(null)),
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: true, label: Text('Active')),
              ButtonSegment(value: false, label: Text('All')),
            ],
            selected: {_activeOnly},
            onSelectionChanged: (s) => setState(() => _activeOnly = s.first),
          ),
          const SizedBox(height: 16),
          async.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => MlEmptyState(
              icon: Icons.error_outline,
              title: 'Could not load disputes',
              message: friendlyError(e),
            ),
            data: (all) {
              final disputes = visibleDisputes(all, activeOnly: _activeOnly);
              if (disputes.isEmpty) {
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 44),
                  decoration: BoxDecoration(
                    color: semantic.surfaceCard,
                    borderRadius: BorderRadius.circular(MlTokens.rXl),
                    border: Border.all(color: semantic.borderCard),
                  ),
                  child: MlEmptyState(
                    icon: Icons.gpp_good_outlined,
                    title: _activeOnly ? 'No open disputes' : 'No disputes yet',
                    message:
                        'When a party disputes a reconciliation variance, it '
                        'appears here for you to resolve.',
                  ),
                );
              }
              return Column(
                children: [
                  for (final d in disputes) ...[
                    _DisputeRowCard(
                      dispute: d,
                      onOpen: () => showDisputeDetailDialog(
                        context,
                        ref,
                        dispute: d,
                        isAdmin: true,
                        companyId: null,
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                ],
              );
            },
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

class _DisputeRowCard extends StatelessWidget {
  final ReconDispute dispute;
  final VoidCallback onOpen;

  const _DisputeRowCard({required this.dispute, required this.onOpen});

  static String _t(double? v) => v == null ? '—' : '${v.toStringAsFixed(2)} t';

  @override
  Widget build(BuildContext context) {
    final semantic = MlSemantic.of(context);
    final d = dispute;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: semantic.surfaceCard,
        borderRadius: BorderRadius.circular(MlTokens.rXl),
        border: Border.all(color: semantic.borderCard),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (d.truckReg != null) MlPlatePill(d.truckReg!, fontSize: 12),
              Text(
                d.reference ?? '—',
                style: TextStyle(
                  fontFamily: MlTokens.fontMono,
                  fontWeight: FontWeight.w700,
                  color: semantic.textStrong,
                ),
              ),
              MlStatusBadge(label: d.category.label, tone: MlTone.neutral),
              DisputeStatusChip(d.status),
              if (d.commentCount > 0)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.forum_outlined,
                      size: 14,
                      color: semantic.textFaint,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      '${d.commentCount}',
                      style: context.mlText.bodySmall.copyWith(
                        color: semantic.textFaint,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${d.sourceName ?? '—'} → ${d.customerName ?? '—'}'
            '${d.transporterName != null ? ' · ${d.transporterName}' : ''}',
            style: context.mlText.bodyMedium.copyWith(color: semantic.textBody),
          ),
          const SizedBox(height: 4),
          Text(
            'Variance ${_t(d.variance)}'
            '${d.claimedTons != null ? ' · claimed ${_t(d.claimedTons)}' : ''}',
            style: context.mlText.code(
              color: semantic.textMuted,
              size: 13,
              weight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            d.reason,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: semantic.textBody),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  'by ${d.raisedByName ?? '—'}'
                  '${d.raisedByCompanyName != null ? ' · ${d.raisedByCompanyName}' : ''}'
                  ' · ${MlTime.stamp(d.createdAt)}',
                  style: context.mlText.bodySmall.copyWith(
                    color: semantic.textFaint,
                  ),
                ),
              ),
              MlButton.outline(
                label: 'Review',
                icon: Icons.gavel_rounded,
                compact: true,
                onPressed: onOpen,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
