begin;

-- Allow platform super admins to read cross-company logistics / operations rows for dashboards.

drop policy if exists transactions_select_super_admin on public.transactions;
create policy transactions_select_super_admin on public.transactions
  for select to authenticated
  using (public.is_super_admin());

drop policy if exists trips_select_super_admin on public.trips;
create policy trips_select_super_admin on public.trips
  for select to authenticated
  using (public.is_super_admin());

drop policy if exists haul_routes_select_super_admin on public.haul_routes;
create policy haul_routes_select_super_admin on public.haul_routes
  for select to authenticated
  using (public.is_super_admin());

drop policy if exists fleet_vehicles_select_super_admin on public.fleet_vehicles;
create policy fleet_vehicles_select_super_admin on public.fleet_vehicles
  for select to authenticated
  using (public.is_super_admin());

drop policy if exists vehicle_positions_select_super_admin on public.vehicle_positions;
create policy vehicle_positions_select_super_admin on public.vehicle_positions
  for select to authenticated
  using (public.is_super_admin());

drop policy if exists reconciliations_select_super_admin on public.reconciliations;
create policy reconciliations_select_super_admin on public.reconciliations
  for select to authenticated
  using (public.is_super_admin());

drop policy if exists weighbridge_records_select_super_admin on public.weighbridge_records;
create policy weighbridge_records_select_super_admin on public.weighbridge_records
  for select to authenticated
  using (public.is_super_admin());

drop policy if exists mineral_loads_select_super_admin on public.mineral_loads;
create policy mineral_loads_select_super_admin on public.mineral_loads
  for select to authenticated
  using (public.is_super_admin());

drop policy if exists security_incidents_select_super_admin on public.security_incidents;
create policy security_incidents_select_super_admin on public.security_incidents
  for select to authenticated
  using (public.is_super_admin());

drop policy if exists gate_checks_select_super_admin on public.gate_checks;
create policy gate_checks_select_super_admin on public.gate_checks
  for select to authenticated
  using (public.is_super_admin());

commit;
