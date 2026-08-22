# MineLink M3 — session handoff

**Rewritten 2026-08-22 (late), at the end of the session that drove the live
app as five accounts in a browser and three roles on Android, found TWELVE
defects doing it, fixed all twelve, and stopped a production database filling
up.** Everything below is verified state, not intention. It replaces the
previous handoff of the same name.

**This file lives at**
`C:\Users\Somebody Someone\Music\SHOWME!\MineLink-M3\HANDOFF.md`

The older, machine-wide handoff is at
`C:\Users\Somebody Someone\Claude\HANDOFF.md` — MCP servers, git position,
decoy folders, the phone tooling, dated 2026-08-08. **Background only; this
file governs the redesign work.**

---

## WHERE THIS SESSION STOPPED — READ THIS FIRST

The tree is **clean**, **157 commits**, nothing half-applied and nothing
uncommitted. **The tip is the commit that carries THIS FILE**, so the count
above includes it. The last code commit under it is `1ffa3d2`.

**The original worktree was re-checked against its §0 baseline and is
untouched** — HEAD `df451d0`, the same three pre-existing modified files,
14163 files under the `-prune` form, two worktree entries, nothing modified
today.

### 🚨 EXACTLY WHERE IT STOPPED, AND WHAT TO DO FIRST

The APK built at commit `1ffa3d2` (SHA-256 `EEE10B20DBF82BBCD26905D8182E335055A2CEA864697E74C543429063879A24`)
**is installed on Jean's SM-G780G and has NOT been driven yet.** The install
completed ("MineLink M3 — App installed"), the dialog was dismissed, and the
phone was left on `home`, signed in as the platform admin, with every
screenshot deleted.

**So the very first job in the next session is the hardware verification that
was interrupted.** Three things, all on that already-installed build:

1. **The sign-out dialog copy.** Tap the profile → Sign out. It must read
   **"Sign out" / "Are you sure you want to sign out?" / [Cancel] [Sign out]**.
   Before commit `3daf897` it read "Logout Confirmation / …log out? / Yes,
   Logout". **Tap Cancel** — do not actually sign him out, the phone should be
   left signed in as the platform admin.
2. **No new `Duplicate GlobalKey` crash reports.** Take a baseline, navigate
   six or seven screens, re-count. The method and the SQL are in §5.
3. **The driver's week chart** (`6c8a4e0`) — this one needs the driver
   account, so it is fine to verify on the EMULATOR instead rather than
   signing Jean's phone out. See §4.1.

Everything else in this session is committed, tested, sabotaged and green.

### What this session did, in one paragraph

It did not build features. It **drove the finished app** — as the platform
admin, a mine owner, a buyer and a transporter in a browser, and as a driver
and a security guard on Android — and wrote down what was actually wrong on
the screen. Twelve defects came out of that, and **not one of them came from
the test suite**: they are screens being *wrong*, not screens being *broken*,
and 2,398 tests, 40 guards and 225 renders all coexisted with every one.

---

## 0. Where you are

| | |
|---|---|
| **This project** | `C:\Users\Somebody Someone\Music\SHOWME!\MineLink-M3` |
| What it is | A **complete, independent fork** of MineLink, redesigned onto Material 3. Its own git repo (`main`), **157 commits**, clean tree. |
| **The original** | `C:\Users\Somebody Someone\Music\SHOWME!\worktree-2026-05-05T11-53-29` — **DO NOT TOUCH IT.** |

### The one rule that must not be broken

**Nothing whatsoever changes inside `worktree-2026-05-05T11-53-29`.** Its
verified baseline, re-checked at the start and end of every session:

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

⚠️ **The file count depends on which `find` you use.** `find . -type f -not
-path "./.git/*"` returns **14164** because in a WORKTREE `.git` is a *file*,
not a directory. The `-prune` form returns **14163**. Same untouched tree.

Reading that tree is fine and often necessary. Writing to it, or running any
git command inside it, is not.

---

## 1. The brief, and the standing instructions

> Redesign the app for all versions — mobile, web and Windows. Put it in a new
> folder outside the app root so I can see how everything looks and test it
> properly before deciding if I like it. Nothing whatsoever changes inside
> `worktree-2026-05-05T11-53-29`. The UI/UX for all of it should follow the
> super global admin's portal — the placement of everything and so on. Use all
> the latest and best Material Design 3.

Still standing:

- **Windows is optional** — two pre-existing faults, neither this project's.
- **Work long, don't stop to check in.** §8, quoted verbatim.
- **Fix what you find, as you go, and prove the fix.** §8.
- **The chat is the dock.**
- **The sidebar and its groups start collapsed, everywhere.**
- **Everything in the sidebar has a parent — except the Dashboard, which is
  first and has none.**
- **If the phone does not answer, STOP and ask.** §5. Exercised twice this
  session; both times Jean fixed it within minutes.

**`supabase/` is frozen.** Things needing a migration are REPORTED — §6.

---

## 2. Verified state, right now

```
flutter analyze                                 no issues
flutter test                                    2440 passed, 1 skipped
dart tool/release_guards.dart                   41/41 PASS, 0 FAIL
dart tool/release_guards.dart --selftest        all guards bite
py -3 tool/_sabotage.py                         ALL SABOTAGES CAUGHT
py -3 tool/type_scale_codemod.py --selftest     OK
py -3 tool/dropdown_width_check.py              passes
py -3 tool/glyph_coverage_check.py              passes
py -3 tool/one_clock_check.py                   0 sites, exit 0
py -3 tool/unphotographed_screens.py            94 targets, 94 photographed, 0 not
py -3 tool/health_probe.py                      7/7 services answering
flutter build web --release                     builds
flutter build apk --debug                       builds
docs/redesign/renders/                          227 renders
render harness — RENDER NOTE / FAILURE STATE    0 / 0
render harness — LOW CONTRAST                   0 (app screens; see below)
render harness — CUT OFF                        5 renders / 9 strings, deliberate
"Duplicate GlobalKey" in a test run             0
APK ON JEAN'S SM-G780G                          INSTALLED (1ffa3d2), NOT yet driven
```

