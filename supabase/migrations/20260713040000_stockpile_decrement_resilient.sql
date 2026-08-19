-- Fix: stockpile is not decremented when a stockpile was created via the UI.
--
-- The Add-Stockpile form could only resolve a buyer_company_id when the mine had
-- a "connected buyer" in the dropdown. That list was empty in practice (a
-- client-side case bug filtered org_type 'buyer' against 'Buyer'), so supervisors
-- fell back to free text and the stockpile was saved with buyer_company_id = NULL.
-- record_truck_load's FIFO decrement only matched buyer_company_id, so those
-- stockpiles were never decremented even though the button says "deduct from
-- stockpile".
--
-- This recreates record_truck_load so the decrement also matches a NULL-buyer
-- stockpile by its human-typed buyer_label (case-insensitive) against the buyer
-- company's name, and heals the row's buyer_company_id when matched so future
-- loads use the fast id match. The companion client fix makes the connected-buyer
-- dropdown populate whenever a transaction/route exists (lib/features/portal/
-- services/logistics_service.dart -> listPartnerCompanies, case-insensitive).
--
-- Body is otherwise identical to 20260712290000/audit rounds.

CREATE OR REPLACE FUNCTION public.record_truck_load(p_trip_id uuid, p_net_tons numeric, p_truck_reg text DEFAULT NULL::text, p_seals jsonb DEFAULT '[]'::jsonb, p_waybill jsonb DEFAULT '{}'::jsonb)
 RETURNS trips
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_trip public.trips; v_txn public.transactions;
  v_seal_required boolean := false; v_seal_count int := 0;
  v_remaining numeric := coalesce(p_net_tons, 0); v_take numeric; v_sp record;
  v_recon_id uuid; v_pool_balance numeric; v_pool_exists boolean := false;
  v_deducted boolean := false; v_actor_name text; v_actor_sig text; v_wb jsonb;
  v_buyer_name text;
