import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter_application_1/core/design/shell/ml_window_class.dart';
import 'package:flutter_application_1/core/design/tokens/m3/ml_typography.dart';
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
              // No outer scroll view: MlDataTable owns its own now, with a
              // scrollbar. Two nested horizontal scrollers is one too many.
              // On a phone the rows are cards (Jean's go-ahead, 2026-10-24),
              // so nothing scrolls sideways at all.
              return _wideUnlessPhone(
                context,
                MlDataTable(
                  cardsOnPhone: true,
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
                        _text(context, r.routeLabel, strong: true, lines: 2),
                        _text(context, r.requesterName ?? '—', lines: 2),
                        _text(context, r.supplierName ?? '—', lines: 2),
                        _text(context, r.transporterNames ?? '—', lines: 2),
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
                          MlTime.day(r.updatedAt),
                        ),
                      ],
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _wideUnlessPhone(BuildContext context, Widget table) =>
      MlWindowClass.of(context).usesBottomNav
          ? table
          : MlWideTable(
              minWidth: 1200,
              child: SizedBox(width: 1200, child: table),
            );

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

  /// A cell of words.
  ///
  /// [lines] is 2 for the columns that hold a ROUTE or a LIST — "Iron Hills
  /// Mining → Richards Bay" is 201px in a 191px column and "Northline Carriers,
  /// Vaal Bulk Movers" is 230px in a 140px one, on a 1600px desktop. Widening
  /// them is not available: this table already pins itself to 1200px and
  /// scrolls, and the columns it would take the width from are the trip counts
  /// and the tonnage.
  Widget _text(BuildContext context, String text,
          {bool strong = false, int lines = 1}) =>
      Text(
        text,
        maxLines: lines,
        overflow: TextOverflow.ellipsis,
        style: context.mlText.titleSmall.copyWith(
          color: strong ? MlSemantic.of(context).textStrong : MlSemantic.of(context).textBody,
          fontWeight: strong ? FontWeight.w700 : FontWeight.w400,
        ),
      );

  Widget _mono(BuildContext context, String text) => Text(
    text,
    textAlign: TextAlign.right,
    maxLines: 1,
    style: context.mlText.code(
      color: MlSemantic.of(context).textStrong,
      size: 13,
      weight: FontWeight.w600,
    ),
  );
}
