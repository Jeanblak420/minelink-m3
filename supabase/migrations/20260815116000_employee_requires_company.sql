-- 20260815116000_employee_requires_company.sql
--
-- An employee may not exist without a company, except while they are still
-- waiting to join one. Client ruling 2026-08-15: a company creates its own
-- staff (or the super global admin does it on the company's behalf), so an
-- employee belonging to nobody is not a state the product has a meaning for.
--
-- 45 rows were in exactly that state: `status = 'active'` with `company_id`
-- NULL, all created 2026-03-29. They could do nothing at all -- every scope in
-- the schema keys off a company -- but they counted as active staff, which is
-- how they came to light: the seat backfill could seat 42 of 87 and no more,
-- because the other 45 had no company to be seated at. All have since been
-- assigned to companies and seated.
--
-- WHY THE EXCEPTION IS `pending_company` AND NOT NOTHING
--
-- `complete_employee_signup` deliberately creates a company-less row: somebody
-- signs up, and only afterwards asks to join a company via
-- `request_company_link`. That row is `pending_company` and is legitimate. A
-- blanket NOT NULL would break self-signup entirely. So the invariant is the
-- narrower true one: company_id may be null ONLY while pending_company.
--
-- The one row left in that state is the WhatsApp OTP test account
-- (`wa-27820000777@wa.mineralguide.com`), moved from `inactive` to
-- `pending_company` -- which is what it actually is: a signup that never
-- joined anybody.
--
-- NOT VALID is deliberate: it validates every future insert and update while
-- skipping the one-time full-table scan. The table was verified clean first
-- (0 violating rows), and the constraint is validated immediately below, so
-- this is about lock duration on a live table, not about tolerating bad rows.

alter table public.employees
  drop constraint if exists employees_company_required;

alter table public.employees
  add constraint employees_company_required
  check (company_id is not null or status = 'pending_company')
  not valid;

alter table public.employees
  validate constraint employees_company_required;

comment on constraint employees_company_required on public.employees is
  'An employee belongs to a company. The only company-less state is '
  'pending_company - a self-signup that has not joined one yet '
  '(complete_employee_signup -> request_company_link). See 20260815116000.';
