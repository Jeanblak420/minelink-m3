-- Compliance document + expiry engine (2026-07-27). Applied live to
-- project yftazblpmicqtamyiwyb.
--
-- One generic register for any expiring document a company manages — a vehicle
-- (registration, COF, licence disc, insurance/GIT), an employee/driver (licence,
-- PrDP, induction), or the company itself (mining right, DMRE return, explosives
-- permit). A daily cron notifies the managing company's management before expiry.
-- Reads = company staff; writes via manager/admin-guarded SECURITY DEFINER RPCs.

CREATE TABLE IF NOT EXISTS public.compliance_documents (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id uuid NOT NULL REFERENCES public.companies(id) ON DELETE CASCADE,
  owner_type text NOT NULL CHECK (owner_type IN ('vehicle','employee','company')),
  owner_id uuid NOT NULL,
  doc_type text NOT NULL,
  title text,
  doc_number text,
  issued_at date,
  expires_at date,
  file_path text,
  notes text,
  last_notified_at timestamptz,
  created_by uuid,
  created_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
  updated_at timestamptz NOT NULL DEFAULT timezone('utc', now())
);
COMMENT ON TABLE public.compliance_documents IS 'Generic expiring-document register (vehicle / employee / company) with daily expiry reminders.';

CREATE INDEX IF NOT EXISTS compliance_documents_company_idx ON public.compliance_documents (company_id);
CREATE INDEX IF NOT EXISTS compliance_documents_owner_idx ON public.compliance_documents (owner_type, owner_id);
CREATE INDEX IF NOT EXISTS compliance_documents_expires_idx ON public.compliance_documents (expires_at);

DROP TRIGGER IF EXISTS set_compliance_documents_updated_at ON public.compliance_documents;
CREATE TRIGGER set_compliance_documents_updated_at
  BEFORE UPDATE ON public.compliance_documents
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

ALTER TABLE public.compliance_documents ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS compliance_documents_select ON public.compliance_documents;
CREATE POLICY compliance_documents_select ON public.compliance_documents FOR SELECT TO authenticated
  USING (public.is_platform_admin() OR public.is_company_staff(company_id));
GRANT SELECT ON public.compliance_documents TO authenticated;

-- Private storage bucket for optional document files, company-path scoped
-- exactly like request_docs ({company_id}/…).
INSERT INTO storage.buckets (id, name, public)
VALUES ('compliance_docs', 'compliance_docs', false)
ON CONFLICT (id) DO NOTHING;

DROP POLICY IF EXISTS compliance_docs_insert_company ON storage.objects;
CREATE POLICY compliance_docs_insert_company ON storage.objects FOR INSERT TO authenticated
  WITH CHECK ((bucket_id = 'compliance_docs') AND (EXISTS (
    SELECT 1 FROM public.companies c
    WHERE ((c.id)::text = (storage.foldername(objects.name))[1]) AND public.is_company_staff(c.id))));
DROP POLICY IF EXISTS compliance_docs_select ON storage.objects;
CREATE POLICY compliance_docs_select ON storage.objects FOR SELECT TO authenticated
  USING ((bucket_id = 'compliance_docs') AND (public.is_platform_admin() OR EXISTS (
    SELECT 1 FROM public.companies c
    WHERE ((c.id)::text = (storage.foldername(objects.name))[1]) AND public.is_company_staff(c.id))));
DROP POLICY IF EXISTS compliance_docs_delete_company ON storage.objects;
CREATE POLICY compliance_docs_delete_company ON storage.objects FOR DELETE TO authenticated
  USING ((bucket_id = 'compliance_docs') AND (EXISTS (
    SELECT 1 FROM public.companies c
    WHERE ((c.id)::text = (storage.foldername(objects.name))[1]) AND public.is_company_staff(c.id))));

-- upsert_compliance_document: manager/admin creates or edits a document.
CREATE OR REPLACE FUNCTION public.upsert_compliance_document(
  p_company_id uuid, p_owner_type text, p_owner_id uuid, p_doc_type text,
  p_expires_at date DEFAULT NULL, p_id uuid DEFAULT NULL, p_title text DEFAULT NULL,
  p_doc_number text DEFAULT NULL, p_issued_at date DEFAULT NULL,
  p_file_path text DEFAULT NULL, p_notes text DEFAULT NULL)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $fn$
DECLARE v_id uuid;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Not authenticated'; END IF;
  IF NOT (public.is_platform_admin() OR public.is_company_manager(p_company_id)) THEN
    RAISE EXCEPTION 'Only a company manager or platform admin can manage compliance documents';
  END IF;
  IF p_owner_type NOT IN ('vehicle','employee','company') THEN
    RAISE EXCEPTION 'Invalid owner type';
  END IF;
  IF coalesce(trim(p_doc_type), '') = '' THEN RAISE EXCEPTION 'Document type is required'; END IF;

  IF p_id IS NULL THEN
    v_id := gen_random_uuid();
    INSERT INTO public.compliance_documents(
      id, company_id, owner_type, owner_id, doc_type, title, doc_number,
      issued_at, expires_at, file_path, notes, created_by)
    VALUES (v_id, p_company_id, p_owner_type, p_owner_id, p_doc_type, p_title,
      p_doc_number, p_issued_at, p_expires_at, p_file_path, p_notes, auth.uid());
  ELSE
    UPDATE public.compliance_documents SET
      owner_type = p_owner_type, owner_id = p_owner_id, doc_type = p_doc_type,
      title = p_title, doc_number = p_doc_number, issued_at = p_issued_at,
      expires_at = p_expires_at,
      file_path = coalesce(p_file_path, file_path), notes = p_notes,
      last_notified_at = CASE WHEN p_expires_at IS DISTINCT FROM expires_at
        THEN NULL ELSE last_notified_at END
    WHERE id = p_id AND company_id = p_company_id;
    IF NOT FOUND THEN RAISE EXCEPTION 'Document not found'; END IF;
    v_id := p_id;
  END IF;
  RETURN jsonb_build_object('id', v_id);
