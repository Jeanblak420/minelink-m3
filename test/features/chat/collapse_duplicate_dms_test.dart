// One conversation per pair of people, on every device.
//
// Production on 2026-10-22 held THREE `dm` rooms between the same two people,
// created by one user within 0.37 s (a check-then-insert raced against itself).
// Only one of them had any messages. Opening the chat picked whichever room
// the database happened to return first, so one device showed the history and
// another showed an empty thread. These tests pin the rule that replaces that
// lottery: duplicates fold into one conversation, the canonical room is chosen
// the same way everywhere, and no room's history is left behind.

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/features/chat/models/messaging_models.dart';

final _t0 = DateTime.utc(2026, 10, 21, 23, 53, 31);

ChatConversation _room(
  String id, {
  List<String> people = const ['jean', 'bryson'],
  ChatRoomType type = ChatRoomType.dm,
  Duration createdAfter = Duration.zero,
  DateTime? lastMessageAt,
  int unread = 0,
}) =>
    ChatConversation(
      id: id,
      name: 'Bryson Mansoor',
      participantIds: people,
      type: type,
      createdAt: _t0.add(createdAfter),
      lastMessageTimestamp: lastMessageAt,
      unreadCount: unread,
    );

void main() {
  test('the production shape: three rooms, one with the message, fold to one',
      () {
    final withMessage = _room('c',
        createdAfter: const Duration(milliseconds: 372),
        lastMessageAt: DateTime.utc(2026, 10, 22, 19));
    final out = collapseDuplicateDms([
      _room('a'),
      _room('b', createdAfter: const Duration(milliseconds: 127)),
      withMessage,
    ]);

    expect(out, hasLength(1));
    expect(out.single.id, 'c',
        reason: 'the room holding the history is where new messages go');
    expect(out.single.allRoomIds.toSet(), {'a', 'b', 'c'},
        reason: 'every duplicate is still read, so no history is hidden');
  });

  test('the choice does not depend on the order the database returned', () {
    final rooms = [
      _room('a', lastMessageAt: DateTime.utc(2026, 10, 1)),
      _room('b', lastMessageAt: DateTime.utc(2026, 10, 5)),
      _room('c'),
    ];
    final ids = {
      for (final order in [
        [0, 1, 2], [2, 1, 0], [1, 2, 0], [2, 0, 1],
      ])
        collapseDuplicateDms([for (final i in order) rooms[i]]).single.id,
    };
    expect(ids, {'b'});
  });

  test('with no messages anywhere, the oldest room wins, then the lowest id',
      () {
    expect(
      collapseDuplicateDms([
        _room('z', createdAfter: const Duration(seconds: 1)),
        _room('y'),
      ]).single.id,
      'y',
    );
    expect(collapseDuplicateDms([_room('q'), _room('p')]).single.id, 'p');
  });

  test('unread counts of the folded rooms add up', () {
    final out = collapseDuplicateDms([_room('a', unread: 2), _room('b', unread: 3)]);
    expect(out.single.unreadCount, 5);
  });

  test('participant order does not make two pairs', () {
    final out = collapseDuplicateDms([
      _room('a', people: ['jean', 'bryson']),
      _room('b', people: ['bryson', 'jean']),
    ]);
    expect(out, hasLength(1));
  });

  test('different people, groups and org groups are never folded', () {
    final out = collapseDuplicateDms([
      _room('a'),
      _room('b', people: ['jean', 'cash']),
      _room('g1', type: ChatRoomType.group, people: ['jean', 'bryson']),
      _room('g2', type: ChatRoomType.group, people: ['jean', 'bryson']),
      _room('o', type: ChatRoomType.orgGroup, people: ['jean']),
    ]);
    expect(out.map((c) => c.id), ['a', 'b', 'g1', 'g2', 'o']);
    expect(out.every((c) => c.mergedRoomIds.isEmpty), isTrue);
  });

  test('the list keeps its newest-activity-first order', () {
    final out = collapseDuplicateDms([
      _room('new', people: ['jean', 'cash'],
          lastMessageAt: DateTime.utc(2026, 10, 22)),
      _room('a'),
      _room('b', lastMessageAt: DateTime.utc(2026, 10, 10)),
    ]);
    expect(out.map((c) => c.id), ['new', 'b']);
  });

  test('a single room carries only itself', () {
    final c = collapseDuplicateDms([_room('solo')]).single;
    expect(c.allRoomIds, ['solo']);
    expect(c.messagesKey, 'solo',
        reason: 'single rooms keep their old provider key');
  });
}
