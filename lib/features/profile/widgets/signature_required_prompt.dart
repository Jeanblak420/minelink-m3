import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:flutter_application_1/core/design/components/ml_components.dart';
import 'package:flutter_application_1/features/profile/services/signature_service.dart';

/// The outcome of [ensureSignatureBeforeSigning].
enum SignaturePromptOutcome {
  /// A signature is on file — nothing was shown, carry on.
  alreadySigned,

  /// No signature, and the user chose to go and draw one. The caller must
  /// abandon what it was doing; navigation to `/profile` has already happened.
  goToProfile,

  /// No signature, and the user chose to proceed knowing the document will be
  /// unsigned.
  proceedUnsigned,

  /// The user dismissed the prompt. Treat as cancel.
  cancelled,
}

/// S8-10 — stop a waybill going out with a blank signature line and no warning.
///
/// ## The state this is written for
///
/// **3 of 116 profiles have a signature.** Everyone else who records a load or
/// files a POD produces a document whose DISPATCHED BY or RECEIVED BY block is
/// an empty rule, and today nothing says so — not at the moment of signing, not
/// afterwards. The waybill is the piece of paper that travels with the ore; an
/// unsigned one is the kind of defect that is discovered by somebody else,
/// later, holding it.
///
/// ## Why it is not a hard block
///
/// "Blocking" here means the prompt interrupts and must be answered — not that
/// the operation becomes impossible. A load controller stands at a weighbridge
/// with a loaded truck on it; refusing to record the load until they have
/// drawn a signature moves the problem from a document to a queue of trucks,
/// which is worse. So the prompt states the consequence in the words that
/// matter ("the waybill will print with an empty signature line"), offers the
/// fix as the primary action, and lets them proceed as the secondary one.
///
/// **If the client wants a hard block, this is the one place to change** —
/// drop [SignaturePromptOutcome.proceedUnsigned] and the second button. It was
/// written as one decision in one function for exactly that reason.
///
/// ## Why it does not offer to draw the signature inline
///
/// A signature is drawn once and reused everywhere; the canvas, the upload and
/// the profile write all live on `/profile`. Duplicating that here would be a
/// second place to save the same thing — and the first one to drift.
Future<SignaturePromptOutcome> ensureSignatureBeforeSigning(
  BuildContext context,
  WidgetRef ref, {
  /// What the user is about to do, in their words: 'record this load',
  /// 'record this delivery'. Used in the sentence, so it must fit after
  /// "before you".
  required String action,

  /// Which block of the waybill would be left blank.
  required String waybillBlock,
}) async {
  // Read rather than watch: this is a one-shot question at the moment of
  // action, not a subscription. `await` the provider so a cold cache asks the
  // server instead of assuming the worst and nagging somebody who has one.
  final url = await ref.read(mySignatureUrlProvider.future);
  if (url != null && url.trim().isNotEmpty) {
    return SignaturePromptOutcome.alreadySigned;
  }
  if (!context.mounted) return SignaturePromptOutcome.cancelled;

  final outcome = await showDialog<SignaturePromptOutcome>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      final semantic = MlSemantic.of(dialogContext);
      return AlertDialog(
        icon: Icon(Icons.draw_rounded,
            color: MlTone.warn.colors(Theme.of(dialogContext).brightness).fg),
        title: const Text('You have no signature on file'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'If you $action now, the waybill will print with an empty '
              '$waybillBlock signature line.',
              style: TextStyle(color: semantic.textBody, height: 1.45),
            ),
            const SizedBox(height: 12),
            Text(
              'Drawing it takes a moment and it is reused automatically on '
              'every waybill, proof of delivery and approval after this one.',
              style: TextStyle(
                  color: semantic.textMuted,
                  fontSize: MlTokens.fsBodySm,
                  height: 1.45),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext)
                .pop(SignaturePromptOutcome.proceedUnsigned),
            child: const Text('Continue unsigned'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(dialogContext)
                .pop(SignaturePromptOutcome.goToProfile),
            icon: const Icon(Icons.draw_rounded, size: 18),
            label: const Text('Add signature'),
          ),
        ],
      );
    },
  );

  if (outcome == SignaturePromptOutcome.goToProfile && context.mounted) {
    context.go('/profile');
  }
  return outcome ?? SignaturePromptOutcome.cancelled;
}
