# MineLink M3 — session handoff

**Rewritten a sixth time on 2026-08-23, at the end of the session that
finished the FLEET REGISTER — the biggest single item left in Phase 3 — and
took the Transporter task from one fix to nine of its nineteen findings.**
Eight fixes, one commit each, every one pinned by a test that was sabotaged
and bit. Five faults no reviewer had raised were found by looking at renders
and measuring, one of them in a shared component and one of them a render
that had silently become a picture of the wrong screen. Everything below is
verified state, not intention. It replaces the previous handoff of the same
name; the earlier rewrites' paragraphs are kept under §3 for their record.

**This file lives at**
`C:\Users\Somebody Someone\Music\SHOWME!\MineLink-M3\HANDOFF.md`

The older, machine-wide handoff is at
`C:\Users\Somebody Someone\Claude\HANDOFF.md` — MCP servers, git position,
decoy folders, the phone tooling, dated 2026-08-08. **Background only; this
file governs the redesign work.**

---

## WHERE THIS SESSION STOPPED — READ THIS FIRST

The tree is **clean of this session's work**, **268 commits**, nothing
half-applied. **The tip is the commit that carries THIS FILE**, so the count
above includes it. The last code commit under it is `83304a1` (the shared
money/distance formatter).

🚨 **THERE IS A SECOND WRITER IN THIS REPO RIGHT NOW, AND IT IS NOT A CLAUDE
SESSION.** At 19:49–19:52 another process created
`tool/icons/generate_app_icons.py` and regenerated **every launcher icon** —
Android (`ic_launcher.png` ×5 plus new `ic_launcher_foreground.png` ×5 and
`mipmap-anydpi-v26/`), iOS, macOS, and web (`favicon.png`, `Icon-192`,
`Icon-512`, both maskables) — and its Gradle/Java build (PID 4464, started
19:52:54) was still alive when the session ended. **None of it is committed.**
Every one of this session's eight commits was checked and carries zero icon
files. From the moment it was noticed, commits used explicit paths instead of
`git add -A`. **Do the same until Jean says that work is his and finished**,
and do not `git checkout --` or clean those files: they are not yours.

**The original worktree was re-checked against its §0 baseline at the end and
is untouched** — HEAD `df451d0`, the same three pre-existing modified files,
14163 files under the `-prune` form, two worktree entries, nothing modified
today.

**Jean paused the session** with: *"please pause here and give me a full
proper correct copy paste message…"*. So: `M3-TASKS.md` has **16 ticks**,
Phase 3 is **three of six tasks done** (console, Mine, Buyer) with the
Transporter task `- [ ]` and a `▶ IN PROGRESS` line naming its nine fixes and
its **ten remaining findings**. Driver and Shared are untouched `- [ ]`; their
reviewer reports are already in the repo.

### What this session did, in one paragraph

It re-earned Phase 0 (the two end-of-session ticks from the fifth session were
REOPENED at the start, because they were true of that session and not this
one), then worked the Transporter task. The FLEET REGISTER — reviewer findings
#4 to #9, the one transporter screen still entirely in the pre-redesign
vocabulary — is done, along with #10, #12, #13, #15 and #16. Eight commits,
one per fix. Every fix was sabotaged; every sabotage compiled clean; every one
kept a case green that a too-eager version of the same fix would have broken.
Two of the session's own mistakes were caught by its own instruments before
they shipped: a test that was blind at 380px and passed under its own
sabotage, and a number formatter that went green while printing `R29,159.2`.

### 🚨 WHAT IS OWED FIRST

1. **Run `flutter build apk --debug`** and re-tick Phase 0's gate line. It is
   the ONLY thing in the gate that did not run, and the gate task is `- [ ]`
   ⏸ BLOCKED because of it — not because anything failed. Everything else ran
   green at the tip (§2). It was skipped deliberately: another process's
   Gradle build was live in this repo and a second one would contend for its
   locks and cook Jean's CPU while his own build ran. Check that build is gone
   first (`Get-CimInstance Win32_Process | Where-Object { $_.Name -match
   'java' }`).
2. **Finish the Transporter portal task.** `M3-TASKS.md`'s `▶ IN PROGRESS`
   line under it is the authoritative list. **Ten findings are left**: #3 the
   donuts have no legend (also mine and buyer); #14 the drivers screen's
   hand-rolled `_Stat`; #18 request tracking repeating its page title as a
   section title with the same meta; #20 "Reconciliation batches" as a bare
   sans heading; #27 the dispatch sheet's sans title and accent metrics; #28
   trip status as muted subtitle text instead of a badge; #29 the compliance
   document list with no section head; #30 fixtures putting `TN 55 QQ GP`
   under Fixture Haulage when it is not in the fleet; **and the MISSING
   RENDERS list at the bottom of `report_transporter.md`, which is part of the
   task, not an extra** — this session and the last one have between them
   found three real defects purely by creating a render that did not exist.
   Ten more need no work: seven were already fixed by the console/mine/buyer
   passes and were verified in the render, three are marked (Shared).
3. **Then Driver, then Shared — one at a time, each ticked before the next
   starts.** Their reports are written.
4. Nothing else. Phases 4–7 and the Decisions are blocked on Jean.

## 0. Where you are

