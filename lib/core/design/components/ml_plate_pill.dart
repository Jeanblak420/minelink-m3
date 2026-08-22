import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:flutter_application_1/core/design/tokens/m3/ml_shape.dart';
import 'package:flutter_application_1/core/design/tokens/ml_tokens.dart';

/// A vehicle plate, waybill number, ticket or serial — the machine identifiers.
///
/// Always monospace and always tabular. `docs/design-reference.md` §3 puts
/// `CK 84 RT GP` and `TRP-000123` in mono precisely so they read as machine
/// identifiers rather than as quantities, which is also why this is a separate
/// component from the display numeral ([MlType.figure]) rather than a size of
/// it.
///
/// ## Press and hold to copy
///
/// Asked for directly (jean, 2026-08-22): *"include more mobile tap and hold
/// controlls and features"*.
///
/// This component is where that earns the most, because of **what** it holds.
/// Every string in a plate pill is one a person has to move somewhere else —
/// read over a radio to a controller, typed into a weighbridge sheet, quoted
/// in a WhatsApp message to a transporter, pasted into a search box. On a
/// phone the alternative is reading `TRP-8CB20569AE` off the glass one
/// character at a time, and a waybill number transcribed wrong is a load that
/// cannot be reconciled.
///
/// So: hold it, and it is on the clipboard. A short tap is left alone, because
/// these pills sit inside rows that are themselves tappable — a plate inside a
/// trip row still opens the trip.
///
/// `Tooltip` names it, **not** a `Semantics` wrapper: an inner
/// `Semantics(button: true)` inside an ink well merges over the node that
/// carries the tap ACTION, so the control announces itself perfectly and does
/// nothing at all. That cost a session's debugging on the chat composer's send
/// button on 2026-08-22 and is recorded in `chat_widget.dart`.
///
/// ## What changed in the M3 rebuild
///
/// **The style is [MlType.code] rather than a fifth hand-written copy of it.**
/// This file spelled out family, size, weight, tracking and
/// `FontFeature.tabularFigures()` inline — and it is one of **138 sites in
/// `lib/` that name `MlTokens.fontMono` by hand**. The helper exists so that
/// list can shrink; a component in the design system reaching past it set the
/// worst possible example.
///
/// **The radius is a scale step** — [MlShape.radiusSmall] (8), which is the
/// value it already used, now named as a step rather than as `rSm`.
class MlPlatePill extends StatelessWidget {
  final String text;
  final double fontSize;

  /// Whether press-and-hold copies [text].
  ///
  /// True everywhere by default. Pass false only where the surrounding widget
  /// already owns the long-press for something else, so the two do not race —
  /// there is nothing worse than a gesture that does one of two things
  /// depending on exactly which pixel the thumb landed on.
  final bool copyable;

  const MlPlatePill(
    this.text, {
    super.key,
    this.fontSize = 13,
    this.copyable = true,
  });

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: text));
    // The little confirming tick a phone gives you. Silent on platforms that
    // have no haptics, which is every desktop and the web.
    await HapticFeedback.selectionClick();
    if (!context.mounted) return;
    // The value names itself. 27 of this component's 29 call sites are truck
    // registrations and the rest are waybill references, so a per-site label
    // would have been 27 mechanical edits with one chance each to be wrong —
    // and `Copied — TRP-8CB20569AE` is already unambiguous.
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Copied — $text')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final semantic = MlSemantic.of(context);
    final pill = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: semantic.surfaceSunken,
        borderRadius: MlShape.radiusSmall,
        border: Border.all(color: semantic.borderSubtle),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: MlType.code(
          color: semantic.textStrong,
          size: fontSize,
          weight: FontWeight.w700,
          letterSpacing: 0.8,
        ).copyWith(height: 1.4),
      ),
    );

    if (!copyable || text.trim().isEmpty) return pill;

    return Tooltip(
      message: 'Hold to copy',
      // A `GestureDetector`, NOT an `InkWell`.
      //
      // An `InkWell` given only `onLongPress` still becomes `enabled`, and an
      // enabled `InkResponse` registers a TAP recogniser as well — it needs
      // one to draw its splash. That recogniser wins the gesture arena against
      // the ancestor's, so wrapping a plate in an ink well SWALLOWED the tap
      // of the row it sits in: the pill inside a trip row stopped opening the
      // trip. Caught by `tap_and_hold_test.dart`'s "a SHORT tap still reaches
      // the row underneath" on the run it was written, and it is the same
      // family as the `Semantics`-inside-`InkWell` trap recorded in
      // `chat_widget.dart` — a wrapper quietly taking a gesture it was not
      // asked for.
      //
      // A `GestureDetector` declaring only `onLongPress` adds only a long-press
      // recogniser, so taps pass straight through. The feedback for the copy is
      // the haptic tick and the snackbar, which is what a phone user reads
      // anyway; a ripple would be the smaller half of it.
      child: GestureDetector(
        onLongPress: () => _copy(context),
        child: pill,
      ),
    );
  }
}
