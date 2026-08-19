# Driver In-App Navigation + Mine Locations + Driver 3-Tab Shell — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task (user forbids subagents — execute inline). Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** In-app Waze-style turn-by-turn navigation (with voice) for drivers; a "Locations" section on the company profile so mines save named collection points (primary auto-used as the driver's destination, Ironhills seeded); and the approved 3-tab driver shell (Dashboard · Trip · Profile) with zero feature loss.

**Architecture:** OSRM public server computes routes/steps over the existing `flutter_map` + `geolocator` stack; a new `company_locations` table + `get_trip_nav_destination` security-definer RPC resolve the destination server-side; the driver shell swaps in at `PortalShellLayout` for `role == driver` on `/home` only.

**Tech Stack:** Flutter/Riverpod/go_router, flutter_map + latlong2, geolocator, http, flutter_tts (new), Supabase (Postgres RLS + RPC), OSRM HTTP API, Nominatim.

**Spec:** `docs/superpowers/specs/2026-07-16-driver-navigation-mine-locations-design.md`

## Global Constraints

- Package name is `flutter_application_1` — all imports `package:flutter_application_1/...`.
- Additive only: never remove existing behaviour; every current driver screen stays reachable; external-maps "Directions" stays as secondary action.
- 100% free mapping stack: OSRM `https://router.project-osrm.org` (overridable via `String.fromEnvironment('OSRM_BASE_URL')`), OSM tiles, Nominatim. No API keys, no billing.
- All colours/typography via `MlTokens` / `MlSemantic` / `MlTone` — no raw `Color(0x...)` in feature code (exception: the cyan→navy hero gradient `Color(0xFF0AA6C7)`/`Color(0xFF0B2545)` copied from the approved export design).
- DB access only through feature services; lifecycle mutations only via cascade RPCs (`set_trip_status` through `lifecycleServiceProvider.setTripStatus`).
- Security boundary in Postgres RLS/RPC, not Dart. RLS helpers that exist: `public.is_platform_admin()`, `public.is_company_staff(uuid)`, `public.is_company_manager(uuid)`, `public.is_company_owner(uuid)`.
- Supabase project `yftazblpmicqtamyiwyb` ONLY. Apply migrations via Management API `POST https://api.supabase.com/v1/projects/yftazblpmicqtamyiwyb/database/query` with Bearer token from repo root `USER_CUSTOM_RULES_AND_TOOLS.txt` (line 218; the token in memory `supabase-project.md` is dead — returns Unauthorized). If the shell permission classifier blocks the curl, STOP and ask the user to run it / approve — do not work around.
- Universal map-link format is `https://www.google.com/maps?q={lat},{lng}` (parser: `latLngFromMapsLink` in `lib/features/portal/utils/maps_link.dart`; builder: `googleMapsLink` in `lib/features/portal/widgets/location_picker.dart`).
- `flutter analyze` must stay clean; run `flutter test` before claiming done.
- Logging via `LoggerFactory.getLogger('Scope')`, never `print`.

## Verified codebase facts (do not re-derive)

