/// Turns a thrown object into a sentence a haulage dispatcher can act on.
///
/// The portal was showing raw exception text to customers. A buyer opening
/// their dashboard saw, verbatim:
///
///     PostgrestException(message: , code: 400, details: , hint: null)
///
/// That is not an error message. It tells the user nothing they can do, names
/// a technology they have no relationship with, and — when the failure is a
/// permission one — quietly discloses that the row exists at all.
///
/// 40 call sites across 34 files interpolated the exception straight into
/// the message. This is what they use
/// instead. The raw object is still logged by the caller's own logger, so
/// nothing is lost for debugging; it just stops being the user's problem.
///
/// Deliberately NOT a translation layer or an error-code taxonomy — it maps
/// the handful of shapes this app actually throws onto plain English, and
/// falls through to one honest sentence for everything else. A mapping that
/// tries to be exhaustive goes stale and starts lying.
library;

import 'dart:async';
import 'dart:io';

/// A short, human sentence describing [error], safe to show a customer.
///
/// [subject] names what failed, so the sentence reads naturally in place —
/// e.g. `friendlyError(e, subject: 'the dashboard')` → "Could not load the
/// dashboard because the server refused the request…". Omit it for a generic
/// sentence.
String friendlyError(Object? error, {String? subject}) {
  // The subject clause is built as a CLAUSE, not glued on after a full stop.
  //
  // The first version of this did `'…the request.$what could not be loaded.'`
  // with `what` empty when no subject was given, and shipped
  //
  //     "The server refused the request. could not be loaded."
  //
  // to the mine production screen — a broken sentence, from the very helper
  // written to stop broken text reaching users. Caught by looking at the
  // rendered screen, not by reading this file.
  final because = subject == null ? '' : ', so $subject could not be loaded';

  // Network first: it is by far the most common real cause on a haul road,
  // and it is the one the user can actually do something about.
  if (error is SocketException || error is HttpException) {
    return 'No connection to the server$because. '
        'Check your signal and try again.';
  }
  if (error is TimeoutException) {
    return 'The server took too long to respond$because. '
        'Try again in a moment.';
  }

  final text = error?.toString() ?? '';

  // The expired-token guard, checked BEFORE the generic codes below.
  //
  // `guard_company_active()` raises with errcode `check_violation` (23514),
  // which the mapping further down turns into "that change was refused because
  // it would leave the records inconsistent" — true of a real constraint and
  // completely wrong here. The user has not made an inconsistent change; their
  // licence has lapsed, and the fix is to renew, which that sentence would
  // never tell them.
  //
  // Matched on the `TOKEN_EXPIRED:` marker the guard raises rather than on the
  // errcode, because 23514 legitimately means other things.
  if (text.contains('TOKEN_EXPIRED')) {
    return 'Your MineLink token is not active, so this change was not saved. '
        'You can still view records, message MineLink, request a renewal and '
        'log a support ticket.';
  }

  // Postgres gave up on the query — `57014`, `query_canceled`, which is what
  // `statement_timeout` raises. Checked BEFORE the Postgrest block below,
  // which would otherwise flatten it into "the server refused the request".
  //
  // The distinction earns its place because the advice differs: a refusal will
  // be refused again, whereas a timed-out query frequently lands on a second
  // ask — the first attempt warms the pages the second one needs. Measured
  // against the live place index on 2026-08-17, "Durban" failed at 3.22s and
  // answered at 3.03s moments later. "Try again" is the correct instruction
  // here and the wrong one there.
  if (text.contains('PlaceIndexTimedOut') ||
      _hasCode(text, '57014') ||
      text.contains('canceling statement due to')) {
    return 'The lookup took too long to come back$because. Try again — it '
        'usually answers on the second attempt.';
  }

  // Supabase/Postgrest, matched on text rather than by importing the type, so
  // this file stays dependency-free and usable from anywhere in the tree.
  if (text.contains('PostgrestException') ||
      text.contains('AuthException') ||
      text.contains('StorageException')) {
    if (_hasCode(text, '42501') ||
        text.contains('row-level security') ||
        text.contains('permission denied')) {
      // Deliberately does not confirm the record exists.
      return 'You do not have access to this.';
    }
    if (_hasCode(text, 'PGRST116')) {
      return 'That record no longer exists.';
    }
    if (_hasCode(text, '401') || _hasCode(text, '403')) {
      return 'Your session has expired. Sign in again to continue.';
    }
    if (_hasCode(text, '404')) {
      return 'That record no longer exists.';
    }
    if (_hasCode(text, '23505')) {
      return 'That already exists.';
    }
    if (_hasCode(text, '23514') || _hasCode(text, '23503')) {
      return 'That change was refused because it would leave the records '
          'inconsistent.';
    }
    // A message the server wrote FOR the user reaches the user.
    //
    // `P0001` is Postgres's `raise_exception` — what a bare `raise exception
    // '…'` produces. Every one of those strings in this schema was authored by
    // hand for a person to read: "This route requires seals: capture each seal
    // number and photo before saving", "Select the supplying mine first",
    // "Margin cannot exceed the agreed price", "This load has already been
    // recorded for S6W001GP". They are the server's half of the conversation.
    //
    // They were all being flattened into the sentence below. Measured
    // 2026-08-17: a load controller blocked for missing seals was told "The
    // server refused the request. Try again" — which does not name what is
    // missing, and advises the one action that cannot work, since the next
    // attempt fails identically until the seals are captured.
    //
    // This sits AFTER the permission and constraint branches on purpose: 42501
    // must keep saying nothing about whether the row exists, and the
    // TOKEN_EXPIRED marker is handled earlier still. It is safe by
    // construction — a P0001 message is one somebody wrote, not one Postgres
    // generated about its own internals.
    if (_hasCode(text, 'P0001')) {
      final raised = _raisedMessage(text);
      if (raised != null && raised.isNotEmpty) return raised;
    }
    return 'The server refused the request$because. '
        'Try again, and tell support if it keeps happening.';
  }

  return 'Something went wrong$because. '
      'Try again, and tell support if it keeps happening.';
}

/// True when [text] carries `code: <code>` — the shape Supabase's exceptions
/// print. Matching the bare number would fire on any digits in the message.
bool _hasCode(String text, String code) =>
    text.contains('code: $code') || text.contains("code: '$code'");

/// The `message:` field out of a `PostgrestException(...)` string.
///
/// Read out of `toString()` rather than off the typed exception so this file
/// stays dependency-free and usable from anywhere in the tree, which is the
/// same reason the code checks above match on text.
///
/// Anchored on the LAST `, code:` so a message that itself contains that
/// phrase cannot truncate the sentence early.
String? _raisedMessage(String text) {
  const open = 'message: ';
  final start = text.indexOf(open);
  if (start < 0) return null;
  final end = text.lastIndexOf(', code:');
  if (end <= start + open.length) return null;
  return text.substring(start + open.length, end).trim();
}
