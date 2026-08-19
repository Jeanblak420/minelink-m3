-- A buyer could read every GPS sample of a truck that had ever run one of their
-- trips -- including samples recorded while that truck was hauling for a
-- DIFFERENT buyer.
--
-- The intent was never that. `20260511140000_vehicle_positions_buyer_party_select`
-- says so in its own first line:
--
--     -- Buyers can read GPS samples for vehicles on trips tied to
--     -- transactions they participate in.
--
-- but the predicate it shipped joined on the vehicle, not on the sample's trip:
--
--     where tr.vehicle_id = vehicle_positions.vehicle_id   -- <- any trip, ever
--       and public.is_company_staff(tx.buyer_company_id)
--
-- `20260727130000_performance_advisory` later folded that standalone policy into
-- `vehicle_positions_select` as a fourth OR-branch to cut the policy count, and
-- copied the predicate across verbatim -- so the gap between the comment and the
-- code survived the consolidation.
--
-- The third branch already implements the documented intent, and does it for all
-- three parties rather than just the buyer:
--
--     where t.id = vehicle_positions.trip_id
--       and (is_company_staff(supplier) or is_company_staff(buyer)
--            or is_company_staff(transporter))
--
-- so the fourth branch grants exactly one thing that the third does not: samples
-- from trips the buyer is not a party to. That is the whole of its effect, and
-- it is the bug.
--
-- Measured before applying this, against live data:
--   * 55 sample rows, 0 with a null trip_id, so branch 3 covers every row that
--     exists and nothing legitimate depends on branch 4;
--   * of the 54 rows visible to Atlas Buyer Group, 54 were already visible via
--     branch 3 and 0 via branch 4 alone -- so no access is lost today;
--   * but two Roadhaul trucks (fa243ad, KVK007MP) already run for BOTH Atlas
--     Buyer Group and SteelWorks SA, which is the exact condition that turns
--     branch 4 into a live cross-buyer location leak the moment either truck
--     records a sample on the other buyer's trip.
--
-- Dropping the branch also correctly denies a buyer any sample with a null
-- trip_id -- a truck that is not on a job is not that buyer's business, and the
-- transporter's own staff still see it through branch 2. `trip_id` is nullable
-- and the retention job in 20260816150000 anticipates nulls, so this matters
-- even though there are none right now.
--
-- Narrowing only. Nothing that could read a row before this migration loses a
-- row it was entitled to.

alter policy vehicle_positions_select on public.vehicle_positions
  using (
    is_platform_admin()
    -- The transporter's own staff: their truck, on or off a job.
    or exists (
      select 1 from public.fleet_vehicles fv
      where fv.id = public.vehicle_positions.vehicle_id
        and public.is_company_staff(fv.company_id)
    )
    -- Any party to the trip THIS sample belongs to -- mine, buyer, transporter.
    or exists (
      select 1
      from public.trips t
      join public.transactions txn on txn.id = t.transaction_id
      where t.id = public.vehicle_positions.trip_id
        and (
          public.is_company_staff(txn.supplier_company_id)
          or public.is_company_staff(txn.buyer_company_id)
          or public.is_company_staff(txn.transporter_company_id)
        )
    )
  );

comment on policy vehicle_positions_select on public.vehicle_positions is
  'Location is scoped to the trip a sample belongs to, never to the vehicle. '
  'Matching on vehicle_id lets a buyer follow a truck onto another buyer''s '
  'job, which is what the fourth branch removed here used to do.';
