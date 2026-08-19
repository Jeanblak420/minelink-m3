-- Security/performance hygiene batch (from Supabase advisors, 2026-07-16 audit).
--
-- 1. Pin search_path on the 4 remaining functions flagged by the
--    function_search_path_mutable lint (pinned to 'public' — their bodies use
--    unqualified table refs, so '' would break them).
-- 2. chat-attachments: drop the broad public SELECT policy on storage.objects.
--    The bucket is public, so object serving via /object/public/ URLs (the only
--    way the app reads it — getPublicUrl) does not consult RLS; the policy's
--    sole effect was letting any client LIST the whole bucket
--    (public_bucket_allows_listing lint).
-- 3. Revoke anon SELECT grants on super-admin platform tables. RLS already
--    returns zero rows for anon, but the grants expose the tables in the
--    GraphQL schema (pg_graphql_anon_table_exposed lint) — pure hygiene.
-- 4. Covering indexes for the hottest unindexed FKs on logistics-path tables.
-- 5. Data cleanup: one 2026-05-10 demo-seed trip stuck in legacy status
--    'active' (parses as en_route_to_offload) polluted active-trip/live-map
--    views for two months — close it out as cancelled.

begin;

-- 1. Pin function search_path -------------------------------------------------
alter function public.check_seat_reassignment_allowed(uuid) set search_path = public;
alter function public.reassign_seat(uuid, uuid, text, text, text) set search_path = public;
alter function public.generate_seat_serial(text) set search_path = public;
alter function public.submit_seat_token_request(uuid, integer, integer, text) set search_path = public;

-- 2. chat-attachments: no more bucket listing ---------------------------------
drop policy if exists chat_attach_read on storage.objects;

-- 3. Anon grant hygiene on platform tables ------------------------------------
revoke select on public.audit_logs from anon;
revoke select on public.organization_seats from anon;
revoke select on public.platform_admin_settings from anon;
revoke select on public.serial_tokens from anon;
revoke select on public.token_requests from anon;
revoke select on public.seat_reassignment_log from anon;

-- 4. Covering indexes for hot logistics FKs -----------------------------------
create index if not exists driver_assignments_company_id_idx
  on public.driver_assignments (company_id);
create index if not exists pod_uploads_transaction_id_idx
  on public.pod_uploads (transaction_id);
create index if not exists margin_ledger_route_id_idx
  on public.margin_ledger (route_id);
create index if not exists margin_ledger_request_id_idx
  on public.margin_ledger (request_id);
create index if not exists request_dispatches_dispatched_by_idx
  on public.request_dispatches (dispatched_by);

-- 5. Close out the stale legacy demo trip -------------------------------------
update public.trips
set status = 'cancelled', updated_at = now()
where id = '353de412-493d-455c-acc6-2512c276f7ba' and status = 'active';

commit;
