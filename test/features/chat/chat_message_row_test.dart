// Every column of `chat_messages` that a reader needs must arrive in the model.
//
// This file exists because of one silent defect, and it is written to catch
// the CLASS rather than the instance.
//
// `ChatScreen` captured a reply target, wrote `reply_to_id` on the insert, and
// then hand-built its `ChatMessage` from the returned row with a map literal
// that had no line for that column. So a reply was written to Postgres, read
// back over the wire, and dropped on the last step — arriving as an ordinary
// message. Nothing threw. Nothing logged. `.select()` with no argument had
// been returning the column the whole time. The sender saw "Replying to
// Thandi" above the composer, sent it, and the quote was simply not there.
//
// A missing line in a map literal is invisible by construction: it looks
// exactly like a field nobody wanted. So the mapping is a named factory now,
// and this asserts that the factory reads every column the app writes.
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/core/widgets/chat_widget.dart';

/// A `chat_messages` row with every column populated.
///
/// The column names and types are production's, read from the live schema on
/// 2026-08-22:
///
///   id uuid            chat_room_id uuid      content text
///   sender_id uuid     sender_name text       sender_avatar_url text
///   timestamp timestamptz               is_read boolean
///   file_url text      file_type text         file_name text
///   reply_to_id uuid   mentions jsonb         delivered_at timestamptz
///   read_at timestamptz
Map<String, dynamic> _fullRow() => {
      'id': 'msg-1',
      'chat_room_id': 'room-1',
      'content': 'Gate opens 05:00 tomorrow, not 06:00.',
      'sender_id': 'user-sipho',
      'sender_name': 'Sipho Radebe',
      'sender_avatar_url': 'signatures/sipho.png',
      'timestamp': '2026-08-22T05:00:00.000Z',
      'is_read': true,
      'file_url': 'chat_files/loading-plan.pdf',
      'file_type': 'pdf',
      'file_name': 'loading-plan-2026-08.pdf',
      'reply_to_id': 'msg-0',
      'mentions': const [],
      'delivered_at': '2026-08-22T05:00:01.000Z',
      'read_at': '2026-08-22T05:01:00.000Z',
    };

void main() {
  group('ChatMessage.fromRow', () {
    test('carries reply_to_id — the column that was silently dropped', () {
      final m = ChatMessage.fromRow(_fullRow());
      expect(
        m.replyToId,
        'msg-0',
        reason: 'A reply was written to the database and thrown away on the '
            'way back, so it rendered as an ordinary message. If this fails '
            'again, the quote has stopped being read — check the factory, not '
            'the widget.',
      );
    });

    test('carries every other column a reader uses', () {
      final m = ChatMessage.fromRow(_fullRow());
      expect(m.id, 'msg-1');
      expect(m.content, 'Gate opens 05:00 tomorrow, not 06:00.');
      expect(m.senderId, 'user-sipho');
      expect(m.senderName, 'Sipho Radebe');
      expect(m.senderAvatarUrl, 'signatures/sipho.png');
      expect(m.timestamp, DateTime.parse('2026-08-22T05:00:00.000Z'));
      expect(m.isRead, isTrue);
      expect(m.fileUrl, 'chat_files/loading-plan.pdf');
      expect(m.fileType, 'pdf');
      expect(m.fileName, 'loading-plan-2026-08.pdf');
      expect(m.hasAttachment, isTrue);
    });

    // The guard that generalises. A row is a Map, so a factory that forgets a
    // column cannot fail at compile time — only a list of what SHOULD be read
    // can notice. Nulling one column at a time and asserting the model changes
    // proves each is genuinely consumed rather than merely present in source.
    test('every consumed column actually reaches the model', () {
      const consumed = [
        'id',
        'content',
        'sender_id',
        'sender_name',
        'sender_avatar_url',
        'timestamp',
        'is_read',
        'file_url',
        'file_type',
        'file_name',
        'reply_to_id',
      ];
      final full = ChatMessage.fromRow(_fullRow());

      for (final column in consumed) {
        // `id`, `sender_id` and `timestamp` are non-null in Postgres and the
        // factory would throw rather than produce a different model, which is
        // itself proof they are read.
        if (column == 'id' || column == 'sender_id' || column == 'timestamp') {
          final row = _fullRow()..remove(column);
          expect(
            () => ChatMessage.fromRow(row),
            throwsA(anything),
            reason: '"$column" is NOT NULL in chat_messages, so dropping it '
                'must be loud rather than silent.',
          );
          continue;
        }

        final row = _fullRow()..[column] = null;
        final without = ChatMessage.fromRow(row);
        expect(
          _fingerprint(without),
          isNot(_fingerprint(full)),
          reason: 'Nulling "$column" changed nothing about the model, which '
              'means ChatMessage.fromRow never reads it. That is exactly how '
              '`reply_to_id` came to be written and never read.',
        );
      }
    });

    test('a row with no reply is not a reply', () {
      final row = _fullRow()..['reply_to_id'] = null;
      expect(ChatMessage.fromRow(row).replyToId, isNull);
    });

    test('tolerates the nullable columns being absent entirely', () {
      // PostgREST omits nothing today, but a narrowed `.select()` would — and
      // a model that throws on a narrowed select fails at run time only, on
      // whichever screen narrowed it.
      final m = ChatMessage.fromRow({
        'id': 'msg-2',
        'sender_id': 'user-thandi',
        'timestamp': '2026-08-22T05:00:00.000Z',
      });
      expect(m.content, '');
      expect(m.senderName, '');
      expect(m.replyToId, isNull);
      expect(m.isRead, isFalse);
      expect(m.hasAttachment, isFalse);
    });
  });
}

/// Everything the model exposes, as one comparable string.
String _fingerprint(ChatMessage m) => [
      m.id,
      m.content,
      m.senderId,
      m.senderName,
      m.senderAvatarUrl,
      m.timestamp.toIso8601String(),
      m.isRead,
      m.fileUrl,
      m.fileType,
      m.fileName,
      m.replyToId,
    ].join('|');
