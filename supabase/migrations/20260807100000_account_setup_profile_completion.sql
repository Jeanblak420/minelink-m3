-- Account setup & profile completion engine (2026-08-07). Applied live to
-- project yftazblpmicqtamyiwyb.
--
-- Every account (company owner or employee of any role, all three org types)
-- gets a per-role "complete your account setup" checklist: personal details,
-- identity documents, medicals, licences/certifications (with expiry dates),
-- and a signature. Requirements live in a seeded catalog
-- (profile_requirements); uploaded documents reuse the compliance_documents
-- register so the existing expiry engine keeps working. New self-service RPCs
-- let a user manage their OWN documents (the manager-gated
-- upsert_compliance_document stays untouched for the employer surface).
-- Daily reminders go to BOTH the user and company management:
--   * notify_expiring_documents_job now also notifies the employee who owns
--     an expiring/expired document (management notice unchanged).
--   * new notify_incomplete_profiles_job nags users with missing required
--     items and sends management a per-company digest (6-day throttles).

-- ---------------------------------------------------------------------------
-- 1. employees / companies: new profile fields + reminder throttles
-- ---------------------------------------------------------------------------
ALTER TABLE public.employees
  ADD COLUMN IF NOT EXISTS date_of_birth date,
  ADD COLUMN IF NOT EXISTS residential_address text,
  ADD COLUMN IF NOT EXISTS emergency_contact_name text,
  ADD COLUMN IF NOT EXISTS emergency_contact_phone text,
  ADD COLUMN IF NOT EXISTS contact_email text,
  ADD COLUMN IF NOT EXISTS profile_reminder_at timestamptz;

ALTER TABLE public.companies
  ADD COLUMN IF NOT EXISTS profile_reminder_at timestamptz,
  ADD COLUMN IF NOT EXISTS profile_digest_reminder_at timestamptz;

-- ---------------------------------------------------------------------------
-- 2. Fix the long-standing supervisorForeman gap: the Dart enum, RLS policies
--    and notifications role_scope all know the role, but employees.role,
--    employee_status_history.assigned_role and is_valid_role_for_org rejected
--    it, so it could never actually be assigned.
-- ---------------------------------------------------------------------------
ALTER TABLE public.employees DROP CONSTRAINT IF EXISTS employees_role_check;
ALTER TABLE public.employees ADD CONSTRAINT employees_role_check
  CHECK (role IN ('security','controllerWB','supervisorForeman','admin','management','driver'));

ALTER TABLE public.employee_status_history
  DROP CONSTRAINT IF EXISTS employee_status_history_assigned_role_check;
ALTER TABLE public.employee_status_history
  ADD CONSTRAINT employee_status_history_assigned_role_check
  CHECK (assigned_role IN ('security','controllerWB','supervisorForeman','admin','management','driver'));

CREATE OR REPLACE FUNCTION public.is_valid_role_for_org(target_org_type text, target_role text)
 RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public'
AS $fn$
  select case
    when target_org_type = 'mineSupplier'
      then target_role in ('security', 'controllerWB', 'supervisorForeman', 'admin', 'management')
    when target_org_type = 'buyer' then target_role in ('admin', 'management')
    when target_org_type = 'transporter' then target_role in ('driver', 'admin', 'management')
    else false
  end;
$fn$;

-- ---------------------------------------------------------------------------
-- 3. update_my_employee_profile: add the new personal-detail fields. The
--    signature changes (5 new defaulted params), so drop the old overload
--    first to avoid PostgREST ambiguity. Same keep-when-blank semantics.
-- ---------------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.update_my_employee_profile(
  text, text, text, text, boolean, text, text, text, text, text, text, text);

CREATE OR REPLACE FUNCTION public.update_my_employee_profile(
  first_name_input text DEFAULT NULL, last_name_input text DEFAULT NULL,
  whatsapp_number_input text DEFAULT NULL, profile_photo_url_input text DEFAULT NULL,
  is_south_african_citizen_input boolean DEFAULT NULL, id_number_input text DEFAULT NULL,
  passport_or_workers_permit_input text DEFAULT NULL, license_document_input text DEFAULT NULL,
  id_document_url_input text DEFAULT NULL, passport_document_url_input text DEFAULT NULL,
  work_visa_document_url_input text DEFAULT NULL, license_document_url_input text DEFAULT NULL,
  date_of_birth_input date DEFAULT NULL, residential_address_input text DEFAULT NULL,
  emergency_contact_name_input text DEFAULT NULL, emergency_contact_phone_input text DEFAULT NULL,
  contact_email_input text DEFAULT NULL)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $fn$
