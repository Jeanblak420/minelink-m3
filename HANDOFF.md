# MineLink M3 — session handoff

**Rewritten 2026-08-21, at the end of the browser-and-device session.**
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

The tree is **clean**, **103 commits**, nothing half-applied and nothing
uncommitted. The whole gate in §2 was run green against the tip, builds
included. The tip is
`tests: thirteen files were asserting on arithmetic that changes with the date`.

**The original worktree was re-checked against its §0 baseline at the start and
at the end of the session and is untouched** — HEAD `df451d0`, the same three
pre-existing modified files, 14163 files under the `-prune` form, two worktree
entries, and **nothing on disk modified today**.

### What changed about this project this session

The previous handoff's §4.1 said: *"Nothing has ever run on a handset, and
nothing has been driven in a browser against the live database as a signed-in
user. Every claim in this file is a claim about a headless render or a unit
test."*

**Both halves of that are now false**, and closing them is what this session
was. The redesign was:

- **driven in a real browser** (Chrome, remote-debugging, real fonts, real
  engine) against the **live Supabase project**, signed in as the platform
  admin `jean@cyberhouse.co.za`, then as the mine owner
  `ironhills.owner@mineralguide.com` — console, insights, targets, margin
  ledger, recon tables, live map, request inboxes, preferences, and the mine
  portal; desktop 1600px, the ~500px band, and a true emulated 412px phone;
