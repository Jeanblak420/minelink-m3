-- Vehicle identity fields: make, type, year model, odometer (km).

alter table public.fleet_vehicles
  add column if not exists vehicle_make text,
  add column if not exists vehicle_type text,
  add column if not exists vehicle_year_model smallint,
  add column if not exists vehicle_odometer_km integer;

comment on column public.fleet_vehicles.vehicle_make is 'Manufacturer / brand, e.g. Opel';
comment on column public.fleet_vehicles.vehicle_type is 'Model line, e.g. Astra J';
comment on column public.fleet_vehicles.vehicle_year_model is 'Model year, e.g. 2018';
comment on column public.fleet_vehicles.vehicle_odometer_km is 'Latest odometer reading in kilometres';

drop function if exists public.create_fleet_vehicle(uuid, text, timestamptz, text, text);
drop function if exists public.update_fleet_vehicle(uuid, text, timestamptz, text, text, boolean);

create or replace function public.create_fleet_vehicle(
  target_company_id uuid,
  vehicle_registration_number text,
  vehicle_registration_expiry_date timestamptz default null,
  first_trailer_regs text default null,
  second_trailer_regs text default null,
  vehicle_make text default null,
  vehicle_type text default null,
  vehicle_year_model smallint default null,
  vehicle_odometer_km integer default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  vehicle_record public.fleet_vehicles;
  actor_name text;
begin
  if not public.can_manage_fleet(target_company_id) then
    raise exception 'Not authorized to manage this fleet';
  end if;

  insert into public.fleet_vehicles (
    company_id,
    vehicle_registration_number,
    vehicle_registration_expiry_date,
    first_trailer_regs,
    second_trailer_regs,
    vehicle_make,
    vehicle_type,
    vehicle_year_model,
    vehicle_odometer_km
  )
  values (
    target_company_id,
    trim(vehicle_registration_number),
    vehicle_registration_expiry_date,
    nullif(trim(coalesce(first_trailer_regs, '')), ''),
    nullif(trim(coalesce(second_trailer_regs, '')), ''),
    nullif(trim(coalesce(vehicle_make, '')), ''),
    nullif(trim(coalesce(vehicle_type, '')), ''),
    vehicle_year_model,
    vehicle_odometer_km
  )
  returning *
  into vehicle_record;

  actor_name := coalesce((select display_name from public.profiles where id = auth.uid()), 'Fleet Manager');

  perform public.notify_company_management(
    target_company_id,
    'Vehicle Added',
    actor_name || ' added vehicle ' || vehicle_record.vehicle_registration_number || ' to the fleet.',
    'fleetVehicleAdded',
    actor_name,
    auth.uid(),
    'normal',
    jsonb_build_object('vehicle_id', vehicle_record.id, 'vehicle_registration_number', vehicle_record.vehicle_registration_number)
  );

  return to_jsonb(vehicle_record);
end;
$$;

create or replace function public.update_fleet_vehicle(
  target_vehicle_id uuid,
  vehicle_registration_number text default null,
  vehicle_registration_expiry_date timestamptz default null,
  first_trailer_regs text default null,
  second_trailer_regs text default null,
  is_active boolean default null,
  vehicle_make text default null,
  vehicle_type text default null,
  vehicle_year_model smallint default null,
  vehicle_odometer_km integer default null,
  clear_vehicle_make boolean default false,
  clear_vehicle_type boolean default false,
  clear_vehicle_year_model boolean default false,
  clear_vehicle_odometer_km boolean default false
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
  next_vehicle_make text := nullif(trim(coalesce(update_fleet_vehicle.vehicle_make, '')), '');
  next_vehicle_type text := nullif(trim(coalesce(update_fleet_vehicle.vehicle_type, '')), '');
  next_vehicle_year_model smallint := update_fleet_vehicle.vehicle_year_model;
  next_vehicle_odometer_km integer := update_fleet_vehicle.vehicle_odometer_km;
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
    first_trailer_regs = case
      when next_first_trailer_regs is not null then nullif(trim(next_first_trailer_regs), '')
      else public.fleet_vehicles.first_trailer_regs
    end,
    second_trailer_regs = case
      when next_second_trailer_regs is not null then nullif(trim(next_second_trailer_regs), '')
      else public.fleet_vehicles.second_trailer_regs
    end,
    is_active = coalesce(next_is_active, public.fleet_vehicles.is_active),
    vehicle_make = case
      when clear_vehicle_make then null
      when next_vehicle_make is not null then next_vehicle_make
      else public.fleet_vehicles.vehicle_make
    end,
    vehicle_type = case
      when clear_vehicle_type then null
      when next_vehicle_type is not null then next_vehicle_type
      else public.fleet_vehicles.vehicle_type
    end,
    vehicle_year_model = case
      when clear_vehicle_year_model then null
      when next_vehicle_year_model is not null then next_vehicle_year_model
      else public.fleet_vehicles.vehicle_year_model
    end,
    vehicle_odometer_km = case
      when clear_vehicle_odometer_km then null
      when next_vehicle_odometer_km is not null then next_vehicle_odometer_km
      else public.fleet_vehicles.vehicle_odometer_km
    end
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

grant execute on function public.create_fleet_vehicle(
  uuid, text, timestamptz, text, text, text, text, smallint, integer
) to authenticated;

grant execute on function public.update_fleet_vehicle(
  uuid, text, timestamptz, text, text, boolean, text, text, smallint, integer, boolean, boolean, boolean, boolean
) to authenticated;
