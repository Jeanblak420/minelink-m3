/// When the `/portal/*` prefix guard should re-read the user's org type and
/// employee role.
///
/// Extracted from `AppRouter` so the decision can be tested as a pure
/// function (S7-7). The router's cache fields are private statics and its
/// redirect needs a live Supabase, so testing this through the router would
/// need a mock stack larger than the logic it verifies — and a test that heavy
/// is the one nobody re-runs.
library;

/// How long a cached org type / employee role stays trusted.
///
/// The trade-off, stated so the number is not mistaken for arbitrary: too
/// short and every route change carries a round trip; too long and a role
/// change takes minutes to bind. Two minutes is well inside the time it takes
/// an admin to tell somebody their role changed, and far outside the rate at
/// which anyone navigates.
const Duration portalGateTtl = Duration(minutes: 2);

/// True when the guard must re-fetch before it can trust its cached answer.
///
/// Before this existed the guard fetched **once per session** and nothing but
/// sign-out reset it, so a role or org change made while the user was signed in
/// was invisible until they signed out. That failed in both directions:
///
/// * **promoted** — the new destinations stayed blocked, and the user was told
///   they had "no such destination" for a route they now legitimately owned;
/// * **demoted or dismissed** — the OLD role kept working for as long as the
///   session lasted.
///
/// The second is the one that matters, though it is a stale *guard*, not a
/// data leak: RLS remains the real boundary, and `is_company_staff()` requires
/// `status = 'active'`, so a dismissed employee's queries already return
/// nothing. What this closes is a guard that answers yes when the answer is no.
///
/// Every unknown resolves toward re-fetching. The cost of being wrong that way
/// is one query; the cost of the opposite default is a dismissed employee
/// keeping their role until they close the tab.
/// How long to wait before re-attempting a gate read that failed.
///
/// A failed read leaves `loaded` false, so without this every subsequent
/// navigation re-attempts immediately. That is fine when the read *fails* —
/// it returns at once — and bad when it **hangs**, because each attempt then
/// costs the full 6-second timeout before the router can render anything.
///
/// Observed while the project was degraded: the app sat on a blank page,
/// spending six seconds per redirect pass, repeatedly. Ten seconds is short
/// enough that recovery is picked up almost immediately and long enough that
/// a hanging backend cannot hold the UI hostage.
const Duration portalGateFailureBackoff = Duration(seconds: 10);

bool shouldRefreshPortalGate({
  required bool loaded,
  required DateTime? fetchedAt,
  required String? cachedUserId,
  required String currentUserId,
  required DateTime now,
  DateTime? failedAt,
  Duration ttl = portalGateTtl,
  Duration failureBackoff = portalGateFailureBackoff,
}) {
  // A different signed-in user must never be served the previous one's cached
  // org type — that would be worse than any staleness, and worth paying the
  // wait for even while the backend is unwell.
  if (cachedUserId != currentUserId) return true;

  if (!loaded) {
    // Back off after a recent failure, but only then: an ordinary cold start
    // has no failure behind it and must fetch straight away.
    if (failedAt != null && now.difference(failedAt) < failureBackoff) {
      return false;
    }
    return true;
  }

  // Loaded but with no timestamp: treat as stale rather than as fresh.
  if (fetchedAt == null) return true;

  return now.difference(fetchedAt) >= ttl;
}
