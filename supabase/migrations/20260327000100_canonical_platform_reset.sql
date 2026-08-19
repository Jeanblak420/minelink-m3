begin;

create extension if not exists pgcrypto with schema extensions;

-- Extensions the later migrations assume, created here because this file is
-- where the schema is bootstrapped and every user of them is stamped later.
--
-- Added 2026-08-17, from the first real cold replay of this repo. A fresh
-- Supabase project has neither pg_cron nor pg_net, so six migrations died on
--     3F000  schema "cron" does not exist
-- and six more cascaded off them. Production has had both for months, which is
-- exactly why nothing noticed. Schemas match production: pg_cron in pg_catalog,
-- pg_net in extensions.
create extension if not exists pg_cron with schema pg_catalog;
create extension if not exists pg_net with schema extensions;
create extension if not exists pg_trgm with schema extensions;
create extension if not exists "uuid-ossp" with schema extensions;

-- Wiping storage is best-effort, and MUST NOT take the schema down with it.
--
-- These two statements used to run bare, and on 2026-08-17 the first real cold
-- replay of this repo showed what that costs. Supabase now guards storage with
-- a trigger:
--     42501  Direct deletion from storage tables is not allowed.
--            Use the Storage API instead.   (storage.protect_delete())
-- which did not exist when this migration was written. This file is ONE
-- transaction and is the sole definition of profiles, companies, employees,
-- notifications, fleet_vehicles, chat_rooms, transactions, weighbridge_records,
-- minerals and gate_checks — so line 5 rolled back the other 2,503 and 102
-- later migrations then failed with `relation "public.profiles" does not
-- exist`. 79 of 251 files applied; the rebuilt database had 9 tables against
-- production's 68.
--
-- On an empty project these deletes are no-ops anyway: there is nothing to
-- delete. They only ever mattered when resetting a populated database, and on
-- one of those the trigger is right to refuse. So: attempt, and carry on. The
-- DO block opens a subtransaction, so catching here does not poison the outer
-- one. Objects left behind are orphaned rows in storage, not schema — remove
-- them through the Storage API if a real reset ever needs it.
do $storage_wipe$
begin
  delete from storage.objects;
  delete from storage.buckets;
exception
  when insufficient_privilege or feature_not_supported then
    raise notice 'storage wipe skipped: %', sqlerrm;
end
$storage_wipe$;

delete from auth.sessions;
delete from auth.refresh_tokens;
delete from auth.identities;
delete from auth.users;

drop schema if exists public cascade;
create schema public;

grant usage on schema public to postgres, anon, authenticated, service_role;
grant all on schema public to postgres, service_role;

