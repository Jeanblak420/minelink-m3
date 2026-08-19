begin;

-- ============================================================
-- Seat usage helpers + enforcement
-- ============================================================

create or replace function public.recompute_company_seats_used(target_company_id uuid)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  used_count integer;
begin
  if target_company_id is null then
    return 0;
  end if;

  select count(*)
  into used_count
  from public.employees e
  where e.company_id = target_company_id
    and e.status = 'active'
    and e.is_dismissed = false;

  update public.companies
  set
    seats_used = used_count,
    updated_at = timezone('utc', now())
  where id = target_company_id;

  return used_count;
end;
$$;

create or replace function public.enforce_company_seat_limit()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  company_record record;
  current_used integer;
begin
  if new.company_id is null then
    return new;
  end if;

  select c.id, c.status, c.seat_limit
  into company_record
  from public.companies c
  where c.id = new.company_id
  limit 1;

  if company_record.id is null then
    raise exception 'Company not found';
  end if;

  -- Only enforce when company is active (or pending activation but trying to add users)
  if company_record.status in ('active', 'pendingActivation') then
    if company_record.seat_limit is null or company_record.seat_limit <= 0 then
      raise exception 'This company has no available user seats';
    end if;

    select count(*)
    into current_used
    from public.employees e
    where e.company_id = new.company_id
      and e.status = 'active'
      and e.is_dismissed = false
      and (tg_op <> 'UPDATE' or e.id <> new.id);

    if current_used >= company_record.seat_limit then
      raise exception 'Company seat limit reached (%/%).', current_used, company_record.seat_limit;
    end if;
  end if;

  return new;
end;
$$;

drop trigger if exists enforce_company_seat_limit_on_employees on public.employees;

create trigger enforce_company_seat_limit_on_employees
before insert or update of company_id, status, is_dismissed
on public.employees
for each row
execute function public.enforce_company_seat_limit();

create or replace function public.sync_company_seats_used()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'DELETE' then
    perform public.recompute_company_seats_used(old.company_id);
    return old;
  end if;

  perform public.recompute_company_seats_used(new.company_id);
  if tg_op = 'UPDATE' and old.company_id is distinct from new.company_id then
    perform public.recompute_company_seats_used(old.company_id);
  end if;

  return new;
end;
$$;

drop trigger if exists sync_company_seats_used_after_employees on public.employees;

create trigger sync_company_seats_used_after_employees
after insert or update of company_id, status, is_dismissed or delete
on public.employees
for each row
execute function public.sync_company_seats_used();

-- ============================================================
-- Audit log helper (insert-only via policy for platform admins)
-- ============================================================

