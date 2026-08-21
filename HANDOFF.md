# MineLink M3 — session handoff

**Rewritten 2026-08-22, at the end of the contrast-and-vocabulary session.**
Everything below is verified state, not intention. It replaces the previous
handoff of the same name; the parts of that one still true have been folded in.

**This file lives at**
`C:\Users\Somebody Someone\Music\SHOWME!\MineLink-M3\HANDOFF.md`

The older, machine-wide handoff is at
`C:\Users\Somebody Someone\Claude\HANDOFF.md` — MCP servers, git position,
decoy folders, the phone tooling, dated 2026-08-08. **Background only; this
file governs the redesign work.**

---

## WHERE THIS SESSION STOPPED — READ THIS FIRST

The tree is **clean**, **111 commits**, nothing half-applied and nothing
uncommitted. The tip is
`naming: the four routes the rail and the bar called different things, settled`.

**The original worktree was re-checked against its §0 baseline at the start and
at the end and is untouched** — HEAD `df451d0`, the same three pre-existing
modified files, 14163 files under the `-prune` form, two worktree entries,
nothing modified today.

### What changed about this project this session

The previous handoff's §4.2 said the work left was **1,812 low-contrast
strings**, ranked, "starting with the avatar initials".

**There are now ZERO**, and the ranking was the wrong instrument. The route was
not 1,812 edits — it was measuring what each finding was *painted by* rather
than what it looked like. That collapsed 233 `(ink, ground)` pairs into a
handful of decisions: **six token values were 86% of it**, and one expression —
`textFaint = onSurfaceVariant.withValues(alpha: 0.62)` — was **916 on its own**.

`test/renders/low_contrast_baseline.json` is now `{}`. A missing entry reads as
zero, so it is no longer a ratchet, it is a **floor**: any string under WCAG AA
on any render, in either brightness, fails the suite.

Also this session: **the instrument was wrong in three more ways** and is
fixed; **four routes the rail and the bar named differently** were settled on
Jean's call; and the phone was **paired and driven for the first time** —
see §7 for exactly where that stopped.

---

## 0. Where you are

| | |
|---|---|
| **This project** | `C:\Users\Somebody Someone\Music\SHOWME!\MineLink-M3` |
| What it is | A **complete, independent fork** of MineLink, being redesigned onto Material 3. Its own git repo (`main`), **111 commits**, clean tree. |
| **The original** | `C:\Users\Somebody Someone\Music\SHOWME!\worktree-2026-05-05T11-53-29` — **DO NOT TOUCH IT.** |

### The one rule that must not be broken

**Nothing whatsoever changes inside `worktree-2026-05-05T11-53-29`.** That was
Jean's instruction and it has held for every commit. Its verified baseline,
re-checked at the start and end of every session:

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

⚠️ **The file count depends on which `find` you use, and the difference is not
a new file.** `find . -type f -not -path "./.git/*"` returns **14164** because
in a WORKTREE `.git` is a *file*, not a directory, so that pattern does not
exclude it. The `-prune` form above returns **14163**. Both describe the same
untouched tree.

Every command in this project must run with its working directory inside
`MineLink-M3`. The two trees share no git state.

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
  pre-existing faults (§4.4); web and Android both build.
- **Work long, don't stop to check in.** The HOW TO WORK paragraph in §8.

**`supabase/` is frozen.** No migration is created, applied or pushed here.

---

## 2. Verified state, right now

Every one of these was run at the end of the session:

```
flutter analyze                                 no issues
flutter test                                    2107 passed, 1 skipped
dart tool/release_guards.dart                   39/39 PASS, 0 FAIL
dart tool/release_guards.dart --selftest        all guards bite
py -3 tool/type_scale_codemod.py --selftest     OK
py -3 tool/dropdown_width_check.py              passes
py -3 tool/glyph_coverage_check.py              passes
py -3 tool/one_clock_check.py                   0 sites off Africa/Johannesburg
py -3 tool/unphotographed_screens.py            93 targets, 93 photographed, 0 not
py -3 tool/_sabotage.py                         all sabotages caught
flutter build web --release                     builds
flutter build apk --debug                       builds
docs/redesign/renders/                          220 renders
render harness — CUT OFF                        6 strings, all deliberate
render harness — FAILURE STATE                  0
render harness — RENDER NOTE                    0  (and it FAILS the test)
render harness — LOW CONTRAST                   0  ← was 1,812
```

Layout is swept at **8 widths (1612 → 360px) × 6 text scales (0.85 → 2.0)**,
and again **with real rows in every table** at 360/800/1280 by 1.0/1.3.

---

## 3. What this session did

Full reasoning is in each commit message — six long ones. Read them rather
than trusting this summary.

### 3.1 The instrument was wrong in three more ways

Before acting on 1,812 findings I went looking for the ones that were wrong.
**Fourteen were**, in five distinct classes, and every one was found the same
way: **by cropping the picture at the coordinates the report itself named.**

