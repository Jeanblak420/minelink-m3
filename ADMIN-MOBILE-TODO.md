# Admin panel — fixes, phone layout & login methods (to-do)

Started 2026-10-24 from Jean's list. Rules for working this list:

- **One task at a time, top to bottom.** The next task is not started until the
  current one is fully done and ticked.
- A task is ticked **only when it is true**, with an evidence line under it
  (test, query, or what was seen on the phone).
- Phone layout changes apply at **phone width only**; the Windows and web
  layouts stay as they are. Data fixes (numbers, seats, wording) apply
  everywhere, because the same data feeds every layout.
- Database changes: Jean gave explicit OK on 2026-10-24 for the seat counting
  and active-users fixes, and the login-method work that needs them. Each ships
  as its own migration file with a rollback note. Database left healthy after
  every change.
- Backup: git tag `backup/pre-admin-mobile-2026-10-24` (commit `ab8605c`,
  pushed) + `Music\SHOWME!\MineLink-M3-backups\2026-10-24-before-admin-mobile\`.

Status: ☐ not started · ◐ in progress · ☑ done

---

## 0. Setup
- [x] 0.1 Backup of the current version (git tag pushed + APK and restore notes).
  - Evidence: tag `backup/pre-admin-mobile-2026-10-24` → `ab8605c` on origin;
    `MineLink-M3-ab8605c.apk` + `README.txt` in the backup folder.
- [x] 0.2 This list created and opened in the IDE.

## 1. The three broken items
- [x] 1.1 "Connect … via MineLink Messenger" on a company page can be pressed
      (nothing floats over it).
  - Fix: on a phone every company-page tab ends with 96px of room, so the last
    item scrolls clear of the floating Generate Token button. Desktop: no change.
  - Evidence: new test (412×915) scrolls Overview to the end — button bottom
    ≤ FAB top. Fails without the fix (895 vs 843), passes with it.
    `console_tail_test` + overflow sweep green (58); desktop and phone renders
    of the page unchanged. Re-check on the phone in 7.3.
- [x] 1.2 Back closes the Messages panel (and steps back inside it first:
      open conversation → list → closed), instead of changing the page under it.
  - Fix: while the window is open it registers its own Back step (newest
    handler, so it runs before the page's): Support / Settings / profile /
    conversation → list → close. Support's ticket and new-ticket screens step
    back to Support's home first. Window closed → Back is the page's again.
  - Evidence: `back_closes_chat_window_test.dart` (3 tests, real router Back
    path): window closes and page stays; open/close ×3; conversation → list →
    closed. Fails without the fix ("Back left the chat window open"). All chat +
    Back tests green (86), analyze clean. Re-check on the phone in 7.3.
- [ ] 1.3 Seats are counted: every company's seats-used matches its real users,
      stays right when users are added, moved, deactivated or removed, and the
      existing numbers are corrected.

## 2. Passwords & login methods
- [ ] 2.1 Super-admin password reset proven end to end for real: reset a test
      account's password, then sign in with the new one.
- [ ] 2.2 Super admin can see, add, change and remove a user's login methods
      (email / WhatsApp), switch between them, and mark one primary and one
      secondary; sign-in works with each method that is set up.

## 3. Wrong or misleading numbers
- [ ] 3.1 "Active users right now" counts people actually using the app (recent
      activity), not people who typed a password in the last 5 minutes.
- [ ] 3.2 Live map: the "trucks reporting" count and the "No GPS fixes yet"
      message agree.
- [ ] 3.3 "Recent alerts" says the period it really shows.
- [ ] 3.4 Zero counts show no badge; "NEW" only shows when something is new.
- [ ] 3.5 Notifications for a request clear themselves once it is linked; the
      stale 18 Sep one is cleared.
- [ ] 3.6 Wording: "1 organization", "1 user", no broken "- — -" separators,
      "updated live, read fresh on every load" sentence fixed — checked across
      the admin panel, not just the examples.

## 4. Hard to read or use on a phone
- [ ] 4.1 No words broken in half and no cut-off labels on Buyers / Mines /
      Transporters insights and Route marketplace; token countdown readable.
- [ ] 4.2 Full names in the menu (no "Communicatio…").
- [ ] 4.3 Targets: the header scrolls away on a phone; nothing clipped.
- [ ] 4.4 Floating chat button (and Generate Token) never cover content or
      buttons on any screen.
- [ ] 4.5 Wide tables become one card per row on a phone: Organizations, Margin
      ledger (money visible), Recon, Route marketplace.
- [ ] 4.6 Company page: one back arrow; bottom bar highlights Access; all tabs
      readable; WhatsApp users show their number, not the internal login
      address (also on Platform users).
- [ ] 4.7 Each insights page opens at the top.
- [ ] 4.8 Tap targets at least 48 px: chat window buttons, table page arrows,
      targets − / +.

## 5. Clean-ups
- [ ] 5.1 Platform settings: checked the Windows/web code, then the old canonical
      tree, then the oldest `ML` tree (read-only) for what it ever held;
      reported to Jean; then removed or filled in.
- [ ] 5.2 Platform users in the menu under Tokens & Seats.
- [ ] 5.3 Chat window on a phone: practical full-screen / docked behaviour that
      can always be moved back, resized or closed — never stuck or unusable.
- [ ] 5.4 Dashboard: repeats removed, one real version of each section kept,
      zero-only stat cards condensed; much shorter on a phone.
- [ ] 5.5 Crash reports: real count instead of a 500 cap; found out why nothing
      arrived after 17 Oct and fixed it so reporting can't silently stop again.

## 6. Additions
- [ ] 6.1 "Needs your attention" list at the top of the dashboard (pending
      requests, expiring tokens, open waybills, disputes), each tappable.
- [ ] 6.2 Phone card layout for the four wide tables (done in 4.5 — tick when
      4.5 is ticked and re-checked).
- [ ] 6.3 Real "online now" count (done in 3.1 — tick when re-checked).
- [ ] 6.4 Seat warning when a company nears its limit.
- [ ] 6.5 Chat behaves like a page: Back closes it, docks out of the way of
      buttons (1.2 + 4.4 + 5.3 — tick when all three are ticked and re-checked).

## 7. Prove it and ship it
- [ ] 7.1 `flutter analyze` clean; full test suite green; new tests for each fix.
- [ ] 7.2 Windows/web layouts unchanged (desktop goldens still match).
- [ ] 7.3 Release APK on Jean's phone; whole admin panel walked again on the
      phone; every item above re-checked there.
- [ ] 7.4 Database healthy (all services probed); migration ledger matches files.
- [ ] 7.5 Committed, pushed, APK on the NAS.
