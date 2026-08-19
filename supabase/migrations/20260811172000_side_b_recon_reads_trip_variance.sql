-- ============================================================================
-- Side B reads the same variance the raw table does (P3-13, part 2)
-- ----------------------------------------------------------------------------
-- Same change as `list_raw_recon_rows`, for the same reason. This one already
-- computed a variance -- `t.net_tons - pod.delivered_tons`, in the SELECT --
-- which was correct but was a THIRD place the same subtraction lived. It now
-- reads the generated `trips.variance_tons`, so Side A, Side B and every
-- export are the same number by construction rather than by three expressions
-- happening to agree.
--
-- Signature unchanged, so `create or replace` is enough here.
-- ============================================================================

create or replace function public.list_trip_reconciliations(p_company_id uuid)
returns table (
  trip_id uuid,
  reference text,
  truck_reg text,
  commodity text,
  source_name text,
  customer_name text,
  transporter_name text,
  mine_net_tons numeric,
  delivered_tons numeric,
  variance numeric,
  trip_status text,
  pod_photo_path text,
  updated_at timestamptz
)
language sql
stable
security definer
set search_path = public
as $$
  select t.id, txn.reference_number,
    coalesce(t.metadata->>'truck_reg', fv.vehicle_registration_number),
    txn.metadata->>'commodity', sc.company_name, bc.company_name, tc.company_name,
    -- The mine's net stays authoritative; the delivered figure and the
    -- variance both come off the trip, not from a re-derivation here.
    t.net_tons, t.delivered_tons, t.variance_tons,
    t.status, pod.photo_url, t.updated_at
  from public.trips t
  join public.transactions txn on txn.id = t.transaction_id
  left join public.fleet_vehicles fv on fv.id = t.vehicle_id
  left join public.companies sc on sc.id = txn.supplier_company_id
  left join public.companies bc on bc.id = txn.buyer_company_id
  left join public.companies tc on tc.id = txn.transporter_company_id
  left join lateral (
    -- Photo only.
    select p.photo_url from public.pod_uploads p
    where p.trip_id = t.id order by p.uploaded_at desc limit 1
  ) pod on true
  where (public.is_platform_admin()
      or public.is_company_staff(txn.supplier_company_id)
      or public.is_company_staff(txn.buyer_company_id)
      or public.is_company_staff(txn.transporter_company_id))
    and (p_company_id is null or txn.supplier_company_id = p_company_id
      or txn.buyer_company_id = p_company_id or txn.transporter_company_id = p_company_id)
    and t.net_tons is not null
  order by t.updated_at desc;
$$;

comment on function public.list_trip_reconciliations(uuid) is
  'Side B reconciled view, party-scoped: mine net mass (authoritative) vs the '
  'delivered re-weigh, with the generated trips.variance_tons. Positive '
  'variance is mass that left the mine and did not arrive.';

revoke execute on function public.list_trip_reconciliations(uuid) from public;
grant  execute on function public.list_trip_reconciliations(uuid) to authenticated;
