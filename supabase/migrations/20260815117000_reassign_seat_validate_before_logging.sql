-- 20260815117000_reassign_seat_validate_before_logging.sql
--
-- `reassign_seat` wrote its audit row BEFORE it validated the seat's
-- role_binding, and returns a `{success:false}` object rather than raising. A
-- normal return does not roll anything back, so a reassignment that was
-- REFUSED still:
--
--   * inserted a row into seat_reassignment_log claiming it happened, and
--   * consumed one of the company's 2 permitted reassignments per 30 days.
--
-- Two refusals on a role-bound seat would therefore exhaust a company's whole
-- monthly allowance without a single seat ever changing hands, and the log --
-- the record of who moved which seat and when -- would show two moves that
-- never occurred.
--
-- The fix is ordering: every check that can refuse now runs before anything is
-- written. Nothing else changes; the jsonb contract is preserved because the
-- UI added alongside this reads `success` and `error`.
--
-- The governance itself was already correct and server-side (2 per 30 days,
-- non-rolling, checked against seat_reassignment_log) -- it had simply never
-- been reachable, because `reassign_seat` had no call site anywhere in the app.

create or replace function public.reassign_seat(
  p_seat_id uuid,
  p_new_user_id uuid,
  p_new_user_email text,
  p_new_user_name text,
  p_new_user_role text
)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $function$
DECLARE
  v_seat record;
  v_count int;
BEGIN
  SELECT * INTO v_seat FROM public.organization_seats WHERE id = p_seat_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Seat not found');
  END IF;

  -- AUTHORIZATION: only a platform admin, or an owner/manager of the seat's
  -- own organization, may reassign it.
  IF NOT (public.is_platform_admin()
          OR public.is_company_manager(v_seat.organization_id)) THEN
    RETURN jsonb_build_object('success', false,
      'error', 'Not authorized to reassign this seat');
  END IF;

  -- VALIDATE FIRST. This block used to sit AFTER the log insert below, so a
  -- refusal here still burned one of the 2 permitted moves and left a log row
  -- describing a reassignment that did not happen.
  IF v_seat.role_binding IS NOT NULL AND v_seat.role_binding != p_new_user_role THEN
    RETURN jsonb_build_object('success', false,
      'error', format('This seat is bound to role "%s". Cannot assign a "%s" user.',
                      v_seat.role_binding, p_new_user_role));
  END IF;

  IF NOT public.is_valid_role_for_org(
       (SELECT org_type FROM public.companies WHERE id = v_seat.organization_id),
       p_new_user_role) THEN
    RETURN jsonb_build_object('success', false,
      'error', format('Role "%s" is not valid for this organisation.', p_new_user_role));
  END IF;

  IF v_seat.occupied_by_user_id IS NOT NULL THEN
    SELECT COUNT(*) INTO v_count
    FROM public.seat_reassignment_log
    WHERE organization_id = v_seat.organization_id
      AND reassigned_at >= (NOW() - INTERVAL '30 days');

    IF v_count >= 2 THEN
      RETURN jsonb_build_object('success', false,
        'error', 'Seat reassignment limit reached (2 per 30 days). Cannot reassign until the window resets.');
    END IF;

    -- Only now, with every refusal path behind us, is the move recorded.
    INSERT INTO public.seat_reassignment_log (
      organization_id, seat_id, previous_user_id, previous_user_email,
      new_user_id, new_user_email, reassigned_by
    ) VALUES (
      v_seat.organization_id, p_seat_id, v_seat.occupied_by_user_id,
      v_seat.occupied_by_email, p_new_user_id, p_new_user_email, auth.uid()
    );
  END IF;

  UPDATE public.organization_seats SET
    occupied_by_user_id = p_new_user_id,
    occupied_by_email = p_new_user_email,
    occupied_by_name = p_new_user_name,
    occupied_by_employee_role = p_new_user_role,
    status = 'occupied',
    assigned_at = NOW(),
    released_at = NULL,
    updated_at = NOW()
  WHERE id = p_seat_id;

  RETURN jsonb_build_object('success', true);
END;
$function$;
