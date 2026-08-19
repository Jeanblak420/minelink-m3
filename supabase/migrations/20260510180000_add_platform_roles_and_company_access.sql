begin;

-- ============================================================
-- Platform roles (Super Global Serial Admin) + company access
-- ============================================================

-- 1) Profiles: platform_role + last_login_at (used by Flutter super admin UI)
alter table public.profiles
  add column if not exists platform_role text not null default 'normalUser',
  add column if not exists last_login_at timestamptz;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'profiles_platform_role_check'
      and conrelid = 'public.profiles'::regclass
  ) then
    alter table public.profiles
      add constraint profiles_platform_role_check
      check (platform_role in (
        'normalUser',
        'superGlobalSerialAdminMain',
        'superGlobalSerialAdminMainChild'
      ));
  end if;
end$$;

create index if not exists profiles_platform_role_idx
  on public.profiles (platform_role);

-- 2) Companies: subscription/access fields used by super admin dashboards
alter table public.companies
  add column if not exists status text not null default 'pendingActivation',
  add column if not exists seat_limit integer not null default 0,
  add column if not exists seats_used integer not null default 0,
  add column if not exists token_expires_at timestamptz,
  add column if not exists token_valid_days integer,
  add column if not exists current_token_id uuid,
  add column if not exists last_token_generated_by uuid references public.profiles (id) on delete set null,
  add column if not exists last_token_generated_at timestamptz;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'companies_status_check'
      and conrelid = 'public.companies'::regclass
  ) then
    alter table public.companies
      add constraint companies_status_check
      check (status in (
        'active',
        'pendingActivation',
        'expired',
        'suspended',
        'blocked'
      ));
  end if;

  if not exists (
    select 1
    from pg_constraint
    where conname = 'companies_seat_limit_nonnegative'
      and conrelid = 'public.companies'::regclass
  ) then
    alter table public.companies
      add constraint companies_seat_limit_nonnegative
      check (seat_limit >= 0);
  end if;

  if not exists (
    select 1
    from pg_constraint
    where conname = 'companies_seats_used_nonnegative'
      and conrelid = 'public.companies'::regclass
  ) then
    alter table public.companies
      add constraint companies_seats_used_nonnegative
      check (seats_used >= 0);
  end if;

  if not exists (
    select 1
    from pg_constraint
    where conname = 'companies_seats_used_lte_limit'
      and conrelid = 'public.companies'::regclass
  ) then
    alter table public.companies
      add constraint companies_seats_used_lte_limit
      check (seats_used <= seat_limit);
  end if;
end$$;

create index if not exists companies_status_idx
  on public.companies (status);

create index if not exists companies_org_type_status_idx
  on public.companies (org_type, status);

create index if not exists companies_token_expires_at_idx
  on public.companies (token_expires_at);

-- 3) Platform admin settings singleton (stores main/child admin + permissions)
create table if not exists public.platform_admin_settings (
  id text primary key,
  main_super_admin_email text not null,
  main_super_admin_user_id uuid references public.profiles (id) on delete set null,
  child_super_admin_user_id uuid references public.profiles (id) on delete set null,
  child_super_admin_email text,
  child_admin_created_at timestamptz,
  child_admin_status text not null default 'inactive' check (child_admin_status in ('active', 'inactive', 'disabled')),
  -- Child admin permission flags (Flutter UI expects these columns)
  child_can_view_companies boolean not null default true,
  child_can_view_users boolean not null default true,
  child_can_generate_tokens boolean not null default true,
  child_can_revoke_tokens boolean not null default false,
  child_can_manage_seats boolean not null default true,
  child_can_suspend_companies boolean not null default false,
  child_can_download_logs boolean not null default false,
  child_can_create_another_child boolean not null default false,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

alter table public.platform_admin_settings enable row level security;

-- Ensure singleton row exists (id='main') while letting projects override later.
insert into public.platform_admin_settings (id, main_super_admin_email, child_admin_status)
values ('main', 'jean@cyberhouse.co.za', 'inactive')
on conflict (id) do nothing;

commit;

