-- Phase 3 — Transporter marketplace + accept→trips (§5.2/5.3).
-- Additive only: lets a transporter SEE requests dispatched to it, links trips
-- and transactions back to their originating dispatch, and turns an accepted
-- dispatch into real transactions + trips that drive the lifecycle cascades.

------------------------------------------------------------------------------
-- 1. Transporter visibility of requests dispatched to them.
--    Additive permissive SELECT policy (OR'd with the existing buyer/admin one).
------------------------------------------------------------------------------
do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'transportation_requests'
      and policyname = 'transportation_requests_select_dispatched'
  ) then
    create policy transportation_requests_select_dispatched
      on public.transportation_requests
      for select to authenticated
      using (
        exists (
          select 1 from public.request_dispatches d
          where d.request_id = transportation_requests.id
            and public.is_company_staff(d.transporter_company_id)
        )
      );
  end if;
end $$;

------------------------------------------------------------------------------
-- 2. Link trips + transactions back to the originating dispatch (per-route
--    metrics for the transporter route detail, §5.2).
------------------------------------------------------------------------------
alter table public.trips
  add column if not exists dispatch_id uuid references public.request_dispatches (id) on delete set null;
create index if not exists trips_dispatch_idx on public.trips (dispatch_id);

alter table public.transactions
  add column if not exists dispatch_id uuid references public.request_dispatches (id) on delete set null;
create index if not exists transactions_dispatch_idx on public.transactions (dispatch_id);

------------------------------------------------------------------------------
-- 3. Accept a dispatched request: create a transaction + trip per ticked truck.
--    SECURITY DEFINER so the transporter's own inserts are authorised here
--    (it does its own manager check on the transporter company).
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
      v_ref, null, v_req.buyer_company_id, v_dispatch.transporter_company_id,
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

-- Decline a dispatched route (transporter admin/management).
create or replace function public.decline_request_dispatch(p_dispatch_id uuid)
returns public.request_dispatches
language plpgsql security definer set search_path = public as $$
declare v_dispatch public.request_dispatches;
begin
  select * into v_dispatch from public.request_dispatches where id = p_dispatch_id;
  if not found then raise exception 'Dispatch % not found', p_dispatch_id; end if;
  if not public.is_company_manager(v_dispatch.transporter_company_id) then
    raise exception 'Only the transporter''s admin/management may decline routes';
  end if;
  update public.request_dispatches set status = 'declined'
  where id = p_dispatch_id and status = 'dispatched'
  returning * into v_dispatch;
  if not found then raise exception 'This route is no longer open'; end if;
  return v_dispatch;
end;
$$;

grant execute on function public.accept_request_dispatch(uuid, uuid[]) to authenticated;
grant execute on function public.decline_request_dispatch(uuid) to authenticated;
