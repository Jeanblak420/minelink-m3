# MineLink M3 — session handoff

**Rewritten 2026-08-22, at the end of the chat session — the one that put the
app on a real phone for the first time.**
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

The tree is **clean**, **118 commits**, nothing half-applied and nothing
uncommitted. The tip is
`docs: the handoff for the session the app first ran on a phone`; the last CODE
commit under it is `91f77cf chat: the driver fix was half a fix, and the
handset said so again`, and the whole gate in §2 was run green against that.

**The original worktree was re-checked against its §0 baseline at the start and
at the end and is untouched** — HEAD `df451d0`, the same three pre-existing
modified files, 14163 files under the `-prune` form, two worktree entries,
nothing modified today.

### What changed about this project this session

Two things, and the second is the one that matters.

**1. The chat was fixed properly** — Jean's call: the dock is the chat (the one
that works in the super global admin portal on the untouched app), so it is not
merged away; cover it, and give the threads whatever else they need. The
invisible reply is fixed end to end, the dock has renders for the first time,
and **thirteen of the eighteen chat palettes were painting text below 4.5:1** —
including every outgoing message on the default palette. None of that was
reachable before the dock had a picture.

**2. THE APP RAN ON A REAL PHONE, and that immediately found three defects
nothing else could.** The biggest: **a driver had no chat at all.** Not "no
button" — no chat. `PortalShellLayout` wraps every role's shell in a `ChatDock`
at the end of its build, and the driver's shell is returned from an early
branch ~300 lines above it.

It had passed `flutter analyze`, 2,145 tests, 261 renders and 39 release
guards. §4.1 of the previous handoff predicted hardware would settle GPS, the
foreground service and battery. It settled none of those. It found a missing
feature, an incomplete fix for that feature, and a wrong string.

---

## 0. Where you are

| | |
|---|---|
| **This project** | `C:\Users\Somebody Someone\Music\SHOWME!\MineLink-M3` |
| What it is | A **complete, independent fork** of MineLink, being redesigned onto Material 3. Its own git repo (`main`), **118 commits**, clean tree. |
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
- **The chat is the dock** (2026-08-22): *"the one that needs to be used is the
  same one thats on the untouched version of the app, the same one that runs
  and works perfectly in the super global admin portal"*, then cover it and
  give the threads whatever else they need. Acted on — §3.1.

**`supabase/` is frozen.** No migration is created, applied or pushed here.
(Checked again this session: the reply feature needed nothing from the database
— see §3.1.)

---

## 2. Verified state, right now

Every one of these was run at the end of the session:

```
flutter analyze                                 no issues
flutter test                                    2149 passed, 1 skipped
dart tool/release_guards.dart                   39/39 PASS, 0 FAIL
dart tool/release_guards.dart --selftest        all guards bite
py -3 tool/_sabotage.py                         all sabotages caught
py -3 tool/type_scale_codemod.py --selftest     OK
py -3 tool/dropdown_width_check.py              passes
py -3 tool/glyph_coverage_check.py              passes
py -3 tool/one_clock_check.py                   0 sites off Africa/Johannesburg
py -3 tool/unphotographed_screens.py            93 targets, 93 photographed, 0 not
flutter build web --release                     builds
flutter build apk --debug                       builds
docs/redesign/renders/                          225 renders
render harness — CUT OFF                        9 strings, all deliberate
render harness — FAILURE STATE                  0
render harness — RENDER NOTE                    0  (and it FAILS the test)
render harness — LOW CONTRAST                   0
ANDROID, ON JEAN'S SM-G780G                     installed and driven
```

Layout is swept at **8 widths (1612 → 360px) × 6 text scales (0.85 → 2.0)**,
and again **with real rows in every table** at 360/800/1280 by 1.0/1.3.

⚠️ **CUT OFF went 6 → 9.** The three new ones are the same deliberate string,
once per dock list render: a conversation row shows one line of the last
message and ellipsises the rest, which is what the row is for.

---

## 3. What this session did

Full reasoning is in each commit message — three long ones. Read them rather
than trusting this summary.

### 3.1 The chat, fixed properly

**The reply was written and never read.** `ChatScreen` captured a reply target,
showed "Replying to Thandi" above the composer, and wrote `reply_to_id` on the
insert — then hand-built its `ChatMessage` from the returned row with a map
literal that had no line for that column. The id went to Postgres, came back
over the wire, and was dropped on the last step. The reply arrived as an
ordinary message. Nothing threw; `.select()` had been returning the column all
along.

**The database half was already right and is unchanged.** Verified against
production rather than assumed: `reply_to_id uuid`, FK to `chat_messages(id)`
ON DELETE SET NULL, `chat_messages_reply_to_id_idx`, and RLS scoping both
select and insert to room membership. There was no migration to write. (Worth
knowing: there is no UPDATE or DELETE policy on `chat_messages`, so no message
can be edited or deleted through PostgREST — and no surface offers to, so
nothing silently fails.)

The mapping is a named factory now (`ChatMessage.fromRow`), because a missing
line in a map literal looks exactly like a field nobody wanted.

**Thirteen of eighteen chat palettes were illegible.** The dock had no renders;
the moment it had one it reported white on `#5E81AC` at 4.03:1 for every
outgoing message on the DEFAULT palette. Most of it was one shape, not thirty
values: `_ReplyQuote` filled its ground with the bubble's own text colour at
14% and then wrote that same colour on it — a ground moved TOWARDS its ink,
which can only cut the ratio. Tinting AWAY (`ChatPalette.quoteGround`) gives a
property worth having: separation can only increase, so a quote is legible
wherever its bubble is. Four fills also needed deepening for white to reach
4.5:1 at all. `test/design/chat_palette_contrast_test.dart` asks the question
of all eighteen as arithmetic, because a render can only ever photograph the
one palette that happens to be selected.

