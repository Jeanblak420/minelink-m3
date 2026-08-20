# MineLink M3 — session handoff

**Written 2026-08-20.** Everything below is verified state, not intention.

---

## 0. Where you are

| | |
|---|---|
| **This project** | `C:\Users\Somebody Someone\Music\SHOWME!\MineLink-M3` |
| What it is | A **complete, independent fork** of MineLink, being redesigned onto Material 3. Its own git repo (`main`), **28 commits**, clean tree. |
| **The original** | `C:\Users\Somebody Someone\Music\SHOWME!\worktree-2026-05-05T11-53-29` — **DO NOT TOUCH IT.** |

### The one rule that must not be broken

**Nothing whatsoever changes inside `worktree-2026-05-05T11-53-29`.** That was
Jean's instruction and it has held for every commit so far. Its verified
baseline, which you should re-check at the start and end of any session:

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
  continue with web and mobile please"* — Windows is blocked by two
  pre-existing faults (see §6); web and Android both build.
- **Work long, don't stop to check in.** *"don't worry about me seeing
  anything, I'll want to see when everything is complete and done, so don't
  stop so much in between please run the task for as long as possible so that
  we can get this completely done and sorted please, correct yourself where you
  make mistakes and fix the mistakes and make sure you don't implement anything
  with gaps in them make sure its full and proper like the original"**

Four decisions settled before any code, recorded in `docs/redesign/DESIGN.md`:

| Question | Answer |
|---|---|
| Preview or a real app? | **A real working fork.** It runs against the live database. |
| How far does the look move? | **M3 Expressive, MineLink palette.** Navy chrome, `#22D3EE`, the three fonts — kept. Colour roles, shape, motion, components — rebuilt. |
| What order? | Foundation → the screens that matter → the tail. |
| What happens when a button writes? | **It writes.** Jean chose no guard. |

**`supabase/` is frozen.** No migration is created, applied or pushed from this
project. A redesign needs no schema change, and a schema change from a design
fork against a production database with no staging is not recoverable.

---

## 2. Verified state, right now

```
flutter analyze                    no issues
flutter test                       1565 passed, 1 skipped (a tag-gated
                                   capture task, not a disabled assertion)
dart tool/release_guards.dart      26/26 PASS
dart tool/release_guards.dart --selftest    all guards bite
flutter build web --release        builds, main.dart.js 7.9 MB
flutter build apk --debug          builds, 180 MB
docs/redesign/renders/             18 PNGs, zero layout faults at any size
```

Layout is swept at **8 widths (1612 → 360px) × 6 text scales (0.85 → 2.0)**
across the console, the portal, and the 22 screens nothing had ever rendered.

---

## 3. What has been done

### Phase 1 — the foundation (commits 1–9)

- **One `ColorScheme`.** The app seeded Material from `MlTokens.teal700`
  (`#0F6E8C`, a colour that appears nowhere in the interface) while twelve token
  files used `#22D3EE`. Nothing reconciled them, so every un-restyled Material
  widget came out teal on a cyan interface. `MlSemantic` is now a derived view
  onto the one scheme.
- **`MlShape`, `MlMotion`, `MlTypeScale`** — the M3 shape / motion / type
  primitives.
- **`MlAppShell`** — one shell for every role, replacing ~9,100 lines that drew
  one navigation five ways. Net **−5,618 lines** while adding a design system.
- Six real defects fell out: Targets unreachable from the default sidebar; the
  portal's whole rail invisible to screen readers; the phone menu button with no
  accessible label; rail tiles producing no semantics nodes; a "mobile parity"
  test that never ran at mobile width; the type theme silently overwriting the
  font families it had just assigned.

### Phase 2 — what actually looking at the screens found (commits 10–28)

**Fabricated figures on the platform admin's landing screen.** Four literals:
`This month · Jul 2026` (written in July, still saying July in August); an
invented `2 aging > 24h`; `Last 24h · +2 companies, +14 users`, which was a
**fake copy of a number the view model already computed and displayed correctly
on the tiles beside it**; and an expired-token *alert banner* that took no data
at all and rendered unconditionally. A fifth turned up when the guard was
written: the flagship chart's crosshair labelled every point `AUG NN` forever on
all three portal dashboards.

