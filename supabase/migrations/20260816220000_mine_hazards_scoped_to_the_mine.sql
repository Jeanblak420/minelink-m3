-- A hazard reaches the drivers going to that mine, and nobody else.
--
-- ============================================================================
-- THE RULING
-- ============================================================================
-- Client, 2026-08-16:
--
--   "only drivers should be able to publish to and for drivers, additionally
--    mine admins and or mine managers and or mine owners should also be able
--    to publish it to any and all drivers which are scheduled to collect tons
--    from stockpiles located on their mines and or who's already on their way
--    to the mine, basically any drivers who still needs to go to the mine, is
--    already on their way, is at the mine and or is not yet scheduled to go to
--    the mine but later that day gets allocated to go to the mine for
--    collection ... and not to drivers who are going to other mines and or
--    will not be going to the mine where the hazzard has been broadcasted."
--
-- ============================================================================
-- WHAT IT WAS
-- ============================================================================
-- `mine_hazards` had nine columns and not one of them said which mine. There
-- was nothing to scope by, so the policies did not scope:
--
--     mine_hazards_select_all   USING (true)
--     mine_hazards_insert_own   WITH CHECK (reported_by = auth.uid())
--
-- The first means every authenticated user on the platform sees every hazard.
-- The second means **anyone at all can publish to drivers** — a buyer's
-- accountant, a security guard at an unrelated mine — because the only
-- condition is that you write your own id in the author column, which is not a
-- permission, it is a signature.
--
-- `get_nearby_hazards` is SECURITY DEFINER, so it bypassed RLS entirely and
-- returned every hazard within the radius regardless. A driver heading to mine
-- A got mine B's hazards, and the pin on the map said nothing about which.
--
-- The table is empty (0 rows on production, 2026-08-16), so `mine_company_id`
-- can be added NOT NULL with no backfill and no grandfathered rows.
--
-- ============================================================================
-- WHO MAY PUBLISH
-- ============================================================================
--   * a DRIVER, for a mine they are actually going to. "Only drivers publish
--     to drivers" is the rule; requiring a live trip to that mine is what
--     stops it becoming "any driver publishes to any mine", which would be the
--     same open door in a smaller doorway. A driver reporting a washout on the
--     approach road still qualifies — they are en route to that mine.
--   * the MINE's owner, admin or management, for their own mine. Exactly the
--     three the client named; supervisorForeman is deliberately NOT included,
--     because it was not asked for and this is a broadcast to third parties.
--
-- ============================================================================
-- WHO RECEIVES, AND WHY IT IS A POLICY RATHER THAN A FAN-OUT
-- ============================================================================
-- The clause that decides the design is "is not yet scheduled to go to the
-- mine but later that day gets allocated". The audience is therefore NOT
-- knowable when the hazard is published — a driver assigned an hour later must
-- still receive it.
--
-- A fan-out (rows written per recipient at publish time) cannot express that
-- without a re-scan. Evaluating membership at READ time does it for free: the
-- policy asks "is this driver going to that mine *now*", so a driver allocated
-- later starts seeing the hazard the moment they are allocated, and a driver
-- whose trip is re-routed stops.
--
-- "Going to the mine" means a trip that has not yet left it:
--   scheduled · en_route_to_load · arrived_at_mine · loading · loaded
-- `loaded` is included because the truck is still standing on the mine.
-- `left_mine` onward is excluded — they are gone, and a hazard at that mine no
-- longer concerns them.
--
-- ============================================================================
-- WHY get_nearby_hazards STOPS BEING SECURITY DEFINER
-- ============================================================================
-- Because the alternative is writing the audience rule twice. A DEFINER
-- function has to re-implement the policy in its own WHERE clause, and the two
-- copies drift — that is how the original bypass happened. As INVOKER the RLS
-- policy is the single definition and the RPC cannot disagree with it.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 1. Which mine
-- ---------------------------------------------------------------------------
alter table public.mine_hazards
  add column if not exists mine_company_id uuid references public.companies(id) on delete cascade;

-- Empty table, so this is safe and there is nothing to backfill. Asserted
-- rather than assumed: if rows appear before this runs, fail loudly instead of
-- silently leaving unscoped hazards behind.
do $$
begin
  if exists (select 1 from public.mine_hazards where mine_company_id is null) then
    raise exception
      'mine_hazards has rows with no mine_company_id — backfill them before '
      'applying 20260816220000; an unscoped hazard is visible to nobody once '
      'the new policies land.';
  end if;
end $$;

alter table public.mine_hazards alter column mine_company_id set not null;

create index if not exists mine_hazards_mine_company_idx
  on public.mine_hazards (mine_company_id);
-- The read path is "unexpired hazards near me", so the expiry filter belongs
-- in the index too.
create index if not exists mine_hazards_live_idx
  on public.mine_hazards (mine_company_id, expires_at);

comment on column public.mine_hazards.mine_company_id is
  'The mine this hazard concerns. Decides both who may publish it and which '
  'drivers receive it — see 20260816220000.';