- **Ironhills:** `companies.id = '6fead29e-434c-4ece-9680-c3beea042e6c'`, `company_name = 'Iron Hills Mining'`, `org_type = 'mineSupplier'`. Name column is **`company_name`** (NOT `name`). Target point: `-26.0285039, 28.0019869` (SPAR Kingfisher; from the user's short link).
- **Trip → parties → request linkage** (template: `supabase/migrations/20260712270000_live_gps_tracking.sql`): `trips t` → `transactions txn on txn.id = t.transaction_id` (`supplier_company_id`, `buyer_company_id`, `transporter_company_id`); `t.dispatch_id` → `request_dispatches d` → `transportation_requests r` (`r.loading_point`, `r.offloading_point`); text fallbacks `txn.metadata->>'loading_point'`, `t.metadata->>'loading_point'` (same for offloading).
- **Driver's current screen:** `lib/features/portal/screens/driver_routes_screen.dart` — `DriverRoutesScreen` (ConsumerWidget). Its `_directions` method (lines ~209–230) launches external Google Maps. `_LiveTrackingCard` (line ~664) is the real GPS-sharing toggle backed by `tripPositionReporterProvider` (`lib/features/portal/services/trip_position_reporter.dart`).
- **Driver data sources:** `resolvePortalCompanyId(ref)` (`portal/utils/portal_company_resolution.dart`); `employeeProvider.employee`; `fleetProvider(companyId).activeVehicles`; `vehicleDriversProvider(companyId)` (`List<VehicleDriver>`, match `a.driverEmployeeId == employee.id` → `a.vehicleId`); `logisticsSnapshotProvider(companyId)` → `snap.trips` (`List<TripRecord>`); `transporterDispatchesProvider(companyId)` → `List<DispatchedRoute>` keyed by `d.dispatchId`, each has `.request` (`TransportationRequest` with `.loadingPoint`, `.offloadingPoint`, `.commodity`, `.routeLabel`).
- **TripRecord** (`portal/models/logistics_models.dart:30`): `id, transactionId, vehicleId?, routeId?, dispatchId?, status, netTons?, truckReg?, updatedAt`.
- **Lifecycle:** `ref.read(lifecycleServiceProvider).setTripStatus(trip.id, TripStatus.arrivedAtMine)`.
- **Driver tab list today** (`lib/features/portal/portal_navigation.dart:197–211`): Dashboard, My routes (`DriverRoutesScreen`), Live map (`LiveTripMapScreen`), Truck locations (`TransporterTruckLocationsScreen`), Truck positions (`TransporterTruckPositionsScreen`), Driver (`DriverTabScreen` in `lib/features/tabs/screens/driver_tab_screen.dart`), Profile (`ProfileScreen`).
- **Shell swap point:** `lib/features/portal/widgets/portal_shell_layout.dart` `build()` (~line 213): after `vm.phase == ready`, `location = GoRouterState.of(context).uri.path`. Swap when `location == '/home'` and `employeeState.employee?.role == UserRole.driver`.
- **Company's own profile:** `ProfileScreen` (`lib/features/profile/screens/profile_screen.dart`) at `/profile`; when `authState.userType?.isCompany == true` it renders `_buildCompanyProfileForm()` — the Locations section mounts below it. Company id from `ref.watch(companyProvider).company?.id`.
- **Reusable bits:** `ProfileSignatureCard()` (no args), `AnimatedNotificationBell()` (no args, self-routes to inbox), `LogoutService.logoutWithConfirmation(context, ref)`, `MlButton.primary/.go/.tonal/.outline/.ghost/.danger`, `MlCard`, `MlIconWell`, `MlSectionTitle`, `MlPlatePill`, `MlStatusBadge`, `MlEmptyState`, `PortalScrollBody`, `formatTons` (from `portal/widgets/premium_overview_widgets.dart`).
- **Design source:** `C:\Users\Somebody Someone\Downloads\Mobile driver app update\flutter_export\driver_app_screen.dart` — copy into repo and wire (Task 8). Land on Dashboard: `_tab = 0`.
- **Existing tests to extend:** `test/location_link_test.dart` covers `latLngFromMapsLink`.

---

### Task 1: Google-Maps short-link resolver (`maps_short_link.dart`)

**Files:**
- Create: `lib/features/portal/utils/maps_short_link.dart`
- Test: `test/features/portal/maps_short_link_test.dart`

**Interfaces:**
- Consumes: `latLngFromMapsLink` from `package:flutter_application_1/features/portal/utils/maps_link.dart`; `package:http/http.dart`.
- Produces: `LatLng? latLngFromExpandedMapsUrl(String url)` and `Future<LatLng?> resolveMapsLink(String link, {http.Client? client})` — Task 4's paste-a-link flow and Task 3's model use these.

- [ ] **Step 1: Write the failing tests**

```dart
// test/features/portal/maps_short_link_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';

import 'package:flutter_application_1/features/portal/utils/maps_short_link.dart';

void main() {
  group('latLngFromExpandedMapsUrl', () {
    test('parses place-pin !3d/!4d form (authoritative over @viewport)', () {
      final p = latLngFromExpandedMapsUrl(
          'https://www.google.com/maps/place/SPAR+Kingfisher/@-26.0285039,27.999412,17z/'
          'data=!3m1!4b1!4m6!3m5!1s0x1e95774af82ae7c3:0xd9da9d64c5f0a485'
          '!8m2!3d-26.0285039!4d28.0019869!16s%2Fg%2F11h5mkjb0r');
      expect(p, isNotNull);
      expect(p!.latitude, closeTo(-26.0285039, 1e-7));
      expect(p.longitude, closeTo(28.0019869, 1e-7)); // NOT 27.999412
    });

    test('falls back to @lat,lng viewport form', () {
      final p = latLngFromExpandedMapsUrl(
          'https://www.google.com/maps/@-29.85,31.02,12z');
      expect(p, isNotNull);
      expect(p!.latitude, closeTo(-29.85, 1e-9));
      expect(p.longitude, closeTo(31.02, 1e-9));
    });

    test('parses ?q= form', () {
      final p = latLngFromExpandedMapsUrl(
          'https://www.google.com/maps?q=-26.03,28.0');
      expect(p, equals(const LatLng(-26.03, 28.0)));
    });

    test('rejects junk', () {
      expect(latLngFromExpandedMapsUrl('https://example.com/nothing'), isNull);
      expect(latLngFromExpandedMapsUrl('not a url'), isNull);
    });
  });

  group('resolveMapsLink', () {
    test('already-parseable ?q= link needs no network', () async {
      final p = await resolveMapsLink('https://www.google.com/maps?q=-1.5,30.5',
          client: MockClient((_) async => throw StateError('no network expected')));
      expect(p, equals(const LatLng(-1.5, 30.5)));
    });

    test('short link follows redirect Location header', () async {
      final client = MockClient((req) async {
        expect(req.url.host, 'maps.app.goo.gl');
        return http.Response('', 302, headers: {
          'location':
              'https://www.google.com/maps/place/X/@-26.0285039,27.999412,17z/'
              'data=!8m2!3d-26.0285039!4d28.0019869'
        });
      });
      final p = await resolveMapsLink('https://maps.app.goo.gl/XcJEYHJFu15XyLY67',
          client: client);
      expect(p!.latitude, closeTo(-26.0285039, 1e-7));
      expect(p.longitude, closeTo(28.0019869, 1e-7));
    });

    test('network failure returns null (never throws)', () async {
      final client = MockClient((_) async => throw http.ClientException('down'));
      final p = await resolveMapsLink('https://maps.app.goo.gl/abc', client: client);
      expect(p, isNull);
    });
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/portal/maps_short_link_test.dart`
Expected: FAIL — `maps_short_link.dart` does not exist.

- [ ] **Step 3: Implement**

```dart
// lib/features/portal/utils/maps_short_link.dart
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import 'package:flutter_application_1/core/utils/logger.dart';
import 'package:flutter_application_1/features/portal/utils/maps_link.dart';

final _log = LoggerFactory.getLogger('MapsShortLink');

/// Extracts a point from a full (already-expanded) Google Maps URL.
/// Priority: `!3d{lat}!4d{lng}` place pin (authoritative) → `?q=lat,lng`
/// → `@lat,lng` viewport centre (weakest). Returns null when nothing parses.
LatLng? latLngFromExpandedMapsUrl(String url) {
  final pin = RegExp(r'!3d(-?\d+(?:\.\d+)?)!4d(-?\d+(?:\.\d+)?)').firstMatch(url);
  if (pin != null) {
    final p = _validated(pin.group(1)!, pin.group(2)!);
    if (p != null) return p;
  }
  final q = latLngFromMapsLink(url);
  if (q != null) return q;
  final at = RegExp(r'@(-?\d+(?:\.\d+)?),(-?\d+(?:\.\d+)?)').firstMatch(url);
  if (at != null) return _validated(at.group(1)!, at.group(2)!);
  return null;
}

LatLng? _validated(String latS, String lngS) {
  final lat = double.tryParse(latS);
  final lng = double.tryParse(lngS);
  if (lat == null || lng == null) return null;
  if (lat < -90 || lat > 90 || lng < -180 || lng > 180) return null;
  return LatLng(lat, lng);
}

/// Resolves ANY Google Maps link — long, `?q=`, or short `maps.app.goo.gl` —
/// to a point. Short links are expanded by following the redirect chain
/// (no API key needed). Returns null on failure; never throws.
Future<LatLng?> resolveMapsLink(String link, {http.Client? client}) async {
  final trimmed = link.trim();
  final direct = latLngFromExpandedMapsUrl(trimmed);
  if (direct != null) return direct;

  final uri = Uri.tryParse(trimmed);
  if (uri == null || !uri.hasScheme) return null;

  final c = client ?? http.Client();
  try {
    // Walk redirects manually so we can parse coordinates out of each hop's
    // Location header (google.com URLs 200 with a JS page — the coords live
    // in the URL itself, so headers are all we need).
    var current = uri;
    for (var hop = 0; hop < 5; hop++) {
      final req = http.Request('GET', current)..followRedirects = false;
      final res = await c.send(req).timeout(const Duration(seconds: 12));
      final location = res.headers['location'];
      if (location == null) break;
      final next = Uri.parse(location);
      final resolved = next.hasScheme ? next : current.resolveUri(next);
      final p = latLngFromExpandedMapsUrl(resolved.toString());
      if (p != null) return p;
      current = resolved;
    }
  } catch (e) {
    _log.warning('Could not resolve maps link: $e');
  } finally {
    if (client == null) c.close();
  }
  return null;
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/portal/maps_short_link_test.dart`
Expected: PASS (all 7).

- [ ] **Step 5: Commit**

```bash
git add lib/features/portal/utils/maps_short_link.dart test/features/portal/maps_short_link_test.dart
git commit -m "feat(locations): resolve any Google Maps link (incl. short links) to coordinates"
```

---

### Task 2: `company_locations` migration + `get_trip_nav_destination` RPC + Ironhills seed

**Files:**
- Create: `supabase/migrations/20260716090000_company_locations.sql`

**Interfaces:**
- Consumes: existing `companies`, `trips`, `transactions`, `request_dispatches`, `transportation_requests` tables; RLS helpers `is_platform_admin()`, `is_company_staff(uuid)`, `is_company_manager(uuid)`.
- Produces: table `public.company_locations(id, company_id, name, map_link, is_primary, created_by, created_at, updated_at)`; RPC `set_primary_company_location(p_location_id uuid) returns void`; RPC `get_trip_nav_destination(p_trip_id uuid, p_leg text) returns jsonb` — `{found bool, lat, lng, label text, source text, address text}`. Tasks 3/8 call these.

- [ ] **Step 1: Read `supabase/MIGRATION_HYGIENE.txt`** (mandatory pre-migration step). Confirm no remote migration already defines these objects (list remote migrations via Management API `GET /v1/projects/yftazblpmicqtamyiwyb/database/migrations` or check the applied list with a query on `supabase_migrations.schema_migrations`).

- [ ] **Step 2: Write the migration**

```sql
-- Company locations (spec 2026-07-16): named, mine-managed collection points.
-- The PRIMARY location is the automatic fallback destination for driver
-- navigation when a trip's request has no coordinate loading/offloading point.
-- Destination resolution is server-side (get_trip_nav_destination) so the
-- table's RLS can stay company-scoped — trip parties never read it directly.

begin;

-- 1. Table -------------------------------------------------------------------

create table if not exists public.company_locations (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete cascade,
  name text not null check (length(trim(name)) between 1 and 120),
  map_link text not null check (map_link ~ '^https://www\.google\.com/maps\?q=-?\d+(\.\d+)?,-?\d+(\.\d+)?$'),
  is_primary boolean not null default false,
  created_by uuid default auth.uid(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists company_locations_company_idx
  on public.company_locations (company_id, created_at desc);

-- At most one primary per company.
create unique index if not exists company_locations_one_primary
  on public.company_locations (company_id) where is_primary;

alter table public.company_locations enable row level security;

-- 2. RLS ----------------------------------------------------------------------
-- Members read their company's locations; owner/admin/management write.

drop policy if exists company_locations_select on public.company_locations;
create policy company_locations_select on public.company_locations
for select to authenticated
using (public.is_platform_admin() or public.is_company_staff(company_id));

drop policy if exists company_locations_insert on public.company_locations;
create policy company_locations_insert on public.company_locations
for insert to authenticated
with check (public.is_platform_admin() or public.is_company_manager(company_id));

drop policy if exists company_locations_update on public.company_locations;
create policy company_locations_update on public.company_locations
for update to authenticated
using (public.is_platform_admin() or public.is_company_manager(company_id))
with check (public.is_platform_admin() or public.is_company_manager(company_id));

drop policy if exists company_locations_delete on public.company_locations;
create policy company_locations_delete on public.company_locations
for delete to authenticated
using (public.is_platform_admin() or public.is_company_manager(company_id));

grant select, insert, update, delete on public.company_locations to authenticated;

-- 3. Primary switch (transactional clear-then-set) ----------------------------

create or replace function public.set_primary_company_location(p_location_id uuid)
returns void
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_company_id uuid;
begin
  select company_id into v_company_id
  from public.company_locations where id = p_location_id;
  if v_company_id is null then
    raise exception 'Location not found';
  end if;
  if not (public.is_platform_admin() or public.is_company_manager(v_company_id)) then
    raise exception 'Not allowed';
  end if;
  update public.company_locations
    set is_primary = false, updated_at = now()
    where company_id = v_company_id and is_primary and id <> p_location_id;
  update public.company_locations
    set is_primary = true, updated_at = now()
    where id = p_location_id;
end;
$$;

revoke all on function public.set_primary_company_location(uuid) from public;
revoke all on function public.set_primary_company_location(uuid) from anon;
grant execute on function public.set_primary_company_location(uuid) to authenticated;

-- 4. Navigation destination resolution -----------------------------------------
-- Chain (spec §2): request coordinate link → party company's primary location
-- → plain-text address (client geocodes / external maps). Caller must be a
-- party to the trip (same clause as list_live_trip_positions).

create or replace function public.get_trip_nav_destination(
  p_trip_id uuid,
  p_leg text default 'load'
)
returns jsonb
language plpgsql
stable
security definer
set search_path to 'public'
as $$
declare
  v_point text;      -- request/metadata loading_point or offloading_point
  v_company uuid;    -- fallback company (mine for load, buyer for offload)
  v_company_name text;
  v_link text;
  v_loc_name text;
  v_lat double precision;
  v_lng double precision;
begin
  if p_leg not in ('load', 'offload') then
    raise exception 'p_leg must be load or offload';
  end if;

  select
    case when p_leg = 'load'
      then coalesce(r.loading_point,  txn.metadata->>'loading_point',  t.metadata->>'loading_point')
      else coalesce(r.offloading_point, txn.metadata->>'offloading_point', t.metadata->>'offloading_point')
    end,
    case when p_leg = 'load' then txn.supplier_company_id else txn.buyer_company_id end,
    case when p_leg = 'load' then sc.company_name else bc.company_name end
  into v_point, v_company, v_company_name
  from public.trips t
  join public.transactions txn on txn.id = t.transaction_id
  left join public.request_dispatches d on d.id = t.dispatch_id
  left join public.transportation_requests r on r.id = d.request_id
  left join public.companies sc on sc.id = txn.supplier_company_id
  left join public.companies bc on bc.id = txn.buyer_company_id
  where t.id = p_trip_id
    and (
      public.is_platform_admin()
      or public.is_company_staff(txn.supplier_company_id)
      or public.is_company_staff(txn.buyer_company_id)
      or public.is_company_staff(txn.transporter_company_id)
    );

  if not found then
    raise exception 'Trip not found or not yours';
  end if;

  -- 1. Coordinate link on the request/trip itself.
  if v_point ~ '[?&]q=-?\d+(\.\d+)?,-?\d+(\.\d+)?' then
    v_lat := (regexp_match(v_point, '[?&]q=(-?\d+(?:\.\d+)?),(-?\d+(?:\.\d+)?)'))[1]::double precision;
    v_lng := (regexp_match(v_point, '[?&]q=(-?\d+(?:\.\d+)?),(-?\d+(?:\.\d+)?)'))[2]::double precision;
    return jsonb_build_object('found', true, 'lat', v_lat, 'lng', v_lng,
      'label', coalesce(v_company_name, 'Destination'), 'source', 'request');
  end if;

  -- 2. The party company's PRIMARY saved location.
  select cl.map_link, cl.name into v_link, v_loc_name
  from public.company_locations cl
  where cl.company_id = v_company and cl.is_primary
  limit 1;

  if v_link is not null then
    v_lat := (regexp_match(v_link, '[?&]q=(-?\d+(?:\.\d+)?),(-?\d+(?:\.\d+)?)'))[1]::double precision;
    v_lng := (regexp_match(v_link, '[?&]q=(-?\d+(?:\.\d+)?),(-?\d+(?:\.\d+)?)'))[2]::double precision;
    return jsonb_build_object('found', true, 'lat', v_lat, 'lng', v_lng,
      'label', coalesce(v_company_name, '') || ' — ' || v_loc_name,
      'source', 'company_location');
  end if;

  -- 3. Plain-text address only (client decides what to do with it).
  if v_point is not null and length(trim(v_point)) > 0 then
    return jsonb_build_object('found', false, 'address', v_point,
      'label', coalesce(v_company_name, 'Destination'), 'source', 'address');
  end if;

  return jsonb_build_object('found', false, 'source', 'none');
end;
$$;

revoke all on function public.get_trip_nav_destination(uuid, text) from public;
revoke all on function public.get_trip_nav_destination(uuid, text) from anon;
grant execute on function public.get_trip_nav_destination(uuid, text) to authenticated;

-- 5. Realtime -------------------------------------------------------------------

do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public' and tablename = 'company_locations'
  ) then
    alter publication supabase_realtime add table public.company_locations;
  end if;
end $$;

-- 6. Ironhills seed (idempotent; id verified live 2026-07-16) --------------------
-- Point from the user's link https://maps.app.goo.gl/XcJEYHJFu15XyLY67
-- (SPAR Kingfisher, -26.0285039, 28.0019869).

insert into public.company_locations (company_id, name, map_link, is_primary)
select c.id, 'Collection point (SPAR Kingfisher area)',
       'https://www.google.com/maps?q=-26.0285039,28.0019869', true
from public.companies c
where c.id = '6fead29e-434c-4ece-9680-c3beea042e6c'
  and not exists (
    select 1 from public.company_locations cl where cl.company_id = c.id and cl.is_primary
  );

commit;
```

- [ ] **Step 3: Apply to live** via Management API (token from `USER_CUSTOM_RULES_AND_TOOLS.txt`; if the permission classifier blocks it, stop and ask the user):

```bash
python - <<'EOF'
import json, pathlib, urllib.request
sql = pathlib.Path('supabase/migrations/20260716090000_company_locations.sql').read_text()
req = urllib.request.Request(
    'https://api.supabase.com/v1/projects/yftazblpmicqtamyiwyb/database/query',
    data=json.dumps({'query': sql}).encode(),
    headers={'Authorization': 'Bearer <TOKEN-FROM-USER_CUSTOM_RULES_AND_TOOLS.txt-line-218>',
             'Content-Type': 'application/json'}, method='POST')
print(urllib.request.urlopen(req).read().decode())
EOF
```

- [ ] **Step 4: Verify live** (all via PostgREST with the Ironhills owner login `ironhills.owner@mineralguide.com` / `MineralGuide123!`, publishable key `sb_publishable__v4NAadmMazm3CLy9RGeeQ_cuzyVhy4`):
  1. `GET /rest/v1/company_locations?select=*` as Ironhills owner → exactly the seeded row, `is_primary=true`.
  2. Same query as `atlasbuyer.owner@mineralguide.com` → `[]` (RLS holds — buyer is not Ironhills staff).
  3. `POST /rest/v1/rpc/get_trip_nav_destination` `{"p_trip_id": "<an active Ironhills trip id>", "p_leg": "load"}` as the trip's driver or Ironhills owner → jsonb with `found:true` and either `source:request` or `source:company_location` (lat/lng = -26.0285039/28.0019869 if fallback). Find a trip id first: `GET /rest/v1/trips?select=id,status&status=not.in.(completed,cancelled)&limit=1` as Ironhills owner.
  4. Roll back nothing — seed is intended state.

- [ ] **Step 5: Commit**

```bash
git add supabase/migrations/20260716090000_company_locations.sql
git commit -m "feat(locations): company_locations table, primary switch, nav-destination RPC, Ironhills seed"
```

---

### Task 3: `CompanyLocation` + `NavDestination` models, service, providers

**Files:**
- Create: `lib/features/portal/models/company_location.dart`
- Create: `lib/features/portal/services/company_location_service.dart`
- Create: `lib/features/portal/providers/company_location_provider.dart`
- Test: `test/models/company_location_test.dart`

**Interfaces:**
- Consumes: Task 2's table/RPCs; `latLngFromMapsLink`; `SupabaseConfig.client` (match the client-access pattern used in `lib/features/portal/services/lifecycle_service.dart` — read that file first and mirror its constructor/provider style exactly).
- Produces: `CompanyLocation {id, companyId, name, mapLink, isPrimary, LatLng? point}` with `fromJson`; `NavDestination {found, LatLng? point, String label, String source, String? address}` with `fromJson`; `CompanyLocationService {list(companyId), add(companyId, name, mapLink), rename(id, name), move(id, mapLink), remove(id), setPrimary(id), tripNavDestination(tripId, {required bool offloadLeg})}`; providers `companyLocationServiceProvider`, `companyLocationsProvider(companyId)` (autoDispose FutureProvider.family).

- [ ] **Step 1: Write the failing model tests**

```dart
// test/models/company_location_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'package:flutter_application_1/features/portal/models/company_location.dart';

void main() {
  test('CompanyLocation.fromJson parses and derives point', () {
    final l = CompanyLocation.fromJson({
      'id': 'a', 'company_id': 'c', 'name': 'Main gate',
      'map_link': 'https://www.google.com/maps?q=-26.0285039,28.0019869',
      'is_primary': true,
    });
    expect(l.name, 'Main gate');
    expect(l.isPrimary, isTrue);
    expect(l.point, isNotNull);
    expect(l.point!.latitude, closeTo(-26.0285039, 1e-7));
  });

  test('NavDestination.fromJson found / address / none forms', () {
    final found = NavDestination.fromJson({
      'found': true, 'lat': -26.0, 'lng': 28.0, 'label': 'Iron Hills — Gate',
      'source': 'company_location',
    });
    expect(found.point, equals(const LatLng(-26.0, 28.0)));
    expect(found.found, isTrue);

    final addr = NavDestination.fromJson({
      'found': false, 'address': 'Steelport, Limpopo', 'label': 'X', 'source': 'address',
    });
    expect(addr.point, isNull);
    expect(addr.address, 'Steelport, Limpopo');

    final none = NavDestination.fromJson({'found': false, 'source': 'none'});
    expect(none.found, isFalse);
    expect(none.point, isNull);
    expect(none.address, isNull);
  });
}
```

- [ ] **Step 2: Run** `flutter test test/models/company_location_test.dart` — FAIL (file missing).

- [ ] **Step 3: Implement the model**

```dart
// lib/features/portal/models/company_location.dart
import 'package:latlong2/latlong.dart';

import 'package:flutter_application_1/features/portal/utils/maps_link.dart';

/// A named, company-managed map point (spec 2026-07-16 §2/§3). The primary
/// location is the automatic driver-navigation fallback destination.
class CompanyLocation {
  final String id;
  final String companyId;
  final String name;
  final String mapLink; // universal 'https://www.google.com/maps?q=lat,lng'
  final bool isPrimary;

  const CompanyLocation({
    required this.id,
    required this.companyId,
    required this.name,
    required this.mapLink,
    required this.isPrimary,
  });

  LatLng? get point => latLngFromMapsLink(mapLink);

  factory CompanyLocation.fromJson(Map<String, dynamic> json) => CompanyLocation(
        id: json['id'] as String,
        companyId: json['company_id'] as String,
        name: (json['name'] as String?) ?? '',
        mapLink: (json['map_link'] as String?) ?? '',
        isPrimary: (json['is_primary'] as bool?) ?? false,
      );
}

/// Result of get_trip_nav_destination: where the driver should drive for the
/// current leg, and where that answer came from
/// (request | company_location | address | none).
class NavDestination {
  final bool found;
  final LatLng? point;
  final String label;
  final String source;
  final String? address;

  const NavDestination({
    required this.found,
    this.point,
    required this.label,
    required this.source,
    this.address,
  });

  factory NavDestination.fromJson(Map<String, dynamic> json) {
    final lat = (json['lat'] as num?)?.toDouble();
    final lng = (json['lng'] as num?)?.toDouble();
    return NavDestination(
      found: (json['found'] as bool?) ?? false,
      point: (lat != null && lng != null) ? LatLng(lat, lng) : null,
      label: (json['label'] as String?) ?? 'Destination',
      source: (json['source'] as String?) ?? 'none',
      address: json['address'] as String?,
    );
  }
}
```

- [ ] **Step 4: Run the model tests** — PASS.

- [ ] **Step 5: Implement service + providers** (mirror `lifecycle_service.dart`'s Supabase-client style — verify before writing; adjust ONLY the client plumbing to match, keep method bodies):

```dart
// lib/features/portal/services/company_location_service.dart
import 'package:flutter_application_1/core/config/supabase_config.dart';
import 'package:flutter_application_1/core/utils/logger.dart';
import 'package:flutter_application_1/features/portal/models/company_location.dart';

/// CRUD for company_locations + trip nav-destination resolution (all DB access
/// for the Locations feature lives here, per CLAUDE.md §6).
class CompanyLocationService {
  static final _log = LoggerFactory.getLogger('CompanyLocationService');
  final _client = SupabaseConfig.client;

  Future<List<CompanyLocation>> list(String companyId) async {
    final rows = await _client
        .from('company_locations')
        .select()
        .eq('company_id', companyId)
        .order('is_primary', ascending: false)
        .order('created_at');
    return [for (final r in rows) CompanyLocation.fromJson(r)];
  }

  Future<void> add(String companyId, String name, String mapLink) async {
    await _client.from('company_locations').insert({
      'company_id': companyId,
      'name': name.trim(),
      'map_link': mapLink,
    });
  }

  Future<void> rename(String id, String name) async {
    await _client
        .from('company_locations')
        .update({'name': name.trim(), 'updated_at': DateTime.now().toIso8601String()})
        .eq('id', id);
  }

  Future<void> move(String id, String mapLink) async {
    await _client
        .from('company_locations')
        .update({'map_link': mapLink, 'updated_at': DateTime.now().toIso8601String()})
        .eq('id', id);
  }

  Future<void> remove(String id) async {
    await _client.from('company_locations').delete().eq('id', id);
  }

  Future<void> setPrimary(String id) async {
    await _client.rpc('set_primary_company_location', params: {'p_location_id': id});
  }

  Future<NavDestination> tripNavDestination(String tripId,
      {required bool offloadLeg}) async {
    final res = await _client.rpc('get_trip_nav_destination', params: {
      'p_trip_id': tripId,
      'p_leg': offloadLeg ? 'offload' : 'load',
    });
    _log.fine('nav destination for $tripId: $res');
    return NavDestination.fromJson(Map<String, dynamic>.from(res as Map));
  }
}
```

```dart
// lib/features/portal/providers/company_location_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter_application_1/features/portal/models/company_location.dart';
import 'package:flutter_application_1/features/portal/services/company_location_service.dart';

final companyLocationServiceProvider =
    Provider<CompanyLocationService>((ref) => CompanyLocationService());

/// The company's saved locations, primary first.
final companyLocationsProvider = FutureProvider.autoDispose
    .family<List<CompanyLocation>, String>((ref, companyId) {
  return ref.watch(companyLocationServiceProvider).list(companyId);
});
```

- [ ] **Step 6: Analyze + commit**

Run: `flutter analyze` → clean.

```bash
git add lib/features/portal/models/company_location.dart lib/features/portal/services/company_location_service.dart lib/features/portal/providers/company_location_provider.dart test/models/company_location_test.dart
git commit -m "feat(locations): CompanyLocation/NavDestination models, service, providers"
```

---

### Task 4: "Locations" section on the company profile

**Files:**
- Create: `lib/features/portal/widgets/company_locations_section.dart`
- Modify: `lib/features/profile/screens/profile_screen.dart` (company branch — mount the section below `_buildCompanyProfileForm()`)

**Interfaces:**
- Consumes: Task 3 providers/service; `showLocationPickerDialog` (`portal/widgets/location_picker.dart`); `googleMapsLink(lat,lng)` (same file); `resolveMapsLink` (Task 1); `MlCard`/`MlSectionTitle`/`MlButton`/`MlIconWell`/`MlEmptyState` from `portal/widgets/ml/ml.dart`.
- Produces: `CompanyLocationsSection({required String companyId, super.key})` — a self-contained ConsumerWidget; used by ProfileScreen (this task) and reachable for any org type.

- [ ] **Step 1: Build the widget**

```dart
// lib/features/portal/widgets/company_locations_section.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter_application_1/core/theme/ml_tokens.dart';
import 'package:flutter_application_1/features/portal/models/company_location.dart';
import 'package:flutter_application_1/features/portal/providers/company_location_provider.dart';
import 'package:flutter_application_1/features/portal/utils/maps_short_link.dart';
import 'package:flutter_application_1/features/portal/widgets/location_picker.dart';
import 'package:flutter_application_1/features/portal/widgets/ml/ml.dart';

/// "Locations" on the company profile (spec §3): named map points, one
/// primary. The primary is what drivers automatically navigate to when a
/// trip has no coordinate loading/offloading point.
class CompanyLocationsSection extends ConsumerWidget {
  final String companyId;
  const CompanyLocationsSection({required this.companyId, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(companyLocationsProvider(companyId));
    final semantic = MlSemantic.of(context);

    return MlCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const MlIconWell(
                icon: Icons.location_on_outlined, tone: MlTone.accent, size: 40, radius: 12),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Locations',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w800, color: semantic.textStrong)),
                Text('Drivers are routed to the primary location automatically.',
                    style: TextStyle(fontSize: 12.5, color: semantic.textMuted)),
              ]),
            ),
            MlButton.tonal(
                label: 'Add location',
                icon: Icons.add_location_alt_outlined,
                onPressed: () => _addOrEdit(context, ref)),
          ]),
          const SizedBox(height: 14),
          async.when(
            loading: () => const Padding(
                padding: EdgeInsets.all(18),
                child: Center(child: CircularProgressIndicator())),
            error: (e, _) => MlEmptyState(
                icon: Icons.wifi_off_rounded,
                title: 'Could not load locations.',
                message: '$e'),
            data: (rows) => rows.isEmpty
                ? const MlEmptyState(
                    icon: Icons.add_location_alt_outlined,
                    title: 'No locations saved yet.',
                    message:
                        'Add your collection point so drivers get directions automatically.')
                : Column(children: [for (final l in rows) _row(context, ref, l, semantic)]),
          ),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, WidgetRef ref, CompanyLocation l, MlSemantic semantic) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration:
          BoxDecoration(border: Border(bottom: BorderSide(color: semantic.divider))),
      child: Row(children: [
        Icon(l.isPrimary ? Icons.star_rounded : Icons.location_on_outlined,
            size: 20,
            color: l.isPrimary
                ? MlTone.done.colors(Theme.of(context).brightness).fg
                : semantic.textFaint),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(l.name,
                style: TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w700, color: semantic.textStrong)),
            Text(
                l.point == null
                    ? l.mapLink
                    : '${l.point!.latitude.toStringAsFixed(6)}, '
                        '${l.point!.longitude.toStringAsFixed(6)}'
                        '${l.isPrimary ? ' · Primary' : ''}',
                style: TextStyle(
                    fontFamily: 'JetBrainsMono', fontSize: 11.5, color: semantic.textMuted)),
          ]),
        ),
        if (!l.isPrimary)
          IconButton(
              tooltip: 'Set as primary',
              icon: const Icon(Icons.star_outline_rounded, size: 20),
              onPressed: () => _mutate(context, ref, () =>
                  ref.read(companyLocationServiceProvider).setPrimary(l.id))),
        IconButton(
            tooltip: 'Edit',
            icon: const Icon(Icons.edit_outlined, size: 19),
            onPressed: () => _addOrEdit(context, ref, existing: l)),
        IconButton(
            tooltip: 'Delete',
            icon: const Icon(Icons.delete_outline_rounded, size: 20),
            onPressed: () => _delete(context, ref, l)),
      ]),
    );
  }

  Future<void> _mutate(
      BuildContext context, WidgetRef ref, Future<void> Function() op) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await op();
      ref.invalidate(companyLocationsProvider(companyId));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Could not save: $e')));
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, CompanyLocation l) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete location?'),
        content: Text('"${l.name}" will be removed. Drivers will no longer be '
            'routed here automatically.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      await _mutate(context, ref,
          () => ref.read(companyLocationServiceProvider).remove(l.id));
    }
  }

  Future<void> _addOrEdit(BuildContext context, WidgetRef ref,
      {CompanyLocation? existing}) async {
    final result = await showDialog<({String name, String mapLink})>(
      context: context,
      builder: (_) => _LocationEditDialog(existing: existing),
    );
    if (result == null || !context.mounted) return;
    await _mutate(context, ref, () async {
      final svc = ref.read(companyLocationServiceProvider);
      if (existing == null) {
        await svc.add(companyId, result.name, result.mapLink);
      } else {
        await svc.rename(existing.id, result.name);
        if (result.mapLink != existing.mapLink) {
          await svc.move(existing.id, result.mapLink);
        }
      }
    });
  }
}

/// Name + point entry: pick on the free OSM map, or paste any Google Maps
/// link (short maps.app.goo.gl links are expanded automatically).
class _LocationEditDialog extends StatefulWidget {
  final CompanyLocation? existing;
  const _LocationEditDialog({this.existing});

  @override
  State<_LocationEditDialog> createState() => _LocationEditDialogState();
}

class _LocationEditDialogState extends State<_LocationEditDialog> {
  late final _name = TextEditingController(text: widget.existing?.name ?? '');
  final _link = TextEditingController();
  String? _mapLink;
  String? _error;
  bool _resolving = false;

  @override
  void initState() {
    super.initState();
    _mapLink = widget.existing?.mapLink;
  }

  @override
  void dispose() {
    _name.dispose();
    _link.dispose();
    super.dispose();
  }

  Future<void> _pickOnMap() async {
    final picked = await showLocationPickerDialog(context, initial: _mapLink);
    if (picked != null) setState(() { _mapLink = picked; _error = null; });
  }

  Future<void> _useLink() async {
    setState(() { _resolving = true; _error = null; });
    final p = await resolveMapsLink(_link.text);
    if (!mounted) return;
    setState(() {
      _resolving = false;
      if (p == null) {
        _error = 'Could not read a location from that link.';
      } else {
        _mapLink = googleMapsLink(p.latitude, p.longitude);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final semantic = MlSemantic.of(context);
    return AlertDialog(
      title: Text(widget.existing == null ? 'Add location' : 'Edit location'),
      content: SizedBox(
        width: 420,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
              controller: _name,
              decoration: const InputDecoration(
                  labelText: 'Name', hintText: 'e.g. Main gate / Weighbridge 2')),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(
                child: MlButton.outline(
                    label: _mapLink == null ? 'Pick on map' : 'Change on map',
                    icon: Icons.map_outlined,
                    onPressed: _pickOnMap)),
          ]),
          const SizedBox(height: 10),
          TextField(
            controller: _link,
            decoration: InputDecoration(
              labelText: 'Or paste a Google Maps link',
              hintText: 'https://maps.app.goo.gl/…',
              suffixIcon: _resolving
                  ? const Padding(
                      padding: EdgeInsets.all(10),
                      child: SizedBox(
                          width: 18, height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2)))
                  : IconButton(
                      icon: const Icon(Icons.check_rounded), onPressed: _useLink),
            ),
            onSubmitted: (_) => _useLink(),
          ),
          const SizedBox(height: 10),
          if (_error != null)
            Text(_error!,
                style: TextStyle(
                    fontSize: 12.5,
                    color: MlTone.error.colors(Theme.of(context).brightness).fg)),
          if (_mapLink != null)
            Align(
              alignment: Alignment.centerLeft,
              child: Text('Saved point: $_mapLink',
                  style: TextStyle(
                      fontFamily: 'JetBrainsMono',
                      fontSize: 11,
                      color: semantic.textMuted)),
            ),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            if (_name.text.trim().isEmpty) {
              setState(() => _error = 'Give the location a name.');
              return;
            }
            if (_mapLink == null) {
              setState(() => _error = 'Pick a point on the map or paste a link.');
              return;
            }
            Navigator.pop(context, (name: _name.text, mapLink: _mapLink!));
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
```

Note: `MlTone.error` / `MlTone.done` `.colors(...)` calls — confirm the exact accessor (`fg`) against `ml_tokens.dart` while implementing; the export file uses `MlTone.done.colors(Theme.of(context).brightness).fg`, so this matches.

- [ ] **Step 2: Mount in ProfileScreen.** In `lib/features/profile/screens/profile_screen.dart`, in the company branch (`authState.userType?.isCompany == true` → `_buildCompanyProfileForm()` around line 346), add directly after the form widget, guarded by a non-null company id:

```dart
// after: _buildCompanyProfileForm()
if (authState.userType?.isCompany == true &&
    companyState.company?.id != null) ...[
  const SizedBox(height: 18),
  CompanyLocationsSection(companyId: companyState.company!.id),
],
```

Add the import: `import 'package:flutter_application_1/features/portal/widgets/company_locations_section.dart';`
(The exact insertion point must keep the existing children list valid — read the surrounding `Column`/list structure first and slot these entries in as list items.)

- [ ] **Step 3: Verify in the running app.** `flutter analyze` clean, then hot-restart the running web session (or `flutter run -d chrome --web-port=61783 --dart-define-from-file=config/supabase.live.json`), log in as `ironhills.owner@mineralguide.com` / `MineralGuide123!`, open Profile → confirm the Locations card shows the seeded "Collection point (SPAR Kingfisher area)" row with a primary star; add a second named location via map picker; paste `https://maps.app.goo.gl/XcJEYHJFu15XyLY67` in the link field and confirm it resolves to `-26.028…, 28.001…`; set primary back; delete the extra row.

- [ ] **Step 4: Commit**

```bash
git add lib/features/portal/widgets/company_locations_section.dart lib/features/profile/screens/profile_screen.dart
git commit -m "feat(locations): Locations section on company profile (map picker + any-maps-link paste)"
```

---

### Task 5: OSRM routing — `NavRoute` model, polyline decoder, `RoutingService`

**Files:**
- Create: `lib/features/portal/models/nav_route.dart`
- Create: `lib/features/portal/services/routing_service.dart`
- Test: `test/features/portal/nav_route_test.dart`

**Interfaces:**
- Consumes: `package:http/http.dart`, `latlong2`.
- Produces: `NavManeuver` enum (`depart, turnLeft, turnRight, slightLeft, slightRight, sharpLeft, sharpRight, uturn, merge, onRamp, offRamp, fork, roundabout, exitRoundabout, continueStraight, newName, arrive, unknown`) with `NavManeuver.parse(String? type, String? modifier)` and `IconData get icon`; `NavStep {instruction, maneuver, roadName, distanceM, durationS, location(LatLng), exit(int?)}`; `NavRoute {points(List<LatLng>), distanceM, durationS, steps}`; `List<LatLng> decodePolyline5(String)`; `RoutingService.fetchRoute(LatLng from, LatLng to, {http.Client? client}) → Future<NavRoute?>` (null on any failure — caller degrades gracefully); `const kOsrmBaseUrl = String.fromEnvironment('OSRM_BASE_URL', defaultValue: 'https://router.project-osrm.org');`.

- [ ] **Step 1: Write failing tests** — polyline decode against the known reference vector, OSRM JSON parse, maneuver parse:

```dart
// test/features/portal/nav_route_test.dart
import 'dart:convert';
import 'package:flutter/material.dart' show Icons;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';

import 'package:flutter_application_1/features/portal/models/nav_route.dart';
import 'package:flutter_application_1/features/portal/services/routing_service.dart';

void main() {
  test('decodePolyline5 decodes the canonical Google example', () {
    // Reference vector from the polyline algorithm docs.
    final pts = decodePolyline5('_p~iF~ps|U_ulLnnqC_mqNvxq`@');
    expect(pts.length, 3);
    expect(pts[0].latitude, closeTo(38.5, 1e-5));
    expect(pts[0].longitude, closeTo(-120.2, 1e-5));
    expect(pts[2].latitude, closeTo(43.252, 1e-5));
    expect(pts[2].longitude, closeTo(-126.453, 1e-5));
  });

  test('NavManeuver.parse maps OSRM type/modifier and falls back to unknown', () {
    expect(NavManeuver.parse('turn', 'left'), NavManeuver.turnLeft);
    expect(NavManeuver.parse('turn', 'slight right'), NavManeuver.slightRight);
    expect(NavManeuver.parse('roundabout', null), NavManeuver.roundabout);
    expect(NavManeuver.parse('arrive', null), NavManeuver.arrive);
    expect(NavManeuver.parse('weird-new-osrm-type', null), NavManeuver.unknown);
    expect(NavManeuver.turnLeft.icon, Icons.turn_left_rounded);
  });

  test('RoutingService.fetchRoute parses an OSRM response', () async {
    final body = jsonEncode({
      'code': 'Ok',
      'routes': [
        {
          'geometry': '_p~iF~ps|U_ulLnnqC',
          'distance': 1234.5,
          'duration': 600.0,
          'legs': [
            {
              'steps': [
                {
                  'maneuver': {'type': 'depart', 'modifier': null, 'location': [-120.2, 38.5]},
                  'name': 'R59', 'distance': 1000.0, 'duration': 500.0,
                },
                {
                  'maneuver': {'type': 'arrive', 'modifier': null, 'location': [-120.95, 40.7]},
                  'name': '', 'distance': 0.0, 'duration': 0.0,
                },
              ],
            },
          ],
        },
      ],
    });
    final client = MockClient((req) async {
      expect(req.url.path, contains('/route/v1/driving/'));
      expect(req.url.queryParameters['steps'], 'true');
      return http.Response(body, 200);
    });
    final r = await RoutingService()
        .fetchRoute(const LatLng(38.5, -120.2), const LatLng(40.7, -120.95), client: client);
    expect(r, isNotNull);
    expect(r!.distanceM, closeTo(1234.5, 0.01));
    expect(r.steps.length, 2);
    expect(r.steps.first.maneuver, NavManeuver.depart);
    expect(r.steps.first.roadName, 'R59');
    expect(r.points.first.latitude, closeTo(38.5, 1e-5));
  });

  test('fetchRoute returns null on non-Ok / network error', () async {
    final bad = MockClient((_) async => http.Response('{"code":"NoRoute"}', 200));
    expect(await RoutingService().fetchRoute(
        const LatLng(0, 0), const LatLng(1, 1), client: bad), isNull);
    final err = MockClient((_) async => throw http.ClientException('down'));
    expect(await RoutingService().fetchRoute(
        const LatLng(0, 0), const LatLng(1, 1), client: err), isNull);
  });
}
```

- [ ] **Step 2: Run** `flutter test test/features/portal/nav_route_test.dart` — FAIL.

- [ ] **Step 3: Implement `nav_route.dart`**

```dart
// lib/features/portal/models/nav_route.dart
import 'package:flutter/material.dart' show IconData, Icons;
import 'package:latlong2/latlong.dart';

