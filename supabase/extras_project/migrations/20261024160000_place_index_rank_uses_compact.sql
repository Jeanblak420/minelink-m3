-- EXTRAS PROJECT ONLY (qbydiuplqhmkaxarnuza). Do not apply to the main project.
--
-- Step two of two: _place_index_rank finds its candidates in the narrow,
-- town-ordered place_index_search (20261024150000) instead of place_index,
-- and goes back to place_index only for the rows it returns (at most 20).
-- Then the old full-text index on place_index, which nothing else uses, is
-- dropped (34 MB).
--
-- Scoring is unchanged: same 2,000-candidate cap by confidence, same word
-- coverage × 0.8 + trigram similarity × 0.2, same order. One addition: `id`
-- as the last tie-break, in the candidate cut and the final order. Where
-- more than 2,000 rows match and several share the confidence at the cut,
-- the old function took whichever lay first on disk — and the disk order is
-- exactly what this change rearranges. Breaking the tie on `id` makes the
-- choice deterministic instead of moving it.
--
-- Return type unchanged, so `create or replace` is allowed (CLAUDE.md §6:
-- a widened return type would need a drop first).
begin;

create or replace function public._place_index_rank(
  p_raw text, p_words text[], p_keys text[], p_limit integer)
returns table (
  id text, name text, category text, addr_street text, addr_locality text,
  addr_region text, addr_postcode text, addr_country text,
  lat double precision, lon double precision, score real)
language sql
stable
security definer
set search_path to 'public', 'extensions'
as $function$
  with candidates as (
    select s.id, s.name, s.search_text, s.confidence
    from public.place_index_search s
    where to_tsvector('simple', s.search_text)
          @@ plainto_tsquery('simple', array_to_string(p_keys, ' '))
    order by s.confidence desc nulls last, s.id
    limit 2000
  ), scored as (
    select c.id, c.name, c.confidence,
           (
             (
               select count(*)::real
               from unnest(p_words) w
               where c.search_text ilike '%' || w || '%'
             ) / greatest(array_length(p_words, 1), 1)
           ) * 0.8
           + similarity(c.search_text, p_raw) * 0.2 as score
    from candidates c
  ), top as (
    -- Word coverage dominates: matching 4 of the 5 words someone typed
    -- matters far more than how similar the two strings look end to end.
    select s.id, s.name, s.confidence, s.score::real as score
    from scored s
    order by s.score desc, s.confidence desc nulls last, s.name, s.id
    limit p_limit
  )
  select p.id, p.name, p.category, p.addr_street, p.addr_locality,
         p.addr_region, p.addr_postcode, p.addr_country, p.lat, p.lon,
         t.score
  from top t
  join public.place_index p on p.id = t.id
  order by t.score desc, t.confidence desc nulls last, t.name, t.id;
$function$;

revoke all on function public._place_index_rank(text, text[], text[], integer)
  from public, anon, authenticated;

drop index if exists public.place_index_search_fts;

commit;
