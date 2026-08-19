-- The schema fingerprint could not see a policy's RULE, only its name.
--
-- `schema_fingerprint()` shipped hours earlier (20260818090000) hashing
-- `tablename.policyname:cmd` for the `policies` shape. That is a real hole in
-- the one guard meant to catch out-of-band change: two databases could hold a
-- policy of the same name, on the same table, for the same command, with
-- COMPLETELY DIFFERENT predicates, and the check would report parity.
--
-- Rewriting a `using (...)` in the dashboard is precisely the kind of quiet
-- production edit this whole instrument exists to catch, and it is the one
-- edit it could not have caught.
--
-- Found 2026-08-18 while reconciling policies to production: comparing the two
-- databases needed `qual` and `with_check`, and the fingerprint did not have
-- them. It happened that every same-named policy DID match — but the check was
-- not what established that, which is the point.
--
-- `qual` and `with_check` are hashed with the rest of the entry now, and
-- `permissive` and `roles` with them, since a PERMISSIVE policy silently turned
-- RESTRICTIVE, or one re-scoped from `authenticated` to `public`, is the same
-- class of invisible change.
--
-- (No inline comment sits inside the function body on purpose. The first
--  version of this file carried one that the applied version did not, because
--  the SQL was retyped into `apply_migration` — CLAUDE.md 6 rule 4 warns about
--  exactly that, and the body-md5 comparison caught it the same hour. The
--  explanation lives in this header, which cannot drift from the catalog.)
--
-- Only the `policies` branch changes. The other eight shapes are re-emitted
-- unchanged because `create or replace function` cannot replace one branch of a
-- `union all`.

begin;

create or replace function public.schema_fingerprint()
returns table (shape text, items bigint, digest text)
language plpgsql
stable
security definer
set search_path to 'public'
as $$
begin
  if not public.is_platform_admin() then
    raise exception 'Not authorized to read the schema fingerprint'
      using errcode = '42501';
  end if;

  return query
  select 'tables'::text, count(*)::bigint,
         md5(coalesce(string_agg(t.table_name, ',' order by t.table_name), ''))
    from information_schema.tables t
   where t.table_schema = 'public' and t.table_type = 'BASE TABLE'
  union all
  select 'columns', count(*)::bigint,
         md5(coalesce(string_agg(
           c.table_name || '.' || c.column_name || ':' || c.data_type, ','
           order by c.table_name, c.column_name), ''))
    from information_schema.columns c where c.table_schema = 'public'
  union all
  select 'functions', count(*)::bigint,
         md5(coalesce(string_agg(q.n, ',' order by q.n), ''))
    from (select distinct p.proname n from pg_proc p
            join pg_namespace ns on ns.oid = p.pronamespace
           where ns.nspname = 'public') q
  union all
  select 'bodies', count(*)::bigint,
         md5(coalesce(string_agg(
           p.proname || ':' ||
           md5(regexp_replace(p.prosrc, '[[:space:]]+', ' ', 'g')), ','
           order by p.proname), ''))
    from pg_proc p join pg_namespace ns on ns.oid = p.pronamespace
   where ns.nspname = 'public'
  union all
  select 'policies', count(*)::bigint,
         md5(coalesce(string_agg(
           pol.tablename || '.' || pol.policyname || ':' || pol.cmd ||
           ':' || pol.permissive ||
           ':' || coalesce(pol.roles::text, '-') ||
           ':' || coalesce(pol.qual, '-') ||
           ':' || coalesce(pol.with_check, '-'), ','
           order by pol.tablename, pol.policyname), ''))
    from pg_policies pol where pol.schemaname = 'public'
  union all
  select 'triggers', count(*)::bigint,
         md5(coalesce(string_agg(
           cl.relname || '.' || tg.tgname || ':' || fp.proname, ','
           order by cl.relname, tg.tgname), ''))
    from pg_trigger tg
    join pg_class cl on cl.oid = tg.tgrelid
    join pg_proc fp on fp.oid = tg.tgfoid
    join pg_namespace ns on ns.oid = cl.relnamespace
   where ns.nspname = 'public' and not tg.tgisinternal
  union all
  select 'indexes', count(*)::bigint,
         md5(coalesce(string_agg(
           ix.tablename || '.' || ix.indexname, ','
           order by ix.tablename, ix.indexname), ''))
    from pg_indexes ix where ix.schemaname = 'public'
  union all
  select 'rls', count(*)::bigint,
         md5(coalesce(string_agg(
           cl.relname || ':' || cl.relrowsecurity::text, ','
           order by cl.relname), ''))
    from pg_class cl join pg_namespace ns on ns.oid = cl.relnamespace
   where ns.nspname = 'public' and cl.relkind = 'r'
  union all
  select 'cron',
         coalesce((select count(*) from cron.job), 0)::bigint,
         coalesce((select md5(string_agg(j.jobname || ' -> ' || j.command, ','
                                         order by j.jobname))
                     from cron.job j), md5(''));
end
$$;

comment on function public.schema_fingerprint() is
  'Nine md5 digests of the live schema, for tool/schema_parity_check.py. '
  'Platform-admin only. The policies digest covers qual, with_check, permissive '
  'and roles — not just the policy name — because a rewritten predicate under an '
  'unchanged name is exactly the invisible production edit this exists to catch.';

revoke all on function public.schema_fingerprint() from public, anon;
grant execute on function public.schema_fingerprint() to authenticated;

commit;
