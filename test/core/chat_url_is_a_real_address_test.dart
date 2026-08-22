// `/chat/:chatRoomId` has to open that chat.
//
// It did not. The router's builder was:
//
//     final chatArgs = state.extra as ChatScreenArgs?;
//     if (chatArgs == null) return const HomeTabBodyScreen();
//
// `ChatScreen` needs a whole `ChatScreenArgs` — the room, the signed-in user's
// id, name and avatar, and the participant list — and only the Communications
// hub supplies it, as `extra`, at the moment of the tap. `extra` does not
// survive a page load. So every other way of arriving at that URL got the
// WORKSPACE DASHBOARD, and `:chatRoomId` was parsed and thrown away.
//
// Driven in a browser as `roadhaul.admin` on 2026-08-22:
// `#/chat/24f1bef3-…` rendered "Dashboard · Signed in as Admin Test · Quick
// Actions" under a top bar reading **Chat**. A refresh, a bookmark, a pasted
// link and a notification deep link all land there.
//
// A silent substitution is the worst of the three possible behaviours: showing
// the chat is best, saying plainly that it could not be opened is acceptable,
// and showing a different screen while calling it Chat is neither.
//
// This reads the router source rather than mounting it, for the same reason
// `driver_can_reach_chat_test.dart` does: the route sits inside a `ShellRoute`
// that reaches for auth, the company, the employee record and Supabase before
// it decides anything, and a fixture deep enough to reach the builder would be
// a fixture that could agree with a broken one. The claim is narrow and
// structural — the id must be USED, and the fallback must not be a dashboard.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/core/routing/ml_route_title.dart';

String get _router =>
    File('lib/core/routing/app_router.dart').readAsStringSync();

/// The body of the `/chat/:chatRoomId` GoRoute builder.
String _chatRouteBuilder() {
  final src = _router;
  final start = src.indexOf("path: '/chat/:chatRoomId'");
  expect(start, greaterThan(-1),
      reason: 'the /chat/:chatRoomId route has moved or gone — re-point this '
          'test at it rather than deleting it');
  // As far as the next route declaration.
  final next = src.indexOf("path: '", start + 10);
  final body = src.substring(start, next < 0 ? src.length : next);
  // COMMENTS STRIPPED. The builder now carries a note explaining what it used
  // to do, and that note names `HomeTabBodyScreen()` — so a naive `contains`
  // matched the explanation of the bug and reported the bug.
  return body
      .split('\n')
      .where((l) => !l.trimLeft().startsWith('//'))
      .join('\n');
}

void main() {
  test('the route uses its own path parameter', () {
    final body = _chatRouteBuilder();
    expect(
      body.contains("state.pathParameters['chatRoomId']"),
      isTrue,
      reason: 'the room id in the URL is parsed and never read, so the URL is '
          'not an address — it is decoration on a screen chosen by `extra`',
    );
  });

  test('an arrival with no `extra` does not get a different screen', () {
    final body = _chatRouteBuilder();
    expect(
      body.contains('ChatRoomRoute('),
      isTrue,
      reason: 'the no-extra path should resolve the room from its id',
    );
    expect(
      body.contains('HomeTabBodyScreen()'),
      isFalse,
      reason: 'the no-extra path renders the WORKSPACE DASHBOARD under a top '
          'bar that says "Chat". Whatever replaces it may show the chat or may '
          'say it cannot — it must not show something else and call it Chat.',
    );
  });

  test('the top bar still calls it Chat', () {
    // The half that was never wrong, and the half that made the substitution
    // a lie rather than merely a gap.
    expect(mlRouteTitle(Uri.parse('/chat/room-1')).title, 'Chat');
  });

  test('the resolver says which state it is in, and never invents one', () {
    // Every branch of `ChatRoomRoute` is named here so that deleting one is a
    // visible change rather than a quiet one. The dangerous branch is the
    // last: a room this user cannot see must say so, not fall through to
    // something that looks like a working chat.
    final src =
        File('lib/features/chat/screens/chat_room_route.dart').readAsStringSync();
    for (final branch in const [
      'A linked company profile is required', // no company yet
      'CircularProgressIndicator', // still reading
      'Could not open this conversation', // the read failed
      'Conversation not available', // no such room, or not theirs
    ]) {
      expect(src.contains(branch), isTrue,
          reason: 'ChatRoomRoute no longer handles: $branch');
    }
    // …and it offers the way out of the two dead ends.
    expect(src.contains("context.go('/communications')"), isTrue);
  });

  test('access is not decided by the widget', () {
    // The room list comes from `communicationsProvider`, which is the same
    // query the hub uses and is scoped by RLS underneath. A room the user is
    // not a participant of is simply not in it. If this widget ever starts
    // fetching a room BY ID on its own, that reasoning stops holding.
    final src =
        File('lib/features/chat/screens/chat_room_route.dart').readAsStringSync();
    expect(src.contains('communicationsProvider'), isTrue);
    expect(
      src.contains('SupabaseConfig.client'),
      isFalse,
      reason: 'this widget should not reach the database directly — access is '
          'enforced by the provider it reads and by RLS under it',
    );
  });
}
