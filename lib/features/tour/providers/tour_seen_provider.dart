import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persisted "the user has finished or skipped the tour" flag. Uses
/// [SharedPreferences], the same local-prefs mechanism as
/// `ThemeModeNotifier` / `AppSidebarPrefs`. Defaults to true (no badge)
/// until the stored value is restored, so the hint never flashes for
/// returning users.
class TourSeenNotifier extends StateNotifier<bool> {
  static const _prefsKey = 'tour_seen';

  TourSeenNotifier() : super(true) {
    _restore();
  }

  Future<void> _restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getBool(_prefsKey);
      if (mounted) {
        state = stored ?? false;
      }
    } catch (_) {
      // Keep the default when prefs are unavailable (e.g. tests).
    }
  }

  Future<void> markSeen() async {
    state = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefsKey, true);
    } catch (_) {
      // Persistence is best-effort.
    }
  }

  Future<void> reset() async {
    state = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefsKey, false);
    } catch (_) {
      // Persistence is best-effort.
    }
  }
}

final tourSeenProvider =
    StateNotifierProvider<TourSeenNotifier, bool>((ref) {
  return TourSeenNotifier();
});
