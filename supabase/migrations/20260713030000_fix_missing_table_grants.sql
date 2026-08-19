-- Fix systemic missing table grants.
--
-- Several tables added in the 2026-07-12/13 migrations had RLS policies created
-- for the `authenticated` role, but the base-table privileges were never GRANTed.
-- PostgREST/Postgres check table-level privileges BEFORE evaluating RLS, so every
-- client read returned `42501: permission denied for table <t>` (HTTP 403) even
-- though the RLS policy would have allowed the row. Because the failure is at the
-- privilege layer, RLS still governs which rows are visible after this grant.
--
-- Symptoms this fixes (all frontend-visible):
--   * transporter could not see/accept dispatched routes (routes embed 403 killed
--     the whole request_dispatches query),
--   * Reconciliations "Edited versions" panel threw a raw PostgrestException,
--   * driver->truck resolution / fleet / available-routes / driver-limits reads,
--   * chat read-receipts and seat reassignment logs.
--
-- Idempotent: GRANT is a no-op if the privilege already exists.

-- SELECT for every affected table (reads happen via direct PostgREST selects).
grant select on table
  public.routes,
  public.reconciliation_uploads,
  public.driver_assignments,
  public.route_assignments,
  public.driver_limit_requests,
  public.org_connections,
  public.chat_message_reads,
  public.seat_reassignment_log
to authenticated;

-- Tables whose RLS exposes write commands (ALL policies) also need write privileges.
-- (The other tables' writes go exclusively through SECURITY DEFINER RPCs, so they
-- intentionally receive SELECT only.)
grant insert, update, delete on table
  public.chat_message_reads,
  public.org_connections,
  public.seat_reassignment_log
to authenticated;
