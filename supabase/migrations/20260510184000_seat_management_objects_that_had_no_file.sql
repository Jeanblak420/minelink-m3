-- The seat-management objects that existed in production with NO migration file.
--
-- Written 2026-08-17, from the first real cold replay of this repo. Two ledger
-- rows from 2026-05-04 — `add_seat_reassignment_log_and_serial_numbers` and
-- `add_seat_management_rpc_functions` — were applied through the Supabase MCP
-- and no file was ever written for either, so they are two of the 19 unmirrored
-- rows `tool/migration_ledger_check.py` found. The replay turned that
-- bookkeeping debt into a measured fact: git could not build these objects, and
-- five later migrations died on them.
--
--   42P01  relation "public.seat_reassignment_log" does not exist
--            -> 20260713030000_fix_missing_table_grants
--            -> 20260717100000_perf_rls_initplan_and_fk_indexes
--            -> 20260727140000_flatten_child_super_admin
--   42883  function public.check_seat_reassignment_allowed(uuid) does not exist
--   42883  function public.reassign_seat(uuid,uuid,text,text,text) does not exist
--            -> both from 20260716121000_security_hygiene_batch, which only
--               ever ALTERs these functions and never creates them
--
-- WHY THIS STAMP, and not the ledger's 2026-05-04.
-- The first attempt at this repair used the ledger rows' own timestamps so the
-- files and rows would line up. It failed on the very next replay:
-- `seat_reassignment_log` has a foreign key to `organization_seats`, which is
-- not created until `20260510181500_create_super_admin_tables.sql`. The ledger
-- records WHEN something was applied to a database that already had those
-- tables; it is not a claim that the same order replays from empty. So this
-- file sits after its dependencies, and is a new migration with its own row
-- rather than a retrospective one. The two 2026-05-04 rows stay in the
-- checker's baseline as the historical facts they are.
--
-- It took two replays to land the stamp, and both misses are worth recording
-- because both were invisible to reading the SQL:
--   * 20260504212635 (the ledger's own date) -- seat_reassignment_log has a
--     foreign key to organization_seats, created at 20260510181500.
--   * 20260510182000 -- the RLS policy below calls public.is_super_admin(),
--     and Postgres VALIDATES a policy expression when the policy is created,
--     so the function has to exist already. It is created at 20260510183000.
-- Hence 20260510184000: after the last of them. The plpgsql function bodies
-- below also call is_platform_admin, is_company_manager and
-- is_valid_role_for_org, but those resolve at run time and do not constrain
-- the stamp -- which is exactly why only a replay finds this class of fault.
--
-- ⚠️ RECONSTRUCTED FROM THE LIVE CATALOG on 2026-08-17, not from the original
-- SQL, which does not exist anywhere. Every definition below was read back from
-- production verbatim. Two consequences worth knowing:
--
--   * The function bodies are TODAY'S, not 2026-05's. `reassign_seat` in
--     particular is re-created by `20260727120000_security_hardening_audit` and
--     patched again later, so the replay converges on the right end state — but
--     the intermediate state here is newer than history really was. There is no
--     way to recover the original bodies, and a replay that ends correct is
--     worth more than a fiction that reads chronologically.
--   * `submit_seat_token_request` writes to `public.seat_requests`, a table
--     that DOES NOT EXIST in production — it was superseded by
--     `token_requests`. So that function is already dead code and would fail if
--     called. It is reproduced here because the point of this file is to make
--     the rebuild match production, warts included; removing it is a separate
--     decision. plpgsql resolves table names at run time, so it creates fine.

begin;

-- ---------------------------------------------------------------- the table

create table if not exists public.seat_reassignment_log (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.companies (id),
  seat_id uuid not null references public.organization_seats (id),
  previous_user_id uuid references public.profiles (id),
  previous_user_email text,
  new_user_id uuid references public.profiles (id),
  new_user_email text,
  reassigned_by uuid references public.profiles (id),
  reassigned_at timestamptz not null default timezone('utc'::text, now()),
  created_at timestamptz not null default timezone('utc'::text, now())
);

create index if not exists seat_reassignment_log_organization_id_idx
  on public.seat_reassignment_log using btree (organization_id);
create index if not exists seat_reassignment_log_seat_id_idx
  on public.seat_reassignment_log using btree (seat_id);
create index if not exists seat_reassignment_log_previous_user_id_idx
  on public.seat_reassignment_log using btree (previous_user_id);
create index if not exists seat_reassignment_log_new_user_id_idx
  on public.seat_reassignment_log using btree (new_user_id);
create index if not exists seat_reassignment_log_reassigned_by_idx
  on public.seat_reassignment_log using btree (reassigned_by);

alter table public.seat_reassignment_log enable row level security;

drop policy if exists "Company owners can read own reassignment logs"
  on public.seat_reassignment_log;
create policy "Company owners can read own reassignment logs"
  on public.seat_reassignment_log for select
  using (exists (
    select 1 from public.companies c
     where c.id = seat_reassignment_log.organization_id
       and c.user_id = (select auth.uid())));

drop policy if exists "Super admins full access to seat_reassignment_log"
  on public.seat_reassignment_log;
create policy "Super admins full access to seat_reassignment_log"
  on public.seat_reassignment_log for all
  using (public.is_super_admin())
  with check (public.is_super_admin());

grant select, insert, update, delete
  on public.seat_reassignment_log to authenticated;

comment on table public.seat_reassignment_log is
  'Audit trail of seat reassignments. Reconstructed from the live catalog on '
  '2026-08-17 — applied in 2026-05 with no migration file, so a cold replay '
  'could not build it.';

-- ------------------------------------------------------------ the functions

create or replace function public.check_seat_reassignment_allowed(
  p_organization_id uuid)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_count int;
  v_allowed boolean;
  v_remaining int;
begin
  select count(*) into v_count
    from public.seat_reassignment_log
   where organization_id = p_organization_id
     and reassigned_at >= (now() - interval '30 days');

  v_allowed := (v_count < 2);
  v_remaining := greatest(0, 2 - v_count);

  return jsonb_build_object(
    'allowed', v_allowed,
    'used', v_count,
    'remaining', v_remaining,
    'limit', 2,
    'period_days', 30
  );
end;
$$;

create or replace function public.generate_seat_serial(p_role text)
returns text
language plpgsql
set search_path to 'public'
as $$
declare
  v_chars text := 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!@#$%';
  v_serial text := '';
  v_suffix text;
  v_i int;
begin
  v_suffix := case p_role
    when 'management' then 'MGT'
    when 'admin' then 'ADM'
    when 'controllerWB' then 'CTR'
    when 'security' then 'SEC'
    when 'driver' then 'DRV'
    else 'GEN'
  end;

  for v_i in 1..12 loop
    v_serial := v_serial || substr(v_chars, floor(random() * length(v_chars) + 1)::int, 1);
  end loop;

  return v_serial || v_suffix;
end;
$$;

create or replace function public.submit_seat_token_request(
  p_organization_id uuid,
  p_requested_extra_seats integer default 0,
  p_requested_valid_days integer default 0,
  p_reason text default ''::text)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_company record;
  v_profile record;
begin
  select * into v_company from public.companies where id = p_organization_id;
  if not found then
    return jsonb_build_object('success', false, 'error', 'Company not found');
  end if;

  if v_company.user_id != auth.uid() then
    return jsonb_build_object('success', false,
      'error', 'Only the company owner can submit requests');
  end if;

  select email into v_profile from public.profiles where id = auth.uid();

  insert into public.seat_requests (
    organization_id, organization_name, organization_type,
    current_seat_limit, current_seats_used,
    requested_extra_seats, requested_new_total,
    reason, requested_by_user_id, requested_by_email, status
  ) values (
    p_organization_id, v_company.company_name, v_company.org_type,
    v_company.seat_limit, v_company.seats_used,
    p_requested_extra_seats,
    v_company.seat_limit + p_requested_extra_seats,
    case when p_requested_valid_days > 0
      then format('Extra seats: %s, Token renewal: %s days. %s',
                  p_requested_extra_seats, p_requested_valid_days, p_reason)
      else format('Extra seats: %s. %s', p_requested_extra_seats, p_reason)
    end,
    auth.uid(), v_profile.email, 'pending'
  );

  return jsonb_build_object('success', true);
end;
$$;

create or replace function public.reassign_seat(
  p_seat_id uuid, p_new_user_id uuid, p_new_user_email text,
  p_new_user_name text, p_new_user_role text)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_seat record;
  v_count int;
begin
  select * into v_seat from public.organization_seats where id = p_seat_id;
  if not found then
    return jsonb_build_object('success', false, 'error', 'Seat not found');
  end if;

  if not (public.is_platform_admin()
          or public.is_company_manager(v_seat.organization_id)) then
    return jsonb_build_object('success', false,
      'error', 'Not authorized to reassign this seat');
  end if;

  if v_seat.role_binding is not null and v_seat.role_binding != p_new_user_role then
    return jsonb_build_object('success', false,
      'error', format('This seat is bound to role "%s". Cannot assign a "%s" user.',
                      v_seat.role_binding, p_new_user_role));
  end if;

  if not public.is_valid_role_for_org(
       (select org_type from public.companies where id = v_seat.organization_id),
       p_new_user_role) then
    return jsonb_build_object('success', false,
      'error', format('Role "%s" is not valid for this organisation.', p_new_user_role));
  end if;

  if v_seat.occupied_by_user_id is not null then
    select count(*) into v_count
      from public.seat_reassignment_log
     where organization_id = v_seat.organization_id
       and reassigned_at >= (now() - interval '30 days');

    if v_count >= 2 then
      return jsonb_build_object('success', false,
        'error', 'Seat reassignment limit reached (2 per 30 days). Cannot reassign until the window resets.');
    end if;

    insert into public.seat_reassignment_log (
      organization_id, seat_id, previous_user_id, previous_user_email,
      new_user_id, new_user_email, reassigned_by
    ) values (
      v_seat.organization_id, p_seat_id, v_seat.occupied_by_user_id,
      v_seat.occupied_by_email, p_new_user_id, p_new_user_email, auth.uid()
    );
  end if;

  update public.organization_seats set
    occupied_by_user_id = p_new_user_id,
    occupied_by_email = p_new_user_email,
    occupied_by_name = p_new_user_name,
    occupied_by_employee_role = p_new_user_role,
    status = 'occupied',
    assigned_at = now(),
    released_at = null,
    updated_at = now()
  where id = p_seat_id;

  return jsonb_build_object('success', true);
end;
$$;

commit;
