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
| Renders at 6 size/theme combinations | generated, `docs/redesign/renders/` |

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
  M3") and cannot replace it, but no APK has been built or installed.
- **Nothing has been run on iOS.** No reachable Apple Developer account, same
  as the shipping app.
- **The app has not been driven against the live database in a browser.** The
  web build compiles and the renders are real, but no screen has been opened
  as a signed-in user in this project. That needs credentials.
- **No screen has been hand-rebuilt.** Every screen *changed*, because every
  screen sits on the theme, the shell and the shared widgets — but Phase 2
  (the ~20 screens that matter) and Phase 3 (the remaining ~80) have not
  started.
- **The layout sweeps have not been extended below 860px.** They are the
  reason the desktop widths are trustworthy and the phone widths are not.

---

## Regenerating

```bash
flutter analyze
flutter test
dart tool/release_guards.dart
flutter test test/renders --update-goldens     # rewrite docs/redesign/renders/
flutter build web  --dart-define-from-file=config/supabase.live.json
flutter build windows --debug
```
