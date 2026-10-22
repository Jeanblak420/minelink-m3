-- Chat history works like Messenger: whoever was in a conversation can always
-- read it, from any device, whatever has happened to their company since.
--
-- ⚠️ Applied from the MineLink-M3 project, whose CLAUDE.md forbids migrations.
-- Jean authorised this one exception on 2026-10-22 ("Allow it from M3"). The
-- canonical tree (worktree-2026-05-05T11-53-29) has no copy of this file; its
-- ledger check will report this row until one is added there.
--
-- ## What was wrong
--
-- Reading a room went through `can_access_chat_room`, i.e.
-- `are_chat_participants_allowed`, which demands that EVERY participant is,
-- right now, an active member of the READER's current company (super admins
-- excepted). That is a rule about who may START a conversation, and applied
-- to reading it meant:
--
--   * a co-worker leaves or is deactivated  -> your whole DM with them blanks;
--   * one member of a group leaves          -> the group blanks for everyone;
--   * you move company                      -> every old chat blanks.
--
-- `get_chat_conversations` (SECURITY DEFINER) still LISTED those rooms, so they
-- opened as empty threads. And org groups were only ever listed for their
-- creator, because `create_org_group` puts only the creator in participant_ids.
--
-- ## The rule now (client ruling 2026-10-22: "Everyone keeps reading")
--
-- You may READ a room if you are in participant_ids, OR your company is an
-- accepted member of the org group, OR you have ever sent a message in it.
-- That last clause is what lets someone who left keep an org group they took
-- part in.
--
-- Deliberately NOT changed: anything that writes. Sending
-- (`can_send_in_chat_room`, `can_send_chat_to`), ending a chat, and uploading,
-- replacing or deleting attachments keep `can_access_chat_room` — so a leaver
-- can read the history but cannot add to it or delete files from it.
-- `can_access_chat_room` itself is left alone for exactly that reason.

-- ---------------------------------------------------------------- the rule
create or replace function public.can_read_chat_room(target_chat_room_id uuid)
returns boolean
language sql
stable
security definer
set search_path to 'public'
as $function$
  select (select auth.uid()) is not null
     and (
       exists (
         select 1 from public.chat_rooms r
         where r.id = target_chat_room_id
           and (select auth.uid()) = any (r.participant_ids)
       )
       or public.is_org_group_member(target_chat_room_id)
       or exists (
         select 1 from public.chat_messages m
         where m.chat_room_id = target_chat_room_id
           and m.sender_id = (select auth.uid())
       )
     );
$function$;

comment on function public.can_read_chat_room(uuid) is
  'Read access to a chat room: participant, accepted org-group member, or has '
  'ever sent a message there. Write paths use can_access_chat_room instead. '
  'See 20261022200000.';

revoke execute on function public.can_read_chat_room(uuid) from public, anon;
grant execute on function public.can_read_chat_room(uuid) to authenticated;

-- ------------------------------------------------------------ read policies
alter policy chat_messages_select_members on public.chat_messages
  using (public.can_read_chat_room(chat_room_id));

alter policy chat_rooms_select_members on public.chat_rooms
  using (public.can_read_chat_room(id));

alter policy chat_room_companies_select on public.chat_room_companies
  using (public.can_read_chat_room(chat_room_id)
         or company_id = (select public.current_company_id()));

-- Reactions were participant_ids-only, so org-group members never saw them.
alter policy reactions_select on public.chat_message_reactions
  using (public.can_read_chat_room(room_id));

-- Attachments: reading only. Insert / update / delete keep can_access_chat_room.
alter policy chat_attach_select on storage.objects
  using (bucket_id = 'chat-attachments'
         and coalesce(array_length(storage.foldername(name), 1), 0) >= 1
         and public.can_read_chat_room(((storage.foldername(name))[1])::uuid));

alter policy chat_files_select_room_participants on storage.objects
  using (bucket_id = 'chat_files'
         and public.can_read_chat_room(((storage.foldername(name))[1])::uuid));

-- ------------------------------------------- functions patched in the catalog
-- Patched from pg_get_functiondef rather than retyped, per CLAUDE.md §6 rule 6,
-- and every anchor is asserted first so a body that has drifted raises instead
-- of being patched blind.
do $patch$
declare
  v_def text;
  v_fn text;
  v_old text;
  v_new text;
