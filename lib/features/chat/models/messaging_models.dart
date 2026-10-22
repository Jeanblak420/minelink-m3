/// MineLink full-chat data models — DM + group messaging with company scoping.
/// Backed by chat_rooms / chat_messages / org_connections / get_chat_contacts.
library;

import 'package:flutter_application_1/features/auth/models/user_type.dart';


/// Which contact group a [ChatContact] belongs to (drives section headers).
enum ContactGroupKind { myCompany, mineLink, connected, organization, unknown }

ContactGroupKind contactGroupKindFromString(String? v) {
  switch (v) {
    case 'my_company':
      return ContactGroupKind.myCompany;
    case 'mine_link':
      return ContactGroupKind.mineLink;
    case 'connected':
      return ContactGroupKind.connected;
    case 'organization':
      return ContactGroupKind.organization;
    default:
      return ContactGroupKind.unknown;
  }
}

/// A chattable person returned by the `get_chat_contacts` RPC, already scoped
/// and grouped per MineLink's company rules.
class ChatContact {
  final String userId;
  final String displayName;
  final String? avatarUrl;
  final String? companyId;
  final String? companyName;
  final String? orgType;
  final bool isSuperAdmin;
  final ContactGroupKind groupKind;
  final String groupLabel;
  final bool isBlocked;

  /// Why [isBlocked] is set: `org_revoked`, `token_expired` or `hierarchy`.
  /// Null when not blocked.
  ///
  /// The three are not interchangeable and must not share wording:
  ///
  /// * `org_revoked` — somebody else's decision; nothing the user can do.
  /// * `token_expired` — their own billing state, which they can fix.
  /// * `hierarchy` — the P10-07 chat hierarchy: this person is not theirs to
  ///   start a conversation with, and an admin is.
  ///
  /// Everything that was not `token_expired` used to fall through to "the
  /// connection between these organisations has been revoked". Told to a driver
  /// who simply may not DM another driver, that is not just unhelpful — it is
  /// false, and it points at a problem that does not exist.
  final String? blockReason;

  /// True when messaging is unavailable only because this company's token has
  /// lapsed — recoverable by renewing.
  bool get isBlockedByExpiry => blockReason == 'token_expired';

  /// True when the chat hierarchy, not a fault, is what stands in the way.
  bool get isBlockedByHierarchy => blockReason == 'hierarchy';

  /// What the profile panel's "Role" row reads.
  ///
  /// `get_chat_contacts` returns [role] for every contact — `owner` for a
  /// company account, the employee's `employees.role` otherwise, `member` when
  /// that is null — and the panel used to throw it away: everyone who was not
  /// a super admin read "Company member", under a row labelled *Role*. Seen on
  /// 2026-08-23 opening Controller Test's profile as ironhills.admin: a
  /// weighbridge controller, described as a member. The contacts list beside
  /// it had already grouped the same person under CONTROLLERS from the same
  /// field.
  ///
  /// Employee roles go through [UserRole.labelFor], so `controllerWB` reads
  /// "Load Controller" here exactly as it does on every other screen; an
  /// unknown wire value shows raw, by that helper's rule. `member` is the
  /// server's own "no role recorded", and keeps the old wording.
  String get roleLabel {
    if (isSuperAdmin) return 'Super Global Admin';
    final r = role?.trim() ?? '';
    if (r.isEmpty || r == 'member') return 'Company member';
    if (r == 'owner') return 'Company owner';
    return UserRole.labelFor(r);
  }

  /// What the pill next to the contact should read.
  String get blockedLabel {
    if (isBlockedByExpiry) return 'Renew to message';
    if (isBlockedByHierarchy) return 'Message an admin';
    return 'Blocked';
  }

  /// The hover explanation for that pill. An unrecognised reason falls back to
  /// the neutral sentence rather than claiming something specific and wrong —
  /// a reason added server-side before the client knows about it must degrade
  /// quietly.
  String get blockedTooltip {
    if (isBlockedByExpiry) {
      return 'Your token has expired, so you can only message MineLink. Renew '
          'it to message your team and connected companies again.';
    }
    if (isBlockedByHierarchy) {
      return 'Your role starts conversations with an admin, who can bring in '
          'whoever else is needed. They can message you directly at any time.';
    }
    if (blockReason == 'org_revoked') {
      return 'The connection between these organisations has been revoked.';
    }
    return 'You cannot start a conversation with this person.';
  }

  /// The person's role — used as the in-company "department" grouping in the
  /// Contacts tab ('owner' | 'admin' | 'management' | 'security' | 'driver' |
  /// 'controller…' | 'member').
  final String? role;