declare
  employee_record public.employees;
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;

  update public.employees
  set
    first_name = coalesce(nullif(trim(coalesce(first_name_input, '')), ''), public.employees.first_name),
    last_name = coalesce(nullif(trim(coalesce(last_name_input, '')), ''), public.employees.last_name),
    whatsapp_number = coalesce(nullif(trim(coalesce(whatsapp_number_input, '')), ''), public.employees.whatsapp_number),
    profile_photo_url = coalesce(profile_photo_url_input, public.employees.profile_photo_url),
    is_south_african_citizen = coalesce(is_south_african_citizen_input, public.employees.is_south_african_citizen),
    id_number = coalesce(id_number_input, public.employees.id_number),
    passport_or_workers_permit = coalesce(passport_or_workers_permit_input, public.employees.passport_or_workers_permit),
    license_document = coalesce(license_document_input, public.employees.license_document),
    id_document_url = coalesce(id_document_url_input, public.employees.id_document_url),
    passport_document_url = coalesce(passport_document_url_input, public.employees.passport_document_url),
    work_visa_document_url = coalesce(work_visa_document_url_input, public.employees.work_visa_document_url),
    license_document_url = coalesce(license_document_url_input, public.employees.license_document_url),
    date_of_birth = coalesce(date_of_birth_input, public.employees.date_of_birth),
    residential_address = coalesce(nullif(trim(coalesce(residential_address_input, '')), ''), public.employees.residential_address),
    emergency_contact_name = coalesce(nullif(trim(coalesce(emergency_contact_name_input, '')), ''), public.employees.emergency_contact_name),
    emergency_contact_phone = coalesce(nullif(trim(coalesce(emergency_contact_phone_input, '')), ''), public.employees.emergency_contact_phone),
    contact_email = coalesce(nullif(trim(coalesce(contact_email_input, '')), ''), public.employees.contact_email)
  where user_id = auth.uid()
  returning * into employee_record;

  if employee_record.id is null then
    raise exception 'Employee profile not found';
  end if;

  return to_jsonb(employee_record);
end;
$fn$;
GRANT EXECUTE ON FUNCTION public.update_my_employee_profile(
  text, text, text, text, boolean, text, text, text, text, text, text, text,
  date, text, text, text, text) TO authenticated;

-- ---------------------------------------------------------------------------
-- 4. Requirements catalog. One row per checklist item; org_type/role NULL =
--    applies to all; the most specific row per item_key wins (role beats org
--    beats common), which is how e.g. "medical" flips from recommended to
--    required for mine staff and drivers.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.profile_requirements (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  audience text NOT NULL CHECK (audience IN ('employee','company')),
  org_type text CHECK (org_type IN ('mineSupplier','buyer','transporter')),
  role text CHECK (role IN ('security','controllerWB','supervisorForeman','admin','management','driver')),
  item_kind text NOT NULL CHECK (item_kind IN ('field','document','signature','photo')),
  item_key text NOT NULL,
  label text NOT NULL,
  description text,
  category text NOT NULL CHECK (category IN ('personal','identity','medical','licences','certifications','company')),
  requires_expiry boolean NOT NULL DEFAULT false,
  requires_file boolean NOT NULL DEFAULT false,
  is_required boolean NOT NULL DEFAULT true,
  sort_order integer NOT NULL DEFAULT 100,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
  updated_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
  CONSTRAINT profile_requirements_scope_key UNIQUE NULLS NOT DISTINCT (audience, org_type, role, item_key)
);
COMMENT ON TABLE public.profile_requirements IS
  'Seeded catalog of account-setup checklist items per audience/org type/role; document item_key doubles as compliance_documents.doc_type.';

DROP TRIGGER IF EXISTS set_profile_requirements_updated_at ON public.profile_requirements;
CREATE TRIGGER set_profile_requirements_updated_at
  BEFORE UPDATE ON public.profile_requirements
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

ALTER TABLE public.profile_requirements ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS profile_requirements_select ON public.profile_requirements;
CREATE POLICY profile_requirements_select ON public.profile_requirements
  FOR SELECT TO authenticated USING (true);
GRANT SELECT ON public.profile_requirements TO authenticated;

INSERT INTO public.profile_requirements
  (audience, org_type, role, item_kind, item_key, label, description, category,
   requires_expiry, requires_file, is_required, sort_order)
