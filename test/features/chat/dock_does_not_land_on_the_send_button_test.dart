// The floating chat launcher sat on top of the composer's SEND button.
//
// Driven in a browser as `roadhaul.admin` on 2026-08-22, with the full-page
// thread open at `#/chat/24f1bef3-c3be-41c7-973c-6625e4fa3913` in a 1689x1277
// window, both rectangles read off the live accessibility tree:
//
//     send button    x 1633..1677   y 1220..1264   (44x44)
//     dock launcher  x 1601..1667   y 1189..1255   (66x66)
//     overlap        x 1633..1667   y 1220..1255   = 34x35 px
//
// 61% of the send button, with the launcher painted above it. A thumb aimed at
// Send opens the dock.
//
// It is the same shape as `chat_dock_keeps_off_the_bottom_bar_test.dart`: the
// dock wraps the whole shell and knows nothing about bottom-anchored chrome
// underneath it. The bottom bar was given a reserve; the composer never was,
// because no other page in the product puts a composer at the bottom of the
// window.
//
// The fix is the one `/communications` has had all along — the shell does not
// mount the dock over a surface that IS the conversation. This file pins both
// halves: that the route is excluded, and that the exclusion is load-bearing
// rather than tidying, because the two controls genuinely collide.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:flutter_application_1/core/theme/app_theme.dart';
import 'package:flutter_application_1/core/widgets/chat_widget.dart';
import 'package:flutter_application_1/features/chat/providers/messaging_providers.dart';
import 'package:flutter_application_1/features/chat/widgets/chat_dock.dart';
import 'package:flutter_application_1/features/portal/widgets/portal_shell_layout.dart';

import '../../fixtures/shared_tail_fixtures.dart';
import '../../test_helpers/real_fonts.dart';

Finder get _launcher => find.byKey(const ValueKey('chat-dock-launcher'));
Finder get _sendButton => find.byTooltip('Send message');

/// The window the collision was measured in.
const _measuredWindow = Size(1689, 1277);

Future<void> _pumpDockOverComposer(WidgetTester tester) async {
  tester.view.physicalSize = _measuredWindow;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      // The dock's live half, stubbed — the same set
      // `chat_dock_keeps_off_the_bottom_bar_test.dart` uses, and for the same
      // reason: a real conversations stream opens a Supabase realtime channel
      // and leaves a timer pending after the tree is disposed.
      overrides: [
        messagingServiceProvider.overrideWithValue(FixtureMessagingService()),
        chatDeliveryProvider.overrideWithValue(null),
        chatConversationsProvider.overrideWith((ref) => Stream.value(const [])),
        chatContactsProvider.overrideWith((ref) async => const []),
      ],
      child: MaterialApp(
        theme: AppTheme.build(Brightness.dark),
        home: ChatDock(
          child: Scaffold(
            body: ChatWidget(
              messages: [
                ChatMessage(
                  id: 'm-1',
                  content: 'Gate opens 05:00 tomorrow.',
                  senderId: 'someone-else',
                  senderName: 'Driver Test',
                  timestamp: DateTime.utc(2026, 8, 22, 5),
                ),
              ],
              currentUserId: 'me',
              onSendMessage: (_, {String? replyToId}) async {},
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();

  // Dispose inside the test, so the dock's providers cancel their own timers
  // while the binding is still willing to pump.
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await loadRealFonts();
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'http://localhost:54321',
      anonKey: 'chat-dock-send-button-test',
    );
  });

  group('the shell does not mount the dock over a conversation', () {
    test('the full-page thread is excluded', () {
      expect(
        portalShowsChatDock(
          location: '/chat/24f1bef3-c3be-41c7-973c-6625e4fa3913',
          isEmployeeWithoutRole: false,
        ),
        isFalse,
        reason: 'the launcher covers 61% of this page\'s send button — '
            'measured in a browser, see this file\'s header',
      );
    });

    test('the hub is excluded, as it always was', () {
      expect(
        portalShowsChatDock(
          location: '/communications',
          isEmployeeWithoutRole: false,
        ),
        isFalse,
      );
    });

    test('an ordinary workspace page still gets the dock', () {
      // The symmetric half. Without this, "return false" everywhere passes.
      for (final where in const [
        '/home',
        '/portal/mine',
        '/portal/mine/stockpiles',
        '/portal/driver/trip',
        '/portal/transporter/routes',
        '/super-admin/targets',
      ]) {
        expect(
          portalShowsChatDock(location: where, isEmployeeWithoutRole: false),
          isTrue,
          reason: '$where is not a conversation and lost its chat launcher',
        );
      }
    });

    test('a route that merely starts with the same letters is not swept in', () {
      // `/chatter` is not `/chat/`. The exclusion is matched on the segment,
      // not on a bare prefix, so a future route cannot silently lose its dock.
      expect(
        portalShowsChatDock(location: '/chatter', isEmployeeWithoutRole: false),
        isTrue,
      );
    });

    test('an employee with no role never gets it, wherever they are', () {
      expect(
        portalShowsChatDock(location: '/home', isEmployeeWithoutRole: true),
        isFalse,
      );
    });
  });

  testWidgets(
    'the exclusion is load-bearing: the launcher really does cover Send',
    (tester) async {
      // Not a test of the fix — a test of the REASON for it. If the launcher
      // and the composer ever stop colliding, this fails and the suppression
      // above can be reconsidered on purpose instead of deleted as tidying.
      await _pumpDockOverComposer(tester);

      expect(_launcher, findsOneWidget,
          reason: 'the dock did not build its launcher, so this proves nothing');
      expect(_sendButton, findsOneWidget,
          reason: 'the composer did not build its send button, so this proves '
              'nothing');

      final disc = tester.getRect(_launcher);
      final send = tester.getRect(_sendButton);
      final overlap = disc.intersect(send);

      expect(
        overlap.width > 0 && overlap.height > 0,
        isTrue,
        reason: 'the launcher $disc and the send button $send no longer '
            'overlap. That is good news, and it means the /chat/ exclusion in '
            'portalShowsChatDock can be revisited — do that deliberately '
            'rather than by deleting a line.',
      );

      // The browser measured 34x35 of a 44x44 button. Widget-test geometry is
      // not the browser's to the pixel, so this asserts the SHARE rather than
      // the pixels: most of the button, not a corner of it.
      final covered = (overlap.width * overlap.height) /
          (send.width * send.height);
      expect(
        covered,
        greaterThan(0.4),
        reason: 'the launcher covers ${(covered * 100).round()}% of the send '
            'button; the browser measured 61%',
      );
    },
  );
}
