# MineLink M3 — session handoff

**Rewritten 2026-08-21 (third rewrite that day).** Everything below is verified
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

- **`git status` is empty. 67 commits.** The tip is
  `shared: the six screens nobody owned, and thirteen second app bars`. Read
  it — it carries its own reasoning, at length. No hash is written down here,
  because a hash in a file the same commit changes is wrong the moment it lands.
- **The whole gate was run for real at the end of this session** (numbers in
  §2), including `flutter build web --release` and `flutter build apk --debug`.
- **The original worktree was re-checked against its §0 baseline** immediately
  before the last commit and is **byte-for-byte untouched**.
- ⚠️ **One correction to that commit message:** it says *"Renders 118 → 137"*.
  The real count is **135** (58 of them phone-width). The 58 is right; the
  total is not. Recorded here rather than rewriting the commit.
- **§4.1 IS FINISHED.** The console list, the portal list and the SHARED list
  are all photographed. Every one of the six shared screens turned up a real
  defect, and one of them turned up a shape repeating across twelve screens.
- **WHERE TO PICK UP: §4.1's remaining list — run
  `py -3 tool/unphotographed_screens.py`, which now keeps that inventory
  instead of this file. 25 route-target screens have never been photographed.**
  Then §4.5's two fixture-less console screens, then §4.2's dialogs. Phone
  width first, because that is where nearly every remaining defect has been.
- **Searches already finished — do NOT redo them:**
  1. `lib/` scanned twice for any other hand-rolled flex table with the
     compressing shape. **Both scans empty.**
  2. Every `FractionallySizedBox`, `MapOptions`, hand-rolled "x ago" formatter
     and `DateTime.now()`-fed relative time routed through one implementation,
     each held by a guard.
  3. Every `MaterialLocalizations.format*Date` / `formatTimeOfDay` (21 sites),
     every hand-rolled absolute timestamp (7 vocabularies), and every
     parenthesised plural `thing(s)` (22 sites). All three held by guards.
  4. **New this session:** every screen the two `ShellRoute`s mount, scanned
     for an app bar of its own (13 found, all fixed, one exemption); every
     private copy of the presence rule (4 found, all routed through
     `MlPresence`); every `DateTime.now()` written to ISO through a local
     variable (2 found, both fixed, the check now matches that shape).

---

## 0. Where you are

| | |
|---|---|
| **This project** | `C:\Users\Somebody Someone\Music\SHOWME!\MineLink-M3` |
| What it is | A **complete, independent fork** of MineLink, being redesigned onto Material 3. Its own git repo (`main`), **67 commits**, clean tree. |
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
flutter test                                    1845 passed, 1 skipped
dart tool/release_guards.dart                   35/35 PASS, 0 FAIL
dart tool/release_guards.dart --selftest        all guards bite
py -3 tool/type_scale_codemod.py --selftest     OK
py -3 tool/dropdown_width_check.py              passes
py -3 tool/glyph_coverage_check.py              passes
py -3 tool/one_clock_check.py                   0 sites off Africa/Johannesburg
flutter build web --release                     builds
flutter build apk --debug                       builds
docs/redesign/renders/                          135 PNGs, 58 of them phone-width
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

**Renders went 25 → 135.** Every screen photographed turned up a real defect,
and almost all of them share one property: **the fault was a layout that FITS.**
An ellipsis, a word broken in half, a truncated label, a zero-height bar, a wire
enum value, an invisible avatar and a mislabelled figure are all valid layouts.
Nothing raises; no overflow sweep fails. Only a measurement of the painted
result sees them.

### 3.1 The 2026-08-21 SHARED session, in one list

