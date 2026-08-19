-- Phase 5 — Super-Admin dashboard logistics metrics (§8.1).
-- Active routes (dispatches currently being run by a transporter) and the total
-- tonnage the platform has managed (sum of loaded trip net tons). SECURITY
-- DEFINER, gated to platform admins. Additive.

create or replace function public.platform_logistics_totals()
returns table (active_routes bigint, total_tons_managed numeric)
language plpgsql security definer set search_path = public as $$
begin
  if not public.is_platform_admin() then
    active_routes := 0;
    total_tons_managed := 0;
    return next;
    return;
  end if;
  select count(*) into active_routes
  from public.request_dispatches where status = 'accepted';
  select coalesce(sum(net_tons), 0) into total_tons_managed
  from public.trips;
  return next;
end;
$$;

grant execute on function public.platform_logistics_totals() to authenticated;
