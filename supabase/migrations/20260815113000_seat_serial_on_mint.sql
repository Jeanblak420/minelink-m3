-- 20260815113000_seat_serial_on_mint.sql
--
-- `generate_seat_serial` existed with ZERO callers, so every one of the 106
-- seats on the project carried a null `serial_number` -- the serial being the
-- unit the serial token is named for. `create_serial_token` mints the seat rows
-- and never set one.
--
-- The existing seats were backfilled on 2026-08-15 (all 274 now carry a
-- distinct serial). This is the other half: without it the very next token
-- issued mints seats with null serials again, and the backfill decays.
--
-- The ONLY change to the function is the seat-minting INSERT, which now selects
-- `public.generate_seat_serial(null)` per row. Null role -> the 'GEN' suffix,
-- which is right for a seat nobody occupies yet; the role suffix (ADM/MGT/CTR/
-- SEC/DRV) is a property of the occupant, and a seat is minted empty.
--
-- Everything else is reproduced verbatim from the live definition. Note
-- `SET search_path TO ''` on this function: every reference has to be
-- schema-qualified, which is why the added call is `public.generate_seat_serial`
-- and not a bare name.

create or replace function public.create_serial_token(
  p_organization_id uuid,
  p_valid_days integer,
  p_seat_limit integer
)
returns jsonb
language plpgsql
security definer
set search_path to ''
as $function$
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

  -- CHANGED: a minted seat now carries its serial. Null role -> 'GEN', because
  -- a seat is minted empty and the role suffix belongs to whoever takes it.
  insert into public.organization_seats (organization_id, seat_number, status, serial_number)
  select p_organization_id, generate_series, 'available', public.generate_seat_serial(null)
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
