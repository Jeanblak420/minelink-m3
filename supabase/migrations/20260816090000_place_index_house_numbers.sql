-- House-number precision, by interpolation.
--
-- The picker can find the right street but not the right number: searching
-- "13 westway road, fourways" returns the business at 15 Westway Rd, because
-- that is the nearest thing anybody has recorded.
--
-- No open dataset can fix that by having number 13 in it. Overture's ADDRESSES
-- theme — the one built from OpenAddresses, which is exactly this — holds
-- **0 points for the whole of southern Africa** (measured 2026-08-16). South
-- Africa publishes no open address file, so there is nothing to load.
--
-- But house numbers run monotonically along a street, and the places table
-- already carries anchors: 15 Westway Rd at (-26.033955, 27.998734) and
-- 39 Westway Rd at (-26.038164, 28.002432). Two anchors fix the whole block.
-- Fitting 13 against them lands at (-26.033604, 27.998426) — 49.7 m up-street
-- from 15, which is where number 13 is. This is how commercial geocoders
-- answer numbers they have never seen.
--
-- Everything here is derived from data already loaded. No new download, no new
-- table, and the result is always LABELLED as interpolated: a pin a driver is
-- routed to must not claim precision it does not have.

-- ---------------------------------------------------------------------------
-- 1. Pull the number and the street out of the free-form address line
-- ---------------------------------------------------------------------------

-- "15 Westway Rd, Fourways" -> 15.  Leading digits only: a number in the
-- middle ("Shop 12A, Pineslopes") is a unit, not a street number, and guessing
-- otherwise puts the pin on the wrong road entirely.
create or replace function public.place_house_number(p_addr text)
returns int
language sql
immutable
parallel safe
set search_path = ''
as $$
  select case
           when p_addr ~ '^\s*\d{1,5}\s' or p_addr ~ '^\s*\d{1,5}[a-zA-Z]?\s'
           then (regexp_match(p_addr, '^\s*(\d{1,5})'))[1]::int
         end;
$$;

-- "15 Westway Rd, Fourways" -> "westway rd".
--
-- Everything after the first comma is locality, not street. The suffix is
-- canonicalised because the SAME street appears both ways in the source —
-- "39 Westway Rd" and "Westway Road" are one street, and if they normalise
-- differently the two anchors never meet and no interpolation is possible.
--
-- Written as a lookup on the last word rather than a regex with per-branch
-- replacements, which Postgres cannot express: the mapping stays readable and
-- can be extended without rewriting an alternation.
create or replace function public.place_street_key(p_addr text)
returns text
language plpgsql
immutable
parallel safe
set search_path = ''
as $$
declare
  s text;
  head text;
  tail text;
begin
  s := lower(btrim(split_part(coalesce(p_addr, ''), ',', 1)));
  s := regexp_replace(s, '^\s*\d{1,5}[a-z]?\s+', '');   -- drop house number
  s := regexp_replace(s, '[^a-z0-9 ]+', ' ', 'g');      -- punctuation out
  s := btrim(regexp_replace(s, '\s+', ' ', 'g'));
  if s = '' then return null; end if;

  head := regexp_replace(s, '\s+\S+$', '');             -- all but last word
  tail := regexp_replace(s, '^.*\s', '');               -- last word
  if head = s then head := ''; end if;                  -- single-word street

  tail := case tail
    when 'road' then 'rd'        when 'rd' then 'rd'
    when 'avenue' then 'ave'     when 'ave' then 'ave'   when 'av' then 'ave'
    when 'street' then 'st'      when 'st' then 'st'     when 'str' then 'st'
    when 'drive' then 'dr'       when 'dr' then 'dr'
    when 'boulevard' then 'blvd' when 'blvd' then 'blvd'
    when 'lane' then 'ln'        when 'ln' then 'ln'
    when 'crescent' then 'cres'  when 'cres' then 'cres'
    when 'close' then 'cl'       when 'cl' then 'cl'
    when 'place' then 'pl'       when 'pl' then 'pl'
    when 'terrace' then 'ter'    when 'ter' then 'ter'
    when 'highway' then 'hwy'    when 'hwy' then 'hwy'
    else tail
  end;

  return btrim(head || ' ' || tail);
end;
$$;

alter table public.place_index
  add column if not exists house_number int,
  add column if not exists street_key   text;

