-- P10-D5 / checklist S3-2 — PARTIAL purge of the seeded demo data.
--
-- Client ruling 2026-08-12 (partial, not the full purge the inventory proposed)
-- and 2026-08-13 (S0-1 backup WAIVED: "nothing needs backup, this is all just
-- dummy data, nothing is real all just test"). There is NO restore point. The
-- guard and post-condition blocks below are therefore the only safety net, and
-- they abort rather than guess.
--
--   DELETE  pod_uploads       photo_url = 'insights-demo/pod-placeholder.jpg'   33
--   DELETE  reconciliations   metadata->>'seed' = 'portal_demo_v1'              1
--   DELETE  haul_routes       metadata->>'seed' = 'portal_demo_v1'              1
--   DELETE  vehicle_positions source = 'portal_demo_v1'                         2
--
--   KEEP    the 38 seeded trips and 38 seeded transactions (client wants the
--           dashboards to still show movement), showcase_data (the BANNER is the
--           defect, not the rows — P10-D8), and the UI-test stockpile.
--
-- delivered_tons is nulled on every seeded trip IN THE SAME migration, because
-- deleting the 33 PODs without it leaves 38 trips carrying a delivered figure
-- and a fabricated 0.2000 t variance whose only evidence was just deleted —
-- the precise fiction P10-D1 exists to stop. variance_tons is generated over
-- delivered_tons, so it goes NULL by construction and reads as NOT COMPARABLE.
-- net_tons is untouched: shipped tonnage and trip counts survive.
--
-- WHAT THE CLIENT MUST BE TOLD: total recorded tonnage stays ~1,193.7 t, of
-- which 1,123.7 t (94.1%) REMAINS INVENTED by their explicit choice. Any
-- dashboard "verification" against those totals is verification against
-- fiction and must be labelled as such, never recorded as proven.
--
-- No begin/commit wrapper: apply_migration supplies the transaction, and a
-- nested one would make the file disagree with schema_migrations.statements.

-- ---------------------------------------------------------------- guard
do $$
declare
  v_pods            int;
  v_recons          int;
  v_routes          int;
  v_positions       int;
  v_seeded_trips    int;
  v_real_pods_seed  int;
begin
  select count(*) into v_pods
    from public.pod_uploads
   where photo_url = 'insights-demo/pod-placeholder.jpg';

  select count(*) into v_recons
    from public.reconciliations
   where metadata->>'seed' = 'portal_demo_v1';

  select count(*) into v_routes
    from public.haul_routes
   where metadata->>'seed' = 'portal_demo_v1';

  select count(*) into v_positions
    from public.vehicle_positions
   where source = 'portal_demo_v1';

  select count(*) into v_seeded_trips
    from public.trips
   where transaction_id in (
     select id from public.transactions
      where metadata->>'seed' in ('insights_demo_20260803', 'portal_demo_v1'));

  -- The interlock that matters most: if a REAL proof of delivery has since been
  -- recorded against a seeded trip, nulling that trip's delivered_tons would
  -- destroy a measured figure. Refuse rather than guess.
  select count(*) into v_real_pods_seed
    from public.pod_uploads p
   where p.photo_url is distinct from 'insights-demo/pod-placeholder.jpg'
     and p.trip_id in (
       select t.id from public.trips t
        where t.transaction_id in (
          select id from public.transactions
           where metadata->>'seed' in ('insights_demo_20260803', 'portal_demo_v1')));

  -- Cold replay 2026-08-18: on a freshly built database every one of these is
  -- zero, because the seed data this migration exists to purge was never
  -- inserted. Aborting there is the guard misfiring on the one case where there
  -- is provably nothing to do — and it stopped a rebuild. A drift check still
  -- fires for any NON-empty database that disagrees with the inventory.
  if v_pods = 0 and v_recons = 0 and v_routes = 0 and v_positions = 0
     and v_seeded_trips = 0 then
    raise notice 'P10-D5 skipped - no seeded demo data present (a fresh build).';
    return;
  end if;

  if v_pods <> 33 or v_recons <> 1 or v_routes <> 1 or v_positions <> 2
     or v_seeded_trips <> 38 then
    raise exception
      'P10-D5 aborted - live counts have drifted from the approved inventory. '
      'Expected pods=33 recons=1 routes=1 positions=2 seeded_trips=38; '
      'found pods=% recons=% routes=% positions=% seeded_trips=%.',
      v_pods, v_recons, v_routes, v_positions, v_seeded_trips;
  end if;

  if v_real_pods_seed <> 0 then
    raise exception
      'P10-D5 aborted - % real POD(s) now sit on seeded trips. Nulling '
      'delivered_tons would destroy a measured delivery figure.',
      v_real_pods_seed;
  end if;
end $$;

-- ---------------------------------------------------------------- 1/4  PODs
delete from public.pod_uploads
 where photo_url = 'insights-demo/pod-placeholder.jpg';

-- ---------------------------------------------------------------- 2/4  recon
delete from public.reconciliations
 where metadata->>'seed' = 'portal_demo_v1';

-- ---------------------------------------------------------------- 3/4  routes
delete from public.haul_routes
 where metadata->>'seed' = 'portal_demo_v1';

-- ---------------------------------------------------------------- 4/4  pings
-- Only the 2 seeded pings. The other 54 vehicle_positions rows are
-- source = 'driver_app' - real GPS from the live-tracking verification - and stay.
delete from public.vehicle_positions
 where source = 'portal_demo_v1';

-- ------------------------------------------------- companion: the delivered figure
update public.trips
   set delivered_tons = null
 where transaction_id in (
   select id from public.transactions
    where metadata->>'seed' in ('insights_demo_20260803', 'portal_demo_v1'))
   and delivered_tons is not null;

-- ---------------------------------------------------------------- post-conditions
do $$
declare
  v_left_pods        int;
  v_left_recons      int;
  v_left_routes      int;
  v_left_positions   int;
  v_seeded_delivered int;
  v_real_delivered   int;
  v_net              numeric;
begin
  -- Cold replay 2026-08-18, second half of the same fault as the guard above.
  -- The purge is a no-op on a database that never had the seed data, so these
  -- post-conditions are asserting the outcome of work that correctly did not
  -- happen. `expected 2 real trips still carrying delivered_tons, found 0` is
  -- true and meaningless on a fresh build. Skip when there is no seeded data
  -- left AND none of the real rows the purge is supposed to preserve exist
  -- either -- i.e. an empty database, not a purge that silently did nothing.
  if not exists (select 1 from public.trips)
     and not exists (select 1 from public.pod_uploads) then
    raise notice 'P10-D5 post-conditions skipped - empty database (a fresh build).';
    return;
  end if;

  select count(*) into v_left_pods
    from public.pod_uploads where photo_url = 'insights-demo/pod-placeholder.jpg';
  select count(*) into v_left_recons
    from public.reconciliations where metadata->>'seed' = 'portal_demo_v1';
  select count(*) into v_left_routes
    from public.haul_routes where metadata->>'seed' = 'portal_demo_v1';
  select count(*) into v_left_positions
    from public.vehicle_positions where source = 'portal_demo_v1';

  select count(*) into v_seeded_delivered
    from public.trips
   where delivered_tons is not null
     and transaction_id in (
       select id from public.transactions
        where metadata->>'seed' in ('insights_demo_20260803', 'portal_demo_v1'));

  select count(*) into v_real_delivered
    from public.trips
   where delivered_tons is not null
     and (transaction_id is null or transaction_id not in (
       select id from public.transactions
        where metadata->>'seed' in ('insights_demo_20260803', 'portal_demo_v1')));

  select coalesce(sum(net_tons), 0) into v_net from public.trips;

  if v_left_pods <> 0 or v_left_recons <> 0 or v_left_routes <> 0
     or v_left_positions <> 0 or v_seeded_delivered <> 0 then
    raise exception 'P10-D5 post-condition failed - pods=% recons=% routes=% '
      'positions=% seeded_trips_still_delivered=%',
      v_left_pods, v_left_recons, v_left_routes, v_left_positions, v_seeded_delivered;
  end if;

  -- The 2 real PODs and their trips must have survived intact. A purge that
  -- silently took the only evidence-backed figures with it is the worst outcome
  -- available here, so it is asserted rather than assumed.
  if v_real_delivered <> 2 then
    raise exception 'P10-D5 post-condition failed - expected 2 real trips still '
      'carrying delivered_tons, found %', v_real_delivered;
  end if;

  -- net_tons must be untouched: the client kept the trips precisely so the
  -- dashboards still show movement.
  if round(v_net, 2) <> 1193.70 then
    raise exception 'P10-D5 post-condition failed - total net_tons moved from '
      '1193.70 to %. This migration must not touch net_tons.', v_net;
  end if;
end $$;