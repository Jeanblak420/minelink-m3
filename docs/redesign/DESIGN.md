# MineLink M3 — the design record

Started 2026-08-20.

This is the reasoning behind the redesign. It is not a summary of the code —
the code carries its own comments — it is the set of decisions, and what each
one cost or bought.

---

## 0. The brief, and how it was read

Jean's instruction, verbatim in substance:

> Redesign the app for all versions — mobile, web and Windows. Put it in a new
> folder outside the app root so I can see how everything looks and test it
> properly before deciding if I like it. Nothing whatsoever changes inside
> `worktree-2026-05-05T11-53-29`. The UI/UX for all of it should follow the
> super global admin's portal — the placement of everything and so on. Use all
> the latest and best Material Design 3.

Four answers were settled before any code:

| Question | Answer |
|---|---|
| Preview, or a real working app? | **A real working fork.** It runs against the live database, so layouts are judged against real companies, real tonnages and real names rather than lorem data. |
| How far does the look move? | **M3 Expressive, MineLink palette.** Navy chrome, `#22D3EE`, the three fonts — kept. Everything underneath — colour roles, shape, motion, components — rebuilt. |
| What order? | **Foundation first.** The theme, the tokens, the shell and the shared widgets change all 112 screens at once. Then the ~20 screens that matter, then the tail. |
| What happens when a button writes? | **It writes.** Jean chose no guard. This fork is the app, with a new skin. |

### The last one has a consequence worth stating plainly

There is no staging anywhere (`CLAUDE.md` §10.2). Every click in this project
does what it does in the real app: advancing a trip advances a real trip,
recording a load mints a real waybill, dispatching notifies real people on
real phones. That was Jean's explicit decision and it is recorded here, in the
README, and in the project's `CLAUDE.md` banner.

The one line drawn without asking: **`supabase/` is frozen.** No migration is
created, applied or pushed from this project. A redesign needs no schema
change, and a schema change from a design fork against a production database
with no staging is not recoverable.

---

## 1. The central problem: there were two colour systems

The shipping app seeded its Material `ColorScheme` from `MlTokens.teal700`
(`#0F6E8C`) — a colour that appears nowhere in the interface — and separately
maintained twelve hand-authored token files whose accent was `#22D3EE`.

Nothing reconciled them. `Theme.of(context).colorScheme.primary` and
`MlTokens.accent` were simply different colours. So every Material widget that
nobody had explicitly restyled came out teal on a cyan interface: switches,
sliders, the text cursor, the selection handles, progress indicators, date
pickers, the pull-to-refresh spinner.

The fix was always to restyle one more widget. That is why the token files kept
multiplying, and it is the single largest cause of the app not feeling like one
product.

**The redesign's core move is that the `ColorScheme` *is* the design system.**

- `MlScheme` writes both schemes out explicitly. Not `fromSeed`: the tonal
  algorithm desaturates a bright cyan seed considerably, and
  `docs/design-reference/` is the specification.
- `MlSemantic` stops being a parallel palette and becomes a *view* onto the
  scheme. Its thirteen values are derived, so a per-user accent or the
  high-contrast preference now reaches every component instead of the handful
  the console used to patch by hand.
- The navy chrome becomes `MlChrome`, a `ThemeExtension` — because the rail is
  navy in *both* themes and therefore cannot be a surface role, since those
  invert by definition. One type replaced five private palette files.

The practical test: **an unstyled Material widget dropped anywhere in the app
should now look like it belongs.** That is the difference between a design
system and a pile of overrides.

### What this structurally fixed

`#22D3EE` is a *light* colour. White text on it measures **1.9:1**, failing
every threshold there is. The shipping app worked around this with a separate
`inkOnAccent` constant (`#04222B`, 11.3:1) that authors had to remember to
reach for.

M3 removes the choice. In dark, the accent is `primary` and its ink is
`onPrimary` — that same near-black. In light, `primary` is `cyan700` (4.9:1 on
white) and the bright cyan lives on as `inversePrimary` and in the navy chrome,
where it sits on dark and is legible. Nobody has to remember anything; the role
name carries it.

`app_theme_test.dart` now measures this: `onPrimary`, `onSurface`,
`onSurfaceVariant` and `onErrorContainer` are all asserted ≥ 4.5:1 in both
themes, and a *chosen* accent is asserted legible at both extremes.

---

## 2. What "follow the super-admin console's UI/UX" was taken to mean

Not "restyle the portal to look like the console". That produces two things
that resemble each other until the next change.

It was taken to mean: **there is one shell, and every role renders it.**

The shipping app had:

| file | lines |
|---|---|
| `super_admin_shell_layout.dart` | 2,031 |
| `portal_scaffold.dart` | 1,239 |
| `portal_shell_layout.dart` | 763 |
| `minelink_sidebar_app.dart` | 1,412 |
| `minelink_sidebar_haul.dart` | 1,285 |
| `minelink_sidebar_weighbridge.dart` | 1,175 |
| `minelink_sidebar_core.dart` | 699 |
| `console_sidebar_bridge.dart` | 338 |
| `console_palette_tokens.dart` | 152 |
| **total** | **~9,100** |