**The test suite reported coverage it did not have, three separate ways.**

1. The console sweep's narrowest width was **860px**, so no console screen had
   ever rendered on a phone — while nine tests said they "survive every width x
   text scale".
2. **Fourteen sweeps stopped at text scale 1.3** while the shells compose the
   in-app slider with the platform's and cap at 2.0. Raising them found seven
   overflows, none of which reproduce at or below 1.3.
3. **Twenty test files rendered under a bare `MaterialApp`** — stock Material's
   type scale in stock Material's font family.

**22 of 74 routed screens had no test that even named them**, including
`LoginScreen`. Sweeping them produced 20 green ticks — and measuring what they
actually painted showed **8 of 19 painted fewer than 3 text runs and 4 painted
zero**; `fleet_management` rendered *"Company information not available."*
Fixtures now get all of them rendering: **PROVING SOMETHING: 18 / 18**, and the
baseline of excuses is an empty `const`.

**Three animations ignored reduce-motion**, all inescapable: the notification
bell (which re-shakes every 30 seconds indefinitely, in the app bar of every
screen), the chat dock's typing dots, and the driver's waypoint pulse. A loop
cannot be fixed by shortening it — 1ms would run it at a thousand frames a
second — so the fix is not starting it.

**Several competing design systems, collapsed:**

| | before | after |
|---|---|---|
| corner radii in `lib/` | **24 distinct values**, 320 sites | 7 scale steps |
| font sizes | **37 values**, 1,015 sites, ten half-points | 27, no half-points |
| type scales | **two**, 1px apart where it matters | one |
| names per typeface | **two** each | one each |

**~21 layout defects fixed**, essentially all one fault: a `Row` hands a
non-flex child unbounded width, so its own `overflow: ellipsis` never engages
(`CLAUDE.md` §10.4).

### The six guards added this phase

| guard | stops |
|---|---|
| `no-hardcoded-month-in-ui` | a month name and year written into a UI string |
| `no-row-around-a-header-that-has-an-actions-slot` | wrapping a header in a `Row` to put a button beside it |
| `test-renders-under-the-app-theme` | a bare `MaterialApp` in a test |
| `no-off-scale-corner-radius` | a corner radius written as a number |
| `no-half-point-font-size` | a font size belonging to neither scale |
| `text-scale-sweep-reaches-the-ceiling` | a sweep capping below `kMaxEffectiveTextScale` |

---

## 4. What is NOT done — pick up here

Ordered by value. Nothing here is blocked; all of it is work.

### 4.1 Per-screen type work — the largest remaining item

`python` the drift script (below) and it reports **3,158 points across 142
files**, down from 5,153. What remains is almost entirely type:

- **~640 raw `fontSize:` literals** across 27 whole-point values. Deliberately
  left: consolidating them moves 18px sub-headings to 16 or 22, which is a
  per-screen design decision a blanket codemod could get wrong in a way that
  looks deliberate. The half-points are gone because no scale has half-points.
- **~500 sites naming a font family by hand.** Safe but not free: a `TextStyle`
  built from scratch does not inherit the scale's `height` and `letterSpacing`,
  so **line spacing varies across the product**. The proper fix is converting
  each to `Theme.of(context).textTheme.<slot>.copyWith(...)`, which needs a
  `BuildContext` many sites do not have and a slot choice per site.

**Do this screen by screen, top of the drift list first**, verifying with the
sweeps after each. The current top:

```
 379  employee/screens/employee_profile_screen.dart      (2148 lines, 69 TextStyles)
 352  super_admin/screens/super_admin_org_insights_screen.dart
 273  super_admin/screens/super_admin_company_mirror_screen.dart
 206  super_admin/widgets/insights_v2/minelink_screen_targets.dart
 189  super_admin/widgets/insights_v2/minelink_screen_dashboard.dart
 181  company/screens/employee_register_screen.dart
```

Re-measure with:

