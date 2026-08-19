-- The driver navigation destination silently answered a different question.
--
-- WHAT WAS MEASURED, 2026-08-16
-- -----------------------------
-- Trip 5e9ae6dd (Roadhaul S6W001GP, route RT-2AA06ECC) hauls Chrome Ore from
-- "Iron Hills Mine, Mpumalanga" to **"Durban Port"**. Asked for the offload
-- leg as the real assigned driver, this function returned:
--
--   {"found": true, "source": "company_location",
--    "lat": -26.1409765, "lng": 28.0359834,
--    "label": "Atlas Buyer Group — 2nd Floor, Trumpet On Keyes, 21 Keyes Ave,
--              Rosebank, Johannesburg"}
--
-- That is the buyer's OFFICE, in Johannesburg, roughly 570 km from the port
-- the load is going to. `found: true` is the part that does the damage: the
-- client's own fallback ladder — which would have geocoded the words "Durban
-- Port" through the staged place search, `place_index` included — never runs,
-- because the server already said it had the answer.
--
-- WHY IT WAS BUILT THIS WAY, AND WHAT WAS ACTUALLY WRONG WITH IT
-- -------------------------------------------------------------
-- The chain (request link → the party company's primary saved location →
-- plain address) is right. The bug is that step 2 was allowed to OVERRULE the
-- named point rather than stand behind it. A company's primary location is a
-- sensible answer to "where is this company", and it is a guess at "where is
-- this load going". Those coincide for a mine — one gate, always the same one,
-- which is why the load leg has never misbehaved — and they routinely do not
-- for a buyer, who receives at ports, sidings, yards and mills that are
-- nothing to do with the address on their letterhead.
--
-- A wrong destination that announces itself is a nuisance. A wrong destination
-- delivered as a confident coordinate, on a screen with no destination name on
-- it at all, is a truck in the wrong province.
--
-- THE FIX
-- -------
-- The function now REPORTS what it knows instead of choosing for the client:
--
--   * `point_name` — the offloading/loading point exactly as the request words
--     it, always present when there is one. This is the driver's actual
--     instruction and the UI can finally show it.
--   * a coordinate + `found: true` ONLY when the coordinate genuinely
--     describes that named point — i.e. it came from a `?q=lat,lng` link on
--     the request itself, or the named point is absent and the company's
--     primary location is all there is.
--   * `fallback` — the party company's primary saved location, offered as a
--     last resort rather than as the answer.
--
-- So when a request names a place in words, the client geocodes THOSE WORDS
-- first (its ladder reaches MineLink's own `place_index`, which Postgres
-- cannot: it lives on the second Supabase project, CLAUDE.md §10.2), and only
-- falls back to the company pin when nothing can be made of them. Behaviour
-- for a mine with a primary collection point and no named point is unchanged.
--
-- Return type is still `jsonb`, so `create or replace` is legal here — no OUT
-- columns to widen (MIGRATION_HYGIENE / CLAUDE.md §6).

create or replace function public.get_trip_nav_destination(
  p_trip_id uuid,
  p_leg text default 'load'
) returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_point text;      -- request/metadata loading_point or offloading_point
  v_company uuid;    -- fallback company (mine for load, buyer for offload)
  v_company_name text;
  v_link text;
  v_loc_name text;
  v_lat double precision;
  v_lng double precision;
  v_fallback jsonb := null;
begin
  if p_leg not in ('load', 'offload') then
    raise exception 'p_leg must be load or offload';
  end if;

  select
    case when p_leg = 'load'
      then coalesce(r.loading_point,  txn.metadata->>'loading_point',  t.metadata->>'loading_point')
      else coalesce(r.offloading_point, txn.metadata->>'offloading_point', t.metadata->>'offloading_point')
    end,
    case when p_leg = 'load' then txn.supplier_company_id else txn.buyer_company_id end,
    case when p_leg = 'load' then sc.company_name else bc.company_name end
  into v_point, v_company, v_company_name
  from public.trips t
  join public.transactions txn on txn.id = t.transaction_id
  left join public.request_dispatches d on d.id = t.dispatch_id
  left join public.transportation_requests r on r.id = d.request_id
  left join public.companies sc on sc.id = txn.supplier_company_id
  left join public.companies bc on bc.id = txn.buyer_company_id
  where t.id = p_trip_id
    and (
      public.is_platform_admin()
      or public.is_company_staff(txn.supplier_company_id)
      or public.is_company_staff(txn.buyer_company_id)
      or public.is_company_staff(txn.transporter_company_id)
    );

  if not found then
    raise exception 'Trip not found or not yours';
  end if;

  v_point := nullif(btrim(coalesce(v_point, '')), '');

  -- The party company's primary saved location, resolved once and carried as
  -- a FALLBACK rather than returned as the answer.
  select cl.map_link, cl.name into v_link, v_loc_name
  from public.company_locations cl
  where cl.company_id = v_company and cl.is_primary
  limit 1;

  if v_link is not null
     and v_link ~ '[?&]q=-?\d+(\.\d+)?,-?\d+(\.\d+)?' then
    v_fallback := jsonb_build_object(
      'lat', (regexp_match(v_link, '[?&]q=(-?\d+(?:\.\d+)?),(-?\d+(?:\.\d+)?)'))[1]::double precision,
      'lng', (regexp_match(v_link, '[?&]q=(-?\d+(?:\.\d+)?),(-?\d+(?:\.\d+)?)'))[2]::double precision,
      'label', coalesce(v_company_name, '') || ' — ' || coalesce(v_loc_name, 'primary location'),
      'source', 'company_location');
  end if;

  -- 1. A coordinate link on the request/trip itself. This one really does
  --    describe the named point, so it is still the answer.
  if v_point is not null
     and v_point ~ '[?&]q=-?\d+(\.\d+)?,-?\d+(\.\d+)?' then
    v_lat := (regexp_match(v_point, '[?&]q=(-?\d+(?:\.\d+)?),(-?\d+(?:\.\d+)?)'))[1]::double precision;
    v_lng := (regexp_match(v_point, '[?&]q=(-?\d+(?:\.\d+)?),(-?\d+(?:\.\d+)?)'))[2]::double precision;
    return jsonb_build_object('found', true, 'lat', v_lat, 'lng', v_lng,
      'label', coalesce(v_company_name, 'Destination'),
      'source', 'request',
      'point_name', v_point,
      'fallback', v_fallback);
  end if;

  -- 2. The request names a place in WORDS. Hand the words back — the client
  --    geocodes them through the staged place search (saved company places →
  --    place_index → Nominatim → Photon), which is strictly better informed
  --    about South African addresses than anything reachable from here.
  if v_point is not null then
    return jsonb_build_object('found', false,
      'address', v_point,
      'point_name', v_point,
      'label', coalesce(v_company_name, 'Destination'),
      'source', 'address',
      'fallback', v_fallback);
  end if;

  -- 3. No named point at all. NOW the company's primary location is the best
  --    answer anyone has, and it is returned as one.
  if v_fallback is not null then
    return jsonb_build_object('found', true,
      'lat', v_fallback->'lat',
      'lng', v_fallback->'lng',
      'label', v_fallback->>'label',
      'source', 'company_location',
      'point_name', null,
      'fallback', v_fallback);
  end if;

  return jsonb_build_object('found', false, 'source', 'none',
    'point_name', null, 'fallback', null);
end;
$$;

comment on function public.get_trip_nav_destination(uuid, text) is
  'Where the driver drives for this leg. Returns a coordinate ONLY when it '
  'genuinely describes the point the request named (a ?q=lat,lng link), or '
  'when the request named no point at all. When the request names a place in '
  'words, those words come back as `address`/`point_name` with found=false so '
  'the client geocodes them through the staged place search; the party '
  'company''s primary saved location rides along as `fallback` for when that '
  'fails. Before 2026-08-17 the fallback was returned as the answer, which '
  'sent a Durban Port load to the buyer''s Rosebank office, 570 km away, with '
  'found=true so nothing downstream ever questioned it.';

revoke all on function public.get_trip_nav_destination(uuid, text) from public;
revoke all on function public.get_trip_nav_destination(uuid, text) from anon;
grant execute on function public.get_trip_nav_destination(uuid, text) to authenticated;
