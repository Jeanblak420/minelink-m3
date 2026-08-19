-- Optional demo rows for portal logistics UI. Skips unless supplier, buyer, transporter,
-- and one transporter fleet vehicle exist. Idempotent via haul_routes.metadata seed key.

do $$
declare
  supplier_id uuid;
  buyer_id uuid;
  transporter_id uuid;
  veh_id uuid;
  route_id uuid;
  txn_id uuid;
  seed_key constant text := 'portal_demo_v1';
begin
  if exists (select 1 from public.haul_routes where metadata->>'seed' = seed_key) then
    return;
  end if;

  select id into supplier_id from public.companies where org_type = 'mineSupplier' order by created_at limit 1;
  select id into buyer_id from public.companies where org_type = 'buyer' order by created_at limit 1;
  select id into transporter_id from public.companies where org_type = 'transporter' order by created_at limit 1;
  select id into veh_id
  from public.fleet_vehicles
  where company_id = transporter_id
  order by created_at
  limit 1;

  if supplier_id is null or buyer_id is null or transporter_id is null or veh_id is null then
    raise notice 'portal logistics demo seed skipped: need mineSupplier, buyer, transporter companies and a fleet vehicle';
    return;
  end if;

  insert into public.haul_routes (
    supplier_company_id,
    buyer_company_id,
    origin_label,
    destination_label,
    metadata
  )
  values (
    supplier_id,
    buyer_id,
    'Demo pit',
    'Demo plant',
    jsonb_build_object('seed', seed_key)
  )
  returning id into route_id;

  insert into public.transactions (
    supplier_company_id,
    buyer_company_id,
    transporter_company_id,
    reference_number,
    status,
    quantity,
    metadata
  )
  values (
    supplier_id,
    buyer_id,
    transporter_id,
    'portal-demo-' || substr(replace(gen_random_uuid()::text, '-', ''), 1, 12),
    'in_transit',
    120.5,
    jsonb_build_object('seed', seed_key)
  )
  returning id into txn_id;

  insert into public.trips (transaction_id, vehicle_id, route_id, status, metadata)
  values (txn_id, veh_id, route_id, 'active', '{}'::jsonb);

  insert into public.vehicle_positions (vehicle_id, lat, lng, heading, recorded_at, source)
  values
    (veh_id, -26.2041, 28.0473, 90, timezone('utc', now()), seed_key),
    (veh_id, -26.105, 28.052, 95, timezone('utc', now()) - interval '15 minutes', seed_key);

  insert into public.reconciliations (
    buyer_company_id,
    supplier_company_id,
    transporter_company_id,
    period_start,
    period_end,
    status,
    notes,
    metadata
  )
  values (
    buyer_id,
    supplier_id,
    transporter_id,
    date_trunc('month', timezone('utc', now()))::date,
    (date_trunc('month', timezone('utc', now())) + interval '1 month - 1 day')::date,
    'draft',
    'Demo reconciliation row',
    jsonb_build_object('seed', seed_key)
  );
end $$;
