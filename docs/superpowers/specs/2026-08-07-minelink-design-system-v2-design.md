# MineLink Design System v2 — standalone component library + new design-sync target

**Date:** 2026-08-07
**Status:** Approved by user (design conversation, this date)
**Owner repo (new):** `C:\Users\Somebody Someone\Music\minelink-design-system\`
**This spec lives in:** the Flutter app repo (the library repo does not exist yet)

## 1. Purpose

Create a brand-new, standalone design-system repo **outside the Flutter project root** that:

- is a **buildable React + TypeScript component library** (the current setup has no
  buildable design-system package — the design lives only in a remote-authored
  claude.ai/design project),
- carries a **fresh visual redesign** of every MineLink surface (full screen parity),
  keeping only the brand anchors,
- becomes the source of truth for a **new** claude.ai/design cloud project
  ("MineLink Design System v2") via its own `/design-sync` configuration,
- has **no link to the old design project** (`9acfde5e-374e-4e39-9ce9-4026310c1c7c`) —
  the old project, and the Flutter repo's existing `.design-sync/` config pointing at
  it, are left untouched,
- serves the Flutter app's future through a **token bridge**: one token source
  generates both the CSS used by the React library and a drop-in Dart tokens file for
  the app.

## 2. Decisions locked with the user

| Question | Decision |
|---|---|
| Scope of the new project | Component library only — the Flutter app stays where it is |
| Design content | **Fresh design from scratch** — do not copy old components/tokens/templates |
| Brand | **Keep brand anchors** (cyan `#00B5D8`, navy chrome, Plus Jakarta Sans / JetBrains Mono / Fraunces); redesign everything else |
| Coverage | **Full screen parity** with the Flutter app, built in phases |
| Stack | React 18 + TypeScript + Vite (best fit for /design-sync + claude.ai/design), with a generated Dart token file for the Flutter app |
| Location | `C:\Users\Somebody Someone\Music\minelink-design-system\` — sibling of `SHOWME!`, fully outside this repo |
| Cloud project | Create **new** design-system project "MineLink Design System v2"; direction **repo-authored** (local repo is source of truth, pushes replace remote) |

## 3. Repository layout (new repo)

```
minelink-design-system/
  package.json              # npm; scripts: build, tokens, preview, check
  vite.config.ts
  tsconfig.json
  tokens/
    tokens.json             # SINGLE source of truth for all design tokens
    build-tokens.mjs        # generator: tokens.json -> tokens.css + ml_tokens_v2.g.dart
  src/
    tokens.css              # GENERATED — CSS custom properties, light + dark
    components/
      core/                 # buttons, cards, stat cards, pills/status badges, icon wells
      forms/                # inputs, dropdowns, date/range pickers, multi-PDF drop zone,
                            # signature field, map-picker frame
      navigation/           # sidebar, top bar, driver bottom nav, tab bars
      feedback/             # dialogs, toasts, empty states, notification items
      data/                 # recon table (date-grouping + Total Tons= footer),
                            # Day/Week/Month/Year/Total stat card row, stockpile fill bars,
                            # trip timeline, live-map frame, charts
    templates/              # full screens, one folder per role/surface (see §6)
  previews/                 # preview entry per component/template (variants, light+dark)
  dist/
    design-project/         # GENERATED design-project bundle pushed by /design-sync:
                            # self-contained HTML previews with first-line
                            # <!-- @dsCard group="…" --> markers, styles.css, manifest
  dart/
    ml_tokens_v2.g.dart     # GENERATED — Dart tokens for the Flutter app
  .design-sync/
    config.json             # NEW cloud project id; shape: repo-authored; push = replace
    NOTES.md                # curation rules + API quirks carried over (see §7)
```

## 4. Token system — one source, two outputs

`tokens/tokens.json` holds every token; nothing is hand-written twice.

- **Kept (brand anchors):** accent cyan `#00B5D8`, navy portal chrome family, font
  families Plus Jakarta Sans (UI), JetBrains Mono (codes/plates/tonnages), Fraunces
  (display accents).
- **Redesigned fresh:** neutral ramps, status hues (transit/atMine/done/warn/error/
  neutral/accent tone pairs with fg/bg + icon wells), spacing scale, radii, elevation/
  shadows, type scale, motion (durations/easings), layout constants — all with
  **light and dark** values.
- **Generator outputs** (run via `npm run tokens`, committed):
  1. `src/tokens.css` — CSS custom properties, `:root` (light) + `[data-theme="dark"]`.
  2. `dart/ml_tokens_v2.g.dart` — mirrors the shape of the app's existing
     `MlTokens` / `MlSemantic` / `MlTone` classes so the Flutter app can adopt v2 by
     dropping the file into `lib/core/theme/` later. Generated, header-commented
     "do not edit by hand".