| where | what the picture showed |
|---|---|
| messages, phone | a 340px sidebar in a `Row` left **71px** for the whole conversation — one CHARACTER per line, beside a 20px composer. No phone layout had ever existed. |
| twelve screens | **thirteen second app bars.** Every `ShellRoute` leaf drawing `Scaffold(appBar:)` repeats the title the shell already drew. Notifications then added a third. |
| the render harness | it handed `MlAppShell` the **company as the title and the section as the subtitle** — the reverse of `PortalShellLayout`. Every portal render showed a bar the product never draws. |
| employee register | *"Last seen 11 min ago"* beside a dot reading **Offline** and a counter reading **AWAY 0**. One row, two clocks. |
| account & security | the **only password-change UI in the product** rendered `SizedBox.shrink()` — in every test and every render there has ever been. |
| chat header | four avatar treatments with **no circle and near-invisible ink**: "FO TM SR" as three grey smudges above two green dots. |
| employee register | the `Ctrl K` chip's border ran the **entire search box**, so the hint and the magnifier had nowhere to be drawn. At every width. |
| notifications ×2 | the meta line truncated **inside the timestamp** — "15 Aug 2026 …", "04:3…". |
| messages list | four rows 14 minutes, 5 hours, a day and a MONTH old, all printing a bare `HH:mm`. |
| profile | *"Owner name: operator"* — the mailbox half of the email as a person's name; `orgType.name`; "CEO First Na…"; and the one page in the product with a painted gradient ground. |
| chat send path | **every chat message this app has ever sent** was stamped with a naive ISO string — stored two hours late, read back two hours late. |
| register hero | the eyebrow cut at "DIRECTO…", and a four-cell stat strip giving each cell **60px** at 412. |
| three phone frames | **clipping their own content** — measured at zero slack above the pinned bottom bar. |

### 3.2 The shapes that changed, rather than the instances

- **`lib/core/presence/ml_presence.dart`** — one presence rule, on INSTANTS,
  measured with `MlTime.instant()`. Replaced four private copies. Pinned by
  `test/core/ml_presence_test.dart`.
- **The chat models hold instants, not South African wall clocks** — which is
  what let `_dateSeparatorLabel` and `_sameDay` run `MlTime.sast` a second time
  and file a 22:30 message under tomorrow.
- **`test/widgets/no_second_app_bar_under_the_shell_test.dart`** — reads the
  router, takes the screen classes the two shells name, scans those CLASSES
  (not their files), one printed exemption for a pushed page.
- **`tool/one_clock_check.py` matches the split naive stamp** —
  `final t = DateTime.now(); … t.toIso8601String()`. It found a second site the
  moment it existed.
- **`accountDeactivationServiceProvider`**, and `start()` on
  `ChatMessagesNotifier` / `TypingUsersNotifier` — the fifth, sixth and seventh
  seams for the same reason: a widget that constructs its own backend cannot be
  photographed.
- **`ChangePasswordSection` watches `accountEmailProvider`** rather than the
  auth singleton its own screen had already stopped reading.
- **`AvatarStack` / `AvatarList` / `ChatWidget` / `_Avatar`** all draw a real
  well, and initials stopped indexing into an empty string.
- **`tool/unphotographed_screens.py`** — the "which screens have never been
  looked at" inventory, which used to be a hand-kept list in this file.

### 3.3 Earlier in Phase 4

`MlTokens.fontSerifFallback` · `MlTime.stamp/day/clock` + `calendarDay/Stamp` ·
`OrgType.labelFor` · `mlCount` · `MlPageHeader`'s action group wrapping right ·
`pumpForCapture` · `truncated()` via `didExceedMaxLines` ·
`FixtureCompanyRepository` · `heightFactor: 1` on every `FractionallySizedBox` ·
`MlTime.instant()` · `MlTime.ago()`/`agoTag()` · `UserRole.labelFor` ·
`AuditLog.actionLabel` · `mlMapBackground` · `mlTileProviderOverride` ·
`MlCard` always provides a `Material` · `TargetsSelectorField` · `shoot()`
captures EVERY framework error · `MlColumn.minWidth` · two-line `MlDataTable`
headers · the bottom bar computing its own height · `routingServiceProvider` ·
`MlTime.debugClock` · `MlStatusBadge.humaniseStatus` · `MlWideTable` ·
`TargetsBand`'s title row as a `Wrap`.

---

## 4. What is NOT done — PICK UP HERE