/// OSRM maneuver types/modifiers folded to a UI-friendly enum. Tolerant parse
/// per the repo's wire-enum rule — unknown wire values never crash the UI.
enum NavManeuver {
  depart, turnLeft, turnRight, slightLeft, slightRight, sharpLeft, sharpRight,
  uturn, merge, onRamp, offRamp, fork, roundabout, exitRoundabout,
  continueStraight, newName, arrive, unknown;

  static NavManeuver parse(String? type, String? modifier) {
    switch (type) {
      case 'depart': return NavManeuver.depart;
      case 'arrive': return NavManeuver.arrive;
      case 'merge': return NavManeuver.merge;
      case 'on ramp': return NavManeuver.onRamp;
      case 'off ramp': return NavManeuver.offRamp;
      case 'fork': return NavManeuver.fork;
      case 'roundabout': case 'rotary': return NavManeuver.roundabout;
      case 'exit roundabout': case 'exit rotary': return NavManeuver.exitRoundabout;
      case 'new name': return NavManeuver.newName;
      case 'continue': return _byModifier(modifier, NavManeuver.continueStraight);
      case 'turn': case 'end of road':
        return _byModifier(modifier, NavManeuver.continueStraight);
      default: return NavManeuver.unknown;
    }
  }

  static NavManeuver _byModifier(String? m, NavManeuver fallback) {
    switch (m) {
      case 'left': return NavManeuver.turnLeft;
      case 'right': return NavManeuver.turnRight;
      case 'slight left': return NavManeuver.slightLeft;
      case 'slight right': return NavManeuver.slightRight;
      case 'sharp left': return NavManeuver.sharpLeft;
      case 'sharp right': return NavManeuver.sharpRight;
      case 'uturn': return NavManeuver.uturn;
      case 'straight': return NavManeuver.continueStraight;
      default: return fallback;
    }
  }

