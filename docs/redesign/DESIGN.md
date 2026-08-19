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
