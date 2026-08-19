# CLAUDE.md — MineLink

> ## ✅ This is the canonical MineLink working tree — you are in the right place.
>
> Repo `github.com/Jeanblak420/minelink-platform`, active branch `feat/minelink-fork-merge`.
> On Jean's machine this checkout lives at
> `C:\Users\Somebody Someone\Music\SHOWME!\worktree-2026-05-05T11-53-29` — a git *worktree* whose
> `.git` is a file pointing into the main repo's `.git\worktrees\`.
>
> **Stale look-alikes exist on that machine. Do not work in them:**
> `Music\TheMineral Guide\worktree-2026-05-05T11-53-29` (plain copy, no `.git`, but carries an
> out-of-date copy of *this* file) and `Music\Old min Guide\worktree-2026-05-05T11-53-29`
> (April copy; its `.git` was disabled on 2026-08-08 because it pointed at this worktree's real
> gitdir). Both now open with a `🛑 STOP` banner. To confirm which tree is real, run
> `git worktree list` — only the main repo and this worktree are registered.
>
> Not the same project: `Music\SHOWME!\ML` and `Music\pray-for-mine-link\ML` are clones of the older
> `Jeanblak420/minelink` repo. **Mine Online** (`Desktop\PrayforPlauge`, Shift Boss Management
> System) is an entirely separate product — different client, different GitHub org, different
> Supabase account. Never mix the two.

Guidance for Claude Code (and other AI agents) working in this repository. Read this before making changes.

MineLink is a **mineral logistics and bulk-commodity haulage operations platform** covering mine-to-port dispatch, load control, weighbridge capture, trip lifecycle tracking, and multi-party (mine / buyer / transporter / driver) coordination. It is a Flutter app backed by Supabase.

---

## 1. Non-negotiables (read first)

- 🚨 **LEAVE THE DATABASE HEALTHY. ALWAYS ACTIVE, EVERY TASK, EVERY SESSION.** Client instruction, 2026-08-16, given as a standing rule for all agents working on this app.

  **Never end a job, and never say a piece of work is done, while the Supabase project is in anything other than a fully healthy state.** If your work touched the database *at all*, then before you finish you must check **every** service that should be healthy — Database, PostgREST, Auth, Storage, Realtime, Edge Functions — not just the one you worked on.

  - **Prove it with a probe, not a status field.** `get_project` reported `ACTIVE_HEALTHY` for the entire 2026-08-16 outage while nothing answered. A request that returns 200 is evidence; the control plane's opinion is not.
  - **Act, don't just report.** Diagnose and fix. `query_logs` against `postgres_logs` goes through the management API and **works when SQL does not**, so it is the diagnostic path during an outage; comparing the newest timestamp per `source` localises the failure (if `edge_logs` run on past the last `postgres_logs`, it is Postgres).
  - **Restarting the project is authorised** when that is what health requires. The client's words: *"if the decision is too big for you to make and or take to get it to a healthy state then to ask what to do, otherwise just do."* `pause_project` may be refused by the permission classifier — if so, say so plainly and point at Settings → General → **Restart project**. Do not go quiet.
  - **Tonnage and routes in this DB are disposable test data** (client, 2026-08-16: *"none of the tons in the db actually matters… if that tons recorded and or routes gets destroyed it would all be fine"*). That permission is real — but confirm it is *relevant* before using it. The 2026-08-16 outage had nothing to do with tonnage, and deleting data would not have fixed it.
  - **Throttle bulk work.** That outage was caused by 20,000-row `UPDATE` batches taking 27–45 s each, run back-to-back against a ~790k-row table, with a `CREATE INDEX` and `ANALYZE` overlapping the backfill feeding them; autovacuum was locked out (`skipping vacuum … lock not available`) and the instance wedged. Both projects are production (§10.2), and other sessions and the live app share them (§10.1). Batch small, pause between, and never overlap an index build with the backfill that feeds it. Use `tools/place_index_backfill.py` as the shape to copy; never hand-roll the loop again.

- 🚨 **THERE ARE TWO SUPABASE PROJECTS, AND THE MCP TOOLS ONLY REACH ONE.** Both are production, both are free plan (500 MB each). Full detail in §10.2 — this entry exists because the failure is silent.

  | | Main app | Extras |
  |---|---|---|
  | Ref | `yftazblpmicqtamyiwyb` | `qbydiuplqhmkaxarnuza` (`Mine-Link_Extra_Data`) |
  | Holds | Everything transactional | Bulk reference data only — today just `place_index` |
  | Dart | `SupabaseConfig` | `PlaceIndexConfig` |
  | Migrations | `supabase/migrations/` | `supabase/extras_project/migrations/` |

  **`.mcp.json` pins the MAIN ref**, so `execute_sql`, `apply_migration`, `query_logs` and `get_advisors` always land on the app database — with no warning — whichever project you believe you are working on. Reach the extras project only through the Management API (§10.2 has the call).

  **Never put user, company or trip data in the extras project.** A JWT from the main project's GoTrue is not valid there, so a signed-in user arrives as `anon` with no session to scope rows by — RLS cannot protect party-scoped data there at all. `place_index` was the one table safe to move precisely because it was the only table in `public` with no RLS policies: ownerless open data reached through a `SECURITY DEFINER` wrapper.

- **Package name is `flutter_application_1`.** Despite the product being MineLink, the Dart package is still `flutter_application_1` (see `pubspec.yaml`). All internal imports use `package:flutter_application_1/...`. Do **not** rename it or "fix" imports to `minelink` — that would break the entire tree. The user-facing product name lives only in `AppBranding.appName` (`lib/core/constants/app_branding.dart`).
- **Never hardcode secrets.** Supabase URL and keys come from `--dart-define` (`SUPABASE_URL`, `SUPABASE_PUBLISHABLE_KEY`, `SUPABASE_ANON_KEY`) or the bundled `config/supabase.live.json` asset, resolved in `lib/core/config/supabase_config.dart`. (`supabase_config.dart` also looks for `config/supabase.local.json` first, but that file **is not in this repo and is deliberately not listed in `pubspec.yaml`** — see the comment there. Anything bundled from `config/` is served at a public URL, which is how a live map token once leaked.) Never paste a key into Dart source, and never commit real keys into the `config/` JSON.
- **Design tokens are law.** All colours, spacing, radii, typography, motion, and status hues come from `lib/core/design/tokens/ml_tokens.dart`. Do not introduce raw `Color(0x...)` literals or magic numbers in feature code — use `MlTokens`, `MlSemantic`, and `MlTone`. See §5.
- **Schema source of truth is `supabase/migrations/*.sql` in git.** Follow `supabase/MIGRATION_HYGIENE.txt` before creating or pushing migrations. See §6.
- **This repo has a lot of legacy scratch files.** The root is littered with one-off `.sql`, `.ps1`, `.bat`, `.md`, and `test_*.dart` helper scripts from past debugging. Treat them as historical artifacts, not current architecture. The live app is `lib/` + `supabase/`. Don't imitate patterns found in root-level scratch scripts.

---

## 2. Tech stack

- **Flutter** SDK `^3.8.0-278.1.beta`, Material 3.
- **State management: Riverpod** (`flutter_riverpod` ^2.4). Providers live per-feature under `providers/`. Global repository providers are declared in `lib/main.dart`.
- **Routing: `go_router`** ^13.2, centralized in `lib/core/routing/app_router.dart`. Auth-gated redirects driven by Supabase `onAuthStateChange` + cached profile fields (role / user type / mandatory-password gate). Public paths: `/login`, `/forgot-password`, `/reset-password`, `/whatsapp-otp`.
- **Backend: `supabase_flutter`** ^2.9 — Postgres + Auth + Realtime + Storage + Edge Functions (Deno).
- **Charts:** `fl_chart`. **SVG:** `flutter_svg`. **Maps:** `flutter_map` + `latlong2`. **GPS:** `geolocator` (driver live pings, 30s cadence).
- **Docs/export:** `pdf`, `printing`, `excel`, `share_plus`, `path_provider`.
- **Logging:** custom `LoggerFactory` in `lib/core/utils/logger.dart` — use it, not `print`.
- **Default theme mode is dark** (`ThemeMode.dark`), user-toggleable via `themeModeProvider`.

---

## 3. Architecture & folder layout

Feature-first. Each feature under `lib/features/<name>/` follows:

```
<feature>/
  models/       # data classes, enums, fromJson/toJson
  services/     # Supabase data access (the *only* place that talks to the DB)
  providers/    # Riverpod providers exposing state to the UI
  screens/      # full pages
  widgets/      # feature-scoped widgets
```

Some larger features (e.g. `super_admin`) add a `data/` (repositories + models) and `domain/` (permissions) layer — mirror that split only where the feature already uses it; don't impose it everywhere.

Shared/cross-cutting code lives in `lib/core/`:
- `core/design/tokens/` — `ml_tokens.dart` (and the other token sets)
- `core/theme/` — `app_theme.dart`, `theme_mode_provider.dart`
- `core/routing/` — `app_router.dart` and route helpers
- `core/config/` — `supabase_config.dart`
- `core/services/` — cross-feature services (database, cache, storage, migration)
- `core/mcp/` — shared repositories/models (company, employee) used app-wide
- `core/widgets/` — reusable widgets (loading, file upload, chat, dropdowns, infinite list/grid)
- `core/utils/`, `core/layout/` (`app_breakpoints.dart`), `core/navigation/`

App entry: `lib/main.dart` (`_BootstrapApp` runs Supabase init + migrations behind a `FutureBuilder` with retry, then mounts `ProviderScope(child: App())`) → `lib/app.dart` (`MaterialApp.router`).

### Key features
`auth`, `portal` (⭐ logistics core — see §4), `operations`, `company`, `employee`, `fleet`, `super_admin`, `chat`, `notifications`, `profile`, `home`, `tabs`, `demo`.

---

## 4. Domain model (the part that makes MineLink MineLink)

### Implementation status (read before assuming anything exists)

Much of this section describes **target state**, not what is currently in the code. Do **not** assume a screen, table, or RPC exists — check the repo first. Status keys used below:

- 🟢 **Built** — fully implemented end-to-end (frontend UI **and** backend DB/Supabase/RPC), wired into the real flow, and in proper working state.
- 🟡 **Partial** — scaffolding or a subset exists; incomplete or not wired through the full flow.
- 🔴 **Planned** — described here but not yet built (or only stray references exist).

