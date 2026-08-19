-- Flatten the child-super-admin concept (CLAUDE.md §4 — both super admins are
-- equal, full-rights). Applied live to project yftazblpmicqtamyiwyb.
--
-- The Dart side was already flattened (platform_role.dart maps the legacy
-- `superGlobalSerialAdminMainChild` string onto the single main role). This
-- migration removes the residual DB references: the child role string in four
-- functions and two policies, and the dead child sub-permission branches in the
-- token functions (which referenced the already-dropped
-- platform_admin_settings.child_can_* columns). No profiles carry the child
-- role, so there is no data to migrate.

-- is_super_admin(): recognise only the single full-rights role.
CREATE OR REPLACE FUNCTION public.is_super_admin()
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select exists(
    select 1 from public.profiles p
    where p.id = auth.uid() and p.platform_role = 'superGlobalSerialAdminMain'
  );
$function$;

-- _notify_platform_admins_token(): notify the single admin role.
CREATE OR REPLACE FUNCTION public._notify_platform_admins_token(p_type text, p_title text, p_message text, p_metadata jsonb DEFAULT '{}'::jsonb)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  r record;
begin
  for r in
    select p.id as uid from public.profiles p
    where p.platform_role = 'superGlobalSerialAdminMain'
  loop
    insert into public.notifications (user_id, title, message, type, org_type, metadata)
    values (r.uid, p_title, p_message, p_type, null, coalesce(p_metadata, '{}'::jsonb));
  end loop;
end;
$function$;

