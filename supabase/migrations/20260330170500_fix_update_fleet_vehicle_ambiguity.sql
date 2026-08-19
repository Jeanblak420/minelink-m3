create or replace function public.update_fleet_vehicle(
  target_vehicle_id uuid,
  vehicle_registration_number text default null,
  vehicle_registration_expiry_date timestamptz default null,
  first_trailer_regs text default null,
  second_trailer_regs text default null,
  is_active boolean default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  vehicle_record public.fleet_vehicles;
  actor_name text;
  next_vehicle_registration_number text := nullif(
    trim(coalesce(update_fleet_vehicle.vehicle_registration_number, '')),
    ''
  );
  next_vehicle_registration_expiry_date timestamptz :=
    update_fleet_vehicle.vehicle_registration_expiry_date;
  next_first_trailer_regs text := update_fleet_vehicle.first_trailer_regs;
  next_second_trailer_regs text := update_fleet_vehicle.second_trailer_regs;
  next_is_active boolean := update_fleet_vehicle.is_active;
begin
  select * into vehicle_record from public.fleet_vehicles where id = target_vehicle_id;
  if vehicle_record.id is null then
    raise exception 'Fleet vehicle not found';
  end if;

  if not public.can_manage_fleet(vehicle_record.company_id) then
    raise exception 'Not authorized to manage this fleet';
  end if;

  update public.fleet_vehicles
  set
    vehicle_registration_number = coalesce(
      next_vehicle_registration_number,
      public.fleet_vehicles.vehicle_registration_number
    ),
    vehicle_registration_expiry_date = coalesce(
      next_vehicle_registration_expiry_date,
      public.fleet_vehicles.vehicle_registration_expiry_date
    ),
    first_trailer_regs = coalesce(
      next_first_trailer_regs,
      public.fleet_vehicles.first_trailer_regs
    ),
    second_trailer_regs = coalesce(
      next_second_trailer_regs,
      public.fleet_vehicles.second_trailer_regs
    ),
    is_active = coalesce(next_is_active, public.fleet_vehicles.is_active)
  where id = target_vehicle_id
  returning *
  into vehicle_record;

  if next_is_active is not null then
    actor_name := coalesce((select display_name from public.profiles where id = auth.uid()), 'Fleet Manager');

    perform public.notify_company_management(
      vehicle_record.company_id,
      case when vehicle_record.is_active then 'Vehicle Activated' else 'Vehicle Deactivated' end,
      actor_name || ' marked vehicle ' || vehicle_record.vehicle_registration_number || ' as ' || case when vehicle_record.is_active then 'active' else 'inactive' end || '.',
      'fleetVehicleStatusChanged',
      actor_name,
      auth.uid(),
      'normal',
      jsonb_build_object(
        'vehicle_id',
        vehicle_record.id,
        'vehicle_registration_number',
        vehicle_record.vehicle_registration_number,
        'is_active',
        vehicle_record.is_active
      )
    );
  end if;

  return to_jsonb(vehicle_record);
end;
$$;
