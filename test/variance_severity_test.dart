// The one definition of "how bad is this variance" (P3-13).
//
// Worth pinning because it decides what a user is told about missing mass, and
// because the value it replaced was demonstrably wrong: Side B used a flat
// `> 0.05 t` → error, which on the live database flagged all 35 reconciled
// loads as errors. Every one of them is short by <= 0.20 t on ~35 t.

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/core/design/tokens/ml_tokens.dart';
import 'package:flutter_application_1/features/portal/utils/variance_severity.dart';

VarianceSeverity sev(double? v, double? net) =>
    varianceSeverityOf(varianceTons: v, netTons: net);

void main() {
  group('not comparable', () {
    test('a missing variance is never a measured zero', () {
      expect(sev(null, 35), VarianceSeverity.notComparable);
      // and it must not render green — "we could not check" is not "it checked
      // out", the same distinction the Employee Register presence fix turned on
      expect(varianceTone(VarianceSeverity.notComparable), MlTone.neutral);
      expect(varianceTone(VarianceSeverity.notComparable),
          isNot(MlTone.done));
    });

    test('a missing or zero load mass has no denominator', () {
      expect(sev(1.5, null), VarianceSeverity.notComparable);
      expect(sev(1.5, 0), VarianceSeverity.notComparable);
      expect(sev(1.5, -4), VarianceSeverity.notComparable);
    });
  });

  group('the live data that broke the old threshold', () {
    test('0.20 t short on a 35 t load is scatter, not an error', () {
      // 0.57%. Under the old flat 0.05 t rule this was MlTone.error, on every
      // one of the 35 reconciled loads on the live database.
      expect(sev(0.20, 35), VarianceSeverity.balanced);
      expect(varianceTone(sev(0.20, 35)), MlTone.done);
    });

    test('the same 0.20 t off a 4 t load is NOT scatter', () {
      // 5% — the whole reason severity is a percentage and not a tonnage.
      expect(sev(0.20, 4), VarianceSeverity.material);
      expect(varianceTone(sev(0.20, 4)), MlTone.error);
    });
  });

  group('thresholds', () {
    test('under 1% is balanced', () {
      expect(sev(0.30, 100), VarianceSeverity.balanced); // 0.3%
    });

    test('1–3% is a warning', () {
      expect(sev(2.0, 100), VarianceSeverity.watch);
      expect(varianceTone(sev(2.0, 100)), MlTone.warn);
    });

    test('above 3% is material', () {
      expect(sev(3.5, 100), VarianceSeverity.material);
      expect(varianceTone(sev(3.5, 100)), MlTone.error);
    });

    test('the boundaries are exclusive, so exactly 1% and 3% do not escalate',
        () {
      expect(sev(1.0, 100), VarianceSeverity.balanced);
      expect(sev(3.0, 100), VarianceSeverity.watch);
    });

    test('the absolute floor protects a small load from rounding', () {
      // 0.04 t off a 0.5 t load is 8% — but it is also 40 kg, which is inside
      // any weighbridge's resolution. The floor wins.
      expect(sev(0.04, 0.5), VarianceSeverity.balanced);
      // Just above the floor, the percentage takes over again.
      expect(sev(0.06, 0.5), VarianceSeverity.material);
    });
  });

  group('over-delivery', () {
    test('more delivered than loaded is graded, never treated as fine', () {
      // A negative variance is still two weights that do not reconcile — it is
      // how a swapped load hides.
      expect(sev(-4.0, 100), VarianceSeverity.material);
      expect(sev(-2.0, 100), VarianceSeverity.watch);
      expect(sev(-0.3, 100), VarianceSeverity.balanced);
    });

    test('a shortfall and an equal overage grade identically', () {
      for (final magnitude in [0.5, 2.0, 5.0]) {
        expect(sev(magnitude, 100), sev(-magnitude, 100),
            reason: '$magnitude t should grade the same either direction');
      }
    });
  });

  test('an exact reconciliation is balanced, and green', () {
    expect(sev(0, 35), VarianceSeverity.balanced);
    expect(varianceTone(sev(0, 35)), MlTone.done);
  });
}
