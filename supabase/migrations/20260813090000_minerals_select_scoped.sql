-- P3-44 / checklist S2-2 — narrow the `minerals` SELECT policy.
--
-- `minerals_select_authenticated ... USING (true)` was the only SELECT policy
-- on the table, so every authenticated user on the platform could read every
-- mine's mineral catalogue: name, grade and tonnage, for companies they have
-- no relationship with. On a multi-tenant B2B platform a competitor's product
-- catalogue is commercially sensitive in the same way its seat and token data
-- is, which is what `companies_select_scoped` (20260812150000) settled.
--
-- MEASURED BLAST RADIUS, live, before applying:
--   * 2 rows total, across 2 companies, 0 orphans (no null company_id).
--   * The ONLY app reader is OperationsService.getMinerals(companyId), which
--     already issues `.eq('company_id', companyId)`. Narrowing the policy to
--     own-company therefore cannot change a single screen — the client was
--     already asking for exactly the rows this policy now permits.
--   * The write policies were ALREADY scoped: insert/update/delete all use
--     `is_company_manager(company_id)`. Only SELECT was blanket-true, so this
--     brings reads in line with writes rather than introducing a new model.
--
-- Client ruling 2026-08-13: own-company + platform admin. Counterparty
-- visibility was offered and NOT taken — no screen reads another company's
-- catalogue today, and a predicate that grants more than any caller asks for
-- is a liability, not future-proofing. Add `is_company_counterparty(company_id)`
-- if a buyer is ever meant to browse a linked mine's catalogue.

drop policy if exists minerals_select_authenticated on public.minerals;

create policy minerals_select_scoped
  on public.minerals
  for select
  to authenticated
  using (
    -- Each helper is wrapped in a scalar subquery so Postgres evaluates it
    -- ONCE per statement instead of once per row (the same initplan issue as
    -- auth.uid(), and the same treatment companies_select_scoped uses).
    (select public.is_platform_admin())
    or company_id = (select public.current_company_id())
  );

comment on policy minerals_select_scoped on public.minerals is
  'P3-44/S2-2: own-company + platform admin. Replaced USING (true), which '
  'exposed every mine''s catalogue platform-wide. Writes were already scoped '
  'by is_company_manager(company_id). Counterparty reads deliberately NOT '
  'granted (client ruling 2026-08-13) — no caller needs them.';
