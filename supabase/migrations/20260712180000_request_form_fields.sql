-- Request form fields (CLAUDE.md §4 Request 2/3): price per ton, transaction
-- kind (FOB/FOT) and free-text product specifications on transportation_requests.
--
-- RESTORED FILE — these three columns were applied to the live database
-- out-of-band (remote migration history records `request_form_fields`) but the
-- migration file was missing from git, so a schema rebuilt purely from
-- migrations lacked them and later migrations (20260712220000) that read
-- `transaction_kind` / `product_specifications` failed to apply. Idempotent
-- ALTERs, matching the live column types.

begin;

alter table public.transportation_requests
  add column if not exists price_per_ton numeric,
  add column if not exists transaction_kind text,
  add column if not exists product_specifications text;

commit;
