-- Targets: the SELECT grant realtime needs (2026-08-08).
--
-- `20260808120000_targets_and_cycles.sql` created both tables, enabled RLS and
-- wrote SELECT policies — but this project does not grant table privileges to
-- `authenticated` by default, so neither table had a SELECT privilege at all.
--
-- That is not just "reads fail". Realtime evaluates its row filter AS THE
-- SUBSCRIBING ROLE, so the publication would have been live and completely
-- silent: subscribed, connected, delivering nothing, with no error anywhere.
-- Found by checking information_schema.role_table_grants after applying, not
-- by anything failing.
--
-- SELECT only. There is deliberately no INSERT / UPDATE / DELETE grant and no
-- write policy, so a direct PostgREST write is refused for want of a privilege
-- before RLS or the closed-month / locked-cycle triggers are even consulted.
-- The SECURITY DEFINER RPCs remain the only way in.
--
-- Split out of the tables migration into its own file because it went to the
-- database as its own migration; one file, one applied migration, so a reset
-- from git reproduces the same ledger. Ordering against
-- `20260808140000_targets_scope_rule.sql` is immaterial — that one only writes
-- comments and pins search_path.

begin;

grant select on public.monthly_targets to authenticated;
grant select on public.target_cycles to authenticated;

commit;
