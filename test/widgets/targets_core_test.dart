// The locking rules are business rules, so they live in pure Dart where a test
// can reach them without pumping a widget — and where the UI cannot quietly
// route around them. These are the checks from
// `targets&monthly goals/INTEGRATION_TARGETS.md` §7.
//
// The server enforces the same two locks independently (closed month, locked
// cycle); see `supabase/migrations/20260808120000_targets_and_cycles.sql`.
// These tests cover the client half only.
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/features/super_admin/widgets/insights_v2/minelink_targets_core.dart';
import '../fixtures/ml_targets_sample.dart';

void main() {
  group('short term — closed months are immutable', () {
    test('only the current month and later can be edited', () {
      final d = MlTargetsSample.build();
      expect(d.canEditMonth(d.currentIndex - 1), isFalse);
      expect(d.canEditMonth(d.currentIndex), isTrue);
      expect(d.canEditMonth(d.currentIndex + 1), isTrue);
    });

    test('the current month is the last one carrying actuals', () {
      final d = MlTargetsSample.build();
      expect(d.months[d.currentIndex].hasActuals, isTrue);
      for (var i = d.currentIndex + 1; i < d.months.length; i++) {
        expect(d.months[i].hasActuals, isFalse,
            reason: '${d.months[i].label} is after the current month and must '
                'be planned, not actual');
        expect(d.isPlanned(i), isTrue);
      }
    });
  });

  group('outcome bands', () {
    test('surpassed at 100%, close at 90%, short below', () {
      expect(MlTargetBands.classify(target: 100, actual: 100),
          MlTargetOutcome.surpassed);
      expect(MlTargetBands.classify(target: 100, actual: 92),
          MlTargetOutcome.close);
      expect(MlTargetBands.classify(target: 100, actual: 89),
          MlTargetOutcome.short);
    });

    test('an unreached checkpoint is pending, never short', () {
      expect(MlTargetBands.classify(target: 100, actual: null),
          MlTargetOutcome.pending);
      expect(MlTargetBands.classify(target: 100, actual: null),
          isNot(MlTargetOutcome.short));
    });

    test('a zero target means "not set", not "a target of zero"', () {
      expect(MlTargetBands.classify(target: 0, actual: 50),
          MlTargetOutcome.none);
      expect(MlTargetBands.classify(target: 0, actual: 0),
          MlTargetOutcome.none);
    });
  });

  group('long term — the cycle lock', () {
    test('a cycle cannot be locked with an unset horizon', () {
      final full = <String, double>{
        for (final z in kMlHorizons) z.key: 100,
      };
      final complete = MlCycle(
        id: 'c',
        label: 'c',
        status: MlCycleStatus.draft,
        targets: const {},
        draft: full,
      );
      expect(complete.unsetHorizons, isEmpty);
      expect(complete.canLock, isTrue);

      // Drop one, and it must refuse — an unset horizon would read as a missed
      // one for the following twelve months.
      final gap = Map<String, double>.from(full)..remove('m6');
      final partial = MlCycle(
        id: 'c',
        label: 'c',
        status: MlCycleStatus.draft,
        targets: const {},
        draft: gap,
      );
      expect(partial.unsetHorizons.map((z) => z.key), ['m6']);
      expect(partial.canLock, isFalse);

      // A zero is not a value either.
      final zeroed = Map<String, double>.from(full)..['d14'] = 0;
      expect(
        MlCycle(
          id: 'c',
          label: 'c',
          status: MlCycleStatus.draft,
          targets: const {},
          draft: zeroed,
        ).canLock,
        isFalse,
      );
    });

    test('a locked cycle is not editable', () {
      final d = MlTargetsSample.build();
      expect(d.cycle.isLocked, isTrue);
      expect(d.canEditCycle, isFalse);
      expect(
        MlCycle(
          id: 'c',
          label: 'c',
          status: MlCycleStatus.locked,
          targets: const {},
          draft: const {},
        ).canLock,
        isFalse,
      );
    });

    test('a horizon has no actual until its checkpoint arrives', () {
      final d = MlTargetsSample.build();
      expect(d.horizonActual(kMlHorizons.last), isNull);
      expect(d.horizonActual(kMlHorizons.first), isNotNull);
      expect(d.horizonReached(kMlHorizons.first), isTrue);
      expect(d.horizonReached(kMlHorizons.last), isFalse);
    });

    test('cumulative tonnage compounds rather than resetting', () {
      final d = MlTargetsSample.build();
      expect(d.cumulativeTo(7), lessThanOrEqualTo(d.cumulativeTo(14)));
      expect(d.cumulativeTo(14), lessThanOrEqualTo(d.cumulativeTo(30)));
      expect(d.cumulativeTo(d.elapsedCycleDays),
          closeTo(d.dailySeries.fold<double>(0, (a, b) => a + b), 0.001));
    });
  });

  // The guide states these counts for the shipped fixture. They are asserted
  // rather than described so a changed fixture shows up as a failure here
  // instead of as a chart nobody double-checks.
  group('the sample fixture exercises every band', () {
    test('the current cycle: 2 surpassed, 1 close, 2 short, 1 pending', () {
      final d = MlTargetsSample.build();
      final counts = <MlTargetOutcome, int>{};
      for (final z in kMlHorizons) {
        final o = d.horizonOutcome(z);
        counts[o] = (counts[o] ?? 0) + 1;
      }
      expect(counts[MlTargetOutcome.surpassed], 2);
      expect(counts[MlTargetOutcome.close], 1);
      expect(counts[MlTargetOutcome.short], 2);
      expect(counts[MlTargetOutcome.pending], 1);
    });

    test('the eleven closed months: 6 surpassed, 2 close, 3 short', () {
      final d = MlTargetsSample.build();
      final past = [
        for (var i = 0; i < d.months.length; i++)
          if (d.isPast(i)) d.months[i],
      ];
      expect(past, hasLength(11));

      final counts = <MlTargetOutcome, int>{};
      for (final m in past) {
        counts[m.outcome] = (counts[m.outcome] ?? 0) + 1;
      }
      expect(counts[MlTargetOutcome.surpassed], 6);
      expect(counts[MlTargetOutcome.close], 2);
      expect(counts[MlTargetOutcome.short], 3);
    });

    test('the misconfigured 28,000 t month is flagged, not just missed', () {
      final d = MlTargetsSample.build();
      final current = d.months[d.currentIndex];
      expect(current.target, 28000);
      expect(current.targetLooksWrong, isTrue,
          reason: 'a target three orders of magnitude off is a configuration '
              'fault, and must be surfaced as one');
    });
  });

  group('parsing what a person types', () {
    test('accepts thousands separators, padding and a unit suffix', () {
      expect(mlParseTons('28,100'), 28100);
      expect(mlParseTons(' 410 '), 410);
      expect(mlParseTons('410t'), 410);
      expect(mlParseTons('410.5'), 410.5);
    });

    test('an empty or unusable field is null, not zero', () {
      // The dial falls back to the current target on null; a 0 here would make
      // an arrow-key nudge step from zero instead.
      expect(mlParseTons(''), isNull);
      expect(mlParseTons('   '), isNull);
      expect(mlParseTons('abc'), isNull);
      expect(mlParseTons('-5'), isNull);
    });
  });
}
