import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter_application_1/core/time/ml_time.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:flutter_application_1/core/config/supabase_config.dart';

/// Live presence snapshot: who is online right now + a real-time last-seen
/// stamp for anyone who has just gone offline this session.
class Presence {
  final Set<String> online;
  final Map<String, DateTime> lastSeen;
  const Presence(this.online, this.lastSeen);
}

/// Realtime presence via a shared `online-users` channel. Drives the green
/// online dots AND an instant "Last seen X" — when a user leaves presence we
/// stamp their last-seen immediately (no polling), so the line flips the moment
/// they go offline. A 45s heartbeat also persists last_seen_at to the DB so it
/// survives across sessions for users you weren't watching.
class PresenceController extends StateNotifier<Presence> {
  PresenceController(this._uid)
      : super(const Presence(<String>{}, <String, DateTime>{})) {
    _init();
  }

  final String? _uid;
  RealtimeChannel? _channel;
  Timer? _heartbeat;
  StreamSubscription<AuthState>? _authSub;
  final Map<String, DateTime> _lastSeen = {};

  void _init() {
    final uid = _uid;
    if (uid == null) return;
    // Leave presence the instant this account signs out, so others see them go
    // offline immediately (the root provider isn't disposed on logout).
    _authSub = SupabaseConfig.client.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.signedOut) {
        _heartbeat?.cancel();
        _channel?.untrack();
        final ch = _channel;
        if (ch != null) SupabaseConfig.client.removeChannel(ch);
        _channel = null;
        if (mounted) {
          state = Presence(const <String>{},
              Map<String, DateTime>.unmodifiable(_lastSeen));
        }
      }
    });
    final ch = SupabaseConfig.client.channel('online-users');
    ch.onPresenceSync((_) {
      final ids = <String>{};
      for (final s in ch.presenceState()) {
        for (final p in s.presences) {
          final id = p.payload['user_id'];
          if (id is String) ids.add(id);
        }
      }
      // Anyone who was online and now isn't → stamp last-seen NOW (instant).
      final now = MlTime.instant();
      for (final was in state.online) {
        if (!ids.contains(was)) _lastSeen[was] = now;
      }
      if (mounted) {
        state = Presence(ids, Map<String, DateTime>.unmodifiable(_lastSeen));
      }
    });
    ch.subscribe((status, error) async {
      if (status == RealtimeSubscribeStatus.subscribed) {
        await ch.track({'user_id': uid});
      }
    });
    _channel = ch;
    // Heartbeat: persist a "last seen" activity time so contacts show the
    // CPS-style "Last seen X" line once a user goes offline (cross-session).
    _touchLastSeen();
    _heartbeat = Timer.periodic(
        const Duration(seconds: 45), (_) => _touchLastSeen());
  }

  Future<void> _touchLastSeen() async {
    try {
      await SupabaseConfig.client.rpc('chat_touch_last_seen');
    } catch (_) {
      // best-effort — presence still works without the timestamp
    }
  }

  @override
  void dispose() {
    _heartbeat?.cancel();
    _authSub?.cancel();
    final ch = _channel;
    if (ch != null) {
      ch.untrack();
      SupabaseConfig.client.removeChannel(ch);
    }
    super.dispose();
  }
}

final presenceProvider =
    StateNotifierProvider<PresenceController, Presence>((ref) {
  return PresenceController(SupabaseConfig.client.auth.currentUser?.id);
});

/// The set of user-ids currently online (real-time).
final onlineUsersProvider =
    Provider<Set<String>>((ref) => ref.watch(presenceProvider).online);

/// Real-time last-seen stamps (user id → when they left presence this session).
/// Merge with the DB `last_seen_at` fallback at the call site.
final presenceLastSeenProvider = Provider<Map<String, DateTime>>(
    (ref) => ref.watch(presenceProvider).lastSeen);

/// Per-room typing indicator via realtime broadcast. State is the set of OTHER
/// users' display names currently typing (auto-expires ~4s after last signal).
class TypingController extends StateNotifier<Set<String>> {
  TypingController(this._roomId, this._uid) : super(const {}) {
    _init();
  }

  final String _roomId;
  final String? _uid;
  RealtimeChannel? _channel;
  final Map<String, DateTime> _lastSeen = {};
  Timer? _sweep;

  void _init() {
    final ch = SupabaseConfig.client.channel('typing:$_roomId');
    ch.onBroadcast(
      event: 'typing',
      callback: (payload) {
        final uid = payload['user_id'];
        final name = payload['name'];
        if (uid == _uid || name is! String || name.isEmpty) return;
        // An explicit stop (sent the instant a message is sent) clears the
        // indicator immediately instead of waiting for the timeout.
        if (payload['stop'] == true) {
          if (_lastSeen.remove(name) != null) _recompute();
          return;
        }
        _lastSeen[name] = MlTime.instant();
        _recompute();
      },
    );
    ch.subscribe();
    _channel = ch;
    _sweep = Timer.periodic(
        const Duration(milliseconds: 500), (_) => _recompute());
  }

