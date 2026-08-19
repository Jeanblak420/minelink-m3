-- The address search failed for the first person to use it after a quiet spell.
--
-- Measured 2026-08-17, against the live extras project, before changing
-- anything. Four identical requests for "Sandton", two seconds apart:
--
--     attempt 1   3.60s   HTTP 500  57014 canceling statement due to timeout
--     attempt 2   3.64s   HTTP 500  57014 canceling statement due to timeout
--     attempt 3   0.97s   HTTP 200
--     attempt 4   0.30s   HTTP 200
--
-- It is a cold buffer cache, not a broken query. Once warm the same searches
-- answer in a quarter of a second. But `search_place_index` runs as `anon` on
-- a free-plan instance whose statement timeout is ~3s, and a cold FTS scan over
-- 611,841 rows does not finish inside it.
--
-- This matters more than a slow search, because of how it fails. The
-- place-index stage degrades to nothing by design (`_placeIndexLookup` swallows
-- the error so a paused project cannot break the picker), and the chain falls
-- through to Nominatim -- which cannot answer South African addresses, which is
-- the entire reason `place_index` exists. So the user gets worse results, no
-- error, and nothing in any log. It reads as "the picker got worse".
--
-- WHY THE EXISTING HEARTBEAT DID NOT PREVENT IT. `ping_extras_project()` has
-- been firing every six hours and returning HTTP 200 throughout -- correctly,
-- because its job was to stop the project being paused after ~7 idle days, and
-- it does that. But it searches for the literal word 'keepalive', which matches
-- nothing in a South African place index. The response body is `[]`. The FTS
-- predicate finds zero candidates and returns immediately, touching almost no
-- index or heap pages. It proves the project is awake; it leaves it cold.
--
-- Warm latencies measured across five real terms after the instance woke:
--
--     keepalive               0.41s   0 rows   <- what the heartbeat asked for
--     Westway Road Fourways   0.26s   1 row
--     Rosebank                0.85s   3 rows
--     Emalahleni              1.78s   3 rows
--     Polokwane               2.34s   3 rows
--
-- Note the top of that range: 2.34s against a ~3s ceiling, *warm*. There is
-- very little headroom, which is why going cold is fatal rather than merely
-- slow.
--
-- THE FIX HERE, AND THE ONE THAT IS NOT HERE.
--
--   * This migration makes the heartbeat do real work -- a term that actually
--     returns rows -- and rotates it hourly across the country so different
--     regions of the index stay resident rather than one hot spot. Hourly
--     rather than four times a day because six hours was demonstrably long
--     enough to go cold.
--
--   * It does NOT raise the statement timeout, which is the other half and
--     belongs on the extras project:
--
--         alter role anon in database postgres set statement_timeout = '8s';
--
--     That cannot be applied from here. `.mcp.json` pins the MAIN project ref,
--     so every MCP tool lands on the app database (CLAUDE.md §1/§10.2), and the
--     Management API query endpoint refuses this environment's token with HTTP
--     403. Reaching the extras project with anything more than `anon` needs a
--     credential this session does not have. Flagged for Jean rather than
--     worked around.
--
-- Both projects are free plan, so this costs 24 small requests a day from
-- main's pg_cron -- which is where it must live: an app-side heartbeat only
-- fires when somebody opens the app, and the case this exists for is precisely
-- the quiet stretch when nobody has.
--
-- ---------------------------------------------------------------------------
-- CORRECTION, same day, after re-measuring 43 minutes past a heartbeat.
--
-- Calling this "a cold cache" was too kind, and hourly warming does not solve
-- it. Six consecutive requests, warm instance:
--
--     Sandton      3.77s  500 57014
--     Sandton      2.13s  200
--     Rosebank     1.07s  200
--     Polokwane    3.75s  500 57014
--     Emalahleni   2.36s  200
--     Durban       3.26s  500 57014
--
-- "Durban" is the third-largest city in the country and it times out *warm*.
-- The query is simply too slow for a 3s ceiling on this instance for a good
-- share of ordinary terms; warmth shifts the odds, it does not fix the shape.
--
-- The warming above is still worth keeping (a genuinely cold instance fails
-- every time rather than some of the time), but the two real fixes are:
--
--   1. raise the ceiling -- `alter role anon in database postgres set
--      statement_timeout = '8s';` on the extras project, which needs a
--      credential this environment does not have; and
--   2. make `search_place_index` cheaper, which is also a change to a project
--      only reachable with that credential.
--
-- What COULD be done from this repo was done: `place_search_service.dart` now
-- retries once, and only on 57014, because a repeat of a timed-out query
-- usually lands (3.77s fail -> 2.13s success). Pinned by
-- `test/place_index_timeout_test.dart`. That is mitigation, not a cure.

create or replace function public.ping_extras_project()
returns bigint
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_request_id bigint;
  v_terms text[] := array[
    'johannesburg', 'durban', 'pretoria', 'cape town', 'gqeberha',
    'bloemfontein', 'polokwane', 'mbombela', 'kimberley', 'rustenburg',
    'emalahleni', 'sandton'
  ];
  v_term text;
begin
  -- Rotate by the hour. A single fixed term keeps one corner of the index hot
  -- and leaves the rest cold, which is the shape of the bug being fixed; twelve
  -- provinces' worth of names spread the resident pages around. Deterministic
  -- rather than random so a slow hour can be reproduced.
  v_term := v_terms[(extract(hour from now())::int % array_length(v_terms, 1)) + 1];

  select net.http_post(
    url     => 'https://qbydiuplqhmkaxarnuza.supabase.co/rest/v1/rpc/search_place_index',
    body    => jsonb_build_object('p_query', v_term, 'p_limit', 5),
    headers => jsonb_build_object(
                 'Content-Type', 'application/json',
                 'apikey', 'sb_publishable_YgnuGC-X2e69OHrbj-TC3A_U7crcLqz'
               ),
    timeout_milliseconds => 15000
  ) into v_request_id;

  return v_request_id;
end;
$function$;

comment on function public.ping_extras_project() is
  'Keeps the extras project (place_index) awake AND its index warm. Searches a '
  'real place name that returns rows, rotated hourly across the country -- the '
  'previous version asked for the literal word "keepalive", matched nothing, '
  'and so left the buffer cache cold. A cold search exceeds the ~3s anon '
  'statement timeout and the address picker degrades silently to Nominatim '
  '(20260817270000).';

-- Hourly. Six hours was measured to be long enough to go cold.
select cron.alter_job(
  (select jobid from cron.job where jobname = 'ping-extras-project'),
  schedule => '7 * * * *'
);
