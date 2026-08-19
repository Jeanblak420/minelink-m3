create or replace function public.get_managed_company_id_for_current_user()
returns uuid
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  managed_company_id uuid;
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;

  select c.id
  into managed_company_id
  from public.companies c
  where c.user_id = auth.uid()
  limit 1;

  if managed_company_id is not null then
    return managed_company_id;
  end if;

  select e.company_id
  into managed_company_id
  from public.employees e
  where e.user_id = auth.uid()
    and e.company_id is not null
    and e.status = 'active'
    and e.is_dismissed = false
    and e.role in ('admin', 'management')
  limit 1;

  if managed_company_id is null then
    raise exception 'Not authorized to manage company employees';
  end if;

  return managed_company_id;
end;
$$;

create or replace function public.is_valid_role_for_org(
  target_org_type text,
  target_role text
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select case
    when target_org_type = 'mineSupplier' then target_role in ('security', 'controllerWB', 'admin', 'management')
    when target_org_type = 'buyer' then target_role in ('admin', 'management')
    when target_org_type = 'transporter' then target_role in ('driver', 'admin', 'management')
    else false
  end;
$$;

create or replace function public.create_company_managed_employee(
  target_user_id uuid,
  first_name_input text,
  last_name_input text,
  whatsapp_number_input text,
  target_role text
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  managed_company_id uuid;
  company_record public.companies;
  employee_record public.employees;
  auth_user auth.users;
  actor_name text;
  resolved_display_name text;
begin
  managed_company_id := public.get_managed_company_id_for_current_user();

  select *
  into company_record
  from public.companies
  where id = managed_company_id;

  if company_record.id is null then
    raise exception 'Company not found';
  end if;

  if target_user_id is null then
    raise exception 'Target user is required';
  end if;

  if target_user_id = auth.uid() then
    raise exception 'You cannot add yourself as a managed employee';
  end if;

  if nullif(trim(coalesce(first_name_input, '')), '') is null then
    raise exception 'First name is required';
  end if;

  if nullif(trim(coalesce(last_name_input, '')), '') is null then
    raise exception 'Last name is required';
  end if;

  if nullif(trim(coalesce(whatsapp_number_input, '')), '') is null then
    raise exception 'WhatsApp number is required';
  end if;

  select *
  into auth_user
  from auth.users
  where id = target_user_id;

  if auth_user.id is null then
    raise exception 'Auth user not found';
  end if;

  if exists (
    select 1
    from public.companies c
    where c.user_id = target_user_id
  ) then
    raise exception 'This user already owns a company account';
  end if;

  if exists (
    select 1
    from public.employees e
    where e.user_id = target_user_id
  ) then
    raise exception 'This user already has an employee profile';
  end if;

  if not public.is_valid_role_for_org(company_record.org_type, target_role) then
    raise exception 'Role % is not valid for %', target_role, company_record.org_type;
  end if;

  resolved_display_name := trim(
    coalesce(first_name_input, '') || ' ' || coalesce(last_name_input, '')
  );

  insert into public.profiles (
    id,
    email,
    user_type,
    display_name,
    metadata
  )
  values (
    target_user_id,
    coalesce(auth_user.email, ''),
    'employee',
    resolved_display_name,
    jsonb_build_object(
      'user_type',
      'employee',
      'display_name',
      resolved_display_name
    )
  )
  on conflict (id) do update
  set
    email = coalesce(excluded.email, public.profiles.email),
    user_type = 'employee',
    display_name = excluded.display_name,
    metadata = coalesce(public.profiles.metadata, '{}'::jsonb) ||
      jsonb_build_object(
        'user_type',
        'employee',
        'display_name',
        resolved_display_name
      ),
    updated_at = timezone('utc', now());

  insert into public.employees (
    user_id,
    first_name,
    last_name,
    whatsapp_number,
    company_id,
    role,
    status
  )
  values (
    target_user_id,
    trim(first_name_input),
    trim(last_name_input),
    trim(whatsapp_number_input),
    company_record.id,
    target_role,
    'active'
  )
  returning *
  into employee_record;

  actor_name := coalesce(
    (select display_name from public.profiles where id = auth.uid()),
    company_record.company_name
  );

  insert into public.employee_status_history (
    employee_id,
    company_id,
    status,
    actioned_by_id,
    actioned_by_name,
    assigned_role
  )
  values (
    employee_record.id,
    company_record.id,
    'role_assigned',
    auth.uid(),
    actor_name,
    target_role
  );

  perform public.create_notification_internal(
    employee_record.user_id,
    company_record.id,
    employee_record.id,
    'Role Assigned',
    'Your account has been created and you have been assigned the ' || target_role || ' role at ' || company_record.company_name || '.',
    'roleAssigned',
    actor_name,
    auth.uid(),
    null,
    company_record.org_type,
    'high',
    jsonb_build_object(
      'company_id',
      company_record.id,
      'company_name',
      company_record.company_name,
      'employee_id',
      employee_record.id,
      'role',
      target_role,
      'managed_creation',
      true
    )
  );

  perform public.notify_company_management(
    company_record.id,
    'User Added',
    actor_name || ' added ' || resolved_display_name || ' as ' || target_role || '.',
    'userManagement',
    actor_name,
    auth.uid(),
    'normal',
    jsonb_build_object(
      'employee_id',
      employee_record.id,
      'employee_name',
      resolved_display_name,
      'role',
      target_role,
      'managed_creation',
      true
    )
  );

  return to_jsonb(employee_record);
end;
$$;

create or replace function public.update_company_employee(
  target_employee_id uuid,
  first_name_input text default null,
  last_name_input text default null,
  whatsapp_number_input text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  managed_company_id uuid;
  company_record public.companies;
  employee_record public.employees;
  actor_name text;
  updated_first_name text;
  updated_last_name text;
  updated_whatsapp_number text;
  resolved_display_name text;
begin
  managed_company_id := public.get_managed_company_id_for_current_user();

  select *
  into employee_record
  from public.employees
  where id = target_employee_id;

  if employee_record.id is null then
    raise exception 'Employee not found';
  end if;

  if employee_record.company_id is distinct from managed_company_id then
    raise exception 'Not authorized to update this employee';
  end if;

  select *
  into company_record
  from public.companies
  where id = managed_company_id;

  updated_first_name := coalesce(
    nullif(trim(coalesce(first_name_input, '')), ''),
    employee_record.first_name
  );
  updated_last_name := coalesce(
    nullif(trim(coalesce(last_name_input, '')), ''),
    employee_record.last_name
  );
  updated_whatsapp_number := coalesce(
    nullif(trim(coalesce(whatsapp_number_input, '')), ''),
    employee_record.whatsapp_number
  );
  resolved_display_name := trim(updated_first_name || ' ' || updated_last_name);

  update public.employees
  set
    first_name = updated_first_name,
    last_name = updated_last_name,
    whatsapp_number = updated_whatsapp_number
  where id = target_employee_id
  returning *
  into employee_record;

  update public.profiles
  set
    display_name = resolved_display_name,
    metadata = coalesce(metadata, '{}'::jsonb) ||
      jsonb_build_object('display_name', resolved_display_name),
    updated_at = timezone('utc', now())
  where id = employee_record.user_id;

  actor_name := coalesce(
    (select display_name from public.profiles where id = auth.uid()),
    company_record.company_name
  );

  perform public.create_notification_internal(
    employee_record.user_id,
    company_record.id,
    employee_record.id,
    'Profile Updated',
    'Your company profile details at ' || company_record.company_name || ' were updated.',
    'profileUpdate',
    actor_name,
    auth.uid(),
    null,
    company_record.org_type,
    'normal',
    jsonb_build_object(
      'company_id',
      company_record.id,
      'company_name',
      company_record.company_name,
      'employee_id',
      employee_record.id,
      'employee_name',
      resolved_display_name
    )
  );

  perform public.notify_company_management(
    company_record.id,
    'User Updated',
    actor_name || ' updated ' || resolved_display_name || '''s company details.',
    'userManagement',
    actor_name,
    auth.uid(),
    'normal',
    jsonb_build_object(
      'employee_id',
      employee_record.id,
      'employee_name',
      resolved_display_name
    )
  );

  return to_jsonb(employee_record);
end;
$$;

create or replace function public.remove_company_employee(target_employee_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  managed_company_id uuid;
  company_record public.companies;
  employee_record public.employees;
  assigned_vehicle record;
  actor_name text;
  employee_name text;
begin
  managed_company_id := public.get_managed_company_id_for_current_user();

  select *
  into employee_record
  from public.employees
  where id = target_employee_id;

  if employee_record.id is null then
    raise exception 'Employee not found';
  end if;

  if employee_record.company_id is distinct from managed_company_id then
    raise exception 'Not authorized to remove this employee';
  end if;

  if employee_record.user_id = auth.uid() then
    raise exception 'You cannot remove your own employee account';
  end if;

  select *
  into company_record
  from public.companies
  where id = managed_company_id;

  for assigned_vehicle in
    select fv.id
    from public.fleet_vehicles fv
    where fv.assigned_driver_employee_id = employee_record.id
  loop
    perform public.unassign_fleet_driver(assigned_vehicle.id);
  end loop;

  employee_name := trim(
    coalesce(employee_record.first_name, '') || ' ' || coalesce(employee_record.last_name, '')
  );

  update public.employees
  set
    company_id = null,
    role = null,
    status = 'inactive',
    is_dismissed = false,
    dismissal_date = null,
    dismissal_reason = null,
    dismissal_by_id = null,
    is_dismissed_pending_appeal = false,
    is_dismissal_final = false,
    account_deletion_date = null
  where id = target_employee_id
  returning *
  into employee_record;

  actor_name := coalesce(
    (select display_name from public.profiles where id = auth.uid()),
    company_record.company_name
  );

  perform public.create_notification_internal(
    employee_record.user_id,
    company_record.id,
    employee_record.id,
    'Removed From Company',
    'Your access to ' || company_record.company_name || ' has been removed. Contact management if this is unexpected.',
    'userManagement',
    actor_name,
    auth.uid(),
    null,
    company_record.org_type,
    'high',
    jsonb_build_object(
      'company_id',
      company_record.id,
      'company_name',
      company_record.company_name,
      'employee_id',
      employee_record.id,
      'employee_name',
      employee_name
    )
  );

  perform public.notify_company_management(
    company_record.id,
    'User Removed',
    actor_name || ' removed ' || coalesce(nullif(employee_name, ''), 'an employee') || ' from the company.',
    'userManagement',
    actor_name,
    auth.uid(),
    'high',
    jsonb_build_object(
      'employee_id',
      employee_record.id,
      'employee_name',
      employee_name
    )
  );

  return to_jsonb(employee_record);
end;
$$;

create or replace function public.assign_employee_role(
  target_employee_id uuid,
  target_role text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  employee_record public.employees;
  company_record public.companies;
  assigned_vehicle record;
  actor_name text;
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;

  select * into employee_record from public.employees where id = target_employee_id;
  if employee_record.id is null or employee_record.company_id is null then
    raise exception 'Employee not found';
  end if;

  if not public.is_company_manager(employee_record.company_id) then
    raise exception 'Not authorized to assign employee roles';
  end if;

  select * into company_record from public.companies where id = employee_record.company_id;

  if not public.is_valid_role_for_org(company_record.org_type, target_role) then
    raise exception 'Role % is not valid for %', target_role, company_record.org_type;
  end if;

  if target_role <> 'driver' then
    for assigned_vehicle in
      select fv.id
      from public.fleet_vehicles fv
      where fv.assigned_driver_employee_id = target_employee_id
    loop
      perform public.unassign_fleet_driver(assigned_vehicle.id);
    end loop;
  end if;

  actor_name := coalesce((select display_name from public.profiles where id = auth.uid()), 'Company Admin');

  update public.employees
  set
    role = target_role,
    status = 'active',
    is_dismissed = false,
    is_dismissed_pending_appeal = false,
    is_dismissal_final = false
  where id = target_employee_id
  returning *
  into employee_record;

  insert into public.employee_status_history (
    employee_id,
    company_id,
    status,
    actioned_by_id,
    actioned_by_name,
    assigned_role
  )
  values (
    employee_record.id,
    employee_record.company_id,
    'role_assigned',
    auth.uid(),
    actor_name,
    target_role
  );

  perform public.create_notification_internal(
    employee_record.user_id,
    employee_record.company_id,
    employee_record.id,
    'Role Assigned',
    'You have been assigned the ' || target_role || ' role at ' || company_record.company_name || '.',
    'roleAssigned',
    actor_name,
    auth.uid(),
    target_role,
    company_record.org_type,
    'high',
    jsonb_build_object('company_id', company_record.id, 'company_name', company_record.company_name, 'employee_id', employee_record.id, 'role', target_role)
  );

  return to_jsonb(employee_record);
end;
$$;

grant execute on function public.create_company_managed_employee(uuid, text, text, text, text) to authenticated;
grant execute on function public.update_company_employee(uuid, text, text, text) to authenticated;
grant execute on function public.remove_company_employee(uuid) to authenticated;
