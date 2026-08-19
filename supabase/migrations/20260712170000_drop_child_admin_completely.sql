-- Fully remove the child super-admin concept (CLAUDE.md §4). The prior migration
-- flattened behaviour; this one drops the remaining plumbing entirely:
--   1. Rewrites the 8 super_admin RPCs to drop the per-child-permission gate
--      (they now require only a platform admin — both admins are equal).
--   2. Drops the child helper/management functions.
--   3. Drops the child config columns.
-- is_main_super_admin is KEPT (still used by release_token_request_claim and
-- semantically valid — every admin is now "main").

begin;

-- ── 1. Rewrite the gate RPCs without the child-permission block ──────────────

create or replace function public.super_admin_set_company_status(p_company_id uuid, p_status text)
returns jsonb language plpgsql security definer set search_path to 'public'
as $function$
declare
  cname text;
begin
  perform public.require_platform_admin();

  if p_company_id is null then
    raise exception 'Company is required';
  end if;

  if p_status is null or p_status not in ('suspended', 'active') then
    raise exception 'Invalid company status';
  end if;

  select c.company_name into cname
  from public.companies c
  where c.id = p_company_id
  limit 1;

  if cname is null then
    raise exception 'Organization not found';
  end if;

  update public.companies
  set status = p_status, updated_at = timezone('utc', now())
  where id = p_company_id;

  perform public.insert_audit_log(
    case when p_status = 'suspended' then 'COMPANY_SUSPENDED' else 'COMPANY_REACTIVATED' end,
    'company', p_company_id, cname, p_company_id,
    'Company status set to ' || p_status
  );

  return jsonb_build_object('company_id', p_company_id, 'status', p_status);
end;
$function$;

create or replace function public.super_admin_set_employee_role(p_employee_id uuid, p_role text)
returns jsonb language plpgsql security definer set search_path to 'public'
as $function$
declare
  emp record;
  cname text;
begin
  perform public.require_platform_admin();

  if p_employee_id is null or p_role is null then
    raise exception 'Employee and role are required';
  end if;

  if p_role not in ('security', 'controllerWB', 'admin', 'management', 'driver') then
    raise exception 'Invalid employee role';
  end if;

  select e.* into emp from public.employees e where e.id = p_employee_id limit 1;
  if emp.id is null then
    raise exception 'Employee not found';
  end if;

  select c.company_name into cname from public.companies c where c.id = emp.company_id limit 1;

  update public.employees set role = p_role where id = p_employee_id;

  perform public.insert_audit_log(
    'USER_ROLE_CHANGED', 'employee', p_employee_id,
    trim(both from coalesce(emp.first_name, '') || ' ' || coalesce(emp.last_name, '')),
    emp.company_id,
    'Employee role changed to "' || p_role || '" by platform admin.'
  );

  return jsonb_build_object('employee_id', p_employee_id, 'role', p_role);
end;
$function$;

create or replace function public.super_admin_set_employee_status(p_employee_id uuid, p_status text, p_reason text default null::text)
returns jsonb language plpgsql security definer set search_path to 'public'
as $function$
declare
  emp record;
  cname text;
  desc_text text;
begin
  perform public.require_platform_admin();

  if p_employee_id is null then
    raise exception 'Employee is required';
  end if;

  if p_status is null or p_status not in ('suspended', 'active') then
    raise exception 'Invalid employee status';
  end if;

  select e.* into emp from public.employees e where e.id = p_employee_id limit 1;
  if emp.id is null then
    raise exception 'Employee not found';
  end if;

  select c.company_name into cname from public.companies c where c.id = emp.company_id limit 1;

  update public.employees set status = p_status where id = p_employee_id;

  desc_text := case when p_status = 'suspended'
    then 'User suspended.' || case when p_reason is not null and length(trim(p_reason)) > 0
      then ' Reason: ' || p_reason else '' end
    else 'User account reactivated by platform admin.'
  end;

  perform public.insert_audit_log(
    case when p_status = 'suspended' then 'USER_SUSPENDED' else 'USER_REACTIVATED' end,
    'employee', p_employee_id,
    trim(both from coalesce(emp.first_name, '') || ' ' || coalesce(emp.last_name, '')),
    emp.company_id, desc_text
  );

  return jsonb_build_object('employee_id', p_employee_id, 'status', p_status);
