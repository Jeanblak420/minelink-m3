# MineLink M3 — session handoff

**Rewritten 2026-08-22, at the end of the session that finished the load on the
road and then found five faults by driving the app instead of reading it.**
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

The tree is **clean**, **131 commits**, nothing half-applied and nothing
uncommitted. **The tip is the commit that carries THIS FILE**, so the count
above includes it. The last code commit under it is `eb84e45`, and the whole
gate in §2 was run green against the tree as it stands.

**The original worktree was re-checked against its §0 baseline at the start and
at the end and is untouched** — HEAD `df451d0`, the same three pre-existing
modified files, 14163 files under the `-prune` form, two worktree entries,
nothing modified today.

### What changed about this project this session

**The load that was on the road is CLOSED**, and driving the app around it
found five real faults that no test and no render could have shown. Every one
was fixed, tested with a check that was sabotaged until it bit, and — where it
could be — re-verified on the running app.

    1. the phone's bottom bar read "Dashboar / d"
    2. three routes announced themselves as "Workspace"
    3. the driver's waybill deep-link drew the portal's chrome twice
    4. every sign-in told the reader their feeds were broken
    5. the /chat/:id URL opened the dashboard, and a failed send was silent

Plus the two decisions Jean settled (§3.1, §3.2).

---

## 0. Where you are

| | |
|---|---|
| **This project** | `C:\Users\Somebody Someone\Music\SHOWME!\MineLink-M3` |
| What it is | A **complete, independent fork** of MineLink, being redesigned onto Material 3. Its own git repo (`main`), **131 commits**, clean tree. |
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

**`supabase/` is frozen.** No migration is created, applied or pushed here.
Three things now need one and are therefore REPORTED, not fixed — §6.

---

## 2. Verified state, right now

Every one of these was run at the end of the session, against the tree as it
stands:

```
flutter analyze                                 no issues
flutter test                                    2229 passed, 1 skipped
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
A WHOLE LOAD, ON THE LIVE DATABASE              CLOSED — trip completed
```

Test count went **2160 → 2229**: sixty-nine new, across six new files.
Guards stayed at **40** (one new one last session; none added this one).

⚠️ **`CUT OFF` counts RENDERS, not strings.** The harness prints one line per
render and names the strings under it: 5 lines, 9 strings — the same nine the
previous handoff recorded (three crash-report exception messages, three chat
message previews, three conversation-row previews). Nothing regressed; the
earlier "9" was counting strings and this counter counts lines.

⚠️ **LOW CONTRAST is 0 for app screens.** A raw `grep -c "LOW CONTRAST"` over a
render run returns **11** — every one of them tagged `[unit]`, which is the
low-contrast reporter's own self-test deliberately painting faint text to prove
the instrument still works. Count
`grep "LOW CONTRAST \[" out.txt | grep -vc "\[unit\]"`.

---

## 3. What this session did

Full reasoning is in each commit message — six long ones. Read them rather than
trusting this summary.

### 3.1 Jean settled the route names (commit `9c7dbe9`)

The eleven remaining rail/bar divergences, with the rule "the clearer of the
two strings, per pair" — so the winner is sometimes the rail's word and
sometimes the bar's:

    mine/stockpiles   rail "Supervisor & stockpiles" -> "Stockpiles"
    mine/security     bar  "Security"                -> "Security gate"
    mine/locations    rail "Mine locations"          -> "Locations"
    */tons-out        rail "Recon tables (tons out)" -> "Tons out"
    */company         rail "Company profile"         -> "Company"
    */profile         bar  "Profile"                 -> "My profile"
    /communications   rail "Announcements"           -> "Communications"
    /appearance       bar  "Appearance & theme"      -> "Appearance"

Two were the "names the neighbour" fault rather than two reasonable names: bar
"Security" sits a group from the real destination "Account & security", and bar
"Profile" a leaf from "Company". Three surfaces carried a THIRD name and came
in with it — the appearance page's own heading, `_legacyTabLabels`, and the mine
dashboard's "Recon tables" shortcut, which named the SIBLING route.

⚠️ `PortalTabItem('Profile')` and the driver's bottom-nav "Profile" are
deliberately untouched: the first is a LEGACY TAB LABEL that `_legacyTabLabels`
maps onto "My profile" (renaming it breaks tab selection silently — the same
trap tried and reverted for 'Trucks On Route'), and the second is the settled
driver-mobile bar, Dashboard · Trip · Profile.

**The render harness was typing the top bar by hand.** `subtitle:` is a string
on every `shootPortal`/`shootShared` call, so 225 pictures could show a bar the
app never draws — and this rename proved it: three fixtures went on
photographing names that no longer existed. The fixture's string is now CHECKED
against `mlRouteTitle`. That check found **nine more mismatches across fifteen
shots**, including **five renders shot at routes that do not exist**
(`/portal/*/trucks`, `/portal/transporter/fuel` — the router mounts
`truck-locations` and `fuel-costs`), so the rail highlighted nothing in them.