VALUES
  -- Employees: everyone, every org type
  ('employee', NULL, NULL, 'photo', 'profile_photo', 'Profile photo',
   'A clear head-and-shoulders photo used on your profile and register card.', 'personal', false, false, true, 10),
  ('employee', NULL, NULL, 'field', 'date_of_birth', 'Date of birth', NULL, 'personal', false, false, false, 20),
  ('employee', NULL, NULL, 'field', 'residential_address', 'Residential address', NULL, 'personal', false, false, false, 30),
  ('employee', NULL, NULL, 'field', 'emergency_contact', 'Emergency contact',
   'Name and phone number of your emergency contact / next of kin.', 'personal', false, false, true, 40),
  ('employee', NULL, NULL, 'field', 'contact_email', 'Contact email', NULL, 'personal', false, false, false, 50),
  ('employee', NULL, NULL, 'document', 'id_document', 'ID document',
   'Copy of your South African ID (book or smart card).', 'identity', false, true, true, 60),
  ('employee', NULL, NULL, 'document', 'passport', 'Passport',
   'Copy of your passport with the expiry date.', 'identity', true, true, true, 61),
  ('employee', NULL, NULL, 'document', 'work_visa', 'Work visa / permit',
   'Your work visa or permit with its expiry date.', 'identity', true, true, true, 62),
  ('employee', NULL, NULL, 'signature', 'signature', 'Signature',
   'Drawn once, then placed on waybills and documents you sign in the app.', 'identity', false, false, true, 70),
  ('employee', NULL, NULL, 'document', 'medical', 'Medical certificate of fitness',
   'Occupational medical certificate with its expiry date.', 'medical', true, true, false, 80),
  ('employee', NULL, NULL, 'document', 'other_medical', 'Other medical record',
   'Any additional medical record worth keeping on file (optional).', 'medical', false, true, false, 85),
  -- Medical becomes REQUIRED for all mine/supplier staff and for drivers
  ('employee', 'mineSupplier', NULL, 'document', 'medical', 'Medical certificate of fitness',
   'Occupational medical certificate with its expiry date — required for mine site access.', 'medical', true, true, true, 80),
  ('employee', 'transporter', 'driver', 'document', 'medical', 'Medical certificate of fitness',
   'Occupational medical certificate with its expiry date — required for professional drivers.', 'medical', true, true, true, 80),
  -- Transporter drivers
  ('employee', 'transporter', 'driver', 'document', 'drivers_license', 'Driver''s licence',
   'Your driver''s licence card with its expiry date.', 'licences', true, true, true, 90),
  ('employee', 'transporter', 'driver', 'document', 'prdp', 'Professional driving permit (PrDP)',
   'PrDP with its expiry date — required for goods transport.', 'licences', true, true, true, 91),
  ('employee', 'transporter', 'driver', 'document', 'induction', 'Site induction certificate',
   'Latest site induction certificate, if you have one.', 'certifications', true, true, false, 92),
  -- Mine security
  ('employee', 'mineSupplier', 'security', 'document', 'psira', 'PSIRA registration',
   'Your PSIRA registration with its expiry/renewal date.', 'licences', true, true, true, 90),
  ('employee', 'mineSupplier', 'security', 'document', 'firearm_competency', 'Firearm competency',
   'Firearm competency certificate, if armed duties apply.', 'licences', true, true, false, 91),
  -- Mine load controller
  ('employee', 'mineSupplier', 'controllerWB', 'document', 'weighbridge_competency', 'Weighbridge operator competency',
   'Weighbridge/load-controller competency certificate.', 'certifications', true, true, false, 90),
  -- Mine supervisor/foreman
  ('employee', 'mineSupplier', 'supervisorForeman', 'document', 'supervisor_appointment', 'Supervisor appointment letter',
   'Your written supervisor appointment (e.g. MHSA 2.9.2).', 'certifications', false, true, false, 90),
  ('employee', 'mineSupplier', 'supervisorForeman', 'document', 'first_aid', 'First-aid certificate',
   'First-aid certificate with its expiry date.', 'certifications', true, true, false, 91),
  -- Company owners: all org types
  ('company', NULL, NULL, 'photo', 'company_logo', 'Company logo', NULL, 'company', false, false, false, 10),
  ('company', NULL, NULL, 'field', 'ceo_names', 'CEO / owner name',
   'First and last name of the CEO or owner.', 'company', false, false, true, 20),
  ('company', NULL, NULL, 'field', 'support_email', 'Support contact email', NULL, 'company', false, false, false, 30),
  ('company', NULL, NULL, 'signature', 'signature', 'Authorised signature',
   'Signature used on documents issued by your company.', 'company', false, false, true, 40),
  ('company', NULL, NULL, 'document', 'company_registration', 'Company registration (CIPC)',
   'CIPC registration document.', 'company', false, true, true, 50),
  ('company', NULL, NULL, 'document', 'tax_clearance', 'Tax clearance certificate',
   'SARS tax clearance with its expiry date.', 'company', true, true, true, 51),
  ('company', NULL, NULL, 'document', 'bee_certificate', 'B-BBEE certificate',
   'B-BBEE certificate or affidavit with its expiry date.', 'company', true, true, false, 52),
  -- Org-specific company documents
  ('company', 'mineSupplier', NULL, 'document', 'mining_right', 'Mining right / permit',
   'Mining right or permit with its expiry date.', 'company', true, true, true, 60),
  ('company', 'transporter', NULL, 'document', 'git_insurance', 'Goods-in-transit (GIT) insurance',
   'GIT insurance policy with its renewal date.', 'company', true, true, true, 60),
  ('company', 'transporter', NULL, 'document', 'operating_licence', 'Operating licence',
   'Road transport operating licence with its expiry date.', 'company', true, true, false, 61),
  ('company', 'buyer', NULL, 'document', 'vat_registration', 'VAT registration', NULL, 'company', false, true, false, 60)
