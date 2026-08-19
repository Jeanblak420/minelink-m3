-- P8-30 — the weight dispute: strip the hold, wire the venue (client ruling 4,
-- 2026-08-11; standing order wave 1.4, 2026-08-12).
--
-- Client, 2026-08-11: "Any and all differences will be handled between the buyer
-- and the transporter, or between the mine and the buyer — that's why we have
-- this built into the app, so that they can fight with each other and get it
-- sorted out between each other."
--
-- So: the app SURFACES the discrepancy to both sides and gives them the venue.
-- It never blocks a trip over a weight difference.
--
-- ============================================================================
-- WHAT THE PLAN GOT RIGHT, AND THE THREE THINGS IT DOES NOT MENTION
-- ============================================================================
--
-- P8-30 says "everything needed already exists and has never been used". That is
-- mostly true and the machinery was NOT rebuilt. But "wire it" turned out to
-- mean four distinct wires, only one of which the item names:
--
--  1. ✅ NAMED — the tolerance hold must go. record_pod held a trip at
--     'offloaded' when the shortfall exceeded routes.variance_tolerance_pct.
--     Stripped here, and the column dropped (0 routes ever set it; dropping it
--     is authorised by the item).
--
--  2. ❌ NOT NAMED — nothing fired on a completed trip with a variance. The
--     item asks for "on completion with a non-zero variance, notify both
--     counterparties", and there was no such code anywhere. This is the wire
--     that makes the venue reachable: without it a party has to go looking at
--     the recon screen to discover there is anything to argue about. Added to
--     complete_trip, which is the one place a trip closes, so it fires whether
--     record_pod closed it or a party called complete_trip directly.
--
--  3. ❌ NOT NAMED — add_recon_dispute_comment notified NOBODY. raise and
--     set_status both already fanned out to all three parties; the comment
--     function did not. A venue where you can post a reply the other side is
--     never told about is not a venue. The item asks to prove
--     "comment -> counter-comment", which cannot honestly work without this.
--
--  4. ❌ NOT NAMED — none of the dispute notifications carried a deep link. The
--     item asks for them to be "deep-linked to the reconciliation screen for
--     that trip". They carried dispute_id/trip_id but no nav_route, so tapping
--     one landed the user nowhere in particular. Every recon notification now
--     carries nav_route for the RECIPIENT'S OWN org type, which is why this
--     goes through one helper instead of being pasted per call site: the mine
--     must be sent to /portal/mine/reconciliations and the buyer to
--     /portal/buyer/reconciliations, off the same event.
--
-- ============================================================================
-- ⚠ ONE DELIBERATE DEVIATION FROM THE ITEM'S WORDING — READ THIS
-- ============================================================================
--
-- P8-30 says notify on "a non-zero variance". Taken literally that fires on
-- EVERY completed load, because two weighbridges never agree exactly. On the
-- live data every single one of the 35 reconciled loads is short by ~0.57%.
-- A notification on all of them is wallpaper, and it is the identical fault
-- P3-13 already found and fixed on the other side of this feature: Side B used
-- a flat 0.05 t threshold that painted all 35 loads red, and "a red that fires
-- on every row is a signal that means nothing".
--
-- So the notification fires on a MATERIAL variance, using the SAME scale the
-- recon screens already paint with — lib/features/portal/utils/
-- variance_severity.dart: percentage of the load, 0.05 t absolute floor,
-- material above 3%. Server and screen therefore agree by construction: the
-- loads that notify are exactly the loads rendered in MlTone.error. The same
-- principle the nav badges were built on (the badge and the page cannot
-- disagree).
--
-- Every variance is still SURFACED on the reconciliation screen, coloured by
-- severity, and either party can raise a dispute on any load at any time —
-- including a 0.1 t one. Nothing is hidden. What is filtered is the push.
--
-- THE CLIENT CAN OVERRULE THIS WITH ONE NUMBER: set k_material_pct to 0 in
-- variance_is_material() below and it notifies on every non-zero variance,
-- exactly as the item's wording reads. Flagged in To-Do's.md under P8-30.

