-- Targets: short-term monthly goals + long-term 12-month horizon cycles.
--
-- Two systems, three scopes, one table pair:
--
--   SHORT TERM  one target per calendar month. Editable while the month is
--               open; immutable the moment it closes.
--   LONG TERM   six horizon targets (7d / 14d / 1m / 3m / 6m / 12m) committed
--               together as a 12-month cycle, immutable for the full 365 days.
--
--   SCOPES      'platform'  the whole network, one set of targets
--               'org_type'  one set per org type (mineSupplier / buyer /
--                           transporter)
--               'company'   one set per company
--
-- The locks are enforced HERE, not in Flutter. The screen refuses to write a
-- closed month or a locked cycle, but a client-side guard is a courtesy —
-- anyone holding the publishable key can call the API directly. Every write
-- path goes through a SECURITY DEFINER RPC (direct table writes are RLS-denied)
-- and the triggers below fire regardless of who is calling, definer included.
--
-- Actuals are never stored for an open cycle: they are computed from
-- trips.net_tons (the weighbridge Net = Gross − Tare, the authoritative figure
-- for recon and billing) on every read. They ARE frozen into target_cycles.
-- actuals at close, so a closed cycle's record cannot change because someone
-- corrected a waybill eighteen months later.

begin;

-- ===========================================================================
-- 1. Tables
-- ===========================================================================

create table if not exists public.monthly_targets (
  id          uuid primary key default gen_random_uuid(),
  scope       text not null check (scope in ('platform', 'org_type', 'company')),
  org_type    text check (org_type in ('mineSupplier', 'buyer', 'transporter')),
  company_id  uuid references public.companies (id) on delete cascade,
  period      text not null check (period ~ '^\d{4}-(0[1-9]|1[0-2])$'),
  target_tons numeric not null default 0 check (target_tons >= 0),
  created_by  uuid references auth.users (id) on delete set null,
  updated_by  uuid references auth.users (id) on delete set null,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  -- The scope key columns are mutually exclusive: exactly the one that scope
  -- names is populated. Without this a row could claim 'platform' and still
  -- carry a company_id, and the partial unique indexes below would not catch it.
  constraint monthly_targets_scope_key check (
    (scope = 'platform' and org_type is null and company_id is null)
    or (scope = 'org_type' and org_type is not null and company_id is null)
    or (scope = 'company' and org_type is null and company_id is not null)
  )
);

-- One target per period per scope. Partial rather than a plain unique tuple:
-- NULLs are distinct in a Postgres unique index, so `unique (org_type,
-- company_id, period)` would happily accept the same platform month twice.
create unique index if not exists monthly_targets_platform_uk
  on public.monthly_targets (period) where scope = 'platform';
create unique index if not exists monthly_targets_org_type_uk
  on public.monthly_targets (org_type, period) where scope = 'org_type';
create unique index if not exists monthly_targets_company_uk
  on public.monthly_targets (company_id, period) where scope = 'company';

create table if not exists public.target_cycles (
  id          uuid primary key default gen_random_uuid(),
  scope       text not null check (scope in ('platform', 'org_type', 'company')),
  org_type    text check (org_type in ('mineSupplier', 'buyer', 'transporter')),
  company_id  uuid references public.companies (id) on delete cascade,
  label       text not null,
  status      text not null check (status in ('draft', 'locked', 'closed')),
  started_on  date not null,
  locked_at   timestamptz,
  closed_at   timestamptz,
  targets     jsonb not null default '{}'::jsonb,   -- committed
  draft       jsonb not null default '{}'::jsonb,   -- pre-commit
  actuals     jsonb,                                -- frozen at close
  created_by  uuid references auth.users (id) on delete set null,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  constraint target_cycles_scope_key check (
    (scope = 'platform' and org_type is null and company_id is null)
    or (scope = 'org_type' and org_type is not null and company_id is null)
    or (scope = 'company' and org_type is null and company_id is not null)
  ),
  -- The client counts elapsed days as "calendar days since the first month
  -- shown", and the first month shown is the cycle's start month. That only
  -- lines up if a cycle starts on the 1st.
  constraint target_cycles_starts_on_first check (extract(day from started_on) = 1)
);

