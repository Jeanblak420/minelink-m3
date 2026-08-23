# MineLink M3 — session handoff

> **Addendum 2026-08-23 (verification session, no feature work).** A fresh session
> audited this file, every commit and every chat transcript since the redesign began,
> re-ran every instrument (all green, figures in §8 below), and created
> **`M3-TASKS.md`** — the single markable list of what is left. From now on that file
> is the source of truth for what is done and what is not; this file is the record of
> how the work got here and how to do it. Where the two disagree about what is left,
> `M3-TASKS.md` wins. Commits since the previous handoff: `8d92de4`, `ad0f8f7`, and the
> one carrying this addendum. Nothing else changed. The phone was asleep throughout.


**Rewritten again on 2026-08-23 at 05:45, at the end of the session that put
two APKs on the handset, closed Phase 1 on glass, drove the POD leg and the
whole request → dispatch chain from the four forms, drove the chat half-way,
and fixed FIVE more defects — one of which tore an admin's whole portal down
every 45 seconds.** The paragraph below is the previous rewrite's, kept for
its record.

**Rewritten 2026-08-23, at the end of the session that finished the previous
one's interrupted hardware checks, drove the last four roles nobody had ever
opened — including one real load through the entire mine floor — found THIRTEEN
more defects doing it, fixed all thirteen, and discovered that the overflow
sweep had been laying out empty screens for its whole life.** Everything below is
verified state, not intention. It replaces the previous handoff of the same
name.

**This file lives at**
`C:\Users\Somebody Someone\Music\SHOWME!\MineLink-M3\HANDOFF.md`

The older, machine-wide handoff is at
`C:\Users\Somebody Someone\Claude\HANDOFF.md` — MCP servers, git position,
decoy folders, the phone tooling, dated 2026-08-08. **Background only; this
file governs the redesign work.**

---

## WHERE THIS SESSION STOPPED — READ THIS FIRST

The tree is **clean**, **178 commits**, nothing half-applied and nothing
uncommitted. **The tip is the commit that carries THIS FILE**, so the count
above includes it. The last code commit under it is `56df087`; `f8d8839` and this commit are docs and two re-pointed test expectations.

**The original worktree was re-checked against its §0 baseline at 05:33 and is
untouched** — HEAD `df451d0`, the same three pre-existing modified files,
14163 files under the `-prune` form, two worktree entries, nothing modified
today.

**Jean paused the session at 05:31** with: *"please pause here and give me a
full proper correct copy paste message"*, then: *"make sure that everything
that should be marked off has been marked and check properly and truly before
u give me the copy paste ready message"*. So: every task that is proven is
ticked in `M3-TASKS.md` (11 ticks), the two half-done ones carry `▶ IN
PROGRESS` lines, and the end-of-session gate carries a `⏸ NOT RUN IN FULL`
line that lists exactly what was and was not run. The phone was put back as
the platform admin on `home` with 0 screenshots before this was written.

### What this session did, in one paragraph

It installed APK `2b235c4` on the handset and closed Phase 1 on glass, found
the app-bar title breaking mid-word there, fixed it, rebuilt as `1ad4c725`,
re-installed and re-saw it. It drove the POD leg of `0d9c6792` and then the
whole request → approve → link → dispatch chain from all four requester forms,
twice through the gate, with every server artefact and all three notification
kinds verified. It drove the chat half-way between two real accounts and there
found the biggest defect of the day: an admin's whole portal torn down and
rebuilt every 45 seconds by the presence heartbeat. Five defects fixed, each
in its own commit, each pinned by a test or guard that was sabotaged and bit.
One server-side gap added to Phase 5. `build/web` is stale and the two last
fixes have not been seen in a browser — that is where it stopped.

### 🚨 WHAT IS OWED FIRST

1. **The full Phase 0 gate** — not run after the last five commits. `flutter
   analyze` is clean, the four new test files pass, guards 43/43 bite. The
   rest (including both builds and `test/renders`) is owed.
2. **`flutter build web --release`**, then LOOK at the five fixes in a browser
   (§4) and tick Phase 2's last task.
3. **Finish the chat task** — reply quote, @mention, phone width (§4).

---

## 0. Where you are

| | |
|---|---|
| **This project** | `C:\Users\Somebody Someone\Music\SHOWME!\MineLink-M3` |
| What it is | A **complete, independent fork** of MineLink, redesigned onto Material 3. Its own git repo (`main`), **178 commits**, clean tree, **no remote**. |
| **The task list** | `MineLink-M3\M3-TASKS.md` — the single markable source of what is done. 11 ticks. |
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
- **If the phone does not answer, STOP and ask.** §5. Exercised this session
  and NOT resolved — see the top of this file.
