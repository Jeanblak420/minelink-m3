# Phase 3 design-review brief (READ-ONLY reviewer)

You are reviewing screens of the MineLink **M3 redesign** against its design reference and reporting drift. You do NOT fix anything. Another session applies fixes from your report, one commit per fix, with tests.

## Hard rules — non-negotiable
- **READ-ONLY.** Do not edit, create, move or delete any file inside the repo. Do not run `git` commands that mutate (no add/commit/stash/checkout/reset/clean). `git log`, `git show`, `git grep` are fine.
- Do not run `flutter`, `dart`, Chrome, adb, or the phone tool. No browsers. No network.
- **NEVER write inside** `C:\Users\Somebody Someone\Music\SHOWME!\worktree-2026-05-05T11-53-29` (the shipping app). Reading it with `cat`/`sed`/`grep`/Read is fine and is REQUIRED before calling something drift (see below).
- Temporary files (e.g. a PIL crop script) go ONLY in your scratchpad directory (the one named in your system prompt). Run them with `py -3`. Set `PYTHONIOENCODING=utf-8`.
- Keep your tool output lean; your FINAL MESSAGE is the deliverable and must be self-contained.

## Where things are
- M3 repo: `C:\Users\Somebody Someone\Music\SHOWME!\MineLink-M3` (bash path `/c/Users/Somebody Someone/Music/SHOWME!/MineLink-M3`).
- Renders (what the redesign currently draws, PNG goldens): `docs/redesign/renders/*.png`. Their names and the widget each one renders are in `test/renders/redesign_renders_test.dart` (grep the golden name to see which screen/fixture/size produced it).
- The design reference: `docs/design-reference.md` (read §1–§5 IN FULL first) and the reference captures `docs/design-reference/*.png` — `super-admin-dashboard-dark.png` (registry language), `transporters-overview-dark.png` (analytics language), `portal-components-dark.png` / `-light.png` (the portal component vocabulary), `chat-states-dark.png`.
- Routes: `lib/core/routing/app_router.dart` (`/portal/mine/*`, `/portal/buyer/*`, `/portal/transporter/*`, `/portal/driver/*`, `/home`, auth routes). Screens: `lib/features/portal/screens/`, `lib/features/operations/screens/`, `lib/features/company/screens/`, `lib/features/employee/screens/`, `lib/features/auth/screens/`, `lib/features/profile/`, `lib/features/chat/`, `lib/features/notifications/`.
- Shared components the reference vocabulary is built from: `lib/core/design/components/` — `MlPageHeader` (page title: Fraunces, optional description, right-aligned meta, actions), `MlSectionTitle` (section heading: Fraunces, icon, subtitle, right meta, `View →` link, action), `MlStatusBadge.toneForStatus`, `MlCard`, `MlButton`, `MlEmptyState`, `MlWideTable`; tokens in `lib/core/design/tokens/`.
- Images: use the Read tool on a PNG to look at it (a tall PNG is downscaled — crop bands with PIL and Read the crop when a detail is in doubt). Example crop helper you may write to your scratchpad:
  ```python
  from PIL import Image; im=Image.open(src).convert('RGB'); im.crop((x0,y0,x1,y1)).save(out)
  ```

