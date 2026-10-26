// Money and distances, formatted once — and the sign in the right place.
//
// Transporter pass, 2026-08-23 (reviewer findings #15 and #16). Three screens
// wrote the same two figures three ways:
//
//   * the earnings screen produced **`R-61,023`** — the sign AFTER the
//     currency and written as a hyphen, on the one figure that tells a
//     transporter it lost money on a load;
//   * the maintenance screen wrote `R ${cost.toStringAsFixed(2)}`, so a real
//     repair bill read `R 128500.00` with no grouping at all;
//   * and its odometers were bare `${km} km`, beside a fleet register one
//     screen away that has grouped them as `412 300 km` all along.
//
// `PortalKpiRow.formatDelta` had already settled the sign — U+2212 MINUS SIGN,
// before the symbol — so this is that decision made once rather than a fourth
// opinion.

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/core/utils/ml_figures.dart';

void main() {
  group('mlRand', () {
    test('groups thousands and puts the symbol first', () {
      expect(mlRand(61023), 'R61,023');
      expect(mlRand(128500, decimals: 2), 'R128,500.00');
    });

    // ⚠ THE FIRST VERSION OF THIS FILE FAILED THIS AND PASSED EVERY OTHER
    // CASE. It used `NumberFormat.decimalPattern`, which keeps up to THREE
    // fraction digits, in place of the `NumberFormat('#,##0')` it replaced —
    // so the earnings screen's whole-rand figures became `R29,159.2`,
    // `R14,850.2`, `R41,665.1`. Every test above was green; the render was
    // not. Rounding is the DEFAULT here because a haulage figure in the tens
    // of thousands does not need cents on a dashboard.
    test('a rand with no decimals asked for is ROUNDED, not shown to 0.1', () {
      expect(mlRand(29159.2), 'R29,159');
      expect(mlRand(14850.24), 'R14,850');
      expect(mlRand(-26814.9), '${mlMinus}R26,815');
    });

    test('a loss is a MINUS SIGN before the R, not a hyphen after it', () {
      expect(mlRand(-61023), '${mlMinus}R61,023');
      // The exact string the earnings screen used to print.
      expect(mlRand(-61023), isNot('R-61,023'));
      // U+2212, not U+002D. They are different characters at different widths
      // and only one of them is a minus.
      expect(mlRand(-61023).codeUnitAt(0), 0x2212);
    });

    test('null is the product\'s em dash, never R0', () {
      expect(mlRand(null), mlNoValue);
      expect(mlRand(null), isNot('R0'));
    });

    // A REAL zero is not a missing value, and must still print. Without this
    // case a formatter that returned the dash for anything falsy would pass
    // every test above.
    test('zero prints as zero', () {
      expect(mlRand(0), 'R0');
      expect(mlRand(0, decimals: 2), 'R0.00');
    });

    test('a currency that is not rand keeps its code', () {
      expect(mlRand(1500, currency: 'USD'), 'USD 1,500');
    });
  });

  group('mlKm', () {
    test('groups with a SPACE, like the fleet register', () {
      expect(mlKm(412300), '412 300 km');
      expect(mlKm(91500), '91 500 km');
    });

    test('short readings are not grouped', () {
      expect(mlKm(500), '500 km');
      expect(mlKm(0), '0 km');
    });

    test('null is the em dash', () {
      expect(mlKm(null), mlNoValue);
    });
  });

  // The two agree with the formatter the KPI row already used, which is the
  // whole point of putting them in one place.
  test('the sign matches PortalKpiRow.formatDelta', () {
    // formatDelta writes '${d >= 0 ? '+' : '−'}${prefix}$n'.
    expect(mlRand(-500).startsWith(mlMinus), isTrue);
    expect(mlRand(500).startsWith('R'), isTrue);
  });
  // S25 walk, 2026-10-26: the production screen read "10000.00 t" beside a
  // stockpile card's "5,000 t", and a route sheet "Tons available 5000".
  group('mlTons', () {
    test('groups thousands and keeps the weighbridge decimals', () {
      expect(mlTons(10000), '10,000.00 t');
      expect(mlTons(36.215), '36.22 t');
    });

    test('whole tons when asked', () {
      expect(mlTons(5000, decimals: 0), '5,000 t');
    });

    test('a loss carries the minus sign, null is the em dash', () {
      expect(mlTons(-771.32), '${mlMinus}771.32 t');
      expect(mlTons(null), mlNoValue);
    });
  });

  group('mlTonsText', () {
    test('a typed plain number is grouped', () {
      expect(mlTonsText('5000'), '5,000 t');
      expect(mlTonsText('4,000'), '4,000 t');
      expect(mlTonsText('1200t'), '1,200 t');
      expect(mlTonsText('30.5'), '30.50 t');
    });

    test('anything else is shown as typed, and empty stays empty', () {
      expect(mlTonsText('5000-6000'), '5000-6000');
      expect(mlTonsText('about 4k'), 'about 4k');
      expect(mlTonsText('  '), isNull);
      expect(mlTonsText(null), isNull);
    });
  });
}
