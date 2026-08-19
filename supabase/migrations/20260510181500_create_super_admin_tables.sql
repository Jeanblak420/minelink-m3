begin;

-- ============================================================
-- Super Admin platform tables: tokens, seats, seat requests, logs
-- ============================================================

create table if not exists public.serial_tokens (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.companies (id) on delete cascade,
  organization_name text not null,
  organization_type text not null check (organization_type in ('mineSupplier', 'buyer', 'transporter')),

  token_hash text not null,
  token_preview text not null,

  valid_days integer not null check (valid_days > 0),
  issued_at timestamptz not null default timezone('utc', now()),
  expires_at timestamptz not null,
  seat_limit integer not null check (seat_limit >= 0),

  status text not null default 'active' check (status in ('active', 'expired', 'revoked', 'replaced')),

  generated_by_user_id uuid references public.profiles (id) on delete set null,
  generated_by_email text,
  generated_by_platform_role text,

  revoked_by uuid references public.profiles (id) on delete set null,
  revoked_at timestamptz,
  revoke_reason text,

  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create index if not exists serial_tokens_org_id_idx
  on public.serial_tokens (organization_id);

create index if not exists serial_tokens_status_expires_idx
  on public.serial_tokens (status, expires_at);

create index if not exists serial_tokens_created_at_idx
  on public.serial_tokens (created_at desc);

alter table public.serial_tokens enable row level security;

-- Add FK now that serial_tokens exists
do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'companies_current_token_id_fkey'
      and conrelid = 'public.companies'::regclass
  ) then
    alter table public.companies
      add constraint companies_current_token_id_fkey
      foreign key (current_token_id) references public.serial_tokens (id)
      on delete set null;
  end if;
end$$;

create table if not exists public.organization_seats (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.companies (id) on delete cascade,
  seat_number integer not null check (seat_number >= 1),
  status text not null default 'available' check (status in ('available', 'occupied', 'disabled')),

  occupied_by_user_id uuid references public.profiles (id) on delete set null,
  occupied_by_employee_id uuid references public.employees (id) on delete set null,
  occupied_by_name text,
  occupied_by_email text,
  occupied_by_employee_role text,

  assigned_at timestamptz,
  released_at timestamptz,

  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),

  unique (organization_id, seat_number)
);

create index if not exists organization_seats_org_id_status_idx
  on public.organization_seats (organization_id, status);

alter table public.organization_seats enable row level security;

create table if not exists public.seat_requests (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.companies (id) on delete cascade,
  organization_name text not null,
  organization_type text not null check (organization_type in ('mineSupplier', 'buyer', 'transporter')),

  current_seat_limit integer not null check (current_seat_limit >= 0),
  current_seats_used integer not null check (current_seats_used >= 0),

  requested_extra_seats integer not null check (requested_extra_seats > 0),
  requested_new_total integer not null check (requested_new_total >= 0),
  reason text not null default '',

  requested_by_user_id uuid not null references public.profiles (id) on delete cascade,
  requested_by_email text,

  status text not null default 'pending' check (status in ('pending', 'approved', 'rejected', 'cancelled')),
  reviewed_by_user_id uuid references public.profiles (id) on delete set null,
  reviewed_by_email text,
  reviewed_at timestamptz,
  review_note text,

  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create index if not exists seat_requests_status_created_idx
  on public.seat_requests (status, created_at desc);

create index if not exists seat_requests_org_id_idx
  on public.seat_requests (organization_id);

alter table public.seat_requests enable row level security;

create table if not exists public.audit_logs (
  id uuid primary key default gen_random_uuid(),

  actor_user_id uuid references public.profiles (id) on delete set null,
  actor_email text,
  actor_platform_role text,

  action_type text not null,
  target_type text not null,
  target_id uuid,
  target_name text,

  organization_id uuid references public.companies (id) on delete set null,
  organization_name text,
  organization_type text,

  description text not null default '',
  before_data jsonb,
  after_data jsonb,

  ip_address text,
  device_info text,

  created_at timestamptz not null default timezone('utc', now())
);

create index if not exists audit_logs_created_at_idx
  on public.audit_logs (created_at desc);

create index if not exists audit_logs_action_type_idx
  on public.audit_logs (action_type);

create index if not exists audit_logs_org_id_created_idx
  on public.audit_logs (organization_id, created_at desc);

create index if not exists audit_logs_actor_created_idx
  on public.audit_logs (actor_user_id, created_at desc);

alter table public.audit_logs enable row level security;

commit;

