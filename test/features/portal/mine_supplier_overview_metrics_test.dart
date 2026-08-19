import 'package:flutter_application_1/features/operations/models/operations_models.dart';
import 'package:flutter_application_1/features/portal/models/logistics_models.dart';
import 'package:flutter_application_1/features/portal/models/stockpile_entry.dart';
import 'package:flutter_application_1/features/portal/services/logistics_service.dart';
import 'package:flutter_application_1/features/portal/utils/mine_supplier_overview_metrics.dart';
import 'package:flutter_test/flutter_test.dart';

/// Builds a waybill transaction. [netTonsOut] is the real weighbridge Net Mass
/// (from `trips.net_tons`) — the figure tonnage metrics must use. [quantity]
/// (the ORDERED amount) defaults to 0 to mirror production, where it is unset:
/// the metrics must ignore it entirely.
OperationTransaction _txn({
  String? buyerId,
  double quantity = 0,
  required double netTonsOut,
  required DateTime updatedAt,
}) {
  return OperationTransaction(
    id: 'id-${updatedAt.microsecondsSinceEpoch}-$buyerId-$netTonsOut',
    buyerCompanyId: buyerId,
    referenceNumber: 'ref',
    status: 'in_transit',
    quantity: quantity,
    netTonsOut: netTonsOut,
    metadata: const {},
    createdAt: updatedAt,
    updatedAt: updatedAt,
  );
}

TripRecord _trip({required String status, required DateTime updatedAt}) {
  return TripRecord(
    id: 'trip-${updatedAt.microsecondsSinceEpoch}-$status',
    transactionId: 'txn',
    status: status,
    updatedAt: updatedAt,
  );
}

