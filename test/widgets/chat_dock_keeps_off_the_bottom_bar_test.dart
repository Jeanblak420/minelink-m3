// The chat launcher must not sit on a navigation destination.
//
// This is the geometry the browser measured on 2026-08-21, at 412x915: the
// 66px disc at y 835..890, inside a bottom bar occupying y 831..914, covering
// 68% of the width of the fifth destination — "More", the only route from the
// bottom bar to the rest of the navigation.
//
// The dock wraps the whole shell, so its area is the whole window; the
// `Scaffold` reserves the bar for its own body and the dock is outside that.
// `kMlBottomNavHeight` is what it reserves instead, and
// `bottom_bar_reserve_test.dart` proves that number is the bar's real height.
// This file proves the reserve is actually applied, and that it is NOT applied
// where there is no bar.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:flutter_application_1/core/design/shell/ml_app_shell.dart';
import 'package:flutter_application_1/core/theme/app_theme.dart';
import 'package:flutter_application_1/features/chat/providers/messaging_providers.dart';
import 'package:flutter_application_1/features/chat/widgets/chat_dock.dart';

import '../fixtures/shared_tail_fixtures.dart';

/// The launcher disc, found by the widget the dock builds for it.
Finder get _launcher => find.byKey(const ValueKey('chat-dock-launcher'));

Future<void> _pump(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      // The dock's live half, stubbed. Same set the render fixtures use — a
      // real conversations stream opens a Supabase realtime channel and leaves
      // a timer pending after the tree is disposed, which fails the test after
      // the body has already passed.
      overrides: [
        messagingServiceProvider.overrideWithValue(FixtureMessagingService()),
        // The delivery marker opens a Supabase realtime channel and arms a
        // 60-second periodic sweep. It early-returns when there is no signed-in
        // user — but the fixture messaging service above HAS one, so stubbing
        // the read half without this one turns the socket back on. That is the
        // trap in reverse: a fixture that says MORE than the service it stands
        // in for.
        chatDeliveryProvider.overrideWithValue(null),
        chatConversationsProvider
            .overrideWith((ref) => Stream.value(const [])),
        chatContactsProvider.overrideWith((ref) async => const []),
      ],
      child: MaterialApp(
        theme: AppTheme.build(Brightness.dark),
        home: ChatDock(
          child: Scaffold(
            body: const SizedBox.expand(),
            bottomNavigationBar: size.width < 600
                ? NavigationBar(
                    selectedIndex: 0,
                    destinations: const [
                      NavigationDestination(
                          icon: Icon(Icons.dashboard_outlined),
                          label: 'Dashboard'),
                      NavigationDestination(
                          icon: Icon(Icons.more_horiz), label: 'More'),
                    ],
                  )
                : null,
          ),
        ),
      ),
    ),
  );
  await tester.pump();

  // Let the dock's own debounces expire inside the test.
  //
  // `chatDeliveryProvider` returns before creating anything when there is no
  // signed-in user, which is this test's situation, but the typing inbox arms
  // a 250ms debounce. A timer still pending when the tree is disposed fails
  // the test AFTER the body has passed — see the handoff's note that a render
  // which passes alone and fails in the suite is a clock, an image cache or a
  // real socket.
  //
  // Disposing the tree INSIDE the test is what makes the providers cancel
  // their own timers while the binding is still willing to pump. Left to the
  // teardown, the tree is disposed after the last pump and the binding
  // asserts, with the body already passed — the exact "passes alone, fails in
  // the suite" shape §5 warns about.
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });
}

void main() {
  setUpAll(() async {
    // The dock reads the signed-in user through Supabase to decide what to
    // show in its unread badge, and asserts if the singleton is missing. Same
    // initialisation the render harness uses, pointing at nothing.
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'http://localhost:54321',
      anonKey: 'chat-dock-geometry-test',
    );
  });

  testWidgets('on a phone the launcher clears the bottom bar', (tester) async {
    await _pump(tester, const Size(412, 915));

    expect(_launcher, findsOneWidget,
        reason: 'the dock did not build its launcher, so this proves nothing');

    final disc = tester.getRect(_launcher);
    final barTop = 915 - kMlBottomNavHeight;

    expect(
      disc.bottom,
      lessThanOrEqualTo(barTop),
      reason: 'the launcher overlaps the bottom navigation bar — it covered '
          '68% of the "More" destination when this was measured in a browser. '
          'disc ${disc.top.round()}..${disc.bottom.round()}, '
          'bar starts at ${barTop.round()}',
    );
  });

  testWidgets('on a desktop window nothing is reserved', (tester) async {
    await _pump(tester, const Size(1600, 1000));

    final disc = tester.getRect(_launcher);
    expect(
      disc.bottom,
      greaterThan(1000 - kMlBottomNavHeight),
      reason: 'there is no bottom bar at this width, so reserving space for '
          'one would float the launcher 80px off the corner for no reason',
    );
  });
}
