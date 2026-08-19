-- Follow-up to 20260815100000, fixing a bug that migration introduced.
--
-- That migration put the P10-07 hierarchy into can_send_chat_to(), and
-- can_send_in_chat_room() delegates to it — so the hierarchy leaked onto
-- REPLYING as well as starting. The comment in that file said, in as many
-- words, that replying is deliberately ungated; the code did the opposite.
--
-- Caught by walking it: a driver in an existing room with the company owner
-- got `can_send_in_chat_room = false`. That is precisely the outcome the
-- comment warned about — management opens a conversation with a driver and
-- the driver cannot answer, turning outreach into a one-way broadcast.
--
-- can_send_in_chat_room now carries its own rules: you must be a participant,
-- and your company must not be expired. Who was allowed to START the room was
-- already decided when the room was created.
create or replace function public.can_send_in_chat_room(target_chat_room_id uuid)
returns boolean
language plpgsql
stable security definer
set search_path to 'public'
as $function$
declare
  v_participants uuid[];
  v_company uuid;
  v_pid uuid;
begin
  select cr.participant_ids into v_participants
  from public.chat_rooms cr where cr.id = target_chat_room_id;

  if v_participants is null then
    return false;
  end if;

  -- Participation only. NOT can_send_chat_to() — that one carries the
  -- initiation hierarchy, which must not reach replies.
  if not public.are_chat_participants_allowed(v_participants) then
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

  -- Expired: may still reply, but only where every other participant is a
  -- super global admin — the MineLink conversation stays open so the renewal
  -- can be sorted out.
  foreach v_pid in array v_participants
  loop
    if v_pid <> auth.uid() and not public.chat_is_super_admin(v_pid) then
      return false;
    end if;
  end loop;

  return true;
end;
$function$;

comment on function public.can_send_in_chat_room(uuid) is
  'Replying in an existing room: participation + the expired-token rule, and '
  'deliberately NOT the P10-07 initiation hierarchy. Gating replies would let '
  'management open a chat a driver cannot answer.';

-- Verified on production, rolled back:
--   driver REPLIES in an existing room with the owner   true
--   driver STARTS a new room with the owner             false
--   driver STARTS a room with an admin                  true
--   expired owner starts a chat with MineLink           true
--   expired owner starts a chat with a non-admin        false
