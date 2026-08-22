// A figure with no denominator must say so, not print the numerator's sign.
//
// Photographed on the live mine Production screen, 2026-08-22, as
// ironhills.owner, 30-day window:
//
//     0.00 t Mined | 771.32 t Dispatched | — Yield | -771.32 t Pit-to-port loss
//
// Yield declined to answer, correctly, because `mined > 0` is false. The loss
// tile was computed from the very same zero and answered anyway:
//
//     final loss = mined - dispatched;                          // always shown
//     final yieldPct = mined > 0 ? (dispatched / mined * 100) : null;
//
// Read plainly, "-771.32 t of pit-to-port loss" says the mine gained 771 tons
// it never mined. And the tone was `loss > 0 ? warn : done`, so a negative loss
// took the GREEN treatment: a meaningless number presented as a good result,
// on the one screen a mine manager would open to ask whether product is going
// missing between the pit and the port.
//
// The data was fine. `production_entries` is empty for this mine — nobody has
// recorded a day's production. "We were not told what was mined" is a
// different fact from "nothing was mined", and neither one means "everything
// arrived safely".
//
// So both figures now come from `ProductionYield`, which has ONE notion of
// whether the window can be measured at all.
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/features/portal/utils/production_metrics.dart';

void main() {
  test('the live window: nothing mined means neither figure answers', () {
    const m = ProductionYield(minedTons: 0, dispatchedTons: 771.32);

    expect(m.isUnmeasured, isTrue);
    expect(m.yieldPercent, isNull, reason: 'this half was always right');
    expect(m.lossTons, isNull,
        reason: '-771.32 t was the bug: a loss stated against an unknown');
  });

  test('yield and loss are undefined together, never one without the other',
      () {
    // The whole fault was two figures disagreeing about whether the question
    // could be answered. Sweep the boundary and require them to agree.
    for (final mined in const [0.0, -1.0, 0.0001, 1.0, 500.0]) {
      final m = ProductionYield(minedTons: mined, dispatchedTons: 771.32);
      expect(m.yieldPercent == null, m.lossTons == null,
          reason: 'mined=$mined: one answered and the other did not');
    }
  });

  test('with production recorded, both figures are real', () {
    const m = ProductionYield(minedTons: 1000, dispatchedTons: 900);

    expect(m.isUnmeasured, isFalse);
    expect(m.yieldPercent, closeTo(90, 1e-9));
    expect(m.lossTons, closeTo(100, 1e-9),
        reason: '100 t mined that never left the weighbridge');
  });

  test('dispatching more than was mined in the window is a real negative', () {
    // Legitimate: product mined before the window shipping inside it. This
    // must still be reported — the fix is about an ABSENT denominator, not
    // about hiding negatives.
    const m = ProductionYield(minedTons: 100, dispatchedTons: 250);

    expect(m.lossTons, closeTo(-150, 1e-9));
    expect(m.yieldPercent, closeTo(250, 1e-9));
  });

  test('mined but nothing dispatched is a full loss, not an unmeasured one',
      () {
    const m = ProductionYield(minedTons: 400, dispatchedTons: 0);

    expect(m.isUnmeasured, isFalse,
        reason: 'the denominator is what has to exist, not the numerator');
    expect(m.lossTons, closeTo(400, 1e-9));
    expect(m.yieldPercent, 0);
  });
}