  IconData get icon {
    switch (this) {
      case NavManeuver.depart: return Icons.navigation_rounded;
      case NavManeuver.turnLeft: return Icons.turn_left_rounded;
      case NavManeuver.turnRight: return Icons.turn_right_rounded;
      case NavManeuver.slightLeft: return Icons.turn_slight_left_rounded;
      case NavManeuver.slightRight: return Icons.turn_slight_right_rounded;
      case NavManeuver.sharpLeft: return Icons.turn_sharp_left_rounded;
      case NavManeuver.sharpRight: return Icons.turn_sharp_right_rounded;
      case NavManeuver.uturn: return Icons.u_turn_left_rounded;
      case NavManeuver.merge: return Icons.merge_rounded;
      case NavManeuver.onRamp: return Icons.ramp_right_rounded;
      case NavManeuver.offRamp: return Icons.exit_to_app_rounded;
      case NavManeuver.fork: return Icons.fork_right_rounded;
      case NavManeuver.roundabout: return Icons.roundabout_right_rounded;
      case NavManeuver.exitRoundabout: return Icons.roundabout_right_rounded;
      case NavManeuver.continueStraight: return Icons.straight_rounded;
      case NavManeuver.newName: return Icons.straight_rounded;
      case NavManeuver.arrive: return Icons.sports_score_rounded;
      case NavManeuver.unknown: return Icons.navigation_outlined;
    }
  }
}

