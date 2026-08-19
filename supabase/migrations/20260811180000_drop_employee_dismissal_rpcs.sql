-- P10-01 — Employee dismissal is removed from the product (client ruling, 2026-08-11).
--
-- Drops the three RPCs that make up the dismissal flow. They are the only writers
-- of the dismissal columns besides remove_company_employee(), which stays and is
-- the supported way to take someone off a company.
--
-- Verified against live production immediately before this migration:
--   employees.status = 'dismissed'                  ->  0 rows  (88 employees)
--   employees.is_dismissed = true                   ->  0
--   employees.is_dismissed_pending_appeal = true    ->  0
--   employees.is_dismissal_final = true             ->  0
--   employees.dismissal_date is not null            ->  0
--   notifications of a dismissal type               ->  0
--   employee_status_history dismissal rows          ->  0
--   other functions calling any of the three        ->  0
-- Nothing in production has ever used this flow, so no data migration is required
-- and no other function loses a dependency.
--
-- ⚠ employees.is_dismissed is NOT dropped and never will be. Nineteen functions
-- read it — including is_company_staff, is_company_manager, has_company_role and
-- are_chat_participants_allowed — plus the chat_directory view. Those gate most of
-- the app's RLS. It stays as a permanently-false flag: removing the *feature* does
-- not require removing the *column*.
--
-- The remaining dismissal columns, indexes and check-constraint values are
-- catalogued in To-Do's.md P12-28 and are deliberately left in place — dropping
-- them is a schema drop outside the granted DB autonomy and needs the client.

drop function if exists public.initiate_employee_dismissal(uuid, text);
drop function if exists public.resolve_employee_dismissal(uuid, boolean, text);
drop function if exists public.submit_employee_dismissal_appeal(text);
