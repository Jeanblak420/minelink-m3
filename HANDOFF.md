# MineLink M3 — session handoff

**Rewritten 2026-08-22, at the end of the session that drove a whole load end
to end on the live database — buyer request to a truck on the road, with the
driver on a real phone.**
Everything below is verified state, not intention. It replaces the previous
handoff of the same name; the parts of that one still true have been folded in.

**This file lives at**
`C:\Users\Somebody Someone\Music\SHOWME!\MineLink-M3\HANDOFF.md`

The older, machine-wide handoff is at
`C:\Users\Somebody Someone\Claude\HANDOFF.md` — MCP servers, git position,
decoy folders, the phone tooling, dated 2026-08-08. **Background only; this
file governs the redesign work.**

---

## WHERE THIS SESSION STOPPED — READ THIS FIRST

The tree is **clean**, **121 commits**, nothing half-applied and nothing
uncommitted. The tip is `docs: the handoff for the session a whole load moved`;
the last two CODE commits under it are `61d2b37` (the driver's stale screen)
and `de5a345` (the rate leak and the delta badge), and the whole gate in §2 was
run green against them.

**The original worktree was re-checked against its §0 baseline at the start and
at the end and is untouched** — HEAD `df451d0`, the same three pre-existing
modified files, 14163 files under the `-prune` form, two worktree entries,
nothing modified today.

### What changed about this project this session

**A WHOLE LOAD WAS DRIVEN, ON THE LIVE DATABASE, ACROSS SIX ACCOUNTS AND TWO
DEVICES AT ONCE.** That is the thing that had never been done, and it is what
found all three defects below. None of them is reachable from one surface.

    buyer raises a transport request        atlasbuyer.admin      browser
    approve · R130 margin · DUE-DILIGENCE   jean@cyberhouse       browser
      GATE · dispatch to Roadhaul
    accept the route, crew the truck        roadhaul.admin        browser
    supervisor adds 45 t to the stockpile   ironhills.management  browser
    START ROUTE                             roadhaul.driver       PHONE
    security marks arrival                  ironhills             browser
    tare 16.4 t · gross 50.6 t · NET 34.2   ironhills             browser
    security marks departure                ironhills             browser
    arrived at the offload point            roadhaul.driver       browser

Route `RT-52619BC4`, trip `927cbf1b`, waybill `TRP-8CB20569AE`, stockpile
45 t → 10.8 t. Every cascade fired: three dispatch notifications to the right
parties, the +30 t collect alert to buyer and transporter, the auto-waybill
with origin and destination, the stockpile decrement.

**Two open items closed on the way through:** the **due-diligence gate** has
now been driven end to end (preview → "are you sure" → the green tick → "are
you 100% sure" → the transporter list → the final confirm), and the driver's
whole mobile lifecycle has been exercised against a real load.

**Three defects, all found by the drive, all fixed, tested and re-verified on
the running app** — §3.

---

## 0. Where you are

| | |
|---|---|
| **This project** | `C:\Users\Somebody Someone\Music\SHOWME!\MineLink-M3` |
| What it is | A **complete, independent fork** of MineLink, being redesigned onto Material 3. Its own git repo (`main`), **121 commits**, clean tree. |
| **The original** | `C:\Users\Somebody Someone\Music\SHOWME!\worktree-2026-05-05T11-53-29` — **DO NOT TOUCH IT.** |

### The one rule that must not be broken

**Nothing whatsoever changes inside `worktree-2026-05-05T11-53-29`.** That was
Jean's instruction and it has held for every commit. Its verified baseline,
re-checked at the start and end of every session:

```
HEAD              df451d0
file count        14163      ← with the `-prune` command below
git status        exactly 3 modified files, all pre-existing:
                    M .design-sync/config.json
                    M lib/features/super_admin/screens/margin_ledger_screen.dart
                    M test/widgets/app_sidebar_behaviour_test.dart
git worktree list only the main repo + that worktree (no third entry)
```

```bash
cd "/c/Users/Somebody Someone/Music/SHOWME!/worktree-2026-05-05T11-53-29"
git status --porcelain --untracked-files=all
git rev-parse --short HEAD
find . -path ./.git -prune -o -type f -print | wc -l
git worktree list
find . -type f -newermt "<today>" -not -path "./.git/*" | wc -l    # must be 0
```

⚠️ **The file count depends on which `find` you use, and the difference is not
a new file.** `find . -type f -not -path "./.git/*"` returns **14164** because
in a WORKTREE `.git` is a *file*, not a directory, so that pattern does not
exclude it. The `-prune` form above returns **14163**. Both describe the same
untouched tree.

Every command in this project must run with its working directory inside
`MineLink-M3`. The two trees share no git state.

---

## 1. The brief, verbatim in substance

> Redesign the app for all versions — mobile, web and Windows. Put it in a new
> folder outside the app root so I can see how everything looks and test it
> properly before deciding if I like it. Nothing whatsoever changes inside
> `worktree-2026-05-05T11-53-29`. The UI/UX for all of it should follow the
> super global admin's portal — the placement of everything and so on. Use all
> the latest and best Material Design 3.

Later instructions, which still stand:

- **Windows is optional.** *"if u struggle with the windows build then just
  continue with web and mobile please"* — Windows is blocked by two
  pre-existing faults (§4.4); web and Android both build.
- **Work long, don't stop to check in.** The HOW TO WORK paragraph in §8.
- **The chat is the dock** (2026-08-22). Acted on in the previous session.
- **Create the load yourself** (2026-08-22): *"the new session can run it, run
  it all and or create it with the other user's, he can do the one side of it
  all on the pc to assign what needs to be assigned and then test the mobile
  stuff on my phone"*. Acted on — the table at the top of this file.

**`supabase/` is frozen.** No migration is created, applied or pushed here.
Two things found this session need one and are therefore REPORTED, not fixed:
the RLS half of the rate leak, and `stockpiles` missing from the realtime
publication (§3.1, §3.3).

---

## 2. Verified state, right now

Every one of these was run at the end of the session:

```
flutter analyze                                 no issues
flutter test                                    2160 passed, 1 skipped
dart tool/release_guards.dart                   40/40 PASS, 0 FAIL
dart tool/release_guards.dart --selftest        all guards bite
py -3 tool/_sabotage.py                         all sabotages caught
py -3 tool/type_scale_codemod.py --selftest     OK
py -3 tool/dropdown_width_check.py              passes
py -3 tool/glyph_coverage_check.py              passes
py -3 tool/one_clock_check.py                   0 sites off Africa/Johannesburg
py -3 tool/unphotographed_screens.py            93 targets, 93 photographed, 0 not
flutter build web --release                     builds
flutter build apk --debug                       builds
docs/redesign/renders/                          225 renders
render harness — CUT OFF                        9 strings, all deliberate
render harness — FAILURE STATE                  0
render harness — RENDER NOTE                    0  (and it FAILS the test)
render harness — LOW CONTRAST                   0
ANDROID, ON JEAN'S SM-G780G                     installed and driven, twice
A WHOLE LOAD, ON THE LIVE DATABASE              driven, six accounts
```

Test count went **2149 → 2160**: eleven new, across three new files.
Guards went **39 → 40**.

⚠️ **LOW CONTRAST is 0 for app screens.** A raw `grep -c "LOW CONTRAST"` over a
render run returns **11** — every one of them tagged `[unit]`, which is the
low-contrast reporter's own self-test deliberately painting faint text to prove
the instrument still works. Count `grep "LOW CONTRAST \[" | grep -v "\[unit\]"`.

---

## 3. What this session did

Full reasoning is in each commit message — two long ones. Read them rather
than trusting this summary.

### 3.1 The transporter could read the buyer's rate  (commit `de5a345`)

The route-detail sheet a transporter accepts from printed, four rows apart in
one grid:

    Your price / ton    R 820.00
    Rate                950

R950 − R820 = R130 — the exact margin typed into the linking panel ten minutes
earlier. The list card behind it carried `950` as a chip. The admin's own
due-diligence preview, the last dialog before dispatch, promises in those
words: *"The transporter never sees your margin — only this price."*

Fixed at three depths: the embedded `select` names its columns instead of `*`
(`rate`, `price_per_ton` and `admin_notes` no longer cross the wire);
`DispatchedRoute.fromJson` strips those three keys regardless, so a `*` put
back later still cannot reach a widget; and both display sites are gone — the
card now carries the transporter's OWN price, which is the number they are
deciding from. Guard `no-star-select-on-embedded-request` (BITES).

🚨 **IT IS ALSO A SERVER-SIDE EXPOSURE AND THAT HALF IS NOT FIXED.** Measured,
not inferred: as the Roadhaul admin's own JWT under RLS on production,
`select rate from transportation_requests` returns `"950"`. `supabase/` is
frozen here. **The policy is the shipping app's to tighten.**

**The fixture is why 225 renders never saw it.** `_request` set nine fields; a
live row has twenty-odd, and the transporter's card and sheet read most of the
missing ones. It had no `rate`, so there was nothing to leak. It carries all of
them now, `rate: '950'` deliberately included, so
`screen-transporter-routes-desktop-dark.png` is now EVIDENCE the rate is
withheld rather than a picture that could not tell.

### 3.2 Every KPI delta badge contradicted its own number  (commit `de5a345`)

On the live buyer dashboard, one card apart:

    ▲ −35        Tons delivered  68.7 t     (amber, "· 24h")
      −6351      Payable         R49,710    (green, no arrow, no period)

and on the transporter's, `▲ −956566 · 24h` beside a value of `R156,567`.

Four faults: the `▲` was welded to the tone and the tone carries the SIGN, so
every unwelcome fall drew an up arrow; a welcome fall drew no arrow and no
period at all, so one row printed one measurement in two shapes; `· 24h` was a
literal while the delta is measured over the SELECTED period; and a Rand delta
had neither its currency nor its grouping.

The arrow is now read off the sign of the delta string, so it cannot disagree
with the figure whatever a caller does with the colour. `PortalKpiRow` requires
the `period`. Money tiles pass `deltaPrefix: 'R'`.

Also a latent §10.4 fault the lengthening would have triggered: `_Delta` was a
NON-FLEX child of a `Row`, so it had unbounded width and could never
ellipsise. It is `Flexible` now, with the window written after the figure so a
squeeze drops the tail and never the number.

⚠️ **The overflow sweep passed with the fix removed the first time.** It swept
1600/900/360 against the −6,351 buyer figure. **1100 is the worst width, not
the narrowest** — it is the exact breakpoint where the row goes 4-up, so each
tile is ~264px. Swept against the real −956,566 transporter delta it fails by
27px. A sweep that cannot fail is not a sweep.

### 3.3 A driver could not finish a load  (commit `61d2b37`)  ⚠️ CRITICAL PATH

    04:33  security marked the truck LEFT SITE.
           trips.status -> en_route_to_offload, confirmed in the database.
    04:37  the driver's Trip screen still read  EN ROUTE TO LOAD.

Four minutes, across a tab switch AND a pull gesture. The driver's lifecycle
buttons are gated on `TripStatus.step`, so `Arrived at offloading` and
`Upload POD` stayed dimmed — **the driver cannot complete the load without
killing the app.**

`DriverRoutesScreen` invalidates `logisticsSnapshotProvider` after the driver's
OWN actions — four call sites, which is exactly why every earlier step of the
drive looked right — and had nothing for anybody else's. But the trip lifecycle
is the one place in this product where the thing on your screen is moved by
somebody else, three times in a row.

`LogisticsService.watchLifecycle` — realtime on `trips` + `transactions`,
700 ms debounce, 60 s periodic fallback, immediate first tick. Shape copied
from `LiveTrackingService.watchLivePositions`, which had already met each of
those. **Verified on the live app**: "Mark Left" clicked in the MINE's browser
context at `02:51:13.828` → the driver's page re-read at `02:51:16.293`, no
interaction on it, 19 s before the next scheduled fallback.

🚨 **`stockpiles` IS NOT IN THE REALTIME PUBLICATION.** Measured against
`pg_publication_tables`. So the "live fill" CLAUDE.md promises the buyer and
the transporter is live-on-load only — observed: 45 t added at 03:35, the
transporter's Routes screen still read `0 / 120 t` until reloaded. This
commit covers the case that matters most (a load writes a trip AND decrements
the pile), but a bare `Add tons` still will not reach an open screen. One line
for the shipping app, and a migration, so not done here:
`alter publication supabase_realtime add table public.stockpiles;`

### 3.4 New tests, all sabotaged to prove they bite

| test | what it stops |
|---|---|
| `dispatched_route_hides_requester_pricing_test.dart` | the requester's `rate`/`price_per_ton`/`admin_notes` reaching the model OR either transporter surface |
| `kpi_delta_agrees_with_its_number_test.dart` | an arrow that disagrees with its sign, a literal `24h`, a bare currency delta, and the badge overflowing at 1100px × 2.0 |
| `logistics_snapshot_refetches_test.dart` | the snapshot not re-reading when another role moves the trip |

⚠️ The last one needed a `_settle()` of four event-loop turns. Without it it
read the future the provider had ALREADY resolved and reported the right number
whether the fix was there or not — green over a stale value, which is the same
shape as the bug it guards.

### 3.5 What the phone proved this time

Installed twice from the NAS. Signed in as `roadhaul.driver`, against the live
database, with a real load on the truck:

- The load reached the handset — **CURRENT TRIP · SCHEDULED · S6W001GP**.
- **`Start route` driven ON THE PHONE**: `scheduled → en_route_to_load` in the
  database, and the pill changed to EN ROUTE TO LOAD with the button correctly
  gone.
- The whole action set, correctly gated: Navigate and Directions live,
  `Arrived at loading` enabled, `Arrived at offloading` and `Upload POD`
  dimmed.
- **The live-location toggle is ENABLED** now there is an active trip — the
  thing §4.1 of the last handoff was blocked on.
- **THE TURN-BY-TURN NAVIGATION RAN ON REAL HARDWARE WITH A REAL ROUTE**:
  *"In 240 m — Turn right onto Alexander Avenue, then At the roundabout take
  exit 3"*, ETA 04:36, 4 min, 958 m, +5 min vs plan, 1 km/h — and it named its
  destination and how the pin resolved. **Sane numbers**, which is the
  unsigned-32-bit polyline fix (CLAUDE.md §10.6) proven on a handset.
- **The 30-second ping cadence is real**: `vehicle_positions` at 02:33:37,
  02:34:07, 02:34:37, 02:35:09, 02:35:37 — five consecutive fixes, 30 s apart,
  from a real GPS stack.

⚠️ **Live sharing was turned OFF again and the card reads "Live tracking
turned off."** It writes JEAN'S REAL POSITION to `vehicle_positions` on
production. Turn it off after any test that turns it on, and say so.

---
## 4. What is NOT done — PICK UP HERE

### 4.1 Three decisions that are JEAN'S, and are blocking nothing else

These are recorded, not open. Put them in front of him and act on the answer.

**(a) The eleven remaining route divergences.** Every one is the same shape —
longer in the rail, shorter in the bar, because the rail has a column and the
bar shares a line. Both strings for each live in
`test/core/every_portal_route_is_named_test.dart`. Eight distinct name pairs,
covering the routes in brackets:

| rail | bar | routes |
|---|---|---|
| Supervisor & stockpiles | Stockpiles | mine |
| Security gate | Security | mine |
| Mine locations | Locations | mine |
| Recon tables (tons out) | Tons out | mine, buyer, transporter |
| Company profile | Company | mine, buyer, transporter |
| My profile | Profile | mine, buyer, transporter, driver |
| Announcements | Communications | /communications |
| Appearance | Appearance & theme | /appearance |

Four more were settled on his call on 2026-08-22 and made to agree
(fleet → "Vehicles", drivers → "Drivers", trucks-on-route → "Trucks on route",
trip → the RAIL becomes "Trip"). ⚠️ Do NOT also rename
`PortalTabItem('Trucks On Route')` — that string is a LEGACY TAB LABEL,
`_legacyTabLabels` maps it onto the canonical form, and renaming it breaks tab
selection SILENTLY. It was tried and reverted.

A separate group is divergent BY DESIGN and is not on the list: the four
dashboard roots (the bar names the active TAB, which the rail cannot know) and
the four `/operations` routes (the rail names that screen three different ways
by role).

**(b) Should `MessagesScreen` and `ChatScreen` be deleted?** About 2,500 lines.
`MessagesScreen` (985 lines) is reachable ONLY when a licence token is
expiring, and its two employee-profile entry points are dead code — guarded on
`ChatDock` NOT being mounted, and the dock is now mounted on the driver shell
too. ⚠️ `ChatScreen` is NOT dead — it is the `/chat/:id` route, reachable from
the Communications hub, and it is the surface whose reply was broken and fixed.
Do not delete it by accident.

**(c) A leftover firewall rule needs an ELEVATED shell.** Still present and
Enabled, from a much earlier session's `serve_apk.ps1`. Nothing is listening on
port 8000. The NAS route makes that script unnecessary, so it should not come
back. Jean, in an admin PowerShell:
```powershell
Remove-NetFirewallRule -DisplayName 'CtrlBridge APK download (TCP in)'
```

### 4.2 The load that is on the road right now

Trip `927cbf1b-c8d4-45f7-aa92-b2592f3c9f98`, route `RT-52619BC4`, truck
S6W001GP, driver `roadhaul.driver`. It is **`en_route_to_offload` with its
arrival at the offload point already stamped** (`metadata.arrived_at_offload_at`
= 02:52:35Z) — a legitimate live state, a truck standing at the terminal.

**Only `Upload POD` is left**, and it closes the trip: POD writes `offloaded`
AND `completed` in one deliberate collapse, back-fills `offloaded_at`, and
regenerates the waybill with the driver's signature in its RECEIVED BY block.

It was not driven, for one honest reason: **it needs a real photograph.** On
the handset that means opening the camera on Jean's personal phone at five in
the morning; in a browser it means a file picker, and browser automation
dropped out (the devtools MCP server disconnected) before it could be tried.
Either is a two-minute job for whoever picks this up. The stockpile still has
10.8 t of the 120 t order on it, so the same route can carry more loads.

### 4.3 Contrast, the chat, and the four route names — CLOSED, do not redo

- **Contrast is closed app-wide AND for chat.** 1,812 low-contrast strings → 0,
  and `test/renders/low_contrast_baseline.json` is `{}`: a missing entry reads
  as zero, so it is a FLOOR, not a ratchet. **If it ever fails, do not add a
  baseline entry** — the failure message names the token to change.
- **All eighteen chat palettes are covered by arithmetic**
  (`test/design/chat_palette_contrast_test.dart`), which renders cannot do — a
  render only ever photographs the ONE palette that happens to be selected.
- **The chat is the dock**, on Jean's explicit call. The invisible reply is
  fixed end to end, the dock has renders, mention tokens no longer render raw,
  and a driver can reach chat on both driver branches.
- The dock's empty state correctly says **"Open the Contacts tab"** — confirmed
  on the live app this session.

### 4.4 Known limitations, stated rather than hidden

- **A live chat between two real accounts is STILL not driven.** A room now
  exists between `roadhaul.admin` and the driver (`chat_rooms.24f1bef3`,
  created this session by opening the contact) and it has **no messages**. Two
  attempts to send failed for a tooling reason, not an app one: the dock's
  presence line ("Last seen 1 h ago") re-renders constantly, which invalidates
  the accessibility-tree uid between the snapshot and the click.
  ⚠️ **Do not drive the dock with synthetic coordinate taps** — a tap that
  misses lands on the dismiss barrier and closes it, and one of mine hit a
  Refresh. Snapshot → click in the tightest possible pair, and retry on a
  stale uid rather than falling back to coordinates.
- **Windows is blocked by two pre-existing faults** — the Flutter tool refuses
  the path because of the `!` in `SHOWME!`, and from a clean path CMake fails
  extracting `firebase_cpp_sdk_windows_12.7.0.zip`. Same dependency, same
  version, in the shipping app. Jean said to skip it.
- **Nine strings are cut, on purpose** — three crash-report exception messages,
  three chat message previews, three conversation-row previews in the dock.
- **Some fixtures are deliberately EMPTY** (the operations hub's ledgers). Do
  not "fix" those by filling them. But see §3.1: a fixture that says LESS than
  the service it stands in for is a different thing entirely, and it hid a
  real leak for 225 renders.
- **The map tiles are real in a browser and on a device**, and blank in renders
  — `flutter_test` answers every HTTP request with 400.
- **The chat FAB overlaps the driver's lifecycle buttons** at 412px. Cosmetic,
  the buttons are full-width and still tappable, not fixed, photographed.
- **iOS** is still unattempted; no reachable Apple Developer account.

### 4.5 What a handset still cannot prove at a desk

Three of the five items the previous handoff listed here are now DONE — the
navigation screen drew a real route, the 30-second cadence was measured on real
hardware, and the live-location toggle works. What is genuinely left needs the
phone to physically move:

- GPS fixes changing along a road over distance
- auto-reroute on going off-route
- the Android foreground service surviving a long backgrounding
- battery over a real trip

⚠️ The EMULATOR can fake movement (`adb emu geo fix`) and the 2026-07-17 run
already proved the navigation stack that way — a real handset cannot be
teleported, so do not try it there.

---
## 5. How to work in this repo

```bash
cd "/c/Users/Somebody Someone/Music/SHOWME!/MineLink-M3"

flutter analyze                                  # must be clean
flutter test                                     # 2160 passing, 1 skipped
dart tool/release_guards.dart                    # 40/40
dart tool/release_guards.dart --selftest         # every guard must BITE
py -3 tool/_sabotage.py                          # every instrument fix must BITE
py -3 tool/type_scale_codemod.py --selftest
py -3 tool/dropdown_width_check.py
py -3 tool/glyph_coverage_check.py
py -3 tool/one_clock_check.py
py -3 tool/unphotographed_screens.py
flutter test test/renders --update-goldens       # after any visual change
flutter build web --release
flutter build apk --debug
```

### Working the contrast report

```bash
flutter test test/renders/redesign_renders_test.dart > out.txt 2>&1   # NEVER | tail
py -3 tool/rank_low_contrast.py out.txt              # by pair / widget / render
py -3 tool/attribute_low_contrast.py out.txt         # by TOKEN — start here
py -3 tool/contrast_calc.py solve-tint '#6B7A9C' '#1C2C46' 4.6
```

⚠️ **`solve-tint` moves the INK.** When the ink is white there is nowhere
lighter for it to go and it answers "UNREACHABLE on this ground at all" — that
is telling you to deepen the FILL, not that the pairing is impossible.

⚠️ **Count app-screen low contrast as
`grep "LOW CONTRAST \[" out.txt | grep -vc "\[unit\]"`.** The `[unit]` lines
are the reporter's own self-tests, which paint faint text on purpose. A raw
count reads 11 and means 0.

### Driving the built app in a browser

```bash
flutter build web --release          # config/supabase.live.json is a bundled
                                     # ASSET, so a plain build reaches live
cd build/web && py -3 -m http.server 8123 --bind 127.0.0.1
"/c/Program Files/Google/Chrome/Application/chrome.exe" \
  --remote-debugging-port=9222 \
  --user-data-dir="<scratch>/ml-m3-chrome" \
  --no-first-run --no-default-browser-check "http://127.0.0.1:8123/"
```

- **Flutter web publishes no accessibility tree until you ask.** Click the
  hidden placeholder — `document.querySelector('flt-semantics-placeholder')
  .click()`.
- **Drive SIX ACCOUNTS AT ONCE with isolated browser contexts.** That is what
  made this session's drive possible, and it is how all three defects were
  found. One `new_page` per role with a distinct `isolatedContext` gives each
  its own storage, so six sessions coexist. Do NOT try to do it with tabs.
- **`fill` on two different fields writes both into one.** Click the field,
  then `type_text` with `submitKey: "Tab"`.
- **Chrome will not resize below ~500px.** Use CDP emulation
  (`412x915x2,mobile,touch`) — that is the driver's phone layout in a browser
  and it reaches the whole driver lifecycle.
- ⚠️ **The accessibility uid churns.** Any screen with a live "last seen" or a
  realtime figure re-renders, and a uid taken from one snapshot is often dead
  by the next call. Snapshot and click in the tightest pair you can, and on
  "no longer exists" take a fresh snapshot rather than reaching for
  coordinates.
- ⚠️ **`performance.getEntriesByType('resource')` is how you prove a refetch.**
  Each `vehicle_positions` request encodes its own moment in the 30-day window
  (`recorded_at=gte.<now − 30d>`), so the timestamps in the URLs are a log of
  exactly when the app re-read. That is what verified §3.3.
- ⚠️ **The devtools MCP server can disconnect mid-session.** Chrome survives it.
  Nothing is lost, but browser automation is gone until it reconnects — finish
  by other means rather than waiting.

### Driving Jean's real phone

**Invoke the `driving-jeans-phone` skill FIRST.** The phone is **paired**
(`status` → `sharing=True control=True`).

The install route, proven three times now, about six minutes:

```
1. flutter build apk --debug
2. copy build/app/outputs/flutter-apk/app-debug.apk  ->
     \\192.168.88.30\Shared\PhoneRemote\minelink-m3.apk
3. On the phone: My Files -> (search "My Files" in the app drawer) ->
   scroll past Recent files -> Network storage -> jean -> Shared ->
   PhoneRemote -> minelink-m3.apk -> ~2.5 min download -> Update -> Open
```

🚨 **THE NAS CLOCK IS ABOUT 2 h 36 m SLOW. DO NOT TRUST ITS TIMESTAMP.** The
previous handoff said to check the staged APK's mtime; that advice is wrong on
this share. A file copied at 04:04 shows as `22 Aug 01:28` both over SMB and in
My Files. **Compare the SHA-256 instead:**

```powershell
(Get-FileHash 'build\app\outputs\flutter-apk\app-debug.apk' -Algorithm SHA256).Hash
(Get-FileHash '\\192.168.88.30\Shared\PhoneRemote\minelink-m3.apk' -Algorithm SHA256).Hash
```

⚠️ **My Files caches the folder listing.** After re-staging, back out of
`PhoneRemote` and re-enter it.

⚠️ **Only Jean can wake a sleeping display.** `probe` reports
`0.061 bits/pixel (under 0.1 - nothing on the screen)`. It slept twice this
session. Ask him; injected touches cannot wake it. When it is awake `probe`
reports something like `0.771`.

⚠️ **The applicationId is `org.minelink.m3`**, deliberately different from the
shipping app's `com.example.flutter_application_1`. They install side by side.

It is his **personal** phone: prefer `sig`/`changed`/`waitstable`, delete every
screenshot immediately, do not read what you did not come for (his Recent
files sit at the top of My Files — scroll past them), back out of anything
opened by mistake and say so, and leave it on `home; waitstable; home`.

⚠️ **`look` does not describe the screen** despite its help text — it prints
frame statistics only. Navigating needs `shot`, which means screenshots, which
means deleting them.

🚨 **Turning on live-location sharing writes JEAN'S REAL POSITION** to
`vehicle_positions` on production, every 30 seconds. It is a real feature and
testing it is legitimate — but turn it off afterwards and confirm the card
reads "Live tracking turned off."

### Live accounts

`active user accounts.txt` in the repo root. `jean@cyberhouse.co.za` /
`BuRG3rJ3@n1995@#` is the platform admin; everything `@mineralguide.com` is
`MineralGuide123!`.

⚠️ **The console stores theme and accent PER ADMIN.** Switching Jean's mode to
Light writes to his account. Put it back.

⚠️ **Every account's setup gate is incomplete. Dismiss it with "Later".**
"Complete now" would write real data to a real account.

### Things that have already gone wrong here — do not repeat them

- 🚨 **A POWER CUT DESTROYED A FILE MID-WRITE.** `low_contrast_report.dart`
  came back as 23,598 NUL bytes — right size, no content. **Commit often; copy
  to the scratchpad before any long edit.**
- 🚨 **A BASH HEREDOC EATS BACKSLASHES EVEN WHEN QUOTED**, and a Python string
  inside one eats them again. **Write any script containing a backslash with
  the Write tool, or use Edit directly.**
- 🚨 **NEVER READ A LONG TEST RUN THROUGH `tail`.** Redirect to a file and grep
  the file.
- 🚨 **`git checkout -- <dir>` THREW AWAY UNCOMMITTED WORK.**
- 🚨 **A LONG `&&` CHAIN ENDING IN `git commit -F <heredoc>` TIMES OUT.** Write
  the message to a file and commit with `-F` as its own command.
- 🚨 **Python's stdout is cp1252 here** — printing `−` or `·` from a script
  dies. Set `PYTHONIOENCODING=utf-8`.
- 🚨 **A CHECK YOU HAVE NOT SABOTAGED IS A CHECK YOU DO NOT HAVE**, and the
  scene must be FAITHFUL. This session added two more proofs of that: an
  overflow sweep that passed with the fix removed because it swept the wrong
  WIDTHS (1100 is the worst, not 360), and a provider test that reported the
  right number with the fix removed because it read an already-resolved future
  (§3.4). Both looked thorough. Neither could fail.
- 🚨 **A TEST WRITTEN FOR A BUG CAN READ THE HALF YOU ALREADY FIXED.**
- 🚨 **A FIXTURE THAT SAYS LESS THAN THE SERVICE HIDES REAL FAULTS.** §3.1.
  When a fixture stands in for a live row, give it every field the live row
  has — INCLUDING the dangerous one, so the render can prove it is withheld.
- 🚨 **ONE SURFACE AT A TIME PROVES ONE SURFACE.** All three defects this
  session needed two roles acting on one object. Drive both sides.
- 🚨 **A NEW TEST MUST PASS `theme: AppTheme.build(...)` to `MaterialApp`.**
  `test-renders-under-the-app-theme` catches it.
- 🚨 **A background task holding a file blocks a later copy to it.** `TaskStop`
  does not always kill the underlying `pwsh` — find it by `CreationDate` and
  `Stop-Process`. **Two long-running `pwsh` processes on this machine are
  Jean's VS Code terminals; check `CommandLine` before killing anything.**
- **A `RepaintBoundary` inside a `Scaffold` does not capture a DIALOG.**
- **`loadRealFonts()` is not enough** — name the family. CLAUDE.md §7, §10.5.
- **`Color.alphaBlend` keeps the BACKGROUND's alpha.**
- **`dart format` on a directory reformats files you did not touch.**
- **`find.text` cannot see a `TextSpan`**, and **`toPlainText()` CANNOT SEE A
  TRUNCATION** — use `RenderParagraph.didExceedMaxLines`.
- **Generating a waybill on web opens a print surface** and closed three
  browser pages when it did. Re-open them; nothing is lost.

### Where the reasoning lives

- `docs/redesign/DESIGN.md` — decisions and what each cost.
- `docs/redesign/VERIFICATION.md` — what was executed, and what has not been.
- `docs/design-reference/` — the **pre-redesign** reference PNGs. **Do not
  regenerate them**; they are the before-image.
- `docs/redesign/renders/` — 225 PNGs of the redesign.
- Every commit message carries its own reasoning.

---

## 6. The project's own rules still apply

`CLAUDE.md` in this repo is the fork's copy of the shipping app's:

- **§10.4** — a `Row` hands a non-flex child unbounded width. Bit again this
  session, on the delta badge (§3.2).
- **§10.5** — a green test over an empty fixture, an error state, or a fallback
  font proves nothing. And a fixture thinner than the service proves less than
  nothing, because it looks like coverage (§3.1).
- **§7** — `flutter test` renders in a fallback font unless you load the real
  ones.
- **§7.1** — one clock, Africa/Johannesburg. `MlTime`, never `DateTime.now()`.
- **§10.6** — Dart bitwise operators are unsigned 32-bit on the web. The fix is
  now confirmed on real hardware: a 958 m leg reported 958 m.
- **§1** — the package is `flutter_application_1`. Do not rename it. (The
  Android *applicationId* is `org.minelink.m3`; those are different things.)
- **§5** — design tokens are law.
- **§4** — *"The transporter only ever sees their resulting price, never the
  admin's margin."* It was not true until this session (§3.1).

---

## 7. Exactly where this session stopped

Nothing is in flight in the repo. The tree is clean at
`docs: the handoff for the session a whole load moved`; the last two CODE
commits under it are `61d2b37` and `de5a345`, and the whole gate in §2 was run
against them.

**Outside the repo:**

1. **A real load is on the road.** Trip `927cbf1b`, `en_route_to_offload`,
   arrival at the offload point stamped, POD not uploaded — §4.2.
2. **The phone is ASLEEP**, and `org.minelink.m3` on it is the build at
   `61d2b37`. Every screenshot taken was deleted; zero remain. Live-location
   sharing was left OFF.
3. **The NAS carries that same APK** at
   `\\192.168.88.30\Shared\PhoneRemote\minelink-m3.apk`, hash-verified
   `7511FB67…`. Ignore its timestamp — §5.
4. **A web server and a Chrome are still running** — `py -3 -m http.server 8123`
   in `build/web`, and Chrome on `--remote-debugging-port=9222` with four
   MineLink pages open (admin, transporter, mine, driver contexts). The
   devtools MCP server disconnected; Chrome itself is fine.
5. **The `CtrlBridge APK download (TCP in)` firewall rule is still Enabled**
   and needs an elevated shell — §4.1(c).

**Pick up at §4.1** — three decisions that are Jean's — or at §4.2, which is
one POD upload away from a completed trip.

---
## 8. COPY-PASTE MESSAGE FOR THE NEXT CHAT

Everything the next session needs is inside this block. Paste it whole.

```
Continue the MineLink Material 3 redesign, exactly where the last session left
off. Read these TWO handoff files before doing anything else, in this order.

1. THE CURRENT HANDOFF — THIS IS THE FILE THAT GOVERNS THE WORK:

      C:\Users\Somebody Someone\Music\SHOWME!\MineLink-M3\HANDOFF.md

   Rewritten 2026-08-22 at the end of the session that drove a whole load end
   to end on the live database. Read it in this order: "WHERE THIS SESSION
   STOPPED — READ THIS FIRST", then §0 (where you are + the one rule), §2
   (verified state), §3 (what was done and what the drive found), §7 (exactly
   where I stopped), §4 (what is NOT done — pick up here) and §5 (things that
   have already gone wrong in this repo).

2. THE OLDER MACHINE-WIDE HANDOFF — BACKGROUND ONLY, DO NOT WORK FROM IT:

      C:\Users\Somebody Someone\Claude\HANDOFF.md

   Dated 2026-08-08. MCP servers, git position, the decoy folders, the phone
   tooling. Claude Desktop reads that folder through its `claude-notes` MCP
   server. The MineLink-M3 handoff above governs this redesign work; where the
   two disagree, the MineLink-M3 one wins.

THE PATHS THAT MATTER

  Work happens here (its own git repo, branch `main`, 121 commits, clean):
    C:\Users\Somebody Someone\Music\SHOWME!\MineLink-M3

  NEVER TOUCHED, for any reason:
    C:\Users\Somebody Someone\Music\SHOWME!\worktree-2026-05-05T11-53-29

THE ONE RULE THAT MUST NOT BREAK: nothing whatsoever changes inside
worktree-2026-05-05T11-53-29. Its verified baseline is in §0 of the MineLink-M3
handoff — CHECK IT AT THE START OF THE SESSION AND AGAIN AT THE END:

    HEAD              df451d0
    git status        exactly 3 modified files, all pre-existing:
                        M .design-sync/config.json
                        M lib/features/super_admin/screens/margin_ledger_screen.dart
                        M test/widgets/app_sidebar_behaviour_test.dart
    file count        14163   (with `find . -path ./.git -prune -o -type f -print | wc -l`)
    git worktree list exactly 2 entries — the main repo and that worktree
    modified today    0

  ⚠️ The file count depends on which `find` you run and the difference is NOT a
  new file: `find . -type f -not -path "./.git/*"` returns 14164, because in a
  WORKTREE `.git` is a FILE, not a directory, so that pattern does not exclude
  it. The `-prune` form returns 14163. Both describe the same untouched tree.

WHERE I LEFT OFF, EXACTLY

The tree is CLEAN. 121 commits. Nothing is half-applied and nothing is
uncommitted. The tip is "docs: the handoff for the session a whole load moved";
the last two CODE commits under it are 61d2b37 "a driver could not finish a
load, because their screen never learned somebody else had moved it" and
de5a345 "the transporter could read the buyer's rate, and every delta badge
lied about its own direction". The whole gate below was run green against them.

Green means EXACTLY this — compare against it rather than guessing:

    flutter analyze                    no issues
    flutter test                       2160 passed, 1 skipped
    dart tool/release_guards.dart      40/40 PASS, 0 FAIL
    dart tool/release_guards.dart --selftest   all guards bite
    py -3 tool/_sabotage.py            all sabotages caught
    py -3 tool/type_scale_codemod.py --selftest   OK
    py -3 tool/dropdown_width_check.py            passes
    py -3 tool/glyph_coverage_check.py            passes
    py -3 tool/one_clock_check.py      0 sites off Africa/Johannesburg
    py -3 tool/unphotographed_screens.py   93 targets, 93 photographed, 0 not
    docs/redesign/renders/             225 renders
    render harness — RENDER NOTE       0   (and it FAILS the test)
    render harness — FAILURE STATE     0
    render harness — LOW CONTRAST      0   (see the [unit] caveat below)
    render harness — CUT OFF           9   (all deliberate, named in place)
    flutter build web --release        builds
    flutter build apk --debug          builds

  ⚠️ A raw `grep -c "LOW CONTRAST"` over a render run returns 11. Every one is
  tagged [unit] — the low-contrast reporter's OWN self-tests, which paint faint
  text deliberately to prove the instrument works. Count app screens with
  `grep "LOW CONTRAST \[" out.txt | grep -vc "\[unit\]"`, which is 0.

STILL RUNNING FROM MY SESSION (you may reuse or kill them):
  - `py -3 -m http.server 8123` serving build/web
  - Chrome on --remote-debugging-port=9222 with four MineLink pages open
    (admin / transporter / mine / driver isolated contexts)
  ⚠️ The devtools MCP server DISCONNECTED near the end of my session. Chrome
  itself is fine. If browser automation is missing, that is why.

WHAT I DID — THE THING THAT HAD NEVER BEEN DONE

I drove a WHOLE LOAD on the live database, across six accounts and two devices
at once. That is what found all three defects; none is reachable from one
surface.

  buyer raises a transport request        atlasbuyer.admin      browser
  approve · R130 margin · DUE-DILIGENCE   jean@cyberhouse       browser
    GATE · dispatch to Roadhaul
  accept the route, crew the truck        roadhaul.admin        browser
  supervisor adds 45 t to the stockpile   ironhills.management  browser
  START ROUTE                             roadhaul.driver       PHONE
  security marks arrival                  ironhills             browser
  tare 16.4 t · gross 50.6 t · NET 34.2   ironhills             browser
  security marks departure                ironhills             browser
  arrived at the offload point            roadhaul.driver       browser

Route RT-52619BC4, trip 927cbf1b, waybill TRP-8CB20569AE, stockpile 45 → 10.8 t.
Every cascade fired. THE DUE-DILIGENCE GATE IS NOW DRIVEN END TO END — that was
an open item and it is closed.

THREE DEFECTS FOUND, FIXED, TESTED (every test sabotaged) AND RE-VERIFIED ON
THE RUNNING APP — full detail in §3:

  1. THE TRANSPORTER COULD READ THE BUYER'S RATE. The route sheet printed
     "Your price / ton R 820.00" and, four rows below, "Rate 950". R950 − R820
     = the admin's exact margin, on the one screen whose contract is that it is
     withheld. 🚨 IT IS ALSO A SERVER-SIDE RLS EXPOSURE, MEASURED NOT INFERRED,
     AND THAT HALF IS NOT FIXED — supabase/ is frozen in this fork.
  2. EVERY KPI DELTA BADGE CONTRADICTED ITS OWN NUMBER — "▲ −35 · 24h" on a
     FALL, a bare "−6351" beside "R49,710", and "· 24h" on a 7-day figure.
  3. A DRIVER COULD NOT FINISH A LOAD. Security marked the truck left site at
     04:33; the driver's Trip screen still read EN ROUTE TO LOAD at 04:37, with
     Arrived-at-offloading dimmed. Fixed with realtime on trips/transactions.

THE PHONE ALSO PROVED, on real hardware with a real load: Start route driving
the lifecycle; the live-location toggle finally ENABLED; TURN-BY-TURN
NAVIGATION drawing a real route with a sane 958 m / 4 min HUD (the
unsigned-32-bit polyline fix, confirmed on a device); and the 30-second ping
cadence, five consecutive fixes 30 s apart.

WHAT IS LEFT — START HERE

  1. THREE DECISIONS THAT ARE JEAN'S. Put them in front of him; they block
     nothing else. §4.1 has the full table.
       (a) The eleven remaining route divergences — eight distinct name pairs,
           all "longer in the rail, shorter in the bar". Both strings for each
           are in test/core/every_portal_route_is_named_test.dart.
           ⚠️ Do NOT also rename PortalTabItem('Trucks On Route') — that string
           is a LEGACY TAB LABEL and renaming it breaks tab selection SILENTLY.
       (b) Whether MessagesScreen (985 lines) and ChatScreen should be deleted
           — about 2,500 lines. ⚠️ ChatScreen is NOT dead: it is /chat/:id,
           reachable from the Communications hub. Do not delete it by accident.
       (c) A leftover firewall rule needs an ADMIN PowerShell — he must run
           Remove-NetFirewallRule -DisplayName 'CtrlBridge APK download (TCP in)'
  2. FINISH THE LOAD THAT IS ON THE ROAD. Trip 927cbf1b is en_route_to_offload
     with its arrival stamped. Only Upload POD is left, and it closes the trip
     (POD writes offloaded AND completed in one deliberate collapse). I did not
     drive it because it needs a real PHOTOGRAPH — the camera on Jean's
     personal phone at 5 a.m., or a file picker in a browser after the devtools
     MCP had dropped. Two minutes for whoever picks it up. The stockpile still
     holds 10.8 t of the 120 t order, so the route can carry more loads.
  3. A LIVE CHAT BETWEEN TWO REAL ACCOUNTS IS STILL NOT DRIVEN. A room now
     exists between roadhaul.admin and the driver (chat_rooms 24f1bef3) with NO
     messages. Two attempts failed for a TOOLING reason, not an app one: the
     dock's "Last seen 1 h ago" re-renders constantly and invalidates the
     accessibility uid between snapshot and click. ⚠️ Do NOT fall back to
     synthetic coordinate taps — a miss lands on the dismiss barrier and closes
     the dock, and one of mine hit a Refresh.
  4. ONE LINE FOR THE SHIPPING APP, NOT FOR THIS FORK: `stockpiles` is not in
     the realtime publication, so the "live fill" the buyer and transporter see
     is live-on-load only.
       alter publication supabase_realtime add table public.stockpiles;

HOW TO WORK — THIS IS JEAN'S INSTRUCTION, FOLLOW IT

don't worry about me seeing anything, I'll want to see when everything is
complete and done, so don't stop so much in between please run the task for as
long as possible so that we can get this completley done and sorted please,
correct your self where you make mistakes and fix the mistakes and make sure
you don't implement anything with gaps in them make sure its full and proper
like the original

AND, EXPLICITLY: IF YOU FIND PROBLEMS ALONG THE WAY, FIX THEM AS YOU GO — then
TEST THE FIX AND CONFIRM IT ACTUALLY WORKS AS EXPECTED before moving on. Do not
collect a list of faults to hand back; do not leave a fix unverified. Every fix
gets a test that BITES (remove the fix, watch the test fail, put it back), and
where the fix is visible on a device or in a browser, GO AND LOOK AT IT THERE.
Half-implemented work, TODOs, stubs and "this could be improved later" notes
are not acceptable — finish each thing properly and completely, the way the
original app does it.

THE METHOD, unchanged: fixtures, regenerate, LOOK at the PNG, MEASURE it with
PIL rather than squint, fix the SHAPE rather than the instance where the fault
is structural, then pin it with a test and prove the test bites by removing the
fix and watching it fail. When a report and a picture disagree, THE PICTURE
WINS.

AND THE LESSON THIS SESSION ADDED: ONE SURFACE AT A TIME PROVES ONE SURFACE.
All three defects needed two roles acting on one object at the same moment.
Open six isolated browser contexts and drive the real chain.

Watch for the faults every batch has had: a screen inside a ShellRoute that
builds its own Scaffold+AppBar; a screen that reads a service directly so no
provider override reaches it; A FIXTURE THAT SAYS LESS THAN THE SERVICE IT
STANDS IN FOR (this one hid a live data leak from 225 renders — give a fixture
every field the live row has, INCLUDING the dangerous one, so the render can
prove it is withheld); an override list that does not reach the screen; a wire
enum value reaching a reader; and a string copied between two surfaces that
names a control only one of them has.

⚠️ AND CHECK THAT YOUR CHECK CAN FAIL. Twice this session a test passed with
the fix removed: an overflow sweep that swept the wrong WIDTHS (1100 is the
worst, not 360 — it is the exact breakpoint where the KPI row goes 4-up), and a
provider test that read an already-resolved future. Both looked thorough.

OPTIONAL: if the Windows build gives trouble, just carry on with web and
mobile. It is blocked by two PRE-EXISTING faults, neither this project's — the
Flutter tool refuses the path because of the `!` in `SHOWME!`, and from a clean
path CMake fails extracting firebase_cpp_sdk_windows_12.7.0.zip. Same
dependency, same version, in the shipping app. Jean already said to skip it.

BEFORE CLAIMING ANYTHING IS DONE, ALL OF THESE MUST BE GREEN:

flutter analyze
flutter test
dart tool/release_guards.dart
dart tool/release_guards.dart --selftest
py -3 tool/_sabotage.py
py -3 tool/type_scale_codemod.py --selftest
py -3 tool/dropdown_width_check.py
py -3 tool/glyph_coverage_check.py
py -3 tool/one_clock_check.py
py -3 tool/unphotographed_screens.py
flutter test test/renders          (after any visual change, --update-goldens first)
flutter build web --release
flutter build apk --debug

...AND the original worktree re-checked against the §0 baseline above.

READ §5 OF THE MineLink-M3 HANDOFF — the things that have already gone wrong in
this repo — so you don't repeat them. The ones that have cost real time more
than once:

  * A POWER CUT DESTROYED A FILE MID-WRITE — it came back as 23,598 NUL bytes,
    right size, no content. COMMIT OFTEN; copy to the scratchpad before any
    long edit.
  * A BASH HEREDOC EATS BACKSLASHES EVEN WHEN QUOTED, and a Python string
    inside one eats them again. WRITE ANY SCRIPT CONTAINING A BACKSLASH WITH
    THE WRITE TOOL, or use Edit directly on the file.
  * NEVER READ A LONG TEST RUN THROUGH `tail`. Redirect to a file and grep it.
  * `git checkout -- <dir>` THREW AWAY THREE FINISHED UNCOMMITTED FIXES.
  * A LONG && CHAIN ENDING IN `git commit -F <heredoc>` TIMES OUT at two
    minutes. Write the message to a file and commit with -F as its own command.
  * PYTHON'S STDOUT IS cp1252 HERE — printing an en-dash or a middot from a
    script dies with UnicodeEncodeError. Set PYTHONIOENCODING=utf-8.
  * A CHECK YOU HAVE NOT SABOTAGED IS A CHECK YOU DO NOT HAVE — and the scene
    must be FAITHFUL. See the two fresh examples above.
  * A TEST WRITTEN FOR A BUG CAN READ THE HALF YOU ALREADY FIXED.
  * A NEW TEST MUST PASS `theme: AppTheme.build(...)` TO ITS MaterialApp.
  * A BACKGROUND TASK HOLDING A FILE BLOCKS A LATER COPY TO IT. ⚠️ TWO
    long-running pwsh processes on this machine are JEAN'S VS CODE TERMINALS.
    Check CommandLine before killing anything.
  * CHECK WHETHER A TEST ALREADY PINS THE BEHAVIOUR YOU ARE ABOUT TO "FIX" —
    route_title_test.dart deliberately pins all four settled route names.
  * `loadRealFonts()` IS NOT ENOUGH — name the family. CLAUDE.md §7 and §10.5.
  * `Color.alphaBlend` KEEPS THE BACKGROUND'S ALPHA.
  * `find.text` CANNOT SEE A TextSpan, and `toPlainText()` CANNOT SEE A
    TRUNCATION — use RenderParagraph.didExceedMaxLines.
  * A RepaintBoundary INSIDE A Scaffold DOES NOT CAPTURE A DIALOG.
  * `dart format` ON A DIRECTORY REFORMATS FILES YOU DID NOT TOUCH.
  * adb is at C:\Android\sdk\platform-tools and is ALREADY ON PATH.
  * THE CONSOLE STORES THEME AND ACCENT PER ADMIN. Put Jean's back.
  * GENERATING A WAYBILL ON WEB OPENS A PRINT SURFACE and closed three browser
    pages when it did. Re-open them; nothing is lost.

THE PHONE — INSTALLED AND WORKING, BUT READ THIS

  Jean's SM-G780G at 192.168.88.34 is paired. `org.minelink.m3` on it is the
  build at commit 61d2b37. Install route, about six minutes:

    1. flutter build apk --debug
    2. copy build/app/outputs/flutter-apk/app-debug.apk  ->
         \\192.168.88.30\Shared\PhoneRemote\minelink-m3.apk
    3. On the phone: My Files -> (search "My Files" in the app drawer) ->
       scroll PAST Recent files -> Network storage -> jean -> Shared ->
       PhoneRemote -> minelink-m3.apk -> ~2.5 min -> Update -> Open

  🚨 THE NAS CLOCK IS ~2 h 36 m SLOW — ITS TIMESTAMP LIES. Earlier handoffs
  said to compare the staged APK's mtime; that advice is WRONG on this share. A
  file copied at 04:04 shows as "22 Aug 01:28". COMPARE THE SHA-256 INSTEAD.
  ⚠️ My Files CACHES the folder listing. After re-staging, back out of
  PhoneRemote and re-enter it.
  ⚠️ ONLY JEAN CAN WAKE A SLEEPING DISPLAY. `probe` reports "0.061 bits/pixel
  (under 0.1 - nothing on the screen)" when it is asleep; awake it reads ~0.77.
  It slept twice on me. Ask him; injected touches cannot wake it.
  ⚠️ Invoke the `driving-jeans-phone` skill FIRST. It is his PERSONAL phone:
  prefer sig/changed/waitstable over screenshots, delete every screenshot
  immediately, do not read what you did not come for (his Recent files sit at
  the TOP of My Files — scroll past them), back out of anything opened by
  mistake and say so, and leave it on `home; waitstable; home`. `look` does NOT
  describe the screen despite its help text.
  ⚠️ The applicationId is `org.minelink.m3`, deliberately different from the
  shipping app's `com.example.flutter_application_1`. They install side by side.
  ⚠️ Sign in as roadhaul.driver@mineralguide.com / MineralGuide123! . The
  account-setup gate lists six missing documents — dismiss it with "Later".
  "Complete now" would write real data to a real production account.
  🚨 TURNING ON LIVE-LOCATION SHARING WRITES JEAN'S REAL POSITION to
  vehicle_positions on production, every 30 seconds. Testing it is legitimate —
  but TURN IT OFF afterwards and confirm the card reads "Live tracking turned
  off", and tell him you did it.

WHEN THE WORK IS DONE: rewrite

    C:\Users\Somebody Someone\Music\SHOWME!\MineLink-M3\HANDOFF.md

the same way this one was written — verified state only, nothing aspirational,
with a fresh self-contained copy-paste block in §8 that carries BOTH handoff
paths (this one and C:\Users\Somebody Someone\Claude\HANDOFF.md), the project
root, the untouchable worktree path and its baseline, exactly where you
stopped, what is already done so it is not redone, what is left, this same HOW
TO WORK instruction from Jean, and the fix-as-you-go-and-test-it rule — and
commit it. Update the commit count and the tip in it so the file does not
describe a state two commits behind itself.
```
