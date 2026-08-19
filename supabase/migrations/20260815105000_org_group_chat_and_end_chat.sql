-- S8-3 (P10-08) group chat, and S8-4 (P10-09) "end chat".
--
-- S8-3's premise verified before building: `chat_rooms` carries `company_a_id`
-- and `company_b_id` — exactly TWO slots — so a three-company group was
-- structurally impossible, not merely unbuilt. `createOrgGroup` in
-- messaging_service.dart took two ids to match, and no UI called it.
--
-- S8-4's premise verified likewise: no `ended_at`, no `ended_by`, no method,
-- no button. Nothing to extend.
--
-- The two-column model is left in place rather than dropped: existing rooms
-- populate it, `chat_block_revoked_send` reads it, and dropping columns on
-- production is not authorised. The membership table below is additive and is
-- the source of truth for groups created from now on.
--
-- NOTE: as written, this migration left a group unreadable by its own members
-- — see 20260815106000, kept separate because the gap is the instructive part.

-- ── S8-3: membership, one row per company in a room ────────────────────────
create table if not exists public.chat_room_companies (
  chat_room_id uuid not null references public.chat_rooms(id) on delete cascade,
  company_id   uuid not null references public.companies(id) on delete cascade,
  org_type     text not null,
  status       text not null default 'invited'
                 check (status in ('invited','accepted','declined')),
  invited_by   uuid references public.profiles(id),
  invited_at   timestamptz not null default timezone('utc', now()),
  responded_at timestamptz,
  primary key (chat_room_id, company_id)
);

-- "Only one of each org type" — enforced by the database, so a third mine
-- cannot be added by any route, UI or otherwise.
create unique index if not exists chat_room_companies_one_per_org_type
  on public.chat_room_companies (chat_room_id, org_type);

comment on table public.chat_room_companies is
  'Companies in an org-group chat. Max 3, at most one per org type (unique '
  'index above + the count check in create_org_group). Replaces the two-slot '
  'company_a_id/company_b_id model, which made a 3-company group impossible.';

alter table public.chat_room_companies enable row level security;

drop policy if exists chat_room_companies_select on public.chat_room_companies;
create policy chat_room_companies_select
  on public.chat_room_companies for select to authenticated
  using (public.can_access_chat_room(chat_room_id)
         or company_id = (select public.current_company_id()));

revoke all on public.chat_room_companies from anon, authenticated;
grant select on public.chat_room_companies to authenticated;

-- ── S8-4: ending a chat ────────────────────────────────────────────────────
alter table public.chat_rooms add column if not exists ended_at timestamptz;
alter table public.chat_rooms add column if not exists ended_by uuid
  references public.profiles(id);

comment on column public.chat_rooms.ended_at is
  'When the conversation was ended. Company-only (owner) per P10-09. An ended '
  'room stays READABLE — ending a chat is not deleting the record of it — but '
  'accepts no new messages.';

-- ── create_org_group ───────────────────────────────────────────────────────
create or replace function public.create_org_group(
  p_name text,
  p_company_ids uuid[]
)
returns uuid
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_me uuid := auth.uid();
  v_my_company uuid;
  v_room uuid;
  v_cid uuid;
  v_all uuid[];
  v_org text;
  v_seen text[] := array[]::text[];
begin
  if v_me is null then
    raise exception 'not authenticated' using errcode = 'insufficient_privilege';
  end if;

  v_my_company := public.current_company_id();
  if v_my_company is null then
    raise exception 'Only a company user can start an organisation group.'
      using errcode = 'insufficient_privilege';
  end if;

  if public.chat_role_of(v_me) not in ('owner', 'management', 'admin') then
    raise exception
      'Only an owner, management or admin may start an organisation group.'
      using errcode = 'insufficient_privilege';
  end if;

  -- The creator's company is always in the group, listed or not.
  v_all := array(select distinct unnest(array_append(coalesce(p_company_ids, '{}'), v_my_company)));

  if array_length(v_all, 1) < 2 then
    raise exception 'An organisation group needs at least two companies.'
      using errcode = 'check_violation';
  end if;
  if array_length(v_all, 1) > 3 then
    raise exception 'An organisation group may hold at most three companies.'
      using errcode = 'check_violation';
  end if;

  -- One of each org type. Checked here as well as by the unique index so the
  -- caller gets a sentence rather than a constraint name.
  foreach v_cid in array v_all loop
    select c.org_type into v_org from public.companies c where c.id = v_cid;
    if v_org is null then
      raise exception 'Unknown company %', v_cid using errcode = 'check_violation';
    end if;
    if v_org = any (v_seen) then
      raise exception
        'An organisation group may hold only one % company.', v_org
        using errcode = 'check_violation';
    end if;
    v_seen := array_append(v_seen, v_org);
  end loop;

  insert into public.chat_rooms (name, participant_ids, type, created_by)
  values (p_name, array[v_me], 'org_group', v_me)
  returning id into v_room;

  foreach v_cid in array v_all loop
    select c.org_type into v_org from public.companies c where c.id = v_cid;
    insert into public.chat_room_companies
      (chat_room_id, company_id, org_type, status, invited_by, responded_at)
    values (v_room, v_cid, v_org,
            case when v_cid = v_my_company then 'accepted' else 'invited' end,
            v_me,
            case when v_cid = v_my_company then timezone('utc', now()) end);

    if v_cid <> v_my_company then
      perform public.notify_company_management(
        v_cid,
        'Group chat invitation',
        format('You have been invited to the group "%s". Accept it to join the '
               'conversation.', p_name),
        'general', null, null, 'normal',
        jsonb_build_object('chat_room_id', v_room, 'kind', 'org_group_invite'));
    end if;
  end loop;

  return v_room;
