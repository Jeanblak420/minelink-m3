# MineLink M3 — session handoff

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

The tree is **clean**, **165 commits**, nothing half-applied and nothing
uncommitted. **The tip is the commit that carries THIS FILE**, so the count
above includes it. The last code commit under it is `2b235c4`.

**The original worktree was re-checked against its §0 baseline and is
untouched** — HEAD `df451d0`, the same three pre-existing modified files,
14163 files under the `-prune` form, two worktree entries, nothing modified
today.

### 🚨 WHAT THE HANDSET DID AND DID NOT SEE

**The handset DID run this session's work.** Jean woke it, the APK built at
`963ca7e` was installed over the NAS, and it was driven as the platform admin.
What that proved, on glass:

- The build installs and runs, and the console reads live data — Transporters
  went 45 -> 46 trips and 1,405 -> 1,439 t, picking up the load driven earlier.
- **The timestamp vocabulary**: `/super-admin/crash-reports` reads
  `22 Aug 2026 . 20:50`, not `Aug 22, 2026 8:50 PM`.
- **The recon table's figures**: 49 rows, and `Day 102.10 t` — exactly the
  three loads inside 24 hours (34.2 + 33.7 + 34.2).
- **And it found a defect nothing else could.** Jean's phone runs a raised
  system font size, and the TIME-IN column rendered `12:35` as `12:3` over `5`.
  That is section 3.15, and it reproduced deterministically the moment it was
  measured.

**What it has NOT seen is the fix for that**, plus everything committed after
`963ca7e`. A newer APK is built, hashed and staged:

```
build/app/outputs/flutter-apk/app-debug.apk
\\192.168.88.30\Shared\PhoneRemote\minelink-m3.apk
SHA-256  6BCAE044229625FB32E770DC5CFA62D38EA6A3E584AF8F07BDA54F0663D82422   (both ends match)
```

The phone's screen went to sleep again — between one `probe` and the next — and
only Jean can wake it. It was 02:15 and he had almost certainly turned in. The
session asked twice, said what it was for, and finished everything that did not
need the handset.

⚠️ **The screen timeout is SHORT — short enough to sleep during the ~2.5 minute
download.** Ask him to keep it awake, or to lengthen the timeout, before
starting the install.

**So the first job next session is:** install that APK and drive the four
things a handset proves and nothing else does —

1. **The recon table at his font size.** `/super-admin/recon-tables`, scroll
   into the table. `TIME-IN` must read `12:35` on ONE line. This is the one the
   handset itself found.
2. **The driver's hero card at a raised text size.** `CURRENT TRIP` and the
   status pill on two lines with NO yellow-and-black stripe. Overflowed by
   44 px before `963ca7e`. Emulator-verified at font scale 1.3 with a real
   trip; not yet on glass.
3. **The load controller's truck row and the buyer's reconciliation card**, same
   raised text size — 22 px, 21 px and 32 px overflows before this session.
4. **No new `Duplicate GlobalKey` rows** — baseline, navigate six or seven
   screens, re-count. SQL in section 5. **Zero were raised all session** from
   the handset, the emulator and six browser accounts, but this exact build has
   not been on glass.

Put the phone back the way it was found: signed in as the platform admin, on
`home`, every screenshot deleted.

⚠️ **One thing was answered on his behalf and he should know:** installing
raised a Google Play Protect prompt — *"Turn on Play Protect?"* — which is a
device-wide setting, not a step in the install. It was **Declined**, because
declining leaves his configuration exactly as he had it. Accepting would have
turned on a service he has off.

### What this session did, in one paragraph

It finished the previous session's interrupted hardware checks (both passed),
then went after the four roles §4.2 had listed as never driven. Reaching the
Load Controller meant there had to be a truck on the weighbridge, so it drove
one real load the whole way — transporter accepts, truck and driver assigned,
driver starts, security checks in, tare, gross, four sealed and photographed,
waybill, gate check-out. Thirteen defects came out of the sweep. **The most
important one is not a screen at all: the portal overflow sweep had been
running 27 screens × 3 widths × 5 text scales against EMPTY providers**, and
turning the data on found four real overflows it had always passed.

---

## 0. Where you are

