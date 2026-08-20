# MineLink M3 — session handoff

**Rewritten 2026-08-20, end of the Phase 3 session.** Everything below is
verified state, not intention. It replaces the previous handoff of the same
name; the parts of that one still true have been folded in.

---

## 0. Where you are

| | |
|---|---|
| **This project** | `C:\Users\Somebody Someone\Music\SHOWME!\MineLink-M3` |
| What it is | A **complete, independent fork** of MineLink, being redesigned onto Material 3. Its own git repo (`main`), **41 commits**, clean tree. |
| **The original** | `C:\Users\Somebody Someone\Music\SHOWME!\worktree-2026-05-05T11-53-29` — **DO NOT TOUCH IT.** |

### The one rule that must not be broken

**Nothing whatsoever changes inside `worktree-2026-05-05T11-53-29`.** That was
Jean's instruction and it has held for every commit. Its verified baseline,
re-checked at the start, middle and end of this session:

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
  anything, I'll want to see when everything is complete and done, so don't stop
  so much in between please run the task for as long as possible so that we can
  get this completely done and sorted please, correct yourself where you make
  mistakes and fix the mistakes and make sure you don't implement anything with
  gaps in them make sure its full and proper like the original"**

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

```
flutter analyze                    no issues
flutter test                       1592 passed, 1 skipped (a tag-gated
                                   capture task, not a disabled assertion)
dart tool/release_guards.dart      27/27 PASS
dart tool/release_guards.dart --selftest    all guards bite
py -3 tool/type_scale_codemod.py --selftest   OK
py -3 tool/dropdown_width_check.py            passes; --selftest OK
py -3 tool/glyph_coverage_check.py            passes; --selftest OK
flutter build web --release        builds, main.dart.js 7.86 MB
flutter build apk --debug          builds
docs/redesign/renders/             25 PNGs, zero layout faults at any size
```

Layout is swept at **8 widths (1612 → 360px) × 6 text scales (0.85 → 2.0)**
across the console, the portal, and the 22 screens nothing had ever rendered.

---

## 3. What Phase 3 did (this session, commits 30–41)

Full reasoning is in each commit message and in `docs/redesign/DESIGN.md` §9.
`git log` is a real record — read it rather than trusting this summary.

### 3.1 The type work (§4.1 of the old handoff) — DONE

**902 hand-built `TextStyle` literals across ~150 files** now reach a scale slot.
`fontFamily` sites in `lib/` went **497 → 128**; raw `fontSize` **~1,031 → 212**.
The codemod reports **zero** convertible sites left.

- **`MlText`** (`lib/core/design/tokens/m3/ml_typography.dart`) — the scale as a
  screen reaches for it: `context.mlText.titleSmall.copyWith(color: …)`.
  Fifteen M3 slots, non-null, so 900 call sites do not each end in a `!`.
- **Three `editorial` rungs** at 24/20/16 — Fraunces at *title* size, which had
  no rung at all. The serif does two jobs and the scale named one.
- **`tool/type_scale_codemod.py`** — the engine, with five documented refusals
  and a `--selftest`. Re-runnable.
- **A fourth typeface retired** — `kConsoleSans = 'Sora'`, alive at 7 console
  sites while the rail beside them ran Plus Jakarta Sans. Out of `lib/` and out
  of `pubspec.yaml` (5 weights, 292 KB in every build).
- **Three sites rendered in the OS's generic monospace**, not JetBrains Mono.
- **16 half-points the guard could not see** — behind parameter defaults and
  `MlOv.s(size:)`. `no-half-point-font-size` matches the *name* now.
- **New guard `typeface-named-by-hand`** — a ratchet at 128, which can only
  shrink. The 128 are const literals, `MlOv`'s ported helpers, and
  `CustomPainter.paint()`; DESIGN.md §9 measures what that costs (±1.4px of line
  box for 85 of the 96 const sites, zero for the two inside a parent span).

