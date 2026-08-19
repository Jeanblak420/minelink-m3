-- Transporter earnings (2026-07-27). Applied live to project yftazblpmicqtamyiwyb.
--
-- Turns the raw ingredients the app already stores into money: revenue per trip
-- = the trip's weighbridge net tons × the transporter's rate/ton
-- (margin_ledger.transporter_price_per_ton, joined by route). The admin margin
-- is NEVER exposed. Maintenance cost per vehicle comes from
-- fleet_maintenance_records.cost_zar. Both are manager/admin-only.

CREATE OR REPLACE FUNCTION public.list_transporter_trip_earnings(p_company_id uuid)
 RETURNS TABLE(
   trip_id uuid, reference text, truck_reg text, vehicle_id uuid, route_id uuid,
   commodity text, customer_name text, source_name text,
   net_tons numeric, rate_per_ton numeric, currency text, revenue numeric,
   status text, updated_at timestamptz)
 LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public'
AS $fn$
  SELECT t.id, txn.reference_number,
    coalesce(t.metadata->>'truck_reg', fv.vehicle_registration_number),
    t.vehicle_id, t.route_id,
    txn.metadata->>'commodity', bc.company_name, sc.company_name,
    t.net_tons, mlx.transporter_price_per_ton, coalesce(mlx.currency, 'ZAR'),
    CASE WHEN t.net_tons IS NOT NULL AND mlx.transporter_price_per_ton IS NOT NULL
      THEN round(t.net_tons * mlx.transporter_price_per_ton, 2) ELSE NULL END,
    t.status, t.updated_at
  FROM public.trips t
  JOIN public.transactions txn ON txn.id = t.transaction_id
  LEFT JOIN public.fleet_vehicles fv ON fv.id = t.vehicle_id
  LEFT JOIN public.companies bc ON bc.id = txn.buyer_company_id
  LEFT JOIN public.companies sc ON sc.id = txn.supplier_company_id
  LEFT JOIN LATERAL (
    SELECT ml.transporter_price_per_ton, ml.currency
    FROM public.margin_ledger ml
    WHERE ml.route_id = t.route_id
    ORDER BY ml.created_at DESC LIMIT 1) mlx ON true
  WHERE (public.is_platform_admin() OR public.is_company_manager(p_company_id))
    AND txn.transporter_company_id = p_company_id
    AND t.net_tons IS NOT NULL
  ORDER BY t.updated_at DESC;
$fn$;

CREATE OR REPLACE FUNCTION public.list_transporter_vehicle_costs(p_company_id uuid)
 RETURNS TABLE(vehicle_id uuid, reg text, maintenance_cost numeric, record_count bigint)
 LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public'
AS $fn$
  SELECT m.vehicle_id, fv.vehicle_registration_number,
    coalesce(sum(m.cost_zar), 0), count(*)
  FROM public.fleet_maintenance_records m
  JOIN public.fleet_vehicles fv ON fv.id = m.vehicle_id
  WHERE (public.is_platform_admin() OR public.is_company_manager(p_company_id))
    AND m.company_id = p_company_id
  GROUP BY m.vehicle_id, fv.vehicle_registration_number;
$fn$;
