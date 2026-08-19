-- Employee profile view (2026-08-03): every activity/document source the live
-- profile subscribes to must emit realtime events. RLS still filters per
-- subscriber (WALRUS), so adding tables to the publication exposes nothing new.
-- APPLIED LIVE 2026-08-03 (user-approved) as `employee_profile_realtime_publication`.
do $$
declare
  t text;
begin
  foreach t in array array[
    'pod_uploads',
    'stockpile_transactions',
    'compliance_documents',
    'recon_disputes',
    'driver_assignments',
    'transportation_requests',
    'request_dispatches'
  ] loop
    if exists (select 1 from pg_tables where schemaname = 'public' and tablename = t)
       and not exists (
         select 1 from pg_publication_tables
         where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = t
       ) then
      execute format('alter publication supabase_realtime add table public.%I', t);
    end if;
  end loop;
end $$;
