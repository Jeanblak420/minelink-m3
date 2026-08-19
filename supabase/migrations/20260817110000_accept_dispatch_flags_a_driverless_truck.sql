-- A truck can be accepted onto a route, arrive, load and leave the mine gate
-- with nobody rostered on it, and nothing said so.
--
-- `accept_request_dispatch` validates four things about each truck — in the
-- caller's fleet, active, not already on a route, not in maintenance — and
-- says nothing about a driver. Measured on live data: of 42 trips with a
-- vehicle, **19 (45.2%) ran on a truck with no `driver_assignments` row**, one
-- of them still in flight at the time of writing.
--
-- What that costs is specific. `record_pod` is restricted to the
-- transporter/driver, and the driver app resolves a driver's trip through
-- `driver_assignments` — so a driverless truck cannot report its position or
-- close its own delivery. The load physically moves and the delivery cannot be
-- confirmed by the person who moved it.
--
-- This does NOT refuse the acceptance, deliberately. The documented order of
-- the flow (CLAUDE.md §4) is: accept the route, allocate trucks, THEN assign
-- drivers — so a truck legitimately has no driver at this instant, and
-- blocking here would contradict the spec and reject a correct action. What
-- was missing is that nothing ever closed the gap afterwards.
--
-- So acceptance now tells the transporter's own admin/management which trucks
-- still need a driver, naming them. It pairs with the "Assign driver" action
-- added to the Trucks On Route screen, which is where the same fact is shown.
--
-- `fleetDriverUnassigned` is already in `notifications_type_check`
-- (20260815109000) — checked before writing this, because a type outside the
-- vocabulary raises 23514 inside a notify block and silently sends nothing,
-- which is the exact failure that migration exists to prevent.
--
-- The notify is wrapped and downgraded to `raise warning`: a warning must
-- never fail an otherwise valid acceptance, but it must not vanish either.

create or replace function public.accept_request_dispatch(
  p_dispatch_id uuid,
  p_vehicle_ids uuid[]
)
returns public.request_dispatches
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_dispatch public.request_dispatches; v_req public.transportation_requests;
  v_vehicle public.fleet_vehicles; v_vid uuid; v_txn_id uuid; v_ref text; v_required int;
  v_driverless text[] := '{}';
begin
  select * into v_dispatch from public.request_dispatches where id = p_dispatch_id;
  if not found then raise exception 'Dispatch % not found', p_dispatch_id; end if;
  if not public.is_company_manager(v_dispatch.transporter_company_id) then
    raise exception 'Only the transporter''s admin/management may accept routes';
  end if;
  if v_dispatch.status <> 'dispatched' then raise exception 'This route is no longer open to accept'; end if;
  if p_vehicle_ids is null or array_length(p_vehicle_ids, 1) is null then
    raise exception 'Tick at least one truck to accept this route';
  end if;
  select * into v_req from public.transportation_requests where id = v_dispatch.request_id;
  if not found then raise exception 'Request for dispatch % not found', p_dispatch_id; end if;
  v_required := nullif(regexp_replace(coalesce(v_req.num_slots, ''), '\D', '', 'g'), '')::int;
  if v_required is not null and v_required > 0 and array_length(p_vehicle_ids, 1) > v_required then
    raise exception 'This route needs at most % truck(s); you selected %', v_required, array_length(p_vehicle_ids, 1);
  end if;
  foreach v_vid in array p_vehicle_ids loop
    select * into v_vehicle from public.fleet_vehicles where id = v_vid;
    if not found or v_vehicle.company_id <> v_dispatch.transporter_company_id then
      raise exception 'Truck % is not in your fleet', v_vid;
    end if;
    -- NEW: a decommissioned truck is not dispatchable.
    if not coalesce(v_vehicle.is_active, true) then
      raise exception 'Truck % is marked inactive and cannot be assigned to a route',
        v_vehicle.vehicle_registration_number;
    end if;
    if exists (select 1 from public.trips t where t.vehicle_id = v_vid
        and t.status not in ('completed', 'cancelled')) then
      raise exception 'Truck % is already on a route and cannot be assigned again',
        v_vehicle.vehicle_registration_number;
    end if;
    if exists (select 1 from public.fleet_maintenance_records m
        where m.vehicle_id = v_vid and m.status = 'open' and m.takes_out_of_service) then
      raise exception 'Truck % is in maintenance and cannot be assigned until it is marked fixed',
        v_vehicle.vehicle_registration_number;
    end if;

    -- Collected, not raised: see the header. The trip is created either way.
    if not exists (
      select 1 from public.driver_assignments da where da.vehicle_id = v_vid
    ) then
      v_driverless := v_driverless || v_vehicle.vehicle_registration_number;
    end if;

    v_ref := 'TRP-' || upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 10));
    insert into public.transactions (reference_number, supplier_company_id, buyer_company_id,
      transporter_company_id, status, quantity, dispatch_id, created_by, metadata)
    values (v_ref, v_req.supplier_company_id, v_req.buyer_company_id, v_dispatch.transporter_company_id,
      'scheduled', 0, p_dispatch_id, auth.uid(),
      jsonb_build_object('request_id', v_req.id, 'dispatch_id', p_dispatch_id, 'commodity', v_req.commodity,
        'loading_point', v_req.loading_point, 'offloading_point', v_req.offloading_point,
        'rate', v_req.rate, 'payment_terms', v_req.payment_terms))
    returning id into v_txn_id;
    insert into public.trips (transaction_id, vehicle_id, status, dispatch_id, route_id, metadata)
    values (v_txn_id, v_vid, 'scheduled', p_dispatch_id, v_dispatch.route_id,
      jsonb_build_object('truck_reg', v_vehicle.vehicle_registration_number));
  end loop;
  update public.request_dispatches set status = 'accepted' where id = p_dispatch_id returning * into v_dispatch;

  if array_length(v_driverless, 1) is not null then
    begin
      perform public.notify_company_role(
        v_dispatch.transporter_company_id, array['admin', 'management'],
        'Assign a driver before these trucks roll',
        array_to_string(v_driverless, ', ')
          || case when array_length(v_driverless, 1) = 1
                  then ' has no driver assigned. It cannot report its position '
                       || 'or upload a proof of delivery until one is.'
                  else ' have no drivers assigned. They cannot report their '
                       || 'position or upload a proof of delivery until they do.'
             end,
        'fleetDriverUnassigned', 'transporter', 'high',
        jsonb_build_object('dispatch_id', p_dispatch_id,
                           'route_id', v_dispatch.route_id,
                           'trucks', to_jsonb(v_driverless),
                           'nav_tab', 'Trucks on route'),
        true);
    exception when others then
      raise warning 'accept_request_dispatch: driverless notify failed for dispatch %: %',
        p_dispatch_id, sqlerrm;
    end;
  end if;

  return v_dispatch;
end;
$function$;

comment on function public.accept_request_dispatch(uuid, uuid[]) is
  'Transporter accepts a dispatched route on the chosen trucks. Does not '
  'require a driver — the documented order is accept, allocate, then assign — '
  'but notifies the transporter''s admin/management, naming any truck that '
  'still has none, because such a truck cannot report position or upload a POD.';
