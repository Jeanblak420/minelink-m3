import 'package:flutter/material.dart' show DateTimeRange;
import 'package:flutter_application_1/features/portal/models/tons_out_entry.dart';
import 'package:flutter_application_1/features/portal/utils/tons_out_filter.dart';
import 'package:flutter_test/flutter_test.dart';

TonsOutEntry _e({
  required DateTime date,
  String time = '10:00',
  String transporter = 'T1',
  String truckReg = 'REG1',
  String destination = 'BAYHEAD',
  String product = 'BLUE COAL POWER',
  String customer = 'TRITON',
  double netMass = 34.0,
}) {
  return TonsOutEntry(
    date: date,
    time: time,
    transporter: transporter,
    truckReg: truckReg,
    destination: destination,
    product: product,
    customer: customer,
    netMass: netMass,
  );
}

void main() {
  final now = DateTime(2026, 6, 17);
  final data = [
    _e(date: now, customer: 'TRITON', netMass: 30, truckReg: 'NB14004'),
    _e(date: now, customer: 'ATLAS', netMass: 40, destination: 'DURBAN'),
    _e(date: now.subtract(const Duration(days: 10)), customer: 'TRITON', netMass: 35),
    _e(date: now.subtract(const Duration(days: 200)), customer: 'STEELWORKS', netMass: 50),
  ];

  test('no filter returns all, default sort is date descending', () {
    final r = TonsOutQuery.apply(data, const TonsOutFilter());
    expect(r.length, 4);
    expect(r.first.date.isAfter(r.last.date) || r.first.date == r.last.date, isTrue);
  });

  test('categorical filter narrows by customer', () {
    final r = TonsOutQuery.apply(data, const TonsOutFilter(customer: 'TRITON'));
    expect(r.length, 2);
    expect(r.every((e) => e.customer == 'TRITON'), isTrue);
  });

  test('search matches truck reg case-insensitively', () {
    final r = TonsOutQuery.apply(data, const TonsOutFilter(search: 'nb14004'));
    expect(r.single.truckReg, 'NB14004');
  });

  test('mass range filters inclusive bounds', () {
    final r = TonsOutQuery.apply(data, const TonsOutFilter(minMass: 35, maxMass: 45));
    expect(r.map((e) => e.netMass).toSet(), {40.0, 35.0});
  });

  test('date range filters by day', () {
    final r = TonsOutQuery.apply(
      data,
      TonsOutFilter(
        dateRange: DateTimeRange(
          start: now.subtract(const Duration(days: 1)),
          end: now.add(const Duration(days: 1)),
        ),
      ),
    );
    expect(r.length, 2); // only the two "now" rows
  });

  test('sort by netMass ascending', () {
    final r = TonsOutQuery.apply(
      data,
      const TonsOutFilter(sortField: TonsOutSortField.netMass, ascending: true),
    );
    expect(r.first.netMass, 30);
    expect(r.last.netMass, 50);
  });

  test('distinct returns sorted unique values', () {
    final c = TonsOutQuery.distinct(data, (e) => e.customer);
    expect(c, ['ATLAS', 'STEELWORKS', 'TRITON']);
  });

  test('summarise buckets net mass into rolling windows', () {
    final s = TonsOutQuery.summarise(data, now: now);
    expect(s.total, 155); // 30+40+35+50
    expect(s.daily, 70); // two "now" rows
    expect(s.monthly, 105); // now rows + 10-day-old row
    expect(s.yearly, 155); // 200-day row still < 365
  });
}
