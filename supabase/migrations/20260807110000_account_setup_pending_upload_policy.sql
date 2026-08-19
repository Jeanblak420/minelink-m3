-- Account setup follow-up (2026-08-07): pending employees can upload their own
-- documents. Applied live to project yftazblpmicqtamyiwyb.
--
-- The account-setup flow (and the daily incomplete-profile reminder) includes
-- employees whose status is still pending_role / pending_company, and
-- upsert_my_compliance_document accepts them — but the compliance_docs storage
-- policies authorize via is_company_staff(), which requires status = 'active'.
-- So a pending employee was told to complete their setup yet storage RLS
-- denied the file upload. Add OR'd policies letting any non-dismissed employee
-- linked to the company read/write under that company's folder.

DROP POLICY IF EXISTS compliance_docs_insert_own_employee ON storage.objects;
CREATE POLICY compliance_docs_insert_own_employee ON storage.objects FOR INSERT TO authenticated
  WITH CHECK ((bucket_id = 'compliance_docs') AND (EXISTS (
    SELECT 1 FROM public.employees e
    WHERE e.user_id = auth.uid()
      AND e.is_dismissed = false
      AND (e.company_id)::text = (storage.foldername(objects.name))[1])));

DROP POLICY IF EXISTS compliance_docs_select_own_employee ON storage.objects;
CREATE POLICY compliance_docs_select_own_employee ON storage.objects FOR SELECT TO authenticated
  USING ((bucket_id = 'compliance_docs') AND (EXISTS (
    SELECT 1 FROM public.employees e
    WHERE e.user_id = auth.uid()
      AND e.is_dismissed = false
      AND (e.company_id)::text = (storage.foldername(objects.name))[1])));
