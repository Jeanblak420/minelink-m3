import 'package:flutter/material.dart';

import 'package:flutter_application_1/core/design/tokens/m3/ml_typography.dart';
import 'package:flutter_application_1/core/design/tokens/ml_tokens.dart';
import 'package:flutter_application_1/features/portal/models/company_access.dart';

/// Wraps a control that a restricted company may not use, so it explains
/// itself on hover and on long-press instead of failing silently.
///
/// The problem it solves: from `20260815094000` an expired company's writes are
/// refused by row-level security. Correct — but a button that looks live,
/// accepts the click and then throws is the worst of the three possible
/// behaviours. This makes the state visible **before** the click, and says what
/// to do about it.
///
/// Three things happen together, and they have to:
///
/// 1. **Dimmed**, so it reads as unavailable at a glance.
/// 2. **Inert**, via `IgnorePointer` — the child never fires. Note the
///    `Tooltip` sits OUTSIDE the `IgnorePointer`, otherwise it would swallow
///    the hover it needs to show the message, which is the obvious way to
///    write this and is wrong.
/// 3. **Explained**, by a tooltip carrying [CompanyAccess.blockedActionTooltip]
///    — "Needs a renewed token — your token has expired." Not "Disabled".
///
/// Long-press is included because the driver and security roles run this on a
/// phone, where there is no hover and a tooltip-only explanation would be
/// invisible to exactly the people most likely to be stopped by it.
///
/// This is presentation, not security. The boundary is RLS; if this widget were
/// removed entirely the database would still refuse the write.
class MlLockedAction extends StatelessWidget {
  const MlLockedAction({
    super.key,
    required this.access,
    required this.child,
    this.reason,
    this.enabled = true,
  });

  final CompanyAccess access;
  final Widget child;

  /// Overrides [CompanyAccess.blockedActionTooltip] where a screen can say
  /// something more specific than the generic sentence.
  final String? reason;

  /// Set false to lock the control for a reason unrelated to company status;
  /// the wrapper then explains the company-status reason only if that also
  /// applies.
  final bool enabled;

  bool get _locked => access.isRestricted || !enabled;

  @override
  Widget build(BuildContext context) {
    if (!_locked) return child;

    final message = reason ??
        (access.isRestricted
            ? access.blockedActionTooltip
            : 'Not available right now.');

    return Tooltip(
      message: message,
      waitDuration: const Duration(milliseconds: 300),
      triggerMode: TooltipTriggerMode.longPress,
      child: MouseRegion(
        cursor: SystemMouseCursors.forbidden,
        child: Opacity(
          opacity: 0.42,
          // IgnorePointer INSIDE the Tooltip, never around it — the tooltip
          // needs the pointer events the child must not receive.
          child: IgnorePointer(child: child),
        ),
      ),
    );
  }
}

/// The small inline chip for places where a tooltip is not discoverable
/// enough — a section that is entirely unavailable, rather than one control.
///
/// Says what is needed, not merely that something is off: "Renew your token to
/// record loads" beats "Unavailable" by exactly the amount that stops a call.
class MlLockedBadge extends StatelessWidget {
  const MlLockedBadge({super.key, required this.access, this.action});

  final CompanyAccess access;

  /// The thing the user was trying to do, lower-cased and verb-first —
  /// `record loads`, `dispatch a truck`, `edit this waybill`.
  final String? action;

  @override
  Widget build(BuildContext context) {
    if (!access.isRestricted) return const SizedBox.shrink();

    final brightness = Theme.of(context).brightness;
    final tones = (access.isSuspended ? MlTone.error : MlTone.warn)
        .colors(brightness);
    final verb = access.isPendingActivation ? 'Activate' : 'Renew';
    final label = action == null
        ? '$verb your token to make changes'
        : '$verb your token to $action';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: tones.bg,
        borderRadius: BorderRadius.circular(MlTokens.rPill),
        border: Border.all(color: tones.fg.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.lock_outline_rounded, size: 13, color: tones.fg),
          const SizedBox(width: 6),
          // NOT `Flexible`. This Row is `mainAxisSize: min`, so in an
          // unbounded parent — a `Row` laying out its own children, which is
          // exactly how a badge gets used — a flex child is handed infinite
          // width and throws "BoxConstraints forces an infinite width".
          // Caught by adding the badge to the component capture, which failed
          // to render at all. A ConstrainedBox gives `ellipsis` the bounded
          // width it needs without asking the parent for a flex share.
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 320),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.mlText.labelMedium.copyWith(color: tones.fg),
            ),
          ),
        ],
      ),
    );
  }
}
