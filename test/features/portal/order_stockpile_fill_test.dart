// S9-4 — the order flow's fill arithmetic, which had no test at all.
//
// `OrderStockpileFill` is what the buyer and the transporter read off the
// order card to decide whether to roll a truck. The number that matters is
// `loadsReady`, and it is computed in TWO places that nothing links:
//
//   Dart    lib/features/portal/providers/order_stockpile_provider.dart
//             int get loadsReady => (balanceTons / 30).floor();
//   Postgres stockpile_add_tons()
//             v_load numeric := 30;
//             v_new_loads := floor(v_new / v_load)::int;
//
// The server figure decides when the "ready to collect" alert fires and what
// number that alert quotes; the Dart figure decides what the card shows. If
// they ever disagree, a transporter is told two different things about the
// same pile. The server body was read off the live project on 2026-08-15 and
// the constants agreed; `kServerLoadTons` below records that, so a change to
// either side has somewhere to fail.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/features/portal/providers/order_stockpile_provider.dart';

/// The trailer size `stockpile_add_tons` uses (`v_load numeric := 30`), read
/// from the live function definition. Mirrored here on purpose: this is the
/// only place the two implementations are written down together.
const double kServerLoadTons = 30;

OrderStockpileFill fill(double balance, {double? cap, String? mineral}) =>
    OrderStockpileFill(
      stockpileId: 'sp-1',
      balanceTons: balance,
      maxCapTons: cap,
      mineral: mineral,
    );

void main() {
  group('loadsReady — full trailer loads on the pile', () {
    test('is zero below one full load, and never rounds up', () {
      expect(fill(0).loadsReady, 0);
      expect(fill(0.1).loadsReady, 0);
      expect(fill(29.9).loadsReady, 0);
      expect(fill(29.999).loadsReady, 0,
          reason: 'a nearly-full trailer is not a full trailer — rounding up '
              'here would send a truck to collect 29.999 t');
    });

    test('steps exactly on each 30 t multiple', () {
      expect(fill(30).loadsReady, 1);
      expect(fill(59.99).loadsReady, 1);
      expect(fill(60).loadsReady, 2);
      expect(fill(89.5).loadsReady, 2);
      expect(fill(90).loadsReady, 3);
    });

    test('agrees with the server constant it duplicates', () {
      // If someone changes v_load in stockpile_add_tons, this is the assertion
      // that should be updated with it — and the one that fails if it is not.
      expect(fill(kServerLoadTons).loadsReady, 1);
      expect(fill(kServerLoadTons - 0.001).loadsReady, 0);
      expect(fill(kServerLoadTons * 4).loadsReady, 4);
    });
  });

  group('fraction — the fill bar', () {
    test('is 0 when there is no cap, rather than dividing by null', () {
      expect(fill(500).fraction, 0);
    });

    test('is 0 for a non-positive cap rather than infinite or NaN', () {
      expect(fill(50, cap: 0).fraction, 0);
      expect(fill(50, cap: -10).fraction, 0);
    });

    test('tracks balance against cap', () {
      expect(fill(0, cap: 200).fraction, 0);
      expect(fill(50, cap: 200).fraction, closeTo(0.25, 1e-9));
      expect(fill(200, cap: 200).fraction, 1);
    });

    test('clamps above the cap so the bar cannot overrun', () {
      expect(fill(260, cap: 200).fraction, 1);
    });
  });

  group('isComplete — the order is fully piled', () {
    test('needs a cap; an uncapped pile is never "complete"', () {
      expect(fill(10000).isComplete, isFalse);
    });

    test('is true at the cap and beyond, false below it', () {
      expect(fill(199.99, cap: 200).isComplete, isFalse);
      expect(fill(200, cap: 200).isComplete, isTrue);
      expect(fill(200.01, cap: 200).isComplete, isTrue);
    });
  });

  test('a completed order still reports its collectable loads', () {
    // The card renders "Order complete · N full load(s) ready to collect", so
    // N must survive completion rather than reset.
    final f = fill(200, cap: 200, mineral: 'Chrome');
    expect(f.isComplete, isTrue);
    expect(f.loadsReady, 6);
    expect(f.mineral, 'Chrome');
  });
}
