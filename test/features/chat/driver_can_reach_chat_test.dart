// A driver must be able to reach chat.
//
// `PortalShellLayout` wraps every role's shell in a `ChatDock` at the END of
// its build. The driver's 3-tab app is returned from an EARLY branch, well
// above that line — so from the day the driver shell was added until
// 2026-08-22 a driver had no chat at all.
//
// Not "no floating button": no chat. `/home` IS the driver's whole app, the
// 3-tab shell replaces the sidebar so there is no rail entry to fall back on,
// and `DriverAppScreen` has no messages affordance of its own. A driver is a
// party to every load — load control weighs their truck, security checks them
// in and out, the transporter's admin assigns them — and none of those people
// could be answered.
//
// Nothing caught it. The render harness builds `MlAppShell` directly and never
// mounts `PortalShellLayout`, so no picture could contain the fault; every
// widget test of the driver screens builds `DriverAppScreen` on its own. It
// was found by installing the app on a real handset, signing in as the real
// driver account, and noticing the disc was not there.
//
// This asserts the structural fact rather than the pixel: whatever the driver
// shell becomes, a `ChatDock` is above it.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/features/chat/providers/messaging_providers.dart';
import 'package:flutter_application_1/features/chat/widgets/chat_dock.dart';

import '../../fixtures/shared_tail_fixtures.dart';
import '../../test_helpers/test_supabase.dart';

void main() {
  // The dock's services build a Supabase client in their constructors, so even
  // the fixture service needs an instance to exist. Pointed at a dummy host:
  // nothing in this test dials out.
  setUpAll(ensureTestSupabaseInitialized);

  test('the driver branch of PortalShellLayout wraps its shell in a ChatDock',
      () {
    // Read as source rather than by mounting the layout: `PortalShellLayout`
    // reaches for auth, the employee record, the router and the company scope
    // before it decides anything, and a fixture deep enough to reach the
    // driver branch would be a fixture that could agree with a broken shell.
    // The claim here is narrow and structural — the early `return` for a
    // driver on `/home` must not hand back a bare `DriverAppScreen`.
    final source = File(
      'lib/features/portal/widgets/portal_shell_layout.dart',
    ).readAsStringSync();

    final branch = RegExp(
      r"if \(shellPath == '/home' && isDriverEmployee\) \{(.*?)\n    \}",
      dotAll: true,
    ).firstMatch(source);

    expect(
      branch,
      isNotNull,
      reason: 'The driver branch has moved or been rewritten. Re-point this '
          'test at it — do not delete it. What it protects is that a driver '
          'can reach chat, and the fault it caught was a `return` placed '
          'above the line that wraps every other role.',
    );

    final body = branch!.group(1)!;
    expect(
      body.contains('ChatDock('),
      isTrue,
      reason: 'A driver on /home is returned a shell with no ChatDock above '
          'it, so they have no way to reach chat at all — no dock, no rail, '
          'and DriverAppScreen has no messages entry of its own. Wrap the '
          'returned shell: `return const ChatDock(child: DriverAppScreen());`',
    );
    expect(
      body.contains('DriverAppScreen()'),
      isTrue,
      reason: 'The driver branch should still render the driver app.',
    );
  });

  testWidgets('ChatDock renders its launcher above a bottom bar of its own',
      (tester) async {
    // The companion fact. The dock reserves `kMlBottomNavHeight` by WINDOW
    // CLASS rather than by asking whether a bar is present, which is what
    // makes wrapping the driver shell safe — the driver shell carries its own
    // Dashboard/Trip/Profile bar and is only ever narrow.
    //
    // `chat_dock_keeps_off_the_bottom_bar_test.dart` measures that geometry in
    // full. This one only asserts the launcher exists at phone width, so that
    // a change which hides the disc on narrow layouts fails HERE, next to the
    // reason a driver needs it.
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        // The dock's live half, stubbed — a real conversations stream opens a
        // Supabase realtime channel and leaves a timer pending after the tree
        // is disposed, which fails the test after the body has passed.
        overrides: [
          messagingServiceProvider.overrideWithValue(FixtureMessagingService()),
          chatDeliveryProvider.overrideWithValue(null),
          chatConversationsProvider.overrideWith((ref) => Stream.value(const [])),
          chatContactsProvider.overrideWith((ref) async => const []),
        ],
        child: const MaterialApp(
          home: ChatDock(child: Scaffold(body: SizedBox.expand())),
        ),
      ),
    );
    await tester.pump();

    expect(
      find.byKey(const ValueKey('chat-dock-launcher')),
      findsOneWidget,
      reason: 'At phone width the launcher must still be drawn — that is the '
          'only chat affordance a driver has.',
    );
  });
}