Nine thousand lines rendering one list of destinations, five different ways —
and in the console's own rail, every destination was written out **twice**,
once for the expanded state and once for the collapsed one, kept in step by
hand.

Now: `MlNavNode` (the tree, as data) → `MlNavRail` (one renderer) →
`MlAppShell` (one shell). The console shell is 253 lines and the portal
scaffold is ~190, and both hold only what is genuinely about their audience.

### The breakpoints

The app had three, each invented for the screen that needed it and named for
what it did rather than what it measured: `sidebarBreakpoint` 900,
`dashboardWideMin` 800, `compactTableMax` 600. An 850px window therefore showed
a drawer (850 < 900) *and* a multi-column dashboard (850 ≥ 800) — a
phone-shaped navigation wrapped around a desktop-shaped page. Neither number
was wrong alone; they had no relationship to each other.

M3's window size classes are one ladder, and every adapting component uses the
same rungs:

| class | width | navigation |
|---|---|---|
| compact | < 600 | `NavigationBar` + modal drawer |
| medium | 600–839 | collapsed rail, tooltips, flyout groups |
| expanded | 840–1199 | full rail — the console look |
| large | ≥ 1200 | full rail, wider workspace |

All four read the same tree, so a destination cannot exist at one width and be
missing at another — which it could, and did, when the two rails were two
hand-maintained lists.

---

## 3. What the redesign found

These are defects in the shipping app that the rebuild surfaced. Each is fixed
here and each is now covered by a test.

### 3.1 Targets was unreachable from the default sidebar

`/super-admin/targets` is a registered route with a fully built screen —
`CLAUDE.md` §4 records it as 🟢 Built and says it belongs "under Insights" —
and `consoleNavRoutes` has mapped its three ids all along. The default rail
never listed it. The only ways in were a dashboard tile or switching to one of
the alternate sidebar skins.

Found by turning the rail into data and diffing the routes it names against the
routes the router registers. Thirty destinations written out twice by hand hid
a missing one; a list did not.

### 3.2 The portal's entire rail was invisible to screen readers

The routed child hosts a nested ShellRoute `Navigator` whose `ModalRoute`
carries `BlockSemantics`, which drops the semantics of everything painted
before it — and the rail and top bar paint first. The console had a
`Semantics(container: true)` boundary around its body for exactly this reason.
The portal never did.

So for every company user — mine supervisor, load controller, driver —
assistive technology saw no destinations, no menu button, nothing. The boundary
now lives in `MlAppShell`, so fixing it once fixed it for every caller.

### 3.3 A tooltip is not a semantics label

Measured on Flutter 3.44.8: an `IconButton` whose only text is its `tooltip`
produces a semantics node that `find.bySemanticsLabel` cannot address — for a
bare one in a plain `Scaffold` app bar as much as for ours. The control that
opens navigation on every phone screen announced itself as an unlabelled
button. Replaced with Flutter's `DrawerButton`.

Related, and the same class: `Semantics(label:)` without `container: true`
merges into a neighbouring node instead of creating one. Every rail tile and
group header now sets `container` plus an explicit label including the badge
count — "Disputes" followed by a bare "3" reads as a list position, not a
queue size.

### 3.4 A "mobile parity" test never ran at mobile width

`tester.binding.setSurfaceSize` does not reach `MediaQuery`. Measured:

```
setSurfaceSize(Size(400, 800))  ->  MediaQuery width == 800
tester.view.physicalSize = ...  ->  MediaQuery width == 400
```

So `SuperAdminShellLayout shows menu drawer control below 900px` never ran
below 900px. It ran at the default 800 and passed because 800 < 900 anyway — a
green test that proved nothing about the width in its own name, and it stayed
green through the whole shell rewrite until the M3 breakpoints put 800 in
`medium`.

Three files used that call; the other 25 layout tests already used
`tester.view.physicalSize`.

### 3.5 The type theme overwrote the families it had just assigned

`AppTheme._mlTextTheme` ended with `.apply(fontFamily: MlTokens.fontSans)`,
which flattens the *whole* `TextTheme`. Twelve tonnage figures the portal drew
as "Fraunces" were rendering in the UI sans, and nothing said so. Families are
now assigned per slot and never applied over the finished theme; asserted.

---

## 4. What was removed, and why removal was the honest option

**The three sidebar skins, and their selector.** Five rails offered as a
per-user preference, each a complete re-implementation of the same
destinations. A destination added to one and forgotten in the others simply did
not exist for the admins who had picked those — and §3.1 is that exact failure,
already in production. `ConsoleSidebarSkin` is gone from `UiPrefs`; a stored
`sidebar` key is read and discarded, so nothing migrates. Leaving the control
in Settings while the shell ignored it would have shipped a setting that does
nothing.

**"About" as a rail entry.** It called `showAboutDialog` — an action sitting in
a list of destinations, with no address, nothing able to link to it and no way
for the back button to return from it. Every leaf in the nav model carries a
route that resolves, and that rule is what keeps dead entries out of navigation
by construction. It moved to the top-bar overflow.

