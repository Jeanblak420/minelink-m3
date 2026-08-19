import 'package:flutter/material.dart' show DateTimeRange;
import 'package:flutter_application_1/features/portal/models/tons_out_entry.dart';

enum TonsOutSortField { date, time, transporter, truckReg, destination, product, customer, netMass }

/// Immutable filter state for the Tons-out table. Every field is optional;
/// an unset field does not constrain results.
class TonsOutFilter {
  final String search; // matches any text column
  final String? transporter;
  final String? destination;
  final String? product;
  final String? customer;
  final DateTimeRange? dateRange;
  final double? minMass;
  final double? maxMass;
  final TonsOutSortField sortField;
  final bool ascending;

  const TonsOutFilter({
    this.search = '',
    this.transporter,
    this.destination,
    this.product,
    this.customer,
    this.dateRange,
    this.minMass,
    this.maxMass,
    this.sortField = TonsOutSortField.date,
    this.ascending = false,
  });

  bool get hasActiveFilters =>
      search.trim().isNotEmpty ||
      transporter != null ||
      destination != null ||
      product != null ||
      customer != null ||
      dateRange != null ||
      minMass != null ||
      maxMass != null;

  TonsOutFilter copyWith({
    String? search,
    Object? transporter = _unset,
    Object? destination = _unset,
    Object? product = _unset,
    Object? customer = _unset,
    Object? dateRange = _unset,
    Object? minMass = _unset,
    Object? maxMass = _unset,
    TonsOutSortField? sortField,
    bool? ascending,
  }) {
    return TonsOutFilter(
      search: search ?? this.search,
      transporter: transporter == _unset ? this.transporter : transporter as String?,
      destination: destination == _unset ? this.destination : destination as String?,
      product: product == _unset ? this.product : product as String?,
      customer: customer == _unset ? this.customer : customer as String?,
      dateRange: dateRange == _unset ? this.dateRange : dateRange as DateTimeRange?,
      minMass: minMass == _unset ? this.minMass : minMass as double?,
      maxMass: maxMass == _unset ? this.maxMass : maxMass as double?,
      sortField: sortField ?? this.sortField,
      ascending: ascending ?? this.ascending,
    );
  }

  static const _unset = Object();
}

/// Aggregate tonnage over rolling windows for the summary boxes.
class TonsOutSummary {
  final double daily;
  final double weekly;
  final double monthly;
  final double yearly;
  final double total;

  const TonsOutSummary({
    required this.daily,
    required this.weekly,
    required this.monthly,
    required this.yearly,
    required this.total,
  });
}

abstract final class TonsOutQuery {
  /// Applies [filter] to [entries] (filter then sort). Pure — no UI.
  static List<TonsOutEntry> apply(
    List<TonsOutEntry> entries,
    TonsOutFilter filter,
  ) {
    final q = filter.search.trim().toLowerCase();
    final list = entries.where((e) {
      if (filter.transporter != null && e.transporter != filter.transporter) return false;
      if (filter.destination != null && e.destination != filter.destination) return false;
      if (filter.product != null && e.product != filter.product) return false;
      if (filter.customer != null && e.customer != filter.customer) return false;
      if (filter.minMass != null && e.netMass < filter.minMass!) return false;
      if (filter.maxMass != null && e.netMass > filter.maxMass!) return false;
      if (filter.dateRange != null) {
        final d = DateTime(e.date.year, e.date.month, e.date.day);
        final start = DateTime(filter.dateRange!.start.year,
            filter.dateRange!.start.month, filter.dateRange!.start.day);
        final end = DateTime(filter.dateRange!.end.year,
            filter.dateRange!.end.month, filter.dateRange!.end.day);
        if (d.isBefore(start) || d.isAfter(end)) return false;
      }
      if (q.isNotEmpty) {
        final hay = [
          e.transporter,
          e.truckReg,
          e.destination,
          e.product,
          e.customer,
          e.time,
        ].join(' ').toLowerCase();
        if (!hay.contains(q)) return false;
      }
      return true;
    }).toList();

    int cmp(TonsOutEntry a, TonsOutEntry b) {
      int r;
      switch (filter.sortField) {
        case TonsOutSortField.date:
          r = a.date.compareTo(b.date);
          break;
        case TonsOutSortField.time:
          r = a.time.compareTo(b.time);
          break;
        case TonsOutSortField.transporter:
          r = a.transporter.compareTo(b.transporter);
          break;
        case TonsOutSortField.truckReg:
          r = a.truckReg.compareTo(b.truckReg);
          break;
        case TonsOutSortField.destination:
          r = a.destination.compareTo(b.destination);
          break;
        case TonsOutSortField.product:
          r = a.product.compareTo(b.product);
          break;
        case TonsOutSortField.customer:
          r = a.customer.compareTo(b.customer);
          break;
        case TonsOutSortField.netMass:
          r = a.netMass.compareTo(b.netMass);
          break;
      }
      return filter.ascending ? r : -r;
    }

    list.sort(cmp);
    return list;
  }

  /// Distinct sorted values of [selector] across [entries] (for dropdowns).
  static List<String> distinct(
    List<TonsOutEntry> entries,
    String Function(TonsOutEntry) selector,
  ) {
    final set = entries.map(selector).toSet().toList()..sort();
    return set;
  }

  /// Sums net mass into rolling windows relative to [now].
  static TonsOutSummary summarise(
    List<TonsOutEntry> entries, {
    required DateTime now,
  }) {
    final dayAgo = now.subtract(const Duration(days: 1));
    final weekAgo = now.subtract(const Duration(days: 7));
    final monthAgo = now.subtract(const Duration(days: 30));
    final yearAgo = now.subtract(const Duration(days: 365));
    double d = 0, w = 0, m = 0, y = 0, t = 0;
    for (final e in entries) {
      t += e.netMass;
      if (e.date.isAfter(yearAgo)) y += e.netMass;
      if (e.date.isAfter(monthAgo)) m += e.netMass;
      if (e.date.isAfter(weekAgo)) w += e.netMass;
      if (e.date.isAfter(dayAgo)) d += e.netMass;
    }
    return TonsOutSummary(daily: d, weekly: w, monthly: m, yearly: y, total: t);
  }
}
