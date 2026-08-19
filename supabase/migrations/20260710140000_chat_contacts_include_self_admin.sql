-- ============================================================================
-- get_chat_contacts: include the viewing Super Global Admin themselves in the
-- MINE-LINK group (previously self was excluded, so an admin only saw the
-- OTHER admin). Regular users already see both admins. Only the admin branch's
-- MINE-LINK query changes (drops `AND d.user_id <> p_user_id`).
-- ============================================================================
create or replace function public.get_chat_contacts(p_user_id uuid)
  returns table(
    user_id uuid, display_name text, avatar_url text,
    company_id uuid, company_name text, org_type text,
    is_super_admin boolean, group_kind text, group_label text, is_blocked boolean
  )
  language plpgsql stable security definer set search_path = public as $$
declare
  v_is_admin boolean := public.chat_is_super_admin(p_user_id);
  v_company  uuid    := public.chat_user_company_id(p_user_id);
begin
  if v_is_admin then
    return query
      select d.user_id, d.display_name, d.avatar_url, d.company_id, d.company_name, d.org_type,
             d.is_super_admin, 'mine_link'::text, 'MINE-LINK'::text, false
      from public.chat_directory d
      where d.is_super_admin
      union all
      select d.user_id, d.display_name, d.avatar_url, d.company_id, d.company_name, d.org_type,
             d.is_super_admin, 'organization'::text, ('ORGANIZATION · ' || d.company_name), false
      from public.chat_directory d
      where not d.is_super_admin and d.company_id is not null and d.user_id <> p_user_id;
    return;
  end if;

  -- MY COMPANY
  return query
    select d.user_id, d.display_name, d.avatar_url, d.company_id, d.company_name, d.org_type,
           d.is_super_admin, 'my_company'::text, 'MY COMPANY'::text, false
    from public.chat_directory d
    where d.company_id = v_company and d.user_id <> p_user_id and not d.is_super_admin;

  -- MINE-LINK (super admins)
  return query
    select d.user_id, d.display_name, d.avatar_url, d.company_id, d.company_name, d.org_type,
           d.is_super_admin, 'mine_link'::text, 'MINE-LINK'::text, false
    from public.chat_directory d
    where d.is_super_admin;

  -- CONNECTED · {Company}
  return query
    select d.user_id, d.display_name, d.avatar_url, d.company_id, d.company_name, d.org_type,
           d.is_super_admin, 'connected'::text, ('CONNECTED · ' || d.company_name),
           (oc.status = 'revoked')
    from public.org_connections oc
    join public.chat_directory d
      on d.company_id = case when oc.company_low_id = v_company then oc.company_high_id else oc.company_low_id end
    where (oc.company_low_id = v_company or oc.company_high_id = v_company)
      and d.user_id <> p_user_id and not d.is_super_admin;
end $$;
