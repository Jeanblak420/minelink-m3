import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_application_1/core/config/supabase_config.dart';
import 'package:flutter_application_1/core/utils/safe_ref.dart';
import 'package:flutter_application_1/features/super_admin/data/models/models.dart';
import 'package:flutter_application_1/features/super_admin/providers/super_admin_providers.dart';
import 'package:flutter_application_1/core/design/components/ml_components.dart';
import 'package:intl/intl.dart';
import 'package:flutter_application_1/core/utils/friendly_error.dart';
import 'package:flutter_application_1/core/time/ml_time.dart';

/// Super-global admin queue: token and seat requests with claim / approve flow.
class TokenRequestsScreen extends ConsumerStatefulWidget {
  const TokenRequestsScreen({super.key});

  @override
  ConsumerState<TokenRequestsScreen> createState() => _TokenRequestsScreenState();
}

class _TokenRequestsScreenState extends ConsumerState<TokenRequestsScreen> {
  RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _subscribeRealtime());
  }

  void _subscribeRealtime() {
    _channel?.unsubscribe();
    _channel = SupabaseConfig.client
        .channel('token-requests-ui')
        ..onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'token_requests',
          callback: (_) {
            ref.invalidate(openTokenRequestsProvider);
            ref.invalidate(dashboardStatsProvider);
          },
        )
        ..subscribe();
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }

  String? get _currentUserId => Supabase.instance.client.auth.currentUser?.id;

  Future<void> _showDetailSheet(TokenRequest r) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: _RequestDetailPanel(
              request: r,
              currentUserId: _currentUserId,
              onRefresh: () {
                ref.invalidateIfMounted(openTokenRequestsProvider);
                ref.invalidateIfMounted(dashboardStatsProvider);
              },
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(openTokenRequestsProvider);
    return Scaffold(
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => MlEmptyState(
          icon: Icons.error_outline,
          title: 'Could not load requests',
          message: friendlyError(e),
        ),
        data: (list) {
          if (list.isEmpty) {
            return RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(openTokenRequestsProvider);
                ref.invalidate(dashboardStatsProvider);
              },
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 80),
                  MlEmptyState(
                    icon: Icons.inbox_outlined,
                    title: 'Queue is clear',
                    message: 'No open token requests right now.',
                  ),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(openTokenRequestsProvider);
              ref.invalidate(dashboardStatsProvider);
            },
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: list.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final r = list[i];
                final df = DateFormat.yMMMd().add_jm();
                final semantic = MlSemantic.of(context);
                return MlCard(
                  padding: const EdgeInsets.all(14),
                  onTap: () => _showDetailSheet(r),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const MlIconWell(
                        icon: Icons.vpn_key_outlined,
                        tone: MlTone.accent,
                        size: 42,
                        radius: 12,
                      ),
                      const SizedBox(width: 13),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              r.organizationName,
                              style: TextStyle(
                                fontFamily: MlTokens.fontSans,
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                                color: semantic.textStrong,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '${r.requestKindLabel} · ${r.organizationType}',
                              style: TextStyle(fontFamily: MlTokens.fontSans, fontSize: 13, color: semantic.textMuted),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Created: ${df.format(MlTime.sast(r.createdAt))}',
                              style: TextStyle(fontFamily: MlTokens.fontMono, fontSize: 12, color: semantic.textFaint),
                            ),
                            if (r.isInProgress && r.handlingDisplayName != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                  'Handled by: ${r.handlingDisplayName}',
                                  style: const TextStyle(
                                    fontFamily: MlTokens.fontSans,
                                    fontSize: 13,
                                    color: MlTokens.accentHover,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      MlStatusBadge.forStatus(r.status),
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _RequestDetailPanel extends ConsumerStatefulWidget {
  final TokenRequest request;
  final String? currentUserId;
  final VoidCallback onRefresh;

  const _RequestDetailPanel({
    required this.request,
    required this.currentUserId,
    required this.onRefresh,
  });

  @override
  ConsumerState<_RequestDetailPanel> createState() => _RequestDetailPanelState();
}

class _RequestDetailPanelState extends ConsumerState<_RequestDetailPanel> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() fn) async {
    setState(() => _busy = true);
    try {
      await fn();
      if (mounted) {
        widget.onRefresh();
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyError(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _claim() async {
    final repo = ref.read(superAdminRepositoryProvider);
    await _run(() async {
      await repo.claimTokenRequest(widget.request.id);
    });
  }

  Future<void> _release() async {
    final repo = ref.read(superAdminRepositoryProvider);
    await _run(() async {
      await repo.releaseTokenRequestClaim(widget.request.id);
    });
  }

  Future<void> _reject() async {
    // Resolved before the dialog await, the way `_release` above already does
    // it: `ref` throws `StateError` once this card is gone, and a dialog can
    // easily outlive the row that opened it.
    final repo = ref.read(superAdminRepositoryProvider);
    final note = TextEditingController(text: 'Request rejected');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
      // Cold-phone audit 2026-08-18: this dialog holds input fields and did
      // not scroll, so at a large text size on a narrow phone its content
      // overflowed the viewport and the fields below the fold could not be
      // reached. Measured at 133px of clipped content on the token
      // generator, which is the same shape. `scrollable` only engages when
      // the content exceeds the space, so it is inert on a desktop.
      scrollable: true,
        title: const Text('Reject request'),
        content: TextField(
          controller: note,
          decoration: const InputDecoration(labelText: 'Note'),
          maxLines: 2,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Reject')),
        ],
      ),
    );
    if (ok != true) return;
    await _run(() async {
      await repo.rejectTokenRequest(requestId: widget.request.id, reviewNote: note.text);
    });
  }

  Future<void> _approveSeat() async {
    // Resolved before the dialog await — see `_reject`.
    final repo = ref.read(superAdminRepositoryProvider);
    final ctrl = TextEditingController(text: '${widget.request.requestedNewTotal}');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
      // Cold-phone audit 2026-08-18: this dialog holds input fields and did
      // not scroll, so at a large text size on a narrow phone its content
      // overflowed the viewport and the fields below the fold could not be
      // reached. Measured at 133px of clipped content on the token
      // generator, which is the same shape. `scrollable` only engages when
      // the content exceeds the space, so it is inert on a desktop.
      scrollable: true,
        title: const Text('Approve seat expansion'),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Approved seat limit'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Approve')),
        ],
      ),
    );
    if (ok != true) return;
    final v = int.tryParse(ctrl.text.trim());
    if (v == null || v <= 0) return;
    await _run(() async {
      await repo.approveTokenRequest(
        requestId: widget.request.id,
        approvedNewSeatLimit: v,
      );
    });
  }

  Future<void> _approveTokenKinds() async {
    // Resolved before the dialog await — see `_reject`.
    final repo = ref.read(superAdminRepositoryProvider);
    final daysCtrl = TextEditingController(
      text: '${widget.request.requestedValidDays ?? 30}',
    );
    final seatCtrl = TextEditingController(text: '${widget.request.requestedNewTotal}');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Approve token request'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: daysCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Valid days'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: seatCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Seat limit'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Issue token')),
        ],
      ),
    );
    if (ok != true) return;
    final days = int.tryParse(daysCtrl.text.trim());
    final seats = int.tryParse(seatCtrl.text.trim());
    if (days == null || days <= 0 || seats == null || seats <= 0) return;
    await _run(() async {
      await repo.approveTokenRequest(
        requestId: widget.request.id,
        validDays: days,
        approvedNewSeatLimit: seats,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.request;
    final uid = widget.currentUserId;
    final isHandler = r.handlingUserId != null && r.handlingUserId == uid;
    final inProgressOther =
        r.isInProgress && r.handlingUserId != null && r.handlingUserId != uid;

    final df = DateFormat.yMMMd().add_jm();

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            r.organizationName,
            style: TextStyle(
              fontFamily: MlTokens.fontSans,
              fontSize: MlTokens.fsH3,
              fontWeight: FontWeight.w800,
              color: MlSemantic.of(context).textStrong,
            ),
          ),
          const SizedBox(height: 8),
          Text('Kind: ${r.requestKindLabel}'),
          Text('Org type: ${r.organizationType}'),
          Text('Seats: ${r.currentSeatsUsed} / ${r.currentSeatLimit}'),
          if (r.requestKind == 'seat_expansion')
            Text('Requested total: ${r.requestedNewTotal} (+${r.requestedExtraSeats})'),
          if (r.requestedValidDays != null) Text('Requested validity (days): ${r.requestedValidDays}'),
          if (r.reason.isNotEmpty) Text('Reason: ${r.reason}'),
          Text('Submitted: ${df.format(MlTime.sast(r.createdAt))}'),
          const Divider(height: 32),
          if (inProgressOther) ...[
            Text(
              'This request is being handled by ${r.handlingDisplayName ?? 'another admin'}. '
              'Check back later for ${r.organizationName}.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 16),
            MlButton.tonal(
              label: 'Close',
              expand: true,
              onPressed: _busy ? null : () => Navigator.pop(context),
            ),
          ] else if (r.isPending) ...[
            Text(
              'Choose an action. “Start token process” reserves this request for you. '
              '“Come back later” closes this panel without changing the queue.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            MlButton.primary(
              label: _busy ? 'Working…' : 'Start token process',
              expand: true,
              onPressed: _busy ? null : _claim,
            ),
            const SizedBox(height: 8),
            MlButton.outline(
              label: 'Come back later',
              expand: true,
              onPressed: _busy ? null : () => Navigator.pop(context),
            ),
          ] else if (r.isInProgress && isHandler) ...[
            Text('You are handling this request.', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 12),
            if (r.requestKind == 'seat_expansion')
              MlButton.go(
                label: 'Approve seat change',
                expand: true,
                onPressed: _busy ? null : _approveSeat,
              )
            else
              MlButton.go(
                label: 'Approve & issue token',
                expand: true,
                onPressed: _busy ? null : _approveTokenKinds,
              ),
            const SizedBox(height: 8),
            MlButton.danger(
              label: 'Reject',
              expand: true,
              onPressed: _busy ? null : _reject,
            ),
            const SizedBox(height: 8),
            MlButton.ghost(
              label: 'Release claim (back to queue)',
              expand: true,
              onPressed: _busy ? null : _release,
            ),
            const SizedBox(height: 8),
            MlButton.outline(
              label: 'Open organization',
              expand: true,
              onPressed: () {
                Navigator.pop(context);
                context.push('/super-admin/organization/${r.organizationId}');
              },
            ),
          ],
        ],
      ),
    );
  }
}
