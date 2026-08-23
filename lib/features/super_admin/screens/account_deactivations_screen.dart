import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:flutter_application_1/core/design/tokens/m3/ml_typography.dart';
import 'package:flutter_application_1/core/time/ml_time.dart';
import 'package:flutter_application_1/core/utils/friendly_error.dart';
import 'package:flutter_application_1/core/utils/safe_ref.dart';
import 'package:flutter_application_1/core/design/components/ml_components.dart';
import 'package:flutter_application_1/features/super_admin/data/models/models.dart';
import 'package:flutter_application_1/features/super_admin/providers/super_admin_providers.dart';
import 'package:flutter_application_1/features/auth/models/user_type.dart';

/// Super-global admin console: the review queue over
/// `account_deactivation_requests` (Tasks 6-9 built the backend and the
/// user-facing card; nothing consumed the RPCs from a console screen until
/// this one).
///
/// 🚨 The default filter is load-bearing.
/// The nightly backstop (`apply_due_account_deactivations_job`) deliberately
/// skips a request whose requester owns a company (`deactivate_account`
/// raises `MLD01` for them, and retrying would raise forever without
/// progressing), so such a row sits at `approved` indefinitely.
/// `review_account_deactivation_request` does not prevent an admin approving
/// an owner's request in the first place, so this state is reachable by
/// ordinary use. A `pending`-only default would hide exactly the state that
/// needs a human — so this screen defaults to everything except the
/// terminal states (`deactivated` / `rejected` / `cancelled`).
///
/// [rows] lets a test (or a future caller) inject rows directly, bypassing
/// the Riverpod provider and the database entirely — the same shape as
/// `CrashReportsScreen.reports`. That path filters client-side over the
/// injected list; the live path does too (see
/// [accountDeactivationRequestsProvider]'s own doc for why a single full
/// fetch, filtered here, is simpler than the RPC's single-status signature).
class AccountDeactivationsScreen extends ConsumerStatefulWidget {
  final List<AccountDeactivationRow>? rows;

  const AccountDeactivationsScreen({super.key, this.rows});

  @override
  ConsumerState<AccountDeactivationsScreen> createState() =>
      _AccountDeactivationsScreenState();
}

/// Filter chip ids. `null` is the default — see the class doc.
const String _pendingFilter = 'pending';
const String _approvedFilter = 'approved';
const String _deactivatedFilter = 'deactivated';
const String _rejectedFilter = 'rejected';

