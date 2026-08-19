begin;

-- ---------------------------------------------------------------------------
-- 1) Rename seat_requests -> token_requests + new columns / constraints
-- ---------------------------------------------------------------------------

alter table if exists public.seat_requests rename to token_requests;

alter index if exists public.seat_requests_status_created_idx
  rename to token_requests_status_created_idx;

alter index if exists public.seat_requests_org_id_idx
  rename to token_requests_org_id_idx;

alter table public.token_requests drop constraint if exists seat_requests_status_check;
alter table public.token_requests drop constraint if exists token_requests_status_check;
alter table public.token_requests
  add constraint token_requests_status_check
  check (status in ('pending', 'in_progress', 'approved', 'rejected', 'cancelled'));

alter table public.token_requests add column if not exists request_kind text;
update public.token_requests set request_kind = 'seat_expansion' where request_kind is null;
alter table public.token_requests alter column request_kind set default 'seat_expansion';
alter table public.token_requests alter column request_kind set not null;

alter table public.token_requests drop constraint if exists seat_requests_requested_extra_seats_check;
alter table public.token_requests drop constraint if exists token_requests_seat_fields_check;
alter table public.token_requests
  add constraint token_requests_seat_fields_check
  check (
    (request_kind = 'seat_expansion' and requested_extra_seats > 0)
    or (request_kind in ('token_renewal', 'new_token'))
  );

alter table public.token_requests drop constraint if exists token_requests_request_kind_check;
alter table public.token_requests
  add constraint token_requests_request_kind_check
  check (request_kind in ('seat_expansion', 'token_renewal', 'new_token'));

alter table public.token_requests add column if not exists current_token_id uuid
  references public.serial_tokens (id) on delete set null;

alter table public.token_requests add column if not exists requested_valid_days integer;

alter table public.token_requests drop constraint if exists token_requests_requested_valid_days_check;
alter table public.token_requests
  add constraint token_requests_requested_valid_days_check
  check (requested_valid_days is null or requested_valid_days > 0);

alter table public.token_requests add column if not exists handling_user_id uuid
  references public.profiles (id) on delete set null;

alter table public.token_requests add column if not exists handling_started_at timestamptz;

-- Dedupe token-expiry warning emails / in-app (one notice per token_expires_at value)
alter table public.companies add column if not exists token_expiry_notice_issued_for timestamptz;

-- ---------------------------------------------------------------------------
-- 2) Notifications: extend allowed type enum
-- ---------------------------------------------------------------------------

alter table public.notifications drop constraint if exists notifications_type_check;

alter table public.notifications
  add constraint notifications_type_check
  check (type in (
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
    'general',
    'tokenExpiringSoon',
    'tokenRequestCreated',
    'tokenRequestClaimed',
    'tokenRequestReleased',
    'tokenRequestHandled'
  ));

-- ---------------------------------------------------------------------------
-- 3) RLS policies (drop old names, recreate on token_requests)
-- ---------------------------------------------------------------------------

drop policy if exists seat_requests_select_allowed on public.token_requests;
drop policy if exists seat_requests_insert_company_manager on public.token_requests;

create policy token_requests_select_allowed
  on public.token_requests
  for select
  to authenticated
  using (public.is_platform_admin() or public.is_company_manager(organization_id));

create policy token_requests_insert_company_manager
  on public.token_requests
  for insert
  to authenticated
  with check (
    requested_by_user_id = auth.uid()
    and public.is_company_manager(organization_id)
  );

-- ---------------------------------------------------------------------------
-- 4) Notify platform admins (insert per super-global profile)
-- ---------------------------------------------------------------------------

