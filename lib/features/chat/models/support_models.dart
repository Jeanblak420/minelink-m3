// MineLink Chat — support ticket models (tables: support_tickets,
// support_ticket_messages, support_ticket_events, support_notifications).

import 'package:flutter_application_1/core/time/ml_time.dart';

class SupportTicket {
  final String id;
  final String createdBy;
  final String? companyId;
  final String subject;
  final String category;
  final String status; // 'sent' | 'in_progress' | 'completed'
  final String? acceptedBy;
  final String? acceptedByName;
  final DateTime createdAt;
  final DateTime updatedAt;

  const SupportTicket({
    required this.id,
    required this.createdBy,
    required this.companyId,
    required this.subject,
    required this.category,
    required this.status,
    required this.acceptedBy,
    required this.acceptedByName,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isOpen => status != 'completed';

  factory SupportTicket.fromJson(Map<String, dynamic> j) => SupportTicket(
        id: j['id'] as String,
        createdBy: j['created_by'] as String,
        companyId: j['company_id'] as String?,
        subject: j['subject'] as String? ?? '',
        category: j['category'] as String? ?? 'General',
        status: j['status'] as String? ?? 'sent',
        acceptedBy: j['accepted_by'] as String?,
        acceptedByName: j['accepted_by_name'] as String?,
        createdAt: MlTime.sast(DateTime.parse(j['created_at'] as String)),
        updatedAt: MlTime.sast(DateTime.parse(j['updated_at'] as String)),
      );
}

class SupportMessage {
  final String id;
  final String ticketId;
  final String senderId;
  final String senderName;
  final String content;
  final DateTime createdAt;
  final String? fileUrl;
  final String? fileType; // 'image' | 'file'
  final String? fileName;

  const SupportMessage({
    required this.id,
    required this.ticketId,
    required this.senderId,
    required this.senderName,
    required this.content,
    required this.createdAt,
    this.fileUrl,
    this.fileType,
    this.fileName,
  });

  factory SupportMessage.fromJson(Map<String, dynamic> j) => SupportMessage(
        id: j['id'] as String,
        ticketId: j['ticket_id'] as String,
        senderId: j['sender_id'] as String,
        senderName: j['sender_name'] as String? ?? '',
        content: j['content'] as String? ?? '',
        createdAt: MlTime.sast(DateTime.parse(j['created_at'] as String)),
        fileUrl: j['file_url'] as String?,
        fileType: j['file_type'] as String?,
        fileName: j['file_name'] as String?,
      );
}

class SupportEvent {
  final String id;
  final String ticketId;
  final String type; // 'sent' | 'accepted' | 'in_progress' | 'completed'
  final String? actorName;
  final DateTime createdAt;

  const SupportEvent({
    required this.id,
    required this.ticketId,
    required this.type,
    required this.actorName,
    required this.createdAt,
  });

  factory SupportEvent.fromJson(Map<String, dynamic> j) => SupportEvent(
        id: j['id'] as String,
        ticketId: j['ticket_id'] as String,
        type: j['type'] as String? ?? 'sent',
        actorName: j['actor_name'] as String?,
        createdAt: MlTime.sast(DateTime.parse(j['created_at'] as String)),
      );
}

class SupportNotification {
  final String id;
  final String ticketId;
  final String text;
  final bool read;
  final DateTime createdAt;

  const SupportNotification({
    required this.id,
    required this.ticketId,
    required this.text,
    required this.read,
    required this.createdAt,
  });

  factory SupportNotification.fromJson(Map<String, dynamic> j) =>
      SupportNotification(
        id: j['id'] as String,
        ticketId: j['ticket_id'] as String,
        text: j['text'] as String? ?? '',
        read: j['read'] as bool? ?? false,
        createdAt: MlTime.sast(DateTime.parse(j['created_at'] as String)),
      );
}

/// A super admin who can receive tickets (for the inbox toggle list).
class SupportAdmin {
  final String id;
  final String name;
  final bool receiving;
  const SupportAdmin(
      {required this.id, required this.name, required this.receiving});
}

const List<String> kSupportCategories = [
  'General',
  'Account & access',
  'Tokens & seats',
  'Organizations',
  'Requests & routes',
  'A bug or error',
  'Something else',
];
