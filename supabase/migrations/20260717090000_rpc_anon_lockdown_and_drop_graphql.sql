-- Advisor cleanup round 2 (2026-07-17): anon RPC lockdown + drop unused GraphQL.
--
-- 1. anon_security_definer_function_executable (104 warnings): every
--    SECURITY DEFINER function in public was executable by `anon` (Postgres
--    grants EXECUTE to PUBLIC by default). The app only calls two RPCs before
--    login — `check_email_registered` (login/forgot-password checks) and
--    `get_runtime_platform_status` (bootstrap) — those keep anon. Everything
--    else: revoke from PUBLIC + anon, and re-grant `authenticated` /
--    `service_role` ONLY where they already had access (privilege state for
--    logged-in clients and edge functions is preserved exactly).
--
-- 2. A small set of provably-internal functions also lose `authenticated`:
--    trigger functions (EXECUTE is never checked when a trigger fires) and
--    pg_cron job bodies + their private _notify helpers (run as postgres, the
--    function owner, so inner calls bypass caller EXECUTE checks). No client
--    should ever invoke these directly.
--
-- 3. Future-proofing: new functions created by postgres in public no longer
--    default to PUBLIC/anon EXECUTE.
--
-- 4. pg_graphql_*_table_exposed (47+ warnings): the app and edge functions
--    contain zero GraphQL usage (verified by grep across lib/ and
--    supabase/functions/) — the GraphQL endpoint was pure attack surface.
--    Drop the extension (reversible with `create extension pg_graphql`).

begin;

-- 1 + 2. Anon lockdown, preserving authenticated/service_role state ----------
do $$
declare
  fn record;
  had_auth boolean;
  had_service boolean;
begin
  for fn in
    select p.oid,
           p.proname,
           pg_get_function_identity_arguments(p.oid) as args,
           p.prorettype = 'pg_catalog.trigger'::regtype as is_trigger
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.prosecdef
      and has_function_privilege('anon', p.oid, 'execute')
      and p.proname not in ('check_email_registered', 'get_runtime_platform_status')
  loop
    had_auth := has_function_privilege('authenticated', fn.oid, 'execute');
    had_service := has_function_privilege('service_role', fn.oid, 'execute');

    execute format('revoke execute on function public.%I(%s) from public', fn.proname, fn.args);
    execute format('revoke execute on function public.%I(%s) from anon', fn.proname, fn.args);

    -- Internal-only functions: triggers (EXECUTE never checked at fire time)
    -- and cron bodies/_notify helpers (run as owner postgres). No client role
    -- needs EXECUTE on these at all.
    if fn.is_trigger
       or fn.proname in ('expire_organizations',
                         'notify_token_expiring_soon_job',
                         '_notify_company_token_managers',
                         '_notify_platform_admins_token') then
      execute format('revoke execute on function public.%I(%s) from authenticated', fn.proname, fn.args);
      continue;
    end if;

    if had_auth then
      execute format('grant execute on function public.%I(%s) to authenticated', fn.proname, fn.args);
    end if;
    if had_service then
      execute format('grant execute on function public.%I(%s) to service_role', fn.proname, fn.args);
    end if;
  end loop;
end $$;

-- 3. New functions no longer default to PUBLIC execute ------------------------
alter default privileges for role postgres in schema public
  revoke execute on functions from public;

-- 4. Drop the unused GraphQL endpoint -----------------------------------------
drop extension if exists pg_graphql;

commit;
