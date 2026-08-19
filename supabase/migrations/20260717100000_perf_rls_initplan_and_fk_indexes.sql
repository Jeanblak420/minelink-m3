-- Advisor cleanup round 3 (2026-07-17): performance lints.
--
-- 1. auth_rls_initplan (4 WARN): four policies evaluated auth.uid() /
--    subqueries per ROW. Wrapping auth.uid() in a scalar subselect lets the
--    planner evaluate it once per statement (InitPlan). Semantics unchanged —
--    each policy keeps its exact original condition.
-- 2. seat_reassignment_log policies were `to public` (anon, authenticator,
--    dashboard_user … all matched, producing 5 multiple_permissive_policies
--    warnings). Scoped to `to authenticated` — the conditions only ever pass
--    for signed-in users anyway.
-- 3. unindexed_foreign_keys (38 INFO): create a covering index for every
--    remaining FK without one, generated from the catalog so names/columns
--    can't drift.
--
-- Deliberately NOT changed: the ~15 core logistics tables that each carry two
-- permissive SELECT policies (super-admin read + party-scoped read). Merging
-- them into one OR-policy would touch audited RLS on the trip-lifecycle
-- tables for negligible gain at current scale — kept separate on purpose.
-- unused_index INFOs are also left alone: usage stats are not meaningful on a
-- young dev database.

begin;

-- 1a. audit_logs: INSERT policy, per-statement auth.uid() -----------------------
drop policy if exists "Super admins can insert audit logs" on public.audit_logs;
create policy "Super admins can insert audit logs" on public.audit_logs
for insert to authenticated
with check (
  ((select auth.uid()) is not null)
  and ((select p.platform_role from public.profiles p where p.id = (select auth.uid()))
       = any (array['superGlobalSerialAdminMain'::text, 'superGlobalSerialAdminMainChild'::text]))
);

-- 1b + 2. seat_reassignment_log: initplan + role scoping ------------------------
drop policy if exists "Super admins full access to seat_reassignment_log" on public.seat_reassignment_log;
create policy "Super admins full access to seat_reassignment_log" on public.seat_reassignment_log
for all to authenticated
using (
  exists (
    select 1 from public.profiles p
    where p.id = (select auth.uid())
      and p.platform_role = any (array['superGlobalSerialAdminMain'::text, 'superGlobalSerialAdminMainChild'::text])
  )
)
with check (
  exists (
    select 1 from public.profiles p
    where p.id = (select auth.uid())
      and p.platform_role = any (array['superGlobalSerialAdminMain'::text, 'superGlobalSerialAdminMainChild'::text])
  )
);

drop policy if exists "Company owners can read own reassignment logs" on public.seat_reassignment_log;
create policy "Company owners can read own reassignment logs" on public.seat_reassignment_log
for select to authenticated
using (
  exists (
    select 1 from public.companies c
    where c.id = seat_reassignment_log.organization_id
      and c.user_id = (select auth.uid())
  )
);

-- 1c. token_requests: INSERT policy ---------------------------------------------
drop policy if exists token_requests_insert_company_manager on public.token_requests;
create policy token_requests_insert_company_manager on public.token_requests
for insert to authenticated
with check (
  (requested_by_user_id = (select auth.uid()))
  and public.is_company_manager(organization_id)
);

-- 3. Covering indexes for every remaining uncovered FK ---------------------------
do $$
declare
  r record;
begin
  for r in
    select c.conrelid::regclass as tbl,
           regexp_replace(c.conname, '_fkey$', '') || '_idx' as idx_name,
           (select string_agg(quote_ident(a.attname), ', ' order by k.ord)
              from unnest(c.conkey) with ordinality as k(attnum, ord)
              join pg_attribute a on a.attrelid = c.conrelid and a.attnum = k.attnum) as cols
    from pg_constraint c
    join pg_namespace n on n.oid = c.connamespace
    where c.contype = 'f'
      and n.nspname = 'public'
      and not exists (
        select 1 from pg_index i
        where i.indrelid = c.conrelid
          and (string_to_array(i.indkey::text, ' ')::int2[])[1:array_length(c.conkey, 1)] @> c.conkey
          and (string_to_array(i.indkey::text, ' ')::int2[])[1:array_length(c.conkey, 1)] <@ c.conkey
      )
  loop
    execute format('create index if not exists %I on %s (%s)', r.idx_name, r.tbl, r.cols);
  end loop;
end $$;

commit;