Test count **2398 → 2440**. Guards **40 → 41**. Renders **225 → 227**.
`one_clock_check.py` went from **3 patterns to 5**.

⚠️ **`CUT OFF` counts RENDERS, not strings** — 5 lines, 9 strings, unchanged.

⚠️ **LOW CONTRAST is 0 for app screens.** A raw `grep -c "LOW CONTRAST"` over a
full run returns **11**, all tagged `[unit]` — the reporter's own self-test.
Count `grep "LOW CONTRAST \[" out.txt | grep -vc "\[unit\]"`.

---

## 3. What this session did — DO NOT REDO ANY OF IT

Twelve defects, all found by driving. **Read the commit messages** — they are
long and they are the real record.

### 3.1 The disputes header said one over an empty list — `3179c1b`

Console read **"1 dispute"** above **"No open disputes"**. `meta:` counted the
whole list; the body counted the ACTIVE subset; the platform's only dispute is
resolved. Fixed with `visibleDisputes(...)`, read by both, and the header now
names which count it gives.

### 3.2 🚨 THE CRASH REPORTER COULD FILL THE DATABASE IT REPORTS INTO — `c846b15`

`/super-admin/crash-reports` would not load. **204,539 rows / 293 MB**, main
project **24 MB → 319 MB, 64% of a 500 MB FREE plan**, peak **60,680 rows in
one hour**. Three browser tabs left signed in overnight — from the previous
session's own multi-account technique — hit a CanvasKit `Aborted()` during
paint and re-threw it every frame for four hours.

Dedup could not bound it: a fold only happens while the row is STILL QUEUED, so
online each flush round-trip starts a fresh row. Fixed with a budget on rows
LEAVING the device — **20/minute, 500/session** — with refused occurrences
carried out as `(+N not sent)`.

**Space reclaimed: 319 MB → 40 MB**, keeping every row outside the burst
(4,539) plus three examples of each of the 875 distinct failures. Staged +
`TRUNCATE` + re-insert in one transaction, because a 197k-row DELETE is the
shape that wedged this instance in August.

### 3.3 / 3.4 The Duplicate GlobalKey fault — `ca0a835`, `f0bf845`, `6d95c68`

**Three passes, and each looked finished until the APK went back on the phone.**

| build | navigations | reports |
|---|---|---|
| before | — | 32 recorded |
| after the recorder key removal | startup | 1 |
| after keying the switcher on the route | 7 | **7** |
| after removing the cross-fade | 6 | **0** |

