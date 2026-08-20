import 'package:flutter/material.dart';
import 'package:flutter_application_1/core/design/tokens/ml_tokens.dart';
import 'package:flutter_application_1/core/design/components/ml_icon_well.dart';

/// Honest, instructive empty state: faint icon in a well, short title,
/// one calm explanatory sentence, optional action.
///
/// **It must survive being placed in a box smaller than it wants.** This widget
/// is used inside cards as well as on full pages, and a card on a 360px phone
/// can be as short as 144px — less than the icon well, title and two lines of
/// message need. Before 2026-08-14 that produced a real
/// `RenderFlex overflowed by 3.0 pixels` on the transporter dashboard at
/// **default text scale**, i.e. for every transporter admin opening the app on
/// a phone, not merely at an accessibility setting.
///
/// The fix is a scroll view rather than a `FittedBox`: shrinking an already
/// small explanatory sentence to fit produces text nobody can read, which
/// defeats the point of an *instructive* empty state. When there is room the
/// scroll view changes nothing — the content is centred exactly as before.
class MlEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;

  const MlEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final semantic = MlSemantic.of(context);
    final text = Theme.of(context).textTheme;
    return SingleChildScrollView(
      // `shrinkWrap`-like behaviour: centres when there is room, scrolls when
      // there is not, instead of overflowing.
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                MlIconWell(icon: icon, tone: MlTone.neutral, size: 64),
                const SizedBox(height: 16),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: text.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: semantic.textStrong,
                  ),
                ),
                if (message != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    message!,
                    textAlign: TextAlign.center,
                    // Looser than the 16/12 the slot specifies: this is the one
                    // paragraph of prose on an otherwise empty screen, and it is
                    // read rather than scanned.
                    style: text.bodySmall?.copyWith(
                      color: semantic.textMuted,
                      height: 1.5,
                    ),
                  ),
                ],
                if (action != null) ...[const SizedBox(height: 18), action!],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
