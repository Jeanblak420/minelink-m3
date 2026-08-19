-- Load quality certificates + payable-tons penalty calc (2026-07-27).
--
-- Grade was a free-text string and lab PDFs only ever attached to REQUESTS,
-- never to a delivered load. This migration makes quality first-class:
--
--  1. Structured contract spec on the route (target Cr2O3 %, max moisture %,
--     sizing) — the yardstick every load is judged against.
--  2. Structured grade fields on stockpiles (alongside the legacy free-text
--     `grade`), so ROM/production piles can carry real assay values.
--  3. `load_quality_certs` — ONE certificate per delivered load (trip):
--     Cr2O3 %, moisture %, sizing, notes + the lab PDF/image in the new
--     private `quality_certs` bucket. Attached by the mine, viewable by every
--     party on the transaction and the platform admin.
--  4. Payable-tons penalty calc (critical for chrome/coal payable tons):
--       payable_tons  = basis_tons × (1 − excess_moisture/100)
--                       where excess_moisture = max(0, moisture − spec max)
--                       and basis_tons = delivered tons (fallback: mine net)
--       grade_factor  = min(1, Cr2O3 / spec Cr2O3)   (penalty only, no bonus)
--     Money stays out of this RPC — `list_buyer_trip_values` (next migration)
--     turns payable tons × grade factor × the buyer's rate into Rand.

begin;

-- 1. Contract quality spec on the route ----------------------------------------

alter table public.routes
  add column if not exists spec_cr2o3_pct numeric,
  add column if not exists spec_moisture_max_pct numeric,
  add column if not exists spec_sizing text;

-- 2. Structured grade on stockpiles --------------------------------------------

alter table public.stockpiles
  add column if not exists cr2o3_pct numeric,
  add column if not exists moisture_pct numeric,
  add column if not exists sizing text;

-- 3. The per-load certificate table --------------------------------------------

