import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Refreshing providers from an async handler, safely.
///
/// `WidgetRef.invalidate` is not a no-op once the widget is gone — it calls
/// riverpod's `_assertNotDisposed()`, which is a real `throw StateError`, not a
/// debug-only assert:
///
/// ```dart
/// void _assertNotDisposed() {
///   if (!context.mounted) {
///     throw StateError('Cannot use "ref" after the widget was disposed.');
///   }
/// }
/// ```
///
/// So it crashes release builds too. The window is ordinary rather than exotic:
/// a handler awaits a Supabase round-trip, and before it returns the user hits
/// back, taps a notification, or the router redirects them to `/login` because
/// the session expired. The write has already landed server-side; only the
/// local refresh is left, and that refresh throws.
///
/// Nothing catches this class of fault at build time. `flutter analyze` stays
/// clean because `use_build_context_synchronously` only tracks `BuildContext`,
/// and no lint covers `ref`. Across this app the same authoring habit shows up
/// repeatedly — the snackbar under the invalidate is `mounted`-guarded while
/// the invalidate above it is not.
///
/// Prefer this over an `if (!mounted) return;` guard when the only work left is
/// a refresh: it reads the same in a `ConsumerWidget` (which has no `mounted`)
/// as in a `ConsumerState`, and it says at the call site why the check is there.
extension SafeRefInvalidate on WidgetRef {
  /// Invalidates [provider], or does nothing if the widget has been disposed.
  ///
  /// Skipping the refresh is the correct outcome, not a compromise: a disposed
  /// widget has nothing to rebuild, and the next mount reads the provider fresh
  /// anyway. It is also strictly better than the status quo, where the throw
  /// means the invalidation does not happen *and* an error is raised.
  void invalidateIfMounted(ProviderOrFamily provider) {
    if (!context.mounted) return;
    invalidate(provider);
  }
}
