import 'dart:typed_data';

import 'package:uuid/uuid.dart';
import 'package:flutter_application_1/core/config/supabase_config.dart';
import 'package:flutter_application_1/features/chat/services/attachment_url.dart';
import 'package:flutter_application_1/core/utils/logger.dart';
import 'package:flutter_application_1/features/chat/models/messaging_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Backend for the full MineLink chat feature. Talks to chat_rooms /
/// chat_messages / org_connections and the get_chat_contacts RPC.
class MessagingService {
  final SupabaseClient _db = SupabaseConfig.client;
  final Map<String, RealtimeChannel> _typingChannels = {};
  static final _log = LoggerFactory.getLogger('MessagingService');

  String? get currentUserId => _db.auth.currentUser?.id;

  /// Broadcasts a "typing" ping to each recipient's personal inbox topic
  /// (`typing-inbox:<recipientId>`) so the floating chat disc can show a typing
  /// indicator even when no thread is open. Mirrors the CPS typing inbox.
  Future<void> pingTyping(List<String> recipientUserIds, String name,
      {bool stop = false, String? roomId}) async {
    final uid = currentUserId;
    if (uid == null) return;
    for (final r in recipientUserIds) {
      if (r == uid || r.isEmpty) continue;
      var ch = _typingChannels[r];
      if (ch == null) {
        ch = _db.channel('typing-inbox:$r');
        ch.subscribe();
        _typingChannels[r] = ch;
      }
      try {
        await ch.sendBroadcastMessage(event: 'typing', payload: {
          'user_id': uid,
          'name': name,
          'stop': stop,
          // Lets the recipient's conversation list mark the exact room as
          // "typing…" (group rooms included), not just the sender.
          if (roomId != null) 'room_id': roomId,
        });
      } catch (e) {
        _log.d('typing ping to $r failed (best effort): $e');
      }
    }
  }

  // -------------------------------------------------------------------------
  // Contacts (company-scoped, grouped) via RPC
  // -------------------------------------------------------------------------
  Future<List<ChatContact>> getContacts() async {
    final uid = currentUserId;
    if (uid == null) return const [];
    final rows = await _db.rpc('get_chat_contacts', params: {'p_user_id': uid});
    return (rows as List)
        .map((r) => ChatContact.fromRpc(Map<String, dynamic>.from(r as Map)))
        .toList();
  }

  /// Resolves the current user's chat display name + avatar (best effort).
  Future<({String name, String? avatarUrl})> getMyIdentity() async {
    final uid = currentUserId;
    if (uid == null) return (name: 'Me', avatarUrl: null);
    String? name;
    String? avatar;
    try {
      final emp = await _db
          .from('employees')
          .select('first_name,last_name,profile_photo_url')
          .eq('user_id', uid)
          .maybeSingle();
      if (emp != null) {
        name = ('${emp['first_name'] ?? ''} ${emp['last_name'] ?? ''}').trim();
        avatar = emp['profile_photo_url'] as String?;
      }
    } catch (e) {
      _log.d('identity: employees lookup failed, trying fallbacks: $e');
    }
    if (name == null || name.isEmpty) {
      try {
        final comp = await _db
            .from('companies')
            .select('company_name,logo_url,ceo_first_name,ceo_last_name')
            .eq('user_id', uid)
            .maybeSingle();
        if (comp != null) {
          final ceo =
              ('${comp['ceo_first_name'] ?? ''} ${comp['ceo_last_name'] ?? ''}')
                  .trim();
          name = ceo.isNotEmpty ? ceo : comp['company_name'] as String?;
          avatar = comp['logo_url'] as String?;
        }
      } catch (e) {
        _log.d('identity: companies lookup failed, trying profiles: $e');
      }
    }
    if (name == null || name.isEmpty) {
      try {
        final prof = await _db
            .from('profiles')
            .select('display_name,email')
            .eq('id', uid)
            .maybeSingle();
        name = (prof?['display_name'] as String?)?.trim();
        if (name == null || name.isEmpty) {
          final email = prof?['email'] as String?;
          name = email != null && email.contains('@')
              ? email.split('@').first
              : 'Me';
        }
      } catch (_) {
        name = 'Me';
      }
    }
    return (name: name, avatarUrl: avatar);
  }

