-- Nobody told the platform admin that a request had arrived.
--
-- WHAT WAS MEASURED, 2026-08-17
-- -----------------------------
-- Signed in as `atlasbuyer.admin` and submitted a real transport request
-- through the form (Iron Hills -> Richards Bay, 90 t). The row landed with
-- `status = 'requested'`. `notifications` gained **zero rows**.
--
-- Every trip in this product begins with a request that this one role has to
-- approve, price and link. It is the narrowest bottleneck in the whole flow,
-- and the only thing that announced work had arrived was a badge on a sidebar
-- item — which requires the admin to already be inside the console looking at
-- it. Nothing reached them anywhere else. A request submitted on a Friday
-- afternoon waits until somebody happens to open the right screen.
--
-- Every other hand-off in the chain already notifies: dispatch tells the mine,
-- the transporter and the buyer; driver assignment tells the driver; check-in
-- tells the weighbridge; check-out tells the buyer; the +30 t alert tells both
-- ends. The first hand-off — the one that starts everything — was silent.
--
-- WHY A TRIGGER AND NOT AN RPC
-- ----------------------------
-- Requests are INSERTed straight from the client under
-- `transportation_requests_insert` RLS; there is no submit RPC to hang this
-- off. A trigger also covers the revision loop for free: a `sent_back` request
-- that the requester edits and resubmits raises the same notice, which is a
-- second silent hand-off nobody would have thought to wire separately.
--
-- Recipients are read from `profiles.platform_role`, so a future admin is
-- covered without touching this function. Both real admins and any test admin
-- get it; there is no company scoping because a platform admin belongs to no
-- company.
--
-- The whole body is wrapped so a notify failure can never refuse a request.
-- Losing the notification is bad; refusing the buyer's order is worse.

create or replace function public.notify_admins_of_request()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_admin record;
  v_kind text;
  v_title text;
  v_body text;
  v_who text;
  v_resubmitted boolean := tg_op = 'UPDATE';
begin
  -- Only the two states that put a request in the admin's court.
  if tg_op = 'UPDATE'
     and not (new.status = 'resubmitted' and old.status is distinct from 'resubmitted') then
    return new;
  end if;
  if tg_op = 'INSERT' and new.status <> 'requested' then
    return new;
  end if;

  begin
    v_kind := case new.request_type
      when 'transportation' then 'transport'
      when 'product'        then 'product'
      when 'buyer'          then 'buyer'
      else coalesce(new.request_type, 'new')
    end;

    v_who := coalesce(
      (select c.company_name from public.companies c
        where c.id = coalesce(new.requesting_company_id,
                              new.buyer_company_id,
                              new.supplier_company_id)),
      'A company');

    v_title := case when v_resubmitted
      then 'Request resubmitted for review'
      else 'New ' || v_kind || ' request to review' end;

    v_body := v_who
      || case when v_resubmitted
              then ' has revised and resubmitted a ' || v_kind || ' request'
              else ' submitted a ' || v_kind || ' request' end
      || case when new.loading_point is not null and new.offloading_point is not null
              then ': ' || new.loading_point || ' -> ' || new.offloading_point
              else '' end
      || case when new.commodity is not null then ' (' || new.commodity || ')' else '' end
      || '. Approve, price it and link the parties to put it on the road.';

    for v_admin in
      select p.id from public.profiles p
       where p.platform_role = 'superGlobalSerialAdminMain'
    loop
      perform public.create_notification_internal(
        v_admin.id, null, null,
        v_title, v_body,
        'request_submitted',
        v_who, new.created_by,
        'admin', null, 'high',
        jsonb_build_object('request_id', new.id,
                           'request_type', new.request_type,
                           'resubmitted', v_resubmitted));
    end loop;
  exception when others then
    raise warning 'notify_admins_of_request failed for request %: %', new.id, sqlerrm;
  end;

  return new;
end;
$$;

comment on function public.notify_admins_of_request() is
  'Tells every platform admin that a request needs review — on submission and '
  'again on resubmission after a send-back. Before 2026-08-17 the only signal '
  'was a sidebar badge inside the console, so the one role that gates every '
  'trip in the product was never told work had arrived.';

drop trigger if exists trg_notify_admins_of_request on public.transportation_requests;
create trigger trg_notify_admins_of_request
  after insert or update of status on public.transportation_requests
  for each row execute function public.notify_admins_of_request();