create unique index if not exists target_cycles_open_platform_uk
  on public.target_cycles (scope)
  where scope = 'platform' and status in ('draft', 'locked');
create unique index if not exists target_cycles_open_org_type_uk
  on public.target_cycles (org_type)
  where scope = 'org_type' and status in ('draft', 'locked');
create unique index if not exists target_cycles_open_company_uk
  on public.target_cycles (company_id)
  where scope = 'company' and status in ('draft', 'locked');

create index if not exists target_cycles_scope_idx
  on public.target_cycles (scope, org_type, company_id, started_on desc);

-- ===========================================================================
-- 2. The locks — server-side, non-negotiable
-- ===========================================================================

-- A closed month's target cannot be changed, and one cannot be created after
-- the fact either: "there was no target" and "the target was X" are different
-- claims about a month that has already been reported on.
create or replace function public.guard_monthly_target()
returns trigger
language plpgsql
set search_path = public
as $$
declare
  v_period text := coalesce(new.period, old.period);
begin
  if to_date(v_period, 'YYYY-MM') < date_trunc('month', current_date) then
    raise exception
      'Target for % is closed and cannot be %', v_period,
      case tg_op when 'INSERT' then 'created' else 'changed' end
      using errcode = 'check_violation';
  end if;
  if tg_op = 'UPDATE' then
    new.updated_at := now();
  end if;
  return new;
end $$;

drop trigger if exists monthly_targets_guard on public.monthly_targets;
create trigger monthly_targets_guard
  before insert or update on public.monthly_targets
  for each row execute function public.guard_monthly_target();

-- A locked cycle is immutable until it has run its full 12 months. Not
-- "unless the user is an admin", not "unless they confirm twice" — the
-- immobility is the feature. A goal you can revise when you are behind
-- measures nothing.
--
-- Measured from started_on, not locked_at: the client's "days elapsed" counts
-- calendar days since the cycle start, and the two must agree or the screen
-- offers a reopen the server then refuses.
create or replace function public.guard_target_cycle()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if old.status = 'locked' and current_date < old.started_on + interval '1 year' then
    if new.targets is distinct from old.targets
       or new.draft is distinct from old.draft
       or new.status is distinct from old.status
       or new.started_on is distinct from old.started_on then
      raise exception
        'Cycle % is locked until %', old.label,
        to_char(old.started_on + interval '1 year', 'DD Mon YYYY')
        using errcode = 'check_violation';
    end if;
  end if;
  if old.status = 'closed' then
    raise exception 'Cycle % is closed and is a permanent record', old.label
      using errcode = 'check_violation';
  end if;
  new.updated_at := now();
  return new;
end $$;

drop trigger if exists target_cycles_guard on public.target_cycles;
create trigger target_cycles_guard
  before update on public.target_cycles
  for each row execute function public.guard_target_cycle();

-- ===========================================================================
-- 3. RLS — reads are scoped, every write goes through an RPC
-- ===========================================================================

alter table public.monthly_targets enable row level security;
alter table public.target_cycles enable row level security;

drop policy if exists monthly_targets_select on public.monthly_targets;
create policy monthly_targets_select
  on public.monthly_targets for select to authenticated
  using (
    public.is_platform_admin()
    or (scope = 'company' and public.is_company_staff(company_id))
  );

drop policy if exists target_cycles_select on public.target_cycles;
create policy target_cycles_select
  on public.target_cycles for select to authenticated
  using (
    public.is_platform_admin()
    or (scope = 'company' and public.is_company_staff(company_id))
  );

