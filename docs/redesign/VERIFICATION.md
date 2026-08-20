# Verification log

What has actually been executed, and what has not. Written this way on purpose:
`CLAUDE.md` §10.5 records that 28 green tests once covered 7 real screens, and
that the honest number is *"screens proving something / N"*, never the passing
count.

---

## Phase 1 — the foundation

Everything below was run on the tree at commit `HEAD` of `main` in this
project.

| Check | Result |
|---|---|
| `flutter analyze` | **No issues found**, all 520 library files |
| `flutter test` | **1,417 passed, 0 failed** (1 pre-existing expected-failure) |
| `dart tool/release_guards.dart` | **20 / 20 PASS** |
| `flutter build web` (dart2js) | **succeeded** — `main.dart.js`, 7.9 MB |
| `flutter build windows --debug` | ❌ **blocked — twice, neither cause is the redesign.** See below |
| Renders — 13 screens/sizes/themes | generated, `docs/redesign/renders/` |

### Windows does not build, and it is not this project's fault

Two independent blockers, both pre-existing:

**1. The folder path.** The Flutter tool refuses outright:

```
Path C:\Users\Somebody Someone\Music\SHOWME!\MineLink-M3 contains invalid
characters in "'#!$^&*=|,;<>?". Please rename your directory ...
```

That is the `!` in `SHOWME!`. **The canonical shipping tree lives under the
same folder**, so `flutter build windows` cannot have been run from there
either. (Not verified by running it there — doing so would write `build/` and
`.dart_tool/` into a tree this project must not touch.)

**2. `firebase_core`'s Windows CMake step.** Building from a clean path
(`C:\mlm3_winbuild`) clears blocker 1 and reaches CMake, which then fails
identically on two consecutive clean runs:

```
CMake Error: Problem with archive_write_finish_entry(): File size could not be restored
CMake Error at flutter/ephemeral/.plugin_symlinks/firebase_core/windows/CMakeLists.txt:46
  file failed to extract: build/windows/x64/firebase_cpp_sdk_windows_12.7.0.zip
```

`firebase_core` came in with the push-notification work (R-2) and pulls the
Firebase C++ SDK on Windows. The shipping app carries the same dependency at
the same version, so it is expected to fail the same way.

**Conclusion: the Windows target is untested, for this project and for the
shipping app.** It is not known to be broken; it is known to be unbuildable in
this environment until the path is changed and the `firebase_core` Windows
extraction is resolved. Moving the project to a path without `!` is the first
step and is a decision for Jean, since it changes where the folder lives.

Two guards worth naming individually, because they are the ones that would have
caught the redesign cheating: **`no-raw-color-hex: 0`** and
**`no-material-colors: 0`**. The whole design system is expressed in tokens; no
colour literal escaped into feature code.

### The web build matters more than it looks

`CLAUDE.md` §10.6 records a bug where a live 10 km route decoded to 599,295 km
in a browser and 10 km on the VM, because Dart's bitwise operators are unsigned
32-bit under dart2js. The unit tests were green throughout — they ran on the
runtime that was right. So "it compiles for web" is a distinct claim from "the
tests pass", and both are made here.

---

## What the renders prove, and what they do not

### What there are pictures of

| file | what it shows |
|---|---|
| `login-desktop-dark`, `login-phone-dark` | the only screen every user of the product sees |
| `console-desktop-dark`, `-light`, `-rail-collapsed` | the platform admin's landing screen, the design reference |
| `console-medium-dark` | the rail narrowing, nothing removed |
| `console-phone-dark`, `-light` | bottom bar and drawer |
| `portal-transporter-desktop-dark` | the transporter rail: Operations / Fleet / Money / Tracking / Reconciliation / Company |
| `portal-mine-desktop-dark` | the mine rail — a different tree from the same shell |
| `portal-buyer-desktop-light` | the buyer rail, in light |
| `portal-transporter-phone-dark` | that same tree reflowed to a bottom bar |
| `portal-driver-phone-dark` | the driver's five destinations: Dashboard · My routes · Live map · Compliance · More |

The portal shots deliberately carry a **placeholder body**, and say so on the
image. Those dashboards need a company, a session and live providers; a picture
of a spinner or an error is not a picture of the design. What is real in every
one of them is the thing the brief actually asked about — *"the placement of
everything"*: the rail and its grouping for that role, the top bar, the canvas,
and how all of it reflows onto a phone. That is what differs between the four
roles, and it is what these show.

`test/renders/redesign_renders_test.dart` renders the **real** console screens —
real widgets, the real shell, the real fonts, and the Material icon font — at
six size and theme combinations, and writes PNGs.

They exist because the app needs a Supabase session to reach the console, so a
browser visit only ever shows the login screen. These make the design judgeable
without credentials and without a device.