class NavStep {
  final NavManeuver maneuver;
  final String roadName;
  final double distanceM; // step length
  final double durationS;
  final LatLng location;  // where the maneuver happens
  final int? exit;        // roundabout exit number

  const NavStep({
    required this.maneuver,
    required this.roadName,
    required this.distanceM,
    required this.durationS,
    required this.location,
    this.exit,
  });

  /// "Turn left onto R59" / "Take exit 2 at the roundabout" / "Arrive".
  String get instruction {
    final onto = roadName.isEmpty ? '' : ' onto $roadName';
    switch (maneuver) {
      case NavManeuver.depart: return 'Head out$onto';
      case NavManeuver.turnLeft: return 'Turn left$onto';
      case NavManeuver.turnRight: return 'Turn right$onto';
      case NavManeuver.slightLeft: return 'Keep slightly left$onto';
      case NavManeuver.slightRight: return 'Keep slightly right$onto';
      case NavManeuver.sharpLeft: return 'Sharp left$onto';
      case NavManeuver.sharpRight: return 'Sharp right$onto';
      case NavManeuver.uturn: return 'Make a U-turn$onto';
      case NavManeuver.merge: return 'Merge$onto';
      case NavManeuver.onRamp: return 'Take the ramp$onto';
      case NavManeuver.offRamp: return 'Take the exit$onto';
      case NavManeuver.fork: return 'Keep to the fork$onto';
      case NavManeuver.roundabout:
        return exit == null
            ? 'Enter the roundabout$onto'
            : 'At the roundabout, take exit $exit$onto';
      case NavManeuver.exitRoundabout: return 'Exit the roundabout$onto';
      case NavManeuver.continueStraight: return 'Continue straight$onto';
      case NavManeuver.newName: return 'Continue$onto';
      case NavManeuver.arrive: return 'You have arrived';
      case NavManeuver.unknown: return roadName.isEmpty ? 'Continue' : 'Continue$onto';
    }
  }

  factory NavStep.fromOsrm(Map<String, dynamic> json) {
    final m = (json['maneuver'] as Map?) ?? const {};
    final loc = (m['location'] as List?) ?? const [0.0, 0.0];
    return NavStep(
      maneuver: NavManeuver.parse(m['type'] as String?, m['modifier'] as String?),
      roadName: (json['name'] as String?) ?? '',
      distanceM: ((json['distance'] as num?) ?? 0).toDouble(),
      durationS: ((json['duration'] as num?) ?? 0).toDouble(),
      location: LatLng((loc[1] as num).toDouble(), (loc[0] as num).toDouble()),
      exit: (m['exit'] as num?)?.toInt(),
    );
  }
}

class NavRoute {
  final List<LatLng> points;
  final double distanceM;
  final double durationS;
  final List<NavStep> steps;

  const NavRoute({
    required this.points,
    required this.distanceM,
    required this.durationS,
    required this.steps,
  });
}

/// Decodes a precision-5 encoded polyline (OSRM default geometry encoding).
List<LatLng> decodePolyline5(String encoded) {
  final points = <LatLng>[];
  var index = 0, lat = 0, lng = 0;
  while (index < encoded.length) {
    for (final isLng in const [false, true]) {
      var shift = 0, result = 0, b = 0x20;
      while (b >= 0x20) {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      }
      final delta = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      if (isLng) { lng += delta; } else { lat += delta; }
    }
    points.add(LatLng(lat / 1e5, lng / 1e5));
  }
  return points;
}
```

- [ ] **Step 4: Implement `routing_service.dart`**

```dart
// lib/features/portal/services/routing_service.dart
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import 'package:flutter_application_1/core/utils/logger.dart';
import 'package:flutter_application_1/features/portal/models/nav_route.dart';

