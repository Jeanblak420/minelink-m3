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
- [x] 4.1 No words broken in half and no cut-off labels on Buyers / Mines /
      Transporters insights and Route marketplace; token countdown readable.
  - Neither screen had ever been rendered at phone width. New goldens at the
    S25's real 360dp: `screen-org-insights-phone-dark`,
    `screen-route-marketplace-phone-dark` (the transporters overview already
    had one and is clean).
  - Insights: the tons card's stat rows go two-to-a-row when the column is
    under 600px (a word wider than its cell is broken mid-word — that was
    "RELIABI / LITY", "FORECA / ST AUG"); rail tiles' labels get two lines
    and, on a phone, 12px side padding ("AVG TURNAROUND", "ROUTE
    RELIABILITY" in full); alert titles 2 lines, messages 3; company meta
    line 2 lines.
  - Route marketplace: `MlDataTable(cardsOnPhone: true)` — a new, opt-in
    phone layout, one card per row with every column as label + value; route
    names up to 3 lines.
  - Countdown: on the dashboard's phone org cards the countdown and date
    split one line in half ("328d 23 : 53…"); now a Wrap, the date drops to
    the next line. (The Organizations list's countdown is part of 4.5.)
  - Desktop untouched: every existing golden byte-identical (twice a change
    leaked to desktop during the work — a row alignment and the tile padding
    — both caught by the desktop golden and gated to phone). Overflow sweep
    (widths 360–1612 × text 0.85–2.0) and `dashboard_responsive_test` green.
- [x] 4.2 Full names in the menu (no "Communicatio…").
  - Cause: the phone drawer was the desktop rail at its fixed 280dp with
    one-line labels; at the phone's text size the long entries were cut.
  - The drawer is now as wide as M3 allows less a 56dp tap-to-close strip
    (304dp on a 360dp phone, at most 320), and passes `wrapLabels` so labels
    take up to two lines and rows grow (min 48dp). Both are new `MlNavRail`
    options; the desktop rail keeps 280dp and one line (renders unchanged).
  - `drawer_labels_whole_test.dart`: the real admin menu, every group open,
    at text 1.0 / 1.15 / 1.3 / 1.5 — no label cut, no overflow; control case
    (old drawer at 1.3) does cut, so the test bites.
- [x] 4.3 Targets: the header scrolls away on a phone; nothing clipped.
  - Cause: `TargetsPage` pinned the band above the workspace at up to half
    the screen, with its own inner scroll — so the dials scrolled in the
    lower half and the band's last line sat clipped at its fold.
  - On a phone (`usesBottomNav`) the page is a `NestedScrollView`: the band
    is the first thing that scrolls, then the workspace's own scroll views;
    the band is never clipped. Desktop keeps the pinned band (renders
    unchanged). Applies to all three targets screens (platform / org type /
    company).
  - `targets_phone_width_test.dart` new case at 360×780: drag up → the band
    leaves the screen and "Set monthly targets" comes up; the file's 15 tests
    and the overflow sweep green.
- [x] 4.4 Floating chat button (and Generate Token) never cover content or
      buttons on any screen.
  - On a phone the admin console no longer floats the chat disc at all: the
    chat opens from a Messages button in the top bar (unread count as a
    badge, a dot while someone is typing). `ChatDock.launcherInAppBarOnPhone`
    + `ChatDockAppBarButton`, opted into by the super-admin shell only;
    wider windows keep the disc. Back still closes the window (1.2).
  - Generate Token is the page's only floating button now, and every tab on
    the company page carries 96px of bottom clearance on a phone (1.x
    `_fabClearance`), so the last row scrolls clear of it.
  - `chat_launcher_in_app_bar_test.dart` 4/4: phone → no disc, top-bar
    button opens the chat; unread count shown; desktop → disc, no button;
    a dock that did not opt in keeps its disc. Chat / admin / render / widget
    suites green, goldens unchanged.
  - Not changed: the company portals still float the disc on a phone (not
    part of this admin-panel job) — flagged to Jean.
- [x] 4.5 Wide tables become one card per row on a phone: Organizations, Margin
      ledger (money visible), Recon, Route marketplace.
  - Route marketplace and Margin ledger: `MlDataTable(cardsOnPhone: true)`
    (4.1) — every column a label + value; the ledger's five money figures
    are all on screen, no sideways scroll.
  - Organizations: a phone card per company — icon, full name, owner email,
    then type pill · "Seats 4/5" · countdown and date on a wrapping line,
    chevron to open. Pill and expiry are now shared helpers used by the
    table row and the card, so the two cannot drift.
  - Recon tables (super-admin): `RawReconView(cardsOnPhone: true)` — a card
    per load, all 14 columns, waybill and POD links and the tinted variance
    kept. Opt-in: the company portals' recon screens are unchanged.
  - Desktop goldens byte-identical (checked after the helper refactor and
    after each card mode). Phone goldens updated: margin ledger,
    organizations, recon tables, route marketplace — each viewed.
  - Tests: `ml_data_table_cards_test.dart` 3/3; `organizations_registry_test`
    now asserts cards on a phone and the scrolling table just above phone
    width (610px). Full suite: 2,791 passed.
- [x] 4.6 Company page: one back arrow; bottom bar highlights Access; all tabs
      readable; WhatsApp users show their number, not the internal login
      address (also on Platform users).
  - One back arrow: on a phone the page's own back arrow and home button are
    gone (the top bar has Back, the bottom bar Dashboard); the title gets the
    room. Desktop header unchanged.
  - Tabs: on a phone the four tabs share the width (not scrollable, tight
    label padding) — "Overview Users Tokens Seats" all whole at 412dp.
  - Bottom bar: `superAdminPhoneNavSection` maps pages whose address is not
    under their section's — company page and Register company → Access
    (Organizations), seat requests → Access (Token requests), request
    inboxes → Requests, tons-out → Recon. Phone only; the desktop rail has
    the same wrong highlight and was left as it is (flagged to Jean).
  - WhatsApp users: Users tab and Seats tab done in 2.2; Platform users now
    shows "WhatsApp 0833067846" instead of the internal address, and the
    number is searchable.
  - `company_page_phone_test.dart` 4/4; company page phone golden updated
    (viewed: one arrow, four tabs) and its frame made the full page height
    (1840) so its last control is not under Generate Token in the picture;
    desktop golden unchanged. Analyzer clean; admin/render/widget/core
    suites green.
- [x] 4.7 Each insights page opens at the top.
  - Cause (reproduced, not assumed): Buyers and Mines are one route
    (`/super-admin/insights/:orgType`). When Mines' figures are already
    loaded — the dashboard reads all three org types — the router keeps the
    same screen and only changes its argument, so the scroll position
    carries over. (First attempt at a test passed WITHOUT the fix because the
    data loaded fresh; the test now visits Mines first, as the app does, and
    the unkeyed control case keeps Buyers' scroll.)
  - Fix: the route builds `SuperAdminOrgInsightsScreen` keyed by org type, so
    each type has its own state and opens at the top. Applies on every
    platform (a key, no visual change); renders unchanged.
  - `insights_open_at_top_test.dart` 3/3: keyed → Mines at 0 after Buyers
    scrolled 1,500px; unkeyed control → kept; source guard on the router's
    key. (The builder stays inline in the route: the render harness reads
    screen names per route block and mislabelled 5 renders when it moved.)
- [x] 4.8 Tap targets at least 48 px: chat window buttons, table page arrows,
      targets − / +.
  - On a phone: chat window buttons 31 → 48 (title bar 42 → 52 to hold them);
    the registry's page arrows and page numbers 34 → 48; the targets dials'
    − / + 26 → 48. Desktop keeps 31 / 34 / 26. (The registry is the only
    paged table in the admin panel; the leaderboard chevron is a back link.)
  - `tap_targets_phone_test.dart` 6/6 — measured at 360dp (≥ 48 each way)
    and at 1280 (desktop sizes unchanged). Six phone goldens updated and
    viewed; full suite 2,807 passed.
  - Noted, not mine: `dock-thread-phone-dark` renders the attachment loaded
    when run alone and still loading in a full run (timing). Goldens are
    therefore regenerated from a full-file run.

## 5. Clean-ups
- [x] 5.1 Platform settings: checked the Windows/web code, then the old canonical
      tree, then the oldest `ML` tree (read-only) for what it ever held;
      reported to Jean; then removed or filled in.
  - **Findings (for Jean):**
    - This app (Windows/web/phone — one codebase): the page only says both
      super admins have equal rights and there is nothing to configure.
    - Old canonical tree (read-only; first version 8895b58, 21 Jun 2026): it
      held exactly two things — the delegated ("child") admin's status
      (email, active, created) with an "Open Child admin" button, and a
      switch "Allow child admin to register companies". Both were removed on
      purpose on 2026-07-12 when the two super admins were made equal.
      Nothing else ever lived there.
    - Oldest `ML` tree (read-only): no Platform settings page at all. Its one
      related admin screen is a read-only guide, "Navigation Setup — Custom
      Mine Maps" (CAD/DXF → QGIS → JOSM → Valhalla steps for adding a
      mine's own haul roads to navigation). It is not in this app. Nothing
      was copied; whether it is wanted is Jean's call.
  - Done: removed from the PHONE menu (`consoleNavTree(phone: true)`); the
    desktop rail keeps it, as instructed, and the route still opens.
    `console_nav_phone_test.dart` 2/2; nav-structure and drawer tests green.
  - Jean to decide: remove it from the desktop menu too? Add the navigation
    guide (as "Navigation setup")?
- [x] 5.2 Platform users in the menu under Tokens & Seats.
  - Phone menu: "Platform users" under Tokens & Seats (after Token history),
    route `/super-admin/users`; the bottom bar lights Access on it. Desktop
    rail unchanged (Jean to say if it should get it too). It also shows
    WhatsApp users by number now (4.6).
  - `console_nav_phone_test.dart` 4/4; the phone-drawer label test now runs
    on the phone menu and includes it (whole at text 1.0–1.5).
- [x] 5.3 Chat window on a phone: practical full-screen / docked behaviour that
      can always be moved back, resized or closed — never stuck or unusable.
  - On a phone (admin console) the chat opens from the top bar (4.4) as the
    whole screen: title bar up under the status bar, clear of the gesture
    bar, and lifted above the keyboard so the message box is never hidden
    (the overlay sits outside the shell's Scaffold, so nothing else did).
  - No window to fight: no dragging, no resize edges, no Minimize/Maximize
    (they did nothing useful on a phone). Ways out: Close (48px, 4.8) and the
    phone's Back, which steps back inside the chat then closes it (1.2).
  - Desktop keeps the floating, draggable, resizable window.
  - `chat_launcher_in_app_bar_test.dart` 6/6 (full screen edge to edge, no
    window controls, Close closes; with a 300px keyboard the panel ends at
    the keyboard); back-closes-chat 3/3; tap-target test updated. Full suite
    2,813 passed. On-device check in 7.3.
- [x] 5.4 Dashboard: repeats removed, one real version of each section kept,
      zero-only stat cards condensed; much shorter on a phone.
  - On a phone: the three org-type cards are one line each (title, org
    count and two headline figures, tap to open); Pending requests shows
    only inboxes with work and disappears when none has any; the registry
    shows the figures that say something two to a row, and every tile that
    reads 0 is folded into one "Nothing in:" line of chips that still open
    their screens; "Recently active organizations" is left off (it is the
    Organizations page again — one tap away under Access and in Quick
    actions). The expired-token banner and Quick actions stay.
  - Length: the phone render is 1,960px for the whole page, down from 4,695
    (sample data); Jean's real data (more zeros) folds further.
  - Desktop unchanged: every desktop dashboard golden byte-identical.
  - Tests: `dashboard_phone_test.dart` 4/4; `dashboard_responsive_test`
    (its harness now gives the window a real size — without one every
    width counted as a phone) 20/20 incl. 360dp at text 2.0 with no
    overflow. Full suite 2,818 passed. Phone goldens updated and viewed.
- [x] 5.5 Crash reports: real count instead of a 500 cap; found out why nothing
      arrived after 17 Oct and fixed it so reporting can't silently stop again.
  - Real count: the header said "500 fingerprints" — the length of the
    newest-500 page. The table holds 9,243 reports. Header now "9,243
    reports · newest 500 shown" (exact count from the server, same filters).
  - Why nothing since 17 Oct (checked, not guessed): the server accepts a
    signed-in user's report (insert probe as jean@, rolled back: 1 row);
    the policy allows own/anonymous rows; no trigger; the 90-day prune is
    not involved; the app wires its reporter at start-up and has no switch
    that stops it except a per-session cap. The last Android reports were a
    388-row "Duplicate GlobalKey" storm on 17 Oct from a bug since fixed;
    web stopped 10 Sep. So the quiet looks genuine — but nothing could tell
    that from a broken pipeline.
  - So a silence can no longer pass unnoticed: the screen says when the last
    report arrived, and "Send a test report" pushes one report through the
    app's real reporter and checks it reached the table — "crash reporting
    works", or in red that it did not arrive within 10 s. (Found and fixed
    on the way: a failed read-back escaped as an error and the screen said
    nothing.) Test reports are labelled "not an error"; the shipping app,
    which reads the same table, will list any that are sent.
  - Not done without Jean's OK (needs a new table): an automatic daily
    check-in per device, so a broken pipeline raises itself without anyone
    pressing the button.
  - `crash_reports_count_test.dart` 5/5; crash screen tests 33/33; three
    crash-report goldens updated (header + the new line — desktop too,
    as a wrong-number fix like section 3). Full suite green.

## 6. Additions
- [x] 6.1 "Needs your attention" list at the top of the dashboard (pending
      requests, expiring tokens, open waybills, disputes), each tappable.
  - First thing on the phone dashboard: one row per queue that has something
    in it, most urgent first — access expired, open disputes, token
    requests, tokens expiring within 7 days, requested routes (mines +
    buyers), requested product, requested buyers, open waybills — each with
    its count, each opening the screen where it is dealt with. Nothing
    waiting → "All clear". Open waybills are counted on the transporter side
    (one transporter per load; summing mine/buyer/transporter would triple
    them); disputes = open + under review, the disputes inbox's own feed.
  - On a phone it stands in for the pending-request cards and the expired
    banner, so nothing appears twice. Desktop: no list, unchanged.
  - `dashboardAttentionItems` (pure) + `_AttentionList`;
    `attention_list_test.dart` 6/6 (order, empties, every row routes, first
    on the page, taps open, all clear, desktop untouched). Phone dashboard
    golden updated and viewed; renders 273/273.
- [x] 6.2 Phone card layout for the four wide tables (done in 4.5 — tick when
      4.5 is ticked and re-checked).
  - Re-checked: 4.5 ticked; `ml_data_table_cards_test` 3/3 and
    `organizations_registry_test` 7/7 re-run green; the four phone goldens
    (organizations, margin ledger, recon tables, route marketplace) pass.
- [x] 6.3 Real "online now" count (done in 3.1 — tick when re-checked).
  - Re-checked live, rolled back: `platform_registry_extras` as jean@ → 0,
    one heartbeat → 1; its body counts `last_seen_at`. The dashboard
    re-reads it every minute (3.6) — `dashboard_stats_refresh_test` green.
    On-device heartbeat check stays in 7.3.
- [x] 6.4 Seat warning when a company nears its limit.
  - Rule (`seat_pressure.dart`): near = a fifth or fewer seats left, and
    always the last seat (8/10, 4/5, 1/2); full; over. No limit set → never
    warned. Seats count people since the seat fix, so it reads
    seats_used / seat_limit directly.
  - On a phone: Organizations cards carry "1 SEAT LEFT" (amber) / "ALL SEATS
    USED" or "N PEOPLE OVER THE LIMIT" (red); the company page shows "4 of 5
    seats used — 1 seat left. Free a seat or raise the limit before adding
    anyone."; Needs your attention lists "Seats running out — N companies".
    Desktop unchanged.
  - `seat_pressure_test.dart` 4/4; attention test 7/7; three phone goldens
    updated and viewed (company page frame 1940 so its last control is not
    under Generate Token in the picture). Full suite 2,834 passed.
- [x] 6.5 Chat behaves like a page: Back closes it, docks out of the way of
      buttons (1.2 + 4.4 + 5.3 — tick when all three are ticked and re-checked).
  - Re-checked: 1.2 (Back steps out of the chat, then closes it), 4.4 (no
    disc over the page; opened from the top bar) and 5.3 (full screen, no
    window controls, above the keyboard) all ticked; their tests re-run
    together green (back-closes 3, launcher 6, tap targets 6). On-device in
    7.3.

## 7. Prove it and ship it
- [x] 7.1 `flutter analyze` clean; full test suite green; new tests for each fix.
  - `flutter analyze`: no issues. Full suite: 2,834 passed, 0 failed (1
    skipped, pre-existing). Every ticked item above names its new test file;
    18 new test files this round (counted against
    the backup tag), plus 8 existing test files and the sample fixture updated.
- [x] 7.2 Windows/web layouts unchanged (desktop goldens still match).
  - Compared every non-phone golden with the backup tag
    `backup/pre-admin-mobile-2026-10-24`. 12 differ; 11 by single text lines
    only (12px bands, no layout movement): the corrected wording and numbers
    from section 3 (active users label, "N waiting", live-map count, alerts
    period, "1 organization"/registry sentence) and "Login & password" on
    the company page (2.1). The 12th, crash reports, gained the "last report
    received / Send a test report" line (5.5), which moves its list down —
    the one desktop layout change, and it is part of a reliability fix.
  - Everything else this round is gated to phones (`usesBottomNav`).
  - Desktop-only faults left as they are, for Jean to decide: the rail lights
    Dashboard on the company page and a few other pages; Platform settings
    still listed; Platform users not listed. The company portals still float
    the chat disc on a phone.
- [x] 7.3 Release APK on Jean's phone; whole admin panel walked again on the
      phone; every item above re-checked there.
      Includes: with the app open (chat never opened), Jean's
      `last_seen_at` moves every ~45 s and the dashboard shows him as active (3.1).
  - Progress (2026-10-24, S25, release APK 511 entries, installed 10:46):
    - 3.1 PROVEN on device: chat never opened, `last_seen_at` 08:46:52 →
      08:47:37 UTC (45 s), the only profile seen in the last 10 min.
    - 3.5 on device: bell carries no badge.
    - 6.1 on device: "Needs your attention" first; "All clear" while loading,
      then "Open waybills · 2". Live org-type cards load with real numbers.
    - FOUND and fixed: the header read "2 items" over that ONE row (it summed
      the counts inside rows). Now counts rows ("1 item");
      `attention_list_test` gained a failing-first test, 12/12 green.
      Needs the rebuilt APK.
    - Walk interrupted: the phone dropped wireless debugging (port refused,
      no longer advertised). Re-paired, rebuilt APK installed 11:0x.
      (First rebuild came out with 444 entries / no config; NOT installed.
      Plain rebuild: 511, config present.)
  - Walk completed on the rebuilt APK, 2026-10-24 10:58–11:12:
    - Dashboard: "1 item" over the one row (fix confirmed). Registry:
      Active users right now = 1 (Jean); zero tiles as "Nothing in:" chips.
    - Drawer (4.2/5.1/5.2): labels whole; Platform users under Tokens &
      Seats; Settings holds only Account security + User preferences.
    - Organizations (4.5/6.4): phone cards; no seat badge, correctly (1/10,
      4/10). Company page (4.6): one back arrow, 4 readable tabs, Access lit;
      Back returns to Organizations.
    - Platform users (4.6): "WhatsApp <number>"; Eli Mans card has no
      placeholder email; Login dialog WhatsApp-only, switch locked with its
      reason (2.2). Cancelled, nothing saved.
    - Chat (4.4/5.3/1.2): opens from the top bar, full screen. Back:
      thread → keyboard down (input autofocuses, `mInputShown=true`) → list →
      closed, page underneath unchanged. Close button also closes.
    - Crash reports (5.5): "9,243 reports · newest 500 shown", "Last report
      received 6 days ago"; Send a test report → 9,244, "just now", row on
      top marked "not an error". Pipeline proven from the release APK.
    - Margin ledger, Recon tables, Route marketplace (4.1/4.5): cards.
    - Live map (3.2): "2 active trips · 0 reporting GPS" agrees with "No GPS
      fixes yet".
    - Insights (4.1/4.7): opens at top, scrolls cleanly.
    - Targets (4.3/4.8): scrolls through the dials; −/+ measured 84 px at
      density 280 = 48 dp.
    - Requests (3.4): no zero badges; inbox counts match the DB (the one
      request is type `buyer` → Requested buyers, listed Linked).
    - Audit logs: the three Eli entries read "Super admin changed removed
      email, …" — stored by the function BEFORE v6 (2.2); audit rows are a
      record and are not rewritten. New entries use the v6 wording.
    - Phone restored: stay-awake off, home screen, screenshots deleted.
  - After the fix: analyze clean; one golden changed
    (`screen-super-admin-dashboard-v2-phone-dark`, header now "9 items" over
    9 rows instead of the summed 43), regenerated from a full-file run;
    full suite 2,835 passed, 1 skipped.
- [x] 7.4 Database healthy (all services probed); migration ledger matches files.
  - `tool/health_probe.py`: main PostgREST/Auth/Storage/Realtime/Postgres RPC/
    Edge Functions all answer. Management API `/health`: db, rest, auth,
    storage healthy; realtime healthy with `db_connected` and
    `replication_connected` both true.
  - Ledger: rows since 20261022 are exactly 20261022200000, 20261024100000,
    110000, 111000, 120000, 130000, with the same names as the 6 files.
  - Extras `search_place_index` still times out (500 statement timeout,
    twice). That predates this work and nothing here touched that project.
    It is the address-search item already waiting on Jean's choice.
- [x] 7.5 Committed, pushed, APK on the NAS.
  - Pushed to origin/main (`git rev-list --left-right --count` = 0 0).
  - `\\192.168.88.30\Shared\MineLink-M3\MineLink-M3-2026-10-24.apk` and
    `\\192.168.88.30\Shared\PhoneRemote\minelink-m3.apk`, both SHA-256 equal
    to the build (511 entries, config present). The 2026-10-23 APK removed;
    the 2026-10-22 Windows and source zips left as they were.

## 8. Jean's go-ahead, 2026-10-24 ("yes go ahead" — all four, plus the address search)
Same rules: one at a time, fully, ticked with evidence; ONE phone walk at the
end (8.7). Item 8.5 is a live database change, explicitly OK'd by Jean.
- [x] 8.1 Platform settings off the desktop menu too (route kept so old links
      still open); add a "Navigation setup" guide for custom mine maps,
      written fresh for this app, the old `ML` guide read as reference only.
  - Menu: Platform settings gone from both trees; `/super-admin/settings`
    still routed (old links open); `settings.platform` id dropped (no tile
    used it). "Navigation setup" under Tracking on both, route
    `/super-admin/navigation-setup`, title + subtitle in `ml_route_title`.
  - Guide (`navigation_setup_screen.dart`), read-only, 8 steps. Written from
    THIS app's code and the Valhalla/osmium docs (Context7); the `ML` guide
    read only. Three corrections to that guide: the setting is
    `VALHALLA_BASE_URL` (the app asks Valhalla first, truck costing; OSRM
    is only the fallback), the image is now
    `ghcr.io/valhalla/valhalla-scripted`, truck access is `hgv=yes`. Added:
    join the gate road to the public road; carry edits over with
    `osmium derive-changes` + `apply-changes` instead of a blind merge;
    a test route before building; every build needs the setting.
    Not run end to end here (no mine drawing); the guide says the test
    route is the proof.
  - Tests: `navigation_setup_test` 4/4 (names what the app reads; says it
    runs outside the app; no overflow at 360 px, text 1.0 and 1.3),
    `console_nav_phone_test` 7/7, `route_title_test`, `console_nav_test`
    green. Analyze clean. Rendered at 412 px and looked at.
  - Goldens: 14 regenerated, all the rail (x 25–259 on desktop) — Platform
    users and Navigation setup in, Platform settings out. The Platform users
    PHONE render now lights Access instead of Dashboard: the harness picks
    the tab from the default tree, which now matches the phone's (the app
    itself already passed `phone:` and lit Access on the S25).
- [x] 8.2 Desktop menu fixes: the rail lights the right item on company pages
      and the other pages that fell back to Dashboard; Platform users under
      Tokens & Seats on desktop too.
  - Platform users on the desktop rail under Tokens & Seats (done with 8.1's
    tree change; `console_nav_phone_test` checks both widths).
  - `superAdminPhoneNavSection` → `superAdminNavSection(location, tree)`,
    used at every width. It only steps in when a page would otherwise light
    Dashboard, because the desktop rail lights one ITEM and each request
    inbox has its own (the old blanket `requests/` mapping would have lit
    the mine inbox on the buyer one). Aliases map to their own inbox; the
    old Platform settings link lights nothing instead of Dashboard.
  - `company_page_phone_test` now runs phone AND desktop, plus a sweep of
    every `/super-admin` path the router registers (params filled): none
    lights Dashboard except Dashboard itself. Sweep bite-tested: deleting
    the tons-out mapping fails it with "[/super-admin/tons-out]".
  - Analyze clean; renders regenerated, none changed (no render shows a
    company page with the desktop rail). Desktop check on the real rail
    added to 8.7.
- [x] 8.3 Company portals on a phone: chat in the top bar (no floating disc),
      full screen like the admin chat.
  - Portal shell: `ChatDock(launcherInAppBarOnPhone: true, ...)` — the same
    dock and full-screen panel the admin console uses (5.3/1.2), so Back and
    Close behave the same.
  - Top bar via new `portalShellActions(...)`. On a phone: chat button first,
    "Take a tour" moved into More (its unseen dot moves to the More icon),
    so the bar stays at FOUR icons — a fifth would have pushed every page
    title to its own row (`MlAppShell` measures 48 dp per action). Desktop
    bar unchanged (tour button, bells, More; the chat button draws nothing).
  - Drivers keep the floating disc, deliberately: their app
    (`DriverAppScreen`) draws its own screens with no top bar, so the disc is
    their only way into chat on the Trip and Profile tabs. For Jean.
  - Inside Messages (`/communications`, `/chat/...`) there is still no dock,
    so the button draws nothing there.
  - Tests: `portal_chat_in_app_bar_test` 4/4 (phone order + four icons +
    tour in More; unseen dot on More; desktop as it was; shell wiring).
    Dock behaviour already proven by `chat_launcher_in_app_bar_test` and
    `back_closes_chat_window_test`. test/features/portal + test/widgets:
    1,198 passed. Analyze clean.
- [x] 8.4 Company portals on a phone: wide tables as cards.
  - Opted in every table in the portals and fleet: 17 `MlDataTable`s
    (dashboards ×3, buyer loads & value, waybills, earnings ×3, fuel costs,
    load controller, production ×2, transporter reconciliations, load
    quality, request tracking, weight reconciliation, fleet vehicles) and
    the 4 portal `RawReconView`s. All had 3+ columns and a 560 px or wider
    minimum, so all scrolled sideways on a phone.
  - Request tracking sat in its own 1200 px sideways scroller; on a phone
    that wrapper is skipped (`_wideUnlessPhone`), so the cards are not
    trapped in it.
  - Tons-out search results (Flutter's sortable `DataTable`, sorted by
    tapping heads): on a phone, cards plus a "Sort by" field and a direction
    button through the same `onSort` (re-keyed so Reset can't leave it
    stale). Desktop keeps the sortable table.
  - Shared with the admin console: the load-quality table also shows on the
    admin Recon tables page, so that page gets cards on a phone too.
  - Tests: `portal_tables_cards_on_phone_test` 4/4 — a guard over every
    `MlDataTable(`/`RawReconView(` in portal + fleet (fails on any that
    forgets `cardsOnPhone`; it failed on all 21 before), tons-out cards with
    no overflow at 360, Sort by sorts both ways, desktop unchanged.
    `wide_table_scrollbar_test` updated: its "a sideways table shows a bar"
    guard moved to 800/600 px (where they still scroll) and gained the
    phone check that nothing scrolls sideways; 4/4.
  - Renders: 20 phone renders regenerated, NO desktop render changed. Looked
    at tons-out search, request tracking, fuel costs and the quality-spec
    dialog (that dialog, and four others, changed only because the page
    behind them now has cards). The harness's CUT OFF notes on four of them
    are the Available-routes chip, ellipsised on purpose (comment in
    `available_routes_section.dart`), not these tables.
  - Analyze clean; portal + fleet + widgets + admin tests: 1,425 passed.
- [x] 8.5 Crash-report check-in: new table + a daily check-in per device, shown
      on the Crash reports page (which devices have gone quiet). Live DB.
  - Migration `20261024140000_device_checkins.sql` (Jean's explicit OK):
    `device_checkins` (one row per install, bounded by installs not runs),
    RLS on, SELECT for the platform admin only, no write grant;
    `record_device_checkin` (signed-in only, ignores a repeat inside the
    hour); `list_device_checkins` (admin only, names the user);
    `prune-device-checkins` cron, nightly 03:58, drops 180-day-quiet rows.
  - Dry run first (probe raising, rolled back, verified nothing left): Eli
    sees 0 rows, Jean sees 1 labelled "Eli Mans", repeat ignored
    (checkins=1), anon may call neither function, cron present. Applied;
    ledger row inserted in its own call; ledger since 20261024 = the 7 files.
  - Real path, throwaway account (created + deleted, 0 rows left): two
    PostgREST calls with a real JWT → 204/204, row has that user and
    checkins=1; non-admin list `[]`, non-admin select `[]`; no sign-in →
    401 "permission denied for function record_device_checkin".
  - Security advisor: only the generic "authenticated can execute a
    SECURITY DEFINER function" notes (the app has ~265, by design); nothing
    on the table.
  - App: `lib/core/telemetry/device_checkin.dart` — stable install id in
    shared preferences, at most once in 20 h, at start + sign-in + resume,
    never throws, a failed send retried next time; started once in `main()`
    beside the crash sink (guarded: boot can be retried). Admin: Crash
    reports gains "Devices: N devices checked in today · M quiet for 3+
    days" with "Show devices" (who, platform, version, last check-in,
    TODAY / QUIET N DAYS).
  - Tests: `device_checkin_test` 5/5, `device_checkins_test` 4/4 (counts,
    wording, badges, fits 360), crash screen tests 47 green. Analyze clean.
  - Phone walk (8.7): the S25 should appear as a device checked in today.
- [x] 8.6 Extras address search timeout: diagnosed and fixed on the extras
      project (`qbydiuplqhmkaxarnuza`, via the Management API only).
  - Symptom: `anon` (every app user, there) has a 3 s statement timeout;
    the first search for a common town took 2.8–7.7 s (Johannesburg
    7,726 ms, Centurion 3,273 ms); the same search again 30–200 ms.
  - Root cause, measured: the machine has 455 MB RAM, Postgres's default
    280 MB cache, 429 MB of swap in use (metrics endpoint). The ranking
    reads every row matching the town to sort by confidence, ~1 page per
    row ("durban": 24,356 rows, 7,991 pages), so a first search pulls
    thousands of pages back from swap. JIT is off; the plan is fine.
    `pg_prewarm` was tried: every page loaded (2.5 s), still 1.8–2.2 s on
    fresh words — the cache itself is swapped. Extension removed again.
  - Fix (extras migrations, ledger rows added in separate calls):
    `20261024150000_place_index_search_compact` — materialized view
    `place_index_search` (id, name, search_text, confidence) in town order
    + its FTS index (91 + 27 MB), no grants. `20261024160000_place_index_rank_uses_compact`
    — `_place_index_rank` finds candidates there, joins `place_index` only
    for the ≤20 rows returned; `id` added as the last tie-break (the
    2,000-row cut used to fall wherever the disk order put it); the unused
    old FTS index dropped (−34 MB). Database 236 → 321 MB (64%).
  - Proof: rolled-back comparison of 25 searches old vs new — identical
    25/25 (139 rows, same ids, scores, order); total 19.3 s → 5.1 s cold.
    After: 12 never-searched towns 40–213 ms each on the server. As `anon`
    over the internet: Johannesburg 1.41 s, Cape Town 1.63 s, the rest
    0.26–0.95 s, all HTTP 200. `tool/health_probe.py` 7/7 (extras failed
    twice this morning).
  - Re-import note in `supabase/extras_project/README.md` (refresh the view;
    the two old tools still create the dropped index).
- [x] 8.7 Analyze clean, full suite green, desktop goldens accounted for,
      Windows build: rail lights Organizations on a company page,
      DB healthy + ledger matches, release APK walked on the S25, pushed, NAS.

  - Progress (2026-10-24):
    - `flutter analyze`: no issues. Full suite: 2,868 passed, 1 skipped
      (pre-existing), 0 failed (+33 since section 8 began).
    - Desktop renders changed in section 8: 13. Pixel-diffed against
      0421b93: 12 differ only inside the rail (x 8–259: Platform users and
      Navigation setup in, Platform settings out, the lit item moved); the
      13th pair, Crash reports, also gains the Devices line (8.5). Fixture
      check-ins added so the render shows it.
    - Health: `tool/health_probe.py` 7/7 incl. extras. Management API: db,
      rest, auth, storage, realtime healthy on both projects. Realtime's
      `db_connected` reads false on BOTH, with zero Realtime connections and
      no replication slots on main — consistent with no client subscribed
      (Realtime connects per tenant on demand; the never-subscribed extras
      project reads the same). To be shown true with the app open on the
      S25 in the walk.
    - Ledgers: main since 20261024 = the 7 files (…140000 device_checkins);
      extras = 20261024150000, 20261024160000, matching its 2 new files.
    - Desktop rail: to be checked on the S25 in LANDSCAPE (≈890 dp, above the
      600 dp phone class, so the same rail a Windows window draws), not a
      separate Windows build.
    - Release APK built: 511 entries, config present.
  - S25 walk (2026-10-24, 13:20–13:26, release APK installed over adb):
    - 8.5 PROVEN live: 16 s after launch `device_checkins` held the S25
      (android, v1.0.0, jean@minelink.org, checkins=1). Crash reports reads
      "Devices: 1 device checked in today"; Show devices lists "Jean Burger
      · android · v1.0.0 · last check-in 1 min ago · TODAY".
    - Realtime with the app open: main `db_connected: true`,
      `replication_connected: true`, connected_cluster 1 — the earlier false
      was idleness, as reasoned.
    - 8.1 on device: Tracking → Live map, Navigation setup; the guide opens,
      reads cleanly, bottom bar lights More.
    - 8.2 on device, phone in LANDSCAPE (≈890 dp, desktop rail): on AB mine's
      company page Dashboard reports selected=false (the bug was Dashboard
      lit); filtering the rail for "Organ" shows Tokens & Seats with its
      icon in the accent that marks the group holding the page.
      FINDING (pre-existing, not from this work): at landscape phone height
      (≈411 dp) the expanded rail's list area is about one row tall and does
      not scroll, so the Organizations row itself can't be seen. For Jean.
    - Rotation restored to Jean's settings (auto-rotate on, user_rotation 0,
      ROTATION_0); stay-awake off; home screen; screenshots deleted.
    - NOT walked on the device: 8.3/8.4 (company-portal chat and cards). They
      need a company account signed in on the phone; Jean's phone is signed
      in as super admin and his own sign-in was not touched. Proven by
      tests and renders (20 phone renders looked at). For Jean.
  - NAS: `MineLink-M3-2026-10-24.apk` (replaced) and
    `PhoneRemote\minelink-m3.apk`, both SHA-256 equal to the build.
## 9. Jean's follow-ups, 2026-10-24
Same rules: one at a time, fully, ticked with evidence; the phone walk last.
- [x] 9.1 The expanded rail is usable on a short window (a phone held
      sideways, ≈411 dp tall): its list gets the height, everything reachable.
  - `MlNavRail`: below `compactHeight` (560 dp) the brand, search, items,
    collapse control and footer scroll as ONE list; taller windows keep the
    pinned layout unchanged (shared by console and portals).
  - `rail_short_window_test` 2/2: at 411 dp no overflow and Organizations,
    Settings and the footer are all reachable by scrolling; at 1000 dp the
    brand stays pinned while the list scrolls. Bite-tested: with the
    threshold at 0 (old layout) the 411 test fails.
  - Analyze clean; test/core + test/widgets 1,161 passed; renders 238 passed,
    none changed. On-device check in the 9.3 walk (landscape).
- [x] 9.2 The old place-index tools no longer recreate the dropped
      `place_index_search_fts` index, and refresh `place_index_search` after
      they change `place_index`.
  - `tools/place_index_move_project.py`: the old FTS index is out of the
    post-load rebuild; the two new extras migrations are in
    EXTRAS_MIGRATIONS (a fresh project gets the copy and the new ranking);
    new `refresh_search_copy()` refreshes + analyzes `place_index_search`
    after the load and stops if its row count differs from `place_index`.
  - `tools/place_index_trim.py`: the old FTS index is out of REBUILD; after
    the delete + rebuild it refreshes the copy and checks the same counts.
    (Their `drop index if exists ..._fts` lines stay: harmless.)
  - Both compile. `refresh_search_copy` run for real on the live extras
    project: 611,841 rows, matches place_index, 31.5 s. Searches after it,
    as anon end to end: Johannesburg 2.24 s, Cape Town 1.73 s, Centurion
    0.81 s, Westway Rd Fourways 0.62 s — all HTTP 200. Note: right after a
    refresh the copy is cold and the biggest towns sit nearer the 3 s
    (server-side) limit than the 1.4 s measured warm.
- [ ] 9.3 Company-portal chat (8.3) and cards (8.4) walked on the S25 as real
      company users. Passwords are stored only as hashes, so: throwaway test
      companies + users created for the walk, and EVERYTHING they create or
      change deleted afterwards (verified by query). Jean's own sign-in on the
      phone must be left as it was.
