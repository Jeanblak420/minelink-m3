# Driver in-app navigation, mine locations & driver app shell — design

**Date:** 2026-07-16
**Status:** Approved design (user), pending spec review
**Branch:** feat/premium-mine-supplier-overview (worktree)

## Goal

Three connected deliverables:

1. **In-app turn-by-turn navigation with voice** for drivers — Waze-like, fully inside the app (no hand-off to external Google Maps as the primary flow).
2. **Mine "Locations" on the company profile** — a mine can save named collection points; the primary one is automatically used as the driver's destination so the driver "only has to start the trip".
3. **Driver app shell redesign** — adopt the approved 3-tab mobile design (Dashboard · Trip · Profile) from `Downloads/Mobile driver app update/flutter_export/driver_app_screen.dart`, wired to real data, **without losing any feature the driver has today**.

Plus a data task: seed **Ironhills** with the location from `https://maps.app.goo.gl/XcJEYHJFu15XyLY67` → **SPAR Kingfisher, lat `-26.0285039`, lng `28.0019869`** (stored as `https://www.google.com/maps?q=-26.0285039,28.0019869`), marked primary.

## Constraints (from CLAUDE.md + memory)

- **Additive only** — never remove/break existing behaviour. All current driver screens stay reachable.
- **100% free, no billing, no API key** mapping stack (same rule as the existing location picker).
- Design tokens only (`MlTokens` / `MlSemantic` / `MlTone`); package name stays `flutter_application_1`.
- DB via feature services; lifecycle via cascade RPCs; RLS in Postgres, not Dart.
- Supabase changes: migration files in git + applied to live project `yftazblpmicqtamyiwyb` via the Management API (the session MCP is bound to a different account).
- No subagents — all work done inline.

## 1. Routing engine (decision)

**OSRM public server** (`router.project-osrm.org`) — free, no key, no signup. Returns driving route geometry (polyline) + turn-by-turn steps (maneuver type, modifier, road name, distance).

- Base URL kept **configurable** (single const / optional dart-define `OSRM_BASE_URL`) so it can later point at a self-hosted OSRM without code changes.
- **Graceful degradation:** if OSRM is unreachable, the nav screen still shows the map, destination pin, straight-line bearing + distance, and a one-tap "Open in external maps" fallback. The existing external-maps "Directions" action is kept as a secondary menu action (additive rule).
- Rejected: OpenRouteService (needs API key), Mapbox/Google nav SDKs (billing).

## 2. Data model — `company_locations`

New table (migration `supabase/migrations/2026….sql`):

```sql
company_locations (
  id uuid pk default gen_random_uuid(),
  company_id uuid not null references companies(id) on delete cascade,
  name text not null,
  map_link text not null,          -- universal 'https://www.google.com/maps?q=lat,lng'
  is_primary boolean not null default false,
  created_by uuid references auth.users(id),
  created_at timestamptz default now(),
  updated_at timestamptz default now()
)
```

