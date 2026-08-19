-- ============================================================================
-- Mine 3-point location system, trip waypoints & two-party security
-- confirmations. Ported/adapted from ML/supabase/migrations/000011_mine_locations.sql
-- (see also ML 000010_gps_navigation.sql for nav context).
--
-- Adaptations from the ML donor schema to WT-live:
--   * ML trips carried mine_company_id / transporter_company_id /
--     buyer_company_id / driver_id (text). Live trips are keyed by
--     transaction_id; the mine = transactions.supplier_company_id and the
--     driver is resolved via driver_assignments -> employees.user_id.
--   * ML profiles.org_id / profiles.is_super_admin do not exist live; RLS is
--     rewritten on public.is_platform_admin(), public.is_company_staff(uuid)
--     and public.is_company_manager(uuid).
--   * mine_locations is a DISTINCT table from the existing company_locations
--     (per-type gate/weighbridge/loading anchors vs named generic points);
--     an optional company_location_id column links the two systems.
--   * mine_location_points was NOT ported: it did not exist in the ML donor
--     SQL (ML's Dart "MineLocationPoint" maps to trip_waypoints rows) and
--     nothing consumes it — dropped during review (YAGNI).
-- ============================================================================

-- ── Party helpers (new, additive; reuse live helpers inside) ─────────────────

create or replace function public.is_trip_driver(p_trip_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.trips t
    join public.driver_assignments da on da.vehicle_id = t.vehicle_id
    join public.employees e on e.id = da.driver_employee_id
    where t.id = p_trip_id
      and e.user_id = auth.uid()
  );
$$;

create or replace function public.is_trip_party(p_trip_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select
    public.is_platform_admin()
    or exists (
      select 1
      from public.trips t
      join public.transactions x on x.id = t.transaction_id
      where t.id = p_trip_id
        and (
          public.is_company_staff(x.supplier_company_id)
          or public.is_company_staff(x.buyer_company_id)
          or public.is_company_staff(x.transporter_company_id)
        )
    )
    or public.is_trip_driver(p_trip_id);
$$;

revoke execute on function public.is_trip_driver(uuid) from anon, public;
grant execute on function public.is_trip_driver(uuid) to authenticated;
revoke execute on function public.is_trip_party(uuid) from anon, public;
grant execute on function public.is_trip_party(uuid) to authenticated;

-- ── Mine Locations ───────────────────────────────────────────────────────────

create table if not exists public.mine_locations (
  id                  uuid primary key default gen_random_uuid(),
  mine_company_id     uuid not null references public.companies (id) on delete cascade,
  location_type       text not null check (location_type in ('main_gate', 'weighbridge', 'loading_point')),
  name                text not null default '',
  address             text not null default '',
  latitude            double precision,
  longitude           double precision,
  map_link            text,
  -- Optional link into the existing company_locations system (WT-live table).
  company_location_id uuid references public.company_locations (id) on delete set null,
  is_active           boolean not null default true,
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now(),
  unique (mine_company_id, location_type)
);

comment on table public.mine_locations
  is 'Configurable mine navigation anchors: Main Gate, Weighbridge, Loading Point. One active per type per mine. Distinct from company_locations (generic named points).';

-- ── Trip Waypoints ───────────────────────────────────────────────────────────

create table if not exists public.trip_waypoints (
  id             uuid primary key default gen_random_uuid(),
  trip_id        uuid not null references public.trips (id) on delete cascade,
  sequence_order integer not null,
  location_type  text not null check (location_type in ('main_gate', 'weighbridge', 'loading_point', 'drop_off')),
  name           text not null default '',
  latitude       double precision not null default 0,
  longitude      double precision not null default 0,
  address        text not null default '',
  is_completed   boolean not null default false,
  completed_at   timestamptz,
  created_at     timestamptz not null default now()
);

comment on table public.trip_waypoints
  is 'Ordered waypoints for a trip. Generated from mine_locations + drop-off input via auto_generate_trip_waypoints.';

-- ── Security Confirmations ───────────────────────────────────────────────────

create table if not exists public.security_confirmations (
  id                    uuid primary key default gen_random_uuid(),
  trip_id               uuid not null references public.trips (id) on delete cascade,
  confirmation_type     text not null check (confirmation_type in ('arrival', 'exit')),
  driver_confirmed      boolean not null default false,
  security_confirmed    boolean not null default false,
  driver_confirmed_at   timestamptz,
  security_confirmed_at timestamptz,
  security_user_id      uuid references public.profiles (id) on delete set null,
  created_at            timestamptz not null default now(),
  updated_at            timestamptz not null default now(),
  unique (trip_id, confirmation_type)
);

comment on table public.security_confirmations
  is 'Two-party confirmation for driver arrival and exit at mine gates. Both driver and security must confirm.';

-- ── Indexes ──────────────────────────────────────────────────────────────────

create index if not exists idx_mine_locations_company
  on public.mine_locations (mine_company_id);
create index if not exists idx_mine_locations_type
  on public.mine_locations (mine_company_id, location_type);
create index if not exists idx_trip_waypoints_trip
  on public.trip_waypoints (trip_id);
create index if not exists idx_trip_waypoints_order
  on public.trip_waypoints (trip_id, sequence_order);
create index if not exists idx_security_confirmations_trip
  on public.security_confirmations (trip_id);
create index if not exists idx_security_confirmations_type
  on public.security_confirmations (trip_id, confirmation_type);

-- ── updated_at triggers (reuses live public.set_updated_at) ──────────────────

drop trigger if exists trg_mine_locations_updated_at on public.mine_locations;
create trigger trg_mine_locations_updated_at
  before update on public.mine_locations
  for each row execute function public.set_updated_at();

drop trigger if exists trg_security_confirmations_updated_at on public.security_confirmations;
create trigger trg_security_confirmations_updated_at
  before update on public.security_confirmations
  for each row execute function public.set_updated_at();

-- ── RLS: mine_locations ──────────────────────────────────────────────────────
-- Live pattern: staff read, manager write, platform admin everything, plus a
-- navigation read for parties (buyer/transporter staff and assigned drivers)
-- of any trip whose transaction's supplier is this mine.

alter table public.mine_locations enable row level security;

drop policy if exists mine_locations_select on public.mine_locations;
create policy mine_locations_select on public.mine_locations
for select to authenticated
using (
  public.is_platform_admin()
  or public.is_company_staff(mine_company_id)
  or exists (
    select 1
    from public.trips t
    join public.transactions x on x.id = t.transaction_id
    where x.supplier_company_id = mine_locations.mine_company_id
      and (
        public.is_company_staff(x.buyer_company_id)
        or public.is_company_staff(x.transporter_company_id)
        or public.is_trip_driver(t.id)
      )
  )
);

drop policy if exists mine_locations_insert on public.mine_locations;
create policy mine_locations_insert on public.mine_locations
for insert to authenticated
with check (public.is_platform_admin() or public.is_company_manager(mine_company_id));

drop policy if exists mine_locations_update on public.mine_locations;
create policy mine_locations_update on public.mine_locations
for update to authenticated
using (public.is_platform_admin() or public.is_company_manager(mine_company_id))
with check (public.is_platform_admin() or public.is_company_manager(mine_company_id));

drop policy if exists mine_locations_delete on public.mine_locations;
create policy mine_locations_delete on public.mine_locations
for delete to authenticated
using (public.is_platform_admin() or public.is_company_manager(mine_company_id));

-- ── RLS: trip_waypoints (all trip parties read/write, per ML semantics) ──────

alter table public.trip_waypoints enable row level security;

drop policy if exists trip_waypoints_select on public.trip_waypoints;
create policy trip_waypoints_select on public.trip_waypoints
for select to authenticated
using (public.is_trip_party(trip_id));

drop policy if exists trip_waypoints_insert on public.trip_waypoints;
create policy trip_waypoints_insert on public.trip_waypoints
for insert to authenticated
with check (public.is_trip_party(trip_id));

drop policy if exists trip_waypoints_update on public.trip_waypoints;
create policy trip_waypoints_update on public.trip_waypoints
for update to authenticated
using (public.is_trip_party(trip_id))
with check (public.is_trip_party(trip_id));

-- ── RLS: security_confirmations (mine staff + assigned driver, per ML) ───────

alter table public.security_confirmations enable row level security;

drop policy if exists security_confirmations_select on public.security_confirmations;
create policy security_confirmations_select on public.security_confirmations
for select to authenticated
using (
  public.is_platform_admin()
  or public.is_trip_driver(trip_id)
  or public.is_company_staff((
    select x.supplier_company_id
    from public.trips t
    join public.transactions x on x.id = t.transaction_id
    where t.id = security_confirmations.trip_id
  ))
);

drop policy if exists security_confirmations_insert on public.security_confirmations;
create policy security_confirmations_insert on public.security_confirmations
for insert to authenticated
with check (
  public.is_platform_admin()
  or public.is_trip_driver(trip_id)
  or public.is_company_staff((
    select x.supplier_company_id
    from public.trips t
    join public.transactions x on x.id = t.transaction_id
    where t.id = security_confirmations.trip_id
  ))
);

drop policy if exists security_confirmations_update on public.security_confirmations;
create policy security_confirmations_update on public.security_confirmations
for update to authenticated
using (
  public.is_platform_admin()
  or public.is_trip_driver(trip_id)
  or public.is_company_staff((
    select x.supplier_company_id
    from public.trips t
    join public.transactions x on x.id = t.transaction_id
    where t.id = security_confirmations.trip_id
  ))
)
with check (
  public.is_platform_admin()
  or public.is_trip_driver(trip_id)
  or public.is_company_staff((
    select x.supplier_company_id
    from public.trips t
    join public.transactions x on x.id = t.transaction_id
    where t.id = security_confirmations.trip_id
  ))
);

-- ── Table grants (Data API exposure; RLS gates rows) ─────────────────────────

grant select, insert, update, delete on public.mine_locations to authenticated;
grant select, insert, update on public.trip_waypoints to authenticated;
grant select, insert, update on public.security_confirmations to authenticated;

-- ── RPC: auto_generate_trip_waypoints ────────────────────────────────────────
-- Called by ML mine_location_service.dart -> autoGenerateWaypoints().
-- Sequence: 1 main_gate (arrive) · 2 weighbridge (tare) · 3 loading_point ·
--           4 weighbridge (gross) · 5 main_gate (exit) · 6 drop_off (placeholder).
-- Adaptation: mine id = transactions.supplier_company_id (ML: trips.mine_company_id);
-- idempotent (returns existing rows instead of duplicating, unlike ML).

create or replace function public.auto_generate_trip_waypoints(p_trip_id uuid)
returns setof public.trip_waypoints
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_mine_id uuid;
  v_mg      record;
  v_wb      record;
  v_lp      record;
  v_now     timestamptz := now();
begin
  if not public.is_trip_party(p_trip_id) then
    raise exception 'Not a party to trip %', p_trip_id;
  end if;

  select x.supplier_company_id into v_mine_id
  from public.trips t
  join public.transactions x on x.id = t.transaction_id
  where t.id = p_trip_id;

  if not found then
    raise exception 'Trip % not found', p_trip_id;
  end if;

  -- Idempotent: never duplicate an existing waypoint set.
  if exists (select 1 from public.trip_waypoints tw where tw.trip_id = p_trip_id) then
    return query
      select * from public.trip_waypoints tw
      where tw.trip_id = p_trip_id
      order by tw.sequence_order;
    return;
  end if;

  select * into v_mg from public.mine_locations ml
    where ml.mine_company_id = v_mine_id and ml.location_type = 'main_gate' and ml.is_active;
  select * into v_wb from public.mine_locations ml
    where ml.mine_company_id = v_mine_id and ml.location_type = 'weighbridge' and ml.is_active;
  select * into v_lp from public.mine_locations ml
    where ml.mine_company_id = v_mine_id and ml.location_type = 'loading_point' and ml.is_active;

  insert into public.trip_waypoints
    (trip_id, sequence_order, location_type, name, latitude, longitude, address, created_at)
  values
    (p_trip_id, 1, 'main_gate',     coalesce(v_mg.name, 'Main Gate'),     coalesce(v_mg.latitude, 0), coalesce(v_mg.longitude, 0), coalesce(v_mg.address, ''), v_now),
    (p_trip_id, 2, 'weighbridge',   coalesce(v_wb.name, 'Weighbridge'),   coalesce(v_wb.latitude, 0), coalesce(v_wb.longitude, 0), coalesce(v_wb.address, ''), v_now),
    (p_trip_id, 3, 'loading_point', coalesce(v_lp.name, 'Loading Point'), coalesce(v_lp.latitude, 0), coalesce(v_lp.longitude, 0), coalesce(v_lp.address, ''), v_now),
    (p_trip_id, 4, 'weighbridge',   coalesce(v_wb.name, 'Weighbridge'),   coalesce(v_wb.latitude, 0), coalesce(v_wb.longitude, 0), coalesce(v_wb.address, ''), v_now),
    (p_trip_id, 5, 'main_gate',     coalesce(v_mg.name, 'Main Gate'),     coalesce(v_mg.latitude, 0), coalesce(v_mg.longitude, 0), coalesce(v_mg.address, ''), v_now),
    (p_trip_id, 6, 'drop_off',      'Drop-Off Point', 0, 0, '', v_now);

  return query
    select * from public.trip_waypoints tw
    where tw.trip_id = p_trip_id
    order by tw.sequence_order;
end;
$$;

-- ── RPC: get_trip_waypoints ──────────────────────────────────────────────────
-- (ML defined it; the Dart service currently reads the table directly, but the
-- RPC is kept for parity with ML 000011.)

create or replace function public.get_trip_waypoints(p_trip_id uuid)
returns setof public.trip_waypoints
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if not public.is_trip_party(p_trip_id) then
    raise exception 'Not a party to trip %', p_trip_id;
  end if;

  return query
    select * from public.trip_waypoints tw
    where tw.trip_id = p_trip_id
    order by tw.sequence_order;
end;
$$;

-- ── RPC: complete_trip_waypoint ──────────────────────────────────────────────
-- Called by ML mine_location_service.dart -> completeWaypoint().

create or replace function public.complete_trip_waypoint(p_waypoint_id uuid)
returns public.trip_waypoints
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_trip_id uuid;
  v_result  public.trip_waypoints;
begin
  select tw.trip_id into v_trip_id
  from public.trip_waypoints tw
  where tw.id = p_waypoint_id;

  if not found then
    raise exception 'Waypoint % not found', p_waypoint_id;
  end if;

  if not public.is_trip_party(v_trip_id) then
    raise exception 'Not a party to trip %', v_trip_id;
  end if;

  update public.trip_waypoints
  set is_completed = true, completed_at = now()
  where id = p_waypoint_id
  returning * into v_result;

  return v_result;
end;
$$;

-- ── RPC: set_drop_off_waypoint ───────────────────────────────────────────────
-- Called by ML mine_location_service.dart -> setDropOffWaypoint().

create or replace function public.set_drop_off_waypoint(
  p_trip_id   uuid,
  p_latitude  double precision,
  p_longitude double precision,
  p_address   text
)
returns public.trip_waypoints
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_result public.trip_waypoints;
begin
  if not public.is_trip_party(p_trip_id) then
    raise exception 'Not a party to trip %', p_trip_id;
  end if;

  update public.trip_waypoints
  set latitude = p_latitude,
      longitude = p_longitude,
      address = p_address,
      name = 'Drop-Off Point'
  where trip_id = p_trip_id
    and location_type = 'drop_off'
  returning * into v_result;

  if not found then
    raise exception 'Drop-off waypoint not found for trip %', p_trip_id;
  end if;

  return v_result;
end;
$$;

-- ── RPC: get_mine_pending_confirmations ──────────────────────────────────────
-- Called by ML mine_location_service.dart -> getMinePendingConfirmations().
-- Adaptation: mine match via transactions.supplier_company_id.

create or replace function public.get_mine_pending_confirmations(p_mine_id uuid)
returns setof public.security_confirmations
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if not (public.is_platform_admin() or public.is_company_staff(p_mine_id)) then
    raise exception 'Not a member of mine %', p_mine_id;
  end if;

  return query
    select sc.*
    from public.security_confirmations sc
    join public.trips t on t.id = sc.trip_id
    join public.transactions x on x.id = t.transaction_id
    where x.supplier_company_id = p_mine_id
      and sc.security_confirmed = false
    order by sc.created_at desc;
end;
$$;

-- ── Function grants ──────────────────────────────────────────────────────────

revoke execute on function public.auto_generate_trip_waypoints(uuid) from anon, public;
grant execute on function public.auto_generate_trip_waypoints(uuid) to authenticated;
revoke execute on function public.get_trip_waypoints(uuid) from anon, public;
grant execute on function public.get_trip_waypoints(uuid) to authenticated;
revoke execute on function public.complete_trip_waypoint(uuid) from anon, public;
grant execute on function public.complete_trip_waypoint(uuid) to authenticated;
revoke execute on function public.set_drop_off_waypoint(uuid, double precision, double precision, text) from anon, public;
grant execute on function public.set_drop_off_waypoint(uuid, double precision, double precision, text) to authenticated;
revoke execute on function public.get_mine_pending_confirmations(uuid) from anon, public;
grant execute on function public.get_mine_pending_confirmations(uuid) to authenticated;

-- ── Realtime: security_confirmations (queue screens refresh live) ────────────

do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public' and tablename = 'security_confirmations'
  ) then
    alter publication supabase_realtime add table public.security_confirmations;
  end if;
end $$;
