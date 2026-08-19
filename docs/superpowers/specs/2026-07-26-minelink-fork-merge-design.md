# MineLink Fork-Merge — Design / Reconciliation Spec

**Date:** 2026-07-26
**Author:** Claude (Opus 4.8) with 7 Fable-5 domain-audit agents
**Status:** Draft for user review

## 1. Problem & context

Two forks of the same app (MineLink / "The Mineral Guide", package `flutter_application_1`,
GitHub `Jeanblak420/minelink`) exist side by side and must become ONE production-quality app:

- **`ML`** — `…/SHOWME!/ML`. Newer, clean re-architecture. 159 Dart files, design tokens, central
  router, golden-path E2E test. Points at Supabase project `lrayvsezbpxuutttfxvi` (inaccessible).
- **`worktree`** — `…/SHOWME!/worktree-2026-05-05T11-53-29`. The larger original. 350 Dart files.
  Points at the **live production** Supabase project `yftazblpmicqtamyiwyb` (49 tables, real data).

A 7-domain, file-by-file / RPC-by-RPC audit was run (reports in the session scratchpad `audit/`,
summarized in `_SYNTHESIS.md`; live-backend facts in `_LIVE_BACKEND.md`).

## 2. Decision (approved by user)

**Foundation = `worktree`. `ML` = donor of unique + cleaner-looking pieces, each re-adapted to the
worktree's live schema & RPC contracts.** Rationale:

1. The worktree's code + schema **match the real, live, populated production DB**. ML uses an
   **incompatible** schema (`vehicles` vs `fleet_vehicles`; split `product_requests`/`buyer_requests`
   vs one `transportation_requests`; `tons_out_entries`/`reconciliation_entries` absent from live)
   and **different RPC signatures** (`record_truck_load` tare/gross vs net_tons; `set_trip_status`
   p_to+actor_role vs p_status; `list_mine_inbound_trips` p_mine_id vs p_supplier_company_id).
2. The worktree wins 6 of 7 domains: core/auth/theme, requests→dispatch (atomic RPC chain), fleet/GPS
   (server-enforced), super-admin (owns the entire seats/tokens/orgs/audit/insights layer ML lacks),
   people/comms (chat, dismissal, realtime notifications — all absent in ML), backend (production RPCs,
   real OTP; ML's OTP is a `000000` test bypass).
3. ML's advantages are largely UI-layer and portable onto the worktree's contracts.

## 3. Governing principles

1. **Working + live-compatible beats spec-purity.** When ML is "more correct per CLAUDE.md" but the
   worktree matches the live DB and works, keep the worktree's and document the deviation.
2. **Best-of-all, per screen/feature.** Where both forks are complete, pick the better implementation
   (nicer-looking UI, cleaner code, richer behaviour) — the user explicitly wants "the best of each".
3. **Every ML port is re-adapted** to the worktree's schema, RPC signatures, `MlTokens`/`MlSemantic`/
   `MlTone` design system, routing, and logging — never a raw drop-in.
4. **The live DB is the source of truth for schema.** New capabilities add NEW migrations; we do not
   rename/replace live tables that hold real rows.
5. **UI bar = the nicest of the two**, referenced against `worktree/Looks of Pages within the app/`.
   Use the `frontend-design` skill for any net-new UI.

## 4. Navigation / UX shell (user directive: "a mix of all — best of each")

Build a **merged shell**, not either fork verbatim:
- **Keep** the worktree's role-tabs + **Operations Hub** (live-tested, role-gated).
- **Add** ML's **deep per-org operational routes** (mine / buyer / transporter / driver portals:
  security, weighbridge, gate, stockpiles, waybill, fleet-allocation) grafted into the worktree's
  router + `OperationsAccessPolicy`, wired to the worktree's live RPCs.
- **Pick the best-looking UI per screen** across both forks; unify on the worktree's `ml_tokens`
  design system (richer: `MlTone`, `MlSemanticScope`).
- **Driver bottom-nav** (Dashboard/Trip/Profile) retained.

## 5. Map, directions & routing (user directive: "ML's map + directions + Valhalla")

