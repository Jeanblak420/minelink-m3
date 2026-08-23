/// Money and distances, formatted once for the whole product.
///
/// Transporter pass, 2026-08-23 (reviewer findings #15 and #16). Three screens
/// wrote the same two figures three different ways:
///
///   * the earnings screen produced **`R-61,023`** — the sign after the
///     currency, and a hyphen rather than a minus sign, on the one figure
///     that says a transporter lost money;
///   * the maintenance screen wrote `R ${cost.toStringAsFixed(2)}` — a space
///     after the R, no thousands grouping at all, so a real repair bill read
///     `R 128500.00`;
///   * and its odometers were bare `${km} km`, ungrouped, beside a fleet
///     register that has grouped them as `412 300 km` all along.
///
/// The sign convention is the one `PortalKpiRow.formatDelta` already fixed and
/// documented: **U+2212 MINUS SIGN, before the currency symbol.** A hyphen is
/// a different character at a different width, and the sign belongs to the
/// amount, not to the rand.
library;

import 'package:intl/intl.dart';

/// ⚠ `decimalPattern` KEEPS UP TO THREE FRACTION DIGITS. The formatter this
/// replaced was `NumberFormat('#,##0')`, which rounds, and swapping in
/// `decimalPattern` turned every whole-rand figure on the earnings screen into
/// `R29,159.2`. Caught by LOOKING at the render, not by the test that had just
/// gone green. `decimalPatternDigits` is the one that takes an answer.
final NumberFormat _grouped =
    NumberFormat.decimalPatternDigits(locale: 'en_ZA', decimalDigits: 0);

/// U+2212. Not a hyphen-minus.
const String mlMinus = '−';

/// The em dash this product uses for "no value".
const String mlNoValue = '—';

/// A rand amount: `R61,023`, `${mlMinus}R61,023`, or [mlNoValue] for null.
///
/// [decimals] is 0 by default — a haulage figure in the tens of thousands does
/// not need cents on a dashboard — and 2 where the exact amount matters, such
/// as a single invoice or repair.
String mlRand(num? amount, {int decimals = 0, String currency = 'ZAR'}) {
  if (amount == null) return mlNoValue;
  final symbol = currency == 'ZAR' ? 'R' : '$currency ';
  final sign = amount < 0 ? mlMinus : '';
  final magnitude = amount.abs();
  final formatter = decimals == 0
      ? _grouped
      : NumberFormat.decimalPatternDigits(
          locale: 'en_ZA', decimalDigits: decimals);
  return '$sign$symbol${formatter.format(magnitude)}';
}

/// A distance in kilometres, grouped with a space: `412 300 km`.
///
/// A SPACE, not a comma, and that is deliberate: it is what
/// `FleetVehicle.formattedOdometer` has always drawn, and an odometer is read
/// as a meter reading rather than as an amount of money.
String mlKm(num? km) {
  if (km == null) return mlNoValue;
  final digits = km.round().abs().toString();
  final buffer = StringBuffer(km < 0 ? mlMinus : '');
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(' ');
    buffer.write(digits[i]);
  }
  return '$buffer km';
}
