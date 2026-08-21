# MineLink M3 — session handoff

**Rewritten 2026-08-21 (fourth rewrite that day).** Everything below is
verified state, not intention. It replaces the previous handoff of the same
name; the parts of that one still true have been folded in.

**This file lives at**
`C:\Users\Somebody Someone\Music\SHOWME!\MineLink-M3\HANDOFF.md`

The older, machine-wide handoff is at
`C:\Users\Somebody Someone\Claude\HANDOFF.md` — MCP servers, git position,
decoy folders, dated 2026-08-08. **Background only; this file governs the
redesign work.**

---

## WHERE THE LAST SESSION STOPPED — READ THIS FIRST

The work is **mid-Phase-4** and stopped at a clean, committed, fully green
point. Nothing is half-applied and nothing is uncommitted.

- **`git status` is empty. 82 commits** (this file's commit included). The tip
  before it is `renders: every phone frame is the height of its own page`. No
  hash is written down, because a hash in a file the same commit changes is
  wrong the moment it lands.
- **The whole gate was run for real at the end of this session** (numbers in
  §2), including `flutter build web --release` and `flutter build apk --debug`.
- **The original worktree was re-checked against its §0 baseline** immediately
  before the last commit and is **untouched** — HEAD `df451d0`, 14164 files,
  exactly the three pre-existing modified files, two worktree entries, and
  nothing on disk modified today.

**§4.1 IS FINISHED — `py -3 tool/unphotographed_screens.py` reports 93 route
targets, 93 photographed, 0 without.** **§4.2 IS FINISHED** — ten dialogs and
the five-step due-diligence gate all have pictures.

**What this session did, and it is a different KIND of work from the ones
before it.** Every earlier session found defects by opening a picture and
looking. That works, and it is slow, and it cannot see the fault it found most
often. So the render harness was taught to report **every string it had to cut
off**, with the paragraph's own width and the nearest named widgets around it:

```
CUT OFF [screen-recon-tables-phone-dark] 3 string(s) at 412x2304:
  ~ TRP-000123
      6px  Row < _MlRow < _SingleChildViewport < _GestureSemantics
```

It found **137**. They are now **6**, and the 6 are deliberate — three
crash-report exception strings and three chat message previews, both documented
in the render file itself. **A truncation is a valid layout**: nothing throws,
no sweep fails, the golden is written happily, and a 6px table cell reads in
the picture as an empty column rather than as a missing waybill number.

**Searches already finished — do NOT redo them:**

1. `lib/` scanned twice for any other hand-rolled flex table with the
   compressing shape. **Both scans empty.**
2. Every `FractionallySizedBox`, `MapOptions`, hand-rolled "x ago" formatter
   and `DateTime.now()`-fed relative time routed through one implementation,
   each held by a guard.
3. Every `MaterialLocalizations.format*Date` / `formatTimeOfDay` (21 sites),
   every hand-rolled absolute timestamp (7 vocabularies), and every
   parenthesised plural `thing(s)` (22 sites). All three held by guards.
4. Every screen the two `ShellRoute`s mount, scanned for an app bar of its own
   (13 found, all fixed, one exemption); every private copy of the presence
   rule (4 found); every `DateTime.now()` written to ISO through a local
   variable (2 found).
5. **New this session:** every rendered screen scanned for CUT text, at every
   width and both themes, by the harness itself — 137 found, 131 fixed, 6
   deliberate and named. **This one is not a one-off search: it runs on every
   render and will report the next one for free.**
6. **New this session:** every phone frame measured for CLIPPING and for dead
   space. 5 were genuinely clipped, 63 were oversized, all 98 now fit.

---

## 0. Where you are

| | |
|---|---|
| **This project** | `C:\Users\Somebody Someone\Music\SHOWME!\MineLink-M3` |
| What it is | A **complete, independent fork** of MineLink, being redesigned onto Material 3. Its own git repo (`main`), **82 commits**, clean tree. |
| **The original** | `C:\Users\Somebody Someone\Music\SHOWME!\worktree-2026-05-05T11-53-29` — **DO NOT TOUCH IT.** |

### The one rule that must not be broken

**Nothing whatsoever changes inside `worktree-2026-05-05T11-53-29`.** That was
Jean's instruction and it has held for every commit. Its verified baseline,
re-checked at the start and end of every session:

```
HEAD              df451d0
file count        14164   (find, excluding .git)
git status        exactly 3 modified files, all pre-existing:
                    M .design-sync/config.json
                    M lib/features/super_admin/screens/margin_ledger_screen.dart
                    M test/widgets/app_sidebar_behaviour_test.dart
git worktree list only the main repo + that worktree (no third entry)
```

Check it with:

```bash
cd "/c/Users/Somebody Someone/Music/SHOWME!/worktree-2026-05-05T11-53-29"
git status --porcelain
git rev-parse --short HEAD
find . -path ./.git -prune -o -type f -print | wc -l
git worktree list
```

Every command in this project must run with its working directory inside
`MineLink-M3`. The two trees share no git state — `MineLink-M3` is a plain
repo, not a worktree.

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
  pre-existing faults (§4.6); web and Android both build.
- **Work long, don't stop to check in.** *"don't worry about me seeing
  anything, I'll want to see when everything is complete and done, so don't
  stop so much in between — please run the task for as long as possible so
  that we can get this completely done and sorted please. Correct yourself
  where you make mistakes and fix the mistakes, and make sure you don't
  implement anything with gaps in them — make sure it's full and proper like
  the original."*

Four decisions settled before any code, recorded in `docs/redesign/DESIGN.md`:

| Question | Answer |
|---|---|
| Preview or a real app? | **A real working fork.** It runs against the live database. |
| How far does the look move? | **M3 Expressive, MineLink palette.** Navy chrome, `#22D3EE`, the three fonts — kept. Colour roles, shape, motion, components — rebuilt. |
| What order? | Foundation → the screens that matter → the tail. |
| What happens when a button writes? | **It writes.** Jean chose no guard. |

**`supabase/` is frozen.** No migration is created, applied or pushed from this
project.

---

## 2. Verified state, right now

Every one of these was run at the end of the session, in this order:

```
flutter analyze                                 no issues
flutter test                                    1931 passed, 1 skipped
dart tool/release_guards.dart                   35/35 PASS, 0 FAIL
dart tool/release_guards.dart --selftest        all guards bite
py -3 tool/type_scale_codemod.py --selftest     OK
py -3 tool/dropdown_width_check.py              passes
py -3 tool/glyph_coverage_check.py              passes
py -3 tool/one_clock_check.py                   0 sites off Africa/Johannesburg
py -3 tool/unphotographed_screens.py            93 targets, 93 photographed, 0 not
flutter build web --release                     builds
flutter build apk --debug                       builds
docs/redesign/renders/                          204 PNGs, 98 of them phone-width
render harness cut-off report                   6 strings, all deliberate
```

Layout is swept at **8 widths (1612 → 360px) × 6 text scales (0.85 → 2.0)**,
and again **with real rows in every table** at 360/800/1280 by 1.0/1.3.

---

## 3. What Phase 4 has done

Full reasoning is in each commit message and in `docs/redesign/DESIGN.md` §10.
`git log` is a real record — read it rather than trusting this summary.

### 3.1 The 2026-08-21 CUT-OFF session, in one list

The list came from the harness, not from reading pictures, and it is worth
knowing what it caught that eyes had not:

- **A table cell 6px wide.** Three tables put an `MlPlatePill` and a second
  identifier in one `Row` inside a column whose declared minimum is the
  PLATE's width — so the pill took all of it and `TRP-000123`, `Chrome` and
  `Manganese` were each drawn as an ellipsis. They are `Wrap`s now: side by
  side when they fit, stacked when they do not, and no wider a scroll floor
  for the tables that fit today.
- **Money.** `55,34…` for the TONS figure on the console's own front page at
  760px, and `R40,920.00` at 76px in the buyer's invoice table. A cut number is
  not a truncation, it is a wrong number.
- **Buttons that could not say what they do** — `Dispute` in 23px, `Edit` and
  `Attach` in 76.
- **A dropdown's options, cut in a menu nobody had opened.** A
  `DropdownButton` lays its items out to size itself, so they are real,
  laid-out text while the menu is shut, and the report caught them there.
- **Two ROUTE families.** `Iron Hills Mining → Richards Bay` was cut in the
  margin ledger, the route marketplace, both request-tracking tables, the
  buyer's request cards and the admin's inbox — **on a 1600px desktop as often
  as on a phone**, because a flex weight cannot know how long a place name is.
- **Company names**, on the register, the audit trail, the deactivation queue,
  the platform-users list, the targets picker, the chat link builder, the org
  detail page's own title bar, and every card that names two parties.
- **A person's name behind a badge** — `Refilwe Sekhukhune-…` had 108px of a
  320px pane because "Renew to message" sat beside it.
- **A fixture fault that photographed as a product fault.**
  `partnerCompaniesProvider` fell through an EMPTY `orgFilter` to the mines, so
  the reconciliation cards read *"Unknown company → Unknown company"*. The real
  service returns every partner for an empty filter.

### 3.2 The shapes that changed, rather than the instances

Three fixes did nearly all of it, and each is a rule worth reusing:

1. **A `Wrap` where two `Flexible`s were splitting a row equally.** Two flex
   children share the free space evenly whatever they hold, so the longer of
   two names is cut to the shorter one's width even when the row has room. In a
   `Wrap` each child takes what it needs and the second drops to a new line.
2. **A second line where the value is an IDENTITY rather than a preview.** A
   company name, a route, a person, a waybill number, a caption that says what
   a figure means — these have to survive. A message preview and an exception
   string do not.
3. **A declared `MlColumn.minWidth` where the figure is the point of the
   screen.** `MlDataTable` widens its scroll floor until every column that
   declared a minimum gets it, so the table SCROLLS rather than eats the
   number.

And one measuring habit: **`test/renders/measure_strings_test.dart` lays a
string out in the real font and prints what it measures.** It exists because
the tons-out search field was widened twice on arithmetic and cut both times —
the estimate kept missing that `prefixIcon` is given a 48px box whatever size
the icon inside it is. It prints only under `ML_RULER=1`.

### 3.3 Earlier in Phase 4

- **§4.1 finished** across four sessions — the console list, the portal list,
  the shared list, the registry four, the auth tail, the two fixture-less
  console screens, and the last five mirrors. Every screen photographed turned
  up a real defect; one turned up a shape repeating across twelve screens.
- **§4.2 finished** — ten dialogs plus the five-step due-diligence gate, driven
  with `shoot()`'s `act:` callback.
- **One page ground.** 83 dark pages on `#060B15` and 7 light on `#EEF2F8`,
  held by `one_page_ground_under_the_shell_test.dart`, which scans the router
  for shell leaves that build their own `Scaffold`.
- **Two structural shell faults** — a canvas that stopped short of a phone
  screen under a short page, and an `AnimatedSwitcher` `Stack` that needed
  `StackFit.passthrough`. Between them they fixed 23 phone renders with a seam
  and 18 two-tone pages.

---

## 4. What is NOT done — PICK UP HERE

**Both of the lists the last three sessions worked from are empty.** There is
no screen without a picture and no dialog without a picture. What follows is
what genuinely remains, in the order it is worth doing.

### 4.1 Light mode has nine renders out of 204

Nine. `console-desktop-light`, `console-phone-light`,
`dash-buyer-desktop-light`, `dash-buyer-phone-light`,
`portal-buyer-desktop-light`, `screen-appearance-desktop-light`,
`screen-buyer-loads-value-desktop-light`, `screen-profile-setup-desktop-light`,
`screen-transporter-reconciliations-desktop-light`.

**This is the largest unexamined surface in the project.** The theme is
token-driven and `MlSemantic` is brightness-aware, so most of it should be
right — but "should be" is exactly the claim every other sweep this phase has
falsified. The page-ground work already found seven light pages that were the
wrong colour, and it only looked at seven.

The cheapest useful next step: **add a light render for every screen that has a
dark one**, run the cut report over the result (it reports per render, so light
and dark are separate rows), and look at the new PNGs. Contrast is the thing to
watch — `MlTone`'s `fg`/`bg` pairs resolve per brightness, and a hue that reads
on navy can vanish on `#EEF2F8`.

### 4.2 Nobody has read all 204 pictures

The cut report finds text that did not fit. It cannot see a misaligned column,
a hue that means the wrong thing, an empty state that should not be empty, or a
card whose heading and body disagree. **Reading the pictures is still the
highest-yield activity in this project** — it is what found every defect before
this session. 204 is a long sitting, but it has never been done end to end.

### 4.3 Decisions waiting on Jean

1. **The margin ledger's TOTALS row sums the three per-ton RATE columns** —
   R 520 + R 638 + R 495 = "R 1,653.00" — a figure with no meaning, printed in
   the same style as the money beside it. The code calls these "the plain
   column totals requested", and the Excel/CSV/PDF export already omits them,
   so the screen and its own export disagree. Left alone because it reads as a
   deliberate instruction. Say the word and it becomes a dash or a
   tonnage-weighted average.
2. **The targets history renders a variance of exactly zero as `+0 t`, in
   green** (`variance >= 0 ? '+' : '−'`). Green for on-target is right; the `+`
   on a genuine zero is the same family as the `0%`-where-a-dash-belongs that
   was fixed on org insights. One character, not wrong enough to change without
   asking.
3. **`AuditLog.actionLabel` title-cases every word**, so `USER_ASSIGNED_TO_SEAT`
   reads "User Assigned To Seat" — English title case would lower-case "to".
   Noted, not changed.
4. **`Recon`, `Requests` and `Docs`** are the phone bottom bar's short forms for
   Reconciliation, Procurement and Compliance. "Recon" is the product's own word
   (CLAUDE.md §4), "Requests" is where the tap actually lands, and "Docs"
   describes what the compliance screen holds. Say the word if any of the three
   should read differently.
5. **The notification body "2 full load(s) ready …" is written by the
   DATABASE**, not by Dart — `supabase/` is frozen in this project, so
   `mlCount` cannot reach it. Every other parenthesised plural in the product
   is gone; this one needs a migration in the shipping app to follow.

### 4.4 The 127 remaining hand-named typefaces

Held by the `typeface-named-by-hand` ratchet, which can only shrink. They are
three different things and `DESIGN.md` §9 measures each. **Not** a gap — a
decision — but the ratchet is there so it can be revisited.

### 4.5 Known limitations, stated rather than hidden

- **Nothing has run on real hardware.** No APK on a handset (Jean's phone can
  be driven — see the `driving-jeans-phone` skill in the global `CLAUDE.md`);
  nothing driven against the live database in a browser as a signed-in user;
  iOS not attempted. **This is the biggest single gap in the whole project.**
- **The map tiles are blank in every render.** Tiles come from OpenStreetMap
  over HTTP and `flutter_test` answers every request with a 400. The route
  line, the puck, the pins, the banner and the HUD are all real; the tiles need
  a device. The map GROUND is theme-correct.
- **The `dd MMM yyyy` date sites were deliberately NOT consolidated.** 18 of
  them, all agreeing with `MlTime.day()`'s own output character for character,
  and several formatting a value whose provenance has to be read before it can
  safely be converted (instant vs already-converted wall clock). The
  `one-vocabulary-for-a-timestamp` guard deliberately does not match a
  date-only pattern for that reason. Converting them is safe but must be done
  site by site, not by regex.
- **The chat-model conversion changed which values are wall clocks.** The five
  models in `messaging_models.dart` now hold INSTANTS. If another surface starts
  reading one of those fields, it must go through `MlTime.clock/stamp/day` — not
  `DateFormat` directly, which would print UTC.
- **Six strings are still cut, on purpose** — three crash-report exception
  messages (`PlatformException(channel-error, …, null, null)` has no bounded
  length, and the card opens onto the full text) and three chat message
  previews (a preview is a glance at a message you open to read; the
  conversation NAME above it takes two lines now). The render file says so in
  place, so the next person does not re-derive it.

### 4.6 Windows — blocked, and not this project's fault

Two independent pre-existing faults, both recorded with exact errors in
`docs/redesign/VERIFICATION.md`:

1. The Flutter tool **refuses the path outright** because of the `!` in
   `SHOWME!`. The canonical shipping tree is under the same folder, so it
   cannot have been built from there either.
2. From a clean path it reaches CMake, which fails on two consecutive clean
   runs extracting `firebase_cpp_sdk_windows_12.7.0.zip` for `firebase_core`.
   Same dependency, same version, in the shipping app.

Jean said to skip it. Moving the folder to a path without `!` is his call.

---

## 5. How to work in this repo

```bash
cd "/c/Users/Somebody Someone/Music/SHOWME!/MineLink-M3"

flutter analyze                                  # must be clean
flutter test                                     # 1931 passing, 1 skipped
dart tool/release_guards.dart                    # 35/35
dart tool/release_guards.dart --selftest         # every guard must BITE
py -3 tool/type_scale_codemod.py --selftest
py -3 tool/dropdown_width_check.py
py -3 tool/glyph_coverage_check.py
py -3 tool/one_clock_check.py
py -3 tool/unphotographed_screens.py             # what still has no picture
flutter test test/renders --update-goldens       # after any visual change
ML_RULER=1 flutter test test/renders/measure_strings_test.dart
flutter build web --release
flutter build apk --debug
```

**Read the render run's output, not just its exit code.** It prints
`RENDER NOTE [name]` for framework errors and `CUT OFF [name]` for every string
that did not fit, with the paragraph's width and the widgets around it. Both
are reported rather than failed, deliberately — a render file that fails on a
deliberate truncation teaches people to add exclusions rather than to look.

### Things that have already gone wrong here — do not repeat them

- 🚨 **`git checkout -- <dir>` THREW AWAY UNCOMMITTED WORK.** It also reverted
  three finished, unrelated fixes in the same directory. **Copy the files to
  the scratchpad first**, or commit before running any codemod that might need
  undoing. (To sabotage-test a fix, `cp file /tmp/x.bak` first and `cp` it
  back — that restores the ORIGINAL verbatim, which a hand-retype does not.)
- 🚨 **A BASH HEREDOC EATS BACKSLASHES EVEN WHEN QUOTED.** It cost two failed
  patches in one session and did it again in the next: `<<'PY'` turned `\\n`
  into a real newline inside a Dart string literal and produced an unterminated
  string. **Write any script containing a backslash with the Write tool**, and
  if you must use a heredoc, keep every `\` out of it.
- **Several files in this repo have MIXED line endings.** A multi-line literal
  match silently finds nothing. Any codemod must read and write with
  `newline=''` and translate its own literals with `if '\r\n' in s`.
- 🚨 **`flutter analyze` output is not reliably indented.** Piping it through
  `grep -E "^\s+(error|warning)"` reported **clean while a warning was
  printed**. Use `| tail -4` and read "N issues found".
- 🚨 **A LONG `&&` CHAIN ENDING IN `git commit -F <heredoc>` TIMES OUT.** Two
  minutes is the Bash tool's default and `flutter analyze` plus a render run
  eats it. Write the commit message to a file with the Write tool and commit
  with `-F` as its own command.
- **`dart format` on a directory reformats files you did not touch.** It did
  131 files once and 106 another time. **The repo is not dart-format clean**,
  so formatting even a single file you edited churns it entirely. Emit
  correctly-formatted code instead.
- **A codemod must not edit prose.** One rewrote the doc comment *explaining* a
  rule into something that no longer said it. It strips comments now.
- **Read AND write files with `newline=''` AND `encoding='utf-8'` in Python.**
  Universal newlines turn a 340-line change into 5,342 insertions, and the
  default Windows codec is cp1252 — which throws on this repo's `—` and `✅`
  and, worse, will happily round-trip other characters into mojibake.
- **A failing golden comparison can mask a failing test.** Delete the golden
  and re-run to see the real error.
- **`git add -A` sweeps `test/renders/failures/`** — golden-comparison
  scratch. It is `.gitignore`d now.
- **Never `git stash`, `git checkout -- .`, or `git clean`** in the original
  worktree — other agent sessions write it (`CLAUDE.md` §10.1).
- **A Windows console is cp1252** and cannot encode the characters these tools
  talk about. Every Python check forces UTF-8 on stdout.
- **`find.text` cannot see a `TextSpan`.** Walk `RenderParagraph` and read
  `toPlainText()` — `console_tail_test.dart` and `portal_tail_test.dart` both
  have the helper.
- 🚨 **AND `toPlainText()` CANNOT SEE A TRUNCATION.** It returns the whole
  string whichever part of it was drawn. An assertion that a name "appears on
  screen" passes while the reader sees "Main Gate …". Use
  `RenderParagraph.didExceedMaxLines` — which is exactly what the harness's
  cut-off report is built on.
- **Ask a `RenderParagraph` anything only after checking `hasSize` and
  `!debugNeedsLayout`.** A paragraph in a subtree that was built but never laid
  out — a `LayoutBuilder` branch that lost, an offstage route — throws
  *"RenderBox was not laid out"*, and the throw comes out of the RENDER rather
  than out of the report.
- **A render that passes alone and fails in the suite is a CLOCK or an image
  cache**, not a flake. `MlTime.debugClock` and `precacheImage` handle both.
- **Restore `FlutterError.onError` INSIDE the helper, never in an
  `addTearDown`.** Tear-downs run *after* the body's `expect`s, and the binding
  then asserts *"a test overrode FlutterError.onError but either failed to
  return it to its original state…"* and **times the whole file out at ten
  minutes**.
- **A sabotage that does not restore the ORIGINAL code proves nothing.** Put
  the original expression back verbatim, not something near it.
- 🚨 **A PHONE RENDER FRAME MUST BE TALL ENOUGH FOR THE WHOLE SCROLL, AND
  "TALL ENOUGH" IS A MEASUREMENT.** Zero slack means clipped, not "exactly
  right". Five frames were clipping this session.
- 🚨 **AND WHEN YOU MEASURE IT, IGNORE THE RIGHT-HAND EDGE.** A phone's FAB is
  PINNED to the bottom of the viewport and sits on the right, so a full-width
  measurement reports "content reaches the bottom bar" at ANY height and never
  converges. Measure over `x in [20, 200]`. The first pass at this read the
  fleet screen's floating "+" as content and left the frame 1,300px too tall.
  A frame exactly 915 tall is the real phone viewport and is correct for a
  dialog, the login page, or any page whose content genuinely fills a screen.
- **A whitelist is the wrong shape for "tell me what went wrong."** `shoot()`
  reports everything now.
- 🚨 **A SCREEN THAT PHOTOGRAPHS AN ERROR CARD IS NOT A SCREEN PHOTOGRAPHED.**
  The company profile was written, the render was produced and the suite was
  green while the picture read `PostgrestException(message: , code: 400 …)`.
  Look at every new PNG before counting it.
- 🚨 **A FIXTURE THAT SAYS LESS THAN THE SERVICE IT STANDS IN FOR PHOTOGRAPHS
  AS A PRODUCT FAULT.** `partnerCompaniesProvider`'s override handled `'buyer'`
  and `'transporter'` and fell through everything else to the mines — but the
  reconciliation screens ask with `orgFilter: ''`, which the real service reads
  as *every* partner. Three renders said "Unknown company → Unknown company"
  and it looked like a bug in the product. **Read the service before writing
  the fixture, including its empty/default case.**
- 🚨 **AN OVERRIDE LIST THAT DOES NOT REACH THE SCREEN IS THE SAME FAULT.**
  Those three renders passed `portalCaptureOverrides()` and the partner fixture
  lives in `portalTailOverrides()`. Check which list a render actually composes.
- 🚨 **A RENDER HARNESS CAN LIE ABOUT THE CHROME.** For 118 renders the shell's
  title and subtitle were the reverse of what `PortalShellLayout` builds. It
  looked fine, and it made a duplicated title impossible to see. **When a
  picture is the evidence, the frame around it is part of the claim.**

### Where the reasoning lives

- `docs/redesign/DESIGN.md` — decisions and what each cost. §8 Phase 2, **§9
  the type work, §10 the Phase 4 record**.
- `docs/redesign/VERIFICATION.md` — what was actually executed, and what has
  not been. Its "still open" list is current.
- `docs/design-reference/` — the **pre-redesign** reference PNGs. **Do not
  regenerate them**; they are the before-image.
- `docs/redesign/renders/` — 204 PNGs of the redesign.
- Every commit message carries its own reasoning.

---

## 6. The project's own rules still apply

`CLAUDE.md` in this repo is the fork's copy of the shipping app's. The ones
that keep mattering:

- **§10.4** — a `Row` hands a non-flex child unbounded width. This phase has
  hit it **ten separate times**, plus its siblings: a `Wrap` laid out against
  unbounded width, an `Align` with no `widthFactor`, three tables of `Expanded`
  columns with no minimum, and — the one that dominated this session — **two
  `Flexible` children splitting a row equally when only one of them is long.**
  That family does not raise, and on a desktop it usually looks perfect.
- **§10.5** — a green test over an empty fixture, an error state, or a fallback
  font proves nothing. Report *screens proving something / N*.
- **§7** — `flutter test` renders in a fallback font unless you load the real
  ones. And an overflow figure that looks like `characters × fontSize` is the
  test font, not a layout fault.
- **§7.1** — one clock, Africa/Johannesburg. `MlTime`, never `DateTime.now()`
  for anything a user reads as a date, a time, or a number bucketed by day.
  Four guards and `tool/one_clock_check.py` hold the places a unit test cannot.
  **And a value's KIND matters as much as its zone**: `MlTime.sast()` returns a
  wall clock, and measuring a duration with one is the bug `MlPresence` exists
  to end.
- **§10.6** — Dart bitwise operators are unsigned 32-bit on the web.
- **§1** — the package is `flutter_application_1`. Do not rename it.

---

## 7. The message to start the next session with

Jean pastes this into a fresh chat. It is kept here so it cannot be lost with a
conversation. The copy-paste block is §8.

---

## 8. COPY-PASTE MESSAGE FOR THE NEXT CHAT

```
Continue the MineLink Material 3 redesign. Read both of these before doing
anything else, in this order:

1. C:\Users\Somebody Someone\Music\SHOWME!\MineLink-M3\HANDOFF.md
   — THE CURRENT HANDOFF, rewritten 2026-08-21 (fourth rewrite that day). This
   is the file that governs the work. Start at the section headed "WHERE THE
   LAST SESSION STOPPED — READ THIS FIRST", then §0, §2, §4 and §5. It has the
   verified baseline of the untouched original, what has been done across 82
   commits, what is verified green, and exactly what is left.
2. C:\Users\Somebody Someone\Claude\HANDOFF.md
   — the older machine-wide handoff from 2026-08-08 (MCP servers, git position,
   decoy folders). Background only; the MineLink-M3 one above governs this work.

THE ONE RULE THAT MUST NOT BREAK: nothing whatsoever changes inside
C:\Users\Somebody Someone\Music\SHOWME!\worktree-2026-05-05T11-53-29. Its
verified baseline is in §0 of the MineLink-M3 handoff — check it at the start
and again at the end. All work happens in
C:\Users\Somebody Someone\Music\SHOWME!\MineLink-M3, which is a separate git
repo (branch `main`).

WHERE TO PICK UP: the tree is clean, 82 commits, and the whole gate is green.
BOTH of the lists the last three sessions worked from are now EMPTY — every one
of the 93 route-target screens has a picture (`py -3
tool/unphotographed_screens.py` reports 93/93/0), and so does every dialog and
the five-step due-diligence gate. The last session also took the harness's new
cut-off report from 137 truncated strings down to 6, and those 6 are deliberate
and documented in place.

So there are three things left worth doing, in this order:

  1. LIGHT MODE. Nine renders out of 204 are light. Add a light render for
     every screen that has a dark one, regenerate, and read the new pictures —
     contrast is the thing to watch, because MlTone's fg/bg pairs resolve per
     brightness and a hue that reads on navy can vanish on #EEF2F8. This is the
     largest unexamined surface in the project. (§4.1)

  2. READ ALL 204 PICTURES, end to end. Nobody has. The cut-off report finds
     text that did not fit; it cannot see a misaligned column, a hue that means
     the wrong thing, an empty state that should not be empty, or a heading
     that disagrees with its body. Reading pictures is what found every defect
     before the last session. (§4.2)

  3. REAL HARDWARE. Nothing has ever run on a handset or been driven in a
     browser against the live database as a signed-in user. Jean's phone can be
     driven — the `driving-jeans-phone` skill in the global CLAUDE.md has the
     commands and the rules. This is the biggest single gap in the project.
     (§4.5)

Do NOT re-run the six searches the handoff's opening section records as already
finished.

THE METHOD, unchanged: fixtures, regenerate, LOOK at the PNG, MEASURE it with
PIL rather than squint, fix the shape rather than the instance where the fault
is structural, then pin it with a test and prove the test bites by removing the
fix and watching it fail. Read the render run's OUTPUT too, not just its exit
code — it prints RENDER NOTE for framework errors and CUT OFF for every string
that did not fit, with the paragraph's width and the widgets around it.

Watch for the faults every batch has had: a screen inside a ShellRoute that
builds its own Scaffold+AppBar (held by a test, so it should stay dead); a
screen that reads a service or repository directly so no provider override
reaches it (it photographs an error card); a FIXTURE that says less than the
service it stands in for (three renders read "Unknown company" for exactly
that reason); an override list that does not reach the screen; a wire enum
value reaching a reader; and a Row handing a non-flex child unbounded width —
including its commonest form, two Flexible children splitting a row equally
when only one of them is long.

HOW TO WORK: don't worry about me seeing anything, I'll want to see when
everything is complete and done, so don't stop so much in between — please run
the task for as long as possible so that we can get this completely done and
sorted please. Correct yourself where you make mistakes and fix the mistakes,
and make sure you don't implement anything with gaps in them — make sure it's
full and proper like the original.

OPTIONAL: if the Windows build gives trouble, just carry on with web and mobile.

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
this repo — so you don't repeat them. Six of them cost real time and are worth
knowing before you touch anything: `git checkout -- <dir>` threw away three
finished uncommitted fixes; a bash heredoc ate backslashes even when quoted and
broke a patch in two separate sessions (write such scripts with the Write tool);
`flutter analyze` output is not reliably indented so grepping it reported clean
while a warning was printed (use `| tail -4`); a long && chain ending in a
git commit heredoc TIMES OUT at two minutes (write the message to a file and
commit with -F); a phone render frame with zero slack above the bottom bar is
CLIPPING, not "exactly right"; and when you measure that slack you must ignore
the right-hand edge, because the FAB is pinned to the viewport and makes the
measurement never converge.

When the work is done, rewrite
C:\Users\Somebody Someone\Music\SHOWME!\MineLink-M3\HANDOFF.md the same way
this one was written — verified state only, with a fresh copy-paste block in
§8 — and commit it.
```