### 4.1 Screens still without a picture

**Run the tool; do not trust a list in this file:**

```bash
py -3 tool/unphotographed_screens.py
```

As of this commit: **89 route-target screens, 64 named in the renders, 25 not.**
Its own header states two honest limits — it is name-based, and a name in the
render file is not the same as a picture of the screen. **Look at the PNG.**

The 25, with `swept` meaning some test at least mentions the class (so its
widths may already be covered, which is not the same as having been seen):

```
   swept  ChatConnectionsScreen              swept  PortalTonsOutSearchScreen
          CompanyDetailsScreen               swept  PortalTripsScreen
          CompanyListScreen                  swept  RegisterCompanyScreen
   swept  CompanySelectionScreen             swept  SuperAdminCompanyMirrorScreen
   swept  DriverAppScreen                    swept  SuperAdminDashboardV2Screen
   swept  DriverLimitRequestsScreen          swept  TransporterLeaderboardScreen
          EmployeeGridScreen                 swept  TransporterRequestTrackingScreen
   swept  ExpiredAccessScreen                       TransportersOverviewV2Screen
   swept  ForgotPasswordScreen               swept  UserPreferencesScreen
   swept  HomeTabBodyScreen                  swept  WhatsAppOtpScreen
   swept  LiveTripMapScreen
   swept  MandatoryPasswordChangeScreen
   swept  MineSupplierBuyersDetailScreen
   swept  PlatformAdminSettingsScreen
   swept  PortalTonsOutScreen
```

**Suggested order**, cheapest and highest-yield first:

1. **The four with no `swept` mark** — `CompanyListScreen`,
   `CompanyDetailsScreen`, `EmployeeGridScreen`,
   `TransportersOverviewV2Screen`. Nothing has ever rendered them at any width.
   Three of them were edited this session (their app bars came off) and have
   NOT been looked at since — that alone makes them the first stop.
2. **`MineSupplierBuyersDetailScreen`, `PortalTonsOutScreen`,
   `PortalTripsScreen`, `LiveTripMapScreen`, `DriverAppScreen`** — real
   operational screens with real data shapes.
3. **§4.5's two fixture-less console screens** (`SuperAdminCompanyMirrorScreen`,
   `CompanyEmployeeRegisterScreen`).
4. **The auth tail** — `ForgotPasswordScreen`, `WhatsAppOtpScreen`,
   `MandatoryPasswordChangeScreen`, `CompanySelectionScreen`,
   `ExpiredAccessScreen`. Small, but `login` is the one screen every user sees
   and these are its neighbours.
5. **§4.2's dialogs.**

**Watch for these four, because every batch so far has had at least one:**

- a screen inside a `ShellRoute` that builds its own `Scaffold(appBar:)` —
  **now held by a test**, so this one should stay dead;
- a screen that reads a SERVICE or a REPOSITORY directly rather than a
  provider, which no override reaches, and which therefore photographs an
  error card;
- a wire enum value reaching a reader;
- a `Row` handing a non-flex child unbounded width (CLAUDE.md §10.4 — this
  phase has now hit that family **ten** times).

### 4.2 Dialogs and flows nothing has photographed

`shoot()` takes an `act:` callback, so an interaction can happen before the
picture is taken (used for opening a request, expanding the token history's
group, and switching the Messages sidebar to People). Nothing yet photographs:

- the **due-diligence gate** — preview → "are you sure" → the green tick → the
  transporter list → the final confirm. It needs an `approved` request and a
  sequence of taps.
