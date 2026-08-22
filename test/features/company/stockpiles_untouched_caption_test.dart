// One KPI must count one set of things, whichever branch it takes.
//
// The employee register's supervisors card shows STOCKPILES UPDATED. Its
// empty-case caption always said "no stockpiles **with product**" — the subset
// it really measures, because a pile holding nothing cannot be "untouched
// today" in any sense a supervisor acts on. Its non-empty caption said plain
// "stockpiles".
//
// Measured on Iron Hills Mining as `ironhills.owner`, 2026-08-23:
//
//     Supervisor screen  ......  "9 stockpiles"
//     Employee register  ......  "7 of 7 stockpiles untouched today"
//
// Both numbers are right. Two of the nine piles hold nothing, so seven have
// product. Neither screen said which set it meant, so the same noun carried
// two totals one click apart — the same shape as the console's "1 dispute"
// over "No open disputes".
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/features/company/services/employee_register_service.dart';

void main() {
  test('the caption names the subset it counts', () {
    final caption = stockpilesUntouchedCaption(untouched: 7, withProduct: 7);

    expect(caption, contains('with product'),
        reason: 'the live caption read "7 of 7 stockpiles untouched today" '
            'beside a Supervisor screen headed "9 stockpiles". A count that '
            'does not say what it counts cannot be reconciled with the one '
            'next to it.');
    expect(caption, '7 of 7 stockpiles with product untouched today');
  });

  test('it uses the SAME words as the empty case', () {
    // The two branches of one KPI. If they drift apart again, the register is
    // back to describing two different sets depending on the data.
    expect(kNoStockpilesWithProduct, contains('with product'));
    expect(
      stockpilesUntouchedCaption(untouched: 1, withProduct: 3),
      contains('with product'),
    );
  });

  test('a single pile is not "1 stockpiles"', () {
    expect(stockpilesUntouchedCaption(untouched: 0, withProduct: 1),
        '0 of 1 stockpile with product untouched today');
  });

  test('everything touched still reads as a real sentence', () {
    expect(stockpilesUntouchedCaption(untouched: 0, withProduct: 9),
        '0 of 9 stockpiles with product untouched today');
  });
}
