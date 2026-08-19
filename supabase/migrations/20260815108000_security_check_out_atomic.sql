-- S6-9 / S6-24 — security check-out was two sequential RPCs, and the gap
-- between them strands a truck that has physically left.
--
-- `security_checkin_screen._markGone` did:
--
--     await lifecycle.setTripStatus(tripId, TripStatus.leftMine);        // :117
--     await lifecycle.setTripStatus(tripId, TripStatus.enRouteToOffload); // :119
--
-- Two round trips, no transaction around them. The first stamps `left_at` and
-- moves the trip to `left_mine`; the second moves it on to
-- `en_route_to_offload`. If the second call fails — and this is a security
-- guard at a mine gate, on the connectivity `friendly_error.dart` already
-- calls out as "by far the most common real cause on a haul road" — the trip
-- stops at `left_mine`.
--
-- That state is worse than not having checked out at all. The truck is gone
-- from the gate, so nobody at the mine is looking at it; and it never entered
-- `en_route_to_offload`, so nobody at the offload point is expecting it. The
-- guard has no way to tell, because from their side the button worked: the
-- first call succeeded and the screen refreshed.
--
-- One RPC, one transaction. Either the truck is checked out or it is not.
--
-- Status guard: check-out only means something from `loaded`. Anything earlier
-- is a truck that has not been weighed out, and refusing is better than
-- recording a departure that did not happen. `left_mine` and
-- `en_route_to_offload` are accepted as idempotent so a retry after a dropped
-- response is not an error — which is exactly the situation this exists for.

create or replace function public.security_check_out(p_trip_id uuid)
returns public.trips
language plpgsql
security definer
set search_path to 'public'
as $function$
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

  -- Same authorisation surface as set_trip_status: any party to the trip.
  -- Deliberately not narrowed to the mine's security role here, because the
  -- platform admin and the mine's management legitimately correct a missed
  -- check-out, and narrowing it would be a behaviour change this migration is
  -- not making.
  if not (
    public.is_platform_admin()
    or public.is_company_staff(v_txn.supplier_company_id)
    or public.is_company_staff(v_txn.buyer_company_id)
    or public.is_company_staff(v_txn.transporter_company_id)
  ) then
    raise exception 'Not authorised to check this truck out'
      using errcode = '42501';
  end if;

  if v_trip.status = 'en_route_to_offload' then
    -- Already through. A retry after a dropped response is not an error.
    return v_trip;
  end if;

  if v_trip.status not in ('loaded', 'left_mine') then
    raise exception
      'This truck cannot be checked out from %. It has to be loaded and '
      'weighed out first.', v_trip.status
      using errcode = '22023';
  end if;

  update public.trips
     set status  = 'en_route_to_offload',
         -- Stamped here because `set_trip_status` only sets it on the
         -- `left_mine` write, and that write no longer happens separately.
         left_at = coalesce(left_at, timezone('utc', now()))
   where id = p_trip_id
  returning * into v_trip;

  v_reg := coalesce(
    (select fv.vehicle_registration_number
       from public.fleet_vehicles fv where fv.id = v_trip.vehicle_id),
    v_trip.metadata->>'truck_reg',
    'A truck');

  -- Best-effort, and never allowed to fail the check-out: the buyer and the
  -- transporter are the two parties who need to know a load is on its way.
  --
  -- `raise warning`, NOT `then null`. The first version of this block swallowed
  -- silently and passed nine arguments' worth of intent to an eight-argument
  -- call -- `notify_company_role` ends in `p_include_owner boolean` -- so the
  -- call never resolved and NOTHING was ever sent. It looked fine: the
  -- check-out succeeded, no error surfaced anywhere. It was caught by counting
  -- `truck_left_mine` rows before and after and getting 0 -> 0.
  --
  -- A fire-and-forget write that fails silently is this project's
  -- characteristic defect (analysis_options.yaml records the same lesson about
  -- unawaited futures). The notification still must not fail a check-out, so
  -- it is still caught -- but it says so in the server log instead of
  -- vanishing.
  begin
    perform public.notify_company_role(
      v_txn.buyer_company_id, array['admin', 'management'],
      'Load on the way',
      v_reg || ' has left the mine and is en route to offload.',
      'truck_left_mine', 'buyer', 'normal',
      jsonb_build_object('trip_id', v_trip.id,
                         'transaction_id', v_trip.transaction_id),
      true);
  exception when others then
    raise warning 'security_check_out: buyer notify failed for trip %: %',
      v_trip.id, sqlerrm;
  end;

  begin
    perform public.notify_company_role(
      v_txn.transporter_company_id, array['admin', 'management'],
      'Truck departed the mine',
      v_reg || ' has been checked out and is en route to offload.',
      'truck_left_mine', 'transporter', 'normal',
      jsonb_build_object('trip_id', v_trip.id,
                         'transaction_id', v_trip.transaction_id),
      true);
  exception when others then
    raise warning 'security_check_out: transporter notify failed for trip %: %',
      v_trip.id, sqlerrm;
  end;

  return v_trip;
end;
$function$;

comment on function public.security_check_out(uuid) is
  'S6-9/S6-24: atomic mine-gate check-out. Replaces two sequential '
  'set_trip_status calls (left_mine then en_route_to_offload) whose gap left a '
  'departed truck stranded at left_mine when the second call failed — nobody '
  'at the mine watching it, nobody at the offload expecting it.';

grant execute on function public.security_check_out(uuid) to authenticated;
