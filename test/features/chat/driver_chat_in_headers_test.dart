// A driver's chat opens from the headers, beside the bell, not from a disc
// floating over the page. On the S25-matched emulator the disc covered the
// bottom card of every driver tab — "Total tons" on Dashboard, the Account
// setup row on Profile (2026-10-24); Jean, 2026-10-25: "fix and improve
// whatever else needs it". The company portals and the console already open
// chat from their top bar; the driver app was the one shell left.
//
// Read as source, like `driver_can_reach_chat_test.dart` beside it, because
// mounting `PortalShellLayout` or the full driver app means stubbing the
// whole session.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/core/theme/app_theme.dart';
import 'package:flutter_application_1/features/chat/providers/messaging_providers.dart';
import 'package:flutter_application_1/features/chat/widgets/chat_dock.dart';

import '../../fixtures/shared_tail_fixtures.dart';
import '../../test_helpers/test_supabase.dart';

String _strip(String s) => s
    .replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '')
    .replaceAll(RegExp(r'//[^\n]*'), '');

void main() {
  setUpAll(ensureTestSupabaseInitialized);

  test('both driver branches hand the launcher to the headers on a phone', () {
    final src = _strip(File('lib/features/portal/widgets/portal_shell_layout.dart')
        .readAsStringSync());
    final docks = RegExp(r'ChatDock\(([^;]*?)DriverAppScreen\(\)|'
            r'_driverBack\(shellPath,\s*ChatDock\(([^;]*?)widget\.child')
        .allMatches(src)
        .toList();
    expect(docks, hasLength(2), reason: 'the two driver branches moved');
    for (final m in docks) {
      expect(m.group(0), contains('launcherInAppBarOnPhone: true'),
          reason: 'a driver branch still floats the chat disc over the page');
    }
  });

  test('every driver tab header carries the chat button beside the bell', () {
    final src = _strip(File('lib/features/portal/screens/driver_app_screen.dart')
        .readAsStringSync());
    final header = RegExp(r'class _DashboardHeader .*?\n\}', dotAll: true)
        .firstMatch(src)!
        .group(0)!;
    expect(header, contains('ChatDockAppBarButton()'));
    expect(header.indexOf('ChatDockAppBarButton()'),
        lessThan(header.indexOf('AnimatedNotificationBell()')));
    // Dashboard, Trip and Profile each draw that header.
    for (final title in ['Dashboard', 'Trip', 'Profile']) {
      expect(src, contains(RegExp("_DashboardHeader\\(\\s*title: '$title'")),
          reason: 'the $title tab has no header, so no chat button');
    }
  });

  testWidgets('at phone width: no disc, the header button opens chat',
      (tester) async {
    tester.view.physicalSize = const Size(411, 891);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        messagingServiceProvider.overrideWithValue(FixtureMessagingService()),
        chatDeliveryProvider.overrideWithValue(null),
        chatConversationsProvider.overrideWith((ref) => Stream.value(const [])),
        chatContactsProvider.overrideWith((ref) async => const []),
      ],
      child: MaterialApp(
        theme: AppTheme.build(Brightness.dark),
        home: const ChatDock(
          launcherInAppBarOnPhone: true,
          child: Scaffold(
            body: SafeArea(
              child: Row(children: [
                Expanded(child: Text('Dashboard')),
                ChatDockAppBarButton(),
              ]),
            ),
          ),
        ),
      ),
    ));
    await tester.pump();
    expect(find.byKey(const ValueKey('chat-dock-launcher')), findsNothing,
        reason: 'the disc still floats over the driver page');
    expect(find.byKey(const ValueKey('chat-dock-appbar-launcher')),
        findsOneWidget);
  });
}
