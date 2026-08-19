import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/features/portal/models/live_trip_position.dart';
import 'package:flutter_application_1/features/portal/models/trip_status.dart';
import 'package:flutter_application_1/features/portal/widgets/live_truck_marker.dart';

void main() {
  const trip = LiveTripPosition(
    tripId: 'trip-test-1',
    status: TripStatus.scheduled,
    truckReg: 'KVK 087 MP',
    transporterName: 'Roadhaul Logistics',
    lat: -26.05,
    lng: 28.01,
  );

  Future<Rect> openCard(WidgetTester tester, Alignment markerAt) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: markerAt,
            child: const SizedBox(
              width: 44,
              height: 44,
              child: LiveTruckMarker(trip: trip),
            ),
          ),
        ),
      ),
    );
    // Touch path toggles the same overlay card hover shows.
    await tester.tap(find.byType(LiveTruckMarker));
    await tester.pump();
    expect(find.text('Driver'), findsOneWidget);
    return tester.getRect(
      find
          .ancestor(of: find.text('Driver'), matching: find.byType(Container))
          .first,
    );
  }

  void expectOnScreen(Rect card, Size screen) {
    expect(card.left, greaterThanOrEqualTo(0), reason: 'clipped left');
    expect(card.top, greaterThanOrEqualTo(0), reason: 'clipped top');
    expect(
      card.right,
      lessThanOrEqualTo(screen.width),
      reason: 'clipped right',
    );
    expect(
      card.bottom,
      lessThanOrEqualTo(screen.height),
      reason: 'clipped bottom',
    );
  }

  testWidgets('info card sizes to its content, not the whole overlay', (
    tester,
  ) async {
    final card = await openCard(tester, Alignment.center);
    // With the overlay's tight full-screen constraints leaking through, the
    // card blows up to the full 800px test surface (the giant-empty-box bug).
    expect(
      card.width,
      288,
      reason: 'Truck info card must keep its 288px width',
    );
    expectOnScreen(card, const Size(800, 600));
  });

  testWidgets('marker near the TOP: card flips below and is never cut off', (
    tester,
  ) async {
    final card = await openCard(tester, Alignment.topCenter);
    expectOnScreen(card, const Size(800, 600));
    // No headroom above the marker — card must open below it.
    expect(card.top, greaterThanOrEqualTo(44), reason: 'should flip below');
  });

  testWidgets('marker in a corner: card stays fully on-screen', (
    tester,
  ) async {
    for (final corner in [
      Alignment.topLeft,
      Alignment.topRight,
      Alignment.bottomLeft,
      Alignment.bottomRight,
    ]) {
      final card = await openCard(tester, corner);
      expectOnScreen(card, const Size(800, 600));
      // Reset between iterations.
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });
}
