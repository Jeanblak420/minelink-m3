/// The two router access gates that were being kept by a widget instead of by
/// the router — G1 and G3 on `COMPLETION-CHECKLIST.md` S2-7 / S2-9.
///
/// Pure functions, taking every signal as an argument, for the reason
/// `portal_gate_staleness.dart` states: the router's cache fields are private
/// statics and its redirect needs a live Supabase, so testing these through
/// the router would need a mock stack larger than the logic it verifies — and
/// a test that heavy is the one nobody re-runs.
library;

/// Paths a signed-in user must always be able to reach, whatever else is wrong
/// with their account.
///
/// A gate that can strand somebody is worse than the gate being absent: with
/// no way to sign out, no way to see whose account they are on and no way to
/// ask for help, the only recovery is clearing site data. Every gate below is
/// checked against this list first.
const Set<String> alwaysReachablePaths = {
  '/login',
  '/forgot-password',
  '/reset-password',
  '/whatsapp-otp',
  '/mandatory-password-change',
};

/// Where an employee with no role assigned may go.
///
/// `/home` is first because it is the destination: `resolvePortalTabs` gives a
/// no-role employee exactly one tab — `WaitingForRoleScreen` — so `/home` *is*
/// the waiting screen, which is what S2-7 asks them to reach.
///
/// `/profile` because the waiting screen promises "you can only access your
/// Profile", and `/account-setup` with it: employees are asked, by banner and
/// by a daily reminder deep-link, to complete their profile, documents and
/// signature *while they wait*. Sending them to a screen and then refusing the
/// screen would make the reminder a dead end. `/company-selection` because a
/// self-signup that has not picked a company yet must be able to.
const Set<String> noRoleAllowedPaths = {
  '/home',
  '/profile',
  '/account-setup',
  '/company-selection',
};

/// G1 (S2-7) — an employee whose role has not been assigned reaches the
/// waiting screen and nothing else.
///
/// ## What this replaces, and why a redirect rather than the overlay
///
/// There was no no-role check in the router at all. Enforcement was
/// `portal_shell_layout.dart`: `isEmployeeWithoutRole && !overlayExempt`
/// stacked `ApprovalPendingOverlay` over the normal shell body. So the
/// destination screen underneath **still built and its providers still
/// fetched**, and the scrim is `black @ 70%` — a `Container` with a colour is
/// hit-testable, so taps were absorbed and the user could not interact, but
/// the screen beneath stayed 30% visible. On a dark portal with light text
/// that is not nothing.
///
/// The real security boundary is and remains RLS: a no-role employee is still
/// an `active` employee of their company, so they read what their company
/// reads, and no redirect changes that. What this closes is the gap between
/// the product's own promise and the mechanism keeping it — a promise kept by
/// a translucent cover rather than by not going there.
///
/// The overlay stays. It is the right thing for the exempt screens, where the
/// user *is* allowed to be and still needs telling why the rest is missing.
String? noRoleRedirect({
  required String path,
  required bool isEmployeeWithoutRole,
  required bool isPlatformAdmin,
}) {
  if (!isEmployeeWithoutRole || isPlatformAdmin) return null;
  if (alwaysReachablePaths.contains(path)) return null;
  if (noRoleAllowedPaths.contains(path)) return null;
  // Deeper paths under an allowed one — `/profile/signature` — belong to it.
  for (final allowed in noRoleAllowedPaths) {
    if (path.startsWith('$allowed/')) return null;
  }
  return '/home';
}

/// G3 (S2-9) — a forced password change applies to **employees**, not only to
/// company accounts.
///
/// ## The gate as written was measuring the smaller half
///
/// The router tested `userType == 'company' && mustChangePassword`. Employees
/// were excluded from the check — and, separately,
/// `create_company_managed_employee` never set the flag, so no employee has
/// ever had it (measured 2026-08-15: 1 of 116 profiles carries it, and that
/// one is a company account). Both halves had to move, and the DB half is the
/// one that matters: **an admin-created employee signs in with a password
/// their manager chose and knows.** That is the exact situation the flag
/// exists for, and it was the one case it did not cover.
///
/// Platform admins are exempt, as before: they are created out-of-band and
/// locking one out of the console over a flag has no recovery path.
String? mandatoryPasswordRedirect({
  required String path,
  required bool mustChangePassword,
  required bool isPlatformAdmin,
}) {
  if (!mustChangePassword || isPlatformAdmin) return null;
  // Exactly [alwaysReachablePaths], which is the set the pre-fix gate skipped
  // as "public paths" plus the change screen itself. Stated by name rather
  // than inherited from `isPublicRoute`, because that coupling is how
  // `/whatsapp-otp` came to sit outside the gate by accident rather than by
  // decision — and it is the one that would have looped: the OTP gate runs
  // AFTER this one, so a flagged phone user bounced off `/whatsapp-otp` would
  // have been sent back and forth.
  if (alwaysReachablePaths.contains(path)) return null;
  return '/mandatory-password-change';
}
