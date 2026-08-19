import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:flutter_application_1/core/config/supabase_config.dart';
import 'package:flutter_application_1/features/chat/models/messaging_models.dart';
import 'package:flutter_application_1/features/chat/services/messaging_service.dart';

/// Singleton messaging backend.
final messagingServiceProvider = Provider<MessagingService>((ref) {
  return MessagingService();
});

/// Global delivery marker (matches CPS's MessageDeliveryService).
///
/// While the app is running and the user is online, every INBOUND message is
/// marked **delivered** the instant it arrives (Supabase Realtime INSERT) plus a
/// periodic sweep — independent of whether any chat is open. "Delivered" =
/// "their app received it". **Read** is a separate thing set ONLY when the
/// recipient opens the actual conversation thread (see `markRoomRead`), so
/// opening the chat window / conversation list never marks anything read.
///
/// Kept alive by the always-mounted ChatDock via `ref.watch`.
final chatDeliveryProvider = Provider<void>((ref) {
  final svc = ref.watch(messagingServiceProvider);
  final uid = svc.currentUserId;
  if (uid == null) return;
  Timer? debounce;
  void markSoon() {
    debounce?.cancel();
    debounce =
        Timer(const Duration(milliseconds: 200), () => svc.markAllDelivered());
  }

  svc.markAllDelivered();

  // The sweep is a SAFETY NET for a realtime INSERT that never arrived — the
  // listener below is the actual mechanism, and it marks within 200 ms.
  //
  // It ran every 5 SECONDS, unconditionally, for the life of every open tab.
  // Measured in the browser against the release build: 25 `chat_mark_all_
  // delivered` calls on one page view, and the ChatDock that keeps this alive
  // is mounted on every portal screen. That is 12 round trips a minute per
  // tab per signed-in user, forever — and the RPC is not a read. It is
  // `update chat_messages set delivered_at = now() where delivered_at is
  // null and ...`, so each one opens a write transaction and, without the
  // partial index added alongside this change, scanned the table to decide it
  // had nothing to do.
  //
  // Sixty seconds is the same safety net. A delivery tick that resolves within
  // a minute of a dropped realtime event is well inside what anyone notices,
  // and the overwhelmingly common case — realtime working — is unaffected,
  // because the listener has already marked the message before the sweep runs.
  const sweepInterval = Duration(seconds: 60);
  final sweep =
      Timer.periodic(sweepInterval, (_) => svc.markAllDelivered());
  final ch = SupabaseConfig.client.channel('chat-delivery:$uid')
    ..onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'chat_messages',
      callback: (payload) {
        if (payload.newRecord['sender_id'] != uid) markSoon();
      },
    )
    ..subscribe();
  ref.onDispose(() {
    debounce?.cancel();
    sweep.cancel();
    SupabaseConfig.client.removeChannel(ch);
  });
});

/// Current user's chat display name + avatar (for outbound messages).
final myChatIdentityProvider =
    FutureProvider<({String name, String? avatarUrl})>((ref) async {
  return ref.watch(messagingServiceProvider).getMyIdentity();
});

/// Company-scoped, grouped contact list (get_chat_contacts RPC).
final chatContactsProvider = FutureProvider<List<ChatContact>>((ref) async {
  return ref.watch(messagingServiceProvider).getContacts();
});

/// Rooms the current user participates in, newest-activity first — LIVE.
///
/// Re-fetches (debounced) whenever any chat_messages or chat_rooms row changes,
/// via Supabase Realtime `postgres_changes`, so last-message previews, ordering,
/// unread counts and delivery ticks all stay real-time without manual refresh.
final chatConversationsProvider =
    StreamProvider<List<ChatConversation>>((ref) {
  final svc = ref.watch(messagingServiceProvider);
  final controller = StreamController<List<ChatConversation>>();
  Timer? debounce;
  var disposed = false;

  Future<void> fetch() async {
    try {
      final list = await svc.getConversations();
      if (!disposed) controller.add(list);
    } catch (e, st) {
      if (!disposed) controller.addError(e, st);
    }
  }

  void schedule() {
    debounce?.cancel();
    debounce = Timer(const Duration(milliseconds: 250), fetch);
  }

  fetch();

  final ch = SupabaseConfig.client.channel('public:chat-conversations')
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'chat_messages',
      callback: (_) => schedule(),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'chat_rooms',
      callback: (_) => schedule(),
    )
    ..subscribe();

  ref.onDispose(() {
    disposed = true;
    debounce?.cancel();
    SupabaseConfig.client.removeChannel(ch);
    controller.close();
  });

  return controller.stream;
});

/// Realtime ordered messages for a room.
final roomMessagesProvider =
    StreamProvider.family<List<ChatMessage>, String>((ref, roomId) {
  return ref.watch(messagingServiceProvider).streamMessages(roomId);
});

/// Org-to-org connections (super-admin Connections panel).
final orgConnectionsProvider =
    FutureProvider<List<OrgConnection>>((ref) async {
  return ref.watch(messagingServiceProvider).getConnections();
});

/// Realtime emoji reactions for a room (grouped per message in the UI).
final roomReactionsProvider =
    StreamProvider.family<List<ChatReaction>, String>((ref, roomId) {
  return ref.watch(messagingServiceProvider).reactionsStream(roomId);
});

/// The room currently open in the Messages screen (null = none selected).
final activeRoomProvider = StateProvider<ChatConversation?>((ref) => null);

/// Bump-counter asking the floating ChatDock to morph open (e.g. the employee
/// profile's "Message X" button after it sets [activeRoomProvider]). The dock
/// listens and animates open; the panel jumps into the active thread.
final dockOpenRequestProvider = StateProvider<int>((ref) => 0);

/// The caller's effective chat role, from the SAME `chat_role_of()` the server
/// uses to enforce the P10-07 hierarchy and to gate `create_org_group`.
///
/// Deliberately not a second copy of the rule in Dart: a UI that decides who
/// may start a group using its own idea of "role" will eventually disagree
/// with the database, and the user finds out by being refused after they have
/// filled in a form.
///
/// Resolves to null while loading or on failure, which hides the affordance
/// rather than showing one that will be refused.
final myChatRoleProvider = FutureProvider<String?>((ref) async {
  final client = SupabaseConfig.client;
  final uid = client.auth.currentUser?.id;
  if (uid == null) return null;
  try {
    final res = await client.rpc('chat_role_of', params: {'p_uid': uid});
    return res as String?;
  } catch (_) {
    return null;
  }
});
