# MineLink M3 — session handoff

**Rewritten 2026-08-22, at the end of the session that did SIX things Jean
asked for during the run and fixed four faults found on the way to them.**
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

The tree is **clean**, **140 commits**, nothing half-applied and nothing
uncommitted. **The tip is the commit that carries THIS FILE**, so the count
above includes it. The last code commit under it is `1b0982c`, and the whole
gate in §2 was run green against the tree as it stands.

**The original worktree was re-checked against its §0 baseline at the start and
at the end and is untouched** — HEAD `df451d0`, the same three pre-existing
modified files, 14163 files under the `-prune` form, two worktree entries,
nothing modified today.

### What changed about this project this session

**Two of the previous handoff's open items are CLOSED**, both by doing them
rather than by deciding they could not be done:

- **A live chat between two real accounts is driven**, both directions, through
  the app's own composer, with the second message arriving in the first
  account's already-open thread over realtime and delivery ticks rendering.
- **The phone was driven.** The current APK is installed on the SM-G780G and
  six separate things were verified on that hardware.

**Jean asked for six things during the session. All six are built, tested and
verified on the phone:**

    1. a re-centre / re-focus control on the driver's map, and more of what
       Google Maps gives a phone
    2. more mobile tap-and-hold controls and features
    3. the sidebar collapsed by default, and every parent in it collapsed,
       on every device and platform
    4. a proper parent for everything in the sidebar — no loose entries
    5. …EXCEPT the Dashboard, which he then ruled must NOT have one
    6. the rail reordered to the ORIGINAL app's super-admin sidebar order,
       across the whole app, keeping the M3 look and the new groups

**And four faults were found and fixed on the way there:**

    1. the chat dock's launcher sat on top of the composer's SEND button,
       covering 61% of it (measured)
    2. a failed ATTACHMENT was silent — the same three-layer swallow fixed for
       text messages on 2026-08-22 and left in place for files
    3. the driver's navigation map was the only map of five with NO
       OpenStreetMap attribution
    4. the dashboard period pills had no `Material` under them, so they never
       rippled — 132 assertions per test run, no failing test

---

## 0. Where you are

| | |
|---|---|
| **This project** | `C:\Users\Somebody Someone\Music\SHOWME!\MineLink-M3` |
| What it is | A **complete, independent fork** of MineLink, being redesigned onto Material 3. Its own git repo (`main`), **140 commits**, clean tree. |
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

- **Windows is optional.** Blocked by two pre-existing faults (§5.4); web and
  Android both build.
- **Work long, don't stop to check in.** The HOW TO WORK paragraph in §8.
- **The chat is the dock** (2026-08-22).
- **Fix what you find, as you go, and prove the fix.** §8.
- **The sidebar and its groups start collapsed, everywhere** (2026-08-22).
- **Everything in the sidebar has a parent** (2026-08-22).

**`supabase/` is frozen.** No migration is created, applied or pushed here.
Three things need one and are therefore REPORTED, not fixed — §6.

---

## 2. Verified state, right now

Every one of these was run at the end of the session, against the tree as it
stands:

```
flutter analyze                                 no issues
flutter test                                    2398 passed, 1 skipped
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
render harness — RENDER NOTE                    0  (and it FAILS the test)
render harness — FAILURE STATE                  0
render harness — LOW CONTRAST                   0  (app screens; see below)
render harness — CUT OFF                        5 renders / 9 strings, deliberate
render harness — "No Material widget found"     0  (was 132 — §3.7)
A LIVE CHAT BETWEEN TWO REAL ACCOUNTS           DRIVEN, both directions
THE CURRENT BUILD ON JEAN'S SM-G780G            INSTALLED and verified
```

Test count went **2229 → 2398**: a hundred and sixty-nine new, across five new
files. Guards stayed at **40**.

⚠️ **`CUT OFF` counts RENDERS, not strings.** 5 lines, 9 strings — three
crash-report exception messages, three chat message previews, three
conversation-row previews. Unchanged.

⚠️ **LOW CONTRAST is 0 for app screens.** A raw `grep -c "LOW CONTRAST"` over a
full `test/renders` run returns **11**, every one tagged `[unit]` — the
low-contrast reporter's own self-test, which paints faint text deliberately to
prove the instrument still works. Count
`grep "LOW CONTRAST \[" out.txt | grep -vc "\[unit\]"`.

---

## 3. What this session did

Full reasoning is in each commit message — five long ones. Read them rather
than trusting this summary.

### 3.1 The live chat is driven, and the "broken send" was a stale bundle

**This is the most important thing in this section, because it nearly became a
fabricated bug report.**

Driving the composer as `roadhaul.admin` in a browser, two messages in a row
were swallowed: the box cleared, nothing reached `chat_messages`, no error, and
`list_network_requests` showed **no POST at all** across 215 requests. That is a
serious-looking fault and it was written up as one in my head before it was
checked.

It was not real. The page had been loaded into a **Chrome profile carried over
from the previous session**, and the disk cache was serving a `main.dart.js`
built before the send fix. The evidence that settled it, in order:

1. The identical insert, issued from the page's own JS with the signed-in
   user's token, returned **201**. So RLS, the payload and the room were all
   fine.
