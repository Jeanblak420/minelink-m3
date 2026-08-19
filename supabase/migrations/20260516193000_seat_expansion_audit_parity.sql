begin;

-- Seat expansion approvals/rejections previously used SEAT_REQUEST_* audit rows with
-- company before/after snapshots (approve_seat_request). Restore that parity for
-- request_kind = seat_expansion while keeping TOKEN_REQUEST_* for token flows.

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

  if req.request_kind = 'seat_expansion' then
    perform public.insert_audit_log(
      'SEAT_REQUEST_APPROVED',
      'seatRequest',
      req.id,
      req.organization_name,
      req.organization_id,
      'Seat request approved. New seat limit: ' || p_approved_new_seat_limit::text,
      company_before,
      (select to_jsonb(c) from public.companies c where c.id = req.organization_id)
    );
  else
    perform public.insert_audit_log(
      'TOKEN_REQUEST_APPROVED',
      'tokenRequest',
      req.id,
      req.organization_name,
      req.organization_id,
      'Token request approved (' || req.request_kind || ')'
    );
  end if;

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

  if req.request_kind = 'seat_expansion' then
    perform public.insert_audit_log(
      'SEAT_REQUEST_REJECTED',
      'seatRequest',
      req.id,
      req.organization_name,
      req.organization_id,
      'Seat request rejected. Note: ' || coalesce(p_review_note, '')
    );
  else
    perform public.insert_audit_log(
      'TOKEN_REQUEST_REJECTED',
      'tokenRequest',
      req.id,
      req.organization_name,
      req.organization_id,
      'Token request rejected. Note: ' || coalesce(p_review_note, '')
    );
  end if;

  return jsonb_build_object('request_id', req.id, 'status', 'rejected');
end;
$$;

commit;
