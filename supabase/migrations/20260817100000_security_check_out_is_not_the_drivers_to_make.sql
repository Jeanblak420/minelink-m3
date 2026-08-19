-- A driver could check their own truck out of the mine gate.
--
-- `security_check_out` authorised "any party to the trip":
--
--     public.is_platform_admin()
--     or public.is_company_staff(v_txn.supplier_company_id)
--     or public.is_company_staff(v_txn.buyer_company_id)
--     or public.is_company_staff(v_txn.transporter_company_id)
--
-- `is_company_staff` is any active employee of that company in ANY role, so
-- that included the DRIVER of the truck being released, and it included the
-- BUYER, who is not at the mine at all. Proven by impersonating real accounts
-- against a completed trip, where the lifecycle branch cannot write, so the
-- error code isolates the authorisation decision (42501 = refused at the gate,
-- 22023 = passed the gate and stopped only by trip status):
--
--     mine security / controllerWB      22023   passed
--     transporter admin                 22023   passed
--     transporter DRIVER                22023   passed   <-- the control
--     buyer admin / management          22023   passed   <-- not even present
--
-- A gate check-out is a control ON the driver: it is the mine confirming what
-- left its premises, sealed and weighed. Letting the driver record their own
-- departure removes the separation the step exists to create, and letting the
-- buyer do it lets a party who was never on site assert that a truck left.
--
-- The previous comment said the width was deliberate, "because the platform
-- admin and the mine's management legitimately correct a missed check-out".
-- That reason is kept in full — both still can. It just never required the
-- driver or the buyer.
--
-- Narrowed to:
--   * the platform admin                          (corrections, unchanged)
--   * ANY staff of the mine                       (security, controller,
--                                                  supervisor, management —
--                                                  the people at the gate)
--   * the transporter's admin/management ONLY     (`is_company_manager` =
--                                                  owner or admin/management,
--                                                  and an active company), so
--                                                  a transporter can still fix
--                                                  a missed check-out on their
--                                                  own truck
--
-- Removed: the buyer entirely, and every non-management transporter role —
-- which is the driver.
--
-- No UI path is affected: `security_check_out` has exactly one caller,
-- `security_checkin_screen.dart`, which is the mine's own Security gate screen.

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

  -- The gate is a physical control AT THE MINE, and it is a control ON the
  -- driver — so the driver is not one of the parties who may perform it, and
  -- neither is the buyer, who is not on site.
  if not (
    public.is_platform_admin()
    or public.is_company_staff(v_txn.supplier_company_id)
    or public.is_company_manager(v_txn.transporter_company_id)
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
  'Mine gate check-out. Authorised for the platform admin, any staff of the '
  'supplying mine, and the transporter''s admin/management only — never the '
  'driver of the truck being released (the control exists to separate those '
  'two), and never the buyer, who is not on site.';