ON CONFLICT ON CONSTRAINT profile_requirements_scope_key DO NOTHING;

-- ---------------------------------------------------------------------------
-- 5. Self-service document RPCs. Company owners write company-owned rows,
--    employees write their own employee-owned rows. Manager RPCs untouched.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.upsert_my_compliance_document(
  p_doc_type text, p_id uuid DEFAULT NULL, p_title text DEFAULT NULL,
  p_doc_number text DEFAULT NULL, p_issued_at date DEFAULT NULL,
  p_expires_at date DEFAULT NULL, p_file_path text DEFAULT NULL, p_notes text DEFAULT NULL)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $fn$
DECLARE
  v_emp public.employees; v_co public.companies;
  v_owner_type text; v_owner_id uuid; v_company uuid; v_id uuid;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Not authenticated'; END IF;
  IF coalesce(trim(p_doc_type), '') = '' THEN RAISE EXCEPTION 'Document type is required'; END IF;

  SELECT * INTO v_co FROM public.companies WHERE user_id = auth.uid() LIMIT 1;
  IF FOUND THEN
    v_owner_type := 'company'; v_owner_id := v_co.id; v_company := v_co.id;
  ELSE
    SELECT * INTO v_emp FROM public.employees WHERE user_id = auth.uid() LIMIT 1;
    IF NOT FOUND THEN RAISE EXCEPTION 'No employee or company profile found'; END IF;
    IF v_emp.company_id IS NULL THEN
      RAISE EXCEPTION 'Link to a company before uploading documents';
    END IF;
    v_owner_type := 'employee'; v_owner_id := v_emp.id; v_company := v_emp.company_id;
  END IF;

  IF p_id IS NULL THEN
    v_id := gen_random_uuid();
    INSERT INTO public.compliance_documents(
      id, company_id, owner_type, owner_id, doc_type, title, doc_number,
      issued_at, expires_at, file_path, notes, created_by)
    VALUES (v_id, v_company, v_owner_type, v_owner_id, p_doc_type, p_title,
      p_doc_number, p_issued_at, p_expires_at, p_file_path, p_notes, auth.uid());
  ELSE
    UPDATE public.compliance_documents SET
      doc_type = p_doc_type, title = p_title, doc_number = p_doc_number,
      issued_at = p_issued_at, expires_at = p_expires_at,
      file_path = coalesce(p_file_path, file_path), notes = p_notes,
      -- renewing a doc re-arms the expiry reminder, same as the manager RPC
      last_notified_at = CASE WHEN p_expires_at IS DISTINCT FROM expires_at
        THEN NULL ELSE last_notified_at END
    WHERE id = p_id AND owner_type = v_owner_type
      AND owner_id = v_owner_id AND company_id = v_company;
    IF NOT FOUND THEN RAISE EXCEPTION 'Document not found'; END IF;
    v_id := p_id;
  END IF;
  RETURN jsonb_build_object('id', v_id);
END;
$fn$;
GRANT EXECUTE ON FUNCTION public.upsert_my_compliance_document(
  text, uuid, text, text, date, date, text, text) TO authenticated;