| | |
|---|---|
| **This project** | `C:\Users\Somebody Someone\Music\SHOWME!\MineLink-M3` |
| What it is | A **complete, independent fork** of MineLink, redesigned onto Material 3. Its own git repo (`main`), **268 commits**, **no remote**. |
| **The task list** | `MineLink-M3\M3-TASKS.md` — the single markable source of what is done. 16 ticks. |
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
modified today    0
```

```bash
cd "/c/Users/Somebody Someone/Music/SHOWME!/worktree-2026-05-05T11-53-29"
git status --porcelain --untracked-files=all
git rev-parse --short HEAD
find . -path ./.git -prune -o -type f -print | wc -l
git worktree list
find . -path ./.git -prune -o -type f -newermt "<today>" -print | wc -l    # must be 0
```

⚠️ The plain `find . -type f -not -path "./.git/*"` returns **14164** because in
a WORKTREE `.git` is a *file*. The `-prune` form returns **14163**. Same tree.

Reading that tree is fine and often necessary. Writing to it, or running any
mutating git command inside it, is not.

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
- **If the phone does not answer, STOP and ask.** §5. Not needed this
  session; the phone was not touched.
- 🚨 **DO NOT MOVE JEAN'S MOUSE.** He works at this machine while the session
  runs. A helper that drove real OS clicks through `SetCursorPos` was written
  once, used twice, and disabled the moment he said so. §5 has what to use
  instead. No browser was opened this session at all.
- 🚨 **ONE TASK AT A TIME, MARKED BEFORE THE NEXT.** Jean, verbatim: *"FROM
  HERE ON FORWARD WITH WHAT YOU'RE BUSY WITH, NO NEW TASK SHOULD BE STARTED
  UNLESS THE PREVIOUS TASK WAS FULLY AND PROPERLY MARKED OFF TRUTHFULLY!"* And
  this session, verbatim: *"you're not marking your tasks as you should, AFTER
  ANY AND EVERY TASK IS COMPLETED IT SHOULD BE MARKED RIGHT AFTER THAT! ONLY
  IF IT'S 100% TRUE!"* — said when Phase 0's start items had been done but not
  re-ticked with the day's evidence, and when the previous session's
  end-of-session ticks were still standing in a new session. Tick the moment
  a thing is proven; reopen a tick that is no longer true; record progress on
  an open task as a `▶ IN PROGRESS` line and commit the file with the work.
- 🚨 **DO NOT COOK HIS CPU.** Verbatim: *"Don't COOK MY FKN CPU! close each
  crome session once you're done with it PLEASE!"* One headless Chrome only
  for the minutes a flow needs; `Stop-Process` every `chrome.exe` whose
  command line contains `ml-chrome-` the moment that flow is done (§5).
- **Reviewer agents are READ-ONLY and the session stays the single writer.**
  Jean asked this session to "deploy your best agents" to help complete the
  task file. What worked: one agent per Phase 3 scope, reading renders and
  source against the reference and reporting drift with file:line, the
  reviewer brief in `docs/redesign/reviews/2026-08-23-phase3/agent_brief.md`.
  What they must never do: edit, run `flutter`/`dart`, open browsers, touch
  the phone, or write in the scratchpad under a name the session uses (one
  overwrote `crop.py`; the session's helpers are now named `my*.py` and
  committed under `tool/phase3_helpers/`). Every reviewer finding was
  VERIFIED against the render and the code before it was fixed; three were
  wrong or deliberate and were recorded as "not drift" rather than applied.

**`supabase/` is frozen.** Things needing a migration are REPORTED — §6.

---

## 2. Verified state, right now

Every one of these was run at the tip, redirected to a file and grepped —
never read through a pipe or a `tail`.

```
flutter analyze                                 No issues found! (whole tree)
flutter test (full)                             2697 passed · 1 skipped · 0 failed
                                                (2647 at the session's start)
dart tool/release_guards.dart                   43/43 PASS · 0 FAIL
dart tool/release_guards.dart --selftest        all guards bite
py -3 tool/_sabotage.py                         ALL SABOTAGES CAUGHT
type_scale_codemod --selftest                   OK
dropdown_width_check                            every dropdown states isExpanded
glyph_coverage_check                            every character drawable
one_clock_check (+ --selftest)                  PASS · 0 sites · selftest bites
unphotographed_screens                          94 route-target screens · 94 named · 0 not
                                                (NAME-BASED — it cannot see a screen whose
                                                every picture is the wrong variant)
health_probe                                    7/7 — the extras project's search_place_index
                                                answered on the RETRY, cold after idling, as
                                                on every day so far; main 6/6 first time
flutter test test/renders                       268 passed — the PLAIN run (no --update-goldens)
                                                at the tip; goldens current
flutter build web --release                     √ — build/web is FRESH at the tip
flutter build apk --debug                       🚨 NOT RUN — another process's Gradle build was
                                                live in this repo (see §0). The APK on disk is
                                                STALE: still 61861FA9…, eight code commits behind
APK on the handset                              1ad4c725 (2026-08-23 04:50) — older still
M3-TASKS.md                                     16 ticks. Phase 0's two start items re-earned with
                                                THIS session's evidence; the browser/HANDOFF item
                                                ticked; the GATE item `- [ ]` ⏸ BLOCKED on the APK
                                                build alone. Phases 1, 2 DONE; Phase 3 console +
                                                Mine + Buyer DONE, Transporter ▶ IN PROGRESS,
                                                Driver and Shared untouched
browsers                                        NONE opened this session at any point; 0
                                                ml-chrome-*, nothing on 9222/9223
phone                                           NOT touched this session
original worktree                               df451d0 · 3 pre-existing modified · 14163 · 2
                                                worktree entries · 0 modified today
UNCOMMITTED, AND NOT THIS SESSION'S             every launcher icon (Android/iOS/macOS/web),
                                                android/.../mipmap-anydpi-v26/, tool/icons/ —
                                                written by another process at 19:49–19:52
```

Test count: 2647 at the session's start → 2697. New test files:
`fleet_fixture_coherence_test`, `on_route_card_keeps_the_plate_test`,
`fleet_register_status_agrees_with_the_cards_test`,
`fleet_register_speaks_the_reference_test`,
`fleet_screens_speak_sentence_case_test`,
`fleet_stat_captions_survive_a_phone_test`,
`add_vehicle_is_a_header_action_test`, `ml_figures_test`. Guards stay at 43.

## 3. What this session did — DO NOT REDO ANY OF IT

Every commit from `8ef16b1` to the tip carries its own reasoning in its
message; `git log --format='%h %s' e62d2ac..HEAD` lists them. The per-screen
record is the "Mine / supplier portal — IN PROGRESS" table in
`docs/redesign/VERIFICATION.md`. The previous sessions' §3.0–§3.25 are kept
below unchanged.

### 3.26 The Phase 3 Mine-portal pass — 23 fixes, five findings open

**Shared components (these fixed findings on every portal at once):**

- `8ef16b1` `SaSectionHeader` — the portal dashboards' band head laid out
  `Flexible(title) · Spacer() · Flexible(meta)`: three flex-1 children split
  the row in thirds and the meta landed at two-thirds (x≈860 in a band ending
  at 1570). Now title `Expanded`, meta bounded non-flex. CLAUDE.md §10.4.
- `6dbfb7e` `MlFlagshipTrend` — the TARGET caption under the `7 days` pill;
  adopts the reference card's rule (a line in the top 30% sends the caption
  to the left end), `flagshipCaptionAnchorsLeft()` public.
- `bb0de74` + `31586a9` `MlSectionTitle` — the stacked (phone) form put the
  action in an `Align(centerLeft)` under the meta; an icon action hung 18px
  below its meta in the wide form (`CrossAxisAlignment.start`). Now meta left
  / action right on one row; centred when there is no subtitle. The first
  version gave the stacked action unbounded width and the sweep caught a
  2.6px overflow at scale 2.0; a loose `Flexible` for the meta then kept its
  unused allotment (action at x=231 of 360); the final shape is a bounded
  non-flex meta + `Expanded(Align(right))` action. 58 goldens.
- `bcb0fdb` `MlPageHeader` — wrapped tools landed at the LEFT on a phone
  with the description under the buttons. **A width rule (stack under 560px)
  was tried, measured on 43 goldens and REVERTED**: it cost every header
  whose tools fit a line ("9 entries · Export" beside "Audit logs"). The
  header now MEASURES with a small render object (`_HeaderLayout`) and
  stacks only when `title + 12 + tools` does not fit. 12 goldens.
- `16fcfac` `SaStatTile` — the KPI delta chip at the tile's midpoint
  (`Spacer() + Flexible(chip)`, the same trap one widget down) → one
  `Expanded(Align(topRight))`. Six dashboard goldens.
- `0057ef8` `MlFlagshipTrend` legend — a "Target" key drawn for a line that
  is not drawn (the 28,000 t rule); the first key now reads `latestLabel`.
- `e911fd4` `MlStatusBadge.toneForStatus` — `loading` fell to neutral
  between amber `arrived` and green `loaded`. Nine goldens, each the one pill.

**Mine screens:**

- `5ddb862` gate screen: hand-rolled sans title + gradient chip →
  `MlPageHeader`; two sans section headings → `MlSectionTitle`; sentence case.
- `bf25042` weighbridge: seven title-case labels → sentence case ("Mine
  Control" kept as the screen's name).
- `6752683` `166571c` Operations Hub: stock `Card`/`FilledButton`/hand-rolled
  empty state → `MlCard` + `MlSectionTitle` (action in the slot) +
  `MlEmptyState`; the company card now spans the column; tab and dialog
  titles sentence case. The empty ledger is the fixture's stated intent.
- `4ef7ee1` figures: `MetricBreakdownRow` values mono (20 sites); the
  stockpile detail headline and the ROM pile card in Fraunces via
  `formatTons` (the pile read `412.60 t` mono here and `412.6 t` Fraunces on
  the Supervisor tab).
- `cf3608f` stockpile audit: two sans headings → `MlSectionTitle`; a load-out
  in the ERROR tone → warn; the plate breaking on a phone → NBSP; sans
  figures → mono. **The last commit before the power cut.**
- `8dc3500` recon heads: "3 delivered loads" counted Pending rows, "2
  certificates" counted loads; the POD link was `MlTokens.accent` as ink
  (1.81:1 on white) → `accentInk`. Redone from scratch after the cut.
- `ce2e10d` quality table: the `38.0% / 42.0%` pill wrapped at its slash
  (flex-2 column 96px wide) → `minWidth: 112` + NBSP + `softWrap: false`;
  MOISTURE/SIZING heads 12px apart → Sizing right-aligned.
- `249106f` Search loads — the one mine screen still in the pre-redesign
  vocabulary end to end: five gradient `_SummaryBox` tiles → `MlStatCard`;
  "Tons out" title → "Search loads"; sans "Filters" → `MlSectionTitle`;
  sans title-case `DataTable` heads on an accent band → uppercase overline
  heads on a plain surface; "Time" → "Time out"; plates → `MlPlatePill`;
  peach-tinted mass → mono; `15/08/2026` → `15 Aug 2026` via `calendarDay`;
  the `minWidth: MediaQuery.size.width − 64` floor (the WINDOW, sidebar
  included) → the table fills its own card via a `LayoutBuilder`. **And a
  real bug**: `TonsOutEntry.date` is a midnight calendar day and the rolling
  windows compared it to `now − 24h`, so "Last 24h" read 71.12 t here and
  103.22 t on Tons out for the same loads; the entry now carries `at` and
  windows on `instant`.
- `e64212a` `a74f0f0` Locations: both card heads → `MlSectionTitle` (the
  Locations section's action in the slot, so "Add location" stays right on a
  phone); "Main gate" / "Loading point"; the anchor card's meta counts
  PINNED anchors the way its CONFIGURED badges do — a row count said "2 of 3
  set" over one badge, caught by looking at the render.
- `da9571e` maps: `kPositions`' nine-hour-old sample drew like a fresh one
  → `isPositionStale` (> 1 h) tones the age and the well warn; the desktop
  lists had no hairline → `ListView.separated` + a head; the highlighted
  marker was `scheme.error` → the accent.
- `db9912d` employees: an ACTIVE employee with an off-org role (the fixture's
  weighbridge controller at a transporter) was counted in "3 PEOPLE" and
  drawn in no group → "Other" now catches it; twelve title-case labels.
- `90a82c1` employee profile: a fall in red → amber; every document well red
  → its status tone; the footer `Wrap` with no alignment → Row/Expanded (the
  button at the edge); "Message  Thandi" (two spaces, wrapping) → one line,
  and the NAME is dropped under 200px (an ellipsis read "Message F…");
  `ProfileSetupEmployerCard` had no fixture, errored and rendered nothing on
  every golden ever taken → fixture added, WITH items (a summary over an
  empty list said "Nothing outstanding" at 70%).
- `9740420` employee register: a second (blue) accent at 16 sites → the
  product's accent (`accentInk` behind the `blue` getter); Offline in the
  fault colour → `textFaint`; "Employee Register" → "Employee register".

**Found by the session's own instruments, not by a reviewer:**

- The power cut after `cf3608f`: `git status` said `index file corrupt`;
  `.git/index` moved aside and rebuilt with `git reset` (no working files
  touched), `git fsck` clean; four files mid-write were **entirely NUL
  bytes** (NTFS allocated the length, never flushed) and were restored from
  HEAD; a tree-wide scan found no other zeroed file; the in-flight edit was
  redone. Lesson in §5.
- The one-clock guard (`MlTime.sast` asserting `instant.isUtc`) refused the
  first draft of the Search loads date cell — `e.date` is a calendar day and
  must be formatted with `calendarDay`, never converted.
- The portal overflow sweep caught two 2–6px overflows introduced by this
  session's own `4ef7ee1` (a wider mono figure in `MetricBreakdownRow`) and
  `bb0de74` (an unbounded stacked action) → `31586a9`.
- A `--name "locations|profile"` filter: this shell ate the `|` as a pipe,
  the targeted re-run never ran, and a golden was committed one digit stale
  ("2 of 3 set") until the full suite was re-run (`a74f0f0`). **Never put
  `|` inside `--name` here; run the whole suite.**

**Reviewer findings checked and NOT applied (recorded in VERIFICATION.md):**
the hub's empty ledger (the fixture says "on purpose"); the register's
one-per-bucket roster under a transporter (deliberate); `OverviewHeroTile`'s
sans card titles (card titles, not section heads); `Total Tons=` (CLAUDE.md
§4 mandates the literal); dialog titles in sans (`dialogTheme`, app-wide);
captions wrapping at a `·`; the 520px gate column (the original's).

---

### 3.28 The sixth session — the FLEET REGISTER, and five faults nobody had raised

**Eight fixes, one commit each. Every one sabotaged; every sabotage compiled
clean; every one keeps a case green that a too-eager version would have
broken.**

- `9781518` **the on-route card paid the status badge before the truck's own
  plate.** `Row(Expanded(identity), badge)` serves its UNFLEXED child first, so
  the badge took its natural width and the registration took the remainder.
  Invisible while the badge read `ON ROUTE`; the moment the fixture stopped
  lying it read `EN ROUTE TO OFFLOAD` and a 412px phone rendered `JD 22 PL …`
  at text scale 1.0, with the identity Row squeezed to 41.3px and overflowing
  by 21 at 360 × 1.6. Fixed with `MlHeaderLayout`, the same measured fit rule
  both page headers use.
- `1244084` **#12 + #13 — three fixtures, four trucks, two answers.**
  `kFleetStatus` said `veh-1` was on route while its only trip (`t-1`) is
  COMPLETED and its own driver assignment says `onRoute: false`; and denied
  `veh-2` while `t-2` is en route to offload and `va-1` says otherwise. It also
  set only the legacy `driverName`, never `drivers` — which is what
  `driversLabel`/`hasDriver` read — so an on-route truck photographed as
  "No driver assigned" under a warning panel offering to assign one, while
  three fixtures beside it named its driver. Pinned by a test of the FIXTURES
  (`test/fixtures/fleet_fixture_coherence_test.dart`), which is the only place
  a lie of that shape can be caught: every screen rendered *consistently* with
  whichever fixture it happened to read.
- `2eca532` **#7 + #6 — the register and the cards above it answered the same
  question differently.** The table derived each row's status from
  `assignedDriverId` while the four cards read `fleetStatusProvider`, so the
  cards said `2 On route · 1 Available` over rows saying `Assigned / Assigned /
  Unassigned / Unassigned`. The comment beside those cards already said what
  that costs, because they had made the same mistake and had it taken out of
  them the day before. It also killed a fourth status vocabulary: a
  solid-gradient pill painting **RED for "Unassigned"**, which is this system's
  declined/error tone spent on the truck an admin allocates from.
- `2e58fa3` **#5 — the last Material `DataTable` in the product, and a column
  that had never been photographed.** At SEVENTEEN columns the table was
  ~1890px wide and the register at 1600px has ~1250px, so STATUS was column
  fifteen and off the edge. A thirteen-column draft was still too wide and
  COMPRESSED rather than scrolled, so Flutter broke inside the words:
  `YEA / R`, `202…`, `Freightlin…`, and the status pill itself reading
  `IN MAINTENA…`. Eight columns now, all of them on a laptop. Two widths are
  MEASURED, not read off the source: an `IconButton` declaring
  `BoxConstraints(maxWidth: 40)` **renders at 48** (Material's padded tap
  target wins), and `ODOMETER` is a longer string than `412 300`.
- `682ecb8` **#4 + #10 — eighteen Title Case labels**, the sharpest being
  `Trucks On Route` directly under an app bar already reading `Trucks on
  route`: one picture, two spellings of the screen's own name. The test asserts
  the SPECIFIC strings, because product names and ALL-CAPS column heads are the
  reference's own texture and a blanket lower-casing pass would have destroyed
  them.
- `ca132cd` **#8 — the stat grid never reached one column.**
  `cols = w > 900 ? 4 : 2` left each card 183px on a phone, of which
  `MlStatCard` spends ~92 on chrome, so the mono captions broke mid-token
  (`carrying_a_lo / ad`). `MlTileGrid`, which the product already has and whose
  own doc names this shape as duplicated across sixteen files.
- `23a708c` **#9 — `Add vehicle` was a FAB**, the only one in the product,
  sitting on top of the register at phone width with a tooltip for a label.
- `83304a1` **#15 + #16 — `R-61,023`.** The sign after the currency, written as
  a hyphen, on the figure that says a transporter lost money; `R 48500.00`
  ungrouped; `91500 km` beside a register that groups. One shared formatter,
  `lib/core/utils/ml_figures.dart`, following the U+2212-before-the-symbol rule
  `PortalKpiRow.formatDelta` had already settled.

**🚨 FIVE FAULTS NO REVIEWER RAISED, AND HOW EACH WAS FOUND**

1. **The plate/badge trade** (`9781518`) — found by looking at the golden the
   fixture fix had just moved, and confirmed by the existing overflow sweep.
2. **`MlWideTable` treated an INFINITE maxWidth as "wide enough already"**
   (`2e58fa3`). `constraints.maxWidth >= minWidth` is trivially true for
   infinity, so it returned the child bare — and a table laid out with
   `Expanded` cells then threw *RenderFlex children have non-zero flex but
   incoming width constraints are unbounded* inside any horizontally
   scrollable parent. Fixed in the shared component with `isFinite`.
3. **No fixture vehicle had ever carried a disk expiry or a driver's ID and
   documents** (`2e58fa3`), so those columns had only ever been photographed
   as a column of em dashes and no test could measure whether a date or a
   document chip fits.
4. **`dialog-add-vehicle-phone-dark` silently became a picture of the FLEET
   SCREEN** (`23a708c`). Its `act` opened the dialog by tapping
   `byTooltip('Add Vehicle')` and, like every other `act` in that file,
   returned QUIETLY when the control was missing — so removing the FAB turned
   a render named *dialog* into a picture of the screen behind it, with the
   whole suite green. **All fifteen guards in that file were made to report and
   the render suite run: this was the ONLY one tripping**, so the rest are
   genuinely doing their act and only this one was hardened to assert.
5. **A `NumberFormat.decimalPattern` that printed `R29,159.2`** (`83304a1`) —
   see below.

**🚨 TWO OF THIS SESSION'S OWN MISTAKES, CAUGHT BY ITS OWN INSTRUMENTS**

- **A test that was BLIND at one width and passed under its own sabotage.**
  The caption test divided each caption's height by the height of
  `all_vehicles` in the same render, assuming the shortest caption always fits.
  Under the old two-column ladder at 380px it does not — it wraps too — so the
  reference was two lines tall and every caption measured as exactly "1". The
  sabotage passed at 380 and only bit at 412. It counts selection boxes now.
  **A reference measured from the thing under test is only a reference while
  the thing under test is right.**
- **A formatter that went green while printing `R29,159.2`.**
  `NumberFormat.decimalPattern` keeps up to THREE fraction digits, where the
  `NumberFormat('#,##0')` it replaced rounds. Nine tests passed; the earnings
  render did not. Caught by putting the regenerated golden beside the old one.

**Reviewer findings checked and NOT applied:** none this session — the nine
worked were all confirmed in the render or the code first, and #4's list of
title-case strings was trimmed to the ones that are not product names.

---

### 3.27 The fifth session — Mine closed, Buyer done, Transporter started

Header note for the whole section: **the fourth session's §3.26 stands
unchanged below.** Nothing in it was redone.

**Mine — the five findings that were open (six commits):**

- `bf40afc` the employee grid's paging. Found by asking whether a header meta
  counting that roster would be TRUE. `EmployeeRepository.getByCompanyId`
  returned its cache VERBATIM — no `orderBy`, no `limit`, no `offset` — so
  every `InfiniteGrid` page after the one that primed the cache was that page
  again, and never short; and it cached the twenty-row SLICE under the
  company's key, so a paged company told every reader it had twenty people for
  five minutes. `SupabaseRepository.supabase` became a getter in the same
  commit, because a field initialiser meant NO repository in this product could
  be built in a test at all.
- `4a4558f` the grid's head: `'$companyName Employees'` (the shipping app's
  `AppBar` title moved into an `MlPageHeader` unchanged) → sentence case, plus
  the meta §5.4 asks for, at no extra round trip.
- `06ecf4b` Buyers: the last portal page opening with a SECTION head + a
  hand-rolled `Text`. Measured at 412px, the meta moved from L16 under a title
  at L48 to L179 on the title's row, and the header is 34px shorter. And every
  buyer card in the `Wrap` was taking `OverviewHeroTile`'s accent wash AND cyan
  glow — `muted` existed, was passed by NOBODY, and thinned only the wash.
- `8b9e71e` the mine's Requests: the description had no `isMine` branch, so a
  mine was told it raises "transportation and product" requests — the one type
  §4 forbids it — directly above a button offering the one it omitted. Both
  actions moved from a left `Wrap` of stock Material into `MlPageHeader.actions`.
  **And the `isMine` screen had never been photographed** (see below).
- `6ee7d68` trip detail: `TRP-000123` and `34.90 t` in sans while the plate
  above them and the same reference on the buyer's Loads & value are mono; the
  facts in a hand-rolled `Container` with no heading; `View waybill` stock
  Material. Per-row `isCode`, not a blanket face — the names are not codes.
- `6762b65` company information: six title-case labels, three WRAPPING in the
  130px column at 1600px. Shortened rather than widening the column, because
  the words repeated the heading above them and the avatar above that.

**Buyer — nine fixes.** Twelve of the reviewer's 23 findings were already
closed by earlier passes and were checked IN THE RENDER; #20 is marked (Shared).
`88492d2` `SaSectionHeader` (the third header in the family to learn that a
width rule is not a fit rule — `MlPageHeader`'s measurement became the shared
`MlHeaderLayout`); `cda2922` "Trucks inbound" amber under a caption saying it
had left the mine; `a95cce5` Routes & mines (a section head as a page title;
route cards coloured BY INDEX); `bfcf8c5` a table demanding 1376px in a 1224px
card, carrying the invoice button off-screen; `5127fe0` a chip cut mid-word;
`0bbf5ef` "Tons Delivered" over a sum of the MINE's own weight; `8e01b67` the
three cross-check figures over two populations; `27acc6f` the live map's status
pill shrunk by a `FittedBox`.

**Transporter — one fix.** `ac190e0`: `toneForStatus` matched `'on route'`
nowhere (it is not `'en route'`), so `Trucks on route`'s pills and `DRIVER ON
ROUTE` drew neutral GREY beside `EN ROUTE TO OFFLOAD` in blue for the same
truck. **And, measured beside it, `toneForStatus('Inactive')` returned
`MlTone.done`** — GREEN — because `"inactive".contains("active")` is true.

**🚨 FOUR FAULTS NO REVIEWER RAISED, AND HOW EACH WAS FOUND**

1. The employee-grid paging (`bf40afc`) — found by asking whether a number the
   fix was about to print would be true.
2. **The mine's Requests screen had never been photographed** (`8b9e71e`).
   `unphotographed_screens.py` said 94/94 because it counts the class NAME in
   the render file — the name-based limit stated in its own header — and every
   picture of `BuyerRequestsScreen` was `isMine: false`. First time that limit
   has cost anything.
3. **The weight reconciliation's three figures covered two populations**
   (`8e01b67`) — found by LOOKING at a desktop render this session had to create
   first. `103.22 t Loaded · 70.70 t Delivered · 0.42 t Net variance` over three
   trips, one still Pending. The caption invites the subtraction; 103.22 − 70.70
   is 32.52, seventy-seven times the stated variance, on the screen that exists
   to say whether mass went missing en route. The file already computed the
   right figure as `deliveredLoaded` for the severity denominator.
4. `toneForStatus('Inactive')` → green (`ac190e0`), measured.

**FIVE RENDERS CREATED FOR SCREENS THAT HAD NO PICTURE** — and two of the four
faults above came out of making them: `screen-mine-requests-{desktop,phone}-dark`,
`screen-buyer-loads-value-{desktop,phone}-dark`,
`screen-buyer-reconciliations-desktop-dark`. 263 → 268.

**🚨 THREE OF THIS SESSION'S OWN MISTAKES, CAUGHT BY ITS OWN INSTRUMENTS**

- **A "fix" that was a NO-OP, and a test that passed without it.** The
  available-route chip (`5127fe0`) looked like CLAUDE.md §10.4 — a child laid
  out against unbounded width — so the first version added a `ConstrainedBox`
  per chip inside a `LayoutBuilder`, and a test asserting the chip's geometry.
  **Sabotaging it passed.** Probing the real widget at the real width showed
  why: `RenderWrap` bounds its children already (33..379 in a card at 16..396,
  with or without the constraint). The actual fault was `Chip` clipping a label
  that had no `maxLines`/`overflow`, silently. Twenty lines became two, and the
  test now asserts `didExceedMaxLines` — a rendered fact — rather than a
  rectangle that was always correct.
- **A header measured in the wrong font** (`20f8a77`). The two cases added to
  `portal_dashboard_kit_test.dart` measure whether a title and its tools FIT,
  and hosted `SaSectionHeader` in a bare `MaterialApp`: stock Material's type
  scale. Caught by `test-renders-under-the-app-theme` on the end-of-session
  gate. Both cases and both sabotages were re-run under the real theme.
- **Two tests that did not bite, in `live_map_status_pill_test`.** Comparing
  the pills' declared `fontSize` passes with a `FittedBox` in place — it scales
  the PAINTED result and leaves the style alone — and checking
  `paragraph.parent` is not a `RenderFittedBox` passes too, because the badge
  puts several render objects in between. Height, and the whole ancestor chain.

**🚨 `mypatch.py` DESTROYED A SOURCE FILE, AND IS NOW HARDENED.**
`io.open(p, 'w')` TRUNCATES the target the moment it is called; the encode
happens on `.write()`. A patch carrying an unpaired surrogate (a
`\ud83d\udea8` escape written to keep a patch script ASCII) emptied
`ml_status_badge.dart` to ZERO BYTES and only then raised `UnicodeEncodeError`.
It encodes first and writes through a temp file and a rename now; proven by
driving the same bad patch at it again and diffing the target. Two smaller
lessons in its docstring: **`flutter analyze` reports "No issues found!" for a
zero-byte Dart file**, and a bash heredoc still eats backslashes (it ate
`\'` out of a Dart string in the same hour).

**A POWER CUT** hit mid-session and zeroed
`mine_supplier_buyers_detail_screen.dart` (18,362 bytes, not one non-NUL byte).
`.git/index` was intact this time, `git fsck` clean, one other zeroed file (a
gradle build artifact). Restored from HEAD, the edit redone, and a stray `~`
that had landed on line 4 of `M3-TASKS.md` in the open editor reverted.

**Reviewer findings checked and NOT applied:** the buyer's own "Delivered"
figure in the weight-reconciliation card (that one really IS the offload
weight — a word-ban would have taken it out, and the test says so);
`'This period'` (a fallback behind `latestLabel`, with a comment); the
`Routes & Mines` KEY in `_legacyTabLabels` (the seam, not the copy);
requester-typed tonnages printed as typed.

---

### Earlier sessions — §3.0 to §3.23, kept unchanged

### 3.0 The previous session's interrupted checks — both PASSED

- **Sign-out copy on the SM-G780G**: "Sign out" / "Are you sure you want to
  sign out?" / [Cancel] [Sign out]. Cancel tapped; phone left as found.
- **`Duplicate GlobalKey`**: baseline, **12** navigations on the handset,
  **0** new rows. (7 in 7 on the build before the fix.) The pipe was proven
  live by the 7 rows that handset wrote the previous night.
- **The driver's week chart**: verified on the emulator. The 33.7 t that used
  to land on a Sunday that had not happened is on Monday; Sunday is flat.

### 3.1 🚨 A wall clock converted twice — `e080197`

`MlTime.sast` returns a NON-UTC DateTime by design, so converting an
already-converted value looks exactly like converting a fresh one:

| the reader's device | what a second `sast` does |
|---|---|
| SAST (UTC+2) | nothing — it is the identity |
| UTC | **+2 hours** |
| New York (UTC−4) | **+6 hours** |

Six sites in `raw_recon_view.dart` — **three of them in the Excel/CSV/PDF
export of the billing record** — plus the chat dock's support notifications and
events, the mine dashboard's Recent-waybills card, and three console "last
active" readouts that go through `MlTime.ago`.

**The fixture had the same error mirrored.** `kRawReconRows` built rows with
raw `DateTime.utc(...)`, which is the opposite of what `RawReconRow.fromJson`
produces, so the two errors cancelled: the rendered time was right in the test
and wrong in production for anybody outside South Africa.

**`MlTime.sast` now ASSERTS its input is a genuine instant.** Every real
instant here arrives UTC-flagged, because Postgres returns `timestamptz` with
an offset and `DateTime.parse` honours it — so `isUtc` is a sound test for
"this is not somebody's wall clock", it costs nothing in release, and it fires
in debug, in every test and in every render. **It is what found this at all.**
The `calendar*` family is now complete: `calendarDay`, `calendarStamp`,
`calendarClock`, `calendarListDay`, `calendarAgo`, `calendarAgoTag`.

### 3.2 The live map's ETA came off the reader's device — `e080197`

```dart
final arrive = DateTime.now().add(eta);
parts.add('ETA ${DateFormat('HH:mm').format(arrive)}');
```

A straight §7.1 violation shown to the buyer, the mine, the transporter and the
platform admin, on the screen whose entire subject is when a truck arrives.
Every other timestamp in that file already went through `MlTime.sast`. The
timeline's "Now" row did the same and also made a render of that panel
unreproducible.

**`one_clock_check.py` gained a sixth pattern for it**: a `DateTime.now()` that
never has a calendar field read off it because it goes straight into a
formatter. Pattern 5 is blind to exactly that. Sabotaged against the real file:
the checker names it, line and all.

### 3.3 An eighth date dialect on three console screens — `e080197`

`Aug 22, 2026 8:50 PM`, photographed on `/super-admin/crash-reports` against
real rows and twice more on `/super-admin/token-requests`. Month-first,
12-hour, in a product that is day-first and 24-hour everywhere else — and the
exact shape `MlTime`'s own doc lists among the seven it replaced.

`one-vocabulary-for-a-timestamp` could not see it: it reads the literal inside
`DateFormat('…')` and `DateFormat.yMMMd().add_jm()` has no literal to read. New
guard **`no-skeleton-dateformat`**, which **failed on the real tree** before the
fix rather than only on a planted line.

### 3.4 A bare time in two lists that span days — `e080197`

The load controller's Recent Loads, live:

```
S6W001GP  34.2 t  Completed             10:10    <- today
KVK007MP  33.7 t  En route to offload   04:51    <- today
fa243ad   30 t    En route to offload   13:39    <- SIX DAYS AGO
```

Sorted newest first, so the times run out of order and the only thing that
explains it is a day nothing on screen mentions. The security gate's Recent
Activity did the same. New `MlTime.listStamp`: the time for today, the date for
any other day. **Both sites were confirmed live, in both branches at once**,
once a load was recorded at 01:00 — the column read `01:00 · 22 Aug · 22 Aug ·
16 Aug`.

### 3.5 The mine's production table contradicted its own header — `f8e815d`

```
0.00 t Mined | 771.32 t Dispatched | — Yield | — Pit-to-port loss

22 Aug   0.00 t   34.20 t   -34.20 t   <- amber, and every row
```

The two tiles were fixed yesterday; the table eight rows below still subtracted
inline and toned every negative `warn`. **The fixture already had two zero-mined
days**, so `screen-mine-production-desktop-dark.png` had been photographing an
amber `-34.20 t` every render for weeks.

### 3.6 The quality screen printed delivered tonnage under "Payable" — `f8e815d`

Under a header reading `0 of 35 loads certified`, with every moisture cell
`—`:

```
S6W001GP   34.20 t   —   34.05 t
KVK007MP   31.80 t   —   34.90 t   <- ABOVE its own net
```

`list_load_quality` returns NULL for `payable_tons` with no moisture reading;
the cell filled the gap with `deliveredTons ?? netTons` and muted it. Payable
is net REDUCED by a penalty, so it cannot exceed the net. **The exporter beside
it already wrote an empty cell**, so screen and spreadsheet disagreed about the
same load.

### 3.7 `R0.00 Invoice variance`, in green, with nothing invoiced — `5cbaeee`

On a card whose own header two lines down said `33 loads · 0 invoiced`. A fold
over an empty list is `0.0`. A variance is a COMPARISON; with one side missing
there is no answer, which is a different fact from the two sides agreeing.
`Invoiced R0.00` beside it is NOT the same thing and is unchanged.

### 3.8 The register counted a different set from the screen next door — `5cbaeee`

`"9 stockpiles"` on the Supervisor screen, `"7 of 7 stockpiles untouched
today"` on the employee register. Both right — two of the nine hold nothing —
and neither said which set it meant. The tell was inside the KPI: its
**empty-case** caption already said "no stockpiles **with product**".

### 3.9 🚨 "Seals — Not required" on a route that refuses a load without four — `4c5f807`

```
transportation_requests.seal_required   false
routes.seal_required                    true
```

`record_truck_load` reads the ROUTE. Driving it end to end, the transporter's
sheet said "Not required" and the Load Controller's sheet opened on "Seals
(4 on this rig) — SEALS REQUIRED … you can't complete the load without them."
The admin had typed "Seals required on this route" into the free-text notes,
which is the workaround the comment above that row was written to end — it
named the right reason and read the wrong column.

Fixed with one more column on an embedded select the transporter already reads.
**Two sabotages**: ignoring the route's flag fails three cases, and dropping
`seal_required` from the select fails a case that reads the service's SOURCE —
because a PostgREST select string cannot be reached from a unit test, and
without that case the fix could silently revert with everything else green.

### 3.10 A distance chip that sometimes said what it measured — `4c5f807`

Nine route cards, one column: `640 km · 620 · 640 · 640 km · (none) · (none) ·
520 km · 120 · 120`. `mlDistanceText` puts `km` on a BARE NUMBER only —
`640km`, `about 600 km` and `620 miles` are somebody's words and are left
exactly as typed.

### 3.11 Two "this week" tonnages on the driver's screen — `963ca7e`

`170.5 t "Tons this week"` (loaded) and `136.3 t "Tons delivered / This week"`,
one scroll apart, only one label saying which. The card is `Tons loaded this
week` now.

### 3.12 The driver's hero card overflowed by 44 px — `963ca7e`

At 360 px × text scale 1.3 — a narrow phone with the text size turned up, which
is a driver standing next to a truck. `CURRENT TRIP` and the status pill were
both unflexed and neither can be ellipsised, so the pill drops to a second line
via a `Wrap` that claims the row.

**It only appears with a trip on the card.** The empty state's pill reads
`NO ACTIVE TRIP`; a real one reads `EN ROUTE TO OFFLOAD`, five characters
longer. Which is the whole of the next item.

### 3.13 🚨 THE OVERFLOW SWEEP HAD BEEN LAYING OUT EMPTY SCREENS — `963ca7e`

`portal_overflow_sweep_test.dart` overrode `mirrorCompanyIdProvider` and
nothing else. That got it past "Company not loaded" — and then every provider
resolved to an EMPTY LIST. 27 screens × 3 widths × 5 text scales × bold, of
empty states. Empty states are short, and short things do not overflow (§10.5).

The load controller's own source already carried a comment about a 29 px
overflow *"that no sweep had seen because the sweep ran with no trips"* — found
by hand, fixed by hand, and the sweep left blind to the next one.

It runs on the real capture fixtures now. Turning the data on surfaced **four**
more overflows on screens it had always covered and always passed:

| | |
|---|---|
| load controller · truck identity row | 22 px @ 360 × 2.0 |
| load controller · the whole wide branch | @ 800 × 2.0 |
| buyer reconciliation card · header | 21 px @ 360 × 2.0 |
| buyer reconciliation card · two buttons | 32 px @ 360 × 2.0 |

All four are §10.4 by the letter. Note the asymmetry the fixes had to respect:
the load controller's identity row is dropped into a **shrink-wrapped** Row, so
`Flexible` there throws outright and it had to become a `Wrap`; the recon
card's header Row sits in a Column of **bounded** width, so `Flexible` is
exactly right there. Each fix names which situation it is in.

The load controller's breakpoint now **scales with the text**: a fixed `640`
asks "is the card wide enough" when the question is "does the content fit", and
the content is text the reader can double.

### 3.14 One real load, driven end to end — the point of the whole sweep

Trip `0d9c6792`, truck S6W001GP. Transporter accepts → truck and driver
assigned → driver starts → security checks in → **weighbridge** → gate
check-out.

The arithmetic closes at every step: tare 15.40, gross 49.60, `Net minerals
loaded 34.20 t` computed live, `Tons loaded (auto) 34.20` agreeing in the
wayslip block below it, `trips.net_tons` 34.2 after. The stat card moved to
`33.025 t Avg Tons / Load` — exactly (34.2 + 33.7 + 30 + 34.2)/4. Four seals
demanded, numbered and photographed, matching `fleet_vehicles.seal_points = 4`.
Waybill `TRP-6C72DDAC41` minted server-side with origin, destination, the
gross-scale photo and the controller's stored signature.

**Zero crash reports were raised all session** — across the handset's 12
navigations, the emulator, and hours of browser driving as six accounts.

### 3.15 🚨 "12:35" rendered as "12:3" over "5" on the billing table — `2b235c4`

**Found on the handset, by the handset, and by nothing else.** Jean's phone runs
a raised system font size; the recon table's TIME-IN column broke a clock time
in half.

The table's minimum width is a MEASURED 1480 px, and the session that measured
it wrote down exactly why: at 1120 the fourteen columns squeezed until Flutter
broke inside words rather than between them — "DELIVER / ED", "VARIAN / CE",
"PO / D". That fix was right. It was measured **at text scale 1.0** and then
left as a fixed pixel figure under a type size the reader controls, which is
the trap `MlDataTable._effectiveMinWidth` documents in as many words, having
fallen into it once already and overflowed six screens at 1.3.

Measured at the table's own minimum:

| text scale | time cells wrapped |
|---|---|
| 1.0 | 0 |
| 1.3 | **16** |
| 2.0 | **16** |

A wrapped cell is a cell that FITS, so no sweep, no overflow capture and no
render could ever have seen it — the same reason the broken header words
shipped. The minimum scales with the text now, because the minimum is a
statement ABOUT the text.

`recon_table_legibility_test.dart` runs at 1.0, 1.3 and 2.0 and asserts on
values with NO legal break point in them (a clock time, a tonnage), so more
than one line can only be a break inside the value. 2.0 is included because
Android's platform text size goes past the console's own 0.85—1.3 slider and
this table is read on a phone.

---

### 3.16 APK `2b235c4` installed; then `1ad4c725` — Phase 1 closed on glass

Both over the NAS route, hashes matched both ends before the tap. On glass:
`12:35` on ONE line (the 20 Jul 2026 row); the driver's hero card with the
long `EN ROUTE TO LOAD` pill and no stripe (a trip THIS session dispatched
and the driver started on the phone); the controller's on-site truck card
and the buyer's reconciliation card at the raised size; 0 new crash rows of
any kind from 01:27Z to 03:38Z across five sign-ins and ~20 navigations on
both builds. The handset found one thing nothing else had: **the app-bar
title broke mid-word** (`Load co`/`ntroller`, `Compli`/`ance`,
`Reconci`/`liations`) — 3.18.

### 3.17 The POD leg of `0d9c6792`, and the whole request → dispatch chain

`M3-TASKS.md` Phase 2 carries the evidence lines. POD: 33.9 t against
34.2 t loaded, variance 0.3 t, photo in `pod_photos`, Side B row on the mine
(the order is buyerless by its own request — that is data). The chain: four
requests typed from the four forms (time pickers, date pickers, the map
picker on the extras project's `place_index`, three PDFs + a photo), the
sent-back / resubmitted loop both ways, all four inboxes, two passes through
the five-step gate, route / ledger / dispatch / capped stockpile per
dispatch, all three notification kinds, the transporter's accept with one
truck, a second driver added to KVK007MP with its order-aware notification,
a scheduled trip, the driver starting it on the handset, security check-in.

### 3.18 🚨 The phone title broke mid-word — `705843a`

Drawer + title + FOUR actions left the title a column narrower than the word
"controller"; two lines cannot help a single word wider than the column.
M3's medium top app bar: the title is MEASURED against the room beside the
icons at the reader's text scale and drops onto its own full-width row only
when a word would otherwise split. Short titles keep the 72px bar. Pinned by
`phone_title_never_breaks_a_word_test.dart`, sabotaged both ways; re-seen on
the handset on APK `1ad4c725`.

### 3.19 The second driver on a truck was unreachable — `69f6738`

The Fleet row swapped Assign for Unassign once a driver was on; the
Trucks-on-route card offered the dialog only under its no-driver warning;
`DriverAssignmentDialog`'s cap and "request more" path had no entry point.
Pinned by `second_driver_is_reachable_test.dart`, four cases, sabotaged both
ways. Not yet seen as pixels (build/web is stale).

### 3.20 "Buyer asked for" on a mine-raised request — `22eb90b`

Pinned by `link_step_names_the_requester_test.dart` over the real review
screen. Not yet seen as pixels.

### 3.21 🚨 An admin's whole portal torn down and rebuilt every 45 s — `f225278`

`CompanyNotifier` cleared its context on every `AuthState` emission from an
employee; the auth notifier re-syncs on every change to the user's `profiles`
row; the chat presence heartbeat writes `last_seen_at` there every 45 s. So
for every admin/management employee: context → null, `portalWorkspaceProvider`
leaves `ready`, the body is torn down and rebuilt, feeds re-read, the dock
closes, scroll and form state go. Owners never saw it. Measured: node count
142 → 6 → 31 → 129 at 05:26:47, 05:27:32, 05:28:16 with a `Synced auth
state` line each time, token unchanged, heartbeat 37 s old; the owner's dock
open for twenty minutes alongside. Pinned by
`company_context_survives_auth_resync_test.dart` (driven auth notifier,
seeded context; sabotage fails exactly the re-sync case). NOT yet re-seen in
a browser — rebuild web, sign in as `ironhills.admin`, open the dock, wait
three minutes.

### 3.22 "Organisation type | mineSupplier", and the second spelling — `56df087`

The chat profile panel's private switch matched 'mine'/'supplier', which the
database never stores. Now `OrgType.labelFor` in the panel, the request
model, the company-link builder and the waybill fallback; held by the
`one-spelling-for-mine-supplier` guard (43 guards, `--selftest` all bite).
Not yet seen as pixels.

### 3.23 The rig: what cost time and must not be re-learned

- A CDP Chrome launched off-screen (`--window-position=2000,2000`) is
  `visibilityState=hidden`, 0 rAF/s: Flutter never paints and every screen
  looks like an endless spinner while its requests complete. Use
  `--headless=new` — and kill it the moment the flow ends (§1, CPU).
- Dropdown menus and dialogs ARE clickable over CDP in headless mode (the
  old "popup menus cannot be reached" note was about the visible window).
- The chat dock's launcher TOGGLES; `clicklabel "Messages"` on an open dock
  closes it. Read the dock from screenshots; read semantics only after
  `cdp.py publish`.
- `cdp.py`, `setfile.py`, `takepic.py` read `CDP_PORT` (default 9222) so two
  browsers can be driven; `takepic.py <paths;joined> "<button label>"`
  enables the file-chooser intercept BEFORE clicking, which `setfile.py`
  cannot; `cdp.py clear` / `scrollx` were added.
- `io.open(..., newline='')` for every doc patch; heredocs still eat
  backslashes.

---

## 4. What is NOT done — PICK UP HERE

### 4.1 Phase 3 — three of six tasks done; Transporter more than half done

**Done and ticked:** the console pass, the Mine portal (29 fixes over two
sessions), the Buyer portal (9 fixes; 12 findings already closed by earlier
passes). Their per-screen tables in `docs/redesign/VERIFICATION.md` carry a
commit or the words "reviewed, no drift" on every row. **Do not redo any of
it.**

**Transporter portal (`- [ ]`, `▶ IN PROGRESS`).** `M3-TASKS.md`'s progress
line under the task is the authoritative list. Of the reviewer's 30 findings
in `report_transporter.md`:

- **7 already fixed** by the console/mine/buyer passes and verified in the
  render, not taken from the report: #1 (`16fcfac`), #2 (`0057ef8`),
  #17 (`bcb0fdb`), #19 (`bb0de74`), #21 (`8dc3500`), #22 (`db9912d`),
  #23 (`6762b65`).
- **3 are (Shared)** and belong to the Shared task: #24, #25, #26.
- **9 fixed** — #11 in `ac190e0` (fifth session), then #4, #5, #6, #7, #8, #9,
  #10, #12, #13, #15 and #16 across the eight commits in §3.28.
- **10 left.** #3 donut legends (also mine and buyer); #14 the drivers
  screen's hand-rolled `_Stat`; #18 request tracking repeating its page title
  as a section title with the same meta; #20 "Reconciliation batches" as a bare
  sans heading; #27 the dispatch sheet's sans title and accent metrics; #28
  trip status as muted subtitle text instead of a badge; #29 the compliance
  document list with no section head; #30 fixtures putting `TN 55 QQ GP` under
  Fixture Haulage when it is not in the fleet.
- **The MISSING RENDERS list at the bottom of that report is part of the
  task.** Between them the fifth and sixth sessions found THREE real defects
  purely by creating a render that did not exist, and
  `unphotographed_screens.py` cannot see the gap because it counts class names.

**Then Driver, then Shared — one at a time, each ticked before the next.**
Their reports are `report_driver.md` and `report_shared.md` in the same folder.

**A report is a lead, not a verdict.** Check every finding against §3.26,
§3.27 and §3.28 first, and verify it in the render before touching anything:
twelve of the buyer's 23 and seven of the transporter's 30 were already fixed.

### 4.2 The Phase 0 gate

Ran at the tip and green — **except `flutter build apk --debug`, which was not
run at all** (§0, §2). That is the whole reason the gate task is `- [ ]` ⏸
BLOCKED; nothing in it failed. `build/web` IS fresh at the tip. The APK on
disk (`61861FA9…`) and the one on the phone (`1ad4c725`) are both stale.
Run the APK build first thing once the other process's Gradle build is gone,
then re-tick.

### 4.3 Decisions for Jean (listed in M3-TASKS.md, do not decide them)

- Buyer and mine/supplier insights and the company mirror in the v1
  analytics language; the chat dock not mounted on `/chat/:id`; the
  inherited v1.0 checklists.
- New from the reviewers, not yet in M3-TASKS.md's decision list (add them
  there when the Shared task is reached): the chat dock's Nord default
  palette (its accent is `#88C0D0`, not `#22D3EE`); dialog titles in sans
  (`dialogTheme.titleTextStyle`, one edit app-wide if Fraunces is wanted);
  the login page's gold brand colour.

### 4.4 Blocked on Jean (name them, do not start them)

Phase 4 (a real road), Phase 5 (seven server-side items, §6), Phase 6
(Windows path, iOS), Phase 7 (a remote for M3; the firewall rule).

### 4.5 Closed, do not redo

Phases 1 and 2 entirely. The console pass. **The Mine portal and the Buyer
portal, both ticked.** The 23 fixes in §3.26 and the 16 in §3.27, and every
row of the Mine and Buyer tables in VERIFICATION.md — every one of them now
carries a commit or the words "reviewed, no drift".


## 5. How to work in this repo

```bash
cd "/c/Users/Somebody Someone/Music/SHOWME!/MineLink-M3"

flutter analyze                                  # must be clean
flutter test                                     # 2478 passing, 1 skipped
dart tool/release_guards.dart                    # 42/42
dart tool/release_guards.dart --selftest         # every guard must BITE
py -3 tool/_sabotage.py                          # every instrument must BITE
py -3 tool/type_scale_codemod.py --selftest
py -3 tool/dropdown_width_check.py
py -3 tool/glyph_coverage_check.py
py -3 tool/one_clock_check.py                    # 0 sites, exit 0
py -3 tool/one_clock_check.py --selftest
py -3 tool/unphotographed_screens.py
py -3 tool/health_probe.py                       # 7/7 — but see §2 on cold extras
flutter test test/renders --update-goldens       # after any visual change
flutter build web --release
flutter build apk --debug
```

### The Phase 3 method (as done for the console, 2026-08-23)

Per route target, in the order `M3-TASKS.md` lists the screens:

1. **Look** at the render(s) in `docs/redesign/renders/` — desktop dark first,
   then light and phone where they exist — beside `docs/design-reference/*.png`
   and §4–§5 of `docs/design-reference.md`. Stack several crops into one PNG
   with PIL to save reads; zoom when a detail is in doubt.
2. **Check the nine classes** in §3.25 first: hand-rolled sans titles and
   headings; card actions riding in the title `Wrap`; title case / a misplaced
   possessive; a `Wrap` sizing to its content; tone (neutral where a tone
   exists, red for a trend, a second accent); a fixture that lies; legal line
   breaks the legibility tests allow; charts (label collisions); nondeterminism.
3. **Before calling something drift, check the ORIGINAL** (read-only) and the
   reference's own notes: snake_case captions, full gridlines, product names
   and the mention token are all deliberate or inherited.
4. **Fix the cause**, in the shared component where one exists (`MlPageHeader`,
   `MlSectionTitle`, `editorialMedium`, `MlStatusBadge.toneForStatus`, the
   tokens). A fix to a token or a shared widget moves many goldens — measure
   every one with `golden_diff.py` and look at the crops.
5. **Regenerate** with `flutter test test/renders --update-goldens --name
   "<screen>"` and look again. Then the full `test/renders` without
   `--update-goldens` before the commit that carries goldens.
6. **Pin** with a test — geometry (`tester.getRect`) for placement, the
   `fontFamily` for faces, the tone enum for colour — and **sabotage** it
   (`git stash push -- <file>` → test fails → `git stash pop`).
7. **One commit per fix**, then the row in VERIFICATION.md's Phase 3 table,
   then the tick in `M3-TASKS.md` with an evidence line naming every fix and
   every "reviewed, no drift" screen.

### What "sabotage" means here

Copy the file to `/tmp`, change **one line** back to the buggy version, run the
test, confirm it **FAILS**, restore, re-run, confirm green. A green test proves
nothing on its own. It only ever touches local Dart source; never the database,
the phone, or the original worktree, and it is never committed.

🚨 **A SABOTAGE MUST COMPILE.** Check `flutter analyze` on the sabotaged file —
a sabotage that fails to build "fails" the test for the wrong reason and proves
nothing. One this session (`Flexible` in a shrink-wrapped Row) threw at layout
rather than compile time, which is still a real bite, but it had to be read to
know that.

🚨 **KEEP A CASE THAT STAYS GREEN UNDER SABOTAGE.** Every fix this session that
turned a figure into a dash also has a case asserting the REAL figure survives.
Without it, a fix that went too far and started hiding true values would look
exactly like a fix that worked.

### 🚨 DRIVING A BROWSER WITHOUT TOUCHING JEAN'S MOUSE

He works at this machine while the session runs. **Never move the cursor.**

The session's CDP driver is in the scratchpad — `cdp.py`, `setfile.py`,
`attach_photos.py`. Copy them forward; they are not in the repo.

```bash
flutter build web --release        # config/supabase.live.json is bundled → LIVE
cd build/web && py -3 -m http.server 8123 --bind 127.0.0.1
"/c/Program Files/Google/Chrome/Application/chrome.exe" \
  --remote-debugging-port=9222 --user-data-dir="<scratch>/ml-chrome-$(date +%H%M%S)" \
  --no-first-run --no-default-browser-check --window-size=1600,1000 \
  "http://127.0.0.1:8123/"
```

- **Publish the semantics tree with a JS `.click()`, not a pointer event.** The
  `flt-semantics-placeholder` sits at (−1,−1) and is 1×1, so no real click can
  land on it. `p.click()` fires its handler and works every time.
- **Read semantics leaves by DESCENDANT** (`!e.querySelector('flt-semantics')`),
  and **replace newlines** — a plate pill's label is `"Hold to copy\nS6W001GP"`
  and a naive read makes it look as if the registration is missing. It is not.
- **Type with `Input.dispatchKeyEvent` per character**, not `Input.insertText`
  (which does not reach Flutter) and not by setting `input.value` (the canvas
  does not follow). Clear the field first: Ctrl+A then Backspace.
- 🚨 **CDP CLICKS DO NOT REACH A POPUP-MENU OVERLAY.** Menu items neither
  highlight on hover nor fire, and the barrier will not dismiss — while every
  other click on the page works. It is the TOOL, not the app: the same menu
  works by touch on Android. **Do not chase it as a defect.** Switch accounts
  by clearing the session instead:
  ```js
  localStorage.removeItem('sb-yftazblpmicqtamyiwyb-auth-token');
  location.href = 'http://127.0.0.1:8123/';
  ```
- **A file input CAN be driven**, which is how the four seal photos and the
  scale photo were attached: `Page.setInterceptFileChooserDialog(true)`, click
  "Take picture", then `DOM.setFileInputFiles` on the `input[type=file]` that
  appears. Re-read the layout between each one — the card grows when a picture
  lands and every later control moves.
- 🚨 **CLOSE EVERY BROWSER YOU SIGN IN WITH, BEFORE YOU FINISH.** §6.
- 🚨 **A SECOND CHROME CANNOT HAVE THE SAME `--remote-debugging-port`, AND IT
  FAILS SILENTLY.** Confirm the owner with `Get-NetTCPConnection -LocalPort
  9222 -State Listen`.
- 🚨 **`ignoreCache` IS NOT ENOUGH.** `transferSize` 0 means cache; compare
  `decodedBodySize` against the built file's byte count.
- ⚠️ The setup gate re-fires on reloads. Dismiss with "Later".
- ⚠️ Some screens need more than 3.5 s to swap; 5 s is safer, and a fresh
  sign-in wants 16.

### Driving the app on ANDROID (emulator)

`emulator-5554`, `adb` at `C:\Android\sdk\platform-tools`. It is the second
best surface after the handset and it does not touch Jean's desktop at all.

```bash
export PATH="$PATH:/c/Android/sdk/platform-tools"
adb -s emulator-5554 install -r -d build/app/outputs/flutter-apk/app-debug.apk
adb -s emulator-5554 shell monkey -p org.minelink.m3 -c android.intent.category.LAUNCHER 1
adb -s emulator-5554 exec-out screencap -p > shot.png     # then Read the png
adb -s emulator-5554 shell input tap <x> <y>              # REAL pixels, 1080x2400
adb -s emulator-5554 shell input text 'someone@example.com'
adb -s emulator-5554 shell input keyevent KEYCODE_BACK    # hides the keyboard
adb -s emulator-5554 shell settings put system font_scale 1.3   # PUT IT BACK to 1.0
```

⚠️ **A Read of a screenshot reports "displayed at 900x2000, multiply by 1.20"**
— the tap coordinates must be the REAL 1080×2400 ones.

⚠️ **The emulator is set to Africa/Johannesburg**, which is why §3.1's whole
class is invisible on it. Reason about the zone; do not just look.

### Driving Jean's real phone

**Invoke the `driving-jeans-phone` skill FIRST.**

🚨 **IF THE PHONE DOES NOT ANSWER, STOP AND ASK — DO NOT WORK AROUND IT.**
`status` saying `no phone at a known address - broadcasting`, or `probe` under
0.1 bits/pixel (display asleep), means pause and say so. Only Jean can enable
host mode or wake the screen.

⚠️ **Host mode staying on does NOT mean the screen is awake.** This session:
`sharing=True control=True` throughout and `probe` 0.061 bits/pixel for hours.
**Check `probe`, not just `status`.** Ask EARLY — he has fixed it within
minutes every time it happened — and keep working on what does not need the
handset while you wait, re-probing as you go.

Install route:

```
1. flutter build apk --debug
2. copy build/app/outputs/flutter-apk/app-debug.apk ->
     \\192.168.88.30\Shared\PhoneRemote\minelink-m3.apk   (hash-match both ends)
3. My Files -> Network storage -> jean -> Shared -> PhoneRemote ->
   minelink-m3.apk -> ~2.5 min -> Update -> Open
```

🚨 **THE NAS CLOCK IS ~2 h 36 m SLOW — compare the SHA-256, not timestamps.**

⚠️ **My Files CACHES the folder listing.** Back out to `Shared` and re-enter
`PhoneRemote`, then check the TIMESTAMP moved. **The size is useless** — every
build rounds to 207 MB.

⚠️ **`home` often drops the link and IS NOT RETRIED**, so send it on its own.
Long batches drift; prefer short ones and re-shoot.

⚠️ **The applicationId is `org.minelink.m3`**, deliberately different from the
shipping app's. They install side by side.

It is his **personal** phone: prefer `sig`/`changed`/`waitstable` over `shot`,
**delete every screenshot immediately**, do not read what you did not come for,
and leave it on `home; waitstable; home`. Battery was 35–37% and charging when
this session ended.

🚨 **Turning on live-location sharing writes JEAN'S REAL POSITION** to
`vehicle_positions` every 30 s. Never switched on.

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
`MineralGuide123!`. The five used this session: `ironhills.owner`,
`ironhills.controller`, `ironhills.security`, `atlasbuyer.owner`,
`roadhaul.admin`, plus `roadhaul.driver` on the emulator.

⚠️ **The console stores theme and accent PER ADMIN.** Put it back if you change
it.

### Things that have already gone wrong here — do not repeat them

- 🚨 **A helper that moved Jean's real mouse.** He was using it. Disabled.
- 🚨 **Browsers left signed in overnight filled a production database.** §6.
- 🚨 **`io.open(p,'w')` in Python REWRITES A FILE'S LINE ENDINGS on Windows**,
  turning a 3-line change into a whole-file diff. This repo is mixed LF/CRLF
  with `core.autocrlf=false`. Pass `newline=''` on BOTH the read and the write,
  or run the scratchpad's `fix_eol.py` before committing — it compares each
  modified file against `git show HEAD:<path>` and puts it back.
- 🚨 **A bash heredoc eats backslashes even when quoted**, and it silently
  mangled a regex into a literal newline this session. **Write any patch script
  with the Write tool and run it with `py -3`.**
- 🚨 **A stale cached bundle looks exactly like a silent failure.**
- 🚨 **The handset found what three instruments could not, twice.** When a fault
  is reported from hardware, re-install and re-check ON HARDWARE.
- 🚨 **CHECK WHETHER A "FAULT" IS THE DATA — or the tool.** Three things this
  session looked wrong and were not: a plate pill's semantics label (the
  registration IS announced, after the tooltip), the seal note contradicting
  the seal flag on an older route (a previous session's own test data), and
  every popup menu in the app (CDP, not the app).
- 🚨 **A power cut destroyed a file mid-write.** Commit often.
- 🚨 **A pipe hides a failing exit code.** Redirect, then check `$?`.
- 🚨 **Never read a long test run through `tail`.** Redirect and grep.
- 🚨 **`git checkout -- <dir>` threw away uncommitted work.**
- 🚨 **Python's stdout is cp1252 here.** Set `PYTHONIOENCODING=utf-8`.
- **A render proves a screen DREW, not that what it drew ADDS UP.** §3.5 was
  photographed 227 times a run for weeks.
- **A green sweep over EMPTY providers proves nothing either.** §3.13.
- **`find.text` cannot see a `TextSpan`**, and a status chip draws UPPERCASE
  where the semantics label is mixed case.
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

### Lessons added 2026-08-23 (second session)

```powershell
# The CPU rule, mechanised — run it the moment a browser flow ends:
Get-CimInstance Win32_Process | Where-Object { $_.Name -eq 'chrome.exe' -and $_.CommandLine -like '*ml-chrome-*' } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force }
```

```bash
# Headless, not off-screen. Same profile dir keeps the signed-in session.
"/c/Program Files/Google/Chrome/Application/chrome.exe" --headless=new \
  --remote-debugging-port=9222 --user-data-dir="<scratch>/ml-chrome-A" \
  --no-first-run --no-default-browser-check --window-size=1600,1000 \
  --disable-background-timer-throttling --disable-backgrounding-occluded-windows \
  --disable-renderer-backgrounding --use-gl=angle --use-angle=swiftshader \
  --enable-unsafe-swiftshader "http://127.0.0.1:8123/"
# second browser: --remote-debugging-port=9223, a different profile dir,
# and CDP_PORT=9223 in front of every cdp.py / takepic.py / setfile.py call.
```

- The helpers (`cdp.py`, `setfile.py`, `takepic.py`, `attach_photos.py`,
  `fix_eol.py`, `pod.jpg`, the fixture PDFs) live in THIS session's
  scratchpad, `…\850c86b2-7712-4015-8a50-5dfcda589d21\scratchpad\`, and the
  older copies in the shared `…\Temp\claude\scratchpad\`. Copy them forward.
- Phone: long `wait` batches drop the link (`ConnectionAbortedError`); keep
  a batch under ~30 s and re-shoot. The NAS listing timestamp DID move for
  the new APK (02:09 → 04:50) — still compare the SHA-256.
- The phone's screen went to sleep once mid-session (04:24) and Jean woke
  it within minutes; asked, kept working, re-probed.

---

### Lessons added 2026-08-23 (fourth session)

- 🚨 **A power cut zeroes the files being written, not just the one.** After
  the cut `git status` said `index file corrupt` and four modified files were
  entirely NUL bytes (NTFS had allocated the new length and never flushed).
  Recovery that worked, in order: `mv .git/index .git/index.corrupt-<date>`
  then `git reset` (rebuilds the index from HEAD, touches no working file);
  `git fsck --no-dangling`; `file <path>` / `tr -d '\0' < f | wc -c` on every
  modified file — a `data` type with 0 non-NUL bytes is a destroyed file;
  `git checkout -- <those files>`; then a tree-wide scan for any other file
  whose first 4 KB is all NUL (`tool/phase3_helpers/` has no script for this
  — it was a ten-line inline Python; write it again, it is in §3.26). The
  committed tree was intact throughout. **Commit after every fix; an edit in
  flight is the only thing a cut can take.**
- 🚨 **Never put `|` inside `--name` on this shell.** `flutter test
  test/renders --update-goldens --name "locations|profile"` was parsed as a
  pipe to a command called `profile`; nothing ran, no error that looked like
  one, and a golden was committed a digit stale. Run the whole suite (~50 s)
  or one `--name` at a time.
- **A width rule is not a fit rule.** `MlPageHeader` stacked its tools under
  560px and that cost every header whose tools fit a line; 43 goldens moved
  and the change was reverted. Measure (`_HeaderLayout`, a 120-line render
  object) when the question is "does it fit", not "how wide is the screen".
- **A loose `Flexible` keeps its unused allotment.** `Flexible(meta) ·
  Expanded(action)` left the action at x=231 of 360: the meta's half was
  allotted, not redistributed. Bounded non-flex (`ConstrainedBox`) for the
  short child, `Expanded` for the one that should take the rest.
- **Reviewer agents overwrite scratchpad files by name.** One rewrote
  `crop.py`; name the session's helpers distinctly (`my*.py`) or commit them
  (`tool/phase3_helpers/`).
- **A meta line that counts rows lies whenever the rows are not the thing it
  names** — found four times in one session ("3 delivered loads" over a
  Pending row, "2 certificates" over one cert, "2 of 3 set" over one
  CONFIGURED badge, "3 reportings" under "3 trucks reporting"). Count the
  predicate, and do not repeat a count the page header already carries.
- **A fixture with a summary and no items lies the same way.** The setup
  card itemises `items` and said "Nothing outstanding" at 70% with a licence
  missing, because the first fixture supplied the summary alone.
- **The one-clock guard earns its keep**: `MlTime.sast` asserts its input is
  UTC and refused a calendar day on the first draft of a date cell. Format a
  day with `calendarDay`; never convert it.
- **Heredocs still eat escapes.** `'Driver\'s licence'` inside a bash heredoc
  reached Dart as `'Driver's licence'`. Write patch scripts with the Write
  tool and run them with `py -3` (`tool/phase3_helpers/mypatch.py` matches
  the file's own line endings, which a naive `replace` does not — half the
  repo is CRLF).
- **`mlCount(n, 'reporting')` pluralises to "reportings".** Pass the plural.
- **A reviewer's "fix" can be worse than the fault.** "Ellipsise the CTA" read
  "Message F…"; dropping the name under 200px was the right shape. Look at
  the render after every fix, not only at the test.


### Lessons added 2026-08-23 (fifth session)

- 🚨 **A FIX THAT CHANGES NOTHING WILL PASS ITS OWN TEST. SABOTAGE FIRST,
  AND IF THE SABOTAGE PASSES, THE FIX IS THE SUSPECT.** The available-route
  chip looked exactly like CLAUDE.md §10.4, so it got a `ConstrainedBox` and a
  geometry test. Removing the `ConstrainedBox` left every case green.
  `RenderWrap` bounds its children already — 33..379 inside a card at 16..396,
  measured, with and without. The real fault was one `Chip` clipping a label
  with no `maxLines`. Twenty lines became two.
- 🚨 **PROBE THE REAL WIDGET AT THE REAL WIDTH.** The first probe for that
  chip used a synthetic `SizedBox(width: 380)` and reproduced nothing. Mounting
  the actual section inside the horizontal padding `MlPageBody` gives it is
  what produced the numbers above. A synthetic reproduction that disagrees with
  the golden is evidence about the reproduction.
- 🚨 **`unphotographed_screens.py` COUNTS CLASS NAMES, AND IT SAYS SO.**
  It reported 94/94 while every picture of `BuyerRequestsScreen` was the buyer's
  half and the mine's `isMine: true` variant had never been drawn. Creating it
  found a real copy fault; creating a desktop render of the buyer's
  reconciliations found a much worse one. **When a task's report lists missing
  renders, they are part of the task.**
- **A count is only as honest as the query under it.** Before printing a meta,
  ask what the number is summed over. The employee grid's would have been a lie
  because the repository cached a page under the roster's key; the weight
  reconciliation's three cards were two populations side by side.
- **Substring matching in a tone map is a trap in both directions.**
  `'on route'` is not `'en route'` and matched nothing; `'inactive'` CONTAINS
  `'active'` and came out green. Word-bound the short words, and put the
  negative case above the positive one.
- **A `FittedBox` scales the PAINTED result.** The declared `fontSize` does not
  change, so a test comparing font sizes passes with the fault in place. Compare
  drawn HEIGHT. And when checking for an ancestor widget type, walk the whole
  chain — `paragraph.parent` was not it.
- **Three shapes can each be wrong in a different direction.** The live map's
  pill: a `FittedBox` shrank it; removing the `FittedBox` cut the PLATE instead;
  measuring per row made two adjacent rows with the same status lay out
  differently. Uniform-and-stacked was the fourth try. Keep the failures in the
  comment — each is a plausible "simplification" for the next reader.
- 🚨 **`mypatch.py` TRUNCATES BEFORE IT ENCODES — it did not, now.** An
  unpaired surrogate in a patch emptied a Dart file to zero bytes and only then
  raised. It encodes first and renames a temp file into place now. **And
  `flutter analyze` reports "No issues found!" for a zero-byte Dart file**, so
  analyze passing is not evidence a file still has anything in it.
- **The bash heredoc still eats backslashes**, even quoted (`<<'PYEOF'`). It ate
  `\'` out of a Dart string literal and produced a syntax error forty lines
  away. Write patch scripts with the Write tool.
- **`code.cmd` is STABLE VS Code, and Jean runs INSIDERS.** It exits 0 and the
  running window never changes tab, so the Phase 0 tick was being earned by an
  exit code rather than by a window. The CLI that reaches his window is
  `C:\Program Files\Microsoft VS Code Insiders\bin\code-insiders.cmd
  --reuse-window "<file>"`. Check the title with `Get-Process`, not the exit code.
- **Run the guards BEFORE claiming a task is done, not only at the session's
  end.** They caught two of this session's own edits on work committed hours
  earlier — a header test measuring in stock Material's font, and a false
  positive worth exempting properly rather than bending the copy around.


### Lessons added 2026-08-23 (sixth session)

- 🚨 **A REFERENCE MEASURED FROM THE THING UNDER TEST IS ONLY A REFERENCE
  WHILE THE THING UNDER TEST IS RIGHT.** The stat-caption test divided each
  caption's height by the height of the shortest caption in the same render.
  Under the fault, that one wraps too — so the reference was two lines tall,
  every caption measured as exactly "1", and the sabotage PASSED at 380px. It
  counts selection boxes now (`getBoxesForSelection`, one box per painted
  line; `computeLineMetrics` is not on `RenderParagraph` in this Flutter).
- 🚨 **A GREEN TEST SUITE DOES NOT MEAN A RENDER SHOWS WHAT ITS NAME SAYS.**
  `dialog-add-vehicle-phone-dark` opens its dialog in an `act` that taps a
  control and **returns quietly if the control is missing**. Removing the FAB
  turned it into a picture of the screen behind it, with 268 render tests
  green. All fifteen such guards in that file were made to report and the suite
  run — only that one was tripping. **When you remove or rename a control, grep
  `test/renders` for it.**
- 🚨 **A WIDGET'S DECLARED CONSTRAINTS ARE NOT ITS RENDERED SIZE.** Every fleet
  action button declares `BoxConstraints(maxWidth: 40, maxHeight: 40)` and
  renders at **48×48**, because `IconButton` keeps Material's padded tap
  target. Two guesses at the column width (168, then 184) both wrapped the
  fourth button onto a second row. Measure it in a test and print the rect;
  don't read the number in the source.
- **A figure column is sized by its HEAD, not by its digits.** `ODOMETER` is a
  longer string than `412 300`, and at flex 2 the head read `ODOMETE / R`.
- **`NumberFormat.decimalPattern` keeps up to THREE fraction digits.** It is
  not a drop-in for `NumberFormat('#,##0')`, which rounds. Swapping them turned
  every whole-rand figure on the earnings screen into `R29,159.2` with nine
  unit tests green. `decimalPatternDigits(decimalDigits: 0)` is the one that
  takes an answer.
- **`MlWideTable` and infinite width.** `constraints.maxWidth >= minWidth` is
  trivially true for infinity, so "wide enough already" was exactly backwards
  for a caller inside a horizontal scroll view. Any `isFinite`-free comparison
  against a constraint has this bug latent in it.
- **Sabotage the SHARED component, not just the screen.** The three fleet-table
  sabotages that mattered were a `minWidth`, an em dash and a pinned width —
  one line each, and each named a different one of the three claims the test
  makes. A sabotage that changes several things at once proves less.
- 🚨 **BACKTICKS IN A `py -3 -c "…"` ARE COMMAND SUBSTITUTION.** A comment
  reading ``which already read `Trucks on route` `` reached the file as "which
  already read . The screen…", and `git commit -m "…`act`…"` silently dropped
  the word and printed `act: command not found`. The handoff already said to
  write patch scripts with the Write tool; **that applies to commit messages
  too — use `git commit -F` with a heredoc, or a file.**
- 🚨 **`\ud83d\udea8` IS AN UNPAIRED SURROGATE PAIR IN A PYTHON STRING, AND
  `mypatch.py` REFUSES IT.** It raised on `s.encode('utf-8')` **before**
  touching the target — which is the hardening the fifth session added working
  exactly as intended. Write the emoji itself; Python source is UTF-8.
- 🚨 **CHECK WHO ELSE IS WRITING BEFORE `git add -A`.** Another process
  regenerated every launcher icon in this repo mid-session and left a Gradle
  build running. `git status --porcelain` plus `ls --time-style=full-iso` on a
  surprising file tells you in ten seconds; `Get-CimInstance Win32_Process`
  tells you whether it is still going. Commit with explicit paths when in
  doubt, and never `git checkout --` files you did not touch.


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
   other surface. Confirmed again this session: the load recorded by "Controller
   Test" wrote `dispatched_by: "Controller"`.
4. **NOTHING SERVER-SIDE RATE-LIMITS AN INSERT INTO `crash_reports`.** The
   client is the only thing between one looping browser and the 500 MB ceiling,
   and the SHIPPING app shares this database.
5. **`prune_telemetry_job()` runs at 90 days** — far too slow to defend against
   a burst that reached 293 MB in four hours.
6. 🆕 **`record_truck_load` RECORDS A LOAD IT COULD NOT DEDUCT, AND SAYS
   NOTHING.** Measured this session on trip `0d9c6792`: the button reads
   *"Confirm load & deduct from stockpile"*, 34.2 t was recorded, and **no
   `stockpile_transactions` row was written** — the FIFO loop selects piles
   `where balance_tons > 0` matching the order, route or buyer, and this order's
   own pile held 0 t. `v_deducted` stays false and nothing is raised.

   Reachable in real operation: a controller weighing a truck before the
   supervisor has added the day's tonnage. The shortfall is known at the point
   it happens (`v_remaining` after the loop) — a `raise warning`, a
   `metadata.undeducted_tons` stamp, or a notification to the supervisor would
   all beat silence. **Not fixed in Dart on purpose**: reimplementing the
   server's pile-matching rules in the client to warn ahead of time would put a
   second, drifting copy of that logic in the UI, which CLAUDE.md §6 forbids in
   as many words.
7. 🆕 **`transportation_requests.seal_required` and `routes.seal_required`
   diverge in production and nothing reconciles them.** §3.9 fixes which one the
   transporter is SHOWN. The two columns still disagree on route `56a1209a`,
   and the admin's own free-text note agrees with the route. Either linking
   should copy the flag onto the request, or the request's copy should stop
   being a source of truth once a route exists.

---

8. 🆕 **`accept_request_dispatch` tells an already-assigned driver nothing.**
   It notifies the transporter's admin/management, and only about DRIVERLESS
   trucks. Measured 2026-08-23: S6W001GP accepted onto RT-1ADEE49D with
   Driver Test on it — 0 driver notifications. The order-aware notice exists
   but fires only from `add_vehicle_driver`. In `M3-TASKS.md` Phase 5.

---

## 7. The project's own rules still apply

`CLAUDE.md` in this repo is the fork's copy of the shipping app's. Especially:

- **§1** — LEAVE THE DATABASE HEALTHY. Prove it with a probe, not a status
  field; throttle bulk work.
- **§7.1** — one clock, Africa/Johannesburg. **Four of this session's twelve
  defects were §7.1-adjacent and none of them was visible on a SAST machine.**
- **§10.2** — two Supabase projects, both production, both free plan; the MCP
  only reaches one.
- **§10.4 / §10.5 / §7** — layout traps, and a green test over an empty
  fixture or a fallback font proves nothing. §3.13 is the largest instance of
  §10.5 found so far.
- **§10.6** — Dart bitwise operators are unsigned 32-bit on the web.
- **§1** — the package is `flutter_application_1`. Do not rename it.
- **§5** — design tokens are law.

---

## 8. COPY-PASTE MESSAGE FOR THE NEXT CHAT

Everything between the rules is the message. It is self-contained.

---

Continue the MineLink Material 3 redesign, exactly where the last session left off. The work is driven by ONE MARKABLE FILE. Read these in this order before doing anything else.

**1. THE MARKABLE TASK FILE — THE SINGLE SOURCE OF WHAT IS DONE AND WHAT IS LEFT:**

`C:\Users\Somebody Someone\Music\SHOWME!\MineLink-M3\M3-TASKS.md`

Seven phases, checkboxes, evidence lines, a session log. Open it in Jean's IDE THE MOMENT YOU START and keep it open all session. Jean runs VS Code **INSIDERS**, so the `code.cmd` older handoffs name does nothing visible — it exits 0 and his window never changes tab. Use:

```
& "C:\Program Files\Microsoft VS Code Insiders\bin\code-insiders.cmd" --reuse-window "C:\Users\Somebody Someone\Music\SHOWME!\MineLink-M3\M3-TASKS.md"
```

then CHECK IT WORKED with `Get-Process | Where-Object { $_.ProcessName -match 'Code' -and $_.MainWindowTitle -ne '' }` — the title must read `M3-TASKS.md - MineLink-M3 - …`. **Do not trust the exit code.** Jean watches this tab and sometimes EDITS it himself; keep his wording and commit it with your next change.

**2. THE PROJECT HANDOFF** — how the redesign got here, how to drive a browser WITHOUT touching Jean's mouse (§5), how to drive his phone (§5), the Phase 3 METHOD and the nine classes of drift (§5), what the last three sessions fixed and must not be redone (§3.28, §3.27, §3.26), exactly what is left (§4.1), what is owed to the SHIPPING app (§6):

`C:\Users\Somebody Someone\Music\SHOWME!\MineLink-M3\HANDOFF.md`

Read "WHERE THIS SESSION STOPPED", §0, §1, §2, §3.28 then §3.27 then §3.26, §4, §5 (including "Lessons added 2026-08-23 (sixth session)"), §6. **Where HANDOFF.md and M3-TASKS.md disagree about what is left, M3-TASKS.md wins.**

**3. THE REVIEWER REPORTS** — read-only agent reports, one per Phase 3 scope, with file:line for every finding:

`C:\Users\Somebody Someone\Music\SHOWME!\MineLink-M3\docs\redesign\reviews\2026-08-23-phase3\`
(`agent_brief.md`, `report_transporter.md`, `report_driver.md`, `report_shared.md`, plus `report_mine.md` and `report_buyer.md`, both closed)

**4. THE OLDER MACHINE-WIDE HANDOFF — BACKGROUND ONLY, DO NOT WORK FROM IT:**

`C:\Users\Somebody Someone\Claude\HANDOFF.md`
Dated 2026-08-08: MCP servers, the decoy folders, the phone rig. Read it only if Jean asks about that setup.

---

### THE PATHS THAT MATTER

Work happens here (its own git repo, branch `main`, no remote):

`C:\Users\Somebody Someone\Music\SHOWME!\MineLink-M3`

NEVER TOUCHED, for any reason:

`C:\Users\Somebody Someone\Music\SHOWME!\worktree-2026-05-05T11-53-29`

### THE ONE RULE THAT MUST NOT BREAK

Jean's words: *"NO CHANGES WHAT SO EVER INSIDE OF `C:\Users\Somebody Someone\Music\SHOWME!\worktree-2026-05-05T11-53-29` then I'm happy"*.

Its verified baseline, re-checked at the start and end of every session:

```
HEAD              df451d0
git status        exactly 3 modified files, all pre-existing:
                    M .design-sync/config.json
                    M lib/features/super_admin/screens/margin_ledger_screen.dart
                    M test/widgets/app_sidebar_behaviour_test.dart
file count        14163   (find . -path ./.git -prune -o -type f -print | wc -l)
git worktree list 2 entries (the main repo 4df071c + this worktree df451d0)
modified today    0
```

(The plain `find . -type f -not -path "./.git/*"` returns **14164** because in a WORKTREE `.git` is a FILE — same untouched tree.) Reading it is fine; writing to it, or running any MUTATING git command in it, is not. `supabase/` inside MineLink-M3 is frozen too — anything needing a migration is REPORTED under Phase 5 / HANDOFF §6, never applied. **Re-checked at the end of the sixth session: all five figures exactly as above.**

---

### HOW THE MARKABLE FILE WORKS

Work the phases IN ORDER. Phase 0 start items → Phase 3's remaining tasks → nothing else. Phases 4, 5, 6, 7 and the "Decisions only Jean can make" are BLOCKED ON JEAN: do not start them, do not tick them, leave their ⏸ lines in place and name them in your report.

- **AFTER EACH TASK IS COMPLETED, MARK IT COMPLETED IMMEDIATELY:** change `- [ ]` to `- [x]` and put an evidence line directly under it:
  `✅ <date> · commit <sha> · proven by <what was run / seen / measured>`
  Then COMMIT `M3-TASKS.md` together with the work it records. **Never increment a count by hand** — recount with `grep -c '^- \[x\]' M3-TASKS.md` (it is **16** right now).
- Jean's rule, verbatim: *"FROM HERE ON FORWARD WITH EVERY TASK, NO TASK SHOULD BE STARTED UNLESS THE PREVIOUS TASK WAS FULLY AND PROPERLY MARKED OFF TRUTHFULLY!"*
- And, verbatim: *"you're not marking your tasks as you should, AFTER ANY AND EVERY TASK IS COMPLETED IT SHOULD BE MARKED OFF RIGHT AFTER THAT! ONLY IF IT'S 100% TRUE!"* — so: tick the moment it is proven; **REOPEN a tick that is no longer true** (the previous session's end-of-session ticks must not stand in a new session); record progress on an open task as a `▶ IN PROGRESS` line under it and commit the file with the work; a task that cannot move keeps `- [ ]` and gets `⏸ BLOCKED — <on what> — <what unblocks it>`. A blocked or in-progress task is never a done task.
- A phase gets `Status: DONE <date>` only when every task in it is ticked.
- Update the "Last updated" line (date · commit count · tip) every time you commit the file, and add ONE line to the Session log at the end of the session.
- Everything already ticked was proven before being ticked. Anything under "Deliberately NOT on this list" stays off the list.

---

### VERIFIED STATE AT THE MOMENT THIS MESSAGE WAS WRITTEN

```
MineLink-M3                 268 commits. Last CODE commit 83304a1; the tip is the docs commit
                            carrying this message. M3-TASKS.md has 16 ticks.
flutter analyze             No issues found! (whole tree)
flutter test (full)         2697 passed · 1 skipped · 0 failed  (2647 at the session's start)
dart tool/release_guards    43/43 PASS · 0 FAIL.  --selftest: all 43 bite.
py -3 tool/_sabotage.py     ALL SABOTAGES CAUGHT
the seven Python checks     all green (type_scale --selftest OK · dropdown_width clean ·
                            glyph_coverage clean · one_clock PASS 0 sites + selftest ·
                            unphotographed 94/94 · health_probe 7/7 — the EXTRAS project's
                            search_place_index answered on the RETRY after idling, as always)
flutter test test/renders   268 passed, PLAIN run (no --update-goldens) — goldens current
build/web                   FRESH (flutter build web --release at the tip code)
flutter build apk --debug   🚨 NOT RUN — see below. APK on disk is STALE (61861FA9…, eight code
                            commits behind); APK on the phone older still (1ad4c725).
Jean's phone (SM-G780G)     NOT touched this session. Left as the previous session left it:
                            platform admin on home, 0 screenshots. Check `probe` before any use.
Android emulator            NOT running (AVD minelink_test; adb at C:\Android\sdk\platform-tools)
Browsers                    NONE opened this session at any point. 0 ml-chrome-*, nothing on
                            9222/9223.
Helpers                     committed under tool/phase3_helpers/ (README there): mypatch.py
                            (line-ending-aware exact patching — IMPORT IT; it is truncation-safe
                            and it REFUSED a bad patch this session, exactly as designed),
                            mypair.py (HEAD-vs-working crop of a golden), golden_diff.py (measure
                            every moved golden; copy it to a scratch dir first, it writes crops
                            beside itself), fix_eol.py (run before every commit), plus
                            cdp.py/setfile.py/takepic.py/attach_photos.py/hover.py/emulate.py
                            (the browser driver, unused these three sessions).
Original worktree           df451d0 · 3 pre-existing modified · 14163 · 2 entries · 0 today
Live data left behind       nothing this session (no browser, no phone, no database writes).
```

🚨 **THERE IS A SECOND WRITER IN THIS REPO AND IT IS NOT A CLAUDE SESSION.** At 19:49–19:52 another process created `tool/icons/generate_app_icons.py` and regenerated **every launcher icon** — Android (`ic_launcher.png` ×5, new `ic_launcher_foreground.png` ×5, new `mipmap-anydpi-v26/`), iOS, macOS and web (`favicon.png`, `Icon-192`, `Icon-512`, both maskables) — and its Gradle/Java build (PID 4464, started 19:52:54) was **still running** when the session ended. **None of it is committed.** All eight of this session's commits were checked and carry zero icon files. **Do not `git add -A` until Jean confirms that work is his and finished; use explicit paths. Do not `git checkout --`, stash or clean those files — they are not yours.** This is also why `flutter build apk --debug` was skipped: a second Gradle build into the same tree would contend for its locks and cook Jean's CPU while his own build runs.

---

### WHAT TO DO, IN ORDER

**0. Phase 0 start items**, then:

**1. Run `flutter build apk --debug` and re-tick Phase 0's gate line.** It is the ONLY thing in the gate that did not run, and the gate task is `- [ ]` ⏸ BLOCKED for that one reason — nothing in it failed. Check the other process's build is gone first: `Get-CimInstance Win32_Process | Where-Object { $_.Name -match 'java' }`.

**2. Finish the Transporter portal task** (Phase 3, task 4 of 6). The `▶ IN PROGRESS` line under it is authoritative. Of the reviewer's 30 findings in `report_transporter.md`: **7 were already fixed** by the console/mine/buyer passes and verified in the render (#1, #2, #17, #19, #21, #22, #23); **3 are (Shared)** and wait for the Shared task (#24, #25, #26); **9 are fixed** (#11 last session; #4, #5, #6, #7, #8, #9, #10, #12, #13, #15, #16 this session). **TEN ARE LEFT:**

- **#3** the donuts have no legend (`transporter_portal_dashboard_screen.dart:467-494`; also mine :476 and buyer :426 — `MlDonut` in `minelink_charts.dart:812` has no legend slot).
- **#14** the drivers screen's hand-rolled `_Stat` (`transporter_drivers_screen.dart:223-262`) — titleLarge w800 sans, no bar → `MlStatCard`.
- **#18** request tracking repeats its page title as a section title with the same meta (`transporter_request_tracking_screen.dart:29-37` + `request_tracking_view.dart:35-47`).
- **#20** "Reconciliation batches" as a bare `titleMedium` w800 sans (`transporter_reconciliations_screen.dart:63-68`) → `MlSectionTitle`; check the mine and buyer recon screens too.
- **#27** the dispatch sheet's sans title and accent metrics (`dispatch_route_widgets.dart:269-273`, `:338-342`, `:511-513`).
- **#28** trip status as muted subtitle text instead of a badge (`transporter_routes_screen.dart:208-214`).
- **#29** the compliance document list with no section head (`compliance_screen.dart:107-150`).
- **#30** fixtures put `TN 55 QQ GP` under Fixture Haulage when it is not in the fleet (`portal_tail_fixtures.dart:358,691`).
- **THE MISSING RENDERS LIST** at the bottom of that report — accept-route sheet, `_AssignTrucksDialog`, `DriverAssignmentDialog`, transporter live-map, transporter trips/tons-out, light for most, phone for routes/maintenance/earnings/truck-locations/recon, desktop trucks-on-route. **This is part of the task, not an extra:** the fifth and sixth sessions found THREE real defects purely by creating a render that did not exist, and `unphotographed_screens.py` cannot see the gap because it counts class NAMES.

When every finding is in, tick the Transporter task with an evidence line naming every fix and every "reviewed, no drift" screen, flip the rows in `docs/redesign/VERIFICATION.md`, and commit `M3-TASKS.md` with it.

**3. Then Driver app, then Shared** — one task at a time, each ticked before the next starts. Start each from its report, verify every finding IN THE RENDER (not from the report), skip the ones already fixed, and record "reviewed, no drift" in `VERIFICATION.md` so nobody re-derives it.

**4. Phases 4–7 and the Decisions: blocked on Jean.** Do not tick, do not start. Three decisions the reviewers surfaced (the chat dock's Nord palette, dialog titles in sans, the login page's gold) are still to be added to the decisions list when the Shared task is reached.

**THE METHOD** (HANDOFF §5, "The Phase 3 method"): LOOK at the render beside `docs/design-reference/*.png` and §4–§5 of `docs/design-reference.md`; fix drift at its CAUSE (the shared component where one exists); regenerate with `flutter test test/renders --update-goldens` (the WHOLE suite — never `--name "a|b"`, this shell eats the `|`); LOOK again (`tool/phase3_helpers/golden_diff.py` + `mypair.py`); pin with a test; SABOTAGE it (stash the lib file → the test must FAIL → pop; keep a case that stays GREEN); one commit per fix; then flip the row in `docs/redesign/VERIFICATION.md`.

---

### REVIEWER AGENTS

Jean asked for them and they worked; keep the shape: read-only, one per scope, reporting by the nine classes with file:line and an "original: same/differs" check; the session stays the SINGLE WRITER (one tree, one golden suite, shared components that move 58 goldens at once). They never edit, never run flutter/dart, never open a browser or touch the phone, and never write a scratchpad file under a name you use. **Verify everything they report before acting on it** — 19 of 53 findings across the buyer and transporter reports were already fixed.

---

### 🚨 IF YOU NEED THE PHONE AND IT DOES NOT ANSWER

Stop. If `status` says "no address", or `probe` is under 0.1 bits/pixel (display asleep) — PAUSE THAT STEP RIGHT THERE AND TELL JEAN, THEN KEEP WORKING ON WHAT DOES NOT NEED IT and re-probe as you go. Jean's words: *"if you need to use my phone via ctrl bridge and the phone is not responding that you should pause the process right there so that I'll respond to you that the phone is no longer asleep and that you can try again"*. Only he can enable host mode and only he can wake the screen; injected touches cannot. Do NOT work around it and do NOT report green as though the phone step were optional. HOST MODE STAYING ON DOES NOT MEAN THE SCREEN IS AWAKE: check `probe`, not just `status`. Invoke the `driving-jeans-phone` skill FIRST the moment you need to touch the phone. It is his PERSONAL phone: prefer `sig`/`changed`/`waitstable` over `shot`, delete every screenshot you take, never switch on live-location sharing (it writes his real position), and leave it signed in as the platform admin on `home`. Installing over the NAS: My Files → Network storage → jean → Shared → PhoneRemote → `minelink-m3.apk` → Update → Open; back out and re-enter the folder to refresh the cached listing; compare the SHA-256 (the phone's clock is ~2h36m slow); keep the screen alive with status-bar taps in batches under 30 s (a long wait drops the link); decline "Turn on Play Protect".

### 🚨 DO NOT MOVE JEAN'S MOUSE

He works at this machine while you run. His words: *"bro make a nother plan for a mouse, I'm using mine"*. Drive the browser through CDP (HANDOFF §5) or use the Android emulator. Switch accounts by clearing `localStorage('sb-yftazblpmicqtamyiwyb-auth-token')` and reloading (CDP clicks do not reach popup menus).

### 🚨 DO NOT COOK HIS CPU

One headless Chrome only for the minutes a flow needs (two, on 9222 and 9223, only for a two-account flow); `Stop-Process` every `chrome.exe` whose command line contains `ml-chrome-` the moment it is done (HANDOFF §5 has the one-liner). Never leave one running while you write code or docs. **And check whether Jean is already building before you start a build** — he was, this session.

---

### HOW TO WORK — THIS IS JEAN'S INSTRUCTION, FOLLOW IT

Work long and don't stop to check in. Fix what you find, as you go, and PROVE the fix: pin it with a test, then SABOTAGE the fix (stash the lib file → the test must FAIL → pop; and keep a case that stays GREEN under the sabotage). If a fix is visible on a device or in a browser, LOOK AT IT THERE TOO. Half-implemented work, TODOs, stubs, "later" notes are not acceptable — finish each thing.

**ONE TASK AT A TIME, MARKED BEFORE THE NEXT.** **FIX AS YOU GO** — do not collect a list of defects to fix later; each one gets its own commit, its own test and its own sabotage before you move on.

---

### THE GATE (Phase 0, end of session — run it in FULL before the end-of-session tick, and redirect every run to a file, then grep; a pipe hides a failing exit code and `tail` hides `[E]`)

```
flutter analyze
flutter test
dart tool/release_guards.dart
dart tool/release_guards.dart --selftest
py -3 tool/_sabotage.py
py -3 tool/type_scale_codemod.py --selftest
py -3 tool/dropdown_width_check.py
py -3 tool/glyph_coverage_check.py
py -3 tool/one_clock_check.py
py -3 tool/one_clock_check.py --selftest
py -3 tool/unphotographed_screens.py
py -3 tool/health_probe.py          (retry once if the extras project is cold)
flutter test test/renders           (plain, after any visual change; golden_diff.py measures moved PNGs)
flutter build web --release
flutter build apk --debug
```

### THE RIG — things that already went wrong; do not re-learn them

- A POWER CUT destroys every file that is mid-write (pure NUL bytes) and has corrupted `.git/index` once. HANDOFF §5 has the recovery. **Commit after every fix**; an edit in flight is the only thing a cut can take.
- **`mypatch.py` encodes before it writes** (a truncating version once emptied a Dart file to zero bytes). It REFUSED a bad patch this session and left the target untouched — that is it working. And `flutter analyze` reports "No issues found!" for a **zero-byte** Dart file, so analyze passing is not evidence a file still has content.
- **`--name "a|b"` is eaten by this shell** (the `|` becomes a pipe): run the whole render suite, or one `--name` at a time.
- **A bash heredoc eats backslashes and apostrophe escapes — even quoted. And BACKTICKS INSIDE `py -3 -c "…"` OR `git commit -m "…"` ARE COMMAND SUBSTITUTION** — both bit this session, silently deleting words from a comment and from a commit message. Write patch scripts with the Write tool and run them with `py -3` through `tool/phase3_helpers/mypatch.py` (half the repo is CRLF and a naive replace misses); write commit messages with `git commit -F` and a quoted heredoc. Python's stdout is cp1252 here: set `PYTHONIOENCODING=utf-8`.
- **A `'''…'''` Python block turns `\u2014` into the literal text `\u2014`** if you double the backslash. Grep the patched file for `\\u[0-9a-f]{4}` afterwards.
- **A pipe hides a failing exit code**; redirect, then grep. Never read a test run through `tail` — grep for `[E]`.
- **A fix that changes nothing will pass its own test.** Sabotage first; if the sabotage passes, the FIX is the suspect.
- **Probe the REAL widget at the REAL width.** A synthetic reproduction that disagrees with the golden is evidence about the reproduction. And a widget's declared `BoxConstraints` are not its rendered size — an `IconButton` saying `maxWidth: 40` renders at **48**.
- **A reference measured from the thing under test is only a reference while the thing under test is right** — a line-height reference wrapped under the fault and made a test pass under its own sabotage.
- **`unphotographed_screens.py` counts class NAMES**, and says so in its own header. A screen whose every picture is the wrong variant reads as photographed. **And a render's `act` can return quietly when the control it taps is gone**, turning a render named *dialog* into a picture of the screen behind it with the suite green — grep `test/renders` for any control you remove or rename.
- **A `FittedBox` scales the painted result**, so a test comparing declared `fontSize` passes with the fault in place. Compare drawn height, and walk the whole ancestor chain rather than `.parent`.
- **A meta line that counts rows lies when the rows are not the thing it names**; a fixture with a summary and no items lies the same way. **Look at the render after every fix, not only at the test.**
- **A golden that moves with no code change is a CACHE or an async thing.**

---

### WHEN JEAN SAYS "PAUSE HERE"

STOP READING AND PRODUCE THE MESSAGE. Rewrite `C:\Users\Somebody Someone\Music\SHOWME!\MineLink-M3\HANDOFF.md` the same way — verified state only, no intentions — ending with a fresh self-contained copy-paste block in §8 that carries ALL THREE paths (`M3-TASKS.md`, `MineLink-M3\HANDOFF.md` and `C:\Users\Somebody Someone\Claude\HANDOFF.md`) plus the reviewer reports' path, the untouchable worktree path and its baseline, exactly where you stopped, what is already ticked so it is not redone, HOW THE MARKABLE FILE WORKS, THE PHONE RULE, THE MOUSE RULE, THE CPU RULE, the reviewer-agent rule, this same HOW TO WORK instruction quoted verbatim, the one-task-at-a-time rule, and the fix-as-you-go rule. Add the session's line to `M3-TASKS.md`'s Session log. Commit both. State the commit count the tree WILL be at once that commit lands, and say that the tip is the commit carrying the file, so that includes itself. Put the message in the chat as well, whole. Before producing it, make sure every task that is truly proven is ticked and nothing unproven is.

---
