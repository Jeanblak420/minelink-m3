-- Fleet Maintenance & Downtime (spec docs/superpowers/specs/2026-07-17-fleet-maintenance-design.md)
--
-- "In maintenance" is DERIVED from an open record with takes_out_of_service —
-- same pattern as On-Route being derived from active trips. Closing the record
-- is the only thing needed to return the truck to Available; no status flag
-- can go stale. Fleet states: Available ↔ On Route ↔ In Maintenance.

begin;

-- 1. Tables ---------------------------------------------------------------

create table if not exists public.fleet_maintenance_records (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete cascade,
  vehicle_id uuid not null references public.fleet_vehicles(id) on delete cascade,
  kind text not null check (kind in ('service', 'repair', 'breakdown', 'inspection')),
  title text not null check (length(trim(title)) between 1 and 160),
  notes text,
  status text not null default 'open' check (status in ('open', 'closed')),
  takes_out_of_service boolean not null default true,
  started_at timestamptz not null default now(),
  expected_back_at timestamptz,
  closed_at timestamptz,
  cost_zar numeric check (cost_zar is null or cost_zar >= 0),
  odometer_km integer check (odometer_km is null or odometer_km >= 0),
  created_by uuid default auth.uid(),
  closed_by uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists fleet_maintenance_company_status_idx
  on public.fleet_maintenance_records (company_id, status);
create index if not exists fleet_maintenance_vehicle_status_idx
  on public.fleet_maintenance_records (vehicle_id, status);
create index if not exists fleet_maintenance_created_by_idx
  on public.fleet_maintenance_records (created_by);
create index if not exists fleet_maintenance_closed_by_idx
  on public.fleet_maintenance_records (closed_by);

create table if not exists public.fleet_service_schedules (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete cascade,
  vehicle_id uuid not null references public.fleet_vehicles(id) on delete cascade,
  name text not null check (length(trim(name)) between 1 and 160),
  due_date date,
  due_odometer_km integer check (due_odometer_km is null or due_odometer_km >= 0),
  repeat_months integer check (repeat_months is null or repeat_months between 1 and 60),
  repeat_km integer check (repeat_km is null or repeat_km between 100 and 1000000),
  notify_days_before integer not null default 7 check (notify_days_before between 0 and 90),
  active boolean not null default true,
  last_done_at timestamptz,
  last_notified_at timestamptz,
  created_by uuid default auth.uid(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint service_schedule_has_due check (due_date is not null or due_odometer_km is not null)
);

create index if not exists fleet_service_schedules_company_active_idx
  on public.fleet_service_schedules (company_id, active);
create index if not exists fleet_service_schedules_vehicle_idx
  on public.fleet_service_schedules (vehicle_id);
create index if not exists fleet_service_schedules_created_by_idx
  on public.fleet_service_schedules (created_by);

-- 2. RLS: staff read their company; ALL writes go through the RPCs ---------

alter table public.fleet_maintenance_records enable row level security;
alter table public.fleet_service_schedules enable row level security;

drop policy if exists fleet_maintenance_select on public.fleet_maintenance_records;
create policy fleet_maintenance_select on public.fleet_maintenance_records
for select to authenticated
using (public.is_platform_admin() or public.is_company_staff(company_id));

drop policy if exists fleet_service_schedules_select on public.fleet_service_schedules;
create policy fleet_service_schedules_select on public.fleet_service_schedules
for select to authenticated
using (public.is_platform_admin() or public.is_company_staff(company_id));

grant select on public.fleet_maintenance_records to authenticated;
grant select on public.fleet_service_schedules to authenticated;

-- 3. Fleet availability gains the third state ------------------------------
-- Return type changes, so drop + recreate (two new columns at the end).

drop function if exists public.list_transporter_fleet_status(uuid);
create function public.list_transporter_fleet_status(p_company_id uuid)
returns table(
  vehicle_id uuid, registration text, make text, vehicle_type text,
  driver_employee_id uuid, driver_name text, drivers text, driver_count integer,
  max_drivers integer, is_active boolean, on_route boolean, active_trip_id uuid,
  trip_status text, buyer_name text, commodity text, offloading_point text,
  loading_point text, in_maintenance boolean, maintenance_title text
)
language sql
stable security definer
set search_path to 'public'
as $$
  select
    v.id,
    v.vehicle_registration_number,
    v.vehicle_make,
    v.vehicle_type,
    v.assigned_driver_employee_id,
    nullif(trim(coalesce(v.driver_first_name, '') || ' ' || coalesce(v.driver_last_name, '')), ''),
    coalesce(
      drv.names,
      nullif(trim(coalesce(v.driver_first_name, '') || ' ' || coalesce(v.driver_last_name, '')), '')
    ) as drivers,
    coalesce(drv.cnt, 0)::integer as driver_count,
    v.max_drivers,
    v.is_active,
    (t.id is not null) as on_route,
    t.id,
    t.status,
    bc.company_name,
    coalesce(txn.metadata->>'commodity', ''),
    coalesce(txn.metadata->>'offloading_point', ''),
    coalesce(txn.metadata->>'loading_point', ''),
    (m.id is not null) as in_maintenance,
    m.title as maintenance_title
  from public.fleet_vehicles v
  left join lateral (
    select
      string_agg(
        nullif(trim(coalesce(e.first_name, '') || ' ' || coalesce(e.last_name, '')), ''),
        ', ' order by da.created_at
      ) as names,
      count(*) as cnt
    from public.driver_assignments da
    join public.employees e on e.id = da.driver_employee_id
    where da.vehicle_id = v.id
  ) drv on true
  left join lateral (
    select tr.id, tr.status, tr.transaction_id
    from public.trips tr
    where tr.vehicle_id = v.id
      and tr.status not in ('completed', 'cancelled')
    order by tr.created_at desc
    limit 1
  ) t on true
  left join public.transactions txn on txn.id = t.transaction_id
  left join public.companies bc on bc.id = txn.buyer_company_id
  left join lateral (
    select r.id, r.title
    from public.fleet_maintenance_records r
    where r.vehicle_id = v.id and r.status = 'open' and r.takes_out_of_service
    order by r.started_at desc
    limit 1
  ) m on true
  where v.company_id = p_company_id
    and public.is_company_staff(p_company_id)
  order by (t.id is not null), v.vehicle_registration_number;
$$;

revoke all on function public.list_transporter_fleet_status(uuid) from public;
grant execute on function public.list_transporter_fleet_status(uuid) to authenticated;

-- 4. Server-side dispatch guard --------------------------------------------
-- Same body as before + the in-maintenance check inside the vehicle loop.

create or replace function public.accept_request_dispatch(p_dispatch_id uuid, p_vehicle_ids uuid[])
returns request_dispatches
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_dispatch public.request_dispatches; v_req public.transportation_requests;
  v_vehicle public.fleet_vehicles; v_vid uuid; v_txn_id uuid; v_ref text; v_required int;
begin
  select * into v_dispatch from public.request_dispatches where id = p_dispatch_id;
  if not found then raise exception 'Dispatch % not found', p_dispatch_id; end if;
  if not public.is_company_manager(v_dispatch.transporter_company_id) then
    raise exception 'Only the transporter''s admin/management may accept routes';
  end if;
  if v_dispatch.status <> 'dispatched' then raise exception 'This route is no longer open to accept'; end if;
  if p_vehicle_ids is null or array_length(p_vehicle_ids, 1) is null then
    raise exception 'Tick at least one truck to accept this route';
  end if;
  select * into v_req from public.transportation_requests where id = v_dispatch.request_id;
  if not found then raise exception 'Request for dispatch % not found', p_dispatch_id; end if;
  v_required := nullif(regexp_replace(coalesce(v_req.num_slots, ''), '\D', '', 'g'), '')::int;
  if v_required is not null and v_required > 0 and array_length(p_vehicle_ids, 1) > v_required then
    raise exception 'This route needs at most % truck(s); you selected %', v_required, array_length(p_vehicle_ids, 1);
  end if;
  foreach v_vid in array p_vehicle_ids loop
    select * into v_vehicle from public.fleet_vehicles where id = v_vid;
    if not found or v_vehicle.company_id <> v_dispatch.transporter_company_id then
      raise exception 'Truck % is not in your fleet', v_vid;
    end if;
    if exists (select 1 from public.trips t where t.vehicle_id = v_vid
        and t.status not in ('completed', 'cancelled')) then
      raise exception 'Truck % is already on a route and cannot be assigned again',
        v_vehicle.vehicle_registration_number;
    end if;
    -- Maintenance gate (spec 2026-07-17): an open out-of-service record blocks
    -- assignment until it is closed, at which point the truck is Available again.
    if exists (select 1 from public.fleet_maintenance_records m
        where m.vehicle_id = v_vid and m.status = 'open' and m.takes_out_of_service) then
      raise exception 'Truck % is in maintenance and cannot be assigned until it is marked fixed',
        v_vehicle.vehicle_registration_number;
    end if;
    v_ref := 'TRP-' || upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 10));
    insert into public.transactions (reference_number, supplier_company_id, buyer_company_id,
      transporter_company_id, status, quantity, dispatch_id, created_by, metadata)
    values (v_ref, v_req.supplier_company_id, v_req.buyer_company_id, v_dispatch.transporter_company_id,
      'scheduled', 0, p_dispatch_id, auth.uid(),
      jsonb_build_object('request_id', v_req.id, 'dispatch_id', p_dispatch_id, 'commodity', v_req.commodity,
        'loading_point', v_req.loading_point, 'offloading_point', v_req.offloading_point,
        'rate', v_req.rate, 'payment_terms', v_req.payment_terms))
    returning id into v_txn_id;
    insert into public.trips (transaction_id, vehicle_id, status, dispatch_id, route_id, metadata)
    values (v_txn_id, v_vid, 'scheduled', p_dispatch_id, v_dispatch.route_id,
      jsonb_build_object('truck_reg', v_vehicle.vehicle_registration_number));
  end loop;
  update public.request_dispatches set status = 'accepted' where id = p_dispatch_id returning * into v_dispatch;
  return v_dispatch;
