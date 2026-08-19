-- Buyers can read GPS samples for vehicles on trips tied to transactions they participate in.
create policy vehicle_positions_select_buyer_via_trips on public.vehicle_positions
for select to authenticated
using (
  exists (
    select 1
    from public.trips tr
    join public.transactions tx on tx.id = tr.transaction_id
    where tr.vehicle_id = vehicle_positions.vehicle_id
      and public.is_company_staff(tx.buyer_company_id)
  )
);
