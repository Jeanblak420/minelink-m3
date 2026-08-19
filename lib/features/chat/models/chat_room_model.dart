import 'package:flutter_application_1/core/widgets/avatar_stack.dart';

class ChatRoom {
  final String id;
  final String name;
  final List<String> participantIds;
  final DateTime createdAt;
  final String? lastMessageContent;
  final DateTime? lastMessageTimestamp;
  final String? lastMessageSenderId;

  const ChatRoom({
    required this.id,
    required this.name,
    required this.participantIds,
    required this.createdAt,
    this.lastMessageContent,
    this.lastMessageTimestamp,
    this.lastMessageSenderId,
  });

  factory ChatRoom.fromJson(Map<String, dynamic> json) {
    return ChatRoom(
      id: json['id'] as String,
      name: json['name'] as String,
      participantIds: List<String>.from(json['participant_ids'] as List),
      createdAt: DateTime.parse(json['created_at'] as String),
      lastMessageContent: json['last_message_content'] as String?,
      lastMessageTimestamp: json['last_message_timestamp'] != null
          ? DateTime.parse(json['last_message_timestamp'] as String)
          : null,
      lastMessageSenderId: json['last_message_sender_id'] as String?,
    );
  }
}

class ChatScreenArgs {
  final ChatRoom chatRoom;
  final String currentUserId;
  final String currentUserName;
  final String? currentUserAvatarUrl;
  final List<AvatarUser> participants;

  const ChatScreenArgs({
    required this.chatRoom,
    required this.currentUserId,
    required this.currentUserName,
    this.currentUserAvatarUrl,
    required this.participants,
  });
}

class ChatContactOption {
  final String userId;
  final String displayName;
  final String? subtitle;
  final String? avatarUrl;

  const ChatContactOption({
    required this.userId,
    required this.displayName,
    this.subtitle,
    this.avatarUrl,
  });
}