## The nine drift classes the console pass found (check these FIRST, in this order)
1. **Hand-rolled sans titles/headings** where `MlPageHeader` / `MlSectionTitle` exist — a page title or section heading drawn with `Text(..., titleLarge/titleMedium/headlineSmall ... w700/w800)` in PlusJakartaSans instead of Fraunces. Grep the screen for `fontWeight: FontWeight.w800`/`w700` on title-sized text and for `headlineSmall`.
2. **A card's actions riding in the title Wrap** instead of right-aligned (buttons inline after a title, or stranded at the far left).
3. **Title case or a misplaced possessive** in labels — the reference is sentence case everywhere ("Total companies", "Register company", "Export snapshot"). "Recent Loads", "Mark Arrived", "Request's Tracking Logs" are drift. Product names are NOT ("Operations Hub", "Global Admin", "Mine Control", "Mine Security", "MineLink"). ALL-CAPS micro-labels/column heads are the reference's own tell, not drift.
4. **A `Wrap` sizing to its content** (so `spaceBetween` does nothing) or a `Flexible` trailing block landing mid-row instead of at the right edge. Look for meta lines / `View →` / counts that sit in the middle of a row rather than flush right.
5. **Tone** — a status that falls to neutral where a tone exists; red used for a downward trend (should be amber); a second accent colour; low-contrast ink.
6. **A fixture that lies** — a render whose fixture data contradicts the tab/filter it is shown under, or a screen that renders an error/empty state in its golden when the fixture should populate it.
7. **Legal line breaks** the legibility tests allow — a label breaking at a hyphen/space mid-token ("TIME-" / "IN", a plate "CK 84 RT" / "GP"), headings ellipsised.
8. **Charts** — label collisions (a caption under a pill, a tick into "Today").
9. **Nondeterminism** — anything that could render differently run to run (async images, clocks not frozen). Lower priority for you.
Plus the general rules in `docs/design-reference.md` §5: both themes, one accent, Fraunces numerals / JetBrainsMono figures / PlusJakartaSans labels, every section with a header + meta line, left accent bar carries tone, survives text scale, empty states say so.

## Already fixed this session — do NOT report these
- Portal dashboard section heads (`SaSectionHeader`) meta/`View →` sitting at two-thirds of the row → now flush right (all three portal dashboards).
- The flagship tons-out chart's `TARGET` caption colliding with the period pill (all three dashboards).
- Security gate screen: hand-rolled title, two sans section headings, title-case labels.

## Known-deliberate, do NOT report
- Mono snake_case stat-card captions (`across_4_org_types`) — the reference's texture.
- The recon table's full gridlines (Excel-style by design).
- Product names: "Operations Hub", "Global Admin", "Mine Control", "Mine Security".
- The chat composer showing the raw `@[Name](user:uuid)` token while typing (the shipping app does the same).
- Buyer/mine insights + company mirror in the v1 analytics language (a decision for the client).
- Screens that have only a dark render — review what exists; note "no light/phone render" in the table, don't invent one.
- Renders that show an error/empty card ONLY IF the render test deliberately captures that state (check the test's comment).
- A 520px centred column on Security/gate-type screens (inherited from the original, phone-first).

## BEFORE calling anything drift: check the ORIGINAL
The shipping app at `C:\Users\Somebody Someone\Music\SHOWME!\worktree-2026-05-05T11-53-29` has the same screen file under the same path. If the original has the identical string/layout, SAY SO in the report ("original: same") — it is still drift against the reference (the redesign is allowed to differ from the original), but the fixer needs to know. If M3 differs from the original AND from the reference, say "original: differs — <how>".

## Output format (your final message — nothing else matters)
1. A table, one row per route target in your scope:
   `| route | render file(s) looked at | verdict | notes |` — verdict is `reviewed, no drift` or `drift: <short list>`.
2. Then a numbered **findings** list. Each finding:
   - **Screen / route** · **render** (file + the y-band or region, e.g. "y≈380–420, right half")
   - **What is wrong** (one sentence, concrete — quote the label, name the widget)
   - **Class** (1–9 or §5 rule)
   - **Cause in code**: `lib/...dart:line` (the exact widget/string)
   - **Original**: same / differs
   - **Suggested fix** (one line; name the shared component if one applies)
3. A short **"looked at and NOT drift"** list (things you considered and rejected, with why) so the fixer does not re-derive them.
4. Any render that is MISSING for a route target in your scope (no PNG at all) — list the route.
Be precise and skeptical. A wrong "drift" costs a fix-and-revert; a missed one costs the user. Quote exact strings. Give line numbers.
