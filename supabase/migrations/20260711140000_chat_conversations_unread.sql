-- Conversation list with per-room unread count + the latest message's
-- read/delivered state, so the chat list can show CPS-style unread badges and
-- delivery ticks. Ordered newest-activity first.
create or replace function public.get_chat_conversations(p_user_id uuid)
returns table(
  id uuid,
  name text,
  participant_ids uuid[],
  type text,
  company_a_id uuid,
  company_b_id uuid,
  created_by uuid,
  created_at timestamptz,
  last_message_content text,
  last_message_timestamp timestamptz,
  last_message_sender_id uuid,
  unread_count integer,
  last_message_read_at timestamptz,
  last_message_delivered_at timestamptz
)
language sql
stable
security definer
set search_path to 'public'
as $$
  select
    r.id, r.name, r.participant_ids, r.type,
    r.company_a_id, r.company_b_id, r.created_by, r.created_at,
    r.last_message_content, r.last_message_timestamp, r.last_message_sender_id,
    coalesce((
      select count(*) from public.chat_messages m
      where m.chat_room_id = r.id
        and m.sender_id <> p_user_id
        and m.read_at is null
    ), 0)::int as unread_count,
    lm.read_at as last_message_read_at,
    lm.delivered_at as last_message_delivered_at
  from public.chat_rooms r
  left join lateral (
    select m2.read_at, m2.delivered_at
    from public.chat_messages m2
    where m2.chat_room_id = r.id
    order by m2.timestamp desc
    limit 1
  ) lm on true
  where r.participant_ids @> array[p_user_id]::uuid[]
  order by coalesce(r.last_message_timestamp, r.created_at) desc;
$$;

grant execute on function public.get_chat_conversations(uuid) to authenticated;

-- Make the conversation list drivable by Supabase Realtime: chat_rooms must be
-- in the realtime publication with full row images (chat_messages already is).
alter table public.chat_rooms replica identity full;
do $$
begin
  begin
    alter publication supabase_realtime add table public.chat_rooms;
  exception when duplicate_object then null;
  end;
end $$;

notify pgrst, 'reload schema';