  /// Last activity time (from profiles.last_seen_at) — powers the CPS-style
  /// "Last seen X" presence line. Null = never active/logged in.
  final DateTime? lastSeenAt;

  const ChatContact({
    required this.userId,
    required this.displayName,
    this.avatarUrl,
    this.companyId,
    this.companyName,
    this.orgType,
    this.isSuperAdmin = false,
    this.groupKind = ContactGroupKind.unknown,
    this.groupLabel = '',
    this.isBlocked = false,
    this.blockReason,
    this.role,
    this.lastSeenAt,
  });

  factory ChatContact.fromRpc(Map<String, dynamic> j) => ChatContact(
        userId: j['user_id'] as String,
        displayName: (j['display_name'] as String?)?.trim().isNotEmpty == true
            ? (j['display_name'] as String).trim()
            : 'Unknown',
        avatarUrl: j['avatar_url'] as String?,
        companyId: j['company_id'] as String?,
        companyName: j['company_name'] as String?,
        orgType: j['org_type'] as String?,
        isSuperAdmin: (j['is_super_admin'] as bool?) ?? false,
        groupKind: contactGroupKindFromString(j['group_kind'] as String?),
        groupLabel: (j['group_label'] as String?) ?? '',
        isBlocked: (j['is_blocked'] as bool?) ?? false,
        blockReason: j['block_reason'] as String?,
        role: j['role'] as String?,
        lastSeenAt: j['last_seen_at'] != null
            ? DateTime.tryParse(j['last_seen_at'] as String)?.toUtc()
            : null,
      );
}

/// A mention embedded in a message (`chat_messages.mentions` jsonb array).
class ChatMention {
  final String userId;
  final String displayName;

  const ChatMention({required this.userId, required this.displayName});

  factory ChatMention.fromJson(Map<String, dynamic> j) => ChatMention(
        userId: j['user_id'] as String? ?? j['userId'] as String? ?? '',
        displayName:
            j['display_name'] as String? ?? j['displayName'] as String? ?? '',
      );

  Map<String, dynamic> toJson() =>
      {'user_id': userId, 'display_name': displayName};
}

/// A single chat message (row of `chat_messages`).
class ChatMessage {
  final String id;
  final String chatRoomId;
  final String content;
  final String senderId;
  final String senderName;
  final String? senderAvatarUrl;
  final DateTime timestamp;
  final bool isRead;
  final DateTime? deliveredAt;
  final DateTime? readAt;
  final String? replyToId;
  final String? fileUrl;
  final String? fileType;
  final String? fileName;
  final List<ChatMention> mentions;

  const ChatMessage({
    required this.id,
    required this.chatRoomId,
    required this.content,
    required this.senderId,
    required this.senderName,
    this.senderAvatarUrl,
    required this.timestamp,
    this.isRead = false,
    this.deliveredAt,
    this.readAt,
    this.replyToId,
    this.fileUrl,
    this.fileType,
    this.fileName,
    this.mentions = const [],
  });

  bool get hasAttachment => fileUrl != null && fileUrl!.isNotEmpty;

  factory ChatMessage.fromJson(Map<String, dynamic> j) {
    final rawMentions = j['mentions'];
    final mentions = <ChatMention>[];
    if (rawMentions is List) {
      for (final m in rawMentions) {
        if (m is Map) {
          mentions.add(ChatMention.fromJson(Map<String, dynamic>.from(m)));
        }
      }
    }
    return ChatMessage(
      id: j['id'] as String,
      chatRoomId: j['chat_room_id'] as String,
      content: j['content'] as String? ?? '',
      senderId: j['sender_id'] as String,
      senderName: j['sender_name'] as String? ?? '',
      senderAvatarUrl: j['sender_avatar_url'] as String?,
      timestamp: DateTime.parse(j['timestamp'] as String).toUtc(),
      isRead: (j['is_read'] as bool?) ?? false,
      deliveredAt: j['delivered_at'] != null
          ? DateTime.parse(j['delivered_at'] as String).toUtc()
          : null,
      readAt: j['read_at'] != null
          ? DateTime.parse(j['read_at'] as String).toUtc()
          : null,
      replyToId: j['reply_to_id'] as String?,
      fileUrl: j['file_url'] as String?,
      fileType: j['file_type'] as String?,
      fileName: j['file_name'] as String?,
      mentions: mentions,
    );
  }
}

/// Room kind mirrors chat_rooms.type.
enum ChatRoomType { dm, group, orgGroup }

