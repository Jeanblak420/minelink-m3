// An empty state that tells you where to go must name a tab that is there.
//
// The dock's "No conversations yet" message read "Open the People tab to start
// a chat." The dock's tabs are **Conversations | Contacts**. There is no People
// tab on that surface — the string was copied verbatim from `MessagesScreen`,
// whose tabs really are Chats | People.
//
// So the single instruction shown to somebody with no conversations — which is
// every user on their first day, and was the first thing a driver saw the day
// drivers got chat at all — pointed at a control that does not exist.
//
// Nothing could catch it by type or by lint: both strings are valid English and
// both tab sets are correct on their own screen. It has to be checked by
// rendering the empty state and looking for the tab it names, which is what
// this does.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/core/theme/app_theme.dart';
import 'package:flutter_application_1/features/chat/providers/messaging_providers.dart';
import 'package:flutter_application_1/features/chat/widgets/chat_dock.dart';

import '../../fixtures/shared_tail_fixtures.dart';
import '../../test_helpers/test_supabase.dart';

/// Pulls `Contacts` out of "Open the Contacts tab to start a chat."
///
/// Deliberately reads the rendered string rather than taking the tab name as a
/// constant: the point is that the COPY and the CONTROL agree, so the copy has
/// to be the thing under test.
final _namesATab = RegExp(r'Open the (.+?) tab');

void main() {
  setUpAll(ensureTestSupabaseInitialized);

  testWidgets('the dock\'s empty conversations state names a tab it actually '
      'has', (tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          messagingServiceProvider.overrideWithValue(FixtureMessagingService()),
          chatDeliveryProvider.overrideWithValue(null),
          // Empty on purpose — this state is only reachable with no rooms.
          chatConversationsProvider
              .overrideWith((ref) => Stream.value(const [])),
          chatContactsProvider.overrideWith((ref) async => kChatContacts),
          ...chatDockOverrides(),
        ],
        // `theme:`, not a bare MaterialApp — stock Material's type scale and
        // font family are a measurement of text this app never draws
        // (`test-renders-under-the-app-theme`, and CLAUDE.md §10.5).
        child: MaterialApp(
          theme: AppTheme.build(Brightness.dark),
          home: const ChatDock(child: Scaffold(body: SizedBox.expand())),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('chat-dock-launcher')));
    await tester.pumpAndSettle();

    final instruction = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data)
        .whereType<String>()
        .firstWhere(
          (s) => _namesATab.hasMatch(s),
          orElse: () => '',
        );

    expect(
      instruction,
      isNotEmpty,
      reason: 'The empty conversations state no longer tells anyone where to '
          'go. If that is deliberate, delete this test and say why; if the '
          'wording changed, keep it in the "Open the X tab" shape so this can '
          'keep checking that X exists.',
    );

    final tabName = _namesATab.firstMatch(instruction)!.group(1)!;
    expect(
      find.text(tabName),
      findsWidgets,
      reason: 'The empty state says "$instruction", but there is no "$tabName" '
          'control on this surface. The dock\'s tabs are Conversations and '
          'Contacts; `MessagesScreen`\'s are Chats and People. Copying an '
          'empty state between the two is how a user gets sent to a tab that '
          'is not on their screen.',
    );
  });
}