Adopt **ML's navigation stack** and make **Valhalla** the primary routing engine:
- Port ML `gps_service.dart` routing: **Valhalla-first** (public FOSSGIS `valhalla1.openstreetmap.de`,
  configurable via `--dart-define`) which honours `avoid_locations`, i.e. **blasting/hazard-zone
  avoidance**, with **OSRM fallback** when Valhalla is unavailable or no avoid-zones exist. Add a
  dedicated `VALHALLA_BASE_URL` define (keep `OSRM_BASE_URL` for fallback).
- Port ML's **mine-navigation layer**: `mine_locations`, `mine_hazards`, `trip_waypoints`,
  `security_confirmations` (new tables) + `waypoint_progress_bar`, hazard/blasting alerts,
  security-gate handoff, `navigation_voice_coach` — adapted to the worktree's trip/RPC model.
- Merge with the worktree's `driver_navigation_screen` polish (rotating follow camera, instruction
  banner, reroute cooldown, telemetry via `publish_trip_nav_state`) → keep the best of both.
- Keep the worktree's richer live map (route polylines, ETA, animated markers) as the base map;
  layer ML's waypoints/hazards on top.

## 6. Per-domain merge plan (itemized port list)

Legend: **[WT]** keep worktree · **[ML→]** port from ML (adapt) · **[MERGE]** combine best of both.

### 6.1 Core shell / auth
- [WT] main.dart bootstrap+retry, supabase_config, theme (`ml_tokens`, `app_theme`, persisted
  `theme_mode_provider`), core services/utils/widgets, auth notifier/session/logout, real WhatsApp OTP.
- [ML→] **Self sign-up flow** (worktree has none — companies are admin-registered). Adapt to worktree
  auth + `profiles`/`companies`/`employees` schema + `company-user-admin` edge fn where relevant.
- [ML→] `multi_file_drop_picker` (richer, 782 ln) → replace worktree's file upload where used.
- [MERGE] Router: worktree base + graft ML's per-org portal route tree & `portalPath` role guards.

### 6.2 Requests → linking → dispatch
- [WT] transportation_requests model + 4 forms + `RequestStatus` + `review_transportation_request`,
  `link_and_dispatch_request`, `accept/decline_request_dispatch`, available-routes RPCs,
  `list_route_marketplace`, `list_margin_ledger`.
- [ML→] `convert_request_to_transport` bridge + `mine_road_requests` table/inbox (ML-only path).
- [ML→] Link-request **wizard UX** + sequential `RT-…` IDs + `routes_secure` view (UI/UX polish only).
- [FIX] Add margin-ledger export (both forks lack it).
- NOTE (deviation): worktree keeps one `transportation_requests` + `request_type` flag (CLAUDE.md says
  use 3 tables). Kept because it matches live & is richer. Documented.

### 6.3 Trips / weighbridge / recon / reconciliations / operations / stockpiles
- [WT] TripStatus + cascade RPCs (`set_trip_status`, `record_truck_load`, `record_pod`,
  `list_mine_inbound_trips`, `get_trip_waybill` — ML lacks the last), weighbridge tare/gross/net +
  seal photos, waybill PDF (server-authoritative assembly), recon exporter (`recon_exporter.dart`).
- [ML→] Reconciliations **single tabbed Side-A/B screen** (cleaner UI) — rewire to worktree data.
- [ML→] Operations **split screens** + 7-tab access policy incl. stockpiles — rewire to worktree RPCs.
- [ML→] Recon **period-totals** (D/W/M/Y/Total) via a worktree-side function if worktree lacks it
  (do NOT adopt ML's `tons_out_entries` table — keep worktree `reconciliations`/`reconciliation_uploads`).
- [WT] stockpile docs + audit screen (ML lacks). [MERGE] stockpile cap + `stockpile_add_tons` + +30t.
- [CLEANUP] Remove worktree's dead legacy ops-hub weighbridge tab that allows manual net entry.

### 6.4 Fleet / GPS / navigation
- [WT] fleet_vehicles CRUD, Available↔On-Route server-enforced (`list_transporter_fleet_status`,
  `accept_request_dispatch`, `add/remove_vehicle_driver`, `request_driver_limit`), maintenance,
  `fleet_notification_service`, `fleet_document_debug`, self-healing GPS reporter + nav telemetry.
- [ML→] accept-route / allocate-fleet / trucks-on-route **UI** (adapt to worktree RPCs).
- [ML→] Mine nav layer + Valhalla (see §5). [MERGE] live map (WT base + ML overlays).

### 6.5 Super-admin platform
- [WT] Seats/tokens (serial_token/organization_seat/token_request + 11 RPCs), org status, audit log,
  monthly ops stats, insights CSV export, dashboard `platform_logistics_totals`, org/user management,
  `super-admin-create-company` edge fn, available-routes/marketplace/margin-ledger.
- [ML→] 4-way split request inboxes + mine-road-request inbox + richer filtered live map.
- [CLEANUP] Strip worktree's residual **child-admin** code (dead enum, `isChildSuperAdmin`,
  `isChildWorkspace` nav-hiding, `CHILD_ADMIN_*` audit constants, register-company copy) — ML clean.