  void _recompute() {
    final now = MlTime.instant();
    // Short window: typing pings are throttled to ~1.5s, so 3s covers a missed
    // keystroke without the indicator lingering after someone stops.
    _lastSeen.removeWhere(
        (k, v) => now.difference(v) > const Duration(seconds: 3));
    final next = _lastSeen.keys.toSet();
    if (mounted && (next.length != state.length || !next.containsAll(state))) {
      state = next;
    }
  }

  /// Immediately drops [name] from the typing set — called by the recipient the
  /// moment a message from that person arrives (they've clearly stopped typing).
  void clearName(String name) {
    if (_lastSeen.remove(name) != null) _recompute();
  }

  Future<void> sendTyping(String name) async {
    await _channel?.sendBroadcastMessage(
      event: 'typing',
      payload: {'user_id': _uid, 'name': name, 'stop': false},
    );
  }

  /// Broadcasts an explicit "stopped typing" for [name] (sent on message send).
  Future<void> sendStop(String name) async {
    await _channel?.sendBroadcastMessage(
      event: 'typing',
      payload: {'user_id': _uid, 'name': name, 'stop': true},
    );
  }

  @override
  void dispose() {
    _sweep?.cancel();
    final ch = _channel;
    if (ch != null) SupabaseConfig.client.removeChannel(ch);
    super.dispose();
  }
}

final typingProvider =
    StateNotifierProvider.family<TypingController, Set<String>, String>(
        (ref, roomId) {
  return TypingController(roomId, SupabaseConfig.client.auth.currentUser?.id);
});

/// Snapshot of everyone currently typing to me (across all rooms): the sender
/// user-ids and — when the ping carries it — the rooms they're typing in.
/// Drives the floating disc bubble, conversation-row and contact-row
/// "typing…" indicators.
class TypingInbox {
  final Set<String> userIds;
  final Set<String> roomIds;
  const TypingInbox(this.userIds, this.roomIds);
  static const empty = TypingInbox(<String>{}, <String>{});
  bool get anyone => userIds.isNotEmpty;
}

/// Global "who is typing to me" signal (across all rooms, none open).
/// Senders ping `typing-inbox:<myId>` (see MessagingService.pingTyping); this
/// listens on the current user's inbox.
class TypingInboxController extends StateNotifier<TypingInbox> {
  TypingInboxController(this._uid) : super(TypingInbox.empty) {
    _init();
  }

  final String? _uid;
  RealtimeChannel? _channel;
  final Map<String, DateTime> _typers = {};
  // sender id → room they last pinged from (absent on legacy pings).
  final Map<String, String> _typerRooms = {};
  Timer? _sweep;

  void _init() {
    final uid = _uid;
    if (uid == null) return;
    final ch = SupabaseConfig.client.channel('typing-inbox:$uid');
    ch.onBroadcast(
      event: 'typing',
      callback: (payload) {
        final from = payload['user_id'];
        if (from is! String || from == uid) return;
        if (payload['stop'] == true) {
          _typerRooms.remove(from);
          _typers.remove(from);
          _recompute();
          return;
        }
        _typers[from] = MlTime.instant();
        final room = payload['room_id'];
        if (room is String && room.isNotEmpty) _typerRooms[from] = room;
        _recompute();
      },
    );
    ch.subscribe();
    _channel = ch;
    _sweep = Timer.periodic(
        const Duration(milliseconds: 500), (_) => _recompute());
  }

  void _recompute() {
    final now = MlTime.instant();
    _typers.removeWhere(
        (k, v) => now.difference(v) > const Duration(seconds: 3));
    _typerRooms.removeWhere((k, _) => !_typers.containsKey(k));
    final users = _typers.keys.toSet();
    final rooms = _typerRooms.values.toSet();
    final changed = users.length != state.userIds.length ||
        !users.containsAll(state.userIds) ||
        rooms.length != state.roomIds.length ||
        !rooms.containsAll(state.roomIds);
    if (mounted && changed) state = TypingInbox(users, rooms);
  }

  @override
  void dispose() {
    _sweep?.cancel();
    final ch = _channel;
    if (ch != null) SupabaseConfig.client.removeChannel(ch);
    super.dispose();
  }
}

final typingInboxProvider =
    StateNotifierProvider<TypingInboxController, TypingInbox>((ref) {
  return TypingInboxController(SupabaseConfig.client.auth.currentUser?.id);
});
