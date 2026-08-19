-- Make search_place_index actually match the way people type addresses.
--
-- The first cut (20260815150000) required the WHOLE typed string to be a
-- substring of the row, or to clear the trigram similarity threshold against
-- it. Neither happens for a real address. Typing
--
--     13 Westway Rd, Fourways, Sandton, 2055
--
-- against the row that should win —
--
--     Micro-Ctrl 15 Westway Rd, Fourways Sandton
--
-- gives no substring (the house numbers differ, and the business name sits in
-- front) and a low whole-string similarity, because similarity() divides by the
-- union of both strings' trigrams and the query is the longer of the two. So
-- the index would have sat there full of the right answers and returned none of
-- them.
--
-- What people actually type is a bag of words, some of which are wrong or
-- missing. So: drive the index with the two longest words (both served by the
-- existing GIN trigram index), then rank candidates by how much of the REST of
-- the query they contain. "Westway" AND "Fourways" is enormously selective;
-- ranking within that handful is free.
--
-- Three passes, widening only when the previous finds nothing, so a precise
-- query never pays for the loose ones:
--   1. all key words (up to 2, longest first, 4+ chars)
--   2. the single longest key word
--   3. plain trigram similarity on the raw string — the old behaviour, kept as
--      the last resort for queries with no long words ("21 Ave", "R512").

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
  v_k1    text;
  v_k2    text;
  v_limit int := least(greatest(coalesce(p_limit, 6), 1), 20);
begin
  if length(v_raw) < 3 then
    return;
  end if;

  -- Every word, for scoring. Punctuation is a separator: "Rd," and "Rd" are
  -- the same word, and "13 Westway Rd, Fourways" has four of them.
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

  -- Key words drive the index. 4+ chars because a trigram index cannot help
  -- with "13" or "Rd", and those match half the country anyway.
  select array_agg(w order by length(w) desc)
    into v_keys
  from (
    select distinct w from unnest(v_words) w where length(w) >= 4
  ) t;

  v_k1 := v_keys[1];
  v_k2 := v_keys[2];

  -- Pass 1 — every key word present.
  if v_k1 is not null then
    return query
    select c.id, c.name, c.category, c.addr_street, c.addr_locality,
           c.addr_region, c.addr_postcode, c.addr_country, c.lat, c.lon,
           c.score
    from _place_index_rank(v_raw, v_words, v_k1, v_k2, v_limit) c;
    if found then return; end if;
  end if;

  -- Pass 2 — just the longest word.
  if v_k2 is not null then
    return query
    select c.id, c.name, c.category, c.addr_street, c.addr_locality,
           c.addr_region, c.addr_postcode, c.addr_country, c.lat, c.lon,
           c.score
    from _place_index_rank(v_raw, v_words, v_k1, null, v_limit) c;
    if found then return; end if;
  end if;

  -- Pass 3 — no usable key word (or nothing matched one): fall back to raw
  -- similarity, which is all the original function ever did.
  return query
  select p.id, p.name, p.category, p.addr_street, p.addr_locality,
         p.addr_region, p.addr_postcode, p.addr_country, p.lat, p.lon,
         greatest(similarity(p.search_text, v_raw),
                  word_similarity(v_raw, p.search_text))::real
  from public.place_index p
  where p.search_text ilike '%' || v_raw || '%'
     or p.search_text % v_raw
  order by 11 desc, p.confidence desc nulls last, p.name
  limit v_limit;
end;
$$;

-- Ranking helper, split out so the three passes cannot drift apart.
--
-- `p_k1`/`p_k2` narrow via the GIN trigram index; the score is then computed
-- only over what survives. The 2000-row cap is a backstop for a key word like
-- "johannesburg" — ordered by confidence, so if it ever bites, what it keeps
-- is the best-attested places rather than an arbitrary slice.
create or replace function public._place_index_rank(
  p_raw   text,
  p_words text[],
  p_k1    text,
  p_k2    text,
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
    where (p_k1 is null or p.search_text ilike '%' || p_k1 || '%')
      and (p_k2 is null or p.search_text ilike '%' || p_k2 || '%')
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
         -- Word coverage dominates: matching 4 of 5 typed words matters far
         -- more than how similar the strings look end to end.
         (s.word_hit * 0.8 + s.trg * 0.2)::real as score
  from scored s
  order by score desc, s.confidence desc nulls last, s.name
  limit p_limit;
$$;

revoke execute on function public._place_index_rank(text, text[], text, text, int)
  from public, anon, authenticated;

revoke execute on function public.search_place_index(text, int) from public;
grant execute on function public.search_place_index(text, int) to authenticated;
