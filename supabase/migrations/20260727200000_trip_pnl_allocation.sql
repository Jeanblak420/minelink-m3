-- Per-trip profit & loss with cost allocation (2026-07-27). Applied live to
-- yftazblpmicqtamyiwyb.
--
-- Resolves the "untagged fuel only rolls up at vehicle level" gap: every cost
-- now lands on a trip's net. direct_cost = fuel/operating costs tagged to that
-- trip; allocated_cost = the vehicle's UNTAGGED pool (untagged fuel + operating
-- costs + all maintenance) shared across that vehicle's revenue trips by
-- tonnage (equal split when tonnage is absent). Invariant: the sum of trip
-- total_cost for a vehicle equals that vehicle's total cost, so per-trip nets
-- reconcile to the per-vehicle net. Manager/admin only.

CREATE OR REPLACE FUNCTION public.list_transporter_trip_pnl(p_company_id uuid)
 RETURNS TABLE(
   trip_id uuid, reference text, truck_reg text, vehicle_id uuid, route_id uuid,
   commodity text, customer_name text, source_name text,
   net_tons numeric, rate_per_ton numeric, currency text, revenue numeric,
   direct_cost numeric, allocated_cost numeric, total_cost numeric, net numeric,
   status text, updated_at timestamptz)
 LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public'
AS $fn$
  WITH tr AS (
    SELECT t.id AS trip_id, t.vehicle_id, t.route_id, t.transaction_id, t.net_tons,
      t.status, t.updated_at, t.metadata AS tmeta,
      txn.reference_number, txn.buyer_company_id, txn.supplier_company_id,
      txn.metadata AS txnmeta,
      mlx.transporter_price_per_ton AS rate, coalesce(mlx.currency, 'ZAR') AS currency
    FROM public.trips t
    JOIN public.transactions txn ON txn.id = t.transaction_id
    LEFT JOIN LATERAL (SELECT ml.transporter_price_per_ton, ml.currency
      FROM public.margin_ledger ml WHERE ml.route_id = t.route_id
      ORDER BY ml.created_at DESC LIMIT 1) mlx ON true
    WHERE txn.transporter_company_id = p_company_id AND t.net_tons IS NOT NULL
  ),
  direct AS (
    SELECT trip_id, sum(c) AS c FROM (
      SELECT trip_id, cost_zar AS c FROM public.fuel_entries
        WHERE company_id = p_company_id AND trip_id IS NOT NULL
      UNION ALL
      SELECT trip_id, cost_zar FROM public.vehicle_operating_costs
        WHERE company_id = p_company_id AND trip_id IS NOT NULL
    ) z GROUP BY trip_id
  ),
  pool AS (
    SELECT vehicle_id, sum(c) AS c FROM (
      SELECT vehicle_id, cost_zar AS c FROM public.fuel_entries
        WHERE company_id = p_company_id AND trip_id IS NULL
      UNION ALL
      SELECT vehicle_id, cost_zar FROM public.vehicle_operating_costs
        WHERE company_id = p_company_id AND trip_id IS NULL
      UNION ALL
      SELECT vehicle_id, cost_zar FROM public.fleet_maintenance_records
        WHERE company_id = p_company_id
    ) z GROUP BY vehicle_id
  ),
  vt AS (
    SELECT vehicle_id, sum(coalesce(net_tons, 0)) AS tons, count(*) AS n
    FROM tr GROUP BY vehicle_id
  ),
  base AS (
    SELECT tr.*,
      coalesce(d.c, 0) AS direct_cost,
      round(CASE
        WHEN coalesce(vt.tons, 0) > 0 THEN coalesce(pl.c, 0) * (coalesce(tr.net_tons, 0) / vt.tons)
        WHEN coalesce(vt.n, 0) > 0 THEN coalesce(pl.c, 0) / vt.n
        ELSE 0 END, 2) AS allocated_cost,
      CASE WHEN tr.rate IS NOT NULL THEN round(tr.net_tons * tr.rate, 2) ELSE NULL END AS revenue
    FROM tr
    LEFT JOIN direct d ON d.trip_id = tr.trip_id
    LEFT JOIN pool pl ON pl.vehicle_id = tr.vehicle_id
    LEFT JOIN vt ON vt.vehicle_id = tr.vehicle_id
  )
  SELECT b.trip_id, b.reference_number,
    coalesce(b.tmeta->>'truck_reg', fv.vehicle_registration_number),
    b.vehicle_id, b.route_id, b.txnmeta->>'commodity',
    bc.company_name, sc.company_name,
    b.net_tons, b.rate, b.currency, b.revenue, b.direct_cost, b.allocated_cost,
    round(b.direct_cost + b.allocated_cost, 2) AS total_cost,
    round(coalesce(b.revenue, 0) - (b.direct_cost + b.allocated_cost), 2) AS net,
    b.status, b.updated_at
  FROM base b
  LEFT JOIN public.fleet_vehicles fv ON fv.id = b.vehicle_id
  LEFT JOIN public.companies bc ON bc.id = b.buyer_company_id
  LEFT JOIN public.companies sc ON sc.id = b.supplier_company_id
  WHERE public.is_platform_admin() OR public.is_company_manager(p_company_id)
  ORDER BY b.updated_at DESC;
$fn$;
