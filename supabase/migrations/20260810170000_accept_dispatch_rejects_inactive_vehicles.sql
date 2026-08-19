-- accept_request_dispatch already refuses a truck that is not in the caller's
-- fleet, is already on a live trip, or has an open maintenance record that
-- takes it out of service, and it already caps the selection at num_slots.
--
-- The one gap: `fleet_vehicles.is_active` is never checked. The client filters
-- on it (FleetVehicleStatus.available = isActive && !onRoute && !inMaintenance)
-- but the server does not, so a decommissioned truck can still be dispatched
-- by anything that calls the RPC directly. Security lives in the RPC, not in
-- the Dart filter.
--
-- Deliberately NOT enforced here, and why:
--   * Under-allocation (fewer trucks than num_slots) stays legal. Accepting 3
--     of 5 and adding the rest later is a real operating pattern; a hard error
--     would block it. Surface it as a UI confirmation instead.
--   * A truck with no driver assigned stays acceptable. The spec's order is
--     trucks first, then drivers, so requiring a driver here would deadlock
--     the documented flow.
create or replace function public.accept_request_dispatch(p_dispatch_id uuid, p_vehicle_ids uuid[])
 returns request_dispatches
 language plpgsql
 security definer
 set search_path to 'public'
as $function$
declare
  v_dispatch public.request_dispatches; v_req public.transportation_requests;
  v_vehicle public.fleet_vehicles; v_vid uuid; v_txn_id uuid; v_ref text; v_required int;
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
  return v_dispatch;
end;
$function$;