| | |
|---|---|
| **This project** | `C:\Users\Somebody Someone\Music\SHOWME!\MineLink-M3` |
| What it is | A **complete, independent fork** of MineLink, redesigned onto Material 3. Its own git repo (`main`), **165 commits**, clean tree. |
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
```

```bash
cd "/c/Users/Somebody Someone/Music/SHOWME!/worktree-2026-05-05T11-53-29"
git status --porcelain --untracked-files=all
git rev-parse --short HEAD
find . -path ./.git -prune -o -type f -print | wc -l
git worktree list
find . -type f -newermt "<today>" -not -path "./.git/*" | wc -l    # must be 0
```

⚠️ **The file count depends on which `find` you use.** `find . -type f -not
-path "./.git/*"` returns **14164** because in a WORKTREE `.git` is a *file*,
not a directory. The `-prune` form returns **14163**. Same untouched tree.

Reading that tree is fine and often necessary. Writing to it, or running any
mutating git command inside it, is not. (`git status` / `git rev-parse` /
`git worktree list` are reads and are how the baseline is checked.)

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

**`supabase/` is frozen.** Things needing a migration are REPORTED — §6.

---

## 2. Verified state, right now

```
flutter analyze                                 no issues
flutter test                                    2478 passed, 1 skipped
dart tool/release_guards.dart                   42/42 PASS, 0 FAIL
dart tool/release_guards.dart --selftest        all guards bite
py -3 tool/_sabotage.py                         ALL SABOTAGES CAUGHT
py -3 tool/type_scale_codemod.py --selftest     OK
py -3 tool/dropdown_width_check.py              passes
py -3 tool/glyph_coverage_check.py              passes
py -3 tool/one_clock_check.py                   0 sites, exit 0   (6 patterns)
py -3 tool/unphotographed_screens.py            94 targets, 94 photographed, 0 not
py -3 tool/health_probe.py                      7/7 services answering
flutter build web --release                     builds
flutter build apk --debug                       builds
docs/redesign/renders/                          227 renders
render harness — RENDER NOTE / FAILURE STATE    0 / 0
render harness — LOW CONTRAST                   0 (app screens; see below)
render harness — CUT OFF                        5 renders / 9 strings, deliberate
CRASH REPORTS RAISED ALL SESSION                0
APK ON JEAN'S SM-G780G                          963ca7e RAN AND WAS DRIVEN; 2b235c4 staged, not installed
```

Test count **2440 → 2478**. Guards **41 → 42**. `one_clock_check.py` went from
**5 patterns to 6**. Renders unchanged at 227 (fourteen were regenerated; none
added).

⚠️ **`CUT OFF` counts RENDERS, not strings** — 5 lines, 9 strings, unchanged.

⚠️ **LOW CONTRAST is 0 for app screens.** A raw `grep -c "LOW CONTRAST"` over a
full run returns **11**, all tagged `[unit]` — the reporter's own self-test.
Count `grep "LOW CONTRAST \[" out.txt | grep -vc "\[unit\]"`.

⚠️ **`health_probe.py` can report 6/7 on a cold extras project and it is not
down.** Measured this session: two consecutive attempts both hit the ~3 s
`anon` statement timeout, then four manual calls returned 200 in 2462 ms, 342,
722 and 355. The hourly `ping-extras-project` cron on main had run 50 minutes
earlier and succeeded 48 times in two days. The pages simply fall out of a
free-tier cache between pings. Warm it and re-run before concluding anything.

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

## 4. What is NOT done — PICK UP HERE

### 4.1 🚨 FIRST: the handset

See the top of this file. The APK is built, hashed and on the NAS; the phone
was asleep and only Jean can wake it.

### 4.2 What the sweep has now reached, and what it has not

**Driven at screen level:** the whole console; the mine, buyer and transporter
dashboards and their sub-screens; DRIVER and SECURITY on Android; and now the
**Load Controller** (including the Record Load sheet end to end), the
**Supervisor/Foreman** stockpile and production screens, **employee
management**, the **buyer's Loads & value**, and the **mine's Quality** tab.

**Not driven:**

- **The POD leg.** Trip `0d9c6792` is `en_route_to_offload`. The driver's POD
  upload needs a photo through the Android picker; the browser route can do it
  with `DOM.setFileInputFiles` (§5) but the driver's POD flow was not attempted.
  Two older trips sit in the same state, so this is a normal resting place, not
  a broken one.
- **The super-admin request → approve → link → dispatch chain**, from the
  requester's form to the due-diligence gate. The gate itself was driven in an
  earlier session; the four request FORMS have not been filled in this one.
- **Chat at length**, beyond the earlier session's two-account exchange.

### 4.3 What a handset still cannot prove at a desk

GPS fixes changing along a road, auto-reroute, the Android foreground service
surviving a long backgrounding, and battery over a real trip. The EMULATOR can
fake movement (`adb emu geo fix`) and the 2026-07-17 run proved the nav stack
that way. **The handset is NOT on adb** — CtrlBridge only.

### 4.4 One elevated-shell item for Jean

```powershell
Remove-NetFirewallRule -DisplayName 'CtrlBridge APK download (TCP in)'
```
A leftover from a much earlier session. Nothing listens on 8000 and the NAS
route makes it unnecessary.

### 4.5 One judgement call Jean may want to reverse

**The dock is not mounted on `/chat/:id`** — it was covering 61% of the send
button. If it should stay, the fix has to become geometric.

### 4.6 Closed, do not redo

- A live chat between two real accounts is DRIVEN.
- Contrast is closed app-wide AND for chat. `low_contrast_baseline.json` is
  `{}` — a FLOOR, not a ratchet. **If it fails, change the token; do NOT add a
  baseline entry.**
- All twelve route names are settled. MessagesScreen is NOT dead code.
- The due-diligence gate and the driver's mobile lifecycle were driven end to
  end; the load on the road is closed (trip `927cbf1b`).
- The 20 themeless test files are converted and guarded.
- **The transporter's route sheet does not leak the admin's margin** — checked
  again this session while driving the accept flow.

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

Continue the MineLink Material 3 redesign, exactly where the last session left
off. Read these TWO handoff files before doing anything else, in this order.

1. THE CURRENT HANDOFF — THIS IS THE FILE THAT GOVERNS THE WORK:

      C:\Users\Somebody Someone\Music\SHOWME!\MineLink-M3\HANDOFF.md

   Rewritten 2026-08-23 at the end of the session that finished the previous
   one's interrupted hardware checks, drove the last four roles nobody had ever
   opened — including ONE REAL LOAD through the entire mine floor — found
   THIRTEEN more defects doing it, fixed all thirteen, and discovered that the
   portal overflow sweep had been laying out EMPTY SCREENS its whole life.
   Read it in this order: "WHERE THIS SESSION STOPPED — READ THIS FIRST"
   (including "WHAT THE HANDSET DID AND DID NOT SEE"), then §0 (where you are +
   the one rule), §2 (verified state), §3 (what was done — §3.0 to §3.15, and
   DO NOT REDO ANY OF IT), §4 (what is NOT done — start at §4.1), §5 (how to
   work here, including how to drive a browser WITHOUT touching Jean's mouse)
   and §6 (seven things owed to the SHIPPING app).

2. THE OLDER MACHINE-WIDE HANDOFF — BACKGROUND ONLY, DO NOT WORK FROM IT:

      C:\Users\Somebody Someone\Claude\HANDOFF.md

   Dated 2026-08-08. MCP servers, git position, the decoy folders, the phone
   tooling. The MineLink-M3 handoff above governs this work; where the two
   disagree, the MineLink-M3 one wins.

THE PATHS THAT MATTER

  Work happens here (its own git repo, branch main, 165 commits, clean):
    C:\Users\Somebody Someone\Music\SHOWME!\MineLink-M3

  NEVER TOUCHED, for any reason:
    C:\Users\Somebody Someone\Music\SHOWME!\worktree-2026-05-05T11-53-29

THE ONE RULE THAT MUST NOT BREAK: nothing whatsoever changes inside
worktree-2026-05-05T11-53-29. CHECK IT AT THE START OF THE SESSION AND AGAIN AT
THE END:

    HEAD              df451d0
    git status        exactly 3 modified files, all pre-existing:
                        M .design-sync/config.json
                        M lib/features/super_admin/screens/margin_ledger_screen.dart
                        M test/widgets/app_sidebar_behaviour_test.dart
    file count        14163   (find . -path ./.git -prune -o -type f -print | wc -l)
    git worktree list exactly 2 entries — the main repo and that worktree
    modified today    0

  ⚠️ The count depends on which `find` you run. `find . -type f -not -path
  "./.git/*"` returns 14164, because in a WORKTREE .git is a FILE, not a
  directory. The -prune form returns 14163. Same untouched tree. Reading that
  tree is fine and often necessary; writing to it, or running any MUTATING git
  command inside it, is not.

🚨 START HERE — WHAT THE HANDSET DID AND DID NOT SEE

THE HANDSET DID RUN THIS SESSION'S WORK. Jean woke it, the APK built at 963ca7e
was installed over the NAS, and it was driven as the platform admin. On glass
that proved the build installs and runs against live data (Transporters 45 -> 46
trips, 1,405 -> 1,439 t), that /super-admin/crash-reports reads
"22 Aug 2026 . 20:50" rather than "Aug 22, 2026 8:50 PM", and that the recon
table shows 49 rows with Day = 102.10 t (exactly the three loads inside 24
hours). AND IT FOUND A DEFECT NOTHING ELSE COULD — his phone runs a raised
system font size, and the TIME-IN column rendered "12:35" as "12:3" over "5".

WHAT IT HAS NOT SEEN IS THE FIX FOR THAT, plus everything committed after
963ca7e. A newer APK is BUILT, HASHED AND STAGED:

    build/app/outputs/flutter-apk/app-debug.apk
    \\192.168.88.30\Shared\PhoneRemote\minelink-m3.apk
    SHA-256 6BCAE044229625FB32E770DC5CFA62D38EA6A3E584AF8F07BDA54F0663D82422
            (both ends match)

The phone's screen went to sleep again — between one probe and the next — and
only Jean can wake it. It was 02:15 and he had almost certainly turned in. The
session asked twice, said what it was for, and finished everything that did not
need the handset.

WARNING: THE SCREEN TIMEOUT IS SHORT — short enough to sleep during the ~2.5
minute download. Ask him to keep it awake, or to lengthen the timeout, before
starting the install.

ALSO TELL HIM: installing raised a Google Play Protect prompt, "Turn on Play
Protect?", which is a device-wide setting rather than a step in the install. It
was DECLINED, because declining leaves his configuration exactly as he had it.

So your first job is: install that APK and drive the four things a handset
proves and nothing else does —

  1. THE RECON TABLE AT HIS FONT SIZE. /super-admin/recon-tables, scroll into
     the table. TIME-IN must read "12:35" on ONE line. This is the one the
     handset itself found.
  2. THE DRIVER'S HERO CARD AT A RAISED TEXT SIZE. "CURRENT TRIP" and the
     status pill must sit on two lines with NO yellow-and-black stripe. At
     360px x 1.3 this overflowed by 44 pixels before 963ca7e. Verified on the
     emulator at font scale 1.3 with a real trip; not yet on glass.
  3. THE LOAD CONTROLLER'S TRUCK ROW AND THE BUYER'S RECONCILIATION CARD, same
     raised text size — 22px, 21px and 32px overflows before this session.
  4. NO NEW "Duplicate GlobalKey" CRASH REPORTS — baseline, navigate six or
     seven screens, re-count. SQL in §5. ZERO were raised all session from the
     handset, the emulator and six browser accounts, but this exact build has
     not been on glass.

Put the phone back the way it was found: signed in as the platform admin, on
home, every screenshot deleted.

🚨 DO NOT MOVE JEAN'S MOUSE. He works at this machine while the session runs,
and he said so mid-run. A helper that drove real OS clicks through SetCursorPos
was written, used twice and disabled the moment he said so. §5 has what to use
instead: a CDP driver that never touches the cursor, and the Android emulator.

VERIFIED STATE (all run at the end, against the tree as it stands)

flutter analyze                        no issues
flutter test                           2478 passed, 1 skipped
dart tool/release_guards.dart          42/42 PASS, 0 FAIL
dart tool/release_guards.dart --selftest   all guards bite
py -3 tool/_sabotage.py                ALL SABOTAGES CAUGHT
py -3 tool/type_scale_codemod.py --selftest  OK
py -3 tool/dropdown_width_check.py     passes
py -3 tool/glyph_coverage_check.py     passes
py -3 tool/one_clock_check.py          0 sites, exit 0   (6 patterns now, was 5)
py -3 tool/unphotographed_screens.py   94 targets, 94 photographed, 0 not
py -3 tool/health_probe.py             7/7 services answering
docs/redesign/renders/                 227 renders
render harness — RENDER NOTE / FAILURE STATE / LOW CONTRAST   0 / 0 / 0
render harness — CUT OFF               5 RENDERS / 9 strings, all deliberate
CRASH REPORTS RAISED ALL SESSION       0
flutter build web --release            builds
flutter build apk --debug              builds
  ⚠️ A raw grep -c "LOW CONTRAST" over a full test/renders run returns 11, all
  tagged [unit] — the reporter's OWN self-tests. Count app screens with
  grep "LOW CONTRAST \[" out.txt | grep -vc "\[unit\]", which is 0.
  ⚠️ health_probe can report 6/7 on a COLD extras project and it is not down:
  two attempts hit the ~3s anon statement timeout, then four manual calls
  returned 200 in 2462ms, 342, 722, 355. Warm it and re-run.

🚨 THE ONE THING TO READ EVEN IF YOU READ NOTHING ELSE

THE PORTAL OVERFLOW SWEEP HAD BEEN LAYING OUT EMPTY SCREENS ITS WHOLE LIFE. It
overrode mirrorCompanyIdProvider and nothing else, so it got past "Company not
loaded" and then EVERY PROVIDER RESOLVED TO AN EMPTY LIST — 27 screens x 3
widths x 5 text scales x bold, of empty states. Empty states are short and
short things do not overflow. The load controller's own source already carried
a comment about a 29px overflow "that no sweep had seen because the sweep ran
with no trips" — found by hand, fixed by hand, and the sweep left blind to the
next one. It runs on the real capture fixtures now, and turning the data on
found FOUR more real overflows on screens it had always covered and always
passed. When a suite is green, ask what it is green OVER.

WHAT IS ALREADY DONE — DO NOT REDO ANY OF THIS

Thirteen defects, every one found by DRIVING the app or by an instrument that
was made to see, every one fixed with a test that was SABOTAGED and watched to
fail before being kept — and every fix that turns a figure into a dash also
keeps a case that stays GREEN under sabotage, so over-fixing would show too.

  0. THE PREVIOUS SESSION'S TWO INTERRUPTED HARDWARE CHECKS, BOTH PASSED on the
     handset: the sign-out dialog copy (then Cancel), and 12 navigations with
     ZERO new Duplicate GlobalKey rows.
  1. A WALL CLOCK CONVERTED TWICE — six sites in the recon table including its
     Excel/CSV/PDF export of the billing record, two in the chat dock, three
     console "last active" readouts, the mine's Recent-waybills card. A no-op
     in South Africa, +2h on UTC, +6h in New York. THE FIXTURE HAD THE SAME
     ERROR MIRRORED so the two cancelled. MlTime.sast now ASSERTS it was handed
     a genuine instant, which is what found it.
  2. THE LIVE MAP'S ETA CAME OFF THE READER'S DEVICE. one_clock_check.py grew a
     sixth pattern for it.
  3. AN EIGHTH DATE DIALECT on three console screens — "Aug 22, 2026 8:50 PM".
     New guard no-skeleton-dateformat, which FAILED ON THE REAL TREE.
  4. A BARE TIME IN TWO LISTS THAT SPAN DAYS — the load controller read 10:10,
     04:51, 13:39 with the third six days old. New MlTime.listStamp.
  5. THE PRODUCTION TABLE CONTRADICTED ITS OWN HEADER — eight amber negatives
     under a "— Pit-to-port loss".
  6. THE QUALITY SCREEN PRINTED DELIVERED TONNAGE UNDER "PAYABLE" — one row
     showed a payable ABOVE its own mine net.
  7. R0.00 INVOICE VARIANCE, IN GREEN, WITH NOTHING INVOICED.
  8. THE EMPLOYEE REGISTER COUNTED A DIFFERENT SET from the screen next door.
  9. "SEALS — NOT REQUIRED" ON A ROUTE THE WEIGHBRIDGE REFUSES WITHOUT FOUR.
     Two columns disagree in production; the sheet read the one the load is NOT
     judged by.
 10. A DISTANCE CHIP THAT SOMETIMES SAID WHAT IT MEASURED.
 11. TWO "THIS WEEK" TONNAGES ON THE DRIVER'S SCREEN, 170.5 t and 136.3 t.
 12. THE DRIVER'S HERO CARD OVERFLOWED BY 44 PIXELS at 360px x 1.3, plus the
     four the sweep found once it had data.
 13. "12:35" RENDERED AS "12:3" OVER "5" on the recon table — found ON THE
     HANDSET, because Jean's phone runs a raised system font size. The table's
     minimum width was MEASURED at text scale 1.0 and then left fixed under a
     type size the reader controls. 0 wrapped cells at 1.0, SIXTEEN at 1.3 and
     at 2.0. A wrapped cell is a cell that FITS, so nothing could have seen it.

ALSO DONE: ONE REAL LOAD DRIVEN THROUGH THE ENTIRE MINE FLOOR (trip 0d9c6792,
truck S6W001GP) — transporter accepts, truck and driver assigned, driver
starts, security checks in, tare 15.40 t, gross 49.60 t, net 34.20 t computed
live and agreeing in three places, four seals numbered and photographed against
seal_points=4, waybill TRP-6C72DDAC41 minted with the controller's signature,
gate check-out. The stat card moved to exactly (34.2+33.7+30+34.2)/4 = 33.025 t.

ALSO SETTLED EARLIER — DO NOT REOPEN: a live chat between two real accounts is
driven; all twelve route names are settled; MessagesScreen is NOT dead code;
contrast is closed app-wide and for chat (the baseline file is a FLOOR, not a
ratchet — if it fails, change the token, do NOT add a baseline entry); the
due-diligence gate and the driver's whole mobile lifecycle were driven end to
end; the 20 themeless test files are converted and guarded.

WHAT IS LEFT

1. THE HANDSET — the three checks under START HERE.
2. NOT YET DRIVEN (§4.2): the POD leg of trip 0d9c6792 (it sits at
   en_route_to_offload, which two older trips also do, so it is a normal
   resting place); the super-admin request → approve → link → dispatch chain
   from the requester's FORMS forward; chat at length.
3. WHAT A HANDSET CANNOT PROVE AT A DESK: GPS along a real road, auto-reroute,
   the foreground service surviving a long backgrounding, battery over a trip.
   The EMULATOR can fake movement (adb emu geo fix); a real handset cannot be
   teleported. The handset is NOT on adb — CtrlBridge only.
4. SEVEN THINGS OWED TO THE SHIPPING APP (§6), not fixable here because
   supabase/ is frozen. Two are new this session: record_truck_load records a
   load it could not deduct and says nothing, and the two seal_required columns
   diverge with nothing reconciling them.
5. ONE ELEVATED-SHELL ITEM FOR JEAN (§4.4) — a leftover firewall rule.
6. 🚨 IF YOU NEED THE PHONE AND IT DOES NOT ANSWER — phone_agent.py status says
   "no phone at a known address - broadcasting", or probe reports under 0.1
   bits/pixel because the display is asleep — PAUSE AND TELL JEAN, THEN KEEP
   WORKING ON WHAT DOES NOT NEED IT and re-probe as you go. Only he can turn
   host mode on and only he can wake a sleeping screen; neither is possible
   from this PC, and injected touches cannot wake it. Do NOT work around it and
   do NOT report green as though the phone step were optional — it is the only
   thing that proves a fix on real hardware. ⚠️ HOST MODE STAYING ON DOES NOT
   MEAN THE SCREEN IS AWAKE: check probe, not just status. ⚠️ Invoke the
   driving-jeans-phone skill FIRST. It is his PERSONAL phone.

HOW TO WORK — THIS IS JEAN'S INSTRUCTION, FOLLOW IT

don't worry about me seeing anything, I'll want to see when everything is
complete and done, so don't stop so much in between please run the task for as
long as possible so that we can get this completley done and sorted please,
correct your self where you make mistakes and fix the mistakes and make sure
you don't implement anything with gaps in them make sure its full and proper
like the original

AND, EXPLICITLY: IF YOU FIND PROBLEMS ALONG THE WAY, FIX THEM AS YOU GO — then
TEST THE FIX AND CONFIRM IT ACTUALLY WORKS AS EXPECTED. Do not merely note or
collect a list of faults to hand back; do not leave a fix unverified. Every fix
gets a test that BITES (remove the fix, watch the test fail), and where the fix
is visible on a device or in a browser, LOOK AT IT THERE TOO. Half-implemented
work, TODOs, stubs and "this could be improved later" notes are not acceptable
— finish each thing properly and fully, the way the original app does it.

THE METHOD, unchanged: fixtures, regenerate, LOOK at the picture, measure with
PIL rather than squint, fix the SHAPE rather than the symptom when the fault is
structural, then pin it with a test and prove the test bites by removing the
fix and watching it fail. When a report and a picture disagree, THE PICTURE
WINS. When a picture and a HANDSET disagree, the handset wins.

THE LESSONS THIS SESSION ADDED:

- 🚨 NEVER MOVE JEAN'S MOUSE. Drive the browser through CDP (§5) or use the
  Android emulator.
- 🚨 WHEN A SUITE IS GREEN, ASK WHAT IT IS GREEN OVER. The overflow sweep ran
  405 combinations against empty providers.
- 🚨 CDP CLICKS CANNOT REACH A FLUTTER POPUP-MENU OVERLAY, while every other
  click on the page works. It is the tool, not the app. Switch accounts by
  clearing localStorage instead of using the menu.
- 🚨 A FILE INPUT CAN BE DRIVEN: Page.setInterceptFileChooserDialog + click +
  DOM.setFileInputFiles. That is how five photos were attached to a real load.
- 🚨 io.open(p,'w') IN PYTHON REWRITES A FILE'S LINE ENDINGS ON WINDOWS and
  turns a 3-line change into a whole-file diff. Pass newline='' on both ends,
  or run fix_eol.py before committing.
- 🚨 MEASURE BEFORE CHOOSING WORDS. "Tons loaded this week" was picked, the
  test measured 134px beside 154px, and the answer was to fix the ROW
  (IntrinsicHeight + stretch) rather than trim the label.
- 🚨 THE SAME FIX IS WRONG IN TWO PLACES FOR OPPOSITE REASONS: Flexible in a
  shrink-wrapped Row throws; Flexible in a bounded Row is exactly right. Say
  which situation each fix is in.
- 🚨 CHECK WHETHER A "FAULT" IS THE DATA, OR THE TOOL. Three looked wrong and
  were not.
- 🚨 A SABOTAGE MUST COMPILE — and keep a case that stays GREEN under it, or
  over-fixing looks like success.
- 🚨 A BASH HEREDOC EATS BACKSLASHES even when quoted. Write patch scripts with
  the Write tool.

BEFORE CLAIMING ANYTHING IS DONE, ALL OF THESE MUST BE GREEN:

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

...AND the original worktree re-checked against the baseline above.

LIVE ACCOUNTS
  active user accounts.txt in the repo root.
  jean@cyberhouse.co.za / BuRG3rJ3@n1995@#   (platform admin)
  everything @mineralguide.com / MineralGuide123!
  Used this session: ironhills.owner, ironhills.controller, ironhills.security,
  atlasbuyer.owner, roadhaul.admin, and roadhaul.driver on the emulator.

WHEN THE WORK IS DONE: rewrite

C:\Users\Somebody Someone\Music\SHOWME!\MineLink-M3\HANDOFF.md

the same way this one was written — verified state only, no intentions, ending
with a fresh self-contained copy-paste block in §8 that carries BOTH handoff
paths (that one and C:\Users\Somebody Someone\Claude\HANDOFF.md), the project
root, the untouchable worktree path and its baseline, exactly where you
stopped, what is already done so it is not redone, what is left, THE PHONE RULE
above, THE MOUSE RULE above, this same HOW TO WORK instruction from Jean quoted
verbatim, and the fix-as-you-go rule — and then commit it. State the commit
count the tree WILL be at once that commit lands, and say that the tip is the
commit carrying the file, so the handoff is self-consistent rather than
describing a tree without itself.
