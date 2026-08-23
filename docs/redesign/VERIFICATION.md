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

- ~~**Nothing has been run on a physical Android phone.**~~ **SUPERSEDED
  2026-08-22 — see the last section of this file.** It has now been installed
  on Jean's SM-G780G and driven as a real driver, and it found three defects.
  The APK identity is still as described: it installs alongside the real
  MineLink (`org.minelink.m3`, "MineLink M3") and cannot replace it.
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
| `flutter test` | **1,580 passed**, 1 skipped (a tag-gated capture task) |
| `dart tool/release_guards.dart` | **27/27**, every one selftest-proven to bite |
| `type_scale_codemod.py --selftest` | OK — slot table, editorial rungs, five rewrites, three refusals |
| `glyph_coverage_check.py` | passes — every character a UI string uses is in a shipped face |
| Renders | **25 files**, zero layout faults at any size |
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
- **Seven screens that had no picture now have one** — and it was never a
  Supabase transport fake. Three notifiers (`FleetNotifier`,
  `OperationsNotifier`, `CommunicationsNotifier`) loaded and opened realtime
  channels **from their constructors**, so none of them could be *constructed*
  without a network. `start()` is the seam; the providers call it immediately,
  so the running app is unchanged. It is not only a test problem: a notifier
  that dials out from its constructor cannot be used by anything wanting a
  snapshot without a subscription.

  The dashboards needed no seam at all — `test/fixtures/portal_capture_
  fixtures.dart` already overrode every portal data provider and was only ever
  wired into the design-*reference* capture. Pointing the redesign renders at
  the same fixtures was the whole change.
- **Four fixture gaps, each invisible until something was photographed.**
  `kFleetStatus` had existed all along and was never registered, so the
  transporter dashboard rendered with four panels of apology.
  `fleetMaintenanceProvider` had no fixture, so the third fleet state (in
  maintenance) had never been drawn. `vehicleDriversProvider` had none, so the
  driver's hero screen photographed as *"Couldn't load your trip"*. And the two
  fixture files described **two different fleets** — `FIXTURE-vehicle-1` was a
  Scania on `CK 84 RT GP` in one while `veh-1` was a Freightliner on the same
  plate in the other — so a screen reading the fleet from one and its trips from
  the other resolved nothing. One namespace now.
- **A character no shipped font can draw.** Two driver lifecycle buttons read
  *"Arrived at loading ✓"* and a chat receipt read *"09:20 ✓✓"*. U+2713 is in
  none of the three faces; on a handset the platform's fallback chain supplies
  it, so it was right wherever anyone had looked and came out as tofu the first
  time it was rendered elsewhere. Both are icons now, and
  `tool/glyph_coverage_check.py` reads the `cmap` out of each TTF and holds the
  line. Emoji are exempt by the Emoji_Presentation property — deliberately not
  "the Dingbats block", because ✓ lives in Dingbats and is the character this
  exists for.

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
- ~~**Seven screens have never been photographed**~~ — **closed.** All seven
  have pictures now: fleet management, the operations hub, the communications
  hub, the three role dashboards and the driver's Trip screen. See "What Phase 3
  closed", below. The four `portal-*` shell renders keep their placeholder on
  purpose: that group is about the rail and the reflow per role, and the
  workspace now has a group of its own.
- **Nothing has run on a physical handset**, and nothing has been driven against
  the live database in a browser as a signed-in user.
- **Thirteen `DropdownButton`s have no `isExpanded`.** They pass the sweeps
  today, so this is hardening rather than a live break — but one of them
  overflowed by 31px the moment its label grew by a single point, and changing a
  dropdown's width changes the row it sits in, which is not a change to make
  from a grep.

---

## Current state — 2026-08-20 (Phase 4)

Every line below was executed at the end of the Phase 4 session, in this order.

| | |
|---|---|
| `flutter analyze` | no issues |
| `flutter test` | **1,692 passed**, 1 skipped (a tag-gated capture task) |
| `dart tool/release_guards.dart` | **28/28 PASS, 0 FAIL** |
| `dart tool/release_guards.dart --selftest` | all guards bite |
| `type_scale_codemod.py --selftest` | OK |
| `dropdown_width_check.py` | passes |
| `glyph_coverage_check.py` | passes |
| Renders | **58 files, 22 of them phone-width**, zero layout faults reported at any of them |
| Web (dart2js release) | builds |
| Android debug APK | builds |
| Windows | **blocked, pre-existing** — see above |
| iOS | not attempted; no reachable Apple Developer account |
| Original worktree | `df451d0`, 14163 files, the same 3 pre-existing modified files — **untouched**, verified at the start and the end |

### The guard added during Phase 4

| guard | what it stops |
|---|---|
| `driver-eta-is-not-the-device-clock` | `DateTime.now().add(` in the driver's navigation screen — an arrival hour read off the device's zone rather than South Africa's. A unit test cannot catch it: on a machine already running SAST both expressions are identical. |

### What is newly PROVEN, and by what

- **A wide table's scrollbar is actually painted.** `wide_table_scrollbar_test.dart`
  drives the real capture schedule over a table whose rows arrive from a future
  and counts thumb pixels in the captured image. The two tests that existed
  before asserted the structure and the colour, and both passed for a whole
  session while the renders showed a truncated table with no bar on it.
- **A count-up figure is settled before the picture is taken.**
  `render_settle_test.dart`. The schedule had been 50ms short, and the
  supervisor's stockpiles photographed as 128.254 / 17.98 / 412.131 against
  fixture values of 128.4 / 18.0 / 412.6.
- **No bottom-nav label is clipped or collides**, in every (org type, role) tree
  the product can build, at 360 and 412 by 1.0 and 1.3.
  `bottom_nav_labels_test.dart` enumerates the trees from
  `UserRole.getRolesForOrgType` rather than listing them, so a role added later
  is covered without anyone remembering.
- **No recon header breaks inside a word**, checked AT the table's own declared
  minimum width rather than at some width that happens to be wider.
- **No margin figure is ellipsised**, at 900 / 1280 / 1600.
- **The two halves of a Reconciliations screen agree about the sign of a
  variance.**
- **The insights board's On-time row is the measured on-time rate**, and a
  company with nothing judgeable renders a dash.
- **Money is prefixed and grouped one way**, on both dashboards.
- **22 portal screens and 4 console screens survive 360/800/1280 × 1.0/1.3 WITH
  REAL ROWS IN THEM** — not the empty states the sweeps had been passing over.
- **No console table compresses on a phone.** The organizations registry
  (`organizations_registry_test.dart`) and both targets tables
  (`targets_phone_width_test.dart`) are checked at 360 and 412 for zero
  overflows and un-truncated key columns, and at 1600 for **no scrollbar** —
  because a scrollbar over content that fits is a promise of more.