| Area | Status | Notes (as of the reviewed snapshot — verify against current repo) |
|---|---|---|
| Core app shell, auth, routing, theme/tokens, portal shell | 🟢 Built | `lib/core/**`, `auth`, `ml_tokens.dart`, portal layout are real and mature. |
| Fleet management (add/edit vehicles, driver-assignment dialog) | 🟢 Built | Available ↔ On-Route state machine (derived from active trips), "Trucks On Route" screen, multi-driver per truck (`driver_assignments`, max 2 default / 5 via super-admin-approved `driver_limit_requests`), driver On-Route status. |
| Transporter Maintenance / downtime sub-module | 🟢 Built | Built 2026-07-17 (spec `docs/superpowers/specs/2026-07-17-fleet-maintenance-design.md`): `fleet_maintenance_records` + `fleet_service_schedules` (migration `20260717120000`, applied live). Third fleet state **In Maintenance** is DERIVED from an open out-of-service record (same pattern as On-Route from trips) — no stale flag; "Mark fixed" is the single action returning the truck to Available. Server-enforced: `accept_request_dispatch` rejects in-maintenance trucks; `list_transporter_fleet_status` gained `in_maintenance`. Maintenance screen: log service/repair/breakdown/inspection (out-of-service toggle, expected-back, cost R, odometer), stat cards, closed history; recurring service schedules due by date and/or odometer, roll-forward on "Log service done", daily `notify_service_due_job` pg_cron reminder; down/back-in-service notifications to management. Live-verified full cycle 2026-07-17: open breakdown → Available 1→0 → dispatch rejected server-side → mark fixed → Available 1 → dispatch accepts; schedule DUE SOON → log done → due date rolled +6 months. |
| Request Route/Transporter form (buyer + mine/supplier) | 🟢 Built | "Number of Trucks Required" rename, Ongoing/Single-request dropdown (start locked to today+2; single adds end date), and mine/supplier parity (mines get the identical form via their Requests tab). |
| Request status enum (`requested→sent_back→resubmitted→approved→linked`) | 🟢 Built | Full `RequestStatus` enum + tolerant `parse()` in `transportation_request.dart`; revision loop wired. |
| Request Product / Request Buyer forms | 🟢 Built | All fields incl. multi-PDF lab-results uploader (`request_docs` bucket, `MultiFileDropPicker`), optional image, FOB/FOT, payment terms, price/ton, OSM location picker. Sent-back requests reopen in the same dialog pre-filled (admin note shown, kept attachments removable, new uploads appended) and resubmit; requesters see their own attachments on their request cards (`RequestAttachmentChips`, shared with the admin panel). |
| Super-admin request inboxes (split screens under "Requests") | 🟢 Built | Four inboxes: Mine/Supplier transport + Buyer transport (transportation split by requesting-org type), Requested product, Requested buyers. |
| Route ID, pricing/margin ledger, due-diligence gate | 🟢 Built | `routes` entity minted at linking (`RT-…`), `margin_ledger` (+ viewer screen), ordered due-diligence gate in `_DispatchStep`, transporter sees only their price. |
| Available routes (auto-fill) + transporter marketplace | 🟢 Built | `route_assignments` + admin Available-routes screen (assign, optionally permanent); assigned routes pre-fill the Request Route form via the shared `AvailableRoutesSection`, shown on the org's Requests screen AND mirrored on the buyer + mine dashboards. Marketplace screen is super-admin-only with the "will become public" note. |
| Weighbridge tare/gross/net capture + auto waybill | 🟢 Built | Auto Net = Gross − Tare at load record; tare/gross scale photos + up to 4 seal photos captured and uploaded to the private `load_photos` bucket (seal `photo_url` wired so seal-required routes can save); non-editable waybill PDF generated + print/preview via `printing`. Waybill NUMBER = the transaction reference (`TRP-…`), auto-assigned server-side and identical to the recon WAYBILL NUMBER column; DESTINATION auto-fills from the route/transaction offloading point. **Seal COUNT is enforced from 2026-08-17** (`20260817300000`/`310000`/`320000`/`330000`). `record_truck_load` demands exactly `public.expected_seal_count(vehicle)` seals, each with a number AND a photo. Before that the only rule was "not zero", and production held a seal-required load recorded with **2** seals on a two-trailer interlink and another with **13** — while the waybill prints four serial lines, so the first named half the seals on the truck and the second recorded nine no document can carry. **The count is `fleet_vehicles.seal_points` — a stated fact about the rig, not an inference.** The first fix derived it from whether the *optional* trailer-registration text had been filled in; a transporter who left a registration blank was told to fit 2 seals to a 4-seal rig and then had the correct load refused. `seal_points` is derived once from the trailers when a vehicle is created (`derive_seal_points`, via a BEFORE trigger), constrained to 1–4, and corrected by the truck's owner through `set_vehicle_seal_points` (guarded by `can_manage_fleet`, so a mine cannot change what its supplier's rig needs). The Load Controller's sheet renders exactly that many slots and names the count in its heading. |
| Waybill layout (auto-fill + auto-signature, matches reference image) | 🟢 Built | `waybill_pdf.dart` matches the real reference `assets/Varsiwave waybil 2l.png` (border, boxed NUMBER/SECTION, SERIALNO. lines, divider, signature blocks); header = SOURCE mine. Dispatch block = Load Controller name + signature (stored in trip metadata at load); RECEIVED block auto-fills the driver's name + signature + offload time at POD — `get_trip_waybill` regenerates the signed copy on the driver's device at delivery. |
| Recon tables (combined + transporter) + D/W/M/Y/Total cards | 🟢 Built | `RawReconView`: full-word Day/Week/Month/Year/Total cards with Show/Hide, transporter/product Filter (= transporter-based view), DATE only on first row per date group, auto `Total Tons =` footer, Excel/CSV/PDF export; super-admin combined table at `/super-admin/recon-tables`. |
| Reconciliations screen (Side A raw + Side B reconciled, 2-version round-trip) | 🟢 Built | Side B variance view (with a POD-photo link per delivered trip) + Side A raw table + Excel/CSV/PDF exports + immutable-original/edited re-upload pairs (`reconciliation_uploads`, edit restricted to an initiating org's manager or the platform admin), on buyer/transporter/mine screens. Recon Day/Week/Month/Year/**Total** cards are all-time over all rows; the transporter/product filter scopes only the table + its `Total Tons=` footer. |
| Trip lifecycle (`TripStatus`) + per-role side-effects | 🟢 Built | Audited + closed 2026-07-12: driver "Start route" (`scheduled→en_route_to_load`), Security check-in fires a real DB notification to the mine's `controllerWB` users (was in-memory only), Security checkout advances `left_mine→en_route_to_offload`, load cascade (seals, FIFO stockpile decrement, recon upsert, waybill) verified, and 0-tons stockpile depletion now stamps `transactions.metadata.stockpile_depleted_at` + notifies mine owner/supervisor/admin/management. Deliberate collapse: POD upload = `offloaded`+`completed` in one step (`offloaded_at` back-filled). Load-record also DB-notifies the mine's `security` users ("ready for gate check-out"); POD photo now really uploads (private `pod_photos` bucket, path stored in `pod_uploads.photo_url`, viewable on the recon screen); driver screens resolve the truck via `driver_assignments` (2nd+ drivers no longer see "no truck assigned"). **2026-07-13 audit-fix round:** `trips.route_id` FK re-pointed to `routes` (route acceptance no longer crashes on the FK); seal enforcement reads `routes.seal_required`; the Supervisor/Foreman now has the Supervisor tab and can write stockpiles (`is_company_stockpile_writer` RLS) with "Add tons" actually persisting via `addTons`; `accept_request_dispatch` caps trucks at the Number Required; 0-tons completion only fires when a load actually empties the pool. In-memory `WorkflowNotificationProvider` pushes remain as same-session UX sugar only. |
| Live trip GPS tracking / ETA | 🟡 Partial | Full stack built 2026-07-12: driver pings every 30s via `record_vehicle_position` (geolocator; Android foreground-service background tracking, iOS background location, driver toggle card), party-scoped `list_live_trip_positions` feed, realtime-refreshed "Live map" tabs (transporter/buyer/mine/driver) + `/super-admin/live-map`, straight-line ETA when the destination is a `?q=lat,lng` maps link. **Server pipeline live-verified 2026-07-13** (simulated a real authenticated driver's ping against the live active trip → `record_vehicle_position` returned `recorded:true`, `list_live_trip_positions` returned the exact position party-scoped; rolled back, no residue). 🟡 remains ONLY for the device/OS layer that can't be tested headlessly: the location-permission prompts, real GPS-fix acquisition, the Android foreground service surviving backgrounding, and iOS background mode. |
| In-app driver navigation (turn-by-turn + voice) + company Locations + driver 3-tab shell | 🟡 Partial | Built 2026-07-16 (spec `docs/superpowers/specs/2026-07-16-driver-navigation-mine-locations-design.md`): OSRM turn-by-turn `DriverNavigationScreen` (`/portal/driver/navigate/:tripId`, free `router.project-osrm.org`, overridable via `OSRM_BASE_URL` dart-define) with rotating follow camera, instruction banner, `flutter_tts` voice, auto-reroute, arrival→lifecycle actions, graceful degradation (no GPS / OSRM down / no destination); `company_locations` table + `set_primary_company_location` + `get_trip_nav_destination` RPCs (migration `20260716090000`, applied live + RLS/party-scope verified with real users); "Locations" section on the company profile (map picker or paste any Google Maps link, short `maps.app.goo.gl` links auto-resolved) — Iron Hills Mining seeded with its primary collection point; destination chain request-link→mine-primary→address live-verified. Driver role gets the 3-tab shell (Dashboard-first · Trip · Profile) on `/home` with real data + quick links to every legacy driver screen (verified in-browser); other roles untouched. **Android-emulator verified 2026-07-17** (minelink_test AVD, live Supabase, real GPS stack via `adb emu geo fix` simulated drive as roadhaul.driver): destination resolved to the Iron Hills primary point, OSRM route drawn on real roads, rotating follow puck tracked every fix, instruction banner counted down with meters ("In 200 m — Turn left onto Robin Drive… then Continue onto Kingfisher Drive"), live ETA/time-left/distance/speed HUD, auto-reroute on off-route jumps, arrival detection fired ("You have arrived." + green "Arrived at mine" lifecycle button), and **voice genuinely spoke** — Google TTS (en-GB) utterances in logcat synced to the drive, stale announcements correctly interrupted. **2026-08-17 — navigation was completely broken on WEB, and had never been driven there.** The Android walk above is the only one that had ever happened, and every defect below was invisible to it. Fixed and re-driven in a browser as the real assigned driver, load leg *and* offload leg: (1) **the polyline codec decoded every route into another universe** — Dart's `~` is unsigned 32-bit under dart2js, so a live 10.0 km Valhalla route decoded to 599 295.4 km. No route line on the map, `ETA/Time left/Distance/vs plan` all dead, a banner reading "In 2194.2 km" on a 10 km trip, and `trip_nav_state.route_polyline` published to every watcher as 13 characters of junk. The codec is arithmetic-only now and the `no-bitwise-in-polyline-codec` release guard holds it (see §10.6). (2) **The destination was resolved by the wrong rule** — see the `get_trip_nav_destination` note below. (3) **The screen never named its destination**; it now shows the booked point and how the pin was resolved, and warns when the pin is a company address rather than the booked place. 🟡 remains ONLY for what neither an emulator nor a browser can prove: physical GPS reception on a real road trip, long-run Android foreground-service backgrounding, and the iOS build. |
| Address search — `place_index`, on the SECOND Supabase project | 🟢 Built | Built 2026-08-15/16. MineLink's own Overture Maps index, because no free OSM-backed geocoder can answer SA addresses (§4 map-picker note). **611,841 South Africa rows** on `Mine-Link_Extra_Data` (`qbydiuplqhmkaxarnuza`), reached via `PlaceIndexConfig` → `search_place_index` as `anon`; **never** via `SupabaseConfig` (§1, §10.2). Moved off main 2026-08-16 where it was 413 MB of a 477 MB database (87% of disk) and **53.0% of all query execution time**; main is now 24 MB / 4.8%. Warm searches ~0.25 s. FTS index only — the 90 MB trigram index is deliberately *not* built (`_place_index_rank` uses an index solely for the FTS predicate, then `ilike`/`similarity()` over ≤2000 candidates, so pg_trgm the extension is needed but not the index). Non-ZA rows (177,839 across 28 countries) dropped — ZA-only until further notice. Kept awake by `ping_extras_project()` on main. Degrades to Nominatim if that project is unreachable. |
| Two-weight offload variance (mine vs delivered) | 🟢 Built | `list_trip_reconciliations`: mine net (authoritative) vs delivered, computed variance, both stored, never overwritten. |
| Per-user profile **signature** field | 🟢 Built | Draw canvas → transparent PNG in private `signatures` bucket; `profiles.signature_url`; auto-placed on waybills. |
| Order-linked capped stockpiles + collect-when-ready alerts | 🟢 Built | On dispatch the system auto-creates ONE capped stockpile per order (`stockpiles.request_id / route_id / transporter_company_id / max_cap_tons`); supervisors can no longer free-create (INSERT RLS `with check (false)`); `stockpile_add_tons` RPC enforces the cap + fires a "ready to collect" alert to buyer + transporter each time the balance crosses **+30 t** (one full trailer load); the linked buyer + dispatched transporter both read the live fill (`OrderFillLine` / `orderStockpileProvider`). `supabase/migrations/20260715090000_stockpile_order_flow.sql`. See "Order-driven stockpiles" below. |
| Cross-party dispatch/assignment notifications | 🟢 Built | On dispatch, `link_and_dispatch_request` notifies the mine supervisor (clickable → the auto-created stockpile), the transporter (owner+admin+management) and the buyer. On truck-then-driver assignment, `add_vehicle_driver` notifies the assigned driver with the collection details + deep-link to "My routes" (`20260715100000_driver_assignment_order_aware.sql`). All via `notify_company_role` / `create_notification_internal` into `notifications`. |
| POD photo cross-party visibility (driver history + recon tables + super-admin) | 🟢 Built | Built 2026-07-27 (migration `20260727210000`, applied live): storage policy `pod_photos_select_parties` lets every company on the upload's transaction (mine/buyer/transporter) open the photo, not just the uploader's company folder; `list_raw_recon_rows` gained `pod_photo_path`; POD column (clickable "View") on the raw recon table for all 3 orgs + the super-admin combined table; POD icon on Side B (shared `PodPhotoIcon` in `pod_photo_link.dart`) and on the driver's Recent Trips history. Live-verified with impersonated buyer/driver users: both open the pod_photos object. |
| Buyer money layer (Rand value per load + delivered vs invoiced recon) | 🟢 Built | Built 2026-07-27 (migration `20260727230000`, applied live): `load_invoices` (one buyer-captured invoice per trip, buyer-private + platform admin — mine/transporter can never read them) + `list_buyer_trip_values` (agreed R/ton from margin_ledger via dispatch→request; loaded/delivered/payable Rand values; invoice variance = invoiced − payable). NEVER returns admin margin or transporter price (live-verified: transporter staff get 0 rows/0 margin_ledger rows). Buyer "Loads & value" tab: money stat cards (Delivered/Payable/Invoiced/Variance), per-load table w/ invoice capture dialog, POD chip, quality view, Excel/CSV/PDF export. |
| Load quality certificates + moisture/grade payable-tons penalty calc | 🟢 Built | Built 2026-07-27 (migration `20260727220000`, applied live): `load_quality_certs` — ONE cert per delivered load (trip): structured Cr₂O₃ % / moisture % / sizing + lab PDF in private `quality_certs` bucket (cross-party select via cert reference, mine-folder writes); contract spec on `routes` (`spec_cr2o3_pct`/`spec_moisture_max_pct`/`spec_sizing`, set via `set_route_quality_spec` by mine or admin); structured grade fields on `stockpiles`. Penalty calc (server-side in `list_load_quality` + buyer values): payable_tons = delivered(→net) × (1 − excess moisture/100); grade_factor = min(1, Cr₂O₃/spec). Mine "Quality" tab (spec editor + attach/edit certs via `set_load_quality_cert`, mine-staff-only — live-verified buyer blocked), buyer sees quality in Loads & value, super-admin in Recon tables (shared `LoadQualityTable`). Live-verified calc: 38% vs 42% spec + 10% vs 8% max → payable 34.10 t, factor 0.9048. |
| Mine production vs dispatch (tons-mined, ROM/production piles, yield) | 🟢 Built | Built 2026-07-27 (migration `20260727240000`, applied live): `stockpiles.kind` ('order' system-only as before; 'production' = mine-creatable ROM piles via new INSERT policy for stockpile writers — order-pile hand-insert still blocked, live-verified); `production_entries` + `record_production` RPC (optionally lands tonnage on a production pile atomically via `stockpile_add_tons`); `mine_production_dispatch_report` (per-day mined vs weighbridge net out). Mine "Production" tab (org/admin/mgmt + supervisorForeman): record-production dialog, 7/30/90/365-day window w/ Mined·Dispatched·Yield %·Pit-to-port-loss stat cards, daily table + export, ROM pile create/add-tons cards, production log. Live-verified: pile bal 120 t after record, report 120 mined vs 35 dispatched; driver blocked from recording. |
| Targets — monthly goals + 12-month horizon cycles (3 scopes) | 🟢 Built | Built 2026-08-08 from the `targets&monthly goals` drop (migration `20260808120000_targets_and_cycles.sql`, applied live). `monthly_targets` + `target_cycles`, both keyed by **scope**: `platform` / `org_type` / `company`, each with its own console screen (`/super-admin/targets`, `/super-admin/targets/org-type/:orgType`, `/super-admin/targets/company/:companyId`) under Insights. Actuals are never stored — computed per read from `trips.net_tons` on the same date basis as `list_raw_recon_rows`, so the dials and the recon table cannot disagree; frozen into `target_cycles.actuals` only at close. **The two locks are enforced in Postgres, not Dart**: a closed month's target cannot be changed *or created*, and a locked cycle is immutable until `started_on + 1 year` — both live-verified through the RPCs *and* by raw UPDATE/INSERT bypassing them. Tables carry a SELECT grant only (no write grant, no write policy), so all writes go through `set_monthly_target` / `set_cycle_draft` / `lock_target_cycle` / `start_new_target_cycle`; reads through `get_targets_state`. Realtime on `monthly_targets`, `target_cycles`, `trips`, `transactions` (fast debounce for edits, slow for trip traffic); dial writes are coalesced in `TargetsController` (400ms trailing) so a held arrow key is one write. Nightly `close-due-target-cycles` pg_cron job freezes actuals + notifies. **Scopes are INDEPENDENT** — see below. The transporters overview's flagship target line reads this store (org-type scope) instead of the drop's hardcoded "Target 28.0k". **Closed to 🟢 on 2026-08-17** — the two reasons it was 🟡 were that the screens had never been opened in a running browser against a signed-in admin, and that nobody had driven the write path. Both done, as `walkbot.superadmin`, against live data: all three scope screens render (platform 498.9 t MTD, `Transporters targets` 498.9 t against the stored 1,000 t reading "short", `Iron Hills Mining targets` 409.9 t); both tabs render, including six horizon dials, `DRAFT — NOT LOCKED`, `0 OF 365 DAYS` and the permanence warning. `set_monthly_target` driven from the dial → a real `monthly_targets` row (platform/2026-08/1500, `created_by` = the walkbot), and the screen re-read it as `1,500 t · actual 498.9 t · 33%`. `set_cycle_draft` driven → `draft {"d7": 800}` with `started_on` still NULL, which is the 2026-08-09 anchor fix behaving. The lock guard fires and names what is missing (*"Still unset: 14 days, 1 month, 3 months, 6 months, 12 months"*) and its dialog dismisses without blanking the console — the F7 shell-navigator fault is not present here. **One defect found and fixed by rendering it: the org-type band read "Every load what was hauled"** (a pill label interpolated into a sentence, all three types). ⚠️ **`lock_target_cycle` and `start_new_target_cycle` were deliberately NOT clicked**: locking is permanent, this is production, and undoing it would mean disabling a trigger on a live table. Their server side is live-verified (2026-08-08, through the RPCs and by raw UPDATE/INSERT bypassing them); the button in front of them is verified as far as its guard. Drive them the first time a real cycle is genuinely being committed. The rollover gap that used to be listed here is **fixed** — core v2.1 counts calendar days from `MlCycle.startedOn` and sums `cumulativeTo()` by date window, so `months` carries full history independently of the cycle; the RPC now emits from the earliest month with a target or a trip, floored at 24 months. |

**Targets — the scope rule.** The three scopes are **independent commitments**. A platform target is not derived from the org-type targets, and an org-type target is not derived from its companies'; they may disagree and a disagreement is not a bug. Rolling up was rejected deliberately (jean, 2026-08-08): it would mean a network number could only be set by talking every company into its share first, and one company joining or leaving would silently move a target already locked for twelve months. Note too that the org-type *actuals* genuinely cannot sum to the platform figure — one load has a mine, a buyer and a transporter, so it counts once under each. Same movement, three sides. This rule is also on `comment on table public.monthly_targets`.

**Targets — what an empty store is supposed to look like (do not report these as regressions).** `monthly_targets` starts empty, and several screens are built to say nothing rather than something invented:

- **The transporters overview draws no target line and no caption.** Until 2026-08-08 that chart drew a dashed line from a hardcoded `1352` captioned "Target 28.0k" — a label and a value that did not even agree, neither of them stored anywhere. It now reads `monthly_targets` at org-type scope, and **no target set means nothing is drawn**. The chart looks emptier than it used to; that is the fix working. The line appears the moment somebody sets a transporter target at `/super-admin/targets/org-type/transporter`.

  **It is drawn as a daily pace, not the month's figure** (2026-08-09). That plot is `DAILY · TONS`; a stored target is a month of tonnage. Laying 28,000 t on an axis whose busiest day is ~1,400 t pins the rule to the ceiling and flattens every real day into the floor — which is exactly how the reference render looked before this was fixed. The rule sits at `target ÷ days in month` and the caption reads `TARGET 903 T/DAY`, so it cannot be misread as the month's number. The legend key says "Target pace".
- **A dial with no target reads "Not set", not "0".** `target_tons = 0` means *not set* throughout, and renders differently from a real zero. A placeholder nobody chose that looks like a decision is the whole reason this system once reported against 28,000 t.
- **An unreached horizon renders dashed and grey, never red.** "Not yet judged" must not look like "missed".
- **Opening a targets screen mints an empty draft cycle** for that scope (`ensure_open_target_cycle`), starting on the 1st of the current month. Nothing is committed until six horizons are set and locked.

  ✅ **RESOLVED 2026-08-09** by `20260809100000_targets_lock_time_anchor.sql`. Kept here because the reasoning is the load-bearing part. Two problems used to follow from that sentence:

  1. **`get_targets_state` writes on read.** A read RPC that mints a row is surprising on its own, but the consequence is the real issue — see below. Bounded to one row per scope by the open-cycle unique index, so it cannot run away.
  2. **The twelve-month lock window is anchored by a page view.** `started_on` is set when the draft is minted, and both `guard_target_cycle` and `start_new_target_cycle` reopen at `started_on + 1 year`. So the length of the commitment depends on when somebody first browsed the screen, while the UI says "twelve months" regardless:

     | draft minted | locked on | actually locked for | screen says |
     |---|---|---|---|
     | 2026-08-01 | 2026-08-09 | 357 days | 12 months |
     | 2026-08-01 | 2027-01-15 | 198 days | 12 months |
     | 2026-08-01 | 2027-07-31 | 1 day | 12 months |
     | 2026-08-01 | 2027-08-02 | **none — the lock is a no-op** | 12 months |

     The last row is the one that matters: a draft left past its own anniversary can be "locked" into an already-open state. The immobility is the whole feature, and it would silently not exist.

  **The fix — one column, one meaning.** `started_on` is now NULL on a draft and set by `lock_target_cycle` to the 1st of the **following** month. Everything downstream still reads that single column, so there is nothing to keep in step.

  - *Why not a second `locked_on` column with `greatest(started_on, locked_on)`?* Because `close_due_target_cycles_job` keys off `started_on`: its `UPDATE` would hit a guard keyed off the other date, and that exception propagates out of the loop — **one stuck cycle would freeze the nightly close for every other scope.** It also leaves a months-long window where a cycle has finished measuring but can be neither closed nor replaced.
  - *Why the following month, not the current one?* Back-dating would mean d7 and d14 had already passed at the instant of commitment — the first two horizons judged on tonnage that moved before anyone agreed to them. That is a backdated score, not a commitment.
  - **A locked cycle is now immutable permanently**, not just until the anniversary. The old guard stopped firing once the year was up, leaving a committed record editable in place. The only transition out of `locked` is `closed`.
  - **`get_targets_state` no longer writes.** It synthesises an unstarted draft with a stable `draft:<scope>` id; the row appears on the first real write.
  - **The months window is no longer anchored to the cycle** — it had to stop being, since `started_on` can now be in the future and would otherwise hide the current month. As a side effect this also fixes the rollover gap: short-term history survives a cycle change.

  A cycle locked 15 Jan starting 1 Feb reads correctly throughout: locked, 0 of 365, six horizons pending, reopens 1 Feb the following year.

  **The reopen boundary is computed once, not twice.** `cycleComplete` and `daysUntilCycleReopens` read `MlCycle.reopensOn` — the same calendar arithmetic as the server's `started_on + interval '1 year'` — rather than counting to a flat 365. A cycle spanning 29 February runs 366 days; counting to 365 would have had the banner offer a new cycle a day before `start_new_target_cycle` would accept one, with nothing on screen to say which was right. Same fault as the anchor, one scale smaller. Pinned by `test/widgets/targets_payload_test.dart`.

  **A refused write is shown on the dial it belongs to.** `TargetsController` reports every write as a `TargetsWriteResult` keyed `m:<period>` / `h:<horizon>`; the workspace keeps those in a map and hands them to `MineLinkTargetsScreen.errorFor(key)`, which passes each one to its own dial. The typed value stays put, the border goes red, and `didUpdateWidget` will not overwrite the field while the error is showing — otherwise the re-read that follows a refusal would wipe the figure being corrected. Cleared on the next write for that key that succeeds. Whole-cycle failures (lock, start-new) carry no key and still use the notice, because they belong to no single dial.
| Driver mobile app (Trip screen + bottom nav) | 🟢 Built | `driver_routes_screen.dart` rebuilt to the driver-mobile mockup (Current Trip hero: status pill, plate + commodity, From→To timeline, lifecycle-aware Directions / Arrived-at-loading / Arrived-at-offloading / Upload POD, stats strip, live-location, Recent Trips); mobile bottom nav **Dashboard · Trip · Profile** (`portal_shell_layout.dart` / `portal_scaffold.dart`, driver role only — drawer, chat dock + bell all kept). See "Driver mobile app" below. |
| Account deactivation (in-app, R-1 of the 2026-08-19 release-hardening plan) | 🟢 Built | Built 2026-08-19 (`docs/superpowers/specs/2026-08-19-release-hardening-design.md`). Originally scoped as account **deletion**; Jean ruled mid-plan that nothing on this platform is ever deleted, so this is **deactivation**, fully reversible. `public.account_deactivation_requests` (request → approve → deactivate flow, `MLD01`/`MLD02`), `deactivate_account` (revokes sessions, refuses sign-in, `employees.status = 'inactive'`) and `reactivate_account` (platform-admin only, returns `banned_until` to null) — migrations `20260819100000`/`105000`/`110000`/`115000`/`120000`/`125000`. Cron backstop applies due deactivations. End-to-end cycle (request → approve → deactivate → reactivate) driven against a throwaway account inside a rolled-back transaction, 2026-08-19. 🚨 **This does NOT close the app-store account-deletion requirement.** Google Play's User Data policy and App Store §5.1.1(v) do not accept deactivation in place of deletion — see COMPLETION-CHECKLIST.md S9-1a. Marked 🟢 because the deactivation feature itself is fully built and wired, not because it satisfies a store submission. |
| Push notifications (R-2 of the 2026-08-19 release-hardening plan) | 🟡 Partial | Built 2026-08-19: `public.device_tokens` (register/unregister RPCs, RLS, a notifications-insert trigger that fans out via `pg_net`, migration `20260819090000`), `PushService` + platform (Android/iOS) wiring in Dart, and both a web release build and a debug APK succeeding with no Firebase config present (graceful degradation). 🚨 **Stays 🟡 — no Firebase project exists, so no FCM message has ever been delivered to a handset.** The DB half, the trigger, the edge function and the Dart half are all verified; the last mile is not, and cannot be from this environment. Six artifacts are still owed from Jean before it can move — see `docs/push-setup.md`. iOS additionally unverified end-to-end (no reachable Apple Developer account). |
| Crash reporting leaving the device (R-3 of the 2026-08-19 release-hardening plan) | 🟢 Built | `crash_reporter.dart`'s seam (`FlutterError.onError`/`PlatformDispatcher.onError`/`runZonedGuarded`/`ErrorWidget.builder`, all installed first thing in `main()`) now has a real destination: `SupabaseReportingSink` → `public.crash_reports` (main project; RLS INSERT `to authenticated` only — deliberately no `anon` policy, the publishable key is public and this is a 500 MB free-plan project; SELECT `is_platform_admin()` only), server-side length caps matching the client clip caps, and dedup (60s window, folds repeated occurrences of the same fingerprint into one row) — migrations `20260819140000`/`145000`, pruned at 90 days by `prune_telemetry_job()` (`20260819150000`). Live-verified 2026-08-19: 36 real rows in the table, one fingerprint (a non-fatal `ListTile` advisory), all inside a 7.3s window that **predates** the dedup commit (`e176391`) by ~18 minutes — it is the original burst that motivated the dedup work, not evidence the fix collapses a live burst; no fresh burst has landed since the fix shipped to observe that directly. A session that never signs in is never collected (accepted gap, `SupabaseReportingSink` buffers and drains on next successful send). |

**Rule for agents:** move an item to 🟢 **Built** in this table **only when it is genuinely, fully implemented** — complete frontend + backend, DB/Supabase and UI both done, the full flow properly wired and in a proper working state. Anything less stays 🟡 or 🔴. Do not mark Built on the basis of a stub, a single screen, or a happy-path demo. When you complete something, update its row honestly (and only that row).

### Pre-trip: request → approval → linking (this comes BEFORE any trip exists)

Every trip in MineLink originates from a **request** that an org submits to the **super global admin** (= the existing `super_admin` / platform admin — NOT a new higher tier; extend that role). The admin approves (or bounces for revision), then **links** the parties, which creates a `scheduled` trip that enters the `TripStatus` lifecycle (§ next). **All four request types ultimately lead to a scheduled trip.**

**Request lifecycle (new — these are the wire strings):**
`requested → sent_back → resubmitted → approved → linked`
- `sent_back ⇄ resubmitted` is a revision loop: admin phones the requester, sends it back, requester edits and resubmits, admin re-reviews. May repeat.
- Model this as its own enum on the request table (e.g. `RequestStatus`), mirroring the `TripStatus` pattern: explicit `.wire` string + tolerant `parse()`. Do **not** overload `TripStatus` for it — they are different state machines.

**The four request types (separate entities, keyed by the requesting org type — do NOT collapse into one table with a type flag):**

| # | Request | Who can submit | Super-admin inbox screen (under **Requests** sidebar dropdown) |
|---|---------|----------------|----------------------------------------------------------------|
| 1 | Request Transporter/Routes | mine/supplier **and** buyer (identical fields) | split into two screens: **Mine/Supplier Transportation Requests** and **Buyer Transportation Requests** |
| 2 | Request Product | buyer only | Product requests screen |
| 3 | Request Buyer | mine/supplier only | Buyer requests screen |

The super-admin always sees a **clean, non-editable** rendering of exactly what was submitted (except when editing the outbound portion during linking — see below).

**Request 1 — Request Transporter/Routes** (shared; already implemented on the buyer side, reuse it for mine/supplier). Required edits to the existing form:
- Rename field "No. of slots" → **"Number of Trucks Required"**.
- Replace the "Ongoing" checkbox + "No fixed starting period" text with a **dropdown**: `Ongoing` | `Single request`.
  - `Ongoing` → select **start date only** (no end date) → optional **Route notes** → submit.
  - `Single request` → select **start date**, then **end date** → optional **Route notes** → submit.

**Request 2 — Request Product** (buyer only). Fields:
- `Product` — placeholder: "Please add all required product specifications here"
- `Tons Required` — numeric input only; app auto-appends a visible `t` suffix (e.g. `200t`, `4000t`)
- `Payment Terms`
- `Price Per Ton`

**Request 3 — Request Buyer** (mine/supplier only). Fields:
- `Tons Available`
- `Product Specifications`
- `Payment Terms`
- `Upload Lab Results/Report (PDF)` — **multi-file**; unify drag-drop area and upload button into one control; support one-by-one, multi-select, and multi drag-drop; label it clearly that multiple PDFs are allowed
- `Upload picture/image/photo` — optional
- `Price per ton`
- `Transaction` — dropdown: `FOB` | `FOT`
- `Product Location` — two entry modes: (a) **map picker**, or (b) plain manual **text** (no lookup triggered). See map spec below.

**Driver navigation destination — the leg decides which pin wins (2026-08-17).**
`get_trip_nav_destination` returns a coordinate only when it genuinely describes
the point the request named (a `?q=lat,lng` link) or when the request named no
point at all; otherwise it hands back the named point as `address`/`point_name`
with `found: false` **plus** the party company's primary pin as `fallback`, and
the client picks:

- **Load leg → the company pin first.** The party is the mine and its primary
  location *is* its collection point. Geocoding the words instead is worse:
  "Iron Hills Mine, Mpumalanga" resolves through the ladder to *"The Courier
  Guy, Tonga St, Tonga, Mpumalanga"* — a courier depot 460 km from the gate,
  offered with no hint that it is a guess.
- **Offload leg → the named point first.** A buyer's primary location is its
  registered office, and its delivery point changes per order. A load booked to
  "Durban Port" used to navigate to the buyer's Rosebank office in
  Johannesburg — 570 km inland — with `found: true`, so the client's own
  geocoding step was never reached and nothing downstream ever questioned it.

The asymmetry is in the data model, not a hedge: the load leg's party is the
site the product is standing on; the offload leg's party is a company whose
delivery point moves. Whichever wins is named on the driver's screen, and a pin
that is *not* the booked point says so.

**Product Location map picker (build it 100% free, no billing, no API key):**
- Map visuals: **`flutter_map` + OpenStreetMap tiles** (already in `pubspec.yaml` with `latlong2`). Interactive drag/pan/zoom; long-press to drop a pin.
- Search/geocoding: a **staged chain** in `place_search_service.dart`, not a single provider. In order: a pasted map link → the company's own saved locations → **MineLink's own `place_index`** → Nominatim as typed → Nominatim relaxed → Photon. Nominatim is rate-limited to 1 req/sec by its usage policy and the gap is enforced in the service, not left to the caller's debounce.

  **`place_index` exists because the free OSM-backed geocoders cannot answer South African addresses.** Measured 2026-08-15: OSM has no record of "Trumpet on Keyes", and no Westway Road in Fourways at all — and Nominatim, Photon, LocationIQ and Geoapify all read OSM, so none of them can ever return them. Overture Maps does hold them. **Do not "simplify" this back to a single hosted geocoder**; it would break addresses that are already saved in `company_locations`.

  **It lives on the SECOND Supabase project** (`Mine-Link_Extra_Data`) and is reached through `PlaceIndexConfig`, never `SupabaseConfig` — see §1 and §10.2. South Africa only: 611,841 ZA rows; the other 28 countries were dropped 2026-08-16 as MineLink operates only in ZA until further notice. Loaded by `tools/overture_import.py`, moved by `tools/place_index_move_project.py`. The stage **degrades to nothing rather than throwing** if that project is unreachable — which is a normal state, since free projects pause after ~7 quiet days — so the search silently falls back down the chain.
- Flow: user types an address in the search bar → map centers on the returned lat/lng → user confirms the pin → save the location as a universal map link.
- **Saved format:** `https://www.google.com/maps?q={lat},{lng}` — this is the corrected, working universal link. (The original spec wrote `https://google.com{lat},${lng}`, which is malformed and opens nothing; use the `?q=` form. Do not "revert" this.)

**Linking → Route ID (super-admin action after `approved`).** For a route/transporter request, on approval + linking the system creates a **Route ID** — an entity holding all the request info that will go to the transporter: commodity details, payment terms, loading point, offloading point, operational hours, and everything else from the request **except price per ton** (see pricing below). The admin first selects a **mine**, then proceeds through pricing and the due-diligence gate before selecting a transporter.

**Super-admin pricing / margin (price per ton is set here, not carried from the request).** The admin manually sets pricing by entering their **profit in R (South African Rand / ZAR)**. The app subtracts that margin from the agreed price to show: the admin's total cut, and the resulting **transporter's price per ton**. This must be recorded in a **super-admin-only margin ledger** — modelled like the recon tables but with the pricing-relevant fields (Route ID, agreed price, admin R cut, resulting transporter price/ton, currencies involved). The transporter only ever sees their resulting price, never the admin's margin.

**Due-diligence gate (ordered confirmation flow before dispatch).** Before the route reaches a transporter, the admin sees the full system-generated package (all Route ID info + the new transporter price) and steps through:
1. **Preview** of exactly what the transporter will receive → "Approve and send".
2. Confirmation: "Are you sure the information you're sending to the Transporter is correct?" (Yes / No).
3. On Yes → prompt "Due diligence done correctly, accurately and accepted" with a **green tickable checkbox**; ticking it asks "Are you 100% sure all of the information is correct?" (Yes / No).
4. On Yes → the **list of all transporters** on the app; admin selects one.
5. Final confirm: "Are you sure you want to send this to [selected transporter name]?" (Yes / No). On Yes → dispatched to the **transporter admin**; the request moves to `linked` and a `scheduled` trip is created.

**Available routes (learned/reusable routes).** The system remembers dispatched routes and stores them as reusable **"available routes"**, visible to the super-admin. The admin can **assign** an available route to a specific requesting org (buyer or mine/supplier). Once assigned to an org, it appears on that org's **dashboard under "Available routes"** as a selectable that **auto-fills the Request Route form** when chosen — the requester can then edit the pre-filled info or submit as-is. Assignment can be made permanent by the admin.

**Transporter route marketplace (super-admin only, for now).** The learned routes also populate a **marketplace of all routes all transporters run**, currently **visible to the super-admin only**. Add a note in that UI stating it will become **public** once the developer implements it — at which point requesters will be able to browse routes each transporter offers and has successfully completed. Keep it super-admin-gated until then.

**On approval + mine selection — auto-create the stockpile and notify the Supervisor FIRST.** At the moment of linking, the system **auto-creates the order's capped stockpile** at the selected mine (see "Order-driven stockpiles & collect-when-ready" below) and notifies that mine's **Supervisor/Foreman** (+ owner / admin / management): "*X tons of X product for Buyer X has been approved by [selected Mine/Supplier name]. A stockpile has been created for this order (cap X t) — add product to it on site as it arrives; [transporter name] is alerted every full load so their trucks only roll when there is enough to collect.*" Interpolate the real request values. The supervisor **maintains** the stockpile as physical product is added — they **no longer create it by hand** (see below).

**Transporter admin: accept route → allocate fleet & drivers.** After the transporter admin **accepts** the route, they're taken to a screen listing **only available trucks** (registered in fleet management, not currently on a route). They select the **Number of Trucks Required**, assign those trucks to the route, then **assign drivers** to each truck.
- **Driver-per-truck rule:** default max **2 drivers per truck** (long-distance). A button lets the admin **request** the ability to add more from the super-admin — approvable up to a **max of 5**.
- **Availability state machine (trucks + drivers each have status):**
  - Trucks: **Available** ↔ **Trucks On Route**. Drivers: **Available** ↔ **Driver On Route** (shown red).
  - Assigning a truck+driver to an accepted route moves both to the On-Route states and lists them under a **"Trucks On Route"** screen (truck + its assigned driver together).
  - The admin can **only select trucks and drivers whose status is Available** — On-Route trucks/drivers are unselectable until the route completes and they return to Available.
- The **linked buyer can see the trucks the transporter allocated** to fulfil their request.

**System side-effects of allocation** (create): Truck-route relationships ("Trucks On Route"), driver assignments ("Driver On Route"), the scheduled trip. (Update): route dashboard, driver notifications, the **active route list** (combined Trucks-On-Route + Driver-On-Route for accepted routes, so the transporter sees which driver is on which truck), and the available-fleet / available-drivers pools.

### Order-driven stockpiles & collect-when-ready (dispatch → fill → +30-ton alerts)
🟢 Built — `supabase/migrations/20260715090000_stockpile_order_flow.sql`. _This refines the "fire the Supervisor notification" paragraph above: the stockpile is now **system-created and capped**, not hand-made by the supervisor._ Everything is linked and talks to each other (request ↔ stockpile ↔ buyer ↔ transporter ↔ mine).

**On dispatch, the system auto-creates the stockpile.** The moment the super-admin links + dispatches a route (`link_and_dispatch_request`), one stockpile is minted at the selected mine for that order — `max_cap_tons` = the request's ordered tonnage, `balance_tons` = 0 — linked to the request, route, buyer and transporter (`stockpiles.request_id / route_id / transporter_company_id / max_cap_tons`; one stockpile per request, enforced by a unique index). **This is when the whole flow starts.**

**Supervisors can no longer freely create stockpiles.** The old "Add stockpile" control is removed; `stockpiles` INSERT is RLS-blocked (`with check (false)`) so only the SECURITY DEFINER dispatch function mints them — no orphan, hand-made stockpiles.

**Dispatch fires three notifications** (via `notify_company_role` / `create_notification_internal` into `notifications`, `importance: high`, carrying `metadata.stockpile_id / request_id / route_id`):
- **Mine supervisor** (company owner + `supervisorForeman` / `admin` / `management`) — "New stockpile to prepare"; **clickable**, deep-links straight to the auto-created stockpile on the **Supervisor** tab (`metadata.stockpile_id` → `pendingStockpileFocusProvider`).
- **Transporter** (owner + `admin` + `management`) — "New order assigned".
- **Buyer** (owner + `admin` + `management`) — "Order accepted & dispatched".

**Supervisor fills the stockpile on site, capped.** "Add tons" goes through the `stockpile_add_tons(uuid, numeric)` RPC (never a client-side balance write): it enforces the order cap (cannot exceed `max_cap_tons`), writes the balance + ledger row atomically, and returns the new balance. The Supervisor card shows a fill bar, `balance / cap`, and "N full load(s) ready", and disables "Add tons" at the cap.

**Every +30 t = one full trailer load → collect alert.** Each time the balance crosses a new 30-ton multiple, `stockpile_add_tons` sends a "Stockpile ready to collect — N full load(s) ready" alert to the **buyer and transporter** (owner + admin + management). This is how the parties know when to roll — so a driver is never sent to sit and wait, and never travels with a half-empty trailer.

**Buyer + transporter see the same live fill.** RLS lets the linked buyer and the dispatched transporter read the order's stockpile + its additions; both see the live `balance / cap` + loads-ready — on the buyer's request card and the transporter's accepted-route card (`OrderFillLine`, `orderStockpileProvider`).

### Driver assignment notifies the driver
🟢 Built — `supabase/migrations/20260715100000_driver_assignment_order_aware.sql`. Once the transporter admin selects a truck and then **assigns a driver** to it (`add_vehicle_driver`), the driver themselves is notified. The message is **order-aware**: if the truck already carries an active trip for a dispatched order, it names the load ("assigned to {truck} to collect {commodity} from {loading} → {offloading}") and carries `metadata.nav_tab = 'My routes'` so tapping it opens the driver's Trip tab. (Company management still gets its own "Driver Assigned" notice.)

### Driver mobile app (Driver role)
🟢 Built — a faithful recreation of the driver-mobile mockup ("Driver App — Manage your trip"), in `driver_routes_screen.dart`. On the narrow (mobile) layout the portal shell shows a **bottom nav — Dashboard · Trip · Profile** (`portal_shell_layout.dart` + a `bottomNav` param on `portal_scaffold.dart`, driver role only). The drawer still holds the full destination list (Live map, Truck locations, Truck positions, Driver, Profile) and the chat dock + notification bell are unchanged — the bottom nav is **additive; nothing is lost**.

The **Trip** screen is the hero:
- **Current Trip** card — status pill (`TripStatus.label`), truck **plate pill** + commodity, a **From → To route timeline** (loading → offloading from the linked route), then lifecycle actions: **Directions** (opens maps to the loading point, then the offloading point once loaded), **Arrived at loading** (`→ arrived_at_mine`), **Arrived at offloading** (`→ offloaded`), **Upload POD** (the existing POD + photo + signed-waybill flow). Buttons are **lifecycle-aware** — enabled/dimmed by `TripStatus.step`, so nothing can be actioned out of order.
- A compact **stats strip** (Loads · Delivered · Tons), the **Live location sharing** toggle, and a **Recent Trips** list. With no active trip the card shows a clean empty state.

### Weighbridge, Net Weight calculation & waybill (Load Controller)

Two weighs per trip, both captured by the **Load Controller** via **photo + manual number entry**:
1. **Tare Weight** — the completely empty truck + trailer (first weigh, before loading).
2. **Gross Weight** — the total combined weight of truck + cargo (second weigh, after loading).

**The app auto-computes `Net Weight = Gross Weight − Tare Weight`** (the cargo alone). This is a derived value — compute it, don't ask the controller to enter it. Net Weight is the number that flows everywhere downstream:

- **Waybill (auto-generated, non-editable, print-ready):** on Net Weight calculation, the app generates a waybill. It must **look exactly like the reference layout** 🟢 (see below) — the app fills every field automatically from data it already holds and **auto-places signatures** from user profiles; the Load Controller only prints and hands it to the driver. (This marker was still 🔴 until 2026-08-17, contradicting the 🟢 four lines below it and the §4 row. The slip was read field by field against `assets/Varsiwave waybil 2l.png` on 2026-08-17 and matches.)
- **Stockpile decrement:** the Net Weight is subtracted from the stockpile the truck loaded from. The cycle repeats until that stockpile reaches **0 tons**, at which point the transaction/workflow is **complete**. Extend the existing `stockpile_entry` / `stockpile_transaction` models for this — do not create parallel stockpile tables.

**Waybill layout & field mapping** 🟢 (Built — matches the real reference image `assets/Varsiwave waybil 2l.png`: bold serif company header + "MANUAL WAYBILL" subtitle, cream background, thin outer border, boxed NUMBER / SECTION, ruled underlines, heavy divider before the received block):

| Waybill field | Auto-filled from |
|---|---|
| **Header (company name)** | the **Mine/Supplier (SOURCE)** name — dynamic, not a fixed brand. Subtitle "MANUAL WAYBILL" stays static. |
| **NUMBER** | the generated waybill number (unique/sequential; same value used in the recon `WAYBILL NUMBER` column) |
| **SECTION** | the **Mine/Supplier (SOURCE)** name again — same value as the header, repeated in this field |
| **TRANSPORTER** | transporter company name (from Route ID / trip) |
| **FLEET/REGISTRATION NO.** | allocated truck's registration (from the fleet vehicle) |
| **DESTINATION** | offloading point (from Route ID) |
| **TRUCK SEAL SERIAL NO. 1–4** | seal numbers entered by the Load Controller at loading (seal record); up to 4 |
| **PRODUCT** | commodity (from Route ID / request) |
| **TONS** | **Net Weight** (`Gross − Tare`), e.g. `36.22` |
| **DISPATCHED BY** | Load Controller name (the user generating/printing it) |
| **SIGNATURE** (dispatch block) | Load Controller's saved **transparent-PNG signature**, auto-placed at dispatch |
| **DATE / TIME** (dispatch block) | dispatch/generation timestamp |
| **RECEIVED BY** | driver/receiver name at offload |
| **SIGNATURE** (received block) | **Driver's** saved signature, auto-placed at offload |
| **DATE / TIME** (received block) | offload/receipt timestamp |

Generate as a non-editable, printable document (use the `pdf` + `printing` packages already in `pubspec.yaml`). Signatures come from the per-user profile signature field (§ Parties & roles) — render the transparent PNG onto the signature line; never ask the user to re-sign inline if a profile signature exists.

The authoritative reference image is **`assets/Varsiwave waybil 2l.png`** (supplied 2026-07-12); `waybill_pdf.dart` was tuned against it and rasterised side-by-side to verify. `waybill_reference.html` was the earlier approximation and is historical. Header/label fonts use the app's embedded Fraunces / Plus Jakarta Sans (closest brand faces to the slip's condensed print).

### Recon tables (auto-populated, exportable)

On every truck's **check-in → check-out**, the app auto-appends a row to a recon table. **Extend the existing `tons_out_entry` model/screen** rather than building new tables. Two views of the same data:
- **Combined recon table** — every truck from every transporter in one table. Visible to **the mine + super-admin only**.
- **Transporter-based recon table** — same fields, filtered per transporter. Visible to **the mine, the linked buyer, and that transporter**.

Both are **exportable** (the portal already has `excel` + `pdf` + `share_plus`). Columns, in order:
`DATE` · `TIME-IN` · `WAYBILL NUMBER` · `TRANSPORTER NAME` · `TRUCK REGISTRATION NO` · `DESTINATION` · `PRODUCT` · `SOURCE` · `CUSTOMER` · `NET MASS` · `TIME-OUT`

- **`SOURCE`** = the **Mine/Supplier** name where product is loaded (the company Security / Load Controller / Supervisor are registered under; the mine the super-admin allocated the transporter's trucks to).
- **`CUSTOMER`** = the **Buyer** name the transporter is collecting for.
- **`NET MASS`** = the **Net Weight** (`Gross − Tare`), i.e. the cargo. ⚠️ Not any tare/first-weigh figure — it's the computed cargo weight.
- **`DATE`** displays only on the first row of each date group (blank on subsequent rows until the date changes) — a display grouping detail, not a data change.
- Footer **`Total Tons=`** = app auto-sums all `NET MASS` rows; recomputed and maintained automatically after every new row.

**Live period-total stat cards (above the table, styled like the dashboard stats):** a row of live summary cards showing rolling `NET MASS` totals — **Day**, **Week**, **Month**, **Year**, **Total**. Label each card with the **full word** (not `D=`/`W=`/`M=`/`Y=`/`T=` abbreviations). They update live as rows are added.
- **Total** is a genuine all-time cumulative that must always show the correct real number for all time and never stops growing.
- Each card has an always-available **Show/Hide** toggle so users can choose which stats are displayed; hiding never removes the underlying data, only its display.
- **Implementation is left to whatever keeps the numbers correct and is healthiest for the app** — correctness of the displayed value is the hard requirement, the method is not prescribed. (Day/Week/Month/Year are naturally windowed sums over recon rows; Total is best kept as a maintained running aggregate rather than re-summing the whole table on every load — but any approach that stays correct at scale is acceptable.)

A **Filter** control accompanies the table.

### Reconciliations screen (dedicated — the system's automated cross-checks)

A dedicated **Reconciliations** screen holds all reconciliations the system performs, distinct from the raw recon/tons-out tables above (those are the source data; this screen is the cross-check layer). It has **two sides** for every reconciliation:

**Side A — Raw (as-submitted, before any system reconciliation).** Everything exactly as the system captured it, prior to applying reconciliation logic. It is:
- **Viewable** in-app, and **exportable** to a **styled, labelled Excel spreadsheet** (also CSV and PDF).
- **Editable via round-trip:** the user exports, edits externally, then **re-uploads** (Excel / CSV / PDF). The system then retains **exactly two versions** — the **original** (pre-edit, never overwritten) and the **latest edited upload** (a new upload replaces the previous edited copy, not the original). Both are shown side by side, clearly labelled (e.g. "Original" vs "Edited — uploaded {date}"), kept for future enquiries.

**Side B — Reconciled (what the system already computed automatically).** The completed automated reconciliations:
- **Trip weight variance** — mine Net Weight (authoritative) vs offload delivered tons, with computed variance (lost/stolen/swapped mass).
- **Stockpile in/out/balance** — supervisor additions vs Net-Weight load-out decrements vs remaining balance, to the 0-tons completion point.
- **Total roll-ups** — buyer totals, transporter tons-delivered, route totals, reconciled against the sum of per-trip Net Weights.
- **Pricing/margin** — agreed price vs admin R cut vs transporter price per Route ID.

Side B is **system-owned and view-only** for everyone who was part of the transaction, and **exportable**. It is **editable only by the super-admin and the transporter/route requester**; their edited export can also be re-uploaded under the **same two-version model** (original + latest edited, both labelled and retained).

**Access & scoping:**
- **Super global admin** — sees and edits **all** reconciliations, globally.
- **The org that initiated the flow** (the buyer or mine/supplier who started that trip/route request) — can see and edit **their own**.
- **All other orgs in that loop** (mine, transporter, buyer who participated) — **view-only**, scoped to only the parts of the transaction they were involved in.
- (Access is intentionally limited for now — the initiator + super-admin edit, others view. This will be revisited later.)

Enforce the edit/view boundary in **RLS + RPCs**, not just the Dart UI. Store version pairs as distinct rows/records (original + edited) with a clear label and timestamp — never mutate the original in place.

### Trip lifecycle — canonical, do not invent new statuses
Defined in `lib/features/portal/models/trip_status.dart`. The `enum TripStatus` maps 1:1 to the `trips.status` wire strings written by the cascade RPCs (`set_trip_status`, `record_truck_load`, `record_pod`). Ordered lifecycle:

`scheduled → en_route_to_load → arrived_at_mine → loading → loaded → left_mine → en_route_to_offload → offloaded → completed` (plus `cancelled`, which sorts last).

- Always persist/read the exact `.wire` string; use `TripStatus.parse()` for tolerant reads (it maps legacy values like `draft` onto canonical).
- `isActive` = not completed and not cancelled.
- When adding UI for a status, colour it via `MlTone` (see §5), not ad-hoc colours.
- A trip enters at `scheduled` only after a request is `approved` + `linked` (see pre-trip section above). The mine-floor sequence — Security check-in (`arrived_at_mine`) → Load Controller tare weigh → `loading` → `loaded` → Load Controller second weigh + info + photos → Security check-out (`left_mine`) — is the **same physical flow** described per-role; it is not a separate system.
- **Display labels vs wire strings:** the stored wire strings stay as above (renaming them needs a migration and breaks existing rows — do not). Human-readable labels may read: Scheduled · On Route to Load · Arrived at Mine · Loading · Loaded · Left Mine · En Route to Offload · Offloaded · Completed. Change labels in the `TripStatus` display layer only.

**Per-role actions & system side-effects along the lifecycle:**

| Stage / status | Role | Action | System creates / updates |
|---|---|---|---|
| `scheduled` → `en_route_to_load` | **Driver** (mobile) | Opens app, views assigned route (loading point, offloading point, commodity, route notes), starts navigation | Trip status → On Route to Load |
| (in transit) | **Buyer / Mine / Transporter** owners & permissioned users | View truck location, ETA, monitor active trips | Uses phone GPS or tracking API; updates live truck map, ETA, route activity |
| → `arrived_at_mine` | **Security** | Search truck registration, mark **Arrived** | Trip status, arrival timestamp, loading activity dashboard, mine loading queue. Notifies Load Controller; updates Supervisor visibility |
| `loading` → `loaded` | **Load Controller** | Search truck reg, tare + gross weigh (photo + manual), enter seal numbers, upload pictures, save wayslip/waybill info | Recon record, load record, seal record. Updates tons-out dashboard, buyer recon totals, transporter tons delivered, route totals, stockpile reductions, loading activity |
| → `left_mine` | **Security** | Mark **Left Site** / check truck out | Departure timestamp, GPS monitoring, active-trips dashboard, ETA. Status → On Route to Offload (`en_route_to_offload`) |
| → `offloaded` | **Driver** | Upload **POD** image, enter **delivered tons** (re-weigh at offload), mark offloaded | Delivery confirmation, recon completion, buyer/transporter/route totals |
| → `completed` | system | Finalizes recon, tons delivered, reporting metrics, route statistics, historical analytics | Trip status → Completed |

**Two-weight reconciliation (important).** The **mine Net Weight** (loaded at source) is the **authoritative figure for recon and billing**. The **offload delivered tons** (driver's re-weigh at destination) is stored **separately** as the delivery figure. The system compares the two and surfaces the **variance** so lost/stolen/swapped mass en route is visible. Store both plus the computed variance — never overwrite one with the other.

### Core logistics models (`lib/features/portal/models/`)
`mine_trip.dart` (inbound trip for Security check-in / Load Controller, backed by `list_mine_inbound_trips` RPC), `stockpile_entry.dart`, `stockpile_transaction.dart`, `tons_out_entry.dart`, `transportation_request.dart`, `logistics_models.dart`, `workflow_notification.dart`.

### Parties & roles
- **Org types** (`OrgType`): `mineSupplier`, `buyer`, `transporter`.
- **User roles** (`UserRole`, in `lib/features/auth/models/user_type.dart`): `security`, `controllerWB` (weighbridge controller), `supervisorForeman`, `driver`, `admin`, `management` (plus org-level `mineSupplier`/`buyer`/`transporter`). Roles available per org type come from `UserRole.getRolesForOrgType()`.
- **Access control:** `OperationsAccessPolicy` (`lib/features/operations/models/operations_models.dart`) gates which operations tabs a role can see/create. Respect and extend these policies rather than bypassing them in the UI. Enforce the real security boundary in Postgres RLS + RPCs — the Dart policy is UX, not security.
- **Super admins are equal — remove the child-admin concept.** 🟢 (Done 2026-07-12: child functions/columns dropped, both admins full-rights.) There must be **no "child super admin" / parent-child admin hierarchy**. Both super admins are **main super global admins with identical full rights and functionality**. The current code has child-admin logic embedded across `lib/features/super_admin/**` (repositories, `platform_role.dart`, `platform_permissions.dart`, screens, providers — ~90+ references). This must be **removed/flattened**: collapse any child/parent role distinction into a single full-rights super-global-admin role, and drop child-admin creation, scoping, and permission gating. Do this carefully with a migration for any DB role/permission columns; verify RLS still holds after flattening.
- **Per-user signature (all users, all org types, all companies, and both super admins).** 🟢 (Built — draw canvas → transparent PNG in the `signatures` bucket, `profiles.signature_url`.) Every user profile gets an **"Add signature"** field where the user **draws their own signature** (canvas). It is saved to their profile as a **transparent-background** image and reused to **place/sign wherever a signature is needed** in future (e.g. waybills, PODs, approvals). Applies to every role and org type without exception, including both super global admins. Store the signature as a transparent PNG in Supabase Storage, referenced from the profile; render it wherever signing is required.

### Operations tabs (`OperationsTab`)
`minerals`, `transactions`, `weighbridge`, `loads`, `security`, `gate`.

### Vocabulary quick-reference
mine (supplier) · buyer · transporter · driver · trip · waybill (auto-generated, header = SOURCE mine, auto-signed) · POD (proof of delivery) · weighbridge · Tare Weight (empty truck+trailer) · Gross Weight (truck+cargo) · Net Weight (cargo alone = Gross − Tare) · stockpile · tons-out · recon table (combined + transporter-based; CUSTOMER = buyer, SOURCE = mine) · load control · gate check · seal (sealRequired) · commodity / mineral · fleet allocation · truck/driver availability (Available ↔ On Route) · Route ID · available routes (learned, auto-fill) · route marketplace (super-admin only for now) · admin margin (in R / ZAR) · due-diligence gate · offload variance (mine Net Weight vs delivered tons) · reconciliations screen (Side A raw + Side B reconciled; two-version edit round-trip) · transaction (supplier↔buyer↔transporter) · request (transporter/route, product, buyer) · super global admin (= super_admin; both admins equal, no child-admin) · profile signature (transparent PNG, all users) · approval · linking (mine + transporter) · order-linked capped stockpile (system-created, one per order, `max_cap_tons`) · +30t collect-ready alert · order-aware driver-assignment notification · live stockpile fill (buyer + transporter) · driver mobile app (Dashboard/Trip/Profile bottom nav) · FOB / FOT.

---

## 5. Design system & UI conventions

Everything is tokenized in `lib/core/design/tokens/ml_tokens.dart`. Use these, never raw values:

- **`MlTokens`** — raw scale: brand cyan (`accent` = `cyan500` = `#00B5D8`), navy portal chrome, slate neutrals, status hues, radii (`rXs`…`rPill`), elevation (`shadowXs`…`shadowDrawer`), motion (`durFast`/`durBase`/`durSlow`, `easeOutCubic`), layout constants (`sidebarWidth`, `appBarHeight`, `contentMaxWidth` = 1280, `contentPadding` = 28).
- **`MlSemantic`** — brightness-aware aliases (`surfaceApp`, `surfaceCard`, `textStrong`, `borderCard`, etc.). Get via `MlSemantic.of(context)`. **This is how you support light/dark correctly** — never branch on brightness manually with hardcoded colours.
- **`MlTone`** — status/lifecycle hues with fg/bg pairs and tinted icon "wells". Semantics: `transit` (blue) = in transit · `atMine` (amber) = at mine/pending · `done` (green) = loaded/arrived/available · `warn` (orange) = maintenance/departure · `error` (red) = declined/error · `neutral` · `accent` (cyan). Call `.colors(brightness)` and `.well(brightness)`.

### Typography
Fonts registered in `pubspec.yaml`: **PlusJakartaSans** (`fontSans`, UI), **JetBrainsMono** (`fontMono`, use for codes/plates/reg numbers/tonnages), **Fraunces** (`fontSerif`, display accents). Type scale is `fsDisplay`…`fsMicro` in tokens. Status pill labels are UPPERCASE.

### Layout
Responsive breakpoints in `lib/core/layout/app_breakpoints.dart`. The portal uses a fixed sidebar (`sidebarWidth` 274 / collapsed 78) + top app bar (`appBarHeight` 72), content capped at `contentMaxWidth`. Reuse `lib/features/portal/widgets/portal_shell_layout.dart` for portal pages rather than rebuilding chrome.

When designing new UI, favour the existing card/well/pill vocabulary already present in the portal and super_admin widget sets for visual consistency.

---

## 6. Supabase & data rules

- **All DB access goes through a feature `service` (or a `core` repository).** Screens and providers must not call `SupabaseConfig.client` directly — follow the pattern in `lib/features/operations/services/operations_service.dart` (typed methods returning models via `Model.fromJson`).
- **Pick the right client.** `SupabaseConfig.client` is the main app database. The **extras** project has its own client, `PlaceIndexConfig.client`, and it is nullable on purpose — that project is free-plan and can be paused, so callers must degrade rather than throw (see `_placeIndexLookup`). Never call `Supabase.initialize` a second time for it: that singleton belongs to the main project and re-initialising it repoints the whole app. See §1 and §10.2.
- **Lifecycle mutations go through the cascade RPCs** (`set_trip_status`, `record_truck_load`, `record_pod`, `list_mine_inbound_trips`, etc.), not ad-hoc table updates — they keep `trips.status` and related rows consistent.
- **Migrations** live in `supabase/migrations/` — **for the main project**. Migrations that apply only to the extras project go in **`supabase/extras_project/migrations/`** (see its README), so they cannot be swept into a `db push` against main. Before adding/pushing: read `supabase/MIGRATION_HYGIENE.txt`. Before `supabase db push`, list remote migrations (Supabase MCP `list_migrations` or dashboard) and avoid re-applying the same objects under a second filename.

  **`create or replace function` cannot add OUT columns.** Adding a column to a `returns table (...)` is a return-type change, and Postgres refuses it outright — `42P13: cannot change return type of existing function`. A migration that widens a function's result MUST `drop function if exists` first. `20260816100000` did not, so the whole `place_index` chain could not run from cold: every database that had run an earlier migration already held the narrower version, meaning `supabase db reset`, a restore into a fresh project, and CI would all have failed there. Fixed 2026-08-16 and verified by replaying it for real.

  **Build a project from the files occasionally — it is the only thing that tests a cold replay.** Both faults above were invisible on a database that already worked. So was a third: `place_house_number` had a fix that lived in one database and no file at all (`\d` matches Unicode digits, so a non-ASCII numeral reached `::int` and killed the whole backfill batch). All three surfaced only when the second Supabase project was built from `supabase/migrations/` for real.

  🚨 **IT WAS DONE FOR REAL ON 2026-08-17, FOR THE MAIN PROJECT, FOR THE FIRST TIME. GIT CANNOT REBUILD THIS DATABASE.** All 251 files replayed in stamp order into a brand-new empty Supabase project (PostgreSQL 17.6, same as production; paced, zero rate-limiting):

  **79 of 251 applied. `public.profiles` was never created. 9 tables, against production's 68.**

  One line does it. `20260327000100_canonical_platform_reset.sql` is 2,504 lines and is the **sole** definition of `profiles`, `companies`, `employees`, `notifications`, `fleet_vehicles`, `chat_rooms`, `transactions`, `weighbridge_records`, `minerals` and `gate_checks` — no other file creates them. Its **line 5** is `delete from storage.objects;`, which Supabase now refuses:

  ```
  42501: Direct deletion from storage tables is not allowed. Use the Storage API instead.
  CONTEXT: PL/pgSQL function storage.protect_delete()
  ```

  `protect_delete()` is a trigger Supabase added *after* that migration was written. The file is one transaction, so line 5 rolls back the other 2,503 — and 102 later files then fail with `relation "public.profiles" does not exist`. On an empty project those two `delete` lines are **no-ops anyway**; they only ever mattered when resetting a populated database.

  **Re-running with only those two lines removed: 225 of 251 applied, 61 tables, `profiles`/`trips`/`record_truck_load` all present.** Two lines are worth 146 files. The remaining 26, by root cause:

  | n | cause |
  |---|---|
  | 8 | independent pre-existing faults — a duplicate policy (`42710`), an FK with no unique constraint (`42830`), `ALTER SYSTEM` inside a transaction (`25001`), a `$$`-quoting syntax error |
  | 6 | **`pg_cron` is never created by any migration.** Production has it; a fresh project does not, so `cron.schedule` fails with `3F000 schema "cron" does not exist` |
  | 6 | cascade from those cron-blocked files (`fleet_maintenance` → `transporter_earnings`, `fuel_operating_costs`, `trip_pnl_allocation`; `compliance_documents` → the account-setup pair) |
  | 4 | **`seat_reassignment_log` has NO FILE AT ALL.** It is one of the 19 unmirrored ledger rows: applied through the MCP before the 2026-08-08 rule, so it exists in production and git cannot build it. This is the first *proven* cost of that debt |
  | 2 | a guard correctly refusing — `revoke_public_execute_on_27_rpcs` ("expected 27, found 4") and the seed-purge inventory check. Working as designed on an empty database |

  **The catalog-patching migrations are fine.** 10 of the 11 applied cleanly, including `20260817310000` and `20260817330000`, which patch `record_truck_load` — a function no file defines in full. That was the single highest-risk thing in the repo and a cold replay clears it. The one failure is a cascade from a cron-blocked file, not a patch fault.

  ✅ **ALL THREE WERE FIXED THE SAME DAY, AND THE REPLAY RE-RUN. 244 of 252 apply, and the rebuilt schema has all 68 of production's tables — zero missing, zero extra.** The fixes: the storage wipe is now a `DO` block that catches `protect_delete()`'s refusal; the reset file creates `pg_cron`/`pg_net`/`pg_trgm`/`uuid-ossp`; and `20260510184000_seat_management_objects_that_had_no_file.sql` reconstructs `seat_reassignment_log` plus `check_seat_reassignment_allowed`, `reassign_seat`, `generate_seat_serial` and `submit_seat_token_request` from the live catalog.

  **The remaining schema delta is 7 functions out of 260.** Three exist in production with no file (`can_access_company_broadcast`, `can_publish_company_broadcast`, `get_user_company_id`) — more unmirrored debt. Four are the reverse: files create them and production has dropped them (`enforce_company_seat_limit`, `recompute_company_seats_used`, `sync_company_seats_used`, `sync_organization_seats`), all seat-era functions superseded by `token_requests`, and they come from the 70 unapplied files, which a replay runs even though production never did. That is the flip side of that debt and it is why a rebuild is not yet byte-identical.

  🚨 **THE STAMP OF A REPAIR IS NOT THE STAMP IN THE LEDGER, AND ONLY A REPLAY FINDS OUT.** That reconstruction took three attempts, and both misses were invisible to reading the SQL:

  1. Stamped `20260504212635`, the ledger row's own date — but `seat_reassignment_log` has a foreign key to `organization_seats`, created at `20260510181500`. **The ledger records when something was applied to a database that already had those tables; it is not a claim that the same order replays from empty.**
  2. Stamped `20260510182000` — but its RLS policy calls `public.is_super_admin()`, and **Postgres validates a policy expression when the policy is created**, so that function must already exist (`20260510183000`).

  Landed at `20260510184000`. Note the asymmetry that makes this class undetectable statically: the plpgsql function bodies in the same file call `is_platform_admin`, `is_company_manager` and `is_valid_role_for_org`, and those resolve at **run time**, so they do not constrain the stamp at all. An order-aware static check over `alter function`/`grant` caught neither miss.

  **The 8 that still fail** are all pre-existing and independent of the above: two duplicate-policy `42710`s, an FK with no unique constraint (`42830`), `ALTER SYSTEM` inside a transaction (`25001`), a `$$`-quoting syntax error in `expire_organizations_job`, `flatten_child_admin` setting a column that no longer exists (`42703`), `seat_role_vocabulary_supervisor` on `role_binding` (`42703`), and the seed-purge inventory guard correctly refusing on an empty database (`P0001`).

  ✅ **CLOSED 2026-08-18: 256 of 256 files apply into an empty project, zero failures.** Six of the nine schema shapes then match production **exactly, by md5** — `tables 68`, `columns 844`, `functions 260`, `triggers 55`, `rls 68`, `cron 9`. Guarded from now on by `tool/schema_parity_check.py` (§6, below).

  ✅ **CLOSED 2026-08-19. EIGHT OF THE NINE SHAPES NOW MATCH PRODUCTION EXACTLY, and the ninth is expected.** Run it yourself: `python tool/cold_replay.py --org <org>` (or `--diff-only <ref>`), which exits 0 on the current tree.

  ❌ **A CORRECTION, because the paragraph below was wrong and was believed for a day.** It said function bodies differed across 15 of 19 letter groups and that "a rebuilt database would run substantially different application logic". **That is false. ZERO functions differ in logic.** The number collapsed as the comparison got less naive:

  | normalisation | "differing" |
  |---|---|
  | raw `prosrc` | ≤175 functions |
  | strip SQL comments | ≤63 |
  | + fold case | 18 |
  | + normalise whitespace around punctuation | 14 |
  | + read the last one | **0** |

  The last one, `enforce_employee_role_org_type`, differed only because the file writes a `hint` as adjacent string literals across three lines, which PL/pgSQL concatenates into production's single literal. Everything else was comments, capitalisation or whitespace — production's copies were applied through the MCP, which does not carry the files' comments.

  **So `bodies` will always differ, and must not be "fixed".** Stripping comments from the files to match a digest destroys documentation to chase a hash. `tool/cold_replay.py` treats `bodies` as expected-different and carries this table in its header so nobody re-derives it. Rule 4 below already recorded this trap from the targets work — *"5 of 15 functions differing, all comments-only, executable SQL identical"* — and it was still re-learned the hard way.

  **`policies` and `indexes` were real and are now reconciled** (`20260818100000`, `20260818120000`) on Jean's call of adopt-production-retire-the-rest. The policy work mattered most: before it, a database restored from git **could not issue or revoke a serial token**, because `serial_tokens` had no INSERT or UPDATE policy and token issuance is how companies get access at all.

  **What still stands from the paragraph below: 70 migration files have no ledger row.** That remains true and is the root cause of everything above. It no longer produces a schema difference, because the reconciliation migrations settle each disagreement explicitly — but the files themselves are still unapplied history, and `tool/migration_ledger_check.py` keeps them baselined and visible.

  🚨 **THE ORIGINAL FINDING, kept because the reasoning is load-bearing — but read the correction above first.**

  **70 migration files in this repo were never applied to production.** They are not inert: a cold replay runs them, so a rebuilt database and production genuinely diverge.

  - **Policies differ on 8 tables**, in *both* directions, and RLS is the security boundary:
    - A rebuild **grants what production does not** — `companies_update_company_manager_or_platform_admin` and `employees_update_company_manager_or_platform_admin` let a company manager UPDATE those tables directly; production has no UPDATE policy at all, so today every write goes through a `SECURITY DEFINER` RPC. Also two extra SELECT policies on `profiles`.
    - A rebuild **withholds what production grants** — production's *"Company users can read own org seats"*, *"Super admins can create/update serial tokens"* and *"Company users can read own seat requests"* do not exist in the files. Restore from git and those features stop working.
    - Nearly all of it traces to one file, `20260510183000_super_admin_rls_and_permissions.sql`, which has no ledger row. Production instead runs `20260510194500_rls_super_admin_core_table_access.sql`.
  - **Function bodies differ across 15 of 19 initial-letter groups.** Counts match everywhere; the bodies do not. A rebuilt database would run substantially different application logic.
  - **Indexes differ on 6 tables** — the same cause, lower stakes (performance, not correctness).

  **This is not a live vulnerability.** Production is the more restrictive side on every write policy, and it is the system that works. The exposure is to *disaster recovery*: restoring from git today gives a database with different security rules and different logic.

  **Do not "fix" this by making one side match the other without deciding which is right.** Applying those 70 files to production changes live security rules; deleting them from the repo may discard intended hardening. Each needs a verdict — adopt, or retire. Until then the three shapes are expected to differ, and `schema_parity_check.py` still does its job, because it compares production against a **recorded baseline**, not against the files.

  **A repair is recorded the way `supabase migration repair --status applied` does when its objects already exist.** `20260510184000` was NOT run against production: its bodies are re-cased copies of the live ones, so `create or replace` would rewrite live function source for no functional gain — and the catalog-patching migrations assert on exact anchor strings. A ledger row was inserted instead.

  ⚠️ **A grant that is right on main can be silently wrong on the extras project.** `20260816100000` grants `search_place_index` to `authenticated`, which is correct on main — and useless on the extras project, where a main-issued JWT is invalid and every user arrives as `anon`. The live project only worked because a script had granted `anon` out of band. Corrections like this belong in `supabase/extras_project/migrations/`, never bolted on by a tool. The failure mode is the dangerous part: the picker degrades to Nominatim by design, so a missing grant shows up as *fewer search results* — no error, nothing in the logs.

  **Files are the source of truth, and the ledger must match them (decided 2026-08-08).** Previously this section said MCP-applied migrations "may show different timestamp prefixes than local files — that's ordering only". That tolerance is what let the targets work end up with three applied migrations against two files, one of them a fix (`grant select`, without which realtime is live and silent) that existed only in the database. Neither side was authoritative. The rule now:

  1. **One file per applied migration**, named for what it did. Never fold a follow-up fix into an earlier file — it makes the file list and the ledger disagree.
  2. **`apply_migration` assigns its own timestamp.** Until CLI access exists (`supabase db push` needs `SUPABASE_DB_PASSWORD`, which is not in this environment), every MCP apply must be followed by repointing the stamp at the filename:
     ```sql
     update supabase_migrations.schema_migrations
     set version = '<file timestamp>' where name = '<migration name>';
     ```
  3. **Mirror to a file in the same commit, without exception.** An applied migration with no file is unreproducible from git, which is the one thing `git is the source of truth` was supposed to guarantee.
  4. Retyping SQL into `apply_migration` risks silent drift from the file. Check it: compare `md5` of whitespace-normalised `pg_proc.prosrc` against the bodies in the file. On the targets migrations that check found 5 of 15 functions differing — all comments-only, executable SQL identical — but the check is what made that a fact rather than a hope.
  5. 🚨 **NEVER put the repoint in the same statement batch as a probe that raises.** A self-rolling-back probe (`do $$ … raise exception 'PROBE …' $$;`) undoes *everything* in its batch, and that includes an `update … schema_migrations` sitting above it. On 2026-08-17 the repoint for `20260817330000` was rolled back exactly this way and the row silently kept its auto-assigned `20260817133116`. Nothing failed; the apply succeeded, the probe printed its findings, and the ledger was wrong. **Repoint in its own call, then verify.** The verification is two commands, and it is the only thing that catches this:
     ```sql
     select version, name from supabase_migrations.schema_migrations
      where version >= '<first new stamp>' order by version;
     ```
     ```bash
     ls supabase/migrations/ | grep -E '^2026….'   # same count, same stamps
     ```

     **That comparison is now mechanical — run it instead of eyeballing it:**

     ```bash
     ML_LEDGER_PASSWORD=… python tool/migration_ledger_check.py
     python tool/migration_ledger_check.py --selftest   # proves it still bites
     ```

     It reads `config/supabase.live.json` like `health_probe.py`, and reaches
     the ledger through `public.migration_ledger()` (migration `20260817340000`)
     because PostgREST does not expose `supabase_migrations` — hence the
     credentials, and hence **exit 2 for "could not check", which is not a
     pass.** It fails on a file with no row, a row with no file, and a row whose
     `version` is not its filename's stamp.

     ⚠️ **101 pre-existing discrepancies are baselined** in
     `tool/migration_ledger_baseline.json` (70 unapplied files, 19 unmirrored
     rows, 10 misstamped, 2 ambiguous — all predating the 2026-08-08 rule). They
     are accepted, not hidden: printed every run, and an entry that has since
     been repaired *fails*, so the file can only shrink. Production is ahead of
     those files rather than behind them — verified 2026-08-17, see the
     baseline's own `_measured` note — but `supabase db push` would treat all 80
     of them as pending. Repairing them is a separate decision.
  6. **A `create or replace` that ships full function text is wrong whenever an earlier migration rewrote that function from the catalog.** Several functions here have no complete definition in any file: `20260817230000` defines `record_truck_load` in full and `20260817290000` then rewrites it from `pg_get_functiondef` to turn a silent `exception when others then null` into a named `raise warning`. Rebuilding the text from the older file applies cleanly, looks right, and silently reverts the newer change — caught on 2026-08-17 only by the md5 check in rule 4 (live body 10,515 chars against a file body of 10,307). **For those functions, patch the catalog** (`select prosrc` → `replace` → `execute format(…, %L)`) and **assert every anchor before writing**, so a body that has drifted underneath raises instead of being patched blind. `20260817310000` and `20260817330000` are the shape to copy.
- **Edge Functions** (Deno) live in `supabase/functions/` (`company-user-admin`, `super-admin-create-company`, `whatsapp-send-otp`, shared code in `_shared/`). Deployment notes in `supabase/edge_function_deployment_guide.md`.
- **Realtime & RLS:** policies are part of migrations. When adding a table the UI subscribes to, add the realtime + RLS policy in the same migration. Security lives in RLS/RPCs, not the Flutter layer.
- **Supabase MCP is configured** (`.mcp.json`, project ref `yftazblpmicqtamyiwyb`; enabled in `.claude/settings.local.json`). Prefer it for inspecting schema, migrations, logs, and advisors over guessing — **but it only ever reaches the MAIN project.** It will happily answer questions about `place_index` by telling you the table does not exist, because on main it no longer does. For the extras project use the Management API (§10.2).

---

## 7. Conventions & commands

- **Lints:** `package:flutter_lints/flutter.yaml` (see `analysis_options.yaml`). Run `flutter analyze` before considering work done — it should stay clean. `docs/new system design/**` and `Looks of Pages within the app/**` are excluded from analysis (reference material, never imported from `lib/`).
- **Logging:** `LoggerFactory.getLogger('Scope')`, not `print`.
- **Enums that hit the wire** carry an explicit `.wire`/`.id` string and a tolerant `parse`/`fromId` — follow that pattern (see `TripStatus`, `OperationsTab`) so DB string drift never crashes the UI.
- **New feature?** Scaffold `models/ services/ providers/ screens/ widgets/` under `lib/features/<name>/`, wire the route in `app_router.dart`, gate visibility by role where relevant.

### ⚠ Widget tests and fonts — read this before chasing a pixel overflow

**`flutter test` does not render in the app's fonts.** Unless a test loads them explicitly it uses a fallback test font in which **every glyph is one em wide** — so a 9-character label at `fontSize: 9` measures 81px instead of ~45px. The result is `RenderFlex overflowed by N pixels` failures for layouts that are perfectly fine in the real app, and — worse in the other direction — real overflows that never reproduce because the metrics are wrong in both directions depending on the string.

A worked example: the targets horizon ladder reported a 4.4px overflow on an `SURPASSED` badge. `9 chars × 9px + letterSpacing 0.6 × 9 = 86.4px`, plus a 16px icon and gap, is exactly the 102.4px the framework reported against a 98px box. It was arithmetic on the test font, not a layout fault. **If an overflow figure looks suspiciously like `characters × fontSize`, that is what you are looking at.**

- **Load the real fonts** in any test that asserts on layout. Copy the `_loadRealFonts()` helper from `test/widgets/super_admin_overflow_sweep_test.dart` (or `targets_screen_test.dart`).
- **Then sweep width × text scale.** The console lets each admin set `ConsolePrefs.textScale` (0.85–1.3) and bold text, applied through `MediaQuery`. A tile 1px inside its box at 1.0 overflows for anyone who nudged the slider. Both real bugs found in the targets work — a fixed 104px badge column and an unflexed `Wrap` in a `Row` — only appeared at 1.3.
- **Fixed widths around text are the usual culprit.** Prefer `ConstrainedBox(minWidth:)` + `Align(widthFactor: 1)` over `SizedBox(width:)`, and never leave a `Wrap` unflexed in a `Row` (it is laid out against unbounded width and will push the row over).

### Common commands
```bash
flutter pub get
flutter analyze
flutter test
# Run web (see run_web*.bat / .ps1 for the project's Chrome/WebGL flags)
flutter run -d chrome --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_PUBLISHABLE_KEY=...
flutter run -d windows   # desktop target is supported
```

Targets present: `web`, `windows`, `android`, `ios`, `linux`, `macos`. Windows and web are the primary dev targets.

---

## 7.1 One clock: Africa/Johannesburg

**Every day this product decides is a South African one.** Ruled by Jean on
2026-08-17, after a printed waybill was found stating `DATE 2026-08-16 · TIME
23:29` for a hand-off that happened at 01:29 on the 17th — the date a day out,
on the document that governs the delivery.

- **Client:** `lib/core/time/ml_time.dart`. `MlTime.now()`, `MlTime.sast(instant)`,
  `MlTime.today()`, `MlTime.startOfDay()`, `MlTime.dateParam()`, `MlTime.toServer()`.
  Never `DateTime.now()` or `.toLocal()` for anything a user reads as a date, a
  time, or a number bucketed by day — those are the *device's* opinion, and a
  laptop left on UTC put a 22:30 SAST load on the previous day.
- **Server:** `public.ml_today()`, `public.ml_day(timestamptz)`,
  `public.ml_day_start(date)` (migration `20260817240000`). Never `current_date`
  for a business day: it is a **UTC** calendar day, so it flips at 02:00 SAST —
  mid-night-shift, two hours after the pit changed date.
- SAST is UTC+02:00 with **no daylight saving**, so a fixed offset is exact.
  That is the only reason the shortcut is safe. **If MineLink ever operates
  outside South Africa, `ml_time.dart` and `ml_zone()` are the two edits, and
  both must become real timezone lookups rather than bigger constants.**

🚨 **Do NOT "simplify" this by setting the database timezone.** It is the obvious
one-line fix and it is wrong. ~180 columns default to `timezone('utc', now())`,
which returns a **naive** timestamp; storing a naive timestamp into a
`timestamptz` column reinterprets it in the **session** zone. Measured on
production before anything was changed:

```
session UTC   -> stored 2026-08-17 09:41:19+02   (the real instant)
session SAST  -> stored 2026-08-17 07:41:19+02   (two hours early)
```

Flipping `TimeZone` would silently move every `created_at` and `updated_at` in
the product by two hours, permanently, while looking like housekeeping. The
database stays on UTC and the zone is named at the sites that decide a day.

`tool/one_clock_check.py` holds the line. Timestamps that merely *stamp* a row
(`created_at`, TTLs, timeouts, animation, "x minutes ago") are not day
decisions and are exempt.

---

## 8. When unsure

- Match the nearest existing feature's structure rather than introducing a new pattern.
- If a change touches trip status, weighbridge, loads, or POD, check the RPC contract first — the DB, not the client, owns lifecycle integrity.
- Prefer extending `MlTokens`/`MlSemantic`/`MlTone` over adding raw values; if a token is genuinely missing, add it to `ml_tokens.dart` with a comment tracing it to the design source.
- Don't touch or resurrect root-level legacy scratch scripts unless explicitly asked.

---

## 9. Required tooling (skills, connectors, plugins)

When building, designing, testing, or completing **any** feature — and especially every 🟡 Partial / 🔴 Planned item in §4 — the agent should actively use the relevant recommended tooling below. If a tool is not yet installed/connected/available to the agent, **install/enable it and use it** (or, where the agent cannot self-install, flag it clearly so it can be enabled) rather than skipping it.

**Connectors (MCP):**
- **Supabase MCP** — already configured; use for schema, migrations, RPCs, logs, advisors (see §6).
- **GitHub** — PRs, issues, repo-wide reads/writes.
- **Filesystem** — direct project-tree access.
- **Sentry** (or the project's error tracker) — pull crash/error context into debugging.
- **Figma** — **only** include/use if the agent can use it directly to design, display, and then implement/integrate the design end-to-end. If it's just a passive reference the agent can't act on, skip it.

**Plugin skills** (apply per task): `engineering:debug`, `engineering:code-review`, `engineering:system-design`, `engineering:architecture`, `engineering:testing-strategy`, `engineering:documentation`; `design:design-system`, `design:design-handoff`, `design:accessibility-review`, `design:design-critique`, `design:ux-copy`; `product-management:write-spec` for turning these flows into structured specs.

**Built-in skills:** `frontend-design` (fires for any UI work; carries this environment's styling constraints), and the document skills (`docx` / `pptx` / `xlsx` / `pdf`) whenever a deliverable in that format is produced (e.g. the recon/reconciliation Excel/CSV/PDF exports).

**Rule:** use these tools as part of implementing/testing each planned feature, not as an afterthought. Prefer the Supabase MCP over guessing at schema, and prefer the design/frontend skills over ad-hoc styling. The only conditional is Figma, per the note above.

---

## 10. Environment hazards (read before touching git or the database)

Learned the hard way on 2026-08-08. Each of these has already cost real time or nearly caused real damage.

### 10.1 Several agent sessions write this worktree at once

Multiple Claude sessions have run against `Music\SHOWME!\worktree-2026-05-05T11-53-29` on `feat/minelink-fork-merge` **simultaneously**. `HEAD` has moved five times inside a single conversation, once between two consecutive tool calls. Every commit is authored *and* committed by the same identity (`Blak-42069 …`) with the same `Co-Authored-By` trailer, so **git cannot attribute work to a session** — the only signal is prose in the commit body.

Expect, and do not mistake for corruption: `git diff` empty for files you just edited; untracked files you did not create; your work swept into somebody else's omnibus commit (`687b263` is 57 files / +19,336 mixing at least three sessions); a red test from another session's in-flight change.

- **Never run `git stash`, `git checkout -- .`, `git clean`,** or anything else that touches uncommitted state. It is not yours. If you need a clean tree, stop and ask.
- **Commit your own work, one commit per logical change, before your turn ends.** Do not leave it for a housekeeping session.
- **Work on your own branch** so your diff is reviewable in isolation.
- **Do not `git checkout` a different branch in this worktree** — it yanks the branch from under live sessions and drags their uncommitted files onto yours. Use `git worktree add <path> -b <branch> <base>` and confirm the path first.

### 10.2 There is no staging — and there are now TWO production projects

**The app talks to two Supabase projects, and the MCP tools only reach one of them.** Establish which database you mean before running anything.

| | Main app project | Extras project |
|---|---|---|
| Name | `bryson@cyberhouse.co.za's Project` | **`Mine-Link_Extra_Data`** |
| Ref | `yftazblpmicqtamyiwyb` | `qbydiuplqhmkaxarnuza` |
| Region | eu-west-1 | eu-central-2 |
| Holds | Everything transactional — auth, profiles, companies, trips, stockpiles, recon, targets, chat, storage | Bulk **reference data only**. First tenant: `place_index` (Overture places, South Africa only) |
| Reached from Dart by | `SupabaseConfig` | `PlaceIndexConfig` (`lib/core/config/place_index_config.dart`) |

🚨 **`.mcp.json` pins the MAIN ref, so `mcp__supabase__execute_sql`, `apply_migration`, `query_logs` and `get_advisors` ALWAYS hit the main app database** — silently, with no warning, even when you believe you are working on the extras project. To touch the extras project you must go through the Management API by hand:

```bash
curl -X POST "https://api.supabase.com/v1/projects/qbydiuplqhmkaxarnuza/database/query" \
  -H "Authorization: Bearer <sbp_…>" -H "Content-Type: application/json" \
  -H "User-Agent: MineLink-ops/1.0" -d '{"query":"select 1;"}'
```

(Cloudflare fronts `api.supabase.com` and answers the default curl/urllib agent with HTTP 403 code 1010 — always send a real `User-Agent`.)

**Auth does not cross the boundary.** A JWT from the main project's GoTrue is not valid on the extras project — different project, different JWT secret — so a signed-in user arrives there as `anon`. That is why `search_place_index` is granted to `anon` there and only to `authenticated` here. It is safe *only* because that project holds nothing but open Overture data. **Never put user, company or trip data in the extras project**: there is no session there to scope it by, and an `anon` grant over that is a breach rather than a lookup.

**Current footprint, measured 2026-08-16 after the move.** Do not try to "balance" these — see below.

| | Main | Extras |
|---|---|---|
| Database | **24 MB — 4.8%** of 500 MB | **235 MB — 47.1%** of 500 MB |
| Tables in `public` | 68, totalling 11 MB | 1, totalling 225 MB |
| Storage | 2.4 MB of 1 GB | none |
| Connections | 22 / 60 | 14 / 60 |
| Cache hit | 98.1% | 99.97% |

**The two cannot be equalised, and should not be.** The arithmetic settles it: MineLink's *entire* application dataset is **11 MB** across 68 tables — the rest of main's 24 MB is Postgres system catalogs and WAL, none of it movable. The extras project holds 225 MB in one table. There is simply nothing of size to move in the other direction, and moving `place_index` back would undo the fix. More importantly, **every one of those 68 tables carries RLS policies**; moving any of them to a project where a main-project JWT is invalid would leave users arriving as `anon` with no session to scope by. That is a breach, not a balance.

The health goal is **headroom on both**, and both now have it: main 95% free, extras 53% free. The asymmetry faithfully reflects the workload — a small transactional app plus one large static lookup table.

`list_projects` returns both, and **both are production** — there is still no staging anywhere. **Every migration, RPC and RLS change lands on live data, and every local run reads it.** Check `list_migrations` against the live project before believing any commit message about whether something is applied — at least one commit says "NOT yet applied" for a migration that is live.

**Both projects are on the FREE plan** (org `bcsvghgolvdzggcwdfsu`, verified 2026-08-16 via `GET /v1/organizations/…` → `"plan":"free"`, no compute add-on selected). That means **500 MB of disk, shared CPU, ~1 GB RAM each** — not a tier that absorbs a mistake. Supabase grants two free projects per account, which is exactly why the split above was affordable; a third would not be.

**Free projects pause after ~7 days of low activity.** That is a live hazard for the extras project specifically: the address picker is used irregularly, and when it pauses the picker fails *silently* — the place-index stage degrades to nothing **by design** and the search falls through to Nominatim, so users get worse results with no error anywhere. It reads as "the picker got worse", not as "a database is down".

**Solved by `ping_extras_project()`** (`20260816180000`), a pg_cron job **on the main project** firing `pg_net` at the extras project's `search_place_index` every 6 hours. It lives on main deliberately: an app-side heartbeat only fires when somebody opens the app, which is exactly the assumption that fails over a holiday — the case it exists for. Main is never idle, so its cron always runs. It calls a **real RPC**, not the gateway: a 401 never reaches Postgres and would not count as activity. Verified working (HTTP 200); responses land in `net._http_response`.

Three more consequences worth holding on to:

- **Bulk data does not fit as casually as it looks.** `tools/overture_import.py` documents the arithmetic in its own docstring — the base database was 64 MB, the Overture place set adds ~150 MB of heap plus ~90 MB of trigram index, and that is already ~60% of the ceiling before a single row is updated. An `UPDATE` writes a new row version, so one full pass over that table can roughly double its heap in dead tuples; if autovacuum is locked out at the same time, none of it comes back. That is the 2026-08-16 outage in three sentences.
- **Disk pressure is invisible from the status field.** `GET /v1/projects/<ref>` said `ACTIVE_HEALTHY` throughout. `GET /v1/projects/<ref>/health?services=db,rest,auth,realtime,storage` is the endpoint that told the truth (`db: UNHEALTHY — Failed to connect to database`), and it keeps working when SQL does not. Note that `realtime` reports `healthy: true` with `info.db_connected: false` when Postgres is gone — read the nested flag, not the headline.
- **Look at index size, not just row count, when hunting for space.** `vehicle_positions` held **55 rows and 8 kB of data** while its indexes occupied **40 MB** — a B-tree does not return emptied pages to the OS on a plain `VACUUM`, so a hard-churned table keeps its extent long after the heap is truncated. A single `reindex table` took the database from 477 MB to 437 MB without touching a row. Find them with:

  ```sql
  select relname, pg_size_pretty(pg_relation_size(oid)) as heap,
         pg_size_pretty(pg_indexes_size(oid)) as indexes
  from pg_class c join pg_namespace n on n.oid = c.relnamespace
  where n.nspname = 'public' and c.relkind = 'r'
    and pg_indexes_size(oid) > pg_relation_size(oid) * 3
  order by pg_indexes_size(oid) desc;
  ```

  The underlying cause was worse than the bloat: nothing had **ever** deleted a GPS ping, on the highest-write table in the product. Fixed by `20260816150000_vehicle_positions_retention.sql`. When adding any high-frequency write path, ship its retention job in the same migration.

### 10.3 A 404 does not mean a remote is dead

All three remotes (`origin`, `TOKEN-BUILD-(…)`, `minelink-legacy`) are **private**, so an unauthenticated `curl` returns 404 for all of them — including `origin`. An earlier session read that as "the remote is unreachable", wrote it into a commit message, and it became a believed backup crisis. Everything was already pushed. Verify properly:

```bash
git ls-remote --heads origin                                   # refs + exit 0 = alive
git rev-list --left-right --count <branch>...origin/<branch>   # "0  0" = fully pushed
```

### 10.4 Layout rules that keep being violated

The console applies a per-user text scale (`ConsolePrefs.textScale`, 0.85–1.3) and bold-text to every super-admin screen via `MediaQuery`, so rigid layouts break for real users. Five instances of one pattern were fixed in a single pass:

- A `Row` gives non-flex children **unbounded width**, so a `Text`'s `overflow: ellipsis` never engages — wrap the cell in `Flexible`.
- `Container(height: N)` counts `Border.all` as padding **on top of** `padding`, so a tile that "fits exactly" overflows by 1–2px — prefer `constraints: BoxConstraints(minHeight: N)`.
- `CrossAxisAlignment.stretch` inside an unbounded parent (a `Stack` sized by one non-positioned child, or a scrollable) throws *"BoxConstraints forces an infinite height"* — paint an accent bar as a `Positioned` overlay instead.
- A reduce-motion helper must never return `Duration.zero`: `AnimationController` then notifies listeners **synchronously**, and `AnimatedSize` calls `markNeedsLayout()` inside its own `performLayout`. Use 1ms.

Two more, added 2026-08-14. Both are *alignment* faults, so neither throws, neither fails a sweep, and neither is visible in a passing test — they were found by rendering the component and **measuring** it:

- **`Flexible` defaults to `flex: 1`.** Put a trailing block in a `Flexible` next to an `Expanded` title and the two split the free space **equally** — the trailing lands mid-row instead of at the right edge. In a 1000px section header the meta line ran `x=507→642`. This is a trap precisely *because* of the first rule above: `Flexible` is the documented fix for the ellipsis problem, but that rule is about the **long** child (the title, which already has the `Expanded`). A short, right-aligned trailing should be **unflexed**.
- **A `Wrap` sizes to its content**, so `WrapAlignment.spaceBetween` has no free space to distribute and does nothing. A header built as `Wrap[title, meta]` rendered 516px wide inside a 1000px column with the meta glued to the title. It must claim the row first — `SizedBox(width: double.infinity, child: Wrap(...))`.

**Assert on geometry, not just on absence of overflow.** `expect(tester.getRect(find.text(meta)).right, closeTo(width, 1))` is what caught both; an overflow sweep never would, because nothing overflowed.

One more, added 2026-08-17: **`DropdownButtonFormField` lays its selected item out at its natural width unless you pass `isExpanded: true`.** A new "Seal points on this rig" control whose longest option reads *"4 seals — interlink, two trailers"* pushed the add-vehicle dialog **357px** past a narrow phone. Same family as the `Row` rules above — a child given unbounded width takes it — but it is worth naming separately because the widget looks like it manages its own width and does not. `test/features/mobile_parity_verification_test.dart` renders that dialog at phone width and is what caught it; **any new field added to a shared add/edit form has to survive that test**, which is cheaper than remembering the rule.

### 10.5 Widget tests do not prove layout by default

`flutter test` renders with a **fallback font** whose metrics differ from PlusJakartaSans / JetBrainsMono, so text-metric overflows do not reproduce — load the real fonts with `FontLoader` (see `test/widgets/super_admin_overflow_sweep_test.dart`). It also defaults `disableAnimations` to false and gives a tall viewport, hiding reduce-motion and vertical-overflow faults.

A green test over an empty fixture, an error state, or a fallback font proves nothing. **Report "screens proving something / N", not the passing-test count** — 28 green tests once covered 7 real screens. Mark unproven screens expected-failure with a reason string; never `skip`.

### 10.6 Dart bitwise operators are UNSIGNED 32-BIT on the web

`flutter test` runs on the Dart VM. The app ships to a browser through dart2js,
where an `int` is a JavaScript double and the bitwise operators are specified to
work on unsigned 32-bit values. `~` is the one that bites:

```
~5        → -6           on the VM
~5        → 4294967290   under dart2js
~26085137 → -26085138  /  4268882158
```

Found 2026-08-17 in `nav_route.dart`. The zig-zag step every polyline decoder in
the world is written `~(result >> 1)`, so a live 10.0 km Valhalla route decoded
to **599 295.4 km** in a browser and to 10.0 km on the VM. In the running app:
no route line, a dead ETA/distance HUD, "In 2194.2 km" on a 10 km trip, and —
worst, because it leaves the device — `trip_nav_state.route_polyline` published
to every watcher's live map as 13 characters of junk. **The existing test suite
was green throughout**, because it never ran on the runtime that was wrong.

- **Use arithmetic, not bitwise, wherever a value can be negative or exceed
  32 bits.** `+ * % ~/` are exact and identical on both runtimes below 2^53.
  `x % 2`, `x ~/ 2`, `-x - 1`, `n * 32` replace `x & 1`, `x >> 1`, `~x`, `n << 5`.
  Masking small non-negative flags (`InteractiveFlag.all & ~InteractiveFlag.rotate`)
  is fine — the sign difference is discarded by the `&`.
- **A unit test cannot guard this**, so `no-bitwise-in-polyline-codec` in
  `tool/release_guards.dart` guards the source instead. If you write another
  codec, guard it the same way.
- Reproduce any suspicion in 30 seconds: put the function in a standalone
  `.dart`, run it with `dart run`, then `dart compile js -o x.js` and `node x.js`,
  and compare.
