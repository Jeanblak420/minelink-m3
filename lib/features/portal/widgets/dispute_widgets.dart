import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter_application_1/core/config/supabase_config.dart';
import 'package:flutter_application_1/core/utils/safe_ref.dart';
import 'package:flutter_application_1/features/portal/models/recon_dispute.dart';
import 'package:flutter_application_1/features/portal/services/dispute_service.dart';
import 'package:flutter_application_1/features/portal/services/reconciliation_service.dart';
import 'package:flutter_application_1/core/design/components/ml_components.dart';
import 'package:flutter_application_1/core/utils/friendly_error.dart';

/// Status → design tone (CLAUDE.md §5). open = needs attention (warn),
/// under review = in progress (transit/blue), resolved = done (green),
/// rejected = error (red), withdrawn = neutral.
MlTone disputeStatusTone(DisputeStatus s) => switch (s) {
      DisputeStatus.open => MlTone.warn,
      DisputeStatus.underReview => MlTone.transit,
      DisputeStatus.resolved => MlTone.done,
      DisputeStatus.rejected => MlTone.error,
      DisputeStatus.withdrawn => MlTone.neutral,
    };

class DisputeStatusChip extends StatelessWidget {
  final DisputeStatus status;
  const DisputeStatusChip(this.status, {super.key});

  @override
  Widget build(BuildContext context) => MlStatusBadge(
        label: status.label,
        tone: disputeStatusTone(status),
        dot: status.isActive,
      );
}

void _invalidateDisputes(WidgetRef ref, String? companyId) {
  ref.invalidate(reconDisputesProvider(companyId));
  ref.invalidate(reconDisputesProvider(null)); // admin inbox
  if (companyId != null) {
    ref.invalidate(tripReconciliationsProvider(companyId));
  }
}

void _snack(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(message)));
}

/// Raise-dispute dialog: category + reason (+ optional claimed tons). Called
/// from a variance row that has no active dispute.
Future<void> showRaiseDisputeDialog(
  BuildContext context,
  WidgetRef ref, {
  required String tripId,
  required String? companyId,
  String? reference,
  double? variance,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => _RaiseDisputeDialog(
      tripId: tripId,
      companyId: companyId,
      reference: reference,
      variance: variance,
    ),
  );
}

class _RaiseDisputeDialog extends ConsumerStatefulWidget {
  final String tripId;
  final String? companyId;
  final String? reference;
  final double? variance;
  const _RaiseDisputeDialog({
    required this.tripId,
    required this.companyId,
    this.reference,
    this.variance,
  });

  @override
  ConsumerState<_RaiseDisputeDialog> createState() =>
      _RaiseDisputeDialogState();
}

