// A shell must not be re-keyed by the route it is showing.
//
// Found in `public.crash_reports` — from the APK on a real handset, so this is
// a fault the app was shipping and nothing in the suite had ever seen:
//
//   Duplicate GlobalKey detected in widget tree.
//   - [GlobalObjectKey int#5fe70]
//   The specific parent that did not update after having one or more children
//   forcibly removed due to GlobalKey reparenting is:
//   - NavHistoryRecorder-[<'/super-admin'>](state: _NavHistoryRecorderState)
//
// Both shells wrapped go_router's shell child like this:
//
//     NavHistoryRecorder(
//       key: ValueKey(navLocation.fullLocation),   // <- changes every nav
//       ...
//       child: widget.child,
//     )
//
// go_router keys its shell navigator `GlobalObjectKey(navigatorKey.hashCode)`
// (go_router 13.2.5, `src/builder.dart`). Change the ValueKey and Flutter
// treats the recorder as a different widget, destroys its element, and — because
// the subtree holds a GlobalKey — REPARENTS that navigator into the new one.
// The outgoing recorder never updates in that frame, which is exactly the
// diagnostic above, and the framework's own warning is that this "will lead to
// parts of the widget tree being truncated unexpectedly".
//
// The second cost is quieter and worse. `_NavHistoryRecorderState` exists to
// record a visit in `didUpdateWidget` when the location changes. A key that
// changes with the location means the state is never UPDATED, only recreated —
// so that branch was dead code, and every visit was being recorded by
// `initState` instead. The widget's own test (`nav_history_recorder_test.dart`)
// mounts it with no key at all, which is why it always passed.
//
// So the fix is to delete the key, and these are the two halves of it: the
// subtree survives a navigation, and the visit is still recorded.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/core/navigation/nav_history_provider.dart';
import 'package:flutter_application_1/core/theme/app_theme.dart';
import 'package:flutter_application_1/core/widgets/nav_history_recorder.dart';

/// Stands in for go_router's `_CustomNavigator`: a stateful child carrying a
/// `GlobalObjectKey` over an int, which is the exact key shape in the report.
class _KeyedShellChild extends StatefulWidget {
  const _KeyedShellChild({super.key});

  @override
  State<_KeyedShellChild> createState() => _KeyedShellChildState();
}

class _KeyedShellChildState extends State<_KeyedShellChild> {
  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

/// The int-valued global key. `GlobalObjectKey`s are equal when their values
/// are identical, and identical ints are identical objects — which is why a
/// hashCode is a usable key and also why two of them collide.
const _shellNavigatorKey = GlobalObjectKey<_KeyedShellChildState>(0x5fe70);

void main() {
  testWidgets('a navigation updates the recorder instead of remounting it', (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    // Deliberately built the way the shells build it: ONE child widget
    // instance reused across locations, exactly as go_router hands the same
    // shell child down while only the location changes.
    Widget host(NavLocation loc) => UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AppTheme.darkTheme,
        home: NavHistoryRecorder(
          location: loc,
          isRoot: loc.path == '/super-admin',
          child: const _KeyedShellChild(key: _shellNavigatorKey),
        ),
      ),
    );

    await tester.pumpWidget(
      host(const NavLocation(path: '/super-admin', homeTabIndex: 0)),
    );
    await tester.pump();

    final recorderBefore = tester.state(find.byType(NavHistoryRecorder));
    final childBefore = _shellNavigatorKey.currentState;
    expect(childBefore, isNotNull);

    // Navigate within the shell — the case that produced the report.
    await tester.pumpWidget(
      host(const NavLocation(path: '/super-admin/disputes', homeTabIndex: 0)),
    );
    await tester.pump();

    // No framework complaint. Note this one alone is NOT what catches the
    // fault: sabotaged with the key put back, takeException still came back
    // null, because a two-widget tree reparents cleanly where a real shell
    // does not. The identity checks below are the ones that bite. Kept anyway
    // — if reparenting ever does start throwing here, that is worth failing on.
    expect(
      tester.takeException(),
      isNull,
      reason: 'reparenting a GlobalKey out of a dying parent is the bug',
    );

    // The recorder was UPDATED, not rebuilt from scratch...
    expect(
      identical(tester.state(find.byType(NavHistoryRecorder)), recorderBefore),
      isTrue,
      reason: 'a route-derived key here remounts the whole shell subtree',
    );

    // ...and neither was the shell child underneath it, which is what
    // "truncated unexpectedly" would have cost.
    expect(
      identical(_shellNavigatorKey.currentState, childBefore),
      isTrue,
      reason: 'the shell navigator must survive a navigation',
    );

    // And the feature still works — through didUpdateWidget, which was
    // unreachable while the key was there.
    expect(container.read(navHistoryProvider).length, 2);
    expect(container.read(navHistoryProvider.notifier).canGoBack, isTrue);
  });

  // A PLAIN test, not testWidgets: real file I/O inside testWidgets' fake-async
  // zone never completes, and the first version of this hung for the full
  // ten-minute timeout instead of failing.
  test('neither shell passes a route-derived key to the recorder', () {
    // The behavioural case above uses a stand-in tree, because mounting a real
    // shell needs an authenticated session and a router. This half reads the
    // two call sites themselves, since that is where the fault actually lived
    // and where it would come back.
    //
    // Comments are stripped first: the explanation left at each call site
    // names the very pattern being searched for, and a source-reading test
    // that matches its own explanation proves nothing.
    for (final path in const [
      'lib/features/super_admin/widgets/super_admin_shell_layout.dart',
      'lib/features/portal/widgets/portal_shell_layout.dart',
    ]) {
      final source = _stripComments(File(path).readAsStringSync());
      expect(
        source,
        contains('NavHistoryRecorder('),
        reason: '$path should still mount the recorder',
      );
      expect(
        source,
        isNot(contains('key: ValueKey(navLocation')),
        reason: '$path must not re-key the shell on every navigation',
      );
    }
  });
}

String _stripComments(String source) =>
    source.split('\n').where((l) => !l.trimLeft().startsWith('//')).join('\n');
