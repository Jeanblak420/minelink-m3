-- Ensure require_platform_admin exists on databases that skipped earlier migrations.
-- Add a definer RPC so child admins can read only the platform owner's display name (neutral contact).

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

create or replace function public.get_platform_owner_display_name()
returns text
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  mid uuid;
  dn text;
begin
  if not public.is_child_super_admin() then
    return null;
  end if;

  select s.main_super_admin_user_id
  into mid
  from public.platform_admin_settings s
  where s.id = 'main'
  limit 1;

  if mid is null then
    return null;
  end if;

  select p.display_name into dn from public.profiles p where p.id = mid;
  return dn;
end;
$$;

grant execute on function public.require_platform_admin() to authenticated;
grant execute on function public.get_platform_owner_display_name() to authenticated;