### 3.2 The renders (§4.2 of the old handoff) — DONE, and it was never a transport fake

The old handoff asked for a Supabase transport fake so three screens could be
photographed. The real blocker was a **constructor**: `FleetNotifier`,
`OperationsNotifier` and `CommunicationsNotifier` each loaded and opened realtime
channels from theirs, so none could be *constructed* without a network.
**`start()`** is the seam; the providers call it immediately, so the running app
is unchanged.

The dashboards needed no seam at all — `test/fixtures/portal_capture_fixtures.dart`
already overrode every portal data provider and was only wired into the
design-*reference* capture.

**Seven screens that had no picture now have one**: fleet management, the
operations hub, the communications hub, the three role dashboards, and the
driver's Trip screen. Renders went 18 → 25.

Four fixture gaps found by photographing: `kFleetStatus` existed and was never
registered; `fleetMaintenanceProvider` had no fixture (so the third fleet state
had never been drawn); `vehicleDriversProvider` had none (the driver hero read
*"Couldn't load your trip"*); and the two fixture files **described two
different fleets** — one namespace now.

### 3.3 Design and layout work (§4.3, STARTED — see §4)

- **13 dropdowns** free to size themselves to their widest option, one of which
  overflowed 31px at 430×1.6. `tool/dropdown_width_check.py` holds it.
- **A character no shipped font can draw** — `✓` in two driver buttons and a
  chat receipt. `tool/glyph_coverage_check.py` reads the `cmap` out of each TTF.
- **Four screens with two margins** — a `Column` centres its children, so a hero
  card floated mid-page while everything below ran full width. One of the four
  was the **portal shell**.
- **15 of 16 horizontal scroll views had no scrollbar** — a table showing a
  column cut off mid-word with nothing to say more existed. `MlWideTable`, plus
  a themed scrollbar whose contrast is **measured** (3:1 minimum, both themes).
- **Every dashboard floated in the middle of the window** — the shell's Row used
  the default `crossAxisAlignment: center`, so the workspace shrink-wrapped and
  was centred. Measured 168px of nothing above and below on a 1900px window, and
  the gap scaled with the window. Pinned by
  `test/widgets/shell_workspace_alignment_test.dart`, proven to bite.

Also fixed: **no scrollbar had ever appeared in any render**, because
`RawScrollbar` fades in from a post-frame callback and `shoot()` pumped once.
And **the 895px mystery** the render file blamed on an animation was
`Image.asset` resolving only when an earlier test had warmed the cache.

---

## 4. What is NOT done — PICK UP HERE

### 4.1 §4.3 — the per-screen redesign against the console reference (IN PROGRESS)

This is the main remaining work and where the last session stopped.

Every screen *changed* (theme, shell, components, shape scale, type scale) and
the systemic faults above are fixed, but **the ~20 screens of Phase 2 and the
~80 of Phase 3 have not been hand-rebuilt against the console reference.**

The method that has been working, and should continue:

1. **Add the screen to `test/renders/redesign_renders_test.dart`** with the
   fixtures it needs, and regenerate:
   `flutter test test/renders --update-goldens`
2. **Look at the PNG.** Every defect in §3.3 was found this way and none of them
   failed a test.
3. **Measure, do not squint.** `PIL` is available. Reading pixel values out of a
   render is how the scrollbar contrast, the top gap and the tofu glyph were all
   settled. Three plausible explanations for the top gap were wrong before the
   measurement found the fourth.
4. Fix the *shape* rather than the instance where the fault is structural —
   `TargetsPage`, `MlWideTable`, the shell Row.
5. Pin it with a test that would have caught it, and **prove the test bites** by
   removing the fix and watching it fail.

**Screens still without a picture** (start here — every one photographed so far
found something):

- the mine dashboard is rendered but has not been *looked at* closely
- the load controller, security check-in, the recon tables, reconciliations
- the request/dispatch dialogs, the margin ledger, the org insights screens
- the driver navigation screen
- anything on a phone: only 4 of the 25 renders are phone-width