CREATE OR REPLACE FUNCTION public.delete_my_compliance_document(p_id uuid)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $fn$
DECLARE v_d public.compliance_documents; v_emp public.employees; v_co public.companies;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Not authenticated'; END IF;
  SELECT * INTO v_d FROM public.compliance_documents WHERE id = p_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Document not found'; END IF;
  IF v_d.owner_type = 'company' THEN
    SELECT * INTO v_co FROM public.companies WHERE id = v_d.owner_id AND user_id = auth.uid();
    IF NOT FOUND THEN RAISE EXCEPTION 'Not authorized'; END IF;
  ELSIF v_d.owner_type = 'employee' THEN
    SELECT * INTO v_emp FROM public.employees WHERE id = v_d.owner_id AND user_id = auth.uid();
    IF NOT FOUND THEN RAISE EXCEPTION 'Not authorized'; END IF;
  ELSE
    RAISE EXCEPTION 'Not authorized';
  END IF;
  DELETE FROM public.compliance_documents WHERE id = p_id;
  RETURN jsonb_build_object('deleted', true);
END;
$fn$;
GRANT EXECUTE ON FUNCTION public.delete_my_compliance_document(uuid) TO authenticated;

-- ---------------------------------------------------------------------------
-- 6. Setup-state resolver. _profile_setup_payload is the internal engine
--    (also used by the cron job); get_profile_setup is the guarded public
--    wrapper. Status per item:
--      complete | expiring (≤30d, still counts complete but flagged)
--      missing | needs_expiry (doc there but no expiry captured) | expired
--    completion_percent counts REQUIRED items only.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public._profile_setup_payload(p_audience text, p_subject_id uuid)
 RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public'
AS $fn$
DECLARE
  v_emp public.employees; v_co public.companies; v_doc public.compliance_documents;
  v_r record;
  v_org text; v_role text; v_user uuid; v_company_id uuid; v_sig text; v_legacy text;
  v_status text; v_source text; v_expires date; v_days int; v_doc_id uuid; v_file boolean;
  v_items jsonb := '[]'::jsonb; v_missing jsonb := '[]'::jsonb;
  v_total int := 0; v_complete int := 0; v_req_total int := 0; v_req_complete int := 0;
  v_missing_count int := 0; v_expiring int := 0; v_expired int := 0;
