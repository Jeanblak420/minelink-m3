-- Make it possible to notice that production has drifted from the files.
--
-- EVERY defect this session's cold replay found had one shape: something
-- reached production out of band, no migration recorded it, and nothing ever
-- compared the two. The list is not short.
--
--   seat_reassignment_log                 a whole table, no file
--   check_seat_reassignment_allowed       and three more seat functions
--   organization_seats.role_binding       a column, no file
--   organization_seats.serial_number      a column, no file
--   organization_seats.token_id           a column, no file
--   companies.{company_admin_user_id,     five columns, no file
--     created_by, seats_available,
--     support_contact_email,
--     token_assigned_at}
--   audit_logs.target_id                  text in production, uuid in the files
--   cron expire-organizations-daily       the job production runs, no file
--
-- Each was found by hand, on 2026-08-18, years after the fact. The repair for
-- each is a migration. The repair for the CLASS is this: a fingerprint of the
-- live schema that a checker can compare against a value committed to git, so
-- the next out-of-band change fails a check the same week instead of being
-- discovered by a rebuild that nobody had run.
--
-- NINE SHAPES, because eight were not enough. Tables, columns, functions,
-- function BODIES, policies, triggers, indexes, RLS state — and cron. Cron was
-- the ninth only after the diff showed a rebuilt database would have scheduled
-- the SUPERSEDED expiry function against real companies every night. Nothing
-- in the schema would ever have revealed that.
--
-- Bodies are hashed, not just names: a function present in both databases with
-- a different body is invisible to a name-level comparison and is exactly
-- where behaviour drifts.
--
-- Platform-admin only, for the same reason as `migration_ledger()`: the
-- publishable key ships inside the web bundle, so an `anon` grant is a public
-- grant, and this returns a map of the entire schema.

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
  -- Whitespace-normalised so a reformat is not reported as a behaviour change.
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
           pol.tablename || '.' || pol.policyname || ':' || pol.cmd, ','
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
  -- pg_cron may be absent in a restore target; report that rather than fail.
  select 'cron',
         coalesce((select count(*) from cron.job), 0)::bigint,
         coalesce((select md5(string_agg(j.jobname || ' -> ' || j.command, ','
                                         order by j.jobname))
                     from cron.job j), md5(''));
end
$$;

comment on function public.schema_fingerprint() is
  'Nine md5 digests of the live schema, for tool/schema_parity_check.py. '
  'Platform-admin only. Exists because every gap the 2026-08-18 cold replay '
  'found was an out-of-band change that nothing was watching for.';

revoke all on function public.schema_fingerprint() from public, anon;
grant execute on function public.schema_fingerprint() to authenticated;

commit;
