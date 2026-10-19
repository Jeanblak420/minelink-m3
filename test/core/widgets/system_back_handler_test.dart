import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_application_1/core/navigation/nav_back.dart';
import 'package:flutter_application_1/core/navigation/nav_history_provider.dart';
import 'package:flutter_application_1/core/widgets/nav_history_recorder.dart';
import 'package:flutter_application_1/core/widgets/system_back_handler.dart';

/// Drives the REAL system-back path (`handlePopRoute` → router back-button
/// dispatcher → go_router `popRoute`), which is what a phone's Back button or
/// gesture sends. `SystemNavigator.pop` being called is the app closing.
void main() {
  late int exits;

  setUp(() {
    exits = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'SystemNavigator.pop') exits++;
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  GoRouter buildRouter({required bool withHandler}) {
    Widget page(String name) => Scaffold(
      body: Builder(
        builder: (context) => Column(
          children: [
            Text('page $name'),
            TextButton(
              onPressed: () => context.go(name == 'root' ? '/a' : '/b'),
              child: const Text('next'),
            ),
            TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => const AlertDialog(content: Text('dialog')),
              ),
              child: const Text('open dialog'),
            ),
          ],
        ),
      ),
    );

    return GoRouter(
      initialLocation: '/root',
      routes: [
        ShellRoute(
          builder: (context, state, child) {
            final location = state.uri.path;
            final recorded = NavHistoryRecorder(
              location: NavLocation(path: location),
              isRoot: location == '/root',
              child: child,
            );
            if (!withHandler) {
              // What the shells had before: never reached by a system back.
              return Consumer(
                builder: (context, ref, _) => PopScope(
                  canPop: false,
                  onPopInvokedWithResult: (didPop, _) {
                    if (didPop) return;
                    if (ref.read(navHistoryProvider.notifier).canGoBack) {
                      navigateBack(context, ref);
                    }
                  },
                  child: recorded,
                ),
              );
            }
            return SystemBackHandler(
              isRoot: location == '/root',
              goToRoot: () => context.go('/root'),
              child: recorded,
            );
          },
          routes: [
            GoRoute(path: '/root', builder: (_, __) => page('root')),
            GoRoute(path: '/a', builder: (_, __) => page('a')),
            GoRoute(path: '/b', builder: (_, __) => page('b')),
          ],
        ),
      ],
    );
  }

  Future<void> pumpApp(WidgetTester tester, GoRouter router) async {
    await tester.pumpWidget(
      ProviderScope(child: MaterialApp.router(routerConfig: router)),
    );
    await tester.pumpAndSettle();
  }

  Future<void> systemBack(WidgetTester tester) async {
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
  }

  testWidgets('control: the old PopScope lets a system back close the app', (
    tester,
  ) async {
    await pumpApp(tester, buildRouter(withHandler: false));
    await tester.tap(find.text('next'));
    await tester.pumpAndSettle();
    expect(find.text('page a'), findsOneWidget);

    await systemBack(tester);
    expect(exits, 1, reason: 'reproduces the reported bug');
  });

  testWidgets('system back steps back through history, like the in-app arrow', (
    tester,
  ) async {
    await pumpApp(tester, buildRouter(withHandler: true));
    await tester.tap(find.text('next'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('next'));
    await tester.pumpAndSettle();
    expect(find.text('page b'), findsOneWidget);

    await systemBack(tester);
    expect(find.text('page a'), findsOneWidget);
    await systemBack(tester);
    expect(find.text('page root'), findsOneWidget);
    expect(exits, 0);
  });

  testWidgets('system back closes an open dialog and stays on the page', (
    tester,
  ) async {
    await pumpApp(tester, buildRouter(withHandler: true));
    await tester.tap(find.text('next'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('open dialog'));
    await tester.pumpAndSettle();
    expect(find.text('dialog'), findsOneWidget);

    await systemBack(tester);
    expect(find.text('dialog'), findsNothing);
    expect(find.text('page a'), findsOneWidget);
    expect(exits, 0);
  });

  testWidgets('with no history off the landing screen, back goes to it', (
    tester,
  ) async {
    final router = buildRouter(withHandler: true);
    await pumpApp(tester, router);
    // Arrive at /b directly (e.g. a notification link), then forget history.
    router.go('/b');
    await tester.pumpAndSettle();
    ProviderScope.containerOf(
      tester.element(find.text('page b')),
    ).read(navHistoryProvider.notifier).reset();

    await systemBack(tester);
    expect(find.text('page root'), findsOneWidget);
    expect(exits, 0);
  });

  testWidgets('on the landing screen: first back warns, second closes', (
    tester,
  ) async {
    await pumpApp(tester, buildRouter(withHandler: true));

    await systemBack(tester);
    expect(find.text('Press back again to exit'), findsOneWidget);
    expect(exits, 0);

    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(exits, 1);
  });
}
