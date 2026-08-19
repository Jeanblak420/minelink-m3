-- Live navigation telemetry sharing (user request 2026-07-17): every party
-- that can already see live tracking (mine / buyer / transporter / platform
-- admin) also sees what the driver's navigation sees — ETA, time left,
-- distance, speed, the current instruction and the actual route line — plus
-- the trip timeline and the ETA overrun vs the driver's original ETA.
--
-- One row per trip, upserted by the driver's nav screen alongside the 30s
-- position pings. Party scoping mirrors list_live_trip_positions.

begin;

-- 1. Per-trip navigation state ------------------------------------------------

create table if not exists public.trip_nav_state (
  trip_id uuid primary key references public.trips(id) on delete cascade,
  vehicle_id uuid references public.fleet_vehicles(id) on delete set null,
  -- OSRM precision-5 encoded polyline of the route the driver is following.
  route_polyline text,
  current_instruction text,
  eta timestamptz,
  time_left_s integer,
  distance_left_m integer,
  speed_kmh double precision,
  -- Baseline for "how late vs plan": the ETA of the FIRST route of this nav
  -- session; kept across reroutes, reset when the driver starts nav afresh.
  original_eta timestamptz,
  nav_started_at timestamptz,
  updated_at timestamptz not null default now()
);

create index if not exists trip_nav_state_vehicle_idx
  on public.trip_nav_state (vehicle_id);

alter table public.trip_nav_state enable row level security;

-- Trip parties read; all writes go through the RPC below.
drop policy if exists trip_nav_state_select on public.trip_nav_state;
create policy trip_nav_state_select on public.trip_nav_state
for select to authenticated
using (
  public.is_platform_admin()
  or exists (
    select 1
    from public.trips t
    join public.transactions x on x.id = t.transaction_id
    where t.id = trip_nav_state.trip_id
      and (
        public.is_company_staff(x.supplier_company_id)
        or public.is_company_staff(x.buyer_company_id)
        or public.is_company_staff(x.transporter_company_id)
      )
  )
);

grant select on public.trip_nav_state to authenticated;

-- 2. Driver publish RPC ---------------------------------------------------------
-- Same caller resolution as record_vehicle_position: the authenticated user
-- must be an assigned driver; the row is keyed to their truck's active trip.

create or replace function public.publish_trip_nav_state(
  p_current_instruction text default null,
  p_eta timestamptz default null,
  p_time_left_s integer default null,
  p_distance_left_m integer default null,
  p_speed_kmh double precision default null,
  p_route_polyline text default null,
  p_new_session boolean default false
)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_vehicle_id uuid;
  v_trip_id uuid;
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;

  select da.vehicle_id into v_vehicle_id
  from public.driver_assignments da
  join public.employees e on e.id = da.driver_employee_id
  where e.user_id = auth.uid()
  limit 1;
  if v_vehicle_id is null then
    return jsonb_build_object('published', false, 'reason', 'no_vehicle');
  end if;

  select t.id into v_trip_id
  from public.trips t
  where t.vehicle_id = v_vehicle_id
    and t.status not in ('completed', 'cancelled')
  order by t.updated_at desc
  limit 1;
  if v_trip_id is null then
    return jsonb_build_object('published', false, 'reason', 'no_active_trip');
  end if;

  insert into public.trip_nav_state (
    trip_id, vehicle_id, route_polyline, current_instruction, eta,
    time_left_s, distance_left_m, speed_kmh, original_eta, nav_started_at,
    updated_at
  ) values (
    v_trip_id, v_vehicle_id, p_route_polyline, p_current_instruction, p_eta,
    p_time_left_s, p_distance_left_m, p_speed_kmh, p_eta, now(), now()
  )
  on conflict (trip_id) do update set
    vehicle_id = excluded.vehicle_id,
    route_polyline = coalesce(excluded.route_polyline, trip_nav_state.route_polyline),
    current_instruction = coalesce(excluded.current_instruction, trip_nav_state.current_instruction),
    eta = coalesce(excluded.eta, trip_nav_state.eta),
    time_left_s = coalesce(excluded.time_left_s, trip_nav_state.time_left_s),
    distance_left_m = coalesce(excluded.distance_left_m, trip_nav_state.distance_left_m),
    speed_kmh = coalesce(excluded.speed_kmh, trip_nav_state.speed_kmh),
    -- A fresh nav session resets the baseline; reroutes inside one session
    -- keep the original ETA so lateness stays measured against the plan.
    original_eta = case
      when p_new_session then excluded.eta
      else coalesce(trip_nav_state.original_eta, excluded.eta)
    end,
    nav_started_at = case
      when p_new_session then now()
      else coalesce(trip_nav_state.nav_started_at, now())
    end,
    updated_at = now();

  return jsonb_build_object('published', true, 'trip_id', v_trip_id);
end;
$$;

revoke all on function public.publish_trip_nav_state(text, timestamptz, integer, integer, double precision, text, boolean) from public;
grant execute on function public.publish_trip_nav_state(text, timestamptz, integer, integer, double precision, text, boolean) to authenticated;

-- 3. Feed: nav telemetry + trip timeline for every watcher ----------------------
-- Return type grows, so drop + recreate (Dart reads by key; additive-safe).