  // -------------------------------------------------------------------------
  // Conversations (rooms the current user belongs to)
  // -------------------------------------------------------------------------
  Future<List<ChatConversation>> getConversations() async {
    final uid = currentUserId;
    if (uid == null) return const [];
    // RPC returns per-room unread count + the latest message's read/delivered
    // state, already ordered newest-activity first.
    final rows = await _db.rpc('get_chat_conversations', params: {'p_user_id': uid});
    return (rows as List)
        .map((r) => ChatConversation.fromJson(Map<String, dynamic>.from(r as Map)))
        .toList();
  }

  /// Finds an existing 1:1 DM room with [otherUserId], or creates one.
  Future<ChatConversation> getOrCreateDm({
    required String otherUserId,
    required String otherDisplayName,
  }) async {
    final uid = currentUserId;
    if (uid == null) {
      throw StateError('Not authenticated');
    }
    final existing = await _db
        .from('chat_rooms')
        .select()
        .eq('type', 'dm')
        .contains('participant_ids', [uid, otherUserId]);
    for (final row in (existing as List)) {
      final conv = ChatConversation.fromJson(Map<String, dynamic>.from(row as Map));
      // Exactly this pair (guard against larger rooms that happen to contain both).
      if (conv.participantIds.toSet().length == 2 &&
          conv.participantIds.contains(uid) &&
          conv.participantIds.contains(otherUserId)) {
        // The stored `name` reflects whoever created the room; always show the
        // OTHER participant from this caller's perspective.
        return conv.copyWith(name: otherDisplayName);
      }
    }
    final inserted = await _db
        .from('chat_rooms')
        .insert({
          'name': otherDisplayName,
          'participant_ids': [uid, otherUserId],
          'type': 'dm',
          'created_by': uid,
        })
        .select()
        .single();
    return ChatConversation.fromJson(inserted).copyWith(name: otherDisplayName);
  }

  /// Creates an org-group chat across up to **three** companies, at most one
  /// of each org type (S8-3 / P10-08).
  ///
  /// Replaces a version that took `myCompanyId` and `otherCompanyId` and wrote
  /// `chat_rooms` directly — two columns, so a three-company group was
  /// **structurally impossible**, not merely unbuilt. Membership now lives in
  /// `chat_room_companies`, one row per company, and the org-type uniqueness
  /// is a database index rather than a hope.
  ///
  /// The caller's own company is always included and auto-accepted; the rest
  /// are invited, and their management is notified. Returns the room id.
  ///
  /// Every rule is enforced server-side by `create_org_group`, so a caller
  /// cannot assemble an invalid group by other means: at most three companies,
  /// at least two, one per org type, and only an owner / management / admin
  /// may commit their company to one.
  Future<String> createOrgGroup({
    required String name,
    required List<String> companyIds,
  }) async {
    final id = await _db.rpc('create_org_group', params: {
      'p_name': name.trim(),
      'p_company_ids': companyIds,
    });
    return id as String;
  }

  /// Accept or decline an invitation for the caller's company (S8-3).
  ///
  /// The inviter is notified either way — a decline that arrives as silence is
  /// indistinguishable from one that was never sent. Declining leaves the room
  /// unreadable to that company, so "decline" means something.
  Future<void> respondToOrgGroupInvite(String roomId, {required bool accept}) =>
      _db.rpc('respond_to_org_group_invite',
          params: {'p_room': roomId, 'p_accept': accept});

  /// Ends a conversation (S8-4 / P10-09). **Company account only** — not an
  /// admin, not management — or a super global admin for support.
  ///
  /// An ended room stays readable: ending a chat is not deleting the record of
  /// it. It simply accepts no further messages, enforced by
  /// `can_send_in_chat_room`, so the block holds whatever the UI does.
  Future<void> endChat(String roomId) =>
      _db.rpc('end_chat', params: {'p_room': roomId});

