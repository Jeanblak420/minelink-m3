-- 20260815125000_buyer_request_links_its_own_buyer.sql
--
-- S6 walk finding: 20260815118000 fixed one direction and broke the other.
--
-- That migration split `transportation_requests.buyer_company_id` out of
-- `requesting_company_id`, because `RequestService.submit()` was writing the
-- requester's own id into the buyer column — so a MINE raising a request was
-- recorded as the buyer of its own ore, and `routes.buyer_company_id`, the
-- order stockpile's `buyer_label`, the dispatch notification and
-- `list_buyer_trip_values` all believed it. Correct fix, correct diagnosis.
--
-- But `submit()` now writes ONLY `requesting_company_id`, and nothing puts the
-- buyer back when the requester genuinely IS the buyer. Walked end to end on
-- 2026-08-15 with Atlas Buyer Group raising a real request:
--
--   routes.buyer_company_id        NULL
--   stockpiles.buyer_company_id    NULL
--   stockpiles.buyer_label         'Atlas Buyer Group'   <-- label right, key wrong
--
--   as the Atlas admin who RAISED the order:
--     own request     1
--     own route       0
--     own stockpile   0
--
-- So the buyer could not see the route they had asked for, could not watch the
-- stockpile being built for them, and would have had nothing in Loads & value
-- — every one of those reads keys on `buyer_company_id`, not on the label.
-- The previous walk missed it because it tested the MINE case, which is the
-- half the split was written for.
--
-- Fixed at the source rather than in `submit()`: a trigger cannot be bypassed
-- by a second call site, and it back-fills nothing it should not — a mine's
-- request keeps a NULL buyer, which is the whole point of the split.

create or replace function public.set_buyer_from_requester()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $function$
begin
  -- Only when the requester is itself a buyer, and only when the column has
  -- not been set explicitly. A mine or a transporter raising a haul request
  -- has no buyer yet and must keep NULL (20260815118000).
  if new.buyer_company_id is null and new.requesting_company_id is not null then
    select c.id into new.buyer_company_id
    from public.companies c
    where c.id = new.requesting_company_id
      and c.org_type = 'buyer';
  end if;
  return new;
end;
$function$;

comment on function public.set_buyer_from_requester() is
  'Fills transportation_requests.buyer_company_id from requesting_company_id when, and only when, the requester is a buyer. 20260815118000 stopped submit() writing the requester into the buyer column - correct for a mine, wrong for a buyer, and it left the buyer unable to see their own route or stockpile.';

drop trigger if exists trg_set_buyer_from_requester
  on public.transportation_requests;

create trigger trg_set_buyer_from_requester
  before insert or update of requesting_company_id, buyer_company_id
  on public.transportation_requests
  for each row
  execute function public.set_buyer_from_requester();

-- Back-fill. One row today — the request raised during this walk — because
-- 20260815118000 landed hours ago and every earlier buyer request still
-- carries the id the old submit() wrote. Counted before and after.
update public.transportation_requests t
set buyer_company_id = t.requesting_company_id
from public.companies c
where c.id = t.requesting_company_id
  and c.org_type = 'buyer'
  and t.buyer_company_id is null;

-- The rows dispatched before the back-fill kept a NULL buyer on the route and
-- the stockpile, which is where the visibility is actually lost. Repair those
-- from the request they came from, buyers only.
update public.routes r
set buyer_company_id = t.buyer_company_id
from public.transportation_requests t
where t.id = r.request_id
  and r.buyer_company_id is null
  and t.buyer_company_id is not null;

update public.stockpiles s
set buyer_company_id = t.buyer_company_id
from public.transportation_requests t
where t.id = s.request_id
  and s.buyer_company_id is null
  and t.buyer_company_id is not null;
