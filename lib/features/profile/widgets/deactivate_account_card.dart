import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:flutter_application_1/core/time/ml_time.dart';
import 'package:flutter_application_1/core/utils/friendly_error.dart';
import 'package:flutter_application_1/core/utils/logger.dart';
import 'package:flutter_application_1/core/design/components/ml_components.dart';
import 'package:flutter_application_1/features/profile/models/account_deactivation_request.dart';
import 'package:flutter_application_1/features/profile/services/account_deactivation_service.dart';

/// Danger-toned profile card offering in-app account deactivation.
///
/// **The product never deletes an account** (spec §1.1, Jean's ruling
/// 2026-08-19). A user who reads "delete" here and gets deactivation has been
/// misled about what happened to their data -- a worse disclosure failure
/// than the one this feature set out to fix. Every string on this file,
/// including error copy, is checked against that rule:
/// `test/features/deactivate_account_card_test.dart` asserts the word never
/// appears anywhere on the card.
///
/// States: `none` (offer to deactivate) → confirm dialog (what happens, that
/// it is reversible, what is kept, the 30-day note, type `DEACTIVATE` +
/// password) → `pending` (under review, cancellable) → `approved` (scheduled,
/// no longer cancellable — an admin has acted) → `rejected` (the admin's
/// note; a fresh request is still allowed).
class DeactivateAccountCard extends StatefulWidget {
  const DeactivateAccountCard({super.key, this.service});

  /// Injected for tests. Defaults to the real Supabase-backed service,
  /// constructed lazily so this default is never touched unless actually
  /// needed (CLAUDE.md §6 — screens/widgets go through a service, not
  /// `SupabaseConfig.client` directly, for DB/RPC access).
  final AccountDeactivationService? service;

  @override
  State<DeactivateAccountCard> createState() => _DeactivateAccountCardState();
}

class _DeactivateAccountCardState extends State<DeactivateAccountCard> {
  late final AccountDeactivationService _service =
      widget.service ?? SupabaseAccountDeactivationService();
  static final _log = LoggerFactory.getLogger('DeactivateAccountCard');