end;
$function$;

-- 5. RPCs -------------------------------------------------------------------

create or replace function public.open_maintenance_record(
  p_vehicle_id uuid,
  p_kind text,
  p_title text,
  p_notes text default null,
  p_takes_out_of_service boolean default true,
  p_expected_back_at timestamptz default null,
  p_cost_zar numeric default null,
  p_odometer_km integer default null
)
returns uuid
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_vehicle public.fleet_vehicles;
  v_id uuid;
begin
  select * into v_vehicle from public.fleet_vehicles where id = p_vehicle_id;
  if not found then raise exception 'Vehicle not found'; end if;
  if not public.can_manage_fleet(v_vehicle.company_id) then
    raise exception 'Only the fleet managers may log maintenance';
  end if;

  insert into public.fleet_maintenance_records (
    company_id, vehicle_id, kind, title, notes, takes_out_of_service,
    expected_back_at, cost_zar, odometer_km
  ) values (
    v_vehicle.company_id, p_vehicle_id, p_kind, trim(p_title), p_notes,
    coalesce(p_takes_out_of_service, true), p_expected_back_at, p_cost_zar, p_odometer_km
  ) returning id into v_id;

  if coalesce(p_takes_out_of_service, true) then
    perform public.notify_company_management(
      v_vehicle.company_id,
      'Vehicle in maintenance',
      format('%s is out of service — %s. It cannot be assigned to routes until marked fixed.',
        v_vehicle.vehicle_registration_number, trim(p_title)),
      'fleetVehicleStatusChanged',
      null, auth.uid(), 'high',
      jsonb_build_object('vehicle_id', p_vehicle_id, 'maintenance_record_id', v_id,
        'nav_tab', 'Maintenance')
    );
  end if;
  return v_id;
