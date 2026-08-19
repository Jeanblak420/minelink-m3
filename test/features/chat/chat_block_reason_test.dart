// S8-1 / S8-2, the Dart half.
//
// The chat hierarchy (P10-07) is enforced in the database — a driver may only
// START a conversation with an admin — and `get_chat_contacts` now returns
// `block_reason = 'hierarchy'` for the colleagues they cannot reach.
//
// That reason has to say something true. There are now three ways a contact
// can be unreachable, and they are not interchangeable:
//
//   org_revoked   — somebody else's decision, nothing the user can do
//   token_expired — their own billing state, which they can fix
//   hierarchy     — the way the company is organised; message an admin instead
//
// Before this, anything that was not `token_expired` fell through to
// "The connection between these organisations has been revoked." Told to a
// driver who simply is not allowed to DM another driver, that is not merely
// unhelpful — it is false, and it points at a problem that does not exist.
//
// The enforcement itself is proven against production, not here: a driver's
// contact list returns admin and MineLink unblocked, and driver / management /
// owner blocked with reason `hierarchy`; the driver can start a room with an
// admin and not with the owner; and replies in an existing room stay open.

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/features/chat/models/messaging_models.dart';

ChatContact _contact({String? reason}) => ChatContact(
      userId: 'u1',
      displayName: 'Thandi',
      isBlocked: reason != null,
      blockReason: reason,
    );

void main() {
  group('a blocked contact says which of the three reasons applies', () {
    test('hierarchy points the user at the route that does work', () {
      final c = _contact(reason: 'hierarchy');
      expect(c.blockedLabel, 'Message an admin');
      expect(c.blockedTooltip, contains('admin'));
      // The specific wrongness this test exists to prevent.
      expect(
        c.blockedTooltip.toLowerCase(),
        isNot(contains('revoked')),
        reason: 'a driver who simply cannot DM another driver must not be '
            'told the organisations have been disconnected',
      );
      expect(c.blockedTooltip.toLowerCase(), isNot(contains('expired')));
    });

    test('an expired token still reads as recoverable by renewing', () {
      final c = _contact(reason: 'token_expired');
      expect(c.blockedLabel, 'Renew to message');
      expect(c.blockedTooltip, contains('MineLink'));
      expect(c.isBlockedByExpiry, isTrue);
    });

    test('a revoked org connection keeps the plain wording', () {
      final c = _contact(reason: 'org_revoked');
      expect(c.blockedLabel, 'Blocked');
      expect(c.blockedTooltip, contains('revoked'));
    });

    test('an unblocked contact has no reason at all', () {
      final c = _contact();
      expect(c.isBlocked, isFalse);
      expect(c.blockReason, isNull);
      expect(c.isBlockedByExpiry, isFalse);
    });

    test('an unknown reason degrades to the neutral wording, not a wrong one',
        () {
      // A reason added server-side before the client knows about it must not
      // claim something specific and false.
      final c = _contact(reason: 'some_future_reason');
      expect(c.blockedLabel, 'Blocked');
      expect(c.blockedTooltip.toLowerCase(), isNot(contains('revoked')));
      expect(c.blockedTooltip.toLowerCase(), isNot(contains('renew')));
    });

    test('block_reason survives the RPC mapping', () {
      final c = ChatContact.fromRpc(const {
        'user_id': 'u1',
        'display_name': 'Thandi',
        'is_blocked': true,
        'block_reason': 'hierarchy',
      });
      expect(c.blockReason, 'hierarchy');
      expect(c.blockedLabel, 'Message an admin');
    });
  });
}
