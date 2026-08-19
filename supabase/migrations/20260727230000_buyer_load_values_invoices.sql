-- Buyer money layer: Rand value per load + delivered vs invoiced recon (2026-07-27).
--
-- Tonnage was everywhere, Rand nowhere: the buyer could not reconcile delivered
-- tons against invoiced money. This migration adds:
--
--  1. `load_invoices` — the buyer captures the invoice they received for a
--     delivered load (number, amount, tons, date). One per trip. Buyer-private
--     (+ platform admin): the mine and transporter never see the buyer's
--     invoice amounts.
--  2. `list_buyer_trip_values` — per delivered load, the buyer's money view:
--     rate = the AGREED price/ton from the margin ledger (what the buyer
--     agreed to pay; the admin margin and the transporter's price are NEVER
--     returned), loaded value (mine net × rate), delivered value (delivered
--     tons × rate), quality-adjusted payable value (payable tons × grade
--     factor × rate, when a quality certificate exists), and the invoice with
--     its variance vs the payable (or delivered) value.

begin;

-- 1. The buyer's invoice per delivered load ------------------------------------

create table if not exists public.load_invoices (
  id uuid primary key default gen_random_uuid(),
  trip_id uuid not null unique references public.trips(id) on delete cascade,
  buyer_company_id uuid not null references public.companies(id),
  invoice_number text not null,
  invoiced_tons numeric check (invoiced_tons is null or invoiced_tons >= 0),
  invoiced_amount numeric not null check (invoiced_amount >= 0),
  currency text not null default 'ZAR',
  invoice_date date not null default current_date,
  notes text,
  created_by uuid default auth.uid(),
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

comment on table public.load_invoices is
  'Invoice the buyer received for one delivered load (trip) — reconciled against the load''s delivered/payable Rand value. Buyer-private + platform admin.';

create index if not exists idx_load_invoices_buyer
  on public.load_invoices (buyer_company_id);

alter table public.load_invoices enable row level security;

drop policy if exists load_invoices_select on public.load_invoices;
create policy load_invoices_select on public.load_invoices
  for select to authenticated
  using (public.is_platform_admin() or public.is_company_staff(buyer_company_id));

drop policy if exists load_invoices_insert on public.load_invoices;
create policy load_invoices_insert on public.load_invoices
  for insert to authenticated
  with check (
    public.is_company_staff(buyer_company_id)
    and exists (
      select 1
      from public.trips t
      join public.transactions txn on txn.id = t.transaction_id
      where t.id = load_invoices.trip_id
        and txn.buyer_company_id = load_invoices.buyer_company_id
    )
  );

drop policy if exists load_invoices_update on public.load_invoices;
create policy load_invoices_update on public.load_invoices
  for update to authenticated
  using (public.is_company_staff(buyer_company_id))
  with check (
    public.is_company_staff(buyer_company_id)
    and exists (
      select 1
      from public.trips t
      join public.transactions txn on txn.id = t.transaction_id
      where t.id = load_invoices.trip_id
        and txn.buyer_company_id = load_invoices.buyer_company_id
    )
  );

drop policy if exists load_invoices_delete on public.load_invoices;
create policy load_invoices_delete on public.load_invoices
  for delete to authenticated
  using (public.is_company_manager(buyer_company_id) or public.is_platform_admin());

grant select, insert, update, delete on public.load_invoices to authenticated;

-- 2. Per-load Rand values for the buyer ----------------------------------------

create or replace function public.list_buyer_trip_values(p_company_id uuid)
returns table(
  trip_id uuid,
  reference text,
  truck_reg text,
  commodity text,
  source_name text,
  transporter_name text,
  net_tons numeric,
  delivered_tons numeric,
  rate_per_ton numeric,
  currency text,
  loaded_value numeric,
  delivered_value numeric,
  payable_tons numeric,
  grade_factor numeric,
  payable_value numeric,
  invoice_id uuid,
  invoice_number text,
  invoiced_tons numeric,
  invoiced_amount numeric,
  invoice_date date,
  invoice_variance numeric,
  trip_status text,
  updated_at timestamptz
)
language sql
stable
security definer
set search_path to 'public'
as $function$
  with base as (
    select
      t.id as trip_id,
      txn.reference_number,
      coalesce(t.metadata->>'truck_reg', fv.vehicle_registration_number) as truck_reg,
      txn.metadata->>'commodity' as commodity,
      sc.company_name as source_name,
      tc.company_name as transporter_name,
      t.net_tons,
      pod.delivered_tons,
      mlx.agreed_price_per_ton as rate_per_ton,
      coalesce(mlx.currency, 'ZAR') as currency,
      -- Quality-adjusted payable tons (same formula as list_load_quality).
      case
        when q.moisture_pct is not null then
          round(
            coalesce(pod.delivered_tons, t.net_tons)
            * (1 - greatest(q.moisture_pct - coalesce(r.spec_moisture_max_pct, q.moisture_pct), 0) / 100.0),
            2)
        else null
      end as payable_tons,
      case
        when q.cr2o3_pct is not null and r.spec_cr2o3_pct is not null and r.spec_cr2o3_pct > 0
          then round(least(1, q.cr2o3_pct / r.spec_cr2o3_pct), 4)
        else null
      end as grade_factor,
      inv.id as invoice_id,
      inv.invoice_number,
      inv.invoiced_tons,
      inv.invoiced_amount,
      inv.invoice_date,
      t.status as trip_status,
      t.updated_at
    from public.trips t
    join public.transactions txn on txn.id = t.transaction_id
    left join public.fleet_vehicles fv on fv.id = t.vehicle_id
    left join public.companies sc on sc.id = txn.supplier_company_id
    left join public.companies tc on tc.id = txn.transporter_company_id
    left join public.routes r on r.id = t.route_id
    left join public.load_quality_certs q on q.trip_id = t.id
    left join public.load_invoices inv on inv.trip_id = t.id
    left join public.request_dispatches rd
      on rd.id = coalesce(t.dispatch_id, txn.dispatch_id)
    left join lateral (
      select ml.agreed_price_per_ton, ml.currency
      from public.margin_ledger ml
      where ml.request_id = rd.request_id
      order by ml.created_at desc
      limit 1
    ) mlx on true
    left join lateral (
      select p.delivered_tons from public.pod_uploads p
      where p.trip_id = t.id order by p.uploaded_at desc limit 1
    ) pod on true
    where (public.is_platform_admin() or public.is_company_staff(p_company_id))
      and txn.buyer_company_id = p_company_id
      and t.net_tons is not null
  )
  select
    b.trip_id,
    b.reference_number,
    b.truck_reg,
    b.commodity,
    b.source_name,
    b.transporter_name,
    b.net_tons,
    b.delivered_tons,
    b.rate_per_ton,
    b.currency,
    case when b.rate_per_ton is not null
      then round(b.net_tons * b.rate_per_ton, 2) end as loaded_value,
    case when b.rate_per_ton is not null and b.delivered_tons is not null
      then round(b.delivered_tons * b.rate_per_ton, 2) end as delivered_value,
    b.payable_tons,
    b.grade_factor,
    case when b.rate_per_ton is not null
           and coalesce(b.payable_tons, b.delivered_tons) is not null
      then round(coalesce(b.payable_tons, b.delivered_tons)
                 * coalesce(b.grade_factor, 1) * b.rate_per_ton, 2)
    end as payable_value,
    b.invoice_id,
    b.invoice_number,
    b.invoiced_tons,
    b.invoiced_amount,
    b.invoice_date,
    -- Invoice variance: what was invoiced minus what the load is worth
    -- (quality-adjusted payable value when available, else delivered value).
    case when b.invoiced_amount is not null and b.rate_per_ton is not null
           and coalesce(b.payable_tons, b.delivered_tons) is not null
      then round(b.invoiced_amount
                 - coalesce(b.payable_tons, b.delivered_tons)
                   * coalesce(b.grade_factor, 1) * b.rate_per_ton, 2)
    end as invoice_variance,
    b.trip_status,
    b.updated_at
  from base b
  order by b.updated_at desc;
$function$;

revoke all on function public.list_buyer_trip_values(uuid) from public;
revoke all on function public.list_buyer_trip_values(uuid) from anon;
grant execute on function public.list_buyer_trip_values(uuid) to authenticated;

commit;
