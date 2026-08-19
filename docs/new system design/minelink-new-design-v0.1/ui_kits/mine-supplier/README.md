# Mine / Supplier Portal — UI kit

Recreates the MineLink **Mine / Supplier** surfaces, including role-scoped views.

- `index.html` — interactive shell: Dashboard (Overview), Control, Security, Buyers, Truck Locations.
- `screens.jsx`:
  - `MineOverview` — tons-out KPIs, 7-day bar chart, request-buyers promo.
  - `MineControl` — load-recording desk: search, KPI row, "Trucks at Mine — Ready for Loading", **Record Load** slide-over (tons + weighbridge ticket), recent loads.
  - `MineSecurity` — the **mobile** gate-control app (rendered in a phone frame): Mark Arrived / Mark Left, incoming/at-mine/departed counts, recent activity.
  - `MineBuyers` — per-buyer tonnage cards with recon/invoice actions.

Role rules from the codebase: Security guards see only the Security screen; Load
Controllers see only Control. Source: `lib/features/portal/` + `portal_navigation.dart`.
