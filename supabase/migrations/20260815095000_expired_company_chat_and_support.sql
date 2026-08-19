-- S2-10 / G4, second slice. Client ruling 2026-08-15: an expired company keeps
-- READ access, may chat **to MineLink (super global admin) only**, may still
-- request a token / seats / access, and may still log a support ticket.
--
-- Support tickets already satisfy this and are deliberately left alone —
-- verified rather than assumed: support_tickets_insert is
-- `created_by = auth.uid()` with no company predicate, and
-- support_create_ticket() is SECURITY DEFINER with no status test. Token and
-- seat requests were preserved in 20260815094000.
--
-- Chat is the part that needed work. Both chat_rooms and chat_messages gate
-- SELECT *and* INSERT through are_chat_participants_allowed(), so touching that
-- one function would have taken read access away with send access. Split
-- instead:
--
--   SELECT  keeps are_chat_participants_allowed()  -> an expired company can
--           still READ its existing conversations, per the read-only ruling
--   INSERT  uses the new can_send_chat_* below     -> new messages only to a
--           super global admin once the token has expired
--
-- So an expired customer can always reach MineLink to sort the renewal out,
-- and can still read what was said before — but cannot run their operation
-- through internal chat while unlicensed.

-- Send-side gate for starting a room.
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
  -- Must already satisfy the ordinary participant rules.
  if not public.are_chat_participants_allowed(target_participant_ids) then
    return false;
  end if;

  -- Super global admins are never restricted.
  if public.chat_is_super_admin(auth.uid()) then
    return true;
  end if;

  v_company := public.current_company_id();
  if v_company is null then
    return false;
  end if;

  -- Licensed company: unchanged behaviour.
  if public.is_company_active(v_company) then
    return true;
  end if;

  -- Expired/suspended/pending: every OTHER participant must be a super admin.
  foreach v_pid in array target_participant_ids
  loop
    if v_pid <> auth.uid() and not public.chat_is_super_admin(v_pid) then
      return false;
    end if;
  end loop;

  return true;
end;
$function$;

comment on function public.can_send_chat_to(uuid[]) is
  'Send-side chat gate. Same rules as are_chat_participants_allowed(), plus: '
  'an inactive company may only send to a super global admin. Reading is '
  'deliberately NOT gated by this — an expired company keeps read access to '
  'its existing conversations (client ruling 2026-08-15).';

-- Send-side gate for posting into an existing room.
create or replace function public.can_send_in_chat_room(target_chat_room_id uuid)
returns boolean
language sql
stable security definer
set search_path to 'public'
as $function$
  select exists (
    select 1 from public.chat_rooms cr
    where cr.id = target_chat_room_id
      and public.can_send_chat_to(cr.participant_ids)
  );
$function$;

-- Swap ONLY the insert policies over. The select policies are untouched.
drop policy if exists chat_rooms_insert_members on public.chat_rooms;
create policy chat_rooms_insert_members
  on public.chat_rooms for insert to authenticated
  with check (public.can_send_chat_to(participant_ids));

drop policy if exists chat_messages_insert_members on public.chat_messages;
create policy chat_messages_insert_members
  on public.chat_messages for insert to authenticated
  with check ((sender_id = (select auth.uid()))
          and public.can_send_in_chat_room(chat_room_id));

-- ---------------------------------------------------------------------------
-- The contact list has to EXPLAIN itself, not just refuse.
--
-- get_chat_contacts already returns is_blocked, but the UI renders that as a
-- red "Blocked" pill — accurate for a revoked org connection, misleading and
-- unhelpful for an expired token, which the customer can fix themselves. A
-- `block_reason` column is added so the UI can say why and what to do:
--   'org_revoked'   -> the existing "Blocked" treatment
--   'token_expired' -> "Renew to message"
-- is_blocked keeps its meaning, so nothing that reads it today changes.
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
  -- A super admin belongs to no company; treat them as always licensed.
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

  -- Own colleagues. Unreachable while the token is expired, and said so.
  return query
    select d.user_id, d.display_name, d.avatar_url, d.company_id, d.company_name, d.org_type,
           d.is_super_admin, 'my_company'::text, 'MY COMPANY'::text,
           v_expired, case when v_expired then 'token_expired' end,
           d.role, d.last_seen_at
    from public.chat_directory d
    where d.company_id = v_company and d.user_id <> p_user_id and not d.is_super_admin;

  -- MineLink. NEVER blocked — this is the route to sorting the renewal out.
  return query
    select d.user_id, d.display_name, d.avatar_url, d.company_id, d.company_name, d.org_type,
           d.is_super_admin, 'mine_link'::text, 'MINE-LINK'::text, false, null::text,
           d.role, d.last_seen_at
    from public.chat_directory d
    where d.is_super_admin;

  -- Connected organisations. A revoked connection still reads 'org_revoked';
  -- an expired token takes precedence in the message because it is the thing
  -- the customer can actually act on.
  return query
    select d.user_id, d.display_name, d.avatar_url, d.company_id, d.company_name, d.org_type,
           d.is_super_admin, 'connected'::text, ('CONNECTED · ' || d.company_name),
           (v_expired or oc.status = 'revoked'),
           case when v_expired then 'token_expired'
                when oc.status = 'revoked' then 'org_revoked' end,
           d.role, d.last_seen_at
    from public.org_connections oc
    join public.chat_directory d
      on d.company_id = case when oc.company_low_id = v_company then oc.company_high_id else oc.company_low_id end
    where (oc.company_low_id = v_company or oc.company_high_id = v_company)
      and d.user_id <> p_user_id and not d.is_super_admin;
end $function$;

grant execute on function public.get_chat_contacts(uuid) to authenticated;

-- Verified on production as the expired owner of SteelWorks SA, in a
-- rolled-back transaction:
--   can_send_chat_to([me, super admin])   true   <- the route to renewal stays
--   can_send_chat_to([me, non-admin])     false  <- internal chat is closed
--   support_create_ticket(...)            ALLOWED
-- and as an ACTIVE company's owner, that messaging their own driver is
-- still permitted (true) — no regression.
