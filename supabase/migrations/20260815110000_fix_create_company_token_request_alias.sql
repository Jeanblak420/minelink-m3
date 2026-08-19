-- 20260815110000_fix_create_company_token_request_alias.sql
--
-- `create_company_token_request` could never succeed, for any caller, since it
-- was written. It declared `c record` and then loaded the company with:
--
--     select c.id, c.company_name, ... into c from public.companies c ...
--
-- PL/pgSQL resolves `c.id` in the select list against the declared *variable*,
-- not the table alias of the same name, and the variable is unassigned at that
-- point — so every call raised
--
--     55000  record "c" is not assigned yet
--
-- The raise happens on the third statement, before the seat_expansion argument
-- checks, so no argument combination avoids it. This is why `token_requests`
-- holds 0 rows: the whole seat-expansion / token-renewal / new-token feature is
-- built and wired (profile > company_token_requests_panel.dart, three flows,
-- each ending in a success snackbar) and has never once written a row.
--
-- Same shape as the notification-vocabulary defect of 20260815109000: shipped,
-- reachable, and never executed, so nothing ever reported it.
--
-- The fix is the table alias and nothing else. The audit that found it is
-- re-derivable and is now enforced by tool/plpgsql_alias_collision_check.py:
--
--     prosrc ~ 'into\s+(\w+)\s+from\s+public\.\w+\s+\1\M'
--
-- which matched exactly one function across the whole schema.

create or replace function public.create_company_token_request(
  p_organization_id uuid,
  p_request_kind text,
  p_reason text default ''::text,
  p_requested_extra_seats integer default null::integer,
  p_requested_new_total integer default null::integer,
  p_requested_valid_days integer default null::integer,
  p_current_token_id uuid default null::uuid
)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $function$
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

  -- `co`, not `c`: the record variable below shadows any alias sharing its name.
  select
    co.id,
    co.company_name,
    co.org_type,
    co.seat_limit,
    co.seats_used,
    co.current_token_id,
    co.token_valid_days,
    co.token_expires_at
  into c
  from public.companies co
  where co.id = p_organization_id
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
$function$;
