# MineLink M3 — session handoff

**Rewritten a fourth time on 2026-08-23, at the end of the session that
started the Phase 3 Mine-portal pass, deployed five read-only reviewer agents
over all five remaining portals, landed 23 fixes (six of them in shared
components that move every portal), survived a power cut mid-write, and was
paused by Jean before the Mine task could be ticked.** Everything below is
verified state, not intention. It replaces the previous handoff of the same
name; the previous rewrites' paragraphs are kept under §3 for their record.

**This file lives at**
`C:\Users\Somebody Someone\Music\SHOWME!\MineLink-M3\HANDOFF.md`

The older, machine-wide handoff is at
`C:\Users\Somebody Someone\Claude\HANDOFF.md` — MCP servers, git position,
decoy folders, the phone tooling, dated 2026-08-08. **Background only; this
file governs the redesign work.**

---

## WHERE THIS SESSION STOPPED — READ THIS FIRST

The tree is **clean**, **234 commits**, nothing half-applied and
nothing uncommitted. **The tip is the commit that carries THIS FILE**, so the
count above includes it. The last code commit under it is `9740420` (the
employee register's accent); the last shared-component fix is `bcb0fdb`.

**The original worktree was re-checked against its §0 baseline at the end of
the session and is untouched** — HEAD `df451d0`, the same three pre-existing
modified files, 14163 files under the `-prune` form, two worktree entries,
nothing modified today.

**Jean paused the session** with: *"please pause here and give me a full
proper correct copy paste message…"*. So: `M3-TASKS.md` has **15 ticks** —
Phase 0's four items are all ticked with this session's evidence — the
whole gate ran green at the tip, builds included (§2) — Phases 1 and 2 are
DONE from before, **Phase 3's console task is DONE from
before and its Mine task is `- [ ]` with a `▶ IN PROGRESS` line listing all
23 fixes and the five findings still open** — it is NOT ticked because five
reviewer findings on four screens are not fixed and the per-screen table is
not complete. Buyer, Transporter, Driver and Shared are untouched `- [ ]`,
but their reviewer reports are already written and in the repo (§4.1).

### What this session did, in one paragraph

It reviewed the mine dashboard, gate, weighbridge and operations hub by hand
against the reference, then — on Jean's instruction to "deploy your best
agents" — launched five read-only reviewer agents in parallel, one per
remaining Phase 3 scope, each reporting drift by the console pass's nine
classes with code locations and an "is it also in the original?" check. It
kept a single writer: every fix was verified in the render and the code,
made one commit at a time, pinned by a test that was sabotaged and bit, its
goldens measured with `golden_diff.py` and looked at. Twenty-three fixes
landed (§3.26): six in shared components (`SaSectionHeader`, `MlSectionTitle`
twice, `MlPageHeader`, the KPI tile, the flagship chart's caption and legend,
the status-tone map) that moved up to 58 goldens each, and seventeen on mine
screens — the largest being the Search loads screen rebuilt in the
vocabulary, where a real bug was found ("Last 24h" windowed on the midnight
date and read 71.12 t against 103.22 t for the same loads). A power cut hit
after `cf3608f`: `.git/index` was corrupt (rebuilt, fsck clean), four files
mid-write were zeroed to NUL bytes (restored from HEAD) and the in-flight
edit was redone. Three of the session's own fixes were caught by its own
instruments before they shipped (§3.26, "found by the instruments").

### 🚨 WHAT IS OWED FIRST

1. **Finish the Mine portal task** — five findings still open, all small,
   all located (file:line in `docs/redesign/VERIFICATION.md`'s Mine table and
   `docs/redesign/reviews/2026-08-23-phase3/report_mine.md` #40–#45):
   employee grid title; Buyers (every card takes the accent wash — pass
   `muted: true` on `BuyerOverviewCard`'s tile and drop the decorative
   shadow when muted; the page head → `MlPageHeader`); the mine's Requests
   copy ("transportation and **buyer** requests" for `isMine`) and its two
   actions into `MlPageHeader.actions` as `MlButton`s; trip detail (codes in
   `MlType.code`, facts in an `MlCard` + `MlSectionTitle`); company
   information labels (sentence case, single-word labels so they stop
   wrapping in the 130px column, the reference in mono). Then the
   VERIFICATION.md rows flip from *open* to a commit, the Mine task is
   ticked with an evidence line naming every fix and every "reviewed, no
   drift" screen, and `M3-TASKS.md` is committed with it.
2. **Then Buyer, Transporter, Driver, Shared — in that order, one at a
   time, each ticked before the next starts.** Their reports are written:
   `docs/redesign/reviews/2026-08-23-phase3/report_{buyer,transporter,
   driver,shared}.md`. Several of their findings are ALREADY FIXED by this
   session's shared-component commits — check each against §3.26 before
   touching it (the KPI delta chip, the legend's Target key, the section-title
   stacking, the page-header wrap, the recon counts, the status-tone map, the
   employees register, the company labels once done).
3. Nothing else. The whole gate is green at the tip (§2); `build/web` and
   the APK on disk (`34157bcf…`) are FRESH. The phone still runs `1ad4c725`;
   installing is not owed unless a Phase 3 fix needs glass.


## 0. Where you are

| | |
|---|---|
| **This project** | `C:\Users\Somebody Someone\Music\SHOWME!\MineLink-M3` |
| What it is | A **complete, independent fork** of MineLink, redesigned onto Material 3. Its own git repo (`main`), **234 commits**, clean tree, **no remote**. |
| **The task list** | `MineLink-M3\M3-TASKS.md` — the single markable source of what is done. 15 ticks. |
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

```
flutter analyze                                 No issues (whole tree, after the last commit)
flutter test (full)                             2578 passed · 1 skipped · 0 failed (after 9740420)
dart tool/release_guards.dart                   43/43 PASS
dart tool/release_guards.dart --selftest        43/43 PASS_SELF
py -3 tool/_sabotage.py                         ALL SABOTAGES CAUGHT
type_scale_codemod --selftest                   OK
dropdown_width_check                            every dropdown states isExpanded
glyph_coverage_check                            every character drawable (the ▲/▼ lines are its usual note, not failures)
one_clock_check (+ --selftest)                  PASS · selftest: every check bites
unphotographed_screens                          94 route-target screens · 94 named · 0 not
health_probe                                    7/7 — the extras project's search_place_index answered on the RETRY
                                                (2.66 s, cold after idling — the same pattern as every day so far);
                                                main 6/6 first time
flutter test test/renders                       263 passed — the PLAIN run (no --update-goldens)
                                                after 9740420; goldens current
flutter build web --release                     √ 76.9 s — build/web is FRESH (tip code)
flutter build apk --debug                       √ — SHA-256 34157bcf…, on disk only, NOT on the phone
APK on the handset                              1ad4c725 (2026-08-23 04:50); carries none of this
                                                session's fixes
M3-TASKS.md                                     15 ticks; Phase 0 all four ticked with this session's
                                                evidence; Phases 1, 2 DONE; Phase 3 console DONE,
                                                Mine ▶ IN PROGRESS (23 fixes, 5 findings open)
browsers                                        NONE opened this session; nothing on 9222/9223;
                                                the idle py -3 -m http.server 8123 over build/web
                                                (now FRESH) may still be running — harmless
phone                                           NOT touched this session (platform admin on home,
                                                0 screenshots, as the previous session left it)
```

Test count: 2531 at the start of the session's work (after the first five
fixes) → 2578. New test files: `flagship_trend_caption_test`,
`security_gate_heads_test`, `load_controller_copy_test`,
`operations_hub_heads_test`, `mine_figure_faces_test`,
`stockpile_audit_heads_test`, `recon_meta_counts_test`,
`quality_table_cells_test`, `search_loads_vocabulary_test`,
`mine_locations_heads_test`, `map_panels_test`,
`company_employees_register_test`, `employee_profile_tones_test`; cases added
to `portal_dashboard_kit_test`, `portal_section_header_test`,
`portal_page_header_test`, `status_badge_vocabulary_test`,
`tons_out_filter_test`, `employee_register_sweep_test`. Guards stay at 43.

---

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

### 4.1 Phase 3 — the Mine task is open with five findings; four tasks untouched

**Mine portal (`- [ ]`, `▶ IN PROGRESS`)** — five findings left, all small,
all located (`docs/redesign/VERIFICATION.md` Mine table, rows marked *open*;
`docs/redesign/reviews/2026-08-23-phase3/report_mine.md` #40–#45):

| screen | finding | where |
|---|---|---|
| employee grid | `'$companyName Employees'` title case; no meta | `lib/features/employee/screens/employee_grid_screen.dart:40` |
| Buyers | every `BuyerOverviewCard` takes `OverviewHeroTile`'s accent gradient + cyan shadow — pass `muted: true` and draw no shadow when muted (the tile has 9 call sites; do not re-skin the others); page head is `MlSectionTitle` + hand `Text` → `MlPageHeader(title, description, meta, actions: [Request buyers])` | `lib/features/portal/widgets/premium_overview_widgets.dart:36–46, 98–116, 268–300`; `lib/features/portal/screens/mine_supplier_buyers_detail_screen.dart:171–192` |
| Requests (`isMine: true`) — **no render exists** | description says "transportation and product requests" for a mine that raises transportation and **buyer** requests; the two actions sit in a left `Wrap` under the header as `FilledButton.tonalIcon` (blue) + `FilledButton.icon` (cyan) → `MlPageHeader.actions` with `MlButton.secondary` / `MlButton.primary`; add a mine-org render | `lib/features/portal/screens/buyer_requests_screen.dart:53–92` |
| trip detail | `TRP-000123`, `34.90 t` in sans w600 → `MlType.code`; the facts in a bare `Container` → `MlCard` + `MlSectionTitle('Trip facts', meta: …)` | `lib/features/portal/screens/portal_trip_detail_screen.dart:84–184` |
| company (`/portal/mine/company`, shared) | "Company Information" + "Company Name", "MineLink Reference", "WhatsApp Number", "Organization Type", "Created At", "Last Updated" — title case AND they wrap in the 130px label column at 1600px → sentence case, single-word labels ("Name", "Reference", "WhatsApp", "Org type", "Created", "Updated"); the reference code in `MlType.code` | `lib/features/company/screens/company_list_screen.dart:247–322` |

When those five are committed (each with a biting test, goldens looked at),
flip their VERIFICATION.md rows to the commit, add the "reviewed, no drift"
screens you also looked at, tick the Mine task with an evidence line naming
every fix, and commit `M3-TASKS.md` with it.

**Then, in order, one at a time:** Buyer → Transporter → Driver → Shared.
Each has a reviewer report in `docs/redesign/reviews/2026-08-23-phase3/`
(file:line, class, original-same-or-differs, suggested fix, and a "not
drift" list). **Check each finding against §3.26 first — many are already
fixed by this session's shared-component commits**: Buyer #1/#3/#7/#11/#12/
#13–#16/#18/#19/#21 and Transporter #1/#2/#17/#19/#21/#22/#23 map onto
`16fcfac`, `0057ef8`, `bb0de74`, `8dc3500`, `6752683`, `249106f`, `db9912d`,
`90a82c1`, `bcb0fdb` and the open company-labels item. Verify in the render
before closing any of them; a report is a lead, not a verdict.

### 4.2 The Phase 0 gate

Ran in full at the tip, green (§2). `build/web` and the APK on disk are
fresh; the phone still runs `1ad4c725` and installing is owed only if a
Phase 3 fix needs glass.

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

Phases 1 and 2 entirely. The console pass. The 23 fixes in §3.26 and every
row of the Mine table in VERIFICATION.md that carries a commit.


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

1. THE MARKABLE TASK FILE — THE SINGLE SOURCE OF WHAT IS DONE AND WHAT IS LEFT:

      C:\Users\Somebody Someone\Music\SHOWME!\MineLink-M3\M3-TASKS.md

   Seven phases, checkboxes, evidence lines, a session log. Open it in Jean's IDE THE MOMENT YOU START and keep it open the whole session:

      code "C:\Users\Somebody Someone\Music\SHOWME!\MineLink-M3\M3-TASKS.md"

   (the code CLI is `C:\Users\Somebody Someone\AppData\Local\Programs\Microsoft VS Code\bin\code.cmd`). Jean watches this tab and sometimes EDITS it himself; keep his wording, commit it with your next change. VS Code reloads it on every save.

2. THE PROJECT HANDOFF — how the redesign got here, how to drive a browser WITHOUT touching Jean's mouse (§5), how to drive his phone (§5), the Phase 3 METHOD and the nine classes of drift (§3.25), what this session fixed and must not be redone (§3.26), the five Mine findings still open and where each one is (§4.1), what is owed to the SHIPPING app (§6):

      C:\Users\Somebody Someone\Music\SHOWME!\MineLink-M3\HANDOFF.md

   Read "WHERE THIS SESSION STOPPED", §0, §1, §2, §3 (§3.26 first, then §3.25), §4, §5 (including "Lessons added 2026-08-23 (fourth session)"), §6. Where HANDOFF.md and M3-TASKS.md disagree about what is left, M3-TASKS.md wins.

3. THE REVIEWER REPORTS — five read-only agents reviewed every route target of the five remaining Phase 3 scopes on 2026-08-23 and reported drift by class with file:line. They are in the repo:

      C:\Users\Somebody Someone\Music\SHOWME!\MineLink-M3\docs\redesign\reviews\2026-08-23-phase3\report_mine.md  (and report_buyer.md, report_transporter.md, report_driver.md, report_shared.md; agent_brief.md is the brief they were given)

   A report is a LEAD, not a verdict: verify every finding in the render and the code before fixing it, and check it against HANDOFF §3.26 — many Buyer/Transporter findings are ALREADY FIXED by this session's shared-component commits.

4. THE OLDER MACHINE-WIDE HANDOFF — BACKGROUND ONLY, DO NOT WORK FROM IT:

      C:\Users\Somebody Someone\Claude\HANDOFF.md

   Dated 2026-08-08: MCP servers, the decoy folders, the phone tooling. Nothing in it is a task.

THE PATHS THAT MATTER

  Work happens here (its own git repo, branch main, 234 commits, clean, NO remote):
      C:\Users\Somebody Someone\Music\SHOWME!\MineLink-M3

  NEVER TOUCHED, for any reason:
      C:\Users\Somebody Someone\Music\SHOWME!\worktree-2026-05-05T11-53-29

THE ONE RULE THAT MUST NOT BREAK — Jean's words: "NO CHANGES WHAT SO EVER INSIDE OF "C:\Users\Somebody Someone\Music\SHOWME!\worktree-2026-05-05T11-53-29" then I'm happy". CHECK IT AT THE START OF THE SESSION AND AGAIN AT THE END, and tick Phase 0 with it:

  HEAD              df451d0
  git status        exactly 3 modified files, all pre-existing:
                      M .design-sync/config.json
                      M lib/features/super_admin/screens/margin_ledger_screen.dart
                      M test/widgets/app_sidebar_behaviour_test.dart
  file count        14163   (find . -path ./.git -prune -o -type f -print | wc -l)
  git worktree list exactly 2 entries — the main repo and that worktree
  modified today    0

  (The plain find . -type f -not -path "./.git/*" returns 14164 because in a WORKTREE .git is a FILE — same untouched tree.) Reading it is fine; writing to it, or running any MUTATING git command inside it, is not. supabase/ inside MineLink-M3 is frozen too — anything needing a migration is REPORTED under Phase 5 / HANDOFF §6, never applied. Re-checked at the end of this session: all five figures exactly as above.

HOW THE MARKABLE FILE WORKS

- Work the phases IN ORDER. Phase 0 start items → Phase 3 in the file's order: Mine portal (OPEN, ▶ IN PROGRESS — finish it first) → Buyer portal → Transporter portal → Driver app → Shared. Phases 4, 5, 6, 7 and the "Decisions only Jean can make" are BLOCKED ON JEAN: do not start them, do not tick them, leave their ⏸ lines in place and name them in your report.
- AFTER EACH TASK IS COMPLETED, MARK IT COMPLETED IMMEDIATELY: change `- [ ]` to `- [x]` and put an evidence line directly under it:
    ✅ <date> · commit <sha> · proven by <what was run / seen / measured>
  Then COMMIT M3-TASKS.md together with the work it records. Never batch ticks. Never increment a count — recount with `grep -c '^- \[x\]' M3-TASKS.md` (it is 15 right now).
- Jean's rule, verbatim: "FROM HERE ON FORWARD WITH WHAT YOU'RE BUSY WITH, NO NEW TASK SHOULD BE STARTED UNLESS THE PREVIOUS TASK WAS FULLY AND PROPERLY MARKED OFF TRUTHFULLY!"
- And this session, verbatim: "you're not marking your tasks as you should, AFTER ANY AND EVERY TASK IS COMPLETED IT SHOULD BE MARKED RIGHT AFTER THAT! ONLY IF IT'S 100% TRUE!" — so: tick the moment a thing is proven; REOPEN a tick that is no longer true (the previous session's end-of-session ticks must not stand in a new session); record progress on an open task as a ▶ IN PROGRESS line under it and commit the file with the work; a task that cannot move keeps `- [ ]` and gets ⏸ BLOCKED — <on what> — <what unblocks it>. A blocked or in-progress task is never a done task.
- A phase gets `Status: DONE <date>` only when every task in it is ticked (Phases 1 and 2 are DONE; Phase 3 is OPEN with its console task ticked and its Mine task in progress).
- Update the "Last updated" line (date · commit count · tip) every time you commit the file, and add ONE line to the Session log at the end of the session.
- Everything already ticked was proven before being ticked. DO NOT REDO IT. Everything under "Deliberately NOT on this list" stays off the list.

VERIFIED STATE AT THE MOMENT THIS MESSAGE WAS WRITTEN

  MineLink-M3                       234 commits, clean, no remote; the last code commit is 9740420 (the register's accent); the tip is the docs commit carrying this message; M3-TASKS.md has 15 ticks
  flutter analyze                   No issues (whole tree)
  flutter test (full)               2578 passed · 1 skipped · 0 failed (after 9740420)
  dart tool/release_guards.dart     43/43 PASS; --selftest: all 43 bite
  py -3 tool/_sabotage.py           ALL SABOTAGES CAUGHT
  the seven Python checks           all green (type_scale_codemod selftest OK · dropdown_width clean · glyph_coverage clean · one_clock PASS + selftest · unphotographed 94/94 · health_probe 7/7 — the EXTRAS project's search_place_index answered on the RETRY after idling, as on every day so far; main 6/6 first time)
  flutter test test/renders         263 passed, PLAIN run (no --update-goldens) after 9740420 — goldens current
  build/web                         FRESH (flutter build web --release √ 76.9 s at the tip code)
  APK on disk                       build/app/outputs/flutter-apk/app-debug.apk, SHA-256 34157bcf…, FRESH — NOT on the phone, NOT on the NAS
  APK on the phone                  1ad4c725 (from 2026-08-23 04:50; carries NONE of this session's 23 fixes). Installing is only owed if a Phase 3 fix needs to be seen on glass.
  Jean's phone (SM-G780G)           NOT touched this session; left as the previous session left it: platform admin on home, 0 screenshots. Check probe before any use.
  Android emulator                  NOT running (AVD minelink_test; adb at C:\Android\sdk\platform-tools)
  Browsers                          NONE opened this session (0 ml-chrome-*, nothing on 9222/9223). The idle py -3 -m http.server 8123 over build/web may still be running — harmless.
  Helpers                           committed under MineLink-M3\tool\phase3_helpers\ (README there): mypatch.py (line-ending-aware exact patching — import it), mypair.py (HEAD-vs-working crop of a golden), golden_diff.py (measure every moved golden; copy it to a scratch dir first, it writes crops beside itself), fix_eol.py (run before every commit), plus the browser driver cdp.py/setfile.py/takepic.py/attach_photos.py/hover.py/emulate.py from earlier sessions (unused this session).
  Original worktree                 df451d0, 3 pre-existing modified, 14163, 2 entries, 0 today
  Live data left behind             nothing new this session (no browser, no phone, no database writes). The previous sessions' test rows (the approved-not-dispatched mine request, the Iron Hills DM rows, trip b9189cd5 …) are still there; all test data.

WHAT TO DO, IN ORDER

0. Tick Phase 0's start-of-session items (baseline check, `code M3-TASKS.md`) with fresh evidence, and REOPEN the two end-of-session items — their ticks describe THIS session's end, not yours; they are earned again only by your own full gate.
1. FINISH PHASE 3, TASK TWO — the Mine portal. Five reviewer findings are open, all small, all located in HANDOFF §4.1 (a table with file:line) and in docs/redesign/VERIFICATION.md's Mine table (rows marked *open*): the employee grid title; the Buyers cards' accent wash + the page head; the mine's Requests copy and its two actions (and that screen has NO render — add a mine-org one); trip detail faces/head; the company-information labels. THE METHOD (HANDOFF §5 "The Phase 3 method"): LOOK at the render beside docs/design-reference/*.png and §4–§5 of docs/design-reference.md; fix drift at its CAUSE (the shared component where one exists); regenerate with `flutter test test/renders --update-goldens` (the WHOLE suite — never `--name "a|b"`, this shell eats the `|`); LOOK again (tool/phase3_helpers/golden_diff.py + mypair.py); pin with a test; SABOTAGE it (stash the lib file → the test must FAIL → pop; keep a case that stays GREEN); one commit per fix; then flip the VERIFICATION.md row from *open* to the commit; when all five are in, tick the Mine task in M3-TASKS.md with an evidence line naming every fix and every "reviewed, no drift" screen, and commit the file with it.
2. Then Buyer portal, Transporter portal, Driver app, Shared — the same way, one task at a time, each ticked before the next starts. Start each from its report in docs/redesign/reviews/2026-08-23-phase3/, verify every finding, skip the ones §3.26 already fixed (check the render, not the report), and record "looked at and NOT drift" in VERIFICATION.md so nobody re-derives it.
3. Phases 4–7 and the Decisions: blocked on Jean. Do not tick, do not start. (Three new decisions surfaced by the reviewers — the chat dock's Nord palette, dialog titles in sans, the login's gold — go onto the Decisions list when the Shared task is reached.)

REVIEWER AGENTS — Jean asked for them and they worked; keep the shape: read-only, one per scope, reporting by the nine classes with file:line and an "original: same/differs" check; the session stays the SINGLE WRITER (one tree, one golden suite, shared components that move 58 goldens at once). They never edit, never run flutter/dart, never open a browser or touch the phone, and never write a scratchpad file under a name you use. Verify everything they say before acting on it.

🚨 IF YOU NEED THE PHONE AND IT DOES NOT ANSWER — `status` says "no phone at a known address" or `probe` is under 0.1 bits/pixel (display asleep) — PAUSE THAT STEP RIGHT THERE AND TELL JEAN, THEN KEEP WORKING ON WHAT DOES NOT NEED IT and re-probe as you go. Jean's words: "if you need to use my phone via ctrl bridge and the phone is not responding that you should pause the process right there so that I'll respond to you that the phone is no longer asleep and that you can try again". Only he can enable host mode and only he can wake the screen; injected touches cannot. Do NOT work around it and do NOT report green as though the phone step were optional. HOST MODE STAYING ON DOES NOT MEAN THE SCREEN IS AWAKE: check probe, not just status. Invoke the driving-jeans-phone skill FIRST the moment you need to touch the phone. It is his PERSONAL phone: prefer sig/changed/waitstable over shot, delete every screenshot immediately, never switch on live-location sharing (it writes his real position), leave it signed in as the platform admin on home. Installing over the NAS: My Files → Network storage → jean → Shared → PhoneRemote → minelink-m3.apk → Update → Open; back out of PhoneRemote and re-enter to refresh the cached listing; compare the SHA-256, not timestamps (the NAS clock is ~2h36m slow); keep the screen alive with status-bar taps in batches under 30 s (a long wait drops the link); decline "Turn on Play Protect".

DO NOT MOVE JEAN'S MOUSE. He works at this machine while you run. His words: "bro make a nother plan for a mouse, I'm using mine". Drive the browser through CDP (HANDOFF §5) or use the Android emulator. Switch accounts by clearing localStorage('sb-yftazblpmicqtamyiwyb-auth-token') and reloading, never by a menu (CDP clicks do not reach popup menus).

🚨 DO NOT COOK HIS CPU. One headless Chrome only for the minutes a flow needs (two, on 9222 and 9223, only for a two-account flow); Stop-Process every chrome.exe whose command line contains ml-chrome- the moment it is done (HANDOFF §5 has the one-liner). Never leave one running while you write code or docs.

HOW TO WORK — THIS IS JEAN'S INSTRUCTION, FOLLOW IT

"don't worry about me seeing anything, I'll want to see when everything is complete and done, so don't stop so much in between please run the task for as long as possible so that we can get this completley done and sorted please, correct your self where you make mistakes and fix the mistakes and make sure you don't implement anything with gaps in them make sure its full and proper like the original"

AND, EXPLICITLY: IF YOU FIND PROBLEMS ALONG THE WAY, FIX THEM AS YOU GO AND TEST THAT THE FIX WORKS AS EXPECTED. Do not merely note or collect a list of faults to hand back; do not leave a fix unverified. Every fix gets a test that BITES (remove the fix, watch the test fail, restore — and keep a case that stays GREEN under sabotage), and where the fix is visible on a device or in a browser, LOOK AT IT THERE TOO. Half-implemented work, TODOs, stubs, "later" notes are not acceptable — finish each thing.

THE GATE (Phase 0, end of session — run it in FULL before the end-of-session tick, and redirect every run to a file, then grep; a pipe hides a failing exit code and `tail` hides [E]):

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
  flutter test test/renders           (after any visual change; then LOOK at each moved PNG — golden_diff.py measures them)
  flutter build web --release
  flutter build apk --debug

...AND the original worktree re-checked against the baseline above, AND every Claude-owned browser closed (one left signed in overnight once filled a production database), AND M3-TASKS.md ticked only where it is earned.

THE RIG — things that already went wrong; do not re-learn them:
- A POWER CUT destroyed every file that was mid-write (pure NUL bytes) and corrupted .git/index this session; HANDOFF §5 "Lessons (fourth session)" has the recovery. Commit after every fix.
- `--name "a|b"` is eaten by this shell (the `|` becomes a pipe): run the whole render suite, or one `--name` at a time.
- A bash heredoc eats backslashes and apostrophe escapes even when quoted; write patch scripts with the Write tool and run them with py -3, through tool/phase3_helpers/mypatch.py (half the repo is CRLF and a naive replace misses). Python's stdout is cp1252 here: set PYTHONIOENCODING=utf-8.
- A pipe hides a failing exit code; redirect, then check $?. Never read a long test run through tail — redirect and grep for [E].
- A second Chrome cannot share --remote-debugging-port and fails silently; use 9223 and CDP_PORT. A stale cached bundle looks like a silent failure: check the http.server log for 200 vs 304 on main.dart.js.
- An off-screen (--window-position) Chrome is visibilityState=hidden, 0 rAF/s: Flutter never paints. Use --headless=new.
- Flexible defaults to flex 1 and a Spacer IS an Expanded — three of them split a row in thirds (the meta at two-thirds, the delta chip at the midpoint). A loose Flexible KEEPS its unused allotment. A Wrap's second run starts at the LEFT. A width rule is not a fit rule — measure. Every one of these bit this session.
- A meta line that counts rows lies when the rows are not the thing it names; a fixture with a summary and no items lies the same way. Look at the render after every fix, not only at the test.
- A golden that moves with no code change is a CACHE or an async thing. The flutter_map logo was one; it is fixed.

WHEN JEAN SAYS "PAUSE HERE": STOP READING AND PRODUCE THE MESSAGE. Rewrite C:\Users\Somebody Someone\Music\SHOWME!\MineLink-M3\HANDOFF.md the same way this one was written — verified state only, no intentions — ending with a fresh self-contained copy-paste block in §8 that carries ALL THREE paths (M3-TASKS.md, MineLink-M3\HANDOFF.md and C:\Users\Somebody Someone\Claude\HANDOFF.md) plus the reviewer reports' path, the untouchable worktree path and its baseline, exactly where you stopped, what is already ticked so it is not redone, HOW THE MARKABLE FILE WORKS, THE PHONE RULE, THE MOUSE RULE, THE CPU RULE, the reviewer-agent rule, this same HOW TO WORK instruction quoted verbatim, the one-task-at-a-time rule, and the fix-as-you-go rule. Add the session's line to M3-TASKS.md's Session log. Commit both. State the commit count the tree WILL be at once that commit lands, and say that the tip is the commit carrying the file, so the handoff describes a tree that includes itself. Put the message in the chat as well, whole. Before producing it, make sure every task that is truly proven is ticked and nothing unproven is.

---