BEGIN
  IF p_audience = 'employee' THEN
    SELECT * INTO v_emp FROM public.employees WHERE id = p_subject_id;
    IF NOT FOUND THEN RAISE EXCEPTION 'Employee not found'; END IF;
    v_user := v_emp.user_id; v_company_id := v_emp.company_id; v_role := v_emp.role;
    SELECT c.org_type INTO v_org FROM public.companies c WHERE c.id = v_emp.company_id;
  ELSIF p_audience = 'company' THEN
    SELECT * INTO v_co FROM public.companies WHERE id = p_subject_id;
    IF NOT FOUND THEN RAISE EXCEPTION 'Company not found'; END IF;
    v_user := v_co.user_id; v_company_id := v_co.id; v_org := v_co.org_type; v_role := NULL;
  ELSE
    RAISE EXCEPTION 'Invalid audience';
  END IF;

  SELECT p.signature_url INTO v_sig FROM public.profiles p WHERE p.id = v_user;

  FOR v_r IN
    SELECT DISTINCT ON (r.item_key) r.*
    FROM public.profile_requirements r
    WHERE r.is_active AND r.audience = p_audience
      AND (r.org_type IS NULL OR r.org_type = v_org)
      AND (p_audience = 'company' OR r.role IS NULL OR r.role = v_role)
    ORDER BY r.item_key, (r.role IS NOT NULL) DESC, (r.org_type IS NOT NULL) DESC, r.sort_order
  LOOP
    -- Citizenship branching: SA citizens supply an ID; non-citizens a
    -- passport + work visa.
    IF p_audience = 'employee' THEN
      IF v_emp.is_south_african_citizen AND v_r.item_key IN ('passport','work_visa') THEN CONTINUE; END IF;
      IF NOT v_emp.is_south_african_citizen AND v_r.item_key = 'id_document' THEN CONTINUE; END IF;
    END IF;

    v_status := NULL; v_source := NULL; v_expires := NULL; v_days := NULL;
    v_doc_id := NULL; v_file := false; v_doc := NULL; v_legacy := NULL;

    IF v_r.item_kind = 'signature' THEN
      v_source := 'signature';
      v_file := coalesce(trim(v_sig), '') <> '';
      v_status := CASE WHEN v_file THEN 'complete' ELSE 'missing' END;
    ELSIF v_r.item_kind = 'photo' THEN
      v_source := 'field';
      v_legacy := CASE WHEN p_audience = 'employee' THEN v_emp.profile_photo_url ELSE v_co.logo_url END;
      v_file := coalesce(trim(v_legacy), '') <> '';
      v_status := CASE WHEN v_file THEN 'complete' ELSE 'missing' END;
    ELSIF v_r.item_kind = 'field' THEN
      v_source := 'field';
      v_status := CASE
        WHEN p_audience = 'employee' AND v_r.item_key = 'date_of_birth' THEN
          CASE WHEN v_emp.date_of_birth IS NOT NULL THEN 'complete' ELSE 'missing' END
        WHEN p_audience = 'employee' AND v_r.item_key = 'residential_address' THEN
          CASE WHEN coalesce(trim(v_emp.residential_address), '') <> '' THEN 'complete' ELSE 'missing' END
        WHEN p_audience = 'employee' AND v_r.item_key = 'emergency_contact' THEN
          CASE WHEN coalesce(trim(v_emp.emergency_contact_name), '') <> ''
                AND coalesce(trim(v_emp.emergency_contact_phone), '') <> ''
            THEN 'complete' ELSE 'missing' END
        WHEN p_audience = 'employee' AND v_r.item_key = 'contact_email' THEN
          CASE WHEN coalesce(trim(v_emp.contact_email), '') <> '' THEN 'complete' ELSE 'missing' END
        WHEN p_audience = 'company' AND v_r.item_key = 'ceo_names' THEN
          CASE WHEN coalesce(trim(v_co.ceo_first_name), '') <> ''
                AND coalesce(trim(v_co.ceo_last_name), '') <> ''
            THEN 'complete' ELSE 'missing' END
        WHEN p_audience = 'company' AND v_r.item_key = 'support_email' THEN
          CASE WHEN coalesce(trim(v_co.support_contact_email), '') <> '' THEN 'complete' ELSE 'missing' END
        ELSE 'complete'  -- unknown field keys fail safe rather than nag wrongly
      END;
    ELSE  -- document
      v_source := 'compliance_doc';
      SELECT d.* INTO v_doc FROM public.compliance_documents d
      WHERE d.owner_type = CASE WHEN p_audience = 'employee' THEN 'employee' ELSE 'company' END
        AND d.owner_id = p_subject_id AND d.doc_type = v_r.item_key
      ORDER BY (d.expires_at IS NOT NULL) DESC, d.expires_at DESC, d.updated_at DESC
      LIMIT 1;

      IF p_audience = 'employee' THEN
        v_legacy := nullif(trim(coalesce(CASE v_r.item_key
          WHEN 'id_document' THEN v_emp.id_document_url
          WHEN 'passport' THEN v_emp.passport_document_url
          WHEN 'work_visa' THEN v_emp.work_visa_document_url
          WHEN 'drivers_license' THEN v_emp.license_document_url
          ELSE NULL END, '')), '');
      END IF;

      IF v_doc.id IS NOT NULL THEN
        v_doc_id := v_doc.id; v_expires := v_doc.expires_at;
        v_file := coalesce(nullif(trim(coalesce(v_doc.file_path, '')), ''), v_legacy) IS NOT NULL;
        IF v_expires IS NOT NULL THEN v_days := v_expires - current_date; END IF;
        IF v_r.requires_file AND NOT v_file THEN v_status := 'missing';
        ELSIF v_r.requires_expiry AND v_expires IS NULL THEN v_status := 'needs_expiry';
        ELSIF v_expires IS NOT NULL AND v_expires < current_date THEN v_status := 'expired';
        ELSIF v_expires IS NOT NULL AND v_expires <= current_date + 30 THEN v_status := 'expiring';
        ELSE v_status := 'complete';
        END IF;
      ELSIF v_legacy IS NOT NULL THEN
        -- Legacy employees.*_url upload with no expiry record behind it.
        v_source := 'legacy_url'; v_file := true;
        v_status := CASE WHEN v_r.requires_expiry THEN 'needs_expiry' ELSE 'complete' END;
      ELSE
        v_status := 'missing';
      END IF;
    END IF;

    v_total := v_total + 1;
    IF v_status IN ('complete','expiring') THEN v_complete := v_complete + 1; END IF;
    IF v_status = 'expiring' THEN v_expiring := v_expiring + 1; END IF;
    IF v_status = 'expired' THEN v_expired := v_expired + 1; END IF;
    IF v_r.is_required THEN
      v_req_total := v_req_total + 1;
      IF v_status IN ('complete','expiring') THEN
        v_req_complete := v_req_complete + 1;
      ELSE
        v_missing := v_missing || to_jsonb(v_r.label);
        v_missing_count := v_missing_count + 1;
      END IF;
    END IF;

    v_items := v_items || jsonb_build_object(
      'item_key', v_r.item_key, 'label', v_r.label, 'description', v_r.description,
      'category', v_r.category, 'item_kind', v_r.item_kind,
      'is_required', v_r.is_required, 'requires_expiry', v_r.requires_expiry,
      'requires_file', v_r.requires_file, 'sort_order', v_r.sort_order,
      'status', v_status, 'source', v_source, 'document_id', v_doc_id,
      'file_present', v_file, 'expires_at', v_expires, 'days_to_expiry', v_days);
  END LOOP;

  RETURN jsonb_build_object(
    'audience', p_audience, 'subject_id', p_subject_id, 'org_type', v_org,
    'role', v_role, 'company_id', v_company_id,
    'is_sa_citizen', CASE WHEN p_audience = 'employee' THEN v_emp.is_south_african_citizen END,
    'items', v_items,
    'summary', jsonb_build_object(
      'total_items', v_total, 'complete_items', v_complete,
      'required_total', v_req_total, 'required_complete', v_req_complete,
      'completion_percent',
        CASE WHEN v_req_total = 0 THEN 100
             ELSE round(100.0 * v_req_complete / v_req_total)::int END,
      'missing_required', v_missing, 'missing_count', v_missing_count,
      'expiring_count', v_expiring, 'expired_count', v_expired));