| Render | What it shows |
|---|---|
| `console-desktop-dark.png` | 1600×1900, expanded rail — the flagship |
| `console-desktop-light.png` | the same in light |
| `console-desktop-dark-rail-collapsed.png` | 80dp rail with flyout groups |
| `console-medium-dark.png` | 760px — the rail narrows, nothing is removed |
| `console-phone-dark.png` | 412px — drawer + bottom bar |
| `console-phone-light.png` | the same in light |

**They are renders, not assertions.** The layout sweeps in `test/widgets` are
what fail on a regression. A golden that fails on every intentional change
teaches people to regenerate without looking, which is worse than having no
golden at all — so the two are kept apart deliberately.

The render harness **captures layout faults, reports them by name, and writes
the image anyway.** A render that refuses to exist because the screen inside it
overflows tells you less than a picture of it overflowing.

### What the phone renders reported

```
RENDER NOTE [console-medium-dark]  2 faults at 760x1400
RENDER NOTE [console-phone-dark]   4 faults at 412x915
RENDER NOTE [console-phone-light]  4 faults at 412x915
```

All of them are in `MineLinkDashboardScreen`'s own stat cards
(`Row ← Expanded ← Row ← … ← AnimatedContainer ← Transform`), **not** in the
shell. The console's v2 dashboard is a desktop layout: its existing sweep only
tests widths down to 860, so nothing below that has ever been checked. The
shipping app has the same faults at the same widths — it simply had no
render to show them.

This is Phase 2 work and it is listed as such. It is recorded here rather than
quietly cropped out of the screenshots.

---

## 🚨 What has NOT been done

Stated plainly. None of the following should be read as implied by the table
above.

- **Nothing has been run on a physical Android phone.** The APK identity is set
  up so it installs alongside the real MineLink (`org.minelink.m3`, "MineLink
  M3") and cannot replace it. A **debug APK now builds** (180 MB,
  `build/app/outputs/flutter-apk/app-debug.apk`, 2026-08-20) — but it has not
  been installed on a handset and nothing has been driven on one.
- **Nothing has been run on iOS.** No reachable Apple Developer account, same
  as the shipping app.
- **The app has not been driven against the live database in a browser.** The
  web build compiles and the renders are real, but no screen has been opened
  as a signed-in user in this project. That needs credentials.
- **Phase 2 is under way, not finished.** The console dashboard and fourteen
  portal headers have been reworked and the layout sweeps widened; the rest of
  the ~20, and all of Phase 3's ~80, have not been touched.
- ~~**The layout sweeps have not been extended below 860px.**~~ ✅ **Done
  2026-08-20.** The console sweep now runs 8 widths down to 360px, the portal
  rail sweep down to 360, and the portal sweep up to text scale 2.0 (the
  ceiling the shells actually install). See the commits for what that found.

### ~~20 test files still render under a theme the app never ships~~ ✅ CLOSED

`_host(...)` helpers that build a bare `MaterialApp` with no `theme:` measure
**stock Material's type scale in stock Material's font family**. That was
survivable while every component hard-coded its own `TextStyle`; now that the
components take type from the theme — which is what makes one design system one
system — a themeless host measures text the app will never draw.

Two were fixed where they were directly implicated
(`deactivate_account_card_test`, `portal_nav_rail_sweep_test`) and the console
sweep was moved onto `AppTheme.darkTheme`. **Twenty remain:**

```
test/core/crash_reporter_test.dart              test/features/portal/place_search_test.dart
test/core/utils/dialog_utils_test.dart          test/features/super_admin/company_link_builder_test.dart
test/core/widgets/app_navigation_back_button…   test/widgets/dialog_pops_the_dialog_test.dart
test/core/widgets/lazy_indexed_stack_test.dart  test/widgets/live_truck_marker_test.dart
test/core/widgets/nav_history_recorder_test…    test/widgets/multi_file_drop_picker_test.dart
test/features/account_deactivations_screen…     test/widgets/portal_phase_gate_test.dart
test/features/auth/whatsapp_otp_screen_test…    test/widgets/portal_scaffold_semantics_test.dart
test/features/crash_reports_screen_test.dart    test/widgets/recon_columns_and_cards_test.dart
test/features/fleet/widgets/fleet_vehicle_…     test/widgets/super_admin_dashboard_v2_test.dart
test/widget_test.dart                           test/widgets/targets_screen_test.dart
```

Converting them will surface real failures — that is the point of doing it, and
why it deserves its own pass rather than being buried in an unrelated commit.
Most assert on behaviour rather than geometry, so the risk they hide something
is lower than it was for the sweeps; it is not zero.

---

## Regenerating