update public.place_index
   set house_number = public.place_house_number(addr_street),
       street_key   = public.place_street_key(addr_street)
 where addr_street is not null
   and (house_number is null and street_key is null);

-- Anchors only: a row with no number cannot anchor an interpolation, and there
-- are ~59k of those. Partial index keeps it small.
create index if not exists place_index_street_number
  on public.place_index (street_key, house_number)
  where house_number is not null and street_key is not null;

-- ---------------------------------------------------------------------------
-- 2. Interpolate
-- ---------------------------------------------------------------------------

create or replace function public._place_index_interpolate(
  p_number int,
  p_street text,
  p_lat    double precision,
  p_lon    double precision
)
returns table (
  lat        double precision,
  lon        double precision,
  match_kind text,
  note       text
)
language plpgsql
stable
security definer
set search_path = public, extensions
as $$
declare
  a record;  -- nearest anchor at or below the wanted number
  b record;  -- nearest anchor above it
  f double precision;
begin
  if p_number is null or p_street is null then return; end if;

  -- Anchors are kept near the match on purpose. Street names repeat across the
  -- country — there is a "Main Rd" in every town — so anchoring on name alone
  -- would happily interpolate between Cape Town and Polokwane. 5 km is wide
  -- enough for a long suburban road and far too narrow to cross a city.
  select p.house_number as n, p.lat, p.lon into a
  from public.place_index p
  where p.street_key = p_street and p.house_number is not null
    and p.house_number <= p_number
    and abs(p.lat - p_lat) < 0.045
    and abs(p.lon - p_lon) < 0.05
  order by p.house_number desc
  limit 1;

  select p.house_number as n, p.lat, p.lon into b
  from public.place_index p
  where p.street_key = p_street and p.house_number is not null
    and p.house_number > p_number
    and abs(p.lat - p_lat) < 0.045
    and abs(p.lon - p_lon) < 0.05
  order by p.house_number asc
  limit 1;

  -- Dead on.
  if a.n = p_number then
    return query select a.lat, a.lon, 'exact'::text,
                        format('number %s', p_number);
    return;
  end if;

  -- Bracketed: the ordinary case, and the accurate one.
  if a.n is not null and b.n is not null and b.n <> a.n then
    f := (p_number - a.n)::double precision / (b.n - a.n);
    return query select a.lat + f * (b.lat - a.lat),
                        a.lon + f * (b.lon - a.lon),
                        'interpolated'::text,
                        format('between %s and %s', a.n, b.n);
    return;
  end if;

  -- Below every known number (13 when the street starts at 15): take the two
  -- lowest and step backwards along the same gradient.
  if a.n is null and b.n is not null then
    declare c record;
    begin
      select p.house_number as n, p.lat, p.lon into c
      from public.place_index p
      where p.street_key = p_street and p.house_number is not null
        and p.house_number > b.n
        and abs(p.lat - p_lat) < 0.045
        and abs(p.lon - p_lon) < 0.05
      order by p.house_number asc
      limit 1;

      if c.n is not null and c.n <> b.n then
        f := (p_number - b.n)::double precision / (c.n - b.n);
        return query select b.lat + f * (c.lat - b.lat),
                            b.lon + f * (c.lon - b.lon),
                            'interpolated'::text,
                            format('projected from %s and %s', b.n, c.n);
        return;
      end if;

      return query select b.lat, b.lon, 'nearest'::text,
                          format('nearest known number is %s', b.n);
      return;
    end;
  end if;

  -- Above every known number: same, stepping forward.
  if a.n is not null and b.n is null then
    declare c record;
    begin
      select p.house_number as n, p.lat, p.lon into c
      from public.place_index p
      where p.street_key = p_street and p.house_number is not null
        and p.house_number < a.n
        and abs(p.lat - p_lat) < 0.045
        and abs(p.lon - p_lon) < 0.05
      order by p.house_number desc
      limit 1;

      if c.n is not null and c.n <> a.n then
        f := (p_number - a.n)::double precision / (a.n - c.n);
        return query select a.lat + f * (a.lat - c.lat),
                            a.lon + f * (a.lon - c.lon),
                            'interpolated'::text,
                            format('projected from %s and %s', c.n, a.n);
        return;
      end if;

      return query select a.lat, a.lon, 'nearest'::text,
                          format('nearest known number is %s', a.n);
      return;
    end;
  end if;
end;
$$;

revoke execute on function
  public._place_index_interpolate(int, text, double precision, double precision)
  from public, anon, authenticated;
