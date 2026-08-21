# MineLink M3 — session handoff

**Rewritten 2026-08-21 (fifth rewrite that day).** Everything below is verified
state, not intention. It replaces the previous handoff of the same name; the
parts of that one still true have been folded in.

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

- **`git status` is empty. 91 commits** (this file's commit included). No hash
  is written down, because a hash in a file the same commit changes is wrong
  the moment it lands.
- **The whole gate was run for real at the end of this session** (numbers in
  §2), including `flutter build web --release` and `flutter build apk --debug`.
- **The original worktree was re-checked against its §0 baseline** and is
  **untouched** — HEAD `df451d0`, the three pre-existing modified files, two
  worktree entries, and **nothing on disk modified today**.

**The two lists this phase worked from are both empty and have been for two
sessions**: 93 of 93 route-target screens photographed, every dialog and the
five-step due-diligence gate too. What replaced them is a different kind of
work, and it is worth understanding before picking anything up.

### The three things the harness now reports on every render

A person forgets to look. These do not, and each was added after the fault it
finds had already slipped through a session that was looking.

1. **`CUT OFF`** — every string the layout had to truncate, with the
   paragraph's own width and the nearest named widgets around it. Found **137**.
   Now **6**, and the 6 are deliberate (three crash-report exception strings,
   three chat message previews), documented in the render file itself.
2. **`FAILURE STATE`** — any render showing `MlLoadFailure`,
   `PortalCompanyRequired`, or text carrying the product's failure vocabulary.
   **Zero across all 218 renders**, and the check is sabotage-proven.
3. **`RENDER NOTE`** — framework errors, captured and reported rather than
   thrown. Zero.

**Read the render run's output, not just its exit code.** All three print and
none of them fail the build, deliberately: a render file that fails on a
deliberate truncation teaches people to add exclusions rather than to look.

### And the colour layer is measured now, not looked at

`test/design/token_contrast_test.dart` measures **every colour pair the
product can put text on, in both brightnesses**, against WCAG AA — 24 tests
over four palettes (`MlSemantic`/`MlTone`, `MlGlass`, `MlOv`, `MlAuth`), with
alpha backgrounds composited onto the surface they are really painted on.

This one **fails** rather than reports: there is no case where an unreadable
status pill is the intent.

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
   (13 found); every private copy of the presence rule (4); every
   `DateTime.now()` written to ISO through a local variable (2).
5. Every rendered screen scanned for CUT text and for FAILURE states, at every
   width and both themes, **by the harness, on every run**.
6. Every phone frame measured for clipping and for dead space. All 100 fit.
7. Every hand-rolled `dd MMM` month table in `lib/` (4 found, all dropped the
   year, all routed through `MlTime.listDay`).
8. Every `Container(alignment:)` with no width cap (29 found; one was the
   fault, the rest are legitimate fills).

---

## 0. Where you are

| | |
|---|---|
| **This project** | `C:\Users\Somebody Someone\Music\SHOWME!\MineLink-M3` |
| What it is | A **complete, independent fork** of MineLink, being redesigned onto Material 3. Its own git repo (`main`), **91 commits**, clean tree. |
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

Check it with:

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
untouched tree; the baseline is quoted against the `-prune` form.

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
flutter test                                    1972 passed, 1 skipped
dart tool/release_guards.dart                   35/35 PASS, 0 FAIL
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
test/design/token_contrast_test.dart            24 tests, 4 palettes, both themes
```

Layout is swept at **8 widths (1612 → 360px) × 6 text scales (0.85 → 2.0)**,
and again **with real rows in every table** at 360/800/1280 by 1.0/1.3.

---

## 3. What Phase 4 has done

Full reasoning is in each commit message and in `docs/redesign/DESIGN.md` §10.
`git log` is a real record — read it rather than trusting this summary.

### 3.1 The 2026-08-21 sessions, in one list

- **§4.1 finished** — 93/93 route-target screens, across five sessions.
- **§4.2 finished** — ten dialogs plus the five-step due-diligence gate.
- **137 truncated strings → 6.** A cell **6px** wide holding a waybill number;
  `55,34…` for the TONS figure on the console's front page; `R40,920.00` in
  76px; buttons reading `Dis…`; a dropdown's options cut in a menu nobody had
  opened; `Iron Hills Mining → Richards Bay` cut on a **1600px desktop** in six
  places; company names, person names, and every card that names two parties.
- **Every phone frame measured.** 5 were clipping, 63 had up to 1,260px of
  dead ground. All 100 now sit between 30 and 200px of slack, or are exactly
  915 — the real phone viewport.
- **The colour layer measured** in four palettes and both themes. In light
  mode every border and divider was **1.13–1.18:1** — the cards had no edges.
  The console's own ink ladder bottomed out at **1.64:1**, and the sign-in
  screen's at 2.01:1.
- **The leaderboard's winner card**, rendered in light for the first time, drew
  its rank, its tonnage and its share line at **2.2:1** — a mid teal on a mid
  teal. That one is invisible to a token audit: both colours are fine on the
  surfaces the palette knows about, and only a gradient the widget builds
  itself puts them together.
- **A render that photographed an error card** for four sessions inside the
  93/93.
- **Eight faults found by reading the pictures**, including a page button
  drawn as a 1,200px bar, a waybill list that read as mis-sorted, a "route"
  that was a commodity, a net that was a dash beside its own two operands, and
  the one screen that never got the redesign's card vocabulary.

### 3.2 The shapes, rather than the instances

Five rules did nearly all of the layout work:

1. **A `Wrap` where two `Flexible`s were splitting a row.** Two flex children
   share free space EQUALLY whatever they hold, so the longer of two names is
   cut to the shorter one's width even when the row has room to spare. **A
   `Spacer` is an `Expanded(flex: 1)`** and counts as the second one — that is
   how a breadcrumb got 122px of a 1600px header.
2. **A second line where the value is an IDENTITY rather than a preview.** A
   company, a route, a person, a waybill number, a caption that says what a
   figure means. A message preview and an exception string are not.
3. **A declared `MlColumn.minWidth` where the figure is the point of the
   screen.** `MlDataTable` widens its scroll floor until every column that
   declared a minimum gets it, so the table SCROLLS rather than eats the
   number.
4. **`Align(widthFactor: 1)`, never `Container(alignment:)`,** for anything
   meant to hug its content. A Container given an alignment lays its child out
   in an `Align`, and an `Align` with no `widthFactor` takes the largest size
   its constraints allow.
5. **Stack the row below a threshold** when a header carries words AND
   controls. Six 36px buttons and a pill do not fit beside a breadcrumb at
   412px, and nothing in the box model will make them.

And one measuring habit: **`test/renders/measure_strings_test.dart`** lays a
string out in the real font and prints what it measures (`ML_RULER=1`). It
exists because one search field was widened twice on arithmetic and cut both
times.

### 3.3 Earlier in Phase 4

- **One page ground** — 83 dark pages on `#060B15`, 7 light on `#EEF2F8`, held
  by `one_page_ground_under_the_shell_test.dart`.
- **Two structural shell faults** — a canvas that stopped short of a phone
  screen, and an `AnimatedSwitcher` `Stack` needing `StackFit.passthrough`.
  Between them, 23 seams and 18 two-tone pages.
- **One clock** — `MlTime` everywhere, four guards and `one_clock_check.py`.

---

## 4. What is NOT done — PICK UP HERE

### 4.1 Real hardware. This is the biggest remaining gap in the project.

**Nothing has ever run on a handset, and nothing has been driven in a browser
against the live database as a signed-in user.** Every claim in this file is a
claim about a headless render or a unit test.

Jean's phone can be driven — the `driving-jeans-phone` skill in the global
`CLAUDE.md` has the commands, the APK-install route and the privacy rules.
`flutter build apk --debug` succeeds today, so there is an artifact to install.

What only a device can settle: touch targets under a real thumb, the
foreground-service behaviour during a drive, real GPS, the map tiles (blank in
every render — `flutter_test` answers every HTTP request with a 400), keyboard
insets over the forms, and whether the type scale reads at arm's length in
daylight.

### 4.2 Light mode has 22 renders out of 218

Up from nine, and the colour layer underneath is now measured in both
brightnesses — so what remains is **shape**, not hue: a widget that assumes a
dark ground in a way the token audit cannot see. The leaderboard's winner card
was exactly that and it took a picture to find.

Thirteen light twins were added, one per widget family. `shootConsole` takes a
`brightness` now, so a console screen's light twin is one line.

### 4.3 Decisions waiting on Jean

1. **The margin ledger's TOTALS row sums the three per-ton RATE columns** —
   R 520 + R 638 + R 495 = "R 1,653.00" — a figure with no meaning, printed in
   the same style as the money beside it. The Excel/CSV/PDF export already
   omits them, so the screen and its own export disagree. Left alone because it
   reads as a deliberate instruction. Say the word and it becomes a dash or a
   tonnage-weighted average.
2. **The targets history renders a variance of exactly zero as `+0 t`, in
   green.** Green for on-target is right; the `+` on a genuine zero is not.
3. **`AuditLog.actionLabel` title-cases every word**, so
   `USER_ASSIGNED_TO_SEAT` reads "User Assigned To Seat".
4. **`Recon`, `Requests` and `Docs`** are the phone bottom bar's short forms
   for Reconciliation, Procurement and Compliance.
5. **The notification body "2 full load(s) ready …" is written by the
   DATABASE**, and `supabase/` is frozen here. Every other parenthesised plural
   in the product is gone; this one needs a migration in the shipping app.
6. **NEW: there are two chat surfaces.** `messages_screen.dart` and
   `chat_screen.dart` both render a full thread, with different composers and
   different chrome. Their wording is aligned now, but they are still two
   implementations of one thing. Merging them is a refactor, not a redesign
   pass — say the word.

### 4.4 The 127 remaining hand-named typefaces

Held by the `typeface-named-by-hand` ratchet, which can only shrink. Three
different things; `DESIGN.md` §9 measures each. **Not** a gap — a decision.

### 4.5 Known limitations, stated rather than hidden

- **The map tiles are blank in every render.** The route line, the puck, the
  pins, the banner and the HUD are all real; the tiles need a device. The map
  GROUND is theme-correct.
- **The `dd MMM yyyy` date sites were deliberately NOT consolidated.** 18 of
  them, all agreeing with `MlTime.day()` character for character, several
  formatting a value whose provenance must be read before converting (instant
  vs already-converted wall clock). The `one-vocabulary-for-a-timestamp` guard
  deliberately does not match a date-only pattern for that reason.
- **The chat models hold INSTANTS.** If another surface starts reading one of
  those fields it must go through `MlTime.clock/stamp/day`, not `DateFormat`.
- **Six strings are still cut, on purpose** — three crash-report exception
  messages and three chat message previews. The render file says so in place.
- **Some fixtures are deliberately EMPTY.** The operations hub's ledgers are
  the documented example: "a fixture where every tab is full hides the empty
  states, and an empty state is a design that has to be looked at like any
  other". Do not "fix" those by filling them.

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
flutter test                                     # 1972 passing, 1 skipped
dart tool/release_guards.dart                    # 35/35
dart tool/release_guards.dart --selftest         # every guard must BITE
py -3 tool/type_scale_codemod.py --selftest
py -3 tool/dropdown_width_check.py
py -3 tool/glyph_coverage_check.py
py -3 tool/one_clock_check.py
py -3 tool/unphotographed_screens.py             # what still has no picture
flutter test test/design/token_contrast_test.dart
flutter test test/renders --update-goldens       # after any visual change
ML_RULER=1 flutter test test/renders/measure_strings_test.dart
flutter build web --release
flutter build apk --debug
```

### Things that have already gone wrong here — do not repeat them

- 🚨 **`git checkout -- <dir>` THREW AWAY UNCOMMITTED WORK**, including three
  finished, unrelated fixes in the same directory. Copy to the scratchpad
  first, or commit before running any codemod that might need undoing. (To
  sabotage-test a fix, `cp file /tmp/x.bak` first and `cp` it back — that
  restores the ORIGINAL verbatim, which a hand-retype does not.)
- 🚨 **A BASH HEREDOC EATS BACKSLASHES EVEN WHEN QUOTED.** It has now broken a
  patch in THREE separate sessions: `\\n` became a real newline inside a Dart
  string, and `\'` inside a Python literal became `'` and killed the parse.
  **Write any script containing a backslash with the Write tool**, or use
  Edit for the edit itself.
- **Several files have MIXED line endings.** Read and write with `newline=''`
  and translate your own literals with `if '\r\n' in s`.
- 🚨 **`flutter analyze` output is not reliably indented.** Grepping it
  reported **clean while a warning was printed**. Use `| tail -4`.
- 🚨 **A LONG `&&` CHAIN ENDING IN `git commit -F <heredoc>` TIMES OUT** at the
  Bash tool's two minutes. Write the message to a file and commit with `-F` as
  its own command.
- **`dart format` on a directory reformats files you did not touch** (131 once,
  106 another time). The repo is not dart-format clean. Emit correctly
  formatted code instead.
- **A codemod must not edit prose.** One rewrote the doc comment *explaining* a
  rule into something that no longer said it.
- **Read AND write with `newline=''` AND `encoding='utf-8'` in Python.**
  Universal newlines turned a 340-line change into 5,342 insertions, and
  cp1252 will round-trip this repo's `—` and `✅` into mojibake.
- **A failing golden comparison can mask a failing test.** Delete the golden
  and re-run to see the real error.
- **Never `git stash`, `git checkout -- .`, or `git clean`** in the original
  worktree — other agent sessions write it (`CLAUDE.md` §10.1).
- **`find.text` cannot see a `TextSpan`.** Walk `RenderParagraph` and read
  `toPlainText()`.
- 🚨 **AND `toPlainText()` CANNOT SEE A TRUNCATION.** It returns the whole
  string whichever part of it was drawn. Use `RenderParagraph.didExceedMaxLines`
  — which is what the harness's cut-off report is built on.
- **Ask a `RenderParagraph` anything only after checking `hasSize` and
  `!debugNeedsLayout`.** A paragraph in a subtree that was built but never laid
  out throws "RenderBox was not laid out", and the throw comes out of the
  RENDER rather than out of the report.
- **A render that passes alone and fails in the suite is a CLOCK, an image
  cache, or a REAL SOCKET.** The employee profile's realtime provider opened
  postgres_changes channels on the live client: green alone, "A Timer is still
  pending even after the widget tree was disposed" in the suite. A screen
  fixture has to stub the LIVE half as well as the read half.
- **Restore `FlutterError.onError` INSIDE the helper, never in an
  `addTearDown`** — the binding asserts and times the file out at ten minutes.
- **A sabotage that does not restore the ORIGINAL code proves nothing.**
- 🚨 **A PHONE RENDER FRAME MUST BE TALL ENOUGH FOR THE WHOLE SCROLL, AND
  "TALL ENOUGH" IS A MEASUREMENT.** Zero slack means clipped.
- 🚨 **AND WHEN YOU MEASURE IT, IGNORE THE RIGHT-HAND EDGE.** A phone's FAB is
  PINNED to the viewport and sits on the right, so a full-width measurement
  reports "content reaches the bottom bar" at ANY height and never converges.
  Measure over `x in [20, 200]`. A frame exactly 915 tall is the real phone
  viewport and is correct.
- 🚨 **A SCREEN THAT PHOTOGRAPHS AN ERROR CARD IS NOT A SCREEN PHOTOGRAPHED.**
  The harness reports these now — but the FIRST version of that check, matching
  widget names, missed the very card that motivated it, because that screen
  hand-built its own error state instead of using `MlLoadFailure`. **A check
  you have not sabotaged is a check you do not have.**
- 🚨 **A FIXTURE THAT SAYS LESS THAN THE SERVICE IT STANDS IN FOR PHOTOGRAPHS
  AS A PRODUCT FAULT.** `partnerCompaniesProvider`'s override fell through an
  EMPTY `orgFilter` to the mines, and three renders read "Unknown company →
  Unknown company". Read the service's default case before writing the fixture.
- 🚨 **AND A FIXTURE THAT SETS TWO DERIVED FIELDS INDEPENDENTLY CAN PRINT AN
  IMPOSSIBILITY.** A profile-setup card read "Expires 01 Mar 2020 · In 12
  days". The server computes one from the other.
- 🚨 **AN OVERRIDE LIST THAT DOES NOT REACH THE SCREEN IS THE SAME FAULT.**
  Forty renders passed `portalCaptureOverrides()` alone and left every provider
  in the TAIL set live. They all go through `allPortalOverrides()` now — tail
  first, capture last, so the capture set keeps its values and the tail only
  fills what nothing was answering.
- 🚨 **A RENDER HARNESS CAN LIE ABOUT THE CHROME.** For 118 renders the shell's
  title and subtitle were the reverse of what `PortalShellLayout` builds. When
  a picture is the evidence, the frame around it is part of the claim.
- **Check whether a test already pins the behaviour you are about to "fix".**
  The fuel screen's two header actions look diagonally opposed in a contact
  sheet; they are not, `WrapAlignment.end` is why, and `portal_tail_test` says
  so with the reasoning attached. That change was made and reverted.

### Where the reasoning lives

- `docs/redesign/DESIGN.md` — decisions and what each cost. §8 Phase 2, **§9
  the type work, §10 the Phase 4 record**.
- `docs/redesign/VERIFICATION.md` — what was actually executed, and what has
  not been.
- `docs/design-reference/` — the **pre-redesign** reference PNGs. **Do not
  regenerate them**; they are the before-image.
- `docs/redesign/renders/` — 218 PNGs of the redesign.
- Every commit message carries its own reasoning.

---

## 6. The project's own rules still apply

`CLAUDE.md` in this repo is the fork's copy of the shipping app's. The ones
that keep mattering:

- **§10.4** — a `Row` hands a non-flex child unbounded width. This phase has
  hit that family a dozen times, and its commonest form by far is **two
  `Flexible` children (or a `Flexible` and a `Spacer`) splitting a row when
  only one of them is long**. It does not raise, and on a desktop it usually
  looks perfect.
- **§10.5** — a green test over an empty fixture, an error state, or a fallback
  font proves nothing. Report *screens proving something / N*.
- **§7** — `flutter test` renders in a fallback font unless you load the real
  ones. An overflow figure that looks like `characters × fontSize` is the test
  font, not a layout fault.
- **§7.1** — one clock, Africa/Johannesburg. `MlTime`, never `DateTime.now()`
  for anything a user reads as a date, a time, or a number bucketed by day.
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
   — THE CURRENT HANDOFF, rewritten 2026-08-21 (fifth rewrite that day). This
   is the file that governs the work. Start at the section headed "WHERE THE
   LAST SESSION STOPPED — READ THIS FIRST", then §0, §2, §4 and §5.
2. C:\Users\Somebody Someone\Claude\HANDOFF.md
   — the older machine-wide handoff from 2026-08-08 (MCP servers, git position,
   decoy folders). Background only; the MineLink-M3 one above governs this work.

THE ONE RULE THAT MUST NOT BREAK: nothing whatsoever changes inside
C:\Users\Somebody Someone\Music\SHOWME!\worktree-2026-05-05T11-53-29. Its
verified baseline is in §0 of the MineLink-M3 handoff — check it at the start
and again at the end. All work happens in
C:\Users\Somebody Someone\Music\SHOWME!\MineLink-M3, which is a separate git
repo (branch `main`).

WHERE TO PICK UP: the tree is clean, 91 commits, and the whole gate is green.
Every route-target screen, every dialog and the due-diligence gate have
pictures (93/93/0). The harness now reports, on every render, every string it
had to CUT OFF (137 → 6, and the 6 are deliberate), every FAILURE STATE (zero
across 218 renders) and every framework error (zero). The colour layer is
measured against WCAG AA in four palettes and both themes.

So the work left is, in this order:

  1. REAL HARDWARE — the biggest remaining gap by far. Nothing has ever run on
     a handset or been driven in a browser against the live database as a
     signed-in user; every claim in the handoff is about a headless render.
     `flutter build apk --debug` succeeds, so there is something to install,
     and my phone can be driven — use the `driving-jeans-phone` skill in the
     global CLAUDE.md, it has the commands and the rules. (§4.1)

  2. LIGHT MODE SHAPE — 22 renders of 218 are light. The colour layer is
     measured now, so what is left is a widget that assumes a dark ground in a
     way a token audit cannot see: the leaderboard's winner card drew its rank
     and its tonnage at 2.2:1 on a gradient it builds itself, and only a
     picture found it. `shootConsole` takes a `brightness`, so a light twin is
     one line. (§4.2)

  3. THE SIX DECISIONS IN §4.3 that are waiting on me — including the margin
     ledger's meaningless TOTALS row and the two chat implementations.

Do NOT re-run the eight searches the handoff's opening section records as
already finished.

THE METHOD, unchanged: fixtures, regenerate, LOOK at the PNG, MEASURE it with
PIL rather than squint, fix the shape rather than the instance where the fault
is structural, then pin it with a test and prove the test bites by removing the
fix and watching it fail. Read the render run's OUTPUT too, not just its exit
code.

Watch for the faults every batch has had: a screen inside a ShellRoute that
builds its own Scaffold+AppBar; a screen that reads a service directly so no
override reaches it; a FIXTURE that says less than the service it stands in for,
or that sets two derived fields independently and prints an impossibility; an
override list that does not reach the screen; a wire enum value reaching a
reader; and a Row handing a non-flex child unbounded width — including its
commonest form, two Flexible children (or a Flexible and a Spacer) splitting a
row when only one of them is long.

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
this repo — so you don't repeat them. The ones that have cost real time more
than once: `git checkout -- <dir>` threw away three finished uncommitted fixes;
a bash heredoc has eaten backslashes and broken a patch in three separate
sessions (write such scripts with the Write tool); `flutter analyze` output is
not reliably indented so grepping it reported clean while a warning printed
(use `| tail -4`); a long && chain ending in a git commit heredoc times out at
two minutes (write the message to a file, commit with -F); a phone render frame
with zero slack above the bottom bar is CLIPPING, and when you measure that
slack you must ignore the right-hand edge because the FAB is pinned there; and
a check you have not sabotaged is a check you do not have — the first version
of the failure-state report missed the very card that motivated it.

When the work is done, rewrite
C:\Users\Somebody Someone\Music\SHOWME!\MineLink-M3\HANDOFF.md the same way
this one was written — verified state only, with a fresh copy-paste block in
§8 — and commit it.
```
