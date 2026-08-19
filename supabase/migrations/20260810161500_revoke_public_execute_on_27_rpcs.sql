-- Release v1.0 hardening — P3-01 (corrected).
--
-- The previous migration (20260810160000) revoked EXECUTE from `anon`, which
-- was a no-op: the grant on these 27 functions is held by PUBLIC, and `anon`
-- inherits from PUBLIC. Verified via pg_proc.proacl — every one showed
-- `{=X/postgres,...}`, where the empty grantee is PUBLIC.
--
-- Revoke from PUBLIC and grant explicitly to `authenticated`, which is the
-- pattern the other 178 functions in this schema already follow (they carry
-- no PUBLIC grant). No behavioural change for any signed-in user; the only
-- effect is that these RPCs stop being reachable over /rest/v1/rpc/* without
-- a session.
--
-- Note: `raise_recon_dispute` held ONLY the PUBLIC grant, so the explicit
-- grant to `authenticated` is load-bearing, not redundant.
--
-- The 27 functions, for the record:
--   add_recon_dispute_comment, check_email_registered,
--   delete_compliance_document, delete_fuel_entry,
--   delete_my_compliance_document, delete_operating_cost,
--   get_profile_setup, get_runtime_platform_status, list_available_routes,
--   list_compliance_documents, list_fuel_entries, list_operating_costs,
--   list_recon_dispute_comments, list_recon_disputes,
--   list_transporter_trip_earnings, list_transporter_trip_pnl,
--   list_transporter_vehicle_cost_breakdown, list_transporter_vehicle_costs,
--   log_fuel_entry, log_operating_cost, raise_recon_dispute,
--   set_recon_dispute_status, set_route_transit_expectation,
--   update_my_company_profile, update_my_employee_profile,
--   upsert_compliance_document, upsert_my_compliance_document
--
-- Written self-targeting rather than as 54 literal statements so the applied
-- state provably matches this file, and so re-running it is a no-op. The
-- count assertion is the guard: if the set ever differs from 27, this fails
-- loudly rather than silently locking down something unintended.

do $$
declare r record; n int := 0;
begin
  for r in
    select p.oid::regprocedure::text as sig
    from pg_proc p
    join pg_namespace nsp on nsp.oid = p.pronamespace
    where nsp.nspname = 'public'
      and p.prokind = 'f'
      and p.proacl::text like '{=X/%'
    order by p.proname
  loop
    execute format('revoke execute on function %s from public', r.sig);
    execute format('grant execute on function %s to authenticated', r.sig);
    n := n + 1;
  end loop;
  raise notice 'locked down % functions', n;
  if n <> 27 then
    raise exception 'expected 27 PUBLIC-granted functions, found %', n;
  end if;
end $$;