**Known cosmetic items already spotted and not yet fixed:**

- The hub hero cards sit in a `MlCard(hero: true)` whose accent border reads
  heavier than the console's equivalent. Compare against
  `docs/design-reference/super-admin-dashboard-dark.png`.
- The buyer light dashboard's canvas gradient is a much stronger step than the
  dark one — worth measuring both.

### 4.2 The 128 remaining hand-named typefaces

Held by the `typeface-named-by-hand` ratchet, which can only shrink. They are
three different things and DESIGN.md §9 measures each. **Not** a gap — a
decision — but the ratchet is there so it can be revisited.

### 4.3 Nothing has run on real hardware

- No APK installed on a handset. (Jean's phone can be driven — see the
  `driving-jeans-phone` skill in the global `CLAUDE.md`.)
- Nothing driven against the live database in a browser as a signed-in user.
- iOS not attempted; no reachable Apple Developer account.

### 4.4 Windows — blocked, and not this project's fault

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
flutter test                                     # 1592 passing
dart tool/release_guards.dart                    # 27/27
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
  lines for a 14-site change. Emit correctly-formatted code instead; the codemod
  does.
- **A codemod must not edit prose.** One rewrote the doc comment *explaining* a
  rule into something that no longer said it. The same trap caught a *test*:
  `one_type_scale_test.dart` failed on the comment recording that Sora had been
  retired. It strips comments now.
- **Read files with `newline=''` in Python.** Universal newlines turn a 340-line
  change into 5,342 insertions.
- **A failing golden comparison can mask a failing test.** Delete the golden and
  re-run to see the real error.
- **Backticks in a bash heredoc get executed**, and heredocs mangle `$` and
  backslashes. Write commit messages and multi-line scripts to a **file** and use
  `git commit -F` / `py -3 file.py`.
- **`git add -A` sweeps `test/renders/failures/`** — golden-comparison scratch.
  It is `.gitignore`d now.
- **Never `git stash`, `git checkout -- .`, or `git clean`** in the original
  worktree — other agent sessions write it (`CLAUDE.md` §10.1).
- **A Windows console is cp1252** and cannot encode the characters these tools
  talk about. Both Python checks force UTF-8 on stdout; `glyph_coverage_check.py`
  died printing its own findings before that.

### Where the reasoning lives

- `docs/redesign/DESIGN.md` — decisions and what each cost. §8 is the Phase 2
  census, **§9 is the Phase 3 record** (the type work, the codemod's refusals,
  the measured drift table).
- `docs/redesign/VERIFICATION.md` — what was actually executed, and what has not
  been. Its "still open" list is current.
- `docs/design-reference/` — the **pre-redesign** reference PNGs, committed in
  the baseline commit. **Do not regenerate them**; they are the before-image.
- `docs/redesign/renders/` — 25 PNGs of the redesign.
- Every commit message carries its own reasoning.

---

## 6. The project's own rules still apply

`CLAUDE.md` in this repo is the fork's copy of the shipping app's. The ones that
keep mattering:

- **§10.4** — a `Row` hands a non-flex child unbounded width. Nearly every
  layout defect in this project has been this, or its sibling: a `Row`/`Column`
  **centring** a child because nobody named `crossAxisAlignment`.
- **§10.5** — a green test over an empty fixture, an error state, or a fallback
  font proves nothing. Report *screens proving something / N*.
- **§7** — `flutter test` renders in a fallback font unless you load the real
  ones. If an overflow figure looks like `characters × fontSize`, that is why.
- **§7.1** — one clock, Africa/Johannesburg. `MlTime`, never `DateTime.now()`.
- **§10.6** — Dart bitwise operators are unsigned 32-bit on the web.
- **§1** — the package is `flutter_application_1`. Do not rename it.