| class | what it was | how it is caught now |
|---|---|---|
| **clipped away** | a paragraph laid out at y=3000 inside a viewport that shows 400px | intersect with every ancestor's paint clip |
| **covered** | the driver HUD under the hazard sheet's opaque button — the covering label is 98% of the way from the HUD's ground to its ink, so "closer to ink than ground" passes it | the pixel must lie ON the ground→ink line, which is what anti-aliasing IS |
| **behind a modal** | a scrim dims ink and ground TOGETHER, so the chat composer's `Send` — a 10.43:1 pairing — measured 2.53:1 under a dialog | `ModalRoute.of(e).isCurrent` |
| **translucent ink** | the ground exclusion matched the DECLARED colour, so `textFaint` was never excluded from its own ground | composite first, two passes, pass one anchored on the box PERIMETER |
| **a glyph's own halo** | in a tight box over a GRADIENT fill the halo does not have to outnumber the fill, only its most common single shade — a rank badge's box held 11 white, ~20 teal split four ways, 8 halo, and the halo won | same ground→ink line rule |

`test/renders/low_contrast_report_test.dart` is 14 tests, each scene's right
answer known by construction. `tool/_sabotage.py` reverts each fix and watches
the matching test fail.

⚠️ **Two of the five are NOT in the default sabotage set, and the script says
why at each.** `ground` (translucent-ink exclusion) is unreachable with real
fonts — surveyed, the densest glyph coverage this app can produce is 45.7%, and
below 50% the background wins the mode either way; running all 220 renders with
and without it returns byte-identical findings. `halo` **was** load-bearing when
made and became unreachable when the same session deepened the light accent the
badge is filled with. Both are kept because they are correct; neither pretends
to be caught.

### 3.2 Six token values were 86% of it

`tool/attribute_low_contrast.py` composites each candidate token onto each
finding's measured ground and asks which one painted it. That is the step that
turns 233 pairs into decisions:

```
 730  textFaint/dark            onSurfaceVariant × 0.62
 367  MlGlass.dark.inkLo
 186  textFaint/light           onSurfaceVariant × 0.62
 124  MlGlass.light.inkLo
  88  MlChrome.railSectionLabel
  49  MlGlass.dark.inkXlo
----
1544  of 1798
```

**An alpha cannot be the faint rung.** 62% of the muted slate is 3.34–3.54:1 on
every dark surface and 2.85–2.99:1 on every light one, against the 4.5:1 WCAG
asks of text under 24px — and these are 9–13px labels. Solving for the alpha
that WOULD reach 4.5 gives 0.87 dark and 0.83 light, at which point "faint" is
`textMuted` and the token has stopped meaning anything. It is its own colour
now: `#8B99AE` dark, `#5A6678` light.

**Raising the bottom rung does not work either, and that is the interesting
part.** `MlGlass`'s bottom two had been raised once already to "AA for LARGE
text" (3.0) — the wrong bar for an 11px label, in a comment that said so while
setting the value. Reaching 4.5 needs `inkLo` at `#8693AE` and `inkXlo` at
`#8893A9`, two colours nobody can tell apart, sitting under an `inkMid` of
`#8896AE` that is the same colour again. **Below the floor there was room for
one rung and the ladder was asking for three**, so `inkMid` moved up and all
three were respaced. Same on the light side, and on `MlAuth`.

### 3.3 The faults that were about SHAPE, not values

- **One token cannot be both the fill and the ink.** Four sites drew a hue
  tuned for text on PAPER onto a console that is dark for most admins —
  `_TxnRow`, `_Delta`, the platform-users avatar, `_DispatchStatusChip`. All
  take both halves from ONE `MlTone` call now, because two halves fetched
  separately are free to disagree. `MlTokens.green800` and `red700` were left
  with no uses and are **deleted**, so the compiler is the guard.
- **White on a mid-saturation fill does not work, measured.** White reached
  4.5:1 on NONE of the six `avatarRamp` gradients, bottoming out at 1.89:1.
  `MlTokens.inkOnFills` picks by MEASURING both candidates against every stop.
  The avatar block existed twice byte-for-byte and is one `_OrgAvatar` now.
- **The leaderboard's winner card was a window onto its own glow.** Its body
  composited to a flat mid teal on which nothing was legible — white included,
  at 3.81:1. The teal was not the wash: `BoxDecoration` paints its shadow
  BEFORE its fill, so a cyan glow at 60% came through a 6%-alpha card. Lowering
  the wash barely moved it, which is what said the wash was not the term that
  mattered. The card gets `MlOv.accentCardGround` now. **The same fault, in a
  second place**, is the org-insights leader row — and there the first fix
  failed because `Color.alphaBlend` keeps the BACKGROUND's alpha and the
  background was white at 2%.
- **An alpha on an ink, five times.** `textFaint` itself, the pager's disabled
  "Prev", the chat timestamp (`fg` at 75%, and `overlayLight` at 68% in the
  other chat), the company mirror's zero. Quiet is SIZE and WEIGHT; an alpha on
  an ink is a contrast cut wearing a hierarchy costume.
