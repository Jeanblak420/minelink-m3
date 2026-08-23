# MineLink M3 — what is left, and nothing else

**Last updated:** 2026-08-23 · M3 at **205 commits** · tip = the commit carrying this line (parent `351b029`) · worktree baseline `df451d0` intact
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

- [x] Worktree baseline re-checked: HEAD `df451d0` · 3 pre-existing modified files · 14163 files (`find . -path ./.git -prune -o -type f -print | wc -l`) · 2 worktree entries · 0 modified today
  ✅ 2026-08-23 (session start) · `git rev-parse` = df451d0 · `git status --porcelain` = the same 3 files · find = 14163 · `git worktree list` = 2 entries · 0 files newer than today
- [x] `code M3-TASKS.md` run, so this file is open in the IDE
  ✅ 2026-08-23 · commit 8d92de4 · VS Code window title reads "M3-TASKS.md - Visual Studio Code"
- [ ] Full gate green at session end: `flutter analyze` · `flutter test` · `dart tool/release_guards.dart` (+ `--selftest`) · `py -3 tool/_sabotage.py` · `type_scale_codemod.py --selftest` · `dropdown_width_check.py` · `glyph_coverage_check.py` · `one_clock_check.py` (+ `--selftest`) · `unphotographed_screens.py` · `health_probe.py` · `flutter test test/renders` (after any visual change) · `flutter build web --release` · `flutter build apk --debug`
  ⏸ NOT RUN IN FULL — Jean said "pause here" at 05:31. Run after the last five commits: `flutter analyze` = No issues (whole tree, 05:38); the four new test files = 12/12; `dart tool/release_guards.dart` = 43/43 PASS and `--selftest` = all guards bite (the new `one-spelling-for-mine-supplier` BITES); the full `flutter test` (05:39–05:49) = **2479 passed, 1 skipped, 11 failed** — 2 were tests asserting the retired spelling `'Mine / Supplier'` (`company_link_builder_test`, `request_tracking_test`), re-pointed to `'Mine/Supplier'` in this commit and green; 9 were GOLDENS that moved on purpose — `screen-fleet-{desktop-dark,desktop-light,phone-dark}` (the new group icon on every assigned truck, 132 px / 1148 px) and `screen-{token-history,organization-detail,chat-connections}-{desktop,phone}-dark` (the word `Mine/Supplier`). Looked at in `test/renders/failures/`: only those pixels differ. **`flutter test test/renders --update-goldens` is still owed** — run it, look at the nine PNGs in `docs/redesign/renders/`, commit them. NOT run: `_sabotage.py`, `type_scale_codemod.py --selftest`, `dropdown_width_check.py`, `glyph_coverage_check.py`, `one_clock_check.py` (+ selftest), `unphotographed_screens.py`, `health_probe.py`, `flutter test test/renders` (the title bar changed — goldens for phone captures with a long title may move), `flutter build web --release` (build/web is STALE: it predates all five fixes), `flutter build apk --debug` (the APK on the phone is `1ad4c725`, which carries the first three fixes but not `f225278`/`56df087`). **Run the whole list first thing next session.**
- [x] Every Claude-owned browser closed; `HANDOFF.md` §8 rewritten to the verified state and committed together with this file
  ✅ 2026-08-23 · this commit · `Get-CimInstance Win32_Process` shows 0 `chrome.exe` with `ml-chrome-` in the command line and nothing listening on 9222/9223 (the only thing left running is the idle `py -3 -m http.server 8123` over `build/web`); HANDOFF.md rewritten to the verified state with a fresh §8 block, committed with this file.

---

## Phase 1 — the handset: prove the last fixes on glass   **Status: DONE 2026-08-23** *(the title defect it found was fixed in `705843a`, rebuilt as APK `1ad4c725` = `\\192.168.88.30\Shared\PhoneRemote\minelink-m3.apk`, re-installed, and re-seen: `Reconciliations` whole on its own row under the icons)*

The phone last ran the APK built at `963ca7e`. The APK carrying the TIME-IN fix is built, hashed and staged: `build/app/outputs/flutter-apk/app-debug.apk` = `\\192.168.88.30\Shared\PhoneRemote\minelink-m3.apk`, SHA-256 `6BCAE044229625FB32E770DC5CFA62D38EA6A3E584AF8F07BDA54F0663D82422`, both ends match.

