# Transporter Portal — UI kit

Recreates the MineLink **Transporter** portal. Transporters run the fleet:
register vehicles & drivers, see routes per client, reconcile load-vs-delivery
variance, and view live truck positions on a map.

- `index.html` — interactive shell: Transporter Portal, Fleet / Transport, Routes, Reconciliations, Truck Positions, Drivers.
- `screens.jsx` — `TransporterDashboard`, `TransporterFleet` (edit slide-over), `TransporterPositions` (live map pins), `TransporterRecons`.

Source of truth: `lib/features/portal/screens/transporter_*` and `lib/features/fleet/`.
