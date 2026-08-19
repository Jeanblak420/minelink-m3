// S7-7. `_portalGateFieldsLoaded` was a one-shot static.
//
// The portal's `/portal/*` prefix guard reads two cached fields — the user's
// org type and their employee role — and fetched them exactly once per
// session:
//
//     if (!_portalGateFieldsLoaded) {
//       await _refreshPortalGateFields(currentUser.id);
//     }
//
// Nothing reset that flag except `clearProfileGateCache()`, which fires on
// sign-in, sign-out and a mandatory password change. So **any role or org
// change made while the user was signed in was invisible to the guard until
// they signed out.**
//
// Both directions of that are wrong, and one of them is a security problem:
//
//   · promoted → the new destinations stay blocked, and the user is told they
//     have "no such destination" for a route they now legitimately own;
//   · demoted or dismissed → the OLD role keeps working. An employee moved off
//     `admin`, or dismissed outright, walks through the same guard on their
//     existing session for as long as they keep the tab open.
//
// RLS is still the real boundary — a dismissed employee's queries return
// nothing, because `is_company_staff()` requires `status = 'active'`. So this
// is not a data leak. It is a guard that says yes when the answer is no, which
// is worth closing on its own terms.
//
// The decision is extracted into `shouldRefreshPortalGate` so it can be tested
// as a pure function. The router's statics are private and the redirect needs
// a live Supabase, so testing this through the router would need a mock stack
// bigger than the logic it verifies — and a test that heavy tends to be the
// one nobody re-runs.

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/core/routing/portal_gate_staleness.dart';

void main() {
  final now = DateTime.utc(2026, 8, 15, 12, 0, 0);

  test('fetches when nothing has been loaded yet', () {
    expect(
      shouldRefreshPortalGate(
        loaded: false,
        fetchedAt: null,
        cachedUserId: null,
        currentUserId: 'u1',
        now: now,
      ),
      isTrue,
    );
  });

  test('does not refetch on every navigation — that was the point of the cache',
      () {
    expect(
      shouldRefreshPortalGate(
        loaded: true,
        fetchedAt: now.subtract(const Duration(seconds: 5)),
        cachedUserId: 'u1',
        currentUserId: 'u1',
        now: now,
      ),
      isFalse,
      reason: 'a fetch per navigation would put a round trip in front of every '
          'route change',
    );
  });

  test('refetches once the cached answer is older than the TTL', () {
    expect(
      shouldRefreshPortalGate(
        loaded: true,
        fetchedAt: now.subtract(portalGateTtl + const Duration(seconds: 1)),
        cachedUserId: 'u1',
        currentUserId: 'u1',
        now: now,
      ),
      isTrue,
      reason: 'this is the whole fix — a role change mid-session becomes '
          'visible without signing out',
    );
  });

  test('refetches immediately when the signed-in user changed', () {
    expect(
      shouldRefreshPortalGate(
        loaded: true,
        fetchedAt: now,
        cachedUserId: 'u1',
        currentUserId: 'u2',
        now: now,
      ),
      isTrue,
      reason: 'serving one user the other user\'s cached org type would be far '
          'worse than a stale role',
    );
  });

  test('a missing fetch time is treated as stale, not as fresh', () {
    // Fail toward re-fetching. The cost of being wrong here is one query; the
    // cost of the other default is a dismissed employee keeping their role.
    expect(
      shouldRefreshPortalGate(
        loaded: true,
        fetchedAt: null,
        cachedUserId: 'u1',
        currentUserId: 'u1',
        now: now,
      ),
      isTrue,
    );
  });

  test('the TTL is short enough to matter and long enough to be worth caching',
      () {
    expect(portalGateTtl.inSeconds, greaterThanOrEqualTo(30));
    expect(portalGateTtl.inMinutes, lessThanOrEqualTo(5));
  });

  group('after a failed read', () {
    // The read is inside `redirect`, so go_router renders NOTHING while it is
    // in flight. When it hangs rather than fails, each attempt costs the full
    // 6-second timeout — and with `loaded` still false, every navigation tried
    // again immediately. Observed as a blank page that stayed blank.
    final now = DateTime(2026, 8, 16, 9);

    test('backs off instead of paying the timeout again at once', () {
      expect(
        shouldRefreshPortalGate(
          loaded: false,
          fetchedAt: null,
          cachedUserId: 'u1',
          currentUserId: 'u1',
          now: now,
          failedAt: now.subtract(const Duration(seconds: 2)),
        ),
        isFalse,
      );
    });

    test('retries once the back-off has passed', () {
      expect(
        shouldRefreshPortalGate(
          loaded: false,
          fetchedAt: null,
          cachedUserId: 'u1',
          currentUserId: 'u1',
          now: now,
          failedAt: now.subtract(portalGateFailureBackoff),
        ),
        isTrue,
      );
    });

    test('never backs off a DIFFERENT user — that outranks the wait', () {
      // Serving one user the previous user's org type is worse than any stall.
      expect(
        shouldRefreshPortalGate(
          loaded: false,
          fetchedAt: null,
          cachedUserId: 'u1',
          currentUserId: 'u2',
          now: now,
          failedAt: now,
        ),
        isTrue,
      );
    });

    test('a cold start with no failure behind it still fetches at once', () {
      expect(
        shouldRefreshPortalGate(
          loaded: false,
          fetchedAt: null,
          cachedUserId: null,
          currentUserId: null.toString(),
          now: now,
          failedAt: null,
        ),
        isTrue,
      );
    });
  });
}