```python
# save as /tmp/drift.py, run from the repo root
import re, glob
rows=[]
for f in glob.glob('lib/features/**/*.dart', recursive=True):
    s=open(f,encoding='utf-8',errors='replace').read()
    fam  = len(re.findall(r'fontFamily:\s*MlTokens\.font', s))
    size = len(re.findall(r'fontSize:\s*[0-9]', s))
    frac = len(re.findall(r'fontSize:\s*[0-9]+\.[0-9]', s))
    rad  = len(re.findall(r'BorderRadius\.circular\(\s*[0-9]', s))
    mot  = len(re.findall(r'Curves\.|Duration\(milliseconds:', s))
    sc = fam*2 + size*2 + frac*3 + rad*3 + mot*3
    if sc: rows.append((sc,f,fam,size,frac,rad,mot))
rows.sort(reverse=True)
for r in rows[:20]: print(r)
print('files:', len(rows), 'total:', sum(r[0] for r in rows))
```

### 4.2 A Supabase transport fake

Three screens — **fleet management, the operations hub, the communications
hub** — cannot be photographed. `FleetNotifier` opens a realtime channel
**unconditionally in its constructor** and the two hubs issue queries; against
the dummy localhost instance that is a real socket attempt which leaves a
pending timer. A sweep survives it (pumps and ends); a golden does not
(`expectLater` keeps the body alive long enough for the invariant check).

They **are** swept for layout at every width and scale. What is missing is a
picture. Pumping past the retry does not work — the reconnect reschedules
itself. This needs a transport fake, which is test infrastructure rather than a
design task.

### 4.3 No screen has been individually redesigned

Every screen *changed* — theme, shell, components, shape scale, type scale — and
every layout defect found along the way is fixed. But the ~20 screens of Phase 2
and the ~80 of Phase 3 have not been hand-rebuilt against the console reference.

### 4.4 Nothing has run on real hardware

- No APK installed on a handset. (Jean's phone can be driven — see the
  `driving-jeans-phone` skill in the global `CLAUDE.md`.)
- Nothing driven against the live database in a browser as a signed-in user.
- iOS not attempted; no reachable Apple Developer account.

### 4.5 Windows — blocked, and not this project's fault

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
flutter test                                     # 1565 passing
dart tool/release_guards.dart                    # 26/26
dart tool/release_guards.dart --selftest         # every guard must BITE
flutter test test/renders --update-goldens       # after any visual change
flutter build web --release
flutter build apk --debug
```

### Things that have already gone wrong here — do not repeat them

- **`dart format` on a directory reformats files you did not touch.** It did
  131 files once and 106 another time, burying the real change. Format only what
  you edited, or not at all.
- **A codemod must not edit prose.** One rewrote a doc comment reading *"Not
  `BorderRadius.circular(11)`"* — the sentence explaining the rule — into
  something that no longer says anything.
- **Read files with `newline=''` in Python.** Universal newlines convert CRLF to
  LF and turn a 340-line change into 5,342 insertions.
- **A failing golden comparison can mask a failing test.** A "Pixel test failed,
  0.04%" hid a pending-timer assertion for a while. Delete the golden and re-run
  to see the real error.
- **Backticks in a bash heredoc get executed.** A commit message lost a phrase
  that way. Write commit messages to a file and use `git commit -F`.
- **Never `git stash`, `git checkout -- .`, or `git clean`** in the original
  worktree — other agent sessions write it (`CLAUDE.md` §10.1).

### Where the reasoning lives

- `docs/redesign/DESIGN.md` — decisions, what each cost, what is not true yet.
  §8 is the Phase 2 census.
- `docs/redesign/VERIFICATION.md` — what was actually executed, and what has
  not been.
- `docs/redesign/renders/` — 18 PNGs.
- Every commit message carries its own reasoning; `git log` is a real record.

---

## 6. The project's own rules still apply

`CLAUDE.md` in this repo is the fork's copy of the shipping app's. It still
governs. The ones that keep mattering:

- **§10.4** — a `Row` hands a non-flex child unbounded width. Nearly every
  layout defect in this project has been this.
- **§10.5** — a green test over an empty fixture, an error state, or a fallback
  font proves nothing. Report *screens proving something / N*.
- **§7** — `flutter test` renders in a fallback font unless you load the real
  ones. If an overflow figure looks like `characters × fontSize`, that is why.
- **§7.1** — one clock, Africa/Johannesburg. `MlTime`, never `DateTime.now()`
  for anything a user reads as a date.
- **§10.6** — Dart bitwise operators are unsigned 32-bit on the web.
- **§1** — the package is `flutter_application_1`. Do not rename it.
