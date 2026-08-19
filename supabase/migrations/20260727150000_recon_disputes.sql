-- Reconciliation dispute workflow (2026-07-27). Applied live to
-- project yftazblpmicqtamyiwyb.
--
-- A party to a trip (staff of its supplier / buyer / transporter company), or
-- the platform admin, can raise a dispute on that trip's weight/delivery
-- reconciliation, discuss it in a comment thread, and the platform admin
-- resolves/rejects it (the raiser may withdraw). Read scoping mirrors
-- list_trip_reconciliations exactly; all writes go through the SECURITY DEFINER
-- RPCs below (tables have SELECT-only RLS, no direct write policy).

CREATE TABLE IF NOT EXISTS public.recon_disputes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  trip_id uuid NOT NULL REFERENCES public.trips(id) ON DELETE CASCADE,
  transaction_id uuid NOT NULL REFERENCES public.transactions(id) ON DELETE CASCADE,
  category text NOT NULL,
  reason text NOT NULL,
  claimed_tons numeric,
  status text NOT NULL DEFAULT 'open',
  raised_by_user_id uuid NOT NULL,
  raised_by_company_id uuid,
  resolution text,
  resolved_by_user_id uuid,
  resolved_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
  updated_at timestamptz NOT NULL DEFAULT timezone('utc', now())
);
COMMENT ON TABLE public.recon_disputes IS 'Disputes raised by a trip party on the weight/delivery reconciliation; resolved by the platform admin.';

CREATE INDEX IF NOT EXISTS recon_disputes_trip_idx ON public.recon_disputes (trip_id);
CREATE INDEX IF NOT EXISTS recon_disputes_transaction_idx ON public.recon_disputes (transaction_id);
CREATE INDEX IF NOT EXISTS recon_disputes_status_idx ON public.recon_disputes (status);
CREATE UNIQUE INDEX IF NOT EXISTS recon_disputes_one_active_per_trip
  ON public.recon_disputes (trip_id) WHERE status IN ('open', 'under_review');

CREATE TABLE IF NOT EXISTS public.recon_dispute_comments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  dispute_id uuid NOT NULL REFERENCES public.recon_disputes(id) ON DELETE CASCADE,
  author_user_id uuid NOT NULL,
  author_company_id uuid,
  author_is_admin boolean NOT NULL DEFAULT false,
  body text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT timezone('utc', now())
);
CREATE INDEX IF NOT EXISTS recon_dispute_comments_dispute_idx ON public.recon_dispute_comments (dispute_id);

DROP TRIGGER IF EXISTS set_recon_disputes_updated_at ON public.recon_disputes;
CREATE TRIGGER set_recon_disputes_updated_at
  BEFORE UPDATE ON public.recon_disputes
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

ALTER TABLE public.recon_disputes ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS recon_disputes_select ON public.recon_disputes;
CREATE POLICY recon_disputes_select ON public.recon_disputes FOR SELECT TO authenticated
  USING (public.is_super_admin() OR EXISTS (
    SELECT 1 FROM public.transactions txn WHERE txn.id = recon_disputes.transaction_id
      AND (public.is_company_staff(txn.supplier_company_id)
        OR public.is_company_staff(txn.buyer_company_id)
        OR public.is_company_staff(txn.transporter_company_id))));

ALTER TABLE public.recon_dispute_comments ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS recon_dispute_comments_select ON public.recon_dispute_comments;
CREATE POLICY recon_dispute_comments_select ON public.recon_dispute_comments FOR SELECT TO authenticated
  USING (public.is_super_admin() OR EXISTS (
    SELECT 1 FROM public.recon_disputes d
      JOIN public.transactions txn ON txn.id = d.transaction_id
    WHERE d.id = recon_dispute_comments.dispute_id
      AND (public.is_company_staff(txn.supplier_company_id)
        OR public.is_company_staff(txn.buyer_company_id)
        OR public.is_company_staff(txn.transporter_company_id))));

GRANT SELECT ON public.recon_disputes TO authenticated;
GRANT SELECT ON public.recon_dispute_comments TO authenticated;

