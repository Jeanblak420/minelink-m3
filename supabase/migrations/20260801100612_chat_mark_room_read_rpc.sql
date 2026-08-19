-- Fix: chat unread count never clears when messages are read.
--
-- Root cause: public.chat_messages has RLS enabled but NO UPDATE policy — the
-- canonical reset (20260327000100) + align (20260329120000) created only SELECT
-- and INSERT policies (align even drops chat_messages_update_members and never
-- recreates it). So the client-side markRoomRead `.update({read_at,...})`
-- silently affected 0 rows (PostgREST returns success, changes nothing),
-- read_at stayed null, and get_chat_conversations kept counting every inbound
-- message as unread forever. (Delivered ticks worked because they go through the
-- SECURITY DEFINER chat_mark_all_delivered RPC, which bypasses RLS.)
--
-- Fix: mirror that working pattern — mark a room read via a SECURITY DEFINER
-- RPC, so a participant can set read_at/delivered_at on INBOUND messages without
-- opening a broad (column-unrestricted) UPDATE policy on chat_messages.

create or replace function public.chat_mark_room_read(p_room_id uuid)
returns integer
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_uid   uuid := auth.uid();
  v_count integer;
begin
  if v_uid is null then
    return 0;
  end if;

  -- Only a participant of the room may mark it read (reuses the same access
  -- helper the SELECT policy uses).
  if not public.can_access_chat_room(p_room_id) then
    raise exception 'Not a participant of chat room %', p_room_id;
  end if;

  update public.chat_messages
     set is_read      = true,
         read_at      = now(),
         delivered_at = coalesce(delivered_at, now())
   where chat_room_id = p_room_id
     and sender_id   <> v_uid
     and read_at is null;

  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

revoke execute on function public.chat_mark_room_read(uuid) from anon, public;
grant execute on function public.chat_mark_room_read(uuid) to authenticated;

notify pgrst, 'reload schema';