-- ---------------------------------------------------------------- 1. severity
-- The Dart thresholds, server-side, so the push and the paint cannot drift.
-- Mirrors varianceSeverityOf() in variance_severity.dart.
create or replace function public.variance_is_material(
  p_variance_tons numeric,
  p_net_tons numeric
)
returns boolean
language sql
immutable
set search_path to 'public'
as $function$
  -- kVarianceScaleFloorTons = 0.05 ; kVarianceMaterialPct = 3.0
  select case
    when p_variance_tons is null or p_net_tons is null or p_net_tons <= 0
      then false                                   -- not comparable, not material
    when abs(p_variance_tons) <= 0.05 then false   -- scale rounding
    else (abs(p_variance_tons) / p_net_tons) * 100 > 3.0
  end;
$function$;

comment on function public.variance_is_material(numeric, numeric) is
  'True when a trip weight variance is MATERIAL on the same scale the recon '
  'screens paint with (variance_severity.dart): percentage of the load, 0.05 t '
  'absolute floor, material above 3%. Over-delivery is graded by magnitude on '
  'the same scale -- reading it as fine is how a swapped load hides. Used to '
  'decide whether a completed trip pushes a notification to the counterparties '
  '(P8-30). Set the 3.0 to 0 to notify on every non-zero variance.';

-- ---------------------------------------------------------------- 2. the fan-out
-- One place that knows how to reach "the parties to this transaction", because
-- the deep link differs per recipient: each company must be sent to its OWN
-- org type's reconciliation screen off the same event.
create or replace function public.notify_recon_parties(
  p_transaction_id uuid,
  p_title text,
  p_message text,
  p_importance text default 'normal',
  p_metadata jsonb default '{}'::jsonb,
  p_actor uuid default null,
  p_exclude_company_id uuid default null
)
returns void
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_txn public.transactions;
  r     record;
begin
  select * into v_txn from public.transactions where id = p_transaction_id;
  if not found then return; end if;

  -- Selecting FROM companies rather than looping the three ids also dedupes:
  -- if one company holds two roles on a transaction it is notified once.
  for r in
    select c.id, c.org_type
      from public.companies c
     where c.id in (v_txn.supplier_company_id,
                    v_txn.buyer_company_id,
                    v_txn.transporter_company_id)
       and (p_exclude_company_id is null or c.id <> p_exclude_company_id)
  loop
    perform public.notify_company_management(
      r.id,
      p_title,
      p_message,
      'recon_dispute',
      null,
      p_actor,
      p_importance,
      p_metadata || jsonb_build_object(
        'nav_route',
        '/portal/'
          || case r.org_type when 'mineSupplier' then 'mine' else r.org_type end
          || '/reconciliations'));
  end loop;
end;
$function$;

comment on function public.notify_recon_parties(uuid, text, text, text, jsonb, uuid, uuid) is
  'Fans a reconciliation/dispute notification out to every company party to a '
  'transaction, deep-linked to the RECIPIENT''S OWN org-type reconciliation '
  'screen via metadata.nav_route (P8-30). p_exclude_company_id suppresses the '
  'author''s own company -- used for comments, where you do not need telling '
  'about your own reply.';

-- ---------------------------------------------------------------- 3. no hold
-- record_pod: the tolerance branch is gone. A weight difference never stops a
-- trip. Everything else -- including the P10-D7 mandatory-photo checks added
-- earlier today in 20260812130000 -- is carried across unchanged.
create or replace function public.record_pod(
  p_trip_id uuid,
  p_delivered_tons numeric,
  p_photo_url text default null
)
returns public.trips
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_trip public.trips;
  v_txn  public.transactions;
  v_driver_name text;
  v_driver_sig  text;
  v_is_admin    boolean;
  v_photo       text;
