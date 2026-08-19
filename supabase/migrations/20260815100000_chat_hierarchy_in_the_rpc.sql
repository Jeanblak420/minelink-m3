-- S8-1 / P10-07. Enforce the chat hierarchy in the database, not the UI.
--
-- Before this, get_chat_contacts returned every user in the caller's own
-- company regardless of role, plus every user at every connected company —
-- `role` was returned but used only as a grouping label. Walked: a driver at
-- Roadhaul Logistics could reach another **driver**, **management** and the
-- company **owner**, on top of admin and MineLink.
--
-- The spec (P10-07):
--   · companies and managers  -> anyone in their company
--   · admins                  -> managers and any role except companies
--   · everyone else           -> only admins
--
-- IT GOVERNS INITIATING, NOT REPLYING, and that distinction is load-bearing.
-- Management is allowed to start a conversation with a driver; if the same
-- rule were applied to messages, the driver could not answer and management's
-- outreach would be a one-way broadcast. So:
--
--   chat_rooms_insert    (starting a conversation) -> hierarchy applies
--   chat_messages_insert (replying in one)         -> hierarchy does NOT apply
--
-- NOTE: this file got that second half WRONG — can_send_in_chat_room()
-- delegates to can_send_chat_to(), so the hierarchy leaked onto replies. The
-- comment above described the intent and the code did the opposite. Fixed in
-- 20260815101000, which is kept as its own file because the mistake is worth
-- reading.
--
-- MineLink (super global admin) is always reachable in both directions. That
-- is not a courtesy: it is the route by which an expired company sorts out its
-- renewal (20260815095000), so closing it would strand paying customers.

create or replace function public.chat_role_of(p_uid uuid)
returns text
language sql
stable security definer
set search_path to 'public'
as $function$
  select coalesce(
    (select 'owner' from public.companies c where c.user_id = p_uid limit 1),
    (select e.role from public.employees e
      where e.user_id = p_uid and e.is_dismissed = false
        and e.status = 'active' limit 1)
  );
$function$;

comment on function public.chat_role_of(uuid) is
  'A user''s effective chat role: ''owner'' for a company account, else their '
  'employee role. Used by can_initiate_chat_with() to apply the P10-07 '
  'hierarchy.';

create or replace function public.can_initiate_chat_with(p_target uuid)
returns boolean
language plpgsql
stable security definer
set search_path to 'public'
as $function$
declare
  v_me text;
  v_them text;
begin
  if auth.uid() is null or p_target is null then
    return false;
  end if;

  if public.chat_is_super_admin(auth.uid()) or public.chat_is_super_admin(p_target) then
    return true;
  end if;

  v_me   := public.chat_role_of(auth.uid());
  v_them := public.chat_role_of(p_target);

  if v_me in ('owner', 'management') then
    return true;
  end if;

  if v_me = 'admin' then
    return v_them is distinct from 'owner';
  end if;

  return v_them = 'admin';
end;
$function$;

comment on function public.can_initiate_chat_with(uuid) is
  'P10-07 chat hierarchy. Governs STARTING a conversation only — replying in '
  'an existing room is deliberately ungated, or management could open a chat '
  'with a driver that the driver cannot answer.';

create or replace function public.can_send_chat_to(target_participant_ids uuid[])
returns boolean
language plpgsql
stable security definer
set search_path to 'public'
as $function$
declare
  v_company uuid;
  v_pid uuid;
begin
  if not public.are_chat_participants_allowed(target_participant_ids) then
    return false;
  end if;

  if public.chat_is_super_admin(auth.uid()) then
    return true;
  end if;

  foreach v_pid in array target_participant_ids
  loop
    if v_pid <> auth.uid() and not public.can_initiate_chat_with(v_pid) then
      return false;
    end if;
  end loop;

  v_company := public.current_company_id();
  if v_company is null then
    return false;
  end if;

  if public.is_company_active(v_company) then
    return true;
  end if;

  foreach v_pid in array target_participant_ids
  loop
    if v_pid <> auth.uid() and not public.chat_is_super_admin(v_pid) then
      return false;
    end if;
  end loop;

  return true;
