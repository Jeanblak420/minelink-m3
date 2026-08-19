-- ============================================================================
-- Delivery/read receipts:
--  * chat_mark_all_delivered() — marks every inbound, not-yet-delivered message
--    (across all the caller's rooms) as delivered. Called when the chat is open
--    so the sender sees the double (delivered) tick even before the recipient
--    opens that specific thread. Read stays separate (set on thread open).
--  * REPLICA IDENTITY FULL on chat_messages so realtime UPDATE events carry the
--    full row — the sender's message stream then reflects tick changes live.
-- ============================================================================
create or replace function public.chat_mark_all_delivered()
  returns void
  language sql security definer set search_path = public as $$
  update public.chat_messages m
  set delivered_at = now()
  where m.delivered_at is null
    and m.sender_id <> (select auth.uid())
    and exists (
      select 1 from public.chat_rooms r
      where r.id = m.chat_room_id and (select auth.uid()) = any (r.participant_ids)
    );
$$;
grant execute on function public.chat_mark_all_delivered() to authenticated;

alter table public.chat_messages replica identity full;
do $$ begin
  alter publication supabase_realtime add table public.chat_messages;
exception when duplicate_object then null; end $$;
