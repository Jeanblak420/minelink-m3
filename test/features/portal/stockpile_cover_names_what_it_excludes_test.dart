// A figure and its own caption must not disagree about the same quantity.
//
// Photographed on the live mine overview, 2026-08-22, signed in as
// ironhills.owner:
//
//     210.3 t
//     Stockpile balance
//     150.3 of 1240 t ordered · 12%
//
// Sixty tons between a number and the caption printed underneath it. Both
// halves were correct in isolation. Iron Hills has nine piles; seven carry a
// `max_cap_tons` and two do not, and one of the two — "C Grade Blue Coal -
// Atlas Buyer" — holds exactly 60.0 t. The headline counts every pile; the
// ratio can only count piles that have a cap, so it dropped that pile from the
// numerator AND the denominator and said nothing.
//
// Scoping both sides of the ratio to capped piles is RIGHT, and was itself a
// fix: a previous version counted every pile against a capped denominator and
// reported a mine at "300% of ordered cap". What that fix left behind is that
// the exclusion is invisible, while the excluded tonnage is sitting in the
// number directly above it.
//
// It also left a note saying the ratio was unreachable in production because
// no live pile had a cap. That note expired the first time an order was
// dispatched — `link_and_dispatch_request` mints the pile WITH a cap — which
// is exactly what the note predicted and nothing re-checked.
//
// So: the caption now names the remainder, and the arithmetic closes on screen
// against the headline. 150.3 + 60 = 210.3.
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/features/portal/models/stockpile_entry.dart';
import 'package:flutter_application_1/features/portal/utils/mine_supplier_overview_metrics.dart';

StockpileEntry _pile(String name, double tons, {double? cap}) => StockpileEntry(
  id: name,
  name: name,
  mineral: 'Chrome Ore',
  tons: tons,
  maxCapTons: cap,
);

/// Iron Hills exactly as production held it when this was found.
final _ironHills = <StockpileEntry>[
  _pile('C Grade Blue Coal - Atlas Buyer', 60.0), // no cap — the missing 60 t
  _pile('Chrome Ore - Atlas Buyer Group', 45, cap: 120),
  _pile('Chrome Ore - Atlas Buyer Group b', 31.58, cap: 600),
  _pile('Chrome Ore 42% Cr2O3 lumpy - unsold', 30.3, cap: 180),
  _pile('Chrome Ore - Atlas Buyer Group c', 26.3, cap: 90),
  _pile('Chrome Ore - Atlas Buyer Group d', 10.8, cap: 120),
  _pile('Chrome Ore - unsold', 6.3, cap: 40),
  _pile('Chrome Ore - Iron Hills Mining', 0, cap: 90),
  _pile('Chrome Ore - Atlas (UI test)', 0), // no cap, and no tons either
];

void main() {
  test('the live pile set: the three figures agree with each other', () {
    final cover = StockpileCover.of(_ironHills);

    // The headline, and the two halves of the ratio, measured off the same
    // list — which is the point of them coming from one place.
    expect(cover.totalTons, closeTo(210.28, 0.001));
    expect(cover.cappedTons, closeTo(150.28, 0.001));
    expect(cover.capacityTons, closeTo(1240, 0.001));
    expect(cover.percent, 12);

    // And the difference is not lost — it is a value the caller can print.
    expect(
      cover.uncappedTons,
      closeTo(60.0, 0.001),
      reason: 'the 60 t pile with no cap is what went missing on screen',
    );
    expect(
      cover.cappedTons + cover.uncappedTons,
      closeTo(cover.totalTons, 1e-9),
      reason: 'the caption must be able to close against the headline',
    );
  });

  test(
    'the caption states the excluded tonnage, and closes on the headline',
    () {
      final cover = StockpileCover.of(_ironHills);

      // The screen's own formatter, so the caption is measured in the units the
      // headline is printed in.
      String tons(double v) => v >= 1000
          ? v.toStringAsFixed(0)
          : v.toStringAsFixed(v == v.roundToDouble() ? 0 : 1);

      // What was on screen, and must never be again: a caption that stops at
      // the ratio while 60 t sits unaccounted for in the figure above it.
      expect(
        cover.caption(tons),
        '150.3 of 1240 t ordered · 12% · 60 t uncapped',
      );
      expect(
        tons(cover.totalTons),
        '210.3',
        reason: '150.3 + 60 is the headline, and a reader can now check that',
      );
    },
  );

  test('every pile capped: there is nothing to disclose', () {
    final cover = StockpileCover.of([
      _pile('a', 45, cap: 120),
      _pile('b', 30, cap: 180),
    ]);

    expect(cover.totalTons, 75);
    expect(cover.cappedTons, 75);
    expect(
      cover.uncappedTons,
      0,
      reason: 'nothing excluded, so the caption stays as it was',
    );
    expect(cover.percent, 25);

    String tons(double v) => v.toStringAsFixed(v == v.roundToDouble() ? 0 : 1);
    expect(
      cover.caption(tons),
      '75 of 300 t ordered · 25%',
      reason: 'no remainder means no trailing clause to read past',
    );
  });

  test('no pile capped: there is no ratio at all, not a ratio of zero', () {
    final cover = StockpileCover.of([_pile('rom', 400)]);

    expect(
      cover.hasRatio,
      isFalse,
      reason: 'a cover percentage over no cap is a number nobody chose',
    );
    expect(cover.capacityTons, isNull);
    expect(
      cover.totalTons,
      400,
      reason: 'the tonnage is still real and still the headline',
    );
    expect(cover.caption((v) => v.toStringAsFixed(0)), 'No capped order piles');
  });

  test('no piles at all', () {
    final cover = StockpileCover.of(const []);
    expect(cover.totalTons, 0);
    expect(cover.hasRatio, isFalse);
    expect(cover.uncappedTons, 0);
  });

  test('an over-filled capped pile is reported over 100, not clamped', () {
    // The ring clamps because a ring cannot draw past full. The FIGURE must
    // not: a mine holding more than it sold needs to see that, and clamping
    // here is how a card and a ring came to disagree in the first place.
    final cover = StockpileCover.of([_pile('a', 260, cap: 200)]);
    expect(cover.percent, 130);
    expect(cover.uncappedTons, 0);
  });
}
