-- Account setup follow-up (2026-08-07): stop reminding about superseded
-- documents. Applied live to project yftazblpmicqtamyiwyb.
--
-- Renewing an EXPIRED document through the self-service account-setup flow
-- (and any employer re-add) inserts a fresh compliance_documents row so the
-- history stays. The old expired row still matched the daily job's predicate
-- (expires_at <= today+30) forever, so the employee and management kept
-- getting "Document expired" reminders every 6 days for a document that had
-- already been renewed. Skip any row when a NEWER row exists for the same
-- (owner_type, owner_id, doc_type) with a strictly later expiry — mirroring
-- the "latest row wins" rule _profile_setup_payload already applies.

CREATE OR REPLACE FUNCTION public.notify_expiring_documents_job()
 RETURNS integer LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $fn$
DECLARE v_d record; v_count integer := 0; v_owner text; v_when text; v_doc_label text;
BEGIN
  FOR v_d IN
    SELECT d.*,
      CASE d.owner_type
        WHEN 'vehicle' THEN fv.vehicle_registration_number
        WHEN 'employee' THEN nullif(trim(coalesce(e.first_name,'') || ' ' || coalesce(e.last_name,'')), '')
        WHEN 'company' THEN oc.company_name
      END AS owner_name,
      e.user_id AS owner_user_id, e.role AS owner_role,
      mc.org_type AS company_org_type
    FROM public.compliance_documents d
    JOIN public.companies mc ON mc.id = d.company_id
    LEFT JOIN public.fleet_vehicles fv ON d.owner_type = 'vehicle' AND fv.id = d.owner_id
    LEFT JOIN public.employees e ON d.owner_type = 'employee' AND e.id = d.owner_id
    LEFT JOIN public.companies oc ON d.owner_type = 'company' AND oc.id = d.owner_id
    WHERE d.expires_at IS NOT NULL
      AND d.expires_at <= current_date + 30
      AND (d.last_notified_at IS NULL OR d.last_notified_at < now() - interval '6 days')
      -- superseded by a renewal: a newer record of the same document exists
      AND NOT EXISTS (
        SELECT 1 FROM public.compliance_documents n
        WHERE n.owner_type = d.owner_type
          AND n.owner_id = d.owner_id
          AND n.doc_type = d.doc_type
          AND n.id <> d.id
          AND n.expires_at IS NOT NULL
          AND n.expires_at > d.expires_at)
  LOOP
    v_owner := coalesce(v_d.owner_name, initcap(v_d.owner_type));
    v_doc_label := coalesce(nullif(v_d.title,''), replace(v_d.doc_type, '_', ' '));
    v_when := CASE WHEN v_d.expires_at < current_date
      THEN 'EXPIRED on ' || to_char(v_d.expires_at, 'DD Mon YYYY')
      ELSE 'expires ' || to_char(v_d.expires_at, 'DD Mon YYYY') END;

    PERFORM public.notify_company_management(
      v_d.company_id,
      CASE WHEN v_d.expires_at < current_date THEN 'Document expired' ELSE 'Document expiring soon' END,
      format('%s — %s %s. Renew it and update the record under Compliance.',
        v_owner, v_doc_label, v_when),
      'general', NULL, NULL,
      CASE WHEN v_d.expires_at < current_date THEN 'high' ELSE 'normal' END,
      jsonb_build_object('compliance_document_id', v_d.id, 'owner_type', v_d.owner_type,
        'owner_id', v_d.owner_id, 'nav_tab', 'Compliance'));

    -- Personal copy to the employee who owns the document. (Company-owned
    -- docs already reach the company owner via notify_company_management;
    -- vehicles have no personal owner.)
    IF v_d.owner_type = 'employee' AND v_d.owner_user_id IS NOT NULL THEN
      PERFORM public.create_notification_internal(
        v_d.owner_user_id, v_d.company_id, v_d.owner_id,
        CASE WHEN v_d.expires_at < current_date
          THEN 'Your document has expired' ELSE 'Your document expires soon' END,
        format('Your %s %s. Please renew it and upload the new document under Account setup.',
          v_doc_label, v_when),
        'general', NULL, NULL, v_d.owner_role, v_d.company_org_type,
        CASE WHEN v_d.expires_at < current_date THEN 'high' ELSE 'normal' END,
        jsonb_build_object('compliance_document_id', v_d.id, 'kind', 'profile_setup',
          'nav_route', '/account-setup'));
    END IF;

    UPDATE public.compliance_documents SET last_notified_at = now() WHERE id = v_d.id;
    v_count := v_count + 1;
  END LOOP;
  RETURN v_count;
END;
$fn$;
REVOKE ALL ON FUNCTION public.notify_expiring_documents_job() FROM public, anon, authenticated;
