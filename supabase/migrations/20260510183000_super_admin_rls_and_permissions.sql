begin;

-- ============================================================
-- Platform admin permission helpers
-- ============================================================

create or replace function public.current_platform_role()
returns text
language sql
stable
security definer
set search_path = public
as $$
  select p.platform_role
  from public.profiles p
  where p.id = auth.uid()
  limit 1;
$$;

-- Live-aligned: same semantics as remote projects' is_super_admin(); is_platform_admin is an alias.
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

create or replace function public.is_child_super_admin()
returns boolean
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  settings record;
begin
  if auth.uid() is null then
    return false;
  end if;

  if public.current_platform_role() <> 'superGlobalSerialAdminMainChild' then
    return false;
  end if;

  select * into settings
  from public.platform_admin_settings
  where id = 'main'
  limit 1;

  return settings.child_super_admin_user_id is not null and settings.child_super_admin_user_id = auth.uid();
end;
$$;

create or replace function public.child_admin_permission(flag text)
returns boolean
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  settings record;
begin
  if not public.is_child_super_admin() then
    return false;
  end if;

  select * into settings
  from public.platform_admin_settings
  where id = 'main'
  limit 1;

  case flag
    when 'canViewCompanies' then return coalesce(settings.child_can_view_companies, false);
    when 'canViewUsers' then return coalesce(settings.child_can_view_users, false);
    when 'canGenerateTokens' then return coalesce(settings.child_can_generate_tokens, false);
    when 'canRevokeTokens' then return coalesce(settings.child_can_revoke_tokens, false);
    when 'canManageSeats' then return coalesce(settings.child_can_manage_seats, false);
    when 'canSuspendCompanies' then return coalesce(settings.child_can_suspend_companies, false);
    when 'canDownloadLogs' then return coalesce(settings.child_can_download_logs, false);
    when 'canCreateAnotherChild' then return coalesce(settings.child_can_create_another_child, false);
    else return false;
  end case;
end;
$$;

create or replace function public.require_platform_admin()
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_platform_admin() then
    raise exception 'Platform admin access required';
  end if;
end;
$$;

-- ============================================================
-- RLS policies for platform tables
-- ============================================================

-- Profiles: ensure users can read their own platform_role.
do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'profiles'
      and policyname = 'profiles_select_self'
  ) then
    create policy profiles_select_self
      on public.profiles
      for select
      to authenticated
      using (id = auth.uid());
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'profiles'
      and policyname = 'profiles_select_platform_admin'
  ) then
    create policy profiles_select_platform_admin
      on public.profiles
      for select
      to authenticated
      using (public.is_platform_admin());
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'profiles'
      and policyname = 'profiles_update_platform_role_main_only'
  ) then
    create policy profiles_update_platform_role_main_only
      on public.profiles
      for update
      to authenticated
      using (public.is_main_super_admin())
      with check (public.is_main_super_admin());
  end if;
end$$;

-- platform_admin_settings: only platform admins can read; only main can update.
do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'platform_admin_settings'
      and policyname = 'platform_admin_settings_select_platform_admin'
  ) then
    create policy platform_admin_settings_select_platform_admin
      on public.platform_admin_settings
      for select
      to authenticated
      using (public.is_platform_admin());
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'platform_admin_settings'
      and policyname = 'platform_admin_settings_update_main_only'
  ) then
    create policy platform_admin_settings_update_main_only
      on public.platform_admin_settings
      for update
      to authenticated
      using (public.is_main_super_admin())
      with check (public.is_main_super_admin());
  end if;
end$$;

-- serial_tokens: read for platform admins; optionally company managers for their org.
do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'serial_tokens'
      and policyname = 'serial_tokens_select_platform_admin'
  ) then
    create policy serial_tokens_select_platform_admin
      on public.serial_tokens
      for select
      to authenticated
      using (public.is_platform_admin() or public.is_company_manager(organization_id));
  end if;
end$$;

-- organization_seats: read for platform admins and company managers.
do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'organization_seats'
      and policyname = 'organization_seats_select_platform_admin'
  ) then
    create policy organization_seats_select_platform_admin
      on public.organization_seats
      for select
      to authenticated
      using (public.is_platform_admin() or public.is_company_manager(organization_id));
  end if;
end$$;

-- seat_requests: company managers can create; platform admins can review.
do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'seat_requests'
      and policyname = 'seat_requests_select_allowed'
  ) then
    create policy seat_requests_select_allowed
      on public.seat_requests
      for select
      to authenticated
      using (public.is_platform_admin() or public.is_company_manager(organization_id));
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'seat_requests'
      and policyname = 'seat_requests_insert_company_manager'
  ) then
    create policy seat_requests_insert_company_manager
      on public.seat_requests
      for insert
      to authenticated
      with check (
        requested_by_user_id = auth.uid()
        and public.is_company_manager(organization_id)
      );
  end if;
end$$;

-- audit_logs: platform admins can read everything; company managers can read their org logs.
do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'audit_logs'
      and policyname = 'audit_logs_select_allowed'
  ) then
    create policy audit_logs_select_allowed
      on public.audit_logs
      for select
      to authenticated
      using (
        public.is_platform_admin()
        or (organization_id is not null and public.is_company_manager(organization_id))
      );
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'audit_logs'
      and policyname = 'audit_logs_insert_platform_admin'
  ) then
    create policy audit_logs_insert_platform_admin
      on public.audit_logs
      for insert
      to authenticated
      with check (public.is_platform_admin());
  end if;
end$$;

-- companies: allow platform admins + company owners/managers to update status/seat/token fields.
do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'companies'
      and policyname = 'companies_update_company_manager_or_platform_admin'
  ) then
    create policy companies_update_company_manager_or_platform_admin
      on public.companies
      for update
      to authenticated
      using (public.is_platform_admin() or public.is_company_manager(id))
      with check (public.is_platform_admin() or public.is_company_manager(id));
  end if;
end$$;

-- employees: allow platform admins + company managers to suspend/reactivate/assign roles.
do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'employees'
      and policyname = 'employees_update_company_manager_or_platform_admin'
  ) then
    create policy employees_update_company_manager_or_platform_admin
      on public.employees
      for update
      to authenticated
      using (public.is_platform_admin() or public.is_company_manager(company_id))
      with check (public.is_platform_admin() or public.is_company_manager(company_id));
  end if;
end$$;

commit;

