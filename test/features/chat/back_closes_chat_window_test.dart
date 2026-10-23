// The phone's Back and the chat window.
//
// Seen on a Galaxy S25 Ultra 2026-10-23: with the Messages window open, Back
// changed the page UNDER the window and left the window open on top of the
// new page. Back now steps back inside the window first, and closes it from
// the conversation list; only then does Back reach the page.
//
// Driven through the real system-back path (`handlePopRoute` → the router's
// back-button dispatcher), the same way `system_back_handler_test.dart` does.
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:flutter_application_1/core/navigation/nav_history_provider.dart';
import 'package:flutter_application_1/core/theme/app_theme.dart';
import 'package:flutter_application_1/core/widgets/nav_history_recorder.dart';
import 'package:flutter_application_1/core/widgets/system_back_handler.dart';
import 'package:flutter_application_1/features/chat/providers/messaging_providers.dart';
import 'package:flutter_application_1/features/chat/widgets/chat_dock.dart';

import '../../fixtures/shared_tail_fixtures.dart';

Finder get _launcher => find.byKey(const ValueKey('chat-dock-launcher'));
Finder get _window => find.text('Messages');

/// The launcher's 3D icon animates forever, so `pumpAndSettle` never returns.
/// Pump long enough for a page change or the window's open/close morph.
Future<void> settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
  await tester.pump(const Duration(milliseconds: 600));
}

void main() {
  late int exits;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'http://localhost:54321',
      anonKey: 'back-closes-chat-window-test',
    );
  });

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

  Future<void> pumpApp(WidgetTester tester,
      {bool withRooms = false}) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    Widget page(String name) => Builder(
          builder: (context) => Center(
            child: TextButton(
              onPressed: () => context.go(name == 'root' ? '/a' : '/b'),
              child: Text('page $name'),
            ),
          ),
        );

    final router = GoRouter(
      initialLocation: '/root',
      routes: [
        ShellRoute(
          builder: (context, state, child) {
            final location = state.uri.path;
            return SystemBackHandler(
              isRoot: location == '/root',
              goToRoot: () => context.go('/root'),
              child: ChatDock(
                child: Scaffold(
                  body: NavHistoryRecorder(
                    location: NavLocation(path: location),
                    isRoot: location == '/root',
                    child: child,
                  ),
                ),
              ),
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

    await tester.pumpWidget(ProviderScope(
      overrides: [
        messagingServiceProvider.overrideWithValue(FixtureMessagingService()),
        chatDeliveryProvider.overrideWithValue(null),
        chatConversationsProvider.overrideWith((ref) =>
            Stream.value(withRooms ? kConversations : const [])),
        chatContactsProvider.overrideWith(
            (ref) async => withRooms ? kChatContacts : const []),
      ],
      child: MaterialApp.router(
        theme: AppTheme.build(Brightness.dark),
        routerConfig: router,
        onNavigationNotification: SystemBackHandler.claimSystemBack,
      ),
    ));
    await settle(tester);

    // Dispose inside the test so the dock's debounces are cancelled while the
    // binding still pumps (see chat_dock_keeps_off_the_bottom_bar_test.dart).
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 1));
    });
  }

  Future<void> systemBack(WidgetTester tester) async {
    await tester.binding.handlePopRoute();
    await settle(tester);
  }

  testWidgets('Back closes the open chat window and keeps the page',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    try {
      await pumpApp(tester);
      await tester.tap(find.text('page root'));
      await settle(tester);
      await tester.tap(find.text('page a'));
      await settle(tester);
      expect(find.text('page b'), findsOneWidget);

      await tester.tap(_launcher);
      await settle(tester);
      expect(_window, findsOneWidget, reason: 'the chat window did not open');

      await systemBack(tester);
      expect(_window, findsNothing,
          reason: 'Back left the chat window open');
      expect(find.text('page b'), findsOneWidget,
          reason: 'Back changed the page under the chat window');

      // With the window closed, Back is the page's again.
      await systemBack(tester);
      expect(find.text('page a'), findsOneWidget);
      expect(exits, 0);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('the window can be opened and closed by Back repeatedly',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    try {
      await pumpApp(tester);
      for (var i = 0; i < 3; i++) {
        await tester.tap(_launcher);
        await settle(tester);
        expect(_window, findsOneWidget, reason: 'open #$i');
        await systemBack(tester);
        expect(_window, findsNothing, reason: 'close #$i');
      }
      expect(find.text('page root'), findsOneWidget);
      expect(exits, 0);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('Back steps out of a conversation to the list, then closes',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    try {
      await pumpApp(tester, withRooms: true);
      await tester.tap(_launcher);
      await settle(tester);
      // The list shows the Conversations / Contacts tabs; a thread does not.
      final listTabs = find.text('Conversations');
      expect(listTabs, findsOneWidget);

      await tester.tap(find.text('Night shift — load control'));
      await settle(tester);
      expect(listTabs, findsNothing, reason: 'the conversation did not open');

      await systemBack(tester);
      expect(_window, findsOneWidget,
          reason: 'Back from a conversation closed the whole window');
      expect(listTabs, findsOneWidget,
          reason: 'Back from a conversation did not return to the list');

      await systemBack(tester);
      expect(_window, findsNothing);
      expect(find.text('page root'), findsOneWidget);
      expect(exits, 0);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}