- **run on Android**, on the `minelink_test` AVD (Android 14, 1080x2400 @
  420dpi — 412dp logical, the same panel as Jean's SM-G780G), built, installed,
  signed in from the device's own keyboard as `roadhaul.driver`, through the
  driver dashboard and Trip tab.

**Twenty-one faults were found and fixed**, every one of them invisible to the
218 renders and the 2,055 tests that were green before. They are listed in §3.

### The one thing a render can never do, and what replaced it

A render is a picture of a widget tree under `flutter_test`, where the fonts
are loaded but **the HTTP stack answers 400, MediaQuery padding is zero, there
is no status bar, no system keyboard, and the data is a fixture**. Four whole
classes of fault live in that gap, and this session hit all four:

1. **What the app really paints behind text** — the leaderboard gradient at
   2.2:1 that the token audit could not see. Now measured, on every render, off
   the pixels: §3, `LOW CONTRAST`.
2. **What the app really puts in its chrome** — the render harness was passing
   `title:` and `subtitle:` by hand, so 100 pictures showed a top bar the
   product does not have. It resolves them through `mlRouteTitle` now, exactly
   as the app does.
3. **What real data looks like** — fixture strings are short. Live ones cut.
4. **What a device adds** — a status bar, a keyboard, a navigation bar.

---

## 0. Where you are

| | |
|---|---|
| **This project** | `C:\Users\Somebody Someone\Music\SHOWME!\MineLink-M3` |
| What it is | A **complete, independent fork** of MineLink, being redesigned onto Material 3. Its own git repo (`main`), **103 commits**, clean tree. |
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
  pre-existing faults (§5.4); web and Android both build.
- **Work long, don't stop to check in.** *"don't worry about me seeing
  anything, I'll want to see when everything is complete and done, so don't
  stop so much in between — please run the task for as long as possible so
  that we can get this completely done and sorted please. Correct yourself
  where you make mistakes and fix the mistakes, and make sure you don't
  implement anything with gaps in them — make sure it's full and proper like
  the original."*

Four decisions settled before any code, in `docs/redesign/DESIGN.md`:

| Question | Answer |
|---|---|
| Preview or a real app? | **A real working fork.** It runs against the live database. |
| How far does the look move? | **M3 Expressive, MineLink palette.** Navy chrome, `#22D3EE`, the three fonts — kept. Colour roles, shape, motion, components — rebuilt. |
| What order? | Foundation → the screens that matter → the tail. |
| What happens when a button writes? | **It writes.** Jean chose no guard. |

**`supabase/` is frozen.** No migration is created, applied or pushed here.

---

## 2. Verified state, right now

Every one of these was run at the end of the session, in this order:

```
flutter analyze                                 no issues
flutter test                                    2055 passed, 1 skipped
dart tool/release_guards.dart                   39/39 PASS, 0 FAIL
dart tool/release_guards.dart --selftest        all guards bite
py -3 tool/type_scale_codemod.py --selftest     OK
py -3 tool/dropdown_width_check.py              passes
py -3 tool/glyph_coverage_check.py              passes
py -3 tool/one_clock_check.py                   0 sites off Africa/Johannesburg
py -3 tool/unphotographed_screens.py            93 targets, 93 photographed, 0 not
flutter build web --release                     builds
flutter build apk --debug                       builds
docs/redesign/renders/                          218 PNGs · 100 phone · 22 light
render harness — CUT OFF                        6 strings, all deliberate
render harness — FAILURE STATE                  0
render harness — RENDER NOTE                    0   (and it FAILS now, see §3)
render harness — LOW CONTRAST                   1812, baselined per render
test/design/token_contrast_test.dart            24 tests, 4 palettes, both themes
```

Layout is swept at **8 widths (1612 → 360px) × 6 text scales (0.85 → 2.0)**,
and again **with real rows in every table** at 360/800/1280 by 1.0/1.3.

---

## 3. What this session did

Full reasoning is in each commit message — `git log` is a real record, and
these eleven commits are long on purpose. Read them rather than trusting this
summary.

### 3.1 The instruments that were themselves wrong

Three checks turned out to be measuring something other than what they claimed.
All three were found by something failing that had no business failing.

- **`RENDER NOTE` was documented as zero across 218 renders. It was not.** The
  company mirror threw **21 framework errors on every desktop render** — a
  `LayoutBuilder` inside `IntrinsicHeight`, immediately under a comment on its
  own method saying a LayoutBuilder cannot go there. It was missed because
  every reading of that output had been piped through `tail`, and that render
  is not last. Both LayoutBuilders now reflow off the width already passed
  down, and **RENDER NOTE FAILS the test** from here on: a truncation can be
  deliberate, a framework error cannot.
- **The render harness was writing its own chrome.** Every console render was
  built with `selectedRoute: '/super-admin'`, `title: 'Global Admin'`,
  `subtitle: 'Platform overview'` — none of which the app produces. A hundred
  pictures showed a top bar the product does not have and lit the *Dashboard*
  rail item on the audit log, the margin ledger and the crash reports alike.
  `console()` now looks the body's class up in `app_router.dart` and resolves
  the chrome through `mlRouteTitle`. It paid immediately: the first honest run
  reported the phone console title cut at 180px.
- **Thirteen test files were asserting on arithmetic that changes with the
  date.** `kCaptureNow` is a fixed instant and the fixtures date every row
  relative to it, while the product measures rolling windows from
  `MlTime.now()`. `recon_table_legibility_test.dart` asserted `103.22 t` and
  went off on 2026-08-21 with nothing changed but the calendar.
  `freezeCaptureClock()` and the `capture-fixture-without-a-frozen-clock` guard
  close it.

### 3.2 The new instrument: contrast measured off the pixels

`test/renders/low_contrast_report.dart` measures **every laid-out paragraph in
every render**: the ink from the resolved style, **the ground from the pixels
behind it**, against WCAG AA with the threshold picked from the paragraph's
real size and weight. Reading the ground back from the raster is what makes
gradients, sheens, alpha stacks, cards-on-cards and images all just work — none
of them has to be modelled, because they have already happened.

`token_contrast_test.dart` states its own limit as a claim — *"a screen cannot
have a light-mode colour fault of its own; it can only inherit one from a token
pair"* — and the leaderboard's winner card disproved it. This is §4.2's gap,
closed.

**1,812 strings across 189 renders, baselined per render so it can only
shrink.** Three earlier versions of it were wrong in instructive ways, and the
commit message records each; the short version is that **ink must not be
measured from a raster** (at 9px a stroke never reaches its declared colour)
and **a pixel belongs to this text only if it is closer to the ink than to the
ground** (or a paragraph scrolled out of view reports against whatever is
painted where it would have been).

### 3.3 The twenty-one faults, by where they were hiding

**Only a browser could show these**

1. **The rail brand was a smudge in every render since the first.**
   `MineLinkLogo(height: 28)` is the full stacked lockup: at 28px the wordmark
   draws **6.53px** and the "TECHNOLOGIES" strapline **1.89px**, and the mark
   came out smaller than the 34px avatar at the foot of the same rail. Now the
   mark plus a real text wordmark under `MlChrome.wordmarkStart/End` — two
   tokens that were defined, lerped, and used by no widget at all.
2. **The target-pace caption was painted into the plot with no ground.** Live
   data put the series through it: `TARGET · 32 T/DAY` read as
   `T RGET 32 T/DAY`. Two sites.
3. **The console header claimed the month came from your laptop** —
   "This month (device calendar)" over a window that is `MlTime.now()`.
4. **The product's primary action was not a button.** The sign-in card's live
   accessibility tree had `StaticText "Sign in"` between two real buttons.
   Three faults behind it: a disabled button vanished instead of announcing as
   disabled; neither button carried `isButton` even when enabled (the browser
   was inferring a role from the tap handler); and neither took keyboard focus.
5. **21 of 38 console routes fell off the title ladder**, 29 off the subtitle
   one — and `/super-admin/requests/transportation-buyer` was titled
   **"Requested buyers"**, the name of a different inbox in the same rail group.
6. **The map ignored the theme.** Every tile host serves a light basemap; the
   console's live map was a bright beige rectangle in a navy console. Filtered
   now — invert composed with a 180° hue rotation, so parks stay green and
   water stays blue, and only the tiles, never the markers.
7. **"1 trucks"** — 32 call sites across 20 files interpolating a figure in
   front of a hard-coded plural. `mlCount` already existed with a doc comment
   saying *"1 loads is the tell"*; nothing used it.
8. **Two figures with no units** on the request queue: `640 · 820` where the
   row above read `640 km · R 700 / ton`.
9. **The chat launcher sat on the "More" tab** — 68% of the fifth destination's
   width, on every phone screen.
10. **A heading cut in a band no sweep reaches.** `MlSectionHead` stacked below
    a guessed `420`; at 452 (what a 500px viewport really leaves) it did not
    stack and ellipsised **"Live operations by organization ty…"**. At 412 it
    was fine — which is why sweeping narrower never found it.
11. **White on the brand cyan, 1.81:1, in 18 renders**, and the same pair
    inverted for every waybill link in light mode.
12. **The portal top bar said the company's name twice** — every company that
    has not finished its setup form, i.e. every company on its first day.
13. **"The stockpile balances could not be read"** while they were being read.
14. **The rail and the top bar disagreed on 15 destinations**; one of them,
    `/portal/mine/weighbridge`, named the neighbour.
15. **"60 tons" beside "45 / 120 t"** in one row of cards.

**Only a device could show these**

16. **The sign-in screen was drawn under the status bar.** The chain mark sat
    on the clock; the "M" of MineLink was behind a notification dot.
    `flutter_test` reports a MediaQuery padding of zero, so all 240 renders are
    taken on a device with no status bar.
17. **The driver's hero card contradicted itself in one row** —
    `● ACTIVE TRIP` beside `[ NO ACTIVE TRIP ]`.
18. **The driver's Recent Trips cut its route label** to
    "Iron Hills Mining - pri…".

**Decisions §4.3 had been holding, taken**

19. The margin ledger's TOTALS row summed three columns of **rates** —
    `R 520 + R 638 + R 495 = R 1,653.00` — while its own export carried no
    totals at all. A dash, not a weighted average: the row is labelled TOTALS.
20. A variance of exactly zero read **"+0 t"**.
21. `AuditLog.actionLabel` title-cased every word — **"User Assigned To Seat"**.
    Sentence case now. And the database's `"2 full load(s) ready"` is repaired
    at `NotificationModel.fromJson`, because `supabase/` is frozen here and the
    only alternative was shipping `load(s)` to a reader.

### 3.4 Six new guards

`release_guards.dart` is **39** now, all biting:

| id | what it stops |
|---|---|
| `brand-lockup-drawn-too-small` | the stacked lockup below its own default height |
| `no-device-clock-in-copy` | copy telling a user a date comes from their device |
| `count-without-plural-agreement` | `${n} trucks` — **both** interpolation forms |
| `capture-fixture-without-a-frozen-clock` | a test reading the real clock against fixed fixtures |

Plus the `LOW CONTRAST` ratchet and the `RENDER NOTE` failure inside the render
harness itself.

---

## 4. What is NOT done — PICK UP HERE

### 4.1 A real handset. Still open, and it needs Jean.

The emulator settles layout, insets, touch, the keyboard and the real Android
text stack. **It does not settle physical GPS reception, the foreground service
surviving a real drive, or battery behaviour**, and it is not iOS.

Jean's phone did not answer on either attempt this session:

```
cd C:\PhoneRemote\tool
py -3 phone_agent.py status
→ (no phone at a known address - broadcasting)
→ !! No phone answered. On the phone: CtrlBridge > Let my PC control this
     phone > Host mode on. Both devices must be on the same Wi-Fi.
```

Three things only Jean can do: turn **Host mode** on, approve the **UAC**
prompt that `serve_apk.ps1` raises to open the port, and take the **Play
Protect** decision (*More details → Install without scanning*).

The artifact is built and current at
`build/app/outputs/flutter-apk/app-debug.apk`. **Do not stage it as
`C:\PhoneRemote\dist\CtrlBridge.apk`** — that file is Jean's live CtrlBridge
build and `check_versions.ps1` verifies it against the published manifest.

**The applicationId is `org.minelink.m3`, deliberately different from the
shipping app's `com.example.flutter_application_1`**, so both install side by
side. Read that twice before concluding which app you are looking at: the first
launch this session was the shipping app's July build, and it looked plausible.

⚠️ **I uninstalled `com.example.flutter_application_1` from the emulator** while
working that out. That was the shipping app's July build. Reinstallable from
the shipping tree with `flutter build apk --debug`; nothing else on the
emulator was touched and the phone was never reached.

### 4.2 Light mode — the colour layer is closed, the SHAPE is measured

Both halves of §4.2 as it was written are now instrumented rather than
eyeballed: the colour layer by `token_contrast_test.dart` (pairs) and the
painted layer by the new `LOW CONTRAST` report (grounds). 22 of 218 renders are
still light, but the report runs on all 240 renders in both brightnesses, so a
light-mode fault no longer needs its own picture to be found.

**What is left is the 1,812.** They are real and they are ranked — group them
by `(ink, ground)` pair and the concentration is small. Two pairs were worth 47
strings and were fixed this session. The next ones down are avatar initials in
white on mid-saturation generated colours (`#FFFFFF` on `#F8AF18` at 1.89:1,
and its neighbours), and `#7C8AA0` at 9–13px on near-white.

### 4.3 Two decisions still Jean's

1. **The phone bottom bar's short forms** — `Recon`, `Requests`, `Docs`. Kept:
   a five-destination bar at 412px is what it is, and the full names are in the
   drawer.
2. **Two chat surfaces.** `messages_screen.dart` and `chat_screen.dart` both
   render a full thread. Their wording and now their inks agree; merging them
   is a refactor, not a redesign pass.

And **fifteen portal routes where the rail and the bar use different words** —
recorded with both strings in `every_portal_route_is_named_test.dart`. Four are
worth a second look because the bar is not shorter, it is a different word:
`fleet` (Vehicles / Fleet management), `drivers` (Drivers / Driver — singular),
`trucks-on-route` (capitalisation), `trip` (My routes / Trip).

### 4.4 The 127 remaining hand-named typefaces

Held by the `typeface-named-by-hand` ratchet, which can only shrink. `DESIGN.md`
§9 measures each. **Not** a gap — a decision.

### 4.5 Known limitations, stated rather than hidden

- **The `dd MMM yyyy` date sites were deliberately NOT consolidated.** 18 of
  them, all agreeing with `MlTime.day()` character for character.
- **The chat models hold INSTANTS.** A new surface reading one must go through
  `MlTime.clock/stamp/day`.
- **Six strings are still cut, on purpose** — three crash-report exception
  messages and three chat message previews. The render file says so in place.
- **Some fixtures are deliberately EMPTY.** The operations hub's ledgers are
  the documented example. Do not "fix" those by filling them.
- **The map tiles are real now in a browser and on a device**, and blank in
  renders — `flutter_test` answers every HTTP request with 400. The tile
  FILTER is asserted structurally instead.

### 4.6 Windows — blocked, and not this project's fault

Two independent pre-existing faults, with exact errors in
`docs/redesign/VERIFICATION.md`: the Flutter tool refuses the path outright
because of the `!` in `SHOWME!`, and from a clean path CMake fails extracting
`firebase_cpp_sdk_windows_12.7.0.zip` for `firebase_core`. Same dependency, same
version, in the shipping app. Jean said to skip it.

---

## 5. How to work in this repo

```bash
cd "/c/Users/Somebody Someone/Music/SHOWME!/MineLink-M3"

flutter analyze                                  # must be clean
flutter test                                     # 2055 passing, 1 skipped
dart tool/release_guards.dart                    # 39/39
dart tool/release_guards.dart --selftest         # every guard must BITE
py -3 tool/type_scale_codemod.py --selftest
py -3 tool/dropdown_width_check.py
py -3 tool/glyph_coverage_check.py
py -3 tool/one_clock_check.py
py -3 tool/unphotographed_screens.py
flutter test test/design/token_contrast_test.dart
flutter test test/renders --update-goldens       # after any visual change
ML_RULER=1 flutter test test/renders/measure_strings_test.dart
flutter build web --release
flutter build apk --debug
```

### Driving the built app in a browser — the setup that worked

```bash
flutter build web --release          # config/supabase.live.json is a bundled
                                     # ASSET, so a plain build reaches live
cd build/web && py -3 -m http.server 8123 --bind 127.0.0.1
"/c/Program Files/Google/Chrome/Application/chrome.exe" \
  --remote-debugging-port=9222 \
  --user-data-dir="<scratch>/ml-m3-chrome" \
  --no-first-run --no-default-browser-check "http://127.0.0.1:8123/"
```

Then drive it with the devtools MCP. Three things that cost time:

- **Flutter web publishes no accessibility tree until you ask.** Click the
  hidden placeholder — `document.querySelector('flt-semantics-placeholder')
  .click()` — and the whole semantic tree appears. It is the best instrument
  in the browser: it is how the `StaticText "Sign in"` fault was found.
- **`fill` on two different fields writes both into one.** Flutter web routes
  all text through one hidden input. Click the field, then `type_text` with
  `submitKey: "Tab"`.
- **Chrome will not resize below ~500px.** Use CDP emulation
  (`412x915x1,mobile,touch`) for a true phone viewport. The ~500px band is
  worth testing in its own right — one fault lived only there.

### Driving it on Android

```bash
flutter emulators --launch minelink_test
export PATH="$PATH:$LOCALAPPDATA/Android/Sdk/platform-tools"
adb install -r build/app/outputs/flutter-apk/app-debug.apk
adb shell monkey -p org.minelink.m3 -c android.intent.category.LAUNCHER 1
adb exec-out screencap -p > shot.png
```

`adb shell input text` mangles `!` and turns `%s` into a space. Quote it for
the DEVICE shell — `adb shell "input text 'MineralGuide123!'"` — and clear a
field with `input keyevent 123` (End) then ~45 backspaces before retyping;
half-cleared fields silently accumulate.

### Live accounts

`active user accounts.txt` in the repo root. `jean@cyberhouse.co.za` /
`BuRG3rJ3@n1995@#` is the platform admin; `ironhills.owner@mineralguide.com`
and `roadhaul.driver@mineralguide.com` / `MineralGuide123!` are the seeded set.

⚠️ **The console stores theme and accent PER ADMIN.** Switching Jean's mode to
Light for the light-mode audit writes to his account. It was switched back to
Dark and his Amber accent was left untouched — check that it still is.

### Things that have already gone wrong here — do not repeat them

- 🚨 **`git checkout -- <dir>` THREW AWAY UNCOMMITTED WORK.** Copy to the
  scratchpad first, or commit before any codemod that might need undoing.
- 🚨 **A BASH HEREDOC EATS BACKSLASHES EVEN WHEN QUOTED**, and a Python string
  inside one eats them again. It broke a patch in FOUR separate sessions now —
  the fourth wrote a real newline into a `text.rfind("\n")` and a `\$` into a
  Dart interpolation, which is valid Dart that prints the literal `${...}`.
  **Write any script containing a backslash with the Write tool.**
- 🚨 **`flutter analyze` output is not reliably indented.** Use `| tail -4`.
- 🚨 **NEVER READ A LONG TEST RUN THROUGH `tail`.** `RENDER NOTE` was
  documented as zero for the whole project because of this. Redirect to a file
  and grep the file.
- 🚨 **A LONG `&&` CHAIN ENDING IN `git commit -F <heredoc>` TIMES OUT.** Write
  the message to a file and commit with `-F` as its own command.
- **`dart format` on a directory reformats files you did not touch.**
- **Read AND write with `newline=''` AND `encoding='utf-8'` in Python.**
- **A codemod must not edit prose.** Skip comment lines and the helper's own
  doc comment — both were nearly rewritten this session, and the skips are
  recorded in the codemod rather than remembered.
- **`find.text` cannot see a `TextSpan`**, and **`toPlainText()` CANNOT SEE A
  TRUNCATION** — use `RenderParagraph.didExceedMaxLines`.
- **A render that passes alone and fails in the suite is a CLOCK, an image
  cache, or a REAL SOCKET.** And a fixture that says MORE than the service it
  stands in for turns the socket back ON: stubbing the chat dock's read half
  while `FixtureMessagingService` supplied a user id re-opened the realtime
  channel.
- 🚨 **A CHECK YOU HAVE NOT SABOTAGED IS A CHECK YOU DO NOT HAVE**, and
  **sabotage the RIGHT half**. Reverting the section-header measurement left
  its sweep green, because a second change in the same commit (`maxLines: 2`)
  masked it. Two changes went in together and each hid the other's regression.
- **Check whether a test already pins the behaviour you are about to "fix"**
  (the fuel screen's header alignment — made and reverted).
- **Assert on the right AXIS.** `meta.top` vs `title.bottom` looked like the
  obvious test for "did the header stack" and proved nothing, because the title
  block also holds a subtitle. It passed against the very constant it was
  written to catch.

### Where the reasoning lives

- `docs/redesign/DESIGN.md` — decisions and what each cost.
- `docs/redesign/VERIFICATION.md` — what was executed, and what has not been.
- `docs/design-reference/` — the **pre-redesign** reference PNGs. **Do not
  regenerate them**; they are the before-image.
- `docs/redesign/renders/` — 218 PNGs of the redesign.
- Every commit message carries its own reasoning.

---

## 6. The project's own rules still apply

`CLAUDE.md` in this repo is the fork's copy of the shipping app's:

- **§10.4** — a `Row` hands a non-flex child unbounded width; its commonest
  form is two `Flexible` children (or a `Flexible` and a `Spacer`) splitting a
  row when only one is long.
- **§10.5** — a green test over an empty fixture, an error state, or a fallback
  font proves nothing.
- **§7** — `flutter test` renders in a fallback font unless you load the real
  ones.
- **§7.1** — one clock, Africa/Johannesburg. `MlTime`, never `DateTime.now()`.
- **§10.6** — Dart bitwise operators are unsigned 32-bit on the web.
- **§1** — the package is `flutter_application_1`. Do not rename it. (The
  Android *applicationId* is `org.minelink.m3`; those are different things.)

---

## 7. Exactly where this session stopped

Nothing was in flight. The tree is clean at
`tests: thirteen files were asserting on arithmetic that changes with the date`,
and the whole gate in §2 was run against that commit — `flutter build web
--release` and `flutter build apk --debug` included.

The last piece of work finished was **the latent-flake sweep**: thirteen test
files that pump a capture fixture were reading the real clock, one of them went
off today, and all thirteen now call `freezeCaptureClock()` with a guard
holding the line.

### The rig is still up — walk into it, do not rebuild it

All three pieces were left running deliberately, so the next session can start
driving in one command instead of twenty minutes of setup. Verified up at the
moment this was written:

| what | where | state |
|---|---|---|
| Web server | `http://127.0.0.1:8123` → `build/web` | HTTP 200 |
| Chrome, remote debugging | port `9222`, profile in the scratchpad | on `#/portal/mine/stockpiles` |
| Android emulator | `emulator-5554` (`minelink_test`) | `org.minelink.m3` installed |

- **The served `build/web` is CURRENT** — newer than every file in `lib/`, so
  it carries every fix in this handoff. Confirm before trusting it:
  `find lib -name "*.dart" -newer build/web/flutter_bootstrap.js` must print
  nothing.
- **The browser is signed in** as `ironhills.owner@mineralguide.com` (the mine
  portal). Re-enable the accessibility tree after any reload —
  `document.querySelector('flt-semantics-placeholder').click()`.
- **The emulator is signed in** as `roadhaul.driver@mineralguide.com`, but its
  INSTALLED build predates the last two lib commits (the driver hero's eyebrow
  and the Recent Trips route label). `adb install -r
  build/app/outputs/flutter-apk/app-debug.apk` refreshes it; the APK on disk is
  current.

None of this is state the project depends on — if a piece is gone, §5 has the
exact commands to bring it back.

**Pick up at §4.2** — the 1,812 low-contrast strings, ranked by `(ink, ground)`
pair, starting with the avatar initials. **§4.1** needs Jean to turn Host mode
on before a handset is possible.

---

## 8. COPY-PASTE MESSAGE FOR THE NEXT CHAT

Everything the next session needs is inside this block. Paste it whole.

```
Continue the MineLink Material 3 redesign, exactly where the last session left
off. Read these TWO handoff files before doing anything else, in this order:

1. THE CURRENT HANDOFF — this is the file that governs the work:
   C:\Users\Somebody Someone\Music\SHOWME!\MineLink-M3\HANDOFF.md
   Rewritten 2026-08-21 at the end of the browser-and-device session. Read it
   in this order: "WHERE THIS SESSION STOPPED — READ THIS FIRST", then §0
   (where you are + the one rule), §2 (verified state), §3 (what was done and
   why it was invisible before), §7 (exactly where I stopped), §4 (what is NOT
   done — pick up here) and §5 (things that have already gone wrong here).

2. THE OLDER MACHINE-WIDE HANDOFF — background only, do not work from it:
   C:\Users\Somebody Someone\Claude\HANDOFF.md
   Dated 2026-08-08. MCP servers, git position, the decoy folders, the phone
   tooling. The MineLink-M3 one above governs this redesign work.

THE PATHS THAT MATTER

  Work happens here (its own git repo, branch `main`):
    C:\Users\Somebody Someone\Music\SHOWME!\MineLink-M3

  NEVER TOUCHED, for any reason:
    C:\Users\Somebody Someone\Music\SHOWME!\worktree-2026-05-05T11-53-29

THE ONE RULE THAT MUST NOT BREAK: nothing whatsoever changes inside
worktree-2026-05-05T11-53-29. Its verified baseline is in §0 of the MineLink-M3
handoff — check it at the START of the session and again at the END. (HEAD
df451d0, exactly three pre-existing modified files, two worktree entries,
nothing modified today. Note the file-count footnote in §0: 14163 or 14164
depending on which `find` you run, because in a worktree `.git` is a FILE.)

WHERE I LEFT OFF, EXACTLY

The tree is CLEAN. 103 commits. Nothing is half-applied and nothing is
uncommitted. The tip is "tests: thirteen files were asserting on arithmetic
that changes with the date", and the whole gate below was run green against it,
both builds included.

The last work finished was a LATENT-FLAKE SWEEP: thirteen test files pump a
capture fixture stamped from a FIXED instant (kCaptureNow) while reading the
REAL clock, so they assert on arithmetic that changes with the calendar. One of
them went off on 2026-08-21 with nothing changed but the date. All thirteen now
call freezeCaptureClock(), and the `capture-fixture-without-a-frozen-clock`
guard holds the line.

THE RIG IS STILL RUNNING — WALK INTO IT, DON'T REBUILD IT

I left all three pieces up on purpose so you can start driving immediately
instead of spending twenty minutes on setup:

  * THE WEB SERVER is up on http://127.0.0.1:8123 serving build/web. That build
    is CURRENT — newer than every file in lib/, so it carries every fix in the
    handoff. Confirm with:
      find lib -name "*.dart" -newer build/web/flutter_bootstrap.js
    (prints nothing = current). If you change lib/, rebuild with
    `flutter build web --release`; the server picks it up with no restart.

  * THE BROWSER is open — Chrome with remote debugging on port 9222, its own
    profile in the scratchpad, currently on #/portal/mine/stockpiles and SIGNED
    IN as ironhills.owner@mineralguide.com. Drive it with the devtools MCP.
    After any reload you must re-enable Flutter's accessibility tree with
    document.querySelector('flt-semantics-placeholder').click() — that tree is
    the single best instrument in the browser and is how the "Sign in" button
    fault was found.

  * THE ANDROID EMULATOR is running (emulator-5554, the minelink_test AVD) with
    org.minelink.m3 installed and SIGNED IN as roadhaul.driver@mineralguide.com.
    Its installed build predates the last two lib commits, so refresh it first:
      adb install -r build/app/outputs/flutter-apk/app-debug.apk
    (the APK on disk is current). adb lives at
    %LOCALAPPDATA%\Android\Sdk\platform-tools.

None of this is state the project depends on — §5 of the handoff has the exact
commands to bring any of it back if it has gone away by the time you start.

WHAT IS ALREADY DONE — do not redo any of it

  * THE REDESIGN HAS NOW BEEN DRIVEN FOR REAL, which the previous handoff said
    had never happened. In a real browser (Chrome + remote debugging) against
    the LIVE Supabase project, signed in as the platform admin and then as a
    mine owner — console, insights, targets, margin ledger, recon tables, live
    map, request inboxes, preferences and the mine portal, at 1600px, in the
    ~500px band, and at a true emulated 412px. AND on Android, on the
    `minelink_test` AVD (Android 14, 1080x2400 @ 420dpi = the same 412dp panel
    as Jean's SM-G780G), built, installed, signed in from the device keyboard
    as the driver, through the driver dashboard and Trip tab.
  * 21 FAULTS FOUND AND FIXED, every one invisible to the 218 renders and the
    2,055 tests that were green before. §3.3 lists them all. Headlines: the
    rail brand was drawing a 6.5px wordmark; the product's primary action was
    not a button; 21 of 38 console routes had no title; the map ignored the
    theme; "1 trucks" in 32 places; the chat launcher sat on the "More" tab;
    and on the device, the sign-in screen was drawn UNDER the status bar.
  * THREE CHECKS WERE THEMSELVES WRONG and are fixed: RENDER NOTE was
    documented as zero and was actually 21 framework errors per desktop render
    (missed because the output had always been read through `tail`); the render
    harness was passing the top bar's title and the rail's selection by HAND,
    so 100 pictures showed chrome the app does not produce; and the thirteen
    date-dependent test files above.
  * A NEW INSTRUMENT closes §4.2: contrast measured off the PIXELS — ink from
    the resolved style, GROUND from the raster behind the text — on every
    paragraph of every render, in both themes. It sees gradients, sheens and
    alpha stacks that a token-pair audit cannot. 1,812 strings, baselined per
    render so it can only shrink.
  * SIX new release guards; the suite is 39/39 and every one bites.
  * FOUR of the six §4.3 decisions taken (margin-ledger TOTALS, "+0 t", the
    title-cased audit action, the database's "load(s)").

WHAT IS LEFT — start here, in this order

  1. THE 1,812 LOW-CONTRAST STRINGS (§4.2). Ranked and concentrated: group the
     report by (ink, ground) pair and the list is short. Two pairs were worth
     47 strings and are already done. Next down are avatar initials in white on
     mid-saturation generated colours (#FFFFFF on #F8AF18 = 1.89:1) and
     #7C8AA0 at 9-13px on near-white. Lower the per-render baseline as you go
     so the gains are held.

  2. A REAL HANDSET (§4.1) — still open and it NEEDS JEAN. The emulator settles
     layout, insets, touch and the keyboard; it does NOT settle physical GPS,
     the foreground service surviving a real drive, or battery. Jean's phone
     did not answer this session: CtrlBridge Host mode is off. Three things
     only he can do — turn Host mode on, approve the UAC prompt, and take the
     Play Protect decision. If he has turned it on, invoke the
     `driving-jeans-phone` skill FIRST. The APK is built and current at
     build/app/outputs/flutter-apk/app-debug.apk. DO NOT stage it as
     C:\PhoneRemote\dist\CtrlBridge.apk — that is his live CtrlBridge build.
     The applicationId is `org.minelink.m3`, deliberately different from the
     shipping app's `com.example.flutter_application_1`; read that twice before
     concluding which app you are looking at.

  3. THE REMAINING §4.3 DECISIONS — the two chat implementations, and the
     fifteen portal routes where the rail and the top bar use different words
     (recorded with both strings in every_portal_route_is_named_test.dart).

THE METHOD, unchanged: fixtures, regenerate, LOOK at the PNG, MEASURE it with
PIL rather than squint, fix the SHAPE rather than the instance where the fault
is structural, then pin it with a test and prove the test bites by removing the
fix and watching it fail.

Watch for the faults every batch has had: a screen inside a ShellRoute that
builds its own Scaffold+AppBar; a screen that reads a service directly so no
provider override reaches it; a FIXTURE that says less than the service it
stands in for, or that sets two derived fields independently and prints an
impossibility; an override list that does not reach the screen; a wire enum
value reaching a reader; and a Row handing a non-flex child unbounded width —
including its commonest form by far, two Flexible children (or a Flexible and
a Spacer, which IS an Expanded) splitting a row when only one of them is long.

HOW TO WORK: don't worry about me seeing anything, I'll want to see when
everything is complete and done, so don't stop so much in between — please run
the task for as long as possible so that we can get this completely done and
sorted please. Correct yourself where you make mistakes and fix the mistakes,
and make sure you don't implement anything with gaps in them — make sure it's
full and proper like the original.

OPTIONAL: if the Windows build gives trouble, just carry on with web and
mobile.

BEFORE CLAIMING ANYTHING IS DONE, all of these must be green:

flutter analyze
flutter test
dart tool/release_guards.dart
dart tool/release_guards.dart --selftest
py -3 tool/type_scale_codemod.py --selftest
py -3 tool/dropdown_width_check.py
py -3 tool/glyph_coverage_check.py
py -3 tool/one_clock_check.py
flutter build web --release
flutter build apk --debug

Read §5 of the MineLink-M3 handoff — the things that have already gone wrong in
this repo — so you don't repeat them. The ones that have cost real time more
than once:
  * NEVER read a long test run through `tail`. RENDER NOTE was documented as
    zero for the whole project because of exactly that. Redirect to a file and
    grep the file.
  * `git checkout -- <dir>` threw away three finished uncommitted fixes.
  * A bash heredoc eats backslashes even when quoted, and a Python string
    inside one eats them again — it has broken a patch in FOUR sessions now.
    Write such scripts with the Write tool.
  * `flutter analyze` output is not reliably indented — use `| tail -4`.
  * A long && chain ending in a git commit heredoc times out at two minutes —
    write the message to a file and commit with -F as its own command.
  * A check you have not sabotaged is a check you do not have — AND sabotage
    the right half: reverting one of two changes in the same commit left a
    sweep green because the other masked it.
  * Assert on the right AXIS. "meta.top vs title.bottom" looked like the
    obvious test for whether a header stacked and proved nothing.
  * Check whether a test already pins the behaviour you are about to "fix".

WHEN THE WORK IS DONE: rewrite
C:\Users\Somebody Someone\Music\SHOWME!\MineLink-M3\HANDOFF.md the same way
this one was written — verified state only, nothing aspirational, with a fresh
self-contained copy-paste block in §8 that carries BOTH handoff paths, the
project root, the untouchable worktree path, exactly where you stopped, what is
done, what is left, and this same HOW TO WORK paragraph — and commit it.
```