-- create_serial_token(): drop the child sub-permission branch; any super admin generates.
CREATE OR REPLACE FUNCTION public.create_serial_token(p_organization_id uuid, p_valid_days integer, p_seat_limit integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_caller_id uuid;
  v_caller_email text;
  v_caller_role text;
  v_org record;
  v_token_raw text;
  v_token_hash text;
  v_token_preview text;
  v_token_id uuid;
  v_expires_at timestamptz;
  v_current_seats_used integer;
begin
  v_caller_id := auth.uid();
  select email, platform_role into v_caller_email, v_caller_role
  from public.profiles where id = v_caller_id;

  if v_caller_role <> 'superGlobalSerialAdminMain' then
    raise exception 'Unauthorized: Only platform super admins can generate tokens';
  end if;

  select * into v_org from public.companies where id = p_organization_id;
  if not found then
    raise exception 'Organization not found';
  end if;

  if p_valid_days <= 0 then
    raise exception 'Valid days must be greater than 0';
  end if;

  select count(*) into v_current_seats_used
  from public.organization_seats
  where organization_id = p_organization_id and status = 'occupied';

  if p_seat_limit < v_current_seats_used then
    raise exception 'Seat limit cannot be less than current seats used (%)', v_current_seats_used;
  end if;

  v_expires_at := timezone('utc', now()) + (p_valid_days || ' days')::interval;

  v_token_raw := 'CH-ENT-' ||
    case v_org.org_type
      when 'mineSupplier' then 'MINE'
      when 'buyer' then 'BUY'
      when 'transporter' then 'TRN'
    end || '-' ||
    to_char(now(), 'YYYY') || '-' ||
    upper(substring(encode(extensions.gen_random_bytes(12), 'hex') from 1 for 4)) || '-' ||
    upper(substring(encode(extensions.gen_random_bytes(12), 'hex') from 1 for 4)) || '-' ||
    upper(substring(encode(extensions.gen_random_bytes(12), 'hex') from 1 for 4));

  v_token_hash := encode(extensions.digest(v_token_raw, 'sha256'), 'hex');
  v_token_preview := substring(v_token_raw from 1 for 12) || '****';

  update public.serial_tokens
  set status = 'replaced', updated_at = timezone('utc', now())
  where organization_id = p_organization_id and status = 'active';

  v_token_id := gen_random_uuid();
  insert into public.serial_tokens (
    id, organization_id, organization_name, organization_type,
    token_hash, token_preview, valid_days, expires_at,
    seat_limit, status,
    generated_by_user_id, generated_by_email, generated_by_platform_role
  ) values (
    v_token_id, p_organization_id, v_org.company_name, v_org.org_type,
    v_token_hash, v_token_preview, p_valid_days, v_expires_at,
    p_seat_limit, 'active',
    v_caller_id, v_caller_email, v_caller_role
  );

  update public.companies
  set status = 'active',
      current_token_id = v_token_id,
      token_expires_at = v_expires_at,
      token_valid_days = p_valid_days,
      seat_limit = p_seat_limit,
      seats_available = p_seat_limit - v_current_seats_used,
      last_token_generated_by = v_caller_id,
      last_token_generated_at = timezone('utc', now()),
      updated_at = timezone('utc', now())
  where id = p_organization_id;

  insert into public.organization_seats (organization_id, seat_number, status)
  select p_organization_id, generate_series, 'available'
  from generate_series(
    coalesce((select max(seat_number) from public.organization_seats where organization_id = p_organization_id), 0) + 1,
    p_seat_limit
  )
  on conflict (organization_id, seat_number) do nothing;

  insert into public.audit_logs (
    actor_user_id, actor_email, actor_platform_role,
    action_type, target_type, target_id, target_name,
    organization_id, organization_name, organization_type,
    description, after_data
  ) values (
    v_caller_id, v_caller_email, v_caller_role,
    'TOKEN_GENERATED', 'serialToken', v_token_id::text, v_token_preview,
    p_organization_id, v_org.company_name, v_org.org_type,
    format('Generated %s-day token for %s %s with %s seats', p_valid_days, v_org.org_type, v_org.company_name, p_seat_limit),
    jsonb_build_object('valid_days', p_valid_days, 'seat_limit', p_seat_limit, 'expires_at', v_expires_at)
  );

  return jsonb_build_object(
    'success', true,
    'token_id', v_token_id,
    'raw_token', v_token_raw,
    'token_preview', v_token_preview,
    'expires_at', v_expires_at,
    'valid_days', p_valid_days,
    'seat_limit', p_seat_limit,
    'organization_name', v_org.company_name
  );
end;
$function$;

-- revoke_serial_token(): drop the child revoke-permission branch.
CREATE OR REPLACE FUNCTION public.revoke_serial_token(p_token_id uuid, p_reason text DEFAULT 'Revoked by admin'::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  v_caller_id uuid;
  v_caller_email text;
  v_caller_role text;
  v_token record;
BEGIN
  v_caller_id := auth.uid();
  SELECT email, platform_role INTO v_caller_email, v_caller_role
  FROM public.profiles WHERE id = v_caller_id;

  IF v_caller_role <> 'superGlobalSerialAdminMain' THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;

  SELECT * INTO v_token FROM public.serial_tokens WHERE id = p_token_id AND status = 'active';
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Active token not found';
  END IF;

  UPDATE public.serial_tokens
  SET status = 'revoked', revoked_by = v_caller_id, revoked_at = timezone('utc', now()), revoke_reason = p_reason, updated_at = timezone('utc', now())
  WHERE id = p_token_id;

  UPDATE public.companies
  SET status = 'suspended', current_token_id = NULL, updated_at = timezone('utc', now())
  WHERE id = v_token.organization_id;

  INSERT INTO public.audit_logs (
    actor_user_id, actor_email, actor_platform_role,
    action_type, target_type, target_id, target_name,
    organization_id, organization_name, organization_type,
    description
  ) VALUES (
    v_caller_id, v_caller_email, v_caller_role,
    'TOKEN_REVOKED', 'serialToken', p_token_id::text, v_token.token_preview,
    v_token.organization_id, v_token.organization_name, v_token.organization_type,
    format('Revoked token for %s. Reason: %s', v_token.organization_name, p_reason)
  );

  RETURN jsonb_build_object('success', true, 'message', 'Token revoked successfully');
END;
$function$;

-- Policies that still carried the child role inline -> is_super_admin().
ALTER POLICY "Super admins full access to seat_reassignment_log" ON public.seat_reassignment_log
  USING (is_super_admin()) WITH CHECK (is_super_admin());
ALTER POLICY "Super admins can insert audit logs" ON public.audit_logs
  WITH CHECK (is_super_admin());
