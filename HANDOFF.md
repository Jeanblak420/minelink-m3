# MineLink M3 — session handoff

**Rewritten 2026-08-20, updated 2026-08-21.** Everything below is verified
state, not intention. It replaces the previous handoff of the same name; the
parts of that one still true have been folded in.

---

## WHERE THE LAST SESSION STOPPED — READ THIS FIRST

The work is **mid-Phase-4** and stopped at a clean, committed, fully green point.
Nothing is half-applied and nothing is uncommitted.

- **Last two commits: the `targets:` one ("a board that overflowed 22 times on
  a phone, and a title cut to 'Plat…'") and the `docs:` one on top of it.**
  Working tree clean. Run `git log --oneline -3` — no hash is written down here,
  because a hash in a file the same commit changes is wrong the moment it lands.
- **The gate was run and is green** (numbers in §2). The original worktree was
  re-checked against its §0 baseline immediately before that commit and is
  **byte-for-byte untouched**.
- **What was in flight:** working through §4.1 — the console tail — screen by
  screen, phone width first, because that is where every remaining defect has
  been. The targets board was the last one done. **Continue at §4.1 with the
  next unphotographed console screen** (organization detail, platform users,
  token history, audit logs, available routes, route marketplace, crash reports,
  account deactivations, live map, the company mirror, targets org-type and
  targets company), then the portal tail, then §4.2's dialogs.
- **A search that is already finished, so do not redo it:** `lib/` was scanned
  twice for any other hand-rolled flex table with the compressing shape — a
  `Row` of three or more `Expanded` cells with uppercase header labels, and
  separately any file mentioning neither `MlWideTable` nor `MlDataTable` that
  contains a `Row` with three or more `Expanded(flex:` children. **Both scans
  are now empty.** The three that turned up — the organizations registry, the
  targets "All months" table and the targets "Target history" table — are all
  fixed. A NEW hand-rolled table is still possible; an existing unfixed one is
  not.

---

## 0. Where you are

| | |
|---|---|
| **This project** | `C:\Users\Somebody Someone\Music\SHOWME!\MineLink-M3` |
| What it is | A **complete, independent fork** of MineLink, being redesigned onto Material 3. Its own git repo (`main`), **57 commits**, clean tree. |
| **The original** | `C:\Users\Somebody Someone\Music\SHOWME!\worktree-2026-05-05T11-53-29` — **DO NOT TOUCH IT.** |

### The one rule that must not be broken

**Nothing whatsoever changes inside `worktree-2026-05-05T11-53-29`.** That was
Jean's instruction and it has held for every commit. Its verified baseline,
re-checked at the start and end of this session:

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
flutter test                                    1714 passed, 1 skipped
dart tool/release_guards.dart                   28/28 PASS, 0 FAIL
dart tool/release_guards.dart --selftest        all guards bite
py -3 tool/type_scale_codemod.py --selftest     OK
py -3 tool/dropdown_width_check.py              passes
py -3 tool/glyph_coverage_check.py              passes
flutter build web --release                     builds
flutter build apk --debug                       builds
docs/redesign/renders/                          64 PNGs, 24 of them phone-width
```

⚠️ The two **builds** were last run at commit `ed9ebcd`. Everything since is
test-and-layout work in `lib/features/super_admin/**` and `test/**` with no new
dependency, plugin or platform code, so neither can plausibly have broken — but
re-run both before calling any milestone done, because "cannot plausibly have
broken" is not the same as "was run".

Layout is swept at **8 widths (1612 → 360px) × 6 text scales (0.85 → 2.0)**,
and — new this session — **again with real rows in every table** at 360/800/1280
by 1.0/1.3, on 22 portal screens and 4 console screens.

---

## 3. What Phase 4 did (commits 42–57)

Full reasoning is in each commit message and in `docs/redesign/DESIGN.md` §10.
`git log` is a real record — read it rather than trusting this summary.

**The method, unchanged and still working:** add the screen to
`test/renders/redesign_renders_test.dart` with the fixtures it needs, regenerate,
**look at the PNG**, **measure it with PIL rather than squint**, fix the *shape*
where the fault is structural, pin it with a test, and **prove the test bites**
by removing the fix and watching it fail.

**Renders went 25 → 64.** Every screen photographed turned up a real defect, and
almost all of them share one property: **the fault was a layout that FITS.** An
ellipsis, a word broken in half, a truncated label and a mislabelled figure are
all valid layouts. Nothing raises; no overflow sweep fails. Only a measurement of
the painted result sees them.

### 3.1 The screens that had no picture, and what each one had wrong

| screen | what the picture showed |
|---|---|
| security gate | KPI chips reading "Incoming Tod…"/"Departed Tod…" — and "Incoming Today" was not scoped to today at all |
| weighbridge | heading "Trucks at Mine — Ready for Lo…"; recon table with no scrollbar |
| every phone screen | the bottom nav clipping wrapped labels in **10 of 12 trees** |
| combined recon table | header reading "DELIVER / ED", "VARIAN / CE", "PO / D" |
| combined recon table | five period-total cards showing an icon and the letters D, W, M, Y, T |
| mine reconciliations | one load as `0.42 t` on the stat card and `−0.42 t` in the row beneath |
| margin ledger | `R 141,306.00` rendered as the single character `R` |
| org insights | a row labelled **On-time** fed the waybill-completion rate (91% where the measure said 30%), and 0% where the model demands a dash |
| driver navigation | a crash, a HUD breaking every word, "In 0 m", the destination named twice with the first copy truncated, and an ETA off the device's clock |
| request inboxes | the page title running **157px** past a phone |
| trucks on route | a plate pill 21px past the card at 360 × 1.3 |
| request tracking | the trips cell 10px over at 1024 × 1.3 |
| the dashboards | `29 159 R` — a currency symbol rendered as a unit of measure — and a second thousands separator |
| supervisor stockpiles | 128.254 / 17.98 / 412.131 tons — a count-up caught one frame short |
| token requests | a pill reading **`IN_PROGRESS`**, and "Seat expansion · mineSupplier" — Postgres's vocabulary on an admin's screen |
| organizations registry | **blank on a phone.** Four `Expanded` columns with no minimum gave each ~70px: "Iron …", "MI…", "10…" |
| targets board | **22 overflows at 412px**, and a header reading **"Plat…"** — four characters of "Platform targets" beside 190px of scope tags |

### 3.2 The shapes that changed, rather than the instances

- **`MlColumn.minWidth`** + `MlDataTable` widening its scroll minimum to honour
  it, **scaled by the live text scaler**.
- **`MlDataTable` headers get two lines**; **`MlSectionTitle` gets two lines**.
- **The bottom navigation bar computes its height** from the label style and the
  text scaler, instead of the constant 72 the theme carried.
- **`routingServiceProvider`** — `RoutingService()` was constructed at the call
  site, so the driver's navigation screen could not be handed a route.
- **`MlTime.debugClock`** — one hook freezes the whole product's clock for the
  render harness.
- **`mlConsoleCanvas*` forwards to `MlGlass.bg0`**, and the canvas texture is off
  by default: measured, every design-reference page is a single flat colour.
- **`pumpForCapture`** (`test/test_helpers/render_pumps.dart`) — the settle
  schedule, now shared with the tests that prove it is long enough.
- **`MlStatusBadge.humaniseStatus`** — the factory that says "give me a status"
  now turns `in_progress` into `in progress`. The tone still comes from the RAW
  string, because `toneForStatus` matches on substrings like `sent_back`.
- **`MlWideTable` is now the answer to a compressing table, everywhere.** Three
  screens adopted it (organizations registry, targets "All months", targets
  "Target history"), each with a `minWidth` **derived from the widest cell
  divided by its flex share and scaled by the live text scaler** — never a
  picked number, because the console has a per-admin text-size slider and a
  fixed figure is right only at 1.0.
- **`TargetsBand`'s title row is a `Wrap`.** Tags drop to a second line rather
  than eating the screen's own name.

### 3.3 The sweeps stopped passing over empty states

`portal_overflow_sweep_test.dart` renders every portal screen with **no data**
and says so in its own header. That is half a job — with no rows there is no
plate pill to overflow. A second pass sweeps 22 screens **with the capture
fixtures installed**; it found seven failing screens the day it was written and
two more when it was widened. `super_admin_overflow_sweep_test.dart` now has the
same second pass over four console screens.

---

## 4. What is NOT done — PICK UP HERE

### 4.1 Screens still without a picture

The render set covers the whole daily flow now. What is left is the tail, and
it is genuinely a tail — but each one has been unlooked-at, and the strike rate
on unlooked-at screens this session was 100%.

- **Console — done since:** targets (platform), disputes inbox, organizations
  registry, token requests. **Still without a picture:** targets **org-type**
  and targets **company** (the platform one is photographed; the other two
  scopes carry a selector the platform screen does not, and `TargetsPage`'s
  half-viewport cap exists specifically because the org-type band overflowed),
  organization detail, platform users, token **history**, audit logs, available
  routes, route marketplace, crash reports, account deactivations, live map,
  the company mirror.
- **Portal:** buyer waybills, buyer requests, buyer routes & mines, mine
  locations, tons-out detail, trip detail, stockpile detail/audit, the three
  truck-location maps, transporter drivers, fuel costs, drop-off, compliance,
  own-company, request-transportation (the form itself).
- **Shared:** chat / messages, notifications, profile, account security,
  appearance & theme, employee register.

The fixtures for most of these already exist — `portal_capture_fixtures.dart`,
`console_capture_fixtures.dart` and `nav_fixtures.dart` between them cover the
providers. Where one does not, adding it has repeatedly been the thing that
found the defect (see `kFleetStatus`, `vehicleDriversProvider`,
`requestTrackingProvider`, `assignedDriverId`).

### 4.2 Dialogs and flows nothing has photographed

`shoot()` now takes an `act:` callback, so an interaction can happen before the
picture is taken (used for opening a request). Nothing yet photographs:

- the **due-diligence gate** — preview → "are you sure" → the green tick → the
  transporter list → the final confirm. It needs an `approved` request and a
  sequence of taps.
- the **Record Load sheet** (tare/gross, seal photos, wayslip).
- the **hazard report sheet**, the **quality-cert dialog**, the **invoice
  capture dialog**, the **add-vehicle dialog**.

`test/test_helpers/dialog_sweep.dart` and
`form_dialog_overflow_sweep_test.dart` already sweep dialogs for overflow; what
is missing is pictures.

### 4.3 A decision waiting on Jean

**The margin ledger's TOTALS row sums the three per-ton RATE columns** —
R 520 + R 638 + R 495 = "R 1,653.00" — which is a figure with no meaning, printed
in the same style as the money beside it. The code calls these "the plain column
totals requested", and the Excel/CSV/PDF export already omits them (it summarises
routes, tons and margin earned only), so the screen and its own export disagree.
Left alone because it reads as a deliberate instruction. Say the word and it
becomes a dash or a tonnage-weighted average.

**A second, smaller one, found 2026-08-21 and deliberately left alone.** The
targets history renders a variance of exactly zero as **`+0 t`, in green**
(`variance >= 0 ? '+' : '−'`). Green for on-target is right; the `+` on a
genuine zero is the same family of fault as the `0%`-where-a-dash-belongs that
was fixed on the org-insights screen. It is one character and it is not wrong
enough to change without asking.

### 4.4 The 128 remaining hand-named typefaces

Held by the `typeface-named-by-hand` ratchet, which can only shrink. They are
three different things and DESIGN.md §9 measures each. **Not** a gap — a
decision — but the ratchet is there so it can be revisited.

### 4.5 Nothing has run on real hardware

- No APK installed on a handset. (Jean's phone can be driven — see the
  `driving-jeans-phone` skill in the global `CLAUDE.md`.)
- Nothing driven against the live database in a browser as a signed-in user.
- iOS not attempted; no reachable Apple Developer account.
- **The map tiles are blank in every render.** Tiles come from OpenStreetMap over
  HTTP and `flutter_test` answers every request with a 400. The route line, the
  puck, the banner and the HUD are all real; the tiles need a device.

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
flutter test                                     # 1714 passing
dart tool/release_guards.dart                    # 28/28
dart tool/release_guards.dart --selftest         # every guard must BITE
py -3 tool/type_scale_codemod.py --selftest
py -3 tool/dropdown_width_check.py
py -3 tool/glyph_coverage_check.py
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
- **Read files with `newline=''` in Python.** Universal newlines turn a 340-line
  change into 5,342 insertions.
- **Write multi-line Python and commit messages to a FILE.** A bash heredoc
  mangles backticks, `$` and backslashes even when quoted — it corrupted a
  replacement string this session and silently skipped one edit. `py -3 file.py`
  and `git commit -F file`.
- **A failing golden comparison can mask a failing test.** Delete the golden and
  re-run to see the real error.
- **`git add -A` sweeps `test/renders/failures/`** — golden-comparison scratch.
  It is `.gitignore`d now.
- **Never `git stash`, `git checkout -- .`, or `git clean`** in the original
  worktree — other agent sessions write it (`CLAUDE.md` §10.1).
- **A Windows console is cp1252** and cannot encode the characters these tools
  talk about. Both Python checks force UTF-8 on stdout.
- **`find.text` cannot see a `TextSpan`.** Two tests this session were written
  against `Text` and silently measured nothing — the org-insights readout and
  the dashboards' money KPI both build their figure as spans of one paragraph.
  Walk `RichText` and read `toPlainText()`.
- **A render that passes alone and fails in the suite is a CLOCK or an image
  cache**, not a flake. `MlTime.debugClock` and `precacheImage` handle both.
- **Restore `FlutterError.onError` INSIDE the helper, never in an
  `addTearDown`.** Displacing it is how you collect every overflow instead of
  the one the binding keeps — but tear-downs run *after* the body's `expect`s,
  and the binding then asserts *"a test overrode FlutterError.onError but either
  failed to return it to its original state…"* and **times the whole file out at
  ten minutes**, reporting every other test in it as "did not complete". Cost 20
  minutes on 2026-08-21.
- **A sabotage that does not restore the ORIGINAL code proves nothing.** Biting
  the title fix by deleting the `Wrap` left the `Text` unflexed, so it stopped
  ellipsising and started overflowing — a different fault, caught by a different
  assertion, and the assertion under test passed. Put the original expression
  back verbatim (`Flexible(child: Text(...))`), not something near it.
- **A phone render frame must be tall enough for the whole scroll.** The targets
  board is 4,209px of content in one `SingleChildScrollView`; at 2,600 the half
  that carried both defects was below the fold and the picture looked fine.
  Measure where the content ends with PIL and size the frame to it plus the
  pinned bottom bar.

### Where the reasoning lives

- `docs/redesign/DESIGN.md` — decisions and what each cost. §8 Phase 2, **§9 the
  type work, §10 the Phase 4 record**.
- `docs/redesign/VERIFICATION.md` — what was actually executed, and what has not
  been. Its "still open" list is current.
- `docs/design-reference/` — the **pre-redesign** reference PNGs, committed in
  the baseline commit. **Do not regenerate them**; they are the before-image, and
  they are the thing to measure against when a treatment is in doubt. Two
  "cosmetic" items were settled this session by reading pixels out of them.
- `docs/redesign/renders/` — 64 PNGs of the redesign.
- Every commit message carries its own reasoning.

---

## 6. The project's own rules still apply

`CLAUDE.md` in this repo is the fork's copy of the shipping app's. The ones that
keep mattering:

- **§10.4** — a `Row` hands a non-flex child unbounded width. This phase hit it
  **five separate times** (three plate pills, a page title and the targets
  band's title), plus its siblings: a `Wrap` laying out against unbounded width,
  two flex children splitting a row that should have had one, and **three tables
  of `Expanded` columns with no minimum**, which compress to unreadable rather
  than overflow. That last shape is the one that keeps hiding: it does not
  raise, and on a desktop it looks perfect.
- **§10.5** — a green test over an empty fixture, an error state, or a fallback
  font proves nothing. Report *screens proving something / N*.
- **§7** — `flutter test` renders in a fallback font unless you load the real
  ones. If an overflow figure looks like `characters × fontSize`, that is why.
- **§7.1** — one clock, Africa/Johannesburg. `MlTime`, never `DateTime.now()`.
  A source guard, `driver-eta-is-not-the-device-clock`, now holds the one place
  a unit test could not.
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
   — the current handoff. Start at the section headed **"WHERE THE LAST SESSION
   STOPPED — READ THIS FIRST"**, then §0, §2, §4 and §5.
2. `C:\Users\Somebody Someone\Claude\HANDOFF.md`
   — the older, machine-wide handoff from 2026-08-08 (MCP servers, git position,
   decoy folders). Background only; the MineLink-M3 one above governs this work.

**THE ONE RULE THAT MUST NOT BREAK:** nothing whatsoever changes inside
`C:\Users\Somebody Someone\Music\SHOWME!\worktree-2026-05-05T11-53-29`. Its
verified baseline is in §0 of the MineLink-M3 handoff — check it at the start
and again at the end. All work happens in `MineLink-M3`, which is a separate git
repo.

**Where to pick up:** the tree is clean, the gate is green, and `git log` is
the record — read the last few commit messages, they carry their own reasoning. Continue at **§4.1** — the console tail, then the portal tail,
then §4.2's dialogs — taking one screen at a time.

**The method, unchanged:** fixtures, regenerate, **LOOK at the PNG**, **MEASURE
it with PIL rather than squint**, fix the *shape* rather than the instance where
the fault is structural, then pin it with a test and **prove the test bites** by
removing the fix and watching it fail. Every screen photographed so far has
turned up a real defect.

**How to work:** don't worry about me seeing anything — I want to see it when
everything is complete and done, so don't stop so much in between; please run
the task for as long as possible so we can get this completely done and sorted.
Correct yourself where you make mistakes and fix the mistakes, and make sure you
don't implement anything with gaps in it — make it full and proper like the
original.

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
flutter build web --release
flutter build apk --debug
```

Read **§5** of the MineLink-M3 handoff (the things that have already gone wrong
in this repo) so you don't repeat them.

