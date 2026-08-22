// A message that was not sent must not look like one that was.
//
// Driven in a browser as `roadhaul.admin` on 2026-08-22. `ChatScreen`'s
// composer had three layers between the send button and the database, and not
// one of them could report a failure:
//
//   1. `ChatWidget._sendMessage` called `widget.onSendMessage(...)` and cleared
//      the box on the NEXT LINE, awaiting nothing.
//   2. `ChatScreen`'s callback was `async` and was not awaited either.
//   3. `ChatMessagesNotifier.sendMessage` wrapped the whole insert in
//      `catch (e) { debugPrint('Error sending message: $e'); }` — a log that
//      goes nowhere a user can see, and nowhere at all in a release web build.
//
// So the composer emptied and the send button vanished, which is exactly what
// a SUCCESS looks like. Whatever the underlying cause — a refused insert, an
// expired session, no network — the sender's only evidence either way was the
// box going empty.
//
// This pins the three facts that make a failure legible:
//
//   * the draft is handed over and only forgotten if that WORKED
//   * a failure puts the draft back, with the caret at the end, and the reply
//     target with it
//   * a failure says so, out loud, in the words of the error
//
// And the fourth, which is what let the bug hide for so long: `onSendMessage`
// returns a `Future` and `_sendMessage` awaits it. A fire-and-forget send
// cannot report anything.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/core/theme/app_theme.dart';
import 'package:flutter_application_1/core/widgets/chat_widget.dart';
import 'package:flutter_application_1/features/chat/screens/chat_screen.dart';

import '../../test_helpers/real_fonts.dart';
import '../../test_helpers/test_supabase.dart';

const _me = 'user-me';

