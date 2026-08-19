import 'dart:typed_data';
import 'package:flutter_application_1/features/chat/services/attachment_url.dart';

import 'package:uuid/uuid.dart';
import 'package:flutter_application_1/core/config/supabase_config.dart';
import 'package:flutter_application_1/features/chat/models/support_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Backend for the chat Support-ticket feature. Talks to support_* tables and
/// the support_* workflow RPCs (create/accept/complete/add_message).
class SupportService {
  final SupabaseClient _db = SupabaseConfig.client;

  String? get currentUserId => _db.auth.currentUser?.id;

  Future<bool> isSuperAdmin() async {
    final uid = currentUserId;
    if (uid == null) return false;
    final row = await _db
        .from('profiles')
        .select('platform_role')
        .eq('id', uid)
        .maybeSingle();
    final role = row?['platform_role'] as String?;
    return role != null && role.startsWith('superGlobalSerialAdmin');
  }

  Future<List<SupportTicket>> myTickets() async {
    final uid = currentUserId;
    if (uid == null) return const [];
    final rows = await _db
        .from('support_tickets')
        .select()
        .eq('created_by', uid)
        .order('updated_at', ascending: false);
    return (rows as List)
        .map((r) => SupportTicket.fromJson(Map<String, dynamic>.from(r as Map)))
        .toList();
  }

  Future<List<SupportTicket>> allTickets() async {
    final rows = await _db
        .from('support_tickets')
        .select()
        .order('updated_at', ascending: false);
    return (rows as List)
        .map((r) => SupportTicket.fromJson(Map<String, dynamic>.from(r as Map)))
        .toList();
  }

  Stream<SupportTicket?> ticketStream(String ticketId) {
    return _db
        .from('support_tickets')
        .stream(primaryKey: ['id'])
        .eq('id', ticketId)
        .map((rows) => rows.isEmpty
            ? null
            : SupportTicket.fromJson(Map<String, dynamic>.from(rows.first)));
  }

  Stream<List<SupportMessage>> messagesStream(String ticketId) {
    return _db
        .from('support_ticket_messages')
        .stream(primaryKey: ['id'])
        .eq('ticket_id', ticketId)
        .order('created_at', ascending: true)
        .map((rows) => rows
            .map((r) => SupportMessage.fromJson(Map<String, dynamic>.from(r)))
            .toList());
  }

  Stream<List<SupportEvent>> eventsStream(String ticketId) {
    return _db
        .from('support_ticket_events')
        .stream(primaryKey: ['id'])
        .eq('ticket_id', ticketId)
        .order('created_at', ascending: true)
        .map((rows) => rows
            .map((r) => SupportEvent.fromJson(Map<String, dynamic>.from(r)))
            .toList());
  }

  Future<List<SupportNotification>> notifications() async {
    final uid = currentUserId;
    if (uid == null) return const [];
    final rows = await _db
        .from('support_notifications')
        .select()
        .eq('user_id', uid)
        .order('created_at', ascending: false)
        .limit(20);
    return (rows as List)
        .map((r) =>
            SupportNotification.fromJson(Map<String, dynamic>.from(r as Map)))
        .toList();
  }

  Future<void> markNotifsRead(String ticketId) async {
    final uid = currentUserId;
    if (uid == null) return;
    await _db
        .from('support_notifications')
        .update({'read': true})
        .eq('user_id', uid)
        .eq('ticket_id', ticketId);
  }

  Future<String> createTicket(
      String subject, String category, String body) async {
    final id = await _db.rpc('support_create_ticket', params: {
      'p_subject': subject,
      'p_category': category,
      'p_body': body,
    });
    return id as String;
  }

  Future<void> acceptTicket(String ticketId, String actorName) =>
      _db.rpc('support_accept_ticket',
          params: {'p_ticket': ticketId, 'p_actor_name': actorName});

