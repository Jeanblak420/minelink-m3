-- Multi-driver per truck (CLAUDE.md §4 "Transporter admin: accept route →
-- allocate fleet & drivers" — driver-per-truck rule).
--
-- Replaces the single embedded driver per vehicle with a `driver_assignments`
-- table (a driver rides at most one truck; a truck carries up to
-- `fleet_vehicles.max_drivers`, default 2 for long-distance). The transporter
-- admin can ask the super-admin to raise a truck's limit (max 5) via
-- `driver_limit_requests`.
--
-- The legacy embedded driver_* columns on fleet_vehicles stay as a mirror of
-- the PRIMARY (oldest-assigned) driver so waybills and older reads keep
-- working; `sync_vehicle_primary_driver` maintains them and every write path
-- goes through the RPCs below.
--
-- Driver availability is DERIVED, like trucks: a driver is "On Route" while
-- their assigned truck has an active trip — no stored status column.

begin;

-- 1. Assignments -------------------------------------------------------------

create table if not exists public.driver_assignments (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete cascade,
  vehicle_id uuid not null references public.fleet_vehicles(id) on delete cascade,
  driver_employee_id uuid not null references public.employees(id) on delete cascade,
  assigned_by uuid,
  created_at timestamptz not null default timezone('utc', now()),
  -- A driver can be on at most one truck at a time.
  constraint driver_assignments_one_truck_per_driver unique (driver_employee_id)
);

create index if not exists driver_assignments_vehicle_idx
  on public.driver_assignments (vehicle_id);

alter table public.driver_assignments enable row level security;

drop policy if exists driver_assignments_select on public.driver_assignments;
create policy driver_assignments_select
on public.driver_assignments
for select
to authenticated
using (public.is_company_staff(company_id) or public.is_platform_admin());
-- Writes go through the SECURITY DEFINER RPCs only (no write policies).

-- 2. Per-truck driver limit ---------------------------------------------------

alter table public.fleet_vehicles
  add column if not exists max_drivers integer not null default 2;

do $$
begin
  alter table public.fleet_vehicles
    add constraint fleet_vehicles_max_drivers_range
    check (max_drivers between 1 and 5);
exception
  when duplicate_object then null;
end $$;

-- 3. Backfill the existing embedded driver as each truck's first assignment.

insert into public.driver_assignments (company_id, vehicle_id, driver_employee_id)
select v.company_id, v.id, v.assigned_driver_employee_id
from public.fleet_vehicles v
where v.assigned_driver_employee_id is not null
on conflict (driver_employee_id) do nothing;

-- 4. Mirror maintenance (internal — not callable by clients).

create or replace function public.sync_vehicle_primary_driver(p_vehicle_id uuid)
returns void
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  d public.employees;
begin
  select e.* into d
  from public.driver_assignments da
  join public.employees e on e.id = da.driver_employee_id
  where da.vehicle_id = p_vehicle_id
  order by da.created_at asc
  limit 1;

  if d.id is null then
    update public.fleet_vehicles set
      assigned_driver_employee_id = null,
      driver_user_id = null,
      driver_first_name = null,
      driver_last_name = null,
      driver_id_number = null,
      driver_passport_number = null,
      driver_work_permit = null,
      drivers_license_document = null,
      driver_id_document_url = null,
      driver_passport_document_url = null,
      driver_work_visa_document_url = null,
      driver_license_document_url = null,
      driver_is_south_african_citizen = null
    where id = p_vehicle_id;
  else
    update public.fleet_vehicles set
      assigned_driver_employee_id = d.id,
      driver_user_id = d.user_id,
      driver_first_name = d.first_name,
      driver_last_name = d.last_name,
      driver_id_number = d.id_number,
      driver_passport_number = d.passport_or_workers_permit,
      driver_work_permit = d.passport_or_workers_permit,
      drivers_license_document = d.license_document,
      driver_id_document_url = d.id_document_url,
      driver_passport_document_url = d.passport_document_url,
      driver_work_visa_document_url = d.work_visa_document_url,
      driver_license_document_url = d.license_document_url,
      driver_is_south_african_citizen = d.is_south_african_citizen
    where id = p_vehicle_id;
  end if;
end;
$$;

revoke all on function public.sync_vehicle_primary_driver(uuid) from public;
revoke all on function public.sync_vehicle_primary_driver(uuid) from anon;
revoke all on function public.sync_vehicle_primary_driver(uuid) from authenticated;

-- 5. Add a driver to a truck (cap-checked). -----------------------------------

create or replace function public.add_vehicle_driver(
  target_vehicle_id uuid,
  target_driver_employee_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  vehicle_record public.fleet_vehicles;
  driver_record public.employees;
  company_record public.companies;
  current_count integer;
  actor_name text;
begin
  select * into vehicle_record from public.fleet_vehicles where id = target_vehicle_id;
  if vehicle_record.id is null then
    raise exception 'Fleet vehicle not found';
  end if;

  if not public.can_manage_fleet(vehicle_record.company_id) then
    raise exception 'Not authorized to manage this fleet';
  end if;

  select * into driver_record from public.employees where id = target_driver_employee_id;
  if driver_record.id is null then
    raise exception 'Driver not found';
  end if;
  if driver_record.company_id is distinct from vehicle_record.company_id then
    raise exception 'Driver must belong to the same company as the vehicle';
  end if;
  if driver_record.role is distinct from 'driver' or driver_record.status is distinct from 'active' then
    raise exception 'Selected employee is not an active driver';
  end if;

  if exists (
    select 1 from public.driver_assignments da
    where da.driver_employee_id = target_driver_employee_id
      and da.vehicle_id <> target_vehicle_id
  ) then
    raise exception 'Driver is already assigned to another vehicle';
  end if;

  select count(*) into current_count
  from public.driver_assignments da
  where da.vehicle_id = target_vehicle_id;

  if not exists (
    select 1 from public.driver_assignments da
    where da.vehicle_id = target_vehicle_id
      and da.driver_employee_id = target_driver_employee_id
  ) then
    if current_count >= vehicle_record.max_drivers then
      raise exception 'Driver limit reached for % (max % drivers). Request an increase from the MineLink admin.',
        vehicle_record.vehicle_registration_number, vehicle_record.max_drivers;
    end if;

    insert into public.driver_assignments (company_id, vehicle_id, driver_employee_id, assigned_by)
    values (vehicle_record.company_id, target_vehicle_id, target_driver_employee_id, auth.uid());
  end if;

  perform public.sync_vehicle_primary_driver(target_vehicle_id);
  select * into vehicle_record from public.fleet_vehicles where id = target_vehicle_id;
  select * into company_record from public.companies where id = vehicle_record.company_id;

  actor_name := coalesce((select display_name from public.profiles where id = auth.uid()), 'Fleet Manager');

  perform public.notify_company_management(
    vehicle_record.company_id,
    'Driver Assigned',
    actor_name || ' assigned ' || driver_record.first_name || ' ' || driver_record.last_name
      || ' to vehicle ' || vehicle_record.vehicle_registration_number || '.',
    'fleetDriverAssigned',
    actor_name,
    auth.uid(),
    'normal',
    jsonb_build_object(
      'vehicle_id', vehicle_record.id,
      'vehicle_registration_number', vehicle_record.vehicle_registration_number,
      'driver_id', driver_record.id,
      'driver_name', driver_record.first_name || ' ' || driver_record.last_name
    )
  );

  perform public.create_notification_internal(
    driver_record.user_id,
    vehicle_record.company_id,
    driver_record.id,
    'Vehicle Assignment',
    'You have been assigned to vehicle ' || vehicle_record.vehicle_registration_number || '.',
    'fleetDriverAssigned',
    actor_name,
    auth.uid(),
    'driver',
    company_record.org_type,
    'high',
    jsonb_build_object(
      'vehicle_id', vehicle_record.id,
      'vehicle_registration_number', vehicle_record.vehicle_registration_number
    )
  );

  return to_jsonb(vehicle_record);
end;
$$;

revoke all on function public.add_vehicle_driver(uuid, uuid) from public;
revoke all on function public.add_vehicle_driver(uuid, uuid) from anon;
grant execute on function public.add_vehicle_driver(uuid, uuid) to authenticated;

-- 6. Remove one driver from a truck. ------------------------------------------

create or replace function public.remove_vehicle_driver(
  target_vehicle_id uuid,
  target_driver_employee_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  vehicle_record public.fleet_vehicles;
  driver_record public.employees;
  company_record public.companies;
  actor_name text;
  driver_name text;
begin
  select * into vehicle_record from public.fleet_vehicles where id = target_vehicle_id;
  if vehicle_record.id is null then
    raise exception 'Fleet vehicle not found';
  end if;

  if not public.can_manage_fleet(vehicle_record.company_id) then
    raise exception 'Not authorized to manage this fleet';
  end if;

  select * into driver_record from public.employees where id = target_driver_employee_id;

  delete from public.driver_assignments
  where vehicle_id = target_vehicle_id
    and driver_employee_id = target_driver_employee_id;

  perform public.sync_vehicle_primary_driver(target_vehicle_id);
  select * into vehicle_record from public.fleet_vehicles where id = target_vehicle_id;
  select * into company_record from public.companies where id = vehicle_record.company_id;

  actor_name := coalesce((select display_name from public.profiles where id = auth.uid()), 'Fleet Manager');
  driver_name := trim(coalesce(driver_record.first_name, '') || ' ' || coalesce(driver_record.last_name, ''));

  perform public.notify_company_management(
    vehicle_record.company_id,
    'Driver Unassigned',
    actor_name || ' unassigned ' || coalesce(nullif(driver_name, ''), 'a driver')
      || ' from vehicle ' || vehicle_record.vehicle_registration_number || '.',
    'fleetDriverUnassigned',
    actor_name,
    auth.uid(),
    'normal',
    jsonb_build_object(
      'vehicle_id', vehicle_record.id,
      'vehicle_registration_number', vehicle_record.vehicle_registration_number,
      'driver_id', target_driver_employee_id,
      'driver_name', driver_name
    )
  );

  if driver_record.user_id is not null then
    perform public.create_notification_internal(
      driver_record.user_id,
      vehicle_record.company_id,
      driver_record.id,
      'Vehicle Assignment Removed',
      'You have been unassigned from vehicle ' || vehicle_record.vehicle_registration_number || '.',
      'fleetDriverUnassigned',
      actor_name,
      auth.uid(),
      'driver',
      company_record.org_type,
      'high',
      jsonb_build_object(
        'vehicle_id', vehicle_record.id,
        'vehicle_registration_number', vehicle_record.vehicle_registration_number
      )
    );
  end if;

  return to_jsonb(vehicle_record);
end;
$$;

revoke all on function public.remove_vehicle_driver(uuid, uuid) from public;
revoke all on function public.remove_vehicle_driver(uuid, uuid) from anon;
grant execute on function public.remove_vehicle_driver(uuid, uuid) to authenticated;

-- 7. Legacy RPCs now delegate so no write path bypasses the table. ------------

create or replace function public.assign_fleet_driver(
  target_vehicle_id uuid,
  target_driver_employee_id uuid
)
returns jsonb
language sql
security definer
set search_path to 'public'
as $$
  select public.add_vehicle_driver(target_vehicle_id, target_driver_employee_id);
$$;

-- unassign_fleet_driver(vehicle) now clears EVERY driver from the truck.
create or replace function public.unassign_fleet_driver(target_vehicle_id uuid)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  vehicle_record public.fleet_vehicles;
  assignment record;
  result jsonb;
begin
  select * into vehicle_record from public.fleet_vehicles where id = target_vehicle_id;
  if vehicle_record.id is null then
    raise exception 'Fleet vehicle not found';
  end if;
  if not public.can_manage_fleet(vehicle_record.company_id) then
    raise exception 'Not authorized to manage this fleet';
  end if;

  result := to_jsonb(vehicle_record);
  for assignment in
    select driver_employee_id from public.driver_assignments
    where vehicle_id = target_vehicle_id
  loop
    result := public.remove_vehicle_driver(target_vehicle_id, assignment.driver_employee_id);
  end loop;

  return result;
end;
$$;

-- 8. Driver listing (assignments + derived On-Route status). ------------------

create or replace function public.list_vehicle_drivers(p_company_id uuid)
returns table (
  assignment_id uuid,
  vehicle_id uuid,
  registration text,
  driver_employee_id uuid,
  driver_name text,
  on_route boolean,
  assigned_at timestamptz
)
language sql
stable
security definer
set search_path to 'public'
as $$
  select
    da.id,
    da.vehicle_id,
    v.vehicle_registration_number,
    da.driver_employee_id,
    nullif(trim(coalesce(e.first_name, '') || ' ' || coalesce(e.last_name, '')), ''),
    exists (
      select 1 from public.trips t
      where t.vehicle_id = da.vehicle_id
        and t.status not in ('completed', 'cancelled')
    ) as on_route,
    da.created_at
  from public.driver_assignments da
  join public.fleet_vehicles v on v.id = da.vehicle_id
  join public.employees e on e.id = da.driver_employee_id
  where da.company_id = p_company_id
    and public.is_company_staff(p_company_id)
  order by v.vehicle_registration_number, da.created_at;
$$;

revoke all on function public.list_vehicle_drivers(uuid) from public;
revoke all on function public.list_vehicle_drivers(uuid) from anon;
grant execute on function public.list_vehicle_drivers(uuid) to authenticated;

-- 9. Fleet status now aggregates every assigned driver. -----------------------
-- Return type changes, so drop + recreate.

drop function if exists public.list_transporter_fleet_status(uuid);

create function public.list_transporter_fleet_status(p_company_id uuid)
returns table (
  vehicle_id uuid,
  registration text,
  make text,
  vehicle_type text,
  driver_employee_id uuid,
  driver_name text,
  drivers text,
  driver_count integer,
  max_drivers integer,
  is_active boolean,
  on_route boolean,
  active_trip_id uuid,
  trip_status text,
  buyer_name text,
  commodity text,
  offloading_point text,
  loading_point text
)
language sql
stable
security definer
set search_path to 'public'
as $function$
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
    coalesce(txn.metadata->>'loading_point', '')
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
  where v.company_id = p_company_id
    and public.is_company_staff(p_company_id)
  order by (t.id is not null), v.vehicle_registration_number;
$function$;

revoke all on function public.list_transporter_fleet_status(uuid) from public;
revoke all on function public.list_transporter_fleet_status(uuid) from anon;
grant execute on function public.list_transporter_fleet_status(uuid) to authenticated;

-- 10. Driver-limit raise requests (approvable by the super-admin, max 5). ------

create table if not exists public.driver_limit_requests (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete cascade,
  vehicle_id uuid not null references public.fleet_vehicles(id) on delete cascade,
  requested_limit integer not null check (requested_limit between 3 and 5),
  status text not null default 'pending' check (status in ('pending', 'approved', 'declined')),
  requested_by uuid,
  decided_by uuid,
  decided_at timestamptz,
  created_at timestamptz not null default timezone('utc', now())
);

create unique index if not exists driver_limit_requests_pending_unique
  on public.driver_limit_requests (vehicle_id)
  where status = 'pending';

alter table public.driver_limit_requests enable row level security;

drop policy if exists driver_limit_requests_select on public.driver_limit_requests;
create policy driver_limit_requests_select
on public.driver_limit_requests
for select
to authenticated
using (public.is_company_staff(company_id) or public.is_platform_admin());

create or replace function public.request_driver_limit(
  p_vehicle_id uuid,
  p_new_limit integer
)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  vehicle_record public.fleet_vehicles;
  request_record public.driver_limit_requests;
begin
  select * into vehicle_record from public.fleet_vehicles where id = p_vehicle_id;
  if vehicle_record.id is null then
    raise exception 'Fleet vehicle not found';
  end if;
  if not public.can_manage_fleet(vehicle_record.company_id) then
    raise exception 'Not authorized to manage this fleet';
  end if;
  if p_new_limit is null or p_new_limit < 3 or p_new_limit > 5 then
    raise exception 'Requested driver limit must be between 3 and 5';
  end if;
  if p_new_limit <= vehicle_record.max_drivers then
    raise exception 'This truck already allows % drivers', vehicle_record.max_drivers;
  end if;
  if exists (
    select 1 from public.driver_limit_requests r
    where r.vehicle_id = p_vehicle_id and r.status = 'pending'
  ) then
    raise exception 'A driver-limit request for % is already awaiting the MineLink admin',
      vehicle_record.vehicle_registration_number;
  end if;

  insert into public.driver_limit_requests (company_id, vehicle_id, requested_limit, requested_by)
  values (vehicle_record.company_id, p_vehicle_id, p_new_limit, auth.uid())
  returning * into request_record;

  return to_jsonb(request_record);
end;
$$;

revoke all on function public.request_driver_limit(uuid, integer) from public;
revoke all on function public.request_driver_limit(uuid, integer) from anon;
grant execute on function public.request_driver_limit(uuid, integer) to authenticated;

create or replace function public.list_driver_limit_requests()
returns table (
  id uuid,
  company_id uuid,
  company_name text,
  vehicle_id uuid,
  registration text,
  current_limit integer,
  requested_limit integer,
  status text,
  requested_by_name text,
  created_at timestamptz,
  decided_at timestamptz
)
language sql
stable
security definer
set search_path to 'public'
as $$
  select
    r.id,
    r.company_id,
    c.company_name,
    r.vehicle_id,
    v.vehicle_registration_number,
    v.max_drivers,
    r.requested_limit,
    r.status,
    coalesce(p.display_name, '—'),
    r.created_at,
    r.decided_at
  from public.driver_limit_requests r
  join public.companies c on c.id = r.company_id
  join public.fleet_vehicles v on v.id = r.vehicle_id
  left join public.profiles p on p.id = r.requested_by
  where public.is_platform_admin()
  order by (r.status = 'pending') desc, r.created_at desc;
$$;

revoke all on function public.list_driver_limit_requests() from public;
revoke all on function public.list_driver_limit_requests() from anon;
grant execute on function public.list_driver_limit_requests() to authenticated;

create or replace function public.decide_driver_limit_request(
  p_id uuid,
  p_approve boolean
)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  request_record public.driver_limit_requests;
  vehicle_record public.fleet_vehicles;
begin
  if not public.is_platform_admin() then
    raise exception 'Only the platform admin may decide driver-limit requests';
  end if;

  select * into request_record from public.driver_limit_requests where id = p_id;
  if request_record.id is null then
    raise exception 'Driver-limit request not found';
  end if;
  if request_record.status <> 'pending' then
    raise exception 'This request has already been decided';
  end if;

  select * into vehicle_record from public.fleet_vehicles where id = request_record.vehicle_id;

  if p_approve then
    update public.fleet_vehicles
    set max_drivers = least(request_record.requested_limit, 5)
    where id = request_record.vehicle_id;
  end if;

  update public.driver_limit_requests
  set status = case when p_approve then 'approved' else 'declined' end,
      decided_by = auth.uid(),
      decided_at = timezone('utc', now())
  where id = p_id
  returning * into request_record;

  -- Best-effort: tell the transporter's management. Never fail the decision.
  begin
    perform public.notify_company_management(
      request_record.company_id,
      case when p_approve then 'Driver limit increased' else 'Driver limit request declined' end,
      case when p_approve
        then 'Vehicle ' || coalesce(vehicle_record.vehicle_registration_number, '—')
          || ' may now carry up to ' || request_record.requested_limit || ' drivers.'
        else 'Your request to raise the driver limit on vehicle '
          || coalesce(vehicle_record.vehicle_registration_number, '—') || ' was declined.'
      end,
      'fleetDriverLimit',
      null,
      auth.uid(),
      'normal',
      jsonb_build_object(
        'vehicle_id', request_record.vehicle_id,
        'requested_limit', request_record.requested_limit,
        'approved', p_approve
      )
    );
  exception when others then
    null;
  end;

  return to_jsonb(request_record);
end;
$$;

revoke all on function public.decide_driver_limit_request(uuid, boolean) from public;
revoke all on function public.decide_driver_limit_request(uuid, boolean) from anon;
grant execute on function public.decide_driver_limit_request(uuid, boolean) to authenticated;

commit;