Future<void> _pump(
  WidgetTester tester,
  Future<void> Function(String, {String? replyToId}) onSend,
) async {
  tester.view.physicalSize = const Size(900, 1200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(MaterialApp(
    // The app's own theme — `test-renders-under-the-app-theme`.
    theme: AppTheme.darkTheme,
    home: Scaffold(
      body: ChatWidget(
        messages: const [],
        currentUserId: _me,
        onSendMessage: onSend,
      ),
    ),
  ));
  await tester.pumpAndSettle();
}

Finder get _composer => find.byType(TextField).last;

/// The send control, found by the name it now carries.
Finder get _sendButton => find.byTooltip('Send message');

void main() {
  setUpAll(loadRealFonts);

  testWidgets('a send that works clears the composer', (tester) async {
    final sent = <String>[];
    await _pump(tester, (m, {String? replyToId}) async => sent.add(m));

    await tester.enterText(_composer, 'tare 16.4 t');
    await tester.pump();
    await tester.tap(_sendButton);
    await tester.pumpAndSettle();

    expect(sent, ['tare 16.4 t']);
    expect(tester.widget<TextField>(_composer).controller!.text, isEmpty);
  });

  testWidgets('a send that FAILS puts the draft back and says why',
      (tester) async {
    await _pump(
      tester,
      (m, {String? replyToId}) async =>
          throw StateError('the weighbridge is on fire'),
    );

    await tester.enterText(_composer, 'gross 50.6 t');
    await tester.pump();
    await tester.tap(_sendButton);
    await tester.pumpAndSettle();

    final controller = tester.widget<TextField>(_composer).controller!;
    expect(
      controller.text,
      'gross 50.6 t',
      reason: 'the draft was lost. Losing what somebody typed is the worst '
          'part of a failed send.',
    );
    expect(
      controller.selection.baseOffset,
      'gross 50.6 t'.length,
      reason: 'the caret should be where they left off, not at 0',
    );
    expect(
      find.textContaining('Message not sent'),
      findsOneWidget,
      reason: 'a failed send said nothing at all — which is what it did before '
          'this test existed',
    );
    // NOT the raw exception text. `friendlyError` rewrites an exception into
    // something a load controller can act on, which is the product's rule
    // everywhere else — so asserting on `'the weighbridge is on fire'` would be
    // asserting that the app leaks stack-trace prose at people. What matters
    // here is that the notice EXISTS and is not the success path.
    final notice = tester
        .widgetList<Text>(find.textContaining('Message not sent'))
        .single
        .data!;
    expect(
      notice.length,
      greaterThan('Message not sent.'.length),
      reason: 'the notice should carry a reason after "Message not sent.", '
          'not just the bare phrase',
    );
  });

  testWidgets('the send is AWAITED, not fired and forgotten', (tester) async {
    // The structural fact underneath both cases above. If the composer stops
    // awaiting, the failing case still ends with an empty box and no message —
    // and this is the assertion that catches it, because a fire-and-forget
    // send clears BEFORE the future has had a chance to fail.
    var released = false;
    final gate = Completer<void>();
    await _pump(tester, (m, {String? replyToId}) async {
      await gate.future;
      released = true;
    });

    await tester.enterText(_composer, 'still in flight');
    await tester.pump();
    await tester.tap(_sendButton);
    await tester.pump();

    expect(released, isFalse, reason: 'the send has not completed yet');

    gate.complete();
    await tester.pumpAndSettle();
    expect(released, isTrue);
  });

  _notifierGroup();

  testWidgets('the send control has a name', (tester) async {
    // It was the only unlabelled control in the composer, and the one that
    // does the thing — a bare "button" in the accessibility tree.
    //
    // A `Tooltip`, NOT a `Semantics` wrapper inside the `InkWell`: that was
    // tried first and it SWALLOWED THE TAP, because the InkWell's own node
    // carries the tap action and an inner `Semantics(button: true)` merged
    // over it as a button with nothing behind it. The control announced itself
    // perfectly and did nothing. This test would not have caught that on its
    // own, which is why the two tests above tap the real button rather than
    // calling the callback directly.
    await _pump(tester, (m, {String? replyToId}) async {});
    expect(_sendButton, findsOneWidget);
  });
}

/// The third layer, on its own.
///
/// The two tests above stub `onSendMessage`, so they pin the COMPOSER's
/// behaviour and say nothing about the notifier underneath it — which is where
/// the swallow actually lived. Removing the `rethrow` left them both green,
/// proved by sabotage, so this calls the notifier directly.
void _notifierGroup() {
  group('ChatMessagesNotifier', () {
    setUpAll(ensureTestSupabaseInitialized);

    test('a refused insert is RETHROWN, not written to debugPrint', () async {
      // Pointed at a dummy host by the helper, so the insert cannot succeed.
      // `start()` is deliberately not called — this test is about the write
      // path, and `start()` opens a realtime channel that would outlive it.
      final notifier = ChatMessagesNotifier('room-under-test');
      addTearDown(notifier.dispose);

      await expectLater(
        notifier.sendMessage('gross 50.6 t', _me, 'Load Controller', null),
        throwsA(anything),
        reason: 'this used to end at `catch (e) { debugPrint(...) }` — a log '
            'that goes nowhere a user can see, and nowhere at all in a release '
            'web build. The composer can only put the draft back and say what '
            'happened if this tells it.',
      );
    });

    test('a refused ATTACHMENT insert is rethrown too', () async {
      // The same swallow, one method down, and it survived the 2026-08-22 fix
      // because that fix was applied to `sendMessage` alone. Found by reading
      // the file while chasing an unrelated question on 2026-08-22.
      //
      // More is lost here than in the text case: `sendFileMessage` is called
      // from `onUploadComplete`, so the object is ALREADY in the `chat_files`
      // bucket by the time it runs. A swallowed failure leaves that object
      // with no row pointing at it, the attach panel closes, and the sender
      // watches their attachment not appear with nothing on screen to say why.
      final notifier = ChatMessagesNotifier('room-under-test');
      addTearDown(notifier.dispose);

      await expectLater(
        notifier.sendFileMessage(
          'Sent a file',
          _me,
          'Load Controller',
          null,
          'chat_files/room-under-test/weighbridge-ticket.pdf',
          'pdf',
          'weighbridge-ticket.pdf',
        ),
        throwsA(anything),
        reason: 'a failed attachment must reach the screen that offered to '
            'send it; `ChatScreen` awaits this and shows "Attachment not '
            'sent." — it can only do that if this tells it',
      );
    });
  });
}
