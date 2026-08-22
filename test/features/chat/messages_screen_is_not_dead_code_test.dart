// `MessagesScreen` is 985 lines and looks deletable. It is not.
//
// The 2026-08-22 handoff put it in front of Jean as a deletion candidate,
// described as "reachable ONLY when a licence token is expiring", and he
// agreed to remove it *as long as only dead code was being deleted*. Reading
// the callers before deleting anything is what stopped it:
//
//   1. `MlExpiryNotice.onMessageMineLink` -> `context.go('/messages')`, wired
//      in `PortalShellLayout` on EVERY portal screen except `/profile`. The
//      notice renders nothing while a company is active, so it is invisible
//      almost all of the time — which is exactly why it read as dead.
//   2. `ExpiredAccessScreen`'s "Message MineLink" button, same route.
//
// Neither is guarded on anything. Both are the path a customer takes at the
// moment their licence lapses, which is the moment they most need to reach
// MineLink — and `MlExpiryNotice`'s own doc comment says so: "Messaging
// MineLink and logging a ticket both live there, and both stay available while
// a token is expired."
//
// The two `context.push('/messages')` calls in `EmployeeProfileScreen` ARE the
// dock-less fallback the handoff described, and they are guarded on
// `ChatDock.isMounted`. They are not deleted either: the dock is mounted
// CONDITIONALLY (`showChatFab = !isEmployeeWithoutRole && !location
// .startsWith('/communications')` in `PortalShellLayout`), so the else branch
// is a real fallback rather than a dead one — and removing it would turn
// "Message" into a button that does nothing whenever the dock is absent.
//
// This file reads source rather than rendering, because what is being pinned
// is REACHABILITY, and a widget test can only prove that a screen it was
// handed renders.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _read(String path) => File(path).readAsStringSync();

void main() {
  test('/messages is still mounted, and still mounts MessagesScreen', () {
    final router = _read('lib/core/routing/app_router.dart');
    expect(
      router.contains("path: '/messages'"),
      isTrue,
      reason: 'the /messages route is gone — every caller below is now a '
          'navigation to nowhere',
    );
    expect(router.contains('const MessagesScreen()'), isTrue);
  });

  test('the licence-expiry notice can still reach it, on every portal screen',
      () {
    final shell = _read('lib/features/portal/widgets/portal_shell_layout.dart');
    expect(
      shell.contains("onMessageMineLink: () => context.go('/messages')"),
      isTrue,
      reason: 'the expiry notice on every portal screen no longer offers a way '
          'to message MineLink. That notice is what a company sees while its '
          'token lapses, and RLS is already refusing their writes by then.',
    );
    // …and it is not itself behind a flag that could be turned off. The only
    // condition on it is the /profile suppression, which is deliberate: that
    // screen IS the renewal request the notice points at.
    expect(shell.contains('MlExpiryNotice('), isTrue);
  });

  test('the expired-access screen can still reach it', () {
    final expired =
        _read('lib/features/super_admin/screens/expired_access_screen.dart');
    expect(expired.contains("'Message MineLink'"), isTrue);
    expect(
      expired.contains("onPressed: () => context.go('/messages')"),
      isTrue,
      reason: 'the "Message MineLink" button on the expired-access screen no '
          'longer goes anywhere',
    );
  });

  test('the employee-profile fallback is a fallback, not a second surface', () {
    final profile =
        _read('lib/features/employee/screens/employee_profile_screen.dart');
    // Both /messages pushes here must stay INSIDE an `else` of the dock check.
    // If one ever escapes it, the platform admin gets a hard error: /messages
    // is portal-workspace-gated, which is what the code comment there records.
    expect(
      'ChatDock.isMounted(context)'.allMatches(profile).length,
      2,
      reason: 'the two dock-presence guards around the /messages fallbacks '
          'have changed in number — re-read them before trusting either',
    );
    expect("context.push('/messages')".allMatches(profile).length, 2);
  });

  test('the dock is mounted conditionally, which is why the fallback exists',
      () {
    final shell = _read('lib/features/portal/widgets/portal_shell_layout.dart');
    expect(
      shell.contains('final showChatFab ='),
      isTrue,
      reason: 'if the dock became unconditional, the employee-profile '
          'fallbacks really would be dead — and this test should be the thing '
          'that says so',
    );
    expect(shell.contains('if (showChatFab) {'), isTrue);
  });
}
