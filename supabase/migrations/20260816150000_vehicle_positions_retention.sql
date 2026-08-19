-- GPS pings were kept forever. Nothing ever pruned them.
--
-- WHAT WAS MEASURED (2026-08-16, live, right after the outage)
-- ------------------------------------------------------------
--   public.vehicle_positions:  55 rows,  8 kB of data
--     heap ..........  16 kB
--     indexes .......  40 MB      <-- 2,500x the heap
--
--       vehicle_positions_vehicle_id_idx   17 MB
--       vehicle_positions_trip_idx         12 MB
--       vehicle_positions_pkey             11 MB
--
-- A REINDEX took those 40 MB down to 64 kB and the database from 477 MB to
-- 437 MB — 95.4% to 87.3% of the 500 MB free-tier ceiling — without touching a
-- single row. That is how much dead index was being carried.
--
-- The bloat itself is explained: a B-tree does not return emptied pages to the
-- OS on a plain VACUUM, so a table that churns hard keeps its index extent even
-- after the heap is truncated. What is NOT explained is why the churn was
-- unbounded, and that is the actual defect this migration fixes.
--
-- THE DEFECT
-- ----------
-- Drivers ping `record_vehicle_position` every 30 seconds while on a trip
-- (CLAUDE.md §4, live GPS tracking), and **nothing has ever deleted those rows**.
-- The only DELETE against this table in the whole migration history is the
-- one-off seed purge in 20260813092000, and none of the seven pg_cron jobs
-- touches it. So:
--
--     1 driver x 8-hour trip        =    960 rows/day
--     10 drivers                    =  9,600 rows/day  =  ~3.5M rows/year
--
-- on a 500 MB database that had 23 MB of headroom. Unbounded growth on the one
-- table with the highest write rate in the product.
--
-- RETENTION
-- ---------
-- 30 days. The live map reads only the newest position per vehicle
-- (list_live_trip_positions), so retention costs it nothing; what 30 days buys
-- is after-the-fact route replay and dispute evidence on a delivery, which is
-- the only reason to keep a ping at all once the truck has arrived.
--
-- Positions belonging to a trip that is still running are NEVER deleted,
-- however old. A trip that outlives the window is unusual, but losing the
-- track of a load still in transit is not a trade worth making.
--
-- The delete is BATCHED AND BOUNDED, for the reason written across this repo in
-- blood: on 2026-08-16 an unbounded bulk write against a ~790k-row table on
-- this exact free-tier instance locked autovacuum out, stalled the replication
-- slot, exhausted the connection pool and took Postgres down for two hours. A
-- nightly job that can quietly grow into a 3-million-row DELETE is the same
-- shape. It stops at 50k rows per night and picks up the next night; steady
-- state is a few thousand.

create or replace function public.prune_vehicle_positions_job(
  p_keep_days int default 30,
  p_max_rows  int default 50000
)
returns int
language plpgsql
security definer
set search_path = public
as $$
declare
  v_batch   int := 5000;
  v_deleted int := 0;
  v_round   int;
begin
  loop
    exit when v_deleted >= p_max_rows;

    delete from public.vehicle_positions
    where ctid in (
      select p.ctid
      from public.vehicle_positions p
      where p.recorded_at < now() - make_interval(days => p_keep_days)
        -- Never prune a load that is still moving.
        and (
          p.trip_id is null
          or not exists (
            select 1 from public.trips t
            where t.id = p.trip_id
              and t.status not in ('completed', 'cancelled')
          )
        )
      limit least(v_batch, p_max_rows - v_deleted)
    );

    get diagnostics v_round = row_count;
    exit when v_round = 0;
    v_deleted := v_deleted + v_round;
  end loop;

  if v_deleted > 0 then
    raise notice 'prune_vehicle_positions_job: deleted % rows', v_deleted;
  end if;
  return v_deleted;
end;
$$;

comment on function public.prune_vehicle_positions_job(int, int) is
  'Nightly retention for GPS pings: drops positions older than p_keep_days '
  '(default 30) except those on a still-running trip, in bounded batches '
  'capped at p_max_rows per run. Added 2026-08-16 — before this, nothing ever '
  'deleted from vehicle_positions and its indexes had reached 40 MB against a '
  '16 kB heap.';

-- Cron-only. This is not an API.
revoke execute on function public.prune_vehicle_positions_job(int, int)
  from public, anon, authenticated;

-- 03:40, between close-due-target-cycles (03:20) and notify-service-due (04:10),
-- so the nightly jobs do not overlap on a shared-CPU instance.
select cron.unschedule('prune-vehicle-positions')
where exists (select 1 from cron.job where jobname = 'prune-vehicle-positions');

select cron.schedule(
  'prune-vehicle-positions',
  '40 3 * * *',
  'select public.prune_vehicle_positions_job()'
);

-- NOTE ON REINDEX — deliberately not scheduled.
--
-- With retention in place the table stays small and autovacuum reuses the index
-- pages, so a recurring rebuild is not needed. It is also not schedulable here:
-- REINDEX ... CONCURRENTLY cannot run inside a transaction block and pg_cron
-- wraps every command in one, so it would fail nightly rather than quietly.
--
-- If this table is ever mass-purged again (as in 20260813092000), reclaim the
-- index extent by hand afterwards — that purge is exactly what left 40 MB
-- behind:
--
--     reindex table concurrently public.vehicle_positions;
