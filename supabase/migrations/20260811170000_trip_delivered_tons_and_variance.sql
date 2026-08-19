-- ============================================================================
-- The variance hole: delivered tons, variance, and the 9th trip status
-- (P3-10 … P3-16)
-- ----------------------------------------------------------------------------
-- MineLink's whole reconciliation layer exists to answer one question: did the
-- tonnage that left the mine arrive at the buyer? Until now the platform could
-- not answer it. `trips.net_tons` held the mine's authoritative weighbridge
-- figure; the driver's re-weigh at offload went into `pod_uploads.delivered_tons`
-- and was never brought alongside it. **The variance -- the lost / stolen /
-- swapped-mass signal -- was computed nowhere.**
--
-- Three things land here.
--
-- 1. `trips.delivered_tons` + a STORED GENERATED `trips.variance_tons`
--    (`net_tons - delivered_tons`). Generated, so it cannot drift from its
--    inputs and cannot be written by hand. NULL-safe by construction: if
--    either side is missing the variance is NULL, which reads as "not
--    comparable" and is emphatically not zero. A zero variance is a real
--    finding; a null one is an absent measurement.
--    The mine's `net_tons` is NEVER overwritten -- it stays authoritative for
--    recon and billing (CLAUDE.md §4, two-weight reconciliation).
--
-- 2. **The 9th status.** `record_pod` set `completed` directly, so `offloaded`
--    had never once been written -- the app could only ever produce 8 of the 9
--    canonical `TripStatus` values, and `select count(*) from trips where
--    status='offloaded'` returned 0 across all 41 trips. It is now a real
--    transition: `record_pod` lands the trip on `offloaded`, and a separate
--    `complete_trip()` closes it.
--
--    **No trip is stranded and today's behaviour is unchanged.** `record_pod`
--    calls `complete_trip` itself once the POD is in. The hold is opt-in per
--    route via `routes.variance_tolerance_pct`, which is NULL everywhere
--    today and therefore never holds anything. Set it on a route and a load
--    whose variance exceeds that percentage stops at `offloaded` for a human
--    to review before it closes. The threshold is deliberately NOT invented
--    here -- an operator sets it, or nothing changes.
--
-- 3. **The party check now matches its own error message** (P3-16). It read
--    `is_company_staff(transporter) OR is_company_staff(supplier)` while
--    raising 'Only the transporter/driver may upload proof of delivery'. A
--    check that permits what its message forbids is worse than either
--    behaviour chosen deliberately: it silently licenses the mine to declare
--    what arrived at the buyer, which is precisely the party whose figure the
--    variance exists to check. Verified safe against live data before
--    narrowing: of 35 PODs, 2 were uploaded by transporter staff and 33 carry
--    no uploader at all (seeded). **Not one was uploaded by a supplier.**
--    `pod_uploads_insert` carried the identical defect and is narrowed with it
--    (P3-47) -- fixing the RPC alone would leave the direct table write open.
--
-- Verified live 2026-08-11 in a rolled-back transaction, on a real trip with
-- net_tons = 35:
--   A  mine account calls record_pod            -> refused, 42501
--   B  transporter uploads, no tolerance        -> offloaded then completed,
--                                                  delivered 33.5, variance 1.5
--   C  10% short against a 1% route tolerance   -> HOLDS at offloaded,
--                                                  completed_at null
--   C2 a party calls complete_trip              -> completed
-- Backfill: 35 of 37 completed trips now carry a delivered figure and a
-- variance (2 have no POD at all); every one of the 35 is short-delivered,
-- 7.00 t in aggregate.
-- ============================================================================

-- ---- 1. the columns -------------------------------------------------------

alter table public.trips
  add column if not exists delivered_tons numeric;

comment on column public.trips.delivered_tons is
  'Tonnage re-weighed at the offloading point and captured with the POD. The '
  'DELIVERY figure. Never overwrites net_tons, which is the mine''s '
  'authoritative weighbridge mass for recon and billing -- the two are stored '
  'separately on purpose so the difference between them is visible.';

alter table public.trips
  add column if not exists variance_tons numeric
  generated always as (net_tons - delivered_tons) stored;

comment on column public.trips.variance_tons is
  'net_tons - delivered_tons. POSITIVE = mass that left the mine and did not '
  'arrive: lost, stolen or swapped en route. Generated and stored, so it can '
  'never disagree with its inputs and can never be written by hand. NULL when '
  'either weight is missing -- "not comparable", which is not the same as a '
  'measured zero.';

alter table public.routes
  add column if not exists variance_tolerance_pct numeric;

comment on column public.routes.variance_tolerance_pct is
  'Percentage of the mine net mass a delivery may fall short by before the '
  'trip HOLDS at offloaded instead of closing (see record_pod). NULL -- the '
  'default, and the value on every existing route -- means no hold: the trip '
  'completes as soon as its POD is in, which is the behaviour that predates '
  'this column. Set it per route to make a material shortfall stop for review. '
  'The number is the operator''s call and is deliberately not defaulted.';

-- ---- 2. backfill from the PODs already captured (P3-14) --------------------
-- Latest POD per trip wins; a re-upload is a correction, not a second load.

