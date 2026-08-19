-- How many seals a rig carries becomes a FACT ABOUT THE RIG, not an inference.
--
-- 20260817300000 stopped a sealed load being recorded with two seals on a
-- four-seal interlink, and that part was right. But it worked out the number
-- like this:
--
--     2 * (first_trailer_regs is non-empty) + (second_trailer_regs is non-empty)
--
-- and those two columns are OPTIONAL FREE TEXT on the add-vehicle form,
-- labelled "1st trailer registration — Optional". So the count was derived from
-- whether somebody had bothered to type a registration number, which is not the
-- same question as how many seal points the vehicle has:
--
--   * a transporter who leaves the trailer regs blank on a two-trailer rig gets
--     told to fit 2 seals to a truck with 4 seal points — and the server then
--     REFUSES the correct load of 4;
--   * a rigid tipper with no trailer is told 2, which may or may not be right;
--   * nobody can state the truth, because there is nowhere to put it.
--
-- Raised with Jean in the session-4 handoff as "a product rule I inferred, not
-- one you gave me". This removes the inference instead of guessing better at
-- it: `fleet_vehicles.seal_points` is set once when the vehicle is created,
-- derived from its trailers as a starting point, and the transporter who owns
-- the truck can correct it. Nothing reads the trailer columns at load time any
-- more.
--
-- Capped at 4 because the waybill prints TRUCK SEAL SERIALNO. 1-4 (CLAUDE.md
-- §4) — above that a seal is recorded that no document can carry, which is how
-- one production load ended up with 13. Floored at 1 because a sealed route
-- with a zero-seal vehicle is a dispatch problem, not something to discover at
-- the weighbridge with a driver waiting.

begin;

-- ---------------------------------------------------------------------------
-- The starting point, in one place so the backfill and the trigger cannot
-- disagree. This is the OLD inference, kept only as an initial value.
-- ---------------------------------------------------------------------------
create or replace function public.derive_seal_points(
  p_first_trailer text,
  p_second_trailer text
)
returns smallint
language sql
immutable
as $$
  select greatest(1, least(4, (2 * (
      (case when coalesce(trim(p_first_trailer), '') <> '' then 1 else 0 end)
    + (case when coalesce(trim(p_second_trailer), '') <> '' then 1 else 0 end)
  ))))::smallint;
$$;

comment on function public.derive_seal_points(text, text) is
  'Starting value for fleet_vehicles.seal_points when a vehicle is created: two '
  'per trailer registration present, clamped to 1..4. Only ever an initial '
  'guess — the stored column is the authority, and the transporter can correct '
  'it. Nothing reads this at load time.';

-- A rig with neither trailer recorded is 0 by that formula; greatest(1, ...)
-- lifts it, but 2 is the honest default for a truck-and-trailer fleet and
-- matches what the old inference floored to.
alter table public.fleet_vehicles
  add column if not exists seal_points smallint;

update public.fleet_vehicles
   set seal_points = greatest(2, public.derive_seal_points(first_trailer_regs,
                                                           second_trailer_regs))
 where seal_points is null;

-- ---------------------------------------------------------------------------
-- Null means "not stated" and is resolved BEFORE the row lands, so no reader
-- ever has to fall back to an inference. Runs on update too, so clearing the
-- value is a way to ask for the default back rather than a way to break the
-- not-null.
-- ---------------------------------------------------------------------------
create or replace function public.fleet_vehicle_seal_points_default()
returns trigger
language plpgsql
as $$
begin
  if new.seal_points is null then
    new.seal_points := greatest(2, public.derive_seal_points(
      new.first_trailer_regs, new.second_trailer_regs));
  end if;
  return new;
end;
$$;

drop trigger if exists fleet_vehicles_seal_points_default on public.fleet_vehicles;
create trigger fleet_vehicles_seal_points_default
  before insert or update on public.fleet_vehicles
  for each row execute function public.fleet_vehicle_seal_points_default();

alter table public.fleet_vehicles
  alter column seal_points set not null;

alter table public.fleet_vehicles
  drop constraint if exists fleet_vehicles_seal_points_range;
alter table public.fleet_vehicles
  add constraint fleet_vehicles_seal_points_range
  check (seal_points between 1 and 4);

comment on column public.fleet_vehicles.seal_points is
  'Seal points on this rig — how many seals a sealed load must carry, enforced '
  'by record_truck_load. Derived from the trailer registrations when the '
  'vehicle is created and correctable by the transporter thereafter via '
  'set_vehicle_seal_points. Before 2026-08-17 this was inferred at load time '
  'from whether the OPTIONAL trailer-registration text had been filled in, so a '
  'blank registration silently changed how many seals the load needed.';

-- ---------------------------------------------------------------------------
-- expected_seal_count now READS rather than infers.
-- ---------------------------------------------------------------------------
create or replace function public.expected_seal_count(p_vehicle_id uuid)
returns int
language sql
stable
as $$
  -- 2 when the trip has no vehicle attached: the load still has to be sealed,
  -- and refusing to seal it at all would be worse than asking for the minimum.
  select coalesce(
    (select v.seal_points from public.fleet_vehicles v where v.id = p_vehicle_id),
    2
  )::int;
$$;

comment on function public.expected_seal_count(uuid) is
  'Seals a sealed load must carry on this vehicle: fleet_vehicles.seal_points, '
  'or 2 when the trip has no vehicle. record_truck_load enforces exactly this '
  'many, each with a number AND a photo, and the Load Controller''s sheet '
  'renders exactly this many slots. Until 2026-08-17 there was no count rule at '
  'all and production held a sealed load with 2 seals on a two-trailer rig and '
  'another with 13.';

grant execute on function public.expected_seal_count(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- The transporter states the truth about their own truck.
--
-- A small dedicated setter rather than a new parameter on update_fleet_vehicle,
-- matching set_route_quality_spec / set_primary_company_location: adding a
-- parameter changes the identity of a function that PostgREST resolves by named
-- argument, so it would mean dropping and recreating a 3.3k-character body to
-- carry one smallint.
-- ---------------------------------------------------------------------------
create or replace function public.set_vehicle_seal_points(
  p_vehicle_id uuid,
  p_seal_points smallint
)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_company uuid;
  v_row public.fleet_vehicles;
begin
  select company_id into v_company from public.fleet_vehicles where id = p_vehicle_id;
  if v_company is null then
    raise exception 'Vehicle % not found', p_vehicle_id;
  end if;
  if not public.can_manage_fleet(v_company) then
    raise exception 'Not authorized to manage this fleet';
  end if;
  if p_seal_points is null or p_seal_points < 1 or p_seal_points > 4 then
    raise exception
      'A rig carries between 1 and 4 seals — the waybill has four serial lines.';
  end if;

  update public.fleet_vehicles
     set seal_points = p_seal_points, updated_at = timezone('utc', now())
   where id = p_vehicle_id
   returning * into v_row;

  return to_jsonb(v_row);
end;
$$;

comment on function public.set_vehicle_seal_points(uuid, smallint) is
  'Set how many seals this rig carries. Guarded by can_manage_fleet, so only '
  'the transporter that owns the truck can say.';

revoke all on function public.set_vehicle_seal_points(uuid, smallint) from public, anon;
grant execute on function public.set_vehicle_seal_points(uuid, smallint) to authenticated;

commit;