- Partial unique index: at most one `is_primary = true` per company (`create unique index ... on company_locations (company_id) where is_primary`). Setting a new primary clears the old one via RPC or service-side update in one transaction (RPC preferred: `set_primary_company_location(location_id)`).
- **RLS:**
  - Company members (any role) of that company: `select`.
  - Company owner + `admin` + `management` roles of that company: full CRUD.
  - Super admins: full CRUD everywhere.
  - **Trip parties:** users whose company participates in an active/scheduled trip with that mine (driver's transporter, buyer) may `select` that mine's locations — needed so the driver's app can resolve the destination. Implemented as an RLS `exists` clause over trips/transactions, or (simpler and preferred) resolution happens inside a `security definer` RPC `get_trip_nav_destination(trip_id)` and the table RLS stays company-only. **Decision: the RPC approach** — one server-side resolution point, no broad read policy.
- Realtime enabled for the table (profile screen updates live).

### Destination resolution chain (server RPC `get_trip_nav_destination(trip_id, leg)`)

`leg` = `'load' | 'offload'` (client passes based on `TripStatus.step >= loaded`).

1. `load` leg: request/route `loading_point` if it parses as a `?q=lat,lng` link → use it.
2. Else: the **source mine's primary `company_locations` row** → its `map_link`.
3. Else: any text `loading_point` returned as address-only (client geocodes via Nominatim once, or falls back to external maps).
4. `offload` leg: same chain with `offloading_point`, falling back to the **buyer's** primary location.

Returns `{lat, lng, label, source}` (or address-only). The RPC checks the caller is a party to the trip.

## 3. Mine profile — "Locations" section

On the company profile screen (mine's own profile view; also shown for buyer/transporter orgs — any org may save locations, mines are the primary user):

- List of saved locations: name, coordinates chip, primary star/badge.
- **Add location** dialog: name field + two entry modes — (a) the existing free map picker (`showLocationPickerDialog`, Nominatim search + drop pin), (b) **paste any Google Maps link**, including short `maps.app.goo.gl` links. Short links are resolved by following the redirect (HTTP GET, no key) and extracting `!3d{lat}!4d{lng}` (place pin) or `@lat,lng` (viewport) or `?q=lat,lng`; the resolved point is previewed on a mini-map before save.
- Edit (rename / move pin), delete, **Set primary**.
- New files: `portal/models/company_location.dart`, `portal/services/company_location_service.dart`, `portal/providers/company_location_provider.dart`, `portal/widgets/company_locations_section.dart` (+ short-link resolver util `portal/utils/maps_short_link.dart` with unit tests).

### Ironhills seed

Insert into `company_locations` for the Ironhills mine company row: name `"Collection point (SPAR Kingfisher area)"`, `map_link = 'https://www.google.com/maps?q=-26.0285039,28.0019869'`, `is_primary = true`. Applied to live DB via Management API; also captured in the migration as idempotent seed (`insert … select from companies where name ilike '%ironhill%' … on conflict do nothing`) — verify the actual company name/id against live data first.

## 4. In-app turn-by-turn navigation (driver)

New fullscreen **`DriverNavigationScreen`** (route `/portal/driver/navigate/:tripId`, driver-gated):

- **Map:** `flutter_map` + OSM tiles. Camera follows the truck; **rotates to heading** (course-up); auto-zoom by speed; "re-center" button after manual pan. Smoothly animated position marker (navigation-arrow icon).
- **Route:** OSRM polyline drawn bold (accent on navy), destination pin; remaining route greys behind the truck as it progresses.
- **Instruction banner (top):** maneuver icon (turn left/right, slight, sharp, roundabout + exit no., u-turn, merge, arrive), primary text "In 400 m, turn left onto R59", secondary "then ➘ right in 1.2 km". Distances live-count down.
- **Bottom bar:** ETA (clock time), minutes remaining, km remaining, current speed; mute toggle; "End navigation".
- **Voice guidance:** `flutter_tts` (new dependency). Announcements per maneuver at distance gates (~1 km / ~300 m / "now"), plus "Rerouting" and "You have arrived". Mute toggle persisted (session-level is fine).
- **GPS while navigating:** dedicated 1 s `geolocator` position stream (high accuracy). The existing 30 s live-trip ping loop continues untouched in parallel.
- **Progress tracking:** snap position to nearest point on route line; advance step index when the step's end is passed. **Off-route:** > 50 m from the line for > 5 s → re-request route from current position ("Rerouting…" + voice).
- **Arrival:** within ~150 m of destination → arrival banner + contextual lifecycle action: load leg → "Mark arrived at mine" (`arrived_at_mine` via existing lifecycle service); offload leg → "Upload POD" (existing dialog). Never auto-fires — driver taps.
- **Leg switching:** target from `get_trip_nav_destination`; before `loaded` → load leg, after → offload leg (same rule as today's `_directions`).
- **Entry points:** big **"Navigate"** primary button on the driver's active-trip card (Trip tab) and on the Dashboard active-trip hero. External-maps "Directions" remains as a secondary action.
- **Failure states:** no location permission → inline prompt with settings link; OSRM down → bearing/distance mode + external fallback; no destination anywhere → "Ask the mine to set their collection point on their profile."
- New files: `portal/models/nav_route.dart` (route, steps, maneuver enum with tolerant parse), `portal/services/routing_service.dart` (OSRM client, polyline decode), `portal/services/navigation_voice.dart` (TTS wrapper), `portal/providers/navigation_provider.dart` (nav session state machine), `portal/screens/driver_navigation_screen.dart`, `portal/widgets/nav_instruction_banner.dart`, `portal/widgets/nav_bottom_bar.dart`.
- Web/desktop: screen works (map + route + banner); voice/TTS and 1 s GPS depend on platform support — degrade silently.

## 5. Driver app shell — 3-tab design (Dashboard · Trip · Profile)

Adopt `driver_app_screen.dart` from the export as the driver's shell, **replacing the sidebar portal shell for the driver role only** (all other roles unchanged). **The Dashboard tab is the main landing page** — the shell opens on Dashboard (index 0), not on Trip as in the export mock (`_tab = 1` → `_tab = 0`). Mounted where `employeeTabs` currently builds the driver tab list (`portal_navigation.dart` / portal home) — when `role == UserRole.driver`, render `DriverAppScreen` instead.

**Feature-parity mapping (nothing lost):**

| Today (sidebar tab) | New home |
| --- | --- |
| Dashboard (generic) | **Dashboard tab** — real data (below) |
| My routes (`DriverRoutesScreen`) | **Trip tab** — unchanged screen |
| Live map (`LiveTripMapScreen`) | Dashboard → "Live map" quick-link card (pushes screen) |
| Truck locations (`TransporterTruckLocationsScreen`) | Dashboard → quick-link card |
| Truck positions (`TransporterTruckPositionsScreen`) | Dashboard → quick-link card |
| Driver (`DriverTabScreen`) | Dashboard → "My workspace" quick-link card (pushes screen) |
| Profile (`ProfileScreen`) | **Profile tab** — design layout; rows push real screens; "Full profile" row opens existing `ProfileScreen` so nothing is orphaned |
| Notifications bell | Header bell on Dashboard/Profile headers → real notifications inbox + real unread dot |

**Dashboard tab wiring (replace mock values):** driver's own trips only, from `logisticsSnapshotProvider(companyId)` filtered to the driver's assigned vehicle(s) via `driver_assignments` (same source `DriverRoutesScreen` uses):

- Active-trip hero: first active trip + request route; status pill from `TripStatus` display label; tap → Trip tab; **"Navigate" button** when a destination resolves.
- Four stat tiles: **Loads this week** (his trips with net weight recorded this week) / **Tons this week** (`sum(netTons)`) / **Deliveries** (his completed trips, all-time) / **Total tons** (all-time `sum(netTons)`, mono font). The mock's "On-time %" is dropped — there is no ETA-vs-actual data to compute it honestly; never fake a number.
- Live-location card: the existing real driver GPS-sharing toggle (reuse the existing widget/provider — same 30 s ping infra), not the mock `_LiveLocationCard`.
- Week chart: his completed trips' `netTons` grouped by weekday (dependency-free bars as in the export; `fl_chart` optional later).

**Profile tab wiring:** real name/initials/company/plate from profile + `driver_assignments`; My signature → existing signature editor; Trip history → his completed trips (count + list); Notifications → notifications screen; Language row omitted unless a language setting exists (**omit — YAGNI**); Sign out → existing `LogoutService`. `MlButton.danger` — verify exists, else outline+error tone.

## 6. Testing & verification

- **Unit tests:** maps short-link resolver (redirect parsing: `!3d/!4d`, `@lat,lng`, `?q=`), OSRM response decode + polyline decode, step-advance / off-route detection (pure functions), destination resolution chain (client side), maneuver-enum tolerant parse.
- **Live DB verification (Management API):** migration applied; RLS checked (company member vs outsider); `get_trip_nav_destination` exercised against a real trip; Ironhills row present with correct link.
- **App verification:** `flutter analyze` clean; run app, verify driver shell renders, dashboard numbers match Trip tab, nav screen fetches and draws a real OSRM route (simulated position on desktop/web where GPS is unavailable).
- Voice + real GPS-follow on a physical phone is the only part not verifiable headlessly (same 🟡 rule as CLAUDE.md live-tracking row).

## 7. Out of scope

- Offline routing/tiles; lane guidance; speed-limit display; traffic data (OSRM public has none).
- Public transporter marketplace, other roles' shells.
- Auto-firing lifecycle transitions from geofences (arrival always driver-confirmed).