void main() {
  final now = DateTime(2026, 6, 17, 12);

  group('tonsOut', () {
    test('buckets quantities into overlapping rolling windows', () {
      final waybills = [
        _txn(netTonsOut: 10, updatedAt: now.subtract(const Duration(hours: 2))),
        _txn(netTonsOut: 20, updatedAt: now.subtract(const Duration(days: 3))),
        _txn(netTonsOut: 30, updatedAt: now.subtract(const Duration(days: 20))),
        _txn(netTonsOut: 40, updatedAt: now.subtract(const Duration(days: 200))),
        _txn(netTonsOut: 5, updatedAt: now.subtract(const Duration(days: 800))),
      ];

      final r = MineSupplierOverviewMetrics.tonsOut(waybills, now: now);

      expect(r.daily, 10);
      expect(r.weekly, 30); // 10 + 20
      expect(r.monthly, 60); // 10 + 20 + 30
      expect(r.yearly, 100); // 10 + 20 + 30 + 40
      expect(r.total, 105); // all
    });

    test('empty waybills yield zeros', () {
      final r = MineSupplierOverviewMetrics.tonsOut(const [], now: now);
      expect(r.total, 0);
      expect(r.daily, 0);
    });
  });

  group('tonsPerDay', () {
    test('sums waybill quantities per calendar day, oldest first', () {
      final waybills = [
        _txn(netTonsOut: 10, updatedAt: DateTime(2026, 6, 17, 9)), // today
        _txn(netTonsOut: 5, updatedAt: DateTime(2026, 6, 17, 11)), // today
        _txn(netTonsOut: 7, updatedAt: DateTime(2026, 6, 16, 15)), // yesterday
        _txn(netTonsOut: 3, updatedAt: DateTime(2026, 6, 11, 8)), // 6 days ago
        _txn(netTonsOut: 99, updatedAt: DateTime(2026, 6, 1, 8)), // outside
      ];
      final series =
          MineSupplierOverviewMetrics.tonsPerDay(waybills, now: now);
      expect(series.length, 7);
      expect(series.first.tons, 3); // 2026-06-11
      expect(series[5].tons, 7); // yesterday
      expect(series.last.tons, 15); // today
      expect(series.last.day, DateTime(2026, 6, 17));
    });

    test('empty waybills produce a zeroed 7-day series', () {
      final series =
          MineSupplierOverviewMetrics.tonsPerDay(const [], now: now);
      expect(series.length, 7);
      expect(series.every((d) => d.tons == 0), isTrue);
    });
  });

  group('buyerTonnage', () {
    test('groups by buyer, resolves names, sorts descending', () {
      final waybills = [
        _txn(buyerId: 'b1', netTonsOut: 100, updatedAt: now),
        _txn(buyerId: 'b2', netTonsOut: 250, updatedAt: now),
        _txn(buyerId: 'b1', netTonsOut: 50, updatedAt: now),
        _txn(buyerId: null, netTonsOut: 999, updatedAt: now), // ignored
      ];
      final pins = [
        const CompanyPin(id: 'b1', name: 'Buyer One', orgType: 'buyer'),
        const CompanyPin(id: 'b2', name: 'Buyer Two', orgType: 'buyer'),
      ];

      final result = MineSupplierOverviewMetrics.buyerTonnage(
        waybills,
        nameById: MineSupplierOverviewMetrics.namesFromPins(pins),
      );

      expect(result.length, 2);
      expect(result.first.name, 'Buyer Two');
      expect(result.first.tons, 250);
      expect(result.last.name, 'Buyer One');
      expect(result.last.tons, 150);
    });

    test('falls back to a short id when name is unknown', () {
      final waybills = [_txn(buyerId: 'abcdef123456', netTonsOut: 1, updatedAt: now)];
      final result = MineSupplierOverviewMetrics.buyerTonnage(
        waybills,
        nameById: const {},
      );
      expect(result.single.name, 'Buyer abcdef');
    });
  });

  group('allocatedBuyers', () {
    test('allocated buyers surface with REAL delivered tons from waybills', () {
      final stockpiles = const [
        StockpileEntry(
            name: 'A', buyer: 'Buyer B', buyerCompanyId: 'b', tons: 8600),
        StockpileEntry(
            name: 'B', buyer: 'Buyer D', buyerCompanyId: 'd', tons: 2200),
        StockpileEntry(
            name: 'E', buyer: 'Buyer B', buyerCompanyId: 'b', tons: 8000),
        StockpileEntry(name: 'F', tons: 999), // unallocated -> ignored
      ];
      final waybills = [
        _txn(buyerId: 'b', netTonsOut: 300, updatedAt: now),
        _txn(buyerId: 'b', netTonsOut: 200, updatedAt: now),
        _txn(buyerId: 'd', netTonsOut: 120, updatedAt: now),
        _txn(buyerId: 'z', netTonsOut: 999, updatedAt: now), // no allocation
      ];

      final result = MineSupplierOverviewMetrics.allocatedBuyers(
        stockpiles,
        waybills: waybills,
      );

      expect(result.length, 2);
      // Delivered tons (500 / 120), NOT the allocated stockpile tonnage.
      expect(result.first.name, 'Buyer B');
      expect(result.first.tons, 500); // 300 + 200
      expect(result.last.name, 'Buyer D');
      expect(result.last.tons, 120);
    });

    test('allocated buyer with no delivered loads shows zero tons', () {
      final result = MineSupplierOverviewMetrics.allocatedBuyers(
        const [
          StockpileEntry(
              name: 'A', buyer: 'Buyer B', buyerCompanyId: 'b', tons: 500),
        ],
        waybills: const [],
      );
      expect(result.single.name, 'Buyer B');
      expect(result.single.tons, 0);
    });

    test('no allocations yields no buyer cards', () {
      final result = MineSupplierOverviewMetrics.allocatedBuyers(
        const [StockpileEntry(name: 'A', tons: 500)],
        waybills: const [],
      );
      expect(result, isEmpty);
    });
  });

  group('trip counts', () {
    test('incomingTrucks counts active statuses only', () {
      final trips = [
        _trip(status: 'in_transit', updatedAt: now),
        _trip(status: 'loading', updatedAt: now),
        _trip(status: 'delivered', updatedAt: now),
        _trip(status: 'scheduled', updatedAt: now),
      ];
      expect(MineSupplierOverviewMetrics.incomingTrucks(trips), 2);
    });

    test('scheduledToday counts trips updated on the given day', () {
      final trips = [
        _trip(status: 'scheduled', updatedAt: now),
        _trip(status: 'scheduled', updatedAt: now.subtract(const Duration(days: 1))),
        _trip(status: 'scheduled', updatedAt: DateTime(2026, 6, 17, 23, 59)),
      ];
      expect(MineSupplierOverviewMetrics.scheduledToday(trips, now: now), 2);
    });
  });
}
