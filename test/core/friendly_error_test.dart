import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/core/utils/friendly_error.dart';

/// The exact string a buyer saw on their dashboard before this existed.
const _realLeak =
    'PostgrestException(message: , code: 400, details: , hint: null)';

void main() {
  group('friendlyError', () {
    test('never returns raw exception text to the user', () {
      // The regression this file exists for. Written against the real string
      // that reached a customer, not a synthetic one.
      final out = friendlyError(Exception(_realLeak), subject: 'the dashboard');
      expect(out, isNot(contains('PostgrestException')));
      expect(out, isNot(contains('code:')));
      expect(out, isNot(contains('hint:')));
      expect(out, contains('the dashboard'));
    });

    test('a permission failure does not confirm the record exists', () {
      // Saying "you cannot see trip 91f2" tells the reader trip 91f2 exists.
      final out = friendlyError(
        Exception('PostgrestException(message: permission denied for table '
            'trips, code: 42501, details: , hint: null)'),
      );
      expect(out, 'You do not have access to this.');
      expect(out, isNot(contains('trips')));
      expect(out, isNot(contains('42501')));
    });

    test('an expired session says what to do about it', () {
      final out = friendlyError(
          Exception('AuthException(message: JWT expired, code: 401)'));
      expect(out, contains('Sign in again'));
    });

    test('no connection reads as a signal problem, not a server fault', () {
      final out = friendlyError(const SocketException('failed host lookup'));
      expect(out, contains('signal'));
      expect(out, isNot(contains('SocketException')));
    });

    test('a timeout is distinguished from a refusal', () {
      final out = friendlyError(TimeoutException('x'));
      expect(out, contains('took too long'));
    });

    test('an unknown error still produces a sentence, never an empty string',
        () {
      for (final e in <Object?>[null, '', Object(), 42, StateError('boom')]) {
        final out = friendlyError(e);
        expect(out.trim(), isNotEmpty);
        expect(out, endsWith('happening.'));
      }
    });

    // 57014 is `query_canceled` — a statement timeout. It has its own sentence
    // because the ADVICE differs: a refusal will be refused again, while a
    // timed-out query frequently lands on the second ask. Measured against the
    // live place index 2026-08-17: "Durban" failed at 3.22s, answered at 3.03s.
    test('a statement timeout says to try again, not that it was refused', () {
      for (final e in [
        Exception('PostgrestException(message: canceling statement due to '
            'statement timeout, code: 57014, details: , hint: null)'),
        Exception('PlaceIndexTimedOut: Westway Rd, Fourways'),
      ]) {
        final out = friendlyError(e);
        expect(out, contains('too long'), reason: out);
        expect(out, contains('Try again'), reason: out);
        expect(out, isNot(contains('refused')),
            reason: 'a timeout is not a refusal, and the two need different '
                'instructions: "$out"');
        expect(out, isNot(contains('tell support')),
            reason: 'the user has a working next step; do not send them to '
                'support instead: "$out"');
      }
    });

    test('reads as a sentence with AND without a subject', () {
      // The regression: the first version glued the subject clause on after a
      // full stop, so with no subject it shipped
      //     "The server refused the request. could not be loaded."
      // to the mine production screen. Grammar is not cosmetic here — this is
      // the helper whose whole job is that users never see broken text.
      for (final subject in <String?>[null, 'the report', 'the fleet']) {
        for (final e in <Object?>[
          Exception('PostgrestException(message: , code: 400)'),
          const SocketException('no route'),
          TimeoutException('slow'),
          Object(),
        ]) {
          final out = friendlyError(e, subject: subject);
          expect(out, isNot(contains('. could not')),
              reason: 'dangling clause after a full stop: "$out"');
          expect(out, isNot(contains('  ')), reason: 'double space: "$out"');
          expect(out, isNot(contains(' .')), reason: 'space before stop: "$out"');
          // Every sentence starts with a capital and ends with a stop.
          expect(out[0], out[0].toUpperCase(), reason: 'no capital: "$out"');
          expect(out.trim(), endsWith('.'), reason: 'no full stop: "$out"');
          if (subject != null && !out.startsWith('You do not have access')) {
            expect(out, contains(subject),
                reason: 'subject dropped: "$out"');
          }
        }
      }
    });

  });
}
