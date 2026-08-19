// Structural guardrails on `app_router.dart` (P4-01…P4-07, P0-12).
//
// The router had five widget classes declared inside it — ~430 lines backing 15
// routes with no screen file, no test, and no way to find them by looking for a
// screen. They are extracted; these tests are what stops them coming back.
//
// Source-reading rather than behavioural, deliberately, and for the same reason
// `portal_nav_test.dart` reads the route table as text: what is being asserted
// is a property of the FILE, not of a running app.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _router() =>
    File('lib/core/routing/app_router.dart').readAsStringSync();

void main() {
  test('the router declares no widget classes', () {
    final source = _router();

    // Every class declared in the file, public or private.
    final declared = RegExp(r'^class\s+(\w+)', multiLine: true)
        .allMatches(source)
        .map((m) => m.group(1)!)
        .toList();

    // A widget is anything extending one of the Flutter widget bases, or a
    // Riverpod consumer equivalent.
    final widgetish = RegExp(
      r'^class\s+(\w+)\s+extends\s+'
      r'(StatelessWidget|StatefulWidget|ConsumerWidget|ConsumerStatefulWidget'
      r'|State<|ConsumerState<)',
      multiLine: true,
    ).allMatches(source).map((m) => m.group(1)!).toList();

    expect(
      widgetish,
      isEmpty,
      reason: 'UI belongs in lib/features/**/screens/, not in the router. '
          'Found: $widgetish. Extract it to a screen file and import it — '
          'a class declared here has no screen file and no test, which is '
          'how 15 routes came to be backed by nothing findable.',
    );

    // Sanity: the regex above is only meaningful if the file parsed at all.
    expect(declared, isNotEmpty,
        reason: 'no classes matched — check the `class` literal format');
  });

  test('no bare "Company not loaded." fallback survives anywhere in lib/', () {
    // It appeared four times in the router: a dead end that stated a fault,
    // offered no way out, and did not distinguish "still loading" from "failed"
    // from "genuinely not linked". `PortalCompanyRequired` replaces it with an
    // MlEmptyState carrying a retry that re-runs the two loaders.
    final offenders = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final text = entity.readAsStringSync();
      if (text.contains("Text('Company not loaded.')")) {
        offenders.add(entity.path);
      }
    }
    expect(
      offenders,
      isEmpty,
      reason: 'use PortalCompanyRequired — it says which of the three cases '
          'this is and offers a retry that does something. Found in: '
          '$offenders',
    );
  });

  test('the five extracted screens exist and are public', () {
    const expected = {
      'lib/features/portal/screens/portal_own_company_screen.dart':
          'PortalOwnCompanyScreen',
      'lib/features/portal/screens/portal_tons_out_screen.dart':
          'PortalTonsOutScreen',
      'lib/features/portal/screens/portal_trips_screen.dart':
          'PortalTripsScreen',
      'lib/features/portal/screens/portal_trip_detail_screen.dart':
          'PortalTripDetailScreen',
      'lib/features/portal/screens/portal_trip_waybill_route.dart':
          'PortalTripWaybillRoute',
    };
    final router = _router();
    for (final entry in expected.entries) {
      final file = File(entry.key);
      expect(file.existsSync(), isTrue, reason: 'missing ${entry.key}');
      expect(file.readAsStringSync(), contains('class ${entry.value}'),
          reason: '${entry.value} not declared in ${entry.key}');
      // And the router actually routes to it, rather than the file being an
      // orphan copy while the router still holds its own.
      expect(router, contains(entry.value),
          reason: 'the router does not reference ${entry.value}');
    }
  });
}