- the **Record Load sheet** (tare/gross, seal photos, wayslip).
- the **hazard report sheet**, the **quality-cert dialog**, the **invoice
  capture dialog**, the **add-vehicle dialog**, the **waybill edit dialog**,
  the **compliance document dialog**, the **log fuel / log cost dialogs**,
  the **org-group dialog** (reachable from Messages' new header action).

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
4. **`Recon`, `Requests` and `Docs`** are the phone bottom bar's short forms for
   Reconciliation, Procurement and Compliance. "Recon" is the product's own word
   (CLAUDE.md §4), "Requests" is where the tap actually lands, and "Docs"
   describes what the compliance screen holds. Say the word if any of the three
   should read differently.
5. **NEW: the notification body "2 full load(s) ready …" is written by the
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
  `portal_tail_fixtures.dart` plus `FixtureMessagingService` /
  `FixtureNotificationService` in `shared_tail_fixtures.dart` are the patterns
  for the service half of it.
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
flutter test                                     # 1845 passing
dart tool/release_guards.dart                    # 35/35
dart tool/release_guards.dart --selftest         # every guard must BITE
py -3 tool/type_scale_codemod.py --selftest
py -3 tool/dropdown_width_check.py
py -3 tool/glyph_coverage_check.py
py -3 tool/one_clock_check.py
py -3 tool/unphotographed_screens.py             # what still has no picture
flutter test test/renders --update-goldens       # after any visual change
flutter build web --release
flutter build apk --debug
```

### Things that have already gone wrong here — do not repeat them

- 🚨 **`git checkout -- <dir>` THREW AWAY UNCOMMITTED WORK.** It also reverted
  three finished, unrelated fixes in the same directory. **Copy the files to
  the scratchpad first**, or commit before running any codemod that might need
  undoing. (To sabotage-test a fix, `cp file /tmp/x.bak` first and `cp` it
  back — that restores the ORIGINAL verbatim, which a hand-retype does not.)
- 🚨 **A BASH HEREDOC EATS BACKSLASHES EVEN WHEN QUOTED.** New this session and
  it cost two failed patches: `cat > f.py <<'PYEOF'` turned `\\n` into `\n`, so
  a Python literal that was meant to carry the two characters of a Dart `\n`
  carried a real newline and the match silently found nothing. **Write any
  script containing a backslash with the Write tool, not a heredoc.** There is
  a line-ending-safe `sub_once`/`patch` helper worth recreating in the
  scratchpad — join every multi-line literal on `\r?\n`.
- **Several files in this repo have MIXED line endings.** A multi-line literal
  match silently finds nothing. Any codemod must join its lines with a
  `\r?\n` regex, not a bare `\n`.
- 🚨 **`flutter analyze` output is not reliably indented.** Piping it through
  `grep -E "^\s+(error|warning)"` reported **clean while a warning was
  printed**. Use `| tail -4` and read "N issues found".
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
- 🚨 **A PHONE RENDER FRAME MUST BE TALL ENOUGH FOR THE WHOLE SCROLL, AND
  "TALL ENOUGH" IS A MEASUREMENT.** Three of this session's frames were
  clipping. Render at a deliberately oversized frame, find the last row of
  painted content with PIL, and add the 142px the pinned bottom bar occupies.
  **Zero slack means clipped, not "exactly right".**
- **A whitelist is the wrong shape for "tell me what went wrong."** `shoot()`
  reports everything now.
- 🚨 **A SCREEN THAT PHOTOGRAPHS AN ERROR CARD IS NOT A SCREEN PHOTOGRAPHED.**
  The company profile was written, the render was produced and the suite was
  green while the picture read `PostgrestException(message: , code: 400 …)`.
  Look at every new PNG before counting it. It happened twice more this session
  (the deactivate card, the company-locations section) — both times because a
  widget constructed its own backend instead of reading a provider.
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
- `docs/redesign/renders/` — 135 PNGs of the redesign.
- Every commit message carries its own reasoning.

---

## 6. The project's own rules still apply

`CLAUDE.md` in this repo is the fork's copy of the shipping app's. The ones
that keep mattering:

- **§10.4** — a `Row` hands a non-flex child unbounded width. This phase has
  hit it **ten separate times now**, plus its siblings: a `Wrap` laid out
  against unbounded width, two flex children splitting a row that should have
  had one, three tables of `Expanded` columns with no minimum, a `Wrap`
  wrapping to the wrong edge, and — new this session — an `Align` with no
  `widthFactor` expanding to fill a whole search field. That family does not
  raise, and on a desktop it usually looks perfect.
- **§10.5** — a green test over an empty fixture, an error state, or a fallback
  font proves nothing. Report *screens proving something / N*.
- **§7** — `flutter test` renders in a fallback font unless you load the real
  ones.
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
   — THE CURRENT HANDOFF, rewritten 2026-08-21 (third rewrite that day). This
   is the file that governs the work. Start at the section headed "WHERE THE
   LAST SESSION STOPPED — READ THIS FIRST", then §0, §2, §4 and §5. It has the
   verified baseline of the untouched original, what has been done across 67
   commits, what is verified green, and exactly what is left with the next
   targets named in priority order.
2. C:\Users\Somebody Someone\Claude\HANDOFF.md
   — the older machine-wide handoff from 2026-08-08 (MCP servers, git position,
   decoy folders). Background only; the MineLink-M3 one above governs this work.

THE ONE RULE THAT MUST NOT BREAK: nothing whatsoever changes inside
C:\Users\Somebody Someone\Music\SHOWME!\worktree-2026-05-05T11-53-29. Its
verified baseline is in §0 of the MineLink-M3 handoff — check it at the start
and again at the end. All work happens in
C:\Users\Somebody Someone\Music\SHOWME!\MineLink-M3, which is a separate git
repo (branch `main`).

WHERE TO PICK UP: the tree is clean, 67 commits, and the whole gate is green.
The tip commit is "shared: the six screens nobody owned, and thirteen second
app bars" — read it, it carries its own reasoning at length. §4.1's console,
portal AND shared lists are all finished; every screen photographed so far has
turned up a real defect.

CONTINUE AT §4.1 of the handoff. Do not trust any list of screens in a file —
run this, which now keeps that inventory:

    py -3 tool/unphotographed_screens.py

It reports 89 route-target screens, 64 with a render, 25 without. Work them in
the order §4.1 gives:
  1. the four with no `swept` mark — CompanyListScreen, CompanyDetailsScreen,
     EmployeeGridScreen, TransportersOverviewV2Screen. Nothing has ever
     rendered them at any width, and three of them had their app bars removed
     in the last commit and have NOT been looked at since.
  2. MineSupplierBuyersDetailScreen, PortalTonsOutScreen, PortalTripsScreen,
     LiveTripMapScreen, DriverAppScreen.
  3. §4.5's two fixture-less console screens (company mirror, company employee
     register).
  4. the auth tail — ForgotPasswordScreen, WhatsAppOtpScreen,
     MandatoryPasswordChangeScreen, CompanySelectionScreen, ExpiredAccessScreen.
  5. §4.2's dialogs — one screen at a time, phone width first, because that is
     where nearly every remaining defect has been.

Do NOT re-run the four searches the handoff's opening section records as
already finished.

THE METHOD, unchanged: fixtures, regenerate, LOOK at the PNG, MEASURE it with
PIL rather than squint, fix the shape rather than the instance where the fault
is structural, then pin it with a test and prove the test bites by removing the
fix and watching it fail. Watch in particular for the four faults every batch
has had: a screen inside the portal ShellRoute that builds its own
Scaffold+AppBar (now held by a test, so it should stay dead), a screen that
reads a service or repository directly so no provider override reaches it (it
photographs an error card), a wire enum value reaching a reader, and a Row
handing a non-flex child unbounded width.

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
this repo — so you don't repeat them. Four of them cost real time and are worth
knowing before you touch anything: `git checkout -- <dir>` threw away three
finished uncommitted fixes; a bash heredoc ate backslashes even when quoted and
silently broke two codemods (write such scripts with the Write tool);
`flutter analyze` output is not reliably indented so grepping it reported clean
while a warning was printed (use `| tail -4`); and a phone render frame with
zero slack above the bottom bar is CLIPPING, not "exactly right".

When the work is done, rewrite
C:\Users\Somebody Someone\Music\SHOWME!\MineLink-M3\HANDOFF.md the same way
this one was written — verified state only, with a fresh copy-paste block in
§8 — and commit it.
```
