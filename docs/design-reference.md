# MineLink design reference — the super-admin console

**Established:** 2026-08-14, by client instruction — *"check how the super global admin's complete dash
and transporters overview looks and use that as reference to continue forward."*
**Reference screens:** `MineLinkDashboardScreen` (`/super-admin/dashboard-v2`) and
`TransportersOverviewBody` (`/super-admin/transporters-overview`).
**Reference images:** regenerate with `flutter test --run-skipped test/widgets/reference_capture_test.dart` →
`docs/design-reference/*.png` (committed). Rendered with the **real fonts loaded**, because `flutter test`
otherwise substitutes a fallback face in which every glyph is one em wide (CLAUDE.md §7) — a capture
in that font would misrepresent every text width in it.

This file is the target for **S5-6 … S5-22**. Where a checklist gate and this file disagree, the
disagreement is called out below rather than silently resolved.

---

## 1. What the reference actually is

Read off the rendered screens, not off the design drop:

- **Dark-native, but genuinely dual-theme.** Both captures are real: the light variant is a proper
  inversion (canvas `#EEF2F8`, white panels, ink `#0F172A`-ish), not an afterthought. Any migrated
  screen has to survive both. `MlGlass.of(context)` / `MlOv.of(context)` pick the variant.
- **Information-dense and quiet.** Small type, tight rhythm, thin hairline borders, generous internal
  padding. No drop shadows doing decorative work; elevation is carried by surface lightness.
- **Colour is semantic, never decorative.** Every hue on the screen means something.

## 2. Palette

### The one interactive accent

| role | dark | light |
|---|---|---|
| **accent** | `#22D3EE` | `#0891B2` |

`MlGlass.accent` and `MlOv.acc` already resolve to the same value, and
`reference_capture_test.dart` asserts that equality so the two surfaces cannot drift apart.

**This settles S5-5.** The four competing values were `#2563EB`, `#6AB8FF`, `#22D3EE`, `#00B5D8` —
all four are the *same role* (interactive/brand) expressed four ways, which is why collapsing them is
correct. **`#22D3EE` wins because it is what the reference renders.** Note this overrides CLAUDE.md
§5, which calls `#00B5D8` "brand cyan"; the reference is the newer authority by client instruction.

### The semantic tones — NOT to be collapsed

These are a different axis and S5-5 does not touch them:

| tone | dark | means |
|---|---|---|
| good / active | `#34D399` | healthy, live, complete |
| warn | `#F59E0B` | expiring, pending, needs attention |
| bad | `#F87171` | expired, suspended, error |
| violet | `#A78BFA` | buyer org type |
| pink | `#F472B6` | secondary series |
| slate | `#64748B` / `#334155` | inert, muted, disabled |

**Collapsing these would destroy the screen's meaning.** On the registry row, orange/cyan seat bars
and the MINE / BUYER / TRANSPORTER badges are the fastest read on the page.

### Canvas and surfaces

| | dark | light |
|---|---|---|
| canvas | `#0A1120` (`bg0` `#060B15`) | `#EEF2F8` |
| panel | `#0E1728` | `#FFFFFF` |
| panel raised | `#0F1A2E` | `#FFFFFF` |

## 3. Typography — three faces, three jobs

| role | family | used for |
|---|---|---|
| **display** | **Fraunces** (serif) | section titles, and **every large numeral** — `24`, `186`, `171,240` |
| **body/UI** | **PlusJakartaSans** | labels, descriptions, buttons, table text |
| **mono** | **JetBrainsMono** | codes, timers, tonnages, counts, machine-ish captions |

The mono face carries a distinctive tell in this design: sub-captions render as
`across_4_org_types`, `tokens_valid · 100%_up`, `action_needed`, `manually_held`,
`signed-in · last_5m` — lowercase, underscored, monospaced. That is a deliberate texture, not a bug.

Countdowns (`42d 08 : 34 : 55`) and tonnages (`55,340 t`) are mono so digits align down a column.

> ⚠ **CONFLICT WITH S5-6 — flagged, not silently resolved.** S5-6 reads *"One UI sans **(Sora)**"*.
> The reference does **not** use Sora for UI text: both `MlGlass.sans` and `MlOv.sans` are
> `PlusJakartaSans`. Sora appears only as `mlConsoleSans`, the **console chrome/rail** face — the
> sidebar, not the screens. Following the gate would restyle every screen away from the reference the
> client just designated. **Recommendation: amend S5-6 to "PlusJakartaSans for UI, Fraunces for
> display numerals, JetBrainsMono for figures; Sora stays the rail face."** Needs the client's word.

> ⚠ **S5-7's PREMISE IS WRONG.** It states `FontFeature.tabularFigures()` is used by **none** today.
> There are **17 usages**, and `MlOv.mono()` applies it centrally, so every figure drawn through the
> reference's own mono helper already has it. The real work is extending that to the portal, not
> introducing it.