-- ---------------------------------------------------------------------------
-- 2. Is this driver going to that mine?
-- ---------------------------------------------------------------------------
create or replace function public.driver_is_heading_to_mine(p_mine_company_id uuid)
returns boolean
language sql
stable
security definer
set search_path to 'public'
as $function$
  select exists (
    select 1
    from public.employees e
    join public.driver_assignments da on da.driver_employee_id = e.id
    join public.trips t on t.vehicle_id = da.vehicle_id
    join public.transactions x on x.id = t.transaction_id
    where e.user_id = auth.uid()
      and e.role = 'driver'
      and e.status = 'active'
      and e.is_dismissed = false
      and x.supplier_company_id = p_mine_company_id
      -- has not yet left the mine
      and t.status in ('scheduled','en_route_to_load','arrived_at_mine','loading','loaded')
  );
$function$;

comment on function public.driver_is_heading_to_mine(uuid) is
  'True when the caller is an active driver with a trip to this mine that has '
  'not yet left it. Evaluated at read time so a driver allocated later that '
  'day starts receiving the mine''s hazards immediately (20260816220000).';

-- ---------------------------------------------------------------------------
-- 3. May the caller publish for this mine?
-- ---------------------------------------------------------------------------
create or replace function public.may_publish_mine_hazard(p_mine_company_id uuid)
returns boolean
language sql
stable
security definer
set search_path to 'public'
as $function$
  select
    -- a driver going to that mine
    public.driver_is_heading_to_mine(p_mine_company_id)
    -- or the mine's own owner / admin / management
    or public.has_company_role(p_mine_company_id, array['admin','management']);
$function$;

comment on function public.may_publish_mine_hazard(uuid) is
  'Only drivers heading to the mine, and that mine''s owner/admin/management, '
  'may broadcast a hazard for it. has_company_role() already covers the owner.';

-- ---------------------------------------------------------------------------
-- 4. The policies
-- ---------------------------------------------------------------------------
drop policy if exists mine_hazards_select_all on public.mine_hazards;
drop policy if exists mine_hazards_insert_own on public.mine_hazards;

-- READ: the mine's own staff, the drivers going there, and platform admin.
create policy mine_hazards_select_scoped on public.mine_hazards
  for select
  using (
    public.is_platform_admin()
    or public.is_company_staff(mine_company_id)
    or public.driver_is_heading_to_mine(mine_company_id)
  );

-- WRITE: signed by the author AND authorised for that mine. The signature was
-- previously the only condition; it is now the lesser half.
create policy mine_hazards_insert_scoped on public.mine_hazards
  for insert
  with check (
    reported_by = (select auth.uid())
    and public.may_publish_mine_hazard(mine_company_id)
  );

-- UPDATE / DELETE stay platform-admin only, unchanged, plus the author may
-- withdraw their own — a hazard that has cleared should be retractable by the
-- person who reported it rather than requiring an admin.
drop policy if exists mine_hazards_delete_own on public.mine_hazards;
create policy mine_hazards_delete_own on public.mine_hazards
  for delete
  using (reported_by = (select auth.uid()));

-- ---------------------------------------------------------------------------
-- 5. The RPC stops bypassing all of the above
-- ---------------------------------------------------------------------------
-- Was SECURITY DEFINER, so it returned every hazard in the radius to anyone
-- who called it. As INVOKER the policy above is the only definition of who
-- sees what, and this function cannot drift from it.
--
-- `mine_company_id` is returned so the caller can say WHICH mine a pin belongs
-- to; the old shape could not.
drop function if exists public.get_nearby_hazards(double precision, double precision, integer);

create or replace function public.get_nearby_hazards(
  lat double precision,
  lng double precision,
  radius_meters integer default 5000
)
returns table(
  id integer,
  hazard_type character varying,
  severity character varying,
  description text,
  latitude double precision,
  longitude double precision,
  distance_meters double precision,
  reported_at timestamp with time zone,
  expires_at timestamp with time zone,
  mine_company_id uuid
)
language sql
stable
security invoker
set search_path to ''
as $function$
  with p as (
    select lat as plat, lng as plng, radius_meters::double precision as r,
      (radius_meters / 111320.0) as dlat,
      (radius_meters / (111320.0 * greatest(cos(radians(lat)), 0.01))) as dlng
  ),
  hav as (
    select mh.*,
      (6371000.0 * 2 * asin(sqrt(
        power(sin(radians(mh.latitude - p.plat) / 2), 2) +
        cos(radians(p.plat)) * cos(radians(mh.latitude)) *
        power(sin(radians(mh.longitude - p.plng) / 2), 2)))) as distance_meters,
      p.r as r
    from public.mine_hazards mh, p
    where mh.latitude between p.plat - p.dlat and p.plat + p.dlat
      and mh.longitude between p.plng - p.dlng and p.plng + p.dlng
      and (mh.expires_at is null or mh.expires_at > now())
  )
  select hav.id, hav.hazard_type, hav.severity, hav.description, hav.latitude,
         hav.longitude, hav.distance_meters, hav.reported_at, hav.expires_at,
         hav.mine_company_id
  from hav where hav.distance_meters <= hav.r order by hav.distance_meters asc;
$function$;

grant execute on function public.get_nearby_hazards(double precision, double precision, integer)
  to authenticated;

comment on function public.get_nearby_hazards(double precision, double precision, integer) is
  'Hazards near a point, scoped by RLS to the caller. SECURITY INVOKER on '
  'purpose: as DEFINER it bypassed the policy and returned every mine''s '
  'hazards to every driver (20260816220000).';