- **The ratchet caught me making one worse.** Deepening `green600` to fix the
  "go" button as a FILL broke `_Delta` as INK on the dark dashboard, reported
  on that very run. That is the whole argument for the ratchet.

### 3.4 What the tests pin

- `test/design/ink_ladder_test.dart` — 38 tests, pure arithmetic. Every rung
  clears 4.5:1 on every ground it lands on (**the ground list comes from the
  REPORT, not the token file**); rungs stay ORDERED and >6% apart; `MlOv`
  equals `MlGlass` rung for rung; every `MlTone` pair reads on its own well,
  composited, in both brightnesses; BOTH `MlChrome` variants — the light rail
  is not the dark rail inverted, and that is how the first pass fixed one and
  left 17 strings in the other.
- The failure message names the measured ratio, the ground, and the
  `contrast_calc.py solve-tint` command that derives a replacement.

### 3.5 Four route names settled (Jean's call, 2026-08-22)

The four of fifteen divergences where the bar was not SHORTER than the rail but
a DIFFERENT word:

```
fleet            bar "Fleet management" -> "Vehicles"
drivers          bar "Driver"           -> "Drivers"
trucks-on-route  bar "Trucks On Route"  -> "Trucks on route"
trip             RAIL "My routes"       -> "Trip"
```

`fleet` goes to the rail's word because the rail's leaf sits inside a group
already called "Fleet" — the old bar title read *Fleet › Fleet*. `trip` goes
the other way because the driver's bottom nav is Dashboard · Trip · Profile, so
the bar already had the word a driver taps. Fifteen routes are now eleven.

⚠️ **I changed `PortalTabItem('Trucks On Route')` too and reverted it.** That
string is a LEGACY tab label: `_legacyTabLabels` maps it onto the canonical
form, and `_portalAliasTabLabel` must return it EXACTLY for the alias route to
select its tab. Renaming it there alone breaks selection **silently** — nothing
throws, the tab just stops highlighting.

### 3.6 New tools, all self-testing

| tool | what it does |
|---|---|
| `tool/rank_low_contrast.py` | groups the report by (ink, ground), by widget, by render |
| `tool/attribute_low_contrast.py` | composites each candidate TOKEN onto each finding's ground and says which one painted it |
| `tool/contrast_calc.py` | composites, and **solves** for the alpha or tint that reaches a target |
| `tool/low_contrast_baseline_update.py` | lowers the baseline, REFUSES to raise it |
| `tool/_sabotage.py` | reverts each instrument fix and watches the right test fail |

---

## 4. What is NOT done — PICK UP HERE

### 4.1 The phone — PAIRED AND DRIVEN, stopped one tap from installed

**This is the first time the phone has ever answered.** Everything below is
verified, not hoped.

- **Pairing had been CLEARED.** The skill and the old handoff both say "this PC
  is already paired, the PIN is not needed again" — **that is stale.**
  `phone_agent.py status` returned *"This phone no longer recognises this PC"*.
  Jean read the PIN off the host-mode screen and
  `py -3 phone_agent.py --pin <PIN> run "status"` paired it in one go.
- Verified up: `SM-G780G at 192.168.88.34  screen 1080x2400  sharing=True
  control=True`.
- The APK is staged as **`C:\PhoneRemote\dist\minelink-m3.apk`** — a SEPARATE
  file, deliberately not `CtrlBridge.apk`. Jean's `CtrlBridge.apk` was verified
  byte-identical to its manifest (SHA-256 `DC98E5…4143`) **after** staging.
- `serve_apk.ps1` is serving; `HEAD http://192.168.88.80:8000/minelink-m3.apk`
  returns 200, length 217272400.
- Driven on the phone: app drawer → search "chrome" → **new tab** (NOT Jean's
  existing tab — he had his own search open and I opened a new one rather than
  navigate his) → typed the URL → Chrome's *"File can't be downloaded
  securely (217,27 MB)"* → **Keep**.
- **Downloads shows `minelink-m3.apk` at 217,27 MB / 217,27 MB — the whole
  file — but with a PAUSE icon, so Chrome has not finalised it.** Tapping the
  filename does nothing; tapping the pause control was the last action and its
  result was not read before the session was paused.

**Where to resume — USE THE NAS SHARE, NOT THE HTTP SERVER.** Jean's
instruction, 2026-08-22: put the APK on the NAS share folder and pull it onto
the phone from there.

```
\\192.168.88.30\Shared\        ← the NAS. Copy the APK here, e.g. into
                                 \\192.168.88.30\Shared\PhoneRemote\ or a
                                 folder of its own, then open it on the phone
                                 through its file manager / the share.
```

This is the better route and it removes three problems at once: no
`serve_apk.ps1`, so **no elevated window and no firewall rule to open or
remove**; no Chrome "can't be downloaded securely" prompt; and no 217 MB
download that Chrome then refuses to finalise, which is exactly where the HTTP
route stalled.