- 🚨 **DO NOT MOVE JEAN'S MOUSE.** New this session, and he said it himself
  mid-run: he works at this machine while the session runs. A helper that
  drove real OS clicks through `SetCursorPos` was written, used twice, and
  then disabled the moment he said so (`realclick.ps1.DISABLED-jean-is-using-
  the-mouse` in the scratchpad). §5 has what to use instead.

- 🚨 **ONE TASK AT A TIME, MARKED BEFORE THE NEXT.** Jean, mid-run, verbatim:
  *"FROM HERE ON FORWARD WITH WHAT YOU'RE BUSY WITH, NO NEW TASK SHOULD BE
  STARTED UNLESS THE PREVIOUS TASK WAS FULLY AND PROPERLY MARKED OFF
  TRUTHFULLY!"* Tick `M3-TASKS.md` with its evidence line and commit it the
  moment a task is proven; never carry three proven tasks unticked.
- 🚨 **DO NOT COOK HIS CPU.** Verbatim: *"Don't COOK MY FKN CPU! close each
  crome session once you're done with it PLEASE!"* A headless Chrome on
  SwiftShader renders Flutter at ~40 fps of pure CPU. Launch one only for the
  minutes a browser flow needs, and `Stop-Process` every `chrome.exe` whose
  command line contains `ml-chrome-` the moment that flow is done (the
  PowerShell one-liner is in §5). Never leave one running while you code.

**`supabase/` is frozen.** Things needing a migration are REPORTED — §6.

---

## 2. Verified state, right now

```
flutter analyze                                 No issues (whole tree, 05:38)
the four new test files                         12/12 — each sabotaged, each bit
dart tool/release_guards.dart                   43/43 PASS
dart tool/release_guards.dart --selftest        all guards bite (new: one-spelling-for-mine-supplier)
flutter test (full, 05:39–05:49)                2479 passed · 1 skipped · 11 failed: 2 spelling
                                                expectations (re-pointed in the tip commit, green)
                                                + 9 goldens that moved on purpose (fleet icon,
                                                Mine/Supplier) — --update-goldens STILL OWED
NOT run after the last five commits             _sabotage.py · type_scale_codemod --selftest ·
                                                dropdown_width_check · glyph_coverage_check ·
                                                one_clock_check (+selftest) · unphotographed_screens ·
                                                health_probe · test/renders · build web · build apk
build/web                                       STALE (03:07, before every fix this session)
APK on the handset                              1ad4c725 — carries 69f6738, 705843a, 22eb90b only
crash_reports since the 01:27Z baseline         0 rows of any kind (re-counted 03:38Z, after the new APK)
M3-TASKS.md                                     11 ticks; Phase 1 DONE; two ▶ IN PROGRESS; one ⏸ gate line
browsers                                        none open; nothing on 9222/9223
phone                                           awake, platform admin, on home, 0 screenshots
```

Test count: 2478 passing at the start + 12 new = the suite the next session
should see (minus nothing — no test was removed). Guards **42 → 43**.

---

## 3. What this session did — DO NOT REDO ANY OF IT

Read the commit messages; they are long and they are the real record.
`e080197`, `f8e815d`, `5cbaeee`, `4c5f807`, `963ca7e`.

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

### 4.1 🚨 FIRST: the gate, then the browser look

Run the whole Phase 0 list (§8 has it). Then `flutter build web --release`,
serve it, and look at each fix in a headless Chrome — kill it after:

- `ironhills.admin`: dock open, three minutes, still open (`f225278`); the
  admin's own contact profile reads `Organisation type | Mine/Supplier`
  (`56df087`).
- `roadhaul.admin`: Trucks on route → `Manage drivers` on S6W001GP; Fleet
  row → the group icon opens the dialog at `1/2 drivers assigned` (`69f6738`).
- `jean@cyberhouse.co.za`: a mine-raised approved request's link step reads
  `Mine asked for:` (`22eb90b`).

Then tick "Every defect found in this phase fixed…" in `M3-TASKS.md`.

### 4.2 The chat, the second half

Reply with a quote (hover a bubble → `Reply`), an `@mention` (type `@` in the
composer), phone width (`Emulation.setDeviceMetricsOverride` 412×915), and
presence/typing from the admin's side — all blocked only by the stale web
build. The DM Iron Hills owner ↔ admin already holds four messages and an
image to reply to.

