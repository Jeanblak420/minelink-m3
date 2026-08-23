import 'package:flutter/material.dart';

import 'package:flutter_application_1/core/design/tokens/m3/ml_shape.dart';
import 'package:flutter_application_1/core/design/tokens/ml_tokens.dart';

/// The lifecycle status pill — the single most repeated motif in MineLink, and
/// **43 of the census's hand-rolled decorations** are an attempt at it.
///
/// Fully rounded, a tonal fg/bg pair from [MlTone], uppercase tracked label,
/// optional leading dot.
///
/// ## What changed in the M3 rebuild
///
/// **The label is no longer shouted at screen readers.** The pill renders
/// `label.toUpperCase()` because that is the design, but several screen-reader
/// engines treat an all-caps token as an initialism and spell it out — so
/// `LOADED` was read "L, O, A, D, E, D" and `EN ROUTE TO OFFLOAD` became
/// nineteen letters. The visual text is still uppercase; the semantics node
/// now carries the original string, so it is *rendered* upper and *announced*
/// as written. This is why the `Text` is wrapped rather than simply styled.
///
/// **Type comes from the theme.** It was a hand-built `TextStyle` naming
/// `fontSans`, size 12 and w700. That is `labelMedium` plus a weight and a
/// little more tracking, which is what uppercase needs to stop the letters
/// crowding — expressed as a `copyWith` on the theme slot so a change to the
/// type scale reaches it.
///
/// **The radius is a scale step.** `MlTokens.rPill` and [MlShape.pill] are
/// both 999; the value is unchanged, the name now says which scale it is on.
class MlStatusBadge extends StatelessWidget {
  final String label;
  final MlTone tone;
  final bool dot;

  const MlStatusBadge({
    super.key,
    required this.label,
    required this.tone,
    this.dot = false,
  });

  /// Maps the app's trip/truck status strings to design tones:
  /// blue = in transit/OTW, amber = at mine, green = loaded/available/
  /// confirmed, orange = maintenance/departed, red = declined/error.
  static MlTone toneForStatus(String status) {
    final s = status.trim().toLowerCase();
    if (s.contains('otw') ||
        s.contains('transit') ||
        s.contains('on trip') ||
        s.contains('en route') ||
        s.contains('in_progress') ||
        s.contains('in progress') ||
        s.contains('pending')) {
      return MlTone.transit;
    }
    // An OPEN request is the reference's "pending, needs attention" (warn).
    // `open` and `in_progress` fell through to neutral, so the token-requests
    // queue — whose whole point is which rows are waiting on the admin —
    // drew every pill in the same grey. Seen 2026-08-23 in the Phase 3 pass.
    if (s == 'open' || s.startsWith('open ') || s.endsWith(' open')) {
      return MlTone.warn;
    }
    if (s.contains('at mine') ||
        s.contains('arrived') ||
        s.contains('waiting')) {
      return MlTone.atMine;
    }
    if (s.contains('loaded') ||
        s.contains('available') ||
        s.contains('approved') ||
        s.contains('confirmed') ||
        s.contains('completed') ||
        s.contains('active') ||
        s.contains('done')) {
      return MlTone.done;
    }
    if (s.contains('maintenance') ||
        s.contains('departed') ||
        s.contains('left') ||
        s.contains('disputed')) {
      return MlTone.warn;
    }
    // 'dismissed' was in this list until the dismissal feature was removed
    // (client ruling, 2026-08-11). No status string in the app can carry it any
    // more, so matching on it only invited it back.
    if (s.contains('declined') ||
        s.contains('error') ||
        s.contains('rejected') ||
        s.contains('expired') ||
        s.contains('failed')) {
      return MlTone.error;
    }
    return MlTone.neutral;
  }

  /// A wire status as a person reads it: `in_progress` → `in progress`.
  ///
  /// Most callers hand this factory a label that is already prose — `Arrived at
  /// mine`, `LOADED` — and for those this is a no-op, because there is nothing
  /// to replace. The ones that hand it a raw column value are why it exists:
  /// the token-requests screen rendered a pill reading **`IN_PROGRESS`**,
  /// underscore and all, which is the database's vocabulary on an admin's
  /// screen. Photographed 2026-08-20.
  ///
  /// It is done HERE rather than at that call site because the factory is the
  /// one that says "give me a status" — a caller passing a status is doing the
  /// right thing, and every future one will pass a raw value too. The badge
  /// renders uppercase, so the visible change is the separator; the spoken
  /// label stops saying "in underscore progress".
  static String humaniseStatus(String status) =>
      status.replaceAll(RegExp(r'[_-]+'), ' ').trim();

  /// Convenience: badge with the tone derived from the status string.
  factory MlStatusBadge.forStatus(String status, {Key? key, bool dot = false}) =>
      MlStatusBadge(
        key: key,
        label: humaniseStatus(status),
        // Tone from the RAW string: `toneForStatus` matches on substrings like
        // `in_progress` and `sent_back`, and humanising first would change what
        // it is matching against.
        tone: toneForStatus(status),
        dot: dot,
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = tone.colors(theme.brightness);

    return Semantics(
      // Announced as written; rendered uppercase below.
      label: label,
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: colors.bg,
          borderRadius: MlShape.pill,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (dot) ...[
              Container(
                width: 6,
                height: 6,
                decoration:
                    BoxDecoration(color: colors.fg, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
            ],
            Flexible(
              child: Text(
                label.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                  color: colors.fg,
                  height: 1.3,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