**And three routes read "Workspace" in the real app.**
`every_portal_route_is_named_test.dart` walks the RAIL, and the rail is a menu,
not the router; every detail page and deep link was invisible to it. The
console has had a router sweep since 2026-08-21 and the portal never got one.
`every_portal_router_route_is_named_test.dart` is that sweep, and it found
`accept-route/:routeId`, `allocate-fleet/:routeId` (the transporter's
accept-and-crew deep links, the busiest in the product) and
`drop-off/:tripId`. It also found the family `/employees/…/details` was fixed
for once: `/portal/mine/trips/t-1` is ONE trip and read "Trips".

### 3.2 MessagesScreen is NOT dead code (commit `3daaa6f`)

Jean agreed to delete it "as long as you're only deleting dead code". Reading
the callers first is what stopped the deletion. It has **two live, unguarded
callers**: `MlExpiryNotice.onMessageMineLink`, wired on EVERY portal screen bar
`/profile`, and `ExpiredAccessScreen`'s "Message MineLink" button. Token expiry
is enforced in Postgres, so by the time that notice appears the company's
writes are already being refused by RLS — deleting the screen would take away
the reply channel at the one moment it matters.

The two `context.push('/messages')` calls in `EmployeeProfileScreen` stay too:
the dock is mounted CONDITIONALLY (`showChatFab`), so the else branch is a live
fallback, and removing it would make "Message" a button that silently does
nothing whenever the dock is absent.

**Nothing was deleted.** The test pins the finding so the question is settled
rather than re-opened by the next reader who counts the lines.

### 3.3 The phone's bottom bar read "Dashboar / d" (commit `31a9c28`)

Photographed on Jean's SM-G780G, signed in as the platform admin. One word
broken between two letters, painted from x=0 rather than centred.
`bottom_nav_labels_test.dart` has forbidden exactly that since 2026-08-21 —
and it was green, for two reasons that are both the "check you have not
sabotaged" trap in a new hat: it swept text scales **1.0 and 1.3 and nothing
between** (the first break at 412px is at **1.2**; at 360px with bold it is
**1.05**), and it switched the one-word rule **off** at 1.3.

The old reasoning — that abbreviating "Dashboard", "Operations", "Stockpiles"
and "Production" is worse than a wrapped word — was right. Its conclusion was
wrong, because those were not the only two options. The slot is `width / 5`
because the bar always showed four destinations plus More. **The words were
never the problem; the FOURTH destination was.** `_bottomDestinations` now
carries as many as fit: three plus More is 103px a tile at 412, two is 137px,
and the one that steps out is a tap away in the drawer with its badge folded
into More's.

The arithmetic is exact, not a fudge: Flutter lays each destination in an
`Expanded` and the label's padding is `EdgeInsets.only(top: 4)` — no horizontal
inset at all.

It also fixed a fault at scale **1.0** that the old rule had accepted: the mine
security guard's bar read "Security / gate" across two lines from x=0, hard
against the screen edge — the exact fault that file's own header describes
finding in August, which its fix could not reach because that tree is FLAT and
has no groups to shorten anything.

Sweep now: 3 widths × 7 scales × bold on/off = **42 combinations** over every
tree; the one-word rule holds at every scale; the bar must keep two
destinations plus More; and `barLabels` READS the rendered destinations instead
of predicting `tree.take(4)`.

### 3.4 The load on the road is CLOSED

POD uploaded as `roadhaul.driver` in a browser at 412×915 with a **generated**
POD image rather than the phone camera — same code path
(`uploadPodPhoto` → `record_pod`), no photograph of wherever a personal phone
happened to be pointing.

    trip 927cbf1b   en_route_to_offload -> completed
    net at mine     34.20 t   (authoritative)
    delivered       34.05 t
    variance        -0.150 t  (both figures kept, as §4 requires)
    offloaded_at / completed_at   both 08:10:00.785942Z — the deliberate collapse
    pod_uploads     1 row, photo in the private bucket
    transaction     TRP-8CB20569AE -> completed

The signed waybill regenerates: opened it and scrolled the document — **RECEIVED
BY carries the driver's real signature**, DATE 2026-08-22, TIME **10:10**,
which is `completed_at` read through the one clock.

⚠️ Two things on that waybill look like faults and are NOT. All four TRUCK SEAL
SERIAL NO. lines are blank because `routes.seal_required` is **false** for this
route and no seals were captured. DISPATCHED BY reads "Management" and RECEIVED
BY "Driver" because those accounts' `profiles.display_name` genuinely ARE those
words, and the dispatch SIGNATURE line is blank because that user has no saved
signature and chose to proceed unsigned — which the prompt offers. Checked in
the database before writing any of it down.