- [x] Install APK `2b235c4` on the SM-G780G (My Files → Network storage → jean → Shared → PhoneRemote → minelink-m3.apk → Update → Open)
  ✅ 2026-08-23 · this commit (parent 7426840) · proven by My Files → Network storage → jean → Shared → PhoneRemote → `minelink-m3.apk` (listed 23 Aug 02:09; SHA-256 `6BCAE044…` re-hashed on both ends before the tap) → download 0→100% → "Do you want to update this app?" → Update → the app opened straight into the Global Admin Dashboard (Transporters 46 trips · 1,439 t). No Play Protect prompt this time.
- [x] `/super-admin/recon-tables` at Jean's raised font size: the TIME-IN column reads `12:35` on ONE line
  ✅ 2026-08-23 · this commit · proven on the SM-G780G at Jean's raised font size: scrolled the combined table to the `20 Jul 2026` row — TIME-IN reads `12:35` on ONE line; every other TIME-IN seen (00:50, 04:27, 14:11, 07:27, 01:15, 22:45, 23:31, 15:05 … 07:40) is one line too. Screenshots viewed and deleted.
- [x] Driver hero card (`roadhaul.driver`): `CURRENT TRIP` and the status pill sit on two lines with NO yellow-and-black stripe
  ✅ 2026-08-23 · this commit · proven on the SM-G780G as `roadhaul.driver` on APK `2b235c4`: the Dashboard hero rendered `CURRENT TRIP` + `SCHEDULED`, then — after `Start route` was tapped on the phone itself — `CURRENT TRIP` + `EN ROUTE TO LOAD` (the long pill) with NO yellow-and-black stripe; at Jean's current font size label and pill share one line rather than two, and the Trip tab's `Current Trip` card wrapped its heading onto two lines beside the same pill, also clean. The trip is `b9189cd5`, minted by this session's own dispatch.
- [x] Load controller truck row (`ironhills.controller`) and the buyer reconciliation card (`atlasbuyer.owner`): no overflow at the raised text size
  ✅ 2026-08-23 · this commit · proven on the SM-G780G at the raised text size: as `ironhills.controller`, Mine Control read `1 truck on site · 4 loaded` and the truck card `S6W001GP · No buyer linked yet · Roadhaul Logistics · Chrome Ore 42% Cr2O3 lumpy 1… · ARRIVED AT MINE · Record Load` with no stripe (the truck checked in by `ironhills.security` on the web minutes earlier); as `atlasbuyer.owner`, the Weight reconciliation card — heading, `33 delivered loads`, Export + refresh, the three stat cards and the Side B table — rendered with no stripe. **Found on glass on the way:** the app-bar title broke MID-WORD (`Load co`/`ntroller`, `Compli`/`ance`, `Reconci`/`liations`); fixed in `705843a` (M3 medium top app bar), pinned by `phone_title_never_breaks_a_word_test.dart`, NOT yet rebuilt and re-seen — the phase stays open for that.
- [x] `Duplicate GlobalKey`: baseline count → six or seven navigations → re-count = 0 new rows (SQL in HANDOFF §5)
  ✅ 2026-08-23 · this commit · baseline at 01:27:47Z = 46 `Duplicate GlobalKey` rows / 5,863 total, last Android row 2026-08-22 18:50:45Z; then four sign-ins (admin, driver, controller, buyer) and ~15 navigations on the handset (recon tables, drawer groups, Trip/Profile tabs, Compliance, Mine Control, Loads & value, Reconciliations); re-count at 02:45:24Z = 46, **0 new Android rows of any kind**.