**"Search" as a rail entry.** Its `onTap` went to
`/super-admin/organizations` — the same address as the Organizations tile three
rows below it. A second entry point to one destination, wearing a magnifying
glass. The rail now has a real filter box that searches the tree itself,
including nested destinations, which is what that tile looked like it did.

**Six of the portal's nine top-bar controls.** The portal carried menu, back,
home chip, title, tour, theme toggle, two bells, profile and sign-out; the
console carried five. The four that are per-user actions moved into the
identity flyout at the foot of the rail, where the console has always kept
them, plus a top-bar overflow. Same reachability, one bar.

---

## 5. Decisions that went *against* my first instinct

Recorded because they are the ones most likely to be re-litigated.

**Groups start open.** I wrote them closed-by-default. P7-03 had already
settled it the other way and the portal's semantics tests encode it: a rail
whose groups start closed hides most of the app behind a click and makes the
tree look smaller than it is. The implementation moved to match the product.
The group holding the current route additionally cannot be closed — otherwise
the rail can be put into a state where nothing is highlighted while you are
plainly on a page.

**The group header carries the sum whether open or shut.** I had it show only
when closed, on the grounds that an open group duplicates numbers visible just
below. But it is the only figure that survives the group being scrolled past,
and a queue that disappears with a disclosure state is a queue that gets
missed.

**`MlTone`'s seven status hues are NOT derived from the scheme.** M3 supplies
exactly one semantic hue — `error`. These carry lifecycle meaning fixed by the
domain (blue = in transit, amber = at mine, green = loaded). Regenerating them
from a tonal palette would make "at mine" change hue when somebody picks a new
accent in Settings — a data-integrity problem dressed as a style choice. A
status hue is content, not chrome.

**The package name stays `flutter_application_1`.** Renaming means rewriting
imports across 520 files plus asset and test paths: real breakage risk, zero
design benefit. Only the Android `applicationId`, the app label, the Windows
binary name and the web title differ — the minimum needed for both apps to sit
side by side on the same machine and the same phone.

---

## 6. What is NOT true yet

Stated plainly so nothing here is mistaken for finished.

- **Phase 1 is the foundation only.** Every screen has changed, because every
  screen sits on the theme, the shell and the shared widgets. None of the ~112
  screens has been hand-rebuilt yet.
- **No spring motion.** Material 3 Expressive specifies it; Flutter 3.44.8
  ships no `MotionScheme` and no `ThemeData.motionScheme` — the material
  library's `motion.dart` contains `Durations` and `Easing` and nothing else.
  Cubic easing is what exists and what this uses.
- **The mine premium appearance directions no longer skin the rail.** They
  still skin the workspace. `MinePremiumPalette` does not carry an `MlChrome`
  yet; reconciling the directions into chrome variants is Phase 2. A mine on a
  premium direction currently gets its own workspace colours with the standard
  navy rail.
- **The driver's phone bar is still an override**, not derived from the tree.
  The driver's tree names the middle destination "My routes" rather than "Trip"
  and carries Live map and Compliance between them; deriving the bar today
  would silently relabel and reorder a driver's primary navigation, which is
  not a change to make as a side effect of a shell rewrite.
- **It has not been run on a physical phone or on iOS.** See the verification
  log for what has actually been executed.

---

## 7. Phase 2 — what looking at the screens actually found

Phase 2 was supposed to be "hand-rebuild the ~20 screens Jean lives in". The
screens were picked by measurement rather than opinion: every file in
`lib/features` was scored on the three things that are genuinely drift — type
re-specified instead of taken from the scale, corner radii written as numbers,
and motion built from a bare `Duration` and `Curves` constant. 161 files score
above zero; the top of that list is where the work started.

**The first correction was to the ranking itself.** The initial score also
counted hand-rolled `BoxDecoration`s, which put `chat_dock.dart` far in front —
6,149 lines and 69 classes in one file, an entire chat application, mounted on
every screen in the product by both shells. Reading it before touching it
showed its 56 decorations are not drift at all: they read `ChatPalette`, which
is **eighteen user-selectable chat themes**, deliberate, already reasoned
about, and correctly filed in the token layer. Scoring colour as drift was
wrong, and it was wrong about the single biggest file.

### What the top of the list actually contained

Not styling. On `/super-admin` — the platform admin's landing screen — four
figures were **literals**:

| what it said | what was true |
|---|---|
| `This month · Jul 2026` | written in July, still reading July in August, heading a section titled *"Live operations … this calendar month"* |
| `… open · 2 aging > 24h` | `MlPendingRequest` carries no timestamp; nothing on the screen could ever have known it |
| `Last 24h · +2 companies, +14 users` | a fake copy of a number the code already had — the view model reads `stats['newCompanies24h']` and puts it on the tiles as a delta |
| `3 companies need approvals … oldest 5 days waiting` | the banner took **no data at all** and rendered unconditionally, so a platform with nothing expired saw a standing amber alert |

The view model directly beside them is scrupulous — its own doc says a figure
with no source is *"left blank rather than filled with a plausible number"*,
and it does that, eight tiles' worth. **The discipline was applied to the data
layer and skipped in the view.** That is the pattern worth remembering: the
place a rule is written down is not the place it gets broken.

