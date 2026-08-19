import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_application_1/core/utils/logger.dart';
import 'package:flutter_application_1/core/design/tokens/ml_chat_palettes.dart';

final _log = LoggerFactory.getLogger('ChatPrefs');

/// User preferences for the chat overlay: the chosen messenger [paletteId] and
/// whether the floating disc follows the cursor. Persisted across restarts.
class ChatPrefs {
  final String paletteId;
  final bool cursorTracking;
  final bool soundsEnabled;
  final String incomingSound;
  final String? customSoundPath;
  final String? customSoundName;

  /// Per-contact incoming-sound overrides (userId → tone id). A user not in the
  /// map falls back to [incomingSound]. Mirrors CPS's per-contact sounds.
  final Map<String, String> perContactSound;

  const ChatPrefs({
    this.paletteId = ChatThemes.defaultId,
    this.cursorTracking = true,
    this.soundsEnabled = true,
    this.incomingSound = 'pop',
    this.customSoundPath,
    this.customSoundName,
    this.perContactSound = const {},
  });

  ChatPalette get palette => ChatThemes.byId(paletteId);

  /// The tone to play for a message from [senderUserId] (per-contact override
  /// or the default incoming tone).
  String resolveIncoming(String? senderUserId) {
    if (senderUserId != null) {
      final o = perContactSound[senderUserId];
      if (o != null) return o;
    }
    return incomingSound;
  }

  ChatPrefs copyWith({
    String? paletteId,
    bool? cursorTracking,
    bool? soundsEnabled,
    String? incomingSound,
    String? customSoundPath,
    String? customSoundName,
    Map<String, String>? perContactSound,
  }) =>
      ChatPrefs(
        paletteId: paletteId ?? this.paletteId,
        cursorTracking: cursorTracking ?? this.cursorTracking,
        soundsEnabled: soundsEnabled ?? this.soundsEnabled,
        incomingSound: incomingSound ?? this.incomingSound,
        customSoundPath: customSoundPath ?? this.customSoundPath,
        customSoundName: customSoundName ?? this.customSoundName,
        perContactSound: perContactSound ?? this.perContactSound,
      );
}

class ChatPrefsController extends StateNotifier<ChatPrefs> {
  ChatPrefsController() : super(const ChatPrefs()) {
    _load();
  }

  static const _kPalette = 'chat.palette_id';
  static const _kCursor = 'chat.cursor_tracking';
  static const _kSounds = 'chat.sounds_enabled';
  static const _kSoundId = 'chat.incoming_sound';
  static const _kCustomPath = 'chat.custom_sound_path';
  static const _kCustomName = 'chat.custom_sound_name';
  static const _kPerContact = 'chat.per_contact_sounds';

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    var perContact = const <String, String>{};
    final raw = p.getString(_kPerContact);
    if (raw != null) {
      try {
        final m = jsonDecode(raw) as Map<String, dynamic>;
        perContact = m.map((k, v) => MapEntry(k, v.toString()));
      } catch (e) {
        _log.w('per-contact sound prefs corrupt, ignoring: $e');
      }
    }
    state = ChatPrefs(
      paletteId: p.getString(_kPalette) ?? ChatThemes.defaultId,
      cursorTracking: p.getBool(_kCursor) ?? true,
      soundsEnabled: p.getBool(_kSounds) ?? true,
      incomingSound: p.getString(_kSoundId) ?? 'pop',
      customSoundPath: p.getString(_kCustomPath),
      customSoundName: p.getString(_kCustomName),
      perContactSound: perContact,
    );
  }

  Future<void> setContactSound(String userId, String? id) async {
    final next = Map<String, String>.from(state.perContactSound);
    if (id == null || id.isEmpty) {
      next.remove(userId);
    } else {
      next[userId] = id;
    }
    state = state.copyWith(perContactSound: next);
    final p = await SharedPreferences.getInstance();
    await p.setString(_kPerContact, jsonEncode(next));
  }

  Future<void> setPalette(String id) async {
    state = state.copyWith(paletteId: id);
    final p = await SharedPreferences.getInstance();
    await p.setString(_kPalette, id);
  }

  Future<void> setCursorTracking(bool value) async {
    state = state.copyWith(cursorTracking: value);
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kCursor, value);
  }

  Future<void> setSoundsEnabled(bool value) async {
    state = state.copyWith(soundsEnabled: value);
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kSounds, value);
  }

  Future<void> setIncomingSound(String id) async {
    state = state.copyWith(incomingSound: id);
    final p = await SharedPreferences.getInstance();
    await p.setString(_kSoundId, id);
  }

  Future<void> setCustomSound(String path, String name) async {
    state = state.copyWith(
        incomingSound: 'custom', customSoundPath: path, customSoundName: name);
    final p = await SharedPreferences.getInstance();
    await p.setString(_kSoundId, 'custom');
    await p.setString(_kCustomPath, path);
    await p.setString(_kCustomName, name);
  }
}

final chatPrefsProvider =
    StateNotifierProvider<ChatPrefsController, ChatPrefs>(
        (ref) => ChatPrefsController());