Naming in `tokens.json` uses one canonical camelCase name per token; the generators
derive kebab-case CSS names and Dart identifiers from it.

## 5. Component layer (fresh redesign)

Every component ships as: React component (typed props, variants) + a preview entry
rendering all variants in light and dark. Groups as in §3 `src/components/`. Domain
components reflect MineLink's real vocabulary (status pills use the tone system;
recon table implements DATE-only-on-first-row grouping and the auto `Total Tons=`
footer as pure presentation; stockpile fill bar shows `balance / cap` + loads-ready;
trip timeline renders the canonical `TripStatus` order). Components are
presentational only — no data fetching, no Supabase.

## 6. Screen templates — full parity, phased

Every screen in the Flutter app gets a fresh React template + preview. Build order:

1. **Phase 1 — Foundations:** repo scaffold, tokens + generators, preview/build
   pipeline, design-project bundle output, new cloud project created + first sync.
2. **Phase 2 — Auth:** login, forgot/reset password, WhatsApp OTP, mandatory-password
   gate.
3. **Phase 3 — Driver mobile:** Dashboard / Trip / Profile bottom-nav shell, Current
   Trip hero, navigation screen frame, POD flow, recent trips.
4. **Phase 4 — Mine/supplier:** dashboard, supervisor (stockpiles), weighbridge/load
   control (tare/gross/net + waybill), security gate (check-in/out), production,
   quality, recon tables + reconciliations, requests.
5. **Phase 5 — Transporter:** dashboard, fleet management, maintenance, trucks-on-route,
   accepted routes + allocation flow, recon.
6. **Phase 6 — Buyer:** dashboard, requests (route/product forms), loads & value,
   recon.
7. **Phase 7 — Super-admin console:** dashboard, four request inboxes, linking +
   due-diligence gate flow, margin ledger, available routes, marketplace, live map,
   combined recon, company mirror, org insights, user preferences.
8. **Phase 8 — Shared:** chat dock, notifications, profile (incl. signature),
   settings/preferences, common empty/error states.

Each phase ends with: previews pass the render check, sync push to the new cloud
project. The library is usable from Phase 1 — parity completes over time. Screen
inventory per phase is finalized against the app's `app_router.dart` during planning
(the list above is the authoritative granularity; the plan enumerates exact screens).

## 7. Design-sync wiring — the clean break

- Create the new cloud project with `DesignSync create_project`
  ("MineLink Design System v2"); record its projectId in the **new repo's**
  `.design-sync/config.json` with `shape: repo-authored`,
  `syncDirection: push-replace` (local builds replace remote design files).
- The old project `9acfde5e…` is never written to again from anywhere; the Flutter
  repo's `.design-sync/config.json` + NOTES stay exactly as they are (still pointing
  at the old project for historical reference — but no further runs push there).
- Carry over the hard-won API quirks into the new repo's NOTES.md: batch
  `write_files` by cumulative size (~6 MB), reserved paths (`CLAUDE.md` basename,
  `.claude/` segment), strict SVG XML sanitizer, `delete_files` exact paths only.
- Update agent memory (`design-sync-minelink-project.md`) so future sessions know:
  v2 project = repo-authored from the new repo; old project = legacy, read-only.

## 8. Relationship to the Flutter app

Nothing in this repo changes now. Future adoption path (out of scope here):
copy/point `ml_tokens_v2.g.dart` into `lib/core/theme/` and migrate screens
incrementally to the v2 look. The library never imports from or depends on the
Flutter repo, and vice versa.

## 9. Verification

- `npm run check`: TypeScript type-check + lint clean.
- `npm run build` produces the design-project bundle; every preview passes the
  render check (no blank/broken/identical-variant cards) before any sync push.
- Token generator round-trip: `tokens.css` and `ml_tokens_v2.g.dart` regenerate
  byte-identical from `tokens.json` in CI-style check (`npm run tokens -- --check`).
- After each phase's push: `DesignSync list_files` confirms the remote tree matches
  the local bundle.

## 10. Out of scope

- Rebuilding the MineLink app itself in React.
- A parallel Flutter widget package ("Flutter twin") — may be added later if earned.
- Migrating the Flutter app to v2 tokens/visuals.
- Deleting or modifying the old cloud project or the old local design snapshot
  (`docs/new system design/minelink-new-design-v0.1/`).