Two more were their own faults: the unread badge took the presence-dot red
(3.76:1 under an 11px numeral — a dot is a shape at 3:1, a badge is text at
4.5), and a reaction chip's emoji had no colour at all, so it inherited the APP
theme's ink while the chip was painted from the CHAT palette — 1.78:1 when the
two disagree. Colour emoji ignore the colour, which is exactly why it survived.

I then made the same mistake in my own new quote block — accent ink on an
accent-tinted well, 3.44:1 — and the render reported it on the next run.

**Raw mention tokens.** Both surfaces read `chat_messages`, and the dock writes
mentions as `@[Display](user:id)`. `ChatScreen` rendered `content` through a
plain `Text`, so a dock-composed message opened there read
`Morning @[Thandi Mokoena](user:8f2c…) — 06:00?`. Chips now.

### 3.2 The first hardware drive, and the three things it found

Installed from `\\192.168.88.30\Shared\PhoneRemote\minelink-m3.apk` through My
Files' own network-storage mount — not over HTTP, which is where the previous
session stalled. Signed in as `roadhaul.driver@mineralguide.com` against the
live database.

**What rendered correctly:** the auth screen, the account-setup gate, the
driver Dashboard with live figures (3 loads this week · 102.1 t · 5 deliveries
· 171.32 t total), the Trip tab's empty state, and Recent Trips with four real
completed trips.

**What it found:**

1. **A driver had no chat at all** — no dock, no rail entry (the 3-tab shell
   replaces the sidebar), and `DriverAppScreen` has no messages affordance of
   its own.
2. **The first fix was half a fix.** There are TWO driver branches and `/home`
   is the wrong one: `portalLandingRoute` sends a driver to
   `/portal/driver/home` on sign-in, so `/home` is one frame. Rebuilding and
   reinstalling is what revealed it — the test I had written for the bug read
   the branch I had already fixed, and passed.
3. **The dock's empty state named a tab that does not exist** — "Open the
   People tab" on a surface whose tabs are Conversations | Contacts. Copied
   verbatim from `MessagesScreen`, whose tabs really are Chats | People. It is
   the one instruction shown to somebody with no conversations.

All three are fixed, guarded, and the guards sabotaged.

### 3.3 New tests, all sabotaged to prove they bite

| test | what it stops |
|---|---|
| `chat_message_row_test.dart` | a column written and never read — nulls each in turn and fails if the model does not change |
| `chat_reply_quote_test.dart` | the quote not reaching the screen: over text, over an attachment, with a dangling parent, with a mention token |
| `chat_palette_contrast_test.dart` | any of the 18 palettes painting text under 4.5:1, quote grounds included |
| `driver_can_reach_chat_test.dart` | **both** driver branches losing their `ChatDock` |
| `empty_state_names_a_real_tab_test.dart` | an empty state naming a control that is not on that surface |

---

## 4. What is NOT done — PICK UP HERE

### 4.1 The phone — INSTALLED AND DRIVEN. What is left is a real trip.

**This is no longer a blocked item.** The install route is proven end to end and
is repeatable in about six minutes:

```
1. flutter build apk --debug
2. copy build/app/outputs/flutter-apk/app-debug.apk  ->
     \\192.168.88.30\Shared\PhoneRemote\minelink-m3.apk
3. On the phone: My Files -> Network storage -> jean -> Shared -> PhoneRemote
   -> minelink-m3.apk -> (downloads ~2.5 min) -> Install/Update -> Open
```

⚠️ **My Files caches the folder listing.** After re-staging, back out of
`PhoneRemote` and re-enter it, and CHECK THE TIMESTAMP against the file you
just copied — otherwise you install the previous build and conclude your fix
did not work. That happened.

⚠️ **Do not install a stale APK.** The one staged by the previous session was
built 25 minutes BEFORE the last code commit, so it did not contain the route
renames. Compare the APK's mtime against `git log -1 --format=%ci`.

⚠️ **Only Jean can wake a sleeping display.** It slept once mid-session;
`probe` reports `0.081 bits/pixel (under 0.1 - nothing on the screen)`. Ask.

**What a handset still has not proven, and how to reach it.** The drive stopped
short because the driver account has no active trip, so the live-location
toggle is disabled by design ("Available once you have an active trip") and the
Trip screen has nothing to act on.

🚨 **CREATE THE LOAD YOURSELF. Jean authorised this on 2026-08-22** when he
asked why a session could not just do it: *"the new session can run it, run it
all and or create it with the other user's, he can do the one side of it all on
the pc to assign what needs to be assigned and then test the mobile stuff on my
phone"*. It also sits inside the standing permission in CLAUDE.md §1 —
*"none of the tons in the db actually matters… if that tons recorded and or
routes gets destroyed it would all be fine."*

Every account the chain needs already exists (`active user accounts.txt`), and
all of it is drivable in a browser against the live database:

| # | do this | as |
|---|---|---|
| 1 | Raise a Request Transporter/Route | `atlasbuyer.admin@mineralguide.com` |
| 2 | Approve → set the R margin → due-diligence gate → select Iron Hills → select Roadhaul → dispatch | `jean@cyberhouse.co.za` |
| 3 | Accept the route, assign a truck, assign the driver | `roadhaul.admin@mineralguide.com` |
| 4 | Supervisor adds tons to the auto-created stockpile | `ironhills.management@mineralguide.com` |
| 5 | Security check-in, weighbridge tare/gross, check-out | `ironhills.security@` / `ironhills.controller@` |
| 6 | Drive the trip | `roadhaul.driver@` **on the phone** |