⚠️ **The share was NOT reachable from this session's shell** — both
`\\192.168.88.30\Shared\...` via bash and via PowerShell returned "share not
reachable", which is also why `check_versions.ps1` reported *"PUBLISHED to the
phone: COULD NOT READ the update share"* (the staged CtrlBridge APK itself was
fine: 2.7.1 build 20, SHA-256 verified). So **check the NAS is awake and
mounted before relying on this route**, and if it is not, ask Jean.

Discard the stalled Chrome download on the phone before re-installing, so there
is no half-finalised 217 MB file sitting in his Downloads.

Then Play Protect — Jean has already turned Play Protect OFF, so that prompt
may not appear at all. Then drive the sign-in and the driver flow.

⚠️ **The applicationId is `org.minelink.m3`**, deliberately different from the
shipping app's `com.example.flutter_application_1`, so both install side by
side. Read that twice before concluding which app you are looking at.

⚠️ **AN ELEVATED PowerShell WINDOW IS STILL RUNNING `serve_apk.ps1`.** It
self-elevates, so an unelevated shell cannot stop it — killing the launcher PID
did not stop the server. **Jean must press Ctrl-C in that window**, which also
removes the `CtrlBridge APK download (TCP in)` firewall rule it opened. That
rule was still Enabled when this was written.

