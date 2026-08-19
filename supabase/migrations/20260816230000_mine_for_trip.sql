-- Which mine is this trip collecting from?
--
-- Needed by the hazard report flow (20260816220000). `mine_hazards` is now
-- NOT NULL on `mine_company_id`, and the only place a hazard is reported from
-- is the driver navigation screen, which holds a `tripId` and nothing else.
--
-- The mine is resolved HERE rather than passed up from the client, so a driver
-- cannot name a mine they are not going to. The RLS insert policy would refuse
-- that anyway — but a value the client chooses is a value the client can get
-- wrong, and the correct one is derivable. This makes the data right by
-- construction and leaves the policy as the second line rather than the only
-- one.
--
-- Party-scoped: returns null to anyone not on the trip, so it cannot be used
-- to enumerate which mine an arbitrary trip belongs to.
create or replace function public.mine_for_trip(p_trip_id uuid)
returns uuid
language sql
stable
security definer
set search_path to 'public'
as $function$
  select x.supplier_company_id
  from public.trips t
  join public.transactions x on x.id = t.transaction_id
  where t.id = p_trip_id
    and public.is_trip_party(p_trip_id);
$function$;

grant execute on function public.mine_for_trip(uuid) to authenticated;

comment on function public.mine_for_trip(uuid) is
  'The SOURCE mine of a trip, or null if the caller is not a party to it. '
  'Used so the hazard report flow derives mine_company_id server-side rather '
  'than trusting the client (20260816230000).';
