/// The route the browser was opened at.
///
/// ## Why this has to be captured, and captured early
///
/// `main()` runs `runApp(_BootstrapApp())`, which mounts a **plain**
/// `MaterialApp` while Supabase initialises. That is enough for Flutter to
/// install its browser-history integration, which records the current route
/// and then normalises the address bar back to the origin. `MaterialApp.router`
/// — and therefore go_router — is only built once initialisation finishes, a
/// second or two later, and by then the URL carries no route at all. go_router
/// falls back to its `initialLocation`, and the deep link is gone.
///
/// Measured against the release build on 2026-08-16, opening
/// `…/#/portal/mine/tons-out` in a fresh tab:
///
/// ```text
/// [main]          Uri.base = http://host/#/portal/mine/tons-out   fragment = /portal/mine/tons-out
/// [router built]  Uri.base = http://host/                          fragment = ""
/// [first redirect] path = /login
/// ```
///
/// So **every** bookmark, shared link, emailed notification link and browser
/// refresh landed on the login screen and from there on the dashboard — S7-6.
/// It looked as though deep links worked, because navigating to one from
/// inside the running app always did.
///
/// Capturing in `main()`, before `runApp`, is the fix: that is the last moment
/// at which `Uri.base` is still the address the user actually opened.
library;

/// The route the app was opened at, or null for an ordinary open.
///
/// Set once by [captureInitialLocation] from `main()` and read by the router
/// when it is eventually built.
String? capturedInitialLocation;

/// Records where the app was opened. Call from `main()` **before `runApp`** —
/// see the library doc above for why later is too late.
///
/// This lives here, in a library that imports nothing, rather than on
/// `AppRouter`. Calling a static on `AppRouter` from `main()` meant importing
/// `app_router.dart`, and `main.dart` declares the global repository providers
/// that `portal_tons_out_screen.dart` imports — so
/// `main → app_router → portal_tons_out_screen → main` closed an import cycle.
/// The app compiled, analysed clean and passed 1157 tests, then rendered a
/// **blank white page** with an empty semantics tree and no console error.
/// A leaf library cannot do that to anyone.
void captureInitialLocation(Uri base) {
  capturedInitialLocation = initialLocationFrom(base);
}

/// Extracts the in-app route from the URL the app was opened at, or null when
/// there is none to restore.
///
/// Handles both URL strategies rather than assuming the current one:
///
/// * **hash** (what this app ships) — `http://host/#/portal/mine?x=1` puts the
///   whole route, query included, in the fragment;
/// * **path** — `http://host/portal/mine?x=1` puts it in the path and query.
///
/// Returns null for a bare origin, which is the ordinary "opened the app
/// normally" case and must fall through to the router's own default rather
/// than being forced to `/`.
String? initialLocationFrom(Uri base) {
  // Off the web `Uri.base` is the process's working directory, not an address
  // anyone opened. On Windows that is `file:///C:/…/<folder the exe ran from>`,
  // and treating its path as a route sent every sign-in to "That page is not
  // here" (found driving the Windows release, 2026-10-19). Android only
  // escaped because its working directory is `/`.
  if (base.scheme == 'file') return null;
  final fragment = base.fragment;
  if (fragment.isNotEmpty) {
    return _accept(fragment);
  }
  // Path strategy, or a server that rewrites. A bare `/` carries no route.
  if (base.path.isEmpty || base.path == '/') return null;
  final query = base.query;
  return _accept(query.isEmpty ? base.path : '${base.path}?$query');
}

/// Only an in-app absolute path is ever returned.
///
/// This value goes straight into `GoRouter.initialLocation`, so it must be a
/// route and not something that could be read as an authority. `//host` is
/// protocol-relative and is refused for the same reason it is in
/// `safeReturnTo` — the two checks are deliberately alike, because they are
/// the same question asked at two different moments.
String? _accept(String candidate) {
  if (!candidate.startsWith('/') || candidate.startsWith('//')) return null;
  if (candidate.startsWith(r'/\')) return null;
  final uri = Uri.tryParse(candidate);
  if (uri == null || uri.hasScheme || uri.hasAuthority) return null;
  if (uri.path.isEmpty || uri.path == '/') return null;
  return candidate;
}