- **The targets board still says which board it is** at 360 and 412. Its title
  was being cut to "Plat…" by two unflexed scope tags.
- **Both bite.** Restoring the `Row` cut the title again; neutering the two
  derived `minWidth`s failed four of the seven targets cases. A sabotage that
  does not restore the original expression verbatim proves nothing — deleting
  the `Wrap` left the title unflexed, which stopped it ellipsising and started
  it overflowing, and the assertion under test passed on a different fault.

### What is still NOT proven

Unchanged from Phase 3 except where noted:

- ~~**Nothing has run on real hardware.**~~ **NO LONGER TRUE — see the
  2026-08-22 section at the end of this file.** The debug APK was installed on
  Jean's SM-G780G from the NAS share and driven signed in as the real driver
  account. iOS is still not attempted (no reachable Apple Developer account).
- **The map tiles are blank in every render.** `flutter_test` answers every HTTP
  request with a 400, so the canvas under the route line is the empty-tile
  colour. Everything drawn on top of it is real.
- **The due-diligence gate has never been photographed or driven** — preview,
  confirm, the green tick, the transporter list, the final confirm. `shoot()`
  can interact now (`act:`), so the mechanism exists; the sequence does not.
- **`flutter build web --release` and `flutter build apk --debug` were last run
  at commit `ed9ebcd`.** Everything since is layout and test work under
  `lib/features/super_admin/**` and `test/**` with no new dependency, plugin or
  platform code — but neither has been re-run, and "cannot plausibly have
  broken" is not evidence.
- **The targets org-type and company scopes have no picture.** Only the platform
  scope has been rendered. The other two carry a selector it does not, and
  `TargetsPage`'s half-viewport cap exists *because* the org-type band once
  overflowed by 60px.
- **Windows** — two pre-existing faults, neither this project's.

---

## Current state — 2026-08-22 (the chat session, and the first hardware drive)

Every line below was executed at the end of the session, in this order.

| | |
|---|---|
| `flutter analyze` | no issues |
| `flutter test` | **2,149 passed**, 1 skipped |
| `dart tool/release_guards.dart` | **39/39 PASS, 0 FAIL** |
| `dart tool/release_guards.dart --selftest` | all guards bite |
| `py -3 tool/_sabotage.py` | all sabotages caught |
| `type_scale_codemod.py --selftest` | OK |
| `dropdown_width_check.py` | passes |
| `glyph_coverage_check.py` | passes |
| `one_clock_check.py` | 0 sites off Africa/Johannesburg |
| `unphotographed_screens.py` | 93 targets · 93 photographed · 0 not |
| Renders | **225 files** (220 + 5 net new; 7 dock shots added) |
| render harness — LOW CONTRAST | **0** |
| render harness — FAILURE STATE | 0 |
| render harness — RENDER NOTE | 0 |
| render harness — CUT OFF | **9** (was 6; the 3 new are one deliberate conversation-row preview, per list render) |
| Web (dart2js release) | builds |
| Android debug APK | builds |
| **Android, ON A REAL HANDSET** | **installed and driven** — see below |
| Windows | blocked, pre-existing |
| iOS | not attempted; no reachable Apple Developer account |
| Original worktree | `df451d0`, 14163 files, the same 3 pre-existing modified files, 2 worktree entries, 0 modified today — **untouched**, verified at the start AND the end |

### THE FIRST HARDWARE DRIVE — what it proved, and what it found

The APK was staged to `\192.168.88.30\Shared\PhoneRemote\minelink-m3.apk` and
installed on Jean's **SM-G780G** through My Files' own network-storage mount —
not over HTTP, which is where the previous session stalled. Signed in as
`roadhaul.driver@mineralguide.com` against the live database.

**Rendered correctly on real hardware:** the auth screen (Fraunces italic
accent, gradient Sign in), the account-setup gate, the driver Dashboard with
live figures (3 loads this week · 102.1 t · 5 deliveries · 171.32 t total), the
Trip tab's empty state, and Recent Trips with four real completed trips, POD
icons and status chips.

**Three defects it found that nothing else could:**

1. **A driver had no chat at all.** `PortalShellLayout` wraps every role's
   shell in a `ChatDock` at the end of its build; the driver's shell is
   returned from an early branch ~300 lines above that. No dock, no rail entry,
   and `DriverAppScreen` has no messages affordance of its own.
2. **The first fix was half a fix** — there are TWO driver branches, and
   `/home` is the wrong one. `portalLandingRoute` sends a driver to
   `/portal/driver/home` on sign-in, so `/home` is one frame. Rebuilding and
   reinstalling is what revealed it; the test written for the bug had read the
   branch that was already fixed and passed.
3. **The dock's empty state named a tab that does not exist** — "Open the
   People tab" on a surface whose tabs are Conversations | Contacts. Copied
   verbatim from `MessagesScreen`, whose tabs really are Chats | People.

**Note what class these are.** §4.1 predicted hardware would settle GPS,
foreground-service survival and battery. It settled none of those; it found a
missing feature, an incomplete fix and a wrong string — all of which had passed
`flutter analyze`, 2,145 tests, 261 renders and 39 release guards.

**Privacy:** every screenshot taken was read and deleted immediately; zero
remain. Two showed things not come for (Jean's WhatsApp media in My Files'
Recent, and a CtrlBridge pairing PIN) and neither was used or recorded. The
phone was left on `home; waitstable; home`.

### What is newly PROVEN

- **The reply feature works end to end.** `chat_message_row_test.dart` proves
  the column survives Postgres → model (and nulls each column in turn to prove
  each is genuinely read); `chat_reply_quote_test.dart` proves the model
  reaches the screen, over text and over an attachment, with a dangling parent
  and with a mention token; the chat-thread renders show it drawn on both
  bubble grounds.
- **All eighteen chat palettes are legible**, as arithmetic rather than as a
  picture — `chat_palette_contrast_test.dart`. Thirteen were not. A render can
  only ever photograph the one palette that happens to be selected.
- **The dock has renders at all** — seven, including the thread, which had
  never been photographed despite being mounted on every portal and console
  screen.

### What is STILL not proven

- **Physical GPS on a real road trip**, the Android foreground service
  surviving a long backgrounding, and battery behaviour. The handset drive did
  not cover these: the driver account has no active trip, so the live-location
  toggle is disabled by design ("Available once you have an active trip").
- **iOS**, unchanged.
- **The due-diligence gate** has still never been driven end to end.
- **A second party in a live chat.** The dock was opened on the handset and its
  empty state read; no message was sent between two real accounts.