Step 2 also drives the **due-diligence gate**, which §4.4 records as never
having been driven end to end — so this closes two open items at once.

**Then the split is honest about what a desk can and cannot settle:**

| reachable once a load exists | needs the phone to physically move |
|---|---|
| the Trip screen showing the real load, From→To timeline | GPS fixes changing along a road |
| the live-location toggle becoming ENABLED | the 30s ping cadence over distance |
| Directions / Arrived at loading / Arrived at offloading / Upload POD | auto-reroute on going off-route |
| the turn-by-turn navigation screen opening and drawing a route | the foreground service surviving a long backgrounding |
| the whole lifecycle from the other roles' side | battery drain over a real trip |

**Only the right-hand column waits on Jean actually driving somewhere.** Do the
left-hand column without asking; report the right-hand column to him with what
is left to check. ⚠️ The emulator can fake movement (`adb emu geo fix`) and the
2026-07-17 emulator run already proved the navigation stack that way — a real
handset cannot be teleported, so do not try.

**iOS** is still unattempted; no reachable Apple Developer account.

### 4.2 Contrast — CLOSED, and now closed for chat too

App-wide 1,812 → **0**, and `low_contrast_baseline.json` is `{}` — a floor, not
a ratchet. **If it ever fails, do not add a baseline entry**; the failure names
the token to change.

The chat palettes are now covered by arithmetic as well
(`chat_palette_contrast_test.dart`), which the renders cannot do: 18 palettes,
one selected at a time.

### 4.3 The chat surfaces — DECIDED AND ACTED ON

Jean's call, 2026-08-22: the dock is the chat, do not merge, cover it, fix what
it needs. Done — §3.1.

**What was deliberately NOT done:** `MessagesScreen` (985 lines) and
`ChatScreen` + `ChatWidget` (1,584 lines) still exist. `MessagesScreen` is
still reachable only when a licence token is expiring, and its two
employee-profile entry points are still dead code (guarded on `ChatDock` NOT
being mounted, and the dock is mounted on both shells — and now on the driver
shell too, so they are deader than before). Deleting ~2,500 lines is a
separate decision and Jean has not been asked for it.

`ChatScreen` is NOT dead, though — it is the `/chat/:id` route, it is reachable
from the Communications hub, and it is the one whose reply was broken. It is
fixed and photographed rather than removed.

### 4.4 Known limitations, stated rather than hidden

- **Windows is blocked by two pre-existing faults** — the Flutter tool refuses
  the path because of the `!` in `SHOWME!`, and from a clean path CMake fails
  extracting `firebase_cpp_sdk_windows_12.7.0.zip`. Same dependency, same
  version, in the shipping app. Jean said to skip it.
- **Nine strings are cut, on purpose** — three crash-report exception messages,
  three chat message previews, and three conversation-row previews in the dock
  list renders (one string, three renders).
- **Some fixtures are deliberately EMPTY.** The operations hub's ledgers are
  the documented example. Do not "fix" those by filling them.
- **The map tiles are real in a browser and on a device**, and blank in renders
  — `flutter_test` answers every HTTP request with 400.
- **The 127 hand-named typefaces** are held by the `typeface-named-by-hand`
  ratchet, which can only shrink. Not a gap.
- **Eleven route divergences remain**, all the same shape: longer in the rail,
  shorter in the bar. Recorded with both strings in
  `test/core/every_portal_route_is_named_test.dart`. Four were settled on
  Jean's call on 2026-08-22; the other eleven need the same.
- **The due-diligence gate has never been driven end to end** — preview,
  confirm, the green tick, the "are you 100% sure", the transporter list, the
  final confirm. `shoot()` can interact (`act:`), so the mechanism to
  photograph it exists; the sequence has never been run. **§4.1 step 2 goes
  straight through it**, so creating the load closes this at the same time.
- **A live chat between two real accounts has never been driven.** The dock was
  opened on the handset and its empty state read; no message was sent.
- ⚠️ **A leftover firewall rule needs an elevated shell.** `CtrlBridge APK
  download (TCP in)` is still present and Enabled, from the previous session's
  `serve_apk.ps1`. Nothing is listening on port 8000 any more — the server is
  stopped — but the inbound rule was not removed, because the script only
  removes it on a clean Ctrl-C. **Jean, in an admin PowerShell:**
  ```powershell
  Remove-NetFirewallRule -DisplayName 'CtrlBridge APK download (TCP in)'
  ```
  An unelevated shell gets "Access is denied". The NAS route makes
  `serve_apk.ps1` unnecessary from now on, so this should not come back.

---

## 5. How to work in this repo

```bash
cd "/c/Users/Somebody Someone/Music/SHOWME!/MineLink-M3"

flutter analyze                                  # must be clean
flutter test                                     # 2149 passing, 1 skipped
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

⚠️ **`solve-tint` moves the INK.** When the ink is white there is nowhere
lighter for it to go and it answers "UNREACHABLE on this ground at all" — that
is telling you to deepen the FILL, not that the pairing is impossible.

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
  .click()`.
- **`fill` on two different fields writes both into one.** Click the field,
  then `type_text` with `submitKey: "Tab"`.
- **Chrome will not resize below ~500px.** Use CDP emulation
  (`412x915x1,mobile,touch`).

