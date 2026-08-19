-- Support tickets: allow both the submitter and the handler to attach images
-- (and files) to ticket messages. Mirrors the main chat attachment pattern
-- (chat_messages.file_url/file_type/file_name + a public storage bucket).

-- 1) Attachment columns on ticket messages (same shape as chat_messages).
alter table public.support_ticket_messages
  add column if not exists file_url  text,
  add column if not exists file_type text,   -- 'image' | 'file'
  add column if not exists file_name text;

-- 2) Public storage bucket for ticket attachments (parity with chat-attachments).
insert into storage.buckets (id, name, public)
  values ('support-attachments', 'support-attachments', true)
  on conflict (id) do nothing;

-- Uploads: only a user who can see the ticket may write into that ticket's
-- folder ({ticketId}/...). Reuses the existing support_can_see_ticket() gate.
drop policy if exists support_attach_insert on storage.objects;
create policy support_attach_insert on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'support-attachments'
    and coalesce(array_length(storage.foldername(name), 1), 0) >= 1
    and public.support_can_see_ticket(((storage.foldername(name))[1])::uuid)
  );

-- Authenticated reads scoped to ticket viewers (public CDN URL still serves the
-- image directly; this covers any API-level access).
drop policy if exists support_attach_select on storage.objects;
create policy support_attach_select on storage.objects
  for select to authenticated
  using (
    bucket_id = 'support-attachments'
    and coalesce(array_length(storage.foldername(name), 1), 0) >= 1
    and public.support_can_see_ticket(((storage.foldername(name))[1])::uuid)
  );

-- 3) support_add_message gains optional attachment params (single function,
-- defaults keep older 3-arg calls working).
drop function if exists public.support_add_message(uuid, text, text);

create or replace function public.support_add_message(
  p_ticket uuid,
  p_content text,
  p_sender_name text,
  p_file_url text default null,
  p_file_type text default null,
  p_file_name text default null
) returns uuid language plpgsql security definer set search_path = public as $$
declare v_uid uuid := (select auth.uid()); v_id uuid; v_creator uuid;
begin
  if not public.support_can_see_ticket(p_ticket) then raise exception 'no access'; end if;
  insert into public.support_ticket_messages
      (ticket_id, sender_id, sender_name, content, file_url, file_type, file_name)
    values (p_ticket, v_uid, coalesce(p_sender_name, ''), p_content, p_file_url, p_file_type, p_file_name)
    returning id into v_id;
  select created_by into v_creator from public.support_tickets where id = p_ticket;
  if public.chat_is_super_admin(v_uid) and v_creator is not null and v_creator <> v_uid then
    insert into public.support_notifications (ticket_id, user_id, text)
      values (p_ticket, v_creator, coalesce(p_sender_name, 'Support') || ' replied to your ticket.');
  end if;
  return v_id;
end $$;

revoke execute on function public.support_add_message(uuid,text,text,text,text,text) from anon, public;
grant execute on function public.support_add_message(uuid,text,text,text,text,text) to authenticated;

notify pgrst, 'reload schema';
