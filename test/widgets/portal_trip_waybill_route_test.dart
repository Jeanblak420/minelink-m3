// The route wrapper that opens a waybill from a URL.
//
// Found during the 2026-08-17 walk and recorded as "minor, not fixed":
// changing the hash to another trip's waybill while one was already open left
// the PREVIOUS trip's PDF on screen. It is not minor in what it says — the URL
// named one trip and the document on the barrier belonged to another, on the
// paper that governs a delivery and carries a tonnage and two signatures.
//
// The cause is a lifecycle one, not a rendering one. The four waybill routes
// differ only in a path parameter, so GoRouter reuses the element: navigating
// between them runs didUpdateWidget, never initState, and a `bool _opened` set
// once in initState suppressed the second document forever.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:flutter_application_1/features/portal/screens/portal_trip_waybill_route.dart';

/// Records which trips were asked for, and keeps each "modal" on screen until
/// it is popped — the property that makes the stale case reproducible.
class _Opener {
  final List<String> opened = [];

  Future<void> call(BuildContext context, WidgetRef ref, String tripId) {
    opened.add(tripId);
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (_) => AlertDialog(content: Text('waybill for $tripId')),
    );
  }
}

void main() {
  Future<GoRouter> pump(WidgetTester tester, _Opener opener) async {
    final router = GoRouter(
      initialLocation: '/portal/mine/trips/trip-1/waybill',
      routes: [
        GoRoute(
          path: '/portal/mine/trips/:id/waybill',
          builder: (context, state) => PortalTripWaybillRoute(
            tripId: state.pathParameters['id'] ?? '',
            openWaybill: opener.call,
            child: Scaffold(
              body: Center(child: Text('trip ${state.pathParameters['id']}')),
            ),
          ),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(child: MaterialApp.router(routerConfig: router)),
    );
    await tester.pumpAndSettle();
    return router;
  }

  testWidgets('opens the waybill named by the URL', (tester) async {
    final opener = _Opener();
    await pump(tester, opener);

    expect(opener.opened, ['trip-1']);
    expect(find.text('waybill for trip-1'), findsOneWidget);
  });

  testWidgets('navigating to another trip replaces the document, and does '
      'not leave the previous one on screen', (tester) async {
    final opener = _Opener();
    final router = await pump(tester, opener);

    router.go('/portal/mine/trips/trip-2/waybill');
    await tester.pumpAndSettle();

    expect(opener.opened, ['trip-1', 'trip-2'],
        reason: 'the second trip must actually be fetched — initState does '
            'not run again when only the path parameter changes');
    expect(find.text('waybill for trip-2'), findsOneWidget);
    expect(find.text('waybill for trip-1'), findsNothing,
        reason: 'the outgoing document must be closed, not stacked under or '
            'left in front of the incoming one');
  });

  testWidgets('the same trip twice does not reopen or stack', (tester) async {
    final opener = _Opener();
    final router = await pump(tester, opener);

    router.go('/portal/mine/trips/trip-1/waybill');
    await tester.pumpAndSettle();

    expect(opener.opened, ['trip-1']);
    expect(find.text('waybill for trip-1'), findsOneWidget);
  });

  testWidgets('dismissing then returning to the same trip opens it again',
      (tester) async {
    final opener = _Opener();
    final router = await pump(tester, opener);

    // Dismiss by tapping the barrier.
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(find.text('waybill for trip-1'), findsNothing);

    router.go('/portal/mine/trips/trip-2/waybill');
    await tester.pumpAndSettle();
    router.go('/portal/mine/trips/trip-1/waybill');
    await tester.pumpAndSettle();

    expect(opener.opened, ['trip-1', 'trip-2', 'trip-1']);
    expect(find.text('waybill for trip-1'), findsOneWidget);
  });
}
