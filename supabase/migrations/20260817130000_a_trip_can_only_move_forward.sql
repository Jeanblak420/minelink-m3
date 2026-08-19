-- `set_trip_status` accepted ANY status, from ANY status, from ANY party.
--
-- WHAT IT ALLOWED, READ OFF THE SHIPPED FUNCTION
-- ----------------------------------------------
-- The whole body was an authorisation check ("are you staff of any of the
-- three companies on this trip?") followed by an unconditional
-- `update public.trips set status = p_status`. So:
--
--   * a trip could go **straight from `scheduled` to `completed`** — no gate,
--     no weighbridge, no seals, no proof of delivery, and `record_pod`'s
--     mandatory-photo rule (P10-D7) simply stepped around;
--   * a trip could go **backwards**, re-opening a delivery that had already
--     been reconciled and invoiced;
--   * a **buyer's** office staff could move a truck through a mine they have
--     never been to. That is the same fault `security_check_out` was narrowed
--     for on 2026-08-17 (`20260817100000`), one layer up: the gate was fixed
--     and the status it guards was left open.
--
-- The client was the only thing holding the line, and not well: the driver's
-- "Arrived at loading" button was enabled while the trip was still
-- `scheduled`, and "Arrived at offloading" wrote `offloaded` — a status that
-- means the load is off the truck — from `loaded`, i.e. before the truck had
-- even been checked out of the mine gate.
--
-- WHAT THIS CHANGES
-- -----------------
-- 1. **Forward only.** A status may not move to a lower step, and a trip that
--    is `completed` or `cancelled` is finished. Repeating the current status
--    stays a no-op so a retry after a dropped response is still safe.
--
--    Deliberately forward-*only* rather than one-step-at-a-time: a truck can
--    legitimately arrive at the gate without its driver ever having tapped
--    "Start route", and mine security marking it `arrived_at_mine` from
--    `scheduled` is a real, correct operation. Refusing that would break the
--    gate to fix a bookkeeping nicety.
--
-- 2. **`offloaded` and `completed` are not this function's to give.** They are
--    written by `record_pod` / `complete_trip`, which is where the delivered
--    tonnage and the POD photo are captured and checked. Letting a bare status
--    write reach them is how a delivery gets closed with no evidence behind it.
--
-- 3. **The buyer is not a party to moving the truck.** Platform admin, the
--    mine's staff (the gate and the weighbridge are theirs) and the
--    transporter's staff (the driver) only.
--
-- 4. A new `mark_trip_arrived_at_offload` gives the driver back the action the
--    misused `offloaded` write was standing in for — "I am at the offload
--    point" — as a timestamp and a notification to the buyer, WITHOUT touching
--    `TripStatus`. The lifecycle keeps the deliberate POD collapse described in
--    CLAUDE.md §4 (POD = offloaded + completed in one step) instead of growing
--    an eleventh status.

-- Step index for a `trips.status` string. Mirrors `TripStatus.step` in
-- lib/features/portal/models/trip_status.dart, legacy aliases included, so the
-- two cannot disagree about what "forward" means. `cancelled` is 99 there and
-- 99 here.
create or replace function public.trip_status_step(p_status text)
returns int
language sql
immutable
set search_path = public
as $$
  select case lower(coalesce(p_status, ''))
    when 'scheduled'           then 0
    when 'draft'               then 0   -- legacy
    when 'en_route_to_load'    then 1
    when 'en_route'            then 1   -- legacy
    when 'inbound'             then 1   -- legacy
    when 'arrived_at_mine'     then 2
    when 'loading'             then 3
    when 'loaded'              then 4
    when 'left_mine'           then 5
    when 'en_route_to_offload' then 6
    when 'offloaded'           then 7
    when 'completed'           then 8
    when 'cancelled'           then 99
    else -1                              -- unknown: never a valid target
  end;
$$;

comment on function public.trip_status_step(text) is
  'Ordered position of a trips.status value. Mirrors TripStatus.step in Dart '
  '(cancelled = 99, legacy aliases folded onto their canonical step). Used by '
  'set_trip_status to refuse a backwards move.';

create or replace function public.set_trip_status(p_trip_id uuid, p_status text)
returns trips
language plpgsql
security definer
set search_path = public
as $$
declare
  v_trip public.trips;
  v_txn public.transactions;
  v_from int;
  v_to int;
begin
  select * into v_trip from public.trips where id = p_trip_id;
  if not found then raise exception 'Trip % not found', p_trip_id; end if;
  select * into v_txn from public.transactions where id = v_trip.transaction_id;

  -- The buyer is not on the haul road. Narrowed 2026-08-17, same reasoning as
  -- security_check_out in 20260817100000.
  if not (
    public.is_platform_admin()
    or public.is_company_staff(v_txn.supplier_company_id)
    or public.is_company_staff(v_txn.transporter_company_id)
  ) then
    raise exception 'Not authorised to update this trip' using errcode = '42501';
  end if;

  v_from := public.trip_status_step(v_trip.status);
  v_to   := public.trip_status_step(p_status);

  if v_to = -1 then
    raise exception 'Unknown trip status "%"', p_status using errcode = '22023';
  end if;

  -- Idempotent no-op: a retry after a dropped response must not be an error.
  if v_to = v_from then
    return v_trip;
  end if;

  if p_status in ('offloaded', 'completed') then
    raise exception
      'A delivery is closed by uploading the proof of delivery, not by '
      'setting its status. Use the POD action so the delivered tonnage and '
      'the offload photo are captured with it.'
      using errcode = '22023';
  end if;

  if v_trip.status in ('completed', 'cancelled') then
    raise exception 'This trip is already % and cannot be changed.',
      v_trip.status using errcode = '22023';
  end if;

  if v_to < v_from and p_status <> 'cancelled' then
    raise exception
      'A trip cannot go back from % to %. If something needs undoing, raise it '
      'with the MineLink admin rather than rewinding a delivered load.',
      v_trip.status, p_status
      using errcode = '22023';
  end if;

  update public.trips set
    status = p_status,
    arrived_at = case when p_status = 'arrived_at_mine' then timezone('utc', now()) else arrived_at end,
    loading_at = case when p_status = 'loading' then timezone('utc', now()) else loading_at end,
    left_at = case when p_status = 'left_mine' then timezone('utc', now()) else left_at end,
    offloaded_at = case when p_status = 'offloaded' then timezone('utc', now()) else offloaded_at end,
    completed_at = case when p_status = 'completed' then timezone('utc', now()) else completed_at end
  where id = p_trip_id
  returning * into v_trip;

  -- Best-effort Load Controller notification on Security check-in.
  if p_status = 'arrived_at_mine' then
    begin
      perform public.notify_company_role(
        v_txn.supplier_company_id,
        array['controllerWB'],
        'Truck checked in',
        'Truck '
          || coalesce(
               (select fv.vehicle_registration_number
                from public.fleet_vehicles fv where fv.id = v_trip.vehicle_id),
               v_trip.metadata->>'truck_reg',
               'without a registered plate')
          || ' has arrived at the gate and is ready for the weighbridge (tare weigh).',
        'truck_checked_in',
        'mineSupplier',
        'high',
        jsonb_build_object('trip_id', v_trip.id, 'transaction_id', v_trip.transaction_id),
        true
      );
    exception when others then
      raise warning 'set_trip_status: check-in notify failed for trip %: %',
        v_trip.id, sqlerrm;
    end;
  end if;

  return v_trip;
end;
$$;

comment on function public.set_trip_status(uuid, text) is
  'Advances a trip along the lifecycle. FORWARD ONLY, never onto offloaded or '
  'completed (those belong to record_pod/complete_trip, which capture the '
  'delivered tonnage and the mandatory POD photo), and never by the buyer. '
  'Repeating the current status is a no-op so a retry is safe. Before '
  '2026-08-17 this accepted any status from any status from any party, which '
  'made scheduled -> completed a single call.';

-- The driver's "I am at the offload point" action.
--
-- Bookkeeping only: it stamps a time and tells the buyer, and NEVER moves
-- TripStatus. The button that used to do this wrote `offloaded`, which says
-- the load is off the truck — reported before the truck had been weighed out
-- of the mine in at least one shipped path.
create or replace function public.mark_trip_arrived_at_offload(p_trip_id uuid)
returns trips
language plpgsql
security definer
set search_path = public
as $$
declare
  v_trip public.trips;
  v_txn  public.transactions;
  v_reg  text;
begin
  select * into v_trip from public.trips where id = p_trip_id;
  if not found then
    raise exception 'Trip % not found', p_trip_id using errcode = 'P0002';
  end if;
  select * into v_txn from public.transactions where id = v_trip.transaction_id;

  if not (
    public.is_platform_admin()
    or public.is_company_staff(v_txn.transporter_company_id)
  ) then
    raise exception 'Only the transporter/driver may report arrival at the '
      'offload point' using errcode = '42501';
  end if;

  if public.trip_status_step(v_trip.status) < public.trip_status_step('loaded') then
    raise exception
      'This truck has not been loaded yet, so it cannot have arrived to '
      'offload.' using errcode = '22023';
  end if;

  -- Idempotent: arriving twice is one arrival.
  if (v_trip.metadata->>'arrived_at_offload_at') is not null then
    return v_trip;
  end if;

  update public.trips
     set metadata = coalesce(metadata, '{}'::jsonb)
       || jsonb_build_object('arrived_at_offload_at',
                             to_char(timezone('utc', now()),
                                     'YYYY-MM-DD"T"HH24:MI:SS"Z"'))
   where id = p_trip_id
  returning * into v_trip;

  v_reg := coalesce(
    (select fv.vehicle_registration_number
       from public.fleet_vehicles fv where fv.id = v_trip.vehicle_id),
    v_trip.metadata->>'truck_reg',
    'A truck');

  begin
    perform public.notify_company_role(
      v_txn.buyer_company_id, array['admin', 'management'],
      'Truck at the offload point',
      v_reg || ' has arrived to offload. The proof of delivery follows once '
            || 'it is unloaded and weighed.',
      'truck_arrived_offload', 'buyer', 'high',
      jsonb_build_object('trip_id', v_trip.id,
                         'transaction_id', v_trip.transaction_id),
      true);
  exception when others then
    raise warning 'mark_trip_arrived_at_offload: buyer notify failed for %: %',
      v_trip.id, sqlerrm;
  end;

  begin
    perform public.notify_company_role(
      v_txn.transporter_company_id, array['admin', 'management'],
      'Truck at the offload point',
      v_reg || ' has arrived at the offload point.',
      'truck_arrived_offload', 'transporter', 'normal',
      jsonb_build_object('trip_id', v_trip.id,
                         'transaction_id', v_trip.transaction_id),
      true);
  exception when others then
    raise warning 'mark_trip_arrived_at_offload: transporter notify failed '
      'for %: %', v_trip.id, sqlerrm;
  end;

  return v_trip;
end;
$$;

comment on function public.mark_trip_arrived_at_offload(uuid) is
  'Driver reports arrival at the offload point: stamps '
  'metadata.arrived_at_offload_at and notifies the buyer. Deliberately does '
  'NOT touch trips.status — the lifecycle keeps its POD collapse (offloaded + '
  'completed together, with evidence) rather than gaining an eleventh status.';

revoke all on function public.mark_trip_arrived_at_offload(uuid) from public;
revoke all on function public.mark_trip_arrived_at_offload(uuid) from anon;
grant execute on function public.mark_trip_arrived_at_offload(uuid) to authenticated;
revoke all on function public.trip_status_step(text) from public;
revoke all on function public.trip_status_step(text) from anon;
grant execute on function public.trip_status_step(text) to authenticated;