create or replace function public._notify_platform_admins_token(
  p_type text,
  p_title text,
  p_message text,
  p_metadata jsonb default '{}'::jsonb
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  r record;
begin
  for r in
    select p.id as uid
    from public.profiles p
    where p.platform_role in ('superGlobalSerialAdminMain', 'superGlobalSerialAdminMainChild')
  loop
    insert into public.notifications (
      user_id,
      title,
      message,
      type,
      org_type,
      metadata
    )
    values (
      r.uid,
      p_title,
      p_message,
      p_type,
      null,
      coalesce(p_metadata, '{}'::jsonb)
    );
  end loop;
end;
$$;

create or replace function public._notify_company_token_managers(
  p_company_id uuid,
  p_type text,
  p_title text,
  p_message text,
  p_metadata jsonb default '{}'::jsonb
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  r record;
  ot text;
begin
  select c.org_type into ot from public.companies c where c.id = p_company_id limit 1;

  for r in
    select distinct uid from (
      select c.user_id as uid
      from public.companies c
      where c.id = p_company_id
        and c.user_id is not null
      union
      select e.user_id as uid
      from public.employees e
      where e.company_id = p_company_id
        and e.user_id is not null
        and e.role in ('admin', 'management')
        and e.status = 'active'
        and e.is_dismissed = false
    ) q
    where q.uid is not null
  loop
    insert into public.notifications (
      user_id,
      company_id,
      title,
      message,
      type,
      org_type,
      metadata
    )
    values (
      r.uid,
      p_company_id,
      p_title,
      p_message,
      p_type,
      ot,
      coalesce(p_metadata, '{}'::jsonb)
    );
  end loop;
end;
$$;

create or replace function public.token_requests_after_write_notify()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  handler_name text;
begin
  if tg_op = 'INSERT' then
    perform public._notify_platform_admins_token(
      'tokenRequestCreated',
      'New token request',
      new.organization_name || ' · ' || new.request_kind,
      jsonb_build_object(
        'token_request_id', new.id,
        'organization_id', new.organization_id,
        'organization_name', new.organization_name,
        'request_kind', new.request_kind,
        'status', new.status
      )
    );
    return new;
  end if;

  if tg_op = 'UPDATE' then
    -- Terminal state first (approve/reject clears handler in same update)
    if new.status in ('approved', 'rejected')
       and old.status is distinct from new.status then
      perform public._notify_platform_admins_token(
        'tokenRequestHandled',
        'Token request ' || new.status,
        new.organization_name || ' · ' || new.request_kind,
        jsonb_build_object(
          'token_request_id', new.id,
          'organization_id', new.organization_id,
          'organization_name', new.organization_name,
          'request_kind', new.request_kind,
          'status', new.status
        )
      );

      perform public._notify_company_token_managers(
        new.organization_id,
        'tokenRequestHandled',
        case new.status
          when 'approved' then 'Token request approved'
          else 'Token request rejected'
        end,
        'Your ' || new.request_kind || ' request for ' || new.organization_name
          || ' was ' || new.status || '.',
        jsonb_build_object(
          'token_request_id', new.id,
          'request_kind', new.request_kind,
          'status', new.status
        )
      );
      return new;
    end if;

    if new.handling_user_id is not null
       and old.handling_user_id is distinct from new.handling_user_id then
      select coalesce(p.display_name, p.email, 'Admin')
      into handler_name
      from public.profiles p
      where p.id = new.handling_user_id;

      perform public._notify_platform_admins_token(
        'tokenRequestClaimed',
        'Token request in progress',
        handler_name || ' is handling ' || new.organization_name,
        jsonb_build_object(
          'token_request_id', new.id,
          'organization_id', new.organization_id,
          'organization_name', new.organization_name,
          'handling_user_id', new.handling_user_id,
          'handling_display_name', handler_name,
          'status', new.status
        )
      );
    elsif new.handling_user_id is null
      and old.handling_user_id is not null
      and new.status = 'pending' then
      perform public._notify_platform_admins_token(
        'tokenRequestReleased',
        'Token request released',
        'A token request for ' || new.organization_name || ' is pending again.',
        jsonb_build_object(
          'token_request_id', new.id,
          'organization_id', new.organization_id,
          'organization_name', new.organization_name,
          'status', new.status
        )
      );
    end if;

    return new;
  end if;

  return coalesce(new, old);
end;
$$;

drop trigger if exists token_requests_notify_ai on public.token_requests;
create trigger token_requests_notify_ai
  after insert on public.token_requests
  for each row
  execute function public.token_requests_after_write_notify();

drop trigger if exists token_requests_notify_au on public.token_requests;
create trigger token_requests_notify_au
  after update on public.token_requests
  for each row
  execute function public.token_requests_after_write_notify();

-- ---------------------------------------------------------------------------
-- 5) Company: create token request (validates manager + writes audit)
-- ---------------------------------------------------------------------------

create or replace function public.create_company_token_request(
  p_organization_id uuid,
  p_request_kind text,
  p_reason text default '',
  p_requested_extra_seats integer default null,
  p_requested_new_total integer default null,
  p_requested_valid_days integer default null,
  p_current_token_id uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  c record;
  rid uuid;
  actor_email text;
  actor_role text;
begin
  if not public.is_company_manager(p_organization_id) then
    raise exception 'Not permitted to create token requests for this organization';
  end if;

  if p_request_kind not in ('seat_expansion', 'token_renewal', 'new_token') then
    raise exception 'Invalid request kind';
  end if;

  select
    c.id,
    c.company_name,
    c.org_type,
    c.seat_limit,
    c.seats_used,
    c.current_token_id,
    c.token_valid_days,
    c.token_expires_at
  into c
  from public.companies c
  where c.id = p_organization_id
  limit 1;

  if c.id is null then
    raise exception 'Organization not found';
  end if;

  if p_request_kind = 'seat_expansion' then
    if p_requested_extra_seats is null or p_requested_extra_seats <= 0 then
      raise exception 'requested_extra_seats required for seat expansion';
    end if;
    if p_requested_new_total is null or p_requested_new_total <= 0 then
      raise exception 'requested_new_total required for seat expansion';
    end if;
  end if;

  if p_request_kind in ('token_renewal', 'new_token') then
    if p_requested_new_total is null then
      raise exception 'requested_new_total snapshot required (use current seat limit)';
    end if;
  end if;

  select p.email, p.platform_role
  into actor_email, actor_role
  from public.profiles p
  where p.id = auth.uid();

  insert into public.token_requests (
    organization_id,
    organization_name,
    organization_type,
    current_seat_limit,
    current_seats_used,
    requested_extra_seats,
    requested_new_total,
    reason,
    requested_by_user_id,
    requested_by_email,
    status,
    request_kind,
    current_token_id,
    requested_valid_days
  )
  values (
    c.id,
    coalesce(c.company_name, ''),
    c.org_type,
    c.seat_limit,
    c.seats_used,
    coalesce(p_requested_extra_seats, 0),
    coalesce(p_requested_new_total, c.seat_limit),
    coalesce(p_reason, ''),
    auth.uid(),
    actor_email,
    'pending',
    p_request_kind,
    coalesce(p_current_token_id, c.current_token_id),
    p_requested_valid_days
  )
  returning id into rid;

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
    created_at
  )
  values (
    auth.uid(),
    coalesce(actor_email, ''),
    coalesce(actor_role, 'normalUser'),
    'TOKEN_REQUEST_SUBMITTED',
    'tokenRequest',
    rid,
    c.company_name,
    c.id,
    c.company_name,
    c.org_type,
    'Token request submitted: ' || p_request_kind,
    timezone('utc', now())
  );

  return jsonb_build_object('id', rid, 'status', 'pending');
end;
$$;

-- ---------------------------------------------------------------------------
-- 6) Claim / release (coordination)
-- ---------------------------------------------------------------------------