class _AccountDeactivationsScreenState
    extends ConsumerState<AccountDeactivationsScreen> {
  String? _filter;
  final Set<String> _busyIds = {};

  /// [isLiveFetch] is true only for rows this screen fetched itself via
  /// [accountDeactivationRequestsProvider]. The default ("Needs review",
  /// `_filter == null`) then hides the terminal states
  /// (`deactivated`/`rejected`/`cancelled`) — see the class doc: a
  /// `pending`-only default would hide an `approved`-but-owner-blocked row,
  /// so the fix is to hide only what genuinely needs no further action, not
  /// to narrow all the way to `pending`.
  ///
  /// A caller that hands this screen an explicit [AccountDeactivationsScreen.rows]
  /// list — a test, or any future direct use — has already decided exactly
  /// what belongs on screen; applying the same default exclusion there would
  /// make the widget silently drop rows the caller explicitly included, which
  /// is a worse surprise than the one this default exists to fix. An
  /// explicit filter chip still narrows an injected list the same as a live
  /// one.
  List<AccountDeactivationRow> _filtered(
    List<AccountDeactivationRow> all, {
    required bool isLiveFetch,
  }) {
    Iterable<AccountDeactivationRow> out;
    switch (_filter) {
      case _pendingFilter:
        out = all.where((r) => r.status == 'pending');
      case _approvedFilter:
        out = all.where((r) => r.status == 'approved');
      case _deactivatedFilter:
        out = all.where((r) => r.status == 'deactivated');
      case _rejectedFilter:
        out = all.where((r) => r.status == 'rejected');
      default:
        out = isLiveFetch
            ? all.where((r) =>
                r.status != 'deactivated' &&
                r.status != 'rejected' &&
                r.status != 'cancelled')
            : all;
    }
    return [...out]..sort((a, b) => b.requestedAt.compareTo(a.requestedAt));
  }

  Future<void> _run(String rowId, Future<void> Function() fn) async {
    setState(() => _busyIds.add(rowId));
    try {
      await fn();
      ref.invalidateIfMounted(accountDeactivationRequestsProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(friendlyError(e))));
      }
    } finally {
      if (mounted) setState(() => _busyIds.remove(rowId));
    }
  }

  /// Confirms before approving. Fix round 1 (coordinator + reviewer,
  /// 2026-08-19): Approve queues a real deactivation the nightly 03:50 run
  /// will apply to a real person, with zero friction, while Reject — which
  /// changes nothing about anyone's access — asked for confirmation *and* a
  /// mandatory note. The lower-consequence action was the guarded one.
  Future<void> _approve(AccountDeactivationRow r) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Approve deactivation'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Approve ${r.displayName}\'s request to deactivate their '
              'account? They will be signed out and unable to sign in once '
              'this is applied by the nightly run. This can be reversed '
              'from this screen at any time with Reactivate.',
            ),
            if (r.isCompanyOwner) ...[
              const SizedBox(height: 12),
              Text(
                '${r.displayName} owns a company. The nightly run will '
                'skip this request until the company is suspended or '
                'ownership is transferred — approving it now will leave it '
                'stuck at "Approved" until a platform admin resolves that.',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: MlTone.warn.colors(Theme.of(ctx).brightness).fg,
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          MlButton.primary(
            label: 'Approve',
            compact: true,
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final repo = ref.read(superAdminRepositoryProvider);
    await _run(r.id, () => repo.reviewAccountDeactivationRequest(
          requestId: r.id,
          approve: true,
        ));
  }

  Future<void> _reject(AccountDeactivationRow r) async {
    final note = await showDialog<String>(
      context: context,
      builder: (_) => _RejectDialog(displayName: r.displayName),
    );
    if (note == null) return;
    final repo = ref.read(superAdminRepositoryProvider);
    await _run(r.id, () => repo.reviewAccountDeactivationRequest(
          requestId: r.id,
          approve: false,
          note: note,
        ));
  }

  Future<void> _reactivate(AccountDeactivationRow r) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reactivate account'),
        content: Text(
          'Restore ${r.displayName}\'s access? They will be able to sign in '
          'again immediately.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          MlButton.go(
            label: 'Reactivate',
            compact: true,
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final repo = ref.read(superAdminRepositoryProvider);
    await _run(r.id, () => repo.reactivateAccount(r.userId));
  }

  @override
  Widget build(BuildContext context) {
    final injected = widget.rows;
    if (injected != null) {
      return _Body(
        rows: _filtered(injected, isLiveFetch: false),
        filter: _filter,
        busyIds: _busyIds,
        onFilterChanged: (v) => setState(() => _filter = v),
        onApprove: _approve,
        onReject: _reject,
        onReactivate: _reactivate,
      );
    }

    final rowsAsync = ref.watch(accountDeactivationRequestsProvider);
    return rowsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => MlEmptyState(
        icon: Icons.error_outline,
        title: 'Could not load requests',
        message: friendlyError(e),
      ),
      data: (all) => _Body(
        rows: _filtered(all, isLiveFetch: true),
        filter: _filter,
        busyIds: _busyIds,
        onFilterChanged: (v) => setState(() => _filter = v),
        onApprove: _approve,
        onReject: _reject,
        onReactivate: _reactivate,
      ),
    );
  }
}

/// The actual page content, split out so both the injected-data path and the
/// provider-backed path render through one place — same shape as
/// `_CrashReportsBody`. Not a [Scaffold] itself; always hosted inside one,
/// either [AccountDeactivationsScreen]'s own (the live route) or the
/// caller's (tests wrap it in one directly).
class _Body extends StatelessWidget {
  final List<AccountDeactivationRow> rows;
  final String? filter;
  final Set<String> busyIds;
  final ValueChanged<String?> onFilterChanged;
  final ValueChanged<AccountDeactivationRow> onApprove;
  final ValueChanged<AccountDeactivationRow> onReject;
  final ValueChanged<AccountDeactivationRow> onReactivate;