### 3.5 The driver's waybill deep-link drew the chrome twice (commit `fb14950`)

One navigation after the POD. `/portal/driver/trip/:id/waybill` came back with
the account-setup banner drawn **TWICE**, one above the other, each with its own
"Complete now" — plus the portal rail down the left AND the driver's own
Dashboard · Trip · Profile bar underneath. Photographed before and after.

`DriverAppScreen` is a complete shell, so `PortalShellLayout` returns it bare —
decided by an exact-match set of three path literals, and that route is not one
of them. It is `driverAppOwnsChrome(path)` now, and
`driver_app_owns_its_chrome_test.dart` reads the ROUTER and asserts the
predicate agrees in BOTH directions: a route that renders `DriverAppScreen`
must be bare, and one that does not must keep the shell
(`/portal/driver/notifications` needs it — it has no chrome of its own).

### 3.6 Every sign-in cried wolf (commit `0acaa70`)  ⚠️ THE BIG ONE

A clean sign-in as `roadhaul.admin` put SEVEN failure states on the
transporter's landing screen at once — four KPIs and three panels, all saying
the feed was unavailable or could not be read — and then filled in by itself
with no reload and no retry: 235 t, R184,611, 2 trucks on route, 67%
utilisation.

Nothing had gone wrong. **Both RPCs were captured from the network panel
returning HTTP 200 with real rows**, against the correct `p_company_id`. That
is what turned it from a backend blip into a defect worth chasing.

`feed.valueOrNull` collapses "still reading" and "could not read" into the same
null. The dashboards' own source has carried a comment naming this trap since
2026-08-21 — written when the MINE's stockpile ring did it to a mine owner —
and the fix at the time was applied to that one card. The KPI band of all
three dashboards and six more panels were left in it, so the mine has been
showing "Reading stockpiles…" in one band and "stockpiles unavailable" in the
band directly above it, for the same feed, in the same frame.

`PortalKpi.loading` and `portalFeedPending(what)` are the split, wired at
eleven sites off `AsyncValue.isFirstLoad` (which already existed in the kit and
is what the action queues use).

**Verified live** with the network throttled to Slow 3G so the window could be
sampled at all: across ten ticks the band read `checking…` on all four tiles
and there were **zero** failure strings.

⚠️ **Getting the test to bite took four attempts, and all four are traps worth
knowing.** It passed over fixture DATA (duplicate overrides in one list are not
"last wins" — the feed overrides are in a NESTED `ProviderScope` now). It
passed over a BLANK PAGE (without the auth/company/employee gates the
dashboards render "Company not loaded" and nothing else — dumped the empty
widget tree to prove it). Overriding `FlutterError.onError` trips the binding's
own assertion — `tester.takeException()` in a drain loop is the supported way.
And `isNotEmpty` on the throwing case survived a sabotage that silenced the KPI
band while the panels still spoke, so there is now a symmetric assertion: a
failed feed must not claim to be loading.

### 3.7 The /chat/:id URL opened the dashboard (commit `da91b0d`)

    final chatArgs = state.extra as ChatScreenArgs?;
    if (chatArgs == null) return const HomeTabBodyScreen();

`extra` does not survive a page load, so `:chatRoomId` was parsed and thrown
away and every arrival that was not the one tap in the Communications hub got
the WORKSPACE DASHBOARD under a top bar reading **Chat**. A refresh, a
bookmark, a pasted link and a notification deep link all land there.

`ChatRoomRoute` resolves the room through the SAME provider the hub reads, so
access stays enforced by that query and RLS rather than by the widget. Verified
on the running app: the thread now opens from the URL alone, with the driver's
real message in it.

**And a failed send looked exactly like a sent one.** Three layers, none of
which could report a failure: the composer cleared the box without awaiting,
`ChatScreen`'s callback was `async` and unawaited, and the notifier wrapped the
whole insert in `catch (e) { debugPrint(...) }` — a log that goes nowhere a
user can see and nowhere at all in a release web build. The draft is now handed
over and only forgotten if that worked; a failure puts it back with the caret
where they left off and says what happened.

⚠️ **The send button's label is a `Tooltip`, and must stay one.** A
`Semantics(button: true, label: …)` inside the `InkWell` was tried first and it
**swallowed the tap** — the InkWell's node carries the tap ACTION, and the
inner node merged over it as a button with nothing behind it. The control
announced itself perfectly and did nothing at all. Found by a probe in
`_sendMessage` that never printed.

---

## 4. What is NOT done — PICK UP HERE

### 4.1 A live chat between two real accounts is STILL not driven

Not for want of trying, and the reason is now measured rather than guessed.