- [x] Phone left signed in as the platform admin, on `home`, every screenshot deleted
  ✅ 2026-08-23 · this commit · the buyer was signed out from the ⋮ menu, `jean@cyberhouse.co.za` signed in, `Open the admin console` tapped → Global Admin Dashboard on APK `1ad4c725` (Transporters 47 trips · 1,439 t), then `home; home` (sig 1.132 bits/pixel = the launcher); `C:\PhoneRemote\tool\shots\` holds 0 files.

Done when: all six ticked with what was seen; any defect found is fixed, tested, rebuilt, re-installed and re-seen on glass.

---

## Phase 2 — the flows nobody has ever driven   **Status: DONE 2026-08-23** *(every flow driven over CDP against live data; records in `docs/redesign/VERIFICATION.md`)*

- [x] **POD leg** of trip `0d9c6792` as `roadhaul.driver`: POD photo attached (`DOM.setFileInputFiles`), delivered tons entered, trip → `offloaded` / `completed`; Reconciliations Side B shows the mine-net vs delivered variance; the buyer's Loads & value updates
  ✅ 2026-08-23 · this commit · proven by driving it as `roadhaul.driver` in a headless CDP Chrome: `Arrived at offloading` → `metadata.arrived_at_offload_at = 2026-08-23T01:40:40Z` (status stays `en_route_to_offload`, by design); `Upload POD` → delivered tons `33.9` + `pod.jpg` through `DOM.setFileInputFiles` → `Submit POD` → `trips.status = completed`, `delivered_tons 33.9`, `variance_tons 0.3`, `offloaded_at = completed_at = 01:43:47Z`, one `pod_uploads` row and a 9,329-byte object in `pod_photos`; the driver's screen went Delivered 6→7, "No active trip", Recent Trips `23 Aug 2026 · 03:43 · COMPLETED`. Side B as `ironhills.owner`: `S6W001GP · 34.20 t · 33.90 t · 0.30 t` with the POD icon. **The buyer half does not apply to this trip**: its request `4a0403a8` was raised by the mine with `buyer_company_id = NULL`, so transaction `TRP-6C72DDAC41` has no buyer and no buyer can see it — that is the data, not a defect. The buyer's Loads & value was checked as `atlasbuyer.owner` and carries the latest buyer-linked POD (`927cbf1b`, 34.05 t, R32,347.50). Rig lesson: a CDP Chrome launched with `--window-position` off-screen reports `visibilityState=hidden` and 0 rAF/s, so Flutter never paints and every screen looks like an endless spinner — use `--headless=new`.
- [x] **Request → approve → link → dispatch, FROM THE FORMS**: Request Transporter/Routes (buyer AND mine, Ongoing and Single request), Request Product, Request Buyer (multi-PDF lab results, image, FOB/FOT, map picker); the `sent_back ⇄ resubmitted` revision loop; the four super-admin inboxes; pricing/margin; the due-diligence gate; transporter accept; fleet + driver allocation; the auto-created capped stockpile and all three dispatch notifications
  ✅ 2026-08-23 · this commit · driven end to end over CDP against live data, every field typed from the forms: **mine** Request transportation (Ongoing, seals ON, 24 h, 30 days / On transporter / R 680 / ton, 2 trucks, 6 months, start 26 Aug, notes) → `18800451`; **mine** Request buyers (1800 t, specs, 14 days, R 2350, FOB, Product location picked on the map — `place_index` answered "Steelpoort" with six results, saved as `https://www.google.com/maps?q=-24.7074699401855,30.2426452636719` — three lab PDFs attached two-together then one-by-one, a photo, notes; all four files in `request_docs` with their byte sizes) → `5dc2579d`; **buyer** Request transportation (Single request, seals ON, 7 days / On account / R 720 / ton, operating **05:30–18:00 by the time pickers**, 27 Aug → 30 Sep by the date pickers, notes) → `d40a9d3e`; **buyer** Request products (3000 t, Daily, R 2100, destination, notes) → `34eba1e9`. **The revision loop:** admin `Send back for revision` with a note → the mine's screen read `NEEDS YOUR ACTION · SENT BACK` with the note and `Edit & resubmit` → the pre-filled form with the `Returned for changes` banner → berth and sizing edited → `Re-submit request` → `resubmitted` (the admins were notified) → admin `Resubmitted | 1` → `Approve`. **All four inboxes** opened and their rows rendered read-only (Mine/Supplier transport, Buyer transport, Requested product incl. the `0 · Complete the order` step, Requested buyers with the attachment chips). **Linking**, twice: mine selected, pricing R 680 − R 60 = R 620 (then R 720 − R 50 = R 670), Roadhaul ticked, `Review & send` → the five-step gate exactly as specified (preview with every field + `R 620.00` + "never sees your margin" → correct? → green tick → 100 % sure? → named Send) → `Linked`. Server: `routes` RT-1ADEE49D / RT-CD03FA4C (seals, 05:30–18:00 carried), `margin_ledger` 680/60/620 and 720/50/670, `request_dispatches` at the transporter price, one capped `stockpiles` row each (2400 t / 600 t at 0, `buyer_label` "No buyer linked yet" / "Atlas Buyer Group"), and the notifications — mine ×4 `New stockpile to prepare`, transporter ×3 `New order assigned`, buyer ×3 `Order accepted & dispatched`. **Transporter accept + allocation** as `roadhaul.admin`: the route sheet showed `Your price / ton R 620.00` and nothing of the margin or the R 680; `Accept & assign trucks` → only S6W001GP selectable (the other two on route) → `Accept 1 truck` → dispatch `accepted`, trip `b9189cd5` **scheduled** on S6W001GP; driver Sipho added to KVK007MP through `DriverAssignmentDialog` (`1/2 drivers assigned`) and the order-aware `Vehicle Assignment` notification reached `roadhaul.driver2`. **Three defects found and fixed on the way** (each one commit, pinned, sabotaged): the second driver was unreachable from every screen (`69f6738`), the phone title broke mid-word (`705843a`), the link step said "Buyer asked for" on a mine-raised request (`22eb90b`). **One server-side gap recorded for Phase 5:** `accept_request_dispatch` notifies only the transporter's admins, and only about driverless trucks — a driver already on the allocated truck is told nothing about the new scheduled trip (0 driver notifications after acceptance).