---

## Current state — 2026-08-22 (the driving session, and a production incident)

Every line below was executed at the end of the session, against the tree as
it stands.

| | |
|---|---|
| `flutter analyze` | no issues |
| `flutter test` | **2,435 passed**, 1 skipped |
| `dart tool/release_guards.dart` | 40/40 PASS, 0 FAIL |
| `dart tool/release_guards.dart --selftest` | all guards bite |
| `py -3 tool/_sabotage.py` | ALL SABOTAGES CAUGHT |
| `type_scale_codemod.py --selftest` | OK |
| `dropdown_width_check.py` | passes |
| `glyph_coverage_check.py` | passes |
| `one_clock_check.py` | 0 sites off Africa/Johannesburg |
| `unphotographed_screens.py` | **94** targets · 94 photographed · 0 not |
| Renders | **227 files** (2 new — the not-found screen) |
| render harness — CUT OFF | 5 renders / 9 strings, unchanged |
| render harness — LOW CONTRAST | 0 (app screens) |
| render harness — FAILURE STATE / RENDER NOTE | 0 / 0 |
| Web (dart2js release) | builds |
| Android debug APK | builds, **and was installed on the SM-G780G three times** |
| `tool/health_probe.py` | **7/7 services answering** |
| Original worktree | `df451d0`, 14163 files, same 3 pre-existing modified files, 2 worktree entries, 0 modified today — untouched |

### Nine defects, every one found by DRIVING rather than by a test

Nothing in this list came from the suite. Seven came from opening screens in
a browser against live data, and two came from a handset.

1. **disputes** — header read "1 dispute" over "No open disputes"
2. **crash reporter** — could fill the database it reports into (below)
3. **shells** — re-keyed by route, remounting on every navigation
4. **mine stockpile tile** — 60 t lost between a figure and its own caption
5. **mine production** — "pit-to-port loss −771 t", in green, with 0 mined
6. **not-found page** — was go_router's default, printing `GoException`
7. **fleet management** — every truck in the wrong bucket, exactly inverted
8. **shell** — the workspace cross-faded against itself (handset)
9. — and the two follow-ups to 3 that only the handset could see

### 🚨 The production incident

`crash_reports` held **204,539 rows / 293 MB**, and the main project had gone
from 24 MB to **319 MB — 64% of the 500 MB free plan**. Three browser tabs
left signed in overnight by the previous session's own multi-account
technique hit a CanvasKit `Aborted()` during paint and re-threw it every
frame for four hours; peak **60,680 rows in one hour**.

Fixed at the source (a send budget: 20 rows/minute, 500/session, suppressed
occurrences carried out as `(+N not sent)`), the leftover browsers were
closed, and the table was reduced to 5,808 rows — every row outside the burst
kept in full, plus up to three examples of each of the 875 distinct failures
inside it. **319 MB → 40 MB.** Both projects then probed healthy.

### What the HANDSET proved that nothing else could

The Duplicate GlobalKey fault took three passes, and each pass looked
finished until the APK went back on the phone:

| build | navigations | reports |
|---|---|---|
| before any fix | — | 32 already recorded |
| after the recorder key removal | startup | 1, naming a now-unkeyed recorder |
| after keying the switcher on the route | 7 | **7** |
| after removing the cross-fade | 6 | **0** |

A widget test cannot see the last one: under the test binding `MlMotion`
collapses to about a millisecond, so the two-subtree overlap is gone before
the next pump. The handset is the instrument, and the test file says so
rather than implying coverage it does not have.

### Still not proven

- **Physical GPS on a real road trip**, the Android foreground service
  surviving a long backgrounding, and battery over a trip. Unchanged.
- **iOS**, unchanged — no reachable Apple Developer account.
- **Windows**, unchanged — two pre-existing faults, neither this project's.

---

## Current state — 2026-08-22 (late) — the Android role sweep

Continues the session above. The browser tooling dropped, the Android emulator
replaced it, and Jean's handset was used for hardware proof.

| | |
|---|---|
| `flutter analyze` | no issues |
| `flutter test` | **2,440 passed**, 1 skipped |
| `dart tool/release_guards.dart` | **41/41** PASS, 0 FAIL |
| `py -3 tool/one_clock_check.py` | 0 sites, exit 0 — **5 patterns now, was 3** |
| `py -3 tool/health_probe.py` | 7/7 services answering |
| Renders | 227 |
| APK on the SM-G780G | **installed (1ffa3d2), NOT yet driven** |
| Original worktree | `df451d0`, 14163 files, 3 pre-existing modified, 2 entries, 0 today |

### Four more defects, all found by driving Android

10. **The driver's week chart drew 33.7 t on a Sunday that had not happened.**
    `byDay[t.updatedAt.weekday - 1]` read the UTC weekday while `inWeek` on the
    lines either side correctly used `MlTime.sast`. The week TOTAL was right to
    the kilogram, so only the distribution was wrong.
11. **Every "Sign out" button opened a dialog saying "Logout"** — ten call
    sites, plus two more dialogs titled "Confirm Logout".
12. **"Departed Today" on the security gate asked the DEVICE what day it is** —
    the mirror image of 10, and invisible on the emulator because it is set to
    Africa/Johannesburg.
13. **`employee_profile_screen`'s "since {Month}"** read a raw instant's month.

### The instruments grew

- `one_clock_check.py`: 3 patterns → 5. It passed this tree cleanly while four
  real §7.1 faults were live. New: a calendar field off a receiver ending in
  `At`, and a `DateTime.now()` local whose date parts are read.
- `release_guards.dart`: 40 → 41, adding `one-vocabulary-for-signing-out`.

### What is NOT proven

- **The build on the handset has not been driven.** Three checks are queued —
  the sign-out copy, no new Duplicate GlobalKey rows, and (on the emulator) the
  driver week chart.
- **Four roles have never been driven at screen level**: Load Controller,
  Supervisor/Foreman, company & employee management, and the buyer/mine quality
  and value tabs.
- Physical GPS, iOS and Windows — all unchanged.

---

## Current state — 2026-08-23 — the last un-driven roles, and a blind instrument

Continues the session above. It began by finishing that session's interrupted
hardware checks, then drove the four roles the sweep had never reached — Load
Controller, Supervisor/Foreman, employee management, and the buyer/mine value
and quality tabs — by walking one real load through the entire mine floor.