ChatRoomType chatRoomTypeFromString(String? v) {
  switch (v) {
    case 'group':
      return ChatRoomType.group;
    case 'org_group':
      return ChatRoomType.orgGroup;
    default:
      return ChatRoomType.dm;
  }
}

String chatRoomTypeToString(ChatRoomType t) {
  switch (t) {
    case ChatRoomType.group:
      return 'group';
    case ChatRoomType.orgGroup:
      return 'org_group';
    case ChatRoomType.dm:
      return 'dm';
  }
}

/// A conversation (row of `chat_rooms`) with last-message preview.
class ChatConversation {
  final String id;
  final String name;
  final List<String> participantIds;
  final ChatRoomType type;
  final String? companyAId;
  final String? companyBId;
  final String? createdBy;
  final DateTime createdAt;
  final String? lastMessageContent;
  final DateTime? lastMessageTimestamp;
  final String? lastMessageSenderId;

  /// Unread inbound messages for the current user (0 when none).
  final int unreadCount;

  /// Read/delivered state of the room's latest message (for the list tick when
  /// that message was sent by me).
  final DateTime? lastMessageReadAt;
  final DateTime? lastMessageDeliveredAt;

  /// When the conversation was ended (S8-4). Null while it is still open.
  ///
  /// An ended room stays **readable** — ending a chat is not deleting the
  /// record of what two companies agreed. It simply accepts no new messages,
  /// which `can_send_in_chat_room()` enforces server-side, so the block holds
  /// whatever the UI does.
  final DateTime? endedAt;

  bool get isEnded => endedAt != null;

  /// Other `dm` rooms between the same two people, folded into this one by
  /// [collapseDuplicateDms]. Their messages are shown in this thread; new
  /// messages go to [id] only.
  final List<String> mergedRoomIds;

  /// Every room whose messages belong in this thread — [id] first.
  List<String> get allRoomIds => [id, ...mergedRoomIds];

  /// The family key for the message and reaction providers. Identical to [id]
  /// for an ordinary room, so nothing keyed by a plain room id changes.
  String get messagesKey => allRoomIds.join(',');

  const ChatConversation({
    required this.id,
    required this.name,
    required this.participantIds,
    this.type = ChatRoomType.dm,
    this.companyAId,
    this.companyBId,
    this.createdBy,
    required this.createdAt,
    this.lastMessageContent,
    this.lastMessageTimestamp,
    this.lastMessageSenderId,
    this.unreadCount = 0,
    this.lastMessageReadAt,
    this.lastMessageDeliveredAt,
    this.endedAt,
    this.mergedRoomIds = const [],
  });

  DateTime get sortKey => lastMessageTimestamp ?? createdAt;

  ChatConversation copyWith({
    String? name,
    int? unreadCount,
    List<String>? mergedRoomIds,
  }) =>
      ChatConversation(
        id: id,
        name: name ?? this.name,
        participantIds: participantIds,
        type: type,
        companyAId: companyAId,
        companyBId: companyBId,
        createdBy: createdBy,
        createdAt: createdAt,
        lastMessageContent: lastMessageContent,
        lastMessageTimestamp: lastMessageTimestamp,
        lastMessageSenderId: lastMessageSenderId,
        unreadCount: unreadCount ?? this.unreadCount,
        lastMessageReadAt: lastMessageReadAt,
        lastMessageDeliveredAt: lastMessageDeliveredAt,
        endedAt: endedAt,
        mergedRoomIds: mergedRoomIds ?? this.mergedRoomIds,
      );

  factory ChatConversation.fromJson(Map<String, dynamic> j) => ChatConversation(
        id: j['id'] as String,
        name: j['name'] as String? ?? '',
        participantIds: List<String>.from((j['participant_ids'] as List?) ?? const []),
        type: chatRoomTypeFromString(j['type'] as String?),
        companyAId: j['company_a_id'] as String?,
        companyBId: j['company_b_id'] as String?,
        createdBy: j['created_by'] as String?,
        createdAt: DateTime.parse(j['created_at'] as String).toUtc(),
        lastMessageContent: j['last_message_content'] as String?,
        lastMessageTimestamp: j['last_message_timestamp'] != null
            ? DateTime.parse(j['last_message_timestamp'] as String).toUtc()
            : null,
        lastMessageSenderId: j['last_message_sender_id'] as String?,
        unreadCount: (j['unread_count'] as num?)?.toInt() ?? 0,
        lastMessageReadAt: j['last_message_read_at'] != null
            ? DateTime.parse(j['last_message_read_at'] as String).toUtc()
            : null,
        lastMessageDeliveredAt: j['last_message_delivered_at'] != null
            ? DateTime.parse(j['last_message_delivered_at'] as String).toUtc()
            : null,
        endedAt: j['ended_at'] != null
            ? DateTime.parse(j['ended_at'] as String).toUtc()
            : null,
      );
}

