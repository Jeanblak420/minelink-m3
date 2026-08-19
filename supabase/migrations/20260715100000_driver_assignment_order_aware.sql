-- Make the driver's assignment notification order-aware: when the truck the
-- driver is assigned to already has a trip for a dispatched order, tell the
-- driver what to collect and where, and deep-link them to "My routes". Falls
-- back to the plain "assigned to vehicle X" message when there's no order yet.
-- Everything else in add_vehicle_driver is unchanged.
create or replace function public.add_vehicle_driver(target_vehicle_id uuid, target_driver_employee_id uuid)
 returns jsonb
 language plpgsql
 security definer
 set search_path to 'public'
as $function$
declare
  vehicle_record public.fleet_vehicles;
  driver_record public.employees;
  company_record public.companies;
  current_count integer;
  actor_name text;
  v_order record;
  v_drv_msg text;
  v_drv_meta jsonb;
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

  -- Order-aware driver notification: pull the truck's current order (if any).
  select r.commodity, r.loading_point, r.offloading_point, r.request_id, r.id as route_id
  into v_order
  from public.trips t
  join public.routes r on r.id = t.route_id
  where t.vehicle_id = target_vehicle_id
    and coalesce(t.status, '') not in ('completed', 'cancelled')
  order by t.created_at desc
  limit 1;

  if v_order.route_id is not null then
    v_drv_msg := 'You have been assigned to truck ' || vehicle_record.vehicle_registration_number
      || ' to collect ' || coalesce(v_order.commodity, 'product')
      || case when v_order.loading_point is not null then ' from ' || v_order.loading_point else '' end
      || case when v_order.offloading_point is not null then ' -> ' || v_order.offloading_point else '' end
      || '. Check "My routes" - collect once a full load is ready on the stockpile.';
    v_drv_meta := jsonb_build_object(
      'vehicle_id', vehicle_record.id,
      'vehicle_registration_number', vehicle_record.vehicle_registration_number,
      'route_id', v_order.route_id,
      'request_id', v_order.request_id,
      'nav_tab', 'My routes');
  else
    v_drv_msg := 'You have been assigned to vehicle ' || vehicle_record.vehicle_registration_number
      || '. Your routes and loads will appear under "My routes".';
    v_drv_meta := jsonb_build_object(
      'vehicle_id', vehicle_record.id,
      'vehicle_registration_number', vehicle_record.vehicle_registration_number,
      'nav_tab', 'My routes');
  end if;

  perform public.create_notification_internal(
    driver_record.user_id,
    vehicle_record.company_id,
    driver_record.id,
    'Vehicle Assignment',
    v_drv_msg,
    'fleetDriverAssigned',
    actor_name,
    auth.uid(),
    'driver',
    company_record.org_type,
    'high',
    v_drv_meta
  );

  return to_jsonb(vehicle_record);
end;
$function$;
