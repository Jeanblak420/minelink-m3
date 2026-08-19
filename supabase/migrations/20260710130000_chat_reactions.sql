-- ============================================================================
-- Chat message reactions (emoji reactions on a message). room_id is
-- denormalised so a room's reactions can be streamed in one subscription.
-- ============================================================================
create table if not exists public.chat_message_reactions (
  id         uuid primary key default gen_random_uuid(),
  room_id    uuid not null,
  message_id uuid not null references public.chat_messages(id) on delete cascade,
  user_id    uuid not null,
  emoji      text not null,
  created_at timestamptz not null default now(),
  unique (message_id, user_id, emoji)
);
create index if not exists idx_reactions_room on public.chat_message_reactions (room_id);
create index if not exists idx_reactions_msg  on public.chat_message_reactions (message_id);

alter table public.chat_message_reactions enable row level security;

-- Membership check without tripping chat_rooms' own RLS.
create or replace function public.chat_is_room_participant(p_room uuid)
  returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.chat_rooms r
    where r.id = p_room and (select auth.uid()) = any (r.participant_ids)
  );
$$;

drop policy if exists reactions_select on public.chat_message_reactions;
create policy reactions_select on public.chat_message_reactions
  for select to authenticated
  using (public.chat_is_room_participant(room_id));

drop policy if exists reactions_insert on public.chat_message_reactions;
create policy reactions_insert on public.chat_message_reactions
  for insert to authenticated
  with check (user_id = (select auth.uid()) and public.chat_is_room_participant(room_id));

drop policy if exists reactions_delete on public.chat_message_reactions;
create policy reactions_delete on public.chat_message_reactions
  for delete to authenticated
  using (user_id = (select auth.uid()));

grant select, insert, delete on public.chat_message_reactions to authenticated;

alter table public.chat_message_reactions replica identity full;
do $$ begin
  alter publication supabase_realtime add table public.chat_message_reactions;
exception when duplicate_object then null; end $$;