class _RaiseDisputeDialogState extends ConsumerState<_RaiseDisputeDialog> {
  DisputeCategory _category = DisputeCategory.weightVariance;
  final _reason = TextEditingController();
  final _claimed = TextEditingController();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    // Pre-fill the claimed tons with the observed shortfall, if any.
    final v = widget.variance;
    if (v != null && v > 0) _claimed.text = v.toStringAsFixed(2);
  }

  @override
  void dispose() {
    _reason.dispose();
    _claimed.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final reason = _reason.text.trim();
    if (reason.isEmpty) {
      _snack(context, 'Please describe the problem.');
      return;
    }
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      await ref.read(disputeServiceProvider).raise(
            tripId: widget.tripId,
            category: _category,
            reason: reason,
            claimedTons: double.tryParse(_claimed.text.trim()),
          );
      _invalidateDisputes(ref, widget.companyId);
      navigator.pop();
      messenger.showSnackBar(
        const SnackBar(content: Text('Dispute raised — the platform admin and '
            'the other parties have been notified.')),
      );
    } catch (e) {
      if (mounted) setState(() => _busy = false);
      messenger.showSnackBar(SnackBar(content: Text(_clean(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.reference == null
          ? 'Raise a dispute'
          : 'Raise a dispute — ${widget.reference}'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DropdownButtonFormField<DisputeCategory>(
                initialValue: _category,
                decoration: const InputDecoration(labelText: 'Category'),
                items: [
                  for (final c in DisputeCategory.values)
                    DropdownMenuItem(value: c, child: Text(c.label)),
                ],
                onChanged: _busy
                    ? null
                    : (c) => setState(() => _category = c ?? _category),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _reason,
                enabled: !_busy,
                minLines: 3,
                maxLines: 6,
                decoration: const InputDecoration(
                  labelText: 'What is wrong?',
                  hintText: 'Describe the discrepancy or problem…',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _claimed,
                enabled: !_busy,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Claimed tons (optional)',
                  hintText: 'e.g. shortfall in tons',
                  suffixText: 't',
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        MlButton.primary(
          label: _busy ? 'Raising…' : 'Raise dispute',
          onPressed: _busy ? null : _submit,
          compact: true,
        ),
      ],
    );
  }
}

/// Full dispute view: details, comment thread, and role-appropriate actions
/// (raiser can withdraw; platform admin can review / resolve / reject).
Future<void> showDisputeDetailDialog(
  BuildContext context,
  WidgetRef ref, {
  required ReconDispute dispute,
  required bool isAdmin,
  required String? companyId,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => _DisputeDetailDialog(
      dispute: dispute,
      isAdmin: isAdmin,
      companyId: companyId,
    ),
  );
}

class _DisputeDetailDialog extends ConsumerStatefulWidget {
  final ReconDispute dispute;
  final bool isAdmin;
  final String? companyId;
  const _DisputeDetailDialog({
    required this.dispute,
    required this.isAdmin,
    required this.companyId,
  });

  @override
  ConsumerState<_DisputeDetailDialog> createState() =>
      _DisputeDetailDialogState();
}

class _DisputeDetailDialogState extends ConsumerState<_DisputeDetailDialog> {
  final _comment = TextEditingController();
  bool _busy = false;

  ReconDispute get d => widget.dispute;

  bool get _isRaiser =>
      SupabaseConfig.client.auth.currentUser?.id == d.raisedByUserId;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action, String okMessage) async {
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      await action();
      _invalidateDisputes(ref, widget.companyId);
      ref.invalidateIfMounted(disputeCommentsProvider(d.id));
      navigator.pop();
      messenger.showSnackBar(SnackBar(content: Text(okMessage)));
    } catch (e) {
      if (mounted) setState(() => _busy = false);
      messenger.showSnackBar(SnackBar(content: Text(_clean(e))));
    }
  }

  Future<void> _addComment() async {
    final body = _comment.text.trim();
    if (body.isEmpty) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(disputeServiceProvider).addComment(d.id, body);
      _comment.clear();
      ref.invalidateIfMounted(disputeCommentsProvider(d.id));
      _invalidateDisputes(ref, widget.companyId);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(_clean(e))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resolveOrReject(DisputeStatus target) async {
    final note = await _promptNote(
      target == DisputeStatus.resolved ? 'Resolve dispute' : 'Reject dispute',
    );
    if (note == null || note.trim().isEmpty) return;
    await _run(
      () => ref
          .read(disputeServiceProvider)
          .setStatus(d.id, target, resolution: note.trim()),
      'Dispute ${target.label.toLowerCase()}.',
    );
  }

  Future<String?> _promptNote(String title) {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: 400,
          child: TextField(
            controller: ctrl,
            autofocus: true,
            minLines: 2,
            maxLines: 5,
            decoration: const InputDecoration(
              labelText: 'Resolution note (required)',
              alignLabelWithHint: true,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          MlButton.primary(
            label: 'Confirm',
            compact: true,
            onPressed: () => Navigator.of(ctx).pop(ctrl.text),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final semantic = MlSemantic.of(context);
    String t(double? v) => v == null ? '—' : '${v.toStringAsFixed(2)} t';

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 640),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      d.reference ?? 'Dispute',
                      style: TextStyle(
                        fontFamily: MlTokens.fontSans,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: semantic.textStrong,
                      ),
                    ),
                  ),
                  DisputeStatusChip(d.status),
                  IconButton(
                    tooltip: 'Close',
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Wrap(spacing: 8, runSpacing: 4, children: [
                MlStatusBadge(label: d.category.label, tone: MlTone.neutral),
                if (d.truckReg != null) MlPlatePill(d.truckReg!, fontSize: 11),
              ]),
              const SizedBox(height: 12),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _kv(context, 'From',
                          '${d.sourceName ?? '—'} → ${d.customerName ?? '—'}'),
                      if (d.transporterName != null)
                        _kv(context, 'Transporter', d.transporterName!),
                      _kv(context, 'Mine net', t(d.mineNetTons)),
                      _kv(context, 'Delivered', t(d.deliveredTons)),
                      _kv(context, 'Variance', t(d.variance)),
                      if (d.claimedTons != null)
                        _kv(context, 'Claimed', t(d.claimedTons)),
                      _kv(context, 'Raised by',
                          '${d.raisedByName ?? '—'}${d.raisedByCompanyName != null ? ' · ${d.raisedByCompanyName}' : ''}'),
                      const SizedBox(height: 8),
                      Text('Reason',
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: semantic.textStrong)),
                      const SizedBox(height: 2),
                      Text(d.reason,
                          style: TextStyle(color: semantic.textBody)),
                      if (d.resolution != null) ...[
                        const SizedBox(height: 10),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: disputeStatusTone(d.status)
                                .well(Theme.of(context).brightness),
                            borderRadius: BorderRadius.circular(MlTokens.rMd),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Resolution',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: semantic.textStrong)),
                              const SizedBox(height: 2),
                              Text(d.resolution!,
                                  style:
                                      TextStyle(color: semantic.textBody)),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 14),
                      Text('Discussion',
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: semantic.textStrong)),
                      const SizedBox(height: 6),
                      _CommentThread(disputeId: d.id),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              if (d.status.isActive) ...[
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _comment,
                        enabled: !_busy,
                        minLines: 1,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          hintText: 'Add a comment…',
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      onPressed: _busy ? null : _addComment,
                      icon: const Icon(Icons.send_rounded, size: 18),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.end,
                  children: _actions(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _actions() {
    final s = ref; // capture
    final actions = <Widget>[];
    if (widget.isAdmin) {
      if (d.status == DisputeStatus.open) {
        actions.add(MlButton.outline(
          label: 'Start review',
          compact: true,
          onPressed: _busy
              ? null
              : () => _run(
                    () => s
                        .read(disputeServiceProvider)
                        .setStatus(d.id, DisputeStatus.underReview),
                    'Dispute is now under review.',
                  ),
        ));
      }
      actions.add(MlButton.danger(
        label: 'Reject',
        compact: true,
        onPressed: _busy ? null : () => _resolveOrReject(DisputeStatus.rejected),
      ));
      actions.add(MlButton.go(
        label: 'Resolve',
        compact: true,
        onPressed:
            _busy ? null : () => _resolveOrReject(DisputeStatus.resolved),
      ));
    } else if (_isRaiser) {
      actions.add(MlButton.ghost(
        label: 'Withdraw',
        compact: true,
        onPressed: _busy
            ? null
            : () => _run(
                  () => s
                      .read(disputeServiceProvider)
                      .setStatus(d.id, DisputeStatus.withdrawn),
                  'Dispute withdrawn.',
                ),
      ));
    }
    return actions;
  }

  Widget _kv(BuildContext context, String k, String v) {
    final semantic = MlSemantic.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
              width: 92,
              child: Text(k, style: TextStyle(color: semantic.textMuted))),
          Expanded(
              child: Text(v, style: TextStyle(color: semantic.textBody))),
        ],
      ),
    );
  }
}