### 6.6 People / chat / notifications / signatures / tutorial / profile
- [WT] Chat (full: realtime, reactions, presence/typing, attachments, chat_dock, support tickets),
  employee service + **dismissal system** (provider/screen/form/appeal), notifications (644-ln service,
  ~13 typed creators, realtime, validator, button widgets), company data layer, profile (920 ln),
  private-bucket signatures.
- [ML→] **Tutorial/onboarding** overlay + `showcase_data` (ML-only).
- [ML→] Richer `company_profile_screen` (locations) + driver-specific profile screen.
- [ML→] ML's edge-function **invite flow** (temp password) as an admin option.
- [DEDUPE] One signatures implementation — keep the worktree's private-bucket `StorageAssetService`;
  drop ML's public-URL version; ensure waybill/POD auto-placement still works.

## 7. Backend execution (user directive: verify live first, then reconcile in-repo)

**Phase A — wire & verify against live `yftazblpmicqtamyiwyb`:**
- Confirmed: 49 tables (all RLS), 4 edge fns, advisors 134 WARN / 0 ERROR.
- New migrations (additive; safe on live) for ported features:
  `mine_locations`, `mine_hazards`, `trip_waypoints`, `security_confirmations`, `mine_road_requests`,
  `showcase_data` (+ RLS + any needed RPCs: waypoint suite, `convert_request_to_transport`,
  hazard-aware route helpers, recon period-totals if missing).
- Capture the live-only `reset-admin-password` edge fn into the repo.
- Address advisors: review 2 anon-callable SECURITY DEFINER fns; enable leaked-password protection.

**Phase B — reconcile code + migrations in-repo:**
- Keep the worktree migration history coherent & deployable (no destructive squash); the new
  additive migrations layer on top. Ensure `config/supabase.*.json` point at `yftazblpmicqtamyiwyb`.

## 8. Verification (definition of done for a domain)
- `flutter analyze` clean (worktree lints).
- `flutter test` incl. porting ML's golden-path E2E verifier, adapted to worktree contracts.
- App **launches** (web + windows) and the end-to-end spine works against live/staged data.
- Each ported ML feature demonstrably wired to a real worktree RPC (no mock/placeholder left).

## 9. Risks / out-of-scope
- **Schema drift on ports** — biggest risk; mitigated by adapting every ML port to live contracts and
  testing against live.
- **ML's inaccessible DB** — we never depend on it; ML is code-only donor.
- **Valhalla public server rate limits** — mitigated by configurable base URL + OSRM fallback.
- Out of scope: physical-device GPS/iOS build validation (can't test headlessly); real WhatsApp/SMTP
  provider secrets (config only).

## 10. Phased execution (detail comes from the writing-plans step)
0. Prep: workspace, config→live, baseline `flutter analyze`.
1. Backend Phase A migrations + verify.
2. Core shell + router merge + sign-up + drop picker.
3. Requests/dispatch merge + mine-road bridge.
4. Trips/weighbridge/recon/operations/stockpiles merges.
5. Fleet + Valhalla nav + mine-nav layer.
6. Super-admin ports + child-admin cleanup.
7. People/chat/notifications/tutorial/profile/signature dedupe.
8. Backend Phase B reconcile + advisors.
9. Full verification: analyze, tests, launch, E2E.
