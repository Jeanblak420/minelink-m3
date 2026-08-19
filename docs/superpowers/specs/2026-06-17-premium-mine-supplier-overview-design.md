# Premium Mine/Supplier Overview — Design

**Date:** 2026-06-17
**Screen:** `lib/features/portal/screens/mine_supplier_portal_dashboard_screen.dart`
**Status:** Approved for spec review

## Goal

Replace the current plain 3-stat + 2-card Mine/Supplier overview with a premium, responsive dashboard matching the supplied mockup: a Tons-out summary, Stockpile levels, an Operations Hub tile, per-buyer cards, loading activity, and a Request-buyers action — built on the existing `PortalColors` theme, elevated with gradients, depth, animated counters, and grouped metric rows.

## Scope decisions

- **Data:** Wire everything that has a live source; stub the rest with clearly-badged placeholders. No DB migrations this round.
- **Visual direction:** Refined existing portal theme (cyan-on-navy `PortalColors`), not a literal mockup re-skin.
- **D / W / M / Y / T** = Daily / Weekly / Monthly / Yearly / Total time windows. Calculation + data source are **deferred** by the user — render structure with a "preview" badge and placeholder values for now.

## Live vs. stubbed

| Element | Source |
|---|---|
| Tons out (D/W/M/Y/T) | **Stub (preview badge)** — calc deferred by user |
| Stockpile levels (A/B/C/Total) | **Stub (sample / pending data source badge)** |
| Operations Hub tile | "Coming soon" styling, tappable → existing `/operations?tab=minerals` |
| Buyer cards: tons out | **Live** — sum of `transaction.quantity` grouped by `buyerCompanyId` |
| Buyer cards: download/view recons | **Live** — navigate to reconciliations (route/tab) |
| Buyer cards: generate invoice | **Stub** — "coming soon" snackbar/dialog (no invoicing backend) |
| Loading activity: incoming trucks | **Live** — count of in-transit/active trips |
| Loading activity: scheduled today | **Live** — count of trips with today's date |
| Request buyers | **Stub** — dialog/snackbar action for now |

All live values are derived in-screen from the existing `logisticsSnapshotProvider` snapshot. No new providers required (light grouping helpers only). Buyer company names resolved from a companies lookup (reuse existing partner-company resolution where possible); show top 3 buyers by tonnage with a "+N more" affordance.

## Layout (responsive)

Wrapped in `PortalScrollBody` (max width 1200). Three vertical zones; each grid collapses to a single column on narrow widths.

1. **Hero row (3 tiles):** Tons out · Stockpile levels · Operations Hub.
2. **Buyers:** section header + per-buyer cards (Tons out, Download/view recons, Generate invoice).
3. **Footer row:** Loading activity (incoming + scheduled today) · Request buyers.

Mirror mode (`portalMirrorActive`): action affordances (invoice, request buyers, operations navigation) are hidden/disabled exactly as the current screen suppresses feature cards.

## Components

New presentational widgets in `lib/features/portal/widgets/premium_overview_widgets.dart` (keeps the screen a thin layout + data-mapping shell):

- `OverviewHeroTile` — titled panel with gradient/elevation and a body slot.
- `MetricBreakdownRow` — label + animated value (used for D/W/M/Y rows and stockpile bins).
- `AnimatedMetricValue` — `TweenAnimationBuilder`-based counter helper.
- `BuyerOverviewCard` — buyer name, tons-out metric, two action buttons.
- `LoadingActivityCard` — incoming + scheduled-today rows.
- `RequestBuyersCard` — prominent CTA card.
- `OverviewPlaceholderBadge` — small "preview" / "pending data source" chip.

Reuse `PortalColors` for all fills, borders, accents, and action button styling. Reuse existing navigation helpers (`openPortalRoute`, `openPortalTabByLabel`, `openPortalDashboardNavigation`).

## Data flow

```
logisticsSnapshotProvider(companyId)  ->  LogisticsSnapshot
  waybills (transactions)  -> group by buyerCompanyId -> buyer tons-out + buyer list
  trips                    -> incoming (active) count, scheduled-today count
  reconciliations          -> recons navigation target / counts
companies lookup           -> buyer display names
```

Stockpiles and tons-out windows render from a small in-screen placeholder model (sample values + badge) until the user defines their real source.

## Error / empty handling

- Provider `loading` → centered progress (unchanged).
- Provider `error` → existing error message.
- No buyers / no trips → friendly empty states inside the respective cards (not a blank screen).
- Stub actions (invoice, request buyers) → non-destructive snackbar/dialog explaining the feature is coming.

## Testing

- Widget tests for the data-mapping helpers (buyer grouping by tonnage, scheduled-today count, top-3 + "N more").
- Golden/widget smoke test that the screen renders for: populated snapshot, empty snapshot, and mirror mode.
- Manual verification logged in via `ironhills.owner@mineralguide.com` (seeded demo data).

## Out of scope (future)

- Real stockpile-level data source + schema.
- Tons-out window calculation + source.
- Invoice generation backend.
- "Request buyers" workflow backend.
