-- Seven columns, one type, and one column production had already dropped.
--
-- Found 2026-08-18 by fingerprinting every table's columns on a database
-- rebuilt from git and comparing with production. 66 of 69 tables matched
-- exactly; these three did not, and every difference is another out-of-band
-- change with no migration behind it — the same class as
-- `seat_reassignment_log`, `organization_seats.role_binding` and the expiry
-- cron job. This is the fourth time this session that pattern has cost
-- something real.
--
-- MISSING FROM A REBUILD (present in production, no file adds them):
--
--   companies.company_admin_user_id   uuid
--   companies.created_by              uuid
--   companies.seats_available         integer not null default 0
--   companies.support_contact_email   text
--   companies.token_assigned_at       timestamptz
--   organization_seats.serial_number  text
--   organization_seats.token_id       uuid
--
-- `organization_seats.serial_number` is worth pausing on: the orphaned ledger
-- row from 2026-05-04 is named `add_seat_reassignment_log_and_serial_numbers`,
-- and the "serial numbers" half of that name is exactly this column. The name
-- was the only surviving record of what the migration did.
--
-- WRONG TYPE:
--
--   audit_logs.target_id is `text` in production and `uuid` from the files.
--   Not cosmetic — the audit log records targets that are not UUIDs (a seat
--   serial, an email, a token reference), and a rebuilt database would reject
--   every one of those inserts at run time while looking perfectly healthy.
--
-- REMOVED, because production removed it:
--
--   organization_seats.occupied_by_employee_id — created by 20260510181500 and
--   last referenced by 20260712170000, which is why this file is stamped after
--   that one.
--
-- Everything below is idempotent and matches the live catalog read on
-- 2026-08-18.

begin;

alter table public.companies
  add column if not exists company_admin_user_id uuid,
  add column if not exists created_by uuid,
  add column if not exists seats_available integer not null default 0,
  add column if not exists support_contact_email text,
  add column if not exists token_assigned_at timestamptz;

alter table public.organization_seats
  add column if not exists serial_number text,
  add column if not exists token_id uuid;

-- `using` is required: uuid -> text is not an assignment cast.
alter table public.audit_logs
  alter column target_id type text using target_id::text;

alter table public.organization_seats
  drop column if exists occupied_by_employee_id;

-- The indexes that go WITH those columns.
--
-- Added in the same breath as a correction: the first version of this file
-- reconstructed the columns and stopped there, and the next index diff showed
-- production carrying four indexes the rebuild did not. Three of them index
-- columns this very file adds — a column restored without its index is only
-- half restored, and the miss is invisible until something is slow.
-- `idx_audit_logs_target` is the fourth, on the target_id whose type this file
-- also corrects.
create index if not exists companies_company_admin_user_id_idx
  on public.companies using btree (company_admin_user_id);
create index if not exists companies_created_by_idx
  on public.companies using btree (created_by);
create index if not exists organization_seats_token_id_idx
  on public.organization_seats using btree (token_id);
create index if not exists idx_audit_logs_target
  on public.audit_logs using btree (target_id);

comment on column public.organization_seats.serial_number is
  'Seat serial. Reconstructed 2026-08-18 — reached production with no migration '
  'file; the only record of it was the name of an orphaned ledger row.';
comment on column public.audit_logs.target_id is
  'Free-text target reference, NOT a uuid: a seat serial, an email or a token '
  'reference may appear here. Corrected 2026-08-18 after a rebuild from git '
  'produced a uuid column that would have rejected those rows.';

commit;
