import 'package:flutter/material.dart';

import 'package:flutter_application_1/core/utils/friendly_error.dart';
import 'package:flutter_application_1/core/design/components/ml_buttons.dart';
import 'package:flutter_application_1/core/design/components/ml_empty_state.dart';

/// The panel a portal screen shows when its data could not be loaded.
///
/// Exists because the hand-written version of this was wrong 23 times out of
/// 27. Every portal screen wraps its whole body — page title included — in
/// `.when(data:)`, so a failed request does not degrade the screen, it
/// *replaces* it. What the user was left with, measured on 2026-08-14 across
/// `lib/features/portal/`:
///
/// * 23 of 27 failure panels had **no way to try again**, and
/// * 16 were titled exactly **"Could not load this"**, which names nothing.
///
/// Found by looking at the S5-20 before-images rather than by reading code:
/// three of the mine portal's eight captures were a centred grey panel on an
/// otherwise empty canvas, with no title to say which screen had failed.
///
/// This matters more here than in most products. `friendly_error.dart` says it
/// itself — *"Network first: it is by far the most common real cause on a haul
/// road"* — so the dominant failure in MineLink is a **transient** one, the
/// kind a retry fixes. A security guard at a mine gate loses signal for a
/// moment, opens Security check-in, and gets a dead end: nothing naming what
/// failed and no button to press. The truck does not get checked in until
/// somebody works out that navigating away and back reloads it.
///
/// Taking [subject] and [onRetry] as **required** is the point of the class.
/// The previous shape — `MlEmptyState(title: …, message: …)` with an optional
/// `action:` — made the correct version and the dead end equally easy to
/// write, and the dead end won 23 times. This one cannot be constructed
/// without a way out of it.
///
/// Pinned by `test/widgets/portal_error_recovery_test.dart`.
class MlLoadFailure extends StatelessWidget {
  const MlLoadFailure({
    super.key,
    required this.subject,
    required this.error,
    required this.onRetry,
    this.icon = Icons.error_outline_rounded,
  });

  /// Names what failed, as a noun phrase **carrying its own article** — e.g.
  /// `'the recon table'` renders "Could not load the recon table". Written
  /// this way so the title reads as a sentence rather than a label, and so the
  /// user can tell support which screen it was.
  final String subject;

  /// The thrown object. Rendered through [friendlyError], never raw — a
  /// `PostgrestException` reaching a customer is the defect that started this.
  /// The caller's own logger still records the original.
  final Object? error;

  /// Re-runs the failed load. In practice `ref.invalidate(theProvider)` — the
  /// same provider the screen watches, so the retry re-fetches rather than
  /// merely rebuilding the panel with the cached error.
  final VoidCallback onRetry;

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return MlEmptyState(
      icon: icon,
      title: 'Could not load $subject',
      // No `subject:` on friendlyError here: it would build "…, so the recon
      // table could not be loaded", repeating the title one line below it.
      // The title names the thing; the message says what went wrong.
      message: friendlyError(error),
      action: MlButton.tonal(
        label: 'Try again',
        icon: Icons.refresh_rounded,
        onPressed: onRetry,
      ),
    );
  }
}