/// Free, key-less OSRM routing (spec §1). Overridable so a self-hosted OSRM
/// (or compatible service) can replace the public demo server without a
/// code change: --dart-define=OSRM_BASE_URL=...
const kOsrmBaseUrl =
    String.fromEnvironment('OSRM_BASE_URL', defaultValue: 'https://router.project-osrm.org');

class RoutingService {
  static final _log = LoggerFactory.getLogger('RoutingService');

  /// Driving route with turn-by-turn steps. Returns null on ANY failure —
  /// the nav screen then degrades to bearing/distance mode.
  Future<NavRoute?> fetchRoute(LatLng from, LatLng to, {http.Client? client}) async {
    final url = Uri.parse(
        '$kOsrmBaseUrl/route/v1/driving/'
        '${from.longitude},${from.latitude};${to.longitude},${to.latitude}'
        '?overview=full&geometries=polyline&steps=true&alternatives=false');
    final c = client ?? http.Client();
    try {
      final res = await c.get(url).timeout(const Duration(seconds: 12));
      if (res.statusCode != 200) {
        _log.warning('OSRM HTTP ${res.statusCode}');
        return null;
      }
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      if (json['code'] != 'Ok') {
        _log.warning('OSRM code ${json['code']}');
        return null;
      }
      final route = (json['routes'] as List).first as Map<String, dynamic>;
      final legs = (route['legs'] as List?) ?? const [];
      final steps = <NavStep>[
        for (final leg in legs)
          for (final s in ((leg as Map)['steps'] as List? ?? const []))
            NavStep.fromOsrm(Map<String, dynamic>.from(s as Map)),
      ];
      return NavRoute(
        points: decodePolyline5(route['geometry'] as String),
        distanceM: ((route['distance'] as num?) ?? 0).toDouble(),
        durationS: ((route['duration'] as num?) ?? 0).toDouble(),
        steps: steps,
      );
    } catch (e) {
      _log.warning('OSRM route failed: $e');
      return null;
    } finally {
      if (client == null) c.close();
    }
  }
}
```

- [ ] **Step 5: Run tests** `flutter test test/features/portal/nav_route_test.dart` — PASS. Also do a one-off REAL server smoke (not a committed test): `curl "https://router.project-osrm.org/route/v1/driving/28.0019869,-26.0285039;28.05,-26.10?overview=false&steps=true"` → expect `"code":"Ok"`.

- [ ] **Step 6: Commit**

```bash
git add lib/features/portal/models/nav_route.dart lib/features/portal/services/routing_service.dart test/features/portal/nav_route_test.dart
git commit -m "feat(nav): OSRM routing service, NavRoute/NavStep/NavManeuver, polyline decoder"
```

---

### Task 6: Pure nav-session math (`nav_math.dart`)

**Files:**
- Create: `lib/features/portal/utils/nav_math.dart`
- Test: `test/features/portal/nav_math_test.dart`

**Interfaces:**
- Consumes: `latlong2` (`Distance()` haversine).
- Produces (all pure — no GPS, no clock):
  - `({int segIndex, LatLng snapped, double offRouteM, double traveledM}) projectOnRoute(List<LatLng> route, LatLng pos)` — nearest point on the polyline, perpendicular distance, cumulative metres from route start.
  - `int currentStepIndex(List<NavStep> steps, List<LatLng> route, double traveledM, List<double> stepStartM)` plus helper `List<double> stepStartOffsets(List<LatLng> route, List<NavStep> steps)` (metres-from-start of each step's maneuver point, monotone).
  - `double remainingMeters(double totalM, double traveledM)`.
  - `bool isOffRoute(double offRouteM) => offRouteM > 50`.
  - `bool hasArrived(LatLng pos, LatLng dest) => const Distance().as(LengthUnit.Meter, pos, dest) < 150`.

- [ ] **Step 1: Write failing tests** — a straight 3-point route (0,0)→(0,0.01)→(0.01,0.01) (~1.11 km per 0.01° at the equator):

```dart
// test/features/portal/nav_math_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'package:flutter_application_1/features/portal/utils/nav_math.dart';

void main() {
  const route = [LatLng(0, 0), LatLng(0, 0.01), LatLng(0.01, 0.01)];

  test('projectOnRoute snaps onto the first segment and measures progress', () {
    final r = projectOnRoute(route, const LatLng(0.0001, 0.005)); // ~11m north of mid-seg-1
    expect(r.segIndex, 0);
    expect(r.offRouteM, closeTo(11.1, 2.0));
    expect(r.traveledM, closeTo(556.0, 15.0)); // half of ~1113m
    expect(r.snapped.latitude, closeTo(0, 1e-6));
  });

  test('projectOnRoute clamps to vertices at the ends', () {
    final before = projectOnRoute(route, const LatLng(0, -0.01));
    expect(before.traveledM, closeTo(0, 1.0));
    final after = projectOnRoute(route, const LatLng(0.02, 0.01));
    expect(after.traveledM, closeTo(2226.0, 30.0)); // full length
  });

  test('off-route / arrival thresholds', () {
    expect(isOffRoute(49), isFalse);
    expect(isOffRoute(51), isTrue);
    expect(hasArrived(const LatLng(0, 0), const LatLng(0, 0.001)), isTrue); // ~111m
    expect(hasArrived(const LatLng(0, 0), const LatLng(0, 0.002)), isFalse); // ~222m
  });
}
```

(Also add a `currentStepIndex` test once implementing — two fake steps with maneuvers at route[0] and route[1]; traveled 556m → step 0 active; traveled 1200m → step 1 active.)

- [ ] **Step 2: Run** — FAIL. **Step 3: Implement:**

```dart
// lib/features/portal/utils/nav_math.dart
import 'package:latlong2/latlong.dart';

import 'package:flutter_application_1/features/portal/models/nav_route.dart';

const _d = Distance();

/// Nearest point on [route] to [pos]: segment index, snapped point,
/// perpendicular distance (m) and cumulative distance from the route start
/// to the snapped point (m). Equirectangular projection per segment — fine
/// at truck-route scale.
({int segIndex, LatLng snapped, double offRouteM, double traveledM})
    projectOnRoute(List<LatLng> route, LatLng pos) {
  assert(route.length >= 2);
  var bestSeg = 0;
  var bestSnap = route.first;
  var bestDist = double.infinity;
  var bestTraveled = 0.0;
  var cumul = 0.0;
  for (var i = 0; i < route.length - 1; i++) {
    final a = route[i], b = route[i + 1];
    final t = _projT(a, b, pos);
    final snap = LatLng(
      a.latitude + (b.latitude - a.latitude) * t,
      a.longitude + (b.longitude - a.longitude) * t,
    );
    final dist = _d.as(LengthUnit.Meter, pos, snap);
    if (dist < bestDist) {
      bestDist = dist;
      bestSeg = i;
      bestSnap = snap;
      bestTraveled = cumul + _d.as(LengthUnit.Meter, a, snap);
    }
    cumul += _d.as(LengthUnit.Meter, a, b);
  }
  return (segIndex: bestSeg, snapped: bestSnap, offRouteM: bestDist, traveledM: bestTraveled);
}

double _projT(LatLng a, LatLng b, LatLng p) {
  final ax = a.longitude, ay = a.latitude;
  final dx = b.longitude - ax, dy = b.latitude - ay;
  final len2 = dx * dx + dy * dy;
  if (len2 == 0) return 0;
  final t = ((p.longitude - ax) * dx + (p.latitude - ay) * dy) / len2;
  return t.clamp(0.0, 1.0);
}

/// Metres-from-route-start of each step's maneuver point (monotone,
/// clamped). Precompute once per fetched route.
List<double> stepStartOffsets(List<LatLng> route, List<NavStep> steps) {
  final out = <double>[];
  var last = 0.0;
  for (final s in steps) {
    final p = projectOnRoute(route, s.location);
    last = p.traveledM < last ? last : p.traveledM;
    out.add(last);
  }
  return out;
}

/// The step whose maneuver the driver is approaching: the first step whose
/// start offset is still ahead of [traveledM] (with 25m of slack so the
/// banner flips right as the truck passes the maneuver).
int currentStepIndex(List<double> stepStartM, double traveledM) {
  for (var i = 0; i < stepStartM.length; i++) {
    if (stepStartM[i] > traveledM + 25) return i;
  }
  return stepStartM.isEmpty ? 0 : stepStartM.length - 1;
}

double remainingMeters(double totalM, double traveledM) =>
    (totalM - traveledM).clamp(0.0, double.infinity);

bool isOffRoute(double offRouteM) => offRouteM > 50;

bool hasArrived(LatLng pos, LatLng dest) =>
    _d.as(LengthUnit.Meter, pos, dest) < 150;
```

- [ ] **Step 4: Run tests** — PASS (tune the `closeTo` deltas only if the haversine constants differ slightly; never loosen beyond ±5%).

- [ ] **Step 5: Commit**

```bash
git add lib/features/portal/utils/nav_math.dart test/features/portal/nav_math_test.dart
git commit -m "feat(nav): pure route-projection/step-advance/off-route/arrival math"
```

---

### Task 7: Voice guidance (`flutter_tts` + announcement gating)

**Files:**
- Modify: `pubspec.yaml` (add `flutter_tts: ^4.2.0` under the geolocator entry, with a comment)
- Create: `lib/features/portal/services/navigation_voice.dart`
- Test: `test/features/portal/navigation_voice_test.dart`

**Interfaces:**
- Consumes: `NavStep.instruction` (Task 5).
- Produces: `NavVoice` — `NavVoice({Future<void> Function(String text)? speak})` (injectable for tests; defaults to a lazily-created `FlutterTts` instance with `setLanguage('en-ZA')` fallback `en-US`); `bool muted` (settable); `void onProgress({required int stepIndex, required double metersToManeuver, required String instruction})` — announces each step at most once per gate: far ≈1000 m ("In 1 kilometer, …"), near ≈300 m ("In 300 meters, …"), now ≤60 m (instruction alone); `void announceRerouting()`, `void announceArrived()`, `void reset()` (new route → clear gate memory).

- [ ] **Step 1: Failing test** (inject a recording `speak`):

```dart
// test/features/portal/navigation_voice_test.dart
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/features/portal/services/navigation_voice.dart';

void main() {
  test('announces each gate once, in order, and never when muted', () {
    final spoken = <String>[];
    final v = NavVoice(speak: (t) async => spoken.add(t));

    // Approach: 1200 → 900 → 800 → 250 → 40 metres.
    for (final m in [1200.0, 900.0, 800.0, 250.0, 40.0]) {
      v.onProgress(stepIndex: 1, metersToManeuver: m, instruction: 'Turn left onto R59');
    }
    expect(spoken, [
      'In 1 kilometer, turn left onto R59',
      'In 300 meters, turn left onto R59',
      'Turn left onto R59',
    ]);

    spoken.clear();
    v.muted = true;
    v.onProgress(stepIndex: 2, metersToManeuver: 100, instruction: 'Turn right');
    expect(spoken, isEmpty);

    v.muted = false;
    v.reset();
    v.onProgress(stepIndex: 1, metersToManeuver: 900, instruction: 'Turn left onto R59');
    expect(spoken, ['In 1 kilometer, turn left onto R59']); // gates re-armed after reset
  });
}
```

- [ ] **Step 2: Run** — FAIL. **Step 3: Implement:**

```dart
// lib/features/portal/services/navigation_voice.dart
import 'package:flutter_tts/flutter_tts.dart';