A fifth turned up when a guard was written for the first four:
`MlFlagshipTrend` defaulted `monthLabel` to `'Aug'`, and not one of its three
call sites passes it — so the crosshair tooltip on the buyer, mine and
transporter dashboards labelled every point `AUG NN` whatever the date. It
reads correctly for one month a year, which is exactly why it survived: it was
written in August and looked right.

### The layout half: one fault, twenty-one times

Every layout defect Phase 2 has found so far is the same one, and it is already
written down in `CLAUDE.md` §10.4: **a `Row` hands a non-flex child unbounded
width**, so that child's own `overflow: ellipsis` can never engage and the row
simply overflows. It appeared as:

- a four-column table asked to fit a phone (the console's org list)
- chips inside a `Wrap`, which lays children out against unbounded width too —
  so a chip wider than the `Wrap` does not wrap, it overflows, and `Flexible`
  cannot help because there is no free space to flex against
- `MlSectionHead` and `MlSectionTitle`, the two shared section headers, whose
  trailing blocks are unflexed *on purpose* (a short right-aligned block given
  `flex: 1` lands mid-row) and therefore cannot shrink when they must
- fourteen screens wrapping `MlPageHeader` / `MlSectionTitle` in a `Row` to put
  a button beside it, when both components already have a slot that drops the
  action under the title
- `MlRailIdentity` drawing its 280dp layout inside an 80dp rail

The last one is the most interesting, because it was not a layout mistake at
all. `MlAppShell` computes the rail's width from the caller's preference **and**
the window class, but `railHeader` / `railFooter` are pre-built widgets whose
own `expanded` came from the preference alone. Two sources of truth for one
fact, and the widgets read the one that was wrong. `MlRailScope` publishes what
the rail actually did.

### Why none of this had been seen

`super_admin_overflow_sweep_test.dart` renders nine console screens across six
widths and six text scales and reports that each "survives every width x text
scale". **Its narrowest width was 860.** So every console screen was unrendered
on every phone and most tablets while the suite said otherwise. The portal's
own sweep reached 360px but stopped at text scale 1.3, while the shells compose
the in-app slider with the platform's and cap at 2.0 — leaving every size
between them unrendered.

Both sweeps also built their test app with `ThemeData(brightness: dark)` rather
than `AppTheme`. That is stock Material's type scale in stock Material's font
family: a measurement of text the app never draws. It was harmless while every
component hard-coded its own `TextStyle`, and stopped being harmless the moment
the components started taking type from the theme — which is the whole point of
one design system.

**A green sweep over the wrong widths, in the wrong font, is the same class of
thing as a hardcoded figure: something that reports a fact it never checked.**

---

## 8. Making it look like one product

Phase 1 built four primitives — a `ColorScheme`, `MlShape`, `MlMotion`, a
`TextTheme`. Phase 2 found that almost nothing used them, and that in three
cases a *second* system was quietly competing with each.

### The census, and what it settled

| | before | after |
|---|---|---|
| corner radii in `lib/` | **24 distinct values** over 320 sites | 7 scale steps |
| font sizes | **37 distinct values** over 1,015 sites, ten of them half-points | 27, no half-points |
| type scales | **two**, 1px apart at the sizes that matter | one |
| names per typeface | **two** each | one each |

None of that is a matter of taste. `MlTokens.fsBodySm` was 13 and
`textTheme.bodyMedium` was 14, and both meant "small body text" — so two labels
on the same card could differ by a pixel depending on which constant the author
reached for. `MlGlass.sans` and `MlTokens.fontSans` were two string literals
naming one font, which means renaming a family in `pubspec.yaml` would have
fixed half the product and silently changed the typeface of the other half,
because **a Flutter `fontFamily` that does not resolve does not throw** — it
falls back.

### Which side wins, and why it is always the same answer

The theme. Every time.

`ColorScheme`, `TextTheme` and `ThemeData` are what a Material widget resolves
*without being told*. A parallel token file is only consulted by code that
remembers to consult it, so the moment one exists the product has two answers to
one question and no way to tell which a given widget got. Phase 1 made
`MlSemantic` a view onto the scheme for exactly this reason; Phase 2 did the
same for the type scale and the face names.

The tokens are kept as **names**, not deleted. `fsBodySm` reads better than
`14.0` at 96 call sites, and a name is what makes the next change one edit
rather than ninety-six.

### What a codemod may and may not do

Three passes were mechanical: radii onto the shape scale, half-points onto whole
points, tokens onto slots. Each ran over the whole tree, and each taught
something about the limits of that:

- **It may not edit prose.** The radius pass rewrote a doc comment that read
  *"Not `BorderRadius.circular(11)`"* — the sentence explaining the rule — into
  *"Not `MlShape.radiusMedium`"*, which no longer says anything. A codemod that
  edits documentation is worse than one that misses a site.
- **It may not reformat what it did not change.** Reading files with Python's
  default universal newlines converted CRLF to LF and turned a 340-line change
  into 5,342 insertions and 5,264 deletions. The real edit was still in there,
  where no reviewer would ever find it.
- **It must know what it is safe to change.** Snapping a radius cannot move
  geometry — Flutter clamps a corner to half the shorter side, so raising one is
  paint-only. Snapping a *font size* can, which is why the half-point pass
  rounded **up**: growing text can only cause an overflow, and the sweeps catch
  those; shrinking it makes something unreadable without making it look broken.

The remaining ~640 raw `fontSize:` literals were left alone on that last
principle. Consolidating them means moving 18px sub-headings to 16 or 22, and
that is a per-screen design decision that a blanket rewrite could easily get
wrong in a way that looks deliberate.

**Phase 3 did them, and the way it did them is the point.** See §9.

### The sweeps were measuring the wrong thing

Every layout defect in this phase was found by making a test render something it
had not rendered before, and there were three separate ways they were not:

1. **The console sweep stopped at 860px** — so no console screen had ever been
   rendered on a phone, while nine tests reported they "survive every width x
   text scale".
2. **Fourteen sweeps stopped at text scale 1.3**, while the shells compose the
   in-app slider with the platform's and cap at 2.0. Everything between was a
   size a real user could reach and nothing had drawn there. Raising them found
   seven overflows, none of which reproduce at or below 1.3.
3. **Twenty test files rendered under a bare `MaterialApp`** — stock Material's
   type scale in stock Material's font family. Harmless while every component
   hard-coded its own `TextStyle`; the moment they started taking type from the
   theme, those tests were measuring a rendering that does not ship.

All three are now guarded, because all three were invisible: each one reported
green about a thing it had never looked at.

---

## 9. Phase 3 — the type work, and what it cost to do properly

Phase 2 collapsed the *scales*. Phase 3 moved the product onto them: **902
hand-built `TextStyle` literals** across 150 files, rewritten to reach a slot.

### Why 900 sites were a defect and not a style preference

A `TextStyle` written from scratch carries only what is written into it.
`height` and `letterSpacing` are inherited from whatever `DefaultTextStyle` is
in scope — inside a `Scaffold`, that is `bodyMedium`. So this:

```dart
TextStyle(fontFamily: MlTokens.fontSans, fontWeight: FontWeight.w800,
          fontSize: 15, color: pal.bodyText)   // a conversation title
```

was drawn with **body** metrics: line height 1.43 where a title wants 1.27, and
tracking +0.25 where a bold title wants −0.1. It is *nearly* right, which is
exactly why nobody fixed it and why nine hundred of them accumulated. The
visible symptom was the one in the brief: line spacing differing between two
cards on the same screen.

### `MlText` — the scale as a screen reaches for it

```dart
style: context.mlText.titleSmall.copyWith(color: pal.headerText),
```

Fifteen M3 slots, **non-null**. `TextTheme`'s fields are `TextStyle?` and this
app never leaves one null, but the type system does not know that — so every
one of nine hundred call sites would have ended in a `!`, which is nine hundred
places a reader has to decide whether the bang is safe. Decided once.

### The serif had two jobs and the scale named one

`docs/design-reference.md` §3 gives Fraunces *"section titles, **and** every
large numeral"*. Only the numeral was on the scale: `display*` is 45/36/32 and
`MlType.figure` covers it. A Fraunces **section title** runs 16–26 across twenty
sites and had no rung at all, so every one was hand-written.

Three rungs at **24 / 20 / 16**, chosen so the sizes actually in use (16, 18,
19, 20, 21, 22, 24, 26) each move by at most 2px. Each shares the line box of
the sans title slot at its own size, so a serif title and a sans title on the
same row sit on the same baseline. Deliberately **not** tabular: `figure()` is
tabular because a numeral re-measuring every frame visibly jitters, and a title
is words.

The 28px boundary between the two jobs is a **measurement, not a rule**:
`tool/type_scale_codemod.py --audit-serif` prints both lists, and every site
below 28 is a title while every site at 28 and above is a hero figure.

### There was a fourth typeface

`kConsoleSans = 'Sora'`, alive at seven sites in the console's own dashboard
widgets. The design drop *did* set the console sans to Sora — but only half of
that override ever landed. `mlConsoleSans`, the rail's copy of the same string,
had already become dead code, so the rail ran Plus Jakarta Sans while seven
cards sitting inside it ran Sora. One screen, two sans faces, in a system that
has three.

Sora was never *chosen* over Plus Jakarta Sans here; it is the surviving half of
an override nobody finished. Retired from `lib/` and from `pubspec.yaml` — five
weights, 292 KB, in every web build and every APK. The `.ttf` files stay:
`reference_capture_test.dart` reproduces the drop and loads them straight off
disk with a `FontLoader`, which does not consult `pubspec`.

Three more sites named the family `monospace` — a *generic* family that Flutter
resolves to whatever the OS calls monospace, silently. A driver's trip
timestamp, a token preview and a generated serial token: three machine
identifiers, which is precisely what the brand mono exists for.

### The codemod's five refusals, each learned by running it

`tool/type_scale_codemod.py` rewrites only what it can decide, because the
failure mode of a type codemod is a screen that still compiles and now says
something slightly different about its own hierarchy.

1. **The pdf package's `TextStyle` is not Flutter's.** It ships a class with the
   same name and nothing else in common. A word-boundary match finds the
   qualified name happily, and the first run produced a `context.mlText` call
   prefixed by the pdf import alias, in files that have no `BuildContext` and
   never will — a PDF is composed off-screen. A lookbehind refuses a qualified
   name rather than guessing.
2. **`const` propagates.** Checking for a literal `const TextStyle(` is not
   enough: a plain `TextStyle(...)` inside `const Text(...)` is itself const.
   The tool computes the const spans in a file and skips anything inside one.
3. **The scale defines itself.** `lib/core/design/tokens/` and `app_theme.dart`
   are refused whatever glob is typed, because `lib/**/*.dart` is the obvious
   thing to type and it is the thing that would rewrite `MlTypeScale.textTheme`
   into `context.mlText.bodyMedium`.
4. **An import can be made dead.** Converting the last `MlGlass` site leaves
   `ml_surface_tokens.dart` unused, and `unused_import` is a warning — a clean
   `analyze` silently became a dirty one. Removal is derived by reading the
   imported file's declarations, with comments stripped, and is scoped to the
   token layer: a general unused-import sweep would delete imports whose only
   use is an **extension** method, which is never named at the call site.
   `context.mlText` is one.
5. **A serif below 14 is neither job.** It is the small companion to a numeral —
   a unit, or an italic sub-label beside a 28px figure. Snapping one onto the
   editorial floor of 16 grows it by a third and detaches it from the figure it
   belongs to.

### Where `context` did not exist — 32 sites out of 902

Twenty-nine were private helpers that took a *palette* but no context, and whose
callers all had one; they simply never needed it, because a hand-written
`TextStyle` needs nothing from the tree. Context was threaded in. Three of them
shared the name `_row` across three classes in one file, which is the single
case where threading by grep would have been wrong.

The other three are `CustomPainter.paint()`, which has no `BuildContext` by
construction. They use `MlType` directly — the same arrangement
`MlSemantic.from(Brightness)` has beside `MlSemantic.of(context)`.

### Sixteen half-points that the guard could not see

`no-half-point-font-size` matched the literal `fontSize:` and nothing else, and
that is not the only way a size reaches a `TextStyle`. On the day the product
was described as having no half-points, sixteen were alive behind two other
shapes:

- a **parameter default** — a 9.5 in a map painter, a 10.5 on `MlCap`, a 10.5 on
  a transporters-overview primitive;
- a **named argument to a type helper** — `MlOv` ships its own `s()`/`m()`
  rather than reaching the theme, so its callers pass `size:` and never write
  `fontSize` at all.

The guard matches the **name** now — `fontSize`, `fs`, `textSize`, `size` —
rather than the constructor.

### Five layout defects, each found by a sweep and worth its diagnosis

- **A compliance chip, 9px at 1024 × 2.0.** The label moved onto `labelMedium`,
  whose letterSpacing is 0.5 where the site had been silently inheriting
  `bodyMedium`'s 0.25. Eighteen characters × 0.25 × 2.0 = 9. The tracking is the
  slot's and is right; the chip having no slack at all was the fault. Five pills
  in that file shared the rigid shape.
- **A `DropdownButton`, 31px at 430 × 1.6.** It lays its selected item out at
  natural width unless told otherwise **and** sizes to the widest item in the
  list, so one long option decided the control's width whatever was selected.
  CLAUDE.md §10.4 records this for `DropdownButtonFormField`; the plain one has
  it too.
- **The platform dashboard, 3.4px at 360 × 2.0.** An org-type pill and a seat
  count in one Row. The pill is the part that can afford to give — but it could
  not, because `MlPill` had no `maxLines` and no overflow behaviour, so a
  bounded width would have made it overflow internally instead. The component
  was fixed first, then the call site.
- **The targets tabs, 131px.** Their label moved 13 → 14. The note beside them is
  explicit that nothing there can ellipsize without destroying the meaning, so
  the label **wraps** instead.
- **The org-type targets screen, 60px on the BOTTOM.** Not horizontal for once.
  An unflexed child of a `Column` does not shrink, and at text scale 2.0 the
  band is taller than the viewport on its own. Fixed as a *shape*: `TargetsPage`
  now owns the band-plus-body column for all three targets screens and caps the
  band at half the viewport with an internal scroll. The other two do not
  overflow today and use it anyway — the shape is the fault, not the one screen
  that crossed the line first.

### What is deliberately left, and the measurement behind it

**128 sites still name a typeface**, held by the `typeface-named-by-hand`
ratchet. They are three different things and none of them is an oversight:

- **`const` literals.** `Theme.of` is not a constant, and a const style with no
  colour *deliberately* inherits the ambient ink — swapping it for a theme slot
  would take `onSurface` and get the colour wrong inside a filled button or a
  chip. That is a worse fault than the drift, which measures like this (a stated
  size under `bodyMedium`'s inherited 20/14 ratio):

  | size | inherited box | scale box | delta |
  |---|---|---|---|
  | 11 | 15.7 | 16.0 | −0.3 |
  | 12 | 17.1 | 16.0 | **+1.1** |
  | 14 | 20.0 | 20.0 | 0.0 |
  | 16 | 22.9 | 24.0 | −1.1 |
  | 22 | 31.4 | 28.0 | **+3.4** |

  85 of the 96 const sites that state a size are at 17px or below, so they sit
  in the ±1.4px band. Of the eleven at 18px and up: two are `TextSpan`s inside a
  parent span that already states the metrics, so they drift by **zero**; two
  are `TextField` styles; the rest are single-line figures, an avatar's initials
  and an emoji-picker glyph. None of them is a paragraph.
- **`MlOv`'s `s()`/`m()`**, a byte-for-byte port of an external drop that ships
  its own type function.
- **`CustomPainter.paint()`**, per above.

The ratchet can only shrink. It is deliberately not a block: turning it into one
today would mean making one of those three changes for the wrong reason.

---

## 10. Phase 4 — photographing the rest, and the two "cosmetic" items measured

Phase 4 continued §4.3 of the handoff: add a screen to the render harness, look
at the PNG, **measure it rather than squint**, fix the shape where the fault is
structural, pin it, and prove the pin bites. Renders went **25 → 36**.

Every screen photographed turned up a real defect, and the pattern in almost all
of them is the same: **the fault was a layout that FITS.** An ellipsis, a wrapped
word, a truncated label and a mislabelled figure are all perfectly valid
layouts. Nothing raises. No overflow sweep fails. The only instrument that sees
them is a measurement of the painted result — `didExceedMaxLines`, a paragraph's
height against a one-line reference, or a rect.

### 10.1 The two items the Phase 3 handoff left as "known cosmetic"

Both were listed as things to fix. Measuring turned one into a real, systemic
fix and the other into a non-defect — which is the point of measuring.

**"The hub hero cards' accent border reads heavier than the console's
equivalent." — NOT A DEFECT.** Measured by finding every long horizontal run of
dim cyan in both images and comparing the composited pixel:

| | accent-border pixels |
|---|---|
| `docs/design-reference/super-admin-dashboard-dark.png` | (12,54,68) (13,59,73) (11,50,64) (18,59,77) |
| `screen-communications-hub-desktop-dark.png` (hero cards) | (15,51,70) (16,54,72) |

The same range. The full-strength accent is also identical — `#22D3EE` appears
literally in the reference (`portal-mine-dashboard-dark.png`, y=487) and in our
renders. There is nothing to fix, and saying so is worth more than an adjustment
nobody could justify afterwards.

**"The buyer light dashboard's canvas gradient is a much stronger step than the
dark one." — REAL, and bigger than it looked.**

Measured, the dark canvas is flat and the light one carries a base, two radial
brand washes and a 24px dot grid. That much was by design. What the measurement
also found is that **the console's own page is neither of them**:

| surface | dark | light |
|---|---|---|
| `docs/design-reference/super-admin-dashboard-*.png` | `#060B15` flat | `#EEF2F8` flat |
| `docs/design-reference/portal-components-light.png` | — | `#F8FAFC` flat |
| `mlConsoleCanvas*` (the shell painted this) | `#070C17` | `#E0E7F0` + washes + dots |
| `MlControlRoom.pageBg` (every v2 console screen paints this) | `#060B15` | `#EEF2F8` |

A 136×140 patch of the light reference's margin holds **exactly one distinct
colour**. `docs/design-reference.md` never mentions a dot grid or a wash.

So the console covered its own shell canvas with a flat page, and only the
portal ever showed the texture — which is precisely why the buyer's light
dashboard read as a different product from the console beside it. In dark the
two bases differ by one RGB unit and nobody could see it; in light by 14 units
of luminance.

Two changes, both narrow:

- `mlConsoleCanvasDark/Light` now **forward to `MlGlass.bg0`** — the value the
  reference shows and the value every v2 console screen already paints —
  instead of re-stating a fourth opinion. Same pattern `MlControlRoom` uses for
  its shared keys, and for the same reason.
- **The texture layer is off by default.** It is not deleted: it stays in
  Settings → User Preferences and a stored `true` still wins. It is off because
  no reference image has it and no admin has ever seen it.

Verified after: a margin patch of `console-desktop-light`, `dash-buyer-desktop-light`
and the reference all hold one colour, and it is the same colour.

### 10.2 What the newly-photographed screens turned up

| screen | what the picture showed |
|---|---|
| security gate | KPI chips reading "Incoming Tod…" / "Departed Tod…"; and "Incoming Today" was not scoped to today at all, while "Departed Today" 10px away was |
| weighbridge | section heading "Trucks at Mine — Ready for Lo…"; the recon table with no scrollbar |
| every phone screen | the bottom navigation bar clipping wrapped labels in **10 of 12 trees** |
| combined recon table | header reading "DELIVER / ED", "VARIAN / CE", "PO / D" — Flutter breaking inside words |
| combined recon table | five period-total cards showing an icon and the letters D, W, M, Y, T, with the tonnage ellipsised away |
| mine reconciliations | one load reported as `0.42 t` on the stat card and `−0.42 t` in the row beneath it |
| margin ledger | `R 141,306.00` rendered as the single character `R` |
| org insights | a row labelled **On-time** fed the waybill-completion rate — 91% where the measured figure was 30% — and 0% where the model demands a dash |
| driver navigation | a crash, a HUD breaking every word, "In 0 m", and the destination named twice with the first copy truncated |

### 10.3 The shapes that changed, rather than the instances

- **`MlColumn.minWidth`.** Flex weights say how space is *shared*; they say
  nothing about how much there has to be. A cell holding an `MlPlatePill` is
  114px of fixed content, and a `Row` hands a non-flex child unbounded width —
  so a 90px column does not squeeze a plate, it overflows behind it. Seven
  tables put a plate in a cell. `MlDataTable` widens its scroll minimum until
  every declared minimum is met, **scaled by the live text scaler**: the first
  version took the number literally and overflowed by 18px at scale 1.3 on six
  screens, which is the same fault as the bottom bar's fixed height.
- **`MlDataTable` headers get two lines**, so a header wraps at its space or
  slash instead of losing words.
- **`MlSectionTitle` gets two lines**, for the same reason at ~32 sites.
- **The bottom navigation bar computes its height** from the label style and the
  text scaler instead of the constant 72 the theme carried. 72 is exactly one
  line of label, and `NavigationBar` does not ellipsize.
- **`routingServiceProvider`.** `RoutingService()` was constructed at the call
  site, so the driver's navigation screen could not be handed a route by
  anything. Same seam, and the same reasoning, as `FleetNotifier.start()`.
- **`MlTime.debugClock`.** Every time in this product already goes through
  `MlTime`, so one hook freezes the clock for the whole render harness. Written
  because the navigation HUD prints an ETA and its golden could never match
  twice; it settles every screen with a relative date or a countdown.

### 10.4 The sweep had been passing over empty states

`portal_overflow_sweep_test.dart` renders every portal screen with **no data**,
27 corners each, and says so in its own header. That is half a job, and the half
it misses is the half with tables in it: with no rows there is no plate to
overflow. A second pass now sweeps sixteen screens with the capture fixtures
installed. It found **seven failing screens immediately**, at 360px.

### 10.5 One shape accounts for three of the last four defects

A table of `Expanded` columns with no minimum. It is not an overflow and it is
not a crash — it **compresses**, and compression is a layout that fits.

| screen | what it did |
|---|---|
| organizations registry | four columns, ~70px each at 412px. Every cell truncated: "Iron …", "MI…", "10…". A registry where no column can be read is a **blank** registry, not a narrow one. |
| targets · All months | ATTAINMENT had 118.8px for content needing 154.9 — a bar, `117%` and a `SURPASSED` badge. The locked TARGET field had 46px for 55.2. 22 overflows on one screen. |
| targets · Target history | five flexed columns plus a fixed 116px badge column. At 360px the attainment cell had 44.2px for a `117%` needing 54, with the bar squeezed to nothing — a percentage with a blank space where its meter belongs. It fit at 412 by a hair, which is why the first pass missed it. |

All three now go through **`MlWideTable`**, and this is the rule that came out
of it: **the `minWidth` is derived, never picked.** Take the widest cell's
content, divide by that column's share of the flex total, add any fixed
columns, and multiply by the live text scaler —

```dart
double _minWidth(BuildContext context) {
  const attainmentCell = 212.0;      // bar 56 + 10 + pct 44 + 8 + badge ~94
  const attainmentShare = 36 / 100;  // its flex, over the row's flex total
  final scale = MediaQuery.textScalerOf(context).scale(12) / 12;
  return (attainmentCell / attainmentShare) * scale;
}
```

The scaler matters as much as the arithmetic. The console gives every admin a
text-size slider (`ConsolePrefs.textScale`) and the shell composes it with the
platform's, so a hard-coded minimum is correct at exactly one setting. This is
the same fault `MlDataTable` had in its first version, one layer up.

Two things it must NOT do. It must not scroll when the content fits — a
scrollbar over a table that fits is a promise of columns that are not there, and
each of these is pinned by a "does NOT scroll at 1600px" case. And the controls
that filter a table stay **outside** the scroll view: a filter that slides away
from the rows it filters is worse than a narrow one.

### 10.6 The band that ate its own title

`TargetsBand` put the screen's name in a `Flexible` and its two scope tags
unflexed. A `Row` hands an unflexed child its natural width, so on a phone the
tags took 190px and the title was cut to **"Plat…"** — four characters of
"Platform targets", beside decoration reading PLATFORM-WIDE and CYCLE LOCKED.

It is a `Wrap` now, and the order of sacrifice is the point: the scope tag
repeats what the title already says, and the lock state is said again on the
cycle card below, so the tags are what should drop to a second line. A `Wrap`
bounds a horizontal child to its own `maxWidth`, so a long company name on the
by-company screen still ellipsises — the fix does not cost the behaviour the
`Flexible` was there for.