END;
$fn$;
REVOKE ALL ON FUNCTION public._profile_setup_payload(text, uuid) FROM public, anon, authenticated;

CREATE OR REPLACE FUNCTION public.get_profile_setup(p_employee_id uuid DEFAULT NULL)
 RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public'
AS $fn$
DECLARE v_emp public.employees; v_co public.companies;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Not authenticated'; END IF;

  IF p_employee_id IS NOT NULL THEN
    SELECT * INTO v_emp FROM public.employees WHERE id = p_employee_id;
    IF NOT FOUND THEN RAISE EXCEPTION 'Employee not found'; END IF;
    IF NOT (v_emp.user_id = auth.uid() OR public.is_platform_admin()
        OR (v_emp.company_id IS NOT NULL AND public.is_company_manager(v_emp.company_id))) THEN
      RAISE EXCEPTION 'Not authorized';
    END IF;
    RETURN public._profile_setup_payload('employee', v_emp.id);
  END IF;

  SELECT * INTO v_co FROM public.companies WHERE user_id = auth.uid() LIMIT 1;
  IF FOUND THEN RETURN public._profile_setup_payload('company', v_co.id); END IF;
  SELECT * INTO v_emp FROM public.employees WHERE user_id = auth.uid() LIMIT 1;
  IF FOUND THEN RETURN public._profile_setup_payload('employee', v_emp.id); END IF;

  -- Platform admins and other accounts with no employee/company profile:
  -- nothing to complete.
  RETURN jsonb_build_object('audience', NULL, 'items', '[]'::jsonb,
    'summary', jsonb_build_object('total_items', 0, 'complete_items', 0,
      'required_total', 0, 'required_complete', 0, 'completion_percent', 100,
      'missing_required', '[]'::jsonb, 'missing_count', 0,
      'expiring_count', 0, 'expired_count', 0));
END;
$fn$;
GRANT EXECUTE ON FUNCTION public.get_profile_setup(uuid) TO authenticated;

-- ---------------------------------------------------------------------------
-- 7. Expiry reminders now reach the document's owner too (management notice
--    unchanged). Same 6-day last_notified_at throttle covers both.
-- ---------------------------------------------------------------------------
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

-- ---------------------------------------------------------------------------
-- 8. Daily incomplete-profile reminders: personal nag (employees + company
--    owners, 6-day throttle) and a per-company management digest.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.notify_incomplete_profiles_job()
 RETURNS integer LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $fn$
DECLARE
  v_e record; v_c record; v_p jsonb; v_labels text;
  v_missing int; v_expired int; v_pct int; v_incomplete int; v_count integer := 0;