| | |
|---|---|
| `flutter analyze` | no issues |
| `flutter test` | **2,478 passed**, 1 skipped |
| `dart tool/release_guards.dart` | **42/42** PASS, 0 FAIL — `no-skeleton-dateformat` is new |
| `dart tool/release_guards.dart --selftest` | every guard bites |
| `py -3 tool/_sabotage.py` | ALL SABOTAGES CAUGHT |
| `py -3 tool/one_clock_check.py` | 0 sites, exit 0 — **6 patterns now, was 5** |
| `py -3 tool/unphotographed_screens.py` | 94 targets, 94 photographed, 0 not |
| `py -3 tool/health_probe.py` | 7/7 services answering |
| Renders | 227 |
| Crash reports raised all session | **0**, across the handset, the emulator and six browser accounts |
| APK on the SM-G780G | `963ca7e` **RAN AND WAS DRIVEN**; `2b235c4` staged, not installed |
| Original worktree | `df451d0`, 14163 files, 3 pre-existing modified, 2 entries, 0 today |

### The interrupted hardware checks, finished

- **The sign-out dialog copy** — read on the SM-G780G: "Sign out" / "Are you
  sure you want to sign out?" / [Cancel] [Sign out]. Cancel was tapped; the
  phone was left signed in as the platform admin, as it was found.
- **No new `Duplicate GlobalKey` rows** — baseline taken, **12** navigations
  driven on the handset, **0** new rows. The build before the fix produced
  7 in 7. Confirmed the pipe was live by the 7 rows it wrote at 20:48–20:50 the
  night before, from the same handset.
- **The driver's week chart** — verified on the emulator (it needs the driver
  account, and the handset was to stay signed in as the admin). The 33.7 t that
  used to sit on a Sunday that had not happened is on Monday, and Sunday is
  flat.

### One real load, driven end to end

Transporter accepts a dispatched route → truck and driver assigned → driver
starts → security checks in → **weighbridge** → gate check-out. Trip
`0d9c6792`, truck S6W001GP.

The arithmetic closes at every step: tare 15.40 t, gross 49.60 t, the sheet
computed `Net minerals loaded 34.20 t` live, `Tons loaded (auto) 34.20` agreed
in the wayslip block below it, and `trips.net_tons` came back 34.2. The stat
card moved to `33.025 t Avg Tons / Load` — exactly (34.2 + 33.7 + 30 + 34.2)/4.
Four seals were demanded, numbered and photographed, matching
`fleet_vehicles.seal_points = 4`; waybill `TRP-6C72DDAC41` was minted
server-side with origin, destination, the gross-scale photo and the
controller's stored signature.

### Thirteen defects, all found by looking

1. **A wall clock converted twice** — six sites in the recon table including
   its Excel/CSV/PDF export of the billing record, two in the chat dock, three
   console "last active" readouts and the mine's Recent-waybills card. A no-op
   in South Africa, +2 h on UTC, +6 h in New York. **The fixture had the same
   error mirrored, so the two cancelled** and the rendered time was right in
   every test and wrong in production for anyone outside SAST.
2. **The live map's ETA came off the reader's device** — a §7.1 violation on
   the screen whose whole subject is when a truck arrives.
3. **An eighth date dialect on three console screens** — `Aug 22, 2026 8:50 PM`
   against the product's `22 Aug 2026 · 20:50`.
4. **Two lists printed a bare time for rows spanning days** — the load
   controller's Recent Loads read `10:10, 04:51, 13:39` sorted newest first,
   and the third was six days old.
5. **The mine's production table contradicted its own header** — eight amber
   negatives under a `— Pit-to-port loss`.
6. **The quality screen printed delivered tonnage under "Payable"** — one row
   showing a payable ABOVE the mine net, which the definition forbids.
7. **`R0.00 Invoice variance` in green with nothing invoiced.**
8. **The employee register counted a different set from the screen next door**
   — "7 of 7 stockpiles" beside "9 stockpiles".
9. **The transporter was told "Seals — Not required"** on a route the
   weighbridge refuses without four numbered, photographed seals. Two columns,
   `transportation_requests.seal_required` false and `routes.seal_required`
   true, and the sheet read the one the load is NOT judged by.
10. **A distance chip that sometimes said what it measured** — `640 km · 620 ·
    640 · 640 km · 520 km · 120 · 120` in one column.
11. **Two "this week" tonnages on the driver's screen** — 170.5 t loaded and
    136.3 t delivered, one scroll apart, only one label saying which.
12. **The driver's hero card overflowed by 44 px** at 360 px × text scale 1.3.
13. **`12:35` rendered as `12:3` over `5`** on the recon table — found ON THE
    HANDSET, whose system font size is raised. The table's minimum width was
    measured at text scale 1.0 and then left fixed under a type size the reader
    controls: 0 wrapped cells at 1.0, **16** at 1.3 and 16 at 2.0. A wrapped
    cell is a cell that FITS, so nothing else could have seen it.

### The instruments grew, and one was blind

- **`portal_overflow_sweep_test.dart` was laying out EMPTY screens.** It
  overrode `mirrorCompanyIdProvider` and nothing else, so every provider
  resolved to an empty list: 27 screens × 3 widths × 5 scales × bold, of empty
  states. Empty states are short and short things do not overflow (§10.5). It
  runs on the real capture fixtures now, and turning the data on surfaced FOUR
  more overflows on screens it had always covered and always passed — the load
  controller's identity row (22 px) and its whole wide branch, and the buyer
  reconciliation card's header (21 px) and its two buttons (32 px).
- **`one_clock_check.py`: 5 patterns → 6.** The new one catches a
  `DateTime.now()` that never has a calendar field read off it because it goes
  straight into a formatter — which is exactly how the live map's ETA survived
  five patterns.
- **`release_guards.dart`: 41 → 42**, adding `no-skeleton-dateformat`. The
  existing `one-vocabulary-for-a-timestamp` reads the literal inside
  `DateFormat('…')`, and `DateFormat.yMMMd().add_jm()` has no literal to read,
  so it reported green over three live violations. The new guard **failed on
  the real tree** before the fix rather than only on a planted line.
- **`MlTime.sast` now asserts it was handed a genuine instant.** Every real
  instant here arrives UTC-flagged from Postgres, so `isUtc` is a sound test
  for "this is not somebody's wall clock". It fires in debug, in every test and
  in every render, and it is what found defect 1 at all. The `calendar*` family
  is complete: `calendarDay`, `calendarStamp`, `calendarClock`,
  `calendarListDay`, `calendarAgo`, `calendarAgoTag`.

### What is NOT proven

- **The handset ran `963ca7e` and was driven on it** — the build, the timestamp
  vocabulary, the recon figures, and the defect above. **It has not run
  `2b235c4`**, which carries that defect's fix; the APK (`6BCAE044…`) is staged
  on the NAS. The phone's screen slept again and only Jean can wake it; the
  session asked twice, per the rule, and finished everything else.
