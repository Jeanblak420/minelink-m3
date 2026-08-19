import 'package:flutter_riverpod/flutter_riverpod.dart';

/// One distinct screen the user has visited. Identity is value-based over
/// (path, query, homeTabIndex) so consecutive duplicate visits are detectable.
class NavLocation {
  final String path;
  final Map<String, String> query;

  /// Sidebar tab index when [path] == '/home'; null otherwise.
  final int? homeTabIndex;

  const NavLocation({
    required this.path,
    this.query = const {},
    this.homeTabIndex,
  });

  /// Path + query string suitable for `context.go(...)`.
  String get fullLocation {
    if (query.isEmpty) return path;
    final qs = query.entries
        .map((e) {
          // Uri.encodeQueryComponent encodes spaces as '+'; go_router's context.go expects '%20'.
          final key = Uri.encodeQueryComponent(e.key).replaceAll('+', '%20');
          final value = Uri.encodeQueryComponent(e.value).replaceAll('+', '%20');
          return '$key=$value';
        })
        .join('&');
    return '$path?$qs';
  }

  @override
  bool operator ==(Object other) =>
      other is NavLocation &&
      other.path == path &&
      other.homeTabIndex == homeTabIndex &&
      _mapEquals(other.query, query);

  @override
  int get hashCode => Object.hash(
        path,
        homeTabIndex,
        Object.hashAllUnordered(
          query.entries.map((e) => Object.hash(e.key, e.value)),
        ),
      );

  static bool _mapEquals(Map<String, String> a, Map<String, String> b) {
    if (a.length != b.length) return false;
    for (final k in a.keys) {
      if (b[k] != a[k]) return false;
    }
    return true;
  }

  @override
  String toString() => 'NavLocation($path, tab=$homeTabIndex, q=$query)';
}

/// Stack of visited screens driving the app-wide Back button.
class NavHistoryNotifier extends StateNotifier<List<NavLocation>> {
  NavHistoryNotifier() : super(const []);

  static const int maxEntries = 50;

  /// Set when a back navigation just happened so the resulting re-visit of the
  /// target screen is not recorded as a new forward step.
  bool _suppressNextVisit = false;

  bool get canGoBack => state.length > 1;

  /// Records that the user is now on [location]. [isRoot] true means this is
  /// the portal's main Dashboard/Overview (or super-admin Console) landing
  /// screen, which resets the history.
  void visit(NavLocation location, {required bool isRoot}) {
    if (_suppressNextVisit) {
      _suppressNextVisit = false;
      return;
    }
    if (state.isNotEmpty && state.last == location) {
      return; // consecutive duplicate
    }
    if (isRoot) {
      state = [location];
      return;
    }
    final next = [...state, location];
    if (next.length > maxEntries) {
      next.removeRange(0, next.length - maxEntries);
    }
    state = next;
  }

  /// Pops the current screen and returns the previous one to navigate to, or
  /// null if there is nothing to go back to. Suppresses the re-record of the
  /// resulting navigation.
  NavLocation? popForBack() {
    if (state.length < 2) return null;
    final target = state[state.length - 2];
    _suppressNextVisit = true;
    state = state.sublist(0, state.length - 1);
    return target;
  }

  /// Clears history (e.g. on logout / shell teardown).
  void reset() {
    _suppressNextVisit = false;
    state = const [];
  }
}

final navHistoryProvider =
    StateNotifierProvider<NavHistoryNotifier, List<NavLocation>>(
  (ref) => NavHistoryNotifier(),
);