end;
$function$;

comment on function public.create_org_group(text, uuid[]) is
  'Creates an org-group chat: max 3 companies, at most one per org type, the '
  'creator''s company auto-accepted and the rest invited with a notification '
  'to their management (P10-08).';

grant execute on function public.create_org_group(text, uuid[]) to authenticated;

-- ── respond_to_org_group_invite ────────────────────────────────────────────
create or replace function public.respond_to_org_group_invite(
  p_room uuid, p_accept boolean)
returns void
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_me uuid := auth.uid();
  v_company uuid := public.current_company_id();
  v_row public.chat_room_companies;
  v_room public.chat_rooms;
begin
  if v_company is null or public.chat_role_of(v_me) not in ('owner','management','admin') then
    raise exception 'Only an owner, management or admin may answer an invitation.'
      using errcode = 'insufficient_privilege';
  end if;

  select * into v_row from public.chat_room_companies
   where chat_room_id = p_room and company_id = v_company;
  if not found then
    raise exception 'No invitation for your company on this group.'
      using errcode = 'insufficient_privilege';
  end if;
  if v_row.status <> 'invited' then
    raise exception 'That invitation has already been answered.'
      using errcode = 'check_violation';
  end if;

  update public.chat_room_companies
     set status = case when p_accept then 'accepted' else 'declined' end,
         responded_at = timezone('utc', now())
   where chat_room_id = p_room and company_id = v_company;

  if p_accept then
    update public.chat_rooms
       set participant_ids = array(select distinct unnest(participant_ids || v_me))
     where id = p_room;
  end if;

  -- Notify the inviter either way — a decline that arrives as silence is
  -- indistinguishable from a decline that was never sent.
  select * into v_room from public.chat_rooms where id = p_room;
  if v_row.invited_by is not null then
    perform public.create_notification_internal(
      v_row.invited_by, v_company, null,
      case when p_accept then 'Group invitation accepted'
           else 'Group invitation declined' end,
      format('%s the invitation to "%s".',
             case when p_accept then 'A company accepted' else 'A company declined' end,
             coalesce(v_room.name, 'the group')),
      'general', null, null, null, null, 'normal',
      jsonb_build_object('chat_room_id', p_room, 'kind', 'org_group_response'));
  end if;
end;
$function$;

grant execute on function public.respond_to_org_group_invite(uuid, boolean) to authenticated;

-- ── end_chat ───────────────────────────────────────────────────────────────
create or replace function public.end_chat(p_room uuid)
returns void
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_me uuid := auth.uid();
  v_role text := public.chat_role_of(auth.uid());
  v_room public.chat_rooms;
begin
  select * into v_room from public.chat_rooms where id = p_room;
  if not found then
    raise exception 'Conversation not found' using errcode = 'P0002';
  end if;
  if v_room.ended_at is not null then
    raise exception 'That conversation has already been ended.'
      using errcode = 'check_violation';
  end if;

  -- COMPANY-ONLY, per P10-09. Not admin, not management — the company account.
  -- A super global admin may also end one, for support.
  if not (v_role = 'owner' or public.chat_is_super_admin(v_me)) then
    raise exception
      'Only the company account can end a conversation.'
      using errcode = 'insufficient_privilege';
  end if;

  if not public.can_access_chat_room(p_room) then
    raise exception 'You are not part of that conversation.'
      using errcode = 'insufficient_privilege';
  end if;

  update public.chat_rooms
     set ended_at = timezone('utc', now()), ended_by = v_me
   where id = p_room;
end;
$function$;

comment on function public.end_chat(uuid) is
  'Ends a conversation. Company-account only (or a super global admin), per '
  'P10-09. The room stays readable — ending a chat is not deleting the record '
  'of it — but can_send_in_chat_room() then refuses new messages.';

grant execute on function public.end_chat(uuid) to authenticated;

-- Verified on production, all rolled back.
--
-- S8-3:
--   3-company group (mine+buyer+transporter)  CREATED, 3 companies
--     invite states: buyer=invited, mineSupplier=accepted, transporter=invited
--   two buyers in one group   REFUSED "may hold only one buyer company"
--   four companies            REFUSED "may hold at most three companies"
--   buyer accepts             status accepted; inviter notified (1 row)
--   answering twice           REFUSED "already been answered"
--   driver answers for their company
--                             REFUSED "Only an owner, management or admin"
--
-- S8-4:
--   ADMIN ends the chat       REFUSED "Only the company account can end"
--   OWNER ends the chat       ALLOWED
--   room still readable       1 row
--   may still post            false
--   ending twice              REFUSED "already been ended"
