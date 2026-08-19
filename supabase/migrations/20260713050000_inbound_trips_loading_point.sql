-- Add loading_point to list_mine_inbound_trips so the Load Controller's Record
-- Load drawer can auto-fill the waybill ORIGIN (it already auto-fills DESTINATION
-- from offloading_point). Return-type change requires drop + recreate.

drop function if exists public.list_mine_inbound_trips(uuid);

CREATE FUNCTION public.list_mine_inbound_trips(p_supplier_company_id uuid)
 RETURNS TABLE(trip_id uuid, status text, vehicle_id uuid, truck_reg text, route_id uuid, seal_required boolean, net_tons numeric, transaction_id uuid, buyer_company_id uuid, buyer_name text, transporter_name text, commodity text, reference text, offloading_point text, loading_point text, updated_at timestamp with time zone)
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select
    t.id, t.status, t.vehicle_id,
    coalesce(t.metadata->>'truck_reg', fv.vehicle_registration_number),
    t.route_id, coalesce(rt.seal_required, false), t.net_tons, tx.id,
    tx.buyer_company_id, bc.company_name, tc.company_name,
    coalesce(nullif(tx.metadata->>'commodity', ''), m.name),
    tx.reference_number,
    coalesce(rt.offloading_point, tx.metadata->>'offloading_point'),
    coalesce(rt.loading_point, tx.metadata->>'loading_point', sc.company_name),
    t.updated_at
  from public.trips t
  join public.transactions tx on tx.id = t.transaction_id
  left join public.fleet_vehicles fv on fv.id = t.vehicle_id
  left join public.routes rt on rt.id = t.route_id
  left join public.companies bc on bc.id = tx.buyer_company_id
  left join public.companies tc on tc.id = tx.transporter_company_id
  left join public.companies sc on sc.id = tx.supplier_company_id
  left join public.minerals m on m.id = tx.mineral_id
  where tx.supplier_company_id = p_supplier_company_id
    and public.is_company_staff(p_supplier_company_id)
    and (
      t.status not in ('completed', 'cancelled')
      or t.updated_at > timezone('utc', now()) - interval '2 days'
    )
  order by t.updated_at desc
  limit 200;
$function$;

revoke execute on function public.list_mine_inbound_trips(uuid) from public;
grant execute on function public.list_mine_inbound_trips(uuid) to authenticated;