  bool _loading = true;
  bool _busyAction = false;
  String? _loadError;
  AccountDeactivationRequest? _current;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final current = await _service.current();
      if (!mounted) return;
      setState(() {
        _current = current;
        _loading = false;
      });
    } catch (e) {
      _log.w('Could not load deactivation status: $e');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = friendlyError(e);
      });
    }
  }

  Future<void> _openConfirm() async {
    final requested = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ConfirmDeactivationDialog(service: _service),
    );
    if (requested == true) {
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)
        ?..clearSnackBars()
        ..showSnackBar(const SnackBar(
            content: Text(
                'Deactivation requested. You can check its status here at any time.')));
    }
  }

  Future<void> _cancel() async {
    setState(() => _busyAction = true);
    try {
      await _service.cancel();
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)
        ?..clearSnackBars()
        ..showSnackBar(
            const SnackBar(content: Text('Deactivation request cancelled.')));
    } catch (e) {
      if (!mounted) return;
      setState(() => _busyAction = false);
      ScaffoldMessenger.maybeOf(context)
        ?..clearSnackBars()
        ..showSnackBar(
            SnackBar(content: Text('Could not cancel. ${friendlyError(e)}')));
      return;
    }
    if (mounted) setState(() => _busyAction = false);
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final semantic = MlSemantic.of(context);
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: semantic.surfaceCard,
        borderRadius: BorderRadius.circular(MlTokens.rLg),
        border: Border.all(
          color: MlTone.error.colors(brightness).fg,
          width: 1.4,
        ),
      ),
      child: _content(context),
    );
  }

  Widget _content(BuildContext context) {
    if (_loading) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _header(context, title: 'Deactivate account'),
          const SizedBox(height: 14),
          const Center(
            child: SizedBox(
              height: 22,
              width: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ],
      );
    }
    if (_loadError != null) {
      final semantic = MlSemantic.of(context);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _header(context, title: 'Deactivate account'),
          const SizedBox(height: 10),
          Text(
            'Could not load your deactivation status. $_loadError',
            style: TextStyle(color: semantic.textMuted, height: 1.4),
          ),
        ],
      );
    }

    final req = _current;
    if (req == null) return _noneState(context);
    if (req.isPending) return _pendingState(context, req);
    if (req.isApproved) return _approvedState(context, req);
    return _rejectedState(context, req);
  }

  Widget _header(BuildContext context,
      {required String title, Widget? trailing}) {
    final brightness = Theme.of(context).brightness;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const MlIconWell(icon: Icons.person_off_rounded, tone: MlTone.error, size: 40),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: MlTone.error.colors(brightness).fg,
            ),
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: 10),
          // Flexible, not bare. A Row hands a non-flex child UNBOUNDED width
          // (CLAUDE.md §10.4), so the status badge measured at its natural
          // width and its own `overflow: ellipsis` could never engage — the
          // header simply overflowed instead. At 360px / text scale 1.3 the
          // "Pending review" badge was inside its box by well under a pixel,
          // so any change to the badge's metrics tipped it over, and one did.
          Flexible(child: trailing),
        ],
      ],
    );
  }

  Widget _noneState(BuildContext context) {
    final semantic = MlSemantic.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _header(context, title: 'Deactivate account'),
        const SizedBox(height: 10),
        Text(
          'If you no longer want to use MineLink, you can ask for your '
          'account to be deactivated. You will be signed out and will not be '
          'able to sign in again — but an administrator can restore your '
          'account at any time. Records of any loads you were part of are '
          'retained either way.',
          style: TextStyle(color: semantic.textMuted, height: 1.4),
        ),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerLeft,
          child: MlButton.danger(
            label: 'Deactivate my account',
            icon: Icons.person_off_outlined,
            onPressed: _openConfirm,
          ),
        ),
      ],
    );
  }

  Widget _pendingState(BuildContext context, AccountDeactivationRequest req) {
    final semantic = MlSemantic.of(context);
    final requested = MlTime.sast(req.requestedAt);
    final autoApply = req.autoApplyAt == null ? null : MlTime.sast(req.autoApplyAt!);
    final autoApplyClause = autoApply == null
        ? ''
        : ' If nobody reviews it, it applies automatically on '
            '${DateFormat('d MMM y').format(autoApply)}.';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _header(
          context,
          title: 'Deactivate account',
          trailing: const MlStatusBadge(
              label: 'Pending review', tone: MlTone.warn, dot: true),
        ),
        const SizedBox(height: 10),
        Text(
          'Your request to deactivate this account is being reviewed by a '
          'platform admin. Requested ${DateFormat('d MMM y').format(requested)}.'
          '$autoApplyClause',
          style: TextStyle(color: semantic.textMuted, height: 1.4),
        ),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerLeft,
          child: MlButton.outline(
            label: 'Cancel request',
            icon: Icons.undo_rounded,
            onPressed: _busyAction ? null : _cancel,
          ),
        ),
      ],
    );
  }

  Widget _approvedState(
      BuildContext context, AccountDeactivationRequest req) {
    final semantic = MlSemantic.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _header(
          context,
          title: 'Deactivate account',
          trailing: const MlStatusBadge(
              label: 'Approved', tone: MlTone.error, dot: true),
        ),
        const SizedBox(height: 10),
        Text(
          'A platform admin has approved this request. Your account will be '
          'deactivated shortly — you will not be able to sign in, though an '
          'administrator can restore it at any time. This can no longer be '
          'cancelled from here.',
          style: TextStyle(color: semantic.textMuted, height: 1.4),
        ),
      ],
    );
  }

  Widget _rejectedState(
      BuildContext context, AccountDeactivationRequest req) {
    final semantic = MlSemantic.of(context);
    final note = req.reviewNote;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _header(
          context,
          title: 'Deactivate account',
          trailing: const MlStatusBadge(
              label: 'Declined', tone: MlTone.neutral, dot: true),
        ),
        const SizedBox(height: 10),
        Text(
          'Your last deactivation request was declined.',
          style: TextStyle(color: semantic.textMuted, height: 1.4),
        ),
        if (note != null && note.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: semantic.surfaceSunken,
              borderRadius: BorderRadius.circular(MlTokens.rMd),
            ),
            child: Text(
              note,
              softWrap: true,
              style: TextStyle(color: semantic.textStrong, height: 1.4),
            ),
          ),
        ],
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerLeft,
          child: MlButton.danger(
            label: 'Deactivate my account',
            icon: Icons.person_off_outlined,
            onPressed: _openConfirm,
          ),
        ),
      ],
    );
  }
}

/// The two-part shape of a dialog error: a fixed, code-derived sentence the
/// user can act on, and — beneath it, smaller and optional — the server's own
/// message. Branch on [AccountDeactivationException.code], never on
/// [AccountDeactivationException.message] (CLAUDE.md, and the `getErrorCode`
/// precedent in `company-user-admin/index.ts`): [primary] is looked up by
/// code alone, so a wording edit on the server can never silently change
/// which branch the user sees. [detail] is shown only as extra context —
/// in production, the real MLD01 message names the actual company, which
/// [primary] deliberately does not, so nothing is lost by keeping it visible.
class _DialogError {
  const _DialogError(this.primary, [this.detail]);
  final String primary;
  final String? detail;
}

class _ConfirmDeactivationDialog extends StatefulWidget {
  const _ConfirmDeactivationDialog({required this.service});
  final AccountDeactivationService service;

  @override
  State<_ConfirmDeactivationDialog> createState() =>
      _ConfirmDeactivationDialogState();
}