### 4.3 Then Phase 3

Untouched. Per screen against `docs/design-reference/`.

### 4.4 Blocked on Jean (name them, do not start them)

Phase 4 (a real road), Phase 5 (seven server-side items now, §6), Phase 6
(Windows path, iOS), Phase 7 (a remote for M3; the firewall rule), and the
two Decisions.

### 4.5 Closed this session, do not redo

- Phase 1 entirely, on two APKs.
- The POD leg; the request → dispatch chain from the four forms; the
  revision loop; the four inboxes; the gate; accept and allocation.
- The five fixes in §3.18–3.22 — code, tests, guards. Only the LOOK is owed.

---

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

Everything the next session needs is inside this block. Paste it whole.

---

Continue the MineLink Material 3 redesign, exactly where the last session left off. The work is driven by ONE MARKABLE FILE. Read these in this order before doing anything else.

1. THE MARKABLE TASK FILE — THE SINGLE SOURCE OF WHAT IS DONE AND WHAT IS LEFT:

      C:\Users\Somebody Someone\Music\SHOWME!\MineLink-M3\M3-TASKS.md

   Seven phases, checkboxes, evidence lines, a session log. Open it in Jean's IDE THE MOMENT YOU START and keep it open the whole session:

      code "C:\Users\Somebody Someone\Music\SHOWME!\MineLink-M3\M3-TASKS.md"

   (the code CLI is C:\Users\Somebody Someone\AppData\Local\Programs\Microsoft VS Code\bin\code.cmd). Jean watches this tab; VS Code reloads it on every save.

2. THE PROJECT HANDOFF — how the redesign got here, how to drive a browser WITHOUT touching Jean's mouse (§5), how to drive his phone (§5), what is owed to the SHIPPING app (§6):

      C:\Users\Somebody Someone\Music\SHOWME!\MineLink-M3\HANDOFF.md

   Read "WHERE THIS SESSION STOPPED", §0, §1 (two new standing rules), §2, §3 (DO NOT REDO ANY OF §3.0–§3.23), §4, §5, §6. Where HANDOFF.md and M3-TASKS.md disagree about what is left, M3-TASKS.md wins.

3. THE OLDER MACHINE-WIDE HANDOFF — BACKGROUND ONLY, DO NOT WORK FROM IT:

      C:\Users\Somebody Someone\Claude\HANDOFF.md

   Dated 2026-08-08: MCP servers, the decoy folders, the phone tooling.

THE PATHS THAT MATTER

  Work happens here (its own git repo, branch main, 178 commits, clean, NO remote):
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

  (The plain find . -type f -not -path "./.git/*" returns 14164 because in a WORKTREE .git is a FILE — same untouched tree.) Reading it is fine; writing to it, or running any MUTATING git command inside it, is not. supabase/ inside MineLink-M3 is frozen too — anything needing a migration is REPORTED under Phase 5 / HANDOFF §6, never applied. Re-checked at 05:33 on 2026-08-23: all five figures exactly as above.

HOW THE MARKABLE FILE WORKS

- Work the phases IN ORDER. Phase 0 start items → finish Phase 2 (chat, then the browser look at the five fixes) → Phase 3. Phases 4, 5, 6, 7 and the "Decisions only Jean can make" are BLOCKED ON JEAN: do not start them, do not tick them, leave their ⏸ lines in place and name them in your report.
- AFTER EACH TASK IS COMPLETED, MARK IT COMPLETED IN M3-TASKS.md IMMEDIATELY: change - [ ] to - [x] and put an evidence line directly under it:
    ✅ <date> · commit <sha> · proven by <what was run / seen / measured>
  Then COMMIT M3-TASKS.md together with the work it records. Never batch ticks. Never tick without evidence. Never increment a count — recount with grep -c '^- \[x\]' M3-TASKS.md (it is 11 right now).
