-- Keep the Mine-Link_Extra_Data project from pausing.
--
-- THE PROBLEM
-- -----------
-- Supabase pauses FREE projects after ~7 days of low activity, and both of this
-- account's projects are free. The extras project (qbydiuplqhmkaxarnuza) now
-- serves the address picker, which is used irregularly — a quiet week is
-- entirely plausible.
--
-- The failure mode is what makes this worth a migration rather than a note. A
-- paused project does not return an error the app surfaces: the picker's
-- place-index stage degrades to nothing by design and the search falls through
-- to Nominatim, so the user sees *fewer and worse results* and no warning at
-- all. It reads as "the picker got worse", not as "a database is down", and it
-- would stay that way until somebody noticed and resumed it by hand.
--
-- WHY THE PING LIVES HERE AND NOT IN THE APP
-- ------------------------------------------
-- An app-side heartbeat only fires when somebody opens the app, which is
-- exactly the assumption that fails over a holiday — the case this exists for.
-- The main project, by contrast, is never idle: it carries the whole product,
-- so its pg_cron always runs. Pinning the extras project's liveness to the main
-- project's liveness is the strongest guarantee available without paying for a
-- plan or adding an external service.
--
-- (If main is ever quiet enough to pause too, the whole product is down and
-- this is not the alarm anybody needs.)
--
-- WHY IT MUST REACH POSTGRES, NOT JUST THE GATEWAY
-- ------------------------------------------------
-- Supabase measures *database* activity. A request the gateway rejects — a 401
-- from a missing or wrong key — never reaches Postgres and so does not count.
-- The ping therefore calls a real RPC with the publishable key, and
-- search_place_index is granted to `anon` on that project precisely so this
-- works without a session.
--
-- The key below is a PUBLISHABLE key. It is designed to ship in clients and is
-- already in config/place_index.live.json and in every built artifact; it is not
-- a secret and CLAUDE.md §1's "never hardcode secrets" is not in play. The
-- database password and the sbp_ management token are the secrets, and neither
-- appears here or anywhere in this repo.

-- `with schema extensions`, not a bare create. A bare `create extension pg_net`
-- registers it in `public`, which the security advisor flags as
-- `extension_in_public` — Supabase keeps extensions out of the exposed schema
-- so their objects cannot reach PostgREST. pg_net does NOT support
-- `alter extension ... set schema` (it owns its own `net` schema), so getting
-- this wrong means dropping and recreating it rather than moving it.
-- Its functions still live in `net`; only the extension's registration moves.
create extension if not exists pg_net with schema extensions;

create or replace function public.ping_extras_project()
returns bigint
language plpgsql
security definer
set search_path = public
as $$
declare
  v_request_id bigint;
begin
  select net.http_post(
    url     => 'https://qbydiuplqhmkaxarnuza.supabase.co/rest/v1/rpc/search_place_index',
    -- A real query, not a sentinel: search_place_index returns immediately for
    -- anything under 3 characters without touching the table, and a round trip
    -- that never reads a row is a weaker claim to "activity" than one that does.
    -- It runs four times a day; the cost is irrelevant.
    body    => '{"p_query":"keepalive","p_limit":1}'::jsonb,
    headers => jsonb_build_object(
                 'Content-Type', 'application/json',
                 'apikey', 'sb_publishable_YgnuGC-X2e69OHrbj-TC3A_U7crcLqz'
               ),
    timeout_milliseconds => 15000
  ) into v_request_id;

  return v_request_id;
end;
$$;

comment on function public.ping_extras_project() is
  'Keeps the Mine-Link_Extra_Data project (qbydiuplqhmkaxarnuza) from being '
  'paused for inactivity by issuing a real RPC against it four times a day. '
  'Free projects pause after ~7 quiet days, and a paused extras project makes '
  'the address picker silently return fewer results rather than raising an '
  'error. pg_net is async and fire-and-forget; responses land in '
  'net._http_response.';

-- Cron-only. Not an API.
revoke execute on function public.ping_extras_project() from public, anon, authenticated;

select cron.unschedule('ping-extras-project')
where exists (select 1 from cron.job where jobname = 'ping-extras-project');

-- Every six hours: four requests a day, comfortably past Supabase's "a few user
-- requests to the database each day", and spread so a single failed run cannot
-- cost a whole day of activity. Offset from the nightly notification jobs.
select cron.schedule(
  'ping-extras-project',
  '7 */6 * * *',
  'select public.ping_extras_project()'
);