- **The POD leg of trip `0d9c6792` was not driven** — it is `en_route_to_offload`,
  a normal state shared with two older trips.
- Physical GPS on a road, iOS and Windows — all unchanged.

## Current state — 2026-08-23 (second session) — the handset runs `2b235c4`, and the POD leg is driven

Worked from `M3-TASKS.md`, the markable list; every tick there carries its own
evidence line and this section only records what was executed.

### The handset

- **APK `2b235c4` (`6BCAE044…`) is on the SM-G780G.** Installed over the NAS
  route (My Files → Network storage → jean → Shared → PhoneRemote), hashes
  matched on both ends before the tap, "Update" → the app opened straight
  into the Global Admin Dashboard. No Play Protect prompt this time.
- **`12:35` reads on ONE line** on `/super-admin/recon-tables` at Jean's
  raised font size — the `20 Jul 2026` row, the one the handset itself found
  broken on `963ca7e`. Every other TIME-IN on the table is one line too.
- The driver's hero card (`roadhaul.driver`) rendered `CURRENT TRIP` with a
  `NO ACTIVE TRIP` pill and no overflow stripe — but that is the SHORT pill,
  because the POD below had just closed the driver's only active trip. The
  long-pill case is still owed and will be re-checked the moment a new trip
  reaches this driver.
- The Load Controller (`ironhills.controller`) had no truck on site to draw a
  truck row for; the Recent Loads table rendered cleanly. **Found on glass:**
  the portal app-bar title wraps MID-WORD at the raised text size — `Load co`
  over `ntroller` — between the hamburger and four action icons. Open, to be
  fixed in this session.

### The POD leg of trip `0d9c6792`, driven

As `roadhaul.driver`, in a headless Chrome driven over CDP (no mouse):

1. `Arrived at offloading` → `mark_trip_arrived_at_offload` stamped
   `metadata.arrived_at_offload_at = 2026-08-23T01:40:40Z`; status stays
   `en_route_to_offload`, which is the designed behaviour (the POD is what
   writes `offloaded`).
2. `Upload POD` → the signature prompt was skipped because the driver already
   has one → the Proof-of-delivery dialog, pre-filled with the mine net
   `34.20`, changed to `33.9`; the photo attached through
   `Page.setInterceptFileChooserDialog` + `DOM.setFileInputFiles`.
3. `Submit POD` → `record_pod`: `trips.status = completed`,
   `delivered_tons = 33.9`, `variance_tons = 0.3`,
   `offloaded_at = completed_at = 2026-08-23 01:43:47Z`, one `pod_uploads`
   row, and a 9,329-byte object in the private `pod_photos` bucket.
4. The driver's own screen: Delivered 6 → 7, "No active trip", Recent Trips
   `23 Aug 2026 · 03:43 · COMPLETED` with a POD icon.
5. Side B as `ironhills.owner`: `S6W001GP · 34.20 t · 33.90 t · 0.30 t`,
   POD icon, Dispute action.

**The buyer half does not apply to this trip.** Its request `4a0403a8` was
raised by the mine with `buyer_company_id = NULL`, so transaction
`TRP-6C72DDAC41` has no buyer — no buyer can see it, and that is the data, not
a defect. The buyer's Loads & value was opened as `atlasbuyer.owner` anyway
and carries the latest buyer-linked POD (`927cbf1b`, delivered 34.05 t,
R32,347.50).

### A rig lesson, so nobody chases it as an app defect

A CDP Chrome launched with `--window-position=2000,2000` to keep it off Jean's
desktop reports `document.visibilityState = "hidden"` and **0 rAF/s**. Flutter
web renders on `requestAnimationFrame`, so nothing paints, and every screen
looks like an endless spinner while its network requests complete normally.
Measured before any app code was suspected. `--headless=new` (same profile,
so the session survives) renders at 39 rAF/s and the Trip tab appeared in
8 s.

### The request → approve → link → dispatch chain, driven from the four forms

Every field typed through the real forms over CDP, against live data, with
the phone asleep and then awake beside it:

- **Mine → Request transportation** (Ongoing, seals, 24 h, R 680 / ton) →
  `18800451`. **Mine → Request buyers** (FOB, R 2350, the map picker —
  `place_index` answered "Steelpoort" with six results and the field saved a
  `?q=lat,lng` link — three lab PDFs added two-together then one-by-one, a
  photo) → `5dc2579d`, four objects in `request_docs`. **Buyer → Request
  transportation** (Single request, operating hours 05:30–18:00 set in the
  time pickers, 27 Aug → 30 Sep in the date pickers) → `d40a9d3e`. **Buyer →
  Request products** → `34eba1e9`.
- **The revision loop** on `18800451`: sent back with a note → the mine saw
  `NEEDS YOUR ACTION · SENT BACK`, the note, `Edit & resubmit`, the pre-filled
  form with its `Returned for changes` banner → edited → `resubmitted` →
  approved.
- **All four inboxes** rendered the submissions read-only; the product inbox
  carries the `0 · Complete the order` step an enquiry needs.
- **Linking twice** through the five-step gate exactly as §4 specifies, with
  the preview naming every field and the transporter's price only. Server
  side per dispatch: a `routes` row (seals and operating hours carried), a
  `margin_ledger` row, a `request_dispatches` row at the transporter price, a
  capped `stockpiles` row at 0, and the three notification kinds — mine
  `New stockpile to prepare`, transporter `New order assigned`, buyer `Order
  accepted & dispatched` (the buyerless order correctly raised no buyer
  notice).
- **Transporter accept + allocation**: the route sheet shows `R 620.00` and
  nothing of the margin; `Accept 1 truck` → `accepted`, trip `b9189cd5`
  scheduled on S6W001GP; a second driver added to KVK007MP through
  `DriverAssignmentDialog`, which fired the order-aware notification to him.
- The driver then **started the route on the handset**, security checked the
  truck in on the web, and the controller's phone showed the on-site truck
  card — which is how Phase 1(b) and 1(c) got their long-pill and truck-row
  evidence.

### Three defects, found by driving that chain

1. **The second driver on a truck was unreachable** (`69f6738`). The Fleet
   register swapped Assign for Unassign the moment a driver was on, and the
   Trucks-on-route card offered the dialog only under its no-driver warning;
   `DriverAssignmentDialog`'s cap and "request more" path had no entry point.
   Pinned by `second_driver_is_reachable_test.dart`, sabotaged both ways.