create or replace function public.insert_audit_log(
  p_action_type text,
  p_target_type text,
  p_target_id uuid default null,
  p_target_name text default null,
  p_organization_id uuid default null,
  p_description text default '',
  p_before_data jsonb default null,
  p_after_data jsonb default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  actor record;
  org record;
begin
  select p.id, p.email, p.platform_role
  into actor
  from public.profiles p
  where p.id = auth.uid()
  limit 1;

  if p_organization_id is not null then
    select c.id, c.company_name, c.org_type
    into org
    from public.companies c
    where c.id = p_organization_id
    limit 1;
  end if;

  insert into public.audit_logs (
    actor_user_id,
    actor_email,
    actor_platform_role,
    action_type,
    target_type,
    target_id,
    target_name,
    organization_id,
    organization_name,
    organization_type,
    description,
    before_data,
    after_data,
    created_at
  )
  values (
    auth.uid(),
    coalesce(actor.email, ''),
    coalesce(actor.platform_role, 'normalUser'),
    p_action_type,
    p_target_type,
    p_target_id,
    p_target_name,
    p_organization_id,
    org.company_name,
    org.org_type,
    coalesce(p_description, ''),
    p_before_data,
    p_after_data,
    timezone('utc', now())
  );
end;
$$;

-- ============================================================
-- Serial Token RPCs
-- ============================================================

create or replace function public.create_serial_token(
  p_organization_id uuid,
  p_valid_days integer,
  p_seat_limit integer
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  org public.companies;
  raw_token text;
  token_hash text;
  token_preview text;
  expires_at timestamptz;
  inserted_token_id uuid;
  actor record;
begin
  perform public.require_platform_admin();

  if public.is_child_super_admin() and not public.child_admin_permission('canGenerateTokens') then
    raise exception 'Child admin not permitted to generate tokens';
  end if;

  if p_organization_id is null then
    raise exception 'Organization is required';
  end if;

  if p_valid_days is null or p_valid_days <= 0 then
    raise exception 'Valid days must be greater than 0';
  end if;

  if p_seat_limit is null or p_seat_limit <= 0 then
    raise exception 'Seat limit must be greater than 0';
  end if;

  select * into org
  from public.companies
  where id = p_organization_id
  limit 1;

  if org.id is null then
    raise exception 'Organization not found';
  end if;

  -- Ensure we are not dropping below current active employees
  perform public.recompute_company_seats_used(org.id);
  if org.seats_used > p_seat_limit then
    raise exception 'Seat limit (% ) cannot be less than seats used (%)', p_seat_limit, org.seats_used;
  end if;

  -- Generate a strong token, hash it, and store only hash + preview.
  raw_token := encode(gen_random_bytes(32), 'hex');
  token_hash := encode(digest(raw_token, 'sha256'), 'hex');
  token_preview := substr(raw_token, 1, 6) || '...' || substr(raw_token, length(raw_token) - 5, 6);

  expires_at := timezone('utc', now()) + make_interval(days => p_valid_days);

  select p.id, p.email, p.platform_role
  into actor
  from public.profiles p
  where p.id = auth.uid()
  limit 1;

  insert into public.serial_tokens (
    organization_id,
    organization_name,
    organization_type,
    token_hash,
    token_preview,
    valid_days,
    expires_at,
    seat_limit,
    status,
    generated_by_user_id,
    generated_by_email,
    generated_by_platform_role,
    created_at,
    updated_at
  )
  values (
    org.id,
    coalesce(org.company_name, ''),
    org.org_type,
    token_hash,
    token_preview,
    p_valid_days,
    expires_at,
    p_seat_limit,
    'active',
    auth.uid(),
    coalesce(actor.email, ''),
    coalesce(actor.platform_role, 'normalUser'),
    timezone('utc', now()),
    timezone('utc', now())
  )
  returning id into inserted_token_id;

  update public.companies
  set
    status = 'active',
    seat_limit = p_seat_limit,
    token_valid_days = p_valid_days,
    token_expires_at = expires_at,
    current_token_id = inserted_token_id,
    last_token_generated_by = auth.uid(),
    last_token_generated_at = timezone('utc', now()),
    updated_at = timezone('utc', now())
  where id = org.id;

  -- Create seat rows up to limit if missing; disable extras if reduced.
  perform public.sync_organization_seats(org.id, p_seat_limit);
  perform public.recompute_company_seats_used(org.id);

  perform public.insert_audit_log(
    'TOKEN_GENERATED',
    'serialToken',
    inserted_token_id,
    token_preview,
    org.id,
    'Serial token generated for ' || coalesce(org.company_name, '') || ' (' || org.org_type || ')'
  );

  return jsonb_build_object(
    'token_id', inserted_token_id,
    'raw_token', raw_token,
    'token_preview', token_preview,
    'expires_at', expires_at,
    'seat_limit', p_seat_limit,
    'valid_days', p_valid_days
  );
end;
$$;

create or replace function public.revoke_serial_token(
  p_token_id uuid,
  p_reason text default 'Revoked by admin'
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  token_row public.serial_tokens;
  org_row public.companies;
  before_company jsonb;
begin
  perform public.require_platform_admin();

  if public.is_child_super_admin() and not public.child_admin_permission('canRevokeTokens') then
    raise exception 'Child admin not permitted to revoke tokens';
  end if;

  select * into token_row
  from public.serial_tokens
  where id = p_token_id
  limit 1;

  if token_row.id is null then
    raise exception 'Token not found';
  end if;

  select * into org_row
  from public.companies
  where id = token_row.organization_id
  limit 1;

  before_company := to_jsonb(org_row);

  update public.serial_tokens
  set
    status = 'revoked',
    revoked_by = auth.uid(),
    revoked_at = timezone('utc', now()),
    revoke_reason = coalesce(p_reason, 'Revoked by admin'),
    updated_at = timezone('utc', now())
  where id = token_row.id;

  -- If this was the current token, restrict company access immediately.
  update public.companies
  set
    status = 'suspended',
    current_token_id = case when current_token_id = token_row.id then null else current_token_id end,
    token_expires_at = case when current_token_id = token_row.id then timezone('utc', now()) else token_expires_at end,
    updated_at = timezone('utc', now())
  where id = token_row.organization_id;

  perform public.insert_audit_log(
    'TOKEN_REVOKED',
    'serialToken',
    token_row.id,
    token_row.token_preview,
    token_row.organization_id,
    'Token revoked. Reason: ' || coalesce(p_reason, 'Revoked by admin'),
    before_company,
    (select to_jsonb(c) from public.companies c where c.id = token_row.organization_id)
  );

  return jsonb_build_object(
    'token_id', token_row.id,
    'status', 'revoked'
  );
end;
$$;

-- ============================================================
-- Organization seats: sync helper
-- ============================================================

create or replace function public.sync_organization_seats(
  p_organization_id uuid,
  p_seat_limit integer
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  max_existing integer;
  seat_num integer;
  occupied_excess integer;
begin
  if p_seat_limit is null or p_seat_limit <= 0 then
    return;
  end if;

  select coalesce(max(seat_number), 0)
  into max_existing
  from public.organization_seats
  where organization_id = p_organization_id;

  -- Add missing seats
  if max_existing < p_seat_limit then
    seat_num := max_existing + 1;
    while seat_num <= p_seat_limit loop
      insert into public.organization_seats (
        organization_id,
        seat_number,
        status,
        created_at,
        updated_at
      ) values (
        p_organization_id,
        seat_num,
        'available',
        timezone('utc', now()),
        timezone('utc', now())
      )
      on conflict (organization_id, seat_number) do nothing;

      seat_num := seat_num + 1;
    end loop;
  end if;

  -- If reduced: disable seats above limit, but fail if any are occupied.
  select count(*)
  into occupied_excess
  from public.organization_seats
  where organization_id = p_organization_id
    and seat_number > p_seat_limit
    and status = 'occupied';

  if occupied_excess > 0 then
    raise exception 'Cannot reduce seat limit: % seats above the new limit are occupied', occupied_excess;
  end if;

  update public.organization_seats
  set
    status = 'disabled',
    updated_at = timezone('utc', now())
  where organization_id = p_organization_id
    and seat_number > p_seat_limit
    and status <> 'disabled';
end;
$$;

-- ============================================================
-- Seat Requests RPCs
-- ============================================================

create or replace function public.approve_seat_request(
  p_request_id uuid,
  p_approved_new_seat_limit integer,
  p_review_note text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  req public.seat_requests;
  company_before jsonb;
begin
  perform public.require_platform_admin();

  if public.is_child_super_admin() and not public.child_admin_permission('canManageSeats') then
    raise exception 'Child admin not permitted to manage seats';
  end if;

  if p_approved_new_seat_limit is null or p_approved_new_seat_limit <= 0 then
    raise exception 'Approved seat limit must be greater than 0';
  end if;

  select * into req
  from public.seat_requests
  where id = p_request_id
  limit 1;

  if req.id is null then
    raise exception 'Seat request not found';
  end if;

  if req.status <> 'pending' then
    raise exception 'Seat request is not pending';
  end if;

  company_before := (select to_jsonb(c) from public.companies c where c.id = req.organization_id);

  -- Validate we aren't going below used seats
  perform public.recompute_company_seats_used(req.organization_id);
  if (select seats_used from public.companies where id = req.organization_id) > p_approved_new_seat_limit then
    raise exception 'Approved seat limit cannot be less than seats used';
  end if;

  update public.companies
  set
    seat_limit = p_approved_new_seat_limit,
    updated_at = timezone('utc', now())
  where id = req.organization_id;

  perform public.sync_organization_seats(req.organization_id, p_approved_new_seat_limit);
  perform public.recompute_company_seats_used(req.organization_id);

  update public.seat_requests
  set
    status = 'approved',
    reviewed_by_user_id = auth.uid(),
    reviewed_by_email = (select email from public.profiles where id = auth.uid()),
    reviewed_at = timezone('utc', now()),
    review_note = p_review_note,
    updated_at = timezone('utc', now())
  where id = req.id;

  perform public.insert_audit_log(
    'SEAT_REQUEST_APPROVED',
    'seatRequest',
    req.id,
    req.organization_name,
    req.organization_id,
    'Seat request approved. New seat limit: ' || p_approved_new_seat_limit,
    company_before,
    (select to_jsonb(c) from public.companies c where c.id = req.organization_id)
  );

  return jsonb_build_object(
    'request_id', req.id,
    'status', 'approved',
    'approved_new_seat_limit', p_approved_new_seat_limit
  );
end;
$$;

create or replace function public.reject_seat_request(
  p_request_id uuid,
  p_review_note text default 'Request rejected'
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  req public.seat_requests;
begin
  perform public.require_platform_admin();

  if public.is_child_super_admin() and not public.child_admin_permission('canManageSeats') then
    raise exception 'Child admin not permitted to manage seats';
  end if;

  select * into req
  from public.seat_requests
  where id = p_request_id
  limit 1;

  if req.id is null then
    raise exception 'Seat request not found';
  end if;

  if req.status <> 'pending' then
    raise exception 'Seat request is not pending';
  end if;

  update public.seat_requests
  set
    status = 'rejected',
    reviewed_by_user_id = auth.uid(),
    reviewed_by_email = (select email from public.profiles where id = auth.uid()),
    reviewed_at = timezone('utc', now()),
    review_note = p_review_note,
    updated_at = timezone('utc', now())
  where id = req.id;

  perform public.insert_audit_log(
    'SEAT_REQUEST_REJECTED',
    'seatRequest',
    req.id,
    req.organization_name,
    req.organization_id,
    'Seat request rejected. Note: ' || coalesce(p_review_note, '')
  );

  return jsonb_build_object(
    'request_id', req.id,
    'status', 'rejected'
  );
end;
$$;

commit;

