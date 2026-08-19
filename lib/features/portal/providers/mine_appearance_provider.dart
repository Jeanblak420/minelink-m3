import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_application_1/core/design/tokens/ml_mine_premium_theme.dart';

/// Immutable appearance selection for the mine/supplier dashboard.
class MineAppearance {
  final MineThemeDirection direction;
  final MineDensity density;

  const MineAppearance({
    this.direction = MineThemeDirection.minelink,
    this.density = MineDensity.comfortable,
  });

  MineAppearance copyWith({
    MineThemeDirection? direction,
    MineDensity? density,
  }) {
    return MineAppearance(
      direction: direction ?? this.direction,
      density: density ?? this.density,
    );
  }
}

/// Persisted premium-theme selection for the mine/supplier dashboard.
///
/// Defaults to [MineThemeDirection.minelink] + [MineDensity.comfortable] so the
/// dashboard looks exactly as it does today until a user opts into a premium
/// direction on the Appearance & theme page. Persistence is best-effort and
/// mirrors [themeModeProvider] (`SharedPreferences`).
class MineAppearanceNotifier extends StateNotifier<MineAppearance> {
  static const _directionKey = 'mine_theme_direction';
  static const _densityKey = 'mine_theme_density';

  MineAppearanceNotifier() : super(const MineAppearance()) {
    _restore();
  }

  Future<void> _restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final direction =
          MineThemeDirection.parse(prefs.getString(_directionKey));
      final density = MineDensity.parse(prefs.getString(_densityKey));
      if (mounted) {
        state = MineAppearance(direction: direction, density: density);
      }
    } catch (_) {
      // Keep defaults when prefs are unavailable (e.g. tests).
    }
  }

  Future<void> setDirection(MineThemeDirection direction) async {
    state = state.copyWith(direction: direction);
    await _persist();
  }

  Future<void> setDensity(MineDensity density) async {
    state = state.copyWith(density: density);
    await _persist();
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_directionKey, state.direction.wire);
      await prefs.setString(_densityKey, state.density.wire);
    } catch (_) {
      // Persistence is best-effort.
    }
  }
}

final mineAppearanceProvider =
    StateNotifierProvider<MineAppearanceNotifier, MineAppearance>((ref) {
  return MineAppearanceNotifier();
});
