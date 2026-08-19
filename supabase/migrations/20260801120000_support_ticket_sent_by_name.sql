-- Support tickets: record WHO submitted the ticket so the progress timeline can
-- show "Ticket sent by <name>" (mirroring "Accepted by <name>").
--
-- support_create_ticket previously inserted the 'sent' event with actor_id only
-- (no actor_name) and the first message with an empty sender_name. This resolves
-- the submitter's display name the same way the app's getMyIdentity does
-- (employees -> companies CEO/name -> profiles display_name/email), stamps it on
-- the 'sent' event + first message, and backfills existing tickets.

-- Reusable name resolver (matches lib/.../messaging_service.dart getMyIdentity).
create or replace function public.support_display_name(p_uid uuid)
returns text
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    nullif(trim((select coalesce(first_name,'') || ' ' || coalesce(last_name,'')
                   from public.employees where user_id = p_uid limit 1)), ''),
    nullif(trim((select coalesce(ceo_first_name,'') || ' ' || coalesce(ceo_last_name,'')
                   from public.companies where user_id = p_uid limit 1)), ''),
    nullif(trim((select company_name from public.companies where user_id = p_uid limit 1)), ''),
    nullif(trim((select display_name from public.profiles where id = p_uid)), ''),
    (select email from public.profiles where id = p_uid),
    'User'
  );
$$;

revoke execute on function public.support_display_name(uuid) from anon, public;
grant execute on function public.support_display_name(uuid) to authenticated;

-- Ticket creation now stamps the submitter's name on the first message + 'sent' event.
create or replace function public.support_create_ticket(
  p_subject text, p_category text, p_body text
) returns uuid language plpgsql security definer set search_path = public as $$
declare
  v_id uuid;
  v_company uuid;
  v_uid uuid := (select auth.uid());
  v_name text;
begin
  if v_uid is null then raise exception 'not authenticated'; end if;
  v_company := public.chat_user_company_id(v_uid);
  v_name := public.support_display_name(v_uid);
  insert into public.support_tickets (created_by, company_id, subject, category)
    values (v_uid, v_company, p_subject, p_category)
    returning id into v_id;
  insert into public.support_ticket_messages (ticket_id, sender_id, sender_name, content)
    values (v_id, v_uid, v_name, p_body);
  insert into public.support_ticket_events (ticket_id, type, actor_id, actor_name)
    values (v_id, 'sent', v_uid, v_name);
  return v_id;
end $$;

-- Backfill existing 'sent' events (+ empty first-message sender names).
update public.support_ticket_events e
   set actor_name = public.support_display_name(t.created_by)
  from public.support_tickets t
 where e.ticket_id = t.id
   and e.type = 'sent'
   and (e.actor_name is null or e.actor_name = '');

update public.support_ticket_messages m
   set sender_name = public.support_display_name(t.created_by)
  from public.support_tickets t
 where m.ticket_id = t.id
   and m.sender_id = t.created_by
   and (m.sender_name is null or m.sender_name = '');
