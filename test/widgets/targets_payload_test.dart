// The seam between `get_targets_state` and the screen. Everything here is a
// literal map, so these run without Supabase and still fail if the RPC's shape
// drifts from what the screen expects.
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/features/super_admin/data/models/target_scope.dart';
import 'package:flutter_application_1/features/super_admin/providers/targets_provider.dart';
import 'package:flutter_application_1/features/super_admin/widgets/insights_v2/minelink_targets_core.dart';

Map<String, dynamic> _payload({
  Object? cycleStatus = 'draft',
  Object? startedOn = '2026-08-01',
  String cycleId = 'cycle-1',
  String cycleLabel = 'Aug 2026 → Jul 2027',
  List<Object?>? months,
  List<Object?>? pastCycles,
}) =>
    <String, dynamic>{
      'scope': {'scope': 'platform', 'org_type': null, 'company_id': null},
      'months': months ??
          [
            {
              'year': 2026,
              'month': 8,
              'period': '2026-08',
              'days_in_month': 31,
              'daily': [0, 129, 0, '46.5'],
              'target': '450',
              'trips': 12,
              'waybills_done': 9,
              'waybills_open': 3,
            },
            {
              'year': 2026,
              'month': 9,
              'period': '2026-09',
              'days_in_month': 30,
              'daily': <Object?>[],
              'target': 0,
              'trips': 0,
              'waybills_done': 0,
              'waybills_open': 0,
            },
          ],
      'cycle': {
        'id': cycleId,
        'label': cycleLabel,
        'status': cycleStatus,
        'targets': {'d7': 80, 'm12': '4300'},
        'draft': {'d7': 80},
        'started_on': startedOn,
        'locked_at': null,
      },
      'past_cycles': pastCycles ?? const <Object?>[],
      // The server's current_date, which the client measures from.
      'as_of': '2026-08-12',
    };

