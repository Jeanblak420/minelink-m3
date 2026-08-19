# MineLink — Audit Findings (dummy / stub / broken data)

Audit of the uploaded `ML.zip` against the agreed spec in `CLAUDE.md`.
Scope: hunt for fake / dummy / placeholder / "coming soon" / stubbed logic and
anything that doesn't represent real code or real data. Each item below cites the
file and line so it can be fixed directly.

**Overall:** the backend is real and solid — all 40 RPCs the app calls exist in the
105 migrations (no missing-function runtime failures), no hardcoded credentials, no
fabricated data rows, and the recon/waybill/weighbridge chains are genuinely wired.
The problems are a **small number of specific stub buttons and one placeholder metric**,
plus repo hygiene. This is *not* a rewrite — it's a targeted fix list.

---

## P1 — Stub buttons that should call REAL, already-existing logic

These are the most important: the real implementation already exists elsewhere in the
codebase, but these buttons are wired to a "coming soon" snackbar instead of calling it.
These are almost certainly what you hit as "broken."

1. **"Request buyers" button → dead stub.**
   `lib/features/portal/screens/mine_supplier_buyers_detail_screen.dart:163`
   Shows `SnackBar('Buyer requests are coming soon.')`.
   **Fix:** call the real `showBuyersRequestDialog(...)` which already exists at
   `lib/features/portal/widgets/request_dialogs.dart:48`. Wire the button to open it
   (same pattern the Requests screen uses). The spec requires Request Buyer to work.

2. **Stockpile "Upload Results" / "Upload Picture" → stubs.**
   `lib/features/portal/screens/stockpile_detail_screen.dart:129,131`
   Both show "coming soon" snackbars.
   **Fix:** wire to the real multi-file uploader already built for the Request Buyer
   lab-results flow (`MultiFileDropPicker`, `request_docs` bucket). Lab-result PDF upload
   and picture upload are required by the spec. Same stubs appear on the Supervisor view:
   `lib/features/portal/screens/supervisor_view_screen.dart:183,185`.

3. **Stockpile "Test requests" button → stub.**
   `lib/features/portal/screens/stockpile_detail_screen.dart:158`
   Shows "Test requests are coming soon." If lab/quality test requests are in scope,
   wire it; if not yet scoped, hide the button rather than showing a dead action.

---

## P2 — Placeholder metric (real numbers required)

4. **`allocatedBuyers` uses allocated-stockpile tonnage as a stand-in for real tons-out.**
   `lib/features/portal/utils/mine_supplier_overview_metrics.dart:144`
   Comment: *"allocated stockpile sample for now — real tons-out wiring comes later."*
   Consumed by the mine/supplier dashboard per-buyer cards
   (`mine_supplier_portal_dashboard_screen.dart:59`).
   **Fix:** compute per-buyer tonnage from real waybill/recon Net Weight (the file already
   has a `buyerTons(...)` method that sums `waybills` by `buyerCompanyId` — use that as the
   source of truth instead of the allocation stand-in), so the dashboard shows delivered
   tons, not allocated estimates.

5. **Decorative fake sparkline on super-admin org cards.**
   `lib/features/super_admin/widgets/super_admin_dashboard_widgets.dart:256` (`_Sparkline`)
   Builds a trend line from `math.Random(seed)` — it looks like data but is noise.
   **Fix:** either feed it a real per-org tonnage/trip time series, or remove the sparkline.
   A random "trend" on an ops dashboard is misleading.

---

## P3 — "Coming soon" modules (legitimately unbuilt — make them honest)

These are genuinely planned, not broken wiring. They're acceptable as placeholders **if**
they read as clearly unbuilt (they mostly do). Listed so the status is tracked, not hidden.

6. **Transporter Maintenance module** — `transporter_maintenance_screen.dart:34`
   Full "Coming soon" hero. Note: the `CLAUDE.md` status table marks *Fleet management*
   🟢 Built; maintenance/downtime is a **separate** sub-module and is NOT built. Either
   build it or add a row to the status table so Built doesn't over-claim.

7. **Mine/supplier "Live operational records" card** —
   `mine_supplier_portal_dashboard_screen.dart:406,422` ("Coming soon" pill). Fine as a
   labelled placeholder; wire when the underlying feed exists.

---

## P4 — Repo hygiene (not user-visible, but pollutes the codebase)

8. **Multiple stray `void main()` entrypoints / debug scaffolds in `lib/`.**
   `lib/canary_test_app.dart`, `lib/minimal_app.dart`, `lib/realtime_example.dart`,
   `lib/debug_screen.dart`, `lib/debug_simple.dart`, `lib/debug_realtime.dart`,
   `lib/debug_supabase.dart`.
   None are referenced by real code except `debug_supabase` (2 refs). The real entry is
   `lib/main.dart`. **Fix:** move debug scaffolds to a `tool/` or `dev/` folder (or delete),
   keep only `main.dart` under `lib/` as an entrypoint. Reduces confusion and build surface.

9. **10 empty `catch {}` blocks silently swallow errors** — chat (`messaging_service.dart` ×3,
   `chat_dock.dart` ×2, `chat_prefs_provider.dart`, `chat_sound_service.dart`),
   `portal/services/lifecycle_service.dart`, `super_admin_repository.dart` ×2.
   Silent catches are a common cause of "it just doesn't work and shows nothing."
   **Fix:** at minimum log via `LoggerFactory` so failures surface instead of vanishing.

---

## What is genuinely REAL (verified, not stubbed)

- All 40 called RPCs exist in migrations — no missing-function crashes.
- Recon table transporter/customer/plate values are **real data**, not the hardcoded
  names from the example image (searched — zero hardcoded FLAMITE/BEXTRANS/etc.).
- `tons_out_mapping.dart` explicitly replaced the old hard-coded sample rows with real values.
- No test/demo credentials or backdoor accounts in the auth flow.
- The `demo` components screen is not routed into the app.
- Recon "batches are seeded automatically as trucks are loaded" = real load-driven seeding,
  not fake data.

---

## Suggested fix order
1. Wire the 3 stub buttons to their existing real handlers (items 1–3) — fastest wins,
   likely the "broken" behaviour you saw.
2. Replace the `allocatedBuyers` placeholder metric with real tons-out (item 4).
3. Decide sparkline: real data or remove (item 5).
4. Reconcile the status table with reality for Maintenance (item 6).
5. Repo hygiene: relocate debug entrypoints, add logging to empty catches (items 8–9).
