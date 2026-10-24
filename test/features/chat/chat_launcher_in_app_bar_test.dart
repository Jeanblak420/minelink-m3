// On a phone the admin console's chat opens from the top bar, not from a disc
// floating over the page (admin phone audit, 2026-10-24): the disc covered the
// "Create company account" button, the edge of "Update password", table edges,
// and beside "Generate Token" a strip of text. Wider windows keep the disc,
// and a dock that did not opt in keeps it everywhere.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:flutter_application_1/core/theme/app_theme.dart';
import 'package:flutter_application_1/features/chat/providers/messaging_providers.dart';
import 'package:flutter_application_1/features/chat/widgets/chat_dock.dart';

import '../../fixtures/shared_tail_fixtures.dart';

final _disc = find.byKey(const ValueKey('chat-dock-launcher'));
final _barButton = find.byKey(const ValueKey('chat-dock-appbar-launcher'));

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
  await tester.pump(const Duration(milliseconds: 600));
}

Future<void> _pump(WidgetTester tester, Size size, {required bool optIn}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      messagingServiceProvider.overrideWithValue(FixtureMessagingService()),
      chatDeliveryProvider.overrideWithValue(null),
      chatConversationsProvider.overrideWith((ref) => Stream.value(kConversations)),
      chatContactsProvider.overrideWith((ref) async => kChatContacts),
    ],
    child: MaterialApp(
      theme: AppTheme.build(Brightness.dark),
      home: ChatDock(
        launcherInAppBarOnPhone: optIn,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Organizations'),
            actions: const [ChatDockAppBarButton()],
          ),
          body: const Center(child: Text('page')),
        ),
      ),
    ),
  ));
  await _settle(tester);
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
        url: 'http://localhost:54321', anonKey: 'chat-launcher-in-app-bar');
  });

  testWidgets('phone: no floating disc; the top-bar button opens the chat',
      (tester) async {
    await _pump(tester, const Size(360, 780), optIn: true);
    expect(_disc, findsNothing, reason: 'the disc still floats over the page');
    expect(_barButton, findsOneWidget);
    expect(find.text('Messages'), findsNothing);

    await tester.tap(_barButton);
    await _settle(tester);
    expect(find.text('Messages'), findsWidgets, reason: 'the chat did not open');
  });

  testWidgets('the top-bar button shows the unread count', (tester) async {
    await _pump(tester, const Size(360, 780), optIn: true);
    final unread = kConversations.fold<int>(0, (s, c) => s + c.unreadCount);
    expect(unread, greaterThan(0), reason: 'fixture has no unread messages');
    expect(
        find.descendant(of: _barButton, matching: find.text('$unread')),
        findsOneWidget);
  });

  testWidgets('desktop: the disc stays and the top bar has no chat button',
      (tester) async {
    await _pump(tester, const Size(1280, 800), optIn: true);
    expect(_disc, findsOneWidget);
    expect(_barButton, findsNothing);
  });

  testWidgets('a dock that did not opt in keeps its disc on a phone',
      (tester) async {
    await _pump(tester, const Size(360, 780), optIn: false);
    expect(_disc, findsOneWidget);
    expect(_barButton, findsNothing);
  });
}
