import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_application_1/core/config/supabase_config.dart';
import 'package:flutter_application_1/core/utils/logger.dart';
import 'package:flutter_application_1/features/auth/providers/auth_state.dart';

final _log = LoggerFactory.getLogger('UiPrefs');

/// Accent palette for the Super-Admin console — mirrors the design handoff's
/// Appearance panel (MineLink Cyan default + 5 alternates). Each accent keeps
/// the design's hover/press ramp so buttons darken consistently.
enum ConsoleAccent {
  cyan('cyan', 'MineLink Cyan', Color(0xFF00B5D8), Color(0xFF0496B6), Color(0xFF0A7791)),
  indigo('indigo', 'Indigo', Color(0xFF4F46E5), Color(0xFF4338CA), Color(0xFF3730A3)),
  violet('violet', 'Violet', Color(0xFF7C3AED), Color(0xFF6D28D9), Color(0xFF5B21B6)),
  emerald('emerald', 'Emerald', Color(0xFF059669), Color(0xFF047857), Color(0xFF065F46)),
  amber('amber', 'Amber', Color(0xFFD97706), Color(0xFFB45309), Color(0xFF92400E)),
  rose('rose', 'Rose', Color(0xFFE11D48), Color(0xFFBE123C), Color(0xFF9F1239));

  final String id;
  final String label;
  final Color color;
  final Color hover;
  final Color press;
  const ConsoleAccent(this.id, this.label, this.color, this.hover, this.press);

  /// Console default (user decision 2026-08-08). Applies to any admin who
  /// hasn't picked an accent; saved choices are untouched.
  static const ConsoleAccent defaultAccent = amber;

  static ConsoleAccent parse(String? id) =>
      values.firstWhere((a) => a.id == id, orElse: () => defaultAccent);
}


// `ConsoleSidebarSkin` was removed by the M3 redesign.
//
// The console shipped FIVE interchangeable navigation rails as a per-user
// preference — three layouts, two of them also in a second palette — across
// roughly 4,600 lines under `widgets/sidebar/`. Each was a complete
// re-implementation of the same thirty destinations, so a destination added
// to one and forgotten in the others simply did not exist for the admins who
// had picked those. Exactly that had happened: Targets was reachable from
// some rails and not from the default one.
//
// There is now one rail (`MlNavRail`) rendering one tree (`consoleNavTree`),
// shown to every role on every platform. A saved `sidebar` value in stored
// preferences is simply ignored on read, so nothing has to migrate.

/// Per-user Super-Admin console preferences (design: "Saved to your account
/// only"). Appearance/Display: mode, accent, canvas texture.
/// Accessibility: text size, high contrast, bold text.
@immutable
class UiPrefs {
  /// DARK is the console's default main theme (user decision 2026-08-07);
  /// light is available per-user from Settings → User Preferences.
  final bool darkMode;
  final ConsoleAccent accent;

  /// Engineering dot-grid + brand washes behind the light workspace canvas.
  final bool canvasTexture;

  /// Text scale factor (1.0 = default). Clamped to [0.85, 1.3].
  final double textScale;
  final bool highContrast;
  final bool boldText;

  const UiPrefs({
    this.darkMode = true,
    this.accent = ConsoleAccent.defaultAccent,
    this.canvasTexture = true,
    this.textScale = 1.0,
    this.highContrast = false,
    this.boldText = false,
  });

  UiPrefs copyWith({
    bool? darkMode,
    ConsoleAccent? accent,
    bool? canvasTexture,
    double? textScale,
    bool? highContrast,
    bool? boldText,
  }) {
    return UiPrefs(
      darkMode: darkMode ?? this.darkMode,
      accent: accent ?? this.accent,
      canvasTexture: canvasTexture ?? this.canvasTexture,
      textScale: (textScale ?? this.textScale).clamp(0.85, 1.3),
      highContrast: highContrast ?? this.highContrast,
      boldText: boldText ?? this.boldText,
    );
  }

  Map<String, Object> toJson() => {
        'dark': darkMode,
        'accent': accent.id,
        'canvas': canvasTexture,
        'scale': textScale,
        'contrast': highContrast,
        'bold': boldText,
      };