### Driving it on the emulator

```bash
# adb is at C:\Android\sdk\platform-tools and is ALREADY ON PATH.
adb devices
flutter emulators --launch minelink_test
adb install -r build/app/outputs/flutter-apk/app-debug.apk
adb shell monkey -p org.minelink.m3 -c android.intent.category.LAUNCHER 1
```

`adb shell input text` mangles `!` and turns `%s` into a space. Quote it for
the DEVICE shell — `adb shell "input text 'MineralGuide123!'"`.

### Driving Jean's real phone

**Invoke the `driving-jeans-phone` skill FIRST**, then §4.1 above for the
install route. The phone is **paired** (`status` → `sharing=True control=True`)
and `phone_agent.py`'s own `text` command handles `!` correctly — unlike adb.

The skill says "already paired, no PIN needed"; that was stale on 2026-08-21
and true again on 2026-08-22. If `status` says the phone no longer recognises
this PC, ask Jean for the PIN off the host-mode screen and run
`py -3 phone_agent.py --pin <PIN> run "status"`.

It is his **personal** phone: prefer `sig`/`changed`/`waitstable`, delete every
screenshot immediately, back out of anything opened by mistake and say so, and
leave it on `home; waitstable; home`.

⚠️ **`look` does not describe the screen** despite its help text — it prints
frame statistics only. Navigating needs `shot`, which means screenshots, which
means deleting them.

### Live accounts

`active user accounts.txt` in the repo root. `jean@cyberhouse.co.za` /
`BuRG3rJ3@n1995@#` is the platform admin; `ironhills.owner@mineralguide.com`
and `roadhaul.driver@mineralguide.com` / `MineralGuide123!` are the seeded set.

⚠️ **The console stores theme and accent PER ADMIN.** Switching Jean's mode to
Light writes to his account. Put it back.

⚠️ **The driver account's setup is 14% complete on production.** The gate
dialog lists six missing documents. Dismiss it with **Later** — "Complete now"
would write real data to a real account.

### Things that have already gone wrong here — do not repeat them

- 🚨 **A POWER CUT DESTROYED A FILE MID-WRITE.** `low_contrast_report.dart`
  came back as 23,598 NUL bytes — right size, no content. **Commit often; copy
  to the scratchpad before any long edit.**
- 🚨 **A BASH HEREDOC EATS BACKSLASHES EVEN WHEN QUOTED**, and a Python string
  inside one eats them again. **It has now broken a patch in SIX sessions** —
  this one ate the `\\` in a Python `p.split('\\')` and died on a
  `SyntaxError`. **Write any script containing a backslash with the Write
  tool, or use Edit directly.**
- 🚨 **NEVER READ A LONG TEST RUN THROUGH `tail`.** Redirect to a file and grep
  the file.
- 🚨 **`git checkout -- <dir>` THREW AWAY UNCOMMITTED WORK.**
- 🚨 **A LONG `&&` CHAIN ENDING IN `git commit -F <heredoc>` TIMES OUT.** Write
  the message to a file and commit with `-F` as its own command.
- 🚨 **Python's stdout is cp1252 here** — printing `−` or `·` from a script
  dies. Set `PYTHONIOENCODING=utf-8`.
- 🚨 **A CHECK YOU HAVE NOT SABOTAGED IS A CHECK YOU DO NOT HAVE**, and the
  scene must be FAITHFUL.
- 🚨 **A TEST WRITTEN FOR A BUG CAN READ THE HALF YOU ALREADY FIXED.** The
  driver-chat test passed while the app was still broken, because it asserted
  on the branch I had changed and there were two. **When a fix is verifiable on
  a device, verify it there before believing the test.**
- 🚨 **A NEW TEST MUST PASS `theme: AppTheme.build(...)` to `MaterialApp`.** A
  bare `MaterialApp` renders in stock Material's type scale and font — text the
  app never draws. `test-renders-under-the-app-theme` caught two of mine.
- 🚨 **A background task holding a file blocks a later copy to it.** A
  `Get-FileHash` over SMB kept `minelink-m3.apk` open and the re-stage failed
  with "used by another process". `TaskStop` does not always kill the
  underlying `pwsh` — find it by `CreationDate` and `Stop-Process`. **Two
  long-running `pwsh` processes on this machine are Jean's VS Code terminals;
  check `CommandLine` before killing anything.**
- **A `RepaintBoundary` inside a `Scaffold` does not capture a DIALOG.**
- **`loadRealFonts()` is not enough** — name the family. CLAUDE.md §7, §10.5.
- **`Color.alphaBlend` keeps the BACKGROUND's alpha.**
- **`dart format` on a directory reformats files you did not touch.**
- **`find.text` cannot see a `TextSpan`**, and **`toPlainText()` CANNOT SEE A
  TRUNCATION** — use `RenderParagraph.didExceedMaxLines`.

### Where the reasoning lives

- `docs/redesign/DESIGN.md` — decisions and what each cost.
- `docs/redesign/VERIFICATION.md` — what was executed, and what has not been.
  **Its 2026-08-22 section is the hardware drive.**
- `docs/design-reference/` — the **pre-redesign** reference PNGs. **Do not
  regenerate them**; they are the before-image.
- `docs/redesign/renders/` — 225 PNGs of the redesign.
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
- **§5** — design tokens are law. `no-material-colors` caught a
  `Colors.black`/`Colors.white` I introduced for a quote tint; the right tokens
  were `MlTokens.overlayDark` / `overlayLight`, which exist precisely to name
  black and white *as a translucent layer, where the alpha is the decision*.

