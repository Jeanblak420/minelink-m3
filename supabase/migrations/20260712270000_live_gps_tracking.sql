-- Live trip GPS tracking (CLAUDE.md §4 "Live trip GPS tracking / ETA").
--
-- Write side: drivers ping their position (~every 30s) from the driver app via
-- record_vehicle_position(). Authorization is derived from driver_assignments
-- (employees.user_id = auth.uid() -> their truck); the ping is stamped with the
-- vehicle's active trip and refused when there is none, which doubles as the
-- client's stop signal.
--
-- Read side: list_live_trip_positions() returns each active trip with its
-- latest position, party-scoped exactly like list_trip_reconciliations
-- (platform admin, or staff of the transaction's supplier/buyer/transporter).
-- vehicle_positions joins the realtime publication so live maps refresh on
-- INSERT. Position history is retained indefinitely (product decision,
-- 2026-07-12) — no pruning here.

begin;

-- 1. Extend vehicle_positions -------------------------------------------------

alter table public.vehicle_positions
  add column if not exists trip_id uuid references public.trips(id) on delete set null,
  add column if not exists speed_kmh double precision,
  add column if not exists accuracy_m double precision,
  add column if not exists recorded_by uuid;

create index if not exists vehicle_positions_trip_idx
  on public.vehicle_positions (trip_id, recorded_at desc);

-- 2. Broaden read access to trip parties --------------------------------------
-- The original policy only covered fleet-owner staff; the live map is for every
-- party on the trip (and realtime INSERT events are filtered by this policy).

drop policy if exists vehicle_positions_select on public.vehicle_positions;
create policy vehicle_positions_select on public.vehicle_positions
for select to authenticated
using (
  public.is_platform_admin()
  or exists (
    select 1 from public.fleet_vehicles fv
    where fv.id = vehicle_positions.vehicle_id
      and public.is_company_staff(fv.company_id)
  )
  or exists (
    select 1
    from public.trips t
    join public.transactions txn on txn.id = t.transaction_id
    where t.id = vehicle_positions.trip_id
      and (
        public.is_company_staff(txn.supplier_company_id)
        or public.is_company_staff(txn.buyer_company_id)
        or public.is_company_staff(txn.transporter_company_id)
      )
  )
);

-- 3. Driver ping RPC -----------------------------------------------------------

create or replace function public.record_vehicle_position(
  p_lat double precision,
  p_lng double precision,
  p_heading double precision default null,
  p_speed_kmh double precision default null,
  p_accuracy_m double precision default null
)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_vehicle_id uuid;
  v_trip_id uuid;
  v_trip_status text;
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;
  if p_lat is null or p_lng is null
     or p_lat < -90 or p_lat > 90
     or p_lng < -180 or p_lng > 180 then
    raise exception 'Invalid coordinates';
  end if;

  -- The caller must be an assigned driver (one truck per driver, enforced by
  -- driver_assignments_one_truck_per_driver).
  select da.vehicle_id into v_vehicle_id
  from public.driver_assignments da
  join public.employees e on e.id = da.driver_employee_id
  where e.user_id = auth.uid()
  limit 1;

  if v_vehicle_id is null then
    return jsonb_build_object('recorded', false, 'reason', 'no_vehicle');
  end if;

  select t.id, t.status into v_trip_id, v_trip_status
  from public.trips t
  where t.vehicle_id = v_vehicle_id
    and t.status not in ('completed', 'cancelled')
  order by t.updated_at desc
  limit 1;

  if v_trip_id is null then
    return jsonb_build_object('recorded', false, 'reason', 'no_active_trip');
  end if;

  insert into public.vehicle_positions
    (vehicle_id, trip_id, lat, lng, heading, speed_kmh, accuracy_m, recorded_by, source)
  values
    (v_vehicle_id, v_trip_id, p_lat, p_lng, p_heading, p_speed_kmh, p_accuracy_m,
     auth.uid(), 'driver_app');

  return jsonb_build_object(
    'recorded', true,
    'vehicle_id', v_vehicle_id,
    'trip_id', v_trip_id,
    'trip_status', v_trip_status
  );
end;
$$;

revoke all on function public.record_vehicle_position(double precision, double precision, double precision, double precision, double precision) from public;
revoke all on function public.record_vehicle_position(double precision, double precision, double precision, double precision, double precision) from anon;
grant execute on function public.record_vehicle_position(double precision, double precision, double precision, double precision, double precision) to authenticated;

-- 4. Party-scoped live feed ----------------------------------------------------
-- One row per active trip that has a truck: trip + parties + latest position
-- (null lat/lng until the driver's first ping). p_company_id = null gives the
-- platform-wide view (super-admin); for org users it narrows to their trips.

drop function if exists public.list_live_trip_positions(uuid);
create function public.list_live_trip_positions(p_company_id uuid default null)
returns table (
  trip_id uuid,
  trip_status text,
  vehicle_id uuid,
  truck_reg text,
  transporter_name text,
  supplier_name text,
  buyer_name text,
  loading_point text,
  offloading_point text,
  lat double precision,
  lng double precision,
  heading double precision,
  speed_kmh double precision,
  recorded_at timestamptz
)
language sql
stable
security definer
set search_path to 'public'
as $$
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
    vp.recorded_at
  from public.trips t
  join public.transactions txn on txn.id = t.transaction_id
  left join public.fleet_vehicles fv on fv.id = t.vehicle_id
  left join public.request_dispatches d on d.id = t.dispatch_id
  left join public.transportation_requests r on r.id = d.request_id
  left join public.companies tc on tc.id = txn.transporter_company_id
  left join public.companies sc on sc.id = txn.supplier_company_id
  left join public.companies bc on bc.id = txn.buyer_company_id
  left join lateral (
    select p.lat, p.lng, p.heading, p.speed_kmh, p.recorded_at
    from public.vehicle_positions p
    where p.vehicle_id = t.vehicle_id
    order by p.recorded_at desc
    limit 1
  ) vp on true
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
$$;

revoke all on function public.list_live_trip_positions(uuid) from public;
revoke all on function public.list_live_trip_positions(uuid) from anon;
grant execute on function public.list_live_trip_positions(uuid) to authenticated;

-- 5. Realtime ------------------------------------------------------------------

do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'vehicle_positions'
  ) then
    alter publication supabase_realtime add table public.vehicle_positions;
  end if;
end $$;

commit;
