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
