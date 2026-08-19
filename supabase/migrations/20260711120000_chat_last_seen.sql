-- CPS-style presence: persist a per-user "last seen" activity time so the
-- chat can show Online / Last seen X / never everywhere (rows, header, profile).
-- Keeps MineLink's existing company-scoped contact grouping intact.

alter table public.profiles add column if not exists last_seen_at timestamptz;

-- Surface last_seen_at through the contact directory view.
create or replace view public.chat_directory as
SELECT c.user_id,
    COALESCE(p.display_name, NULLIF(TRIM(BOTH FROM (COALESCE(c.ceo_first_name, ''::text) || ' '::text) || COALESCE(c.ceo_last_name, ''::text)), ''::text), c.company_name) AS display_name,
    c.logo_url AS avatar_url,
    c.id AS company_id,
    c.company_name,
    c.org_type,
    false AS is_super_admin,
    'owner'::text AS role,
    p.last_seen_at
   FROM companies c
     JOIN profiles p ON p.id = c.user_id
UNION
 SELECT e.user_id,
    TRIM(BOTH FROM (e.first_name || ' '::text) || e.last_name) AS display_name,
    e.profile_photo_url AS avatar_url,
    e.company_id,
    c.company_name,
    c.org_type,
    false AS is_super_admin,
    COALESCE(e.role, 'member'::text) AS role,
    p.last_seen_at
   FROM employees e
     JOIN companies c ON c.id = e.company_id
     JOIN profiles p ON p.id = e.user_id
  WHERE e.company_id IS NOT NULL AND COALESCE(e.is_dismissed, false) = false
UNION
 SELECT p.id AS user_id,
    COALESCE(p.display_name, split_part(p.email, '@'::text, 1)) AS display_name,
    NULL::text AS avatar_url,
    NULL::uuid AS company_id,
    NULL::text AS company_name,
    NULL::text AS org_type,
    true AS is_super_admin,
    'admin'::text AS role,
    p.last_seen_at
   FROM profiles p
  WHERE p.platform_role ~~ 'superGlobalSerialAdmin%'::text;

-- Add last_seen_at to the scoped contact RPC (return type changes → drop first).
DROP FUNCTION IF EXISTS public.get_chat_contacts(uuid);
CREATE OR REPLACE FUNCTION public.get_chat_contacts(p_user_id uuid)
 RETURNS TABLE(user_id uuid, display_name text, avatar_url text, company_id uuid, company_name text, org_type text, is_super_admin boolean, group_kind text, group_label text, is_blocked boolean, role text, last_seen_at timestamptz)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_is_admin boolean := public.chat_is_super_admin(p_user_id);
  v_company  uuid    := public.chat_user_company_id(p_user_id);
begin
  if v_is_admin then
    return query
      select d.user_id, d.display_name, d.avatar_url, d.company_id, d.company_name, d.org_type,
             d.is_super_admin, 'mine_link'::text, 'MINE-LINK'::text, false, d.role, d.last_seen_at
      from public.chat_directory d
      where d.is_super_admin
      union all
      select d.user_id, d.display_name, d.avatar_url, d.company_id, d.company_name, d.org_type,
             d.is_super_admin, 'organization'::text, ('ORGANIZATION · ' || d.company_name), false, d.role, d.last_seen_at
      from public.chat_directory d
      where not d.is_super_admin and d.company_id is not null and d.user_id <> p_user_id;
    return;
  end if;

  return query
    select d.user_id, d.display_name, d.avatar_url, d.company_id, d.company_name, d.org_type,
           d.is_super_admin, 'my_company'::text, 'MY COMPANY'::text, false, d.role, d.last_seen_at
    from public.chat_directory d
    where d.company_id = v_company and d.user_id <> p_user_id and not d.is_super_admin;

  return query
    select d.user_id, d.display_name, d.avatar_url, d.company_id, d.company_name, d.org_type,
           d.is_super_admin, 'mine_link'::text, 'MINE-LINK'::text, false, d.role, d.last_seen_at
    from public.chat_directory d
    where d.is_super_admin;

  return query
    select d.user_id, d.display_name, d.avatar_url, d.company_id, d.company_name, d.org_type,
           d.is_super_admin, 'connected'::text, ('CONNECTED · ' || d.company_name),
           (oc.status = 'revoked'), d.role, d.last_seen_at
    from public.org_connections oc
    join public.chat_directory d
      on d.company_id = case when oc.company_low_id = v_company then oc.company_high_id else oc.company_low_id end
    where (oc.company_low_id = v_company or oc.company_high_id = v_company)
      and d.user_id <> p_user_id and not d.is_super_admin;
end $function$;

-- Heartbeat: the client calls this periodically while the app is open.
create or replace function public.chat_touch_last_seen()
returns void
language sql
security definer
set search_path to 'public'
as $$
  update public.profiles set last_seen_at = now() where id = auth.uid();
$$;

grant execute on function public.chat_touch_last_seen() to authenticated;

notify pgrst, 'reload schema';