  Future<void> completeTicket(String ticketId, String actorName) =>
      _db.rpc('support_complete_ticket',
          params: {'p_ticket': ticketId, 'p_actor_name': actorName});

  Future<void> addMessage(
    String ticketId,
    String content,
    String senderName, {
    String? fileUrl,
    String? fileType,
    String? fileName,
  }) =>
      _db.rpc('support_add_message', params: {
        'p_ticket': ticketId,
        'p_content': content,
        'p_sender_name': senderName,
        if (fileUrl != null) 'p_file_url': fileUrl,
        if (fileType != null) 'p_file_type': fileType,
        if (fileName != null) 'p_file_name': fileName,
      });

  /// Uploads a ticket attachment (image or file) to the private
  /// `support-attachments` bucket under `{ticketId}/{uuid}.{ext}` and returns
  /// the **bucket-qualified object path** plus a coarse [type]
  /// ('image' | 'file') and the original file [name] for the bubble.
  ///
  /// P3-53 (client ruling 3, 2026-08-12): the bucket was public with no size
  /// limit and no MIME restriction — both an exposure and an abuse vector.
  /// Mirrors MessagingService.uploadAttachment, including that `url` is a path.
  Future<({String url, String type, String name})> uploadTicketAttachment({
    required Uint8List bytes,
    required String fileName,
    required String ticketId,
  }) async {
    final uid = currentUserId;
    if (uid == null) throw StateError('Not authenticated');
    final safeName = fileName.trim().isEmpty ? 'file' : fileName.trim();
    final ext =
        safeName.contains('.') ? safeName.split('.').last.toLowerCase() : '';
    const imageExts = {'png', 'jpg', 'jpeg', 'gif', 'webp', 'bmp', 'heic'};
    final isImage = imageExts.contains(ext);
    final path = '$ticketId/${const Uuid().v4()}${ext.isEmpty ? '' : '.$ext'}';
    await _db.storage.from('support-attachments').uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            contentType: _contentTypeFor(ext),
            upsert: false,
          ),
        );
    return (
      url: qualifiedAttachmentPath(kSupportAttachmentsBucket, path),
      type: isImage ? 'image' : 'file',
      name: safeName,
    );
  }

  static String _contentTypeFor(String ext) {
    switch (ext) {
      case 'png':
        return 'image/png';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      case 'bmp':
        return 'image/bmp';
      case 'heic':
        return 'image/heic';
      case 'pdf':
        return 'application/pdf';
      case 'txt':
        return 'text/plain';
      case 'csv':
        return 'text/csv';
      case 'doc':
      case 'docx':
        return 'application/msword';
      case 'xls':
      case 'xlsx':
        return 'application/vnd.ms-excel';
      default:
        return 'application/octet-stream';
    }
  }

  /// Super admins (for the inbox "who receives tickets" list), joined with
  /// their current receiving preference.
  Future<List<SupportAdmin>> inboxAdmins() async {
    final rows = await _db
        .from('profiles')
        .select('id, display_name, platform_role')
        .like('platform_role', 'superGlobalSerialAdmin%');
    final prefRows = await _db
        .from('support_inbox_prefs')
        .select('admin_id, receiving');
    final prefs = <String, bool>{};
    for (final p in (prefRows as List)) {
      prefs[p['admin_id'] as String] = p['receiving'] as bool? ?? true;
    }
    return (rows as List).map((r) {
      final m = Map<String, dynamic>.from(r as Map);
      final id = m['id'] as String;
      final name = (m['display_name'] as String?)?.trim();
      return SupportAdmin(
        id: id,
        name: name != null && name.isNotEmpty ? name : 'Admin',
        receiving: prefs[id] ?? true,
      );
    }).toList();
  }

  Future<void> setInbox(String adminId, bool receiving) async {
    await _db.from('support_inbox_prefs').upsert({
      'admin_id': adminId,
      'receiving': receiving,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'admin_id');
  }
}
