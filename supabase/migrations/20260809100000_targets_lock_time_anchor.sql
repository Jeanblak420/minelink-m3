-- Targets: anchor the twelve months at the commitment, not at a page view.
-- 2026-08-09.
--
-- THE DEFECT
-- `started_on` was set when a draft was minted, and a draft was minted by
-- `get_targets_state` — a read. So the length of a twelve-month commitment
-- depended on when somebody first opened the screen:
--
--   minted 2026-08-01, locked 2026-08-09  ->  357 days   screen said 12 months
--   minted 2026-08-01, locked 2027-01-15  ->  198 days   screen said 12 months
--   minted 2026-08-01, locked 2027-07-31  ->    1 day    screen said 12 months
--   minted 2026-08-01, locked 2027-08-02  ->  NO LOCK AT ALL
--
-- The last line is the one that decided it. The guard tested
-- `current_date < started_on + interval '1 year'`; once false it never fired
-- again, so a stale draft could be "locked" into an already-open state and the
-- immobility — the entire feature — silently would not exist.
--
-- THE FIX: one column, one meaning
-- `started_on` is NULL on a draft and set by `lock_target_cycle` to the 1st of
-- the FOLLOWING month. Everything downstream — horizons, cumulative tonnage,
-- the reopen date, the cron, the client — keeps reading that single column, so
-- there is nothing to keep in step.
--
-- The alternative considered was a second `locked_on` column with the guard on
-- `greatest(started_on, locked_on)`. Rejected: it splits one idea across five
-- consumers that must agree forever, and it fails concretely. A cycle minted
-- Aug and locked Jan finishes measuring the following Aug — the client's
-- `cycleComplete` fires and the banner offers a new cycle — while the guard
-- refuses until Jan. Worse, `close_due_target_cycles_job` keys off
-- `started_on`, so its UPDATE would hit the guard, and that exception
-- propagates out of the loop: one stuck cycle freezes the nightly close for
-- every other scope.
--
-- The 1st of the FOLLOWING month, not the current one: back-dating would mean
-- the d7 and d14 checkpoints had already passed at the instant of commitment,
-- so the first two horizons would be judged on tonnage that moved before
-- anyone agreed to the target. That is a backdated score, not a commitment.
--
-- ALSO IN HERE
--   * A locked cycle's targets become permanently immutable. Previously the
--     guard stopped firing at the anniversary, leaving a committed record
--     editable in place. The only transition out of `locked` is now `closed`.
--   * `get_targets_state` no longer writes. It synthesises an unstarted draft
--     in its return value; the row appears on the first real write.
--   * The months window is decoupled from the cycle. It has to be: with
--     `started_on` now possibly in the FUTURE, anchoring months there would
--     hide the current month — the one with actuals — the moment a cycle was
--     locked. As a side effect this is also the rollover fix, since history is
--     no longer trimmed to the current cycle.
--   * The four drafts already carrying `started_on = 2026-08-01` from page
--     views are nulled. Nothing is locked and no targets are set, so it costs
--     nothing today and could not be done cheaply later.

begin;

-- ===========================================================================
-- 1. started_on becomes nullable
-- ===========================================================================

alter table public.target_cycles alter column started_on drop not null;

alter table public.target_cycles drop constraint if exists target_cycles_starts_on_first;
alter table public.target_cycles add constraint target_cycles_starts_on_first
  check (started_on is null or extract(day from started_on) = 1);

-- Page-view anchors. No cycle is locked and no target is set, so these carry
-- no meaning worth keeping.
update public.target_cycles
set started_on = null, label = 'Not started'
where status = 'draft' and started_on is not null;

comment on column public.target_cycles.started_on is
  'The date the commitment runs from. NULL until the cycle is locked — a draft '
  'has not started, and must not show progress against targets nobody has '
  'committed to. lock_target_cycle sets it to the 1st of the month FOLLOWING '
  'the lock, so the d7/d14 checkpoints are never judged on tonnage that moved '
  'before the target existed. Everything measures from here: horizons, '
  'cumulative tonnage, the reopen date (started_on + 1 year, in both the guard '
  'and close_due_target_cycles_job) and the client. One column, one meaning — '
  'there is deliberately no second lock date to keep in step.';

