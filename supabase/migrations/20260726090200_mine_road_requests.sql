-- ============================================================================
-- Mine road integration requests (mines ask for their haul roads to be added
-- to navigation). Ported/adapted from ML/supabase/migrations/000016_mine_road_requests.sql
--
-- Adaptations from the ML donor schema to WT-live:
--   * ML RLS used profiles.org_id (does not exist live) -> rewritten on
--     public.is_company_staff(mine_company_id) for reads and
--     public.is_company_manager(mine_company_id) for inserts (WT-live pattern;
--     ML allowed ANY org member to insert — tighten/loosen at review).
--   * ML super-admin checks (profiles.is_super_admin) -> public.is_platform_admin().
--   * No RPCs: ML's Dart layer reads/writes this table directly.
-- ============================================================================

create table if not exists public.mine_road_requests (
  id              uuid primary key default gen_random_uuid(),
  mine_company_id uuid not null references public.companies (id) on delete cascade,
  mine_name       varchar(255) not null default '',
  description     text not null default '',
  status          varchar(20) not null default 'requested'
                  check (status in ('requested', 'accepted', 'in_progress', 'completed')),
  admin_notes     text,
  requested_at    timestamptz not null default current_timestamp,
  accepted_at     timestamptz,
  completed_at    timestamptz
);

comment on table public.mine_road_requests
  is 'Mine road integration requests — mines request their haul roads be added to navigation.';
comment on column public.mine_road_requests.status
  is 'Lifecycle: requested -> accepted -> in_progress -> completed';
comment on column public.mine_road_requests.admin_notes
  is 'Notes left by the platform admin during processing.';

create index if not exists idx_mine_road_requests_mine
  on public.mine_road_requests (mine_company_id);
create index if not exists idx_mine_road_requests_status
  on public.mine_road_requests (status);

-- ── RLS ──────────────────────────────────────────────────────────────────────

alter table public.mine_road_requests enable row level security;

-- Mine staff read their own requests; platform admin reads all.
drop policy if exists mine_road_requests_select on public.mine_road_requests;
create policy mine_road_requests_select on public.mine_road_requests
for select to authenticated
using (public.is_platform_admin() or public.is_company_staff(mine_company_id));

-- Mine managers create requests for their own company.
drop policy if exists mine_road_requests_insert on public.mine_road_requests;
create policy mine_road_requests_insert on public.mine_road_requests
for insert to authenticated
with check (public.is_platform_admin() or public.is_company_manager(mine_company_id));

-- Platform admin processes (update) and cleans up (delete).
drop policy if exists mine_road_requests_update_admin on public.mine_road_requests;
create policy mine_road_requests_update_admin on public.mine_road_requests
for update to authenticated
using (public.is_platform_admin())
with check (public.is_platform_admin());

drop policy if exists mine_road_requests_delete_admin on public.mine_road_requests;
create policy mine_road_requests_delete_admin on public.mine_road_requests
for delete to authenticated
using (public.is_platform_admin());

grant select, insert, update, delete on public.mine_road_requests to authenticated;