---

## 7. Exactly where this session stopped

Nothing is in flight in the repo. The tree is clean at
`docs: the handoff for the session the app first ran on a phone`; the last CODE
commit under it is `91f77cf chat: the driver fix was half a fix, and the
handset said so again`, and the whole gate in §2 was run against that, both
builds included.

**Outside the repo:**

1. **The phone is paired, awake and idle**, left on `home`. `org.minelink.m3`
   on it is the build at commit `91f77cf` (staged 02:13). Every screenshot
   taken was deleted; zero remain.
2. **The NAS carries that same APK** at
   `\\192.168.88.30\Shared\PhoneRemote\minelink-m3.apk`, and
   `C:\PhoneRemote\dist\minelink-m3.apk` matches it.
3. **The `CtrlBridge APK download (TCP in)` firewall rule is still Enabled**
   and needs an elevated shell to remove — §4.4. Nothing is listening on 8000.

**Pick up at §4.1** if a real trip can be dispatched to the driver account
(that is the only way to reach GPS, the foreground service and battery), or
§4.4's eleven route divergences, which need Jean's call the way the first four
did.

---

## 8. COPY-PASTE MESSAGE FOR THE NEXT CHAT

Everything the next session needs is inside this block. Paste it whole.

```
Continue the MineLink Material 3 redesign, exactly where the last session left
off. Read these TWO handoff files before doing anything else, in this order.

1. THE CURRENT HANDOFF — THIS IS THE FILE THAT GOVERNS THE WORK:

      C:\Users\Somebody Someone\Music\SHOWME!\MineLink-M3\HANDOFF.md

   Rewritten 2026-08-22 at the end of the chat-and-first-hardware-drive
   session. Read it in this order: "WHERE THIS SESSION STOPPED — READ THIS
   FIRST", then §0 (where you are + the one rule), §2 (verified state), §3
   (what was done and what the phone found), §7 (exactly where I stopped), §4
   (what is NOT done — pick up here) and §5 (things that have already gone
   wrong in this repo).

2. THE OLDER MACHINE-WIDE HANDOFF — BACKGROUND ONLY, DO NOT WORK FROM IT:

      C:\Users\Somebody Someone\Claude\HANDOFF.md

   Dated 2026-08-08. MCP servers, git position, the decoy folders, the phone
   tooling. Claude Desktop reads that folder through its `claude-notes` MCP
   server. The MineLink-M3 handoff above governs this redesign work; where the
   two disagree, the MineLink-M3 one wins.

THE PATHS THAT MATTER

  Work happens here (its own git repo, branch `main`, 118 commits, clean):
    C:\Users\Somebody Someone\Music\SHOWME!\MineLink-M3

  NEVER TOUCHED, for any reason:
    C:\Users\Somebody Someone\Music\SHOWME!\worktree-2026-05-05T11-53-29

THE ONE RULE THAT MUST NOT BREAK: nothing whatsoever changes inside
worktree-2026-05-05T11-53-29. Its verified baseline is in §0 of the MineLink-M3
handoff — CHECK IT AT THE START OF THE SESSION AND AGAIN AT THE END:

    HEAD              df451d0
    git status        exactly 3 modified files, all pre-existing:
                        M .design-sync/config.json
                        M lib/features/super_admin/screens/margin_ledger_screen.dart
                        M test/widgets/app_sidebar_behaviour_test.dart
    file count        14163   (with `find . -path ./.git -prune -o -type f -print | wc -l`)
    git worktree list exactly 2 entries — the main repo and that worktree
    modified today    0

  ⚠️ The file count depends on which `find` you run and the difference is NOT a
  new file: `find . -type f -not -path "./.git/*"` returns 14164, because in a
  WORKTREE `.git` is a FILE, not a directory, so that pattern does not exclude
  it. The `-prune` form returns 14163. Both describe the same untouched tree.

WHERE I LEFT OFF, EXACTLY

The tree is CLEAN. 118 commits. Nothing is half-applied and nothing is
uncommitted. The tip is "docs: the handoff for the session the app first ran on
a phone"; the last CODE commit under it is 91f77cf "chat: the driver fix was
half a fix, and the handset said so again", and the whole gate below was run
green against that, both builds included.

Green, at that commit, means EXACTLY this — compare against it rather than
guessing what "passing" looks like in this repo:

    flutter analyze                    no issues
    flutter test                       2149 passed, 1 skipped
    dart tool/release_guards.dart      39/39 PASS, 0 FAIL
    dart tool/release_guards.dart --selftest   all guards bite
    py -3 tool/_sabotage.py            all sabotages caught
    py -3 tool/unphotographed_screens  93 targets, 93 photographed, 0 not
    py -3 tool/one_clock_check.py      0 sites off Africa/Johannesburg
    py -3 tool/type_scale_codemod.py --selftest   OK
    py -3 tool/dropdown_width_check.py            passes
    py -3 tool/glyph_coverage_check.py            passes
    docs/redesign/renders/             225 renders
    render harness — RENDER NOTE       0   (and it FAILS the test)
    render harness — FAILURE STATE     0
    render harness — LOW CONTRAST      0
    render harness — CUT OFF           9   (all deliberate, named in place)
    flutter build web --release        builds
    flutter build apk --debug          builds

⚠️ NOTHING IS RUNNING. No web server, no Chrome with remote debugging, no
emulator, no APK server. §5 of the handoff has the commands to bring each back.

THE PHONE IS INSTALLED AND WORKING — THIS IS NO LONGER A BLOCKED ITEM

  Jean's SM-G780G at 192.168.88.34 is paired and idle on `home`.
  `org.minelink.m3` on it is the build at commit 91f77cf. The install route is
  proven end to end and takes about six minutes:

    1. flutter build apk --debug
    2. copy build/app/outputs/flutter-apk/app-debug.apk  ->
         \\192.168.88.30\Shared\PhoneRemote\minelink-m3.apk
    3. On the phone: My Files -> Network storage -> jean -> Shared ->
       PhoneRemote -> minelink-m3.apk -> (downloads ~2.5 min) -> Install or
       Update -> Open

  ⚠️ My Files CACHES the folder listing. After re-staging, back out of
  PhoneRemote and re-enter it, and CHECK THE TIMESTAMP against the file you
  just copied — otherwise you install the PREVIOUS build and conclude your fix
  did not work. That happened in the last session.
  ⚠️ Do NOT install a stale APK. The one the session before had staged was
  built 25 minutes BEFORE the last code commit. Compare the APK's mtime against
  `git log -1 --format=%ci`.
  ⚠️ Only Jean can wake a sleeping display. `probe` reports "0.081 bits/pixel
  (under 0.1 - nothing on the screen)" when it is asleep. Ask him; injected
  touches cannot wake it.
  ⚠️ Invoke the `driving-jeans-phone` skill FIRST. It is his PERSONAL phone:
  prefer sig/changed/waitstable over screenshots, delete every screenshot
  immediately after reading it, do not read what you did not come for, back out
  of anything opened by mistake and say so, and leave it on
  `home; waitstable; home`. Note that `look` does NOT describe the screen
  despite its help text — it prints frame statistics only, so navigating means
  taking screenshots and deleting them.
  ⚠️ The applicationId is `org.minelink.m3`, deliberately different from the
  shipping app's `com.example.flutter_application_1` — read that twice before
  concluding which app you are looking at. They install side by side.
  ⚠️ Sign in as roadhaul.driver@mineralguide.com / MineralGuide123! . The
  account-setup gate lists six missing documents — dismiss it with "Later".
  "Complete now" would write real data to a real production account.

  ONE THING ONLY JEAN CAN DO, in an ADMIN PowerShell:
      Remove-NetFirewallRule -DisplayName 'CtrlBridge APK download (TCP in)'
  It is left over from the old HTTP install route, still present and Enabled.
  Nothing is listening on port 8000 any more — the server is stopped — but the
  script only removes the rule on a clean Ctrl-C, and an unelevated shell gets
  "Access is denied". The NAS route makes serve_apk.ps1 unnecessary from now
  on, so this should not come back. Remind him; do not try to do it yourself.

WHAT IS ALREADY DONE — DO NOT REDO ANY OF IT

  * CONTRAST IS CLOSED, app-wide AND for chat. 1,812 low-contrast strings -> 0,
    and test/renders/low_contrast_baseline.json is `{}`: a missing entry reads
    as zero, so it is a FLOOR, not a ratchet. IF IT EVER FAILS, DO NOT ADD A
    BASELINE ENTRY — the failure message names the token to change.
  * ALL EIGHTEEN CHAT PALETTES ARE COVERED BY ARITHMETIC
    (test/design/chat_palette_contrast_test.dart), which renders cannot do — a
    render only ever photographs the ONE palette that happens to be selected.
    THIRTEEN OF EIGHTEEN were painting text under 4.5:1 before this session.
  * THE CHAT IS THE DOCK, on Jean's explicit call. It is NOT merged away. The
    invisible reply is fixed end to end (the column was written to Postgres and
    never read back — the legacy ChatMessage model had nowhere to put it); the
    dock has 7 renders where it had NONE; mention tokens no longer render raw
    as `@[Name](user:id)`; the unread badge and a reaction chip were both
    illegible and are fixed.
  * THE DATABASE NEEDED NOTHING and is unchanged. `reply_to_id`, its FK
    (ON DELETE SET NULL), its index and both RLS policies were already correct
    — verified against production, not assumed. `supabase/` stays FROZEN: no
    migration is created, applied or pushed in this fork.
  * A DRIVER CAN REACH CHAT. They could not, AT ALL, until this session — no
    dock, no rail entry (the 3-tab shell replaces the sidebar), and
    DriverAppScreen has no messages affordance of its own. There are TWO driver
    branches in PortalShellLayout and BOTH are wrapped now.
  * THE APP HAS RUN ON REAL HARDWARE, and the three defects it found are fixed,
    guarded, and the guards sabotaged to prove they bite.
  * FOUR ROUTE NAMES SETTLED on Jean's call in an earlier session: fleet ->
    "Vehicles", drivers -> "Drivers", trucks-on-route -> "Trucks on route",
    trip -> the RAIL becomes "Trip". Fifteen divergences are now eleven.
    ⚠️ Do NOT also rename PortalTabItem('Trucks On Route') — that string is a
    LEGACY TAB LABEL, `_legacyTabLabels` maps it onto the canonical form, and
    renaming it breaks tab selection SILENTLY. It was tried and reverted.

WHAT IS LEFT — START HERE, IN THIS ORDER

  1. CREATE A REAL LOAD FOR THE DRIVER, YOURSELF, AND DRIVE THE WHOLE CHAIN.
     DO NOT ASK FIRST — Jean authorised this explicitly on 2026-08-22: "the new
     session can run it, run it all and or create it with the other user's, he
     can do the one side of it all on the pc to assign what needs to be
     assigned and then test the mobile stuff on my phone". It also sits inside
     the standing permission in CLAUDE.md §1: "none of the tons in the db
     actually matters… if that tons recorded and or routes gets destroyed it
     would all be fine."

     The driver has no active trip, which is why the last drive stopped short:
     the live-location toggle is disabled BY DESIGN until there is one
     ("Available once you have an active trip") and the Trip screen has nothing
     to act on. Every account the chain needs already exists — they are all in
     `active user accounts.txt` in the repo root, and the whole thing is
     drivable in a browser against the live database:

       1. Raise a Request Transporter/Route
             as atlasbuyer.admin@mineralguide.com
       2. Approve -> set the R margin -> due-diligence gate -> select Iron
          Hills -> select Roadhaul -> dispatch
             as jean@cyberhouse.co.za          (platform admin)
       3. Accept the route, assign a truck, assign the driver
             as roadhaul.admin@mineralguide.com
       4. Supervisor adds tons to the auto-created capped stockpile
             as ironhills.management@mineralguide.com
       5. Security check-in, weighbridge tare/gross, security check-out
             as ironhills.security@ / ironhills.controller@
       6. Drive the trip ON THE PHONE
             as roadhaul.driver@mineralguide.com

     Password for every @mineralguide.com account: MineralGuide123!
     Password for jean@cyberhouse.co.za: BuRG3rJ3@n1995@#

     ⚠️ Step 2 also drives the DUE-DILIGENCE GATE, which has never been driven
     end to end — so doing this closes two open items at once. Photograph it.

     THEN BE HONEST ABOUT THE SPLIT. Reachable once a load exists, all of it
     without Jean: the Trip screen showing the real load and its From->To
     timeline; the live-location toggle becoming ENABLED; Directions / Arrived
     at loading / Arrived at offloading / Upload POD; the turn-by-turn
     navigation screen opening and drawing a real route; and the entire
     lifecycle from the other roles' side.

     NOT reachable at a desk, because a real handset cannot be teleported: GPS
     fixes changing along a road, the 30s ping cadence over distance,
     auto-reroute on going off-route, the foreground service surviving a long
     backgrounding, and battery over a real trip. Do the first list without
     asking; report the second to Jean with exactly what is left to check.
     ⚠️ The EMULATOR can fake movement (`adb emu geo fix`) and a 2026-07-17 run
     already proved the navigation stack that way — do not try it on the phone.
  2. THE ELEVEN REMAINING ROUTE DIVERGENCES — all the same shape (longer in the
     rail, shorter in the bar). Both strings for each are recorded in
     test/core/every_portal_route_is_named_test.dart. They need Jean's call the
     way the first four did; they are RECORDED, not open. Put the eleven in
     front of him as a list and let him choose.
  3. WHETHER MessagesScreen AND ChatScreen SHOULD BE DELETED. About 2,500
     lines. MessagesScreen (985 lines) is reachable ONLY when a licence token
     is expiring, and its two employee-profile entry points are dead code —
     guarded on ChatDock NOT being mounted, and the dock is now mounted on the
     driver shell too, so they are deader than before. Jean has NOT been asked.
     ⚠️ ChatScreen is NOT dead — it is the /chat/:id route, reachable from the
     Communications hub, and it is the surface whose reply was broken. It is
     fixed and photographed rather than removed. Do not delete it by accident.
  4. A LIVE CHAT BETWEEN TWO REAL ACCOUNTS has never been driven. The dock was
     opened on the handset and its empty state read; no message has been sent
     between two signed-in users, and no reply has been sent through the real
     database. That is the one part of the chat work proven only by tests and
     renders.

HOW TO WORK — THIS IS JEAN'S INSTRUCTION, FOLLOW IT

don't worry about me seeing anything, I'll want to see when everything is
complete and done, so don't stop so much in between please run the task for as
long as possible so that we can get this completley done and sorted please,
correct your self where you make mistakes and fix the mistakes and make sure
you don't implement anything with gaps in them make sure its full and proper
like the original

AND, EXPLICITLY: IF YOU FIND PROBLEMS ALONG THE WAY, FIX THEM AS YOU GO — then
TEST THE FIX AND CONFIRM IT ACTUALLY WORKS AS EXPECTED before moving on. Do not
collect a list of faults to hand back; do not leave a fix unverified. Every fix
gets a test that BITES (remove the fix, watch the test fail, put it back), and
where the fix is visible on a device or in a browser, GO AND LOOK AT IT THERE.
Half-implemented work, TODOs, stubs and "this could be improved later" notes
are not acceptable — finish each thing properly and completely, the way the
original app does it.

THE METHOD, unchanged: fixtures, regenerate, LOOK at the PNG, MEASURE it with
PIL rather than squint, fix the SHAPE rather than the instance where the fault
is structural, then pin it with a test and prove the test bites by removing the
fix and watching it fail. When a report and a picture disagree, THE PICTURE
WINS.

AND — learned the hard way last session — WHEN A FIX IS VERIFIABLE ON THE
DEVICE, VERIFY IT THERE BEFORE BELIEVING THE TEST. A test written specifically
for a bug PASSED while the app was still broken, because it asserted on the one
branch that had already been fixed and there were two of them. Only rebuilding
and reinstalling on the handset showed it.

Watch for the faults every batch has had: a screen inside a ShellRoute that
builds its own Scaffold+AppBar; a screen that reads a service directly so no
provider override reaches it; a FIXTURE that says less than the service it
stands in for, or that sets two derived fields independently and prints an
impossibility; an override list that does not reach the screen; a wire enum
value reaching a reader; a Row handing a non-flex child unbounded width —
including its commonest form, two Flexible children (or a Flexible and a
Spacer, which IS an Expanded) splitting a row when only one is long; a notifier
that dials out from its CONSTRUCTOR so it cannot be photographed (six have
needed a `start()` seam now); and a string copied between two surfaces that
names a control only one of them has.

OPTIONAL: if the Windows build gives trouble, just carry on with web and
mobile. It is blocked by two PRE-EXISTING faults, neither this project's — the
Flutter tool refuses the path because of the `!` in `SHOWME!`, and from a clean
path CMake fails extracting firebase_cpp_sdk_windows_12.7.0.zip. Same
dependency, same version, in the shipping app. Jean already said to skip it.

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
py -3 tool/unphotographed_screens.py
flutter test test/renders          (after any visual change, --update-goldens first)
flutter build web --release
flutter build apk --debug

...AND the original worktree re-checked against the §0 baseline above.

READ §5 OF THE MineLink-M3 HANDOFF — the things that have already gone wrong in
this repo — so you don't repeat them. The ones that have cost real time more
than once:

  * A POWER CUT DESTROYED A FILE MID-WRITE — it came back as 23,598 NUL bytes,
    right size, no content, and git called it binary. A scratchpad copy is what
    saved the work. COMMIT OFTEN; copy to the scratchpad before any long edit.
  * A BASH HEREDOC EATS BACKSLASHES EVEN WHEN QUOTED, and a Python string
    inside one eats them again. It has now broken a patch in SIX sessions —
    last time it ate the `\\` in a Python `p.split('\\')` and died on a
    SyntaxError. WRITE ANY SCRIPT CONTAINING A BACKSLASH WITH THE WRITE TOOL,
    or use Edit directly on the file.
  * NEVER READ A LONG TEST RUN THROUGH `tail`. Redirect to a file and grep it.
  * `git checkout -- <dir>` THREW AWAY THREE FINISHED UNCOMMITTED FIXES.
  * A LONG && CHAIN ENDING IN `git commit -F <heredoc>` TIMES OUT at two
    minutes. Write the message to a file and commit with -F as its own command.
  * PYTHON'S STDOUT IS cp1252 HERE — printing an en-dash or a middot from a
    script dies with UnicodeEncodeError. Set PYTHONIOENCODING=utf-8.
  * A CHECK YOU HAVE NOT SABOTAGED IS A CHECK YOU DO NOT HAVE — and the scene
    must be FAITHFUL. Two test scenes once proved nothing: one put the two
    labels at x-ranges that never overlapped, the other used a flat fill where
    the mechanism needs a gradient.
  * A TEST WRITTEN FOR A BUG CAN READ THE HALF YOU ALREADY FIXED. See above.
  * A NEW TEST MUST PASS `theme: AppTheme.build(...)` TO ITS MaterialApp. A
    bare MaterialApp renders in stock Material's type scale and font — a
    measurement of text this app never draws. The release guard
    `test-renders-under-the-app-theme` catches it.
  * A BACKGROUND TASK HOLDING A FILE BLOCKS A LATER COPY TO IT. A Get-FileHash
    over SMB kept minelink-m3.apk open and the re-stage failed with "used by
    another process". Stopping the harness task did not kill the underlying
    pwsh — find it by CreationDate and Stop-Process. ⚠️ TWO long-running pwsh
    processes on this machine are JEAN'S VS CODE TERMINALS. Check CommandLine
    before killing anything.
  * CHECK WHETHER A TEST ALREADY PINS THE BEHAVIOUR YOU ARE ABOUT TO "FIX" —
    route_title_test.dart deliberately pins all four settled route names.
  * `loadRealFonts()` IS NOT ENOUGH — a TextStyle naming no family still
    resolves to the test fallback, whose glyphs are solid one-em boxes. Name
    the family. CLAUDE.md §7 and §10.5.
  * `Color.alphaBlend` KEEPS THE BACKGROUND'S ALPHA. Blending onto a 2%-white
    surface gives another 2%-alpha colour that looks solid in source.
  * `find.text` CANNOT SEE A TextSpan, and `toPlainText()` CANNOT SEE A
    TRUNCATION — use RenderParagraph.didExceedMaxLines.
  * A RepaintBoundary INSIDE A Scaffold DOES NOT CAPTURE A DIALOG — a dialog
    renders in the Navigator's Overlay, above it. Wrap the whole app.
  * `dart format` ON A DIRECTORY REFORMATS FILES YOU DID NOT TOUCH.
  * adb is at C:\Android\sdk\platform-tools and is ALREADY ON PATH. The old
    machine-wide handoff's %LOCALAPPDATA%\Android\Sdk path does not exist.
  * THE CONSOLE STORES THEME AND ACCENT PER ADMIN. Switching Jean's mode to
    Light writes to his account. Put it back.

WHEN THE WORK IS DONE: rewrite

    C:\Users\Somebody Someone\Music\SHOWME!\MineLink-M3\HANDOFF.md

the same way this one was written — verified state only, nothing aspirational,
with a fresh self-contained copy-paste block in §8 that carries BOTH handoff
paths (this one and C:\Users\Somebody Someone\Claude\HANDOFF.md), the project
root, the untouchable worktree path and its baseline, exactly where you
stopped, what is already done so it is not redone, what is left, this same HOW
TO WORK instruction from Jean, and the fix-as-you-go-and-test-it rule — and
commit it. Update the commit count and the tip in it so the file does not
describe a state two commits behind itself.
```
