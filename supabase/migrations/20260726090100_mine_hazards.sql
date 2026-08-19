-- ============================================================================
-- Mine hazards + nearby-hazard radius query (no PostGIS).
-- Ported/adapted from ML/supabase/migrations/000015_mine_hazards.sql
--
-- Adaptations from the ML donor schema to WT-live:
--   * ML stored a PostGIS geography(Point,4326) column and used ST_DWithin.
--     PostGIS is NOT installed on this project, and is unnecessary for the use
--     case (list hazards within a radius so Valhalla can avoid them). Hazards
--     therefore store plain latitude/longitude (double precision) and
--     get_nearby_hazards uses a bounding-box pre-filter + haversine distance.
--     => When porting ML hazard_service.dart, insert latitude/longitude
--        (NOT EWKT geom). Flagged for the Dart port phase.
--   * ML super-admin checks (profiles.is_super_admin) -> public.is_platform_admin().
--   * SERIAL integer PK kept (ML's Dart HazardService.clearHazard uses the int id).
-- ============================================================================

create table if not exists public.mine_hazards (
  id          serial primary key,
  hazard_type varchar(50) not null,                    -- blasting, pothole, slow_haulage, road_closure
  severity    varchar(20) not null default 'medium',   -- low, medium, critical
  description text not null default '',
  latitude    double precision not null,
  longitude   double precision not null,
  reported_at timestamptz not null default now(),
  expires_at  timestamptz
);

comment on table public.mine_hazards
  is 'Hazards (blasting zones, potholes, road closures) near mine haul roads; consumed as Valhalla avoid-points and as driver alerts.';
comment on column public.mine_hazards.hazard_type is 'Category: blasting, pothole, slow_haulage, road_closure';
comment on column public.mine_hazards.severity is 'Priority: low, medium, critical';
comment on column public.mine_hazards.expires_at is 'When this hazard auto-expires. NULL = persists until cleared.';

create index if not exists idx_mine_hazards_lat_lng on public.mine_hazards (latitude, longitude);
create index if not exists idx_mine_hazards_type on public.mine_hazards (hazard_type);
create index if not exists idx_mine_hazards_expires
  on public.mine_hazards (expires_at) where expires_at is not null;

-- ── RLS: hazards are shared safety data — any authenticated user reads and may
-- report; only the platform admin edits/clears. ─────────────────────────────
alter table public.mine_hazards enable row level security;

drop policy if exists mine_hazards_select_all on public.mine_hazards;
create policy mine_hazards_select_all on public.mine_hazards
for select to authenticated using (true);

drop policy if exists mine_hazards_insert_all on public.mine_hazards;
create policy mine_hazards_insert_all on public.mine_hazards
for insert to authenticated with check (true);

drop policy if exists mine_hazards_update_admin on public.mine_hazards;
create policy mine_hazards_update_admin on public.mine_hazards
for update to authenticated
using (public.is_platform_admin()) with check (public.is_platform_admin());

drop policy if exists mine_hazards_delete_admin on public.mine_hazards;
create policy mine_hazards_delete_admin on public.mine_hazards
for delete to authenticated using (public.is_platform_admin());

grant select, insert, update, delete on public.mine_hazards to authenticated;
grant usage, select on sequence public.mine_hazards_id_seq to authenticated;

-- ── RPC: get_nearby_hazards(lat, lng, radius_meters) ─────────────────────────
-- Bounding-box pre-filter (degree approximation) + haversine exact distance.
-- Called by ML hazard_service.dart -> getNearbyHazards(). Param names are the
-- wire contract — do not rename.
create or replace function public.get_nearby_hazards(
  lat           double precision,
  lng           double precision,
  radius_meters integer default 5000
)
returns table (
  id              integer,
  hazard_type     varchar(50),
  severity        varchar(20),
  description     text,
  latitude        double precision,
  longitude       double precision,
  distance_meters double precision,
  reported_at     timestamptz,
  expires_at      timestamptz
)
language sql
stable
security definer
set search_path = ''
as $$
  with p as (
    select
      lat  as plat,
      lng  as plng,
      radius_meters::double precision as r,
      (radius_meters / 111320.0) as dlat,
      (radius_meters / (111320.0 * greatest(cos(radians(lat)), 0.01))) as dlng
  ),
  hav as (
    select
      mh.*,
      (6371000.0 * 2 * asin(sqrt(
        power(sin(radians(mh.latitude - p.plat) / 2), 2) +
        cos(radians(p.plat)) * cos(radians(mh.latitude)) *
        power(sin(radians(mh.longitude - p.plng) / 2), 2)
      ))) as distance_meters,
      p.r as r
    from public.mine_hazards mh, p
    where mh.latitude  between p.plat - p.dlat and p.plat + p.dlat
      and mh.longitude between p.plng - p.dlng and p.plng + p.dlng
      and (mh.expires_at is null or mh.expires_at > now())
  )
  select
    hav.id, hav.hazard_type, hav.severity, hav.description,
    hav.latitude, hav.longitude, hav.distance_meters,
    hav.reported_at, hav.expires_at
  from hav
  where hav.distance_meters <= hav.r
  order by hav.distance_meters asc;
$$;

revoke execute on function public.get_nearby_hazards(double precision, double precision, integer) from anon, public;
grant execute on function public.get_nearby_hazards(double precision, double precision, integer) to authenticated;

-- ── Realtime (hazard alerts push to nearby drivers) ──────────────────────────
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public' and tablename = 'mine_hazards'
  ) then
    alter publication supabase_realtime add table public.mine_hazards;
  end if;
end $$;