end;
$$;

create or replace function public.close_maintenance_record(
  p_record_id uuid,
  p_notes text default null,
  p_cost_zar numeric default null,
  p_odometer_km integer default null
)
returns void
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_rec public.fleet_maintenance_records;
  v_reg text;
begin
  select * into v_rec from public.fleet_maintenance_records where id = p_record_id;
  if not found then raise exception 'Maintenance record not found'; end if;
  if not public.can_manage_fleet(v_rec.company_id) then
    raise exception 'Only the fleet managers may close maintenance';
  end if;
  if v_rec.status = 'closed' then return; end if;

  update public.fleet_maintenance_records
  set status = 'closed',
      closed_at = now(),
      closed_by = auth.uid(),
      notes = coalesce(p_notes, notes),
      cost_zar = coalesce(p_cost_zar, cost_zar),
      odometer_km = coalesce(p_odometer_km, odometer_km),
      updated_at = now()
  where id = p_record_id;

  select vehicle_registration_number into v_reg
  from public.fleet_vehicles where id = v_rec.vehicle_id;

  if v_rec.takes_out_of_service then
    perform public.notify_company_management(
      v_rec.company_id,
      'Vehicle back in service',
      format('%s is fixed and available for routes again (%s closed).',
        coalesce(v_reg, 'Vehicle'), v_rec.title),
      'fleetVehicleStatusChanged',
      null, auth.uid(), 'normal',
      jsonb_build_object('vehicle_id', v_rec.vehicle_id, 'maintenance_record_id', p_record_id,
        'nav_tab', 'Maintenance')
    );
  end if;
end;
$$;