import 'package:flutter_application_1/core/utils/logger.dart';

/// Spoken turn-by-turn guidance (spec §4). Distance gates per step:
/// far (≤1000 m), near (≤300 m), now (≤60 m) — each spoken at most once.
class NavVoice {
  static final _log = LoggerFactory.getLogger('NavVoice');

  final Future<void> Function(String text) _speak;
  bool muted = false;

  // gate memory: stepIndex -> highest gate already announced (0 none, 1 far,
  // 2 near, 3 now).
  final _announced = <int, int>{};

  NavVoice({Future<void> Function(String text)? speak})
      : _speak = speak ?? _defaultSpeak;

  static FlutterTts? _tts;
  static Future<void> _defaultSpeak(String text) async {
    try {
      final tts = _tts ??= await _init();
      await tts.speak(text);
    } catch (e) {
      _log.warning('TTS unavailable: $e'); // voice is best-effort, never fatal
    }
  }

  static Future<FlutterTts> _init() async {
    final tts = FlutterTts();
    try {
      await tts.setLanguage('en-ZA');
    } catch (_) {
      await tts.setLanguage('en-US');
    }
    await tts.setSpeechRate(0.5);
    return tts;
  }

  void onProgress({
    required int stepIndex,
    required double metersToManeuver,
    required String instruction,
  }) {
    if (muted) return;
    final gate = metersToManeuver <= 60
        ? 3
        : metersToManeuver <= 300
            ? 2
            : metersToManeuver <= 1000
                ? 1
                : 0;
    if (gate == 0) return;
    final already = _announced[stepIndex] ?? 0;
    if (gate <= already) return;
    _announced[stepIndex] = gate;
    final text = switch (gate) {
      1 => 'In 1 kilometer, ${_lc(instruction)}',
      2 => 'In 300 meters, ${_lc(instruction)}',
      _ => instruction,
    };
    _speak(text);
  }

  void announceRerouting() {
    if (!muted) _speak('Rerouting');
  }

  void announceArrived() {
    if (!muted) _speak('You have arrived at your destination');
  }

  /// New route fetched — re-arm all gates.
  void reset() => _announced.clear();

  static String _lc(String s) => s.isEmpty ? s : s[0].toLowerCase() + s.substring(1);
}
```

Add to `pubspec.yaml` dependencies (after `geolocator`):

```yaml
  # In-app turn-by-turn voice guidance for driver navigation (free, on-device).
  flutter_tts: ^4.2.0