end;
$function$;

create or replace function public.super_admin_release_organization_seat(p_organization_id uuid, p_user_id uuid)
returns jsonb language plpgsql security definer set search_path to 'public'
as $function$
declare
  n int;
  cname text;
begin
  perform public.require_platform_admin();

  if p_organization_id is null or p_user_id is null then
    raise exception 'Organization and user are required';
  end if;

  select c.company_name into cname from public.companies c where c.id = p_organization_id limit 1;
  if cname is null then
    raise exception 'Organization not found';
  end if;

  update public.organization_seats
  set occupied_by_user_id = null, occupied_by_employee_id = null, occupied_by_name = null,
      occupied_by_email = null, occupied_by_employee_role = null, status = 'available',
      released_at = timezone('utc', now()), assigned_at = null, updated_at = timezone('utc', now())
  where organization_id = p_organization_id and occupied_by_user_id = p_user_id;

  get diagnostics n = row_count;
  perform public.recompute_company_seats_used(p_organization_id);

  perform public.insert_audit_log(
    'SEAT_RELEASED', 'user', p_user_id, null, p_organization_id,
    'User removed from seat by platform admin.'
  );

  return jsonb_build_object('organization_id', p_organization_id, 'user_id', p_user_id, 'rows_updated', n);
end;
$function$;

create or replace function public.claim_token_request(p_request_id uuid)
returns jsonb language plpgsql security definer set search_path to 'public'
as $function$
declare
  req public.token_requests;
  actor_name text;
begin
  perform public.require_platform_admin();

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
  set status = 'in_progress', handling_user_id = auth.uid(),
      handling_started_at = timezone('utc', now()), updated_at = timezone('utc', now())
  where id = req.id;

  perform public.insert_audit_log(
    'TOKEN_REQUEST_CLAIMED', 'tokenRequest', req.id, req.organization_name, req.organization_id,
    'Token request claimed by ' || coalesce(actor_name, '')
  );

  return jsonb_build_object('id', req.id, 'status', 'in_progress', 'handling_user_id', auth.uid());
end;
$function$;

create or replace function public.reject_token_request(p_request_id uuid, p_review_note text default 'Request rejected'::text)
returns jsonb language plpgsql security definer set search_path to 'public'
as $function$
declare
  req public.token_requests;
begin
  perform public.require_platform_admin();

  select * into req from public.token_requests where id = p_request_id for update;
  if req.id is null then
    raise exception 'Token request not found';
  end if;

  if req.status <> 'in_progress' or req.handling_user_id is distinct from auth.uid() then
    raise exception 'You must start the token process (claim) before rejecting this request';
  end if;

  update public.token_requests
  set status = 'rejected', reviewed_by_user_id = auth.uid(),
      reviewed_by_email = (select email from public.profiles where id = auth.uid()),
      reviewed_at = timezone('utc', now()), review_note = p_review_note,
      handling_user_id = null, handling_started_at = null, updated_at = timezone('utc', now())
  where id = req.id;

  if req.request_kind = 'seat_expansion' then
    perform public.insert_audit_log('SEAT_REQUEST_REJECTED', 'seatRequest', req.id,
      req.organization_name, req.organization_id, 'Seat request rejected. Note: ' || coalesce(p_review_note, ''));
  else
    perform public.insert_audit_log('TOKEN_REQUEST_REJECTED', 'tokenRequest', req.id,
      req.organization_name, req.organization_id, 'Token request rejected. Note: ' || coalesce(p_review_note, ''));
  end if;

  return jsonb_build_object('request_id', req.id, 'status', 'rejected');
