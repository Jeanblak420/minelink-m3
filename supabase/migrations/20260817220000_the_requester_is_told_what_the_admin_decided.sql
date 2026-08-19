-- Nobody told the requester what the platform admin decided.
--
-- Session 2 fixed the outbound half of this hand-off: a submitted request now
-- notifies every platform admin (20260817150000). The return leg was still
-- silent. Measured 2026-08-17: the admin returned a buyer's product request for
-- revision, with a note, and `notifications` gained **zero** rows. Same for
-- approve and decline. The requester learned about it only by opening the
-- Requests screen and noticing a card had moved into "Requests sent back for
-- revision" -- which means, in practice, when they next happened to look.
--
-- A revision loop where one side is told and the other is not is not a loop.
--
-- The note the admin wrote is carried in the message, because it is the entire
-- reason the request came back, and `metadata.request_id` deep-links the card.

create or replace function public.notify_requester_of_review()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_kind text;
  v_title text;
  v_body text;
  v_note text;
  v_meta jsonb;
begin
  -- Only the three decisions, and only on the transition INTO them, so an
  -- unrelated update to an already-sent-back request does not re-notify.
  if new.status not in ('sent_back', 'approved', 'declined') then
    return new;
  end if;
  if old.status is not distinct from new.status then
    return new;
  end if;

  begin
    v_kind := case new.request_type
      when 'transportation' then 'transport'
      when 'product'        then 'product'
      when 'buyer'          then 'buyer'
      else coalesce(new.request_type, 'new')
    end;
    v_note := nullif(btrim(coalesce(new.admin_notes, '')), '');
    v_meta := jsonb_build_object('request_id', new.id,
                                 'request_type', new.request_type,
                                 'status', new.status);

    if new.status = 'sent_back' then
      v_title := 'Your ' || v_kind || ' request needs changes';
      v_body  := 'MineLink sent your ' || v_kind || ' request back for revision.'
        || case when v_note is null then ''
                else ' What needs to change: "' || v_note || '"' end
        || ' Open it, update the details and resubmit.';
      -- The type is a LITERAL in every branch on purpose. Passed as a variable
      -- it is invisible to tool/notification_vocabulary_check.py, which reads
      -- the call sites textually -- and a type the checker cannot see is
      -- exactly how order_assigned and stockpile_ready sat dead for a month.
      perform public.notify_company_role(
        new.requesting_company_id, array['admin', 'management'],
        v_title, v_body, 'request_sent_back', null, 'high', v_meta, true);

    elsif new.status = 'approved' then
      v_title := 'Your ' || v_kind || ' request was approved';
      v_body  := 'MineLink approved your ' || v_kind || ' request'
        || case when new.commodity is not null
                then ' (' || new.commodity || ')' else '' end
        || '. The parties are being linked — you will be told again once it is '
        || 'dispatched to a transporter.';
      perform public.notify_company_role(
        new.requesting_company_id, array['admin', 'management'],
        v_title, v_body, 'request_approved', null, 'high', v_meta, true);

    else
      v_title := 'Your ' || v_kind || ' request was declined';
      v_body  := 'MineLink declined your ' || v_kind || ' request'
        || case when v_note is null then '.'
                else ': "' || v_note || '"' end;
      perform public.notify_company_role(
        new.requesting_company_id, array['admin', 'management'],
        v_title, v_body, 'requestDeclined', null, 'high', v_meta, true);
    end if;

  exception when others then
    -- A notification must never roll back the admin's decision, but it must
    -- also not vanish without trace the way this whole path used to.
    raise warning 'notify_requester_of_review failed for request %: %', new.id, sqlerrm;
  end;

  return new;
end;
$function$;

comment on function public.notify_requester_of_review() is
  'Tells the requesting company when the platform admin sends a request back, '
  'approves it, or declines it. Added 2026-08-17: the return leg of the '
  'sent_back <-> resubmitted loop produced no notification at all.';

drop trigger if exists trg_notify_requester_of_review on public.transportation_requests;
create trigger trg_notify_requester_of_review
after update of status on public.transportation_requests
for each row execute function public.notify_requester_of_review();

revoke all on function public.notify_requester_of_review() from public, anon, authenticated;