**The composer cannot be driven through CDP.** `type_text` sets Flutter's
hidden textarea and the Dart controller — the semantics node shows the value —
but never fires `onChanged`, so `hasDraft` stays false and the send button's
semantics node has **no tap action** (`flt-tappable` absent, measured). Real key
events via `press_key` DO fire it and the button becomes tappable, but the
draft does not survive to the next tool call on that screen.

That is the same wall the previous session hit from the DOCK by a different
route, and it is why the one real message in that room — "hi", 04:21 — was
typed by hand on the phone. **It is a tooling limit, not a proven app fault**,
and it is recorded as unproven rather than claimed either way.

**Ten seconds of thumb settles it.** Ask Jean to open the app on his phone as
`roadhaul.driver`, or sign in as `roadhaul.admin` on any browser he is holding,
and send one message in the Driver Test room. Room
`24f1bef3-c3be-41c7-973c-6625e4fa3913`; check it landed with:

```sql
select sender_name, content, timestamp, delivered_at, read_at
from chat_messages where chat_room_id = '24f1bef3-c3be-41c7-973c-6625e4fa3913'
order by timestamp;
```

### 4.2 The phone was not driven this session

`CtrlBridge` host mode went **off** partway through (Jean took a WhatsApp call
and the app backgrounded), and `phone_agent.py status` has answered
"no phone at a known address" since. Nothing on the phone was changed.

**A current APK is staged and hash-verified, ready to install:**

```
\\192.168.88.30\Shared\PhoneRemote\minelink-m3.apk
SHA-256  B33B58B0B2DAE7C3024D02879C6FC737997A239DC2E1A6C31A1A72991DF56E3D
```

That build is the current tip. Installing it verifies **§3.3 on real hardware**
— the console's bottom bar should read `Dashboard · Insights · Requests · More`
(four tiles, one destination fewer) with no word broken in half. Jean turns
host mode back on: **CtrlBridge → Let my PC control this phone → Host mode on.**

⚠️ The app on the phone is currently signed in as the **platform admin**, not
the driver, and I had begun signing out when the call arrived. It may be at the
login screen or still on the console. Nothing was left half-done in the
database.

### 4.3 One decision still outstanding, and it needs an ELEVATED shell

The leftover firewall rule from a much earlier session's `serve_apk.ps1` is
still present and Enabled. Nothing is listening on port 8000 and the NAS route
makes that script unnecessary. **Jean, in an admin PowerShell:**

```powershell
Remove-NetFirewallRule -DisplayName 'CtrlBridge APK download (TCP in)'
```

### 4.4 What a handset still cannot prove at a desk

Unchanged from the previous handoff. What is genuinely left needs the phone to
physically move: GPS fixes changing along a road over distance, auto-reroute on
going off-route, the Android foreground service surviving a long backgrounding,
and battery over a real trip.

⚠️ The EMULATOR can fake movement (`adb emu geo fix`) and the 2026-07-17 run
already proved the navigation stack that way — a real handset cannot be
teleported, so do not try it there.

### 4.5 Closed, do not redo

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
- **All twelve route names are settled** — the four from 2026-08-22 morning and
  the eight in §3.1. `every_portal_route_is_named_test.dart`'s allow-list is
  down to the eight that are divergent BY DESIGN (four dashboard roots, four
  `/operations`), both groups for the same cause: the resolver has no role and
  no session.
- **The due-diligence gate** and **the driver's whole mobile lifecycle** were
  driven end to end last session.

---

## 5. How to work in this repo

```bash
cd "/c/Users/Somebody Someone/Music/SHOWME!/MineLink-M3"

flutter analyze                                  # must be clean
flutter test                                     # 2229 passing, 1 skipped
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
  .click()`. **After every reload**, and it can take a second attempt.
- **A hash-only navigation does NOT reload the document.** Going from
  `#/a` to `#/b` never re-fetches `main.dart.js`, so a fresh build is not
  picked up. Reload with `ignoreCache` after every rebuild — this cost real
  time before it was written down.
- **Drive SIX ACCOUNTS AT ONCE with isolated browser contexts.** One `new_page`
  per role with a distinct `isolatedContext` gives each its own storage. Do NOT
  try to do it with tabs.
- ⚠️ **`type_text` does not fire Flutter's `onChanged`.** It reaches the Dart
  controller (the semantics node shows the value) but the widget never
  rebuilds, so anything gated on "is there a draft" stays disabled and its
  semantics node has no tap action. `press_key` sends real key events and does
  fire it. This is what stopped the live chat — §4.1.
- **Chrome will not resize below ~500px.** Use CDP emulation
  (`412x915x2,mobile,touch`).
- ⚠️ **Throttle the network to see a loading state at all.** The §3.6 fault
  lives in a window of about a second; `Slow 3G` is what made it samplable.