- [x] **Chat at length**: two real accounts, both directions, attachments, reply quotes, mentions, presence, on phone width and desktop
  ✅ 2026-08-23 · this commit · proven in two headless Chromes on the rebuilt web (`ironhills.owner` 9222 desktop, `ironhills.admin` 9223 — desktop, then `Emulation.setDeviceMetricsOverride` 412×915): presence `Online` in both conversation lists and both thread headers; **reply with a quote** — admin hovered `ping 3 at 05:15:23` → floating `Reply` → quote bar in the composer → sent; the owner's incoming bubble carries the quote block and the server row `649d61d8` has `reply_to_id = 1c1dc7b5`; **@mention** — owner typed `@Adm`, the picker offered three matches, `@Admin Test · Iron Hills Mining` accepted, sent; rendered as a chip on both sides, row `93bac70e` carries `mentions: [{user_id 47f21f63…, display_name Admin Test}]`, and tapping the chip on the owner's side opened `Admin Test's profile · Role Admin · Mine/Supplier · Online` (tapping one's own mention is a no-op by construction — the caller is never in the contacts list); **phone width** — the dock reflowed to 412 px above the bottom nav, the admin typed there and the owner's desktop showed `Admin Test is typing…` in the header and `Admin is typing…` above the composer, then `Sent from phone width at 08:57:59` landed (`b4d3f93b`); **attachments both directions** — the owner's `product-photo.jpg` (earlier) and now `lab-sizing-2026-08-23.pdf` from the admin's phone-width dock through `Attach a file or image` (`92ecf5b8`, `file_type file`), a file chip with a download glyph on both sides; every row `delivered` and `read`. Observed and left as the original does it: the composer shows the raw `@[Name](user:uuid)` token while typing (the shipping app's line 3324 inserts the same). One defect found on the way and fixed: the profile panel's Role row read "Company member" for everyone but a super admin (`31b07cb`).
- [x] Every defect found in this phase fixed in M3, pinned by a test that bites, seen in the browser/emulator, committed one per fix
  ✅ 2026-08-23 · this commit · six defects, each one commit, each pinned by a test or guard that was sabotaged and bit, and **all six now seen in a browser on the rebuilt web** (`build/web` from `31b07cb`): `69f6738` — as `roadhaul.admin`, Trucks on route shows `Manage drivers` on S6W001GP and KVK007MP, and it opens `Drivers — S6W001GP · 1/2 drivers assigned` with Driver Test `DRIVER ON ROUTE`; `705843a` — re-seen on glass in Phase 1; `22eb90b` — as `jean@cyberhouse.co.za`, a mine-raised request (raised from the mine's own form this session, 500 t north stockyard → Richards Bay, approved and deliberately NOT dispatched) shows `1 · Supplying mine — Mine asked for: "Iron Hills Mining - north stockyard"`; `f225278` — as `ironhills.admin`, the dock was opened at 08:37:21 and held for 181 s through four 45-s presence heartbeats (`Synced auth state` logged at +17, +63, +108, +152 s) with the semantics node count 142 → 142 → 142 → 142 and the dock still open in the +181 s screenshot (before the fix: 142 → 6 → 31 → 129 each beat); `56df087` — the contact profile reads `Organisation type · Mine/Supplier`; `31b07cb` (found this session while looking at `56df087`) — `Role · Load Controller`-class values instead of "Company member": Admin Test's profile, opened from the owner's @mention chip, reads `Role · Admin`. Looked at and NOT a defect: `fa243ad` on the Trucks on route card is a real registration typed into a test HILUX; the fleet stat-card captions `all_vehicles` / `carrying_a_load` are the reference's deliberate mono texture (`docs/design-reference.md` §3); the admin cannot message the owner (`Message an admin`) by the P10-07 hierarchy.
Done when: each flow has been driven end to end against live data and its record is in `docs/redesign/VERIFICATION.md`.

---

## Phase 3 — per-screen design pass against the console reference   **Status: OPEN**

The redesign so far is the theme, the shell, the components, the shape/type scales, and every defect found by driving. No screen has been reviewed one by one against `docs/design-reference/` and the super-admin console. That is the remaining design work.

- [x] M3 version of Console (super-admin) screens — all of them, at desktop / medium / phone, dark and light
  ✅ 2026-08-23 · this commit · every console route target looked at against `docs/design-reference/` and §4–§5 of `docs/design-reference.md` (the shell at desktop dark/light, medium, rail-collapsed and phone dark/light; every screen at the widths its renders exist for); the per-screen table is in `docs/redesign/VERIFICATION.md` ("Phase 3 — Console"). Twenty-one fixes, one commit each, every one pinned by a test that was sabotaged and bit and re-rendered: organizations (`368665f`), platform users (`f7a49f2`), organisation detail (`ad1dc5a`), token requests + the status-tone map (`af5fab6`), token history + its lying fixture (`8e0bb19`), audit logs (`a37776f`), crash reports (`a388658`), account deactivations (`f4812a1`), margin ledger (`0e5950c`), recon tables (`f57b84c`), available routes (`0225e95`), driver limits (`d5dd1c1`), org insights chart (`19200e6`), leaderboard + the light `inkXlo` token (`b8f33ab`), company mirror (`ee3e213`), platform settings (`da85f81`), the communications group (`4676106`), request tracking / appearance / the widened spelling guard (`3a0d212`), and the flutter_map logo that made twelve map goldens non-deterministic (`fde2fad`). Reviewed with no drift: the shell, the v2 dashboard, the four request inboxes and the review/dispatch/due-diligence screens, disputes, route marketplace, live map, the transporters overview (the reference itself), the three targets scopes, register company, user preferences, expired access, messages, employee register. Recurring causes: hand-rolled 16px sans titles where `MlPageHeader` exists (6 screens), a card's actions riding in the title Wrap instead of right-aligned (3), title-case or a misplaced possessive in a label (6), and a `Wrap` sizing to its content (§10.4, twice).
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
- [ ] `accept_request_dispatch` notifies only the transporter's admins, and only about DRIVERLESS trucks — a driver already assigned to an allocated truck is told nothing about the new scheduled trip (measured 2026-08-23: S6W001GP accepted with Driver Test on it, 0 driver notifications; the order-aware notice fires only from `add_vehicle_driver`)

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
- The buyer and mine/supplier insights (`/super-admin/insights/buyer`, `/mineSupplier`) and the company mirror still speak the **v1 analytics language** — `docs/design-reference.md` §6 records it, and the router says "until their own versions land". Migrating them onto the v2 transporters-overview language is a feature (org-specific figures: orders/tons/value for buyers, tons/loads/users for mines), not drift. Do it here, or leave it?
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
- 2026-08-23 03:20–05:45 · 166 → 179 commits · Phase 1 DONE on glass (APK `2b235c4` then `1ad4c725`; the phone found the mid-word title break, fixed, rebuilt, re-seen); Phase 2: POD leg and the whole request → dispatch chain driven from the four forms, chat driven half-way; five defects fixed and pinned (`69f6738` `705843a` `22eb90b` `f225278` `56df087`), one server-side gap added to Phase 5; ticks 5 → 11. Paused by Jean at 05:31 before the end gate and the web rebuild. Phone: awake, platform admin, on home, 0 screenshots. No Claude browser left open.