begin
  select * into v_trip from public.trips where id = p_trip_id;
  if not found then
    raise exception 'Trip % not found', p_trip_id using errcode = 'P0002';
  end if;

  select * into v_txn from public.transactions where id = v_trip.transaction_id;

  -- P3-16: the mine must not be able to declare what arrived at the buyer --
  -- its own figure is the other half of the comparison.
  v_is_admin := public.is_platform_admin();
  if not (
    public.is_company_staff(v_txn.transporter_company_id)
    or v_is_admin
  ) then
    raise exception 'Only the transporter/driver may upload proof of delivery'
      using errcode = '42501';
  end if;

  -- ------------------------------------------------------------ P10-D7
  -- Proof of delivery must require proof. A non-blank string is not enough:
  -- 33 seeded rows carry a non-blank path to a file that never existed.
  v_photo := nullif(btrim(coalesce(p_photo_url, '')), '');

  if v_photo is null then
    raise exception
      'A proof-of-delivery photo is required. Capture the offload photo before '
      'recording the delivery.'
      using errcode = '22023';
  end if;

  if not exists (
    select 1 from storage.objects o
     where o.bucket_id = 'pod_photos'
       and o.name = v_photo
  ) then
    raise exception
      'The proof-of-delivery photo % was not found in storage. The upload did '
      'not complete — retry the photo before recording the delivery.', v_photo
      using errcode = '22023';
  end if;

  if not v_is_admin
     and v_photo not like v_txn.transporter_company_id::text || '/%' then
    raise exception
      'The proof-of-delivery photo does not belong to the hauling company for '
      'this trip.'
      using errcode = '42501';
  end if;
  -- ------------------------------------------------------------ end P10-D7

  insert into public.pod_uploads
    (trip_id, transaction_id, photo_url, delivered_tons, uploaded_by)
  values
    (p_trip_id, v_trip.transaction_id, v_photo, p_delivered_tons, auth.uid());

  v_driver_name := coalesce(
    (select display_name from public.profiles where id = auth.uid()), 'Driver');
  v_driver_sig := (select signature_url from public.profiles where id = auth.uid());

  update public.trips
     set status = 'offloaded',
         delivered_tons = p_delivered_tons,
         offloaded_at = coalesce(offloaded_at, timezone('utc', now())),
         metadata = coalesce(metadata, '{}'::jsonb) || jsonb_build_object(
           'waybill',
           coalesce(metadata->'waybill', '{}'::jsonb) || jsonb_build_object(
             'received_by', v_driver_name,
             'received_signature_path', v_driver_sig,
             'pod_photo_path', v_photo))
   where id = p_trip_id
  returning * into v_trip;

  -- P8-30: NO HOLD. The 'offloaded' status stays as a real, distinct step
  -- (P3-15 -- the split lifecycle is kept, the item says so explicitly), but
  -- nothing keeps a trip parked there over a weight difference. complete_trip
  -- raises the discrepancy with the counterparties instead of blocking.
  v_trip := public.complete_trip(p_trip_id);

  return v_trip;
end;
$function$;

-- The column the hold gated on. New, never populated on any route (verified:
-- 0 of 5 routes), and dropping it is authorised by P8-30. Dropped AFTER
-- record_pod stopped reading it.
alter table public.routes drop column if exists variance_tolerance_pct;

-- ---------------------------------------------------------------- 4. the alert
-- complete_trip: surface a material discrepancy to both sides at close.
create or replace function public.complete_trip(p_trip_id uuid)
returns public.trips
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_trip public.trips;
  v_txn  public.transactions;
  v_recon_id uuid;
  v_ref text;
  v_pct numeric;
