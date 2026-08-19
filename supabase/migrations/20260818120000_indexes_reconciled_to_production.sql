-- Bring the indexes the FILES build into line with the ones production HAS.
--
-- The last of the nine schema shapes to differ. Jean's call, 2026-08-18: adopt
-- production, retire the rest — the same rule applied to the RLS policies in
-- 20260818100000.
--
-- Most of this difference turned out to be RENAMING rather than missing work:
-- the same column, the same btree, under two spellings, because 70 migration
-- files in this repo have no ledger row and a cold replay runs them all while
-- production got its indexes another way.
--
--   production                          the files
--   idx_audit_logs_action               audit_logs_action_type_idx
--   idx_audit_logs_actor                audit_logs_actor_created_idx
--   idx_audit_logs_created              audit_logs_created_at_idx
--   idx_audit_logs_org                  audit_logs_org_id_created_idx
--   serial_tokens_organization_id_idx   serial_tokens_org_id_idx
--   seat_requests_organization_id_idx   token_requests_org_id_idx
--
-- The pairs are not always identical — `idx_audit_logs_actor` is on
-- (actor_user_id) where the file's is on (actor_user_id, created_at), and
-- `idx_audit_logs_created` is DESC. Adopting production means taking its exact
-- definitions, not assuming a rename is a rename.
--
-- RETIRED. Indexes the files create that production has never had. Each is a
-- reasonable performance index that somebody wrote; none has ever existed on
-- the live system, so nothing is being taken away from anything that runs:
--
--   companies_org_type_status_idx, companies_status_idx,
--   companies_token_expires_at_idx, organization_seats_org_id_status_idx,
--   profiles_platform_role_idx, serial_tokens_created_at_idx,
--   serial_tokens_status_expires_idx, token_requests_status_created_idx
--
-- ⚠️ If any of those are actually wanted, the correct move is to ADD them to
-- production in their own migration and re-accept the parity baseline — not to
-- leave them here, where they make a rebuilt database quietly differ from the
-- live one forever. That is a performance decision, deliberately separated from
-- this reconciliation.
--
-- NOT APPLIED TO PRODUCTION: it already holds exactly this state. The proof is
-- the replay — after this file the rebuilt `indexes` fingerprint must equal
-- production's.

begin;

-- ---------------------------------------------------------- adopt production
create index if not exists idx_audit_logs_action
  on public.audit_logs using btree (action_type);
create index if not exists idx_audit_logs_actor
  on public.audit_logs using btree (actor_user_id);
create index if not exists idx_audit_logs_created
  on public.audit_logs using btree (created_at desc);
create index if not exists idx_audit_logs_org
  on public.audit_logs using btree (organization_id);
create index if not exists serial_tokens_organization_id_idx
  on public.serial_tokens using btree (organization_id);
create index if not exists seat_requests_organization_id_idx
  on public.token_requests using btree (organization_id);

-- ------------------------------------------------------------- retire the rest
drop index if exists public.audit_logs_action_type_idx;
drop index if exists public.audit_logs_actor_created_idx;
drop index if exists public.audit_logs_created_at_idx;
drop index if exists public.audit_logs_org_id_created_idx;
drop index if exists public.companies_org_type_status_idx;
drop index if exists public.companies_status_idx;
drop index if exists public.companies_token_expires_at_idx;
drop index if exists public.organization_seats_org_id_status_idx;
drop index if exists public.profiles_platform_role_idx;
drop index if exists public.serial_tokens_created_at_idx;
drop index if exists public.serial_tokens_org_id_idx;
drop index if exists public.serial_tokens_status_expires_idx;
drop index if exists public.token_requests_org_id_idx;
drop index if exists public.token_requests_status_created_idx;

commit;