2. `debugPrint` reaches the browser console **even in a release web build**
   (the app's own "Presence status" lines are visible), so a temporary probe
   was added and the build redeployed.
3. The probes printed the whole chain — `_sendMessage enter` → `calling
   onSendMessage` → `notifier.sendMessage` → `about to insert` → `insert
   returned` — and the row landed.

**The lesson is in §5 and it is not a new one:** a hash-only navigation does not
re-fetch `main.dart.js`, and neither does a reload without `ignoreCache`. What
was new is that a *stale bundle* can look exactly like a *silent failure*.

Both directions were then driven for real:

    Admin Test  "probe run three"                  13:10 SAST
    Driver Test "Driver here, loaded and rolling."  13:17 SAST

The driver's message arrived in the admin's **already-open** thread with no
reload, `delivered_at` was stamped 2.4 s later, the delivery ticks render, and
the times read SAST for UTC rows. Room
`24f1bef3-c3be-41c7-973c-6625e4fa3913`.

### 3.2 The dock's launcher sat on the send button (commit `b9be44b`)

Measured off the live accessibility tree in a 1689×1277 window:

    send button    x 1633..1677  y 1220..1264  (44×44)
    dock launcher  x 1601..1667  y 1189..1255  (66×66)
    overlap        x 1633..1667  y 1220..1255  = 34×35 px

**61% of the send button**, with the launcher painted above it. Same shape as
the bottom-bar collision fixed on 2026-08-21: the dock wraps the whole shell
and knows nothing about the bottom-anchored chrome underneath it.

The fix is the one `/communications` has had all along — the shell does not
mount the dock over a surface that IS the conversation. `showChatFab` is now
the named `portalShowsChatDock(...)`, matched on the segment (`/chat/`) so a
future `/chatter` route cannot be swept in.

`dock_does_not_land_on_the_send_button_test.dart` pins both halves: the route
is excluded (and ordinary pages still get their dock — without that,
`return false` everywhere passes), AND the exclusion is load-bearing, by
mounting the real dock over the real composer and measuring the overlap.

**And a failed ATTACHMENT was still silent.** `sendFileMessage` was three
layers of the exact fault fixed for text — caught into a `debugPrint`, called
fire-and-forget, panel closed regardless. More is lost here than in the text
case: it runs from `onUploadComplete`, so the object is ALREADY in the
`chat_files` bucket, and a swallowed failure left it there with no row pointing
at it. `markAsRead` still swallows and is left deliberately: a read receipt is
not the user's work and the next load repairs it.

### 3.3 The maps (commit `a2340ef`) — jean's first request

> *"for the driver side map there needs to be a button to re-center and or
> re-focus … on the user's current location for incase he swipes on the map to
> check something. also add more functions and features to the maps which are
> similar to google map's mobile features and functions"*

**What was there: five `FlutterMap`s and ONE control between them** — a small
re-centre FAB on the turn-by-turn screen that only existed once the camera had
already been left behind. No zoom buttons anywhere, no way back to north, no
overview, and `onLongPress` null on every map in the tree.

`MlMapControls` is Google Maps' own mobile arrangement: a stack at the trailing
edge, reading down and ending nearest the thumb — compass (only while the map
is turned, and it turns WITH the map), overview, zoom joined into one pill with
a hairline, then my location. **48px touch targets**, measured in the test, not
the 40 a desktop map would use.

The my-location button has three states and says which: following (filled), a
fix but not following (hollow), nothing to follow. Where there is no "me" at
all — a fleet overview — it is **absent rather than dim**: the first render
showed a permanently crossed-out disc, which reads as a broken control.

Wired into all four maps a person can pan, plus a **scale bar** and
**press-and-hold to drop a pin** on each. The console's company-mirror preview
is deliberately left inert (`InteractiveFlag.none` inside an `IgnorePointer`
inside a `GestureDetector` — the tile is a BUTTON), and the test records that
exemption rather than leaving it looking like an oversight.

The dropped-pin sheet says only what the device knows — coordinate, distance,
bearing — and **deliberately does not name the place**. Reverse geocoding is
the answer that is confidently wrong here; the same ladder put "Iron Hills
Mine, Mpumalanga" at a courier depot 460 km from the gate. It does not claim
"of you" on a map that does not know where you are, which the live map does
not.

⚠️ **The driver's navigation map had NO OpenStreetMap attribution** — four of
five maps called `mlMapAttribution()`; the fullscreen one a driver looks at for
an hour did not. Added, and moved to the bottom-LEFT after measuring the first
render: the credit sat at x 334..352 and the my-location disc at x 350..397.

### 3.4 Tap and hold (same commit) — jean's second request

`MlPlatePill` is where it earns most, because of what it holds: every plate,
waybill number, ticket and serial in the product — the strings a person has to
move somewhere else. On a phone the alternative is reading `TRP-8CB20569AE` off
the glass one character at a time, and a waybill number transcribed wrong is a
load that cannot be reconciled. **29 call sites, no per-site edit** — the value
names itself.

⚠️ **The first version swallowed the row's tap, and this test caught it on the
run it was written.** An `InkWell` given only `onLongPress` still becomes
`enabled`, and an enabled `InkResponse` registers a TAP recogniser too — it
needs one for its splash. That recogniser wins the arena against the ancestor's,
so a plate inside a trip row stopped opening the trip. It is a
`GestureDetector` now. Same family as the `Semantics`-inside-`InkWell` trap
recorded in `chat_widget.dart`.

### 3.5 The sidebar starts collapsed (commit `b353543`) — jean's third request

> *"the sidebar menu nav should always be collapsed by default and each of the
> parents in it should also be collapsed by default on all devices and
> platforms please, windows, mobile, where ever and what ever"*

**FOUR places had to agree.** `AppSidebarPrefs.readPortalExpanded` and
`readSuperAdminExpanded` both answered `?? true`. The other two are the
in-memory values used for the frames BEFORE that read resolves —
`_portalSidebarExpanded` and `_railExpanded` — and they have to match the
preference's own default or the rail opens at 280px and snaps shut a frame
later, a flash of the wrong layout on every app start. That is the half that
would have been missed by changing only the obvious file.

`_MlNavRailState._isOpen` returned `?? true`. Its own doc argued for that —
groups starting closed "makes the tree look smaller than it is" — and that
reasoning was not wrong, it was outweighed: the mine rail alone opened with
five groups and twenty-one destinations at once.

**The group holding the CURRENT ROUTE still opens**, deliberately: it opens
exactly one group, the one you are standing in, and without it the rail can be
put into a state where nothing is highlighted while you are plainly on a page.

**What this makes load-bearing:** with groups shut, a closed group's badge SUM
is often the only thing saying there is work behind it. The mine rail reads
`Logistics 2` and `Settings 5`; the console reads `Requests 16`,
`Reconciliation 2`, `Communications 7`.

### 3.6 Everything has a parent (commit `04a61d5`) — jean's fourth request

> *"none of them shouldn't have a parent, all should have a parent"*

The console carried EIGHT loose leaves under a comment calling them "the flat,
high-traffic destinations". Every portal tree opened with a bare `Dashboard`.
The restricted roles were entirely flat.

| tree | new group | holds |
|---|---|---|
| console | Overview | Dashboard, Live map |
| console | Reconciliation | Recon tables, Margin ledger History, Disputes |
| console | Routes | Available routes, Route marketplace |
| console | Communications | Chat links, Notifications |
| mine · security | Gate | the gate IS that role's whole job |
| mine · controller | Weighbridge | likewise |
| mine · supervisor | Overview / Operations / Logistics / Reconciliation | the FULL tree's own four names |
| driver | My trip | Trip, Live map |
| every role | My account | Compliance, My profile |
| all portals | Overview | Dashboard |

**"Overview" rather than a group called "Dashboard"** because that is already
what the top bar calls these routes.

**Three consequences, stated rather than discovered later:**

1. Dashboard is one level deeper in the rail, because a rail group header
   TOGGLES rather than navigates. That is the cost of the rule.
2. The bottom bar's first tile reads **"Overview"** instead of "Dashboard" — it
   takes the first four TOP-LEVEL nodes, and a group navigates to its first
   child, so the destination is unchanged. **The DRIVER's bar is untouched**:
   `Dashboard · Trip · Profile` is built explicitly in `portal_shell_layout`,
   not read off this tree.
3. Landing routes are unaffected — both resolvers read the first LEAF of the
   first node.

`every_destination_has_a_parent_test.dart` sweeps **every tree the product can
build** — three org types × every role, plus the console, 94 assertions — and
the symmetric halves: no EMPTY group, every landing route still resolves, and
the console kept all eight destinations rather than losing one in the move.

### 3.7 The period pills had no Material (commit `736a8b8`)

Found while reading a test log for something else: **132 "No Material widget
found" assertions in one run, all from one line, and not one failing test** —
the assertion is thrown while BUILDING and the framework carries on. It was in
the previous green run's log too, which is how it survived: a green suite that
prints the same complaint 132 times reads as noise.

`PortalPeriodSelector` is the Today / 7 days / 30 days / 12 months control on
all three org dashboards, and its `InkWell`s had nowhere to put their ink — the
most-tapped control on those pages responded with no ripple at all.
`Material(type: MaterialType.transparency)` paints nothing, so all 261 renders
pass with goldens UNCHANGED and the count goes 132 → 0.

### 3.8 The Dashboard came back out, and the rail took the original's order (commit `1b0982c`)

Both corrections came from Jean after seeing §3.6 rendered.

**The Dashboard is the one destination with no parent**, and that turns out to
be what the ORIGINAL app does rather than an exception invented to please
anybody: `minelink_sidebar_core.dart` in the shipping tree declares three
sections — `dashboard`, `main`, `footer` — and the first holds one item, above
everything else. Wrapping it cost a tap on the most-used destination in the
product and made the bottom bar's first tile read "Overview". Everything else
keeps the parent it was given.

**The order now matches the original**, read out of the untouchable worktree
rather than remembered:

| original | this rail |
|---|---|
| Dashboard | Dashboard |
| Insights | Insights |
| **Tokens & Seats** | **Tokens & Seats** ← was below Requests |
| Requests | Requests |
| Margin ledger · Recon tables · Disputes | Reconciliation ▾ *(same order inside)* |
| Available routes · Route marketplace | Routes ▾ |
| Chat links | Communications ▾ |
| Live map | Tracking ▾ |
| Notifications · About · Settings | Settings ▾ (About is already excluded — an action, not a destination) |

So the original's flat block keeps its sequence, inside the parents §3.6 gave
it. "Tracking" is the transporter portal's own word for a live map, so nothing
was invented to house it.

The test **names** the exception instead of leaving a hole: exactly one
top-level leaf per tree, it must be the Dashboard, and it must be FIRST — a
Dashboard buried between groups is not the exception, it is a different bug. A
second test pins the console order outright, including the sequence inside
Reconciliation, because that is the half a picture cannot check.

⚠️ **The bottom bar's third tile is now "Access"**, the pre-existing
`shortLabel` for Tokens & Seats, because that group moved above Requests. Four
tiles, every word whole — photographed on the phone.

### 3.9 What was verified on Jean's actual phone

The FINAL build (tip `1b0982c`) is installed on the SM-G780G, SHA-256
`ee01e891…79f0` checked against the local build before and after the copy.
Photographed, then every screenshot deleted:

- **the console's bottom bar** reads `Dashboard · Insights · Requests · More`,
  four tiles, every word whole — the 2026-08-22 "Dashboar / d" fix, proven on
  hardware for the first time
- **the drawer reads the original order, all groups shut** — Dashboard (on its
  own, selected, no chevron), then Insights, Tokens & Seats, Requests,
  Reconciliation, Routes, Communications, Tracking, Settings. Before this
  session Insights and Requests were expanded into a wall and eight
  destinations sat loose among them.
- **the live map's controls** — overview, zoom pill, centre-on-truck, and a
  `1 km` scale bar, over real OSM tiles
- **hold-to-copy** — holding the plate pill produced our own
  `Copied — KVK007MP` **and** Android's own "Copied to clipboard" toast, which
  is what proves the clipboard really received it
- **the dropped-pin sheet** — long-pressing the map returned
  `-26.019021, 27.988375` with Copy coordinates / Open in maps

The phone was left on `home`, signed in as the platform admin, as it was found.

---

## 4. What is NOT done — PICK UP HERE

### 4.1 One decision still outstanding, and it needs an ELEVATED shell

The leftover firewall rule from a much earlier session's `serve_apk.ps1` is
still present and Enabled. Nothing is listening on port 8000 and the NAS route
makes that script unnecessary. **Jean, in an admin PowerShell:**

```powershell
Remove-NetFirewallRule -DisplayName 'CtrlBridge APK download (TCP in)'
```

### 4.2 What a handset still cannot prove at a desk

Unchanged. What is genuinely left needs the phone to physically move: GPS fixes
changing along a road over distance, auto-reroute on going off-route, the
Android foreground service surviving a long backgrounding, and battery over a
real trip.

⚠️ The EMULATOR can fake movement (`adb emu geo fix`) and the 2026-07-17 run
already proved the navigation stack that way — a real handset cannot be
teleported, so do not try it there. **An emulator is currently running**
(`emulator-5554`, visible to `adb devices`), so that route is one command away
if it is wanted.

### 4.3 One judgement call Jean may want to reverse

**The dock is not mounted on `/chat/:id`.** It was covering 61% of the send
button; suppressing it matches what `/communications` has always done. If the
dock should stay there instead, the fix has to become geometric — the dock
would need to reserve space for a bottom composer the way it already does for
the bottom bar.

(The other call from earlier in the session — Dashboard inside an "Overview"
group — was reversed by Jean the same day and is done: §3.8.)

### 4.4 Closed, do not redo

- **A live chat between two real accounts is DRIVEN** — §3.1. The previous
  handoff's §4.1 is closed.
- **The phone was driven** and the current build is installed — §3.8. The
  previous handoff's §4.2 is closed.
- **Contrast is closed app-wide AND for chat.** 1,812 low-contrast strings → 0,
  and `test/renders/low_contrast_baseline.json` is `{}`: a missing entry reads
  as zero, so it is a FLOOR, not a ratchet. **If it ever fails, do not add a
  baseline entry** — the failure message names the token to change.
- **All eighteen chat palettes are covered by arithmetic**
  (`test/design/chat_palette_contrast_test.dart`), which renders cannot do.
- **All twelve route names are settled.**
- **MessagesScreen is NOT dead code** — two live, unguarded callers on the
  licence-expiry path. Settled; do not reopen.
- **The due-diligence gate** and **the driver's whole mobile lifecycle** were
  driven end to end in earlier sessions, and **the load on the road is closed**
  (trip `927cbf1b`, 34.05 t delivered against a 34.20 t mine net).

---

## 5. How to work in this repo

```bash
cd "/c/Users/Somebody Someone/Music/SHOWME!/MineLink-M3"

flutter analyze                                  # must be clean
flutter test                                     # 2398 passing, 1 skipped
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

### What "sabotage" means here, because the word alarms people

It is a controlled, seconds-long loop, and it never leaves the working tree:
copy the file to `/tmp`, change **one line** back to the buggy version, run the
test, confirm it **fails**, restore from the backup, re-run, confirm green. A
green test proves nothing on its own — it is green either because the code is
right or because the test does not check the thing it claims to, and those look
identical from outside. It only ever touches local Dart source; never the
database, the phone, or the original worktree, and it is never committed.

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

- 🚨 **USE A FRESH `--user-data-dir` AFTER A REBUILD, or reload with
  `ignoreCache`.** This cost most of an hour this session and produced a
  convincing false bug report — see §3.1. A stale `main.dart.js` looks exactly
  like a silent failure: the UI reacts, nothing reaches the database, and there
  is no error anywhere.
- **A fresh `--user-data-dir` is also how you test a DEFAULT.** SharedPreferences
  on web is `localStorage`, so "what a user who has never touched this sees" is
  only observable in a profile that has never stored it.
- **Flutter web publishes no accessibility tree until you ask.** Click the
  hidden placeholder — `document.querySelector('flt-semantics-placeholder')
  .click()`. **After every reload**, and it can take a second attempt.
- ⚠️ **`document.body.innerText` is EMPTY on a canvas-rendered app.** Read the
  semantics instead: `flt-semantics` elements, filtered to LEAVES
  (`e.children.length === 0`), reading `aria-label || textContent`. A parent's
  `textContent` swallows all its descendants, which is how a naive reader
  reports 17 nodes on a 135-node page.
- ⚠️ **`performance.getEntriesByType('resource')` caps at 250 entries.** Once
  the buffer is full NOTHING new is recorded, so "no new requests" is a lie on
  any page that has been open a while. `list_network_requests` is CDP-based and
  has no such cap — use it, and remember it PAGES (the interesting request is
  on the LAST page).
- ⚠️ **`debugPrint` DOES reach the browser console in a release web build.**
  The app's own "Presence status" lines prove it. That makes a temporary probe
  the fastest way to settle "did this code even run".
- **A hash-only navigation does NOT reload the document.**
- **Drive several accounts at once with isolated browser contexts** — one
  `new_page` per role with a distinct `isolatedContext`. Not tabs.
- ⚠️ **`type_text` DOES fire Flutter's `onChanged`** on both the login form and
  the chat composer — the previous handoff recorded it as not working, and that
  finding did not reproduce. Click the field first, then type.
- **Chrome will not resize below ~500px.** Use CDP emulation
  (`412x915x2,mobile,touch`).
- ⚠️ **Throttle the network to see a loading state at all.** `Slow 3G`.
- ⚠️ **The accessibility uid churns.** Snapshot and click in the tightest pair
  you can.
- ⚠️ **The devtools MCP server can disconnect mid-session.** Chrome survives
  it; relaunch Chrome if not.

### Driving Jean's real phone

**Invoke the `driving-jeans-phone` skill FIRST.**

🚨 **IF THE PHONE DOES NOT ANSWER, STOP AND ASK — DO NOT WORK AROUND IT.**
Jean's standing instruction, 2026-08-22. When `phone_agent.py status` reports
`no phone at a known address - broadcasting`, or the display is asleep
(`probe` under 0.1 bits/pixel), **pause the whole task right there and say so**.
Only he can turn host mode back on and only he can wake the screen. Wait for him
to reply that the phone is awake and reachable, then retry from where you
stopped. This is not "note it and carry on with something else".

**It answered this session** (`sharing=True control=True`, `probe` 0.76
bits/pixel) and the install route worked exactly as documented, in about six
minutes:

```
1. flutter build apk --debug
2. copy build/app/outputs/flutter-apk/app-debug.apk  ->
     \\192.168.88.30\Shared\PhoneRemote\minelink-m3.apk
3. On the phone: My Files -> Network storage -> jean -> Shared ->
   PhoneRemote -> minelink-m3.apk -> ~2.5 min download -> Update -> Open
```

🚨 **THE NAS CLOCK IS ABOUT 2 h 36 m SLOW. Compare the SHA-256 instead.**

⚠️ **My Files caches the folder listing** — after re-staging, back out of
`PhoneRemote` and re-enter it, or you will tap yesterday's APK. It showed the
old timestamp until backed out this session.

⚠️ **Only Jean can wake a sleeping display.**

⚠️ **The applicationId is `org.minelink.m3`**, deliberately different from the
shipping app's. They install side by side.

It is his **personal** phone: prefer `sig`/`changed`/`waitstable` over `shot`,
delete every screenshot immediately, do not read what you did not come for,
back out of anything opened by mistake and say so, and leave it on
`home; waitstable; home`.

⚠️ **A call can come in mid-session.** Stop driving immediately — an injected
tap can hang up on somebody — press `home`, delete the screenshot, say what
happened.

🚨 **Turning on live-location sharing writes JEAN'S REAL POSITION** to
`vehicle_positions` on production, every 30 seconds. Turn it off afterwards and
confirm the card reads "Live tracking turned off."

### Live accounts

`active user accounts.txt` in the repo root. `jean@cyberhouse.co.za` /
`BuRG3rJ3@n1995@#` is the platform admin; everything `@mineralguide.com` is
`MineralGuide123!`.

⚠️ **The console stores theme and accent PER ADMIN.** Put it back if you
change it.

⚠️ **Every account's setup gate is incomplete. Dismiss it with "Later".** It
re-fires on reloads and some navigations.

### Things that have already gone wrong here — do not repeat them

- 🚨 **A STALE CACHED BUNDLE LOOKS EXACTLY LIKE A SILENT FAILURE.** §3.1. The
  single most expensive thing this session.
- 🚨 **A POWER CUT DESTROYED A FILE MID-WRITE.** Commit often.
- 🚨 **A BASH HEREDOC EATS BACKSLASHES EVEN WHEN QUOTED**, and quoting a Python
  script inside one is worse. It bit twice more this session — once on a `'` in
  a comment, once on nested quote escaping. **Write any script with the Write
  tool and run it with `py -3`.**
- 🚨 **`dart format` RUNS BETWEEN YOUR EDITS AND REFLOWS THE FILE**, so a
  patch script must not depend on indentation. Locate a block by a unique
  LABEL and walk back to the opening constructor.
- 🚨 **NEVER READ A LONG TEST RUN THROUGH `tail`.** Redirect and grep the file.
- 🚨 **`git checkout -- <dir>` THREW AWAY UNCOMMITTED WORK.**
- 🚨 **A LONG `&&` CHAIN ENDING IN `git commit -F <heredoc>` TIMES OUT.**
- 🚨 **A PIPE HIDES A FAILING EXIT CODE.** `py -3 script.py | tail -3 && dart
  format …` runs the format even when the script threw, because the pipeline's
  status is `tail`'s. That is how a half-applied edit got formatted.
- 🚨 **Python's stdout is cp1252 here.** Set `PYTHONIOENCODING=utf-8`.
- 🚨 **A CHECK YOU HAVE NOT SABOTAGED IS A CHECK YOU DO NOT HAVE.**
- 🚨 **AND A SABOTAGE THAT LEAVES THE STRING BEHIND PROVES NOTHING.** A
  source-reading test was declared non-biting this session because the sabotage
  renamed an argument and left `MlMapControls(` in the file. The test was fine;
  the sabotage was wrong. Check what your sabotage actually removed.
- 🚨 **A SOURCE-READING TEST CAN MATCH ITS OWN EXPLANATION.** Strip comments
  before asserting on source — every such test here does.
- 🚨 **CHECK WHETHER A "FAULT" IS THE DATA.** Query the row first.
- 🚨 **CHECK WHETHER A TEST ALREADY PINS THE BEHAVIOUR YOU ARE ABOUT TO
  CHANGE**, and when it does, UPDATE it with the reason rather than deleting
  it. Five tests were reversed this session, each carrying why.
- 🚨 **A NEW TEST MUST PASS `theme: AppTheme.build(...)` to `MaterialApp`**, and
  if it uses `portalCaptureOverrides()` it MUST call `freezeCaptureClock()`.
- **An `InkWell` with only `onLongPress` still steals the TAP.** §3.4.
- **A `Semantics` wrapper INSIDE an `InkWell` can swallow its tap** — use
  `Tooltip` to name an ink-well control.
- **An `Align` inside a `Positioned` that names only `right`/`bottom` expands
  to unbounded and throws.** `MlMapControls` deliberately does not wrap itself.
- **`Flexible` defaults to `flex: 1`**, and a `Wrap` sizes to its content.
- **A `RepaintBoundary` inside a `Scaffold` does not capture a DIALOG.**
- **`loadRealFonts()` is not enough** — name the family.
- **`Color.alphaBlend` keeps the BACKGROUND's alpha.**
- **`dart format` on a directory reformats files you did not touch** — name
  them.
- **`find.text` cannot see a `TextSpan`**, and **`toPlainText()` CANNOT SEE A
  TRUNCATION** — use `RenderParagraph.didExceedMaxLines`.
- **Generating a waybill on web opens a print surface.**
- **Two long-running `pwsh` processes on this machine are Jean's VS Code
  terminals.** Check `CommandLine` before killing anything.

### Where the reasoning lives

- `docs/redesign/DESIGN.md` — decisions and what each cost.
- `docs/redesign/VERIFICATION.md` — what was executed, and what has not been.
- `docs/design-reference/` — the **pre-redesign** reference PNGs. **Do not
  regenerate them**; they are the before-image.
- `docs/redesign/renders/` — 225 PNGs of the redesign.
- Every commit message carries its own reasoning.

---

## 6. For the SHIPPING app, not this fork

`supabase/` is frozen here, so these are reported rather than fixed. All three
are measured, not inferred.

1. **The transporter can read the buyer's rate, server-side.** As the Roadhaul
   admin's own JWT under RLS on production,
   `select rate from transportation_requests` returns `"950"`. The Dart half is
   fixed here (three depths plus a release guard); **the policy is the shipping
   app's to tighten.**
2. **`stockpiles` is not in the realtime publication** (measured against
   `pg_publication_tables`), so the "live fill" CLAUDE.md promises the buyer and
   transporter is live-on-load only. One line, and a migration:
   `alter publication supabase_realtime add table public.stockpiles;`
3. **The waybill names a person differently from every other surface.**
   `record_pod` writes `coalesce(profiles.display_name, 'Driver')` into
   `metadata.waybill.received_by`, and `record_truck_load` does the same for
   `dispatched_by`. Not fixed here because the document should record what was
   stamped at the time, and changing that is a decision about the record.

---

## 7. The project's own rules still apply

`CLAUDE.md` in this repo is the fork's copy of the shipping app's:

- **§10.4** — a `Row` hands a non-flex child unbounded width.
- **§10.5** — a green test over an empty fixture, an error state or a fallback
  font proves nothing.
- **§7** — `flutter test` renders in a fallback font unless you load the real
  ones.
- **§7.1** — one clock, Africa/Johannesburg.
- **§10.6** — Dart bitwise operators are unsigned 32-bit on the web. The new
  `geo_format.dart` is arithmetic-only for that reason, and its own tests say
  so.
- **§1** — the package is `flutter_application_1`. Do not rename it.
- **§5** — design tokens are law.

---

## 8. COPY-PASTE MESSAGE FOR THE NEXT CHAT

Everything the next session needs is inside this block. Paste it whole.

```
Continue the MineLink Material 3 redesign, exactly where the last session left
off. Read these TWO handoff files before doing anything else, in this order.

1. THE CURRENT HANDOFF — THIS IS THE FILE THAT GOVERNS THE WORK:

      C:\Users\Somebody Someone\Music\SHOWME!\MineLink-M3\HANDOFF.md

   Rewritten 2026-08-22 at the end of the session that did four things Jean
   asked for mid-run and fixed four faults found on the way to them. Read it in
   this order: "WHERE THIS SESSION STOPPED — READ THIS FIRST", then §0 (where
   you are + the one rule), §2 (verified state), §3 (what was done), §4 (what
   is NOT done — pick up here), §5 (how to work here, and the things that have
   already gone wrong) and §6 (three things owed to the SHIPPING app).

2. THE OLDER MACHINE-WIDE HANDOFF — BACKGROUND ONLY, DO NOT WORK FROM IT:

      C:\Users\Somebody Someone\Claude\HANDOFF.md

   Dated 2026-08-08. MCP servers, git position, the decoy folders, the phone
   tooling. The MineLink-M3 handoff above governs this work; where the two
   disagree, the MineLink-M3 one wins.

THE PATHS THAT MATTER

  Work happens here (its own git repo, branch `main`, 140 commits, clean):
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

  ⚠️ The file count depends on which `find` you run, and a difference is not a
  new file: `find . -type f -not -path "./.git/*"` returns 14164, because in a
  WORKTREE `.git` is a FILE, not a directory, so that pattern does not exclude
  it. The `-prune` form returns 14163. Both describe the same untouched tree.

WHERE I LEFT OFF, EXACTLY

The tree is CLEAN. 140 commits. Nothing is half-applied and nothing is
uncommitted. The tip is the commit carrying HANDOFF.md, so the count includes
it. The six code commits of the session are:

    b9be44b  the chat dock's launcher sat on the send button, and a failed
             attachment was silent
    a2340ef  the driver can get back to himself, and every map got the controls
             a phone expects
    b353543  the sidebar starts collapsed, and so does every group in it
    04a61d5  nothing in a sidebar sits at the top level on its own any more
    736a8b8  the dashboard period pills had no Material under them
    1b0982c  the Dashboard comes back out, and the rail is in the ORIGINAL
             app's order

Green means EXACTLY this — compare against it rather than against a memory:

    flutter analyze                    no issues
    flutter test                       2398 passed, 1 skipped
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
    render harness — CUT OFF           5 RENDERS / 9 strings, all deliberate
    render harness — "No Material widget found"   0   (was 132)
    flutter build web --release        builds
    flutter build apk --debug          builds

  ⚠️ A raw `grep -c "LOW CONTRAST"` over a full test/renders run returns 11,
  all tagged [unit] — the low-contrast reporter's OWN self-tests, which paint
  faint text deliberately to prove the instrument works. Count app screens with
  `grep "LOW CONTRAST \[" out.txt | grep -vc "\[unit\]"`, which is 0.

  ⚠️ CUT OFF counts RENDERS, not strings — 5 lines carrying 9 strings.

WHAT I DID

Closed BOTH of the previous handoff's open items, and did the four things Jean
asked for during the session.

  1. A LIVE CHAT BETWEEN TWO REAL ACCOUNTS IS DRIVEN, both directions, through
     the app's own composer, with the second message arriving in the first
     account's already-open thread over realtime. 🚨 On the way there, two
     sends looked SILENTLY SWALLOWED — box cleared, no row, no error, no POST
     in 215 requests. That was a STALE CACHED main.dart.js from a reused Chrome
     profile, not a defect. Settled by issuing the identical insert from the
     page's own JS (201) and then by temporary debugPrint probes, which DO
     reach the console in a release web build.
  2. THE PHONE WAS DRIVEN. The current APK is installed on the SM-G780G and
     four things were verified on that hardware: the console's bottom bar reads
     Dashboard · Insights · Requests · More with no broken word; the drawer's
     groups are collapsed; the live map carries overview/zoom/centre and a
     1 km scale bar over real tiles; holding a plate pill produced our
     "Copied — KVK007MP" AND Android's own clipboard toast; long-pressing the
     map returned a dropped-pin sheet with real coordinates.
  3. THE MAPS. Five FlutterMaps had ONE control between them and onLongPress
     null everywhere. MlMapControls (compass, overview, zoom pill, three-state
     my-location, 48px targets) + a scale bar + press-and-hold-to-drop-a-pin,
     on all four pannable maps. The console's mirror preview is deliberately
     left inert and the test records that exemption.
  4. TAP AND HOLD. MlPlatePill copies its code on a long press — 29 call sites,
     every plate, waybill number and serial in the product.
  5. THE SIDEBAR AND ITS GROUPS START COLLAPSED, in four places that all had to
     agree (two preferences and the two in-memory values used before those
     resolve, or the rail flashes 280px and snaps shut).
  6. EVERYTHING IN THE SIDEBAR HAS A PARENT. Nine new groups across the console
     and every role tree; 94 assertions sweep every org type × every role.
  7. FOUR FAULTS FIXED ON THE WAY: the dock's launcher covered 61% of the chat
     send button (measured); a failed ATTACHMENT was silent; the driver's
     navigation map had NO OpenStreetMap attribution; the dashboard period
     pills had no Material and never rippled (132 assertions per run, zero
     failing tests).

TWO JUDGEMENT CALLS JEAN MAY WANT TO REVERSE — both one-line reverts, both in
§4.3: Dashboard now sits inside an "Overview" group (so it is one level deeper
and the bottom bar's first tile reads "Overview"), and the chat dock is no
longer mounted on /chat/:id.

WHAT IS LEFT — START HERE

  1. A LEFTOVER FIREWALL RULE needs an ADMIN PowerShell — only Jean can run it:
       Remove-NetFirewallRule -DisplayName 'CtrlBridge APK download (TCP in)'
  2. WHAT A HANDSET STILL CANNOT PROVE AT A DESK — needs the phone to
     physically move: GPS fixes changing along a road, auto-reroute, the
     foreground service surviving a long backgrounding, battery over a trip.
     The EMULATOR can fake movement and already proved the nav stack that way;
     an emulator is running right now (emulator-5554).
  3. THREE THINGS ARE OWED TO THE SHIPPING APP, not fixable in this fork
     (`supabase/` is frozen): the RLS half of the rate leak, `stockpiles`
     missing from the realtime publication, and the waybill naming a person by
     `profiles.display_name`. All three measured, not inferred — §6.
  4. 🚨 IF YOU NEED THE PHONE AND IT DOES NOT ANSWER — `phone_agent.py status`
     says "no phone at a known address - broadcasting", or `probe` reports
     under 0.1 bits/pixel because the display is asleep — PAUSE THE WHOLE TASK
     RIGHT THERE AND TELL JEAN. Then WAIT for him to reply that the phone is
     awake and reachable, and retry from exactly where you stopped. Only he can
     turn host mode on and only he can wake a sleeping screen; neither is
     possible from this PC, and injected touches cannot wake it. Do NOT work
     around it, do NOT skip ahead to something else, and do NOT report the rest
     green as though the phone step were optional — it is the only thing that
     proves a fix on real hardware.
     ⚠️ Invoke the `driving-jeans-phone` skill FIRST. It is his PERSONAL phone.

HOW TO WORK — THIS IS JEAN'S INSTRUCTION, FOLLOW IT

don't worry about me seeing anything, I'll want to see when everything is
complete and done, so don't stop so much in between please run the task for as
long as possible so that we can get this completley done and sorted please,
correct your self where you make mistakes and fix the mistakes and make sure
you don't implement anything with gaps in them make sure its full and proper
like the original

AND, EXPLICITLY: IF YOU FIND PROBLEMS ALONG THE WAY, FIX THEM AS YOU GO — then
TEST THE FIX AND CONFIRM IT ACTUALLY WORKS AS EXPECTED. Do not merely note or
collect a list of faults to hand back; do not leave a fix unverified. Every fix
gets a test that BITES (remove the fix, watch the test fail, put it back), and
where the fix is visible on a device or in a browser, LOOK AT IT THERE TOO.
Half-implemented work, TODOs, stubs and "this could be improved later" notes
are not acceptable — finish each thing properly and completely, the way the
original app does it.

THE METHOD, unchanged: fixtures, regenerate, LOOK at the PNG, MEASURE it with
PIL rather than squint, fix the SHAPE rather than the symptom when the fault
is structural, then pin it with a test and prove the test bites by removing the
fix and watching it fail. When a report and a picture disagree, THE PICTURE
WINS.

AND THE LESSONS THIS SESSION ADDED:

  * 🚨 A STALE CACHED BUNDLE LOOKS EXACTLY LIKE A SILENT FAILURE. Use a fresh
    --user-data-dir after every rebuild, or reload with ignoreCache. A fresh
    profile is ALSO the only way to test what a first-time user sees, since
    SharedPreferences on web is localStorage.
  * `document.body.innerText` IS EMPTY on a canvas-rendered app — read the
    semantics LEAVES, not a parent's textContent.
  * `performance.getEntriesByType('resource')` CAPS AT 250 and then records
    nothing, so "no new requests" is a lie on a long-lived page. Use
    list_network_requests, and page to the END.
  * `debugPrint` REACHES THE BROWSER CONSOLE in a release web build. A
    temporary probe is the fastest way to settle "did this run at all".
  * A SABOTAGE THAT LEAVES THE STRING BEHIND PROVES NOTHING — check what your
    sabotage actually removed before concluding a test does not bite.
  * `dart format` RUNS BETWEEN EDITS AND REFLOWS THE FILE, so a patch script
    must locate blocks by label and walk back, never by indentation.
  * A PIPE HIDES A FAILING EXIT CODE: `py script.py | tail && dart format`
    formats even when the script threw.
  * AN InkWell WITH ONLY onLongPress STILL STEALS THE TAP from the row it sits
    in. Use a GestureDetector.
  * AN Align INSIDE A Positioned that names only right/bottom expands to
    unbounded and throws.
  * WHEN AN EXISTING TEST PINS THE BEHAVIOUR YOU ARE CHANGING, UPDATE IT WITH
    THE REASON. Five were reversed this session, each carrying why.

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
flutter test test/renders          (after any visual change, --update-goldens)
flutter build web --release
flutter build apk --debug

...AND the original worktree re-checked against the §0 baseline above.

READ §5 OF THE MineLink-M3 HANDOFF — the things that have already gone wrong in
this repo — so you don't repeat them. The ones that have cost real time more
than once:

  * A POWER CUT DESTROYED A FILE MID-WRITE. Commit often.
  * A BASH HEREDOC EATS BACKSLASHES EVEN WHEN QUOTED, and quoting a Python
    script inside one is worse. WRITE ANY SCRIPT WITH THE WRITE TOOL and run it
    with `py -3`.
  * NEVER READ A LONG TEST RUN THROUGH `tail`. Redirect to a file and grep it.
  * `git checkout -- <dir>` THREW AWAY THREE FINISHED UNCOMMITTED FIXES.
  * A LONG && CHAIN ENDING IN `git commit -F <heredoc>` TIMES OUT at two
    minutes. Write the message to a file and commit with -F as its own command.
  * PYTHON'S STDOUT IS cp1252 HERE — set PYTHONIOENCODING=utf-8.
  * A NEW TEST MUST PASS `theme: AppTheme.build(...)` TO `MaterialApp`, and if
    it uses `portalCaptureOverrides()` it MUST call `freezeCaptureClock()`.
  * CHECK WHETHER A TEST ALREADY PINS THE BEHAVIOUR YOU ARE ABOUT TO "FIX".
  * `loadRealFonts()` IS NOT ENOUGH — name the family.
  * `Color.alphaBlend` KEEPS THE BACKGROUND'S ALPHA.
  * `find.text` CANNOT SEE A TextSpan, and `toPlainText()` CANNOT SEE A
    TRUNCATION — use RenderParagraph.didExceedMaxLines.
  * A RepaintBoundary INSIDE A Scaffold DOES NOT CAPTURE A DIALOG.
  * `dart format` ON A DIRECTORY REFORMATS FILES YOU DID NOT TOUCH — name them.
  * TWO LONG-RUNNING pwsh PROCESSES ON THIS MACHINE ARE JEAN'S VS CODE
    TERMINALS. Check CommandLine before killing anything.
  * THE CONSOLE STORES THEME AND ACCENT PER ADMIN. Put it back if you change it.
  * EVERY ACCOUNT'S SETUP GATE IS INCOMPLETE — dismiss it with "Later".
  * GENERATING A WAYBILL ON WEB OPENS A PRINT SURFACE.
  * THE DEVTOOLS MCP SERVER CAN DISCONNECT MID-SESSION, and Chrome may exit
    with it.
  * adb is at C:\Android\sdk\platform-tools.
  * 🚨 TURNING ON LIVE-LOCATION SHARING WRITES JEAN'S REAL POSITION to
    vehicle_positions on production, every 30 seconds. Turn it off afterwards,
    confirm the card reads "Live tracking turned off", and TELL HIM.

OPTIONAL: if the Windows build gives trouble, just carry on with web and
mobile. It is blocked by two PRE-EXISTING faults, neither of them the redesign:
the Flutter tool refuses the path because of the `!` in `SHOWME!`, and from a
clean path CMake fails extracting firebase_cpp_sdk_windows_12.7.0.zip — same
dependency, same version, in the shipping app. Jean already said to skip it.

LIVE ACCOUNTS
  `active user accounts.txt` in the repo root.
  jean@cyberhouse.co.za / BuRG3rJ3@n1995@#   (platform admin)
  everything @mineralguide.com / MineralGuide123!

WHEN THE WORK IS DONE: rewrite

    C:\Users\Somebody Someone\Music\SHOWME!\MineLink-M3\HANDOFF.md

the same way this one was written — verified state only, no intentions, ending
with a fresh self-contained copy-paste block in §8 that carries BOTH handoff
paths (that one and C:\Users\Somebody Someone\Claude\HANDOFF.md), the project
root, the untouchable worktree path and its baseline, exactly where you
stopped, what is already done so it is not redone, what is left, THE PHONE RULE
above, this same HOW TO WORK instruction from Jean quoted VERBATIM, and the
fix-as-you-go rule — and then commit it. State the commit count the tree WILL
be at once that commit lands, and say that the tip is the commit carrying the
file, so the handoff is self-consistent rather than a commit or two behind
itself.
```
