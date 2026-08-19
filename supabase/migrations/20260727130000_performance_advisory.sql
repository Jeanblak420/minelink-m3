-- Performance advisory pass from the 2026-07-27 audit. Applied live to
-- project yftazblpmicqtamyiwyb. Idempotent / re-runnable.
--
-- Two changes, both semantics-preserving:
--   1. Add the two missing FK covering indexes.
--   2. Collapse duplicate permissive SELECT policies: fold each
--      *_select_super_admin policy into its table's main SELECT policy as
--      `OR is_super_admin()` (an exact permissive union), then drop the extra
--      policy — so one fewer policy is evaluated per row. Super-admin read
--      access is unchanged.
--
-- Intentionally NOT merged (would change write scope; low value, 0-few rows):
--   mineral_loads (main policy is FOR ALL), org_connections (FOR ALL),
--   token_requests INSERT pair. Left as-is.

CREATE INDEX IF NOT EXISTS security_confirmations_security_user_id_idx
  ON public.security_confirmations (security_user_id);
CREATE INDEX IF NOT EXISTS mine_locations_company_location_id_idx
  ON public.mine_locations (company_location_id);

ALTER POLICY employees_select_self_or_company_managers ON public.employees
  USING (((user_id = (select auth.uid())) OR is_company_manager(company_id) OR is_super_admin()));
DROP POLICY IF EXISTS employees_select_super_admin ON public.employees;

ALTER POLICY fleet_vehicles_select_company_staff ON public.fleet_vehicles
  USING ((is_company_staff(company_id) OR is_super_admin()));
DROP POLICY IF EXISTS fleet_vehicles_select_super_admin ON public.fleet_vehicles;

ALTER POLICY gate_checks_select_company_staff ON public.gate_checks
  USING ((is_company_staff(company_id) OR is_super_admin()));
DROP POLICY IF EXISTS gate_checks_select_super_admin ON public.gate_checks;

ALTER POLICY haul_routes_select ON public.haul_routes
  USING ((is_company_staff(supplier_company_id) OR is_company_staff(buyer_company_id) OR is_super_admin()));
DROP POLICY IF EXISTS haul_routes_select_super_admin ON public.haul_routes;

ALTER POLICY reconciliations_select ON public.reconciliations
  USING ((is_company_staff(buyer_company_id) OR is_company_staff(supplier_company_id) OR is_company_staff(transporter_company_id) OR is_super_admin()));
DROP POLICY IF EXISTS reconciliations_select_super_admin ON public.reconciliations;

ALTER POLICY security_incidents_select_company_staff ON public.security_incidents
  USING ((is_company_staff(company_id) OR is_super_admin()));
DROP POLICY IF EXISTS security_incidents_select_super_admin ON public.security_incidents;

ALTER POLICY transactions_select_company_staff ON public.transactions
  USING ((is_company_staff(supplier_company_id) OR is_company_staff(buyer_company_id) OR is_company_staff(transporter_company_id) OR is_super_admin()));
DROP POLICY IF EXISTS transactions_select_super_admin ON public.transactions;

ALTER POLICY trips_select ON public.trips
  USING ((EXISTS ( SELECT 1 FROM transactions t WHERE ((t.id = trips.transaction_id) AND (is_company_staff(t.supplier_company_id) OR is_company_staff(t.buyer_company_id) OR is_company_staff(t.transporter_company_id)))) OR is_super_admin()));
DROP POLICY IF EXISTS trips_select_super_admin ON public.trips;

ALTER POLICY weighbridge_records_select_company_staff ON public.weighbridge_records
  USING ((is_company_staff(company_id) OR is_super_admin()));
DROP POLICY IF EXISTS weighbridge_records_select_super_admin ON public.weighbridge_records;

ALTER POLICY profiles_select_own ON public.profiles
  USING (((id = (select auth.uid())) OR is_super_admin()));
DROP POLICY IF EXISTS profiles_select_super_admin ON public.profiles;

-- vehicle_positions (hottest table): fold buyer-via-trips into the main policy
-- and drop the redundant super-admin policy (main already grants is_platform_admin()).
ALTER POLICY vehicle_positions_select ON public.vehicle_positions
  USING ((is_platform_admin()
    OR (EXISTS ( SELECT 1 FROM fleet_vehicles fv WHERE ((fv.id = vehicle_positions.vehicle_id) AND is_company_staff(fv.company_id))))
    OR (EXISTS ( SELECT 1 FROM (trips t JOIN transactions txn ON ((txn.id = t.transaction_id))) WHERE ((t.id = vehicle_positions.trip_id) AND (is_company_staff(txn.supplier_company_id) OR is_company_staff(txn.buyer_company_id) OR is_company_staff(txn.transporter_company_id)))))
    OR (EXISTS ( SELECT 1 FROM (trips tr JOIN transactions tx ON ((tx.id = tr.transaction_id))) WHERE ((tr.vehicle_id = vehicle_positions.vehicle_id) AND is_company_staff(tx.buyer_company_id))))));
DROP POLICY IF EXISTS vehicle_positions_select_super_admin ON public.vehicle_positions;
DROP POLICY IF EXISTS vehicle_positions_select_buyer_via_trips ON public.vehicle_positions;

-- Fully-redundant super-admin SELECT policies (already covered by a broader policy).
DROP POLICY IF EXISTS "Super admins can read all seats" ON public.organization_seats;
DROP POLICY IF EXISTS "Super admins can read all seat requests" ON public.token_requests;