-- No INSERT / UPDATE / DELETE grant and no write policy: a direct PostgREST
-- write is refused for want of a privilege, before RLS or the triggers are
-- even consulted. The SECURITY DEFINER RPCs below are the only way in — and
-- they still fire the triggers.
--
-- The policies above are necessary but NOT sufficient: this project grants no
-- table privileges to `authenticated` by default, so as this migration stands
-- neither table is readable and the realtime publication at the end of it is
-- live and silent. The SELECT grant that fixes it is
-- `20260808150000_targets_realtime_select_grant.sql` — kept there rather than
-- here because that is how it reached the database, and one file per applied
-- migration is what makes a reset from git reproduce this ledger.

-- ===========================================================================
-- 4. Actuals — computed from weighbridge net mass
-- ===========================================================================

-- Does a trip's transaction belong to this scope?
--   platform  every trip
--   org_type  every trip carrying a party of that type
--   company   every trip where this company is the mine, buyer or transporter
--             (a company has one org_type, so this resolves to its own role)
create or replace function public.target_scope_matches(
  p_scope text,
  p_org_type text,
  p_company_id uuid,
  p_supplier uuid,
  p_buyer uuid,
  p_transporter uuid
)
returns boolean
language sql
immutable
as $$
  select case p_scope
    when 'platform' then true
    when 'org_type' then case p_org_type
        when 'transporter' then p_transporter is not null
        when 'buyer' then p_buyer is not null
        when 'mineSupplier' then p_supplier is not null
        else false
      end
    when 'company' then
      coalesce(p_supplier = p_company_id, false)
      or coalesce(p_buyer = p_company_id, false)
      or coalesce(p_transporter = p_company_id, false)
    else false
  end;
$$;

-- Day → tons for a scope over a window, as {'2026-08-01': 129.5, ...}.
--
-- Dated on coalesce(arrived_at, created_at) — the same basis
-- list_raw_recon_rows uses for its DATE column, so the targets screen and the
-- recon table can never disagree about which day a load belongs to.
--
-- Bucketed in UTC deliberately. The recon table's client parses trip_date with
-- DateTime.parse, which keeps the value in UTC, so its day grouping is a UTC
-- day; bucketing here in Africa/Johannesburg would be more natural for the pit
-- but would put a late-evening load in a different day than the recon row it
-- came from. One basis, even if it is the less obvious one.
create or replace function public.target_scope_daily_tons(
  p_scope text,
  p_org_type text,
  p_company_id uuid,
  p_from date,
  p_to date
)
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    jsonb_object_agg(d.day::text, d.tons),
    '{}'::jsonb
  )
  from (
    select
      (coalesce(t.arrived_at, t.created_at) at time zone 'UTC')::date as day,
      sum(coalesce(t.net_tons, 0))::numeric as tons
    from public.trips t
    join public.transactions x on x.id = t.transaction_id
    where coalesce(t.arrived_at, t.created_at) >= p_from::timestamptz
      and coalesce(t.arrived_at, t.created_at) < (p_to + 1)::timestamptz
      and public.target_scope_matches(
            p_scope, p_org_type, p_company_id,
            x.supplier_company_id, x.buyer_company_id, x.transporter_company_id)
    group by 1
  ) d;
$$;

