-- S2-10 / G4, third slice: close the RPC half.
--
-- 20260815094000 gated the RLS write policies, but SECURITY DEFINER functions
-- bypass RLS entirely and there are 90 mutating ones executable by
-- `authenticated`, none of which consult company status. CLAUDE.md §6 requires
-- lifecycle mutations to go through exactly those cascade RPCs
-- (record_truck_load, record_pod, set_trip_status, stockpile_add_tons …), so
-- that was where an expired company could still write. Proven: the expired
-- owner of SteelWorks SA reached inside set_notification_read, which failed on
-- its own data check rather than on authorisation.
--
-- A TRIGGER rather than 9 edited function bodies, deliberately:
--   · triggers fire regardless of RLS and regardless of SECURITY DEFINER, so
--     one mechanism covers the RPCs, direct table writes, and anything added
--     later — a new RPC cannot forget to call it;
--   · rewriting nine large function bodies by hand into apply_migration is
--     exactly the silent-drift risk CLAUDE.md §6 warns about.
--
-- It keys on the ACTING USER's company, not on the row's. That is the correct
-- test: a driver at an active transporter recording a POD on a trip whose
-- BUYER has expired must not be blocked — the buyer's lapsed licence is not
-- the driver's problem. Live-verified below.
create or replace function public.guard_company_active()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_company uuid;
begin
  -- System context: pg_cron jobs and migrations run with no JWT. They must
  -- never be blocked — expire_organizations() itself writes through here.
  if auth.uid() is null then
    return new;
  end if;

  -- Platform admins are never restricted (company-mirror observer mode).
  if public.is_platform_admin() then
    return new;
  end if;

  v_company := public.current_company_id();

  -- No company context at all: not this guard's business.
  if v_company is null then
    return new;
  end if;

  if public.is_company_active(v_company) then
    return new;
  end if;

  -- Message is deliberately specific and actionable — it reaches the user
  -- through friendlyError(), and "permission denied" would tell them nothing.
  raise exception
    'TOKEN_EXPIRED: your MineLink token is not active, so this change cannot '
    'be saved. You can still view records, message MineLink, request a '
    'renewal and log a support ticket.'
    using errcode = 'check_violation';
end;
$function$;

comment on function public.guard_company_active() is
  'Refuses an operational write when the ACTING user''s company is not active. '
  'Fires regardless of RLS and of SECURITY DEFINER, so it closes the RPC path '
  'that 20260815094000 could not reach. Exempts system/cron context '
  '(auth.uid() null) and platform admins.';

-- The lifecycle cascade and the operational record it writes.
do $$
declare t text;
begin
  foreach t in array array[
    'trips', 'transactions', 'weighbridge_records', 'stockpiles',
    'stockpile_transactions', 'seal_records', 'pod_uploads',
    'production_entries', 'mineral_loads', 'gate_checks',
    'security_confirmations', 'vehicle_positions', 'reconciliations',
    'load_invoices', 'request_dispatches', 'transportation_requests',
    'haul_routes', 'minerals', 'mine_locations', 'company_locations'
  ]
  loop
    execute format(
      'drop trigger if exists guard_company_active_%1$s on public.%1$I', t);
    execute format(
      'create trigger guard_company_active_%1$s
         before insert or update or delete on public.%1$I
         for each row execute function public.guard_company_active()', t);
  end loop;
end $$;

-- ---------------------------------------------------------------------------
-- VERIFIED ON PRODUCTION, four walks in rolled-back transactions.
--
--   expired owner, via the RPC path that was open:
--     set_trip_status(...)  ->  REFUSED
--                               "TOKEN_EXPIRED: your MineLink token is not
--                                active, so this change cannot be saved…"
--
--   ACTIVE company owner (Cyberhouse Mine Supplier):
--     UPDATE minerals       ->  ALLOWED 1 row — no regression
--
--   SYSTEM context (auth.uid() null, i.e. every pg_cron job):
--     UPDATE trips          ->  ALLOWED — the nightly jobs are not broken
--
--   ACTIVE transporter's manager, on a trip whose BUYER is expired:
--     UPDATE trips          ->  ALLOWED 1 row — somebody else's lapsed
--                               licence does not stop them working
--
-- Note that friendly_error.dart had to learn this shape: the guard raises with
-- errcode `check_violation` (23514), which the existing mapping turned into
-- "that change was refused because it would leave the records inconsistent" —
-- true of a real constraint, and completely wrong here.
