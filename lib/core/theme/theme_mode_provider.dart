import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persisted light/dark preference for the MineLink chrome theme toggle.
/// Defaults to DARK — matches the premium "LoadTrack" portal look; light is
/// available via the toggle and persisted when chosen.
class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  static const _prefsKey = 'app_theme_mode';

  ThemeModeNotifier() : super(ThemeMode.dark) {
    _restore();
  }

  Future<void> _restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString(_prefsKey);
      if (stored == 'light' && mounted) {
        state = ThemeMode.light;
      } else if (stored == 'dark' && mounted) {
        state = ThemeMode.dark;
      } else if (stored == 'system' && mounted) {
        state = ThemeMode.system;
      }
    } catch (_) {
      // Keep the default when prefs are unavailable (e.g. tests).
    }
  }

  Future<void> toggle() async {
    state = state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    await _persist();
  }

  /// Set an explicit mode (Light / Dark / System) from the Appearance page.
  /// Additive to [toggle] — existing callers are unaffected.
  Future<void> setMode(ThemeMode mode) async {
    state = mode;
    await _persist();
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, _wire(state));
    } catch (_) {
      // Persistence is best-effort.
    }
  }

  static String _wire(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.system:
        return 'system';
      case ThemeMode.dark:
        return 'dark';
    }
  }
}

final themeModeProvider =
    StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  return ThemeModeNotifier();
});