create or replace function public.list_fleet_maintenance(p_company_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path to 'public'
as $$
begin
  if not (public.is_platform_admin() or public.is_company_staff(p_company_id)) then
    raise exception 'Not your fleet';
  end if;
  return jsonb_build_object(
    'records', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', r.id, 'vehicle_id', r.vehicle_id,
        'registration', v.vehicle_registration_number,
        'kind', r.kind, 'title', r.title, 'notes', r.notes,
        'status', r.status, 'takes_out_of_service', r.takes_out_of_service,
        'started_at', r.started_at, 'expected_back_at', r.expected_back_at,
        'closed_at', r.closed_at, 'cost_zar', r.cost_zar,
        'odometer_km', r.odometer_km
      ) order by (r.status = 'open') desc, r.started_at desc)
      from public.fleet_maintenance_records r
      join public.fleet_vehicles v on v.id = r.vehicle_id
      where r.company_id = p_company_id
    ), '[]'::jsonb),
    'schedules', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', s.id, 'vehicle_id', s.vehicle_id,
        'registration', v.vehicle_registration_number,
        'vehicle_odometer_km', v.vehicle_odometer_km,
        'name', s.name, 'due_date', s.due_date,
        'due_odometer_km', s.due_odometer_km,
        'repeat_months', s.repeat_months, 'repeat_km', s.repeat_km,
        'notify_days_before', s.notify_days_before, 'active', s.active,
        'last_done_at', s.last_done_at
      ) order by s.active desc, s.due_date nulls last)
      from public.fleet_service_schedules s
      join public.fleet_vehicles v on v.id = s.vehicle_id
      where s.company_id = p_company_id
    ), '[]'::jsonb)
  );
end;
$$;

create or replace function public.upsert_service_schedule(
  p_vehicle_id uuid,
  p_name text,
  p_due_date date default null,
  p_due_odometer_km integer default null,
  p_repeat_months integer default null,
  p_repeat_km integer default null,
  p_notify_days_before integer default 7,
  p_schedule_id uuid default null
)
returns uuid
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_vehicle public.fleet_vehicles;
  v_id uuid;
begin
  select * into v_vehicle from public.fleet_vehicles where id = p_vehicle_id;
  if not found then raise exception 'Vehicle not found'; end if;
  if not public.can_manage_fleet(v_vehicle.company_id) then
    raise exception 'Only the fleet managers may manage service schedules';
  end if;
  if p_due_date is null and p_due_odometer_km is null then
    raise exception 'A schedule needs a due date and/or a due odometer';
  end if;

  if p_schedule_id is null then
    insert into public.fleet_service_schedules (
      company_id, vehicle_id, name, due_date, due_odometer_km,
      repeat_months, repeat_km, notify_days_before
    ) values (
      v_vehicle.company_id, p_vehicle_id, trim(p_name), p_due_date, p_due_odometer_km,
      p_repeat_months, p_repeat_km, coalesce(p_notify_days_before, 7)
    ) returning id into v_id;
  else
    update public.fleet_service_schedules
    set vehicle_id = p_vehicle_id,
        name = trim(p_name),
        due_date = p_due_date,
        due_odometer_km = p_due_odometer_km,
        repeat_months = p_repeat_months,
        repeat_km = p_repeat_km,
        notify_days_before = coalesce(p_notify_days_before, 7),
        last_notified_at = null,
        updated_at = now()
    where id = p_schedule_id and company_id = v_vehicle.company_id
    returning id into v_id;
    if v_id is null then raise exception 'Schedule not found'; end if;
  end if;
  return v_id;
end;
$$;

create or replace function public.set_service_schedule_active(p_schedule_id uuid, p_active boolean)
returns void
language plpgsql
security definer
set search_path to 'public'
as $$
declare v_company uuid;
begin
  select company_id into v_company from public.fleet_service_schedules where id = p_schedule_id;
  if v_company is null then raise exception 'Schedule not found'; end if;
  if not public.can_manage_fleet(v_company) then
    raise exception 'Only the fleet managers may manage service schedules';
  end if;
  update public.fleet_service_schedules
  set active = p_active, updated_at = now()
  where id = p_schedule_id;
end;
$$;

