# MineLink M3 — what is left, and nothing else

**Last updated:** 2026-08-23 · M3 at **165 commits** · tip `bb80505` · worktree baseline `df451d0` intact
**Open this file in the IDE:** `code "C:\Users\Somebody Someone\Music\SHOWME!\MineLink-M3\M3-TASKS.md"`
**Progress:** recount with `grep -c '^- \[x\]' M3-TASKS.md` — never increment by hand.

**Rules of this file**
- A task is ticked `- [x]` **only** with an evidence line under it: `✅ <date> · commit <sha> · proven by <what was run / seen / measured>`.
- A task that cannot move keeps `- [ ]` and gets `⏸ BLOCKED — <on what> — <what unblocks it>`. Never a silent tick.
- A phase is marked `Status: DONE <date>` only when every task in it is ticked.
- Every change to this file is committed with the work it records. One line per session in the Session log at the bottom.

**Standing rules (Jean, verbatim)**
- *"NO CHANGES WHAT SO EVER INSIDE OF "C:\Users\Somebody Someone\Music\SHOWME!\worktree-2026-05-05T11-53-29" then I'm happy"* — reads are fine; writes and mutating git are not. `supabase/` in this fork is frozen.
- *"if you need to use my phone via ctrl bridge and the phone is not responding that you should pause the process right there so that I'll respond to you that the phone is no longer asleep and that you can try again"* — check `probe`, not just `status`; keep working on what does not need it.
- *"bro make a nother plan for a mouse, I'm using mine"* — never move the mouse; CDP or the emulator only.
- *"don't worry about me seeing anything, I'll want to see when everything is complete and done, so don't stop so much in between please run the task for as long as possible so that we can get this completley done and sorted please, correct your self where you make mistakes and fix the mistakes and make sure you don't implement anything with gaps in them make sure its full and proper like the original"*
- Fix as you go: every fix gets a test that BITES (sabotage it, watch it fail, restore), and is looked at where it shows. When he says "pause here", produce the full copy-paste handoff message immediately.

---

## Phase 0 — every session, at the start and at the end  *(repeats; never marked DONE)*

- [ ] Worktree baseline re-checked: HEAD `df451d0` · 3 pre-existing modified files · 14163 files (`find . -path ./.git -prune -o -type f -print | wc -l`) · 2 worktree entries · 0 modified today
- [ ] `code M3-TASKS.md` run, so this file is open in the IDE
- [ ] Full gate green at session end: `flutter analyze` · `flutter test` · `dart tool/release_guards.dart` (+ `--selftest`) · `py -3 tool/_sabotage.py` · `type_scale_codemod.py --selftest` · `dropdown_width_check.py` · `glyph_coverage_check.py` · `one_clock_check.py` (+ `--selftest`) · `unphotographed_screens.py` · `health_probe.py` · `flutter test test/renders` (after any visual change) · `flutter build web --release` · `flutter build apk --debug`
- [ ] Every Claude-owned browser closed; `HANDOFF.md` §8 rewritten to the verified state and committed together with this file

---

## Phase 1 — the handset: prove the last fixes on glass   **Status: OPEN** *(needs the phone awake)*

The phone last ran the APK built at `963ca7e`. The APK carrying the TIME-IN fix is built, hashed and staged: `build/app/outputs/flutter-apk/app-debug.apk` = `\\192.168.88.30\Shared\PhoneRemote\minelink-m3.apk`, SHA-256 `6BCAE044229625FB32E770DC5CFA62D38EA6A3E584AF8F07BDA54F0663D82422`, both ends match.

- [ ] Install APK `2b235c4` on the SM-G780G (My Files → Network storage → jean → Shared → PhoneRemote → minelink-m3.apk → Update → Open)
- [ ] `/super-admin/recon-tables` at Jean's raised font size: the TIME-IN column reads `12:35` on ONE line
- [ ] Driver hero card (`roadhaul.driver`): `CURRENT TRIP` and the status pill sit on two lines with NO yellow-and-black stripe
- [ ] Load controller truck row (`ironhills.controller`) and the buyer reconciliation card (`atlasbuyer.owner`): no overflow at the raised text size
- [ ] `Duplicate GlobalKey`: baseline count → six or seven navigations → re-count = 0 new rows (SQL in HANDOFF §5)
- [ ] Phone left signed in as the platform admin, on `home`, every screenshot deleted

Done when: all six ticked with what was seen; any defect found is fixed, tested, rebuilt, re-installed and re-seen on glass.

---

## Phase 2 — the flows nobody has ever driven   **Status: OPEN** *(CDP browser or emulator; no phone needed)*

- [ ] **POD leg** of trip `0d9c6792` as `roadhaul.driver`: POD photo attached (`DOM.setFileInputFiles`), delivered tons entered, trip → `offloaded` / `completed`; Reconciliations Side B shows the mine-net vs delivered variance; the buyer's Loads & value updates
- [ ] **Request → approve → link → dispatch, FROM THE FORMS**: Request Transporter/Routes (buyer AND mine, Ongoing and Single request), Request Product, Request Buyer (multi-PDF lab results, image, FOB/FOT, map picker); the `sent_back ⇄ resubmitted` revision loop; the four super-admin inboxes; pricing/margin; the due-diligence gate; transporter accept; fleet + driver allocation; the auto-created capped stockpile and all three dispatch notifications
- [ ] **Chat at length**: two real accounts, both directions, attachments, reply quotes, mentions, presence, on phone width and desktop
- [ ] Every defect found in this phase fixed in M3, pinned by a test that bites, seen in the browser/emulator, committed one per fix

