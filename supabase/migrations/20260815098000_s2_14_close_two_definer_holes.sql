-- S2-14. Two holes found by reading all 181 authenticated-executable SECURITY
-- DEFINER bodies. Both were walked on production before being touched.
--
-- 1. get_chat_conversations(p_user_id) TOOK THE USER ID AS A PARAMETER AND
--    NEVER CHECKED IT AGAINST THE CALLER.
--
--    Walked: roadhaul.driver passed the super global admin's uuid and got back
--    **7 conversation rows, 5 of them carrying last_message_content** — the
--    actual text of the most recent message in each room. Any authenticated
--    user could read any other user's conversation list and message previews,
--    across every tenant, given only a uuid (which profiles hand out freely).
--
--    The parameter is kept because the app passes it (messaging_service.dart:127)
--    and because a super global admin legitimately reads other people's rooms
--    for support. It is now checked rather than trusted.
create or replace function public.get_chat_conversations(p_user_id uuid)
returns table(id uuid, name text, participant_ids uuid[], type text,
              company_a_id uuid, company_b_id uuid, created_by uuid,
              created_at timestamp with time zone, last_message_content text,
              last_message_timestamp timestamp with time zone,
              last_message_sender_id uuid, unread_count integer,
              last_message_read_at timestamp with time zone,
              last_message_delivered_at timestamp with time zone)
language plpgsql
stable security definer
set search_path to 'public'
as $function$
begin
  -- The whole fix. Ask for somebody else's conversations and you get nothing,
  -- unless you are a super global admin.
  if p_user_id is distinct from auth.uid()
     and not public.chat_is_super_admin(auth.uid()) then
    raise exception 'You may only read your own conversations'
      using errcode = 'insufficient_privilege';
  end if;

  return query
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
end;
$function$;

comment on function public.get_chat_conversations(uuid) is
  'A user''s own conversation list. p_user_id MUST equal auth.uid() unless the '
  'caller is a super global admin — before 2026-08-15 it was unchecked, and a '
  'driver could read any user''s rooms and message previews.';

-- 2. notify_company_management(company_id, title, message, type, …) SENT
--    ARBITRARY NOTIFICATIONS TO ANY COMPANY'S MANAGEMENT, FROM ANYONE.
--
--    Walked: a driver at Roadhaul called it against Cyberhouse Mine Supplier
--    and **2 notifications were actually written**, delivered to that company's
--    owner and a manager, with a title and body of the driver's choosing. An
--    in-product spoofing and phishing vector.
--
--    Fixed by REVOKE rather than by adding a predicate, because a predicate
--    would have to be wrong: the function's whole job is cross-company
--    delivery (dispatch notifies the mine, driver assignment notifies the
--    transporter), so "caller must be staff of the target" would break 16
--    legitimate callers. It is an internal helper that was never meant to be
--    an API — the Dart app does not call it anywhere; its only mention in
--    lib/ is a comment.
--
--    The 16 SECURITY DEFINER callers are unaffected: they execute as their
--    owner (postgres), not as `authenticated`, so the grant they rely on is
--    postgres's, not the caller's.
--
--    Revoked from PUBLIC, not merely from anon/authenticated: Postgres grants
--    EXECUTE on functions to PUBLIC by default, and revoking from a named role
--    leaves a privilege held via PUBLIC in place. Learned at 20260815092000,
--    where exactly that mistake made a migration silently do nothing.
revoke execute on function public.notify_company_management(
  uuid, text, text, text, text, uuid, text, jsonb) from public;

-- NOTE: this revoke was still INCOMPLETE — `authenticated` held an explicit
-- grant of its own, independent of PUBLIC, and the spoof still worked after
-- this ran. See 20260815099000, which finishes the job and records the rule.