-- Allow the new 'recon_dispute' notification type (the RPCs below notify the
-- parties + platform admins through the existing notification pipeline).
ALTER TABLE public.notifications DROP CONSTRAINT IF EXISTS notifications_type_check;
ALTER TABLE public.notifications ADD CONSTRAINT notifications_type_check CHECK (type = ANY (ARRAY[
  'employeeRequest','roleAssigned','requestDeclined','roleConfirmation','profileUpdate',
  'userManagement','securityAlert','controllerAction','adminAction','managementAction',
  'dismissalInitiated','dismissalAppeal','dismissalFinal','fleetVehicleAdded','fleetDriverAssigned',
  'fleetDriverUnassigned','fleetVehicleStatusChanged','general','tokenExpiringSoon','tokenRequestCreated',
  'tokenRequestClaimed','tokenRequestReleased','tokenRequestHandled','stockpile_prepare','truck_checked_in',
  'truck_loaded','stockpile_depleted','recon_dispute']::text[]));

-- raise_recon_dispute: a trip party (or admin) opens a dispute.
CREATE OR REPLACE FUNCTION public.raise_recon_dispute(
  p_trip_id uuid, p_category text, p_reason text, p_claimed_tons numeric DEFAULT NULL)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $fn$
DECLARE
  v_txn record;
  v_actor uuid := auth.uid();
  v_id uuid;
  v_ref text;
  v_title text := 'Reconciliation dispute raised';
  v_msg text;
  v_meta jsonb;
BEGIN
  IF v_actor IS NULL THEN RAISE EXCEPTION 'Not authenticated'; END IF;
  IF coalesce(trim(p_reason), '') = '' THEN RAISE EXCEPTION 'A reason is required'; END IF;
  IF p_category NOT IN ('weight_variance','short_delivery','quality','seal','damage','other') THEN
    RAISE EXCEPTION 'Invalid dispute category';
  END IF;

  SELECT txn.* INTO v_txn
  FROM public.trips t JOIN public.transactions txn ON txn.id = t.transaction_id
  WHERE t.id = p_trip_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Trip not found'; END IF;

  IF NOT (public.is_platform_admin()
      OR public.is_company_staff(v_txn.supplier_company_id)
      OR public.is_company_staff(v_txn.buyer_company_id)
      OR public.is_company_staff(v_txn.transporter_company_id)) THEN
    RAISE EXCEPTION 'Not authorized to dispute this trip';
  END IF;

  IF EXISTS (SELECT 1 FROM public.recon_disputes
      WHERE trip_id = p_trip_id AND status IN ('open','under_review')) THEN
    RAISE EXCEPTION 'An open dispute already exists for this trip';
  END IF;

  v_id := gen_random_uuid();
  INSERT INTO public.recon_disputes(
    id, trip_id, transaction_id, category, reason, claimed_tons, status,
    raised_by_user_id, raised_by_company_id)
  VALUES (v_id, p_trip_id, v_txn.id, p_category, p_reason, p_claimed_tons, 'open',
    v_actor, public.current_company_id());

  v_ref := coalesce(v_txn.reference_number, left(p_trip_id::text, 8));
  v_msg := format('A %s dispute was raised on trip %s.', replace(p_category,'_',' '), v_ref);
  v_meta := jsonb_build_object('dispute_id', v_id, 'trip_id', p_trip_id);

  IF v_txn.supplier_company_id IS NOT NULL THEN
    PERFORM public.notify_company_management(v_txn.supplier_company_id, v_title, v_msg, 'recon_dispute', NULL, v_actor, 'high', v_meta);
  END IF;
  IF v_txn.buyer_company_id IS NOT NULL THEN
    PERFORM public.notify_company_management(v_txn.buyer_company_id, v_title, v_msg, 'recon_dispute', NULL, v_actor, 'high', v_meta);
  END IF;
  IF v_txn.transporter_company_id IS NOT NULL THEN
    PERFORM public.notify_company_management(v_txn.transporter_company_id, v_title, v_msg, 'recon_dispute', NULL, v_actor, 'high', v_meta);
  END IF;
  INSERT INTO public.notifications(user_id, title, message, type, org_type, metadata)
  SELECT p.id, v_title, v_msg, 'recon_dispute', NULL, v_meta
  FROM public.profiles p WHERE p.platform_role = 'superGlobalSerialAdminMain';

  RETURN jsonb_build_object('id', v_id, 'status', 'open');
END;
$fn$;

