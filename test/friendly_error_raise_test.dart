// A message the server wrote FOR the user must reach the user.
//
// Found 2026-08-17 at the weighbridge. Recording a load on a seal-required
// route without seals, the server sent back exactly this:
//
//     400 {"code":"P0001",
//          "message":"This route requires seals: capture each seal number and
//                     photo before saving"}
//
// and the operator was shown:
//
//     "Could not record load. The server refused the request. Try again, and
//      tell support if it keeps happening."
//
// Both halves are wrong. It does not say what is missing, and "try again" is
// the one thing that cannot work — the next attempt fails identically until the
// seals are captured.
//
// `P0001` is Postgres's `raise_exception`: the code you get from a bare
// `raise exception '…'`. Every one of those strings in this schema was written
// by hand for a person to read — "Select the supplying mine first", "Margin
// cannot exceed the agreed price", "This load has already been recorded for
// S6W001GP". Flattening them all to one sentence discards the entire
// server-side vocabulary.
//
// What must NOT change: a permission failure still says nothing about whether
// the row exists, and a raw `PostgrestException(message: , code: 400 …)` still
// never reaches a customer. Those are why this helper exists.
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/core/utils/friendly_error.dart';

/// The exact `toString()` shape supabase_flutter produces.
String pg(String message, String code) =>
    'PostgrestException(message: $message, code: $code, details: null, hint: null)';

void main() {
  group('friendlyError surfaces a hand-written server message', () {
    test('the seal refusal reaches the load controller verbatim', () {
      expect(
        friendlyError(pg(
            'This route requires seals: capture each seal number and photo '
            'before saving',
            'P0001')),
        'This route requires seals: capture each seal number and photo '
        'before saving',
      );
    });

    test('the double-record refusal reaches them too', () {
      expect(
        friendlyError(pg(
            'This load has already been recorded for S6W001GP. A load is '
            'captured once; raise a dispute if the tonnage is wrong.',
            'P0001')),
        startsWith('This load has already been recorded for S6W001GP.'),
      );
    });

    test('a subject does not mangle the sentence', () {
      // The server already wrote a complete sentence; do not glue a clause on.
      expect(
        friendlyError(pg('Select the supplying mine first', 'P0001'),
            subject: 'the dispatch'),
        'Select the supplying mine first',
      );
    });
  });

  group('what must not regress', () {
    test('a permission failure still gives nothing away', () {
      expect(
        friendlyError(pg('permission denied for table trips', '42501')),
        'You do not have access to this.',
      );
    });

    test('an empty PostgrestException never reaches the user', () {
      expect(
        friendlyError('PostgrestException(message: , code: 400, details: , hint: null)'),
        contains('The server refused the request'),
      );
    });

    test('the expired-token marker still wins over the raise text', () {
      expect(
        friendlyError(pg(
            'TOKEN_EXPIRED: your MineLink token is not active', 'P0001')),
        contains('Your MineLink token is not active'),
      );
    });
  });
}