update public.trips t
set delivered_tons = p.delivered_tons
from (
  select distinct on (trip_id) trip_id, delivered_tons
  from public.pod_uploads
  where delivered_tons is not null
  order by trip_id, uploaded_at desc
) p
where p.trip_id = t.id
  and t.delivered_tons is distinct from p.delivered_tons;

-- ---- 3. complete_trip: the second stage (P3-15) ----------------------------

create or replace function public.complete_trip(p_trip_id uuid)
returns public.trips
language plpgsql
security definer
set search_path = public
as $$
declare
  v_trip public.trips;
  v_txn  public.transactions;
  v_recon_id uuid;
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

  -- The recon accumulator moves here from record_pod so it is credited exactly
  -- once, at close, whether the trip closed immediately or was held for review.
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

  return v_trip;
end;
$$;

comment on function public.complete_trip(uuid) is
  'Closes an offloaded trip: offloaded -> completed, stamps completed_at, '
  'completes the transaction and credits the draft reconciliation with the '
  'delivered tonnage. Called automatically by record_pod unless the route sets '
  'a variance_tolerance_pct the load exceeded, in which case a party calls it '
  'after reviewing the shortfall. Idempotent on an already-completed trip.';

revoke execute on function public.complete_trip(uuid) from public;
grant  execute on function public.complete_trip(uuid) to authenticated;

-- ---- 4. record_pod: offloaded + delivered_tons, then close -----------------

create or replace function public.record_pod(
  p_trip_id uuid,
  p_delivered_tons numeric,
  p_photo_url text default null
)
returns public.trips
language plpgsql
security definer
set search_path = public
as $$
declare
  v_trip public.trips;
  v_txn  public.transactions;
  v_driver_name text;
  v_driver_sig  text;
  v_tolerance   numeric;
  v_hold        boolean := false;
begin
  select * into v_trip from public.trips where id = p_trip_id;
  if not found then
    raise exception 'Trip % not found', p_trip_id using errcode = 'P0002';
  end if;

  select * into v_txn from public.transactions where id = v_trip.transaction_id;

  -- P3-16: this used to permit supplier staff while the message below said it
  -- did not. The mine must not be able to declare what arrived at the buyer --
  -- its own figure is the other half of the comparison.
  if not (
    public.is_company_staff(v_txn.transporter_company_id)
    or public.is_platform_admin()
  ) then
    raise exception 'Only the transporter/driver may upload proof of delivery'
      using errcode = '42501';
  end if;

  insert into public.pod_uploads
    (trip_id, transaction_id, photo_url, delivered_tons, uploaded_by)
  values
    (p_trip_id, v_trip.transaction_id, p_photo_url, p_delivered_tons, auth.uid());

  v_driver_name := coalesce(
    (select display_name from public.profiles where id = auth.uid()), 'Driver');
  v_driver_sig := (select signature_url from public.profiles where id = auth.uid());

  -- The delivery figure lands on the trip beside the mine's net mass; the
  -- generated variance_tons follows from the two.
  update public.trips
     set status = 'offloaded',
         delivered_tons = p_delivered_tons,
         offloaded_at = coalesce(offloaded_at, timezone('utc', now())),
         metadata = coalesce(metadata, '{}'::jsonb) || jsonb_build_object(
           'waybill',
           coalesce(metadata->'waybill', '{}'::jsonb) || jsonb_build_object(
             'received_by', v_driver_name,
             'received_signature_path', v_driver_sig,
             'pod_photo_path', p_photo_url))
   where id = p_trip_id
  returning * into v_trip;

  -- Hold only when the route asked for one AND the shortfall exceeds it.
  -- NULL tolerance (every route today) never holds, so the end-to-end
  -- behaviour is exactly what it was before this migration.
  select r.variance_tolerance_pct into v_tolerance
    from public.routes r where r.id = v_trip.route_id;

  if v_tolerance is not null
     and v_trip.net_tons is not null and v_trip.net_tons > 0
     and v_trip.variance_tons is not null
     and (v_trip.variance_tons / v_trip.net_tons) * 100 > v_tolerance then
    v_hold := true;
  end if;

  if not v_hold then
    v_trip := public.complete_trip(p_trip_id);
  end if;

  return v_trip;
end;
$$;

comment on function public.record_pod(uuid, numeric, text) is
  'Driver uploads proof of delivery: writes the POD row, lands the trip on '
  'OFFLOADED with delivered_tons (never touching the mine''s net_tons), and '
  'then closes it via complete_trip unless the route''s variance_tolerance_pct '
  'was exceeded. Transporter staff and the platform admin only -- the mine is '
  'excluded because its weighbridge figure is the other half of the variance.';

revoke execute on function public.record_pod(uuid, numeric, text) from public;
grant  execute on function public.record_pod(uuid, numeric, text) to authenticated;

-- ---- 5. the same narrowing on the direct table write (P3-47) ---------------

drop policy if exists pod_uploads_insert on public.pod_uploads;
create policy pod_uploads_insert on public.pod_uploads
  for insert to authenticated
  with check (
    exists (
      select 1 from public.transactions t
      where t.id = pod_uploads.transaction_id
        and public.is_company_staff(t.transporter_company_id)
    )
  );