## 4. The component vocabulary

Every migrated screen is assembled from these. They already exist on the reference screens; S5-13
merges the duplicates into one set.

**Section header** — the pattern S5-22 asks for, visible five times on the dashboard:
```
Platform registry                          Last 24h · +2 companies, +14 users
Companies, users and throughput — …                        Export snapshot →
└ Fraunces title   └ PlusJakartaSans meta line    └ right meta   └ action link
```

**Stat card** — tinted icon well (rounded square, top-left) · delta chip (top-right, e.g. `2 · 24h`,
`83% healthy`, `unchanged`) · large Fraunces numeral with optional unit · PlusJakartaSans label ·
mono sub-caption. **A coloured 3px bar runs down the left edge**, carrying the semantic tone.

**Org-type roll-up card** — title + subtitle, a 3-column mono figure strip (`TRIPS / TONS / FLEET`),
and a sparkline top-right tinted to the card's hue.

**Badge pill** — uppercase, tiny, tinted: `MINE` amber · `BUYER` violet · `TRANSPORTER` cyan · `NEW`.

**Filter chip row** — `All types 5` · `Mines 2` · `Buyers 2` · `Transporters 1`; selected chip takes
the accent tint.

**Data table** — uppercase mono column heads, hairline row separators, avatar + two-line identity
cell, inline progress bar, right-aligned actions.

**Notice bar** — left accent rule, icon well, title + meta, right-aligned action button.

**Quick-action row** — outlined pills with a leading icon; the first takes the accent.

### What the transporters overview adds

The dashboard is the *registry* language; the overview is the *analytics* language. Both are in scope.

- **Hero figure.** One number owns the screen — `29,240` in Fraunces at ~64px, the unit (`.5t`)
  trailing at small size, and a delta chip (`▼10.9%`) top-right. Any screen with a single headline
  metric should use this treatment.

  ⚠ **CORRECTED 2026-08-15. This bullet used to end "…with a cyan rule underneath it", and that
  rule does not exist.** What was under `29,240` in the capture was Flutter's **yellow double
  underline** — the marker it paints on every text run that has no `Material` ancestor. `_capture`
  built its tree as `MaterialApp(home: RepaintBoundary(…))`, and `MaterialApp` does not insert a
  `Material`; only `Scaffold` does. `_capturePortal` supplied one, which is why the portal captures
  were clean and the three console captures were not. Every text run in them carried the mark, and
  one instance of it was read as a design feature and written into this document as a rule migrated
  screens must satisfy. There is no such rule anywhere in `tons_moved_card.dart`. Harness fixed
  (a transparent `Material` in `_capture`), captures regenerated — **70.7% of the pixels in
  `transporters-overview-dark.png` changed.**
- **Uppercase letterspaced micro-labels** caption every panel and every figure:
  `FLEET DISTRIBUTION`, `TONS MOVED THIS PERIOD`, `PEAK DAY`, `AVG / DAY`, `TRUCKS ACTIVE`,
  `WAYBILLS DONE`, `PODS MISSING`, `15-DAY TEMPO`. `inkLo`. This is the strongest single tell of
  the design.

  ⚠ **CORRECTED 2026-08-15: they are PlusJakartaSans, not mono.** This bullet said "uppercase
  **mono** micro-labels", and since it also calls them the design's strongest tell, migrating 48
  widgets to mono would have driven the portal *away* from the console it is supposed to match.
  Three independent call sites say sans: `MlCap` → `MlGlass.sans`; `MlStat`'s label →
  `MlGlass.sans`; `15-DAY TEMPO` in `transporter_card.dart:155` → `t.s(...)`, and `t.s` is
  `fontFamily: sans`. Mono **is** used nearby, which is probably where the confusion came from —
  the chart's axis ticks (`t.m(size: 9)`) and every figure in a column are JetBrainsMono. The rule
  is the one already in §3: mono for figures, sans for labels. A micro-label is a label.
- **Exactly one accent card per screen.** The leaderboard panel is cyan-tinted (`MlOv.accentBase` +
  `accentCardShadow`); everything else is neutral glass. Emphasis is spent once, deliberately.
- **Rank rows** — numbered badge, name, mono tonnage, a thin progress bar and a share percentage.
  Rank 1 gets the accent treatment; the rest are neutral. An empty/zero row (`b man trans 0.0 t`)
  renders greyed rather than hidden — **the honest-empty rule again**.
- **Donut** with multi-hue segments and a centred `20%` + `UTILISED` caption; the legend is a
  two-column name/value list with a colour dot.
- **Status pills on entity cards**: `Active` green · `Idle` amber · `Top volume` cyan ·
  `50% PoD` red. Tone carries the meaning; the label never repeats the colour.