END;
$fn$;

CREATE OR REPLACE FUNCTION public.delete_compliance_document(p_id uuid)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $fn$
DECLARE v_company uuid;
BEGIN
  SELECT company_id INTO v_company FROM public.compliance_documents WHERE id = p_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Document not found'; END IF;
  IF NOT (public.is_platform_admin() OR public.is_company_manager(v_company)) THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;
  DELETE FROM public.compliance_documents WHERE id = p_id;
  RETURN jsonb_build_object('deleted', true);
END;
$fn$;

CREATE OR REPLACE FUNCTION public.list_compliance_documents(p_company_id uuid DEFAULT NULL)
 RETURNS TABLE(
   id uuid, company_id uuid, owner_type text, owner_id uuid, owner_name text,
   doc_type text, title text, doc_number text, issued_at date, expires_at date,
   file_path text, notes text, days_to_expiry integer, status text,
   created_at timestamptz, updated_at timestamptz)
 LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public'
AS $fn$
  SELECT d.id, d.company_id, d.owner_type, d.owner_id,
    CASE d.owner_type
      WHEN 'vehicle' THEN fv.vehicle_registration_number
      WHEN 'employee' THEN nullif(trim(coalesce(e.first_name,'') || ' ' || coalesce(e.last_name,'')), '')
      WHEN 'company' THEN oc.company_name
    END AS owner_name,
    d.doc_type, d.title, d.doc_number, d.issued_at, d.expires_at, d.file_path, d.notes,
    CASE WHEN d.expires_at IS NULL THEN NULL ELSE (d.expires_at - current_date) END AS days_to_expiry,
    CASE
      WHEN d.expires_at IS NULL THEN 'no_expiry'
      WHEN d.expires_at < current_date THEN 'expired'
      WHEN d.expires_at <= current_date + 30 THEN 'expiring'
      ELSE 'valid'
    END AS status,
    d.created_at, d.updated_at
  FROM public.compliance_documents d
  LEFT JOIN public.fleet_vehicles fv ON d.owner_type = 'vehicle' AND fv.id = d.owner_id
  LEFT JOIN public.employees e ON d.owner_type = 'employee' AND e.id = d.owner_id
  LEFT JOIN public.companies oc ON d.owner_type = 'company' AND oc.id = d.owner_id
  WHERE (public.is_platform_admin() OR public.is_company_staff(d.company_id))
    AND (p_company_id IS NULL OR d.company_id = p_company_id)
  ORDER BY d.expires_at ASC NULLS LAST, d.updated_at DESC;
$fn$;

-- Daily reminder (mirrors notify_service_due_job): notify the managing company's
-- management about documents expired or expiring within 30 days, throttled to
-- once every 6 days.
CREATE OR REPLACE FUNCTION public.notify_expiring_documents_job()
 RETURNS integer LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $fn$
DECLARE v_d record; v_count integer := 0; v_owner text; v_when text;
BEGIN
  FOR v_d IN
    SELECT d.*,
      CASE d.owner_type
        WHEN 'vehicle' THEN fv.vehicle_registration_number
        WHEN 'employee' THEN nullif(trim(coalesce(e.first_name,'') || ' ' || coalesce(e.last_name,'')), '')
        WHEN 'company' THEN oc.company_name
      END AS owner_name
    FROM public.compliance_documents d
    LEFT JOIN public.fleet_vehicles fv ON d.owner_type = 'vehicle' AND fv.id = d.owner_id
    LEFT JOIN public.employees e ON d.owner_type = 'employee' AND e.id = d.owner_id
    LEFT JOIN public.companies oc ON d.owner_type = 'company' AND oc.id = d.owner_id
    WHERE d.expires_at IS NOT NULL
      AND d.expires_at <= current_date + 30
      AND (d.last_notified_at IS NULL OR d.last_notified_at < now() - interval '6 days')
  LOOP
    v_owner := coalesce(v_d.owner_name, initcap(v_d.owner_type));
    v_when := CASE WHEN v_d.expires_at < current_date
      THEN 'EXPIRED on ' || to_char(v_d.expires_at, 'DD Mon YYYY')
      ELSE 'expires ' || to_char(v_d.expires_at, 'DD Mon YYYY') END;
    PERFORM public.notify_company_management(
      v_d.company_id,
      CASE WHEN v_d.expires_at < current_date THEN 'Document expired' ELSE 'Document expiring soon' END,
      format('%s — %s %s. Renew it and update the record under Compliance.',
        v_owner, coalesce(nullif(v_d.title,''), v_d.doc_type), v_when),
      'general', NULL, NULL,
      CASE WHEN v_d.expires_at < current_date THEN 'high' ELSE 'normal' END,
      jsonb_build_object('compliance_document_id', v_d.id, 'owner_type', v_d.owner_type,
        'owner_id', v_d.owner_id, 'nav_tab', 'Compliance'));
    UPDATE public.compliance_documents SET last_notified_at = now() WHERE id = v_d.id;
    v_count := v_count + 1;
  END LOOP;
  RETURN v_count;
END;
$fn$;

-- Schedule daily (idempotent).
SELECT cron.schedule('notify-expiring-documents', '25 4 * * *',
  'select public.notify_expiring_documents_job()')
WHERE NOT EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'notify-expiring-documents');
