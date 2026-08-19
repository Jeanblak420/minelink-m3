-- Request Transporter/Routes form edits (CLAUDE.md §4 Request 1):
-- the "Ongoing" checkbox becomes an `Ongoing | Single request` dropdown.
-- Ongoing → start date only; Single request → start date + END date.
-- `is_ongoing` keeps backing the dropdown; this adds the end date.

begin;

alter table public.transportation_requests
  add column if not exists ending_date date;

commit;
