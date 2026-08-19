-- Mine production vs dispatch (2026-07-27).
--
-- Only tons-OUT was tracked: no tons-mined input, so no yield or pit-to-port
-- loss view, and stockpile INSERT was RLS-locked to the system dispatch
-- function, so a mine could not even represent its own ROM/production piles.
--
--  1. `stockpiles.kind` — 'order' (system-created, capped, unchanged) vs
--     'production' (mine-owned ROM/production piles). A new INSERT policy lets
--     the mine's stockpile writers create PRODUCTION piles only; order piles
--     stay system-only (`with check (false)` policy remains for other inserts).
--  2. `production_entries` — the tons-mined input: date, tons, commodity,
--     pit/section. Recorded via `record_production`, which can atomically add
--     the tonnage onto one of the mine's production piles.
--  3. `mine_production_dispatch_report` — per-day tons mined vs tons
--     dispatched (weighbridge net out of this mine), the raw series behind
--     yield % and pit-to-port loss.

begin;

-- 1. Production piles ----------------------------------------------------------

alter table public.stockpiles
  add column if not exists kind text not null default 'order';

alter table public.stockpiles
  drop constraint if exists stockpiles_kind_check;
alter table public.stockpiles
  add constraint stockpiles_kind_check check (kind in ('order', 'production'));

comment on column public.stockpiles.kind is
  'order = system-created capped order stockpile; production = mine-owned ROM/production pile (mine-creatable).';

-- Mine stockpile writers may create their own PRODUCTION piles (never order
-- piles — those are minted only by the SECURITY DEFINER dispatch function).
drop policy if exists stockpiles_insert_production on public.stockpiles;
create policy stockpiles_insert_production on public.stockpiles
  for insert to authenticated
  with check (
    kind = 'production'
    and request_id is null
    and route_id is null
    and buyer_company_id is null
    and max_cap_tons is null
    and public.is_company_stockpile_writer(supplier_company_id)
  );

-- 2. Tons-mined input ----------------------------------------------------------

create table if not exists public.production_entries (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete cascade,
  entry_date date not null default current_date,
  tons numeric not null check (tons > 0),
  commodity text,
  pit_section text,
  stockpile_id uuid references public.stockpiles(id) on delete set null,
  notes text,
  created_by uuid default auth.uid(),
  created_at timestamptz not null default timezone('utc', now())
);

comment on table public.production_entries is
  'Tons mined per day at a mine (ROM production input) — the missing half of production-vs-dispatch yield reporting.';

create index if not exists idx_production_entries_company_date
  on public.production_entries (company_id, entry_date);

alter table public.production_entries enable row level security;

drop policy if exists production_entries_select on public.production_entries;
create policy production_entries_select on public.production_entries
  for select to authenticated
  using (public.is_platform_admin() or public.is_company_staff(company_id));

-- Inserts go through record_production (validates + optional pile add).
drop policy if exists production_entries_delete on public.production_entries;
create policy production_entries_delete on public.production_entries
  for delete to authenticated
  using (public.is_company_manager(company_id) or public.is_platform_admin());

grant select, delete on public.production_entries to authenticated;

create or replace function public.record_production(
  p_company_id uuid,
  p_tons numeric,
  p_entry_date date default current_date,
  p_commodity text default null,
  p_pit_section text default null,
  p_stockpile_id uuid default null,
  p_notes text default null
) returns public.production_entries
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_sp public.stockpiles;
  v_row public.production_entries;
begin
  if not public.is_company_stockpile_writer(p_company_id) then
    raise exception 'Only this mine''s supervisors/management may record production';
  end if;
  if p_tons is null or p_tons <= 0 then
    raise exception 'Enter a mined tonnage greater than zero';
  end if;
  if p_entry_date is null or p_entry_date > current_date then
    raise exception 'The production date cannot be in the future';
  end if;

  if p_stockpile_id is not null then
    select * into v_sp from public.stockpiles where id = p_stockpile_id;
    if not found or v_sp.supplier_company_id <> p_company_id then
      raise exception 'That stockpile does not belong to this mine';
    end if;
    if v_sp.kind <> 'production' then
      raise exception 'Production can only be added onto a production/ROM pile — order stockpiles are filled from the Supervisor screen';
    end if;
  end if;

  insert into public.production_entries (
    company_id, entry_date, tons, commodity, pit_section, stockpile_id, notes, created_by
  ) values (
    p_company_id, p_entry_date, p_tons,
    nullif(trim(p_commodity), ''), nullif(trim(p_pit_section), ''),
    p_stockpile_id, nullif(trim(p_notes), ''), auth.uid()
  ) returning * into v_row;

  -- Atomically reflect the mined tons on the chosen production pile (cap-free
  -- for production piles; writes the ledger row like every other addition).
  if p_stockpile_id is not null then
    perform public.stockpile_add_tons(p_stockpile_id, p_tons);
  end if;

  return v_row;
end;
$function$;

revoke all on function public.record_production(uuid, numeric, date, text, text, uuid, text) from public;
revoke all on function public.record_production(uuid, numeric, date, text, text, uuid, text) from anon;
grant execute on function public.record_production(uuid, numeric, date, text, text, uuid, text) to authenticated;

-- 3. Production vs dispatch series ---------------------------------------------

create or replace function public.mine_production_dispatch_report(
  p_company_id uuid,
  p_from date,
  p_to date
) returns table(
  day date,
  mined_tons numeric,
  dispatched_tons numeric
)
language sql
stable
security definer
set search_path to 'public'
as $function$
  with mined as (
    select pe.entry_date as day, sum(pe.tons) as tons
    from public.production_entries pe
    where pe.company_id = p_company_id
      and pe.entry_date between p_from and p_to
    group by pe.entry_date
  ),
  dispatched as (
    select (coalesce(t.loaded_at, t.updated_at) at time zone 'utc')::date as day,
           sum(t.net_tons) as tons
    from public.trips t
    join public.transactions txn on txn.id = t.transaction_id
    where txn.supplier_company_id = p_company_id
      and t.net_tons is not null
      and (coalesce(t.loaded_at, t.updated_at) at time zone 'utc')::date
            between p_from and p_to
    group by 1
  )
  select
    coalesce(m.day, d.day),
    coalesce(m.tons, 0),
    coalesce(d.tons, 0)
  from mined m
  full outer join dispatched d on d.day = m.day
  where public.is_platform_admin() or public.is_company_staff(p_company_id)
  order by 1;
$function$;

revoke all on function public.mine_production_dispatch_report(uuid, date, date) from public;
revoke all on function public.mine_production_dispatch_report(uuid, date, date) from anon;
grant execute on function public.mine_production_dispatch_report(uuid, date, date) to authenticated;

commit;
