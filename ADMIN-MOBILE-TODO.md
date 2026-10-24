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
  - Added before any database change (Jean asked): full read-only database
    export (all 71 public tables + auth users/identities, every function,
    constraint, trigger, policy, index, cron job and the migration ledger),
    zipped and tested; full project-folder zip (tested). Code zip + APK copied
    to `\\192.168.88.30\Shared\MineLink-M3-backups\2026-10-24-before-admin-mobile\`.
    The database zip holds login data, so it stays on the PC only.
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
- [x] 1.3 Seats are counted: every company's seats-used matches its real users,
      stays right when users are added, moved, deactivated or removed, and the
      existing numbers are corrected.
  - Cause: the triggers that kept the count were dropped from production out
    of band; nothing updated `seats_used` or the seat list since.
  - Fix — migration `20261024100000_seats_follow_active_employees` (applied
    live, ledger row matches the file): one rule, a seat is held by every
    active person; triggers keep `seats_used` / `seats_available` and the seat
    list in step on every employee and seat-limit change; existing data
    corrected. Found and fixed on the way, all broken before today:
    seat-expansion approval ("function does not exist"), Suspend user (status
    not allowed), Suspend company / Change role / Suspend-Reactivate user (audit
    log refused 'company'/'employee'), Remove from seat (dropped function +
    missing column), a token could be issued with fewer seats than people.
  - App: Suspend frees the seat and says so; "Remove from Seat" dropped (now
    identical to Suspend); Reassign offers only people without a seat and says
    the holder will be suspended; every user action now shows an error instead
    of failing silently and refreshes seats + counts; "Suspended" label
    everywhere; a suspended person signing in gets "Access suspended" + Sign
    out instead of an empty workspace.
  - Evidence: live now AB mine 4/10 (4 people, 4 seats), AB trans 1/10, AB
    buyer 0/10. Rollback probes on live: suspend → 0 / reactivate → 1;
    limit 10→4→2→10 (seats disabled/re-enabled, people never evicted); remove
    from seat; reassign seat 1 to Bob; reassign to a seated person refused;
    token below headcount refused; seat expansion to 15 approved (failed
    before); expansion below headcount refused; every company consistent.
    Health: main 6/6 services OK. Tests: 437 admin/portal + new suspended
    tests green; analyze clean.

## 2. Passwords & login methods
- [x] 2.1 Super-admin password reset proven end to end for real: reset a test
      account's password, then sign in with the new one.
  - Done on Jean's S25 Ultra (today's build, wireless adb), signed in as
    jean@minelink.org: AB trans → Users → Eli Mans → Change Password → saved
    ("Updated password for Eli Mans"). **Eli Mans's password is now
    `MineLinkTest2410`** (WhatsApp 083 306 7846).
  - Evidence: Auth sign-in as wa-0833067846 with the new password → HTTP 200
    (session signed straight back out, 204); wrong password → 400
    invalid_credentials; audit log row "Super admin changed password for Eli
    Mans" by jean@minelink.org, 2026-10-24 00:25 UTC.
  - Fixed on the way: with the keyboard open the Confirm field was hidden and
    the keyboard's button did not go to it. Next now moves password → confirm
    (explicitly — the default landed on the show-password eye) and Done saves.
    `edit_login_dialog_test.dart` (3 tests) green.
  - Seen, for 4.x: the user menu's last item is cut off at the screen edge
    ("Change Password / Email / Ph…").
- [x] 2.2 Super admin can see, add, change and remove a user's login methods
      (email / WhatsApp), switch between them, and mark one primary and one
      secondary; sign-in works with each method that is set up.
  - Server: migrations `20261024110000_login_methods`,
    `20261024111000_clear_user_phone` (applied, ledger rows), edge function
    `admin-update-user` v6. Throwaway-account end-to-end
    (add / make primary / remove WhatsApp / refuse removing the last method /
    add back / switch to WhatsApp-only / email user gets WhatsApp / internal
    address refused / non-admin refused): **26/26 pass** against v6; cleanup
    leaves 0 throwaway accounts, super admins = bryson@ + jean@ only.
  - Number sign-in tries the phone first, then the old internal address:
    `whatsapp_number_sign_in_test.dart` 5/5. Dialog: `edit_login_dialog_test.dart`
    10/10.
  - Jean's S25 Ultra, 2026-10-24, as jean@minelink.org, on Eli Mans: the dialog
    read WhatsApp on (locked: only way in) and email off → added
    eli.mans.test@minelink-probe.invalid, made Email primary, saved. From the
    PC: email + password → 200, number + password → 200; DB email set,
    `login_primary = email`. Then switched email off in the dialog → saved:
    WhatsApp primary again, the test email → 400, number → 200, internal
    address restored. Eli is exactly as before. Three audit rows present.
  - Fixed from that walk: the user card and the seat list showed the internal
    `wa-…@wa.mineralguide.com` address as the user's email (now hidden,
    `realEmailOrNull`); the save message and the audit text read "Updated
    removed email, primary: whatsapp" (now "email sign-in removed; primary is
    now WhatsApp"). `login_display_test.dart` 2/2; goldens unchanged.

## 3. Wrong or misleading numbers
- [x] 3.1 "Active users right now" counts people actually using the app (recent
      activity), not people who typed a password in the last 5 minutes.
  - Cause, two parts: `platform_registry_extras` counted
    `auth.users.last_sign_in_at` in the last 5 min (a token refresh does not
    move it), AND the 45 s activity heartbeat (`chat_touch_last_seen`) only
    started once somebody opened the chat panel or a staff profile. Seen
    live: Jean's `last_seen_at` stopped at 23:56 the night before although
    the app was open on his phone 03:58–04:13.
  - App: `App` keeps `presenceProvider` alive for the whole session
    (`presenceKeepAlive`, a listen — nothing rebuilds on presence changes);
    the provider follows the signed-in account (rebuilt for a new user, torn
    down on sign-out, not on a token refresh) and beats once on returning to
    the app. This also fixes the green online dots and "last seen" app-wide.
  - DB: migration `20261024120000_active_users_from_activity` (applied,
    ledger row; live body verified) counts `profiles.last_seen_at` in the
    last 2 min. Rolled-back probe as jean@: 0 → one heartbeat → 1.
  - Label "signed-in · last 5m" → "using the app · last 2 min". Six goldens
    changed by that line only (668 px each; crop compared old vs new).
  - Phone confirmation of the heartbeat is in the final walk (7.3).
- [x] 3.2 Live map: the "trucks reporting" count and the "No GPS fixes yet"
      message agree.
  - Cause: both live-map headers (super admin + company portal) counted every
    active trip as "a truck reporting"; the map only draws trips with a GPS
    fix. Now one shared rule, `liveMapReportingMeta`: all reporting → "N trucks
    reporting"; otherwise "N active trips · M reporting GPS".
  - `live_map_reporting_count_test.dart` 3/3. The sample-data renders showed
    the bug too ("4 trucks reporting" over 3 fixes) — three live-map goldens
    now read "4 active trips · 3 reporting GPS" (header line only changed).
- [x] 3.3 "Recent alerts" says the period it really shows.
  - Cause: the Buyers / Mines / Transporters org-insights card hard-coded
    "Signals from the last 24h", but its alerts are built from the month's
    rows and each one's date is that company's last load (hence 07 Oct).
  - Now "Signals from <Mon yyyy> · MTD · dated by last load", the period
    taken from `_periodLabel()` — the same function the page header uses, so
    the two cannot name different windows again. The transporters overview's
    own alerts card already named its window (checked; unchanged). No other
    "last 24h" claim in the admin panel sits over older data (searched: the
    remaining ones are real 24 h counts — new companies/users/requests).
  - `screen-org-insights-desktop-dark` golden: that subtitle line only.
- [x] 3.4 Zero counts show no badge; "NEW" only shows when something is new.
  - Cause: the dashboard's Pending-requests section always drew its NEW pill
    and "N open", and every request card its orange count badge — at 0 too.
  - Now: no badge on a card with 0 ("None waiting · Open →"); the NEW pill
    and "N open" only when at least one request is open, else "Nothing
    waiting". Cards say "N waiting", not "N new": the count is what is open,
    and nothing on that screen knows when a request arrived. The cards stay
    (they are the way into each inbox).
  - Checked the rest: nav rail / bottom bar / More badges already hide at 0
    (`count > 0` in `ml_app_shell.dart` and `ml_nav_rail.dart`).
  - `pending_requests_zero_test.dart` 2/2 (all-empty; one inbox with work).
    Seven dashboard goldens changed by "new" → "waiting" only (compared).
- [x] 3.5 Notifications for a request clear themselves once it is linked; the
      stale 18 Sep one is cleared.
  - Migration `20261024130000_request_notifications_clear_when_decided`
    (applied, ledger row): trigger on `transportation_requests` status — the
    admins' "to review" notices are marked read once the request is decided
    (approved / sent back / declined / linked; a resubmission makes fresh
    ones), and the requester's "was approved" notice once it is linked.
    Marked read, never deleted; a failure only warns, never blocks the
    decision.
  - Rolled-back probe on the real request: resubmit → 2 new admin notices
    unread → approve → 0 unread; new "approved" notice 1 → link → 0; the
    57 unrelated unread notifications untouched (57 → 57).
  - Backfill: the 18 Sep "New buyer request to review" (jean@) and the
    requester's "approved" (bryson@tlgc.com) are now read; Jean's unread
    count is 0. The open app updates live (the feed listens to all changes).
    The company-side order / stockpile / driver notices for that request are
    still current work, so they were left alone.
- [x] 3.6 Wording: "1 organization", "1 user", no broken "- — -" separators,
      "updated live, read fresh on every load" sentence fixed — checked across
      the admin panel, not just the examples.
  - Swept all of `lib/` (scripted: an interpolated count followed by a plural
    noun). Real counts fixed with `mlCount`: dashboard org cards
    "N organizations" (×3), Targets search "Search N organizations", audit
    export "Total: N entries", recent-organization rows "N users". The rest
    are names, not counts (e.g. "Manage <company> users"), or already guarded.
  - Recent-organization line built once (`_orgSummary`) for card and table:
    joined with " · ", the "—" no-address placeholder left out — was
    "Active - — - 0 users", now "Active · 0 users". Swept the admin panel
    for other " - " joins: none left.
  - The sentence was also untrue: the dashboard figures were read ONCE per
    app session. `dashboardStatsProvider` now re-reads on every visit and
    every minute while open (current figures stay up while it does), so
    "Active users right now" (3.1) is current too. Sentence: "Companies,
    users and throughput — refreshed every minute while this page is open."
    `dashboard_stats_refresh_test.dart` (59 s: 1 read; 60 s: 2, shown; closed
    3 min: still 2; reopened: 3).
  - Full suite: only the 7 dashboard goldens differed; regenerated and
    compared band by band (the wording, and the one extra subtitle line
    moving the rest down).

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
      Includes: with the app open (chat never opened), Jean's
      `last_seen_at` moves every ~45 s and the dashboard shows him as active (3.1).
- [ ] 7.4 Database healthy (all services probed); migration ledger matches files.
- [ ] 7.5 Committed, pushed, APK on the NAS.