  static UiPrefs fromJson(Map<String, dynamic> j) => UiPrefs(
        darkMode: j['dark'] as bool? ?? true,
        accent: ConsoleAccent.parse(j['accent'] as String?),
        canvasTexture: j['canvas'] as bool? ?? true,
        // A stored `sidebar` key from before the M3 redesign is deliberately
        // read and discarded — there is one rail now, so there is nothing for
        // it to select and nothing to migrate.
        textScale:
            ((j['scale'] as num?)?.toDouble() ?? 1.0).clamp(0.85, 1.3),
        highContrast: j['contrast'] as bool? ?? false,
        boldText: j['bold'] as bool? ?? false,
      );
}

class UiPrefsNotifier extends StateNotifier<UiPrefs> {
  final String? _userId;

  UiPrefsNotifier(this._userId) : super(const UiPrefs()) {
    _restore();
  }

  String get _key => 'ml.console.prefs.v1.${_userId ?? 'anon'}';

  /// Device cache first, then the profile row.
  ///
  /// S5-4: the profile row is the SOURCE OF TRUTH, but reading it is a
  /// round-trip. The cache is read first so a cold start paints the user's own
  /// accent and text scale immediately rather than flashing the defaults and
  /// then correcting itself — and so an offline device (a weighbridge with no
  /// signal) keeps the settings it had.
  Future<void> _restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw != null && mounted) {
        state = UiPrefs.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      }
    } catch (e) {
      _log.d('ui prefs cache unavailable, using defaults: $e');
    }
    await _restoreFromProfile();
  }

  /// Pull the row and let it win. Silent on failure by design: a user with no
  /// connection keeps their cached preferences rather than being reset to the
  /// defaults by a failed read.
  Future<void> _restoreFromProfile() async {
    final id = _userId;
    if (id == null) return;
    try {
      final row = await SupabaseConfig.client
          .from('profiles')
          .select('ui_prefs')
          .eq('id', id)
          .maybeSingle();
      final json = row?['ui_prefs'];
      if (json is Map && json.isNotEmpty && mounted) {
        state = UiPrefs.fromJson(Map<String, dynamic>.from(json));
        await _persistLocal();
      }
    } catch (e) {
      _log.d('ui prefs not read from profile, keeping cached: $e');
    }
  }

  Future<void> _persistLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, jsonEncode(state.toJson()));
    } catch (e) {
      _log.d('ui prefs cache write failed: $e');
    }
  }

  /// Cache immediately, profile row behind it.
  ///
  /// The order matters: the slider must feel instant, and the round-trip must
  /// not be able to lose a keystroke. The RPC clamps and whitelists server-side
  /// (`set_my_ui_prefs`), so a stale client cannot store a text scale no layout
  /// has ever been rendered at.
  Future<void> _persist() async {
    await _persistLocal();
    if (_userId == null) return;
    try {
      await SupabaseConfig.client
          .rpc('set_my_ui_prefs', params: {'p_prefs': state.toJson()});
    } catch (e) {
      // Not fatal: the cache already has it, and the next successful write
      // carries the current state. Logged so a persistently failing sync is
      // visible rather than looking like "my settings keep resetting".
      _log.w('ui prefs not saved to profile: $e');
    }
  }

  void update(UiPrefs Function(UiPrefs) fn) {
    state = fn(state);
    _persist();
  }

  void setDarkMode(bool v) => update((p) => p.copyWith(darkMode: v));
  void setAccent(ConsoleAccent a) => update((p) => p.copyWith(accent: a));
  void setCanvasTexture(bool v) => update((p) => p.copyWith(canvasTexture: v));
  void setTextScale(double v) => update((p) => p.copyWith(textScale: v));
  void setHighContrast(bool v) => update((p) => p.copyWith(highContrast: v));
  void setBoldText(bool v) => update((p) => p.copyWith(boldText: v));
}

/// Per-user console preferences. Re-keys (and re-restores) whenever the
/// signed-in user changes so each admin gets their own saved appearance.
final uiPrefsProvider =
    StateNotifierProvider<UiPrefsNotifier, UiPrefs>((ref) {
  final userId = ref.watch(authStateProvider.select((s) => s.user?.id));
  return UiPrefsNotifier(userId);
});