-- Per-month trip and waybill counts, as {'2026-08': {"trips":12,...}, ...}.
-- Waybill open/closed follows the definition the rest of the console already
-- uses (transactions.status = 'completed'), so the numbers agree with the
-- monthly insights bundle rather than inventing a second truth.
create or replace function public.target_scope_month_counts(
  p_scope text,
  p_org_type text,
  p_company_id uuid,
  p_from date,
  p_to date
)
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  with trip_counts as (
    select
      to_char(coalesce(t.arrived_at, t.created_at), 'YYYY-MM') as period,
      count(*)::int as trips
    from public.trips t
    join public.transactions x on x.id = t.transaction_id
    where coalesce(t.arrived_at, t.created_at) >= p_from::timestamptz
      and coalesce(t.arrived_at, t.created_at) < (p_to + 1)::timestamptz
      and public.target_scope_matches(
            p_scope, p_org_type, p_company_id,
            x.supplier_company_id, x.buyer_company_id, x.transporter_company_id)
    group by 1
  ),
  waybill_counts as (
    select
      to_char(x.updated_at, 'YYYY-MM') as period,
      count(*) filter (
        where lower(trim(coalesce(x.status, ''))) = 'completed')::int as done,
      count(*) filter (
        where lower(trim(coalesce(x.status, ''))) is distinct from 'completed')::int as open
    from public.transactions x
    where x.updated_at >= p_from::timestamptz
      and x.updated_at < (p_to + 1)::timestamptz
      and public.target_scope_matches(
            p_scope, p_org_type, p_company_id,
            x.supplier_company_id, x.buyer_company_id, x.transporter_company_id)
    group by 1
  )
  select coalesce(
    jsonb_object_agg(
      p.period,
      jsonb_build_object(
        'trips', coalesce(tc.trips, 0),
        'waybills_done', coalesce(wc.done, 0),
        'waybills_open', coalesce(wc.open, 0)
      )
    ),
    '{}'::jsonb
  )
  from (
    select period from trip_counts
    union
    select period from waybill_counts
  ) p
  left join trip_counts tc on tc.period = p.period
  left join waybill_counts wc on wc.period = p.period;
$$;

-- ===========================================================================
-- 5. Scope plumbing
-- ===========================================================================

create or replace function public.assert_target_scope(
  p_scope text,
  p_org_type text,
  p_company_id uuid
)
returns void
language plpgsql
stable
set search_path = public
as $$
begin
  if not public.is_super_admin() then
    raise exception 'forbidden' using errcode = 'insufficient_privilege';
  end if;
  if p_scope = 'platform' then
    if p_org_type is not null or p_company_id is not null then
      raise exception 'platform scope takes no key';
    end if;
  elsif p_scope = 'org_type' then
    if p_org_type !~ '^(mineSupplier|buyer|transporter)$' then
      raise exception 'invalid org type %', coalesce(p_org_type, 'null');
    end if;
    if p_company_id is not null then
      raise exception 'org_type scope takes no company';
    end if;
  elsif p_scope = 'company' then
    if p_company_id is null then
      raise exception 'company scope needs a company';
    end if;
    if not exists (select 1 from public.companies where id = p_company_id) then
      raise exception 'unknown company %', p_company_id;
    end if;
    if p_org_type is not null then
      raise exception 'company scope takes no org type';
    end if;
  else
    raise exception 'invalid scope %', coalesce(p_scope, 'null');
  end if;
end $$;

create or replace function public.target_cycle_label(p_start date)
returns text
language sql
immutable
as $$
  select to_char(p_start, 'Mon YYYY') || ' → '
       || to_char(p_start + interval '11 months', 'Mon YYYY');
$$;

-- The open cycle for a scope, minted as a draft starting this month if there
-- isn't one. A brand-new cycle starts at the current month rather than at the
-- earliest trip on record: the client measures elapsed days as "days since the
-- first month shown", so back-dating the start would make a fresh draft read
-- as already complete.
create or replace function public.ensure_open_target_cycle(
  p_scope text,
  p_org_type text,
  p_company_id uuid
)
returns public.target_cycles
language plpgsql
security definer
set search_path = public
as $$
declare
  v_cycle public.target_cycles;
  v_start date := date_trunc('month', current_date)::date;
begin
  select * into v_cycle
  from public.target_cycles
  where scope = p_scope
    and org_type is not distinct from p_org_type
    and company_id is not distinct from p_company_id
    and status in ('draft', 'locked')
  order by started_on desc
  limit 1;

  if found then
    return v_cycle;
  end if;

  insert into public.target_cycles (
    scope, org_type, company_id, label, status, started_on, created_by
  )
  values (
    p_scope, p_org_type, p_company_id,
    public.target_cycle_label(v_start), 'draft', v_start, auth.uid()
  )
  returning * into v_cycle;

  return v_cycle;