-- add_recon_dispute_comment: any party (or admin) adds to the thread.
CREATE OR REPLACE FUNCTION public.add_recon_dispute_comment(p_dispute_id uuid, p_body text)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $fn$
DECLARE v_d record; v_txn record; v_actor uuid := auth.uid(); v_id uuid;
BEGIN
  IF v_actor IS NULL THEN RAISE EXCEPTION 'Not authenticated'; END IF;
  IF coalesce(trim(p_body), '') = '' THEN RAISE EXCEPTION 'Comment cannot be empty'; END IF;
  SELECT * INTO v_d FROM public.recon_disputes WHERE id = p_dispute_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Dispute not found'; END IF;
  SELECT * INTO v_txn FROM public.transactions WHERE id = v_d.transaction_id;
  IF NOT (public.is_platform_admin()
      OR public.is_company_staff(v_txn.supplier_company_id)
      OR public.is_company_staff(v_txn.buyer_company_id)
      OR public.is_company_staff(v_txn.transporter_company_id)) THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;
  v_id := gen_random_uuid();
  INSERT INTO public.recon_dispute_comments(id, dispute_id, author_user_id, author_company_id, author_is_admin, body)
  VALUES (v_id, p_dispute_id, v_actor, public.current_company_id(), public.is_platform_admin(), p_body);
  UPDATE public.recon_disputes SET updated_at = timezone('utc', now()) WHERE id = p_dispute_id;
  RETURN jsonb_build_object('id', v_id);
END;
$fn$;

-- set_recon_dispute_status: admin reviews/resolves/rejects; raiser may withdraw.
CREATE OR REPLACE FUNCTION public.set_recon_dispute_status(
  p_dispute_id uuid, p_status text, p_resolution text DEFAULT NULL)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $fn$
DECLARE
  v_d record; v_txn record; v_actor uuid := auth.uid(); v_is_admin boolean;
  v_ref text; v_title text; v_msg text; v_meta jsonb;
BEGIN
  IF v_actor IS NULL THEN RAISE EXCEPTION 'Not authenticated'; END IF;
  SELECT * INTO v_d FROM public.recon_disputes WHERE id = p_dispute_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Dispute not found'; END IF;
  SELECT * INTO v_txn FROM public.transactions WHERE id = v_d.transaction_id;
  v_is_admin := public.is_platform_admin();

  IF p_status = 'withdrawn' THEN
    IF v_d.raised_by_user_id <> v_actor AND NOT v_is_admin THEN
      RAISE EXCEPTION 'Only the person who raised it can withdraw this dispute';
    END IF;
    IF v_d.status NOT IN ('open','under_review') THEN
      RAISE EXCEPTION 'Dispute is already closed';
    END IF;
  ELSIF p_status IN ('under_review','resolved','rejected') THEN
    IF NOT v_is_admin THEN RAISE EXCEPTION 'Only a platform admin can review or resolve disputes'; END IF;
    IF v_d.status IN ('resolved','rejected','withdrawn') THEN
      RAISE EXCEPTION 'Dispute is already closed';
    END IF;
    IF p_status IN ('resolved','rejected') AND coalesce(trim(p_resolution), '') = '' THEN
      RAISE EXCEPTION 'A resolution note is required to close a dispute';
    END IF;
  ELSE
    RAISE EXCEPTION 'Invalid status';
  END IF;

  UPDATE public.recon_disputes SET
    status = p_status,
    resolution = CASE WHEN p_status IN ('resolved','rejected') THEN p_resolution ELSE resolution END,
    resolved_by_user_id = CASE WHEN p_status IN ('resolved','rejected','withdrawn') THEN v_actor ELSE resolved_by_user_id END,
    resolved_at = CASE WHEN p_status IN ('resolved','rejected','withdrawn') THEN timezone('utc', now()) ELSE resolved_at END,
    updated_at = timezone('utc', now())
  WHERE id = p_dispute_id;

  v_ref := coalesce(v_txn.reference_number, left(v_d.trip_id::text, 8));
  v_title := 'Dispute ' || replace(p_status, '_', ' ');
  v_msg := format('The dispute on trip %s is now %s.', v_ref, replace(p_status, '_', ' '));
  v_meta := jsonb_build_object('dispute_id', p_dispute_id, 'trip_id', v_d.trip_id);
  IF v_txn.supplier_company_id IS NOT NULL THEN
    PERFORM public.notify_company_management(v_txn.supplier_company_id, v_title, v_msg, 'recon_dispute', NULL, v_actor, 'normal', v_meta);
  END IF;
  IF v_txn.buyer_company_id IS NOT NULL THEN
    PERFORM public.notify_company_management(v_txn.buyer_company_id, v_title, v_msg, 'recon_dispute', NULL, v_actor, 'normal', v_meta);
  END IF;
  IF v_txn.transporter_company_id IS NOT NULL THEN
    PERFORM public.notify_company_management(v_txn.transporter_company_id, v_title, v_msg, 'recon_dispute', NULL, v_actor, 'normal', v_meta);
  END IF;

  RETURN jsonb_build_object('id', p_dispute_id, 'status', p_status);
