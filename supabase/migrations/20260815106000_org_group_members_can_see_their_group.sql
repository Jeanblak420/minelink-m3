-- Follow-up to 20260815105000, closing a gap that migration created.
--
-- An org group could be created and its invitations accepted, and then NOBODY
-- COULD READ IT. `are_chat_participants_allowed()` requires every participant
-- to be in the caller's own company (or a super admin) — which is right for a
-- DM and exactly wrong for a group whose entire purpose is to span companies.
-- The room existed, the membership rows existed, and `select … from chat_rooms`
-- returned nothing for the very people who had just joined.
--
-- Caught by walking the accept: the buyer's own "am I a participant now?" read
-- came back NULL, not false — the row was filtered away, not the flag unset.
--
-- Membership in an accepted org group is now its own route to a room,
-- alongside the same-company rule.
create or replace function public.is_org_group_member(target_chat_room_id uuid)
returns boolean
language sql
stable security definer
set search_path to 'public'
as $function$
  select exists (
    select 1
    from public.chat_room_companies rc
    where rc.chat_room_id = target_chat_room_id
      and rc.company_id = public.current_company_id()
      and rc.status = 'accepted'
  );
$function$;

comment on function public.is_org_group_member(uuid) is
  'True when the caller''s company has ACCEPTED its invitation to this group. '
  'A declined or still-pending invitation does not open the room — otherwise '
  '"decline" would mean nothing.';

create or replace function public.can_access_chat_room(target_chat_room_id uuid)
returns boolean
language sql
stable security definer
set search_path to 'public'
as $function$
  select public.is_org_group_member(target_chat_room_id)
      or exists (
        select 1
        from public.chat_rooms cr
        where cr.id = target_chat_room_id
          and public.are_chat_participants_allowed(cr.participant_ids)
      );
$function$;

drop policy if exists chat_rooms_select_members on public.chat_rooms;
create policy chat_rooms_select_members
  on public.chat_rooms for select to authenticated
  using (public.are_chat_participants_allowed(participant_ids)
         or public.is_org_group_member(id));

create or replace function public.can_send_in_chat_room(target_chat_room_id uuid)
returns boolean
language plpgsql
stable security definer
set search_path to 'public'
as $function$
declare
  v_participants uuid[];
  v_ended timestamptz;
  v_company uuid;
  v_pid uuid;
begin
  select cr.participant_ids, cr.ended_at into v_participants, v_ended
  from public.chat_rooms cr where cr.id = target_chat_room_id;

  if v_participants is null then
    return false;
  end if;

  -- An ended conversation accepts nothing further, from anyone (S8-4).
  if v_ended is not null then
    return false;
  end if;

  -- Either the ordinary participation rule, or membership of an accepted
  -- org group. NOT the P10-07 initiation hierarchy — replying is ungated.
  if not (public.are_chat_participants_allowed(v_participants)
          or public.is_org_group_member(target_chat_room_id)) then
    return false;
  end if;

  if public.chat_is_super_admin(auth.uid()) then
    return true;
  end if;

  v_company := public.current_company_id();
  if v_company is null then
    return false;
  end if;

  if public.is_company_active(v_company) then
    return true;
  end if;

  foreach v_pid in array v_participants
  loop
    if v_pid <> auth.uid() and not public.chat_is_super_admin(v_pid) then
      return false;
    end if;
  end loop;

  return true;
end;
$function$;

-- Verified on production, rolled back:
--   BEFORE accepting: buyer reads the room   0 rows  (decline means something)
--   AFTER accepting:  buyer reads the room   1 row
--   AFTER accepting:  buyer may post         true