  const _Body({
    required this.rows,
    required this.filter,
    required this.busyIds,
    required this.onFilterChanged,
    required this.onApprove,
    required this.onReject,
    required this.onReactivate,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // The shared page header, not a hand-rolled 16px sans title — every
        // other console screen opens in the Fraunces display face through
        // MlPageHeader, with a description and a count on the right. Found
        // 2026-08-23 in the Phase 3 pass.
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
          child: MlPageHeader(
            title: 'Account deactivations',
            description:
                'Requests to deactivate an account, and the accounts already '
                'held — approve, reject or reactivate.',
            meta: mlCount(rows.length, 'request'),
            padding: EdgeInsets.zero,
          ),
        ),
        const Divider(height: 1),
        SizedBox(
          width: double.infinity,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                ChoiceChip(
                  label: const Text('Needs review'),
                  selected: filter == null,
                  onSelected: (_) => onFilterChanged(null),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('Pending'),
                  selected: filter == _pendingFilter,
                  onSelected: (_) => onFilterChanged(_pendingFilter),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('Approved'),
                  selected: filter == _approvedFilter,
                  onSelected: (_) => onFilterChanged(_approvedFilter),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('Deactivated'),
                  selected: filter == _deactivatedFilter,
                  onSelected: (_) => onFilterChanged(_deactivatedFilter),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('Rejected'),
                  selected: filter == _rejectedFilter,
                  onSelected: (_) => onFilterChanged(_rejectedFilter),
                ),
              ],
            ),
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: rows.isEmpty
              ? const MlEmptyState(
                  icon: Icons.how_to_reg_outlined,
                  title: 'Nothing needs review',
                  message: 'No account deactivation requests in this view.',
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                  itemCount: rows.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final r = rows[i];
                    return _RequestCard(
                      row: r,
                      busy: busyIds.contains(r.id),
                      onApprove: onApprove,
                      onReject: onReject,
                      onReactivate: onReactivate,
                    );
                  },
                ),
        ),
      ],
    );
  }
}

MlTone _statusTone(AccountDeactivationRow r) {
  switch (r.status) {
    case 'pending':
      return MlTone.transit;
    case 'approved':
      // A stuck (owner-blocked) approval reads as a warning, not the same
      // neutral "waiting on tonight's run" amber as an ordinary approval.
      return r.isCompanyOwner ? MlTone.warn : MlTone.atMine;
    case 'reactivated':
      return MlTone.done;
    case 'rejected':
    case 'cancelled':
      return MlTone.error;
    case 'deactivated':
    default:
      return MlTone.neutral;
  }
}

class _RequestCard extends StatelessWidget {
  final AccountDeactivationRow row;
  final bool busy;
  final ValueChanged<AccountDeactivationRow> onApprove;
  final ValueChanged<AccountDeactivationRow> onReject;
  final ValueChanged<AccountDeactivationRow> onReactivate;

  const _RequestCard({
    required this.row,
    required this.busy,
    required this.onApprove,
    required this.onReject,
    required this.onReactivate,
  });

