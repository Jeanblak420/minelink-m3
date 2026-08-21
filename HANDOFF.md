# MineLink M3 — session handoff

**Rewritten 2026-08-21.** Everything below is verified state, not intention. It
replaces the previous handoff of the same name; the parts of that one still true
have been folded in.

**This file lives at**
`C:\Users\Somebody Someone\Music\SHOWME!\MineLink-M3\HANDOFF.md`

---

## WHERE THE LAST SESSION STOPPED — READ THIS FIRST

The work is **mid-Phase-4** and stopped at a clean, committed, fully green
point. Nothing is half-applied and nothing is uncommitted.

- **Last two commits: the `console:` one ("the tail, and a card that was never
  a Material") and the `docs:` one on top of it.** Working tree clean. Run
  `git log --oneline -3` — no hash is written down here, because a hash in a
  file the same commit changes is wrong the moment it lands.
- **The gate was run and is green** (numbers in §2). The original worktree was
  re-checked against its §0 baseline immediately before that commit and is
  **byte-for-byte untouched**.
- **What was in flight:** working through §4.1 — the console tail — screen by
  screen, phone width first, because that is where most remaining defects have
  been. **The console tail is now FINISHED.** The next screen to photograph is
  the first one in §4.1's *portal* list.
- **Two searches that are already finished, so do not redo them:**
  1. `lib/` was scanned twice for any other hand-rolled flex table with the
     compressing shape (a `Row` of three or more `Expanded` cells with uppercase
     header labels; and separately, any file mentioning neither `MlWideTable`
     nor `MlDataTable` that contains a `Row` with three or more `Expanded(flex:`
     children). **Both scans are empty.**
  2. Every `FractionallySizedBox`, every `MapOptions`, every hand-rolled
     "x ago" formatter and every `DateTime.now()`-fed relative time in `lib/`
     was found and routed through a single shared implementation. Three release
     guards now hold each of those lines, so a new one fails the build rather
     than needing another sweep.

---

## 0. Where you are

| | |
|---|---|
| **This project** | `C:\Users\Somebody Someone\Music\SHOWME!\MineLink-M3` |
| What it is | A **complete, independent fork** of MineLink, being redesigned onto Material 3. Its own git repo (`main`), **60 commits**, clean tree. |
| **The original** | `C:\Users\Somebody Someone\Music\SHOWME!\worktree-2026-05-05T11-53-29` — **DO NOT TOUCH IT.** |

### The one rule that must not be broken

**Nothing whatsoever changes inside `worktree-2026-05-05T11-53-29`.** That was
Jean's instruction and it has held for every commit. Its verified baseline,
re-checked at the start and end of every session:

```
HEAD              df451d0
file count        14163
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
`MineLink-M3`. The two trees share no git state — `MineLink-M3` is a plain repo,
not a worktree.

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
  continue with web and mobile please"* — Windows is blocked by two pre-existing
  faults (§6); web and Android both build.
- **Work long, don't stop to check in.** *"don't worry about me seeing
  anything, I'll want to see when everything is complete and done… correct
  yourself where you make mistakes and fix the mistakes and make sure you don't
  implement anything with gaps in them make sure its full and proper like the
  original"*

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
flutter test                                    1768 passed, 1 skipped
dart tool/release_guards.dart                   31/31 PASS, 0 FAIL
dart tool/release_guards.dart --selftest        all guards bite
py -3 tool/type_scale_codemod.py --selftest     OK
py -3 tool/dropdown_width_check.py              passes
py -3 tool/glyph_coverage_check.py              passes
py -3 tool/one_clock_check.py                   0 sites off Africa/Johannesburg
flutter build web --release                     builds
flutter build apk --debug                       builds
docs/redesign/renders/                          87 PNGs, 35 of them phone-width
```

Layout is swept at **8 widths (1612 → 360px) × 6 text scales (0.85 → 2.0)**, and
again **with real rows in every table** at 360/800/1280 by 1.0/1.3, on 22 portal
screens and 4 console screens.

---

## 3. What Phase 4 has done (commits 42–60)

Full reasoning is in each commit message and in `docs/redesign/DESIGN.md` §10.
`git log` is a real record — read it rather than trusting this summary.

**The method, unchanged and still working:** add the screen to
`test/renders/redesign_renders_test.dart` with the fixtures it needs, regenerate,
**look at the PNG**, **measure it with PIL rather than squint**, fix the *shape*
where the fault is structural, pin it with a test, and **prove the test bites**
by removing the fix and watching it fail.

**Renders went 25 → 87.** Every screen photographed turned up a real defect, and
almost all of them share one property: **the fault was a layout that FITS.** An
ellipsis, a word broken in half, a truncated label, a zero-height bar and a
mislabelled figure are all valid layouts. Nothing raises; no overflow sweep
fails. Only a measurement of the painted result sees them.

### 3.1 The 2026-08-21 session, in one list

| where | what the picture showed |
|---|---|
| targets, all three scopes | **every attainment bar in the product was a track and a tick.** A `FractionallySizedBox` with only a `widthFactor`, under a `Stack`'s loose constraints, gives its childless `DecoratedBox` `constraints.smallest` — **zero pixels tall.** The Sep-2025 row reads 82% beside a 315px rail that is one flat colour end to end. Same fault on request tracking and org insights. Inherited from the shipping app. |
| targets by-company | the title read **"Consolidated Mineral Offta…"** — `overflow: ellipsis` with no `maxLines` truncates a paragraph to ONE line, losing the rest of a real registry name AND the word "targets". |
| targets by-company | the picker ran **37px** off the panel (a pill's label Column unflexed in a Row). |
| targets by-org-type | the `ORG TYPE` caption stranded mid-column beside a three-deep pill stack. |
| organisations registry | the token countdown read `102d 09h left` in the morning and `102d 08h left` an hour later — a golden that could not be reproduced, off `DateTime.now()`. |
| audit logs | **the newest three entries all printed "5d ago"** for 22 minutes, 3 hours and 9 hours — nine hand-rolled "x ago" formatters existed, six vocabularies, six of them reading the device clock. |
| audit logs | the action badge ran **20px** past the card at 412px, and the organisation line had no bound at all. |
| account deactivations | **`controllerWB`** — Postgres's vocabulary on an admin's screen, while the list beside it said "Load Controller". |
| token history | **TOKEN_GENERATED** where the audit log said "Token Generated"; `org o1` as a caption; and **no page title at all**. |
| organisation detail | a token countdown ticking to the second under "Status: Suspended", explaining nothing and moving every second. |
| organisation detail | a `ListTile` inside a coloured `Container` — *"ListTile background color or ink splashes may be invisible"* thrown on **every build** in debug, and swallowed by the render harness. |
| live map (and all 5 maps) | **a near-white rectangle in a dark console** wherever a tile has not arrived. |
| company-link picker | 220 fixed pixels for a list of text, in a console with a text-size slider; the third company clipped mid-row. |

### 3.2 The shapes that changed, rather than the instances

- **`heightFactor: 1` on every `FractionallySizedBox`**, stated even where the
  parent already tightens the height, held by
  `fractional-fill-declares-its-height` and measured by
  `test/widgets/meter_fill_is_visible_test.dart`.
- **`MlTime.instant()`** — the real UTC instant, honouring `debugClock`, for
  measuring a duration. `MlTime.now()` is a WALL CLOCK and subtracting it from a
  server timestamp is wrong everywhere except South Africa.
- **`MlTime.ago()` / `MlTime.agoTag()`** — ONE relative-time vocabulary,
  replacing nine, held by `one-vocabulary-for-time-ago`.
- **`UserRole.labelFor()`** and **`AuditLog.actionLabel`** — one place each for
  a displayed role and a displayed audit action.
- **`mlMapBackground(context)`** on all five `MapOptions`, held by
  `map-states-its-background`.
- **`mlTileProviderOverride`** — a `@visibleForTesting` seam, because
  `flutter_cache_manager`'s housekeeping timer fails any widget test that
  renders a map.
- **`MlCard` always provides a `Material`** (`MaterialType.transparency`).
  Untapped cards had none, so every `ListTile` inside one asserted and every
  ripple painted on the page behind the card.
- **`TargetsSelectorField`** — a scope label beside its control, above it below
  560px; shared by both targets scope screens.
- **`shoot()` captures EVERY framework error**, not a whitelist of four phrases.
  The whitelist hid two real defects in two days; the first run after the change
  found a third.

### 3.3 Earlier in Phase 4 (2026-08-20 and before)

`MlColumn.minWidth` + `MlDataTable` honouring it, scaled by the live text
scaler · two-line `MlDataTable` headers and `MlSectionTitle` · the bottom
navigation bar computing its own height · `routingServiceProvider` ·
`MlTime.debugClock` · `pumpForCapture` · `MlStatusBadge.humaniseStatus` ·
`MlWideTable` as the answer to a compressing table · `TargetsBand`'s title row
as a `Wrap` · the sweeps stopped passing over empty states (a second pass with
the capture fixtures installed, which found seven failing screens the day it was
written).

---

## 4. What is NOT done — PICK UP HERE

### 4.1 Screens still without a picture

**Console — FINISHED.** All of it is photographed: dashboard, targets
(platform / org-type / company), disputes, organizations registry, organization
detail, token requests, token history, audit logs, platform users, request
tracking, available routes, route marketplace, crash reports, account
deactivations, live map, recon tables, margin ledger, org insights, the four
request inboxes.

Two console screens are deliberately NOT in the render set, and the reason is
recorded in `super_admin_overflow_sweep_test.dart`: **`SuperAdminCompanyMirrorScreen`**
and **`CompanyEmployeeRegisterScreen`** each need a company object plus a handful
of further providers (the mirror's private search index, live trip positions)
that no fixture builds, so they would photograph an error state rather than a
layout. **Adding those fixtures is a real remaining task** — see §4.5.

**Portal — this is where to continue, in this order:**

1. buyer waybills
2. buyer requests
3. buyer routes & mines
4. mine locations
5. tons-out detail
6. trip detail
7. stockpile detail / audit
8. the three truck-location maps
9. transporter drivers
10. fuel costs
11. drop-off
12. compliance
13. own-company
14. request-transportation (the form itself)

**Shared, after the portal tail:** chat / messages, notifications, profile,
account security, appearance & theme, employee register.

The fixtures for most of these already exist — `portal_capture_fixtures.dart`,
`console_capture_fixtures.dart`, `console_tail_fixtures.dart` and
`nav_fixtures.dart` between them cover the providers. Where one does not, adding
it has repeatedly been the thing that found the defect (see `kFleetStatus`,
`vehicleDriversProvider`, `requestTrackingProvider`, `assignedDriverId`,
`organizationDetailProvider`, `orgConnectionsProvider`).

### 4.2 Dialogs and flows nothing has photographed

`shoot()` takes an `act:` callback, so an interaction can happen before the
picture is taken (used for opening a request, and for expanding the token
history's group). Nothing yet photographs:

- the **due-diligence gate** — preview → "are you sure" → the green tick → the
  transporter list → the final confirm. It needs an `approved` request and a
  sequence of taps.
- the **Record Load sheet** (tare/gross, seal photos, wayslip).
- the **hazard report sheet**, the **quality-cert dialog**, the **invoice
  capture dialog**, the **add-vehicle dialog**.

`test/test_helpers/dialog_sweep.dart` and `form_dialog_overflow_sweep_test.dart`
already sweep dialogs for overflow; what is missing is pictures.

### 4.3 Decisions waiting on Jean

1. **The margin ledger's TOTALS row sums the three per-ton RATE columns** —
   R 520 + R 638 + R 495 = "R 1,653.00" — a figure with no meaning, printed in
   the same style as the money beside it. The code calls these "the plain column
   totals requested", and the Excel/CSV/PDF export already omits them, so the
   screen and its own export disagree. Left alone because it reads as a
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

### 4.4 The 127 remaining hand-named typefaces

Held by the `typeface-named-by-hand` ratchet, which can only shrink (128 → 127
this session). They are three different things and `DESIGN.md` §9 measures each.
**Not** a gap — a decision — but the ratchet is there so it can be revisited.

### 4.5 Known limitations, stated rather than hidden

- **Nothing has run on real hardware.** No APK on a handset (Jean's phone can be
  driven — see the `driving-jeans-phone` skill in the global `CLAUDE.md`);
  nothing driven against the live database in a browser as a signed-in user; iOS
  not attempted.
- **The map tiles are blank in every render.** Tiles come from OpenStreetMap
  over HTTP and `flutter_test` answers every request with a 400. The route line,
  the puck, the pins, the banner and the HUD are all real; the tiles need a
  device. The map GROUND is now theme-correct, which is what the white-sheet fix
  was about.
- **Two console screens have no fixtures** (company mirror, company employee
  register) — see §4.1.
- **One scrollbar thumb does not appear in one capture.** The company-link
  picker's list paints 1,090 thumb pixels when pumped standalone through
  `pumpForCapture`, and none inside the organisation detail screen, where the
  `Scrollbar` is in the tree and the list reports `maxScrollExtent 32 /
  viewport 220`. `RawScrollbar` reveals its thumb from a one-shot post-frame
  callback registered in `initState`, and on a screen whose picker is built only
  after two futures resolve, that callback and the position attach do not line
  up. The measurement and the reasoning are in
  `company_link_builder.dart`. **Do not read that render as evidence the bar is
  absent.**

### 4.6 Windows — blocked, and not this project's fault

Two independent pre-existing faults, both recorded with exact errors in
`docs/redesign/VERIFICATION.md`:

1. The Flutter tool **refuses the path outright** because of the `!` in
   `SHOWME!`. The canonical shipping tree is under the same folder, so it cannot
   have been built from there either.
2. From a clean path it reaches CMake, which fails on two consecutive clean runs
   extracting `firebase_cpp_sdk_windows_12.7.0.zip` for `firebase_core`. Same
   dependency, same version, in the shipping app.

Jean said to skip it. Moving the folder to a path without `!` is his call.

---

## 5. How to work in this repo

```bash
cd "/c/Users/Somebody Someone/Music/SHOWME!/MineLink-M3"

flutter analyze                                  # must be clean
flutter test                                     # 1768 passing
dart tool/release_guards.dart                    # 31/31
dart tool/release_guards.dart --selftest         # every guard must BITE
py -3 tool/type_scale_codemod.py --selftest
py -3 tool/dropdown_width_check.py
py -3 tool/glyph_coverage_check.py
py -3 tool/one_clock_check.py
flutter test test/renders --update-goldens       # after any visual change
flutter build web --release
flutter build apk --debug
```

### Things that have already gone wrong here — do not repeat them

- **`dart format` on a directory reformats files you did not touch.** It did 131
  files once and 106 another time. **The repo is not dart-format clean**, so
  formatting even a single file you edited churns it entirely — measured, 620
  lines for a 14-site change. Emit correctly-formatted code instead.
- **A codemod must not edit prose.** One rewrote the doc comment *explaining* a
  rule into something that no longer said it. It strips comments now.
- **Read AND write files with `newline=''` AND `encoding='utf-8'` in Python.**
  Universal newlines turn a 340-line change into 5,342 insertions, and the
  default Windows codec is cp1252 — which throws on this repo's `—` and `✅`
  and, worse, will happily round-trip other characters into mojibake.
- **Write multi-line Python and commit messages to a FILE.** A bash heredoc
  mangles backticks, `$` and backslashes even when quoted — it corrupted a
  replacement string this session and silently skipped one edit, and a `\n`
  inside a quoted heredoc arrived as a real newline and broke a Dart string.
  `py -3 file.py` and `git commit -F file`.
- **A failing golden comparison can mask a failing test.** Delete the golden and
  re-run to see the real error.
- **`git add -A` sweeps `test/renders/failures/`** — golden-comparison scratch.
  It is `.gitignore`d now.
- **Never `git stash`, `git checkout -- .`, or `git clean`** in the original
  worktree — other agent sessions write it (`CLAUDE.md` §10.1).
- **A Windows console is cp1252** and cannot encode the characters these tools
  talk about. Both Python checks force UTF-8 on stdout.
- **`find.text` cannot see a `TextSpan`.** Two tests were written against `Text`
  and silently measured nothing. Walk `RenderParagraph` and read
  `toPlainText()` — `console_tail_test.dart` has the helper.
- **A render that passes alone and fails in the suite is a CLOCK or an image
  cache**, not a flake. `MlTime.debugClock` and `precacheImage` handle both. If
  a golden differs run-to-run, something is reading `DateTime.now()`.
- **Restore `FlutterError.onError` INSIDE the helper, never in an
  `addTearDown`.** Tear-downs run *after* the body's `expect`s, and the binding
  then asserts *"a test overrode FlutterError.onError but either failed to
  return it to its original state…"* and **times the whole file out at ten
  minutes**, reporting every other test in it as "did not complete".
- **A sabotage that does not restore the ORIGINAL code proves nothing.** Put the
  original expression back verbatim, not something near it.
- **A phone render frame must be tall enough for the whole scroll.** Measure it:
  render at a deliberately oversized frame, find the last row of painted content
  with PIL, add the 142px the pinned bottom bar occupies. Reasoning from a
  band's extra height came out 173px short and put four months of a table under
  the bottom bar — a picture of a screen that looks finished.
- **A whitelist is the wrong shape for "tell me what went wrong."** `shoot()`
  captured four phrases and swallowed everything else; that hid two
  every-build assertions. It reports everything now.

### Where the reasoning lives

- `docs/redesign/DESIGN.md` — decisions and what each cost. §8 Phase 2, **§9 the
  type work, §10 the Phase 4 record**.
- `docs/redesign/VERIFICATION.md` — what was actually executed, and what has not
  been. Its "still open" list is current.
- `docs/design-reference/` — the **pre-redesign** reference PNGs, committed in
  the baseline commit. **Do not regenerate them**; they are the before-image,
  and they are the thing to measure against when a treatment is in doubt.
- `docs/redesign/renders/` — 87 PNGs of the redesign.
- Every commit message carries its own reasoning.

---

## 6. The project's own rules still apply

`CLAUDE.md` in this repo is the fork's copy of the shipping app's. The ones that
keep mattering:

- **§10.4** — a `Row` hands a non-flex child unbounded width. This phase hit it
  **six separate times**, plus its siblings: a `Wrap` laying out against
  unbounded width, two flex children splitting a row that should have had one,
  and **three tables of `Expanded` columns with no minimum**, which compress to
  unreadable rather than overflow. That last shape is the one that keeps hiding:
  it does not raise, and on a desktop it looks perfect.
- **§10.5** — a green test over an empty fixture, an error state, or a fallback
  font proves nothing. Report *screens proving something / N*.
- **§7** — `flutter test` renders in a fallback font unless you load the real
  ones. If an overflow figure looks like `characters × fontSize`, that is why.
- **§7.1** — one clock, Africa/Johannesburg. `MlTime`, never `DateTime.now()`.
  Two source guards and `tool/one_clock_check.py` hold the places a unit test
  cannot.
- **§10.6** — Dart bitwise operators are unsigned 32-bit on the web.
- **§1** — the package is `flutter_application_1`. Do not rename it.

---

## 7. The message to start the next session with

Jean pastes this into a fresh chat. It is kept here so it cannot be lost with a
conversation.

---

Continue the MineLink Material 3 redesign. Read both of these before doing
anything else, in this order:

1. `C:\Users\Somebody Someone\Music\SHOWME!\MineLink-M3\HANDOFF.md`
   — the current handoff, rewritten 2026-08-21. Start at the section headed
   **"WHERE THE LAST SESSION STOPPED — READ THIS FIRST"**, then §0, §2, §4
   and §5.
2. `C:\Users\Somebody Someone\Claude\HANDOFF.md`
   — the older, machine-wide handoff from 2026-08-08 (MCP servers, git position,
   decoy folders). Background only; the MineLink-M3 one above governs this work.

**THE ONE RULE THAT MUST NOT BREAK:** nothing whatsoever changes inside
`C:\Users\Somebody Someone\Music\SHOWME!\worktree-2026-05-05T11-53-29`. Its
verified baseline is in §0 of the MineLink-M3 handoff — check it at the start
and again at the end. All work happens in `MineLink-M3`, which is a separate git
repo.

**Where to pick up:** the tree is clean and the gate is green. The last two
commits are the `console:` one and the `docs:` one on top of it — read them,
they carry their own reasoning. **The console tail is FINISHED.** Continue at
HANDOFF §4.1's *portal* list, in the order given: buyer waybills, buyer
requests, buyer routes & mines, mine locations, tons-out detail, trip detail,
stockpile detail/audit, the three truck-location maps, transporter drivers, fuel
costs, drop-off, compliance, own-company, request-transportation. Then the
shared screens, then §4.2's dialogs — one screen at a time, phone width first,
because that is where most remaining defects have been.

Do NOT re-run the two searches §4.1's opening records as finished.

**The method, unchanged:** fixtures, regenerate, **LOOK at the PNG**, **MEASURE
it with PIL rather than squint**, fix the *shape* rather than the instance where
the fault is structural, then pin it with a test and **prove the test bites** by
removing the fix and watching it fail. Every screen photographed so far has
turned up a real defect.

**How to work:** don't worry about me seeing anything, I want to see when
everything is complete and done, so don't stop so much in between — please run
the task for as long as possible so that we can get this completely done and
sorted. Correct yourself where you make mistakes and fix the mistakes, and make
sure you don't implement anything with gaps in them — make it full and proper
like the original.

**Windows is optional:** if the Windows build gives trouble, just carry on with
web and mobile.

**Before claiming anything is done, all of these must be green:**

```
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
```

Read **§5** of the MineLink-M3 handoff (the things that have already gone wrong
in this repo) so you don't repeat them.
