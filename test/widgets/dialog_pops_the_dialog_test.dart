// A dialog must dismiss ITSELF, not the screen underneath it.
//
// Found 2026-08-17 by driving the running app: on the super-admin request
// inbox, "Send back for revision" opened its note dialog and pressing EITHER
// button blanked the whole console to white. No Dart exception, no JS error,
// `location.hash` unchanged, semantics tree down to 0 nodes, and the request
// left untouched in the database. The control that pinned it: **Cancel** —
// which performs no network call at all — blanked the app identically, so it
// was never the review RPC.
//
// The cause is one discarded parameter:
//
//   showDialog(
//     context: context,
//     builder: (_) => AlertDialog(                    // <- context thrown away
//       actions: [TextButton(onPressed: () => Navigator.pop(context))],
//     ),                                              // <- the SCREEN's context
//   );
//
// The super-admin console and the portal are both GoRouter `ShellRoute`s
// (`app_router.dart:657` and `:1292`), so each has its own inner `Navigator`.
// `showDialog` defaults to `useRootNavigator: true` and pushes onto the ROOT
// navigator, while `Navigator.pop(screenContext)` resolves to the SHELL's inner
// one — so the pop removes the *page*, and the shell is left with nothing to
// draw.
//
// This test builds that exact shape: a root navigator with an inner navigator
// under it, a dialog pushed to the root, and a pop issued with the inner
// screen's context. It fails the way the console did — the screen disappears —
// so the fix is provable rather than asserted.
//
// `tool/dialog_context_check.py` guards the source pattern across the tree;
// this test guards the behaviour.
import 'package:flutter_application_1/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Builds a ShellRoute-shaped tree: an outer (root) Navigator whose single
/// route hosts a *nested* Navigator, which is where the "screen" lives.
Widget _shellApp({required Widget Function(BuildContext) screen}) {
  return MaterialApp(
    theme: AppTheme.darkTheme,
    home: Navigator(
      onGenerateRoute: (_) => MaterialPageRoute<void>(
        builder: (innerContext) => Scaffold(body: Builder(builder: screen)),
      ),
    ),
  );
}

void main() {
  testWidgets(
    'a dialog dismissed with the DIALOG context leaves the screen standing',
    (tester) async {
      await tester.pumpWidget(
        _shellApp(
          screen: (screenContext) => Column(
            children: [
              const Text('THE SCREEN'),
              TextButton(
                onPressed: () => showDialog<void>(
                  context: screenContext,
                  // The fix: keep the builder's own context and pop with it.
                  builder: (dialogContext) => AlertDialog(
                    content: const Text('THE DIALOG'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        child: const Text('Cancel'),
                      ),
                    ],
                  ),
                ),
                child: const Text('open'),
              ),
            ],
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('THE DIALOG'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(
        find.text('THE DIALOG'),
        findsNothing,
        reason: 'dialog must close',
      );
      expect(
        find.text('THE SCREEN'),
        findsOneWidget,
        reason: 'the screen underneath must survive its own dialog closing',
      );
    },
  );

  testWidgets(
    'popping with the SCREEN context destroys the screen — the defect itself',
    (tester) async {
      await tester.pumpWidget(
        _shellApp(
          screen: (screenContext) => Column(
            children: [
              const Text('THE SCREEN'),
              TextButton(
                onPressed: () => showDialog<void>(
                  context: screenContext,
                  // The defect: builder context discarded, pop uses the screen's.
                  builder: (_) => AlertDialog(
                    content: const Text('THE DIALOG'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(screenContext),
                        child: const Text('Cancel'),
                      ),
                    ],
                  ),
                ),
                child: const Text('open'),
              ),
            ],
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // This is what the console did: the page is gone and the dialog is still
      // up. Asserted so the failure mode stays documented and cannot silently
      // become "fine" without somebody noticing.
      expect(
        find.text('THE SCREEN'),
        findsNothing,
        reason:
            'popping with the screen context pops the SCREEN — this is the bug',
      );
      expect(
        find.text('THE DIALOG'),
        findsOneWidget,
        reason: 'and the dialog it was meant to close is still there',
      );
    },
  );
}
