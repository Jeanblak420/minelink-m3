-- One clock: Africa/Johannesburg.
--
-- Jean's ruling, 2026-08-17: a single basis everywhere. MineLink operates only
-- in South Africa, which is UTC+02:00 and has never observed daylight saving,
-- so the offset is a constant rather than a rule.
--
-- WHY NOT `alter database ... set timezone` -- the obvious one-line fix, which
-- would have been wrong:
--
--   ~180 columns in this schema default to `timezone('utc', now())`. That
--   expression returns a **naive** timestamp (the UTC wall clock), and storing
--   a naive timestamp into a `timestamptz` column reinterprets it in the
--   SESSION zone. Measured on production before touching anything:
--
--     session UTC   -> stored 2026-08-17 09:41:19+02   (the real instant)
--     session SAST  -> stored 2026-08-17 07:41:19+02   (two hours early)
--
--   So flipping the database timezone would silently shift every created_at and
--   updated_at in the product by two hours, for ever, while looking like a
--   tidy-up. The database stays on UTC (confirmed: pg_settings TimeZone = UTC,
--   from the configuration file) and the zone is named explicitly wherever a
--   **day** is decided.
--
-- These two helpers are that one place. Everything that used `current_date` to
-- mean "today at the mine" now says `ml_today()`, and everything that bucketed
-- an instant into a day says `ml_day()`. If MineLink ever leaves South Africa,
-- this file is what changes -- and it must become a real zone lookup, not a
-- bigger constant. `lib/core/time/ml_time.dart` is the client's half of the
-- same decision.

create or replace function public.ml_zone()
returns text
language sql
immutable
parallel safe
as $function$ select 'Africa/Johannesburg'::text $function$;

comment on function public.ml_zone() is
  'The one timezone MineLink reckons days in. Named once so a move out of South '
  'Africa is a single edit rather than a search.';

create or replace function public.ml_today()
returns date
language sql
stable
parallel safe
as $function$ select (now() at time zone public.ml_zone())::date $function$;

comment on function public.ml_today() is
  'Today, on the clock at the mine. Replaces `current_date`, which is a UTC '
  'calendar day and therefore flips at 02:00 SAST -- in the middle of a night '
  'shift, and two hours after the pit changed date.';

create or replace function public.ml_day(p_at timestamptz)
returns date
language sql
immutable
parallel safe
as $function$ select (p_at at time zone public.ml_zone())::date $function$;

comment on function public.ml_day(timestamptz) is
  'The South African day an instant falls in. The day bucket for every report '
  'that groups tonnage.';

create or replace function public.ml_day_start(p_day date)
returns timestamptz
language sql
stable
parallel safe
as $function$ select (p_day::timestamp at time zone public.ml_zone()) $function$;

comment on function public.ml_day_start(date) is
  'Midnight in South Africa on a given day, as an instant -- for the edges of a '
  'date window, so the filter and the bucket agree. `p_day::timestamptz` uses '
  'the SESSION zone and would not.';

grant execute on function public.ml_zone() to authenticated, anon, service_role;
grant execute on function public.ml_today() to authenticated, anon, service_role;
grant execute on function public.ml_day(timestamptz) to authenticated, anon, service_role;
grant execute on function public.ml_day_start(date) to authenticated, anon, service_role;

-- ---------------------------------------------------------------------------
-- The production-vs-dispatch report, which was joining two different calendars.
--
-- `mined` comes from `production_entries.entry_date` -- a day a person at the
-- mine typed. `dispatched` was bucketed `at time zone 'utc'`. They are then
-- joined on `d.day = m.day`, so every load that left between 00:00 and 02:00
-- SAST was attributed to the previous day and landed on the wrong row. The
-- screen reading this computes Yield % and pit-to-port loss from those sums, so
-- the error is in a number the mine manages the pit by. This was wrong before
-- today's ruling and independently of it.

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
    -- Same calendar as `mined`: the one at the mine.
    select public.ml_day(coalesce(t.loaded_at, t.updated_at)) as day,
           sum(t.net_tons) as tons
    from public.trips t
    join public.transactions txn on txn.id = t.transaction_id
    where txn.supplier_company_id = p_company_id
      and t.net_tons is not null
      and public.ml_day(coalesce(t.loaded_at, t.updated_at))
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

-- ---------------------------------------------------------------------------
-- "The production date cannot be in the future" -- measured against the pit's
-- today, not UTC's. Between midnight and 02:00 SAST a supervisor recording the
-- shift they had just finished was refused, because UTC still thought it was
-- yesterday and their date was therefore "tomorrow".

create or replace function public.record_production(
  p_company_id uuid,
  p_tons numeric,
  p_entry_date date default null,
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
  v_date date := coalesce(p_entry_date, public.ml_today());
begin
  if not public.is_company_stockpile_writer(p_company_id) then
    raise exception 'Only this mine''s supervisors/management may record production';
  end if;
  if p_tons is null or p_tons <= 0 then
    raise exception 'Enter a mined tonnage greater than zero';
  end if;
  if v_date > public.ml_today() then
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
    p_company_id, v_date, p_tons,
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

revoke all on function public.record_production(uuid, numeric, date, text, text, uuid, text) from public, anon;
grant execute on function public.record_production(uuid, numeric, date, text, text, uuid, text) to authenticated;

-- ---------------------------------------------------------------------------
-- Business dates a person will read off a document, stamped on the pit's day.

alter table public.production_entries alter column entry_date set default public.ml_today();
alter table public.load_invoices     alter column invoice_date set default public.ml_today();
alter table public.load_quality_certs alter column issued_at   set default public.ml_today();

comment on column public.load_invoices.invoice_date is
  'The day the buyer dates the invoice. Defaults to the day at the mine '
  '(ml_today), not the UTC one -- an invoice raised at 01:00 SAST used to be '
  'dated yesterday.';
comment on column public.load_quality_certs.issued_at is
  'The day the certificate is issued, on the pit clock (ml_today). It is quoted '
  'on the certificate and feeds payable-tonnage disputes.';