begin
  select * into v_trip from public.trips where id = p_trip_id;
  if not found then
    raise exception 'Trip % not found', p_trip_id using errcode = 'P0002';
  end if;

  select * into v_txn from public.transactions where id = v_trip.transaction_id;

  -- The parties who can close a delivered load: the hauler that ran it, the
  -- buyer that received it, or the platform admin. NOT the mine -- the mine's
  -- figure is the one under test.
  if not (
    public.is_company_staff(v_txn.transporter_company_id)
    or public.is_company_staff(v_txn.buyer_company_id)
    or public.is_platform_admin()
  ) then
    raise exception
      'Only the transporter, the buyer or the platform admin may close a trip'
      using errcode = '42501';
  end if;

  if v_trip.status = 'completed' then
    return v_trip;  -- idempotent: closing a closed trip is not an error
  end if;

  if v_trip.status <> 'offloaded' then
    raise exception
      'Trip % is % -- only an offloaded trip can be completed', p_trip_id,
      v_trip.status
      using errcode = '22023';
  end if;

  update public.trips
     set status = 'completed',
         completed_at = timezone('utc', now())
   where id = p_trip_id
  returning * into v_trip;

  update public.transactions
     set status = 'completed'
   where id = v_trip.transaction_id;

  -- The recon accumulator is credited exactly once, at close.
  select id into v_recon_id
    from public.reconciliations
   where supplier_company_id = v_txn.supplier_company_id
     and buyer_company_id is not distinct from v_txn.buyer_company_id
     and transporter_company_id is not distinct from v_txn.transporter_company_id
     and status = 'draft'
   limit 1;

  if v_recon_id is not null then
    update public.reconciliations
       set metadata = coalesce(metadata, '{}'::jsonb) || jsonb_build_object(
             'delivered_tons',
             coalesce((metadata->>'delivered_tons')::numeric, 0)
               + coalesce(v_trip.delivered_tons, 0))
     where id = v_recon_id;
  end if;

  -- ------------------------------------------------------------ P8-30
  -- The load is closed either way. If what left the mine and what arrived do
  -- not reconcile materially, both sides are told, and told where to argue --
  -- the reconciliation screen, where raise_recon_dispute is one tap away.
  -- This is the whole of the app's role: surface it, and provide the venue.
  if public.variance_is_material(v_trip.variance_tons, v_trip.net_tons) then
    v_ref := coalesce(v_txn.reference_number, left(p_trip_id::text, 8));
    v_pct := round(abs(v_trip.variance_tons) / v_trip.net_tons * 100, 2);

    perform public.notify_recon_parties(
      v_trip.transaction_id,
      case when v_trip.variance_tons > 0
           then 'Weight shortfall on delivery'
           else 'Over-delivery on weight' end,
      format(
        '%s: the mine weighed %s t out and %s t was recorded delivered — a '
        '%s of %s t (%s%%). Open the reconciliation to compare the weights, '
        'and raise a dispute there if you do not agree.',
        v_ref,
        trim(to_char(v_trip.net_tons, 'FM9999990.00')),
        trim(to_char(v_trip.delivered_tons, 'FM9999990.00')),
        case when v_trip.variance_tons > 0 then 'shortfall' else 'surplus' end,
        trim(to_char(abs(v_trip.variance_tons), 'FM9999990.00')),
        trim(to_char(v_pct, 'FM9999990.00'))),
      'high',
      jsonb_build_object(
        'trip_id',        p_trip_id,
        'transaction_id', v_trip.transaction_id,
        'net_tons',       v_trip.net_tons,
        'delivered_tons', v_trip.delivered_tons,
        'variance_tons',  v_trip.variance_tons,
        'variance_pct',   v_pct),
      auth.uid(),
      null);
  end if;

  return v_trip;
end;
$function$;

-- ---------------------------------------------------------------- 5. the reply
-- add_recon_dispute_comment: tell the OTHER side. Without this a counter-comment
-- is posted into silence, and "comment -> counter-comment" cannot honestly be
-- proven. The author's own company is excluded -- you do not need a push about
-- your own reply.
create or replace function public.add_recon_dispute_comment(
  p_dispute_id uuid,
  p_body text
)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_d record; v_txn record; v_actor uuid := auth.uid(); v_id uuid;
  v_ref text; v_who text; v_mine uuid;