  /// Adds/removes a member from a room the current user manages.
  Future<void> setRoomMembers(String roomId, List<String> participantIds) async {
    await _db
        .from('chat_rooms')
        .update({'participant_ids': participantIds}).eq('id', roomId);
  }

  // -------------------------------------------------------------------------
  // Messages
  // -------------------------------------------------------------------------
  Future<List<ChatMessage>> getMessages(String roomId, {int limit = 200}) async {
    final rows = await _db
        .from('chat_messages')
        .select()
        .eq('chat_room_id', roomId)
        .order('timestamp', ascending: true)
        .limit(limit);
    return (rows as List)
        .map((r) => ChatMessage.fromJson(Map<String, dynamic>.from(r as Map)))
        .toList();
  }

  Future<ChatMessage> sendMessage({
    required String roomId,
    required String content,
    required String senderName,
    String? senderAvatarUrl,
    String? replyToId,
    List<ChatMention> mentions = const [],
    String? fileUrl,
    String? fileType,
    String? fileName,
  }) async {
    final uid = currentUserId;
    if (uid == null) throw StateError('Not authenticated');
    final now = DateTime.now().toUtc().toIso8601String();
    final inserted = await _db
        .from('chat_messages')
        .insert({
          'chat_room_id': roomId,
          'content': content,
          'sender_id': uid,
          'sender_name': senderName,
          'sender_avatar_url': senderAvatarUrl,
          'timestamp': now,
          'is_read': false,
          // delivered_at/read_at are set by the RECIPIENT (delivered when their
          // app receives it, read when they open the thread) — not the sender.
          'reply_to_id': replyToId,
          'mentions': mentions.map((m) => m.toJson()).toList(),
          'file_url': fileUrl,
          'file_type': fileType,
          'file_name': fileName,
        })
        .select()
        .single();
    // Room's last-message preview is bumped by the DB trigger
    // trg_chat_bump_last_message (SECURITY DEFINER) — no client update needed.
    return ChatMessage.fromJson(inserted);
  }

