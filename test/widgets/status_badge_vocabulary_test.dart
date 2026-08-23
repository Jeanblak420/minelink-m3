// A status pill must not show an admin the database's vocabulary.
//
// The token-requests screen rendered **`IN_PROGRESS`** — underscore and all —
// and beside it "Seat expansion · mineSupplier". Both were raw column values
// printed straight onto the screen, and both were found the same way: by
// photographing a screen that had only ever been swept.
//
// Neither is an overflow, a truncation or a colour. They are correctly laid out
// words that belong to Postgres rather than to a person.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/core/design/components/ml_components.dart';
import 'package:flutter_application_1/core/theme/app_theme.dart';
import 'package:flutter_application_1/features/super_admin/data/models/token_request.dart';

import '../test_helpers/real_fonts.dart';

/// The smallest TokenRequest that compiles, varying only the org type.
TokenRequest _request(String orgType) => TokenRequest(
      id: 't',
      organizationId: 'o',
      organizationName: 'Fixture Org',
      organizationType: orgType,
      requestKind: 'seat_expansion',
      currentSeatLimit: 5,
      currentSeatsUsed: 5,
      requestedExtraSeats: 1,
      requestedNewTotal: 6,
      reason: '',
      requestedByUserId: 'u',
      requestedByEmail: 'a@b.c',
      status: 'open',
      createdAt: DateTime.utc(2026, 8, 15),
      updatedAt: DateTime.utc(2026, 8, 15),
    );

void main() {
  setUpAll(loadRealFonts);

  group('MlStatusBadge.forStatus', () {
    test('humanises a wire status', () {
      expect(MlStatusBadge.humaniseStatus('in_progress'), 'in progress');
      expect(MlStatusBadge.humaniseStatus('sent_back'), 'sent back');
      expect(MlStatusBadge.humaniseStatus('en-route'), 'en route');
    });

    test('leaves prose alone', () {
      // Most callers already pass a label. This must not touch them.
      for (final label in const [
        'Arrived at mine',
        'LOADED',
        'On Route to Load',
        'Completed',
      ]) {
        expect(MlStatusBadge.humaniseStatus(label), label);
      }
    });

    testWidgets('no separator survives to the screen', (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
          body: Center(child: MlStatusBadge.forStatus('in_progress')),
        ),
      ));
      await tester.pump();

      expect(find.textContaining('_'), findsNothing,
          reason: 'a raw wire status reached the pill. `forStatus` is the '
              'factory that says "give me a status", so a caller passing a '
              'column value is doing the right thing and the humanising '
              'belongs here.');
      // The badge renders uppercase; the SEMANTICS label keeps the prose,
      // which is why the humanising is on the label rather than on the paint.
      expect(find.text('IN PROGRESS'), findsOneWidget);
    });

    test('an open request is pending (warn) and one in hand is moving (transit)',
        () {
      // Both fell through to neutral, so the token-requests queue drew every
      // pill the same grey. docs/design-reference.md §2: warn = "pending,
      // needs attention"; the blue transit tone is what is in motion.
      expect(MlStatusBadge.toneForStatus('open'), MlTone.warn);
      expect(MlStatusBadge.toneForStatus('in_progress'), MlTone.transit);
      // And the specific wrongness: not neutral.
      expect(MlStatusBadge.toneForStatus('open'), isNot(MlTone.neutral));
      expect(MlStatusBadge.toneForStatus('in_progress'),
          isNot(MlTone.neutral));
      // Statuses that were already toned keep their tone.
      expect(MlStatusBadge.toneForStatus('expired'), MlTone.error);
      expect(MlStatusBadge.toneForStatus('approved'), MlTone.done);
    });

    test('the tone still comes from the RAW string', () {
      // `toneForStatus` matches substrings including `in_progress` and
      // `sent_back`. Humanising before the match would change what it sees.
      expect(
        MlStatusBadge.forStatus('sent_back').tone,
        MlStatusBadge.toneForStatus('sent_back'),
      );
    });
  });

  group('TokenRequest', () {
    test('names the org type the way a person does', () {
      final r = _request('mineSupplier');
      expect(r.organizationTypeLabel, 'Mine/Supplier',
          reason: 'the screen printed `mineSupplier` at an admin, in the list '
              'row and again in the detail sheet, while every other surface in '
              'the product goes through a label.');
    });

    test('an unknown org type is shown, not hidden', () {
      final r = _request('smelter');
      expect(r.organizationTypeLabel, 'smelter',
          reason: 'falling back to a dash would hide an org type the app does '
              'not know about, which is something to see rather than to '
              'swallow.');
    });
  });
}
