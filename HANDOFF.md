# MineLink M3 — session handoff

**Rewritten 2026-08-21 (second rewrite that day).** Everything below is
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

- **`git status` is empty. 65 commits.** The last four are the portal ones:
  `portal: the buyer's own screens…`, `portal: the mine's tail…`,
  `portal: the transporter's tail…` and `portal: the company profile was an
  error card…`. Read them — each carries its own reasoning. No hash is written
  down here, because a hash in a file the same commit changes is wrong the
  moment it lands.
- **The whole gate was run for real at the end of this session** (numbers in
  §2), including `flutter build web --release` and `flutter build apk --debug`.
- **The original worktree was re-checked against its §0 baseline** immediately
  before the last commit and is **byte-for-byte untouched**.
- **§4.1's PORTAL LIST IS FINISHED.** All fourteen screens it named are
  photographed, and every one of them turned up a real defect.
- **WHERE TO PICK UP: §4.1's *shared* list — chat / messages, notifications,
  profile, account security, appearance & theme, employee register — then
  §4.5's two fixture-less console screens, then §4.2's dialogs.** Phone width
  first, because that is where nearly every remaining defect has been.
- **Searches already finished — do NOT redo them:**
  1. `lib/` scanned twice for any other hand-rolled flex table with the
     compressing shape. **Both scans empty.**
  2. Every `FractionallySizedBox`, `MapOptions`, hand-rolled "x ago" formatter
     and `DateTime.now()`-fed relative time routed through one implementation,
     each held by a guard.
  3. **New this session:** every `MaterialLocalizations.format*Date` /
     `formatTimeOfDay` (21 sites), every hand-rolled absolute timestamp
     (7 vocabularies), and every parenthesised plural `thing(s)` (22 sites).
     All three are now held by guards, so a new one fails the build.

---

## 0. Where you are