```

- [ ] **Step 4: Run** `flutter pub get` then the test — PASS. `flutter analyze` clean.

- [ ] **Step 5: Commit**

```bash
git add pubspec.yaml pubspec.lock lib/features/portal/services/navigation_voice.dart test/features/portal/navigation_voice_test.dart
git commit -m "feat(nav): voice guidance with distance-gated announcements (flutter_tts)"
```

---

### Task 8: `DriverNavigationScreen` + router wiring + Navigate entry points

**Files:**
- Create: `lib/features/portal/screens/driver_navigation_screen.dart`
- Modify: `lib/core/routing/app_router.dart` (add top-level route `/portal/driver/navigate/:tripId` OUTSIDE the portal ShellRoute, like `/operations`)
- Modify: `lib/features/portal/screens/driver_routes_screen.dart` (add "Navigate" primary action next to the existing "Directions"; keep Directions)

**Interfaces:**
- Consumes: `CompanyLocationService.tripNavDestination` (Task 3), `RoutingService.fetchRoute` (Task 5), nav_math (Task 6), `NavVoice` (Task 7), `geolocator` position stream, `lifecycleServiceProvider.setTripStatus`, `TripStatus`.
- Produces: `DriverNavigationScreen({required String tripId, super.key})` route `/portal/driver/navigate/:tripId`. Task 9's dashboard hero links here too.

- [ ] **Step 1: Implement the screen.** Structure (single file, ~5 private widgets). Key mechanics — implement exactly:
  - **State:** `_destination (NavDestination?)`, `_route (NavRoute?)`, `_stepStartM (List<double>)`, `_pos (LatLng?)`, `_heading (double)`, `_speedKmh (double)`, `_traveledM`, `_stepIx`, `_offRouteSince (DateTime?)`, `_rerouting (bool)`, `_arrived (bool)`, `_followCamera (bool = true)`, `_voice (NavVoice)`, `_muted` mirrors `_voice.muted`.
  - **Init:** load trip via `logisticsSnapshotProvider`-independent path: call `companyLocationServiceProvider.tripNavDestination(tripId, offloadLeg: statusStep >= TripStatus.loaded.step)` — obtain trip status by reading the snapshot for `resolvePortalCompanyId(ref)` and matching `tripId` (fall back to `offloadLeg:false` if the trip is not found). If `destination.point == null && destination.address != null` → geocode ONCE via Nominatim (same debounced pattern/URL as `location_picker.dart` `_runSearch` — copy the request shape incl. the `User-Agent` header if one is set there); still null → render the "no destination" empty state with an "Ask the mine to set their collection point" message + `MlButton.outline('Open in external maps')` using the address, and a Close button.
  - **GPS:** `Geolocator.getPositionStream(locationSettings: const LocationSettings(accuracy: LocationAccuracy.bestForNavigation, distanceFilter: 3))` — subscribe in `initState` (after a permission check exactly like `trip_position_reporter.dart` does — read that file and reuse its permission-request flow); update `_pos/_heading/_speedKmh`; cancel in `dispose`. Handle `LocationServiceDisabledException`/denied with an inline `MlEmptyState` + "Open settings" (`Geolocator.openAppSettings()`).
  - **First fix + destination →** `RoutingService().fetchRoute(pos, dest)`; success → set `_route`, `_stepStartM = stepStartOffsets(route.points, route.steps)`, `_voice.reset()`. Failure → bearing/distance degraded mode (map + destination pin + straight `Polyline([pos, dest])` dashed + distance readout + "Open in external maps" button; retry button re-calls fetchRoute).
  - **Every position event with a route:** `final p = projectOnRoute(_route!.points, _pos!)`; `_traveledM = p.traveledM`; `_stepIx = currentStepIndex(_stepStartM, _traveledM)`; meters to maneuver = `_stepStartM[_stepIx] - _traveledM`; `_voice.onProgress(stepIndex: _stepIx, metersToManeuver: mtm, instruction: _route!.steps[_stepIx].instruction)`. Off-route: `isOffRoute(p.offRouteM)` → start/extend `_offRouteSince`; if > 5 s and not `_rerouting` → `_voice.announceRerouting()`, re-fetch route from current pos, on success replace `_route/_stepStartM`, `_voice.reset()`. On-route again → clear `_offRouteSince`. Arrival: `hasArrived(_pos!, destPoint)` once → `_arrived = true`, `_voice.announceArrived()`.
  - **Map:** `FlutterMap` with `MapController`; on each fix when `_followCamera` → `_mapController.moveAndRotate(_pos!, _zoomForSpeed(_speedKmh), -_heading)` (`_zoomForSpeed`: ≥80 km/h → 14, ≥40 → 15.5, else 17). OSM tile layer copied verbatim from `live_trip_map_view.dart`'s tile layer (same urlTemplate + userAgentPackageName). `PolylineLayer` route line: width 7, `MlTokens.accent`, with a wider navy underlay (`Color(0xFF0B2545)`, width 11 — part of the approved hero-gradient exception). `MarkerLayer`: destination pin (`Icons.location_on_rounded`, `MlTone.error` fg colour, 40) + truck marker (`Icons.navigation_rounded` rotated by `_heading` when following is off; when following, the map rotates instead so the icon stays screen-up). Manual pan (`onPositionChanged` with `hasGesture`) → `_followCamera = false`; floating "Re-center" `FloatingActionButton.small` when not following.
  - **Instruction banner (top, SafeArea):** dark navy card (`Color(0xFF0B2545)` — approved exception), maneuver icon 34 white, "In 400 m" (mono, `_fmtMeters`: <1000 → "In X m" rounded to 10s, else "In X.X km"), instruction text white w700, secondary line "then ⟶ <next step short instruction>" white70 when a next step exists. While `_rerouting` show "Rerouting…" instead.
  - **Bottom bar:** `MlCard` row — ETA clock (`DateTime.now().add(Duration(seconds: remaining duration estimate))`, где remaining duration = `_route.durationS * (remainingMeters/_route.distanceM)` — simple proportional), minutes remaining, `_fmtMeters(remainingMeters(_route.distanceM, _traveledM))`, speed `${_speedKmh.round()} km/h`; mute `IconButton` (`Icons.volume_up_rounded`/`volume_off_rounded`); `MlButton.danger(label: 'End', ...)` → `context.pop()`.
  - **Arrival overlay:** when `_arrived` — banner card: load leg → `MlButton.go('Mark arrived at mine')` → `lifecycleServiceProvider.setTripStatus(tripId, TripStatus.arrivedAtMine)` then pop with a snackbar; offload leg → `MlButton.go('Back to trip — upload POD')` → pop (POD dialog lives on the Trip screen; do not duplicate it). Never auto-fire.
  - **Degraded/edge states** all render inside the same Scaffold: permission denied, no destination, OSRM down. The screen must never throw for a missing anything.
- [ ] **Step 2: Router.** In `app_router.dart`, add alongside other top-level GoRoutes (NOT inside the portal ShellRoute — full-screen chrome-less):

```dart
GoRoute(
  path: '/portal/driver/navigate/:tripId',
  builder: (context, state) => DriverNavigationScreen(
    tripId: state.pathParameters['tripId'] ?? '',
  ),
),
```

with import `package:flutter_application_1/features/portal/screens/driver_navigation_screen.dart`.

- [ ] **Step 3: Entry point on the Trip screen.** In `driver_routes_screen.dart` `_CurrentTripCard` invocation (line ~94), the card exposes action callbacks; add `onNavigate: current == null ? null : () => context.push('/portal/driver/navigate/${current.id}')` — thread a new `VoidCallback? onNavigate` parameter through `_CurrentTripCard` and render it as the FIRST action: `MlButton.go(label: 'Navigate', icon: Icons.navigation_rounded, onPressed: onNavigate)` before the existing buttons; keep the existing "Directions" (external) button unchanged. `import 'package:go_router/go_router.dart';` if absent.

- [ ] **Step 4: Verify.** `flutter analyze` clean; `flutter test` green. Run the app (web), log in as a driver (find one via `active user accounts.txt` at repo root — a Roadhaul driver account; if none works ask the user), open Trip tab → Navigate on the active trip → confirm: OSRM route line draws from the simulated/browser location to the destination (browser geolocation prompt → allow), banner shows a real instruction, bottom bar shows ETA/km. Web has no reliable heading — confirm graceful behaviour (heading 0). Voice on web: Chrome speaks via Web Speech; mute toggle works.

- [ ] **Step 5: Commit**

```bash
git add lib/features/portal/screens/driver_navigation_screen.dart lib/core/routing/app_router.dart lib/features/portal/screens/driver_routes_screen.dart
git commit -m "feat(nav): in-app turn-by-turn DriverNavigationScreen with voice, reroute, arrival actions"
```

---

### Task 9: Driver 3-tab shell (Dashboard · Trip · Profile), real data, zero feature loss

**Files:**
- Create: `lib/features/portal/widgets/driver_live_tracking_card.dart` (extract `_LiveTrackingCard` from `driver_routes_screen.dart:664` → public `DriverLiveTrackingCard`, same body; `driver_routes_screen.dart` switches to importing it — additive-safe refactor)
- Create: `lib/features/portal/screens/driver_app_screen.dart` (adapted from `C:\Users\Somebody Someone\Downloads\Mobile driver app update\flutter_export\driver_app_screen.dart`)
- Modify: `lib/features/portal/widgets/portal_shell_layout.dart` (driver swap on `/home`)

**Interfaces:**
- Consumes: everything listed in "Verified codebase facts"; `DriverLiveTrackingCard({required bool hasActiveTrip})`; screens for quick-links: `LiveTripMapScreen`, `TransporterTruckLocationsScreen`, `TransporterTruckPositionsScreen`, `DriverTabScreen`, `ProfileScreen` (import paths per `portal_navigation.dart`'s imports).
- Produces: `DriverAppScreen` — self-contained Scaffold with `NavigationBar`; `_tab = 0` (Dashboard is the landing page per spec).

- [ ] **Step 1: Extract the live-tracking card.** Move the `_LiveTrackingCard` class body verbatim from `driver_routes_screen.dart` into `driver_live_tracking_card.dart`, rename to `DriverLiveTrackingCard`, make constructor `const DriverLiveTrackingCard({required this.hasActiveTrip, super.key})`; keep ALL imports it needs (`tripPositionReporterProvider` etc.). In `driver_routes_screen.dart` delete the private class and replace its two usages (`_LiveTrackingCard(hasActiveTrip: ...)` → `DriverLiveTrackingCard(hasActiveTrip: ...)`) + add the import. Run `flutter analyze` — clean. Commit: `git commit -am "refactor(driver): extract DriverLiveTrackingCard for reuse by the driver shell"`.

- [ ] **Step 2: Build `DriverAppScreen`.** Start from the export file's structure (bottom `NavigationBar`, 3 destinations, `_DashboardHeader`, `_ActiveTripHero`, `_MiniStat`, `_WeekChartCard`, `_ProfileRow` — copy those widget classes as-is, they're already tokenized), then wire real data:
  - `_tab = 0` initial (Dashboard lands first — spec).
  - **Trip tab** = `const DriverRoutesScreen()` unchanged.
  - **DriverDashboardTab** (ConsumerWidget): same data pipeline as `DriverRoutesScreen.build` (companyId → employee → fleet/assignments → `myVehicle` via the same `driver_assignments`-first matching — copy the `_assignedVehicle` helper — → `logisticsSnapshotProvider` trips filtered to `myVehicle.id`, `transporterDispatchesProvider` for request lookups):
    - Header: title 'Dashboard', subtitle `'${employee?.fullName ?? 'Driver'} — your week at a glance'`; bell = replace the mock `Stack` bell with `const AnimatedNotificationBell()`.
    - `_ActiveTripHero`: real `plate` (`myVehicle?.vehicleRegistrationNumber ?? trip.truckReg ?? '—'`), `route` (`request?.routeLabel ?? '${request?.loadingPoint ?? '?'} → ${request?.offloadingPoint ?? '?'}'`), `statusLabel` = `TripStatus.parse(trip.status).label.toUpperCase()`; tap → switch to Trip tab (pass `onOpenTrip` callback from the shell state); add a white `MlButton`-style "Navigate" `FilledButton.icon` inside the hero when there's an active trip → `context.push('/portal/driver/navigate/${trip.id}')`. No active trip → keep the hero but with 'NO ACTIVE TRIP' status pill and route '—' (never hide — parity with the mock's always-present hero is NOT required; an `MlEmptyState`-style card is acceptable if cleaner, but the hero with placeholder text is simpler).
    - Stat tiles (2×2 `_MiniStat`s): **Loads this week** = trips with `netTons != null` and `updatedAt` within the current ISO week (Mon–Sun, compute `now.subtract(Duration(days: now.weekday - 1))` date-floored); **Tons this week** = sum of those trips' `netTons`, `formatTons`; **Deliveries** = all-time completed count; **Total tons** = all-time `netTons` sum, `formatTons`. (Spec: "On-time %" dropped — no honest data.)
    - `DriverLiveTrackingCard(hasActiveTrip: active.isNotEmpty)`.
    - **Quick links** (parity table): a `MlCard` with four `_ProfileRow`-style rows — 'Live map' → push `LiveTripMapScreen`, 'Truck locations' → push `TransporterTruckLocationsScreen`, 'Truck positions' → push `TransporterTruckPositionsScreen`, 'My workspace' → push `DriverTabScreen`; each pushed wrapped: `Navigator.of(context).push(MaterialPageRoute(builder: (_) => Scaffold(appBar: AppBar(title: Text(label)), body: SafeArea(child: screen))))`.
    - `_WeekChartCard`: real data — completed trips this week grouped by weekday (`netTons` sums), `_max` = data max (min 1.0), highlight = today's weekday index; header right shows `formatTons(weekTotal)` and the ▲/▼ delta vs the previous week (compute both sums; if previous week is 0 show just the total, no fake delta).
  - **DriverProfileTab** (ConsumerWidget): avatar initials from `employee.fullName`; name; `'Driver · ${employeeState.company?.companyName ?? ''}'`; `MlPlatePill(myVehicle?.vehicleRegistrationNumber ?? '—')`; rows: 'My signature' → push a Scaffold-wrapped `ProfileSignatureCard` page, 'Trip history' (value `'${completedCount} completed trips'`) → push a Scaffold-wrapped list reusing `_RecentTripsCard`-equivalent (simplest: push the Trip tab's screen? NO — push a minimal `ListView` of completed trips: date · route label · `formatTons(netTons)`), 'Notifications' → `context.go('/notifications')`, 'Full profile' → `context.go('/profile')` (nothing orphaned). 'Language' row omitted (spec: YAGNI). Sign out: `MlButton.danger(label: 'Sign out', icon: Icons.logout, expand: true, onPressed: () => LogoutService.logoutWithConfirmation(context, ref))`.

- [ ] **Step 3: Shell swap.** In `portal_shell_layout.dart` `build()` immediately after the `vm.phase` switch (after line ~229, before `final tabs = vm.tabs!`):

```dart
// Drivers get the mobile-first 3-tab shell (Dashboard · Trip · Profile,
// spec 2026-07-16 §5) instead of the sidebar chrome — on /home only, so
// pushed routes (/profile, /notifications, /chat/...) keep normal chrome.
if (GoRouterState.of(context).uri.path == '/home' &&
    authState.userType?.isEmployee == true &&
    employeeState.employee?.role == UserRole.driver) {
  return const DriverAppScreen();
}
```

Add imports (`driver_app_screen.dart`, `UserRole` if not already imported). The driver's sidebar tab list in `portal_navigation.dart` stays untouched (defensive: nothing else breaks if the flag path is missed).

- [ ] **Step 4: Verify.** `flutter analyze` clean; `flutter test` green. Run the app; driver login → lands on Dashboard tab (bottom nav, hero, real stats matching the Trip tab's numbers); Trip tab identical to the old My-routes screen incl. POD/waybill actions; every quick-link opens; Profile tab rows all navigate; sign out works; a non-driver login (Ironhills owner) still gets the normal sidebar portal untouched.

- [ ] **Step 5: Commit**

```bash
git add lib/features/portal/screens/driver_app_screen.dart lib/features/portal/widgets/driver_live_tracking_card.dart lib/features/portal/widgets/portal_shell_layout.dart lib/features/portal/screens/driver_routes_screen.dart
git commit -m "feat(driver): 3-tab mobile shell (Dashboard/Trip/Profile) with real data, all legacy screens reachable"
```

---

### Task 10: Full verification, docs, memory

**Files:**
- Modify: `CLAUDE.md` (§4 status table)
- Modify: memory `premium-overview-screen.md`/`outstanding-work.md` as appropriate; add a memory for this feature set

- [ ] **Step 1:** `flutter analyze` (must be clean) and `flutter test` (all green) at the repo root.
- [ ] **Step 2:** End-to-end drive (use the `verify` skill): web app, driver account, full loop — Dashboard → Navigate → route draws → End → Trip tab actions intact; Ironhills profile → Locations CRUD; RLS negative check (buyer sees no Ironhills locations).
- [ ] **Step 3:** Update `CLAUDE.md` §4: add a row `In-app driver navigation (turn-by-turn + voice) + company locations` — mark 🟡 Partial with the honest note that server+app logic is verified but on-device GPS-follow/voice/permission prompts need a physical phone (mirror the Live-GPS row's precedent). Driver 3-tab shell noted under the same row or the app-shell row. Do NOT mark 🟢.
- [ ] **Step 4:** Write memory file `driver-nav-and-locations.md` (type: project): what was built, OSRM base URL override, Ironhills location id, the dead-token gotcha (Management API token now lives in `USER_CUSTOM_RULES_AND_TOOLS.txt` line 218), and update `MEMORY.md` index.
- [ ] **Step 5: Commit**

```bash
git add CLAUDE.md
git commit -m "docs: status-table update for driver nav, company locations, driver shell"
```

---

## Self-review results

- **Spec coverage:** §1 OSRM+config (T5), degradation (T5/T8); §2 table/RLS/RPC/resolution chain (T2), models/service (T3); §3 profile section + short links + Ironhills (T1/T2/T4); §4 nav screen mechanics/voice/reroute/arrival/entry points (T7/T8); §5 shell + parity table + real data + Dashboard-first (T9); §6 tests (T1/T3/T5/T6/T7), live verify (T2/T4/T8/T9/T10), analyze (every task). Out-of-scope items respected.
- **Type consistency:** `NavDestination` produced in T3 consumed in T8; `NavRoute/NavStep/stepStartOffsets/currentStepIndex` names match T5→T6→T8; `DriverLiveTrackingCard` name matches T9 steps 1–2; `resolveMapsLink`/`googleMapsLink` match T1→T4.
- **Known judgement points for the implementer:** exact insertion syntax in `profile_screen.dart` (read surrounding widget list first); `MlSemantic`/`MlTone` accessor names verified against export usage but re-check on first analyze; driver test account discovery in T8 step 4.
