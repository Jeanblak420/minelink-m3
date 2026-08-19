-- place_street_key: never NULL, and cheap enough to inline.
--
-- WHY THIS FILE EXISTS
-- -------------------
-- This function was already replaced on the live database at 2026-08-15 23:38,
-- during the outage described below, and the replacement was never mirrored to
-- a migration file. CLAUDE.md §6 rule 3 forbids that state without exception:
-- an applied migration with no file is unreproducible from git. This file is
-- that mirror — the body below is the text that was applied, not a rewrite of
-- it, so re-running it against the live database is a no-op.
--
-- THE TWO FAULTS IN THE PLPGSQL VERSION (20260816090000)
-- ------------------------------------------------------
-- Both were found by running it over the full ~790k-row table.
--
-- 1. IT RETURNED NULL FOR AN UNPARSEABLE ADDRESS, WHICH MADE ANY BACKFILL
--    NON-TERMINATING. An address line with no parseable street ("Shop 5,",
--    punctuation only) reduces to the empty string, and the old body did
--    `if s = '' then return null; end if`.
--
--    A batched backfill is necessarily driven by `where street_key is null`
--    — that predicate is what "not yet done" means. So every row the function
--    could not parse was written back as NULL, re-selected by the next batch,
--    written back as NULL again, and re-selected forever. The loop had no
--    fixed point and could not converge.
--
--    This is not a theoretical fault. It is the direct cause of the 2026-08-16
--    outage: 20,000-row UPDATE batches at 27-45 s each, running back-to-back
--    and never finishing, against a 500 MB free-tier instance shared with the
--    live app. Autovacuum was locked out the whole time
--    ("skipping vacuum of place_index --- lock not available") by a CREATE
--    INDEX overlapping the same table, so none of the dead tuples the loop
--    produced were ever reclaimed. Postgres stopped answering at 23:49 and
--    every service that depends on it went with it.
--
--    The fix is to make the two states distinguishable, which they were not:
--      ''    = processed, there was no street in this address line
--      NULL  = not yet processed
--    A backfill on `where street_key is null` now strictly shrinks its own
--    candidate set on every pass, so it terminates by construction.
--
-- 2. PLPGSQL CANNOT BE INLINED, so it cost a function call per row. Written as
--    pure SQL the planner folds it into the UPDATE. Same reason the rewrite is
--    `language sql` rather than a minimal one-line patch to the plpgsql body.
--
-- The suffix canonicalisation is unchanged in behaviour. The identity arms of
-- the old CASE ('rd' -> 'rd', 'st' -> 'st', ...) are gone because `else tail`
-- already covers them; every non-identity mapping is preserved exactly.

create or replace function public.place_street_key(p_addr text)
returns text
language sql
immutable
parallel safe
set search_path = ''
as $$
  with a as (
    select btrim(regexp_replace(
             regexp_replace(
               regexp_replace(
                 lower(btrim(split_part(coalesce(p_addr, ''), ',', 1))),
                 '^[[:space:]]*[0-9]{1,5}[a-z]?[[:space:]]+', ''),
               '[^a-z0-9 ]+', ' ', 'g'),
             '[[:space:]]+', ' ', 'g')) as v
  ), b as (
    select v,
           case when v like '% %'
                then regexp_replace(v, '[[:space:]]+[^[:space:]]+$', '')
                else '' end as head,
           regexp_replace(v, '^.*[[:space:]]', '') as tail
    from a
  )
  select btrim(head || ' ' || case tail
           when 'road' then 'rd'
           when 'avenue' then 'ave'   when 'av' then 'ave'
           when 'street' then 'st'    when 'str' then 'st'
           when 'drive' then 'dr'
           when 'boulevard' then 'blvd'
           when 'lane' then 'ln'
           when 'crescent' then 'cres'
           when 'close' then 'cl'
           when 'place' then 'pl'
           when 'terrace' then 'ter'
           when 'highway' then 'hwy'
           else tail
         end)
  from b;
$$;

comment on function public.place_street_key(text) is
  'Canonical street key from a free-form address line. Returns '''' (not NULL) '
  'when there is no parseable street, so that a backfill driven by '
  '"where street_key is null" strictly shrinks its candidate set and '
  'terminates. Returning NULL there caused the 2026-08-16 outage. Pure SQL so '
  'the planner can inline it into a bulk UPDATE.';

-- ---------------------------------------------------------------------------
-- Repair rows the old function already poisoned
-- ---------------------------------------------------------------------------
-- Rows whose address line has no parseable street are sitting at NULL and
-- would be re-selected forever by the predicate above. Settle them to '' once,
-- bounded and cheap: this touches only the unparseable remainder (~tens of
-- thousands at most), not the whole table, and it is the ONLY write in this
-- migration. It is deliberately NOT the whole-table rewrite that
-- 20260816090000 performs — see place_index_backfill.py for how the bulk pass
-- is meant to be run.
update public.place_index
   set street_key = ''
 where addr_street is not null
   and street_key is null
   and public.place_street_key(addr_street) = '';
