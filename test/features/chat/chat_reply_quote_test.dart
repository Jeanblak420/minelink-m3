// The reply quote, as a thing you can see and tap.
//
// `chat_message_row_test.dart` proves the column survives the trip from
// Postgres into the model. This proves the model reaches the screen — the
// other half of the same defect, and the half a user would have described as
// "replying does nothing".
//
// Fonts are loaded because two of these assert on TRUNCATION, and
// `flutter test` otherwise renders in a fallback whose glyphs are one em wide
// — CLAUDE.md §7 and §10.5. A clamp measured against the wrong metrics is not
// a measurement.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/core/theme/app_theme.dart';
import 'package:flutter_application_1/core/widgets/chat_widget.dart';

import '../../test_helpers/real_fonts.dart';

const _me = 'user-me';

ChatMessage _msg(
  String id,
  String content, {
  String sender = 'user-thandi',
  String senderName = 'Thandi Mokoena',
  String? replyToId,
  String? fileName,
}) =>
    ChatMessage(
      id: id,
      content: content,
      senderId: sender,
      senderName: senderName,
      timestamp: DateTime.utc(2026, 8, 22, 5),
      replyToId: replyToId,
      fileUrl: fileName == null ? null : 'chat_files/$fileName',
      fileType: fileName == null ? null : 'pdf',
      fileName: fileName,
    );

Future<void> _pump(
  WidgetTester tester,
  List<ChatMessage> messages, {
  Size size = const Size(900, 1400),
  Brightness brightness = Brightness.dark,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.build(brightness),
      home: Scaffold(
        body: ChatWidget(
          messages: messages,
          currentUserId: _me,
          onSendMessage: (_, {String? replyToId}) {},
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// The quote block, found by the semantics the widget gives it.
Finder _quoteFor(String senderName) => find.bySemanticsLabel(
      RegExp('Replying to $senderName\\. Show the original message\\.'),
    );

void main() {
  setUpAll(loadRealFonts);

  testWidgets('a reply renders the original it answers', (tester) async {
    await _pump(tester, [
      _msg('m-1', 'Gate opens 05:00 tomorrow, not 06:00.'),
      _msg('m-2', 'Understood. Two trucks moved to 05:00.',
          sender: _me, senderName: 'Fixture Operator', replyToId: 'm-1'),
    ]);

    expect(
      _quoteFor('Thandi Mokoena'),
      findsOneWidget,
      reason: 'The reply carries `replyToId` and its original is in the '
          'thread, so the bubble must show what it is answering. This is the '
          'defect itself: for the life of this screen the id was written to '
          'the database and never drawn.',
    );
    // The original's words appear TWICE now — once as its own bubble, once
    // quoted inside the reply.
    expect(find.text('Gate opens 05:00 tomorrow, not 06:00.'), findsNWidgets(2));
  });

  testWidgets('an ordinary message renders no quote', (tester) async {
    await _pump(tester, [
      _msg('m-1', 'Gate opens 05:00 tomorrow, not 06:00.'),
      _msg('m-2', 'Understood.', sender: _me, senderName: 'Fixture Operator'),
    ]);

    expect(_quoteFor('Thandi Mokoena'), findsNothing);
    expect(find.text('Gate opens 05:00 tomorrow, not 06:00.'), findsOneWidget);
  });

  testWidgets('a quote of an attachment previews the file, not empty space',
      (tester) async {
    await _pump(tester, [
      _msg('m-1', '', fileName: 'loading-plan-2026-08.pdf'),
      _msg('m-2', 'Received, thank you.',
          sender: _me, senderName: 'Fixture Operator', replyToId: 'm-1'),
    ]);

    expect(_quoteFor('Thandi Mokoena'), findsOneWidget);
    expect(
      find.text('📎 loading-plan-2026-08.pdf'),
      findsOneWidget,
      reason: 'A message with no words is still answerable. Quoting it as an '
          'empty bar tells the reader nothing about what was replied to.',
    );
  });

  testWidgets('a reply whose original is gone renders without a quote, '
      'rather than throwing', (tester) async {
    // `chat_messages.reply_to_id` is `ON DELETE SET NULL`, so this is normally
    // the column going null — but a narrowed window, or a row deleted between
    // the read and the render, can leave an id pointing at nothing.
    await _pump(tester, [
      _msg('m-2', 'Received, thank you.',
          sender: _me, senderName: 'Fixture Operator', replyToId: 'm-gone'),
    ]);

    expect(tester.takeException(), isNull);
    expect(_quoteFor('Thandi Mokoena'), findsNothing);
    expect(find.text('Received, thank you.'), findsOneWidget);
  });

  testWidgets('a long original is clamped, not run at full length',
      (tester) async {
    const long =
        'The interlink is at the weighbridge now and the tare is captured, '
        'so he only needs the gross once the pile is loaded and the seals '
        'are on, which should be about twenty minutes from now at the most.';
    await _pump(tester, [
      _msg('m-1', long),
      _msg('m-2', 'Understood.',
          sender: _me, senderName: 'Fixture Operator', replyToId: 'm-1'),
    ]);

    // The quote preview clamps at 80 characters plus an ellipsis; the bubble
    // itself shows the whole thing. Finding the full string exactly once is
    // what says the quote is NOT repeating it in full.
    expect(find.text(long), findsOneWidget);
    expect(find.textContaining('…'), findsWidgets);
    expect(_quoteFor('Thandi Mokoena'), findsOneWidget);
  });

  testWidgets('a mention token is previewed as a name, not as its raw token',
      (tester) async {
    // Both chat surfaces read `chat_messages`, and the dock writes mentions
    // into `content` as `@[Name](user:id)`. Rendered raw in a quote that reads
    // as machinery.
    await _pump(tester, [
      _msg('m-1', 'Morning @[Thandi Mokoena](user:user-thandi) — 06:00?'),
      _msg('m-2', 'Confirmed.',
          sender: _me, senderName: 'Fixture Operator', replyToId: 'm-1'),
    ]);

    expect(find.textContaining('user:user-thandi'), findsNothing,
        reason: 'Neither the bubble nor the quote may show the raw token. The '
            'bubble draws it as a chip; the quote strips it to a plain '
            '@Display, as the dock does for its own previews.');
    // The quote's flattened preview.
    expect(find.text('Morning @Thandi Mokoena — 06:00?'), findsOneWidget);
    // The bubble's chip.
    expect(find.text('@Thandi Mokoena'), findsOneWidget);
  });

  testWidgets('tapping a quote is offered as a button to a screen reader',
      (tester) async {
    await _pump(tester, [
      _msg('m-1', 'Gate opens 05:00 tomorrow, not 06:00.'),
      _msg('m-2', 'Understood.',
          sender: _me, senderName: 'Fixture Operator', replyToId: 'm-1'),
    ]);

    final handle = tester.ensureSemantics();
    expect(_quoteFor('Thandi Mokoena'), findsOneWidget);
    // Tapping must reach the original without throwing. On a thread this short
    // the original is already on screen, so this asserts the gesture is wired
    // and safe rather than that the viewport moved.
    await tester.tap(_quoteFor('Thandi Mokoena'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    handle.dispose();
  });
}