Done when: each flow has been driven end to end against live data and its record is in `docs/redesign/VERIFICATION.md`.

---

## Phase 3 — per-screen design pass against the console reference   **Status: OPEN**

The redesign so far is the theme, the shell, the components, the shape/type scales, and every defect found by driving. No screen has been reviewed one by one against `docs/design-reference/` and the super-admin console. That is the remaining design work.

- [ ] Console (super-admin) screens — all of them, at desktop / medium / phone, dark and light
- [ ] Mine portal — dashboard, operations tabs (security, weighbridge, loads, gate), supervisor stockpiles, production, quality, reconciliations, locations, employees
- [ ] Buyer portal — dashboard, requests, loads & value, reconciliations, live map
- [ ] Transporter portal — dashboard, routes, fleet management, maintenance, trucks on route, reconciliations, live map
- [ ] Driver app — 3-tab shell, trip, navigation, POD, history, profile
- [ ] Shared — auth screens, profile, settings, chat dock + messages, notifications, every dialog

Per screen: render → compare placement, hierarchy and spacing to the reference → fix the drift → regenerate the render → pin with a test.
Done when: every route target carries a dated "reviewed against reference" line in `docs/redesign/VERIFICATION.md`.

---

## Phase 4 — tests only a real device on a real road can run   **Status: OPEN** *(needs Jean in a vehicle with the phone)*

- [ ] Live GPS along a real road: a ping every 30 s reaches `vehicle_positions`; the live map follows the truck
- [ ] Turn-by-turn with voice, auto-reroute on a deliberate wrong turn, arrival detection
- [ ] The Android foreground service survives 20+ minutes backgrounded with the screen off
- [ ] Battery drain over one real trip recorded

The emulator's `adb emu geo fix` drives have already proved the navigation stack; this phase is the physical proof. ⚠️ Live-location sharing writes Jean's real position to `vehicle_positions` — only with his say-so.

---

## Phase 5 — database fixes the app needs, owed to the shipping project   **Status: BLOCKED on Jean**

`supabase/` is frozen in this fork and the worktree is frozen, so these need a migration applied from the shipping project. M3 uses the same database, so M3 behaves wrongly until they land. Each was measured, not inferred (HANDOFF §6).

- [ ] `record_truck_load` records a load it could not deduct from any stockpile and says nothing → raise a warning, stamp `metadata.undeducted_tons`, notify the supervisor
- [ ] `transportation_requests.seal_required` and `routes.seal_required` diverge in production with nothing reconciling them → linking copies the flag onto the request, or the request's copy stops being a source of truth once a route exists
- [ ] `stockpiles` is not in the realtime publication, so the "live fill" is live-on-load only → `alter publication supabase_realtime add table public.stockpiles;`
- [ ] The transporter can read the buyer's `rate` server-side (`transportation_requests` RLS) — the Dart side is already fixed here
- [ ] Nothing server-side rate-limits inserts into `crash_reports`, and `prune_telemetry_job()` at 90 days is too slow for a burst (the 293 MB incident)
- [ ] The waybill names the person by `profiles.display_name`, unlike every other surface

⏸ BLOCKED — Jean decides where and when these are applied (the shipping worktree, by a session allowed to write there).

---

## Phase 6 — platforms   **Status: BLOCKED on Jean**

- [ ] Windows build — needs the project moved to a path without `!` (Flutter refuses `SHOWME!`) AND `firebase_core`'s Windows CMake extraction resolved. Jean said Windows is optional; his call whether to move the folder.
- [ ] iOS — no reachable Apple Developer account.

---

## Phase 7 — safety of the work itself   **Status: OPEN**

- [ ] M3 has **no git remote**: 165 commits exist on this disk only, and a power cut has already destroyed a file mid-write once → Jean creates a private GitHub repo; the session secret-scans and pushes `main`
- [ ] Remove the leftover firewall rule `CtrlBridge APK download (TCP in)` — Jean's elevated PowerShell: `Remove-NetFirewallRule -DisplayName 'CtrlBridge APK download (TCP in)'`

---

## Decisions only Jean can make *(not tasks until answered)*

- The chat dock is **not** mounted on `/chat/:id` because it covered 61% of the send button. Keep it that way, or make the fix geometric?
- The fork inherited the shipping app's v1.0 checklists (`To-Do's.md` 413 items at 109 done; `COMPLETION-CHECKLIST.md` 157 gates at 107). They have never been updated in M3. **Assumed here: that work belongs to the shipping app, not to the redesign.** Say so if that is wrong.

## Deliberately NOT on this list *(so nobody re-adds them)*

- Targets `lock_target_cycle` / `start_new_target_cycle` — permanent on production; drive them only when a real cycle is genuinely being committed.
- 128 typeface-named sites held by the `typeface-named-by-hand` ratchet (const literals, the `MlOv` port, `CustomPainter`) — measured drift ≤ 1.4 px, left on purpose.
- No spring motion — Flutter 3.44.8 ships no `MotionScheme`.
- The driver's phone bar is an explicit override, not derived from the nav tree — deriving it would relabel and reorder his primary navigation.
- Mine premium appearance directions skin the workspace, not the navy rail — by design until chrome variants are decided.
- Outside M3 entirely: plaintext DB credentials in the shipping repo / on GitHub / the website's `config.php`; `minelink.org` in registrar `clientHold`; the CtrlBridge PIN on the share; CtrlBridge not in git; the decoy folders sharing a name. Real, but they belong to Jean and the other projects.

---

## Session log

- 2026-08-23 · 165 commits · file created from the verified state of the tree; nothing marked yet. Phone: reachable, host mode on, display OFF (probe 0.061 bits/pixel).