2. **The phone title broke mid-word** (`705843a`) — `Load co` / `ntroller`,
   `Compli` / `ance`, `Reconci` / `liations` on the SM-G780G at Jean's font.
   The bar now measures the title against the room beside the icons and drops
   it onto its own full-width row (M3's medium top app bar) only when a word
   would otherwise split. Pinned by `phone_title_never_breaks_a_word_test.dart`.
3. **"Buyer asked for" on a mine-raised request** (`22eb90b`). Pinned by
   `link_step_names_the_requester_test.dart` over the real review screen.

### A server-side gap, recorded for the shipping app

`accept_request_dispatch` notifies only the transporter's admins, and only
about DRIVERLESS trucks. A driver already on the allocated truck is told
nothing about the new scheduled trip — measured: S6W001GP accepted with
Driver Test on it, 0 driver notifications. The order-aware notice exists but
fires only from `add_vehicle_driver`. Added to Phase 5.

### The chat, half driven — and what it found

Two headless Chromes (`CDP_PORT` 9222 / 9223), `ironhills.owner` and
`ironhills.admin`. Proven: presence both ways (`Online` on the contact
profile and on the conversation row), a DM started from a contact's profile,
a text and an image attachment arriving on the other side (`Sent a file:
product-photo.jpg`, a `2 unread messages` divider in the room), the
conversation row's preview and unread badge. NOT yet driven: a reply with a
quote, an @mention, the phone-width layout.

It stopped there because the admin's dock closed by itself — three times in
ninety seconds — and that was the defect, not the tool:

- **An admin's whole portal was torn down and rebuilt every 45 seconds**
  (`f225278`). `CompanyNotifier` wiped its context on every `AuthState`
  emission from an employee user; the auth notifier re-syncs on every change
  to the user's own `profiles` row; the chat presence heartbeat writes
  `last_seen_at` there every 45 s. Semantics node count 142 → 6 → 31 → 129 at
  05:26:47, 05:27:32 and 05:28:16, each with a `Synced auth state` console
  line, the access token unchanged, `last_seen_at` 37 s old — and the owner's
  dock open for twenty minutes beside it. Pinned by
  `company_context_survives_auth_resync_test.dart` (sabotaged: the re-sync
  case fails alone).
- **"Organisation type | mineSupplier"** on the contact profile (`56df087`),
  and with it the second spelling of Mine/Supplier in three more files; now
  `OrgType.labelFor` everywhere, held by the `one-spelling-for-mine-supplier`
  guard (43 guards, all bite).

Neither is re-seen in a browser yet: `build/web` predates every fix this
session made. The APK on the handset (`1ad4c725`) carries the first three.

### What is NOT proven

- The chat's reply quotes, @mentions and phone-width layout.
- `f225278` and `56df087` in a running browser; the `Manage drivers` control
  and the "Mine asked for" line as pixels rather than tests.
- The end-of-session gate was not run in full (Jean paused the session at
  05:31): `flutter analyze` clean, the four new test files 12/12, guards
  43/43 + selftest; everything else on the Phase 0 list is owed first thing
  next session, including both builds.
- Phases 3–7 are untouched, as before.

## Current state — 2026-08-23 (third session) — the gate, the browser look, the chat finished, Phase 2 closed

### The owed gate, run in full

`flutter analyze` clean · `flutter test` 2481 passed / 1 skipped / 9 failed, the
nine being exactly the goldens that moved on purpose in `69f6738` and `56df087`,
regenerated with `--update-goldens`, each diffed against HEAD with PIL and looked
at (`eb2276d`: the group icon, 1148 px on the phone fleet; 132 px of scrollbar
thumb on desktop because the table grew by the icon's width; `Mine / Supplier`
→ `Mine/Supplier` on six) · guards 43/43, `--selftest` all bite · `_sabotage.py`
all three caught · `type_scale_codemod --selftest` OK · `dropdown_width_check`
clean · `glyph_coverage_check` clean · `one_clock_check` 0 sites, selftest bites
· `unphotographed_screens` 94/94 · `health_probe` 6/7 then 7/7 — the extras
project's `search_place_index` timed out twice on the first run (cold after an
idle stretch) and answered in 1.16 s on the retry · `flutter build web
--release` 73.6 s · `flutter build apk --debug` 43.4 s.

### The five fixes, seen in a browser on the rebuilt web

- `f225278` — as `ironhills.admin`, the dock opened at 08:37:21 and held for
  181 s through four presence heartbeats. The console still logs `Synced auth
  state` every 45 s (+17, +63, +108, +152 s) — that is the auth notifier doing
  what it always did — but the semantics node count read 142 at every minute and
  the +181 s screenshot shows the dock open. Before the fix the count went
  142 → 6 → 31 → 129 on each beat.
- `56df087` — `Organisation type · Mine/Supplier` on the contact profile.
- `69f6738` — as `roadhaul.admin`, `Manage drivers` on both assigned trucks;
  on S6W001GP it opens `Drivers — S6W001GP · 1/2 drivers assigned`.
- `22eb90b` — as `jean@cyberhouse.co.za`, on a mine-raised request raised from
  the mine's own form this session (500 t, north stockyard → Richards Bay,
  `REQUESTED` → `APPROVED`, deliberately not dispatched): `1 · Supplying mine —
  Mine asked for: "Iron Hills Mining - north stockyard"`.
- `705843a` — already re-seen on glass (Phase 1).

### One more defect, found by looking at `56df087`

**The profile panel's Role row never said the role** (`31b07cb`). Opening
Controller Test's profile read `Role · Company member` — a weighbridge
controller, while the Contacts list beside it had grouped the same person under
CONTROLLERS from the same RPC field. `ChatContact.roleLabel` now carries the
rule beside `blockedLabel`, through `UserRole.labelFor`; pinned by
`chat_contact_role_label_test.dart` (7 cases; sabotaged: 4 fail, the 3 that must
survive do). Re-seen: Admin Test's profile reads `Role · Admin`.

### The chat, finished