create or replace function public.claim_token_request(p_request_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  req public.token_requests;
  actor_name text;
begin
  perform public.require_platform_admin();

  if public.is_child_super_admin() and not public.child_admin_permission('canManageSeats') then
    raise exception 'Child admin not permitted to manage token requests';
  end if;

  select * into req from public.token_requests where id = p_request_id for update;
  if req.id is null then
    raise exception 'Token request not found';
  end if;

  if req.status <> 'pending' then
    raise exception 'Token request is not pending';
  end if;

  if req.handling_user_id is not null then
    raise exception 'Token request is already being handled';
  end if;

  select coalesce(p.display_name, p.email, 'Admin') into actor_name
  from public.profiles p where p.id = auth.uid();

  update public.token_requests
  set
    status = 'in_progress',
    handling_user_id = auth.uid(),
    handling_started_at = timezone('utc', now()),
    updated_at = timezone('utc', now())
  where id = req.id;

  perform public.insert_audit_log(
    'TOKEN_REQUEST_CLAIMED',
    'tokenRequest',
    req.id,
    req.organization_name,
    req.organization_id,
    'Token request claimed by ' || coalesce(actor_name, '')
  );

  return jsonb_build_object('id', req.id, 'status', 'in_progress', 'handling_user_id', auth.uid());
end;
$$;

create or replace function public.release_token_request_claim(p_request_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  req public.token_requests;
begin
  perform public.require_platform_admin();

  if public.is_child_super_admin() and not public.child_admin_permission('canManageSeats') then
    raise exception 'Child admin not permitted to manage token requests';
  end if;

  select * into req from public.token_requests where id = p_request_id for update;
  if req.id is null then
    raise exception 'Token request not found';
  end if;

  if req.status <> 'in_progress' then
    raise exception 'Token request is not in progress';
  end if;

  if req.handling_user_id is distinct from auth.uid() and not public.is_main_super_admin() then
    raise exception 'Only the assigned handler (or main admin) can release this claim';
  end if;

  update public.token_requests
  set
    status = 'pending',
    handling_user_id = null,
    handling_started_at = null,
    updated_at = timezone('utc', now())
  where id = req.id;

  perform public.insert_audit_log(
    'TOKEN_REQUEST_RELEASED',
    'tokenRequest',
    req.id,
    req.organization_name,
    req.organization_id,
    'Token request claim released; back to pending queue'
  );

  return jsonb_build_object('id', req.id, 'status', 'pending');
end;
$$;

-- ---------------------------------------------------------------------------
-- 7) Approve / reject (handler-only when in_progress; seat vs token branches)
-- ---------------------------------------------------------------------------

create or replace function public.approve_token_request(
  p_request_id uuid,
  p_review_note text default null,
  p_approved_new_seat_limit integer default null,
  p_valid_days integer default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  req public.token_requests;
  company_before jsonb;
  tok_result jsonb;
  days integer;
  seat_lim integer;
begin
  perform public.require_platform_admin();

  if public.is_child_super_admin() and not public.child_admin_permission('canManageSeats') then
    raise exception 'Child admin not permitted to manage token requests';
  end if;

  select * into req from public.token_requests where id = p_request_id for update;
  if req.id is null then
    raise exception 'Token request not found';
  end if;

  if req.status <> 'in_progress' or req.handling_user_id is distinct from auth.uid() then
    raise exception 'You must start the token process (claim) before approving this request';
  end if;

  company_before := (select to_jsonb(c) from public.companies c where c.id = req.organization_id);

  if req.request_kind = 'seat_expansion' then
    if p_approved_new_seat_limit is null or p_approved_new_seat_limit <= 0 then
      raise exception 'Approved seat limit must be greater than 0';
    end if;

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

  elsif req.request_kind in ('token_renewal', 'new_token') then
    days := coalesce(p_valid_days, req.requested_valid_days,
      (select token_valid_days from public.companies where id = req.organization_id), 30);
    if days is null or days <= 0 then
      raise exception 'Valid days must be greater than 0';
    end if;

    seat_lim := coalesce(p_approved_new_seat_limit, req.requested_new_total, req.current_seat_limit);
    if seat_lim is null or seat_lim <= 0 then
      raise exception 'Seat limit must be greater than 0';
    end if;

    tok_result := public.create_serial_token(req.organization_id, days, seat_lim);
  end if;

  update public.token_requests
  set
    status = 'approved',
    reviewed_by_user_id = auth.uid(),
    reviewed_by_email = (select email from public.profiles where id = auth.uid()),
    reviewed_at = timezone('utc', now()),
    review_note = p_review_note,
    handling_user_id = null,
    handling_started_at = null,
    updated_at = timezone('utc', now())
  where id = req.id;

  perform public.insert_audit_log(
    'TOKEN_REQUEST_APPROVED',
    'tokenRequest',
    req.id,
    req.organization_name,
    req.organization_id,
    'Token request approved (' || req.request_kind || ')'
  );

  if req.request_kind = 'seat_expansion' then
    return jsonb_build_object(
      'request_id', req.id,
      'status', 'approved',
      'approved_new_seat_limit', p_approved_new_seat_limit
    );
  else
    return coalesce(tok_result, '{}'::jsonb) || jsonb_build_object('request_id', req.id, 'status', 'approved');
  end if;
end;
$$;

create or replace function public.reject_token_request(
  p_request_id uuid,
  p_review_note text default 'Request rejected'
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  req public.token_requests;
begin
  perform public.require_platform_admin();

  if public.is_child_super_admin() and not public.child_admin_permission('canManageSeats') then
    raise exception 'Child admin not permitted to manage token requests';
  end if;

  select * into req from public.token_requests where id = p_request_id for update;
  if req.id is null then
    raise exception 'Token request not found';
  end if;

  if req.status <> 'in_progress' or req.handling_user_id is distinct from auth.uid() then
    raise exception 'You must start the token process (claim) before rejecting this request';
  end if;

  update public.token_requests
  set
    status = 'rejected',
    reviewed_by_user_id = auth.uid(),
    reviewed_by_email = (select email from public.profiles where id = auth.uid()),
    reviewed_at = timezone('utc', now()),
    review_note = p_review_note,
    handling_user_id = null,
    handling_started_at = null,
    updated_at = timezone('utc', now())
  where id = req.id;

  perform public.insert_audit_log(
    'TOKEN_REQUEST_REJECTED',
    'tokenRequest',
    req.id,
    req.organization_name,
    req.organization_id,
    'Token request rejected. Note: ' || coalesce(p_review_note, '')
  );

  return jsonb_build_object('request_id', req.id, 'status', 'rejected');
end;
$$;

drop function if exists public.approve_seat_request(uuid, integer, text);
drop function if exists public.reject_seat_request(uuid, text);

-- ---------------------------------------------------------------------------
-- 8) Scheduled warnings (7-day window) + optional pg_cron
-- ---------------------------------------------------------------------------

create or replace function public.notify_token_expiring_soon_job()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  sent integer := 0;
  co record;
  mgr record;
  ot text;
begin
  for co in
    select c.*
    from public.companies c
    where c.status = 'active'
      and c.token_expires_at is not null
      and c.token_expires_at > timezone('utc', now())
      and c.token_expires_at <= timezone('utc', now()) + interval '7 days'
      and (
        c.token_expiry_notice_issued_for is null
        or c.token_expiry_notice_issued_for is distinct from c.token_expires_at
      )
  loop
    ot := co.org_type;

    for mgr in
      select distinct q.uid
      from (
        select co.user_id as uid
        union
        select e.user_id as uid
        from public.employees e
        where e.company_id = co.id
          and e.user_id is not null
          and e.role in ('admin', 'management')
          and e.status = 'active'
          and e.is_dismissed = false
      ) q
      where q.uid is not null
    loop
      insert into public.notifications (
        user_id,
        company_id,
        title,
        message,
        type,
        org_type,
        metadata
      )
      values (
        mgr.uid,
        co.id,
        'Access token expiring soon',
        'The access token for ' || coalesce(co.company_name, 'your company')
          || ' expires on ' || to_char(co.token_expires_at at time zone 'UTC', 'YYYY-MM-DD HH24:MI') || ' UTC. Renew it now to avoid interruption.',
        'tokenExpiringSoon',
        ot,
        jsonb_build_object(
          'company_id', co.id,
          'token_expires_at', co.token_expires_at
        )
      );
      sent := sent + 1;
    end loop;

    update public.companies c
    set
      token_expiry_notice_issued_for = co.token_expires_at,
      updated_at = timezone('utc', now())
    where c.id = co.id;
  end loop;

  return sent;
end;
$$;

do $$
begin
  if not exists (
    select 1 from cron.job where jobname = 'notify_token_expiring_soon_daily'
  ) then
    perform cron.schedule(
      'notify_token_expiring_soon_daily',
      '15 2 * * *',
      $cron$select public.notify_token_expiring_soon_job();$cron$
    );
  end if;
exception
  when undefined_table or insufficient_privilege or invalid_schema_name then
    null;
end$$;

-- ---------------------------------------------------------------------------
-- 9) Realtime publication
-- ---------------------------------------------------------------------------

alter table public.token_requests replica identity full;

do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    begin
      execute 'alter publication supabase_realtime add table public.token_requests';
    exception
      when duplicate_object then
        null;
    end;
  end if;
end$$;

grant execute on function public.create_company_token_request(uuid, text, text, integer, integer, integer, uuid) to authenticated;
grant execute on function public.claim_token_request(uuid) to authenticated;
grant execute on function public.release_token_request_claim(uuid) to authenticated;
grant execute on function public.approve_token_request(uuid, text, integer, integer) to authenticated;
grant execute on function public.reject_token_request(uuid, text) to authenticated;
grant execute on function public.notify_token_expiring_soon_job() to authenticated;

commit;
