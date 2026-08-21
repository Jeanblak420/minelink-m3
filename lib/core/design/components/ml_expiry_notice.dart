import 'package:flutter/material.dart';

import 'package:flutter_application_1/core/design/tokens/m3/ml_typography.dart';
import 'package:flutter_application_1/core/design/tokens/ml_surface_tokens.dart';
import 'package:flutter_application_1/core/design/tokens/ml_tokens.dart';
import 'package:flutter_application_1/features/portal/models/company_access.dart';

/// The notice a restricted company sees, in the reference's notice-bar shape:
/// left accent rule · icon well · title + explanation · right-aligned actions
/// (`docs/design-reference.md` §4).
///
/// Exists because token expiry was enforced in the database before anything on
/// screen could explain it. From `20260815094000` an expired company's writes
/// were refused by row-level security — correctly — and the user got a failed
/// request with no idea that a lapsed token was the cause or that renewing was
/// the fix. A silent block is a support call.
///
/// **It leads with what is still possible.** A notice that only lists refusals
/// reads as a wall and produces exactly the call it should have prevented, so
/// the copy names reading, messaging MineLink, requesting a renewal and logging
/// a ticket before it mentions what needs a token.
///
/// Tone is [MlTone.warn], not [MlTone.error] — deliberately. An expired token
/// is a **billing state the customer can fix themselves**, not a fault. The
/// reference makes the same distinction for downward deltas (§4: "red is
/// reserved for a fault; a downward trend is a warning"), and painting a
/// renewable licence red would misrepresent a routine commercial event as a
/// system failure. Suspension is the one case that does read as an error,
/// because the customer cannot lift it alone.
class MlExpiryNotice extends StatelessWidget {
  const MlExpiryNotice({
    super.key,
    required this.access,
    this.onRequestRenewal,
    this.onMessageMineLink,
    this.onExplain,
    this.compact = false,
  });

  final CompanyAccess access;

  /// Opens the company's token-requests panel (`CompanyTokenRequestsPanel`,
  /// on `/profile`), which already supports renewal, a new token and seat
  /// expansion. Null hides the action rather than showing a dead button.
  final VoidCallback? onRequestRenewal;

  /// Opens `/messages`. Messaging MineLink and logging a ticket both live
  /// there, and both stay available while a token is expired.
  final VoidCallback? onMessageMineLink;

  /// Opens `/expired-access`, which spells out exactly what still works and
  /// what does not. The notice is one sentence; some people want the list, and
  /// without this that screen is unreachable — it had no navigator at all
  /// before 2026-08-15.
  final VoidCallback? onExplain;

  /// Denser variant for narrow layouts: same words, tighter padding, actions
  /// wrap under the text.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (!access.isRestricted) return const SizedBox.shrink();

    final semantic = MlSemantic.of(context);
    final brightness = Theme.of(context).brightness;
    // Suspension is the only one the customer cannot resolve themselves.
    final tone = access.isSuspended ? MlTone.error : MlTone.warn;
    final tones = tone.colors(brightness);
    final pad = compact ? 12.0 : 16.0;

    final actions = <Widget>[
      if (onRequestRenewal != null)
        _NoticeAction(
          label: access.isPendingActivation
              ? 'Request activation'
              : 'Request renewal',
          icon: Icons.autorenew_rounded,
          tone: tones.fg,
          filled: true,
          onPressed: onRequestRenewal!,
          tooltip: access.isPendingActivation
              ? 'Ask MineLink to activate this company\'s token.'
              : 'Ask MineLink for a new token. You can do this while expired.',
        ),
      if (onMessageMineLink != null)
        _NoticeAction(
          label: 'Message MineLink',
          icon: Icons.forum_outlined,
          tone: tones.fg,
          filled: false,
          onPressed: onMessageMineLink!,
          tooltip:
              'Chat to MineLink or log a support ticket — both stay '
              'available while your token is expired.',
        ),
      if (onExplain != null)
        _NoticeAction(
          label: 'What this means',
          icon: Icons.help_outline_rounded,
          tone: tones.fg,
          filled: false,
          onPressed: onExplain!,
          tooltip: 'See exactly what you can still do and what needs an '
              'active token.',
        ),
    ];

    return Semantics(
      liveRegion: true,
      container: true,
      label: '${access.headline}. ${access.explanation}',
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: tones.bg,
          borderRadius: BorderRadius.circular(MlTokens.rMd),
          border: Border.all(color: tones.fg.withValues(alpha: 0.28)),
        ),
        // The reference's left accent rule, painted as a Positioned overlay
        // rather than a stretched Row child. `CrossAxisAlignment.stretch`
        // inside an unbounded parent — and this notice sits in the portal
        // shell's Column and inside MlPageBody's scroll view — throws
        // "BoxConstraints forces an infinite height" (CLAUDE.md §10.4). It was
        // written the stretched way first and the component capture would not
        // render at all. A Stack sizes to its non-positioned child, so the bar
        // matches the content's height without demanding one.
        child: Stack(
          children: [
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: 3,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: tones.fg,
                  borderRadius: const BorderRadius.horizontal(
                    left: Radius.circular(MlTokens.rMd),
                  ),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(pad + 3, pad, pad, pad),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Title row and actions share ONE Wrap rather than a Row
                  // containing one: an unflexed Wrap inside a Row is measured
                  // against unbounded width and pushes the row over
                  // (CLAUDE.md §10.4).
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 12,
                    runSpacing: 10,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            access.isSuspended
                                ? Icons.gpp_maybe_outlined
                                : Icons.hourglass_disabled_rounded,
                            size: 18,
                            color: tones.fg,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            access.headline,
                            style: TextStyle(
                              fontFamily: MlGlass.display,
                              fontFamilyFallback: MlGlass.displayFallback,
                              fontSize: compact ? 15 : 17,
                              fontWeight: FontWeight.w400,
                              letterSpacing: -0.2,
                              color: semantic.textStrong,
                            ),
                          ),
                        ],
                      ),
                      if (actions.isNotEmpty)
                        Wrap(spacing: 8, runSpacing: 8, children: actions),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    access.explanation,
                    style: context.mlText.bodyMedium.copyWith(
                      color: semantic.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A compact outlined/filled pill used only inside the notice.
class _NoticeAction extends StatelessWidget {
  const _NoticeAction({
    required this.label,
    required this.icon,
    required this.tone,
    required this.filled,
    required this.onPressed,
    required this.tooltip,
  });

  final String label;
  final IconData icon;
  final Color tone;
  final bool filled;
  final VoidCallback onPressed;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    final semantic = MlSemantic.of(context);
    // Ink is chosen for contrast against the fill, not by theme: the tone is a
    // fixed amber/red, so a themed ink would be unreadable in one mode.
    final ink = filled ? MlTokens.navy950 : tone;
    return Tooltip(
      message: tooltip,
      waitDuration: const Duration(milliseconds: 400),
      child: Material(
        color: filled ? tone : Colors.transparent,
        borderRadius: BorderRadius.circular(MlTokens.rPill),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(MlTokens.rPill),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(MlTokens.rPill),
              border: filled
                  ? null
                  : Border.all(color: tone.withValues(alpha: 0.45)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 14, color: ink),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: context.mlText.labelMedium.copyWith(
                    color: filled ? ink : semantic.textStrong,
                    fontWeight: FontWeight.w700,
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
