-- ============================================================================
-- MineLink Chat — Support tickets.
-- Any user logs a ticket to the Super Global Admins. Both admins can be in the
-- inbox; whoever ACCEPTS becomes the handler and the ticket auto-advances to
-- 'in_progress'. Admins can message the logger and mark it 'completed'. Each
-- stage change records a timeline event and notifies the logger.
-- Mirrors templates/chat/chat-support.jsx.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- Tickets
-- ---------------------------------------------------------------------------
create table if not exists public.support_tickets (
  id               uuid primary key default gen_random_uuid(),
  created_by       uuid not null,
  company_id       uuid,
  subject          text not null,
  category         text not null default 'General',
  status           text not null default 'sent'
                     check (status in ('sent','in_progress','completed')),
  accepted_by      uuid,
  accepted_by_name text,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now()
);
create index if not exists idx_support_tickets_creator on public.support_tickets (created_by);
create index if not exists idx_support_tickets_status  on public.support_tickets (status);

-- ---------------------------------------------------------------------------
-- Ticket conversation messages
-- ---------------------------------------------------------------------------
create table if not exists public.support_ticket_messages (
  id          uuid primary key default gen_random_uuid(),
  ticket_id   uuid not null references public.support_tickets(id) on delete cascade,
  sender_id   uuid not null,
  sender_name text not null default '',
  content     text not null,
  created_at  timestamptz not null default now()
);
create index if not exists idx_support_msgs_ticket on public.support_ticket_messages (ticket_id, created_at);

-- ---------------------------------------------------------------------------
-- Timeline events (sent / accepted / in_progress / completed)
-- ---------------------------------------------------------------------------
create table if not exists public.support_ticket_events (
  id         uuid primary key default gen_random_uuid(),
  ticket_id  uuid not null references public.support_tickets(id) on delete cascade,
  type       text not null check (type in ('sent','accepted','in_progress','completed')),
  actor_id   uuid,
  actor_name text,
  created_at timestamptz not null default now()
);
create index if not exists idx_support_events_ticket on public.support_ticket_events (ticket_id, created_at);

-- ---------------------------------------------------------------------------
-- Per-logger notifications (the "UPDATES" list)
-- ---------------------------------------------------------------------------
create table if not exists public.support_notifications (
  id         uuid primary key default gen_random_uuid(),
  ticket_id  uuid not null references public.support_tickets(id) on delete cascade,
  user_id    uuid not null,
  text       text not null,
  read       boolean not null default false,
  created_at timestamptz not null default now()
);
create index if not exists idx_support_notifs_user on public.support_notifications (user_id, read, created_at);

-- ---------------------------------------------------------------------------
-- Which admins receive new tickets
-- ---------------------------------------------------------------------------
create table if not exists public.support_inbox_prefs (
  admin_id   uuid primary key,
  receiving  boolean not null default true,
  updated_at timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- RLS
-- ---------------------------------------------------------------------------
alter table public.support_tickets         enable row level security;
alter table public.support_ticket_messages enable row level security;
alter table public.support_ticket_events   enable row level security;
alter table public.support_notifications   enable row level security;
alter table public.support_inbox_prefs     enable row level security;

-- Tickets: logger sees/creates own; super admins see all + update.
drop policy if exists support_tickets_select on public.support_tickets;
create policy support_tickets_select on public.support_tickets
  for select to authenticated
  using (created_by = (select auth.uid()) or public.chat_is_super_admin((select auth.uid())));

drop policy if exists support_tickets_insert on public.support_tickets;
create policy support_tickets_insert on public.support_tickets
  for insert to authenticated
  with check (created_by = (select auth.uid()));

drop policy if exists support_tickets_update on public.support_tickets;
create policy support_tickets_update on public.support_tickets
  for update to authenticated
  using (public.chat_is_super_admin((select auth.uid())))
  with check (public.chat_is_super_admin((select auth.uid())));

-- A row is visible to the logger or any super admin.
create or replace function public.support_can_see_ticket(p_ticket uuid)
  returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.support_tickets t
    where t.id = p_ticket
      and (t.created_by = (select auth.uid())
           or public.chat_is_super_admin((select auth.uid())))
  );
$$;

-- Messages: participants read; participants insert their own.
drop policy if exists support_msgs_select on public.support_ticket_messages;
create policy support_msgs_select on public.support_ticket_messages
  for select to authenticated
  using (public.support_can_see_ticket(ticket_id));

drop policy if exists support_msgs_insert on public.support_ticket_messages;
create policy support_msgs_insert on public.support_ticket_messages
  for insert to authenticated
  with check (sender_id = (select auth.uid()) and public.support_can_see_ticket(ticket_id));

-- Events: participants read; inserts happen via SECURITY DEFINER RPCs below.
drop policy if exists support_events_select on public.support_ticket_events;
create policy support_events_select on public.support_ticket_events
  for select to authenticated
  using (public.support_can_see_ticket(ticket_id));

-- Notifications: recipient reads / updates (mark read).
drop policy if exists support_notifs_all on public.support_notifications;
create policy support_notifs_all on public.support_notifications
  for all to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

