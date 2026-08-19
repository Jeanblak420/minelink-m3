-- place_house_number: ASCII digits only.
--
-- WHY THIS FILE EXISTS
-- --------------------
-- This body is already live on the main project. It was applied on 2026-08-15
-- as `place_house_number_ascii_digits` and **never mirrored to a migration
-- file**, which CLAUDE.md §6 rule 3 forbids without exception: an applied
-- migration with no file is unreproducible from git.
--
-- It was found on 2026-08-16 by diffing `md5(prosrc)` between the two Supabase
-- projects while moving place_index across. The main project had
-- f668e18f7e382f0d7a43baca04070a5b and the new project, built from the files in
-- this directory, had 676ee94d6c1b5a78174cf072166a3731 — a difference that only
-- existed because the fix lived nowhere but in one database. The body below is
-- copied from `pg_get_functiondef` on the main project, not rewritten, so
-- applying it there is a no-op.
--
-- THE BUG IT FIXES
-- ----------------
-- The version in 20260816090000 matched house numbers with `\d`:
--
--     when p_addr ~ '^\s*\d{1,5}\s' or p_addr ~ '^\s*\d{1,5}[a-zA-Z]?\s'
--     then (regexp_match(p_addr, '^\s*(\d{1,5})'))[1]::int
--
-- **In Postgres, `\d` matches any Unicode decimal digit, not just 0-9.** Overture
-- is a global dataset assembled from Meta, Microsoft, Foursquare and OSM, so an
-- address line can legitimately begin with Arabic-Indic or Devanagari numerals.
-- Those matched the guard, were captured by the same class, and were then handed
-- to `::int` — which does NOT accept them, so the row raised
-- `invalid input syntax for type integer` instead of returning NULL. In a
-- backfill that is not one bad row; it is the whole batch rolled back, forever,
-- with the transaction dying on the same row every retry.
--
-- `[0-9]` and `[[:space:]]` say exactly what was meant. The two alternated
-- branches also collapse into one: the first was a strict subset of the second,
-- since `[a-zA-Z]?` already covers the empty case.

create or replace function public.place_house_number(p_addr text)
returns integer
language sql
immutable
parallel safe
set search_path = ''
as $$
  select case
           when p_addr ~ '^[[:space:]]*[0-9]{1,5}[a-zA-Z]?[[:space:]]'
           then (regexp_match(p_addr, '^[[:space:]]*([0-9]{1,5})'))[1]::int
         end;
$$;

comment on function public.place_house_number(text) is
  'Leading house number from a free-form address line, ASCII digits only. '
  '`\d` in Postgres matches Unicode digits, which then fail ::int and abort '
  'the whole backfill batch rather than yielding NULL. A number in the middle '
  '("Shop 12A, Pineslopes") is a unit, not a street number, and is ignored.';