END;
$fn$;

-- list_recon_disputes: party-scoped (all, for admin when p_company_id is null),
-- joined with the trip's reconciliation figures. Newest first.
CREATE OR REPLACE FUNCTION public.list_recon_disputes(p_company_id uuid DEFAULT NULL)
 RETURNS TABLE(
   id uuid, trip_id uuid, transaction_id uuid, category text, reason text,
   claimed_tons numeric, status text, reference text, truck_reg text,
   source_name text, customer_name text, transporter_name text,
   mine_net_tons numeric, delivered_tons numeric, variance numeric,
   raised_by_user_id uuid, raised_by_name text, raised_by_company_id uuid,
   raised_by_company_name text, resolution text, resolved_at timestamptz,
   comment_count bigint, created_at timestamptz, updated_at timestamptz)
 LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public'
AS $fn$
  SELECT d.id, d.trip_id, d.transaction_id, d.category, d.reason,
    d.claimed_tons, d.status, txn.reference_number,
    coalesce(t.metadata->>'truck_reg', fv.vehicle_registration_number),
    sc.company_name, bc.company_name, tc.company_name,
    t.net_tons, pod.delivered_tons,
    CASE WHEN t.net_tons IS NOT NULL AND pod.delivered_tons IS NOT NULL
      THEN t.net_tons - pod.delivered_tons ELSE NULL END,
    d.raised_by_user_id, coalesce(rp.display_name, rp.email), d.raised_by_company_id,
    rc.company_name, d.resolution, d.resolved_at,
    (SELECT count(*) FROM public.recon_dispute_comments c WHERE c.dispute_id = d.id),
    d.created_at, d.updated_at
  FROM public.recon_disputes d
  JOIN public.trips t ON t.id = d.trip_id
  JOIN public.transactions txn ON txn.id = d.transaction_id
  LEFT JOIN public.fleet_vehicles fv ON fv.id = t.vehicle_id
  LEFT JOIN public.companies sc ON sc.id = txn.supplier_company_id
  LEFT JOIN public.companies bc ON bc.id = txn.buyer_company_id
  LEFT JOIN public.companies tc ON tc.id = txn.transporter_company_id
  LEFT JOIN public.profiles rp ON rp.id = d.raised_by_user_id
  LEFT JOIN public.companies rc ON rc.id = d.raised_by_company_id
  LEFT JOIN LATERAL (SELECT p.delivered_tons FROM public.pod_uploads p
    WHERE p.trip_id = t.id ORDER BY p.uploaded_at DESC LIMIT 1) pod ON true
  WHERE (public.is_platform_admin()
      OR public.is_company_staff(txn.supplier_company_id)
      OR public.is_company_staff(txn.buyer_company_id)
      OR public.is_company_staff(txn.transporter_company_id))
    AND (p_company_id IS NULL
      OR txn.supplier_company_id = p_company_id
      OR txn.buyer_company_id = p_company_id
      OR txn.transporter_company_id = p_company_id)
  ORDER BY d.updated_at DESC;
$fn$;

-- list_recon_dispute_comments: the thread for one dispute, party-scoped.
CREATE OR REPLACE FUNCTION public.list_recon_dispute_comments(p_dispute_id uuid)
 RETURNS TABLE(
   id uuid, author_user_id uuid, author_name text, author_company_id uuid,
   author_company_name text, author_is_admin boolean, body text,
   created_at timestamptz)
 LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public'
AS $fn$
  SELECT c.id, c.author_user_id, coalesce(ap.display_name, ap.email),
    c.author_company_id, ac.company_name, c.author_is_admin, c.body, c.created_at
  FROM public.recon_dispute_comments c
  JOIN public.recon_disputes d ON d.id = c.dispute_id
  JOIN public.transactions txn ON txn.id = d.transaction_id
  LEFT JOIN public.profiles ap ON ap.id = c.author_user_id
  LEFT JOIN public.companies ac ON ac.id = c.author_company_id
  WHERE c.dispute_id = p_dispute_id
    AND (public.is_platform_admin()
      OR public.is_company_staff(txn.supplier_company_id)
      OR public.is_company_staff(txn.buyer_company_id)
      OR public.is_company_staff(txn.transporter_company_id))
  ORDER BY c.created_at ASC;
$fn$;
