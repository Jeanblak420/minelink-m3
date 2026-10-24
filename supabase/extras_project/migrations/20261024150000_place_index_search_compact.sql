-- EXTRAS PROJECT ONLY (qbydiuplqhmkaxarnuza). Do not apply to the main project.
--
-- A narrow copy of place_index for the address search to scan, stored in
-- town order. Step one of two; it changes no behaviour on its own
-- (20261024160000 points the ranking at it).
--
-- WHY (measured 2026-10-24, Jean's go-ahead to investigate and fix)
-- ----------------------------------------------------------------
-- The address search timed out for app users: they arrive here as `anon`,
-- whose statement_timeout is 3 s, and the first search for a common town
-- took 2.8–7.7 s ("Johannesburg" 7,726 ms, "Centurion" 3,273 ms). The same
-- search a second time took 30–200 ms.
--
-- The query plan is fine. The machine is not: this free-plan database has
-- 455 MB of RAM in total, Postgres's own default cache is 280 MB of it, and
-- 429 MB of swap was in use. A page Postgres counts as cached is often in
-- swap, so the first touch is a disk read. Pre-loading the table
-- (pg_prewarm, tried and removed) did not help for exactly that reason.
--
-- What does help is touching fewer pages. The ranking reads every row that
-- matches the town name to sort by confidence, and those rows are scattered
-- across place_index — "durban" (24,356 rows) touched 7,991 pages, about one
-- per row. Copying just the columns the ranking reads into a narrow table
-- sorted by town puts a town's rows on neighbouring pages: roughly sixty
-- times fewer pages, so a cold search stays inside the timeout.
--
-- It is a materialized view because place_index is static between imports:
-- after re-importing place_index, run
--
--     refresh materialized view public.place_index_search;
--
-- (non-concurrent on purpose: a CONCURRENTLY refresh needs a unique index,
-- 34 MB this project does not need to spend). It is read only by
-- _place_index_rank, a SECURITY DEFINER function; nobody else is granted it.
begin;

set local statement_timeout = '15min';

create materialized view public.place_index_search as
  select id, name, search_text, confidence
    from public.place_index
   order by addr_locality nulls last, street_key nulls last, name
  with data;

comment on materialized view public.place_index_search is
  'Narrow copy of place_index in town order, scanned by _place_index_rank. '
  'Refresh after re-importing place_index. See migration 20261024150000.';

create index place_index_search_text_fts
  on public.place_index_search
  using gin (to_tsvector('simple', search_text));

revoke all on public.place_index_search from public, anon, authenticated;

analyze public.place_index_search;

commit;