class _CommentThread extends ConsumerWidget {
  final String disputeId;
  const _CommentThread({required this.disputeId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final semantic = MlSemantic.of(context);
    final async = ref.watch(disputeCommentsProvider(disputeId));
    return async.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Text('Could not load the discussion. ${friendlyError(e)}',
          style: TextStyle(color: semantic.textMuted)),
      data: (comments) {
        if (comments.isEmpty) {
          return Text('No comments yet.',
              style: TextStyle(color: semantic.textMuted));
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final c in comments)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: semantic.surfaceSunken,
                    borderRadius: BorderRadius.circular(MlTokens.rMd),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Text(
                          c.authorName ??
                              (c.authorIsAdmin ? 'Platform admin' : 'User'),
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 12.5,
                              color: semantic.textStrong),
                        ),
                        const SizedBox(width: 6),
                        if (c.authorIsAdmin)
                          const MlStatusBadge(
                              label: 'ADMIN', tone: MlTone.accent),
                        if (c.authorCompanyName != null && !c.authorIsAdmin) ...[
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text('· ${c.authorCompanyName}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontSize: 12, color: semantic.textMuted)),
                          ),
                        ],
                      ]),
                      const SizedBox(height: 3),
                      Text(c.body, style: TextStyle(color: semantic.textBody)),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Trims a Postgres/Supabase error to the human message the RPC raised.
String _clean(Object e) {
  final s = e.toString();
  final m = RegExp(r'message: ([^,]+)').firstMatch(s);
  if (m != null) return m.group(1)!.trim();
  return s.replaceFirst('Exception: ', '');
}
