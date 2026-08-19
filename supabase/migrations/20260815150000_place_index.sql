-- A place index MineLink owns, so address search stops depending on data that
-- does not exist.
--
-- Why this table exists, measured 2026-08-15 against the live services:
--
--   * OpenStreetMap has NO record of "Trumpet on Keyes" (Overpass: 0 objects
--     named "Trumpet" anywhere near Rosebank), and no Westway Road in Fourways
--     at all. Nominatim and Photon both read OSM, so neither can ever find
--     them — and neither can LocationIQ or Geoapify, which read it too.
--   * Overture Maps DOES hold them: "15 Westway Rd, Fourways" and "39 Westway
--     Rd" both carry coordinates, alongside 789,680 named places across
--     southern Africa, 92% of them with a street address.
--
-- Overture places are open data (CDLA-Permissive-2.0) built from Meta,
-- Microsoft, Foursquare and OSM contributions. No API key, no billing, no
-- per-query terms — which is the constraint CLAUDE.md §4 puts on this feature
-- and the reason a commercial geocoder was not used instead.
--
-- The table is EMPTY on purpose. Loading it needs database credentials this
-- environment does not hold (CLAUDE.md §6 — no SUPABASE_DB_PASSWORD), so the
-- import runs from tools/overture_import.py. Until it does, the RPC simply
-- returns nothing and the picker falls through to Nominatim exactly as before.

create extension if not exists pg_trgm with schema extensions;

create table if not exists public.place_index (
  -- Overture's GERS id: stable across releases, so a re-import updates rows
  -- rather than duplicating them.
  id            text primary key,
  name          text not null,
  category      text,
  addr_street   text,
  addr_locality text,
  addr_region   text,
  addr_postcode text,
  addr_country  text,
  -- Overture's own 0..1 confidence. Used to break ties, never to hide rows.
  confidence    real,
  lat           double precision not null,
  lon           double precision not null,
  -- One column to match against, so a query naming a business AND its street
  -- ("Micro-Ctrl Westway") can hit both halves. Generated, so it cannot drift
  -- out of step with the columns it is built from.
  search_text   text generated always as (
    coalesce(name, '') || ' ' ||
    coalesce(addr_street, '') || ' ' ||
    coalesce(addr_locality, '') || ' ' ||
    coalesce(addr_region, '') || ' ' ||
    coalesce(addr_postcode, '')
  ) stored,
  constraint place_index_lat_valid check (lat between -90 and 90),
  constraint place_index_lon_valid check (lon between -180 and 180)
);

comment on table public.place_index is
  'Overture Maps places (CDLA-Permissive-2.0) for southern Africa. Read-only '
  'reference data, loaded by tools/overture_import.py. Reached only through '
  'search_place_index(); the table itself carries no grant.';

-- gin_trgm_ops serves BOTH the ILIKE substring match and the similarity
-- ordering in the RPC. Without it, either one is a sequential scan over ~790k
-- rows on every keystroke.
create index if not exists place_index_search_trgm
  on public.place_index using gin (search_text extensions.gin_trgm_ops);

-- Reference data with no owner: RLS on, no policy, no grant. Every read goes
-- through the SECURITY DEFINER function below, which is the only thing that
-- can see it. Same shape as monthly_targets (CLAUDE.md §4).
alter table public.place_index enable row level security;

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
language sql
stable
security definer
set search_path = public, extensions
as $$
  select p.id, p.name, p.category, p.addr_street, p.addr_locality,
         p.addr_region, p.addr_postcode, p.addr_country, p.lat, p.lon,
         greatest(
           similarity(p.search_text, p_query),
           word_similarity(p_query, p.search_text)
         )::real as score
  from public.place_index p
  where length(btrim(p_query)) >= 3
    and (
      -- Substring first: "13 Westway Rd" must reach "15 Westway Rd" rows even
      -- when the whole-string similarity is low because the numbers differ.
      p.search_text ilike '%' || btrim(p_query) || '%'
      or p.search_text % btrim(p_query)
    )
  order by score desc, p.confidence desc nulls last, p.name
  limit least(greatest(coalesce(p_limit, 6), 1), 20);
$$;

comment on function public.search_place_index(text, int) is
  'Address/business lookup over the Overture place index. Reference data with '
  'nothing user-specific in it, so it is readable by any signed-in user; anon '
  'holds no grant because the app never searches while signed out.';

revoke execute on function public.search_place_index(text, int) from public;
grant execute on function public.search_place_index(text, int) to authenticated;
