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
import 'package:flutter_application_1/features/portal/models/trip_status.dart';

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

    test('a truck LOADING is at the mine (amber), not inert', () {
      // Between "Arrived at mine" (amber) and "Loaded" (green) on the
      // weighbridge; it fell through to neutral and the truck being worked
      // on read as the most inert row. Phase 3 mine pass, 2026-08-23.
      expect(MlStatusBadge.toneForStatus('Loading'), MlTone.atMine);
      expect(MlStatusBadge.toneForStatus('loading'), MlTone.atMine);
      // The neighbours keep their tones.
      for (final status in TripStatus.values) {
        final tone = MlStatusBadge.toneForStatus(status.label);
        if (status == TripStatus.scheduled || status == TripStatus.cancelled) {
          continue; // not yet moving / never will: inert is honest
        }
        expect(tone, isNot(MlTone.neutral),
            reason: '"${status.label}" falls to neutral');
      }
      expect(MlStatusBadge.toneForStatus(TripStatus.loaded.label), MlTone.done);
      expect(MlStatusBadge.toneForStatus(TripStatus.arrivedAtMine.label),
          MlTone.atMine);
      expect(MlStatusBadge.toneForStatus(TripStatus.enRouteToLoad.label),
          MlTone.transit);
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

  group('the four states a fleet register draws', () {
    // Transporter pass, 2026-08-23. Both of these were MEASURED off
    // `toneForStatus`, not guessed, and both are substring traps.

    test('ON ROUTE is a truck in transit, not an unknown', () {
      // `on route` is not `en route`, and nothing else in the map contains it.
      expect(MlStatusBadge.toneForStatus('On route'), MlTone.transit);
      expect(MlStatusBadge.toneForStatus('Driver on route'), MlTone.transit);
      expect(
        MlStatusBadge.toneForStatus('On route'),
        MlStatusBadge.toneForStatus('En route to offload'),
        reason: 'the same truck, on two screens, in two colours',
      );
    });

    test('INACTIVE is not ACTIVE, however the string is matched', () {
      // "inactive".contains("active") is true, so this returned MlTone.done:
      // a truck taken out of the fleet drawn in the same green as one
      // standing ready to load.
      expect(
        MlStatusBadge.toneForStatus('Inactive'),
        MlTone.neutral,
        reason: 'a decommissioned truck is inert, not good and not a fault',
      );
      expect(MlStatusBadge.toneForStatus('Not in service'), MlTone.neutral);
      expect(MlStatusBadge.toneForStatus('Out of service'), MlTone.neutral);
    });

    // The GREEN case: `ACTIVE` on its own is still a real status and still
    // green. Fixing the substring by deleting the branch would have taken it.
    test('ACTIVE on its own is still green', () {
      expect(MlStatusBadge.toneForStatus('Active'), MlTone.done);
      expect(MlStatusBadge.toneForStatus('ACTIVE'), MlTone.done);
      expect(MlStatusBadge.toneForStatus('Available'), MlTone.done);
    });

    test('the four fleet states are four different tones', () {
      final tones = {
        for (final s in ['On route', 'Available', 'In maintenance', 'Inactive'])
          s: MlStatusBadge.toneForStatus(s),
      };
      expect(
        tones.values.toSet().length,
        4,
        reason: 'a register that draws two states alike cannot be read: $tones',
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