/// Folds duplicate 1:1 rooms into one conversation per pair of people.
///
/// `chat_rooms` has no uniqueness rule for a DM pair, and opening a DM was a
/// check-then-insert, so a quick double tap could mint several rooms for the
/// same two people — production held three, created within 0.37 s on
/// 2026-10-21, only one of them with messages. Opening the chat then picked
/// whichever room the database returned first, so one device showed the
/// history and another an empty thread.
///
/// The surviving conversation is chosen the same way on every device: most
/// recent message first, then the oldest room, then the lowest id. The others
/// ride along in [ChatConversation.mergedRoomIds] so their history is still
/// shown. Groups, org groups and rooms that are not exactly two people are
/// passed through untouched. Order is otherwise preserved.
List<ChatConversation> collapseDuplicateDms(List<ChatConversation> rooms) {
  String? pairKey(ChatConversation c) {
    if (c.type != ChatRoomType.dm) return null;
    final people = c.participantIds.toSet().toList()..sort();
    return people.length == 2 ? people.join('|') : null;
  }

  int preference(ChatConversation a, ChatConversation b) {
    final am = a.lastMessageTimestamp, bm = b.lastMessageTimestamp;
    if (am != null || bm != null) {
      if (am == null) return 1;
      if (bm == null) return -1;
      final byMessage = bm.compareTo(am);
      if (byMessage != 0) return byMessage;
    }
    final byAge = a.createdAt.compareTo(b.createdAt);
    return byAge != 0 ? byAge : a.id.compareTo(b.id);
  }

  final groups = <String, List<ChatConversation>>{};
  for (final c in rooms) {
    final key = pairKey(c);
    if (key != null) (groups[key] ??= []).add(c);
  }

  final canonical = <String, ChatConversation>{};
  groups.forEach((key, members) {
    if (members.length < 2) return;
    final sorted = [...members]..sort(preference);
    final keep = sorted.first;
    canonical[key] = keep.copyWith(
      unreadCount: members.fold<int>(0, (n, c) => n + c.unreadCount),
      mergedRoomIds: [for (final c in sorted.skip(1)) c.id],
    );
  });

  final out = <ChatConversation>[];
  final emitted = <String>{};
  for (final c in rooms) {
    final key = pairKey(c);
    final folded = key == null ? null : canonical[key];
    if (folded == null) {
      out.add(c);
    } else if (emitted.add(key!)) {
      // Placed where the group's newest member stood, which in a
      // newest-first list is where the canonical room belongs.
      out.add(folded);
    }
  }
  return out;
}

/// An emoji reaction on a chat message (row of `chat_message_reactions`).
class ChatReaction {
  final String id;
  final String messageId;
  final String userId;
  final String emoji;

  const ChatReaction({
    required this.id,
    required this.messageId,
    required this.userId,
    required this.emoji,
  });

  factory ChatReaction.fromJson(Map<String, dynamic> j) => ChatReaction(
        id: j['id'] as String,
        messageId: j['message_id'] as String,
        userId: j['user_id'] as String,
        emoji: j['emoji'] as String? ?? '',
      );
}

/// An org-to-org connection (row of `org_connections`).
class OrgConnection {
  final String id;
  final String companyLowId;
  final String companyHighId;
  final String status; // 'granted' | 'revoked'
  final DateTime? grantedAt;
  final DateTime? revokedAt;

  const OrgConnection({
    required this.id,
    required this.companyLowId,
    required this.companyHighId,
    required this.status,
    this.grantedAt,
    this.revokedAt,
  });

  bool get isRevoked => status == 'revoked';

  factory OrgConnection.fromJson(Map<String, dynamic> j) => OrgConnection(
        id: j['id'] as String,
        companyLowId: j['company_low_id'] as String,
        companyHighId: j['company_high_id'] as String,
        status: j['status'] as String? ?? 'granted',
        grantedAt: j['granted_at'] != null
            ? DateTime.parse(j['granted_at'] as String).toUtc()
            : null,
        revokedAt: j['revoked_at'] != null
            ? DateTime.parse(j['revoked_at'] as String).toUtc()
            : null,
      );
}
