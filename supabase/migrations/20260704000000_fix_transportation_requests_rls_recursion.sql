-- Fix: infinite recursion (Postgres 42P17) between the RLS SELECT policies of
-- `transportation_requests` and `request_dispatches`.
--
-- `transportation_requests_select_dispatched` (added in 20260627020000) selected
-- from `request_dispatches`, whose own `request_dispatches_select` policy selects
-- back from `transportation_requests`. Each table's policy referenced the other,
-- so any authenticated SELECT on either table aborted with:
--   42P17 "infinite recursion detected in policy for relation transportation_requests"
-- This broke the buyer request flow, the transporter marketplace, and the
-- super-admin Requested routes/product/buyers queues.
--
-- Break the cycle by moving the cross-table check into a SECURITY DEFINER helper.
-- The helper is owned by `postgres` (force_rls = false on both tables), so its
-- internal read of `request_dispatches` bypasses that table's RLS and never
-- re-enters `transportation_requests`'s policies. Behaviour is unchanged: a
-- transporter still sees exactly the requests dispatched to a company they are
-- active staff of.

create or replace function public.can_view_request_via_dispatch(target_request_id uuid)
returns boolean
language sql
stable
security definer
set search_path to 'public'
as $$
  select exists (
    select 1
    from public.request_dispatches d
    where d.request_id = target_request_id
      and public.is_company_staff(d.transporter_company_id)
  );
$$;

drop policy if exists transportation_requests_select_dispatched
  on public.transportation_requests;

create policy transportation_requests_select_dispatched
  on public.transportation_requests
  for select to authenticated
  using ( public.can_view_request_via_dispatch(id) );