  /// Uploads an attachment (image or file) to the private `chat-attachments`
  /// bucket under `{roomId}/{uuid}.{ext}` and returns the **bucket-qualified
  /// object path** plus a coarse [type] ('image' | 'file') and the original
  /// file [name] for the bubble.
  ///
  /// P3-52 (client ruling 3, 2026-08-12): the bucket was public, so every file
  /// shared in company-to-company chat was readable by URL to anyone on the
  /// internet. `url` is no longer a URL — storing a signed one would give
  /// attachments that work until they silently expire. The path is persisted
  /// and signed at render by `resolveAttachmentUrl`.
  Future<({String url, String type, String name})> uploadAttachment({
    required Uint8List bytes,
    required String fileName,
    required String roomId,
  }) async {
    final uid = currentUserId;
    if (uid == null) throw StateError('Not authenticated');
    final safeName = fileName.trim().isEmpty ? 'file' : fileName.trim();
    final ext =
        safeName.contains('.') ? safeName.split('.').last.toLowerCase() : '';
    const imageExts = {'png', 'jpg', 'jpeg', 'gif', 'webp', 'bmp', 'heic'};
    final isImage = imageExts.contains(ext);
    final path = '$roomId/${const Uuid().v4()}${ext.isEmpty ? '' : '.$ext'}';
    await SupabaseConfig.client.storage.from('chat-attachments').uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            contentType: _contentTypeFor(ext),
            upsert: false,
          ),
        );
    return (
      url: qualifiedAttachmentPath(kChatAttachmentsBucket, path),
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

  /// Marks all inbound messages in [roomId] as read (and delivered) for the
  /// current user — called when they open/view the thread.
  Future<void> markRoomRead(String roomId) async {
    final uid = currentUserId;
    if (uid == null) return;
    // chat_messages has no RLS UPDATE policy, so a direct client `.update()`
    // silently affects 0 rows and read_at never persists (leaving the unread
    // count stuck). Mark read via the SECURITY DEFINER RPC — the same pattern
    // markAllDelivered() already uses for delivery receipts.
    try {
      await _db.rpc('chat_mark_room_read', params: {'p_room_id': roomId});
    } catch (_) {
      // Best-effort — read receipts degrade gracefully if the RPC is absent.
    }
  }

  /// Marks every inbound message the current user has NOT yet received as
  /// "delivered" (across all their rooms). Called when the chat surface is
  /// open, so the sender sees the delivered (double) tick even before the
  /// recipient opens that specific thread. Read stays separate.
  Future<void> markAllDelivered() async {
    final uid = currentUserId;
    if (uid == null) return;
    try {
      await _db.rpc('chat_mark_all_delivered');
    } catch (_) {
      // Best-effort — delivery ticks degrade gracefully if the RPC is absent.
    }
  }

  /// Realtime stream of all emoji reactions in a room (grouped per message in
  /// the UI).
  Stream<List<ChatReaction>> reactionsStream(String roomId) {
    return _db
        .from('chat_message_reactions')
        .stream(primaryKey: ['id'])
        .eq('room_id', roomId)
        .map((rows) => rows
            .map((r) => ChatReaction.fromJson(Map<String, dynamic>.from(r)))
            .toList());
  }

  /// Adds my [emoji] reaction to [messageId], or removes it if already present.
  Future<void> toggleReaction({
    required String roomId,
    required String messageId,
    required String emoji,
  }) async {
    final uid = currentUserId;
    if (uid == null) return;
    final existing = await _db
        .from('chat_message_reactions')
        .select('id')
        .eq('message_id', messageId)
        .eq('user_id', uid)
        .eq('emoji', emoji)
        .maybeSingle();
    if (existing != null) {
      await _db
          .from('chat_message_reactions')
          .delete()
          .eq('id', existing['id'] as String);
    } else {
      await _db.from('chat_message_reactions').insert({
        'room_id': roomId,
        'message_id': messageId,
        'user_id': uid,
        'emoji': emoji,
      });
    }
  }

  /// Realtime stream of the ordered message list for a room.
  Stream<List<ChatMessage>> streamMessages(String roomId) {
    return _db
        .from('chat_messages')
        .stream(primaryKey: ['id'])
        .eq('chat_room_id', roomId)
        .order('timestamp', ascending: true)
        .map((rows) => rows
            .map((r) => ChatMessage.fromJson(Map<String, dynamic>.from(r)))
            .toList());
  }

  // -------------------------------------------------------------------------
  // Org connections (super-admin)
  // -------------------------------------------------------------------------
  Future<List<OrgConnection>> getConnections() async {
    final rows = await _db.from('org_connections').select();
    return (rows as List)
        .map((r) => OrgConnection.fromJson(Map<String, dynamic>.from(r as Map)))
        .toList();
  }

  Future<void> grantConnection(String companyIdA, String companyIdB) async {
    final uid = currentUserId;
    final low = companyIdA.compareTo(companyIdB) < 0 ? companyIdA : companyIdB;
    final high = companyIdA.compareTo(companyIdB) < 0 ? companyIdB : companyIdA;
    final now = DateTime.now().toUtc().toIso8601String();
    await _db.from('org_connections').upsert({
      'company_low_id': low,
      'company_high_id': high,
      'status': 'granted',
      'granted_by': uid,
      'granted_at': now,
      'revoked_by': null,
      'revoked_at': null,
      'updated_at': now,
    }, onConflict: 'company_low_id,company_high_id');
  }

  Future<void> revokeConnection(String connectionId) async {
    final uid = currentUserId;
    final now = DateTime.now().toUtc().toIso8601String();
    await _db.from('org_connections').update({
      'status': 'revoked',
      'revoked_by': uid,
      'revoked_at': now,
      'updated_at': now,
    }).eq('id', connectionId);
  }
}