Two headless Chromes, `ironhills.owner` (9222, desktop) and `ironhills.admin`
(9223, desktop then 412×915). Presence `Online` in both lists and both thread
headers. Reply with a quote: hover → floating `Reply` → quote bar → sent; the
owner's bubble carries the quote block; `chat_messages.649d61d8.reply_to_id =
1c1dc7b5`. @mention: `@Adm` → picker with three matches → `@Admin Test · Iron
Hills Mining` → chip on both sides; row `93bac70e.mentions = [{user_id,
display_name}]`; tapping the chip on the owner's side opened the admin's
profile. Phone width: the dock reflowed above the bottom nav; the admin typed
there and the owner's desktop showed `Admin Test is typing…` (header) and
`Admin is typing…` (above the composer); the message landed (`b4d3f93b`).
Attachments both directions: the owner's image (previous session) and the
admin's `lab-sizing-2026-08-23.pdf` from phone width through `Attach a file or
image` (`92ecf5b8`, `file_type file`). Every row `delivered` and `read`.

Observed and left alone, because the shipping app does the same: the composer
shows the raw `@[Name](user:uuid)` token while typing (its line 3324 inserts
the identical string); tapping one's own mention is a no-op (the caller is never
in the contacts list).

Looked at and NOT defects: `fa243ad` on a Trucks-on-route card is a real
registration typed into a test HILUX (trailers `asf324g` / `142ghg42`); the
fleet stat-card captions `all_vehicles` / `carrying_a_load` / `ready_to_allocate`
/ `not_in_service` are the reference's deliberate mono texture
(`docs/design-reference.md` §3, "a deliberate texture, not a bug"); an admin
cannot start a DM with the owner (`Message an admin`) by the P10-07 hierarchy.

### What is NOT proven

- Phase 3 (the per-screen design pass) is untouched.
- Phases 4–7 remain blocked on Jean, as before.
- The approved request above is live test data awaiting a dispatch nobody has
  asked for.

## Phase 3 — per-screen design pass, reviewed against `docs/design-reference/`

Method, per screen: the render is looked at beside the reference captures
(`super-admin-dashboard-dark.png`, `transporters-overview-dark.png`) and the
rules in `docs/design-reference.md` §4–§5 — placement, hierarchy, spacing,
type faces, tone — drift is fixed at its cause, the render regenerated and
looked at again, and the fix pinned by a test that was sabotaged and bit.
"Reviewed, no drift" below means the screen was looked at at the widths its
renders exist for and nothing was found; it is not a claim that the screen is
finished in every respect.

### Console (super-admin) — reviewed 2026-08-23

| route target | verdict | commit |
|---|---|---|
| console shell (desktop dark/light, medium, rail collapsed, phone dark/light) | reviewed, no drift | — |
| `/super-admin` dashboard v2 (desktop dark/light, phone) | matches the reference section for section | — |
| `/super-admin/organizations` | footer hairline shrink-wrapped to the pager; header had no description | `368665f` |
| `/super-admin/users` (platform users) | hand-rolled 16px sans title, no count → MlPageHeader | `f7a49f2` |
| `/super-admin/organization/:id` | five hand-rolled sans headings → MlSectionTitle; two `_InfoRow` copies 8 px apart | `ad1dc5a` |
| `/super-admin/token-requests` | no page header; `open` / `in_progress` pills neutral → warn / transit | `af5fab6` |
| `/super-admin/token-history` | fixture gave every log one org id and ignored the tab's org type; "Mines / suppliers" | `8e0bb19` |
| `/super-admin/audit-logs` | hand-rolled title, title-cased, bare download icon → MlPageHeader + Export | `a37776f` |
| `/super-admin/crash-reports` | hand-rolled title → MlPageHeader | `a388658` |
| `/super-admin/account-deactivations` | hand-rolled title; Approve / Reject at the card's far left → right | `f4812a1` |
| `/super-admin/requests/*` (four inboxes), request detail, dispatch, due-diligence gate | reviewed, no drift | — |
| `/super-admin/margin-ledger` | "Margin ledger History" → sentence case | `0e5950c` |
| `/super-admin/recon-tables` (and the shared RawReconView) | "TIME-IN" broke at its hyphen, plates at their spaces; "All Transporter" | `f57b84c` |
| `/super-admin/disputes` | reviewed, no drift (its OPEN pill now amber from `af5fab6`) | — |
| `/super-admin/available-routes` | actions inline after the title, Unassign stranded → right-aligned action row | `0225e95` |
| `/super-admin/route-marketplace` | reviewed, no drift | — |
| `/super-admin/live-map` | reviewed, no drift | — |
| `/super-admin/driver-limits` | decision floated mid-row → right; "Transporter Driver limits" | `d5dd1c1` |
| `/super-admin/insights/transporter` | is the reference; intact | — |
| `/super-admin/insights/{buyer,mineSupplier}` (v1 language) | last axis tick collided with "Today"; TARGET caption on the spike | `19200e6` |
| `/super-admin/insights/transporter/leaderboard` | "▲ 0.0%" green for no change; red for a fall; light `inkXlo` 4.40:1 | `b8f33ab` |
| `/super-admin/targets`, `/targets/org-type/:t`, `/targets/company/:id` | reviewed, no drift | — |
| `/super-admin/insights/:t/company/:id` (mirror) | sans title/headings; sky-blue second accent; BUYER badge blue, TRANSPORTER green | `ee3e213` |
| `/super-admin/settings` | hand-rolled title → MlPageHeader | `da85f81` |
| `/super-admin/register-company`, `/preferences`, expired access | reviewed, no drift ("User Preferences" casing in `3a0d212`) | — |
| `/super-admin/chat-connections`, communications hub, messages, notifications manager | "Chat Rooms" / "All Notifications" casing; chat-connections sans headings | `4676106` |
| `/super-admin/request-tracking` | "Request's Tracking Logs" → "Request tracking logs" | `3a0d212` |
| appearance (portal, found on the way) | "Mine / Supplier" inside two sentences; the guard now matches the phrase anywhere | `3a0d212` |
| employee register | reviewed, no drift | — |

Also from this pass: the flutter_map logo was the one non-deterministic pixel
across twelve map renders (`fde2fad`).

**Kept on purpose:** the recon table's full gridlines (an Excel-style grid, by
design); the mono snake_case stat-card captions (`design-reference.md` §3, "a
deliberate texture, not a bug"); `Operations Hub` and `Global Admin` as product
names.

**Decision for Jean, not drift:** the buyer and mine/supplier insights and the
company mirror still speak the v1 analytics language (`design-reference.md` §6
records this; the router says "until their own versions land"). Migrating them
onto the v2 overview is a feature, and is listed in `M3-TASKS.md`.

### Mine / supplier portal — IN PROGRESS, 2026-08-23 (fourth session; paused by Jean)

Same method as the console pass. Five read-only reviewer agents looked at every
route target of all five remaining Phase 3 scopes and reported drift by the
nine classes (reports in `docs/redesign/reviews/2026-08-23-phase3/`); every
finding below was verified in the render and the code before it was fixed, one
commit per fix, each pinned by a test that was sabotaged and bit. **The task is
not done** — the rows marked *open* are the reviewer's findings still to be
fixed; the screens not listed are not yet reviewed by this session.

| route target | verdict | commit |
|---|---|---|
| `/portal/mine` dashboard (desktop dark, phone dark) | every band's meta / `View →` sat at two-thirds of the row (`SaSectionHeader`: Flexible·Spacer·Flexible); the chart's TARGET caption under the `7 days` pill; the KPI delta chip at the tile's midpoint; a "Target" legend key for a line not drawn | `8ef16b1` `6dbfb7e` `16fcfac` `0057ef8` |
| portal shell for the mine (`portal-mine-desktop-dark`) | reviewed, no drift — the chrome the console pass reviewed | — |
| `/portal/mine/security`, `/gate` (desktop dark gate mode, phone dark) | hand-rolled sans title with a gradient chip; two sans section headings; title-case labels | `5ddb862` |
| `/portal/mine/weighbridge` (desktop dark/light, phone dark, record-load slide-over) | title case on four stat labels, two headings, the action and the slide-over title; the LOADING pill neutral grey (shared tone map) | `bf25042` `e911fd4` |
| `/portal/mine/operations` (+ `/minerals` `/loads` `/transactions`; rendered as the transporter fixture) | stock-Material company card (sans title, sized to content), tab card (sans heading, button under it), hand-rolled empty state; title-case tab and dialog titles. The empty ledger is the fixture's stated intent. The mine-only tabs are unphotographed (no mine-org render) | `6752683` `166571c` |
| shared `MlSectionTitle` (every portal section) | stacked action stranded left; an icon action hanging below its meta; then a stacked action unbounded (sweep) | `bb0de74` `31586a9` |
| shared `MlPageHeader` (every portal page) | wrapped tools landing LEFT on a phone, description under the buttons — a width rule tried and reverted (43 goldens); the header now MEASURES and stacks only when the tools do not fit | `bcb0fdb` |
| `/portal/mine/stockpiles` (desktop dark) | breakdown-row figures in sans → mono (`MetricBreakdownRow`, 20 sites); then its label given the flex (sweep) | `4ef7ee1` `31586a9` |
| `/portal/mine/stockpiles/:id` (desktop, phone) | "Remaining on hand" headline in sans beside Fraunces cards | `4ef7ee1` |
| stockpile audit (desktop, phone) | two sans headings; a load-out in the error tone; the plate breaking on a phone; sans column figures | `cf3608f` |
| `/portal/mine/production` (desktop dark) | ROM pile card figure mono `412.60 t` vs Fraunces `412.6 t` elsewhere | `4ef7ee1` |
| `/portal/mine/quality` (desktop dark; two dialogs) | `38.0% / 42.0%` pill wrapping at its slash; MOISTURE/SIZING heads abutting; "2 certificates" counting loads | `ce2e10d` `8dc3500` |
| `/portal/mine/reconciliations` (desktop dark) + shared recon tables (desktop dark/light, phone) | "3 delivered loads" over a Pending row; the POD link in accent FILL as ink (1.81:1 on white) | `8dc3500` |
| `/portal/mine/tons-out` (desktop, phone) | reviewed, no drift | — |
| `/portal/mine/tons-out-search` (desktop, phone) | rebuilt in the vocabulary: five reference stat cards, uppercase heads, plate pills, mono mass, "Search loads" title, Fraunces Filters, "Time out", the table filling its card — and a real bug, "Last 24h" windowed on the midnight date (71.12 t vs Tons out's 103.22 t for the same loads) | `249106f` |
| `/portal/mine/locations` (desktop, phone) + the shared Locations section | both card headings hand-rolled; "Add location" stranded left on a phone; "Main Gate" / "Loading Point"; a meta that counted rows, not pinned anchors | `e64212a` `a74f0f0` |
| `/portal/mine/truck-locations`, `/live-map` (shared panels) | a nine-hour-old GPS sample reading like a fresh one; desktop lists with no hairline and no head; the highlighted marker in the fault colour | `da9571e` |
| `/portal/mine/employees` (transporter render) | an active employee with an off-org role counted and drawn nowhere; twelve title-case labels | `db9912d` |
| `/portal/mine/employees/:id` (desktop, phone) | a fall in red; every document well red; the footer button mid-row; "Message  Thandi" wrapping; the employer setup card absent from every golden (no fixture) | `90a82c1` |
| `/portal/mine/register` (desktop, phone) | a second (blue) accent at 16 sites; Offline in the fault colour; "Employee Register" | `9740420` |
| `/portal/mine/compliance`, `/trips` | reviewed, no drift | — |
| employee grid (`/employees/:companyId`) (desktop, phone) | "Fixture Haulage Employees" — the shipping app's `AppBar` title moved into an `MlPageHeader` unchanged — and no meta line (§5.4). **And a real bug behind it:** `getByCompanyId` returned the cache VERBATIM, so every `InfiniteGrid` page after the one that primed it was that page again and never short; and it cached the twenty-row SLICE under the company's key, so for five minutes every reader of that roster — a header counting it included — was told the company had twenty people | `bf40afc` `4a4558f` |
| `/portal/mine/buyers` | *open* — every buyer card takes the accent wash + shadow (`OverviewHeroTile`, `BuyerOverviewCard`); the page head is an `MlSectionTitle` + hand Text, not `MlPageHeader` (`mine_supplier_buyers_detail_screen.dart:171–192`) | — |
| `/portal/mine/requests` (`BuyerRequestsScreen(isMine: true)`, **no render exists**) | *open* — description says "transportation and product requests" for a mine that raises transportation and BUYER requests; actions in a left Wrap under the header, `FilledButton.tonalIcon` (blue) beside cyan (`buyer_requests_screen.dart:56–92`) | — |
| `/portal/mine/trips/:id` | *open* — codes/tonnage in sans, facts in a bare container with no section head (`portal_trip_detail_screen.dart:84–184`) | — |
| `/portal/mine/company` (`company_list_screen.dart`) | *open* — "Company Information" + six title-case labels that wrap in a 130px column even at 1600px; the reference code in sans (`:247–322`) | — |

**Kept on purpose / not drift:** "Mine Control", "Mine Security", "Operations
Hub" as screen names; the gate's 520px phone-first column (the original's);
`OverviewHeroTile`'s sans card titles (card titles, not section heads); the
register's one-per-bucket fixture roster; `Total Tons=` (CLAUDE.md §4);
captions wrapping at a `·`; dialog titles in sans (`dialogTheme`, app-wide);
blank map tiles (the harness). The hub's empty ledger is the fixture's stated
intent (`screen_fixtures.dart`), not a lie.

**Found by the session's own instruments, not a reviewer:** the power cut
zeroed four files mid-write (restored from HEAD); the one-clock guard refused
`MlTime.sast` on a calendar day in the first draft of the Search loads date
cell; the overflow sweep caught two 2–6px overflows that two of this session's
fixes introduced (`31586a9`); a `--name "a|b"` filter is eaten by this shell
(the `|` became a pipe) and a golden was committed a digit stale until the
full suite was re-run (`a74f0f0`).
