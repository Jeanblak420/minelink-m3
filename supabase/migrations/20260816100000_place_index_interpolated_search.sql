-- Return the number that was asked for, not the nearest one somebody recorded.
--
-- Searching "13 westway road, fourways" found 15 Westway Rd, because a business
-- sits at 15 and nothing is recorded at 13. With house numbers now parsed out of
-- the address line (20260816090000), the anchors on that street are 15 and 39,
-- and 13 fits against them at (-26.033604, 27.998426) — 49.7 m up-street from
-- 15, which is where 13 is.
--
-- The interpolated point is returned FIRST and carries `match_kind` +
-- `note` so the picker can say "interpolated between 15 and 39". It is a
-- calculation, not a survey, and the UI has to admit that: this pin is what a
-- driver gets routed to.
--
-- The base results still follow it, so the real recorded places remain one tap
-- away when the calculation looks wrong.
--
-- ---------------------------------------------------------------------------
-- WHY THE DROP BELOW IS NOT OPTIONAL
-- ---------------------------------------------------------------------------
-- This migration is where `search_place_index` gains `match_kind` and `note`,
-- taking its return from 11 columns to 13. **`create or replace function`
-- cannot change a function's return type**, and adding OUT columns is exactly
-- that:
--
--     ERROR:  42P13: cannot change return type of existing function
--     DETAIL: Row type defined by OUT parameters is different.
--     HINT:   Use DROP FUNCTION search_place_index(text,integer) first.
--
-- Without the drop this file simply cannot run against any database where an
-- earlier migration in this chain already created the 11-column version —
-- which is every database that has run 20260815150000, 20260815160000 or
-- 20260815170000, i.e. all of them. The chain was therefore **not replayable**:
-- `supabase db reset`, a restore into a fresh project, or CI would all have
-- failed here. It only ever appeared to work on the project it was first
-- written against, where the function happened to have been dropped by hand
-- in between.
--
-- Found 2026-08-16 by building the second Supabase project from these files
-- for real, which is the only thing that exercises a cold replay.
--
-- `if exists` keeps it idempotent, and dropping is safe because the function is
-- recreated immediately below and nothing else depends on it — the picker
-- reaches it over PostgREST, not through a stored dependency.
-- ---------------------------------------------------------------------------

drop function if exists public.search_place_index(text, int);

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
  score         real,
  match_kind    text,
  note          text
)
language plpgsql
stable
security definer
set search_path = public, extensions
as $$
declare
  v_raw    text := btrim(coalesce(p_query, ''));
  v_words  text[];
  v_keys   text[];
  v_limit  int := least(greatest(coalesce(p_limit, 6), 1), 20);
  v_ids    text[];
  v_scores real[];
  v_num    int;
  v_top    record;
  v_pin    record;
begin
  if length(v_raw) < 3 then
    return;
  end if;

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

  select array_agg(w order by length(w) desc)
    into v_keys
  from (select distinct w from unnest(v_words) w where length(w) >= 4) t;

  -- Run the ranking ONCE and keep the ids. The street lookup below needs the
  -- winner, and re-running the search to find it would double the query time
  -- of every address search in the app.
  if array_length(v_keys, 1) >= 2 then
    select array_agg(r.id order by r.score desc),
           array_agg(r.score order by r.score desc)
      into v_ids, v_scores
    from public._place_index_rank(v_raw, v_words, v_keys[1:2], v_limit) r;
  end if;

  if v_ids is null and array_length(v_keys, 1) >= 1 then
    select array_agg(r.id order by r.score desc),
           array_agg(r.score order by r.score desc)
      into v_ids, v_scores
    from public._place_index_rank(v_raw, v_words, v_keys[1:1], v_limit) r;
  end if;

  if v_ids is null then
    select array_agg(r.id order by r.score desc),
           array_agg(r.score order by r.score desc)
      into v_ids, v_scores
    from public._place_index_rank(v_raw, v_words, v_words, v_limit) r;
  end if;

  if v_ids is null then
    return;
  end if;

  -- A leading number is a house number. ASCII digits only: Postgres' \d also
  -- matches Arabic-Indic digits, which this dataset contains, and ::int then
  -- throws.
  v_num := (regexp_match(v_raw, '^[[:space:]]*([0-9]{1,5})[[:space:]]'))[1]::int;

  if v_num is not null then
    -- The street comes from the best hit that has one, not from parsing the
    -- query: the data's own spelling of the street is the one the anchors are
    -- filed under.
    select p.street_key, p.lat as plat, p.lon as plon,
           p.addr_street, p.addr_locality, p.addr_region, p.addr_country
      into v_top
    from unnest(v_ids) with ordinality u(uid, ord)
    join public.place_index p on p.id = u.uid
    where p.street_key is not null
    order by u.ord
    limit 1;

    if v_top.street_key is not null then
      select * into v_pin
      from public._place_index_interpolate(
             v_num, v_top.street_key, v_top.plat, v_top.plon);

      -- 'exact' means a place is already recorded at that number, and it is
      -- already in the list below. Only a computed point is worth prepending.
      if v_pin.lat is not null and v_pin.match_kind <> 'exact' then
        return query select
          'interp:' || v_top.street_key || ':' || v_num,
          v_num || ' ' || coalesce(
            initcap(v_top.street_key), split_part(v_top.addr_street, ',', 1)),
          null::text,
          v_num || ' ' || coalesce(
            initcap(v_top.street_key), split_part(v_top.addr_street, ',', 1)),
          v_top.addr_locality, v_top.addr_region, null::text, v_top.addr_country,
          v_pin.lat, v_pin.lon,
          1.0::real,
          v_pin.match_kind,
          v_pin.note;
      end if;
    end if;
  end if;

  return query
  select p.id, p.name, p.category, p.addr_street, p.addr_locality,
         p.addr_region, p.addr_postcode, p.addr_country, p.lat, p.lon,
         v_scores[u.ord], 'place'::text, null::text
  from unnest(v_ids) with ordinality u(uid, ord)
  join public.place_index p on p.id = u.uid
  order by u.ord;
end;
$$;

revoke execute on function public.search_place_index(text, int) from public;
grant execute on function public.search_place_index(text, int) to authenticated;
