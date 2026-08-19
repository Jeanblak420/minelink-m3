-- ============================================================================
-- Add `role` (used as the in-company "department" grouping in the chat Contacts
-- tab) to chat_directory and get_chat_contacts. Owners → 'owner', super admins
-- → 'admin', employees → their employees.role (fallback 'member').
-- ============================================================================
create or replace view public.chat_directory
  with (security_invoker = false) as
  select c.user_id,
         coalesce(p.display_name, nullif(trim(coalesce(c.ceo_first_name,'') || ' ' || coalesce(c.ceo_last_name,'')), ''), c.company_name) as display_name,
         c.logo_url as avatar_url, c.id as company_id, c.company_name, c.org_type,
         false as is_super_admin, 'owner'::text as role
  from public.companies c
  join public.profiles p on p.id = c.user_id
  union
  select e.user_id,
         trim(e.first_name || ' ' || e.last_name) as display_name,
         e.profile_photo_url as avatar_url, e.company_id, c.company_name, c.org_type,
         false as is_super_admin, coalesce(e.role, 'member') as role
  from public.employees e
  join public.companies c on c.id = e.company_id
  join public.profiles p on p.id = e.user_id
  where e.company_id is not null and coalesce(e.is_dismissed, false) = false
  union
  select p.id as user_id,
         coalesce(p.display_name, split_part(p.email, '@', 1)) as display_name,
         null::text as avatar_url, null::uuid as company_id, null::text as company_name, null::text as org_type,
         true as is_super_admin, 'admin'::text as role
  from public.profiles p
  where p.platform_role ~~ 'superGlobalSerialAdmin%';

drop function if exists public.get_chat_contacts(uuid);
create or replace function public.get_chat_contacts(p_user_id uuid)
  returns table(
    user_id uuid, display_name text, avatar_url text,
    company_id uuid, company_name text, org_type text,
    is_super_admin boolean, group_kind text, group_label text, is_blocked boolean,
    role text
  )
  language plpgsql stable security definer set search_path = public as $$
declare
  v_is_admin boolean := public.chat_is_super_admin(p_user_id);
  v_company  uuid    := public.chat_user_company_id(p_user_id);
begin
  if v_is_admin then
    return query
      select d.user_id, d.display_name, d.avatar_url, d.company_id, d.company_name, d.org_type,
             d.is_super_admin, 'mine_link'::text, 'MINE-LINK'::text, false, d.role
      from public.chat_directory d
      where d.is_super_admin
      union all
      select d.user_id, d.display_name, d.avatar_url, d.company_id, d.company_name, d.org_type,
             d.is_super_admin, 'organization'::text, ('ORGANIZATION · ' || d.company_name), false, d.role
      from public.chat_directory d
      where not d.is_super_admin and d.company_id is not null and d.user_id <> p_user_id;
    return;
  end if;

  return query
    select d.user_id, d.display_name, d.avatar_url, d.company_id, d.company_name, d.org_type,
           d.is_super_admin, 'my_company'::text, 'MY COMPANY'::text, false, d.role
    from public.chat_directory d
    where d.company_id = v_company and d.user_id <> p_user_id and not d.is_super_admin;

  return query
    select d.user_id, d.display_name, d.avatar_url, d.company_id, d.company_name, d.org_type,
           d.is_super_admin, 'mine_link'::text, 'MINE-LINK'::text, false, d.role
    from public.chat_directory d
    where d.is_super_admin;

  return query
    select d.user_id, d.display_name, d.avatar_url, d.company_id, d.company_name, d.org_type,
           d.is_super_admin, 'connected'::text, ('CONNECTED · ' || d.company_name),
           (oc.status = 'revoked'), d.role
    from public.org_connections oc
    join public.chat_directory d
      on d.company_id = case when oc.company_low_id = v_company then oc.company_high_id else oc.company_low_id end
    where (oc.company_low_id = v_company or oc.company_high_id = v_company)
      and d.user_id <> p_user_id and not d.is_super_admin;
end $$;

grant execute on function public.get_chat_contacts(uuid) to authenticated;