- **Per-row tempo sparkbars** — 15 small bars, accent-tinted, captioned `15-DAY TEMPO`. A row with no
  movement draws flat grey bars rather than nothing, so "no data" and "not rendered" look different.
- **Alerts list** — tone-coded icon well, bold title, one-line explanation, right-aligned date.
- **Negative deltas are amber, not red.** `▼10.9%`, `−11%`, `▼3,003 t vs. Jul`. Red is reserved for
  a fault (expired, variance, missing POD); a downward trend is a warning, not an error.

## 5. Rules a migrated screen must satisfy

1. Reads correctly in **both** themes — resolve through `MlGlass.of(context)` / `MlSemantic.of(context)`,
   never a raw literal (S5-18, S5-19).
2. **One accent**, `#22D3EE`/`#0891B2`. Semantic tones stay as they are.
3. **Fraunces for display numerals, JetBrainsMono for figures in columns**, PlusJakartaSans elsewhere.
4. Every section carries a **header with a meta line**, plus `View →` / filter row / export where the
   screen has them (S5-22).
5. Cards use the **left accent bar** to carry tone; the tone must mean something.
6. Survives **text scale 0.85–1.3 and bold text at three widths** — the console applies a per-user
   scale via `MediaQuery`, and rigid layouts break for real users (CLAUDE.md §10.4).
7. An empty state **says it is empty**. A dial with no target reads "Not set", never `0`.

## 6. Two routing facts that change what "the reference" means

Found 2026-08-14 while working against it, and load-bearing:

1. **`/super-admin` — the route a super admin actually lands on — builds the OLD v1
   `SuperAdminDashboardScreen`, not the v2 screen captured here.** The v2 dashboard is mounted at
   `/super-admin/dashboard-v2`, and **no nav entry points at it** (`consoleNavRoutes['dashboard']` is
   `/super-admin`). It is reachable only by typing the URL. The router says why:
   *"Mounted alongside the existing dashboard rather than replacing it, so both can be compared
   before switching."* **The switch was never made.** So the captured dashboard is the intended
   design, not the shipped one. **Client decision needed: promote v2 to `/super-admin` and retire
   v1, or re-designate v1 as the reference.**

2. **The transporters overview IS live.** `insights.transporters` → `/super-admin/insights/transporter`
   → `TransportersOverviewV2Screen`. What is captured here is what a super admin sees. Only the
   transporter org type was migrated in the 2026-08-09 drop; buyer and mine still render the older
   `SuperAdminOrgInsightsScreen`, so two visual languages are live side by side under one nav group.

## 7. Known gaps in the reference itself

Recorded so they are not copied forward as though intentional:

- The captured dashboard renders from **fixture data** (`test/fixtures/ml_sample_data.dart`), not live
  data. It is a faithful reference for *layout and treatment*; **its numbers are invented** and prove
  nothing about any KPI.
- ✅ **RESOLVED 2026-08-15 — the portal captures used to be pictures of ERROR states.**
  `portal-mine-dashboard-dark.png` and its siblings rendered "Could not load this / The server
  refused the request", because the capture ran with no backend and every data provider rejected.
  The files were named as though they were the screens, so a reader reaching for "the mine dashboard
  reference" got an error card, and S5-20/21 — which ask for a per-screen *visual comparison* — had
  no surface to compare against.

  `test/fixtures/portal_capture_fixtures.dart` now resolves them. The seam is the **provider**, not
  the service: every portal data provider is a `FutureProvider.family` reading a service, so an
  override on the provider skips the network without anyone implementing a service interface.
  **11 of 11 portal captures render content**, and the run prints that count so the number is beside
  the images rather than assumed.

  Two things about the fixture are deliberate. It is pinned to a fixed `kCaptureNow`, so
  regenerating produces the same pixels instead of a diff every run. And it is **not uniform** — one
  stockpile is over the 30 t collect threshold and one under, one truck is on route and one
  available, one load carries a quality penalty, one route has no spec. A fixture where every row
  looks the same hides exactly the states a design has to handle.

  **The numbers are invented and prove nothing about any KPI** — the same caveat the console
  fixtures carry, one bullet up.

  📌 It paid for itself on the first render. The mine dashboard's "Stockpile balance" card read
  **559 t of 290 · 193% of ordered cap** while the donut beside it read **100% · 290/290** — two
  widgets on one screen disagreeing about the same quantity. `balance` summed *every* pile including
  ROM production, and divided it by a cap counting only order piles; the donut then clamped the
  result to 100%, hiding which figure was wrong. Fixed. It was invisible for as long as the capture
  produced an error card.
- The transporters overview draws **no target line** until somebody sets one at
  `/super-admin/targets/org-type/transporter`. That emptiness is correct behaviour (see CLAUDE.md
  §4 — a hardcoded "Target 28.0k" is exactly what it replaced), not a rendering fault to fix.
