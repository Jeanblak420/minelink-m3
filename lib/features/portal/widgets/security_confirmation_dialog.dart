import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter_application_1/core/design/tokens/m3/ml_typography.dart';
import 'package:flutter_application_1/core/design/tokens/ml_tokens.dart';
import 'package:flutter_application_1/core/utils/logger.dart';
import 'package:flutter_application_1/core/utils/safe_ref.dart';
import 'package:flutter_application_1/features/portal/models/trip_waypoint.dart';
import 'package:flutter_application_1/features/portal/providers/security_confirmation_provider.dart';

final _log = LoggerFactory.getLogger('SecurityConfirmDialog');

/// Two-party security confirmation dialog for driver arrival/exit at the
/// mine gate (phase-5 T6, adapted from the ML donor). Status progression:
///
/// 1. "Confirm your arrival/exit…" — driver hasn't confirmed yet
/// 2. "Waiting for security…" — driver confirmed, security pending
/// 3. "Confirmed" — both parties confirmed
///
/// Confirmations are ADDITIVE bookkeeping over `security_confirmations`;
/// failures are logged and surfaced but never rethrown, so a confirmation
/// problem can never break the caller (e.g. active navigation).
class SecurityConfirmationDialog extends ConsumerStatefulWidget {
  final String tripId;
  final SecurityConfirmationType type;
  final String gateName;
  final bool isDriver;

  const SecurityConfirmationDialog({
    super.key,
    required this.tripId,
    required this.type,
    required this.gateName,
    this.isDriver = true,
  });

  /// Show the dialog; resolves true when both parties have confirmed.
  static Future<bool?> show({
    required BuildContext context,
    required String tripId,
    required SecurityConfirmationType type,
    required String gateName,
    bool isDriver = true,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => SecurityConfirmationDialog(
        tripId: tripId,
        type: type,
        gateName: gateName,
        isDriver: isDriver,
      ),
    );
  }

  @override
  ConsumerState<SecurityConfirmationDialog> createState() =>
      _SecurityConfirmationDialogState();
}