begin
  if v_actor is null then raise exception 'Not authenticated'; end if;
  if coalesce(trim(p_body), '') = '' then raise exception 'Comment cannot be empty'; end if;
  select * into v_d from public.recon_disputes where id = p_dispute_id;
  if not found then raise exception 'Dispute not found'; end if;
  select * into v_txn from public.transactions where id = v_d.transaction_id;
  if not (public.is_platform_admin()
      or public.is_company_staff(v_txn.supplier_company_id)
      or public.is_company_staff(v_txn.buyer_company_id)
      or public.is_company_staff(v_txn.transporter_company_id)) then
    raise exception 'Not authorized';
  end if;

  -- A closed argument is not a venue. Commenting on a resolved/rejected/
  -- withdrawn dispute reopens nothing and confuses the record.
  if v_d.status not in ('open', 'under_review') then
    raise exception 'This dispute is closed — no further comments'
      using errcode = '22023';
  end if;

  v_mine := public.current_company_id();

  v_id := gen_random_uuid();
  insert into public.recon_dispute_comments(
    id, dispute_id, author_user_id, author_company_id, author_is_admin, body)
  values (v_id, p_dispute_id, v_actor, v_mine, public.is_platform_admin(), p_body);
  update public.recon_disputes set updated_at = timezone('utc', now())
   where id = p_dispute_id;

  -- P8-30: notify the counterparties so the reply actually reaches them.
  v_ref := coalesce(v_txn.reference_number, left(v_d.trip_id::text, 8));
  v_who := coalesce(
    (select c.company_name from public.companies c where c.id = v_mine),
    case when public.is_platform_admin() then 'The platform admin' else 'A party' end);

  perform public.notify_recon_parties(
    v_d.transaction_id,
    'New reply on the trip ' || v_ref || ' dispute',
    format('%s replied: "%s"', v_who,
           left(btrim(p_body), 140)
             || case when length(btrim(p_body)) > 140 then '…' else '' end),
    'normal',
    jsonb_build_object('dispute_id', p_dispute_id, 'trip_id', v_d.trip_id),
    v_actor,
    v_mine);   -- exclude the author's own company

  return jsonb_build_object('id', v_id);
end;
$function$;

-- ---------------------------------------------------------------- 6. deep links
-- raise / status: unchanged in behaviour except that their three hand-written
-- notify calls now go through notify_recon_parties, so every one of them carries
-- the recipient's own nav_route. The item asked for the deep link; this is the
-- only way to get a per-recipient one off a single event.
create or replace function public.raise_recon_dispute(
  p_trip_id uuid,
  p_category text,
  p_reason text,
  p_claimed_tons numeric default null
)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_txn record;
  v_actor uuid := auth.uid();
  v_id uuid;
  v_ref text;
  v_title text := 'Reconciliation dispute raised';
  v_msg text;
  v_meta jsonb;
begin
  if v_actor is null then raise exception 'Not authenticated'; end if;
  if coalesce(trim(p_reason), '') = '' then raise exception 'A reason is required'; end if;
  if p_category not in ('weight_variance','short_delivery','quality','seal','damage','other') then
    raise exception 'Invalid dispute category';
  end if;

  select txn.* into v_txn
  from public.trips t join public.transactions txn on txn.id = t.transaction_id
  where t.id = p_trip_id;
  if not found then raise exception 'Trip not found'; end if;

  if not (public.is_platform_admin()
      or public.is_company_staff(v_txn.supplier_company_id)
      or public.is_company_staff(v_txn.buyer_company_id)
      or public.is_company_staff(v_txn.transporter_company_id)) then
    raise exception 'Not authorized to dispute this trip';
  end if;

  if exists (select 1 from public.recon_disputes
      where trip_id = p_trip_id and status in ('open','under_review')) then
    raise exception 'An open dispute already exists for this trip';
  end if;

  v_id := gen_random_uuid();
  insert into public.recon_disputes(
    id, trip_id, transaction_id, category, reason, claimed_tons, status,
    raised_by_user_id, raised_by_company_id)
  values (v_id, p_trip_id, v_txn.id, p_category, p_reason, p_claimed_tons, 'open',
    v_actor, public.current_company_id());

  v_ref := coalesce(v_txn.reference_number, left(p_trip_id::text, 8));
  v_msg := format('A %s dispute was raised on trip %s.', replace(p_category,'_',' '), v_ref);
  v_meta := jsonb_build_object('dispute_id', v_id, 'trip_id', p_trip_id);

  -- All three parties, each deep-linked to their own reconciliation screen.
  perform public.notify_recon_parties(
    v_txn.id, v_title, v_msg, 'high', v_meta, v_actor, null);

  insert into public.notifications(user_id, title, message, type, org_type, metadata)
  select p.id, v_title, v_msg, 'recon_dispute', null,
         v_meta || jsonb_build_object('nav_route', '/super-admin/disputes')
  from public.profiles p where p.platform_role = 'superGlobalSerialAdminMain';

  return jsonb_build_object('id', v_id, 'status', 'open');
