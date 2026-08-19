-- Fix super-admin-create-company edge function failures (400 Bad Request).
--
-- Symptoms:
--   Postgres: "permission denied for table profiles" when service_role updates
--   the new company owner's profile after auth.admin.createUser.
--   Edge function catch returns 400 with opaque { error: "permission denied..." }.
--
-- Also restores is_child_super_admin() on databases that applied later migrations
-- referencing it without the defining migration (20260510183000) being applied.

begin;

-- ---------------------------------------------------------------------------
-- Missing helper used by child_admin_permission and several RPCs
-- ---------------------------------------------------------------------------
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

  return settings.child_super_admin_user_id is not null
    and settings.child_super_admin_user_id = auth.uid();
end;
$$;

grant execute on function public.is_child_super_admin() to authenticated;

-- ---------------------------------------------------------------------------
-- service_role table grants for edge functions (RLS bypass still needs GRANT)
-- ---------------------------------------------------------------------------
grant select, insert, update, delete on table public.profiles to service_role;
grant select, insert, update, delete on table public.companies to service_role;

commit;
