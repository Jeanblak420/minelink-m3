-- 20260815122000_employee_must_change_password.sql
--
-- S2-9 (G3), the half that mattered: the flag was never SET for an employee.
--
-- `must_change_password` exists because somebody other than the account
-- holder chose the password. That is exactly what happens when a company
-- admin creates an employee: `company-user-admin` takes a password out of the
-- admin's form, calls `auth.admin.createUser` with it, and then
-- `create_company_managed_employee` writes the profile **without the flag**.
-- So the manager knows their staff member's password, indefinitely, and
-- nothing ever asks the employee to change it.
--
-- Measured on production before this change: 1 of 116 profiles carries the
-- flag, and it is a company account. Not one employee has ever had it.
--
-- The router half is separate (`app_access_gates.dart`): it tested
-- `userType == 'company' && mustChangePassword`, so even a flagged employee
-- would not have been stopped.
--
-- APPLIES TO NEW EMPLOYEES ONLY, deliberately. Back-filling the 87 existing
-- active employees would force a password change on every demo account at
-- next sign-in and break the walkthrough the client runs on the shared test
-- password, which they have explicitly chosen to keep. If the client wants
-- the back-fill, it is one UPDATE and belongs to their decision, not to this
-- migration.
--
-- ⚠ SUPERSEDED IN PART BY 20260815123000. This file sets the flag only on the
-- INSERT path, on the reasoning that the `on conflict do update` path was a
-- re-link of an account whose password is already its own. That model of the
-- flow is wrong — `on_auth_user_created` inserts the profile when
-- `auth.admin.createUser` runs, so this RPC ALWAYS takes the conflict path
-- and this change was a no-op on the only route that reaches it. Kept as
-- applied; 20260815123000 fixes it.

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
set search_path to 'public'
as $function$
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
    must_change_password,
    metadata
  )
  values (
    target_user_id,
    coalesce(auth_user.email, ''),
    'employee',
    resolved_display_name,
    -- S2-9. The admin who created this account chose the password and knows
    -- it. The employee changes it at first sign-in.
    true,
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
$function$;

comment on function public.create_company_managed_employee(uuid, text, text, text, text) is
  'Creates an admin-managed employee. Sets profiles.must_change_password = true on the INSERT path (S2-9, 2026-08-15): the admin chose the password and knows it. Not set on the conflict-update path, which is a re-link of an account whose password is already its own. Existing employees are deliberately not back-filled.';