- ⚠️ **The accessibility uid churns.** Snapshot and click in the tightest pair
  you can, and on "no longer exists" take a fresh snapshot rather than reaching
  for coordinates.
- ⚠️ **`performance.getEntriesByType('resource')` is how you prove a request
  did or did not happen.** It is what established that the chat send issued no
  POST at all, which is a different fault from one that was refused.
- ⚠️ **`list_network_requests` pages.** The interesting request is usually on
  the LAST page, not the first.
- ⚠️ **The devtools MCP server can disconnect mid-session.** Chrome survives it.

### Driving Jean's real phone

**Invoke the `driving-jeans-phone` skill FIRST.**

⚠️ **Host mode is currently OFF** — see §4.2. `status` answers "no phone at a
known address". Only Jean can turn it back on.

The install route, proven three times, about six minutes:

```
1. flutter build apk --debug
2. copy build/app/outputs/flutter-apk/app-debug.apk  ->
     \\192.168.88.30\Shared\PhoneRemote\minelink-m3.apk
3. On the phone: My Files -> (search "My Files" in the app drawer) ->
   scroll past Recent files -> Network storage -> jean -> Shared ->
   PhoneRemote -> minelink-m3.apk -> ~2.5 min download -> Update -> Open
```

🚨 **THE NAS CLOCK IS ABOUT 2 h 36 m SLOW. DO NOT TRUST ITS TIMESTAMP.**
**Compare the SHA-256 instead:**

```powershell
(Get-FileHash 'build\app\outputs\flutter-apk\app-debug.apk' -Algorithm SHA256).Hash
(Get-FileHash '\\192.168.88.30\Shared\PhoneRemote\minelink-m3.apk' -Algorithm SHA256).Hash
```

⚠️ **My Files caches the folder listing.** After re-staging, back out of
`PhoneRemote` and re-enter it.

⚠️ **Only Jean can wake a sleeping display.** `probe` reports
`0.061 bits/pixel` when asleep and about `0.771` when awake.

⚠️ **The applicationId is `org.minelink.m3`**, deliberately different from the
shipping app's. They install side by side.

It is his **personal** phone: prefer `sig`/`changed`/`waitstable`, delete every
screenshot immediately, do not read what you did not come for, back out of
anything opened by mistake and say so, and leave it on `home; waitstable; home`.

⚠️ **A call can come in mid-session.** One did, and WhatsApp brought its own
screen to the foreground while a sign-out was in progress. **Stop driving
immediately** — an injected tap on that screen can hang up on somebody. Press
`home` (which backgrounds the call without ending it), delete the screenshot,
and say what happened.

🚨 **Turning on live-location sharing writes JEAN'S REAL POSITION** to
`vehicle_positions` on production, every 30 seconds. Turn it off afterwards and
confirm the card reads "Live tracking turned off."

### Live accounts

`active user accounts.txt` in the repo root. `jean@cyberhouse.co.za` /
`BuRG3rJ3@n1995@#` is the platform admin; everything `@mineralguide.com` is
`MineralGuide123!`.

⚠️ **The console stores theme and accent PER ADMIN.** Switching Jean's mode to
Light writes to his account. Put it back.

⚠️ **Every account's setup gate is incomplete. Dismiss it with "Later".** It
re-fires on every reload and on some navigations, so expect to dismiss it more
than once per session.

### Things that have already gone wrong here — do not repeat them

- 🚨 **A POWER CUT DESTROYED A FILE MID-WRITE.** **Commit often; copy to the
  scratchpad before any long edit.**
- 🚨 **A BASH HEREDOC EATS BACKSLASHES EVEN WHEN QUOTED**, and a Python string
  inside one eats them again. It bit twice more this session — a `\n` inside a
  Dart string literal came out as a real newline and broke the file. **Write
  any script containing a backslash with the Write tool, or use Edit.**
- 🚨 **NEVER READ A LONG TEST RUN THROUGH `tail`.** Redirect and grep the file.
- 🚨 **`git checkout -- <dir>` THREW AWAY UNCOMMITTED WORK.**
- 🚨 **A LONG `&&` CHAIN ENDING IN `git commit -F <heredoc>` TIMES OUT.**
- 🚨 **Python's stdout is cp1252 here.** Set `PYTHONIOENCODING=utf-8`.
- 🚨 **A CHECK YOU HAVE NOT SABOTAGED IS A CHECK YOU DO NOT HAVE**, and the
  scene must be FAITHFUL. Four fresh proofs in §3.6 alone, plus §3.3's
  unswept scale band.
- 🚨 **A SOURCE-READING TEST CAN MATCH ITS OWN EXPLANATION.** A `contains`
  check for `HomeTabBodyScreen()` matched the COMMENT describing the bug it
  was written for. Strip comments before asserting on source.