class _SecurityConfirmationDialogState
    extends ConsumerState<SecurityConfirmationDialog> {
  bool _isLoading = false;
  bool _driverConfirmed = false;
  bool _securityConfirmed = false;

  @override
  void initState() {
    super.initState();
    _loadConfirmation();
  }

  void _invalidate() {
    // Both callers reach here after an await, so the dialog may already be
    // closed; `ref.invalidate` throws once it is.
    ref.invalidateIfMounted(tripSecurityConfirmationsProvider(widget.tripId));
  }

  Future<void> _loadConfirmation() async {
    try {
      final conf = await ref
          .read(securityConfirmationServiceProvider)
          .get(widget.tripId, widget.type);
      if (!mounted) return;
      setState(() {
        _driverConfirmed = conf?.driverConfirmed ?? false;
        _securityConfirmed = conf?.securityConfirmed ?? false;
      });
      // Already fully confirmed — auto-close after a brief moment.
      if (_driverConfirmed && _securityConfirmed) {
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) Navigator.of(context).pop(true);
        });
      }
    } catch (e) {
      _log.w('Failed to load confirmation: $e');
    }
  }

  Future<void> _handleDriverConfirm() async {
    setState(() => _isLoading = true);
    try {
      // Upsert — creates the row when missing, idempotent when it exists.
      final conf = await ref
          .read(securityConfirmationServiceProvider)
          .driverConfirm(widget.tripId, widget.type);
      if (!mounted) return;
      setState(() {
        _driverConfirmed = true;
        _securityConfirmed = conf.securityConfirmed;
        _isLoading = false;
      });
      _invalidate();
    } catch (e) {
      _log.w('Driver confirm failed (navigation unaffected): $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Could not send the confirmation — try again.')));
      }
    }
  }

  Future<void> _handleSecurityConfirm() async {
    setState(() => _isLoading = true);
    try {
      final conf = await ref
          .read(securityConfirmationServiceProvider)
          .securityConfirm(widget.tripId, widget.type);
      if (!mounted) return;
      setState(() {
        _driverConfirmed = conf.driverConfirmed;
        _securityConfirmed = true;
        _isLoading = false;
      });
      _invalidate();
      // Fully confirmed — close.
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted) Navigator.of(context).pop(true);
      });
    } catch (e) {
      _log.w('Security confirm failed: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Could not send the confirmation — try again.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final semantic = MlSemantic.of(context);
    final brightness = Theme.of(context).brightness;
    final done = MlTone.done.colors(brightness);
    final atMine = MlTone.atMine.colors(brightness);
    final transit = MlTone.transit.colors(brightness);
    final typeLabel =
        widget.type == SecurityConfirmationType.arrival ? 'Arrival' : 'Exit';
    final isFullyConfirmed = _driverConfirmed && _securityConfirmed;

    final statusTone = isFullyConfirmed
        ? done
        : _driverConfirmed
            ? atMine
            : transit;

    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(MlTokens.r2xl),
      ),
      backgroundColor: semantic.surfaceCard,
      titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
      title: Column(
        children: [
          // Status icon
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: statusTone.bg,
            ),
            alignment: Alignment.center,
            child: Icon(
              isFullyConfirmed
                  ? Icons.check_circle
                  : _driverConfirmed
                      ? Icons.shield_outlined
                      : Icons.local_shipping,
              size: 36,
              color: statusTone.fg,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            isFullyConfirmed
                ? '$typeLabel Confirmed'
                : '$typeLabel — ${widget.gateName}',
            textAlign: TextAlign.center,
            style: context.mlText.editorialSmall.copyWith(
              color: semantic.textStrong,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            isFullyConfirmed
                ? 'Both parties confirmed. Proceeding...'
                : widget.isDriver && !_driverConfirmed
                    ? 'Confirm your ${typeLabel.toLowerCase()} at ${widget.gateName}.'
                    : widget.isDriver && !_securityConfirmed
                        ? 'Waiting for security to confirm your ${typeLabel.toLowerCase()}...'
                        : !widget.isDriver && !_driverConfirmed
                            ? 'Waiting for the driver to confirm...'
                            : 'Confirm this ${typeLabel.toLowerCase()} for the driver.',
            textAlign: TextAlign.center,
            style: context.mlText.bodyMedium.copyWith(color: semantic.textMuted),
          ),
          const SizedBox(height: 16),

          // Two-party indicator
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _PartyIndicator(
                icon: Icons.local_shipping,
                label: 'Driver',
                isConfirmed: _driverConfirmed,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  width: 40,
                  height: 2,
                  color: isFullyConfirmed ? done.fg : semantic.borderCard,
                ),
              ),
              _PartyIndicator(
                icon: Icons.shield,
                label: 'Security',
                isConfirmed: _securityConfirmed,
              ),
            ],
          ),
        ],
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        if (isFullyConfirmed)
          const SizedBox.shrink()
        else if (widget.isDriver && !_driverConfirmed)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isLoading ? null : _handleDriverConfirm,
              icon: _isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: MlTokens.inkOnFill,
                      ),
                    )
                  : const Icon(Icons.check),
              label: Text(
                widget.type == SecurityConfirmationType.arrival
                    ? 'I have arrived at ${widget.gateName}'
                    : 'I am leaving through ${widget.gateName}',
                style: const TextStyle(
                  fontFamily: MlTokens.fontSans,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: MlTokens.accent,
                foregroundColor: MlTokens.inkOnFill,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(MlTokens.rMd),
                ),
              ),
            ),
          )
        else if (!widget.isDriver && !_securityConfirmed && _driverConfirmed)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isLoading ? null : _handleSecurityConfirm,
              icon: _isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: MlTokens.inkOnFill,
                      ),
                    )
                  : const Icon(Icons.shield_outlined),
              label: Text(
                'Confirm $typeLabel',
                style: const TextStyle(
                  fontFamily: MlTokens.fontSans,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: MlTokens.green600,
                foregroundColor: MlTokens.inkOnFill,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(MlTokens.rMd),
                ),
              ),
            ),
          )
        else
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: CircularProgressIndicator(),
          ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () => Navigator.of(context).pop(isFullyConfirmed),
          child: Text(
            isFullyConfirmed ? 'Done' : 'Close',
            style: const TextStyle(fontFamily: MlTokens.fontSans),
          ),
        ),
      ],
    );
  }
}

/// A small avatar/icon indicator for one party (driver / security) with the
/// green "confirmed" state driven by `MlTone.done`.
class _PartyIndicator extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isConfirmed;

  const _PartyIndicator({
    required this.icon,
    required this.label,
    required this.isConfirmed,
  });

  @override
  Widget build(BuildContext context) {
    final semantic = MlSemantic.of(context);
    final done = MlTone.done.colors(Theme.of(context).brightness);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isConfirmed ? done.bg : semantic.surfaceSunken,
            border: Border.all(
              color: isConfirmed ? done.fg : semantic.borderCard,
              width: 2,
            ),
          ),
          alignment: Alignment.center,
          child: Icon(
            icon,
            size: 22,
            color: isConfirmed ? done.fg : semantic.textMuted,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: context.mlText.labelSmall.copyWith(
            color: isConfirmed ? done.fg : semantic.textMuted,
            fontWeight: isConfirmed ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ],
    );
  }
}