Causes, in order: both shells re-keyed by route (remount per navigation, and it
made `didUpdateWidget` dead code); `_Workspace` keying its `AnimatedSwitcher`
on `child.hashCode` (a new key on ANY shell rebuild, which also threw away the
page's State); and finally the structural one —

> **An `AnimatedSwitcher` cannot wrap a subtree that holds a GlobalKey.** It
> mounts the outgoing and incoming subtrees TOGETHER while it cross-fades, and
> under a go_router `ShellRoute` both hold the same navigator.

`_Workspace` is stateful now and fades ONE subtree. M3's fade-through is
sequential anyway, so this is closer to spec.

⚠️ **A widget test cannot see the third one** — `MlMotion` collapses to ~1ms
under the test binding. The test file says so rather than implying coverage.

⚠️ **One change was thrown away for lack of evidence**: making
`MlAppShell.build`'s body `Row` unconditional. Sabotage showed it was not
load-bearing and it would have altered a carefully-measured compact-height
constraint.

### 3.5 The stockpile tile lost 60 t between its figure and its caption — `6afee34`

**210.3 t** over **"150.3 of 1240 t ordered · 12%"**. A pile with a NULL cap
(60.0 t) was dropped from both sides of the ratio silently. `StockpileCover`
now names the remainder so the arithmetic closes on screen.
**The fixture was worse and had been photographed 227 times a run.**

### 3.6 A mine was told its pit-to-port loss was −771 t, in green — `93fc99f`

`0.00 t Mined · 771.32 t Dispatched · — Yield · **-771.32 t Pit-to-port loss**`,
and the tone was `loss > 0 ? warn : done`, so it was GREEN. Both figures come
from `ProductionYield` now, with one notion of whether the window is
measurable at all.

### 3.7 The not-found page was go_router's — `20262b1`

`GoException: no routes for location: …` shown to users, with no design system
on it. ⚠️ **The `no-raw-exception-in-ui` guard could never have caught it** —
the string is interpolated inside the package and the guard greps `lib/`.
`RouteNotFoundScreen` replaces it; its action resolves the user's real landing
route (verified live: a buyer lands on `/portal/buyer`, not `/`). Two renders
added — `unphotographed_screens.py` walks route targets and a page reached by
NOT matching a route is not one.

### 3.8 Every truck was in the wrong bucket on Fleet Management — `3487ad2`

```
dashboard          2 on route of 3 · 67%
Trucks On Route    On Route 2 · Available 1
Fleet Management   On Trip 1 · Available 2      <- wrong, and INVERTED
```
The counters read `hasAssignedDriver` under an "On Trip" label. The two trucks
carrying loads have no driver row, so they were reported **Available to
allocate** — the number a transporter dispatches from. Now reads
`list_transporter_fleet_status`, the same derived source the other two use.

### 3.9 The driver's week chart drew tonnage on a day that had not happened — `6c8a4e0`

Found on the emulator on a **Saturday**; the chart had a bar on **Sunday**.
`byDay[t.updatedAt.weekday - 1]` read the **UTC** weekday while `inWeek` and
`inPrevWeek` on the lines either side correctly used `MlTime.sast`. A load
delivered **01:29 Monday SAST = 23:29 Sunday UTC** put 33.7 t on tomorrow.

**The week TOTAL was right to the kilogram** (136.3 t, agreeing with the card
above), so only the distribution was wrong — nothing to notice unless you read
the bars and knew what day it was. Extracted to `tonsByWeekday`. Sabotage
reproduces the exact on-screen bars `[68.4, 0, 0, 0, 0, 34.2, 33.7]`.

Also fixed: `employee_profile_screen`'s "since {Month} {Year}" read
`e.createdAt.month` off a raw instant.

### 3.10 Every "Sign out" button opened a dialog that said "Logout" — `3daf897`

`LogoutService` has **TEN call sites**, every one labelled "Sign out", and the
dialog they all open read "Logout Confirmation / …log out? / Yes, Logout".
Two more dialogs titled "Confirm Logout" turned up once there was something
looking. New guard `one-vocabulary-for-signing-out`, third in that family.
Writing it found four developer-log strings too; rewording them left a rule
with **no exceptions**.

### 3.11 "Departed Today" asked the device what day it is — `1ffa3d2`

```dart
final now = DateTime.now();                    // the DEVICE
final d   = MlTime.sast(t.updatedAt);          // the pit
return d.year == now.year && d.month == now.month && d.day == now.day;
```
The mirror image of 3.9. Right on a SAST phone — **which is why the emulator,
set to Africa/Johannesburg, showed a plausible 2** — and wrong on any other
device, by a whole day between midnight and 02:00 SAST. Also fixed a
date-range picker built from `DateTime.now().year`.

### 3.12 The instrument grew two patterns

`one_clock_check.py` had three patterns and passed this tree cleanly while
**four** real faults were live. It has five now:

4. `someAt.weekday` — a calendar field off a raw UTC instant. Scoped to
   receivers ending in `At`; `tripDate` and friends are already
   `MlTime.sast(...)` at parse and are deliberately not matched.
5. `DateTime.now()` bound to a local whose `.year`/`.month`/`.day`/`.weekday`
   is read within 60 lines — a day decision on the device clock.

Both have self-test cases that BITE plus negative cases that stay clean.

---

## 4. What is NOT done — PICK UP HERE

### 4.1 🚨 FIRST: the interrupted hardware verification

See "EXACTLY WHERE IT STOPPED" at the top. The build is already installed on
the handset. Verify the sign-out copy (then **Cancel**), and confirm no new
`Duplicate GlobalKey` rows after navigating. Verify the driver week chart on
the **emulator** (`emulator-5554`, already has the driver account) so Jean's
phone stays signed in as the platform admin.

### 4.2 Roles the driving sweep has NOT reached

Driven so far: the whole console; the mine, buyer and transporter dashboards
plus their main sub-screens; the DRIVER (dashboard, trip, profile) and
SECURITY (gate) on Android.

**Not yet driven, and this is where to continue:**

- **Load Controller** (`ironhills.controller@mineralguide.com`) — the
  weighbridge, tare/gross capture, seal counts, waybill generation. This is
  the densest arithmetic in the product and has never been driven this way.
- **Supervisor / Foreman** (`ironhills.management@mineralguide.com` or the
  owner) — stockpiles, production, "Add tons".
- **Company & employee management** — the register, role assignment, seats.
- The **buyer's Loads & value** and **quality** tabs, and the **mine's
  Quality** tab, at screen level rather than dashboard level.

That method found twelve things in one pass; there is no reason to think it is
exhausted.

### 4.3 What a handset still cannot prove at a desk

GPS fixes changing along a road over distance, auto-reroute on going
off-route, the Android foreground service surviving a long backgrounding, and
battery over a real trip. The EMULATOR can fake movement (`adb emu geo fix`)
and the 2026-07-17 run already proved the nav stack that way. **The handset is
NOT on adb** — it is reachable only through CtrlBridge.

### 4.4 One elevated-shell item for Jean

```powershell
Remove-NetFirewallRule -DisplayName 'CtrlBridge APK download (TCP in)'
```
A leftover from a much earlier session. Nothing listens on 8000 and the NAS
route makes it unnecessary.

### 4.5 One judgement call Jean may want to reverse

**The dock is not mounted on `/chat/:id`** — it was covering 61% of the send
button. If it should stay, the fix has to become geometric.

### 4.6 Closed, do not redo

- A live chat between two real accounts is DRIVEN (earlier session).
- Contrast is closed app-wide AND for chat. `low_contrast_baseline.json` is
  `{}` — a FLOOR, not a ratchet. **If it fails, change the token; do NOT add a
  baseline entry.**
- All eighteen chat palettes are covered by arithmetic.
- All twelve route names are settled.
- MessagesScreen is NOT dead code — two live callers on the licence-expiry
  path.
- The due-diligence gate and the driver's whole mobile lifecycle were driven
  end to end; the load on the road is closed (trip `927cbf1b`, 34.05 t against
  a 34.20 t mine net).
- The 20 themeless test files are converted and guarded.

---

## 5. How to work in this repo

```bash
cd "/c/Users/Somebody Someone/Music/SHOWME!/MineLink-M3"

flutter analyze                                  # must be clean
flutter test                                     # 2440 passing, 1 skipped
dart tool/release_guards.dart                    # 41/41
dart tool/release_guards.dart --selftest         # every guard must BITE
py -3 tool/_sabotage.py                          # every instrument must BITE
py -3 tool/type_scale_codemod.py --selftest
py -3 tool/dropdown_width_check.py
py -3 tool/glyph_coverage_check.py
py -3 tool/one_clock_check.py                    # 0 sites, exit 0
py -3 tool/unphotographed_screens.py
py -3 tool/health_probe.py                       # 7/7
flutter test test/renders --update-goldens       # after any visual change
flutter build web --release
flutter build apk --debug
```

### What "sabotage" means here

Copy the file to `/tmp`, change **one line** back to the buggy version, run the
test, confirm it **FAILS**, restore, re-run, confirm green. A green test proves
nothing on its own. It only ever touches local Dart source; never the database,
the phone, or the original worktree, and it is never committed.

**It also tells you when a fix is NOT needed** — §3.4's Row change was reverted
because sabotaging it showed the tests stayed green without it.

### Driving the app on ANDROID (emulator) — the fastest surface

The browser MCP dropped mid-session; the emulator replaced it and found four
defects. `emulator-5554` is running, `adb` is at `C:\Android\sdk\platform-tools`.

```bash
export PATH="$PATH:/c/Android/sdk/platform-tools"
adb -s emulator-5554 install -r -d build/app/outputs/flutter-apk/app-debug.apk
adb -s emulator-5554 shell monkey -p org.minelink.m3 -c android.intent.category.LAUNCHER 1
adb -s emulator-5554 exec-out screencap -p > shot.png     # then Read the png
adb -s emulator-5554 shell input tap <x> <y>              # REAL pixels, 1080x2400
adb -s emulator-5554 shell input text 'someone@example.com'
adb -s emulator-5554 shell input keyevent KEYCODE_BACK    # hides the keyboard
```

⚠️ **A Read of a screenshot reports "displayed at 900x2000, multiply by 1.20"**
— the tap coordinates must be the REAL 1080x2400 ones, so multiply what you
measure off the image.

⚠️ **The emulator is set to Africa/Johannesburg**, which is exactly why §3.11
looked correct on it. A clock fault that only bites off-SAST will NOT show
here — reason about it, do not just look.

### Driving the app in a BROWSER

```bash
flutter build web --release        # config/supabase.live.json is bundled, so
                                   # a plain build reaches LIVE
cd build/web && py -3 -m http.server 8123 --bind 127.0.0.1
"/c/Program Files/Google/Chrome/Application/chrome.exe" \
  --remote-debugging-port=9222 --user-data-dir="<scratch>/ml-m3-chrome-$(date +%H%M%S)" \
  --no-first-run --no-default-browser-check "http://127.0.0.1:8123/"
```

- 🚨 **CLOSE EVERY BROWSER YOU SIGN IN WITH, BEFORE YOU FINISH.** §3.2.
- 🚨 **A SECOND CHROME CANNOT HAVE THE SAME `--remote-debugging-port`, AND IT
  FAILS SILENTLY** — you get the OLD browser, its profile and its stale bundle.
  Confirm the owner:
  ```powershell
  Get-NetTCPConnection -LocalPort 9222 -State Listen |
    ForEach-Object { (Get-CimInstance Win32_Process -Filter "ProcessId=$($_.OwningProcess)").CommandLine }
  ```
- 🚨 **`ignoreCache` IS NOT ENOUGH EITHER.** `transferSize` 0 means cache;
  compare `decodedBodySize` against the built file's byte count.
- ⚠️ **READ SEMANTICS LEAVES BY DESCENDANT, not `children.length === 0`** —
  Flutter puts label text in a `<span>` CHILD, so the old recipe silently drops
  whole empty states:
  ```js
  [...document.querySelectorAll('flt-semantics')]
    .filter(e => !e.querySelector('flt-semantics'))
    .map(e => (e.getAttribute('aria-label') || e.textContent || '').trim())
    .filter(Boolean)
  ```
- Click `flt-semantics-placeholder` after EVERY reload to publish the tree.
- ⚠️ Some screens need **more than 3.5s** to swap; 5s is safer.
- ⚠️ The setup gate re-fires on reloads. Dismiss with "Later" — a JS `.click()`
  on the node does NOT work; use a real pointer event.

### Driving Jean's real phone

**Invoke the `driving-jeans-phone` skill FIRST.**

🚨 **IF THE PHONE DOES NOT ANSWER, STOP AND ASK — DO NOT WORK AROUND IT.**
`status` saying `no phone at a known address - broadcasting`, or `probe` under
0.1 bits/pixel (display asleep), means pause and say so. Only Jean can enable
host mode or wake the screen. **Both happened this session and he fixed each
within minutes — so ASK EARLY rather than idling.**

⚠️ **Host mode staying on does NOT mean the screen is awake.** The second time,
`status` was `sharing=True control=True` and `probe` was 0.061 bits/pixel — the
screen had slept on its timer. Check `probe`, not just `status`.

Install route (three times this session, ~6 min each):

```
1. flutter build apk --debug
2. copy build/app/outputs/flutter-apk/app-debug.apk ->
     \\192.168.88.30\Shared\PhoneRemote\minelink-m3.apk   (hash-match both ends)
3. My Files -> Network storage -> jean -> Shared -> PhoneRemote ->
   minelink-m3.apk -> ~2.5 min -> Update -> Open
```

🚨 **THE NAS CLOCK IS ~2 h 36 m SLOW — compare the SHA-256, not timestamps.**

⚠️ **My Files CACHES the folder listing, and it bit every single time.** Back
out to `Shared` and re-enter `PhoneRemote`, then check the TIMESTAMP moved.
**The size is useless** — every build rounds to 207 MB.

⚠️ **`home` often drops the link and IS NOT RETRIED**, so a batch beginning
`home; …` can run its remaining steps inside the app you meant to leave. Send
`home` as its own invocation. Long batches drift generally — prefer short ones
and re-shoot.

⚠️ **The applicationId is `org.minelink.m3`**, deliberately different from the
shipping app's. They install side by side.

It is his **personal** phone: prefer `sig`/`changed`/`waitstable` over `shot`,
**delete every screenshot immediately**, do not read what you did not come for,
back out of anything opened by mistake and say so, and leave it on
`home; waitstable; home`. Two screens showed his personal content in passing
this session (WhatsApp media in My Files' recents, and his home screen);
neither was read beyond recognising it, and both shots were deleted.

⚠️ **Battery was at 23–26% and falling when the session ended.** Worth a word
to Jean before a long drive.

🚨 **Turning on live-location sharing writes JEAN'S REAL POSITION** to
`vehicle_positions` every 30 s. Never switched on this session.

### Counting crash reports (the hardware instrument)

```sql
select count(*) filter (where platform='android' and error like 'Duplicate GlobalKey%') as gk,
       max(at) filter (where platform='android') as last, now()
from public.crash_reports;
```
Take a baseline, drive, re-count against `at > <baseline>`.

### Live accounts

`active user accounts.txt` in the repo root. `jean@cyberhouse.co.za` /
`BuRG3rJ3@n1995@#` is the platform admin; everything `@mineralguide.com` is
`MineralGuide123!`.

⚠️ **The console stores theme and accent PER ADMIN.** Put it back if you
change it.

### Things that have already gone wrong here — do not repeat them

- 🚨 **Browsers left signed in overnight filled a production database.** §3.2.
- 🚨 **A second Chrome on a taken debug port silently gives you the old one.**
- 🚨 **A stale cached bundle looks exactly like a silent failure.**
- 🚨 **The handset found what three instruments could not, twice.** When a fault
  is reported from hardware, re-install and re-check ON HARDWARE. Do not close
  it on a green suite.
- 🚨 **Check whether a "fault" is the DATA.** A truck labelled `fa243ad` on the
  live map is a real registration somebody typed, not an id leaking.
- 🚨 **A power cut destroyed a file mid-write.** Commit often.
- 🚨 **A bash heredoc eats backslashes even when quoted.** It produced a literal
  NUL byte inside a Dart file this session. **Write any patch script with the
  Write tool and run it with `py -3`.**
- 🚨 **A regex qualifying bare identifiers will eat named arguments** —
  `child` became `widget.child:`. Exclude a following colon.
- 🚨 **`dart format` reflows lines you did not touch** and can expose a
  pre-existing lint (it did: `curly_braces_in_flow_control_structures`). Run
  `flutter analyze` on the file after formatting it.
- 🚨 **A sabotage must COMPILE to prove anything.**
- 🚨 **Real file I/O inside `testWidgets` never completes** — use a plain `test`
  and `readAsStringSync`.
- 🚨 **A pipe hides a failing exit code.** `py x.py | tail` reports `tail`'s
  status. Redirect, then check `$?`.
- 🚨 **Never read a long test run through `tail`.** Redirect and grep.
- 🚨 **`git checkout -- <dir>` threw away uncommitted work.**
- 🚨 **A long `&&` chain ending in `git commit -F <heredoc>` times out.**
- 🚨 **Python's stdout is cp1252 here.** Set `PYTHONIOENCODING=utf-8`.
- 🚨 **A guard over your own source is blind to a dependency's default.** §3.7.
- **A render proves a screen DREW, not that what it drew ADDS UP.** §3.5 was
  photographed 227 times a run for weeks.
- **`find.text` cannot see a `TextSpan`**, and a status chip draws UPPERCASE
  where the semantics label is mixed case.
- **An `InkWell` with only `onLongPress` still steals the TAP.**
- **`Flexible` defaults to `flex: 1`**, and a `Wrap` sizes to its content.
- **A `RepaintBoundary` inside a `Scaffold` does not capture a DIALOG.**
- **Two long-running `pwsh` processes are Jean's VS Code terminals**, and his
  personal Chrome runs under `AppData\Local\Google\Chrome\User Data` — never
  sweep those up when closing Claude-owned browsers.

### Where the reasoning lives

- `docs/redesign/DESIGN.md` — decisions and what each cost.
- `docs/redesign/VERIFICATION.md` — what was executed, and what has not been.
- `docs/design-reference/` — the **pre-redesign** reference PNGs. Do not
  regenerate them.
- `docs/redesign/renders/` — 227 PNGs.
- Every commit message carries its own reasoning.

---

## 6. For the SHIPPING app, not this fork

`supabase/` is frozen here, so these are reported. All measured, not inferred.

1. **The transporter can read the buyer's rate, server-side.** As the Roadhaul
   admin's own JWT under RLS, `select rate from transportation_requests`
   returns `"950"`. The Dart half is fixed here; the policy is the shipping
   app's to tighten.
2. **`stockpiles` is not in the realtime publication**, so the "live fill" is
   live-on-load only.
   `alter publication supabase_realtime add table public.stockpiles;`
3. **The waybill names a person by `profiles.display_name`**, unlike every
   other surface.
4. **NOTHING SERVER-SIDE RATE-LIMITS AN INSERT INTO `crash_reports`.** §3.2
   fixed the client, and the client is the only thing between one looping
   browser and the 500 MB ceiling. The SHIPPING app shares this database and
   can still do it.
5. **`prune_telemetry_job()` runs at 90 days** — far too slow to defend against
   a burst that reached 293 MB in four hours.

---

## 7. The project's own rules still apply

`CLAUDE.md` in this repo is the fork's copy of the shipping app's. Especially:

- **§1** — LEAVE THE DATABASE HEALTHY. Exercised in earnest this session:
  prove it with a probe, not a status field; throttle bulk work.
- **§7.1** — one clock, Africa/Johannesburg. **Three of this session's twelve
  defects were §7.1 violations that the checker could not see.**
- **§10.2** — two Supabase projects, both production, both free plan; the MCP
  only reaches one.
- **§10.4 / §10.5 / §7** — layout traps, and a green test over an empty fixture
  or a fallback font proves nothing.
- **§10.6** — Dart bitwise operators are unsigned 32-bit on the web.
- **§1** — the package is `flutter_application_1`. Do not rename it.
- **§5** — design tokens are law.

---

## 8. COPY-PASTE MESSAGE FOR THE NEXT CHAT

Everything the next session needs is inside this block. Paste it whole.

---

Continue the MineLink Material 3 redesign, exactly where the last session left
off. Read these TWO handoff files before doing anything else, in this order.

1. THE CURRENT HANDOFF — THIS IS THE FILE THAT GOVERNS THE WORK:

      C:\Users\Somebody Someone\Music\SHOWME!\MineLink-M3\HANDOFF.md

   Rewritten 2026-08-22 (late) at the end of the session that DROVE the
   finished app as five accounts in a browser and three roles on Android,
   found TWELVE defects doing it, fixed all twelve, and stopped a production
   database filling up. Read it in this order: "WHERE THIS SESSION STOPPED —
   READ THIS FIRST" (including "EXACTLY WHERE IT STOPPED, AND WHAT TO DO
   FIRST"), then §0 (where you are + the one rule), §2 (verified state), §3
   (what was done — §3.1 to §3.12, and DO NOT REDO ANY OF IT), §4 (what is NOT
   done — start at §4.1, then §4.2), §5 (how to work here, and everything that
   has already gone wrong) and §6 (five things owed to the SHIPPING app).

2. THE OLDER MACHINE-WIDE HANDOFF — BACKGROUND ONLY, DO NOT WORK FROM IT:

      C:\Users\Somebody Someone\Claude\HANDOFF.md

   Dated 2026-08-08. MCP servers, git position, the decoy folders, the phone
   tooling. The MineLink-M3 handoff above governs this work; where the two
   disagree, the MineLink-M3 one wins.

THE PATHS THAT MATTER

  Work happens here (its own git repo, branch `main`, 157 commits, clean):
    C:\Users\Somebody Someone\Music\SHOWME!\MineLink-M3

  NEVER TOUCHED, for any reason:
    C:\Users\Somebody Someone\Music\SHOWME!\worktree-2026-05-05T11-53-29

THE ONE RULE THAT MUST NOT BREAK: nothing whatsoever changes inside
worktree-2026-05-05T11-53-29. CHECK IT AT THE START OF THE SESSION AND AGAIN AT
THE END:

    HEAD              df451d0
    git status        exactly 3 modified files, all pre-existing:
                        M .design-sync/config.json
                        M lib/features/super_admin/screens/margin_ledger_screen.dart
                        M test/widgets/app_sidebar_behaviour_test.dart
    file count        14163   (find . -path ./.git -prune -o -type f -print | wc -l)
    git worktree list exactly 2 entries — the main repo and that worktree
    modified today    0

  ⚠️ The count depends on which `find` you run. `find . -type f -not -path
  "./.git/*"` returns 14164, because in a WORKTREE `.git` is a FILE, not a
  directory. The `-prune` form returns 14163. Same untouched tree. Reading that
  tree is fine and often necessary; writing to it, or running any git command
  inside it, is not.

🚨 START HERE — THE EXACT POINT IT STOPPED

The APK built at commit 1ffa3d2 (SHA-256
EEE10B20DBF82BBCD26905D8182E335055A2CEA864697E74C543429063879A24) IS ALREADY
INSTALLED on Jean's SM-G780G and HAS NOT BEEN DRIVEN. The install completed
("MineLink M3 — App installed"), the dialog was dismissed, the phone was left
on home signed in as the platform admin, and every screenshot was deleted.

Your first job is the hardware verification that was interrupted:

  1. Tap through to the profile and press Sign out. The dialog must read
     "Sign out" / "Are you sure you want to sign out?" / [Cancel] [Sign out].
     Before commit 3daf897 it read "Logout Confirmation / …log out? / Yes,
     Logout". THEN TAP CANCEL — do not sign him out; the phone must be left
     signed in as the platform admin, as it was found.
  2. Take a crash_reports baseline, navigate six or seven screens, and confirm
     ZERO new "Duplicate GlobalKey" rows. The SQL is in §5. The build before
     this one produced 7 reports in 7 navigations; the fix produced 0 in 6.
  3. The driver's week chart (commit 6c8a4e0) needs the driver account, so
     verify that on the EMULATOR instead — emulator-5554 is running and already
     has the driver signed in. Do not sign Jean's phone out for it.

Then continue with §4.2 — the roles the sweep has not reached.

VERIFIED STATE (all run at the end, against the tree as it stands)

    flutter analyze                        no issues
    flutter test                           2440 passed, 1 skipped
    dart tool/release_guards.dart          41/41 PASS, 0 FAIL
    dart tool/release_guards.dart --selftest   all guards bite
    py -3 tool/_sabotage.py                ALL SABOTAGES CAUGHT
    py -3 tool/type_scale_codemod.py --selftest  OK
    py -3 tool/dropdown_width_check.py     passes
    py -3 tool/glyph_coverage_check.py     passes
    py -3 tool/one_clock_check.py          0 sites, exit 0
    py -3 tool/unphotographed_screens.py   94 targets, 94 photographed, 0 not
    py -3 tool/health_probe.py             7/7 services answering
    docs/redesign/renders/                 227 renders
    render harness — RENDER NOTE           0   (and it FAILS the test)
    render harness — FAILURE STATE         0
    render harness — LOW CONTRAST          0   (see the [unit] caveat below)
    render harness — CUT OFF               5 RENDERS / 9 strings, all deliberate
    "Duplicate GlobalKey" in a test run    0
    flutter build web --release            builds
    flutter build apk --debug              builds, and is INSTALLED on the phone

  ⚠️ A raw `grep -c "LOW CONTRAST"` over a full test/renders run returns 11,
  all tagged [unit] — the reporter's OWN self-tests, which paint faint text
  deliberately. Count app screens with
  `grep "LOW CONTRAST \[" out.txt | grep -vc "\[unit\]"`, which is 0.

🚨 THE ONE THING TO READ EVEN IF YOU READ NOTHING ELSE

A PRODUCTION DATABASE WAS 64% FULL OF CRASH REPORTS ABOUT ONE BUG. Three
browser tabs left signed in overnight — by the previous session's own
multi-account driving technique — hit a CanvasKit Aborted() during paint and
re-threw it every frame for four hours: 204,539 rows, 293 MB, peak 60,680 rows
in ONE HOUR, taking the main project from 24 MB to 319 MB of a 500 MB FREE
plan. It is fixed at the source (a send budget in SupabaseReportingSink: 20
rows/minute, 500/session) and the space is reclaimed (319 MB -> 40 MB). BUT THE
CAUSE WAS THE WORKING METHOD, so: CLOSE EVERY BROWSER YOU SIGN IN WITH, BEFORE
YOU FINISH.

WHAT IS ALREADY DONE — DO NOT REDO ANY OF THIS

Twelve defects, every one found by DRIVING the app rather than by a test, every
one fixed with a test or a guard that was SABOTAGED and watched to fail before
being kept.

  1. DISPUTES read "1 dispute" directly above "No open disputes".
  2. THE CRASH REPORTER could fill the database it reports into — above.
  3. BOTH SHELLS were re-keyed by route, remounting on every navigation.
  4. …AND THAT WAS HALF A FIX, TWICE. Second cause: _Workspace keyed its
     AnimatedSwitcher on child.hashCode, so ANY shell rebuild minted a new key
     and threw away the page's State. Third and real cause: AN AnimatedSwitcher
     CANNOT WRAP A SUBTREE THAT HOLDS A GlobalKey — it mounts both subtrees at
     once and under a ShellRoute both hold the same navigator. It fades ONE
     subtree now. 7 navigations/7 reports became 6 navigations/0 on hardware.
  5. THE MINE STOCKPILE TILE read 210.3 t over "150.3 of 1240 t ordered" —
     60 t lost between a figure and its own caption.
  6. MINE PRODUCTION told a mine its pit-to-port loss was MINUS 771 TONS, in
     GREEN, with 0.00 t mined.
  7. THE NOT-FOUND PAGE was go_router's default, printing "GoException: no
     routes for location: …" with no design system on it.
  8. FLEET MANAGEMENT had EVERY TRUCK IN THE WRONG BUCKET, exactly inverted —
     the two carrying loads showed as "Available to allocate".
  9. THE DRIVER'S WEEK CHART drew 33.7 t on a Sunday that had not happened yet
     (UTC weekday vs SAST), while the week TOTAL was right to the kilogram.
 10. EVERY "Sign out" BUTTON opened a dialog that said "Logout" — ten call
     sites, plus two more dialogs titled "Confirm Logout".
 11. "DEPARTED TODAY" on the security gate asked the DEVICE what day it is.
 12. THE INSTRUMENT GREW TWO PATTERNS: one_clock_check.py had three and passed
     cleanly while four real faults were live. It has five now.
 13. ONE CHANGE WAS THROWN AWAY for lack of evidence — making MlAppShell's body
     Row unconditional. Sabotage showed it was not load-bearing.

ALSO SETTLED EARLIER — DO NOT REOPEN: a live chat between two real accounts is
driven; all twelve route names are settled; MessagesScreen is NOT dead code;
contrast is closed app-wide and for chat (the baseline file is a FLOOR, not a
ratchet — if it fails, change the token, do NOT add a baseline entry); the
due-diligence gate and the driver's whole mobile lifecycle were driven end to
end; the load on the road is closed (trip 927cbf1b, 34.05 t delivered against a
34.20 t mine net); the 20 themeless test files are converted and guarded.

WHAT IS LEFT

  1. THE INTERRUPTED HARDWARE VERIFICATION — the three items under START HERE.
  2. THE ROLES THE SWEEP HAS NOT REACHED (§4.2). Driven so far: the whole
     console; the mine, buyer and transporter dashboards plus their main
     sub-screens; the DRIVER and SECURITY roles on Android. NOT yet driven:
       * Load Controller (ironhills.controller@mineralguide.com) — the
         weighbridge, tare/gross, seal counts, waybill generation. The densest
         arithmetic in the product and never driven this way.
       * Supervisor / Foreman — stockpiles, production, "Add tons".
       * Company & employee management — register, roles, seats.
       * The buyer's Loads & value and quality tabs, and the mine's Quality
         tab, at screen level rather than dashboard level.
     That method found twelve things in one pass. It is not exhausted.
  3. WHAT A HANDSET CANNOT PROVE AT A DESK: GPS along a real road, auto-reroute,
     the foreground service surviving a long backgrounding, battery over a trip.
     The EMULATOR can fake movement (adb emu geo fix); a real handset cannot be
     teleported. The handset is NOT on adb — CtrlBridge only.
  4. FIVE THINGS OWED TO THE SHIPPING APP (§6), not fixable here because
     supabase/ is frozen: the RLS half of the rate leak; stockpiles missing
     from the realtime publication; the waybill naming a person by
     profiles.display_name; NOTHING server-side rate-limits an INSERT into
     crash_reports; and prune_telemetry_job() at 90 days is far too slow.
  5. ONE ELEVATED-SHELL ITEM FOR JEAN (§4.4) — a leftover firewall rule.
  6. 🚨 IF YOU NEED THE PHONE AND IT DOES NOT ANSWER — `phone_agent.py status`
     says "no phone at a known address - broadcasting", or `probe` reports
     under 0.1 bits/pixel because the display is asleep — PAUSE THE WHOLE TASK
     RIGHT THERE AND TELL JEAN. Then WAIT for him to reply that the phone is
     awake and reachable, and retry from exactly where you stopped. Only he can
     turn host mode on and only he can wake a sleeping screen; neither is
     possible from this PC, and injected touches cannot wake it. Do NOT work
     around it, do NOT skip ahead, and do NOT report green as though the phone
     step were optional — it is the only thing that proves a fix on real
     hardware, and this session it caught two "finished" fixes that were not.
     ⚠️ HOST MODE STAYING ON DOES NOT MEAN THE SCREEN IS AWAKE: check `probe`,
     not just `status`. Both happened this session and Jean fixed each within
     minutes, so ASK EARLY rather than idling.
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
gets a test that BITES (remove the fix, watch the test fail), and where the fix
is visible on a device or in a browser, LOOK AT IT THERE TOO. Half-implemented
work, TODOs, stubs and "this could be improved later" notes are not acceptable
— finish each thing properly and fully, the way the original app does it.

THE METHOD, unchanged: fixtures, regenerate, LOOK at the picture, measure with
PIL rather than squint, fix the SHAPE rather than the symptom when the fault is
structural, then pin it with a test and prove the test bites by removing the
fix and watching it fail. When a report and a picture disagree, THE PICTURE
WINS. When a picture and a HANDSET disagree, the handset wins.

WHAT "SABOTAGE" MEANS HERE: copy the file to /tmp, change ONE line back to the
buggy version, run the test, confirm it FAILS, restore from the backup, re-run,
confirm green. A green test proves nothing on its own. It only ever touches
local Dart source; never the database, the phone, or the original worktree, and
it is never committed. IT ALSO TELLS YOU WHEN A FIX IS NOT NEEDED — one change
was reverted this session because sabotaging it showed the tests stayed green.

THE LESSONS THIS SESSION ADDED:

  * 🚨 CLOSE EVERY BROWSER YOU SIGN IN WITH.
  * 🚨 A SECOND CHROME CANNOT HAVE THE SAME --remote-debugging-port AND FAILS
    SILENTLY — you get the OLD browser, cache and stale bundle. Check the port
    owner with Get-NetTCPConnection before trusting a "fresh" profile.
  * 🚨 `ignoreCache` IS NOT ENOUGH: transferSize 0 means cache. Compare
    decodedBodySize against the built file's byte count.
  * 🚨 READ SEMANTICS LEAVES BY DESCENDANT, not `children.length === 0` —
    Flutter puts label text in a <span> CHILD and the old recipe drops whole
    empty states. Filter on `!e.querySelector('flt-semantics')`.
  * 🚨 THE ANDROID EMULATOR IS A FINE SUBSTITUTE when the browser tooling
    drops, and it found four defects — but it is set to Africa/Johannesburg, so
    a clock fault that only bites off-SAST will NOT show there.
  * 🚨 THE HANDSET FOUND WHAT THREE INSTRUMENTS COULD NOT, TWICE. A widget test
    literally cannot see the cross-fade overlap (MlMotion collapses to ~1ms
    under the test binding). Say so in the test file rather than implying
    coverage you do not have.
  * 🚨 CHECK WHETHER A "FAULT" IS THE DATA before writing it down.
  * 🚨 A GUARD OVER YOUR OWN SOURCE IS BLIND TO A DEPENDENCY'S DEFAULT.
  * 🚨 MY FILES CACHES ITS FOLDER LISTING — every time. Back out and re-enter,
    and confirm the TIMESTAMP moved; the size rounds identically for every
    build.
  * 🚨 `home` ON THE PHONE OFTEN DROPS THE LINK AND IS NOT RETRIED. Long batches
    drift; prefer short ones and re-shoot.
  * 🚨 WRITE PATCH SCRIPTS WITH THE WRITE TOOL — a quoted heredoc produced a
    literal NUL byte inside a Dart file this session.
  * 🚨 A REGEX QUALIFYING BARE IDENTIFIERS WILL EAT NAMED ARGUMENTS.
  * 🚨 `dart format` REFLOWS LINES YOU DID NOT TOUCH and can expose a
    pre-existing lint. Run flutter analyze on the file after formatting it.
  * 🚨 A SABOTAGE MUST COMPILE TO PROVE ANYTHING.
  * 🚨 REAL FILE I/O INSIDE testWidgets NEVER COMPLETES — plain test +
    readAsStringSync.
  * A RENDER PROVES A SCREEN DREW, NOT THAT WHAT IT DREW ADDS UP.
  * `find.text` CANNOT SEE A TextSpan, and a status chip draws UPPERCASE where
    the semantics label is mixed case.

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
py -3 tool/health_probe.py
flutter test test/renders          (after any visual change, --update-goldens)
flutter build web --release
flutter build apk --debug

...AND the original worktree re-checked against the baseline above.

HOW TO DRIVE THE APP ON ANDROID (the fastest surface; full detail in §5):

export PATH="$PATH:/c/Android/sdk/platform-tools"
adb -s emulator-5554 install -r -d build/app/outputs/flutter-apk/app-debug.apk
adb -s emulator-5554 shell monkey -p org.minelink.m3 -c android.intent.category.LAUNCHER 1
adb -s emulator-5554 exec-out screencap -p > shot.png       # then Read the png
adb -s emulator-5554 shell input tap <x> <y>                # REAL px, 1080x2400
adb -s emulator-5554 shell input text 'someone@example.com'
adb -s emulator-5554 shell input keyevent KEYCODE_BACK      # hides the keyboard

⚠️ A Read of a screenshot says "displayed at 900x2000, multiply by 1.20" — taps
must use the REAL 1080x2400 coordinates.

HOW TO DRIVE THE BUILT APP IN A BROWSER (full detail in §5):

flutter build web --release          # config/supabase.live.json is a bundled
                                     # ASSET, so a plain build reaches live
cd build/web && py -3 -m http.server 8123 --bind 127.0.0.1
"/c/Program Files/Google/Chrome/Application/chrome.exe" \
  --remote-debugging-port=9222 --user-data-dir="<scratch>/ml-m3-chrome-$(date +%H%M%S)" \
  --no-first-run --no-default-browser-check "http://127.0.0.1:8123/"

CONFIRM YOU GOT YOUR OWN BROWSER, not an older session's holding the port.

HOW TO PUT A BUILD ON THE PHONE (full detail in §5; invoke the skill first):

flutter build apk --debug
copy build\app\outputs\flutter-apk\app-debug.apk to
  \\192.168.88.30\Shared\PhoneRemote\minelink-m3.apk     (hash-match both ends)
On the phone: My Files > Network storage > jean > Shared > PhoneRemote >
  minelink-m3.apk > ~2.5 min download > Update > Open

🚨 THE NAS CLOCK IS ABOUT 2 h 36 m SLOW — compare the SHA-256, not timestamps.
⚠️ My Files CACHES the folder listing: back out of PhoneRemote and re-enter it,
and confirm the TIMESTAMP moved. The size rounds to 207 MB for every build.
⚠️ The applicationId is org.minelink.m3, deliberately different from the
shipping app's. They install side by side.
⚠️ Battery was at 23–26% and falling when this session ended.

OPTIONAL: if the Windows build gives trouble, carry on with web and mobile. It
is blocked by two PRE-EXISTING faults, neither of them the redesign: the
Flutter tool refuses the path because of the `!` in `SHOWME!`, and from a clean
path CMake fails extracting firebase_cpp_sdk_windows_12.7.0.zip — same
dependency, same version, in the shipping app. Jean already said to skip it.

LIVE ACCOUNTS
  `active user accounts.txt` in the repo root.
  jean@cyberhouse.co.za / BuRG3rJ3@n1995@#   (platform admin)
  everything @mineralguide.com / MineralGuide123!
  ironhills.controller@mineralguide.com is the Load Controller — the next role
  to drive.

WHEN THE WORK IS DONE: rewrite

    C:\Users\Somebody Someone\Music\SHOWME!\MineLink-M3\HANDOFF.md

the same way this one was written — verified state only, no intentions, ending
with a fresh self-contained copy-paste block in §8 that carries BOTH handoff
paths (that one and C:\Users\Somebody Someone\Claude\HANDOFF.md), the project
root, the untouchable worktree path and its baseline, exactly where you
stopped, what is already done so it is not redone, what is left, THE PHONE RULE
above, this same HOW TO WORK instruction from Jean quoted verbatim, and the
fix-as-you-go rule — and then commit it. State the commit count the tree WILL
be at once that commit lands, and say that the tip is the commit carrying the
file, so the handoff is self-consistent rather than describing a tree without
itself.