create table if not exists public.load_quality_certs (
  id uuid primary key default gen_random_uuid(),
  trip_id uuid not null unique references public.trips(id) on delete cascade,
  transaction_id uuid not null references public.transactions(id) on delete cascade,
  supplier_company_id uuid not null references public.companies(id),
  cr2o3_pct numeric check (cr2o3_pct is null or (cr2o3_pct >= 0 and cr2o3_pct <= 100)),
  moisture_pct numeric check (moisture_pct is null or (moisture_pct >= 0 and moisture_pct <= 100)),
  sizing text,
  notes text,
  cert_path text,
  file_name text,
  issued_at date not null default current_date,
  created_by uuid default auth.uid(),
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

comment on table public.load_quality_certs is
  'One quality certificate per delivered load (trip): structured Cr2O3/moisture/sizing + the lab PDF. Attached by the mine, visible to all transaction parties.';

create index if not exists idx_load_quality_certs_txn
  on public.load_quality_certs (transaction_id);
create index if not exists idx_load_quality_certs_supplier
  on public.load_quality_certs (supplier_company_id);

alter table public.load_quality_certs enable row level security;

-- Every party on the transaction (mine / buyer / transporter) + platform admin may read.
drop policy if exists load_quality_certs_select on public.load_quality_certs;
create policy load_quality_certs_select on public.load_quality_certs
  for select to authenticated
  using (
    public.is_platform_admin()
    or exists (
      select 1 from public.transactions txn
      where txn.id = load_quality_certs.transaction_id
        and (
          public.is_company_staff(txn.supplier_company_id)
          or public.is_company_staff(txn.buyer_company_id)
          or public.is_company_staff(txn.transporter_company_id)
        )
    )
  );

-- Writes go through the set_load_quality_cert RPC (SECURITY DEFINER validates
-- the caller is the loading mine's staff). No direct-write policies.

grant select on public.load_quality_certs to authenticated;

-- 4. Private storage bucket for the certificate files ---------------------------

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'quality_certs',
  'quality_certs',
  false,
  20971520,
  array['application/pdf', 'image/png', 'image/jpeg', 'image/webp', 'image/heic']
)
on conflict (id) do update
set public = excluded.public,
    file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;

-- Mine staff manage files under their company folder (<company_id>/...).
drop policy if exists quality_certs_insert_company on storage.objects;
create policy quality_certs_insert_company
on storage.objects for insert to authenticated
with check (
  bucket_id = 'quality_certs'
  and exists (
    select 1 from public.companies c
    where c.id::text = (storage.foldername(name))[1]
      and public.is_company_staff(c.id)
  )
);

drop policy if exists quality_certs_delete_company on storage.objects;
create policy quality_certs_delete_company
on storage.objects for delete to authenticated
using (
  bucket_id = 'quality_certs'
  and exists (
    select 1 from public.companies c
    where c.id::text = (storage.foldername(name))[1]
      and public.is_company_staff(c.id)
  )
);

-- View: own-company folder, platform admin, or any party on the transaction
-- the certificate is attached to (same cross-party pattern as pod_photos).
drop policy if exists quality_certs_select on storage.objects;
create policy quality_certs_select
on storage.objects for select to authenticated
using (
  bucket_id = 'quality_certs'
  and (
    public.is_platform_admin()
    or exists (
      select 1 from public.companies c
      where c.id::text = (storage.foldername(name))[1]
        and public.is_company_staff(c.id)
    )
    or exists (
      select 1
      from public.load_quality_certs q
      join public.transactions txn on txn.id = q.transaction_id
      where q.cert_path = storage.objects.name
        and (
          public.is_company_staff(txn.supplier_company_id)
          or public.is_company_staff(txn.buyer_company_id)
          or public.is_company_staff(txn.transporter_company_id)
        )
    )
  )
);

-- 5. Attach/replace the certificate on a load (mine staff or platform admin) ---

create or replace function public.set_load_quality_cert(
  p_trip_id uuid,
  p_cr2o3_pct numeric default null,
  p_moisture_pct numeric default null,
  p_sizing text default null,
  p_notes text default null,
  p_cert_path text default null,
  p_file_name text default null
) returns public.load_quality_certs
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_trip public.trips;
  v_txn public.transactions;
  v_row public.load_quality_certs;
begin
  select * into v_trip from public.trips where id = p_trip_id;
  if not found then
    raise exception 'Trip % not found', p_trip_id;
  end if;
  select * into v_txn from public.transactions where id = v_trip.transaction_id;

  if not (public.is_platform_admin()
          or public.is_company_staff(v_txn.supplier_company_id)) then
    raise exception 'Only the loading mine''s staff may attach a quality certificate';
  end if;
  if v_trip.net_tons is null then
    raise exception 'Record the load''s weighbridge Net Weight before attaching a certificate';
  end if;
  if p_cr2o3_pct is null and p_moisture_pct is null
     and coalesce(p_sizing, '') = '' and coalesce(p_cert_path, '') = '' then
    raise exception 'Enter at least one quality value or attach the lab certificate file';
  end if;

  insert into public.load_quality_certs (
    trip_id, transaction_id, supplier_company_id,
    cr2o3_pct, moisture_pct, sizing, notes, cert_path, file_name, created_by
  ) values (
    p_trip_id, v_trip.transaction_id, v_txn.supplier_company_id,
    p_cr2o3_pct, p_moisture_pct, nullif(trim(p_sizing), ''),
    nullif(trim(p_notes), ''), nullif(trim(p_cert_path), ''),
    nullif(trim(p_file_name), ''), auth.uid()
  )
  on conflict (trip_id) do update set
    cr2o3_pct = excluded.cr2o3_pct,
    moisture_pct = excluded.moisture_pct,
    sizing = excluded.sizing,
    notes = excluded.notes,
    -- A new file replaces the old reference; omitting the file keeps it.
    cert_path = coalesce(excluded.cert_path, load_quality_certs.cert_path),
    file_name = coalesce(excluded.file_name, load_quality_certs.file_name),
    updated_at = timezone('utc', now())
  returning * into v_row;

  return v_row;
end;
$function$;

revoke all on function public.set_load_quality_cert(uuid, numeric, numeric, text, text, text, text) from public;
revoke all on function public.set_load_quality_cert(uuid, numeric, numeric, text, text, text, text) from anon;
grant execute on function public.set_load_quality_cert(uuid, numeric, numeric, text, text, text, text) to authenticated;

-- 6. Party-scoped load-quality listing (tons-level; money lives elsewhere) -----

create or replace function public.list_load_quality(p_company_id uuid)
returns table(
  trip_id uuid,
  reference text,
  truck_reg text,
  commodity text,
  source_name text,
  customer_name text,
  net_tons numeric,
  delivered_tons numeric,
  cr2o3_pct numeric,
  moisture_pct numeric,
  sizing text,
  cert_notes text,
  cert_path text,
  cert_file_name text,
  issued_at date,
  spec_cr2o3_pct numeric,
  spec_moisture_max_pct numeric,
  spec_sizing text,
  payable_tons numeric,
  grade_factor numeric,
  trip_status text,
  route_id uuid,
  updated_at timestamptz
)
language sql
stable
security definer
set search_path to 'public'
as $function$
  select
    t.id,
    txn.reference_number,
    coalesce(t.metadata->>'truck_reg', fv.vehicle_registration_number),
    txn.metadata->>'commodity',
    sc.company_name,
    bc.company_name,
    t.net_tons,
    pod.delivered_tons,
    q.cr2o3_pct,
    q.moisture_pct,
    q.sizing,
    q.notes,
    q.cert_path,
    q.file_name,
    q.issued_at,
    r.spec_cr2o3_pct,
    r.spec_moisture_max_pct,
    r.spec_sizing,
    -- Payable tons: excess moisture over the contract max is deducted pro-rata
    -- from the delivered (outturn) tonnage; falls back to the mine net.
    case
      when q.moisture_pct is not null then
        round(
          coalesce(pod.delivered_tons, t.net_tons)
          * (1 - greatest(q.moisture_pct - coalesce(r.spec_moisture_max_pct, q.moisture_pct), 0) / 100.0),
          2)
      else null
    end,
    -- Grade factor: pro-rata penalty below the contract grade, capped at 1.
    case
      when q.cr2o3_pct is not null and r.spec_cr2o3_pct is not null and r.spec_cr2o3_pct > 0
        then round(least(1, q.cr2o3_pct / r.spec_cr2o3_pct), 4)
      else null
    end,
    t.status,
    t.route_id,
    greatest(t.updated_at, coalesce(q.updated_at, t.updated_at))
  from public.trips t
  join public.transactions txn on txn.id = t.transaction_id
  left join public.fleet_vehicles fv on fv.id = t.vehicle_id
  left join public.companies sc on sc.id = txn.supplier_company_id
  left join public.companies bc on bc.id = txn.buyer_company_id
  left join public.routes r on r.id = t.route_id
  left join public.load_quality_certs q on q.trip_id = t.id
  left join lateral (
    select p.delivered_tons from public.pod_uploads p
    where p.trip_id = t.id order by p.uploaded_at desc limit 1
  ) pod on true
  where (
      public.is_platform_admin()
      or public.is_company_staff(txn.supplier_company_id)
      or public.is_company_staff(txn.buyer_company_id)
      or public.is_company_staff(txn.transporter_company_id)
    )
    and (
      p_company_id is null
      or txn.supplier_company_id = p_company_id
      or txn.buyer_company_id = p_company_id
      or txn.transporter_company_id = p_company_id
    )
    and t.net_tons is not null
  order by greatest(t.updated_at, coalesce(q.updated_at, t.updated_at)) desc;
$function$;

revoke all on function public.list_load_quality(uuid) from public;
revoke all on function public.list_load_quality(uuid) from anon;
grant execute on function public.list_load_quality(uuid) to authenticated;

-- 7. The mine (or admin) sets the contract quality spec on its route -----------

create or replace function public.set_route_quality_spec(
  p_route_id uuid,
  p_spec_cr2o3_pct numeric default null,
  p_spec_moisture_max_pct numeric default null,
  p_spec_sizing text default null
) returns public.routes
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_row public.routes;
begin
  select * into v_row from public.routes where id = p_route_id;
  if not found then
    raise exception 'Route % not found', p_route_id;
  end if;
  if not (public.is_platform_admin()
          or public.is_company_staff(v_row.supplier_company_id)) then
    raise exception 'Only the supplying mine or the platform admin may set the quality spec';
  end if;
  if p_spec_cr2o3_pct is not null and (p_spec_cr2o3_pct <= 0 or p_spec_cr2o3_pct > 100) then
    raise exception 'Target Cr2O3 %% must be between 0 and 100';
  end if;
  if p_spec_moisture_max_pct is not null
     and (p_spec_moisture_max_pct < 0 or p_spec_moisture_max_pct > 100) then
    raise exception 'Max moisture %% must be between 0 and 100';
  end if;

  update public.routes set
    spec_cr2o3_pct = p_spec_cr2o3_pct,
    spec_moisture_max_pct = p_spec_moisture_max_pct,
    spec_sizing = nullif(trim(p_spec_sizing), '')
  where id = p_route_id
  returning * into v_row;

  return v_row;
end;
$function$;

revoke all on function public.set_route_quality_spec(uuid, numeric, numeric, text) from public;
revoke all on function public.set_route_quality_spec(uuid, numeric, numeric, text) from anon;
grant execute on function public.set_route_quality_spec(uuid, numeric, numeric, text) to authenticated;

commit;