  @override
  Widget build(BuildContext context) {
    final semantic = MlSemantic.of(context);
    final brightness = Theme.of(context).brightness;
    final df = DateFormat('d MMM y');

    final chips = <Widget>[
      if (row.isBlockedApproved)
        _InfoChip(label: 'Blocked — owns a company', tone: MlTone.warn)
      else if (row.isCompanyOwner)
        _InfoChip(label: 'Company owner', tone: MlTone.neutral),
      if (row.activeTrips > 0)
        _InfoChip(
          label: row.activeTrips == 1
              ? '1 active trip'
              : '${row.activeTrips} active trips',
          tone: MlTone.atMine,
        ),
    ];

    final actions = <Widget>[
      if (row.isPending) ...[
        MlButton.primary(
          label: 'Approve',
          compact: true,
          onPressed: busy ? null : () => onApprove(row),
        ),
        MlButton.danger(
          label: 'Reject',
          compact: true,
          onPressed: busy ? null : () => onReject(row),
        ),
      ],
      if (row.isDeactivated)
        MlButton.go(
          label: 'Reactivate',
          compact: true,
          onPressed: busy ? null : () => onReactivate(row),
        ),
    ];

    return MlCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              MlIconWell(
                icon: Icons.person_off_outlined,
                tone: _statusTone(row),
                size: 42,
                radius: 12,
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Flexible(
                          child: Text(
                            row.displayName,
                            style: context.mlText.titleMedium.copyWith(
                              color: semantic.textStrong,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        MlStatusBadge(
                          label: row.status,
                          tone: _statusTone(row),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            // `controllerWB` is a column value, and it
                            // read exactly like that here while the platform
                            // users list beside it said "Load Controller" for
                            // the same person.
                            '${row.companyName ?? 'No company'} · '
                            '${UserRole.labelFor(row.role, fallback: 'Unknown role')}',
                            // TWO lines. Company AND role, and the role is the
                            // half at the end — so a long company name pushed
                            // the very thing that says what this person can do
                            // off the card ("…Logistics Holdings · Admin" cut
                            // at 295px).
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: context.mlText.bodyMedium.copyWith(
                              color: semantic.textMuted,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            'Requested ${df.format(MlTime.sast(row.requestedAt))}',
                            overflow: TextOverflow.ellipsis,
                            style: context.mlText.code(
                              color: semantic.textFaint,
                              size: 12,
                              weight: FontWeight.w400,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (row.isPending) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              _autoAppliesLabel(row.autoApplyAt),
                              overflow: TextOverflow.ellipsis,
                              style: context.mlText.labelMedium.copyWith(
                                color: MlTone.warn.colors(brightness).fg,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    if ((row.reason ?? '').trim().isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        row.reason!.trim(),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: context.mlText.bodyMedium.copyWith(
                          color: semantic.textBody,
                        ),
                      ),
                    ],
                    if (row.status == 'rejected' &&
                        (row.reviewNote ?? '').trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Note: ${row.reviewNote!.trim()}',
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: context.mlText.bodySmall.copyWith(
                          color: semantic.textFaint,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                    if (chips.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(spacing: 6, runSpacing: 6, children: chips),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (actions.isNotEmpty) ...[
            const SizedBox(height: 12),
            // Right-aligned, as the reference places a card's actions
            // (docs/design-reference.md §4: notice bar, data rows) and as
            // the request-review card beside this one does. They used to
            // hang at the card's far left, under the icon well. The Wrap
            // must claim the row first (CLAUDE.md §10.4) or `end` has no
            // free space to align within.
            SizedBox(
              width: double.infinity,
              child: Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                runSpacing: 8,
                children: actions,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// "Auto-applies in N days" — an admin must be able to see the clock they
  /// are not the only thing standing in front of. [autoApplyAt] is a UTC
  /// instant from the server; both sides of the subtraction go through
  /// [MlTime.sast] so the day count is not silently off by the SAST offset.
  String _autoAppliesLabel(DateTime autoApplyAt) {
    final days = MlTime.sast(autoApplyAt)
        .difference(MlTime.now())
        .inDays;
    if (days <= 0) return 'Auto-applies within a day';
    return 'Auto-applies in $days day${days == 1 ? '' : 's'}';
  }
}

/// A tonal pill that keeps the caller's exact casing — unlike
/// [MlStatusBadge], which always uppercases. Used for the blocker chips
/// ("Company owner", "N active trips"), which read as ordinary sentence
/// fragments rather than lifecycle-status pills.
class _InfoChip extends StatelessWidget {
  final String label;
  final MlTone tone;

  const _InfoChip({required this.label, required this.tone});

  @override
  Widget build(BuildContext context) {
    final colors = tone.colors(Theme.of(context).brightness);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: colors.bg,
        borderRadius: BorderRadius.circular(MlTokens.rPill),
      ),
      child: Text(
        label,
        style: context.mlText.labelMedium.copyWith(color: colors.fg),
      ),
    );
  }
}

/// Reject-with-note dialog. `review_account_deactivation_request` itself
/// refuses an empty note with SQLSTATE MLD02 — this mirrors that client-side
/// so the admin is never told "no" by a snackbar after already typing (and
/// submitting) a rejection.
class _RejectDialog extends StatefulWidget {
  final String displayName;

  const _RejectDialog({required this.displayName});

  @override
  State<_RejectDialog> createState() => _RejectDialogState();
}

class _RejectDialogState extends State<_RejectDialog> {
  final _note = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Rebuilds so the "Reject request" button's disabled state tracks the
    // field live, the same shape as the profile card's confirm dialog
    // (`_ConfirmDeactivationDialogState`) — a check only reached inside
    // `_submit` would leave the button tappable with an empty note.
    _note.addListener(_onChanged);
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _note.removeListener(_onChanged);
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canSubmit = _note.text.trim().isNotEmpty;
    return AlertDialog(
      // See token_requests_screen.dart's matching dialogs: scrollable so a
      // large text size on a narrow phone cannot clip the field below the
      // fold — inert on desktop, where the content already fits.
      scrollable: true,
      title: const Text('Reject request'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Declining ${widget.displayName}\'s deactivation request.'),
            const SizedBox(height: 12),
            TextField(
              controller: _note,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Reason',
                helperText:
                    'A reason is required — the requester will see it.',
                helperMaxLines: 2,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed:
              canSubmit ? () => Navigator.pop(context, _note.text.trim()) : null,
          child: const Text('Reject request'),
        ),
      ],
    );
  }
}
