// S9-4 — support tickets and the chat room model, neither of which had a test.
//
// Two things here are worth pinning rather than merely covering.
//
// 1. `SupportTicket.status` is a free `String` on the Dart side but a CHECK
//    constraint in Postgres. The constraint was read off the live project on
//    2026-08-15 and is mirrored in `kServerTicketStatuses`, so a status added
//    on one side without the other has somewhere to fail.
//
// 2. `isOpen` is `status != 'completed'`, which means an UNRECOGNISED status
//    counts as open. That is the safe direction — a ticket nobody can classify
//    stays in the inbox rather than vanishing from it — and the test below
//    records it as a decision rather than leaving it to be rediscovered.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/features/chat/models/support_models.dart';
import 'package:flutter_application_1/features/chat/models/chat_room_model.dart';

/// `support_tickets_status_check` on the live project.
const List<String> kServerTicketStatuses = ['sent', 'in_progress', 'completed'];

SupportTicket ticket(Map<String, dynamic> extra) => SupportTicket.fromJson({
      'id': 'tk-1',
      'created_by': 'u-1',
      'created_at': '2026-08-15T08:00:00Z',
      'updated_at': '2026-08-15T08:00:00Z',
      ...extra,
    });

void main() {
  group('SupportTicket.isOpen', () {
    test('every server status except completed is open', () {
      for (final s in kServerTicketStatuses) {
        expect(ticket({'status': s}).isOpen, s != 'completed',
            reason: 'status "$s"');
      }
    });

    test('an unrecognised status stays open rather than disappearing', () {
      expect(ticket({'status': 'escalated'}).isOpen, isTrue);
      expect(ticket({'status': ''}).isOpen, isTrue);
    });

    test('a missing status defaults to sent, which is open', () {
      final t = ticket({});
      expect(t.status, 'sent');
      expect(t.isOpen, isTrue);
    });
  });

  group('SupportTicket.fromJson', () {
    test('a company-less ticket is allowed — support predates a company', () {
      expect(ticket({'company_id': null}).companyId, isNull);
    });

    test('blank subject and category fall back rather than render empty', () {
      final t = ticket({});
      expect(t.subject, '');
      expect(t.category, 'General');
    });

    test('an unaccepted ticket carries null acceptor fields', () {
      final t = ticket({'status': 'sent'});
      expect(t.acceptedBy, isNull);
      expect(t.acceptedByName, isNull);
    });

    test('timestamps are converted to local time', () {
      final t = ticket({'created_at': '2026-08-15T08:00:00Z'});
      expect(t.createdAt.isUtc, isFalse,
          reason: 'the inbox sorts and stamps in the reader\'s timezone');
      expect(t.createdAt.toUtc(), DateTime.utc(2026, 8, 15, 8));
    });
  });

  group('kSupportCategories — the picker feeding ticket.category', () {
    test('is non-empty and starts with the default', () {
      expect(kSupportCategories, isNotEmpty);
      expect(kSupportCategories.first, 'General',
          reason: 'fromJson falls back to "General", so it must be offered');
    });

    test('has no duplicates', () {
      expect(kSupportCategories.toSet().length, kSupportCategories.length);
    });

    test('the fromJson fallback is a category a user could have picked', () {
      expect(kSupportCategories, contains(ticket({}).category));
    });
  });

  group('SupportMessage / SupportEvent / SupportNotification', () {
    test('a text-only message has no attachment fields', () {
      final m = SupportMessage.fromJson({
        'id': 'm1',
        'ticket_id': 'tk-1',
        'sender_id': 'u-1',
        'content': 'Cannot sign in',
        'created_at': '2026-08-15T08:00:00Z',
      });
      expect(m.senderName, '');
      expect(m.fileUrl, isNull);
      expect(m.fileType, isNull);
      expect(m.content, 'Cannot sign in');
    });

    test('an attachment carries url, type and name together', () {
      final m = SupportMessage.fromJson({
        'id': 'm2',
        'ticket_id': 'tk-1',
        'sender_id': 'u-1',
        'sender_name': 'Jean',
        'content': '',
        'file_url': 'https://example.invalid/a.png',
        'file_type': 'image',
        'file_name': 'a.png',
        'created_at': '2026-08-15T08:00:00Z',
      });
      expect(m.fileType, 'image');
      expect(m.fileName, 'a.png');
      expect(m.content, '');
    });

    test('an event defaults its type to sent', () {
      final e = SupportEvent.fromJson({
        'id': 'e1',
        'ticket_id': 'tk-1',
        'created_at': '2026-08-15T08:00:00Z',
      });
      expect(e.type, 'sent');
      expect(e.actorName, isNull);
    });

    test('a notification defaults to unread', () {
      final n = SupportNotification.fromJson({
        'id': 'n1',
        'ticket_id': 'tk-1',
        'created_at': '2026-08-15T08:00:00Z',
      });
      expect(n.read, isFalse,
          reason: 'defaulting to read would hide a notification nobody saw');
      expect(n.text, '');
    });

    test('an explicitly read notification stays read', () {
      final n = SupportNotification.fromJson({
        'id': 'n1',
        'ticket_id': 'tk-1',
        'read': true,
        'created_at': '2026-08-15T08:00:00Z',
      });
      expect(n.read, isTrue);
    });
  });

  group('ChatRoom.fromJson', () {
    test('reads a room with a last message', () {
      final r = ChatRoom.fromJson({
        'id': 'r1',
        'name': 'Iron Hills · Roadhaul',
        'participant_ids': ['u1', 'u2'],
        'created_at': '2026-08-15T08:00:00Z',
        'last_message_content': 'Truck at the gate',
        'last_message_timestamp': '2026-08-15T09:00:00Z',
        'last_message_sender_id': 'u2',
      });
      expect(r.participantIds, ['u1', 'u2']);
      expect(r.lastMessageContent, 'Truck at the gate');
      expect(r.lastMessageSenderId, 'u2');
    });

    test('a room with no messages yet carries nulls, not empty strings', () {
      final r = ChatRoom.fromJson({
        'id': 'r1',
        'name': 'New room',
        'participant_ids': <String>[],
        'created_at': '2026-08-15T08:00:00Z',
      });
      expect(r.lastMessageContent, isNull);
      expect(r.lastMessageTimestamp, isNull);
      expect(r.participantIds, isEmpty);
    });

    test('a dynamic participant list is narrowed to List<String>', () {
      final r = ChatRoom.fromJson({
        'id': 'r1',
        'name': 'Group',
        'participant_ids': <dynamic>['u1', 'u2', 'u3'],
        'created_at': '2026-08-15T08:00:00Z',
      });
      expect(r.participantIds, isA<List<String>>());
      expect(r.participantIds, ['u1', 'u2', 'u3']);
    });

    test('a non-String participant fails HERE, at the JSON boundary', () {
      // `List<String>.from` validates eagerly. A lazy `.cast<String>()` would
      // construct happily and then throw somewhere inside the chat dock, far
      // from the malformed row that caused it. The first version of this test
      // asserted only `isA<List<String>>()` and length — which a lazy cast
      // also satisfies, so it distinguished nothing. Found by mutating the
      // model and watching the test stay green.
      expect(
        () => ChatRoom.fromJson({
          'id': 'r1',
          'name': 'Group',
          'participant_ids': <dynamic>['u1', 2, 'u3'],
          'created_at': '2026-08-15T08:00:00Z',
        }),
        throwsA(isA<TypeError>()),
      );
    });
  });
}
