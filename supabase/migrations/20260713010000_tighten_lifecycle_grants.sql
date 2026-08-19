-- Tighten grants on the lifecycle write RPCs (audit minor): they were
-- executable by anon-by-default (via the implicit PUBLIC grant) even though
-- each raises for an unauthenticated caller via its internal is_company_staff
-- check. Revoke PUBLIC/anon so only signed-in users can reach them; the
-- explicit grant to `authenticated` (the app's real callers) stays.

begin;

revoke execute on function public.set_trip_status(uuid, text) from public, anon;
revoke execute on function public.record_truck_load(uuid, numeric, text, jsonb, jsonb) from public, anon;
revoke execute on function public.record_pod(uuid, numeric, text) from public, anon;
revoke execute on function public.accept_request_dispatch(uuid, uuid[]) from public, anon;
revoke execute on function public.record_vehicle_position(
  double precision, double precision, double precision, double precision, double precision
) from public, anon;

commit;