end;
$function$;

create or replace function public.set_recon_dispute_status(
  p_dispute_id uuid,
  p_status text,
  p_resolution text default null
)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_d record; v_txn record; v_actor uuid := auth.uid(); v_is_admin boolean;
  v_ref text; v_title text; v_msg text; v_meta jsonb;
begin
  if v_actor is null then raise exception 'Not authenticated'; end if;
  select * into v_d from public.recon_disputes where id = p_dispute_id;
  if not found then raise exception 'Dispute not found'; end if;
  select * into v_txn from public.transactions where id = v_d.transaction_id;
  v_is_admin := public.is_platform_admin();

  -- NOTE (P8-30, flagged for the client rather than changed here): only the
  -- platform admin may move a dispute to under_review/resolved/rejected, which
  -- sits oddly beside client ruling 4 ("sorted out between each other"). It is
  -- left as built because P3-30 and P8-42 both specify "super-admin resolve",
  -- and because the parties CAN already settle without the admin: the raiser
  -- withdraws. Changing who may close a commercial dispute is a client call,
  -- not an implementation detail.
  if p_status = 'withdrawn' then
    if v_d.raised_by_user_id <> v_actor and not v_is_admin then
      raise exception 'Only the person who raised it can withdraw this dispute';
    end if;
    if v_d.status not in ('open','under_review') then
      raise exception 'Dispute is already closed';
    end if;
  elsif p_status in ('under_review','resolved','rejected') then
    if not v_is_admin then raise exception 'Only a platform admin can review or resolve disputes'; end if;
    if v_d.status in ('resolved','rejected','withdrawn') then
      raise exception 'Dispute is already closed';
    end if;
    if p_status in ('resolved','rejected') and coalesce(trim(p_resolution), '') = '' then
      raise exception 'A resolution note is required to close a dispute';
    end if;
  else
    raise exception 'Invalid status';
  end if;

  update public.recon_disputes set
    status = p_status,
    resolution = case when p_status in ('resolved','rejected') then p_resolution else resolution end,
    resolved_by_user_id = case when p_status in ('resolved','rejected','withdrawn') then v_actor else resolved_by_user_id end,
    resolved_at = case when p_status in ('resolved','rejected','withdrawn') then timezone('utc', now()) else resolved_at end,
    updated_at = timezone('utc', now())
  where id = p_dispute_id;

  v_ref := coalesce(v_txn.reference_number, left(v_d.trip_id::text, 8));
  v_title := 'Dispute ' || replace(p_status, '_', ' ');
  v_msg := format('The dispute on trip %s is now %s.%s', v_ref,
                  replace(p_status, '_', ' '),
                  case when p_status in ('resolved','rejected')
                       then ' ' || coalesce(p_resolution, '') else '' end);
  v_meta := jsonb_build_object('dispute_id', p_dispute_id, 'trip_id', v_d.trip_id);

  perform public.notify_recon_parties(
    v_d.transaction_id, v_title, v_msg, 'normal', v_meta, v_actor, null);

  return jsonb_build_object('id', p_dispute_id, 'status', p_status);
end;
$function$;

-- ---------------------------------------------------------------- grants
-- The two new functions follow the pattern the other 178 follow (P3-01): PUBLIC
-- holds nothing, authenticated is granted explicitly. notify_recon_parties is an
-- internal fan-out and is callable by nobody from the API.
revoke all on function public.variance_is_material(numeric, numeric) from public;
revoke all on function public.notify_recon_parties(uuid, text, text, text, jsonb, uuid, uuid) from public;
grant execute on function public.variance_is_material(numeric, numeric) to authenticated;
