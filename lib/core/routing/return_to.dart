/// Where the user was going when the router bounced them to `/login`.
///
/// Extracted from `app_router.dart` for the same reason
/// `portal_gate_staleness.dart` was: it is a decision with a security
/// consequence, and a decision buried inside a 700-line `redirect` closure
/// cannot be exercised on its own.
library;

/// The query key that carries the interrupted destination on `/login`.
const String kReturnToKey = 'from';

/// Validates a `?from=` value before the router is allowed to send anyone to
/// it. Returns null when it is not a safe in-app destination.
///
/// This is an **open-redirect check**, not a formality. The value arrives
/// inside a URL that anyone can construct and send to somebody else, so
/// everything that reaches `context.go` from it must be a path inside this app
/// and nothing else. A link reading
/// `minelink.example/#/login?from=https://evil.example` that lands a
/// freshly-authenticated user on someone else's page is the whole failure
/// mode, and it is a particularly good phishing carrier because the first half
/// of the journey is genuine.
///
/// The rules:
///
/// * It must start with a single `/`. `//evil.example` is **protocol-relative**
///   — browsers read it as `https://evil.example` — which is the case a naive
///   `startsWith('/')` check lets straight through.
/// * It must carry no scheme and no authority, decided by *parsing* rather
///   than by pattern-matching the string. `\/\/evil.example`, percent-encoded
///   variants and backslash tricks all differ as text and agree once parsed.
/// * `/login` is refused: returning to it after signing in is a redirect loop.
///
/// Authorisation is deliberately NOT decided here. A path that survives this
/// check is still put through every guard in the router, so a deep link into a
/// route the user's role does not own is bounced exactly as if they had typed
/// it while signed in.
String? safeReturnTo(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  if (!raw.startsWith('/') || raw.startsWith('//')) return null;
  // A backslash is not a path separator in a URI, but several browsers
  // normalise `/\` to `//` before the app ever sees it.
  if (raw.startsWith(r'/\')) return null;
  final uri = Uri.tryParse(raw);
  if (uri == null || uri.hasScheme || uri.hasAuthority) return null;
  if (uri.path.isEmpty || uri.path == '/login') return null;
  return raw;
}