- 🚨 **A FIXTURE THAT SAYS LESS THAN THE SERVICE HIDES REAL FAULTS**, and a
  fixture that says what the CODE computes hides drift — the render harness
  typed its own top bar for 225 pictures.
- 🚨 **ONE SURFACE AT A TIME PROVES ONE SURFACE.**
- 🚨 **A NEW TEST MUST PASS `theme: AppTheme.build(...)` to `MaterialApp`.**
- 🚨 **A NEW TEST THAT USES `portalCaptureOverrides()` MUST FREEZE THE CLOCK**
  (`freezeCaptureClock()` from `test_helpers/frozen_clock.dart`). The
  `capture-fixture-without-a-frozen-clock` guard caught this session's new
  sweep on the run it was written.
- 🚨 **CHECK WHETHER A "FAULT" IS THE DATA.** Two things on the waybill looked
  wrong and were faithful — §3.4. Query the row before writing anything down.
- 🚨 **A background task holding a file blocks a later copy to it.** **Two
  long-running `pwsh` processes on this machine are Jean's VS Code terminals;
  check `CommandLine` before killing anything.**
- **A `Semantics` wrapper INSIDE an `InkWell` can swallow its tap** — §3.7.
  Use `Tooltip` to name an ink-well control.
- **`Flexible` defaults to `flex: 1`**, and a `Wrap` sizes to its content.
- **A `RepaintBoundary` inside a `Scaffold` does not capture a DIALOG.**
- **`loadRealFonts()` is not enough** — name the family.
- **`Color.alphaBlend` keeps the BACKGROUND's alpha.**
- **`dart format` on a directory reformats files you did not touch** — name the
  files.
- **`find.text` cannot see a `TextSpan`**, and **`toPlainText()` CANNOT SEE A
  TRUNCATION** — use `RenderParagraph.didExceedMaxLines`.
- **Generating a waybill on web opens a print surface.**

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
   `dispatched_by`. Where an employee record carries a fuller `first_name` +
   `last_name` — "Driver Test" — the identity chip says one thing and the
   document that governs the delivery says another. Not fixed here because the
   document should record what was stamped at the time, and changing that is a
   decision about the record, not a client tweak.

---

## 7. The project's own rules still apply

`CLAUDE.md` in this repo is the fork's copy of the shipping app's:

- **§10.4** — a `Row` hands a non-flex child unbounded width.
- **§10.5** — a green test over an empty fixture, an error state or a fallback
  font proves nothing.
- **§7** — `flutter test` renders in a fallback font unless you load the real
  ones.
- **§7.1** — one clock, Africa/Johannesburg. Confirmed again this session: the
  waybill's RECEIVED TIME read 10:10 SAST for an 08:10Z `completed_at`.
- **§10.6** — Dart bitwise operators are unsigned 32-bit on the web.
- **§1** — the package is `flutter_application_1`. Do not rename it.
- **§5** — design tokens are law.
- **§4** — *"The transporter only ever sees their resulting price."* True in
  this fork's client since 2026-08-22; see §6.1 for the server half.

---

## 8. COPY-PASTE MESSAGE FOR THE NEXT CHAT

Everything the next session needs is inside this block. Paste it whole.