create or replace function public.complete_service_schedule(
  p_schedule_id uuid,
  p_cost_zar numeric default null,
  p_odometer_km integer default null,
  p_notes text default null
)
returns void
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_s public.fleet_service_schedules;
begin
  select * into v_s from public.fleet_service_schedules where id = p_schedule_id;
  if not found then raise exception 'Schedule not found'; end if;
  if not public.can_manage_fleet(v_s.company_id) then
    raise exception 'Only the fleet managers may log services';
  end if;

  -- The log entry: a closed 'service' record (no downtime by default).
  insert into public.fleet_maintenance_records (
    company_id, vehicle_id, kind, title, notes, takes_out_of_service,
    status, started_at, closed_at, closed_by, cost_zar, odometer_km
  ) values (
    v_s.company_id, v_s.vehicle_id, 'service', v_s.name, p_notes, false,
    'closed', now(), now(), auth.uid(), p_cost_zar, p_odometer_km
  );

  -- Roll the schedule forward, or deactivate a one-off.
  if v_s.repeat_months is not null or v_s.repeat_km is not null then
    update public.fleet_service_schedules
    set due_date = case when repeat_months is not null and due_date is not null
                        then due_date + make_interval(months => repeat_months)
                        else due_date end,
        due_odometer_km = case when repeat_km is not null and due_odometer_km is not null
                               then due_odometer_km + repeat_km
                               else due_odometer_km end,
        last_done_at = now(),
        last_notified_at = null,
        updated_at = now()
    where id = p_schedule_id;
  else
    update public.fleet_service_schedules
    set active = false, last_done_at = now(), updated_at = now()
    where id = p_schedule_id;
  end if;
end;
$$;

-- 6. Daily due-service reminders (pg_cron) -----------------------------------
-- Internal job (runs as postgres); NOT granted to client roles.

create or replace function public.notify_service_due_job()
returns integer
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_s record;
  v_count integer := 0;
begin
  for v_s in
    select s.*, v.vehicle_registration_number as reg, v.vehicle_odometer_km as odo
    from public.fleet_service_schedules s
    join public.fleet_vehicles v on v.id = s.vehicle_id
    where s.active
      and (s.last_notified_at is null or s.last_notified_at < now() - interval '6 days')
      and (
        (s.due_date is not null
          and s.due_date - make_interval(days => s.notify_days_before) <= now())
        or (s.due_odometer_km is not null and v.vehicle_odometer_km is not null
          and v.vehicle_odometer_km >= s.due_odometer_km - 500)
      )
  loop
    perform public.notify_company_management(
      v_s.company_id,
      'Service due soon',
      format('%s — "%s" is due%s%s. Schedule the service and log it under Maintenance.',
        coalesce(v_s.reg, 'Vehicle'), v_s.name,
        case when v_s.due_date is not null then ' by ' || to_char(v_s.due_date, 'DD Mon YYYY') else '' end,
        case when v_s.due_odometer_km is not null then ' at ' || v_s.due_odometer_km || ' km' else '' end),
      'general',
      null, null, 'high',
      jsonb_build_object('vehicle_id', v_s.vehicle_id, 'service_schedule_id', v_s.id,
        'nav_tab', 'Maintenance')
    );
    update public.fleet_service_schedules
    set last_notified_at = now() where id = v_s.id;
    v_count := v_count + 1;
  end loop;
  return v_count;
end;
$$;

-- Schedule daily at 04:10 UTC (idempotent re-schedule).
do $$
begin
  perform cron.unschedule(jobid) from cron.job where jobname = 'notify-service-due';
exception when others then null;
end $$;
select cron.schedule('notify-service-due', '10 4 * * *', 'select public.notify_service_due_job()');

-- 7. Function privileges (default privileges no longer grant PUBLIC) ---------
revoke all on function public.open_maintenance_record(uuid, text, text, text, boolean, timestamptz, numeric, integer) from public;
revoke all on function public.close_maintenance_record(uuid, text, numeric, integer) from public;
revoke all on function public.list_fleet_maintenance(uuid) from public;
revoke all on function public.upsert_service_schedule(uuid, text, date, integer, integer, integer, integer, uuid) from public;
revoke all on function public.set_service_schedule_active(uuid, boolean) from public;
revoke all on function public.complete_service_schedule(uuid, numeric, integer, text) from public;
revoke all on function public.notify_service_due_job() from public;
grant execute on function public.open_maintenance_record(uuid, text, text, text, boolean, timestamptz, numeric, integer) to authenticated;
grant execute on function public.close_maintenance_record(uuid, text, numeric, integer) to authenticated;
grant execute on function public.list_fleet_maintenance(uuid) to authenticated;
grant execute on function public.upsert_service_schedule(uuid, text, date, integer, integer, integer, integer, uuid) to authenticated;
grant execute on function public.set_service_schedule_active(uuid, boolean) to authenticated;
grant execute on function public.complete_service_schedule(uuid, numeric, integer, text) to authenticated;

-- 8. Realtime -----------------------------------------------------------------
do $$
begin
  if not exists (select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public'
      and tablename = 'fleet_maintenance_records') then
    alter publication supabase_realtime add table public.fleet_maintenance_records;
  end if;
  if not exists (select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public'
      and tablename = 'fleet_service_schedules') then
    alter publication supabase_realtime add table public.fleet_service_schedules;
  end if;
end $$;

commit;