end $$;

-- ===========================================================================
-- 6. Read — the whole targets picture in one payload
-- ===========================================================================

-- Months run from the cycle's start month through p_planned_months beyond the
-- current one. Every month up to today carries a `daily` array with one entry
-- per calendar day, zeros included — "no trips that day" and "no data" are
-- different things and the charts draw them differently. Planned months carry
-- an empty array, which is what makes them planned.
create or replace function public.get_targets_state(
  p_scope text default 'platform',
  p_org_type text default null,
  p_company_id uuid default null,
  p_planned_months int default 6
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_cycle public.target_cycles;
  v_first date;
  v_this_month date := date_trunc('month', current_date)::date;
  v_last date;
  v_days jsonb;
  v_counts jsonb;
  v_targets jsonb;
  v_months jsonb := '[]'::jsonb;
  v_past jsonb := '[]'::jsonb;
  m date;
  v_dim int;
  v_n int;
  v_daily jsonb;
  v_period text;
  v_count jsonb;
  i int;
begin
  perform public.assert_target_scope(p_scope, p_org_type, p_company_id);

  v_cycle := public.ensure_open_target_cycle(p_scope, p_org_type, p_company_id);

  v_first := date_trunc('month', v_cycle.started_on)::date;
  v_last := (date_trunc('month', current_date)
             + make_interval(months => greatest(p_planned_months, 0)))::date;

  v_days := public.target_scope_daily_tons(
    p_scope, p_org_type, p_company_id, v_first,
    least(current_date, (v_last + interval '1 month - 1 day')::date));
  v_counts := public.target_scope_month_counts(
    p_scope, p_org_type, p_company_id, v_first, current_date);

  select coalesce(jsonb_object_agg(period, target_tons), '{}'::jsonb)
  into v_targets
  from public.monthly_targets
  where scope = p_scope
    and org_type is not distinct from p_org_type
    and company_id is not distinct from p_company_id;

  m := v_first;
  while m <= v_last loop
    v_dim := extract(day from (m + interval '1 month - 1 day'))::int;
    v_period := to_char(m, 'YYYY-MM');

    if m < v_this_month then
      v_n := v_dim;                                  -- closed month, full
    elsif m = v_this_month then
      v_n := extract(day from current_date)::int;    -- current month, to date
    else
      v_n := 0;                                      -- planned, no actuals
    end if;

    v_daily := '[]'::jsonb;
    i := 1;
    while i <= v_n loop
      v_daily := v_daily || to_jsonb(
        coalesce((v_days ->> (m + make_interval(days => i - 1))::date::text)::numeric, 0));
      i := i + 1;
    end loop;

    v_count := coalesce(v_counts -> v_period, '{}'::jsonb);

    v_months := v_months || jsonb_build_array(jsonb_build_object(
      'year', extract(year from m)::int,
      'month', extract(month from m)::int,
      'period', v_period,
      'days_in_month', v_dim,
      'daily', v_daily,
      'target', coalesce((v_targets ->> v_period)::numeric, 0),
      'trips', coalesce((v_count ->> 'trips')::int, 0),
      'waybills_done', coalesce((v_count ->> 'waybills_done')::int, 0),
      'waybills_open', coalesce((v_count ->> 'waybills_open')::int, 0)
    ));

    m := (m + interval '1 month')::date;
  end loop;

  select coalesce(jsonb_agg(jsonb_build_object(
           'id', c.id,
           'label', c.label,
           'targets', c.targets,
           'actuals', coalesce(c.actuals, '{}'::jsonb),
           'closed_at', c.closed_at
         ) order by c.started_on desc), '[]'::jsonb)
  into v_past
  from public.target_cycles c
  where c.scope = p_scope
    and c.org_type is not distinct from p_org_type
    and c.company_id is not distinct from p_company_id
    and c.status = 'closed';

  return jsonb_build_object(
    'scope', jsonb_build_object(
      'scope', p_scope, 'org_type', p_org_type, 'company_id', p_company_id),
    'months', v_months,
    'cycle', jsonb_build_object(
      'id', v_cycle.id,
      'label', v_cycle.label,
      'status', v_cycle.status,
      'targets', v_cycle.targets,
      'draft', v_cycle.draft,
      'started_on', v_cycle.started_on,
      'locked_at', v_cycle.locked_at
    ),
    'past_cycles', v_past,
    'as_of', current_date
  );
end $$;

-- ===========================================================================
-- 7. Writes
-- ===========================================================================

create or replace function public.set_monthly_target(
  p_scope text,
  p_org_type text,
  p_company_id uuid,
  p_period text,
  p_tons numeric
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public.assert_target_scope(p_scope, p_org_type, p_company_id);

  if p_period !~ '^\d{4}-(0[1-9]|1[0-2])$' then
    raise exception 'invalid period %', coalesce(p_period, 'null');
  end if;
  if p_tons is null or p_tons < 0 then
    raise exception 'target must be zero or more';
  end if;
  -- The trigger enforces this too; checked here so the caller gets the reason
  -- rather than a constraint name.
  if to_date(p_period, 'YYYY-MM') < date_trunc('month', current_date) then
    raise exception 'Target for % is closed and cannot be changed', p_period
      using errcode = 'check_violation';
  end if;

  -- Update-then-insert rather than ON CONFLICT: the uniqueness that matters
  -- here lives in three *partial* indexes chosen by scope at runtime, and a
  -- conflict target has to be named statically. The retry closes the race
  -- between two admins setting the same month at the same moment.
  update public.monthly_targets
  set target_tons = p_tons,
      updated_by = auth.uid()
  where scope = p_scope
    and org_type is not distinct from p_org_type
    and company_id is not distinct from p_company_id
    and period = p_period;

  if not found then
    begin
      insert into public.monthly_targets (
        scope, org_type, company_id, period, target_tons, created_by, updated_by
      )
      values (
        p_scope, p_org_type, p_company_id, p_period, p_tons, auth.uid(), auth.uid()
      );
    exception when unique_violation then
      update public.monthly_targets
      set target_tons = p_tons,
          updated_by = auth.uid()
      where scope = p_scope
        and org_type is not distinct from p_org_type
        and company_id is not distinct from p_company_id
        and period = p_period;
    end;
  end if;
end $$;

create or replace function public.set_cycle_draft(
  p_scope text,
  p_org_type text,
  p_company_id uuid,
  p_horizon text,
  p_tons numeric
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_cycle public.target_cycles;
begin
  perform public.assert_target_scope(p_scope, p_org_type, p_company_id);

  if p_horizon !~ '^(d7|d14|m1|m3|m6|m12)$' then
    raise exception 'unknown horizon %', coalesce(p_horizon, 'null');
  end if;
  if p_tons is null or p_tons < 0 then
    raise exception 'target must be zero or more';
  end if;

  v_cycle := public.ensure_open_target_cycle(p_scope, p_org_type, p_company_id);

  if v_cycle.status <> 'draft' then
    raise exception 'Cycle % is locked until %', v_cycle.label,
      to_char(v_cycle.started_on + interval '1 year', 'DD Mon YYYY')
      using errcode = 'check_violation';
  end if;

  update public.target_cycles
  set draft = draft || jsonb_build_object(p_horizon, p_tons)
  where id = v_cycle.id;
end $$;

create or replace function public.lock_target_cycle(
  p_scope text,
  p_org_type text,
  p_company_id uuid,
  p_targets jsonb
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_cycle public.target_cycles;
  v_key text;
  v_val numeric;
begin
  perform public.assert_target_scope(p_scope, p_org_type, p_company_id);

  v_cycle := public.ensure_open_target_cycle(p_scope, p_org_type, p_company_id);

  if v_cycle.status <> 'draft' then
    raise exception 'Cycle % is already locked', v_cycle.label
      using errcode = 'check_violation';
  end if;

  -- All six or none. An unset horizon would read as a missed one for the
  -- following twelve months, which is worse than refusing the lock.
  foreach v_key in array array['d7', 'd14', 'm1', 'm3', 'm6', 'm12'] loop
    v_val := (p_targets ->> v_key)::numeric;
    if v_val is null or v_val <= 0 then
      raise exception 'Horizon % has no target — all six must be set before locking', v_key
        using errcode = 'check_violation';
    end if;
  end loop;

  update public.target_cycles
  set targets = p_targets,
      draft = p_targets,
      status = 'locked',
      locked_at = now()
  where id = v_cycle.id;
end $$;

-- Closes the current cycle (freezing its actuals as they stand) and opens the
-- next one. Only possible once the full 12 months have run.
create or replace function public.start_new_target_cycle(
  p_scope text,
  p_org_type text,
  p_company_id uuid
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_cycle public.target_cycles;
  v_next date;
begin
  perform public.assert_target_scope(p_scope, p_org_type, p_company_id);

  v_cycle := public.ensure_open_target_cycle(p_scope, p_org_type, p_company_id);

  if current_date < v_cycle.started_on + interval '1 year' then
    raise exception 'Cycle % has not run its 12 months yet — it closes on %',
      v_cycle.label,
      to_char(v_cycle.started_on + interval '1 year', 'DD Mon YYYY')
      using errcode = 'check_violation';
  end if;

  perform public.close_target_cycle(v_cycle.id);

  v_next := (v_cycle.started_on + interval '1 year')::date;
  insert into public.target_cycles (
    scope, org_type, company_id, label, status, started_on, created_by
  )
  values (
    p_scope, p_org_type, p_company_id,
    public.target_cycle_label(v_next), 'draft', v_next, auth.uid()
  );
end $$;

-- ===========================================================================
-- 8. Close — freeze the record, then tell somebody
-- ===========================================================================

create or replace function public.close_target_cycle(p_cycle_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_cycle public.target_cycles;
  v_days jsonb;
  v_actuals jsonb := '{}'::jsonb;
  v_end date;
  v_horizon record;
  v_sum numeric;
  d date;
begin
  select * into v_cycle from public.target_cycles where id = p_cycle_id;
  if not found or v_cycle.status = 'closed' then
    return;
  end if;

  v_end := least(current_date, (v_cycle.started_on + interval '1 year - 1 day')::date);
  v_days := public.target_scope_daily_tons(
    v_cycle.scope, v_cycle.org_type, v_cycle.company_id, v_cycle.started_on, v_end);

  -- Cumulative tonnage at each checkpoint, recorded as it stands right now.
  -- After this the numbers are a record, not a query.
  for v_horizon in
    select * from (values ('d7', 7), ('d14', 14), ('m1', 30),
                          ('m3', 90), ('m6', 180), ('m12', 365)) as h(key, days)
  loop
    v_sum := 0;
    d := v_cycle.started_on;
    while d < v_cycle.started_on + make_interval(days => v_horizon.days) loop
      v_sum := v_sum + coalesce((v_days ->> d::text)::numeric, 0);
      d := d + 1;
    end loop;
    v_actuals := v_actuals || jsonb_build_object(v_horizon.key, v_sum);
  end loop;

  update public.target_cycles
  set status = 'closed',
      closed_at = now(),
      actuals = v_actuals
  where id = p_cycle_id;
end $$;

-- Daily sweep: close any cycle that has run its 365 days and tell the people
-- who set it. The in-screen banner works on its own, but nobody watching the
-- console every day is how a cycle quietly rolls over unnoticed.
create or replace function public.close_due_target_cycles_job()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_cycle record;
  v_admin record;
  v_label text;
begin
  for v_cycle in
    select * from public.target_cycles
    where status = 'locked'
      and current_date >= started_on + interval '1 year'
  loop
    perform public.close_target_cycle(v_cycle.id);

    v_label := case v_cycle.scope
      when 'platform' then 'the platform'
      when 'org_type' then v_cycle.org_type
      else coalesce(
        (select company_name from public.companies where id = v_cycle.company_id),
        'a company')
    end;

    for v_admin in
      select id from public.profiles
      where platform_role in (
        'superGlobalSerialAdminMain', 'superGlobalSerialAdminMainChild')
    loop
      perform public.create_notification_internal(
        v_admin.id, null, null,
        'Target cycle closed',
        v_cycle.label || ' has run its full 365 days for ' || v_label
          || '. Review how the six horizon goals landed and set the next cycle.',
        'target_cycle_closed',
        null, null, null, null, 'high',
        jsonb_build_object(
          'cycle_id', v_cycle.id,
          'scope', v_cycle.scope,
          'org_type', v_cycle.org_type,
          'company_id', v_cycle.company_id)
      );
    end loop;

    -- A company's own management hears about their own cycle too.
    if v_cycle.scope = 'company' then
      perform public.notify_company_role(
        v_cycle.company_id,
        array['admin', 'management'],
        'Target cycle closed',
        v_cycle.label || ' has run its full 365 days.',
        'target_cycle_closed',
        null, 'high',
        jsonb_build_object('cycle_id', v_cycle.id),
        true
      );
    end if;
  end loop;
end $$;

-- ===========================================================================
-- 9. Grants
-- ===========================================================================

do $$
declare
  fn text;
begin
  foreach fn in array array[
    'public.get_targets_state(text, text, uuid, int)',
    'public.set_monthly_target(text, text, uuid, text, numeric)',
    'public.set_cycle_draft(text, text, uuid, text, numeric)',
    'public.lock_target_cycle(text, text, uuid, jsonb)',
    'public.start_new_target_cycle(text, text, uuid)'
  ] loop
    execute format('revoke all on function %s from public', fn);
    execute format('revoke all on function %s from anon', fn);
    execute format('grant execute on function %s to authenticated', fn);
  end loop;
end $$;

-- Internals: definer-only, never reachable from a client session.
revoke all on function public.close_target_cycle(uuid) from public, anon, authenticated;
revoke all on function public.close_due_target_cycles_job() from public, anon, authenticated;
revoke all on function public.ensure_open_target_cycle(text, text, uuid) from public, anon, authenticated;
revoke all on function public.target_scope_daily_tons(text, text, uuid, date, date) from public, anon, authenticated;
revoke all on function public.target_scope_month_counts(text, text, uuid, date, date) from public, anon, authenticated;

-- ===========================================================================
-- 10. Realtime
-- ===========================================================================

do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public' and tablename = 'monthly_targets'
  ) then
    alter publication supabase_realtime add table public.monthly_targets;
  end if;
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public' and tablename = 'target_cycles'
  ) then
    alter publication supabase_realtime add table public.target_cycles;
  end if;
exception when undefined_object or insufficient_privilege then null;
end $$;

-- Realtime only delivers rows the subscriber may SELECT, and both policies
-- above are restrictive, so REPLICA IDENTITY FULL is what lets the row filter
-- see the columns it needs on UPDATE and DELETE.
alter table public.monthly_targets replica identity full;
alter table public.target_cycles replica identity full;

-- ===========================================================================
-- 11. Schedule
-- ===========================================================================

do $$
begin
  if not exists (select 1 from cron.job where jobname = 'close-due-target-cycles') then
    perform cron.schedule('close-due-target-cycles', '20 3 * * *',
      'select public.close_due_target_cycles_job()');
  end if;
exception when undefined_table or insufficient_privilege or invalid_schema_name then null;
end $$;

commit;
