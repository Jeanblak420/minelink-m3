// A driver must see the lifecycle move when SOMEBODY ELSE moves it.
//
// Found by driving both sides of one load at once against production,
// 2026-08-22 — the platform admin and the mine in a browser, the driver on a
// real Samsung SM-G780G:
//
//   04:33  security marked the truck LEFT SITE.
//          `trips.status` → `en_route_to_offload`, confirmed in the database.
//   04:37  the driver's Trip screen still read **EN ROUTE TO LOAD**.
//
// Four minutes, across a tab switch and a pull gesture. It is not cosmetic:
// the driver's lifecycle buttons are gated on `TripStatus.step`, so
// `Arrived at offloading` and `Upload POD` stayed dimmed and the driver could
// not finish the load without killing the app.
//
// `DriverRoutesScreen` invalidates `logisticsSnapshotProvider` after the
// driver's OWN actions — which is exactly why every earlier step of the drive
// looked correct — and had nothing at all for anybody else's. The mine floor
// is three other people in a row: security checks in, the load controller
// weighs, security checks out.
//
// `logisticsSnapshotProvider` now watches a lifecycle tick fed by realtime on
// `trips`/`transactions`. This test drives the tick directly, because the
// point of failure was the WATCH, not the socket.

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/features/portal/providers/logistics_provider.dart';
import 'package:flutter_application_1/features/portal/services/logistics_service.dart';

/// Counts reads and hands back a snapshot that changes each time, so the test
/// can tell a genuine re-read from a cached value.
class _CountingLogisticsService implements LogisticsService {
  int loads = 0;

  @override
  Future<LogisticsSnapshot> loadForCompany(String companyId) async {
    loads++;
    return LogisticsSnapshot.empty;
  }

  @override
  Stream<int> watchLifecycle(String companyId) => const Stream<int>.empty();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Lets the stream emission reach the provider before the next read.
///
/// Without this the test read the future the provider had ALREADY resolved and
/// reported `loads == 1` whether the fix was present or not — a green test
/// over a stale value, which is the same shape as the bug it guards.
Future<void> _settle() async {
  for (var i = 0; i < 4; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  late _CountingLogisticsService service;
  late StreamController<int> ticks;
  late ProviderContainer container;

  setUp(() {
    service = _CountingLogisticsService();
    ticks = StreamController<int>.broadcast();
    container = ProviderContainer(
      overrides: [
        logisticsServiceProvider.overrideWithValue(service),
        logisticsLifecycleTickProvider('co-1')
            .overrideWith((ref) => ticks.stream),
      ],
    );
    addTearDown(() {
      container.dispose();
      ticks.close();
    });
  });

  test('a lifecycle tick re-reads the snapshot', () async {
    // Keep the provider alive for the whole test — it is autoDispose, and an
    // unlistened family member is torn down between reads, which would make
    // every read look like a "refetch" and the test prove nothing.
    final sub = container.listen(
      logisticsSnapshotProvider('co-1'),
      (_, __) {},
      fireImmediately: true,
    );
    addTearDown(sub.close);

    await container.read(logisticsSnapshotProvider('co-1').future);
    expect(service.loads, 1, reason: 'the first read is the mount');

    // Security marks the truck left site. Nothing on the driver's device
    // touched anything.
    ticks.add(1);
    await _settle();
    await container.read(logisticsSnapshotProvider('co-1').future);

    expect(service.loads, 2,
        reason: 'a change made by another role must be re-read');

    // The load controller weighs, then security checks out.
    ticks.add(2);
    await _settle();
    await container.read(logisticsSnapshotProvider('co-1').future);
    ticks.add(3);
    await _settle();
    await container.read(logisticsSnapshotProvider('co-1').future);

    expect(service.loads, 4);
  });

  test('with no tick, the snapshot is read exactly once', () async {
    final sub = container.listen(
      logisticsSnapshotProvider('co-1'),
      (_, __) {},
      fireImmediately: true,
    );
    addTearDown(sub.close);

    await container.read(logisticsSnapshotProvider('co-1').future);
    await container.read(logisticsSnapshotProvider('co-1').future);
    await container.read(logisticsSnapshotProvider('co-1').future);

    // Reading is not refetching — this is the behaviour that made the fault
    // invisible, and it is still correct on its own.
    expect(service.loads, 1);
  });
}
