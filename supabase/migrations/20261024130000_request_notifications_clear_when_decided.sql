-- A request's notifications clear themselves once they stop being true.
--
-- Found on the admin phone audit, 2026-10-24: Jean's only unread notification
-- was "New buyer request to review" from 18 Sep, for a request that had been
-- approved and linked weeks before. It kept the "1" on the bell and the menu
-- icon on every screen, and nothing would ever have cleared it but a tap.
--
--   * An admin's "to review" notification (request_submitted, created by
--     notify_admins_of_request) is read once the request is decided: approved,
--     sent back, declined or linked. A resubmission makes a fresh one.
--   * The requester's "was approved" notice (request_approved) is read once
--     the request is linked: linking sends its own dispatch notices.
--
-- Marked read, never deleted: nothing on this platform is deleted.
begin;

create or replace function public.clear_decided_request_notifications()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $function$
begin
  if old.status is not distinct from new.status then
    return new;
  end if;

  begin
    if old.status in ('requested', 'resubmitted')
       and new.status not in ('requested', 'resubmitted') then
      update public.notifications
         set is_read = true
       where type = 'request_submitted'
         and not is_read
         and metadata ->> 'request_id' = new.id::text;
    end if;

    if new.status = 'linked' then
      update public.notifications
         set is_read = true
       where type = 'request_approved'
         and not is_read
         and metadata ->> 'request_id' = new.id::text;
    end if;
  exception when others then
    -- Housekeeping must never block a decision on the request itself.
    raise warning 'clear_decided_request_notifications failed for request %: %',
      new.id, sqlerrm;
  end;

  return new;
end;
$function$;

revoke all on function public.clear_decided_request_notifications() from public, anon, authenticated;

drop trigger if exists trg_clear_decided_request_notifications on public.transportation_requests;
create trigger trg_clear_decided_request_notifications
  after update of status on public.transportation_requests
  for each row execute function public.clear_decided_request_notifications();

-- The ones already stale.
update public.notifications n
   set is_read = true
  from public.transportation_requests r
 where not n.is_read
   and n.metadata ->> 'request_id' = r.id::text
   and (   (n.type = 'request_submitted' and r.status not in ('requested', 'resubmitted'))
        or (n.type = 'request_approved'  and r.status = 'linked'));

commit;