drop function if exists public.list_live_trip_positions(uuid);
create function public.list_live_trip_positions(p_company_id uuid default null::uuid)
returns table(
  trip_id uuid, trip_status text, vehicle_id uuid, truck_reg text,
  transporter_name text, supplier_name text, buyer_name text,
  loading_point text, offloading_point text,
  lat double precision, lng double precision, heading double precision,
  speed_kmh double precision, recorded_at timestamptz,
  driver_name text, driver_phone text, stationary_since timestamptz,
  -- Trip timeline (started / left / arrived …)
  trip_created_at timestamptz, arrived_at timestamptz, loading_at timestamptz,
  loaded_at timestamptz, left_at timestamptz, offloaded_at timestamptz,
  -- Driver navigation mirror
  nav_instruction text, nav_eta timestamptz, nav_original_eta timestamptz,
  nav_time_left_s integer, nav_distance_left_m integer,
  nav_speed_kmh double precision, nav_started_at timestamptz,
  nav_route_polyline text, nav_updated_at timestamptz
)
language sql
stable security definer
set search_path to 'public'
as $function$
  select
    t.id as trip_id,
    t.status as trip_status,
    t.vehicle_id,
    coalesce(fv.vehicle_registration_number, t.metadata->>'truck_reg') as truck_reg,
    tc.company_name as transporter_name,
    sc.company_name as supplier_name,
    bc.company_name as buyer_name,
    coalesce(r.loading_point, txn.metadata->>'loading_point', t.metadata->>'loading_point') as loading_point,
    coalesce(r.offloading_point, txn.metadata->>'offloading_point', t.metadata->>'offloading_point') as offloading_point,
    vp.lat,
    vp.lng,
    vp.heading,
    vp.speed_kmh,
    vp.recorded_at,
    drv.names as driver_name,
    drv.primary_phone as driver_phone,
    mot.stationary_since,
    t.created_at as trip_created_at,
    t.arrived_at,
    t.loading_at,
    t.loaded_at,
    t.left_at,
    t.offloaded_at,
    ns.current_instruction as nav_instruction,
    ns.eta as nav_eta,
    ns.original_eta as nav_original_eta,
    ns.time_left_s as nav_time_left_s,
    ns.distance_left_m as nav_distance_left_m,
    ns.speed_kmh as nav_speed_kmh,
    ns.nav_started_at,
    ns.route_polyline as nav_route_polyline,
    ns.updated_at as nav_updated_at
  from public.trips t
  join public.transactions txn on txn.id = t.transaction_id
  left join public.fleet_vehicles fv on fv.id = t.vehicle_id
  left join public.request_dispatches d on d.id = t.dispatch_id
  left join public.transportation_requests r on r.id = d.request_id
  left join public.companies tc on tc.id = txn.transporter_company_id
  left join public.companies sc on sc.id = txn.supplier_company_id
  left join public.companies bc on bc.id = txn.buyer_company_id
  left join public.trip_nav_state ns on ns.trip_id = t.id
  left join lateral (
    select p.lat, p.lng, p.heading, p.speed_kmh, p.recorded_at
    from public.vehicle_positions p
    where p.vehicle_id = t.vehicle_id
    order by p.recorded_at desc
    limit 1
  ) vp on true
  left join lateral (
    select
      nullif(string_agg(
        nullif(trim(coalesce(e.first_name, '') || ' ' || coalesce(e.last_name, '')), ''),
        ', ' order by da.created_at
      ), '') as names,
      (array_agg(e.whatsapp_number order by da.created_at))[1] as primary_phone
    from public.driver_assignments da
    join public.employees e on e.id = da.driver_employee_id
    where da.vehicle_id = t.vehicle_id
  ) drv on true
  left join lateral (
    select min(p.recorded_at) filter (
      where p.recorded_at > coalesce(
        (select max(p2.recorded_at)
         from public.vehicle_positions p2
         where p2.vehicle_id = t.vehicle_id
           and p2.speed_kmh is not null
           and p2.speed_kmh >= 5),
        '-infinity'::timestamptz)
    ) as stationary_since
    from public.vehicle_positions p
    where p.vehicle_id = t.vehicle_id
  ) mot on true
  where t.status not in ('completed', 'cancelled')
    and t.vehicle_id is not null
    and (
      public.is_platform_admin()
      or public.is_company_staff(txn.supplier_company_id)
      or public.is_company_staff(txn.buyer_company_id)
      or public.is_company_staff(txn.transporter_company_id)
    )
    and (
      p_company_id is null
      or txn.supplier_company_id = p_company_id
      or txn.buyer_company_id = p_company_id
      or txn.transporter_company_id = p_company_id
    )
  order by t.updated_at desc;
$function$;

revoke all on function public.list_live_trip_positions(uuid) from public;
grant execute on function public.list_live_trip_positions(uuid) to authenticated;

-- 4. Realtime: watchers refresh when the nav state changes between pings --------
do $$
begin
  if not exists (select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public'
      and tablename = 'trip_nav_state') then
    alter publication supabase_realtime add table public.trip_nav_state;
  end if;
end $$;

commit;