class _ConfirmDeactivationDialogState
    extends State<_ConfirmDeactivationDialog> {
  final _confirmController = TextEditingController();
  final _passwordController = TextEditingController();
  final _reasonController = TextEditingController();
  static final _log = LoggerFactory.getLogger('DeactivateAccountCard');

  bool _busy = false;
  _DialogError? _error;

  @override
  void initState() {
    super.initState();
    // Rebuilds so the confirm button's enabled state (see [_canSubmit])
    // tracks both fields live. This is what makes the password gate HARD:
    // the button itself carries `onPressed: null` until both are satisfied,
    // rather than a check inside `_submit` that a disabled tap would never
    // reach anyway (that was the bug — typing DEACTIVATE alone submitted,
    // because the only place a blank password mattered was a branch guarded
    // by `if (password.isNotEmpty)` a few lines further in, never a gate on
    // the button itself).
    _confirmController.addListener(_onFieldsChanged);
    _passwordController.addListener(_onFieldsChanged);
  }

  void _onFieldsChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _confirmController.removeListener(_onFieldsChanged);
    _passwordController.removeListener(_onFieldsChanged);
    _confirmController.dispose();
    _passwordController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  /// Hard gate: the typed confirmation must match exactly AND a password
  /// must be present, or the confirm button is not just ignored but
  /// genuinely disabled (`onPressed: null`). Re-auth is unconditional
  /// whenever this is true — never skipped because the field "happened" to
  /// be non-empty, because it can no longer be empty here at all.
  bool get _canSubmit =>
      !_busy &&
      _confirmController.text.trim() == 'DEACTIVATE' &&
      _passwordController.text.isNotEmpty;

  static String _primaryCopyFor(AccountDeactivationException e) {
    switch (e.code) {
      case 'MLD01':
        return 'You own a company on MineLink. A platform admin must have '
            'it suspended, or its ownership transferred, before your '
            'account can be deactivated.';
      case 'MLD02':
        return 'You already have a deactivation request in progress.';
      case 'AUTH_FAILED':
        return 'That password was not correct.';
      case 'AUTH_NO_EMAIL':
        return 'Could not verify your password on this session. Sign out '
            'and back in, then try again.';
      default:
        return 'That request could not be completed. Contact support if '
            'this keeps happening.';
    }
  }

  Future<void> _submit() async {
    // Belt-and-braces — the button is already disabled unless this holds.
    if (!_canSubmit) return;

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      // Re-auth is unconditional and must succeed before the RPC is ever
      // called. This is NOT a second access-control check on the account —
      // the RPC is `security definer`, keyed off the caller's own
      // `auth.uid()` from the session already established at sign-in, and
      // that is the real authorization boundary. What this guards against is
      // an unattended, already-signed-in SESSION carrying a perfectly valid
      // `auth.uid()` — a shared depot tablet, a driver's phone left on a
      // seat. See `AccountDeactivationService.reauthenticate`'s doc. The
      // widget never touches Supabase directly for this (CLAUDE.md §6) —
      // the service does, and the typed DEACTIVATE text is preserved either
      // way, so a mistyped password does not force re-typing it.
      await widget.service.reauthenticate(_passwordController.text);

      final reason = _reasonController.text.trim();
      await widget.service.request(reason.isEmpty ? null : reason);
      if (mounted) Navigator.of(context).pop(true);
    } on AccountDeactivationException catch (e) {
      _log.w('Deactivation confirm refused: ${e.code} ${e.message}');
      if (!mounted) return;
      final detail = e.message.trim();
      setState(() {
        _busy = false;
        _error = _DialogError(
            _primaryCopyFor(e), detail.isEmpty ? null : detail);
      });
    } catch (e) {
      _log.w('Deactivation confirm failed: $e');
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = _DialogError(friendlyError(e));
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final semantic = MlSemantic.of(context);
    final brightness = Theme.of(context).brightness;
    return AlertDialog(
      title: const Text('Confirm account deactivation'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _point(semantic,
                  'You will be signed out and will not be able to sign in again.'),
              const SizedBox(height: 10),
              _point(semantic,
                  'This is reversible: an administrator can restore your account at any time.'),
              const SizedBox(height: 10),
              _point(semantic,
                  'Records of any loads you were part of are retained either way — nothing about them changes.'),
              const SizedBox(height: 10),
              _point(semantic,
                  'A platform admin can review this for up to 30 days. If nobody acts, it completes automatically once that window passes.'),
              const SizedBox(height: 18),
              TextField(
                controller: _confirmController,
                enabled: !_busy,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'Type DEACTIVATE to confirm',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _passwordController,
                enabled: !_busy,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Your password',
                  helperText: 'Confirms this is really you.',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _reasonController,
                enabled: !_busy,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Reason (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!.primary,
                  softWrap: true,
                  style: TextStyle(
                    color: MlTone.error.colors(brightness).fg,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (_error!.detail != null &&
                    _error!.detail != _error!.primary) ...[
                  const SizedBox(height: 4),
                  Text(
                    _error!.detail!,
                    softWrap: true,
                    style: TextStyle(fontSize: 12, color: semantic.textFaint),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(false),
          child: const Text('Never mind'),
        ),
        MlButton.danger(
          label: 'Deactivate my account',
          compact: true,
          onPressed: _canSubmit ? _submit : null,
        ),
      ],
    );
  }

  Widget _point(MlSemantic semantic, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Icon(Icons.circle, size: 6, color: semantic.textMuted),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            text,
            softWrap: true,
            style: TextStyle(color: semantic.textMuted, height: 1.4),
          ),
        ),
      ],
    );
  }
}