void main() {
  group('payload → MlTargetsData', () {
    test('months keep their zero days and their period key', () {
      final d = TargetsPayload.parse(_payload());
      expect(d.months, hasLength(2));

      final aug = d.months.first;
      expect(aug.key, '2026-08');
      expect(aug.label, 'Aug 2026');
      expect(aug.daysInMonth, 31);
      // Zeros are data: "no trips that day" is not "no data", and the charts
      // draw them differently.
      expect(aug.daily, [0, 129, 0, 46.5]);
      expect(aug.total, closeTo(175.5, 0.001));
      expect(aug.trips, 12);
      expect(aug.waybillsDone, 9);
      expect(aug.waybillsOpen, 3);
    });

    test('numerics survive arriving as strings', () {
      // PostgREST hands `numeric` over as a string once it is wide enough to
      // lose precision in a double, so both forms have to parse.
      final d = TargetsPayload.parse(_payload());
      expect(d.months.first.target, 450);
      expect(d.cycle.targets['m12'], 4300);
      expect(d.cycle.targets['d7'], 80);
    });

    test('a month with no daily entries is a planned month', () {
      final d = TargetsPayload.parse(_payload());
      expect(d.months.last.hasActuals, isFalse);
      expect(d.currentIndex, 0);
      expect(d.isPlanned(1), isTrue);
      expect(d.canEditMonth(0), isTrue);
      expect(d.canEditMonth(1), isTrue);
    });

    test('elapsed cycle days are calendar days from the anchor, not '
        'recorded days', () {
      // The cycle starts 2026-08-01 and `as_of` is the server's 2026-08-12, so
      // eleven days have elapsed — even though the record holds only four.
      // Counting the record would let a quiet week stop the clock while the
      // Postgres trigger kept counting.
      //
      // Eleven, not twelve: the count is exclusive of the start day, so day 0
      // is the day the cycle begins. That is what makes
      // `elapsed >= 365` line up with the trigger's
      // `current_date >= started_on + interval '1 year'`.
      final d = TargetsPayload.parse(_payload());
      expect(d.dailySeries, hasLength(4));
      expect(d.elapsedCycleDays, 11);
      expect(d.cycleComplete, isFalse);
      expect(d.daysUntilCycleReopens, 354);
    });

    test('the server clock wins, not the browser clock', () {
      // Both halves of the lock have to agree on the date. The trigger uses
      // Postgres `current_date`; this is where the client picks up the same
      // value instead of trusting the device.
      final d = TargetsPayload.parse(_payload());
      expect(d.asOf, DateTime(2026, 8, 12));
    });

    test('an unstarted draft shows no progress at all', () {
      // A cycle nobody has locked has not started. Showing elapsed days
      // against targets nobody committed to is the thing the null anchor
      // exists to prevent.
      final d = TargetsPayload.parse(_payload(startedOn: null));
      expect(d.cycle.hasStarted, isFalse);
      expect(d.elapsedCycleDays, 0);
      expect(d.cycleProgress, 0);
      expect(d.cycleComplete, isFalse);
      expect(d.cumulativeTo(365), 0);
      for (final z in kMlHorizons) {
        expect(d.horizonReached(z), isFalse, reason: z.key);
        expect(d.horizonActual(z), isNull, reason: z.key);
        // Never judged: `pending` where a target exists, `none` where one was
        // never set. Neither may read as `short` — "not started" is not
        // "missed", and that is the whole point of the null anchor.
        expect(
          d.horizonOutcome(z),
          anyOf(MlTargetOutcome.pending, MlTargetOutcome.none),
          reason: z.key,
        );
      }
      expect(d.horizonOutcome(kMlHorizons.first), MlTargetOutcome.pending,
          reason: 'd7 has a target, so it is pending rather than unset');
      expect(d.horizonOutcome(kMlHorizons[1]), MlTargetOutcome.none,
          reason: 'd14 has no target, so it is unset rather than pending');
    });

    test('a cycle locked but not yet begun reads as locked and pending', () {
      // Locked 12 Aug, starts 1 Sep: a real state for a fortnight.
      final d = TargetsPayload.parse(_payload(
        cycleStatus: 'locked',
        startedOn: '2026-09-01',
      ));
      expect(d.cycle.isLocked, isTrue);
      expect(d.canEditCycle, isFalse);
      expect(d.cycle.hasStarted, isTrue, reason: 'it has a start date…');
      expect(d.cycleRunning, isFalse, reason: '…but it has not arrived');
      expect(d.elapsedCycleDays, 0);
      expect(d.horizonOutcome(kMlHorizons.first), MlTargetOutcome.pending);
    });

    // The client and the Postgres trigger each decide when a cycle is over.
    // They have to land on the same day, or the banner offers a new cycle that
    // start_new_target_cycle refuses, with nothing on screen to say which is
    // right. The server uses `started_on + interval '1 year'`; these pin the
    // client to the same calendar arithmetic.
    group('the reopen boundary matches the server', () {
      MlTargetsData at(String startedOn, String asOf) => TargetsPayload.parse(
            _payload(cycleStatus: 'locked', startedOn: startedOn),
          ).copyWith(asOf: DateTime.parse(asOf));

      test('not complete the day before, complete on the day', () {
        expect(at('2026-09-01', '2027-08-31').cycleComplete, isFalse);
        expect(at('2026-09-01', '2027-09-01').cycleComplete, isTrue);
        expect(at('2026-09-01', '2027-08-31').daysUntilCycleReopens, 1);
        expect(at('2026-09-01', '2027-09-01').daysUntilCycleReopens, 0);
      });

      test('a cycle spanning 29 February runs the extra day', () {
        // 2027-09-01 -> 2028-09-01 contains 2028-02-29, so it is 366 days.
        // Counting to a flat 365 would have called this complete on 08-31.
        final eve = at('2027-09-01', '2028-08-31');
        expect(eve.elapsedCycleDays, 365,
            reason: 'a full 365 days have elapsed…');
        expect(eve.cycleComplete, isFalse,
            reason: '…but the calendar year has not, and the server agrees');
        expect(at('2027-09-01', '2028-09-01').cycleComplete, isTrue);
      });

      test('reopensOn is the date the server will accept a new cycle', () {
        final d = at('2026-09-01', '2027-01-01');
        expect(d.cycle.reopensOn, DateTime(2027, 9, 1));
        expect(d.cycleComplete, isFalse);
      });
    });

    test('a synthesised draft carries a stable id to key on', () {
      // The server no longer mints a row on read; it hands back this instead.
      final d = TargetsPayload.parse(_payload(
        cycleId: 'draft:org_type:transporter',
        cycleLabel: 'Not started',
        startedOn: null,
      ));
      expect(d.cycle.id, 'draft:org_type:transporter');
      expect(d.cycle.label, 'Not started');
      expect(d.cycle.isDraft, isTrue);
    });

    test('the cycle carries its status, targets and draft separately', () {
      final d = TargetsPayload.parse(_payload());
      expect(d.cycle.id, 'cycle-1');
      expect(d.cycle.label, 'Aug 2026 → Jul 2027');
      expect(d.cycle.isDraft, isTrue);
      expect(d.canEditCycle, isTrue);
      expect(d.cycle.draft, {'d7': 80.0});
      expect(d.cycle.startedOn, DateTime(2026, 8, 1));
      expect(d.cycle.hasStarted, isTrue);
    });

    test('an unrecognised status fails closed, not open', () {
      // Better to show a padlock over an editable cycle than a dial over a
      // committed one.
      for (final status in <Object?>['locked', 'closed', 'nonsense', null, 7]) {
        final d = TargetsPayload.parse(_payload(cycleStatus: status));
        expect(d.canEditCycle, isFalse, reason: 'status $status');
      }
    });

    test('closed cycles come through read-only, with frozen actuals', () {
      final d = TargetsPayload.parse(_payload(pastCycles: [
        {
          'id': 'cycle-0',
          'label': 'Aug 2025 → Jul 2026',
          'targets': {for (final z in kMlHorizons) z.key: 100},
          'actuals': {for (final z in kMlHorizons) z.key: 120},
        }
      ]));
      expect(d.pastCycles, hasLength(1));
      expect(d.pastCycles.first.surpassedCount, 6);
      expect(d.pastCycles.first.outcomeFor(kMlHorizons.first),
          MlTargetOutcome.surpassed);
    });

    test('a malformed payload degrades instead of throwing', () {
      final d = TargetsPayload.parse(<String, dynamic>{});
      expect(d.months, isEmpty);
      expect(d.pastCycles, isEmpty);
      expect(d.cycle.targets, isEmpty);
      expect(d.canEditCycle, isFalse);
    });
  });

  group('TargetScope', () {
    test('carries the wire strings the RPCs take', () {
      expect(TargetScope.platform.rpcArgs, {
        'p_scope': 'platform',
        'p_org_type': null,
        'p_company_id': null,
      });
      expect(const TargetScope.orgType('buyer').rpcArgs, {
        'p_scope': 'org_type',
        'p_org_type': 'buyer',
        'p_company_id': null,
      });
      expect(const TargetScope.company('abc').rpcArgs, {
        'p_scope': 'company',
        'p_org_type': null,
        'p_company_id': 'abc',
      });
    });

    test('is value-equal, so it is a stable provider family key', () {
      expect(const TargetScope.orgType('buyer'),
          const TargetScope.orgType('buyer'));
      expect(const TargetScope.orgType('buyer').hashCode,
          const TargetScope.orgType('buyer').hashCode);
      expect(const TargetScope.orgType('buyer'),
          isNot(const TargetScope.orgType('transporter')));
      expect(const TargetScope.company('a'), isNot(TargetScope.platform));
    });

    test('the three kinds are distinguishable', () {
      expect(TargetScope.platform.isPlatform, isTrue);
      expect(const TargetScope.orgType('buyer').isOrgType, isTrue);
      expect(const TargetScope.company('a').isCompany, isTrue);
      expect(TargetScopeKind.parse('org_type'), TargetScopeKind.orgType);
      expect(TargetScopeKind.parse('nonsense'), TargetScopeKind.platform);
    });
  });

  // A write asks its feed to re-read through this rather than invalidating the
  // provider, which would resubscribe a realtime channel on every keypress.
  group('TargetsFeedRegistry', () {
    test('refreshes only the scope that asked', () {
      final registry = TargetsFeedRegistry();
      var platform = 0;
      var buyer = 0;
      registry.register(TargetScope.platform, () => platform++);
      registry.register(const TargetScope.orgType('buyer'), () => buyer++);

      registry.refresh(TargetScope.platform);
      expect(platform, 1);
      expect(buyer, 0);

      registry.refresh(const TargetScope.orgType('buyer'));
      expect(platform, 1);
      expect(buyer, 1);
    });

    test('a scope nobody is listening to is a no-op, not a crash', () {
      final registry = TargetsFeedRegistry();
      expect(() => registry.refresh(const TargetScope.company('gone')),
          returnsNormally);

      var calls = 0;
      registry.register(TargetScope.platform, () => calls++);
      registry.unregister(TargetScope.platform);
      registry.refresh(TargetScope.platform);
      expect(calls, 0, reason: 'a disposed feed must not be called');
    });
  });
}