- Jean's rule, verbatim, given mid-run on 2026-08-23: "FROM HERE ON FORWARD WITH WHAT YOU'RE BUSY WITH, NO NEW TASK SHOULD BE STARTED UNLESS THE PREVIOUS TASK WAS FULLY AND PROPERLY MARKED OFF TRUTHFULLY!"
- A task that cannot move keeps - [ ] and gets ⏸ BLOCKED — <on what> — <what unblocks it> under it. A task half-driven keeps - [ ] and a ▶ IN PROGRESS line (two carry one now). A blocked or in-progress task is never a done task.
- A phase gets Status: DONE <date> only when every task in it is ticked (Phase 1 is DONE as of this session).
- Update the "Last updated" line (date · commit count · tip) every time you commit the file, and add ONE line to the Session log at the end of the session.
- Everything already ticked was proven before being ticked. DO NOT REDO IT. Everything under "Deliberately NOT on this list" stays off the list.

VERIFIED STATE AT THE MOMENT THIS MESSAGE WAS WRITTEN (2026-08-23 05:45)

  MineLink-M3                       178 commits, clean; the tip is the commit carrying this message (parent 56df087); M3-TASKS.md has 11 ticks
  flutter analyze                   No issues (whole tree, 05:38, after the last code commit)
  the four new test files           12/12 pass (second_driver_is_reachable, phone_title_never_breaks_a_word, link_step_names_the_requester, company_context_survives_auth_resync); each was sabotaged and bit
  dart tool/release_guards.dart     43/43 PASS; --selftest: all guards bite (new: one-spelling-for-mine-supplier)
  flutter test (full)               2479 passed · 1 skipped · 11 failed (05:39–05:49): 2 tests pinned the retired spelling 'Mine / Supplier' → re-pointed to 'Mine/Supplier' in the tip commit, green; 9 GOLDENS moved on purpose — screen-fleet-{desktop-dark,desktop-light,phone-dark} (the group icon on every assigned truck) and screen-{token-history,organization-detail,chat-connections}-{desktop,phone}-dark (the word Mine/Supplier). Their diffs were looked at in test/renders/failures/ and are only those pixels. `flutter test test/renders --update-goldens` IS STILL OWED — run it, look at the nine PNGs, commit them. The rest of the Phase 0 gate was NOT run (Jean paused the session).
  build/web                         STALE — built at 03:07, before all five fixes (69f6738 705843a 22eb90b f225278 56df087). Rebuild before serving.
  APK on the phone                  1ad4c725… (built 04:50 from 7b6e129; carries 69f6738, 705843a, 22eb90b; NOT f225278, 56df087) = \\192.168.88.30\Shared\PhoneRemote\minelink-m3.apk, SHA-256 1AD4C7258583D65FFDF8E00980B63EF2EB1EA8EB7591A290C966F07485409A09, both ends match; INSTALLED and driven
  Jean's phone (SM-G780G)           awake at 05:38 (probe 0.667 bits/pixel), signed in as the platform admin, on home, 0 screenshots in C:\PhoneRemote\tool\shots\
  Android emulator                  NOT running (AVD minelink_test; adb at C:\Android\sdk\platform-tools)
  Browsers                          NONE open (every ml-chrome-* chrome.exe stopped; nothing on 9222/9223). The idle py -3 -m http.server 8123 over build/web may still be running — harmless; restart it after the rebuild.
  CDP helpers                       cdp.py (clear, scrollx, CDP_PORT), setfile.py, takepic.py (multi-file, label match, intercept-before-click), attach_photos.py, fix_eol.py, pod.jpg, lab-*.pdf, product-photo.jpg in C:\Users\SOMEBO~1\AppData\Local\Temp\claude\C--Users-Somebody-Someone-Music-SHOWME--MineLink-M3\850c86b2-7712-4015-8a50-5dfcda589d21\scratchpad\ — copy them into your own scratchpad.
  Original worktree                 df451d0, 3 pre-existing modified, 14163, 2 entries, 0 today (re-checked 05:33)
  Live data left behind             trip b9189cd5 (S6W001GP, arrived_at_mine on route RT-1ADEE49D, the mine-raised 2400 t order); route RT-CD03FA4C (Atlas, 600 t, dispatched to Roadhaul, not yet accepted); Sipho (roadhaul.driver2) on KVK007MP; the four requests 18800451 5dc2579d d40a9d3e 34eba1e9; a DM Iron Hills owner ↔ admin with four messages and one image. All of it is test data and may be driven further.

WHAT TO DO, IN ORDER