create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  email text not null unique,
  user_type text not null check (user_type in ('company', 'employee')),
  display_name text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create table public.companies (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null unique references public.profiles (id) on delete cascade,
  company_name text not null,
  whatsapp_number text not null,
  org_type text not null check (org_type in ('mineSupplier', 'buyer', 'transporter')),
  logo_url text,
  ceo_first_name text,
  ceo_last_name text,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create table public.employees (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null unique references public.profiles (id) on delete cascade,
  first_name text not null,
  last_name text not null,
  whatsapp_number text not null,
  company_id uuid references public.companies (id) on delete set null,
  role text check (role in ('security', 'controllerWB', 'admin', 'management', 'driver')),
  status text not null default 'pending_company' check (status in ('pending_company', 'pending_role', 'active', 'rejected', 'dismissed', 'inactive')),
  profile_photo_url text,
  is_south_african_citizen boolean not null default true,
  id_number text,
  passport_or_workers_permit text,
  license_document text,
  id_document_url text,
  passport_document_url text,
  work_visa_document_url text,
  license_document_url text,
  is_dismissed boolean not null default false,
  dismissal_date timestamptz,
  dismissal_reason text,
  dismissal_by_id uuid references public.profiles (id) on delete set null,
  is_dismissed_pending_appeal boolean not null default false,
  is_dismissal_final boolean not null default false,
  account_deletion_date timestamptz,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create table public.employee_status_history (
  id uuid primary key default gen_random_uuid(),
  employee_id uuid not null references public.employees (id) on delete cascade,
  company_id uuid references public.companies (id) on delete set null,
  status text not null check (status in (
    'company_requested',
    'request_approved',
    'request_declined',
    'role_assigned',
    'dismissal_initiated',
    'appeal_submitted',
    'dismissal_upheld',
    'dismissal_reversed'
  )),
  timestamp timestamptz not null default timezone('utc', now()),
  actioned_by_id uuid references public.profiles (id) on delete set null,
  actioned_by_name text,
  assigned_role text check (assigned_role in ('security', 'controllerWB', 'admin', 'management', 'driver')),
  appeal_reason text,
  dismissal_reason text,
  decision_reason text,
  uphold_dismissal boolean,
  account_deletion_date timestamptz
);

create table public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  company_id uuid references public.companies (id) on delete set null,
  employee_id uuid references public.employees (id) on delete set null,
  title text not null,
  message text not null,
  type text not null check (type in (
    'employeeRequest',
    'roleAssigned',
    'requestDeclined',
    'roleConfirmation',
    'profileUpdate',
    'userManagement',
    'securityAlert',
    'controllerAction',
    'adminAction',
    'managementAction',
    'dismissalInitiated',
    'dismissalAppeal',
    'dismissalFinal',
    'fleetVehicleAdded',
    'fleetDriverAssigned',
    'fleetDriverUnassigned',
    'fleetVehicleStatusChanged',
    'general'
  )),
  is_read boolean not null default false,
  created_at timestamptz not null default timezone('utc', now()),
  actioned_by text,
  actioned_by_id uuid references public.profiles (id) on delete set null,
  role_scope text check (role_scope in ('security', 'controllerWB', 'admin', 'management', 'driver')),
  org_type text check (org_type in ('mineSupplier', 'buyer', 'transporter')),
  importance text not null default 'normal' check (importance in ('normal', 'high', 'extreme')),
  metadata jsonb not null default '{}'::jsonb
);

create table public.fleet_vehicles (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies (id) on delete cascade,
  vehicle_registration_number text not null,
  vehicle_registration_expiry_date timestamptz,
  first_trailer_regs text,
  second_trailer_regs text,
  assigned_driver_employee_id uuid references public.employees (id) on delete set null,
  driver_user_id uuid references public.profiles (id) on delete set null,
  driver_first_name text,
  driver_last_name text,
  driver_id_number text,
  driver_passport_number text,
  driver_work_permit text,
  drivers_license_document text,
  driver_id_document_url text,
  driver_passport_document_url text,
  driver_work_visa_document_url text,
  driver_license_document_url text,
  driver_is_south_african_citizen boolean,
  is_active boolean not null default true,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  unique (company_id, vehicle_registration_number)
);

create table public.chat_rooms (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  participant_ids uuid[] not null default '{}',
  created_at timestamptz not null default timezone('utc', now()),
  last_message_content text,
  last_message_timestamp timestamptz,
  last_message_sender_id uuid references public.profiles (id) on delete set null
);

create table public.chat_messages (
  id uuid primary key default gen_random_uuid(),
  chat_room_id uuid not null references public.chat_rooms (id) on delete cascade,
  content text not null default '',
  sender_id uuid not null references public.profiles (id) on delete cascade,
  sender_name text not null,
  sender_avatar_url text,
  timestamp timestamptz not null default timezone('utc', now()),
  is_read boolean not null default false,
  file_url text,
  file_type text,
  file_name text,
  reply_to_id uuid references public.chat_messages (id) on delete set null
);

create table public.broadcast_messages (
  id uuid primary key default gen_random_uuid(),
  event text not null,
  payload jsonb not null default '{}'::jsonb,
  created_by uuid references public.profiles (id) on delete set null,
  timestamp timestamptz not null default timezone('utc', now())
);

create table public.minerals (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies (id) on delete cascade,
  name text not null,
  grade text,
  description text,
  unit_of_measure text not null default 'ton',
  created_by uuid references public.profiles (id) on delete set null,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create table public.transactions (
  id uuid primary key default gen_random_uuid(),
  mineral_id uuid references public.minerals (id) on delete set null,
  supplier_company_id uuid references public.companies (id) on delete set null,
  buyer_company_id uuid references public.companies (id) on delete set null,
  transporter_company_id uuid references public.companies (id) on delete set null,
  reference_number text not null unique,
  status text not null default 'draft' check (status in ('draft', 'scheduled', 'in_transit', 'delivered', 'completed', 'cancelled')),
  quantity numeric(14, 3) not null default 0,
  created_by uuid references public.profiles (id) on delete set null,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create table public.weighbridge_records (
  id uuid primary key default gen_random_uuid(),
  transaction_id uuid references public.transactions (id) on delete set null,
  company_id uuid references public.companies (id) on delete set null,
  vehicle_id uuid references public.fleet_vehicles (id) on delete set null,
  direction text not null check (direction in ('inbound', 'outbound')),
  gross_weight numeric(14, 3),
  tare_weight numeric(14, 3),
  net_weight numeric(14, 3),
  recorded_by uuid references public.profiles (id) on delete set null,
  recorded_at timestamptz not null default timezone('utc', now()),
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create table public.mineral_loads (
  id uuid primary key default gen_random_uuid(),
  transaction_id uuid references public.transactions (id) on delete set null,
  vehicle_id uuid references public.fleet_vehicles (id) on delete set null,
  mineral_id uuid references public.minerals (id) on delete set null,
  loader_employee_id uuid references public.employees (id) on delete set null,
  notes text,
  loaded_at timestamptz not null default timezone('utc', now()),
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create table public.security_incidents (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies (id) on delete cascade,
  employee_id uuid references public.employees (id) on delete set null,
  vehicle_id uuid references public.fleet_vehicles (id) on delete set null,
  severity text not null default 'low' check (severity in ('low', 'medium', 'high', 'critical')),
  title text not null,
  description text,
  status text not null default 'open' check (status in ('open', 'investigating', 'resolved', 'closed')),
  reported_by uuid references public.profiles (id) on delete set null,
  resolved_by uuid references public.profiles (id) on delete set null,
  occurred_at timestamptz not null default timezone('utc', now()),
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create table public.gate_checks (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies (id) on delete cascade,
  employee_id uuid references public.employees (id) on delete set null,
  vehicle_id uuid references public.fleet_vehicles (id) on delete set null,
  check_type text not null check (check_type in ('entry', 'exit')),
  gate_status text not null default 'pending' check (gate_status in ('pending', 'cleared', 'blocked')),
  notes text,
  checked_by uuid references public.profiles (id) on delete set null,
  checked_at timestamptz not null default timezone('utc', now()),
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create index companies_org_type_idx on public.companies (org_type);
create index companies_user_id_idx on public.companies (user_id);
create index employees_company_id_idx on public.employees (company_id);
create index employees_user_id_idx on public.employees (user_id);
create index employees_status_idx on public.employees (status);
create index employees_role_idx on public.employees (role);
create index employee_status_history_employee_id_idx on public.employee_status_history (employee_id, timestamp desc);
create index notifications_user_id_idx on public.notifications (user_id, created_at desc);
create index notifications_company_id_idx on public.notifications (company_id);
create index fleet_vehicles_company_id_idx on public.fleet_vehicles (company_id);
create index fleet_vehicles_assigned_driver_employee_id_idx on public.fleet_vehicles (assigned_driver_employee_id);
create unique index fleet_vehicles_assigned_driver_employee_id_unique on public.fleet_vehicles (assigned_driver_employee_id) where assigned_driver_employee_id is not null;
create index chat_messages_chat_room_id_idx on public.chat_messages (chat_room_id, timestamp asc);
create index employee_status_history_company_id_idx on public.employee_status_history (company_id);
create index employee_status_history_actioned_by_id_idx on public.employee_status_history (actioned_by_id);
create index employees_dismissal_by_id_idx on public.employees (dismissal_by_id);
create index notifications_employee_id_idx on public.notifications (employee_id);
create index notifications_actioned_by_id_idx on public.notifications (actioned_by_id);
create index fleet_vehicles_driver_user_id_idx on public.fleet_vehicles (driver_user_id);
create index chat_rooms_last_message_sender_id_idx on public.chat_rooms (last_message_sender_id);
create index chat_messages_sender_id_idx on public.chat_messages (sender_id);
create index chat_messages_reply_to_id_idx on public.chat_messages (reply_to_id);
create index broadcast_messages_created_by_idx on public.broadcast_messages (created_by);
create index minerals_company_id_idx on public.minerals (company_id);
create index minerals_created_by_idx on public.minerals (created_by);
create index transactions_reference_number_idx on public.transactions (reference_number);
create index transactions_mineral_id_idx on public.transactions (mineral_id);
create index transactions_supplier_company_id_idx on public.transactions (supplier_company_id);
create index transactions_buyer_company_id_idx on public.transactions (buyer_company_id);
create index transactions_transporter_company_id_idx on public.transactions (transporter_company_id);
create index transactions_created_by_idx on public.transactions (created_by);
create index weighbridge_records_transaction_id_idx on public.weighbridge_records (transaction_id);
create index weighbridge_records_company_id_idx on public.weighbridge_records (company_id);
create index weighbridge_records_vehicle_id_idx on public.weighbridge_records (vehicle_id);
create index weighbridge_records_recorded_by_idx on public.weighbridge_records (recorded_by);
create index mineral_loads_transaction_id_idx on public.mineral_loads (transaction_id);
create index mineral_loads_vehicle_id_idx on public.mineral_loads (vehicle_id);
create index mineral_loads_mineral_id_idx on public.mineral_loads (mineral_id);
create index mineral_loads_loader_employee_id_idx on public.mineral_loads (loader_employee_id);
create index security_incidents_company_id_idx on public.security_incidents (company_id);
create index security_incidents_employee_id_idx on public.security_incidents (employee_id);
create index security_incidents_vehicle_id_idx on public.security_incidents (vehicle_id);
create index security_incidents_reported_by_idx on public.security_incidents (reported_by);
create index security_incidents_resolved_by_idx on public.security_incidents (resolved_by);
create index gate_checks_company_id_idx on public.gate_checks (company_id);
create index gate_checks_employee_id_idx on public.gate_checks (employee_id);
create index gate_checks_vehicle_id_idx on public.gate_checks (vehicle_id);
create index gate_checks_checked_by_idx on public.gate_checks (checked_by);

create or replace function public.set_updated_at()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  new.updated_at = timezone('utc', now());
  return new;
end;
$$;

create or replace function public.handle_auth_user_created()
returns trigger
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  metadata jsonb := coalesce(new.raw_user_meta_data, '{}'::jsonb);
begin
  insert into public.profiles (id, email, user_type, display_name, metadata)
  values (
    new.id,
    coalesce(new.email, ''),
    case
      when metadata ->> 'user_type' in ('company', 'employee') then metadata ->> 'user_type'
      else 'employee'
    end,
    coalesce(metadata ->> 'display_name', split_part(coalesce(new.email, ''), '@', 1)),
    metadata
  )
  on conflict (id) do update
  set
    email = excluded.email,
    user_type = excluded.user_type,
    display_name = excluded.display_name,
    metadata = excluded.metadata,
    updated_at = timezone('utc', now());

  return new;
end;
$$;

create or replace function public.handle_auth_user_updated()
returns trigger
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  metadata jsonb := coalesce(new.raw_user_meta_data, '{}'::jsonb);
begin
  update public.profiles as p
  set
    email = coalesce(new.email, email),
    display_name = coalesce(metadata ->> 'display_name', display_name),
    metadata = p.metadata || coalesce(new.raw_user_meta_data, '{}'::jsonb),
    updated_at = timezone('utc', now())
  where p.id = new.id;

  return new;
end;
$$;

create trigger handle_profiles_updated_at
before update on public.profiles
for each row
execute function public.set_updated_at();

create trigger handle_companies_updated_at
before update on public.companies
for each row
execute function public.set_updated_at();

create trigger handle_employees_updated_at
before update on public.employees
for each row
execute function public.set_updated_at();

create trigger handle_fleet_vehicles_updated_at
before update on public.fleet_vehicles
for each row
execute function public.set_updated_at();

create trigger handle_minerals_updated_at
before update on public.minerals
for each row
execute function public.set_updated_at();

create trigger handle_transactions_updated_at
before update on public.transactions
for each row
execute function public.set_updated_at();

create trigger handle_weighbridge_records_updated_at
before update on public.weighbridge_records
for each row
execute function public.set_updated_at();

create trigger handle_mineral_loads_updated_at
before update on public.mineral_loads
for each row
execute function public.set_updated_at();

create trigger handle_security_incidents_updated_at
before update on public.security_incidents
for each row
execute function public.set_updated_at();

create trigger handle_gate_checks_updated_at
before update on public.gate_checks
for each row
execute function public.set_updated_at();

create trigger on_auth_user_created
after insert on auth.users
for each row
execute function public.handle_auth_user_created();

create trigger on_auth_user_updated
after update of email, raw_user_meta_data on auth.users
for each row
execute function public.handle_auth_user_updated();

create or replace function public.current_company_id()
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    (select c.id from public.companies c where c.user_id = auth.uid() limit 1),
    (select e.company_id from public.employees e where e.user_id = auth.uid() limit 1)
  );
$$;

create or replace function public.current_employee_id()
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select e.id
  from public.employees e
  where e.user_id = auth.uid()
  limit 1;
$$;

create or replace function public.is_company_owner(target_company_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.companies c
    where c.id = target_company_id
      and c.user_id = auth.uid()
  );
$$;

create or replace function public.is_company_manager(target_company_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select
    public.is_company_owner(target_company_id)
    or exists (
      select 1
      from public.employees e
      where e.company_id = target_company_id
        and e.user_id = auth.uid()
        and e.role in ('admin', 'management')
        and e.status = 'active'
        and e.is_dismissed = false
    );
$$;

create or replace function public.is_company_staff(target_company_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select
    public.is_company_owner(target_company_id)
    or exists (
      select 1
      from public.employees e
      where e.company_id = target_company_id
        and e.user_id = auth.uid()
        and e.status = 'active'
        and e.is_dismissed = false
    );
$$;

create or replace function public.has_company_role(
  target_company_id uuid,
  allowed_roles text[]
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select
    public.is_company_owner(target_company_id)
    or exists (
      select 1
      from public.employees e
      where e.company_id = target_company_id
        and e.user_id = auth.uid()
        and e.role = any (allowed_roles)
        and e.status = 'active'
        and e.is_dismissed = false
    );
$$;

create or replace function public.is_employee_self(target_employee_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.employees e
    where e.id = target_employee_id
      and e.user_id = auth.uid()
  );
$$;

create or replace function public.employee_company_id(target_employee_id uuid)
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select e.company_id
  from public.employees e
  where e.id = target_employee_id
  limit 1;
$$;

create or replace function public.can_access_employee_profile_photo(target_employee_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select
    public.is_employee_self(target_employee_id)
    or public.is_company_staff(public.employee_company_id(target_employee_id));
$$;

create or replace function public.can_access_employee_document(target_employee_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select
    public.is_employee_self(target_employee_id)
    or public.is_company_manager(public.employee_company_id(target_employee_id));
$$;

create or replace function public.can_manage_fleet(target_company_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.companies c
    where c.id = target_company_id
      and c.org_type = 'transporter'
      and public.is_company_manager(target_company_id)
  );
$$;

create or replace function public.are_chat_participants_allowed(
  target_participant_ids uuid[]
)
returns boolean
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  base_company_id uuid;
  participant_id uuid;
begin
  if auth.uid() is null then
    return false;
  end if;

  base_company_id := public.current_company_id();
  if base_company_id is null then
    return false;
  end if;

  if target_participant_ids is null or array_length(target_participant_ids, 1) is null then
    return false;
  end if;

  if not auth.uid() = any (target_participant_ids) then
    return false;
  end if;

  foreach participant_id in array target_participant_ids
  loop
    if not exists (
      select 1
      from public.companies c
      where c.id = base_company_id
        and c.user_id = participant_id
      union all
      select 1
      from public.employees e
      where e.company_id = base_company_id
        and e.user_id = participant_id
        and e.status = 'active'
        and e.is_dismissed = false
    ) then
      return false;
    end if;
  end loop;

  return true;
end;
$$;

create or replace function public.can_access_chat_room(target_chat_room_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.chat_rooms cr
    where cr.id = target_chat_room_id
      and public.are_chat_participants_allowed(cr.participant_ids)
  );
$$;

create or replace function public.extract_payload_company_id(payload jsonb)
returns uuid
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  raw_company_id text;
begin
  raw_company_id := nullif(trim(coalesce(payload ->> 'company_id', '')), '');

  if raw_company_id is null then
    return null;
  end if;

  begin
    return raw_company_id::uuid;
  exception
    when invalid_text_representation then
      return null;
  end;
end;
$$;

create or replace function public.can_access_broadcast_message(payload jsonb)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.is_company_staff(public.extract_payload_company_id(payload));
$$;

create or replace function public.can_create_broadcast_message(
  payload jsonb,
  created_by uuid
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select
    created_by = auth.uid()
    and public.has_company_role(
      public.extract_payload_company_id(payload),
      array['admin', 'management']
    );
$$;

create or replace function public.list_company_chat_contacts(
  target_company_id uuid
)
returns table (
  id uuid,
  user_id uuid,
  first_name text,
  last_name text,
  whatsapp_number text,
  company_id uuid,
  role text,
  status text,
  created_at timestamptz,
  updated_at timestamptz,
  profile_photo_url text
)
language sql
stable
security definer
set search_path = public
as $$
  select
    e.id,
    e.user_id,
    e.first_name,
    e.last_name,
    e.whatsapp_number,
    e.company_id,
    e.role,
    e.status,
    e.created_at,
    e.updated_at,
    e.profile_photo_url
  from public.employees e
  where e.company_id = target_company_id
    and e.status = 'active'
    and e.is_dismissed = false
    and public.is_company_staff(target_company_id)
  order by e.first_name, e.last_name;
$$;

create or replace function public.check_user_exists(user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public, auth
as $$
  select exists (
    select 1
    from auth.users
    where id = user_id
  );
$$;

create or replace function public.get_runtime_platform_status()
returns jsonb
language plpgsql
security definer
stable
set search_path = public
as $$
declare
  missing_capabilities text[] := array[]::text[];
  required_realtime_tables text[] := array[
    'profiles',
    'companies',
    'employees',
    'employee_status_history',
    'notifications',
    'fleet_vehicles',
    'chat_rooms',
    'chat_messages',
    'broadcast_messages',
    'minerals',
    'transactions',
    'weighbridge_records',
    'mineral_loads',
    'security_incidents',
    'gate_checks'
  ];
  required_table_name text;
begin
  if not exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and information_schema.columns.table_name = 'fleet_vehicles'
      and column_name = 'is_active'
  ) then
    missing_capabilities := array_append(
      missing_capabilities,
      'fleet_vehicles.is_active'
    );
  end if;

  if not exists (
    select 1
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname = 'create_actioned_notification'
  ) then
    missing_capabilities := array_append(
      missing_capabilities,
      'rpc:create_actioned_notification'
    );
  end if;

  if not exists (
    select 1
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname = 'mark_all_notifications_read'
  ) then
    missing_capabilities := array_append(
      missing_capabilities,
      'rpc:mark_all_notifications_read'
    );
  end if;

  if not exists (
    select 1
    from storage.buckets
    where id = 'employee_assets'
      and public = false
  ) then
    missing_capabilities := array_append(
      missing_capabilities,
      'storage:employee_assets_private'
    );
  end if;

  if not exists (
    select 1
    from storage.buckets
    where id = 'chat_files'
      and public = false
  ) then
    missing_capabilities := array_append(
      missing_capabilities,
      'storage:chat_files_private'
    );
  end if;

  foreach required_table_name in array required_realtime_tables
  loop
    if not exists (
      select 1
      from pg_publication_tables
      where pubname = 'supabase_realtime'
        and schemaname = 'public'
        and tablename = required_table_name
    ) then
      missing_capabilities := array_append(
        missing_capabilities,
        'realtime:' || required_table_name
      );
    end if;

    if not exists (
      select 1
      from pg_class c
      join pg_namespace n on n.oid = c.relnamespace
      where n.nspname = 'public'
        and c.relname = required_table_name
        and c.relreplident = 'f'
    ) then
      missing_capabilities := array_append(
        missing_capabilities,
        'replica_identity:' || required_table_name
      );
    end if;
  end loop;

  return jsonb_build_object(
    'ready',
    cardinality(missing_capabilities) = 0,
    'missing_capabilities',
    to_jsonb(missing_capabilities),
    'profiles_in_realtime',
    exists (
      select 1
      from pg_publication_tables
      where pubname = 'supabase_realtime'
        and schemaname = 'public'
        and tablename = 'profiles'
    ),
    'operations_realtime_hardened',
    not exists (
      select 1
      from unnest(array[
        'minerals',
        'transactions',
        'weighbridge_records',
        'mineral_loads',
        'security_incidents',
        'gate_checks'
      ]) as required_table(table_name)
      where not exists (
        select 1
        from pg_class c
        join pg_namespace n on n.oid = c.relnamespace
        where n.nspname = 'public'
          and c.relname = required_table.table_name
          and c.relreplident = 'f'
      )
    ),
    'private_employee_assets',
    exists (
      select 1 from storage.buckets
      where id = 'employee_assets' and public = false
    ),
    'private_chat_files',
    exists (
      select 1 from storage.buckets
      where id = 'chat_files' and public = false
    )
  );
end;
$$;

create or replace function public.create_notification_internal(
  target_user_id uuid,
  target_company_id uuid,
  target_employee_id uuid,
  notification_title text,
  notification_message text,
  notification_type text,
  notification_actioned_by text default null,
  notification_actioned_by_id uuid default null,
  notification_role_scope text default null,
  notification_org_type text default null,
  notification_importance text default 'normal',
  notification_metadata jsonb default '{}'::jsonb
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  new_notification_id uuid := gen_random_uuid();
begin
  insert into public.notifications (
    id,
    user_id,
    company_id,
    employee_id,
    title,
    message,
    type,
    actioned_by,
    actioned_by_id,
    role_scope,
    org_type,
    importance,
    metadata
  )
  values (
    new_notification_id,
    target_user_id,
    target_company_id,
    target_employee_id,
    notification_title,
    notification_message,
    notification_type,
    notification_actioned_by,
    notification_actioned_by_id,
    notification_role_scope,
    notification_org_type,
    notification_importance,
    coalesce(notification_metadata, '{}'::jsonb)
  );

  return new_notification_id;
end;
$$;

create or replace function public.sync_chat_room_last_message()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.chat_rooms
  set
    last_message_content = case
      when nullif(trim(coalesce(new.content, '')), '') is not null then new.content
      when nullif(trim(coalesce(new.file_name, '')), '') is not null then 'Sent a file: ' || new.file_name
      else 'New message'
    end,
    last_message_timestamp = new.timestamp,
    last_message_sender_id = new.sender_id
  where id = new.chat_room_id;

  return new;
end;
$$;

create trigger handle_chat_rooms_last_message
after insert on public.chat_messages
for each row
execute function public.sync_chat_room_last_message();

create or replace function public.notify_company_management(
  target_company_id uuid,
  notification_title text,
  notification_message text,
  notification_type text,
  notification_actioned_by text default null,
  notification_actioned_by_id uuid default null,
  notification_importance text default 'normal',
  notification_metadata jsonb default '{}'::jsonb
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  company_record public.companies;
  recipient record;
begin
  select *
  into company_record
  from public.companies
  where id = target_company_id;

  if company_record.id is null then
    raise exception 'Company not found';
  end if;

  perform public.create_notification_internal(
    company_record.user_id,
    company_record.id,
    null,
    notification_title,
    notification_message,
    notification_type,
    notification_actioned_by,
    notification_actioned_by_id,
    null,
    company_record.org_type,
    notification_importance,
    notification_metadata
  );

  for recipient in
    select e.user_id, e.role
    from public.employees e
    where e.company_id = target_company_id
      and e.role in ('admin', 'management')
      and e.status = 'active'
      and e.is_dismissed = false
  loop
    perform public.create_notification_internal(
      recipient.user_id,
      company_record.id,
      null,
      notification_title,
      notification_message,
      notification_type,
      notification_actioned_by,
      notification_actioned_by_id,
      recipient.role,
      company_record.org_type,
      notification_importance,
      notification_metadata
    );
  end loop;
end;
$$;

create or replace function public.complete_company_signup(
  company_name text,
  whatsapp_number text,
  org_type text,
  ceo_first_name text default null,
  ceo_last_name text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  company_record public.companies;
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;

  if exists (select 1 from public.companies where user_id = auth.uid()) then
    select * into company_record from public.companies where user_id = auth.uid();
    return to_jsonb(company_record);
  end if;

  update public.profiles
  set
    user_type = 'company',
    display_name = company_name
  where id = auth.uid();

  insert into public.companies (
    user_id,
    company_name,
    whatsapp_number,
    org_type,
    ceo_first_name,
    ceo_last_name
  )
  values (
    auth.uid(),
    trim(company_name),
    trim(whatsapp_number),
    org_type,
    nullif(trim(coalesce(ceo_first_name, '')), ''),
    nullif(trim(coalesce(ceo_last_name, '')), '')
  )
  returning *
  into company_record;

  return to_jsonb(company_record);
end;
$$;

create or replace function public.complete_employee_signup(
  first_name text,
  last_name text,
  whatsapp_number text,
  is_south_african_citizen boolean default true,
  id_number text default null,
  passport_or_workers_permit text default null,
  license_document text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  employee_record public.employees;
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;

  if exists (select 1 from public.employees where user_id = auth.uid()) then
    select * into employee_record from public.employees where user_id = auth.uid();
    return to_jsonb(employee_record);
  end if;

  update public.profiles
  set
    user_type = 'employee',
    display_name = trim(first_name) || ' ' || trim(last_name)
  where id = auth.uid();

  insert into public.employees (
    user_id,
    first_name,
    last_name,
    whatsapp_number,
    status,
    is_south_african_citizen,
    id_number,
    passport_or_workers_permit,
    license_document
  )
  values (
    auth.uid(),
    trim(first_name),
    trim(last_name),
    trim(whatsapp_number),
    'pending_company',
    coalesce(is_south_african_citizen, true),
    nullif(trim(coalesce(id_number, '')), ''),
    nullif(trim(coalesce(passport_or_workers_permit, '')), ''),
    nullif(trim(coalesce(license_document, '')), '')
  )
  returning *
  into employee_record;

  return to_jsonb(employee_record);
end;
$$;

create or replace function public.update_my_company_profile(
  company_name_input text default null,
  whatsapp_number_input text default null,
  logo_url_input text default null,
  ceo_first_name_input text default null,
  ceo_last_name_input text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  company_record public.companies;
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;

  update public.companies
  set
    company_name = coalesce(nullif(trim(coalesce(company_name_input, '')), ''), public.companies.company_name),
    whatsapp_number = coalesce(nullif(trim(coalesce(whatsapp_number_input, '')), ''), public.companies.whatsapp_number),
    logo_url = coalesce(logo_url_input, public.companies.logo_url),
    ceo_first_name = coalesce(nullif(trim(coalesce(ceo_first_name_input, '')), ''), public.companies.ceo_first_name),
    ceo_last_name = coalesce(nullif(trim(coalesce(ceo_last_name_input, '')), ''), public.companies.ceo_last_name)
  where user_id = auth.uid()
  returning *
  into company_record;

  if company_record.id is null then
    raise exception 'Company profile not found';
  end if;

  return to_jsonb(company_record);
end;
$$;

create or replace function public.update_my_employee_profile(
  first_name_input text default null,
  last_name_input text default null,
  whatsapp_number_input text default null,
  profile_photo_url_input text default null,
  is_south_african_citizen_input boolean default null,
  id_number_input text default null,
  passport_or_workers_permit_input text default null,
  license_document_input text default null,
  id_document_url_input text default null,
  passport_document_url_input text default null,
  work_visa_document_url_input text default null,
  license_document_url_input text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  employee_record public.employees;
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;

  update public.employees
  set
    first_name = coalesce(nullif(trim(coalesce(first_name_input, '')), ''), public.employees.first_name),
    last_name = coalesce(nullif(trim(coalesce(last_name_input, '')), ''), public.employees.last_name),
    whatsapp_number = coalesce(nullif(trim(coalesce(whatsapp_number_input, '')), ''), public.employees.whatsapp_number),
    profile_photo_url = coalesce(profile_photo_url_input, public.employees.profile_photo_url),
    is_south_african_citizen = coalesce(is_south_african_citizen_input, public.employees.is_south_african_citizen),
    id_number = coalesce(id_number_input, public.employees.id_number),
    passport_or_workers_permit = coalesce(passport_or_workers_permit_input, public.employees.passport_or_workers_permit),
    license_document = coalesce(license_document_input, public.employees.license_document),
    id_document_url = coalesce(id_document_url_input, public.employees.id_document_url),
    passport_document_url = coalesce(passport_document_url_input, public.employees.passport_document_url),
    work_visa_document_url = coalesce(work_visa_document_url_input, public.employees.work_visa_document_url),
    license_document_url = coalesce(license_document_url_input, public.employees.license_document_url)
  where user_id = auth.uid()
  returning *
  into employee_record;

  if employee_record.id is null then
    raise exception 'Employee profile not found';
  end if;

  return to_jsonb(employee_record);
end;
$$;

create or replace function public.request_company_link(target_company_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  employee_record public.employees;
  company_record public.companies;
  manager_recipient record;
  actor_name text;
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;

  select * into employee_record from public.employees where user_id = auth.uid();
  if employee_record.id is null then
    raise exception 'Employee profile not found';
  end if;

  select * into company_record from public.companies where id = target_company_id;
  if company_record.id is null then
    raise exception 'Company not found';
  end if;

  if employee_record.company_id is not null and employee_record.status not in ('rejected', 'pending_company') then
    raise exception 'Employee already linked to a company';
  end if;

  update public.employees
  set company_id = target_company_id, role = null, status = 'pending_company'
  where id = employee_record.id
  returning *
  into employee_record;

  actor_name := employee_record.first_name || ' ' || employee_record.last_name;

  insert into public.employee_status_history (
    employee_id,
    company_id,
    status,
    actioned_by_id,
    actioned_by_name
  )
  values (
    employee_record.id,
    target_company_id,
    'company_requested',
    auth.uid(),
    actor_name
  );

  perform public.create_notification_internal(
    company_record.user_id,
    company_record.id,
    employee_record.id,
    'New Employee Request',
    actor_name || ' has requested to join your company.',
    'employeeRequest',
    actor_name,
    auth.uid(),
    null,
    company_record.org_type,
    'high',
    jsonb_build_object('employee_id', employee_record.id, 'employee_name', actor_name, 'company_id', company_record.id)
  );

  for manager_recipient in
    select e.user_id, e.role
    from public.employees e
    where e.company_id = company_record.id
      and e.role in ('admin', 'management')
      and e.status = 'active'
      and e.is_dismissed = false
  loop
    perform public.create_notification_internal(
      manager_recipient.user_id,
      company_record.id,
      employee_record.id,
      'New Employee Request',
      actor_name || ' has requested to join your company.',
      'employeeRequest',
      actor_name,
      auth.uid(),
      manager_recipient.role,
      company_record.org_type,
      'high',
      jsonb_build_object('employee_id', employee_record.id, 'employee_name', actor_name, 'company_id', company_record.id)
    );
  end loop;

  perform public.create_notification_internal(
    auth.uid(),
    company_record.id,
    employee_record.id,
    'Company Request Sent',
    'Your request to join ' || company_record.company_name || ' has been sent. Please wait for approval.',
    'employeeRequest',
    actor_name,
    auth.uid(),
    null,
    company_record.org_type,
    'normal',
    jsonb_build_object('company_id', company_record.id, 'company_name', company_record.company_name)
  );

  return to_jsonb(employee_record);
end;
$$;

create or replace function public.approve_employee_request(target_employee_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  employee_record public.employees;
  company_record public.companies;
  actor_name text;
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;

  select * into employee_record from public.employees where id = target_employee_id;
  if employee_record.id is null or employee_record.company_id is null then
    raise exception 'Employee request not found';
  end if;

  if not public.is_company_manager(employee_record.company_id) then
    raise exception 'Not authorized to approve employee requests';
  end if;

  select * into company_record from public.companies where id = employee_record.company_id;
  actor_name := coalesce((select display_name from public.profiles where id = auth.uid()), 'Company Admin');

  update public.employees
  set status = 'pending_role'
  where id = target_employee_id
  returning *
  into employee_record;

  insert into public.employee_status_history (
    employee_id,
    company_id,
    status,
    actioned_by_id,
    actioned_by_name
  )
  values (
    employee_record.id,
    employee_record.company_id,
    'request_approved',
    auth.uid(),
    actor_name
  );

  perform public.create_notification_internal(
    employee_record.user_id,
    employee_record.company_id,
    employee_record.id,
    'Request Approved',
    'Your request to join ' || company_record.company_name || ' has been approved. Waiting for role assignment.',
    'employeeRequest',
    actor_name,
    auth.uid(),
    null,
    company_record.org_type,
    'high',
    jsonb_build_object('company_id', company_record.id, 'company_name', company_record.company_name, 'employee_id', employee_record.id)
  );

  return to_jsonb(employee_record);
end;
$$;

create or replace function public.assign_employee_role(
  target_employee_id uuid,
  target_role text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  employee_record public.employees;
  company_record public.companies;
  actor_name text;
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;

  select * into employee_record from public.employees where id = target_employee_id;
  if employee_record.id is null or employee_record.company_id is null then
    raise exception 'Employee not found';
  end if;

  if not public.is_company_manager(employee_record.company_id) then
    raise exception 'Not authorized to assign employee roles';
  end if;

  select * into company_record from public.companies where id = employee_record.company_id;

  if company_record.org_type = 'mineSupplier' and target_role not in ('security', 'controllerWB', 'admin', 'management') then
    raise exception 'Role % is not valid for %', target_role, company_record.org_type;
  elsif company_record.org_type = 'buyer' and target_role not in ('admin', 'management') then
    raise exception 'Role % is not valid for %', target_role, company_record.org_type;
  elsif company_record.org_type = 'transporter' and target_role not in ('driver', 'admin', 'management') then
    raise exception 'Role % is not valid for %', target_role, company_record.org_type;
  end if;

  actor_name := coalesce((select display_name from public.profiles where id = auth.uid()), 'Company Admin');

  update public.employees
  set
    role = target_role,
    status = 'active',
    is_dismissed = false,
    is_dismissed_pending_appeal = false,
    is_dismissal_final = false
  where id = target_employee_id
  returning *
  into employee_record;

  insert into public.employee_status_history (
    employee_id,
    company_id,
    status,
    actioned_by_id,
    actioned_by_name,
    assigned_role
  )
  values (
    employee_record.id,
    employee_record.company_id,
    'role_assigned',
    auth.uid(),
    actor_name,
    target_role
  );

  perform public.create_notification_internal(
    employee_record.user_id,
    employee_record.company_id,
    employee_record.id,
    'Role Assigned',
    'You have been assigned the ' || target_role || ' role at ' || company_record.company_name || '.',
    'roleAssigned',
    actor_name,
    auth.uid(),
    target_role,
    company_record.org_type,
    'high',
    jsonb_build_object('company_id', company_record.id, 'company_name', company_record.company_name, 'employee_id', employee_record.id, 'role', target_role)
  );

  return to_jsonb(employee_record);
end;
$$;

create or replace function public.decline_employee_request(target_employee_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  employee_record public.employees;
  company_record public.companies;
  actor_name text;
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;

  select * into employee_record from public.employees where id = target_employee_id;
  if employee_record.id is null or employee_record.company_id is null then
    raise exception 'Employee request not found';
  end if;

  if not public.is_company_manager(employee_record.company_id) then
    raise exception 'Not authorized to decline employee requests';
  end if;

  select * into company_record from public.companies where id = employee_record.company_id;
  actor_name := coalesce((select display_name from public.profiles where id = auth.uid()), 'Company Admin');

  insert into public.employee_status_history (
    employee_id,
    company_id,
    status,
    actioned_by_id,
    actioned_by_name
  )
  values (
    employee_record.id,
    employee_record.company_id,
    'request_declined',
    auth.uid(),
    actor_name
  );

  update public.employees
  set company_id = null, role = null, status = 'rejected'
  where id = target_employee_id
  returning *
  into employee_record;

  perform public.create_notification_internal(
    employee_record.user_id,
    company_record.id,
    employee_record.id,
    'Request Declined',
    'Your request to join ' || company_record.company_name || ' has been declined.',
    'requestDeclined',
    actor_name,
    auth.uid(),
    null,
    company_record.org_type,
    'high',
    jsonb_build_object('company_id', company_record.id, 'company_name', company_record.company_name, 'employee_id', employee_record.id)
  );

  return to_jsonb(employee_record);
end;
$$;

create or replace function public.create_fleet_vehicle(
  target_company_id uuid,
  vehicle_registration_number text,
  vehicle_registration_expiry_date timestamptz default null,
  first_trailer_regs text default null,
  second_trailer_regs text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  vehicle_record public.fleet_vehicles;
  actor_name text;
begin
  if not public.can_manage_fleet(target_company_id) then
    raise exception 'Not authorized to manage this fleet';
  end if;

  insert into public.fleet_vehicles (
    company_id,
    vehicle_registration_number,
    vehicle_registration_expiry_date,
    first_trailer_regs,
    second_trailer_regs
  )
  values (
    target_company_id,
    trim(vehicle_registration_number),
    vehicle_registration_expiry_date,
    nullif(trim(coalesce(first_trailer_regs, '')), ''),
    nullif(trim(coalesce(second_trailer_regs, '')), '')
  )
  returning *
  into vehicle_record;

  actor_name := coalesce((select display_name from public.profiles where id = auth.uid()), 'Fleet Manager');

  perform public.notify_company_management(
    target_company_id,
    'Vehicle Added',
    actor_name || ' added vehicle ' || vehicle_record.vehicle_registration_number || ' to the fleet.',
    'fleetVehicleAdded',
    actor_name,
    auth.uid(),
    'normal',
    jsonb_build_object('vehicle_id', vehicle_record.id, 'vehicle_registration_number', vehicle_record.vehicle_registration_number)
  );

  return to_jsonb(vehicle_record);
end;
$$;

create or replace function public.update_fleet_vehicle(
  target_vehicle_id uuid,
  vehicle_registration_number text default null,
  vehicle_registration_expiry_date timestamptz default null,
  first_trailer_regs text default null,
  second_trailer_regs text default null,
  is_active boolean default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  vehicle_record public.fleet_vehicles;
  actor_name text;
begin
  select * into vehicle_record from public.fleet_vehicles where id = target_vehicle_id;
  if vehicle_record.id is null then
    raise exception 'Fleet vehicle not found';
  end if;

  if not public.can_manage_fleet(vehicle_record.company_id) then
    raise exception 'Not authorized to manage this fleet';
  end if;

  update public.fleet_vehicles
  set
    vehicle_registration_number = coalesce(nullif(trim(coalesce(vehicle_registration_number, '')), ''), public.fleet_vehicles.vehicle_registration_number),
    vehicle_registration_expiry_date = coalesce(vehicle_registration_expiry_date, public.fleet_vehicles.vehicle_registration_expiry_date),
    first_trailer_regs = coalesce(first_trailer_regs, public.fleet_vehicles.first_trailer_regs),
    second_trailer_regs = coalesce(second_trailer_regs, public.fleet_vehicles.second_trailer_regs),
    is_active = coalesce(is_active, public.fleet_vehicles.is_active)
  where id = target_vehicle_id
  returning *
  into vehicle_record;

  if is_active is not null then
    actor_name := coalesce((select display_name from public.profiles where id = auth.uid()), 'Fleet Manager');

    perform public.notify_company_management(
      vehicle_record.company_id,
      case when vehicle_record.is_active then 'Vehicle Activated' else 'Vehicle Deactivated' end,
      actor_name || ' marked vehicle ' || vehicle_record.vehicle_registration_number || ' as ' || case when vehicle_record.is_active then 'active' else 'inactive' end || '.',
      'fleetVehicleStatusChanged',
      actor_name,
      auth.uid(),
      'normal',
      jsonb_build_object('vehicle_id', vehicle_record.id, 'vehicle_registration_number', vehicle_record.vehicle_registration_number, 'is_active', vehicle_record.is_active)
    );
  end if;

  return to_jsonb(vehicle_record);
end;
$$;

create or replace function public.assign_fleet_driver(
  target_vehicle_id uuid,
  target_driver_employee_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  vehicle_record public.fleet_vehicles;
  driver_record public.employees;
  company_record public.companies;
  actor_name text;
begin
  select * into vehicle_record from public.fleet_vehicles where id = target_vehicle_id;
  if vehicle_record.id is null then
    raise exception 'Fleet vehicle not found';
  end if;

  if not public.can_manage_fleet(vehicle_record.company_id) then
    raise exception 'Not authorized to manage this fleet';
  end if;

  select * into driver_record from public.employees where id = target_driver_employee_id;
  if driver_record.id is null then
    raise exception 'Driver not found';
  end if;

  if driver_record.company_id is distinct from vehicle_record.company_id then
    raise exception 'Driver must belong to the same company as the vehicle';
  end if;

  if driver_record.role is distinct from 'driver' or driver_record.status is distinct from 'active' then
    raise exception 'Selected employee is not an active driver';
  end if;

  if exists (
    select 1
    from public.fleet_vehicles fv
    where fv.assigned_driver_employee_id = target_driver_employee_id
      and fv.id <> target_vehicle_id
  ) then
    raise exception 'Driver is already assigned to another vehicle';
  end if;

  select * into company_record from public.companies where id = vehicle_record.company_id;

  update public.fleet_vehicles
  set
    assigned_driver_employee_id = driver_record.id,
    driver_user_id = driver_record.user_id,
    driver_first_name = driver_record.first_name,
    driver_last_name = driver_record.last_name,
    driver_id_number = driver_record.id_number,
    driver_passport_number = driver_record.passport_or_workers_permit,
    driver_work_permit = driver_record.passport_or_workers_permit,
    drivers_license_document = driver_record.license_document,
    driver_id_document_url = driver_record.id_document_url,
    driver_passport_document_url = driver_record.passport_document_url,
    driver_work_visa_document_url = driver_record.work_visa_document_url,
    driver_license_document_url = driver_record.license_document_url,
    driver_is_south_african_citizen = driver_record.is_south_african_citizen
  where id = target_vehicle_id
  returning *
  into vehicle_record;

  actor_name := coalesce((select display_name from public.profiles where id = auth.uid()), 'Fleet Manager');

  perform public.notify_company_management(
    vehicle_record.company_id,
    'Driver Assigned',
    actor_name || ' assigned ' || driver_record.first_name || ' ' || driver_record.last_name || ' to vehicle ' || vehicle_record.vehicle_registration_number || '.',
    'fleetDriverAssigned',
    actor_name,
    auth.uid(),
    'normal',
    jsonb_build_object('vehicle_id', vehicle_record.id, 'vehicle_registration_number', vehicle_record.vehicle_registration_number, 'driver_id', driver_record.id, 'driver_name', driver_record.first_name || ' ' || driver_record.last_name)
  );

  perform public.create_notification_internal(
    driver_record.user_id,
    vehicle_record.company_id,
    driver_record.id,
    'Vehicle Assignment',
    'You have been assigned to vehicle ' || vehicle_record.vehicle_registration_number || '.',
    'fleetDriverAssigned',
    actor_name,
    auth.uid(),
    'driver',
    company_record.org_type,
    'high',
    jsonb_build_object('vehicle_id', vehicle_record.id, 'vehicle_registration_number', vehicle_record.vehicle_registration_number)
  );

  return to_jsonb(vehicle_record);
end;
$$;

create or replace function public.unassign_fleet_driver(target_vehicle_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  vehicle_record public.fleet_vehicles;
  company_record public.companies;
  driver_employee_id uuid;
  driver_user_id uuid;
  driver_name text;
  actor_name text;
begin
  select * into vehicle_record from public.fleet_vehicles where id = target_vehicle_id;
  if vehicle_record.id is null then
    raise exception 'Fleet vehicle not found';
  end if;

  if not public.can_manage_fleet(vehicle_record.company_id) then
    raise exception 'Not authorized to manage this fleet';
  end if;

  driver_employee_id := vehicle_record.assigned_driver_employee_id;
  driver_user_id := vehicle_record.driver_user_id;
  driver_name := trim(coalesce(vehicle_record.driver_first_name, '') || ' ' || coalesce(vehicle_record.driver_last_name, ''));
  select * into company_record from public.companies where id = vehicle_record.company_id;

  update public.fleet_vehicles
  set
    assigned_driver_employee_id = null,
    driver_user_id = null,
    driver_first_name = null,
    driver_last_name = null,
    driver_id_number = null,
    driver_passport_number = null,
    driver_work_permit = null,
    drivers_license_document = null,
    driver_id_document_url = null,
    driver_passport_document_url = null,
    driver_work_visa_document_url = null,
    driver_license_document_url = null,
    driver_is_south_african_citizen = null
  where id = target_vehicle_id
  returning *
  into vehicle_record;

  actor_name := coalesce((select display_name from public.profiles where id = auth.uid()), 'Fleet Manager');

  if driver_employee_id is not null then
    perform public.notify_company_management(
      vehicle_record.company_id,
      'Driver Unassigned',
      actor_name || ' unassigned ' || coalesce(nullif(driver_name, ''), 'the driver') || ' from vehicle ' || vehicle_record.vehicle_registration_number || '.',
      'fleetDriverUnassigned',
      actor_name,
      auth.uid(),
      'normal',
      jsonb_build_object('vehicle_id', vehicle_record.id, 'vehicle_registration_number', vehicle_record.vehicle_registration_number, 'driver_id', driver_employee_id, 'driver_name', driver_name)
    );

    if driver_user_id is not null then
      perform public.create_notification_internal(
        driver_user_id,
        vehicle_record.company_id,
        driver_employee_id,
        'Vehicle Assignment Removed',
        'You have been unassigned from vehicle ' || vehicle_record.vehicle_registration_number || '.',
        'fleetDriverUnassigned',
        actor_name,
        auth.uid(),
        'driver',
        company_record.org_type,
        'high',
        jsonb_build_object('vehicle_id', vehicle_record.id, 'vehicle_registration_number', vehicle_record.vehicle_registration_number)
      );
    end if;
  end if;

  return to_jsonb(vehicle_record);
end;
$$;

create or replace function public.delete_fleet_vehicle(target_vehicle_id uuid)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  vehicle_record public.fleet_vehicles;
begin
  select * into vehicle_record from public.fleet_vehicles where id = target_vehicle_id;
  if vehicle_record.id is null then
    return false;
  end if;

  if not public.can_manage_fleet(vehicle_record.company_id) then
    raise exception 'Not authorized to manage this fleet';
  end if;

  delete from public.fleet_vehicles where id = target_vehicle_id;
  return true;
end;
$$;

create or replace function public.mark_chat_messages_read(
  target_chat_room_id uuid,
  target_message_id uuid default null
)
returns bigint
language plpgsql
security definer
set search_path = public
as $$
declare
  updated_count bigint;
begin
  if not public.can_access_chat_room(target_chat_room_id) then
    raise exception 'Not authorized to access this chat room';
  end if;

  update public.chat_messages
  set is_read = true
  where chat_room_id = target_chat_room_id
    and sender_id <> auth.uid()
    and is_read = false
    and (target_message_id is null or id = target_message_id);

  get diagnostics updated_count = row_count;
  return updated_count;
end;
$$;

create or replace function public.initiate_employee_dismissal(
  target_employee_id uuid,
  dismissal_reason_input text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  employee_record public.employees;
  company_record public.companies;
  actor_name text;
begin
  select * into employee_record from public.employees where id = target_employee_id;
  if employee_record.id is null or employee_record.company_id is null then
    raise exception 'Employee not found';
  end if;

  if not public.is_company_manager(employee_record.company_id) then
    raise exception 'Not authorized to dismiss this employee';
  end if;

  select * into company_record from public.companies where id = employee_record.company_id;
  actor_name := coalesce((select display_name from public.profiles where id = auth.uid()), 'Company Admin');

  update public.employees
  set
    status = 'dismissed',
    is_dismissed = true,
    dismissal_date = timezone('utc', now()),
    dismissal_reason = dismissal_reason_input,
    dismissal_by_id = auth.uid(),
    is_dismissed_pending_appeal = true,
    is_dismissal_final = false,
    account_deletion_date = null
  where id = target_employee_id
  returning *
  into employee_record;

  insert into public.employee_status_history (
    employee_id,
    company_id,
    status,
    actioned_by_id,
    actioned_by_name,
    dismissal_reason
  )
  values (
    employee_record.id,
    employee_record.company_id,
    'dismissal_initiated',
    auth.uid(),
    actor_name,
    dismissal_reason_input
  );

  perform public.create_notification_internal(
    employee_record.user_id,
    employee_record.company_id,
    employee_record.id,
    'Dismissal Initiated',
    'You have been dismissed from ' || company_record.company_name || '. Reason: ' || dismissal_reason_input,
    'dismissalInitiated',
    actor_name,
    auth.uid(),
    employee_record.role,
    company_record.org_type,
    'extreme',
    jsonb_build_object('employee_id', employee_record.id, 'company_id', employee_record.company_id, 'dismissal_reason', dismissal_reason_input)
  );

  return to_jsonb(employee_record);
end;
$$;

create or replace function public.submit_employee_dismissal_appeal(appeal_reason_input text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  employee_record public.employees;
  actor_name text;
begin
  select * into employee_record from public.employees where user_id = auth.uid();
  if employee_record.id is null or employee_record.company_id is null then
    raise exception 'Employee not found';
  end if;

  if employee_record.is_dismissed_pending_appeal = false then
    raise exception 'Employee does not have an active dismissal appeal window';
  end if;

  actor_name := employee_record.first_name || ' ' || employee_record.last_name;

  insert into public.employee_status_history (
    employee_id,
    company_id,
    status,
    actioned_by_id,
    actioned_by_name,
    appeal_reason
  )
  values (
    employee_record.id,
    employee_record.company_id,
    'appeal_submitted',
    auth.uid(),
    actor_name,
    appeal_reason_input
  );

  perform public.notify_company_management(
    employee_record.company_id,
    'Dismissal Appeal Submitted',
    actor_name || ' has submitted a dismissal appeal.',
    'dismissalAppeal',
    actor_name,
    auth.uid(),
    'extreme',
    jsonb_build_object('employee_id', employee_record.id, 'appeal_reason', appeal_reason_input)
  );

  return to_jsonb(employee_record);
end;
$$;

create or replace function public.resolve_employee_dismissal(
  target_employee_id uuid,
  uphold_dismissal boolean,
  decision_reason_input text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  employee_record public.employees;
  deletion_date timestamptz;
  actor_name text;
begin
  select * into employee_record from public.employees where id = target_employee_id;
  if employee_record.id is null or employee_record.company_id is null then
    raise exception 'Employee not found';
  end if;

  if not public.is_company_manager(employee_record.company_id) then
    raise exception 'Not authorized to resolve this dismissal';
  end if;

  actor_name := coalesce((select display_name from public.profiles where id = auth.uid()), 'Company Admin');
  deletion_date := case when uphold_dismissal then timezone('utc', now()) + interval '7 days' else null end;

  update public.employees
  set
    status = case when uphold_dismissal then 'dismissed' when role is null then 'pending_role' else 'active' end,
    is_dismissed = uphold_dismissal,
    is_dismissed_pending_appeal = false,
    is_dismissal_final = uphold_dismissal,
    account_deletion_date = deletion_date,
    dismissal_reason = case when uphold_dismissal then dismissal_reason else null end,
    dismissal_date = case when uphold_dismissal then dismissal_date else null end,
    dismissal_by_id = case when uphold_dismissal then dismissal_by_id else null end
  where id = target_employee_id
  returning *
  into employee_record;

  insert into public.employee_status_history (
    employee_id,
    company_id,
    status,
    actioned_by_id,
    actioned_by_name,
    decision_reason,
    uphold_dismissal,
    account_deletion_date
  )
  values (
    employee_record.id,
    employee_record.company_id,
    case when uphold_dismissal then 'dismissal_upheld' else 'dismissal_reversed' end,
    auth.uid(),
    actor_name,
    decision_reason_input,
    uphold_dismissal,
    deletion_date
  );

  perform public.create_notification_internal(
    employee_record.user_id,
    employee_record.company_id,
    employee_record.id,
    'Final Decision on Dismissal',
    case when uphold_dismissal
      then 'Your dismissal has been upheld. Your account will be deleted in 7 days. Reason: ' || decision_reason_input
      else 'Your appeal has been successful. The dismissal has been overturned. Reason: ' || decision_reason_input
    end,
    'dismissalFinal',
    actor_name,
    auth.uid(),
    employee_record.role,
    (select org_type from public.companies where id = employee_record.company_id),
    case when uphold_dismissal then 'extreme' else 'high' end,
    jsonb_build_object('employee_id', employee_record.id, 'uphold_dismissal', uphold_dismissal, 'decision_reason', decision_reason_input, 'account_deletion_date', deletion_date)
  );

  return to_jsonb(employee_record);
end;
$$;

create or replace function public.create_actioned_notification(
  target_user_id uuid,
  notification_title text,
  notification_message text,
  notification_type text,
  target_company_id uuid default null,
  target_employee_id uuid default null,
  notification_actioned_by text default null,
  notification_actioned_by_id uuid default null,
  notification_role_scope text default null,
  notification_org_type text default null,
  notification_importance text default 'normal',
  notification_metadata jsonb default '{}'::jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  notification_id uuid;
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;

  if target_user_id <> auth.uid() then
    if target_company_id is null or not public.is_company_manager(target_company_id) then
      raise exception 'Not authorized to create notifications for this user';
    end if;

    if not exists (
      select 1 from public.companies c where c.id = target_company_id and c.user_id = target_user_id
      union all
      select 1 from public.employees e where e.company_id = target_company_id and e.user_id = target_user_id
    ) then
      raise exception 'Target user is not part of the supplied company context';
    end if;
  end if;

  notification_id := public.create_notification_internal(
    target_user_id,
    target_company_id,
    target_employee_id,
    notification_title,
    notification_message,
    notification_type,
    notification_actioned_by,
    coalesce(notification_actioned_by_id, auth.uid()),
    notification_role_scope,
    notification_org_type,
    notification_importance,
    notification_metadata
  );

  return (select to_jsonb(n.*) from public.notifications n where n.id = notification_id);
end;
$$;

create or replace function public.set_notification_read(
  target_notification_id uuid,
  read_state boolean default true
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  notification_record public.notifications;
begin
  update public.notifications
  set is_read = read_state
  where id = target_notification_id
    and user_id = auth.uid()
  returning *
  into notification_record;

  if notification_record.id is null then
    raise exception 'Notification not found';
  end if;

  return to_jsonb(notification_record);
end;
$$;

create or replace function public.mark_all_notifications_read()
returns bigint
language plpgsql
security definer
set search_path = public
as $$
declare
  updated_count bigint;
begin
  update public.notifications
  set is_read = true
  where user_id = auth.uid()
    and is_read = false;

  get diagnostics updated_count = row_count;
  return updated_count;
end;
$$;

create or replace function public.cleanup_old_broadcast_messages()
returns bigint
language plpgsql
security definer
set search_path = public
as $$
declare
  deleted_count bigint;
begin
  delete from public.broadcast_messages
  where timestamp < timezone('utc', now()) - interval '30 days';

  get diagnostics deleted_count = row_count;
  return deleted_count;
end;
$$;

alter table public.profiles enable row level security;
alter table public.companies enable row level security;
alter table public.employees enable row level security;
alter table public.employee_status_history enable row level security;
alter table public.notifications enable row level security;
alter table public.fleet_vehicles enable row level security;
alter table public.chat_rooms enable row level security;
alter table public.chat_messages enable row level security;
alter table public.broadcast_messages enable row level security;
alter table public.minerals enable row level security;
alter table public.transactions enable row level security;
alter table public.weighbridge_records enable row level security;
alter table public.mineral_loads enable row level security;
alter table public.security_incidents enable row level security;
alter table public.gate_checks enable row level security;

create policy profiles_select_own on public.profiles for select to authenticated using (id = (select auth.uid()));
create policy profiles_update_own on public.profiles for update to authenticated using (id = (select auth.uid())) with check (id = (select auth.uid()));
create policy companies_select_authenticated on public.companies for select to authenticated using (true);
create policy employees_select_self_or_company_managers on public.employees for select to authenticated using (user_id = (select auth.uid()) or public.is_company_manager(company_id));
create policy employee_status_history_select_self_or_company_managers on public.employee_status_history for select to authenticated using (public.is_employee_self(employee_id) or public.is_company_manager(company_id));
create policy notifications_select_own on public.notifications for select to authenticated using (user_id = (select auth.uid()));
create policy fleet_vehicles_select_company_staff on public.fleet_vehicles for select to authenticated using (public.is_company_staff(company_id));
create policy chat_rooms_select_members on public.chat_rooms for select to authenticated using (public.are_chat_participants_allowed(participant_ids));
create policy chat_rooms_insert_members on public.chat_rooms for insert to authenticated with check (public.are_chat_participants_allowed(participant_ids));
create policy chat_messages_select_members on public.chat_messages for select to authenticated using (public.can_access_chat_room(chat_room_id));
create policy chat_messages_insert_members on public.chat_messages for insert to authenticated with check (sender_id = (select auth.uid()) and public.can_access_chat_room(chat_room_id));
create policy broadcast_messages_select_company_staff on public.broadcast_messages for select to authenticated using (public.can_access_broadcast_message(payload));
create policy broadcast_messages_insert_company_managers on public.broadcast_messages for insert to authenticated with check (public.can_create_broadcast_message(payload, created_by));
create policy minerals_select_authenticated on public.minerals for select to authenticated using (true);
create policy minerals_insert_company_managers on public.minerals for insert to authenticated with check (public.is_company_manager(company_id));
create policy minerals_update_company_managers on public.minerals for update to authenticated using (public.is_company_manager(company_id)) with check (public.is_company_manager(company_id));
create policy minerals_delete_company_managers on public.minerals for delete to authenticated using (public.is_company_manager(company_id));
create policy transactions_select_company_staff on public.transactions for select to authenticated using (public.is_company_staff(supplier_company_id) or public.is_company_staff(buyer_company_id) or public.is_company_staff(transporter_company_id));
create policy transactions_insert_company_managers on public.transactions for insert to authenticated with check (public.is_company_manager(supplier_company_id) or public.is_company_manager(buyer_company_id) or public.is_company_manager(transporter_company_id));
create policy transactions_update_company_managers on public.transactions for update to authenticated using (public.is_company_manager(supplier_company_id) or public.is_company_manager(buyer_company_id) or public.is_company_manager(transporter_company_id)) with check (public.is_company_manager(supplier_company_id) or public.is_company_manager(buyer_company_id) or public.is_company_manager(transporter_company_id));
create policy transactions_delete_company_managers on public.transactions for delete to authenticated using (public.is_company_manager(supplier_company_id) or public.is_company_manager(buyer_company_id) or public.is_company_manager(transporter_company_id));
create policy weighbridge_records_select_company_staff on public.weighbridge_records for select to authenticated using (public.is_company_staff(company_id));
create policy weighbridge_records_insert_allowed_roles on public.weighbridge_records for insert to authenticated with check (public.has_company_role(company_id, array['controllerWB', 'admin', 'management']));
create policy weighbridge_records_update_allowed_roles on public.weighbridge_records for update to authenticated using (public.has_company_role(company_id, array['controllerWB', 'admin', 'management'])) with check (public.has_company_role(company_id, array['controllerWB', 'admin', 'management']));
create policy weighbridge_records_delete_company_managers on public.weighbridge_records for delete to authenticated using (public.is_company_manager(company_id));
create policy mineral_loads_company_staff on public.mineral_loads for all to authenticated using (exists (select 1 from public.fleet_vehicles fv where fv.id = vehicle_id and public.is_company_staff(fv.company_id))) with check (exists (select 1 from public.fleet_vehicles fv where fv.id = vehicle_id and public.is_company_manager(fv.company_id)));
create policy security_incidents_select_company_staff on public.security_incidents for select to authenticated using (public.is_company_staff(company_id));
create policy security_incidents_insert_allowed_roles on public.security_incidents for insert to authenticated with check (public.has_company_role(company_id, array['security', 'admin', 'management']));
create policy security_incidents_update_allowed_roles on public.security_incidents for update to authenticated using (public.has_company_role(company_id, array['security', 'admin', 'management'])) with check (public.has_company_role(company_id, array['security', 'admin', 'management']));
create policy security_incidents_delete_company_managers on public.security_incidents for delete to authenticated using (public.is_company_manager(company_id));
create policy gate_checks_select_company_staff on public.gate_checks for select to authenticated using (public.is_company_staff(company_id));
create policy gate_checks_insert_allowed_roles on public.gate_checks for insert to authenticated with check (public.has_company_role(company_id, array['security', 'admin', 'management']));
create policy gate_checks_update_allowed_roles on public.gate_checks for update to authenticated using (public.has_company_role(company_id, array['security', 'admin', 'management'])) with check (public.has_company_role(company_id, array['security', 'admin', 'management']));
create policy gate_checks_delete_company_managers on public.gate_checks for delete to authenticated using (public.is_company_manager(company_id));

do $$
declare
  storage_policy record;
begin
  for storage_policy in
    select policyname
    from pg_policies
    where schemaname = 'storage'
      and tablename = 'objects'
  loop
    execute format('drop policy if exists %I on storage.objects', storage_policy.policyname);
  end loop;
end;
$$;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values
  ('company_assets', 'company_assets', true, 10485760, array['image/png', 'image/jpeg', 'image/webp', 'image/svg+xml']),
  ('employee_assets', 'employee_assets', false, 26214400, array['image/png', 'image/jpeg', 'image/webp', 'application/pdf']),
  ('chat_files', 'chat_files', false, 26214400, array['image/png', 'image/jpeg', 'image/webp', 'application/pdf'])
on conflict (id) do update
set public = excluded.public, file_size_limit = excluded.file_size_limit, allowed_mime_types = excluded.allowed_mime_types;

create policy company_assets_insert on storage.objects for insert to authenticated with check (bucket_id = 'company_assets' and (storage.foldername(name))[1] = 'company_logos' and public.is_company_owner(((storage.foldername(name))[2])::uuid));
create policy company_assets_update on storage.objects for update to authenticated using (bucket_id = 'company_assets' and (storage.foldername(name))[1] = 'company_logos' and public.is_company_owner(((storage.foldername(name))[2])::uuid)) with check (bucket_id = 'company_assets' and (storage.foldername(name))[1] = 'company_logos' and public.is_company_owner(((storage.foldername(name))[2])::uuid));
create policy employee_assets_select_employee_scoped on storage.objects for select to authenticated using (
  bucket_id = 'employee_assets'
  and (
    (
      (storage.foldername(name))[1] = 'profile_photos'
      and public.can_access_employee_profile_photo(((storage.foldername(name))[2])::uuid)
    )
    or (
      (storage.foldername(name))[1] in ('id_documents', 'passport_documents', 'work_visa_documents', 'license_documents')
      and public.can_access_employee_document(((storage.foldername(name))[2])::uuid)
    )
  )
);
create policy employee_assets_insert on storage.objects for insert to authenticated with check (bucket_id = 'employee_assets' and (storage.foldername(name))[1] in ('profile_photos', 'id_documents', 'passport_documents', 'work_visa_documents', 'license_documents') and public.is_employee_self(((storage.foldername(name))[2])::uuid));
create policy employee_assets_update on storage.objects for update to authenticated using (bucket_id = 'employee_assets' and (storage.foldername(name))[1] in ('profile_photos', 'id_documents', 'passport_documents', 'work_visa_documents', 'license_documents') and public.is_employee_self(((storage.foldername(name))[2])::uuid)) with check (bucket_id = 'employee_assets' and (storage.foldername(name))[1] in ('profile_photos', 'id_documents', 'passport_documents', 'work_visa_documents', 'license_documents') and public.is_employee_self(((storage.foldername(name))[2])::uuid));
create policy chat_files_select_room_participants on storage.objects for select to authenticated using (bucket_id = 'chat_files' and public.can_access_chat_room(((storage.foldername(name))[1])::uuid));
create policy chat_files_insert on storage.objects for insert to authenticated with check (bucket_id = 'chat_files' and public.can_access_chat_room(((storage.foldername(name))[1])::uuid));
create policy chat_files_update on storage.objects for update to authenticated using (bucket_id = 'chat_files' and public.can_access_chat_room(((storage.foldername(name))[1])::uuid)) with check (bucket_id = 'chat_files' and public.can_access_chat_room(((storage.foldername(name))[1])::uuid));

grant select on public.profiles to authenticated;
grant select on public.companies to authenticated;
grant select on public.employees to authenticated;
grant select on public.employee_status_history to authenticated;
grant select on public.notifications to authenticated;
grant select on public.fleet_vehicles to authenticated;
grant select, insert on public.chat_rooms to authenticated;
grant select, insert on public.chat_messages to authenticated;
grant select, insert on public.broadcast_messages to authenticated;
grant select, insert, update, delete on public.minerals to authenticated;
grant select, insert, update, delete on public.transactions to authenticated;
grant select, insert, update, delete on public.weighbridge_records to authenticated;
grant select, insert, update, delete on public.mineral_loads to authenticated;
grant select, insert, update, delete on public.security_incidents to authenticated;
grant select, insert, update, delete on public.gate_checks to authenticated;

grant execute on function public.complete_company_signup(text, text, text, text, text) to authenticated;
grant execute on function public.complete_employee_signup(text, text, text, boolean, text, text, text) to authenticated;
grant execute on function public.update_my_company_profile(text, text, text, text, text) to authenticated;
grant execute on function public.update_my_employee_profile(text, text, text, text, boolean, text, text, text, text, text, text, text) to authenticated;
grant execute on function public.request_company_link(uuid) to authenticated;
grant execute on function public.approve_employee_request(uuid) to authenticated;
grant execute on function public.assign_employee_role(uuid, text) to authenticated;
grant execute on function public.decline_employee_request(uuid) to authenticated;
grant execute on function public.create_fleet_vehicle(uuid, text, timestamptz, text, text) to authenticated;
grant execute on function public.update_fleet_vehicle(uuid, text, timestamptz, text, text, boolean) to authenticated;
grant execute on function public.assign_fleet_driver(uuid, uuid) to authenticated;
grant execute on function public.unassign_fleet_driver(uuid) to authenticated;
grant execute on function public.delete_fleet_vehicle(uuid) to authenticated;
grant execute on function public.initiate_employee_dismissal(uuid, text) to authenticated;
grant execute on function public.submit_employee_dismissal_appeal(text) to authenticated;
grant execute on function public.resolve_employee_dismissal(uuid, boolean, text) to authenticated;
grant execute on function public.create_actioned_notification(uuid, text, text, text, uuid, uuid, text, uuid, text, text, text, jsonb) to authenticated;
grant execute on function public.list_company_chat_contacts(uuid) to authenticated;
grant execute on function public.check_user_exists(uuid) to authenticated;
grant execute on function public.get_runtime_platform_status() to anon, authenticated;
grant execute on function public.mark_chat_messages_read(uuid, uuid) to authenticated;
grant execute on function public.set_notification_read(uuid, boolean) to authenticated;
grant execute on function public.mark_all_notifications_read() to authenticated;
grant execute on function public.cleanup_old_broadcast_messages() to authenticated;

alter table public.profiles replica identity full;
alter table public.companies replica identity full;
alter table public.employees replica identity full;
alter table public.employee_status_history replica identity full;
alter table public.notifications replica identity full;
alter table public.fleet_vehicles replica identity full;
alter table public.broadcast_messages replica identity full;
alter table public.minerals replica identity full;
alter table public.transactions replica identity full;
alter table public.weighbridge_records replica identity full;
alter table public.mineral_loads replica identity full;
alter table public.security_incidents replica identity full;
alter table public.gate_checks replica identity full;
alter table public.chat_rooms replica identity full;
alter table public.chat_messages replica identity full;

do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    alter publication supabase_realtime set table
      public.profiles,
      public.companies,
      public.employees,
      public.employee_status_history,
      public.notifications,
      public.fleet_vehicles,
      public.chat_rooms,
      public.chat_messages,
      public.broadcast_messages,
      public.minerals,
      public.transactions,
      public.weighbridge_records,
      public.mineral_loads,
      public.security_incidents,
      public.gate_checks;
  end if;
end;
$$;

commit;