begin
  -- Marking a thread read is a reader's action.
  foreach v_fn in array array[
    'public.chat_mark_room_read(uuid)',
    'public.mark_chat_messages_read(uuid,uuid)'
  ] loop
    v_def := pg_get_functiondef(v_fn::regprocedure);
    if v_def not like '%public.can_access_chat_room(%' then
      raise exception 'anchor missing in %: can_access_chat_room', v_fn;
    end if;
    execute replace(v_def, 'public.can_access_chat_room(', 'public.can_read_chat_room(');
  end loop;

  -- The conversation list: every room the user can read, not just the ones
  -- whose participant_ids name them.
  v_fn := 'public.get_chat_conversations(uuid)';
  v_def := pg_get_functiondef(v_fn::regprocedure);
  v_old := 'where r.participant_ids @> array[p_user_id]::uuid[]';
  v_new := 'where r.participant_ids @> array[p_user_id]::uuid[]
       -- 20261022200000: org groups the user''s company accepted, and rooms
       -- they once wrote in, are theirs to read too (can_read_chat_room).
       or exists (
         select 1 from public.chat_room_companies rc
         where rc.chat_room_id = r.id
           and rc.status = ''accepted''
           and rc.company_id = public.chat_user_company_id(p_user_id)
       )
       or exists (
         select 1 from public.chat_messages ms
         where ms.chat_room_id = r.id and ms.sender_id = p_user_id
       )';
  if position(v_old in v_def) = 0 then
    raise exception 'anchor missing in %: %', v_fn, v_old;
  end if;
  execute replace(v_def, v_old, v_new);
end
$patch$;

-- --------------------------------------------- one DM per pair, atomically
-- Opening a DM was a client-side check-then-insert, so two taps (or two
-- devices) could each find nothing and each insert: production held three
-- rooms for one pair, created within 0.37 s on 2026-10-21. This does the same
-- thing under a per-pair advisory lock, so concurrent callers queue and the
-- second finds the first's room.
--
-- Returns EVERY dm room for the pair (existing duplicates included) so the
-- client can fold them with collapseDuplicateDms and show their full history.
-- No unique index: three duplicates already exist, and nothing on this
-- platform is deleted.
create or replace function public.get_or_create_dm(
  p_other_user_id uuid,
  p_name text default null
)
returns setof public.chat_rooms
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_me uuid := auth.uid();
  v_lo uuid;
  v_hi uuid;
begin
  if v_me is null then
    raise exception 'not authenticated' using errcode = 'insufficient_privilege';
  end if;
  if p_other_user_id is null or p_other_user_id = v_me then
    raise exception 'A conversation needs another person.'
      using errcode = 'check_violation';
  end if;

  v_lo := least(v_me, p_other_user_id);
  v_hi := greatest(v_me, p_other_user_id);
  perform pg_advisory_xact_lock(
    hashtextextended('chat_dm:' || v_lo::text || ':' || v_hi::text, 0));

  if not exists (
    select 1 from public.chat_rooms r
    where r.type = 'dm'
      and r.participant_ids @> array[v_lo, v_hi]
      and cardinality(array(select distinct unnest(r.participant_ids))) = 2
  ) then
    -- Same bar as the chat_rooms INSERT policy this replaces.
    if not public.can_send_chat_to(array[v_me, p_other_user_id]) then
      raise exception 'You cannot start a conversation with this person.'
        using errcode = 'insufficient_privilege';
    end if;
    insert into public.chat_rooms (name, participant_ids, type, created_by)
    values (coalesce(nullif(trim(p_name), ''), 'Conversation'),
            array[v_me, p_other_user_id], 'dm', v_me);
  end if;

  return query
    select r.* from public.chat_rooms r
    where r.type = 'dm'
      and r.participant_ids @> array[v_lo, v_hi]
      and cardinality(array(select distinct unnest(r.participant_ids))) = 2
    order by r.created_at;
end;
$function$;

comment on function public.get_or_create_dm(uuid, text) is
  'Atomic get-or-create for a 1:1 chat. Returns every dm room for the pair '
  '(duplicates predate it). See 20261022200000.';

revoke execute on function public.get_or_create_dm(uuid, text) from public, anon;
grant execute on function public.get_or_create_dm(uuid, text) to authenticated;