0. Tick Phase 0's start-of-session items (baseline check, code M3-TASKS.md). THEN RUN THE FULL PHASE 0 GATE FIRST — it was not run after the last five commits: flutter analyze · flutter test · dart tool/release_guards.dart (+ --selftest) · py -3 tool/_sabotage.py · type_scale_codemod.py --selftest · dropdown_width_check.py · glyph_coverage_check.py · one_clock_check.py (+ --selftest) · unphotographed_screens.py · health_probe.py · flutter test test/renders (the phone title bar changed in 705843a — if a phone golden with a long title moved, LOOK at it, then --update-goldens) · flutter build web --release · flutter build apk --debug. Fix anything red before anything else.
1. Serve the fresh build/web on 127.0.0.1:8123 and LOOK at the five fixes in a headless Chrome (HANDOFF §5: --headless=new, never off-screen; CDP_PORT for a second browser; KILL every ml-chrome-* chrome.exe the moment each flow ends — Jean: "Don't COOK MY FKN CPU!"):
   a. ironhills.admin: open the dock, leave it three minutes — it must stay open (f225278). Then its contact profile must read "Organisation type | Mine/Supplier" (56df087).
   b. roadhaul.admin: Trucks on route → "Manage drivers" on S6W001GP; Fleet row → the group icon opens DriverAssignmentDialog at 1/2 (69f6738).
   c. jean@cyberhouse.co.za: a mine-raised approved request's link step reads "Mine asked for" (22eb90b).
   Then tick "Every defect found in this phase fixed…" with what you saw.
2. FINISH THE CHAT TASK (Phase 2): two real accounts (ironhills.owner 9222, ironhills.admin 9223 is what was used), both directions, a reply WITH a quote, an @mention, presence, on phone width (Emulation.setDeviceMetricsOverride 412×915 or a 412-wide window) and desktop. Drive the dock from screenshots; clicklabel "Messages" on an OPEN dock closes it. Tick it with the evidence, record it in docs/redesign/VERIFICATION.md.
3. Phase 2's last task, then Phase 3 — the per-screen design pass against docs/design-reference/ and the super-admin console, screen by screen as the file lists them: render → compare placement, hierarchy, spacing → fix drift → regenerate → pin with a test → tick with a dated "reviewed against reference" line in docs/redesign/VERIFICATION.md.
4. Phases 4–7 and the two Decisions: blocked on Jean. Name them in your report. Do not tick, do not start.

🚨 IF YOU NEED THE PHONE AND IT DOES NOT ANSWER — status says "no phone at a known address", or probe reports under 0.1 bits/pixel (display asleep) — PAUSE THAT STEP RIGHT THERE AND TELL JEAN, THEN KEEP WORKING ON WHAT DOES NOT NEED IT and re-probe as you go. Jean's words: "if you need to use my phone via ctrl bridge and the phone is not responding that you should pause the process right there so that I'll respond to you that the phone is no longer asleep and that you can try again". Only he can turn host mode on and only he can wake the screen; injected touches cannot. Do NOT work around it and do NOT report green as though the phone step were optional. HOST MODE STAYING ON DOES NOT MEAN THE SCREEN IS AWAKE: check probe, not just status. Invoke the driving-jeans-phone skill FIRST the moment you touch the phone. It is his PERSONAL phone: prefer sig/changed/waitstable over shot, delete every screenshot immediately, never switch on live-location sharing (it writes his real position), leave it signed in as the platform admin on home. Installing over the NAS: My Files → Network storage → jean → Shared → PhoneRemote → minelink-m3.apk → Update → Open; back out of PhoneRemote and re-enter to refresh the cached listing; compare the SHA-256, not timestamps; keep the screen alive with status-bar taps in batches under 30 s (a long wait drops the link); decline "Turn on Play Protect?" if it appears.

🚨 DO NOT MOVE JEAN'S MOUSE. He works at this machine while you run. His words: "bro make a nother plan for a mouse, I'm using mine". Drive the browser through CDP (HANDOFF §5) or use the Android emulator. Switch accounts by clearing localStorage('sb-yftazblpmicqtamyiwyb-auth-token') and reloading, never by a menu.

🚨 DO NOT COOK HIS CPU. One headless Chrome only for the minutes a flow needs; Stop-Process every chrome.exe whose command line contains ml-chrome- the moment it is done (HANDOFF §5 has the one-liner). Never leave one running while you write code or docs.

HOW TO WORK — THIS IS JEAN'S INSTRUCTION, FOLLOW IT

don't worry about me seeing anything, I'll want to see when everything is complete and done, so don't stop so much in between please run the task for as long as possible so that we can get this completley done and sorted please, correct your self where you make mistakes and fix the mistakes and make sure you don't implement anything with gaps in them make sure its full and proper like the original