-- ===========================================================================
-- 2. The guard: a committed cycle is a record, not a document
-- ===========================================================================

create or replace function public.guard_target_cycle()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if old.status = 'closed' then
    raise exception 'Cycle % is closed and is a permanent record', old.label
      using errcode = 'check_violation';
  end if;

  if old.status = 'locked' then
    -- Immutable for good, not merely until the anniversary. The previous
    -- version stopped firing once the year was up, which left what had been
    -- committed editable in place for however long it took the nightly job to
    -- close it. Reopening means starting a NEW cycle, never editing the old.
    if new.targets is distinct from old.targets
       or new.draft is distinct from old.draft
       or new.started_on is distinct from old.started_on then
      raise exception
        'Cycle % is locked — what was committed is the record and cannot be changed',
        old.label using errcode = 'check_violation';
    end if;

    if new.status is distinct from old.status then
      if new.status <> 'closed' then
        raise exception 'A locked cycle can only be closed, not set to %', new.status
          using errcode = 'check_violation';
      end if;
      if old.started_on is null
         or current_date < old.started_on + interval '1 year' then
        raise exception 'Cycle % is locked until %', old.label,
          coalesce(to_char(old.started_on + interval '1 year', 'DD Mon YYYY'),
                   'it has a start date')
          using errcode = 'check_violation';
      end if;
    end if;
  end if;

  new.updated_at := now();
  return new;
end $$;

-- ===========================================================================
-- 3. Minting: no start date, and never from a read
-- ===========================================================================

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
begin
  select * into v_cycle
  from public.target_cycles
  where scope = p_scope
    and org_type is not distinct from p_org_type
    and company_id is not distinct from p_company_id
    and status in ('draft', 'locked')
  order by created_at desc
  limit 1;

  if found then
    return v_cycle;
  end if;

  -- No started_on: a draft has not started. The label is set at lock, when
  -- there is finally a date to name it after.
  insert into public.target_cycles (
    scope, org_type, company_id, label, status, created_by
  )
  values (p_scope, p_org_type, p_company_id, 'Not started', 'draft', auth.uid())
  returning * into v_cycle;

  return v_cycle;
end $$;

-- ===========================================================================
-- 4. Locking: this is where the twelve months begin
-- ===========================================================================

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
  v_start date := (date_trunc('month', current_date) + interval '1 month')::date;
begin
  perform public.assert_target_scope(p_scope, p_org_type, p_company_id);

  v_cycle := public.ensure_open_target_cycle(p_scope, p_org_type, p_company_id);

  if v_cycle.status <> 'draft' then
    raise exception 'Cycle % is already locked', v_cycle.label
      using errcode = 'check_violation';
  end if;

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
      locked_at = now(),
      started_on = v_start,
      label = public.target_cycle_label(v_start)
  where id = v_cycle.id;
end $$;

-- ===========================================================================
-- 5. Closing and reopening
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

  -- A cycle that never started has no record to freeze.
  if v_cycle.started_on is null then
    return;
  end if;

  v_end := least(current_date, (v_cycle.started_on + interval '1 year - 1 day')::date);
  v_days := public.target_scope_daily_tons(
    v_cycle.scope, v_cycle.org_type, v_cycle.company_id, v_cycle.started_on, v_end);

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

  -- An unlocked draft has nothing to close and nothing to succeed. Without
  -- this, a null started_on made the comparison below NULL and the whole
  -- guard fell open.
  if v_cycle.status <> 'locked' or v_cycle.started_on is null then
    raise exception
      'This cycle has not been locked in yet, so there is nothing to close'
      using errcode = 'check_violation';
  end if;

  if current_date < v_cycle.started_on + interval '1 year' then
    raise exception 'Cycle % has not run its 12 months yet — it closes on %',
      v_cycle.label,
      to_char(v_cycle.started_on + interval '1 year', 'DD Mon YYYY')
      using errcode = 'check_violation';
  end if;

  perform public.close_target_cycle(v_cycle.id);

  v_next := (v_cycle.started_on + interval '1 year')::date;
  insert into public.target_cycles (
    scope, org_type, company_id, label, status, started_on, locked_at,
    targets, draft, created_by
  )
  values (
    p_scope, p_org_type, p_company_id,
    public.target_cycle_label(v_next), 'draft', null, null,
    '{}'::jsonb, '{}'::jsonb, auth.uid()
  );