begin
  select * into v_trip from public.trips where id = p_trip_id;
  if not found then raise exception 'Trip % not found', p_trip_id; end if;
  select * into v_txn from public.transactions where id = v_trip.transaction_id;
  if not public.is_company_staff(v_txn.supplier_company_id) then
    raise exception 'Only the mine''s staff can record a load';
  end if;
  v_buyer_name := (select company_name from public.companies where id = v_txn.buyer_company_id);
  if v_trip.route_id is not null then
    select coalesce(seal_required, false) into v_seal_required
    from public.routes where id = v_trip.route_id;
  end if;
  v_seal_count := coalesce(jsonb_array_length(p_seals), 0);
  if v_seal_required and v_seal_count = 0 then
    raise exception 'This route requires seals: capture each seal number and photo before saving';
  end if;
  if v_seal_required then
    if exists (select 1 from jsonb_array_elements(p_seals) e
      where coalesce(e->>'number','') = '' or coalesce(e->>'photo_url','') = '') then
      raise exception 'Each seal needs both a number and a photo on a seal-required route';
    end if;
  end if;
  insert into public.seal_records (trip_id, transaction_id, seal_number, photo_url, captured_by)
  select p_trip_id, v_trip.transaction_id, e->>'number', e->>'photo_url', auth.uid()
  from jsonb_array_elements(p_seals) e where coalesce(e->>'number','') <> '';
  v_actor_name := coalesce((select display_name from public.profiles where id = auth.uid()), 'Load Controller');
  v_actor_sig := (select signature_url from public.profiles where id = auth.uid());
  v_wb := coalesce(p_waybill, '{}'::jsonb) || jsonb_build_object(
    'waybill_number', v_txn.reference_number,
    'dispatched_by', v_actor_name,
    'dispatch_signature_path', v_actor_sig);
  update public.trips set status = 'loaded', loaded_at = timezone('utc', now()), net_tons = p_net_tons,
    metadata = coalesce(metadata, '{}'::jsonb) || jsonb_build_object('truck_reg', p_truck_reg, 'waybill', v_wb)
  where id = p_trip_id returning * into v_trip;
  update public.transactions set status = 'in_transit'
  where id = v_trip.transaction_id and status in ('draft','scheduled');
  begin
    perform public.notify_company_role(
      v_txn.supplier_company_id, array['security'], 'Load complete',
      'Truck ' || coalesce(p_truck_reg, v_trip.metadata->>'truck_reg', 'at the weighbridge')
        || ' is loaded (' || coalesce(round(p_net_tons, 2)::text, '?') || ' t) — ready for gate check-out.',
      'truck_loaded', 'mineSupplier', 'normal',
      jsonb_build_object('trip_id', v_trip.id, 'transaction_id', v_trip.transaction_id));
  exception when others then null; end;
  if v_txn.buyer_company_id is not null and v_remaining > 0 then
    for v_sp in select * from public.stockpiles
      where supplier_company_id = v_txn.supplier_company_id and balance_tons > 0
        and (buyer_company_id = v_txn.buyer_company_id
             or (buyer_company_id is null and v_buyer_name is not null
                 and lower(trim(buyer_label)) = lower(trim(v_buyer_name))))
      order by created_at
    loop
      exit when v_remaining <= 0;
      if v_sp.buyer_company_id is null then
        update public.stockpiles set buyer_company_id = v_txn.buyer_company_id where id = v_sp.id;
      end if;
      v_take := least(v_remaining, v_sp.balance_tons);
      update public.stockpiles set balance_tons = balance_tons - v_take where id = v_sp.id;
      insert into public.stockpile_transactions (stockpile_id, type, delta_tons, balance_after, truck_reg, trip_id, created_by)
      values (v_sp.id, 'deduction', -v_take, v_sp.balance_tons - v_take, p_truck_reg, p_trip_id, auth.uid());
      v_remaining := v_remaining - v_take; v_deducted := true;
    end loop;
    if v_deducted then
      begin
        select exists(select 1 from public.stockpiles
                 where supplier_company_id = v_txn.supplier_company_id and buyer_company_id = v_txn.buyer_company_id),
               coalesce((select sum(balance_tons) from public.stockpiles
                 where supplier_company_id = v_txn.supplier_company_id and buyer_company_id = v_txn.buyer_company_id), 0)
          into v_pool_exists, v_pool_balance;
        if v_pool_exists and v_pool_balance <= 0
           and (v_txn.metadata is null or v_txn.metadata->>'stockpile_depleted_at' is null) then
          update public.transactions set metadata = coalesce(metadata, '{}'::jsonb)
              || jsonb_build_object('stockpile_depleted_at', timezone('utc', now())) where id = v_txn.id;
          perform public.notify_company_role(
            v_txn.supplier_company_id, array['supervisorForeman', 'admin', 'management'],
            'Stockpile reached 0 tons',
            'The stockpile for ' || coalesce(v_buyer_name, 'the buyer')
              || ' has been fully loaded out (0 tons remaining). This transaction cycle is complete.',
            'stockpile_depleted', 'mineSupplier', 'high',
            jsonb_build_object('trip_id', v_trip.id, 'transaction_id', v_txn.id), true);
        end if;
      exception when others then null; end;
    end if;
  end if;
  select id into v_recon_id from public.reconciliations
  where supplier_company_id = v_txn.supplier_company_id
    and buyer_company_id is not distinct from v_txn.buyer_company_id
    and transporter_company_id is not distinct from v_txn.transporter_company_id and status = 'draft' limit 1;
  if v_recon_id is null then
    insert into public.reconciliations (buyer_company_id, supplier_company_id, transporter_company_id, status, metadata)
    values (v_txn.buyer_company_id, v_txn.supplier_company_id, v_txn.transporter_company_id,
       'draft', jsonb_build_object('loaded_tons', p_net_tons, 'loads', 1)) returning id into v_recon_id;
  else
    update public.reconciliations set metadata = coalesce(metadata,'{}'::jsonb) || jsonb_build_object(
        'loaded_tons', coalesce((metadata->>'loaded_tons')::numeric,0) + coalesce(p_net_tons,0),
        'loads', coalesce((metadata->>'loads')::int,0) + 1) where id = v_recon_id;
  end if;
  return v_trip;
end;
$function$;
