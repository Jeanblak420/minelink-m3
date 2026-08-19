-- Security hardening from the 2026-07-27 full-project audit.
-- Closes four confirmed holes; applied live to project yftazblpmicqtamyiwyb.
-- All statements are idempotent so this migration is safe to re-run.

-- SECURITY-1: reassign_seat had NO authorization guard — any authenticated
-- user could seize/evict an organization seat in any company. Add a guard:
-- only a platform admin or an owner/manager of the seat's own org may reassign.
CREATE OR REPLACE FUNCTION public.reassign_seat(
  p_seat_id uuid, p_new_user_id uuid, p_new_user_email text,
  p_new_user_name text, p_new_user_role text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_seat record;
  v_count int;
BEGIN
  SELECT * INTO v_seat FROM public.organization_seats WHERE id = p_seat_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Seat not found');
  END IF;

  IF NOT (public.is_platform_admin()
          OR public.is_company_manager(v_seat.organization_id)) THEN
    RETURN jsonb_build_object('success', false,
      'error', 'Not authorized to reassign this seat');
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

    INSERT INTO public.seat_reassignment_log (
      organization_id, seat_id, previous_user_id, previous_user_email,
      new_user_id, new_user_email, reassigned_by
    ) VALUES (
      v_seat.organization_id, p_seat_id, v_seat.occupied_by_user_id,
      v_seat.occupied_by_email, p_new_user_id, p_new_user_email, auth.uid()
    );
  END IF;

  IF v_seat.role_binding IS NOT NULL AND v_seat.role_binding != p_new_user_role THEN
    RETURN jsonb_build_object('success', false,
      'error', format('This seat is bound to role "%s". Cannot assign a "%s" user.', v_seat.role_binding, p_new_user_role));
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

-- SECURITY-2: create_notification_internal is an internal helper for other
-- SECURITY DEFINER functions (which run as owner and are unaffected). Revoke
-- direct REST execute so authenticated users can no longer forge notifications.
REVOKE EXECUTE ON FUNCTION public.create_notification_internal(
  uuid, uuid, uuid, text, text, text, text, uuid, text, text, text, jsonb
) FROM anon, authenticated, public;

-- SECURITY-3: cleanup_old_broadcast_messages performed an unguarded DELETE.
-- The app's maintenance scheduler calls it for any user, so guard as a no-op
-- for non-admins (return 0) rather than raising — only admins now delete.
CREATE OR REPLACE FUNCTION public.cleanup_old_broadcast_messages()
 RETURNS bigint
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  deleted_count bigint;
begin
  if not public.is_platform_admin() then
    return 0;
  end if;
  delete from public.broadcast_messages where timestamp < timezone('utc', now()) - interval '30 days';
  get diagnostics deleted_count = row_count;
  return deleted_count;
end;
$function$;

-- SECURITY-4: mine_hazards INSERT policy was WITH CHECK (true) — any user could
-- forge hazard rows attributable to no one. Add an owner column (default
-- auth.uid(), so the existing insert keeps working) and scope INSERT to it.
ALTER TABLE public.mine_hazards
  ADD COLUMN IF NOT EXISTS reported_by uuid DEFAULT auth.uid();
DROP POLICY IF EXISTS mine_hazards_insert_all ON public.mine_hazards;
CREATE POLICY mine_hazards_insert_own ON public.mine_hazards
  FOR INSERT TO authenticated
  WITH CHECK (reported_by = auth.uid());