**Privacy, as the skill requires:** every screenshot taken was deleted
immediately after being read — verified zero remain. Two showed things I did
not come for (a calendar entry, and Jean's own open Chrome tab); I backed out
of the tab rather than navigating it. The phone was left on `home; waitstable;
home`.

### 4.2 Contrast — CLOSED

1,812 → **0**. `low_contrast_baseline.json` is `{}` and any finding fails.
Sabotaged to prove it: putting `inkLo` back to its old value fails three
renders by name. **If it ever fails, do not add a baseline entry** — the file
can only hold zero, and the failure message names the token to change.

### 4.3 The chat surfaces — INVESTIGATED, decision is Jean's

Jean asked for a report before deciding. It is **not two implementations** —
it is **three thread renderers, two `ChatMessage` models, two data stacks and
two storage buckets**.

| | `MessagesScreen` (985 ln) | `ChatScreen` + `ChatWidget` (1,584 ln) | `chat_dock` `_ThreadView` (6,201 ln) |
|---|---|---|---|
| How you reach it | **No rail entry at all** — two licence-expiry buttons | **One** card tap on Communications hub | Mounted on every portal AND console screen |
| Attachments | ✗ | ✓ bucket `chat_files` | ✓ bucket `chat-attachments` |
| Typing indicator | ✗ | ✓ | ✓ |
| Reply / quote | ✗ | **writes `reply_to_id` and never reads it back** | ✓ full, tap-to-scroll |
| Reactions | ✗ | ✗ | ✓ only here |
| End-chat / blocked banners | ✓ only here | ✗ | ✗ |
| Render coverage | 4 shots | 2 shots | **none** |

Three findings:

1. **The coverage is inverted.** The surface every user actually touches has no
   render and no thread-level test; the one with the fewest features and one
   entry point has six shots.
2. **`ChatScreen`'s reply is broken, not merely duplicated.** It writes
   `reply_to_id` at `chat_screen.dart:131`; its reader at `:61-72` never
   selects the column, so a reply looks sent and shows as an ordinary message.
3. **`MessagesScreen` is 985 lines reachable only when a token is expiring.**
   Its two employee-profile entry points are dead code — guarded on `ChatDock`
   NOT being mounted, and the dock is mounted on both shells.

**Recommendation (not yet accepted): do not merge.** The dock is the real
product and already wins on features. The valuable work is narrower — fix the
invisible-reply bug and give the dock's thread the render coverage it has never
had. Merging 8,700 lines across two data stacks and two buckets is not.

### 4.4 Known limitations, stated rather than hidden

- **Windows is blocked by two pre-existing faults** — the Flutter tool refuses
  the path because of the `!` in `SHOWME!`, and from a clean path CMake fails
  extracting `firebase_cpp_sdk_windows_12.7.0.zip`. Same dependency, same
  version, in the shipping app. Jean said to skip it.
- **Six strings are still cut, on purpose** — three crash-report exception
  messages and three chat message previews.
- **Some fixtures are deliberately EMPTY.** The operations hub's ledgers are
  the documented example. Do not "fix" those by filling them.
- **The map tiles are real in a browser and on a device**, and blank in renders
  — `flutter_test` answers every HTTP request with 400. The tile FILTER is
  asserted structurally instead.
- **The 127 hand-named typefaces** are held by the `typeface-named-by-hand`
  ratchet, which can only shrink. `DESIGN.md` §9 measures each. Not a gap.
- **Eleven route divergences remain**, all the same shape: longer in the rail,
  shorter in the bar. Recorded with both strings in
  `test/core/every_portal_route_is_named_test.dart`.

---

## 5. How to work in this repo

```bash
cd "/c/Users/Somebody Someone/Music/SHOWME!/MineLink-M3"

flutter analyze                                  # must be clean
flutter test                                     # 2107 passing, 1 skipped
dart tool/release_guards.dart                    # 39/39
dart tool/release_guards.dart --selftest         # every guard must BITE
py -3 tool/_sabotage.py                          # every instrument fix must BITE
py -3 tool/type_scale_codemod.py --selftest
py -3 tool/dropdown_width_check.py
py -3 tool/glyph_coverage_check.py
py -3 tool/one_clock_check.py
py -3 tool/unphotographed_screens.py
flutter test test/renders --update-goldens       # after any visual change
flutter build web --release
flutter build apk --debug
```

### Working the contrast report

```bash
flutter test test/renders/redesign_renders_test.dart > out.txt 2>&1   # NEVER | tail
py -3 tool/rank_low_contrast.py out.txt              # by pair / widget / render
py -3 tool/attribute_low_contrast.py out.txt         # by TOKEN — start here
py -3 tool/contrast_calc.py solve-tint '#6B7A9C' '#1C2C46' 4.6
```

### Driving the built app in a browser

```bash
flutter build web --release          # config/supabase.live.json is a bundled
                                     # ASSET, so a plain build reaches live
cd build/web && py -3 -m http.server 8123 --bind 127.0.0.1
"/c/Program Files/Google/Chrome/Application/chrome.exe" \
  --remote-debugging-port=9222 \
  --user-data-dir="<scratch>/ml-m3-chrome" \
  --no-first-run --no-default-browser-check "http://127.0.0.1:8123/"
```

- **Flutter web publishes no accessibility tree until you ask.** Click the
  hidden placeholder — `document.querySelector('flt-semantics-placeholder')
  .click()`. It is the best instrument in the browser.
- **`fill` on two different fields writes both into one.** Flutter web routes
  all text through one hidden input. Click the field, then `type_text` with
  `submitKey: "Tab"`.
- **Chrome will not resize below ~500px.** Use CDP emulation
  (`412x915x1,mobile,touch`). The ~500px band is worth testing in its own
  right — one fault lived only there.

### Driving it on Android

```bash
# adb is at C:\Android\sdk\platform-tools and is ALREADY ON PATH.
# The old handoff said %LOCALAPPDATA%\Android\Sdk — that path does not exist.
adb devices
flutter emulators --launch minelink_test
adb install -r build/app/outputs/flutter-apk/app-debug.apk
adb shell monkey -p org.minelink.m3 -c android.intent.category.LAUNCHER 1
```

`adb shell input text` mangles `!` and turns `%s` into a space. Quote it for
the DEVICE shell — `adb shell "input text 'MineralGuide123!'"`.

### Driving Jean's real phone

**Invoke the `driving-jeans-phone` skill FIRST.** Then §4.1 above for the
current state. `py -3 phone_agent.py --pin <PIN> run "status"` if pairing has
been cleared again.

### Live accounts

`active user accounts.txt` in the repo root. `jean@cyberhouse.co.za` /
`BuRG3rJ3@n1995@#` is the platform admin; `ironhills.owner@mineralguide.com`
and `roadhaul.driver@mineralguide.com` / `MineralGuide123!` are the seeded set.

⚠️ **The console stores theme and accent PER ADMIN.** Switching Jean's mode to
Light writes to his account. Put it back.

### Things that have already gone wrong here — do not repeat them

- 🚨 **A POWER CUT DESTROYED A FILE MID-WRITE.** `low_contrast_report.dart`
  came back as 23,598 NUL bytes — right size, no content, and `git status`
  called it binary. A scratchpad copy is what saved the work. **Commit often;
  copy to the scratchpad before any long edit.**
- 🚨 **A BASH HEREDOC EATS BACKSLASHES EVEN WHEN QUOTED**, and a Python string
  inside one eats them again. It has now broken a patch in FIVE sessions — this
  one wrote a literal `\n` into a Python source line and a literal `\$` into a
  Dart string. **Write any script containing a backslash with the Write tool.**
- 🚨 **NEVER READ A LONG TEST RUN THROUGH `tail`.** Redirect to a file and grep
  the file.
- 🚨 **`git checkout -- <dir>` THREW AWAY UNCOMMITTED WORK.**
- 🚨 **A LONG `&&` CHAIN ENDING IN `git commit -F <heredoc>` TIMES OUT.** Write
  the message to a file and commit with `-F` as its own command.
- 🚨 **Python's stdout is cp1252 here** — printing `−` or `·` from a script
  dies with `UnicodeEncodeError`. Set `PYTHONIOENCODING=utf-8`.
- 🚨 **A CHECK YOU HAVE NOT SABOTAGED IS A CHECK YOU DO NOT HAVE**, and the
  scene must be FAITHFUL. Two of this session's test scenes proved nothing: the
  covered-text one put the two labels at x-ranges that never overlapped, and
  the halo one used a flat fill when the mechanism needs a GRADIENT.
- 🚨 **Check whether a test already pins the behaviour you are about to
  "fix".** `route_title_test.dart` pinned all four route names, deliberately.
- **A `RepaintBoundary` inside a `Scaffold` does not capture a DIALOG** — a
  dialog renders in the Navigator's Overlay, above it. Wrap the whole app.
- **`loadRealFonts()` is not enough** — a `TextStyle` naming no family still
  resolves to the test fallback, whose glyphs are solid one-em boxes. Name the
  family. CLAUDE.md §7 and §10.5.
- **`Color.alphaBlend` keeps the BACKGROUND's alpha.** Blending onto a 2%-white
  surface gives another 2%-alpha colour that looks solid in source.
- **`dart format` on a directory reformats files you did not touch.**
- **`find.text` cannot see a `TextSpan`**, and **`toPlainText()` CANNOT SEE A
  TRUNCATION** — use `RenderParagraph.didExceedMaxLines`.

### Where the reasoning lives

- `docs/redesign/DESIGN.md` — decisions and what each cost.
- `docs/redesign/VERIFICATION.md` — what was executed, and what has not been.
- `docs/design-reference/` — the **pre-redesign** reference PNGs. **Do not
  regenerate them**; they are the before-image.
- `docs/redesign/renders/` — 220 PNGs of the redesign.
- Every commit message carries its own reasoning.

---

## 6. The project's own rules still apply

`CLAUDE.md` in this repo is the fork's copy of the shipping app's:

- **§10.4** — a `Row` hands a non-flex child unbounded width; its commonest
  form is two `Flexible` children (or a `Flexible` and a `Spacer`) splitting a
  row when only one is long.
- **§10.5** — a green test over an empty fixture, an error state, or a fallback
  font proves nothing.
- **§7** — `flutter test` renders in a fallback font unless you load the real
  ones.
- **§7.1** — one clock, Africa/Johannesburg. `MlTime`, never `DateTime.now()`.
- **§10.6** — Dart bitwise operators are unsigned 32-bit on the web.
- **§1** — the package is `flutter_application_1`. Do not rename it. (The
  Android *applicationId* is `org.minelink.m3`; those are different things.)
- **§5** — design tokens are law. `no-raw-color-hex` caught a literal I
  introduced for the winner card's ground, which is why it is a named token.

---

## 7. Exactly where this session stopped

Nothing is in flight in the repo. The tree is clean at
`naming: the four routes the rail and the bar called different things, settled`,
and the whole gate in §2 was run against it, both builds included.

**Two things are mid-flight OUTSIDE the repo:**

1. **The phone.** Paired, screen shared, control live, APK fully downloaded
   (217,27 MB / 217,27 MB) but Chrome has not finalised the download — it shows
   a pause icon. The last action was tapping that control; its result was not
   read. Resume at §4.1.
2. **An elevated `serve_apk.ps1` window is still serving on port 8000** and its
   firewall rule is still open. **Jean must Ctrl-C it.**

**Pick up at §4.1** (finish the install and drive the app on the real handset),
then §4.3 (Jean's decision on the chat surfaces).

---

## 8. COPY-PASTE MESSAGE FOR THE NEXT CHAT

Everything the next session needs is inside this block. Paste it whole.

```
Continue the MineLink Material 3 redesign, exactly where the last session left
off. Read these TWO handoff files before doing anything else, in this order:

1. THE CURRENT HANDOFF — this is the file that governs the work:
   C:\Users\Somebody Someone\Music\SHOWME!\MineLink-M3\HANDOFF.md
   Rewritten 2026-08-22 at the end of the contrast-and-vocabulary session. Read
   it in this order: "WHERE THIS SESSION STOPPED — READ THIS FIRST", then §0
   (where you are + the one rule), §2 (verified state), §3 (what was done and
   why it was invisible before), §7 (exactly where I stopped), §4 (what is NOT
   done — pick up here) and §5 (things that have already gone wrong here).

2. THE OLDER MACHINE-WIDE HANDOFF — background only, do not work from it:
   C:\Users\Somebody Someone\Claude\HANDOFF.md
   Dated 2026-08-08. MCP servers, git position, the decoy folders, the phone
   tooling. The MineLink-M3 one above governs this redesign work.

THE PATHS THAT MATTER

  Work happens here (its own git repo, branch `main`):
    C:\Users\Somebody Someone\Music\SHOWME!\MineLink-M3

  NEVER TOUCHED, for any reason:
    C:\Users\Somebody Someone\Music\SHOWME!\worktree-2026-05-05T11-53-29

THE ONE RULE THAT MUST NOT BREAK: nothing whatsoever changes inside
worktree-2026-05-05T11-53-29. Its verified baseline is in §0 of the MineLink-M3
handoff — check it at the START of the session and again at the END. (HEAD
df451d0, exactly three pre-existing modified files, two worktree entries,
nothing modified today. Note the file-count footnote in §0: 14163 or 14164
depending on which `find` you run, because in a worktree `.git` is a FILE.)

WHERE I LEFT OFF, EXACTLY

The tree is CLEAN. 111 commits. Nothing is half-applied and nothing is
uncommitted. The tip is "naming: the four routes the rail and the bar called
different things, settled", and the whole gate below was run green against it,
both builds included.

TWO THINGS ARE MID-FLIGHT OUTSIDE THE REPO — start here:

  1. THE PHONE IS PAIRED AND DRIVEN FOR THE FIRST TIME, and stopped ONE TAP
     from installed. Jean's SM-G780G at 192.168.88.34, sharing=True
     control=True. The pairing had been CLEARED (the skill's "already paired,
     no PIN needed" is STALE) — Jean read the PIN off the host-mode screen and
     `py -3 phone_agent.py --pin <PIN> run "status"` paired it.

     The APK is staged as C:\PhoneRemote\dist\minelink-m3.apk — a SEPARATE
     file, NOT CtrlBridge.apk (his live build; verified byte-identical to its
     manifest afterwards). serve_apk.ps1 is serving it on
     http://192.168.88.80:8000/minelink-m3.apk (HTTP 200, 217272400 bytes).

     On the phone: Chrome → new tab → the URL → "File can't be downloaded
     securely" → Keep. Downloads now shows minelink-m3.apk at
     217,27 MB / 217,27 MB — the WHOLE file — but with a PAUSE icon, so Chrome
     has not finalised it. Tapping the filename does nothing. The last action
     was tapping that pause control and its result was NOT read.

     RESUME VIA THE NAS SHARE, NOT THE HTTP SERVER — Jean's instruction:
     copy the APK to \\192.168.88.30\Shared\ (e.g. \Shared\PhoneRemote\ or a
     folder of its own) and open it on the phone from there through its file
     manager. That removes three problems at once: no serve_apk.ps1, so no
     elevated window and no firewall rule; no Chrome "can't be downloaded
     securely" prompt; and no 217 MB download for Chrome to refuse to
     finalise, which is exactly where the HTTP route stalled.

     ⚠️ That share was NOT reachable from this session's shell — both bash and
     PowerShell returned "share not reachable", which is also why
     check_versions.ps1 said "PUBLISHED to the phone: COULD NOT READ the
     update share". Check the NAS is awake first; ask Jean if it is not.

     DISCARD the stalled Chrome download on the phone first, so there is no
     half-finalised 217 MB file left in his Downloads. Then install, then sign
     in as roadhaul.driver@mineralguide.com / MineralGuide123! and drive the
     driver flow on real hardware. Play Protect is already OFF so that prompt
     may not appear.

     Invoke the `driving-jeans-phone` skill FIRST. It is his PERSONAL phone:
     prefer sig/changed/waitstable over screenshots, delete any you take, do
     not read what you did not come for, and leave it on `home; waitstable;
     home`. The applicationId is `org.minelink.m3`, deliberately different from
     the shipping app's `com.example.flutter_application_1` — read that twice
     before concluding which app you are looking at.

  2. AN ELEVATED PowerShell WINDOW IS STILL RUNNING serve_apk.ps1 on port 8000,
     and the `CtrlBridge APK download (TCP in)` firewall rule it opened is
     still Enabled. It self-elevates, so an unelevated shell CANNOT stop it —
     killing the launcher PID did not. Ask Jean to press Ctrl-C in that window,
     which stops the server AND removes the rule.

WHAT IS ALREADY DONE — do not redo any of it

  * CONTRAST IS CLOSED: 1,812 low-contrast strings -> ZERO. The route was not
    1,812 edits — it was attributing each finding to the TOKEN that painted it,
    which collapsed 233 (ink, ground) pairs into a handful of decisions. SIX
    token values were 86% of it, and `textFaint = onSurfaceVariant × 0.62` was
    916 on its own. test/renders/low_contrast_baseline.json is now `{}`: a
    missing entry reads as zero, so it is a FLOOR, not a ratchet. If it fails,
    DO NOT add an entry — the failure names the token to change.
  * THE INSTRUMENT WAS WRONG IN FIVE WAYS and is fixed: a paragraph clipped
    away; one COVERED by an opaque widget; one BEHIND A MODAL SCRIM (a 10.43:1
    pairing measures 2.53:1 under a dialog); a TRANSLUCENT ink never excluded
    from its own ground; and a glyph's own ANTI-ALIASED HALO winning the ground
    vote in a tight box over a gradient. 14 unit tests, each scene's answer
    known by construction, plus tool/_sabotage.py which reverts each fix and
    watches the right test fail. TWO of the five are deliberately NOT in the
    default sabotage set and the script says why at each — both are correct and
    currently unreachable, and neither pretends to be caught.
  * FOUR ROUTE NAMES SETTLED on Jean's call: fleet -> "Vehicles", drivers ->
    "Drivers", trucks-on-route -> "Trucks on route", trip -> RAIL becomes
    "Trip". Fifteen divergences are now eleven.
  * THE CHAT SURFACES ARE INVESTIGATED AND REPORTED (§4.3) — it is not two
    implementations, it is THREE thread renderers, two ChatMessage models, two
    data stacks and two buckets. The decision is Jean's and he has NOT given it
    yet. My recommendation is in §4.3: do not merge; fix the invisible-reply
    bug (ChatScreen writes reply_to_id and never reads it back) and give the
    dock's thread the render coverage it has never had.
  * NEW SELF-TESTING TOOLS: rank_low_contrast.py, attribute_low_contrast.py,
    contrast_calc.py, low_contrast_baseline_update.py, _sabotage.py.

WHAT IS LEFT — start here, in this order

  1. FINISH THE PHONE INSTALL and drive the redesign on real hardware (§4.1).
     This is the last thing an emulator and a browser cannot settle: physical
     GPS, the foreground service surviving a real drive, battery, and the real
     panel in the hand.
  2. JEAN'S DECISION ON THE CHAT SURFACES (§4.3), then do whatever he decides.
  3. THE ELEVEN REMAINING ROUTE DIVERGENCES are all the same shape (longer in
     the rail, shorter in the bar) and are recorded, not open.

THE METHOD, unchanged: fixtures, regenerate, LOOK at the PNG, MEASURE it with
PIL rather than squint, fix the SHAPE rather than the instance where the fault
is structural, then pin it with a test and prove the test bites by removing the
fix and watching it fail. When a report and a picture disagree, the picture
wins — cropping at the coordinates the report named is what found five separate
instrument faults this session.

Watch for the faults every batch has had: a screen inside a ShellRoute that
builds its own Scaffold+AppBar; a screen that reads a service directly so no
provider override reaches it; a FIXTURE that says less than the service it
stands in for, or that sets two derived fields independently and prints an
impossibility; an override list that does not reach the screen; a wire enum
value reaching a reader; and a Row handing a non-flex child unbounded width —
including its commonest form by far, two Flexible children (or a Flexible and
a Spacer, which IS an Expanded) splitting a row when only one of them is long.

HOW TO WORK: don't worry about me seeing anything, I'll want to see when
everything is complete and done, so don't stop so much in between — please run
the task for as long as possible so that we can get this completely done and
sorted please. Correct yourself where you make mistakes and fix the mistakes,
and make sure you don't implement anything with gaps in them — make sure it's
full and proper like the original.

OPTIONAL: if the Windows build gives trouble, just carry on with web and
mobile.

BEFORE CLAIMING ANYTHING IS DONE, all of these must be green:

flutter analyze
flutter test
dart tool/release_guards.dart
dart tool/release_guards.dart --selftest
py -3 tool/_sabotage.py
py -3 tool/type_scale_codemod.py --selftest
py -3 tool/dropdown_width_check.py
py -3 tool/glyph_coverage_check.py
py -3 tool/one_clock_check.py
py -3 tool/unphotographed_screens.py
flutter build web --release
flutter build apk --debug

Read §5 of the MineLink-M3 handoff — the things that have already gone wrong in
this repo — so you don't repeat them. The ones that have cost real time more
than once:
  * A POWER CUT DESTROYED A FILE MID-WRITE — it came back as 23,598 NUL bytes,
    right size, no content. A scratchpad copy saved it. Commit often.
  * A bash heredoc eats backslashes even when quoted, and a Python string
    inside one eats them again — it has broken a patch in FIVE sessions now.
    Write such scripts with the Write tool.
  * NEVER read a long test run through `tail`. Redirect to a file and grep it.
  * `git checkout -- <dir>` threw away three finished uncommitted fixes.
  * A long && chain ending in a git commit heredoc times out at two minutes —
    write the message to a file and commit with -F as its own command.
  * Python's stdout is cp1252 here: printing `−` or `·` from a script dies.
    Set PYTHONIOENCODING=utf-8.
  * A check you have not sabotaged is a check you do not have — AND the scene
    must be FAITHFUL. Two of my test scenes proved nothing: one put the two
    labels at x-ranges that never overlapped, the other used a flat fill when
    the mechanism needs a gradient.
  * Check whether a test already pins the behaviour you are about to "fix" —
    route_title_test.dart pinned all four route names, deliberately.
  * adb is at C:\Android\sdk\platform-tools and already on PATH. The old
    handoff's %LOCALAPPDATA%\Android\Sdk path does not exist.

WHEN THE WORK IS DONE: rewrite
C:\Users\Somebody Someone\Music\SHOWME!\MineLink-M3\HANDOFF.md the same way
this one was written — verified state only, nothing aspirational, with a fresh
self-contained copy-paste block in §8 that carries BOTH handoff paths, the
project root, the untouchable worktree path, exactly where you stopped, what is
done, what is left, and this same HOW TO WORK paragraph — and commit it.
```
