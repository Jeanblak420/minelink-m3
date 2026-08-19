begin;

create or replace function public.has_company_role(
  target_company_id uuid,
  allowed_roles text[]
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select
    public.is_company_owner(target_company_id)
    or exists (
      select 1
      from public.employees e
      where e.company_id = target_company_id
        and e.user_id = auth.uid()
        and e.role = any (allowed_roles)
        and e.status = 'active'
        and e.is_dismissed = false
    );
$$;

create or replace function public.are_chat_participants_allowed(
  target_participant_ids uuid[]
)
returns boolean
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  base_company_id uuid;
  participant_id uuid;
begin
  if auth.uid() is null then
    return false;
  end if;

  base_company_id := public.current_company_id();
  if base_company_id is null then
    return false;
  end if;

  if target_participant_ids is null or array_length(target_participant_ids, 1) is null then
    return false;
  end if;

  if not auth.uid() = any (target_participant_ids) then
    return false;
  end if;

  foreach participant_id in array target_participant_ids
  loop
    if not exists (
      select 1
      from public.companies c
      where c.id = base_company_id
        and c.user_id = participant_id
      union all
      select 1
      from public.employees e
      where e.company_id = base_company_id
        and e.user_id = participant_id
        and e.status = 'active'
        and e.is_dismissed = false
    ) then
      return false;
    end if;
  end loop;

  return true;
end;
$$;

create or replace function public.can_access_chat_room(target_chat_room_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.chat_rooms cr
    where cr.id = target_chat_room_id
      and public.are_chat_participants_allowed(cr.participant_ids)
  );
$$;

create or replace function public.extract_payload_company_id(payload jsonb)
returns uuid
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  raw_company_id text;
begin
  raw_company_id := nullif(trim(coalesce(payload ->> 'company_id', '')), '');

  if raw_company_id is null then
    return null;
  end if;

  begin
    return raw_company_id::uuid;
  exception
    when invalid_text_representation then
      return null;
  end;
end;
$$;

create or replace function public.can_access_broadcast_message(payload jsonb)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.is_company_staff(public.extract_payload_company_id(payload));
$$;

create or replace function public.can_create_broadcast_message(
  payload jsonb,
  created_by uuid
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select
    created_by = auth.uid()
    and public.has_company_role(
      public.extract_payload_company_id(payload),
      array['admin', 'management']
    );
$$;

create or replace function public.list_company_chat_contacts(
  target_company_id uuid
)
returns table (
  id uuid,
  user_id uuid,
  first_name text,
  last_name text,
  whatsapp_number text,
  company_id uuid,
  role text,
  status text,
  created_at timestamptz,
  updated_at timestamptz,
  profile_photo_url text
)
language sql
stable
security definer
set search_path = public
as $$
  select
    e.id,
    e.user_id,
    e.first_name,
    e.last_name,
    e.whatsapp_number,
    e.company_id,
    e.role,
    e.status,
    e.created_at,
    e.updated_at,
    e.profile_photo_url
  from public.employees e
  where e.company_id = target_company_id
    and e.status = 'active'
    and e.is_dismissed = false
    and public.is_company_staff(target_company_id)
  order by e.first_name, e.last_name;
$$;

create or replace function public.sync_chat_room_last_message()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.chat_rooms
  set
    last_message_content = case
      when nullif(trim(coalesce(new.content, '')), '') is not null then new.content
      when nullif(trim(coalesce(new.file_name, '')), '') is not null then 'Sent a file: ' || new.file_name
      else 'New message'
    end,
    last_message_timestamp = new.timestamp,
    last_message_sender_id = new.sender_id
  where id = new.chat_room_id;

  return new;
end;
$$;

drop trigger if exists handle_chat_rooms_last_message on public.chat_messages;

create trigger handle_chat_rooms_last_message
after insert on public.chat_messages
for each row
execute function public.sync_chat_room_last_message();

create or replace function public.mark_chat_messages_read(
  target_chat_room_id uuid,
  target_message_id uuid default null
)
returns bigint
language plpgsql
security definer
set search_path = public
as $$
declare
  updated_count bigint;
begin
  if not public.can_access_chat_room(target_chat_room_id) then
    raise exception 'Not authorized to access this chat room';
  end if;

  update public.chat_messages
  set is_read = true
  where chat_room_id = target_chat_room_id
    and sender_id <> auth.uid()
    and is_read = false
    and (target_message_id is null or id = target_message_id);

  get diagnostics updated_count = row_count;
  return updated_count;
end;
$$;

drop policy if exists chat_rooms_select_members on public.chat_rooms;
drop policy if exists chat_rooms_insert_members on public.chat_rooms;
drop policy if exists chat_rooms_update_members on public.chat_rooms;

create policy chat_rooms_select_members
on public.chat_rooms
for select
to authenticated
using (public.are_chat_participants_allowed(participant_ids));

create policy chat_rooms_insert_members
on public.chat_rooms
for insert
to authenticated
with check (public.are_chat_participants_allowed(participant_ids));

drop policy if exists chat_messages_select_members on public.chat_messages;
drop policy if exists chat_messages_insert_members on public.chat_messages;
drop policy if exists chat_messages_update_members on public.chat_messages;

create policy chat_messages_select_members
on public.chat_messages
for select
to authenticated
using (public.can_access_chat_room(chat_room_id));

create policy chat_messages_insert_members
on public.chat_messages
for insert
to authenticated
with check (
  sender_id = (select auth.uid())
  and public.can_access_chat_room(chat_room_id)
);

drop policy if exists broadcast_messages_select_authenticated on public.broadcast_messages;
drop policy if exists broadcast_messages_insert_authenticated on public.broadcast_messages;
drop policy if exists broadcast_messages_select_company_scope on public.broadcast_messages;
drop policy if exists broadcast_messages_insert_company_scope on public.broadcast_messages;
drop policy if exists broadcast_messages_select_company_staff on public.broadcast_messages;
drop policy if exists broadcast_messages_insert_company_managers on public.broadcast_messages;

create policy broadcast_messages_select_company_staff
on public.broadcast_messages
for select
to authenticated
using (public.can_access_broadcast_message(payload));

create policy broadcast_messages_insert_company_managers
on public.broadcast_messages
for insert
to authenticated
with check (public.can_create_broadcast_message(payload, created_by));

drop policy if exists weighbridge_records_company_staff on public.weighbridge_records;
drop policy if exists weighbridge_records_select_company_staff on public.weighbridge_records;
drop policy if exists weighbridge_records_insert_authorized on public.weighbridge_records;
drop policy if exists weighbridge_records_update_authorized on public.weighbridge_records;
drop policy if exists weighbridge_records_delete_managers on public.weighbridge_records;
drop policy if exists weighbridge_records_insert_allowed_roles on public.weighbridge_records;
drop policy if exists weighbridge_records_update_allowed_roles on public.weighbridge_records;
drop policy if exists weighbridge_records_delete_company_managers on public.weighbridge_records;

create policy weighbridge_records_select_company_staff
on public.weighbridge_records
for select
to authenticated
using (public.is_company_staff(company_id));

create policy weighbridge_records_insert_allowed_roles
on public.weighbridge_records
for insert
to authenticated
with check (public.has_company_role(company_id, array['controllerWB', 'admin', 'management']));

create policy weighbridge_records_update_allowed_roles
on public.weighbridge_records
for update
to authenticated
using (public.has_company_role(company_id, array['controllerWB', 'admin', 'management']))
with check (public.has_company_role(company_id, array['controllerWB', 'admin', 'management']));

create policy weighbridge_records_delete_company_managers
on public.weighbridge_records
for delete
to authenticated
using (public.is_company_manager(company_id));

drop policy if exists security_incidents_company_staff on public.security_incidents;
drop policy if exists security_incidents_select_company_staff on public.security_incidents;
drop policy if exists security_incidents_insert_authorized on public.security_incidents;
drop policy if exists security_incidents_update_authorized on public.security_incidents;
drop policy if exists security_incidents_delete_managers on public.security_incidents;
drop policy if exists security_incidents_insert_allowed_roles on public.security_incidents;
drop policy if exists security_incidents_update_allowed_roles on public.security_incidents;
drop policy if exists security_incidents_delete_company_managers on public.security_incidents;

create policy security_incidents_select_company_staff
on public.security_incidents
for select
to authenticated
using (public.is_company_staff(company_id));

create policy security_incidents_insert_allowed_roles
on public.security_incidents
for insert
to authenticated
with check (public.has_company_role(company_id, array['security', 'admin', 'management']));

create policy security_incidents_update_allowed_roles
on public.security_incidents
for update
to authenticated
using (public.has_company_role(company_id, array['security', 'admin', 'management']))
with check (public.has_company_role(company_id, array['security', 'admin', 'management']));

create policy security_incidents_delete_company_managers
on public.security_incidents
for delete
to authenticated
using (public.is_company_manager(company_id));

drop policy if exists gate_checks_company_staff on public.gate_checks;
drop policy if exists gate_checks_select_company_staff on public.gate_checks;
drop policy if exists gate_checks_insert_authorized on public.gate_checks;
drop policy if exists gate_checks_update_authorized on public.gate_checks;
drop policy if exists gate_checks_delete_managers on public.gate_checks;
drop policy if exists gate_checks_insert_allowed_roles on public.gate_checks;
drop policy if exists gate_checks_update_allowed_roles on public.gate_checks;
drop policy if exists gate_checks_delete_company_managers on public.gate_checks;

create policy gate_checks_select_company_staff
on public.gate_checks
for select
to authenticated
using (public.is_company_staff(company_id));

create policy gate_checks_insert_allowed_roles
on public.gate_checks
for insert
to authenticated
with check (public.has_company_role(company_id, array['security', 'admin', 'management']));

create policy gate_checks_update_allowed_roles
on public.gate_checks
for update
to authenticated
using (public.has_company_role(company_id, array['security', 'admin', 'management']))
with check (public.has_company_role(company_id, array['security', 'admin', 'management']));

create policy gate_checks_delete_company_managers
on public.gate_checks
for delete
to authenticated
using (public.is_company_manager(company_id));

revoke update on public.chat_rooms from authenticated;
revoke update on public.chat_messages from authenticated;

grant execute on function public.list_company_chat_contacts(uuid) to authenticated;
grant execute on function public.mark_chat_messages_read(uuid, uuid) to authenticated;

commit;