| | |
|---|---|
| **This project** | `C:\Users\Somebody Someone\Music\SHOWME!\MineLink-M3` |
| What it is | A **complete, independent fork** of MineLink, being redesigned onto Material 3. Its own git repo (`main`), **65 commits**, clean tree. |
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
  pre-existing faults (§6); web and Android both build.
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
flutter test                                    1815 passed, 1 skipped
dart tool/release_guards.dart                   35/35 PASS, 0 FAIL
dart tool/release_guards.dart --selftest        all guards bite
py -3 tool/type_scale_codemod.py --selftest     OK
py -3 tool/dropdown_width_check.py              passes
py -3 tool/glyph_coverage_check.py              passes
py -3 tool/one_clock_check.py                   0 sites off Africa/Johannesburg
flutter build web --release                     builds (main.dart.js 7.86 MB)
flutter build apk --debug                       builds
docs/redesign/renders/                          118 PNGs, 50 of them phone-width
```

Layout is swept at **8 widths (1612 → 360px) × 6 text scales (0.85 → 2.0)**,
and again **with real rows in every table** at 360/800/1280 by 1.0/1.3.

---

## 3. What Phase 4 has done

Full reasoning is in each commit message and in `docs/redesign/DESIGN.md` §10.
`git log` is a real record — read it rather than trusting this summary.

**The method, unchanged and still working:** add the screen to
`test/renders/redesign_renders_test.dart` with the fixtures it needs,
regenerate, **look at the PNG**, **measure it with PIL rather than squint**,
fix the *shape* where the fault is structural, pin it with a test, and **prove
the test bites** by removing the fix and watching it fail.

**Renders went 25 → 118.** Every screen photographed turned up a real defect,
and almost all of them share one property: **the fault was a layout that
FITS.** An ellipsis, a word broken in half, a truncated label, a zero-height
bar, a wire enum value and a mislabelled figure are all valid layouts. Nothing
raises; no overflow sweep fails. Only a measurement of the painted result sees
them.

### 3.1 The 2026-08-21 portal session, in one list

| where | what the picture showed |
|---|---|
| buyer waybills | **every route heading was a tofu box** — `MlSectionTitle` draws in Fraunces and Fraunces has no `→`. Fraunces is missing SEVEN of the non-ASCII characters the product uses; the sans and the mono are missing none. `tool/glyph_coverage_check.py` had already listed all seven and could only call them advisory. |
| the phone's bottom bar | **"Reconciliatio / n"** — a one-word label broken between two letters with the orphan on the bar's bottom edge. Three of them. |
| buyer requests | the allocated-truck chips ran **156px** past a 412px phone — a `Row` inside a `Wrap`, §10.4 for the seventh time. |
| buyer routes & mines | both linked mines captioned **"mineSupplier"**, and "4 route records" over two route cards (it counted the snapshot's TRANSACTIONS). |
| buyer waybills | a transaction with no route grouped under a heading of **"— → —"**, counted as a route. |
| truck locations ×3 | three trucks reporting 4 minutes, 21 minutes and NINE HOURS ago all printed **"15 Aug"**. |
| trip detail | `Updated Aug 15, 2026 9:30 AM` — the READER'S LOCALE, and the DATE taken from the raw UTC instant while the TIME came from SAST. 21 locale sites; 7 vocabularies for a timestamp. |
| mine locations | every anchor read **"Main Gate …" / "Weighbridge …"** — the name truncated back to the word the row already says. |
| stockpile audit | every entry read "Loaded out · Order pile · Atlas Buyer Group · **Atlas Buyer Group**". |
| tons out | a bare **`198`** on a screen called Tons out, rounded, disagreeing with its own table (197.70 t). And a **second app bar** under the shell's. |
| transporter drivers | three stat tiles across a phone: **"Dri…", "On…", "Av…"**. And a status beside a plate reduced to **"D…"**. |
| fuel & costs | the wrapped action group put the outlined button at the right of one line and the **primary at the left of the next**. |
| compliance | **"12 day(s) overdue"**. Twenty-two parenthesised plurals across the product. |
| own company | **a PostgrestException rendered as the screen** — and with it fixed, a second app bar, a wire org type, a FOURTH private org-type switch and an eighth date format. |
| request transportation | the earliest bookable start date came off `DateTime.now()`. Two more business-day sites with it. |

### 3.2 The shapes that changed, rather than the instances

- **`MlTokens.fontSerifFallback`** at all sixteen sites that name the serif
  face, under any of its four local aliases. Held by
  `serif-declares-its-fallback`, pinned on every editorial rung by
  `one_type_scale_test.dart`.
- **`MlTime.stamp` / `day` / `clock`** for an INSTANT and **`MlTime.calendarDay`
  / `calendarStamp`** for a value already on the South African clock (a
  Postgres `date`, a `showDatePicker` result, or a model that ran `MlTime.sast`
  at parse time). Held by `one-vocabulary-for-a-timestamp` and
  `a-date-is-not-the-readers-locale`.
- **`OrgType.labelFor`** — the twin of `UserRole.labelFor`, taking four sites
  with it including two private switches that disagreed about the spacing
  around a slash.
- **`mlCount` everywhere a count is shown**, held by
  `no-parenthesised-plural`.
- **`MlPageHeader`'s action group wraps to the RIGHT** (`WrapAlignment.end`),
  inert when everything fits.
- **`pumpForCapture` gained two frames** — the third time that schedule has
  been one step short. It also fixed the company-link-picker thumb the previous
  handoff recorded as unexplained.
- **`truncated()` in `portal_tail_test.dart`** — `RenderParagraph.text
  .toPlainText()` returns the WHOLE string whichever part was drawn, so "is
  this name on screen" is not a question about truncation.
  `didExceedMaxLines` is. Proved by reverting a fix and watching the naive
  version of the test pass.
- **`FixtureCompanyRepository`** — the seam for a screen that reads a
  repository inside a `FutureBuilder` rather than watching a provider.

### 3.3 Earlier in Phase 4

`heightFactor: 1` on every `FractionallySizedBox` · `MlTime.instant()` ·
`MlTime.ago()`/`agoTag()` · `UserRole.labelFor` · `AuditLog.actionLabel` ·
`mlMapBackground` · `mlTileProviderOverride` · `MlCard` always provides a
`Material` · `TargetsSelectorField` · `shoot()` captures EVERY framework error
· `MlColumn.minWidth` + `MlDataTable` honouring it · two-line `MlDataTable`
headers · the bottom bar computing its own height · `routingServiceProvider` ·
`MlTime.debugClock` · `pumpForCapture` · `MlStatusBadge.humaniseStatus` ·
`MlWideTable` · `TargetsBand`'s title row as a `Wrap`.

---

## 4. What is NOT done — PICK UP HERE

### 4.1 Screens still without a picture

**Console — FINISHED** except the two in §4.5.

**Portal — FINISHED.** All fourteen of the previous handoff's list are
photographed: buyer waybills, buyer requests, buyer routes & mines, mine
locations, tons-out detail, trip detail, stockpile detail, stockpile audit, the
three truck-location maps, transporter drivers, fuel costs, drop-off,
compliance, own-company and request-transportation.

**SHARED — THIS IS WHERE TO CONTINUE, in this order:**

1. **chat / messages** — `lib/features/chat/screens/messages_screen.dart` and
   `chat_screen.dart`. `communications_hub_screen.dart` is already
   photographed; these two are not.
2. **notifications** — `lib/features/notifications/screens/
   notification_screen.dart` and `notification_management_screen.dart`.
3. **profile** — `lib/features/profile/screens/profile_screen.dart`.
4. **account security** — `lib/features/profile/screens/
   account_security_screen.dart`.
5. **appearance & theme** — `lib/features/portal/screens/
   appearance_theme_screen.dart`.
6. **employee register** — `lib/features/company/screens/
   employee_register_screen.dart`.

The fixture pattern is established: add what the screen's providers need to
`test/fixtures/portal_tail_fixtures.dart` (or a new `shared_tail_fixtures.dart`
if the set is large), add the screen to the `the portal tail` group in
`test/renders/redesign_renders_test.dart` at phone AND desktop width, then
regenerate and LOOK.

**Watch for these three, because every batch so far has had at least one:**

- a screen inside the portal `ShellRoute` that builds its own
  `Scaffold(appBar:)` — that is a second bar under the shell's;
- a screen that reads a SERVICE or a REPOSITORY directly rather than a
  provider, which no override reaches, and which therefore photographs an
  error card;
- a wire enum value reaching a reader.

### 4.2 Dialogs and flows nothing has photographed

`shoot()` takes an `act:` callback, so an interaction can happen before the
picture is taken (used for opening a request, and for expanding the token
history's group). Nothing yet photographs:

- the **due-diligence gate** — preview → "are you sure" → the green tick → the
  transporter list → the final confirm. It needs an `approved` request and a
  sequence of taps.
- the **Record Load sheet** (tare/gross, seal photos, wayslip).
- the **hazard report sheet**, the **quality-cert dialog**, the **invoice
  capture dialog**, the **add-vehicle dialog**, the **waybill edit dialog**,
  the **compliance document dialog**, the **log fuel / log cost dialogs**.

`test/test_helpers/dialog_sweep.dart` and `form_dialog_overflow_sweep_test.dart`
already sweep dialogs for overflow; what is missing is pictures.

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
4. **NEW: `Recon`, `Requests` and `Docs`** are the phone bottom bar's short
   forms for Reconciliation, Procurement and Compliance. "Recon" is the
   product's own word (CLAUDE.md §4), "Requests" is where the tap actually
   lands, and "Docs" describes what the compliance screen holds. Say the word
   if any of the three should read differently.

### 4.4 The 127 remaining hand-named typefaces

Held by the `typeface-named-by-hand` ratchet, which can only shrink. They are
three different things and `DESIGN.md` §9 measures each. **Not** a gap — a
decision — but the ratchet is there so it can be revisited.

### 4.5 Known limitations, stated rather than hidden

- **Nothing has run on real hardware.** No APK on a handset (Jean's phone can
  be driven — see the `driving-jeans-phone` skill in the global `CLAUDE.md`);
  nothing driven against the live database in a browser as a signed-in user;
  iOS not attempted.
- **The map tiles are blank in every render.** Tiles come from OpenStreetMap
  over HTTP and `flutter_test` answers every request with a 400. The route
  line, the puck, the pins, the banner and the HUD are all real; the tiles need
  a device. The map GROUND is theme-correct.
- **Two console screens have no fixtures** —
  `SuperAdminCompanyMirrorScreen` and `CompanyEmployeeRegisterScreen`. Each
  needs a company object plus a handful of further providers (the mirror's
  private search index, live trip positions) that no fixture builds, so they
  would photograph an error state rather than a layout. **Adding those fixtures
  is a real remaining task**, and `FixtureCompanyRepository` in
  `portal_tail_fixtures.dart` is now the pattern for the repository half of it.
- **The `dd MMM yyyy` date sites were deliberately NOT consolidated.** 18 of
  them, all agreeing with `MlTime.day()`'s own output character for character,
  and several formatting a value whose provenance has to be read before it can
  safely be converted (instant vs already-converted wall clock). The
  `one-vocabulary-for-a-timestamp` guard deliberately does not match a
  date-only pattern for that reason. Converting them is safe but must be done
  site by site, not by regex.
- **The scrollbar-thumb note from the previous handoff is RESOLVED.** It was
  the capture schedule, not the widget; `pumpForCapture` gained two frames and
  `test/widgets/wide_table_scrollbar_test.dart` now measures the painted thumb
  by running the painter over a recording canvas.

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
flutter test                                     # 1815 passing
dart tool/release_guards.dart                    # 35/35
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

- 🚨 **`git checkout -- <dir>` THREW AWAY UNCOMMITTED WORK.** Done this
  session to undo a half-applied codemod; it also reverted three finished,
  unrelated fixes in the same directory that had not been committed yet — the
  mine-anchor row, the stockpile-audit dedup and the tons-out units. They had
  to be reapplied from scratch. **Copy the files to the scratchpad first**, or
  commit before running any codemod that might need undoing.
- **A bash heredoc mangles `${...}`, backticks and backslashes even when
  quoted.** It corrupted a Dart string, a Python regex and a test file this
  session — three separate times, in three different ways. **Write multi-line
  Python and commit messages to a FILE** and run `py -3 file.py` /
  `git commit -F file`. For Dart edits prefer the Edit tool.
- **Several files in this repo have MIXED line endings.** A multi-line literal
  match silently finds nothing. Any codemod must join its lines with a
  `\r?\n` regex, not a bare `\n`.
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
  talk about. Both Python checks force UTF-8 on stdout.
- **`find.text` cannot see a `TextSpan`.** Walk `RenderParagraph` and read
  `toPlainText()` — `console_tail_test.dart` and `portal_tail_test.dart` both
  have the helper.
- 🚨 **AND `toPlainText()` CANNOT SEE A TRUNCATION.** It returns the whole
  string whichever part of it was drawn. An assertion that a name "appears on
  screen" passes while the reader sees "Main Gate …" — measured, by reverting
  the fix and watching that version of the test pass. Use
  `RenderParagraph.didExceedMaxLines`.
- **A render that passes alone and fails in the suite is a CLOCK or an image
  cache**, not a flake. `MlTime.debugClock` and `precacheImage` handle both.
- **Restore `FlutterError.onError` INSIDE the helper, never in an
  `addTearDown`.** Tear-downs run *after* the body's `expect`s, and the binding
  then asserts *"a test overrode FlutterError.onError but either failed to
  return it to its original state…"* and **times the whole file out at ten
  minutes**.
- **A sabotage that does not restore the ORIGINAL code proves nothing.** Put
  the original expression back verbatim, not something near it.
- **A phone render frame must be tall enough for the whole scroll.** Measure
  it: render at a deliberately oversized frame, find the last row of painted
  content with PIL, add the 142px the pinned bottom bar occupies.
- **A whitelist is the wrong shape for "tell me what went wrong."** `shoot()`
  reports everything now.
- 🚨 **A SCREEN THAT PHOTOGRAPHS AN ERROR CARD IS NOT A SCREEN PHOTOGRAPHED.**
  The company profile was written, the render was produced and the suite was
  green while the picture read `PostgrestException(message: , code: 400 …)`.
  Look at every new PNG before counting it.

### Where the reasoning lives

- `docs/redesign/DESIGN.md` — decisions and what each cost. §8 Phase 2, **§9
  the type work, §10 the Phase 4 record**.
- `docs/redesign/VERIFICATION.md` — what was actually executed, and what has
  not been. Its "still open" list is current.
- `docs/design-reference/` — the **pre-redesign** reference PNGs. **Do not
  regenerate them**; they are the before-image.
- `docs/redesign/renders/` — 118 PNGs of the redesign.
- Every commit message carries its own reasoning.

---

## 6. The project's own rules still apply

`CLAUDE.md` in this repo is the fork's copy of the shipping app's. The ones
that keep mattering:

- **§10.4** — a `Row` hands a non-flex child unbounded width. This phase has
  hit it **eight separate times now**, plus its siblings: a `Wrap` laid out
  against unbounded width, two flex children splitting a row that should have
  had one, three tables of `Expanded` columns with no minimum, and a `Wrap`
  wrapping to the wrong edge. That family does not raise, and on a desktop it
  looks perfect.
- **§10.5** — a green test over an empty fixture, an error state, or a fallback
  font proves nothing. Report *screens proving something / N*.
- **§7** — `flutter test` renders in a fallback font unless you load the real
  ones.
- **§7.1** — one clock, Africa/Johannesburg. `MlTime`, never `DateTime.now()`
  for anything a user reads as a date, a time, or a number bucketed by day.
  Four guards and `tool/one_clock_check.py` hold the places a unit test cannot.
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
   — the current handoff, rewritten 2026-08-21 (second rewrite that day). Start
   at the section headed "WHERE THE LAST SESSION STOPPED — READ THIS FIRST",
   then §0, §2, §4 and §5. It has the verified baseline of the untouched
   original, what has been done across 65 commits, what is verified green, and
   exactly what is left with the next targets named in priority order.
2. C:\Users\Somebody Someone\Claude\HANDOFF.md
   — the older machine-wide handoff from 2026-08-08 (MCP servers, git position,
   decoy folders). Background only; the MineLink-M3 one above governs this work.

THE ONE RULE THAT MUST NOT BREAK: nothing whatsoever changes inside
C:\Users\Somebody Someone\Music\SHOWME!\worktree-2026-05-05T11-53-29. Its
verified baseline is in §0 of the MineLink-M3 handoff — check it at the start
and again at the end. All work happens in MineLink-M3, which is a separate git
repo.

WHERE TO PICK UP: the tree is clean and the gate is green. The last four
commits are the portal ones — "portal: the buyer's own screens, and an arrow no
font could draw", "portal: the mine's tail, and seven ways of saying when",
"portal: the transporter's tail, and twenty-two counts nobody decided" and
"portal: the company profile was an error card, and a fourth org-type switch".
Read them; they carry their own reasoning.

§4.1's PORTAL LIST IS FINISHED — all fourteen screens are photographed and
every one turned up a real defect. Continue at §4.1's SHARED list, in the order
given: chat/messages, notifications, profile, account security, appearance &
theme, employee register. Then §4.5's two fixture-less console screens (company
mirror, company employee register). Then §4.2's dialogs — one screen at a time,
phone width first, because that is where nearly every remaining defect has been.

Do NOT re-run the three searches the handoff's opening section records as
already finished.

THE METHOD, unchanged: fixtures, regenerate, LOOK at the PNG, MEASURE it with
PIL rather than squint, fix the shape rather than the instance where the fault
is structural, then pin it with a test and prove the test bites by removing the
fix and watching it fail. Every screen photographed so far has turned up a real
defect. Watch in particular for the three faults every batch has had: a screen
inside the portal ShellRoute that builds its own Scaffold+AppBar (a second bar
under the shell's), a screen that reads a service or repository directly so no
provider override reaches it (it photographs an error card), and a wire enum
value reaching a reader.

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
this repo — so you don't repeat them. Two of them are new and cost real time
this session: `git checkout -- <dir>` threw away three finished uncommitted
fixes, and `RenderParagraph.toPlainText()` cannot see a truncation, so a test
asserting "this name is on screen" passed while the reader saw an ellipsis.
```