end;
$function$;

-- The contact list says WHY somebody is unreachable, rather than hiding them.
-- Hiding a colleague would read as "they are not on the platform"; a labelled
-- row reads as "not your route to them", which is the truth.
drop function if exists public.get_chat_contacts(uuid);
create function public.get_chat_contacts(p_user_id uuid)
returns table(user_id uuid, display_name text, avatar_url text, company_id uuid,
              company_name text, org_type text, is_super_admin boolean,
              group_kind text, group_label text, is_blocked boolean,
              block_reason text, role text, last_seen_at timestamp with time zone)
language plpgsql
stable security definer
set search_path to 'public'
as $function$
declare
  v_is_admin boolean := public.chat_is_super_admin(p_user_id);
  v_company  uuid    := public.chat_user_company_id(p_user_id);
  v_expired  boolean := (not v_is_admin)
                        and v_company is not null
                        and not public.is_company_active(v_company);
begin
  if v_is_admin then
    return query
      select d.user_id, d.display_name, d.avatar_url, d.company_id, d.company_name, d.org_type,
             d.is_super_admin, 'mine_link'::text, 'MINE-LINK'::text, false, null::text,
             d.role, d.last_seen_at
      from public.chat_directory d
      where d.is_super_admin
      union all
      select d.user_id, d.display_name, d.avatar_url, d.company_id, d.company_name, d.org_type,
             d.is_super_admin, 'organization'::text, ('ORGANIZATION · ' || d.company_name), false,
             null::text, d.role, d.last_seen_at
      from public.chat_directory d
      where not d.is_super_admin and d.company_id is not null and d.user_id <> p_user_id;
    return;
  end if;

  return query
    select d.user_id, d.display_name, d.avatar_url, d.company_id, d.company_name, d.org_type,
           d.is_super_admin, 'my_company'::text, 'MY COMPANY'::text,
           (v_expired or not public.can_initiate_chat_with(d.user_id)),
           case when v_expired then 'token_expired'
                when not public.can_initiate_chat_with(d.user_id) then 'hierarchy' end,
           d.role, d.last_seen_at
    from public.chat_directory d
    where d.company_id = v_company and d.user_id <> p_user_id and not d.is_super_admin;

  return query
    select d.user_id, d.display_name, d.avatar_url, d.company_id, d.company_name, d.org_type,
           d.is_super_admin, 'mine_link'::text, 'MINE-LINK'::text, false, null::text,
           d.role, d.last_seen_at
    from public.chat_directory d
    where d.is_super_admin;

  return query
    select d.user_id, d.display_name, d.avatar_url, d.company_id, d.company_name, d.org_type,
           d.is_super_admin, 'connected'::text, ('CONNECTED · ' || d.company_name),
           (v_expired or oc.status = 'revoked'
              or not public.can_initiate_chat_with(d.user_id)),
           case when v_expired then 'token_expired'
                when oc.status = 'revoked' then 'org_revoked'
                when not public.can_initiate_chat_with(d.user_id) then 'hierarchy' end,
           d.role, d.last_seen_at
    from public.org_connections oc
    join public.chat_directory d
      on d.company_id = case when oc.company_low_id = v_company then oc.company_high_id else oc.company_low_id end
    where (oc.company_low_id = v_company or oc.company_high_id = v_company)
      and d.user_id <> p_user_id and not d.is_super_admin;
end $function$;

grant execute on function public.get_chat_contacts(uuid) to authenticated;

-- Verified on production, as a driver at Roadhaul Logistics (rolled back).
-- Their contact list, before -> after:
--   admin (MineLink)   2 reachable  ->  2 reachable
--   admin (own company) 1 reachable ->  1 reachable
--   driver              1 reachable ->  BLOCKED, reason 'hierarchy'
--   management          1 reachable ->  BLOCKED, reason 'hierarchy'
--   owner               1 reachable ->  BLOCKED, reason 'hierarchy'
-- and management -> driver returns true, so the hierarchy only points one way.
