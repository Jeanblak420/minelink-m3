-- Nothing could check that the migration ledger matched the files.
--
-- CLAUDE.md §6 says the files are the source of truth and the ledger must
-- match them: one file per applied migration, one row per file, each row's
-- `version` equal to its filename stamp. That rule is enforced by attention,
-- and on 2026-08-17 attention lost. The repoint for `20260817330000` was
-- issued in the same statement batch as a self-rolling-back `raise exception`
-- probe, so it was rolled back with it and the row silently kept its
-- auto-assigned `20260817133116`.
--
-- Nothing failed. The apply succeeded, the probe printed its findings, and the
-- ledger was quietly wrong. It was found by hand-comparing `ls
-- supabase/migrations/` against a `select` — a mechanical comparison that
-- belongs in `tool/`, beside the other checkers.
--
-- The obstacle was access, which is what this migration is for.
-- `supabase_migrations` is not one of the schemas PostgREST exposes, so a
-- checker holding the app's publishable key cannot read the ledger at all:
--
--     PGRST106  Invalid schema: supabase_migrations
--     hint: Only the following schemas are exposed: public, graphql_public
--
-- So `public.migration_ledger()` is the door — read-only, two columns, and
-- gated on `is_platform_admin()`.
--
-- WHY NOT GRANT IT TO `anon`, which would have saved the checker a sign-in:
-- the publishable key ships inside the web bundle, so an `anon` grant is a
-- public grant. The row names in this ledger read as a candid changelog of
-- past defects — `a_load_can_be_recorded_twice`,
-- `a_dispatch_could_succeed_with_no_stockpile_and_no_word_to_anyone`,
-- `vehicle_positions_buyer_sees_only_its_own_trips`. That is a map of where
-- this product has been weak, handed to anyone who asks. `authenticated` plus
-- the admin check costs the checker one password grant and gives that away to
-- nobody.

begin;

create or replace function public.migration_ledger()
returns table (version text, name text)
language plpgsql
stable
security definer
set search_path to 'public'
as $$
begin
  -- SECURITY DEFINER, so the check is the whole boundary. Raise rather than
  -- return nothing: a checker that reads zero rows because it was refused
  -- would report "every file is unapplied", which is alarming and false.
  if not public.is_platform_admin() then
    raise exception 'Not authorized to read the migration ledger'
      using errcode = '42501';
  end if;

  -- Every reference is alias-qualified. An unqualified `version` here would
  -- resolve against the OUT parameter of the same name rather than the
  -- column — the same family of fault as
  -- tool/plpgsql_alias_collision_check.py exists for.
  return query
    select m.version::text, m.name::text
      from supabase_migrations.schema_migrations m
     order by m.version;
end
$$;

comment on function public.migration_ledger() is
  'The applied-migration ledger, for tool/migration_ledger_check.py. Read-only '
  'and platform-admin only: supabase_migrations is not exposed to PostgREST, '
  'and the row names describe past defects, so this is deliberately not '
  'granted to anon even though the checker would be simpler if it were.';

revoke all on function public.migration_ledger() from public, anon;
grant execute on function public.migration_ledger() to authenticated;

commit;