end;
$function$;

create or replace function public.release_token_request_claim(p_request_id uuid)
returns jsonb language plpgsql security definer set search_path to 'public'
as $function$
declare
  req public.token_requests;
begin
  perform public.require_platform_admin();

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
  set status = 'pending', handling_user_id = null, handling_started_at = null,
      updated_at = timezone('utc', now())
  where id = req.id;

  perform public.insert_audit_log(
    'TOKEN_REQUEST_RELEASED', 'tokenRequest', req.id, req.organization_name, req.organization_id,
    'Token request claim released; back to pending queue'
  );

  return jsonb_build_object('id', req.id, 'status', 'pending');
end;
$function$;

create or replace function public.approve_token_request(p_request_id uuid, p_review_note text default null::text, p_approved_new_seat_limit integer default null::integer, p_valid_days integer default null::integer)
returns jsonb language plpgsql security definer set search_path to 'public', 'extensions'
as $function$
declare
  req public.token_requests;
  company_before jsonb;
  tok_result jsonb;
  days integer;
  seat_lim integer;
begin
  perform public.require_platform_admin();

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
    set seat_limit = p_approved_new_seat_limit, updated_at = timezone('utc', now())
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
  set status = 'approved', reviewed_by_user_id = auth.uid(),
      reviewed_by_email = (select email from public.profiles where id = auth.uid()),
      reviewed_at = timezone('utc', now()), review_note = p_review_note,
      handling_user_id = null, handling_started_at = null, updated_at = timezone('utc', now())
  where id = req.id;

  if req.request_kind = 'seat_expansion' then
    perform public.insert_audit_log('SEAT_REQUEST_APPROVED', 'seatRequest', req.id,
      req.organization_name, req.organization_id,
      'Seat request approved. New seat limit: ' || p_approved_new_seat_limit::text,
      company_before, (select to_jsonb(c) from public.companies c where c.id = req.organization_id));
  else
    perform public.insert_audit_log('TOKEN_REQUEST_APPROVED', 'tokenRequest', req.id,
      req.organization_name, req.organization_id, 'Token request approved (' || req.request_kind || ')');
  end if;

  if req.request_kind = 'seat_expansion' then
    return jsonb_build_object('request_id', req.id, 'status', 'approved', 'approved_new_seat_limit', p_approved_new_seat_limit);
  else
    return coalesce(tok_result, '{}'::jsonb) || jsonb_build_object('request_id', req.id, 'status', 'approved');
  end if;
end;
$function$;

-- ── 2. Drop child helper + management functions (now unreferenced) ───────────
do $$
declare r record;
begin
  for r in
    select p.oid::regprocedure as sig
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname in (
        'is_child_super_admin', 'child_admin_permission',
        'super_admin_assign_child_admin', 'super_admin_disable_child_admin',
        'super_admin_patch_child_admin_permissions', 'get_platform_owner_display_name'
      )
  loop
    execute 'drop function ' || r.sig;
  end loop;
end $$;

-- ── 3. Drop child config columns ────────────────────────────────────────────
alter table public.profiles drop column if exists parent_super_admin_id;

alter table public.platform_admin_settings
  drop column if exists child_can_view_companies,
  drop column if exists child_can_view_users,
  drop column if exists child_can_generate_tokens,
  drop column if exists child_can_revoke_tokens,
  drop column if exists child_can_manage_seats,
  drop column if exists child_can_suspend_companies,
  drop column if exists child_can_download_logs,
  drop column if exists child_can_create_another_child,
  drop column if exists child_can_register_companies,
  drop column if exists child_super_admin_user_id,
  drop column if exists child_super_admin_email,
  drop column if exists child_admin_created_at,
  drop column if exists child_admin_status;

commit;