BEGIN
  -- Personal reminders: employees (linked or not; dismissed excluded)
  FOR v_e IN
    SELECT e.*, c.org_type AS c_org
    FROM public.employees e
    LEFT JOIN public.companies c ON c.id = e.company_id
    WHERE e.user_id IS NOT NULL
      AND e.is_dismissed = false
      AND e.status IN ('active','pending_company','pending_role')
      AND (e.profile_reminder_at IS NULL OR e.profile_reminder_at < now() - interval '6 days')
  LOOP
    v_p := public._profile_setup_payload('employee', v_e.id);
    v_missing := coalesce((v_p->'summary'->>'missing_count')::int, 0);
    v_expired := coalesce((v_p->'summary'->>'expired_count')::int, 0);
    v_pct := coalesce((v_p->'summary'->>'completion_percent')::int, 100);
    IF v_missing > 0 THEN
      SELECT string_agg(x, ', ') INTO v_labels
      FROM (SELECT jsonb_array_elements_text(v_p->'summary'->'missing_required') AS x LIMIT 6) s;
      IF v_missing > 6 THEN v_labels := v_labels || ', …'; END IF;
      PERFORM public.create_notification_internal(
        v_e.user_id, v_e.company_id, v_e.id,
        'Complete your account setup',
        format('Your profile is %s%% complete — still required: %s. Open Account setup to finish.',
          v_pct, v_labels),
        'general', NULL, NULL, v_e.role, v_e.c_org,
        CASE WHEN v_expired > 0 THEN 'high' ELSE 'normal' END,
        jsonb_build_object('kind', 'profile_setup', 'nav_route', '/account-setup'));
      UPDATE public.employees SET profile_reminder_at = now() WHERE id = v_e.id;
      v_count := v_count + 1;
    END IF;
  END LOOP;

  -- Personal reminders: company owners
  FOR v_c IN
    SELECT c.* FROM public.companies c
    WHERE c.user_id IS NOT NULL
      AND (c.profile_reminder_at IS NULL OR c.profile_reminder_at < now() - interval '6 days')
  LOOP
    v_p := public._profile_setup_payload('company', v_c.id);
    v_missing := coalesce((v_p->'summary'->>'missing_count')::int, 0);
    v_expired := coalesce((v_p->'summary'->>'expired_count')::int, 0);
    v_pct := coalesce((v_p->'summary'->>'completion_percent')::int, 100);
    IF v_missing > 0 THEN
      SELECT string_agg(x, ', ') INTO v_labels
      FROM (SELECT jsonb_array_elements_text(v_p->'summary'->'missing_required') AS x LIMIT 6) s;
      IF v_missing > 6 THEN v_labels := v_labels || ', …'; END IF;
      PERFORM public.create_notification_internal(
        v_c.user_id, v_c.id, NULL,
        'Complete your company account setup',
        format('Your company profile is %s%% complete — still required: %s. Open Account setup to finish.',
          v_pct, v_labels),
        'general', NULL, NULL, NULL, v_c.org_type,
        CASE WHEN v_expired > 0 THEN 'high' ELSE 'normal' END,
        jsonb_build_object('kind', 'profile_setup', 'nav_route', '/account-setup'));
      UPDATE public.companies SET profile_reminder_at = now() WHERE id = v_c.id;
      v_count := v_count + 1;
    END IF;
  END LOOP;

  -- Management digest, one per company
  FOR v_c IN
    SELECT c.* FROM public.companies c
    WHERE (c.profile_digest_reminder_at IS NULL OR c.profile_digest_reminder_at < now() - interval '6 days')
  LOOP
    v_incomplete := 0;
    FOR v_e IN
      SELECT e.* FROM public.employees e
      WHERE e.company_id = v_c.id AND e.is_dismissed = false AND e.status = 'active'
    LOOP
      v_p := public._profile_setup_payload('employee', v_e.id);
      IF coalesce((v_p->'summary'->>'missing_count')::int, 0) > 0
         OR coalesce((v_p->'summary'->>'expired_count')::int, 0) > 0 THEN
        v_incomplete := v_incomplete + 1;
      END IF;
    END LOOP;
    IF v_incomplete > 0 THEN
      PERFORM public.notify_company_management(
        v_c.id, 'Team account setup incomplete',
        format('%s team member(s) still have missing or expired profile items. Open an employee''s profile to see what is outstanding.',
          v_incomplete),
        'general', NULL, NULL, 'normal',
        jsonb_build_object('kind', 'profile_setup_digest'));
      UPDATE public.companies SET profile_digest_reminder_at = now() WHERE id = v_c.id;
      v_count := v_count + 1;
    END IF;
  END LOOP;

  RETURN v_count;
END;
$fn$;
REVOKE ALL ON FUNCTION public.notify_incomplete_profiles_job() FROM public, anon, authenticated;

-- Schedule daily at 04:40 (after the expiring-documents run), idempotent and
-- safe in environments without pg_cron.
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'notify-incomplete-profiles') THEN
    PERFORM cron.schedule('notify-incomplete-profiles', '40 4 * * *',
      'select public.notify_incomplete_profiles_job()');
  END IF;
EXCEPTION WHEN undefined_table OR insufficient_privilege OR invalid_schema_name THEN NULL;
END $$;
