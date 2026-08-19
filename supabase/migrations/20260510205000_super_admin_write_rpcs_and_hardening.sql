begin;

-- ---------------------------------------------------------------------------
-- Align helpers with live (is_super_admin); is_platform_admin stays an alias.
-- ---------------------------------------------------------------------------

create or replace function public.is_super_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists(
    select 1
    from public.profiles p
    where p.id = auth.uid()
      and p.platform_role in (
        'superGlobalSerialAdminMain',
        'superGlobalSerialAdminMainChild'
      )
  );
$$;

create or replace function public.is_platform_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.is_super_admin();
$$;

create or replace function public.is_main_super_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists(
    select 1
    from public.profiles p
    where p.id = auth.uid()
      and p.platform_role = 'superGlobalSerialAdminMain'
  );
$$;

-- ---------------------------------------------------------------------------
-- Audit helper: only callable by platform admins (closes open definer hole).
-- ---------------------------------------------------------------------------

create or replace function public.insert_audit_log(
  p_action_type text,
  p_target_type text,
  p_target_id uuid default null,
  p_target_name text default null,
  p_organization_id uuid default null,
  p_description text default '',
  p_before_data jsonb default null,
  p_after_data jsonb default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  actor record;
  org record;
begin
  perform public.require_platform_admin();

  select p.id, p.email, p.platform_role
  into actor
  from public.profiles p
  where p.id = auth.uid()
  limit 1;

  if p_organization_id is not null then
    select c.id, c.company_name, c.org_type
    into org
    from public.companies c
    where c.id = p_organization_id
    limit 1;
  end if;

  insert into public.audit_logs (
    actor_user_id,
    actor_email,
    actor_platform_role,
    action_type,
    target_type,
    target_id,
    target_name,
    organization_id,
    organization_name,
    organization_type,
    description,
    before_data,
    after_data,
    created_at
  )
  values (
    auth.uid(),
    coalesce(actor.email, ''),
    coalesce(actor.platform_role, 'normalUser'),
    p_action_type,
    p_target_type,
    p_target_id,
    p_target_name,
    p_organization_id,
    org.company_name,
    org.org_type,
    coalesce(p_description, ''),
    p_before_data,
    p_after_data,
    timezone('utc', now())
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- Sensitive writes: security definer RPCs (RLS bypass with explicit checks).
-- ---------------------------------------------------------------------------

create or replace function public.super_admin_set_company_status(
  p_company_id uuid,
  p_status text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  cname text;
begin
  perform public.require_platform_admin();

  if public.is_child_super_admin() and not public.child_admin_permission('canSuspendCompanies') then
    raise exception 'Child admin not permitted to change company status';
  end if;

  if p_company_id is null then
    raise exception 'Company is required';
  end if;

  if p_status is null or p_status not in ('suspended', 'active') then
    raise exception 'Invalid company status';
  end if;

  select c.company_name into cname
  from public.companies c
  where c.id = p_company_id
  limit 1;

  if cname is null then
    raise exception 'Organization not found';
  end if;

  update public.companies
  set
    status = p_status,
    updated_at = timezone('utc', now())
  where id = p_company_id;

  perform public.insert_audit_log(
    case when p_status = 'suspended' then 'COMPANY_SUSPENDED' else 'COMPANY_REACTIVATED' end,
    'company',
    p_company_id,
    cname,
    p_company_id,
    'Company status set to ' || p_status
  );

  return jsonb_build_object('company_id', p_company_id, 'status', p_status);
end;
$$;

create or replace function public.super_admin_set_employee_status(
  p_employee_id uuid,
  p_status text,
  p_reason text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  emp record;
  cname text;
  desc_text text;
begin
  perform public.require_platform_admin();

  if public.is_child_super_admin() and not public.child_admin_permission('canSuspendCompanies') then
    raise exception 'Child admin not permitted to change employee status';
  end if;

  if p_employee_id is null then
    raise exception 'Employee is required';
  end if;

  if p_status is null or p_status not in ('suspended', 'active') then
    raise exception 'Invalid employee status';
  end if;

  select e.* into emp
  from public.employees e
  where e.id = p_employee_id
  limit 1;

  if emp.id is null then
    raise exception 'Employee not found';
  end if;

  select c.company_name into cname
  from public.companies c
  where c.id = emp.company_id
  limit 1;

  update public.employees
  set status = p_status
  where id = p_employee_id;

  desc_text := case when p_status = 'suspended'
    then 'User suspended.' || case when p_reason is not null and length(trim(p_reason)) > 0
      then ' Reason: ' || p_reason else '' end
    else 'User account reactivated by platform admin.'
  end;

  perform public.insert_audit_log(
    case when p_status = 'suspended' then 'USER_SUSPENDED' else 'USER_REACTIVATED' end,
    'employee',
    p_employee_id,
    trim(both from coalesce(emp.first_name, '') || ' ' || coalesce(emp.last_name, '')),
    emp.company_id,
    desc_text
  );

  return jsonb_build_object('employee_id', p_employee_id, 'status', p_status);
end;
$$;

create or replace function public.super_admin_set_employee_role(
  p_employee_id uuid,
  p_role text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  emp record;
  cname text;
begin
  perform public.require_platform_admin();

  if public.is_child_super_admin() and not public.child_admin_permission('canViewUsers') then
    raise exception 'Child admin not permitted to change employee roles';
  end if;

  if p_employee_id is null or p_role is null then
    raise exception 'Employee and role are required';
  end if;

  if p_role not in ('security', 'controllerWB', 'admin', 'management', 'driver') then
    raise exception 'Invalid employee role';
  end if;

  select e.* into emp
  from public.employees e
  where e.id = p_employee_id
  limit 1;

  if emp.id is null then
    raise exception 'Employee not found';
  end if;

  select c.company_name into cname
  from public.companies c
  where c.id = emp.company_id
  limit 1;

  update public.employees
  set role = p_role
  where id = p_employee_id;

  perform public.insert_audit_log(
    'USER_ROLE_CHANGED',
    'employee',
    p_employee_id,
    trim(both from coalesce(emp.first_name, '') || ' ' || coalesce(emp.last_name, '')),
    emp.company_id,
    'Employee role changed to "' || p_role || '" by platform admin.'
  );

  return jsonb_build_object('employee_id', p_employee_id, 'role', p_role);
end;
$$;

create or replace function public.super_admin_release_organization_seat(
  p_organization_id uuid,
  p_user_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  n int;
  cname text;
begin
  perform public.require_platform_admin();

  if public.is_child_super_admin() and not public.child_admin_permission('canManageSeats') then
    raise exception 'Child admin not permitted to release seats';
  end if;

  if p_organization_id is null or p_user_id is null then
    raise exception 'Organization and user are required';
  end if;

  select c.company_name into cname
  from public.companies c
  where c.id = p_organization_id
  limit 1;

  if cname is null then
    raise exception 'Organization not found';
  end if;

  update public.organization_seats
  set
    occupied_by_user_id = null,
    occupied_by_employee_id = null,
    occupied_by_name = null,
    occupied_by_email = null,
    occupied_by_employee_role = null,
    status = 'available',
    released_at = timezone('utc', now()),
    assigned_at = null,
    updated_at = timezone('utc', now())
  where organization_id = p_organization_id
    and occupied_by_user_id = p_user_id;

  get diagnostics n = row_count;

  perform public.recompute_company_seats_used(p_organization_id);

  perform public.insert_audit_log(
    'SEAT_RELEASED',
    'user',
    p_user_id,
    null,
    p_organization_id,
    'User removed from seat by platform admin.'
  );

  return jsonb_build_object('organization_id', p_organization_id, 'user_id', p_user_id, 'rows_updated', n);
end;
$$;

create or replace function public.super_admin_assign_child_admin(
  p_target_user_id uuid,
  p_target_email text,
  p_permissions jsonb default '{}'::jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  s record;
  old_child uuid;
  em text;
  tgt_role text;
begin
  if not public.is_main_super_admin() then
    raise exception 'Main super admin required';
  end if;

  if p_target_user_id is null then
    raise exception 'Target user is required';
  end if;

  em := lower(trim(coalesce(p_target_email, '')));
  if em = '' then
    raise exception 'Target email is required';
  end if;

  select platform_role into tgt_role
  from public.profiles
  where id = p_target_user_id
  limit 1;

  if tgt_role is null then
    raise exception 'Target user not found';
  end if;

  if tgt_role <> 'normalUser' then
    raise exception 'Target user must have platform role normalUser';
  end if;

  select * into s
  from public.platform_admin_settings
  where id = 'main'
  limit 1;

  old_child := s.child_super_admin_user_id;

  if old_child is not null and old_child is distinct from p_target_user_id then
    update public.profiles
    set platform_role = 'normalUser'
    where id = old_child;
  end if;

  update public.profiles
  set platform_role = 'superGlobalSerialAdminMainChild'
  where id = p_target_user_id;

  update public.platform_admin_settings
  set
    child_super_admin_user_id = p_target_user_id,
    child_super_admin_email = em,
    child_admin_created_at = timezone('utc', now()),
    child_admin_status = 'active',
    child_can_view_companies = coalesce((p_permissions->>'child_can_view_companies')::boolean, true),
    child_can_view_users = coalesce((p_permissions->>'child_can_view_users')::boolean, true),
    child_can_generate_tokens = coalesce((p_permissions->>'child_can_generate_tokens')::boolean, true),
    child_can_revoke_tokens = coalesce((p_permissions->>'child_can_revoke_tokens')::boolean, false),
    child_can_manage_seats = coalesce((p_permissions->>'child_can_manage_seats')::boolean, true),
    child_can_suspend_companies = coalesce((p_permissions->>'child_can_suspend_companies')::boolean, false),
    child_can_download_logs = coalesce((p_permissions->>'child_can_download_logs')::boolean, false),
    child_can_create_another_child = coalesce((p_permissions->>'child_can_create_another_child')::boolean, false),
    updated_at = timezone('utc', now())
  where id = 'main';

  perform public.insert_audit_log(
    'CHILD_ADMIN_CREATED',
    'user',
    p_target_user_id,
    em,
    null,
    'Child admin account created for ' || em
  );

  return jsonb_build_object('ok', true, 'user_id', p_target_user_id);
end;
$$;

create or replace function public.super_admin_disable_child_admin(p_child_user_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  cur uuid;
begin
  if not public.is_main_super_admin() then
    raise exception 'Main super admin required';
  end if;

  if p_child_user_id is null then
    raise exception 'Child user is required';
  end if;

  select child_super_admin_user_id into cur
  from public.platform_admin_settings
  where id = 'main'
  limit 1;

  if cur is null or cur is distinct from p_child_user_id then
    raise exception 'User is not the active child admin';
  end if;

  update public.profiles
  set platform_role = 'normalUser'
  where id = p_child_user_id;

  update public.platform_admin_settings
  set
    child_admin_status = 'inactive',
    child_super_admin_user_id = null,
    child_super_admin_email = null,
    updated_at = timezone('utc', now())
  where id = 'main';

  perform public.insert_audit_log(
    'CHILD_ADMIN_DISABLED',
    'user',
    p_child_user_id,
    null,
    null,
    'Child admin account disabled'
  );

  return jsonb_build_object('ok', true, 'user_id', p_child_user_id);
end;
$$;

create or replace function public.super_admin_patch_child_admin_permissions(p_patch jsonb)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_main_super_admin() then
    raise exception 'Main super admin required';
  end if;

  if p_patch is null then
    raise exception 'Patch payload is required';
  end if;

  update public.platform_admin_settings
  set
    child_can_view_companies = case
      when p_patch ? 'child_can_view_companies' then (p_patch->>'child_can_view_companies')::boolean
      else child_can_view_companies end,
    child_can_view_users = case
      when p_patch ? 'child_can_view_users' then (p_patch->>'child_can_view_users')::boolean
      else child_can_view_users end,
    child_can_generate_tokens = case
      when p_patch ? 'child_can_generate_tokens' then (p_patch->>'child_can_generate_tokens')::boolean
      else child_can_generate_tokens end,
    child_can_revoke_tokens = case
      when p_patch ? 'child_can_revoke_tokens' then (p_patch->>'child_can_revoke_tokens')::boolean
      else child_can_revoke_tokens end,
    child_can_manage_seats = case
      when p_patch ? 'child_can_manage_seats' then (p_patch->>'child_can_manage_seats')::boolean
      else child_can_manage_seats end,
    child_can_suspend_companies = case
      when p_patch ? 'child_can_suspend_companies' then (p_patch->>'child_can_suspend_companies')::boolean
      else child_can_suspend_companies end,
    child_can_download_logs = case
      when p_patch ? 'child_can_download_logs' then (p_patch->>'child_can_download_logs')::boolean
      else child_can_download_logs end,
    child_can_create_another_child = case
      when p_patch ? 'child_can_create_another_child' then (p_patch->>'child_can_create_another_child')::boolean
      else child_can_create_another_child end,
    updated_at = timezone('utc', now())
  where id = 'main';

  perform public.insert_audit_log(
    'CHILD_ADMIN_PERMISSION_UPDATED',
    'settings',
    null,
    null,
    null,
    'Child admin permissions updated'
  );

  return jsonb_build_object('ok', true);
end;
$$;

grant execute on function public.super_admin_set_company_status(uuid, text) to authenticated;
grant execute on function public.super_admin_set_employee_status(uuid, text, text) to authenticated;
grant execute on function public.super_admin_set_employee_role(uuid, text) to authenticated;
grant execute on function public.super_admin_release_organization_seat(uuid, uuid) to authenticated;
grant execute on function public.super_admin_assign_child_admin(uuid, text, jsonb) to authenticated;
grant execute on function public.super_admin_disable_child_admin(uuid) to authenticated;
grant execute on function public.super_admin_patch_child_admin_permissions(jsonb) to authenticated;

-- ---------------------------------------------------------------------------
-- Tighten RLS: platform admins use RPCs for these writes (managers keep 830 policies).
-- ---------------------------------------------------------------------------

drop policy if exists companies_update_super_admin on public.companies;
drop policy if exists employees_update_super_admin on public.employees;
drop policy if exists profiles_update_main_super_admin on public.profiles;
drop policy if exists profiles_update_platform_role_main_only on public.profiles;

commit;