end $$;

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
      and started_on is not null
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
-- 6. The read stops writing
-- ===========================================================================

create or replace function public.get_targets_state(
  p_scope text default 'platform',
  p_org_type text default null,
  p_company_id uuid default null,
  p_planned_months int default 6
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_cycle public.target_cycles;
  v_has_cycle boolean := false;
  v_cycle_json jsonb;
  v_first date;
  v_first_target date;
  v_first_trip date;
  v_floor date := (date_trunc('month', current_date) - interval '24 months')::date;
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

  select * into v_cycle
  from public.target_cycles
  where scope = p_scope
    and org_type is not distinct from p_org_type
    and company_id is not distinct from p_company_id
    and status in ('draft', 'locked')
  order by created_at desc
  limit 1;
  v_has_cycle := found;

  if v_has_cycle then
    v_cycle_json := jsonb_build_object(
      'id', v_cycle.id,
      'label', v_cycle.label,
      'status', v_cycle.status,
      'targets', v_cycle.targets,
      'draft', v_cycle.draft,
      'started_on', v_cycle.started_on,
      'locked_at', v_cycle.locked_at
    );
  else
    -- Synthesised, not persisted. A read that writes is how four rows and four
    -- clocks appeared before anyone had set a single target. The row is minted
    -- by the first real write (set_cycle_draft / lock_target_cycle).
    -- The id is stable so the widget tree has something to key on.
    v_cycle_json := jsonb_build_object(
      'id', case p_scope
              when 'platform' then 'draft:platform'
              when 'org_type' then 'draft:org_type:' || p_org_type
              else 'draft:company:' || p_company_id::text
            end,
      'label', 'Not started',
      'status', 'draft',
      'targets', '{}'::jsonb,
      'draft', '{}'::jsonb,
      'started_on', null,
      'locked_at', null
    );
  end if;

  -- The months window is the SHORT-TERM system's, and it is deliberately
  -- independent of the cycle. Anchoring it to started_on would now hide the
  -- current month the moment a cycle was locked, because started_on is next
  -- month. It also means history survives a cycle rollover.
  select min(to_date(period, 'YYYY-MM')) into v_first_target
  from public.monthly_targets
  where scope = p_scope
    and org_type is not distinct from p_org_type
    and company_id is not distinct from p_company_id;

  select date_trunc('month', min(coalesce(t.arrived_at, t.created_at)))::date
  into v_first_trip
  from public.trips t
  join public.transactions x on x.id = t.transaction_id
  where coalesce(t.arrived_at, t.created_at) >= v_floor::timestamptz
    and public.target_scope_matches(
          p_scope, p_org_type, p_company_id,
          x.supplier_company_id, x.buyer_company_id, x.transporter_company_id);

  v_first := least(
    coalesce(v_first_target, v_this_month),
    coalesce(v_first_trip, v_this_month),
    v_this_month);
  v_first := greatest(v_first, v_floor);

  v_last := (date_trunc('month', current_date)
             + make_interval(months => greatest(p_planned_months, 0)))::date;

  v_days := public.target_scope_daily_tons(
    p_scope, p_org_type, p_company_id, v_first, current_date);
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
      v_n := v_dim;
    elsif m = v_this_month then
      v_n := extract(day from current_date)::int;
    else
      v_n := 0;
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
    'cycle', v_cycle_json,
    'past_cycles', v_past,
    'as_of', current_date
  );
end $$;

commit;
