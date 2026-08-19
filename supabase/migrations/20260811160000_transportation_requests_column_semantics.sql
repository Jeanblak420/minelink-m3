-- ============================================================================
-- transportation_requests — say what the columns actually mean (P3-46)
-- ----------------------------------------------------------------------------
-- Documentation only. No policy, no data, no signature changes.
--
-- WHY THIS IS WORTH A MIGRATION. `buyer_company_id` does not mean "the buyer".
-- It means "the company that raised this request", and it is `not null` on
-- every row. A mine writes its own id there exactly as a buyer does --
-- *Request Transporter/Routes* is identical for both org types and *Request
-- Buyer* is mine-only. `supplier_company_id` is the unrelated thing: the mine
-- the platform admin LINKS at dispatch, null until then.
--
-- That name read as an org-type gate to a careful reader and produced a false
-- release blocker: an audit concluded from `transportation_requests_insert
-- WITH CHECK (is_company_staff(buyer_company_id))` that a mine could not submit
-- a request at all, and pointed at 6 of 6 live rows belonging to buyers as
-- proof. The policy does not test org type -- `is_company_staff` tests
-- employment and ownership only -- and the whole mine path was verified end to
-- end on 2026-08-11 against this database, inside a transaction that was rolled
-- back: mine inserts `transportation` -> mine inserts `buyer` -> mine reads
-- both back -> the row resolves to the Mine/Supplier admin inbox by its
-- requester's org_type -> admin `sent_back` -> mine `resubmitted`. Six steps,
-- all green, no code change needed.
--
-- Renaming the column would be the real fix and is deliberately NOT done here:
-- it is referenced by policies, by `list_request_tracking`,
-- `link_and_dispatch_request` and `can_view_request_via_dispatch`, by the
-- admin inbox's `companies!buyer_company_id` embed, and by live client code.
-- A comment costs nothing and reaches the next reader in the same place the
-- confusion starts.
-- ============================================================================

comment on column public.transportation_requests.buyer_company_id is
  'THE REQUESTER, not necessarily a buyer. The company that raised this '
  'request -- buyer OR mine/supplier; not null on every row. A mine raises '
  'transport requests on identical fields, and Request Buyer is mine-only. '
  'The super-admin inbox splits Mine/Supplier from Buyer by joining this to '
  'companies.org_type, which is the only place org type enters. RLS gates on '
  'is_company_staff() of this column, which tests employment, never org type '
  '-- reading it as a buyer-only gate produced a false release blocker '
  '(P3-46). Renaming it to requester_company_id is a wanted change, but it is '
  'load-bearing for 5 functions, 4 policies and the admin inbox embed.';

comment on column public.transportation_requests.supplier_company_id is
  'The mine/supplier the platform admin LINKED to fulfil this request, set at '
  'linking/dispatch and null before that. Not the requester -- see '
  'buyer_company_id. A linked mine deliberately CANNOT select this row: it '
  'carries price_per_ton, rate and admin_notes, and the mine must never see '
  'the buyer''s price or the admin margin (CLAUDE.md §4). It reads its linked '
  'orders through list_request_tracking(), which returns facts rather than the '
  'row -- the same reasoning as list_company_member_presence.';

comment on table public.transportation_requests is
  'All four request types (transportation, product, buyer) from every org '
  'type, on the lifecycle requested -> sent_back <-> resubmitted -> approved '
  '-> linked. Read buyer_company_id as "requester" -- see its comment.';
