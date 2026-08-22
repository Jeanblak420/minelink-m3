// The one screen in the product that still looked like a crash.
//
// Driving the live app on 2026-08-22 as atlasbuyer.owner, a portal path that
// does not resolve produced this — go_router's own default, because the router
// was given no `errorBuilder`:
//
//     Page Not Found                                       (bare app bar)
//     GoException: no routes for location: /portal/buyer/does-not-exist
//     Home                                                 (bare text link)
//
// Three faults, and the redesign had never touched any of them because the
// screen belongs to a PACKAGE rather than to this app:
//
//   1. a raw exception class name shown to a customer — which this repo has a
//      release guard against (`no-raw-exception-in-ui`) and a `friendlyError()`
//      helper to obey. Neither could ever have caught it: the string is
//      interpolated inside go_router, and the guard greps `lib/`. That blind
//      spot is the reason this test reads the RENDERED text rather than the
//      source.
//   2. no design system on it at all — no tokens, no MlEmptyState, no chrome,
//      on a product where every other empty and error state is an MlEmptyState.
//   3. "Home" is not where a signed-in user lives. Each role has its own
//      landing route (`portalLandingRoute`), so a weighbridge controller was
//      sent to a second dead end after the first.
//
// The path itself is still shown: "which link was wrong" is the useful fact
// here, and a path is not an exception.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:flutter_application_1/core/design/components/ml_components.dart';
import 'package:flutter_application_1/core/routing/route_not_found_screen.dart';
import 'package:flutter_application_1/core/theme/app_theme.dart';

/// Every string the tree draws, TextSpans included — `find.text` cannot see a
/// TextSpan, and the exception text was drawn as one.
String _rendered(WidgetTester tester) => tester
    .widgetList<RichText>(find.byType(RichText))
    .map((r) => r.text.toPlainText())
    .join(' | ');

void main() {
  testWidgets('a bad link renders the app\'s own screen, not go_router\'s', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    var wentTo = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.build(Brightness.dark),
        home: RouteNotFoundScreen(
          location: '/portal/buyer/this-route-does-not-exist',
          onGoBack: () => wentTo++,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final text = _rendered(tester);

    // The fault, named exactly as it appeared.
    expect(
      text,
      isNot(contains('GoException')),
      reason: 'a customer must never be shown an exception class name',
    );
    expect(text, isNot(contains('Exception')));
    expect(text, isNot(contains('no routes for location')));

    // What it says instead, and the one fact worth keeping.
    expect(text, contains('That page is not here'));
    expect(
      text,
      contains('/portal/buyer/this-route-does-not-exist'),
      reason: 'the path is the useful half, and it is not an exception',
    );

    // It is built from the design system like every other empty state.
    expect(find.byType(MlEmptyState), findsOneWidget);

    // And its action actually goes somewhere.
    await tester.tap(find.text('Back to your dashboard'));
    await tester.pumpAndSettle();
    expect(wentTo, 1);
  });

  testWidgets('the router mounts it — an unresolvable path does not fall '
      'through to the package default', (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // A miniature router with the SAME errorBuilder shape as AppRouter's, so
    // this proves the wiring without needing a Supabase session. The real
    // router's builder is one line and is read by the source check below.
    final router = GoRouter(
      initialLocation: '/real',
      routes: [
        GoRoute(path: '/real', builder: (_, __) => const Text('the real page')),
      ],
      errorBuilder: (context, state) =>
          RouteNotFoundScreen(location: state.uri.toString(), onGoBack: () {}),
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      MaterialApp.router(
        theme: AppTheme.build(Brightness.dark),
        routerConfig: router,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('the real page'), findsOneWidget);

    router.go('/nowhere-at-all');
    await tester.pumpAndSettle();

    expect(find.byType(RouteNotFoundScreen), findsOneWidget);
    expect(_rendered(tester), isNot(contains('GoException')));
    // go_router's default titles its app bar exactly this.
    expect(find.text('Page Not Found'), findsNothing);
  });

  test('the real router actually passes an errorBuilder', () {
    // The behavioural cases above use a stand-in router, because AppRouter's is
    // a `static final` that touches Supabase at construction. This reads the
    // one line that matters. Comments stripped first — the explanation left at
    // the call site names `errorBuilder` and would satisfy its own search.
    final source = File('lib/core/routing/app_router.dart')
        .readAsStringSync()
        .split('\n')
        .where((l) => !l.trimLeft().startsWith('//'))
        .join('\n');

    expect(
      source,
      contains('errorBuilder:'),
      reason: 'without one, go_router supplies the page this replaced',
    );
    expect(source, contains('RouteNotFoundScreen('));
  });
}