```
Continue the MineLink Material 3 redesign, exactly where the last session left
off. Read these TWO handoff files before doing anything else, in this order.

1. THE CURRENT HANDOFF — THIS IS THE FILE THAT GOVERNS THE WORK:

      C:\Users\Somebody Someone\Music\SHOWME!\MineLink-M3\HANDOFF.md

   Rewritten 2026-08-22 at the end of the session that closed the load on the
   road and then found five faults by DRIVING the app rather than reading it.
   Read it in this order: "WHERE THIS SESSION STOPPED — READ THIS FIRST",
   then §0 (where you are + the one rule), §2 (verified state), §3 (what was
   done and what the drive found), §4 (what is NOT done — pick up here), §5
   (how to work here, and the things that have already gone wrong) and §6
   (three things owed to the SHIPPING app, not fixable in this fork).

2. THE OLDER MACHINE-WIDE HANDOFF — BACKGROUND ONLY, DO NOT WORK FROM IT:

      C:\Users\Somebody Someone\Claude\HANDOFF.md

   Dated 2026-08-08. MCP servers, git position, the decoy folders, the phone
   tooling. Claude Desktop reads that folder through its `claude-notes` MCP
   server. The MineLink-M3 handoff above governs this work; where the two
   disagree, the MineLink-M3 one wins.

THE PATHS THAT MATTER

  Work happens here (its own git repo, branch `main`, 131 commits, clean):
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

The tree is CLEAN. 131 commits. Nothing is half-applied and nothing is
uncommitted. The tip is the commit carrying HANDOFF.md, so the count includes
it. The last CODE commit under it is eb84e45. The six code commits of the
session are:

    9c7dbe9  one name per destination, and three routes that announced
             themselves as "Workspace"
    3daaa6f  MessagesScreen is NOT dead code, and here is the proof
    31a9c28  the phone's bottom bar showed "Dashboar / d"
    fb14950  the driver's waybill deep-link drew the portal's chrome on top of
             the driver app's own
    0acaa70  every sign-in told the reader their feeds were broken while they
             were still loading
    da91b0d  the /chat/:id URL opened the dashboard, and a failed send looked
             exactly like a sent one

The whole gate below was run green against the tree as it stands.

Green means EXACTLY this — compare against it rather than against a memory:

    flutter analyze                    no issues
    flutter test                       2229 passed, 1 skipped
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
    flutter build web --release        builds
    flutter build apk --debug          builds

  ⚠️ A raw `grep -c "LOW CONTRAST"` over a render run returns 11, all of them
  tagged [unit] — the low-contrast reporter's OWN self-tests, which paint faint
  text deliberately to prove the instrument works. Count app screens with
  `grep "LOW CONTRAST \[" out.txt | grep -vc "\[unit\]"`, which is 0.

  ⚠️ CUT OFF counts RENDERS, not strings — 5 lines carrying 9 strings. The
  previous handoff's "9" counted strings. Nothing regressed.

STILL RUNNING FROM MY SESSION:
  - `py -3 -m http.server 8123` serving build/web — verified answering 200,
    and serving a CURRENT release build. Reuse it.
  - Chrome IS running with --remote-debugging-port=9222, with five isolated
    contexts signed in (a driver and four transporter admins). Reuse or close.

WHAT I DID

Closed the load that was on the road, and then found five real faults by
driving the app across several roles. Full detail in §3 of the handoff; the
short version:

  1. THE PHONE'S BOTTOM BAR READ "Dashboar / d" — photographed on the real
     SM-G780G. The sweep that forbids exactly that was green because it tested
     text scales 1.0 and 1.3 AND NOTHING BETWEEN (the first break at 412px is
     at 1.2), and switched the rule off at 1.3. The bar now carries as many
     destinations as FIT rather than always four; nothing is abbreviated.
  2. THREE ROUTES ANNOUNCED THEMSELVES AS "Workspace", two of them on the
     transporter's accept-and-crew deep links. The rail walk could not see them
     because the rail is a menu, not the router.
  3. THE DRIVER'S WAYBILL DEEP-LINK DREW THE CHROME TWICE — two account-setup
     banners, a rail AND the driver's own bottom bar.
  4. EVERY SIGN-IN TOLD THE READER THEIR FEEDS WERE BROKEN. Seven failure
     states on the transporter's landing screen, while both RPCs were returning
     HTTP 200 with real rows. `valueOrNull` collapses "still reading" and
     "could not read"; the dashboards' own source had named that trap in August
     and it had been fixed for exactly one card.
  5. THE /chat/:id URL OPENED THE DASHBOARD, and a failed send cleared the
     composer and said nothing — three layers, none of which could report a
     failure.

Every fix has a test that was SABOTAGED until it bit, and four of the five were
re-verified on the running app.

TWO DECISIONS JEAN SETTLED — DO NOT REOPEN:
  * The eight remaining route-name pairs, by "the clearer of the two, per pair".
  * MessagesScreen: he said delete it "as long as you're only deleting dead
    code" — and it is NOT dead. It has two live, unguarded callers on the
    licence-expiry path. NOTHING WAS DELETED, and a test now pins why.

WHAT IS LEFT — START HERE

  1. A LIVE CHAT BETWEEN TWO REAL ACCOUNTS IS STILL NOT DRIVEN, and the reason
     is now measured: `type_text` over CDP reaches Flutter's controller but
     NEVER FIRES `onChanged`, so the send button's semantics node has no tap
     action (flt-tappable absent). `press_key` does fire it, but the draft does
     not survive to the next tool call. It is a TOOLING limit, not a proven app
     fault, and it is recorded as unproven rather than claimed either way.
     Ten seconds of Jean's thumb settles it — room
     24f1bef3-c3be-41c7-973c-6625e4fa3913, then check chat_messages.
  2. THE PHONE WAS NOT DRIVEN. CtrlBridge host mode went OFF mid-session when a
     call came in, and has not answered since. A CURRENT APK IS STAGED AND
     HASH-VERIFIED at \\192.168.88.30\Shared\PhoneRemote\minelink-m3.apk
     (SHA-256 B33B58B0B2DAE7C3024D02879C6FC737997A239DC2E1A6C31A1A72991DF56E3D).
     Installing it verifies the bottom-bar fix on real hardware: the console's
     bar should read Dashboard · Insights · Requests · More, four tiles, with
     no word broken in half. Jean turns it back on: CtrlBridge → Let my PC
     control this phone → Host mode on. The app there is signed in as the
     PLATFORM ADMIN and a sign-out was interrupted.
  3. A LEFTOVER FIREWALL RULE needs an ADMIN PowerShell — only Jean can run it:
       Remove-NetFirewallRule -DisplayName 'CtrlBridge APK download (TCP in)'
  4. THREE THINGS ARE OWED TO THE SHIPPING APP, not fixable in this fork
     (`supabase/` is frozen): the RLS half of the rate leak, `stockpiles`
     missing from the realtime publication, and the waybill naming a person by
     `profiles.display_name` while every other surface uses their employee
     name. All three are measured, not inferred — §6 of the handoff.
  5. WHAT A HANDSET STILL CANNOT PROVE AT A DESK — needs the phone to
     physically move: GPS fixes changing along a road, auto-reroute, the
     foreground service surviving a long backgrounding, battery over a trip.
     The EMULATOR can fake movement and already proved the nav stack that way;
     a real handset cannot be teleported, so do not try it there.

HOW TO WORK — THIS IS JEAN'S INSTRUCTION, FOLLOW IT

don't worry about me seeing anything, I'll want to see it when its all
complete and done, so don't stop so much in between please run the task for as
long as possible so that we can get this completley done and dusted, and
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

  * DRIVE IT, DON'T READ IT. All five faults were invisible to 2,229 tests and
    225 renders. Four of them needed a real sign-in; one needed the network
    throttled to Slow 3G before the window was even samplable.
  * CHECK WHETHER A "FAULT" IS THE DATA. Two things on the waybill looked
    broken and were faithful — blank seal lines on a route that requires no
    seals, and a person whose display name really is "Driver". Query the row
    before writing anything down.
  * A CHECK YOU HAVE NOT SABOTAGED IS A CHECK YOU DO NOT HAVE, and this session
    produced four fresh ways for one to be green over nothing: over fixture
    DATA (duplicate Riverpod overrides in one list are not "last wins" — nest
    the scopes), over a BLANK PAGE (no auth/company gates, empty widget tree),
    over an already-resolved future, and over a NEIGHBOUR still speaking when
    the thing under test had gone silent. Assert POSITIVE evidence of the state
    you think you are in, before asserting the absence of anything.
  * A SOURCE-READING TEST CAN MATCH ITS OWN EXPLANATION — a `contains` check
    matched the comment describing the bug it was written for. Strip comments.
  * A `Semantics` WRAPPER INSIDE AN `InkWell` CAN SWALLOW ITS TAP. Name an
    ink-well control with a `Tooltip`.
  * A HASH-ONLY NAVIGATION DOES NOT RELOAD THE DOCUMENT, so a fresh web build
    is not picked up. Reload with ignoreCache after every rebuild.
  * A CALL CAN COME IN ON THE PHONE MID-SESSION. Stop driving immediately — an
    injected tap can hang up on somebody — press home, delete the screenshot,
    and say what happened.

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

  * A POWER CUT DESTROYED A FILE MID-WRITE — it came back as 23,598 NUL bytes,
    right size, no content. Commit often; copy to the scratchpad before any
    long edit.
  * A BASH HEREDOC EATS BACKSLASHES EVEN WHEN QUOTED, and a Python string
    inside one eats them again. It bit twice more this session. WRITE ANY
    SCRIPT CONTAINING A BACKSLASH WITH THE WRITE TOOL, or use Edit directly.
  * NEVER READ A LONG TEST RUN THROUGH `tail`. Redirect to a file and grep it.
  * `git checkout -- <dir>` THREW AWAY THREE FINISHED UNCOMMITTED FIXES.
  * A LONG && CHAIN ENDING IN `git commit -F <heredoc>` TIMES OUT at two
    minutes. Write the message to a file and commit with -F as its own command.
  * PYTHON'S STDOUT IS cp1252 HERE — set PYTHONIOENCODING=utf-8.
  * A NEW TEST MUST PASS `theme: AppTheme.build(...)` TO `MaterialApp`, and if
    it uses `portalCaptureOverrides()` it MUST call `freezeCaptureClock()` —
    the guard caught this session's new sweep on the run it was written.
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
  * GENERATING A WAYBILL ON WEB OPENS A PRINT SURFACE.
  * THE DEVTOOLS MCP SERVER CAN DISCONNECT MID-SESSION, and Chrome may exit
    with it. Finish by other means rather than waiting.

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
stopped, what is already done so it is not redone, what is left, this same HOW
TO WORK instruction from Jean, and the fix-as-you-go rule — and then commit it.
State the commit count the tree WILL be at once that commit lands, and say that
the tip is the commit carrying the file, so the handoff is self-consistent
rather than a commit or two behind itself.
```
