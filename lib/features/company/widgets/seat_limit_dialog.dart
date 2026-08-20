import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter_application_1/core/utils/friendly_error.dart';
import 'package:flutter_application_1/features/company/models/seat_limit.dart';
import 'package:flutter_application_1/features/super_admin/providers/super_admin_providers.dart';

/// Shown when the seat gate blocks adding or activating a person.
///
/// Client ruling 2026-08-15: **block at the limit, and give them a way to ask
/// for more.** A refusal on its own would leave a company admin at a dead end
/// with no route forward — the seat limit is set by the platform team, not by
/// them, so "you cannot do this" without "here is how to fix it" is unusable.
///
/// It submits the same `seat_expansion` request as the Platform requests panel
/// on the company profile (`create_company_token_request`), so both entry
/// points land in the one super-admin inbox rather than creating a second,
/// parallel way to ask.
///
/// Note that RPC could never once succeed before today — it raised `55000` on
/// every call for any caller (migration `20260815110000`). Offering this
/// button before that was fixed would have produced a second dead end.
Future<void> showSeatLimitDialog(
  BuildContext context,
  WidgetRef ref, {
  required String companyId,
  required String serverMessage,
}) async {
  final extra = TextEditingController(text: '1');
  final reason = TextEditingController();
  var submitting = false;
  String? error;

  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => StatefulBuilder(
      builder: (ctx, setLocal) {
        Future<void> submit() async {
          final n = int.tryParse(extra.text.trim()) ?? 0;
          if (n <= 0) {
            setLocal(() => error = 'Enter how many extra seats you need.');
            return;
          }
          setLocal(() {
            submitting = true;
            error = null;
          });
          try {
            final repo = ref.read(superAdminRepositoryProvider);
            // The current limit is the snapshot the request is judged against,
            // so it is read now rather than assumed.
            final snap = await repo.getCompanySeatSnapshotForRequests(companyId);
            final limit = snap['seat_limit'] as int? ?? 0;
            await repo.createCompanyTokenRequest(
              organizationId: companyId,
              requestKind: 'seat_expansion',
              reason: reason.text.trim(),
              requestedExtraSeats: n,
              requestedNewTotal: limit + n,
            );
            if (ctx.mounted) Navigator.of(ctx).pop();
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Requested $n extra seat${n == 1 ? '' : 's'}. '
                    'The platform team will review it.',
                  ),
                ),
              );
            }
          } catch (e) {
            setLocal(() {
              submitting = false;
              error = friendlyError(e);
            });
          }
        }

        return AlertDialog(
      // Cold-phone audit 2026-08-18: this dialog holds input fields and did
      // not scroll, so at a large text size on a narrow phone its content
      // overflowed the viewport and the fields below the fold could not be
      // reached. Measured at 133px of clipped content on the token
      // generator, which is the same shape. `scrollable` only engages when
      // the content exceeds the space, so it is inert on a desktop.
      scrollable: true,
          title: const Text('No seats available'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // The server's own sentence — it already names the company and
                // the limit, so it is shown rather than paraphrased.
                Text(
                  serverMessage,
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: extra,
                  enabled: !submitting,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'Extra seats needed',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: reason,
                  enabled: !submitting,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Reason (optional)',
                    hintText: 'e.g. two new weighbridge controllers starting',
                    border: OutlineInputBorder(),
                  ),
                ),
                if (error != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    error!,
                    style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(ctx).colorScheme.error,
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: submitting ? null : () => Navigator.of(ctx).pop(),
              child: const Text('Not now'),
            ),
            FilledButton(
              onPressed: submitting ? null : submit,
              child: submitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Request seats'),
            ),
          ],
        );
      },
    ),
  );

  extra.dispose();
  reason.dispose();
}

/// If [error] is the seat gate refusing, open the request dialog and return
/// true. Otherwise return false so the caller shows its normal message.
Future<bool> handleSeatLimitError(
  BuildContext context,
  WidgetRef ref,
  Object error, {
  required String? companyId,
}) async {
  if (!isSeatLimitError(error) || companyId == null) return false;
  if (!context.mounted) return false;
  await showSeatLimitDialog(
    context,
    ref,
    companyId: companyId,
    serverMessage: seatLimitMessage(error) ?? 'This company has no free seats.',
  );
  return true;
}
