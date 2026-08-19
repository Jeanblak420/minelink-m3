// S6-27 / ruling 5 — the waybill modal now offers the link to the route that
// renders it.
//
// `waybill_link_test.dart` proves WHAT the link is. This proves the control
// exists, is scoped to shells that have a waybill route, and puts the right
// text on the clipboard.
//
// RED FIRST: before this change the header held one button, Close. The first
// test asserts the link control is present, which fails against that header.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:flutter_application_1/features/portal/models/waybill_data.dart';
import 'package:flutter_application_1/features/portal/widgets/waybill_modal.dart';

const _tripId = 'abc-123';

/// Stands in for `buildTripWaybill`. Returns null — "no waybill yet" — which
/// renders the modal's empty state. The header, which is what these tests are
/// about, is drawn outside the FutureBuilder and so renders either way.
Future<WaybillData?> _noWaybill(WidgetRef ref, String tripId) async => null;

/// Records what the app puts on the clipboard.
class _ClipboardSpy {
  String? text;

  void install(WidgetTester tester) {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          text = (call.arguments as Map)['text'] as String?;
        }
        if (call.method == 'Clipboard.getData') {
          return <String, dynamic>{'text': text};
        }
        return null;
      },
    );
  }

  void remove(WidgetTester tester) {
    tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  }
}

/// Pumps an app at [atPath] and opens the waybill modal from it.
Future<void> _openModalFrom(WidgetTester tester, String atPath) async {
  final router = GoRouter(
    initialLocation: atPath,
    routes: [
      GoRoute(
        path: atPath,
        builder: (context, state) => Consumer(
          builder: (context, ref, _) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => showWaybillModal(
                  context,
                  ref,
                  tripId: _tripId,
                  waybillNumber: 'TRP-001',
                  fetch: _noWaybill,
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(child: MaterialApp.router(routerConfig: router)),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the modal offers a link control in a portal shell',
      (tester) async {
    await _openModalFrom(tester, '/portal/mine/tons-out');

    expect(find.text('Waybill TRP-001'), findsOneWidget);
    // Red-first: the pre-fix header had only Close.
    expect(find.byTooltip('Copy a link to this waybill'), findsOneWidget);
  });

  testWidgets('copying puts the waybill route on the clipboard',
      (tester) async {
    final spy = _ClipboardSpy()..install(tester);
    addTearDown(() => spy.remove(tester));

    await _openModalFrom(tester, '/portal/mine/tons-out');
    await tester.tap(find.byTooltip('Copy a link to this waybill'));
    await tester.pump();

    // Not web under `flutter test`, so the bare route is copied rather than
    // an absolute URL — a `file:` origin would help nobody.
    expect(spy.text, '/portal/mine/trips/$_tripId/waybill');
  });

  testWidgets('the control confirms itself, then reverts', (tester) async {
    final spy = _ClipboardSpy()..install(tester);
    addTearDown(() => spy.remove(tester));

    await _openModalFrom(tester, '/portal/mine/tons-out');
    await tester.tap(find.byTooltip('Copy a link to this waybill'));
    await tester.pump();

    // A SnackBar would render behind the dialog barrier; the button confirms
    // on itself instead.
    expect(find.byTooltip('Link copied'), findsOneWidget);
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);

    await tester.pump(const Duration(seconds: 3));
    expect(find.byTooltip('Copy a link to this waybill'), findsOneWidget);
    expect(find.byIcon(Icons.check_rounded), findsNothing);
  });

  testWidgets("the driver's shell copies its singular /trip/ route",
      (tester) async {
    final spy = _ClipboardSpy()..install(tester);
    addTearDown(() => spy.remove(tester));

    await _openModalFrom(tester, '/portal/driver/trip');
    await tester.tap(find.byTooltip('Copy a link to this waybill'));
    await tester.pump();

    expect(spy.text, '/portal/driver/trip/$_tripId/waybill');
  });

  testWidgets('no link control where no waybill route exists', (tester) async {
    // The super-admin combined recon table can open this modal, but there is
    // no /super-admin/**/waybill route. A button copying a URL the presser
    // cannot open is worse than no button.
    await _openModalFrom(tester, '/super-admin/recon-tables');

    expect(find.text('Waybill TRP-001'), findsOneWidget);
    expect(find.byTooltip('Copy a link to this waybill'), findsNothing);
    expect(find.byTooltip('Close'), findsOneWidget);
  });
}