```bash
flutter analyze
flutter test
dart tool/release_guards.dart
flutter test test/renders --update-goldens     # rewrite docs/redesign/renders/
flutter build web  --dart-define-from-file=config/supabase.live.json
flutter build apk --debug                      # 180 MB, verified 2026-08-20
flutter build windows --debug                  # blocked — see above
```

---

## Current state — 2026-08-20 (Phase 3)

| | |
|---|---|
| `flutter analyze` | no issues |
| `flutter test` | **1,573 passed**, 1 skipped (a tag-gated capture task) |
| `dart tool/release_guards.dart` | **27/27**, every one selftest-proven to bite |
| `type_scale_codemod.py --selftest` | OK — slot table, editorial rungs, five rewrites, three refusals |
| Renders | 18 files, zero layout faults at any size |
| Screens proving something | **18 / 18** in the untested-screens check; its baseline of excuses is empty |
| Web (dart2js release) | builds |
| Android debug APK | builds |
| Windows | **blocked, pre-existing** — see above |
| iOS | not attempted; no reachable Apple Developer account |

### Guards added during Phase 2

| guard | what it stops |
|---|---|
| `no-hardcoded-month-in-ui` | a month name and a year written into a UI string |
| `no-row-around-a-header-that-has-an-actions-slot` | wrapping a header in a `Row` to put a button beside it |
| `test-renders-under-the-app-theme` | a bare `MaterialApp` in a test |
| `no-off-scale-corner-radius` | a corner radius written as a number |
| `no-half-point-font-size` | a font size belonging to neither scale |
| `text-scale-sweep-reaches-the-ceiling` | a sweep capping below `kMaxEffectiveTextScale` |

### Guard added during Phase 3

| guard | what it stops |
|---|---|
| `typeface-named-by-hand` | a `TextStyle` built from scratch instead of reaching a slot — a ratchet at 128, which can only shrink |

`no-half-point-font-size` was **widened** in the same phase: it matched the
literal `fontSize:` and nothing else, and sixteen half-points were alive behind
a parameter default and a named argument to `MlOv`'s own type helper. It matches
the *name* now — `fontSize`, `fs`, `textSize`, `size`.

### What Phase 3 closed

- **902 hand-built `TextStyle` literals** across 150 files now reach a slot.
  `fontFamily` sites in `lib/` went 497 → 128 and raw `fontSize` ~1,031 → 212;
  the tool reports **zero** convertible sites left. The residue is what it is
  built to refuse — const expressions, non-literal sizes, `CustomPainter` — and
  DESIGN.md §9 carries the per-shape measurement of what that costs.
- **Three editorial rungs** added for the serif at title size, which had no rung
  on the scale at all.
- **A fourth typeface retired** (Sora, seven sites, 292 KB of bundled font) and
  **three sites** that were rendering in the OS's generic monospace rather than
  JetBrains Mono.
- **Five layout defects**, all surfaced by the sweeps rather than by reading:
  a compliance chip, a `DropdownButton`, a dashboard pill, the targets tabs, and
  a targets band 60px taller than the viewport. The last was fixed as a *shape*
  (`TargetsPage`) rather than as an instance.

### Still open, stated plainly

- **128 sites still name a typeface**, held by a ratchet. They are const
  literals (where a theme slot would take `onSurface` and get the ink wrong
  inside a filled subtree), `MlOv`'s ported `s()`/`m()` helpers, and
  `CustomPainter.paint()` which has no `BuildContext`. DESIGN.md §9 measures the
  drift: ±1.4px of line box for 85 of the 96 const sites that state a size, and
  zero for the two that sit inside a parent span.
- **No screen has been hand-rebuilt.** Every screen changed — theme, shell,
  components, shape scale, type scale — and the layout defects found along the
  way are fixed, but the ~20 screens of Phase 2 and the ~80 of Phase 3 have not
  been individually redesigned against the console reference.
- **Seven screens have never been photographed**, not three. The handoff names
  fleet management, the operations hub and the communications hub, which cannot
  be goldened because a realtime channel opened in a constructor leaves a
  pending timer that a golden's `expectLater` outlives. But the four `portal-*`
  renders are **shell only** — the workspace body is a placeholder that says so
  in the picture: *"The dashboards need a live session; a picture of their
  loading state would not be a picture of the design."* So the three portal
  dashboards, the screens that carry the product, have no picture either.
- **Nothing has run on a physical handset**, and nothing has been driven against
  the live database in a browser as a signed-in user.
- **Thirteen `DropdownButton`s have no `isExpanded`.** They pass the sweeps
  today, so this is hardening rather than a live break — but one of them
  overflowed by 31px the moment its label grew by a single point, and changing a
  dropdown's width changes the row it sits in, which is not a change to make
  from a grep.
