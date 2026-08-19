-- EXTRAS PROJECT ONLY (qbydiuplqhmkaxarnuza). Do not apply to the main project.
--
-- Match the main project's posture: RLS **and** no table grant.
--
-- WHAT WAS FOUND
-- --------------
-- Probed live 2026-08-16, unauthenticated, with only the publishable key, on
-- each project:
--
--   main    GET /rest/v1/place_index  ->  401  permission denied for table place_index
--   extras  GET /rest/v1/place_index  ->  200  []
--
-- No rows leaked — RLS is enabled with no policy, so every row is filtered — but
-- the two projects were not equivalent, and the weaker one is the one exposed
-- to `anon`.
--
-- The difference is that this project handed `anon`/`authenticated` a
-- table-level SELECT grant that the main project never had. Nothing in
-- 20260815150000 grants it; Supabase's Data API settings expose newly created
-- public tables automatically, and that default applied here because the table
-- was created fresh rather than inherited.
--
-- WHY IT IS WORTH CLOSING EVEN THOUGH NO DATA LEAKED
-- ---------------------------------------------------
--   * It leaks the table's existence and, through PostgREST's error and OPTIONS
--     responses, its column names.
--   * It leaves ONE control standing between anon and 611,841 rows. RLS with no
--     policy is correct today, but a single later `create policy ... using
--     (true)` — the obvious-looking way to "make search work" — would turn the
--     whole table public in one statement. With no grant underneath, that same
--     mistake changes nothing.
--   * The two projects should fail the same way. A posture that differs between
--     them is a posture nobody can reason about.
--
-- This does NOT affect search_place_index. That function is SECURITY DEFINER, so
-- it runs as its owner and reads the table regardless of what `anon` may do
-- directly — which the main project has been proving in production all along,
-- with no grant at all.

revoke all on table public.place_index from anon, authenticated, public;

-- Belt and braces: stop the default from coming back for anything created here
-- later. Supabase's own roles keep what they need; service_role is server-side
-- only and already bypasses RLS.
alter default privileges in schema public revoke all on tables from anon, authenticated;

comment on table public.place_index is
  'Overture Maps places (CDLA-Permissive-2.0), South Africa only. Read-only '
  'reference data on the Mine-Link_Extra_Data project. RLS on, no policy, no '
  'grant — reachable ONLY through search_place_index(), which is SECURITY '
  'DEFINER and granted to anon because a main-project JWT is not valid here.';