-- Inbox prefs: super admins manage.
drop policy if exists support_inbox_all on public.support_inbox_prefs;
create policy support_inbox_all on public.support_inbox_prefs
  for all to authenticated
  using (public.chat_is_super_admin((select auth.uid())))
  with check (public.chat_is_super_admin((select auth.uid())));

-- ---------------------------------------------------------------------------
-- Workflow RPCs (SECURITY DEFINER — write events + notifications atomically)
-- ---------------------------------------------------------------------------

-- Create a ticket: inserts the row, its first message, a 'sent' event.
create or replace function public.support_create_ticket(
  p_subject text, p_category text, p_body text
) returns uuid language plpgsql security definer set search_path = public as $$
declare v_id uuid; v_company uuid; v_uid uuid := (select auth.uid());
begin
  if v_uid is null then raise exception 'not authenticated'; end if;
  v_company := public.chat_user_company_id(v_uid);
  insert into public.support_tickets (created_by, company_id, subject, category)
    values (v_uid, v_company, p_subject, p_category)
    returning id into v_id;
  insert into public.support_ticket_messages (ticket_id, sender_id, sender_name, content)
    values (v_id, v_uid, '', p_body);
  insert into public.support_ticket_events (ticket_id, type, actor_id)
    values (v_id, 'sent', v_uid);
  return v_id;
end $$;

-- Accept a ticket (admin becomes handler, → in_progress).
create or replace function public.support_accept_ticket(
  p_ticket uuid, p_actor_name text
) returns void language plpgsql security definer set search_path = public as $$
declare v_uid uuid := (select auth.uid()); v_creator uuid;
begin
  if not public.chat_is_super_admin(v_uid) then raise exception 'not an admin'; end if;
  update public.support_tickets
    set status = 'in_progress', accepted_by = v_uid, accepted_by_name = p_actor_name, updated_at = now()
    where id = p_ticket and status = 'sent'
    returning created_by into v_creator;
  if v_creator is null then return; end if;
  insert into public.support_ticket_events (ticket_id, type, actor_id, actor_name)
    values (p_ticket, 'accepted', v_uid, p_actor_name),
           (p_ticket, 'in_progress', v_uid, p_actor_name);
  insert into public.support_notifications (ticket_id, user_id, text)
    values (p_ticket, v_creator, p_actor_name || ' is now handling your ticket.');
end $$;

-- Complete a ticket.
create or replace function public.support_complete_ticket(
  p_ticket uuid, p_actor_name text
) returns void language plpgsql security definer set search_path = public as $$
declare v_uid uuid := (select auth.uid()); v_creator uuid;
begin
  if not public.chat_is_super_admin(v_uid) then raise exception 'not an admin'; end if;
  update public.support_tickets
    set status = 'completed', updated_at = now()
    where id = p_ticket
    returning created_by into v_creator;
  if v_creator is null then return; end if;
  insert into public.support_ticket_events (ticket_id, type, actor_id, actor_name)
    values (p_ticket, 'completed', v_uid, p_actor_name);
  insert into public.support_notifications (ticket_id, user_id, text)
    values (p_ticket, v_creator, 'Your ticket was completed by ' || p_actor_name || '.');
end $$;

-- Post a message on a ticket (and notify the other party when an admin replies).
create or replace function public.support_add_message(
  p_ticket uuid, p_content text, p_sender_name text
) returns uuid language plpgsql security definer set search_path = public as $$
declare v_uid uuid := (select auth.uid()); v_id uuid; v_creator uuid;
begin
  if not public.support_can_see_ticket(p_ticket) then raise exception 'no access'; end if;
  insert into public.support_ticket_messages (ticket_id, sender_id, sender_name, content)
    values (p_ticket, v_uid, coalesce(p_sender_name,''), p_content)
    returning id into v_id;
  select created_by into v_creator from public.support_tickets where id = p_ticket;
  if public.chat_is_super_admin(v_uid) and v_creator is not null and v_creator <> v_uid then
    insert into public.support_notifications (ticket_id, user_id, text)
      values (p_ticket, v_creator, coalesce(p_sender_name,'Support') || ' replied to your ticket.');
  end if;
  return v_id;
end $$;

grant execute on function public.support_create_ticket(text,text,text)   to authenticated;
grant execute on function public.support_accept_ticket(uuid,text)         to authenticated;
grant execute on function public.support_complete_ticket(uuid,text)       to authenticated;
grant execute on function public.support_add_message(uuid,text,text)      to authenticated;

-- ---------------------------------------------------------------------------
-- Realtime
-- ---------------------------------------------------------------------------
alter table public.support_tickets         replica identity full;
alter table public.support_ticket_messages replica identity full;
alter table public.support_ticket_events   replica identity full;
alter table public.support_notifications   replica identity full;
do $$ begin alter publication supabase_realtime add table public.support_tickets;         exception when duplicate_object then null; end $$;
do $$ begin alter publication supabase_realtime add table public.support_ticket_messages; exception when duplicate_object then null; end $$;
do $$ begin alter publication supabase_realtime add table public.support_ticket_events;   exception when duplicate_object then null; end $$;
do $$ begin alter publication supabase_realtime add table public.support_notifications;   exception when duplicate_object then null; end $$;
