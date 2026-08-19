-- Phase 3/4 — Representative selects the supplying mine at dispatch (§8.4).
-- The buyer types a desired mine free-text; the MineLink representative picks
-- the registered mineSupplier company when dispatching. That supplier then
-- flows onto the trips created on transporter accept, so the mine's Security /
-- Load Controller screens can work the real trips. Additive only.

------------------------------------------------------------------------------
-- 1. Supplier (mine) chosen by the representative for a request.
------------------------------------------------------------------------------
alter table public.transportation_requests
  add column if not exists supplier_company_id uuid
    references public.companies (id) on delete set null;
create index if not exists transportation_requests_supplier_idx
  on public.transportation_requests (supplier_company_id);

------------------------------------------------------------------------------
-- 2. Representative sets/updates the supplier for a request (before dispatch).
------------------------------------------------------------------------------
create or replace function public.set_request_supplier(
  p_id uuid,
  p_supplier_company_id uuid
)
returns public.transportation_requests
language plpgsql security definer set search_path = public as $$
declare v_row public.transportation_requests;
begin
  if not public.is_platform_admin() then
    raise exception 'Only the MineLink representative may set the supplier';
  end if;
  update public.transportation_requests
    set supplier_company_id = p_supplier_company_id
  where id = p_id
  returning * into v_row;
  if not found then raise exception 'Request % not found', p_id; end if;
  return v_row;
end;
$$;
grant execute on function public.set_request_supplier(uuid, uuid) to authenticated;

------------------------------------------------------------------------------
-- 3. accept_request_dispatch now stamps the chosen supplier onto each
--    transaction so the mine becomes a party (RLS) and can load the truck.
--    Same signature as before — additive replace.
------------------------------------------------------------------------------
create or replace function public.accept_request_dispatch(
  p_dispatch_id uuid,
  p_vehicle_ids uuid[]
)
returns public.request_dispatches
language plpgsql security definer set search_path = public as $$
declare
  v_dispatch public.request_dispatches;
  v_req public.transportation_requests;
  v_vehicle public.fleet_vehicles;
  v_vid uuid;
  v_txn_id uuid;
  v_ref text;
begin
  select * into v_dispatch from public.request_dispatches where id = p_dispatch_id;
  if not found then raise exception 'Dispatch % not found', p_dispatch_id; end if;

  if not public.is_company_manager(v_dispatch.transporter_company_id) then
    raise exception 'Only the transporter''s admin/management may accept routes';
  end if;
  if v_dispatch.status <> 'dispatched' then
    raise exception 'This route is no longer open to accept';
  end if;
  if p_vehicle_ids is null or array_length(p_vehicle_ids, 1) is null then
    raise exception 'Tick at least one truck to accept this route';
  end if;

  select * into v_req from public.transportation_requests where id = v_dispatch.request_id;
  if not found then raise exception 'Request for dispatch % not found', p_dispatch_id; end if;

  foreach v_vid in array p_vehicle_ids loop
    select * into v_vehicle from public.fleet_vehicles where id = v_vid;
    if not found or v_vehicle.company_id <> v_dispatch.transporter_company_id then
      raise exception 'Truck % is not in your fleet', v_vid;
    end if;

    v_ref := 'TRP-' || upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 10));
    insert into public.transactions (
      reference_number, supplier_company_id, buyer_company_id, transporter_company_id,
      status, quantity, dispatch_id, created_by, metadata
    ) values (
      v_ref, v_req.supplier_company_id, v_req.buyer_company_id, v_dispatch.transporter_company_id,
      'scheduled', 0, p_dispatch_id, auth.uid(),
      jsonb_build_object(
        'request_id', v_req.id,
        'dispatch_id', p_dispatch_id,
        'commodity', v_req.commodity,
        'loading_point', v_req.loading_point,
        'offloading_point', v_req.offloading_point,
        'rate', v_req.rate,
        'payment_terms', v_req.payment_terms
      )
    ) returning id into v_txn_id;

    insert into public.trips (transaction_id, vehicle_id, status, dispatch_id, metadata)
    values (
      v_txn_id, v_vid, 'scheduled', p_dispatch_id,
      jsonb_build_object('truck_reg', v_vehicle.vehicle_registration_number)
    );
  end loop;

  update public.request_dispatches set status = 'accepted'
  where id = p_dispatch_id
  returning * into v_dispatch;
  return v_dispatch;
end;
$$;
grant execute on function public.accept_request_dispatch(uuid, uuid[]) to authenticated;
