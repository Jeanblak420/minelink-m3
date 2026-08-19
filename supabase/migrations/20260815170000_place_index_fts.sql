-- Index the place index for the query it actually runs: whole words.
--
-- 20260815150000 reached for a GIN trigram index, which is the right tool for
-- fuzzy matching and the wrong one here. Measured on the loaded table
-- (789,680 rows, 254 MB):
--
--   * trigram GIN would have cost ~120 MB; the full-text GIN costs **40 MB**.
--     On a project whose database was 64 MB before this, that difference is
--     the difference between comfortable and not.
--   * Bulk-loading THROUGH the trigram index halved insert throughput
--     (1,900 -> 950 rows/s, still sagging) and a search during the load took
--     **11.5 seconds**, because every query had to scan GIN's pending list.
--     tools/overture_import.py now drops the index for the load and builds it
--     once at the end; that is why it does that.
--   * The search matches WORDS ("westway", "fourways"), not fuzzy spellings.
--     Trigram makes Postgres intersect six 3-character posting lists and
--     recheck every candidate row; full text intersects one posting list per
--     word. Same answers, far less work.
--
-- Fuzzy tolerance is not lost, it moves: a misspelling now falls through the
-- index and the picker asks Nominatim and Photon, which is the ladder
-- place_search_service.dart already implements.
--
-- The 'simple' text-search config is deliberate — no stemming and no stop
-- words. An address is not prose: "Rd" must not stem, and dropping a word for
-- being common is exactly wrong when the word is "north" or "west".

drop index if exists public.place_index_search_trgm;

create index if not exists place_index_search_fts
  on public.place_index using gin (to_tsvector('simple', search_text));

analyze public.place_index;

-- Ranking helper. Candidates come from the FTS index; the score is computed
-- only over what survives, so the per-row word count is cheap.
--
-- The 2000-row cap is a backstop for a key word like "johannesburg" — ordered
-- by confidence, so if it ever bites, what it keeps is the best-attested
-- places rather than an arbitrary slice.
create or replace function public._place_index_rank(
  p_raw   text,
  p_words text[],
  p_keys  text[],
  p_limit int
)
returns table (
  id            text,
  name          text,
  category      text,
  addr_street   text,
  addr_locality text,
  addr_region   text,
  addr_postcode text,
  addr_country  text,
  lat           double precision,
  lon           double precision,
  score         real
)
language sql
stable
security definer
set search_path = public, extensions
as $$
  with candidates as (
    select p.*
    from public.place_index p
    where to_tsvector('simple', p.search_text)
          @@ plainto_tsquery('simple', array_to_string(p_keys, ' '))
    order by p.confidence desc nulls last
    limit 2000
  ), scored as (
    select c.*,
           (
             select count(*)::real
             from unnest(p_words) w
             where c.search_text ilike '%' || w || '%'
           ) / greatest(array_length(p_words, 1), 1) as word_hit,
           similarity(c.search_text, p_raw) as trg
    from candidates c
  )
  select s.id, s.name, s.category, s.addr_street, s.addr_locality,
         s.addr_region, s.addr_postcode, s.addr_country, s.lat, s.lon,
         -- Word coverage dominates: matching 4 of the 5 words someone typed
         -- matters far more than how similar the two strings look end to end.
         (s.word_hit * 0.8 + s.trg * 0.2)::real as score
  from scored s
  order by score desc, s.confidence desc nulls last, s.name
  limit p_limit;
$$;

create or replace function public.search_place_index(
  p_query text,
  p_limit int default 6
)
returns table (
  id            text,
  name          text,
  category      text,
  addr_street   text,
  addr_locality text,
  addr_region   text,
  addr_postcode text,
  addr_country  text,
  lat           double precision,
  lon           double precision,
  score         real
)
language plpgsql
stable
security definer
set search_path = public, extensions
as $$
declare
  v_raw   text := btrim(coalesce(p_query, ''));
  v_words text[];
  v_keys  text[];
  v_limit int := least(greatest(coalesce(p_limit, 6), 1), 20);
begin
  if length(v_raw) < 3 then
    return;
  end if;

  -- Every word, for scoring. Punctuation is a separator, so "Rd," and "Rd" are
  -- the same word and "13 Westway Rd, Fourways" has four of them.
  select array_agg(w)
    into v_words
  from unnest(
         string_to_array(lower(regexp_replace(v_raw, '[^a-zA-Z0-9]+', ' ', 'g')),
                         ' ')
       ) w
  where length(w) > 0;

  if v_words is null or array_length(v_words, 1) = 0 then
    return;
  end if;

  -- Key words drive the index: 4+ characters, longest first, at most two.
  -- "13" and "Rd" are skipped — they match half the country and would make the
  -- AND useless.
  select array_agg(w order by length(w) desc)
    into v_keys
  from (select distinct w from unnest(v_words) w where length(w) >= 4) t;

  -- Pass 1 — the two longest words must BOTH appear. Enormously selective:
  -- "westway" AND "fourways" is a handful of rows out of 789,680.
  if array_length(v_keys, 1) >= 2 then
    return query select * from public._place_index_rank(
      v_raw, v_words, v_keys[1:2], v_limit);
    if found then return; end if;
  end if;

  -- Pass 2 — just the longest word.
  if array_length(v_keys, 1) >= 1 then
    return query select * from public._place_index_rank(
      v_raw, v_words, v_keys[1:1], v_limit);
    if found then return; end if;
  end if;

  -- Pass 3 — nothing long enough to key on ("21 Ave", "R512"). Ask for all the
  -- words at once and take what comes.
  return query select * from public._place_index_rank(
    v_raw, v_words, v_words, v_limit);
end;
$$;

-- Internal: only search_place_index may call it, and that runs as the owner.
revoke execute on function public._place_index_rank(text, text[], text[], int)
  from public, anon, authenticated;
drop function if exists public._place_index_rank(text, text[], text, text, int);

revoke execute on function public.search_place_index(text, int) from public;
grant execute on function public.search_place_index(text, int) to authenticated;
