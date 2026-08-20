import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:flutter_application_1/features/portal/models/request_tracking.dart';
import 'package:flutter_application_1/features/portal/providers/request_provider.dart';
import 'package:flutter_application_1/core/design/components/ml_components.dart';
import 'package:flutter_application_1/core/utils/friendly_error.dart';
import 'package:flutter_application_1/core/time/ml_time.dart';

/// Request tracking (Jean, 2026-07-12): every request this company is part
/// of — as requester, supplying mine, or dispatched transporter — followed
/// through to completion (all trips completed). [companyId] null = the
/// super-admin's platform-wide view.
class RequestTrackingView extends ConsumerWidget {
  const RequestTrackingView({super.key, required this.companyId});

  final String? companyId;

  static final _dateFmt = DateFormat('dd MMM yyyy');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(requestTrackingProvider(companyId));
    final semantic = MlSemantic.of(context);

    return MlCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // The action goes in the header's own slot rather than a Row wrapped
          // around it: a Row hands an unflexed button UNBOUNDED width
          // (CLAUDE.md 10.4) and squeezes the Expanded title to whatever is
          // left, which on a phone is less than the title needs. The slot
          // drops the action under the title instead.
          MlSectionTitle(
            'Request tracking',
            meta: async.valueOrNull == null
                ? null
                : mlCount(async.value!.length, 'request'),
            icon: Icons.track_changes_outlined,
            margin: EdgeInsets.zero,
            action: IconButton(
              tooltip: 'Refresh',
              onPressed: () =>
                  ref.invalidate(requestTrackingProvider(companyId)),
              icon: const Icon(Icons.refresh_rounded, size: 20),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Every request you are part of, followed to completion — a '
            'request completes when all of its trips are completed.',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: semantic.textMuted),
          ),
          const SizedBox(height: 14),
          async.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => Text(
              'Could not load tracking. ${friendlyError(e)}',
              style: TextStyle(color: semantic.textMuted),
            ),
            data: (rows) {
              if (rows.isEmpty) {
                return MlEmptyState(
                  icon: Icons.track_changes_outlined,
                  title: 'Nothing to track yet.',
                  message:
                      'Requests appear here as soon as you are part of '
                      'one — as requester, mine or transporter.',
                );
              }
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: 1200,
                  child: MlDataTable(
                    columns: const [
                      MlColumn('Type', flex: 2),
                      MlColumn('Route / product', flex: 4),
                      MlColumn('Requested by', flex: 3),
                      MlColumn('Mine', flex: 3),
                      MlColumn('Transporters', flex: 3),
                      MlColumn('Trips', flex: 2, align: TextAlign.right),
                      MlColumn('Tons', flex: 2, align: TextAlign.right),
                      // Wider so the "REQUESTED"/"COMPLETED" badge never clips.
                      MlColumn('Status', width: 118),
                      MlColumn('Updated', flex: 2),
                    ],
                    rows: [
                      for (final r in rows)
                        [
                          _text(context, r.typeLabel),
                          _text(context, r.routeLabel, strong: true),
                          _text(context, r.requesterName ?? '—'),
                          _text(context, r.supplierName ?? '—'),
                          _text(context, r.transporterNames ?? '—'),
                          _mono(
                            context,
                            r.tripsTotal == 0
                                ? '—'
                                : '${r.tripsCompleted}/${r.tripsTotal}',
                          ),
                          _mono(
                            context,
                            r.tonsDelivered == 0
                                ? '—'
                                : r.tonsDelivered.toStringAsFixed(2),
                          ),
                          _statusChip(context, r),
                          _text(
                            context,
                            _dateFmt.format(MlTime.sast(r.updatedAt)),
                          ),
                        ],
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _statusChip(BuildContext context, RequestTrackingRow r) {
    final tone = r.isCompleted
        ? MlTone.done
        : switch (r.status) {
            'linked' || 'approved' => MlTone.transit,
            'declined' => MlTone.error,
            'sent_back' => MlTone.warn,
            _ => MlTone.atMine,
          };
    return Align(
      alignment: Alignment.centerLeft,
      child: MlStatusBadge(
        label: r.isCompleted ? 'Completed' : r.displayStatus,
        tone: tone,
      ),
    );
  }

  Widget _text(BuildContext context, String text, {bool strong = false}) =>
      Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 13,
          fontWeight: strong ? FontWeight.w700 : FontWeight.w400,
          color: strong
              ? MlSemantic.of(context).textStrong
              : MlSemantic.of(context).textBody,
        ),
      );

  Widget _mono(BuildContext context, String text) => Text(
    text,
    textAlign: TextAlign.right,
    maxLines: 1,
    style: TextStyle(
      fontFamily: MlTokens.fontMono,
      fontSize: 13,
      fontWeight: FontWeight.w600,
      color: MlSemantic.of(context).textStrong,
      fontFeatures: const [FontFeature.tabularFigures()],
    ),
  );
}
