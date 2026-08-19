# Buyer Portal — UI kit

Recreates the MineLink **Buyer** portal (LoadTrack-style chrome). Buyers purchase
minerals, track routes to mines/offload points, manage waybills, reconcile
delivered tonnage and watch trucks on a live map.

- `index.html` — interactive shell. Sidebar nav → Dashboard, Routes & Mines, Requests, Waybills, Reconciliations, Truck Locations.
- `screens.jsx` — `BuyerDashboard`, `BuyerRoutesMines`, `BuyerWaybills`, `BuyerReconciliations`, `BuyerTruckLocations`.

Source of truth: `lib/features/portal/screens/buyer_*` in the MineLink Flutter app.
Composes the shared chrome (`../shared/shell.jsx`) and design-system primitives.
