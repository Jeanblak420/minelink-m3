// An employee still waiting for a role signed in (after another user, on the
// S25-matched emulator, 2026-10-25) and landed on "That page is not here —
// /portal/mine" instead of the "Waiting for Role Assignment" screen.
//
// The router's portal-gate read wrote "waiting for a role" first and the
// company's org type after a second `await`. Sign-in clears that cache while a
// redirect can be mid-read, and the clear landed in between: it reset the flag
// to false, then the late org-type write put "mine" back. The /home redirect
// saw a mine employee with a role and sent them to /portal/mine; the no-role
// gate bounced that, and the bounce ended on the not-found page. The log read:
//
//   Blocked /portal/transporter/notifications: employee has no role assigned
//   Landing mineSupplier session on /portal/mine
//   Blocked /portal/mine: employee has no role assigned
//
// Read as source: the fault is an ordering of writes around awaits inside a
// static router method that needs a live Supabase client to run.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _body(String src, String signature) {
  final start = src.indexOf(signature);
  expect(start, isNonNegative, reason: '$signature has moved');
  var depth = 0;
  for (var i = src.indexOf('{', start); i < src.length; i++) {
    if (src[i] == '{') depth++;
    if (src[i] == '}' && --depth == 0) return src.substring(start, i + 1);
  }
  fail('unbalanced $signature');
}

String _code(String s) => s.replaceAll(RegExp(r'//[^\n]*'), '');

void main() {
  final src = File('lib/core/routing/app_router.dart').readAsStringSync();

  test('every gate field is written after the last read, behind the check',
      () {
    final body = _code(_body(
        src, 'static Future<void> _refreshPortalGateFields(String userId)'));
    final lastAwait = body.lastIndexOf('await ');
    final check = body.indexOf('if (generation != _gateGeneration) return;');
    expect(check, greaterThan(lastAwait),
        reason: 'the stale-read check must follow the last await');
    for (final field in const [
      '_cachedOrgType =',
      '_cachedEmployeeRole =',
      '_cachedIsEmployeeWithoutRole =',
    ]) {
      final writes = RegExp(RegExp.escape(field)).allMatches(body);
      expect(writes, isNotEmpty, reason: '$field is never written');
      for (final w in writes) {
        expect(w.start, greaterThan(check),
            reason: '$field is written before the read finished — a clear '
                'during the await can be overwritten by half an answer');
      }
    }
  });

  test('a clear invalidates reads already in flight', () {
    final clear = _code(_body(src, 'static void clearProfileGateCache()'));
    expect(clear, contains('_gateGeneration++'));
    final profile = _code(_body(
        src, 'static Future<void> _refreshProfileGateFields(String userId)'));
    expect(
        profile.indexOf('if (generation != _gateGeneration) return;'),
        greaterThan(profile.lastIndexOf('await ')));
  });
}