AND, EXPLICITLY: IF YOU FIND PROBLEMS ALONG THE WAY, FIX THEM AS YOU GO — then TEST THAT THE FIX WORKS AS EXPECTED. Do not merely note or collect a list of faults to hand back; do not leave a fix unverified. Every fix gets a test that BITES (remove the fix, watch the test fail, restore — and keep a case that stays GREEN under sabotage), and where the fix is visible on a device or in a browser, LOOK AT IT THERE TOO. Half-implemented work, TODOs, stubs and "this could be improved later" notes are not acceptable — finish each thing the way the original app does it. Do not ask Jean questions you can answer by reading the tree or the database. One commit per fix; tick the task the moment it is proven.

THE METHOD, unchanged: fixtures, regenerate, LOOK at the picture, measure with PIL rather than trust a report, fix the CAUSE rather than the symptom when the fault is structural, then pin it with a test and prove the test bites. When a report and a picture disagree, THE PICTURE WINS. When a picture and a HANDSET disagree, the handset wins. When a suite is green, ask what it is green OVER. Check whether a "fault" is the data, or the tool, before fixing the app (this session: a buyerless order was data; an off-screen Chrome and a dock toggle were the tool).

BEFORE CLAIMING ANYTHING IS DONE, ALL OF THESE MUST BE GREEN (Phase 0's end-of-session tick):

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
py -3 tool/health_probe.py
flutter test test/renders          (after any visual change, --update-goldens)
flutter build web --release
flutter build apk --debug

...AND the original worktree re-checked against the baseline above, AND every Claude-owned browser closed (one left signed in overnight once filled a production database), AND M3-TASKS.md committed with every tick you earned.

LIVE ACCOUNTS
  active user accounts.txt in the MineLink-M3 root.
  jean@cyberhouse.co.za / BuRG3rJ3@n1995@#   (platform admin)
  everything @mineralguide.com / MineralGuide123!
  Used this session: ironhills.owner, ironhills.admin, ironhills.controller, ironhills.security, atlasbuyer.owner, roadhaul.admin, roadhaul.driver (roadhaul.driver2 = Sipho exists, unused as a login).
  The console stores theme and accent PER ADMIN — put it back if you change it.

LESSONS ALREADY PAID FOR — DO NOT REPEAT
- io.open(p,'w') in Python rewrites line endings on Windows; pass newline='' on both ends or run fix_eol.py before committing.
- A bash heredoc eats backslashes even when quoted; write patch scripts with the Write tool and run them with py -3. Python's stdout is cp1252 here: set PYTHONIOENCODING=utf-8.
- A pipe hides a failing exit code; redirect, then check $?. Never read a long test run through tail.
- A second Chrome cannot share --remote-debugging-port and fails silently; use 9223 and CDP_PORT. A stale cached bundle looks like a silent failure: compare decodedBodySize to the file.
- An off-screen (--window-position) Chrome is visibilityState=hidden, 0 rAF/s: Flutter never paints. Use --headless=new.
- Flexible in a shrink-wrapped Row throws; Flexible in a bounded Row is right. A fixed pixel floor under a user-controlled text size is a trap that has bitten four times now (the title bar was the fourth). Measure before choosing words.
- The chat dock launcher toggles; its semantics are only fresh after cdp.py publish; the dock state between calls is unknown — screenshot it.
- A power cut destroyed a file mid-write: commit often. M3 has NO remote.

WHEN JEAN SAYS "PAUSE HERE": STOP READING AND PRODUCE THE MESSAGE. Rewrite C:\Users\Somebody Someone\Music\SHOWME!\MineLink-M3\HANDOFF.md the same way this one was written — verified state only, no intentions — ending with a fresh self-contained copy-paste block in §8 that carries ALL THREE paths (M3-TASKS.md, MineLink-M3\HANDOFF.md and C:\Users\Somebody Someone\Claude\HANDOFF.md), the untouchable worktree path and its baseline, exactly where you stopped, what is already ticked so it is not redone, THE PHONE RULE, THE MOUSE RULE, THE CPU RULE, this same HOW TO WORK instruction quoted verbatim, the one-task-at-a-time rule, and the fix-as-you-go rule. Add the session's line to M3-TASKS.md's Session log. Commit both. State the commit count the tree WILL be at once that commit lands, and say that the tip is the commit carrying the file, so the handoff describes a tree that includes itself. Give Jean the block in the chat as well, whole. Before producing it, make sure every task that is truly proven is ticked and nothing unproven is.
