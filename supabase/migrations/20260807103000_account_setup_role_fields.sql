-- Account setup: role/org-natural profile fields (2026-08-07, follow-up to
-- 20260807100000). Applied live to project yftazblpmicqtamyiwyb.
--
-- Adds the profile fields that naturally belong to a person or company given
-- their role and org type, wires them into the self-update RPCs and the
-- setup-completion engine, and seeds catalog rows for them:
--   employees: employment_start_date (drives tenure), plus per-role fields —
--     drivers: license_codes (e.g. "C1, EC"); mine security: psira_grade.
--   companies: registration_number (required), vat_number, physical_address,
--     and support_contact_email becomes self-editable.

-- ---------------------------------------------------------------------------
-- 1. Columns
-- ---------------------------------------------------------------------------
ALTER TABLE public.employees
  ADD COLUMN IF NOT EXISTS employment_start_date date,
  ADD COLUMN IF NOT EXISTS license_codes text,
  ADD COLUMN IF NOT EXISTS psira_grade text;

ALTER TABLE public.companies
  ADD COLUMN IF NOT EXISTS registration_number text,
  ADD COLUMN IF NOT EXISTS vat_number text,
  ADD COLUMN IF NOT EXISTS physical_address text;

-- ---------------------------------------------------------------------------
-- 2. update_my_employee_profile: 3 new params (drop the 17-param overload)
-- ---------------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.update_my_employee_profile(
  text, text, text, text, boolean, text, text, text, text, text, text, text,
  date, text, text, text, text);

CREATE OR REPLACE FUNCTION public.update_my_employee_profile(
  first_name_input text DEFAULT NULL, last_name_input text DEFAULT NULL,
  whatsapp_number_input text DEFAULT NULL, profile_photo_url_input text DEFAULT NULL,
  is_south_african_citizen_input boolean DEFAULT NULL, id_number_input text DEFAULT NULL,
  passport_or_workers_permit_input text DEFAULT NULL, license_document_input text DEFAULT NULL,
  id_document_url_input text DEFAULT NULL, passport_document_url_input text DEFAULT NULL,
  work_visa_document_url_input text DEFAULT NULL, license_document_url_input text DEFAULT NULL,
  date_of_birth_input date DEFAULT NULL, residential_address_input text DEFAULT NULL,
  emergency_contact_name_input text DEFAULT NULL, emergency_contact_phone_input text DEFAULT NULL,
  contact_email_input text DEFAULT NULL, employment_start_date_input date DEFAULT NULL,
  license_codes_input text DEFAULT NULL, psira_grade_input text DEFAULT NULL)
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
    contact_email = coalesce(nullif(trim(coalesce(contact_email_input, '')), ''), public.employees.contact_email),
    employment_start_date = coalesce(employment_start_date_input, public.employees.employment_start_date),
    license_codes = coalesce(nullif(trim(coalesce(license_codes_input, '')), ''), public.employees.license_codes),
    psira_grade = coalesce(nullif(trim(coalesce(psira_grade_input, '')), ''), public.employees.psira_grade)
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
  date, text, text, text, text, date, text, text) TO authenticated;

-- ---------------------------------------------------------------------------
-- 3. update_my_company_profile: support email + registration/VAT/address
-- ---------------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.update_my_company_profile(text, text, text, text, text);

CREATE OR REPLACE FUNCTION public.update_my_company_profile(
  company_name_input text DEFAULT NULL, whatsapp_number_input text DEFAULT NULL,
  logo_url_input text DEFAULT NULL, ceo_first_name_input text DEFAULT NULL,
  ceo_last_name_input text DEFAULT NULL, support_contact_email_input text DEFAULT NULL,
  registration_number_input text DEFAULT NULL, vat_number_input text DEFAULT NULL,
  physical_address_input text DEFAULT NULL)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $fn$
declare
  company_record public.companies;
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;

  update public.companies
  set
    company_name = coalesce(nullif(trim(coalesce(company_name_input, '')), ''), public.companies.company_name),
    whatsapp_number = coalesce(nullif(trim(coalesce(whatsapp_number_input, '')), ''), public.companies.whatsapp_number),
    logo_url = coalesce(logo_url_input, public.companies.logo_url),
    ceo_first_name = coalesce(nullif(trim(coalesce(ceo_first_name_input, '')), ''), public.companies.ceo_first_name),
    ceo_last_name = coalesce(nullif(trim(coalesce(ceo_last_name_input, '')), ''), public.companies.ceo_last_name),
    support_contact_email = coalesce(nullif(trim(coalesce(support_contact_email_input, '')), ''), public.companies.support_contact_email),
    registration_number = coalesce(nullif(trim(coalesce(registration_number_input, '')), ''), public.companies.registration_number),
    vat_number = coalesce(nullif(trim(coalesce(vat_number_input, '')), ''), public.companies.vat_number),
    physical_address = coalesce(nullif(trim(coalesce(physical_address_input, '')), ''), public.companies.physical_address)
  where user_id = auth.uid()
  returning * into company_record;

  if company_record.id is null then
    raise exception 'Company profile not found';
  end if;

  return to_jsonb(company_record);
end;
$fn$;
GRANT EXECUTE ON FUNCTION public.update_my_company_profile(
  text, text, text, text, text, text, text, text, text) TO authenticated;

-- ---------------------------------------------------------------------------
-- 4. Catalog rows for the new fields
-- ---------------------------------------------------------------------------
INSERT INTO public.profile_requirements
  (audience, org_type, role, item_kind, item_key, label, description, category,
   requires_expiry, requires_file, is_required, sort_order)
VALUES
  ('employee', NULL, NULL, 'field', 'employment_start_date', 'Employment start date',
   'When you joined the company — drives the tenure shown on your profile.', 'personal', false, false, false, 25),
  ('employee', 'transporter', 'driver', 'field', 'license_codes', 'Licence codes',
   'Vehicle classes you are licensed to drive (e.g. C1, EC).', 'licences', false, false, false, 93),
  ('employee', 'mineSupplier', 'security', 'field', 'psira_grade', 'PSIRA grade',
   'Your PSIRA grade (A–E).', 'licences', false, false, false, 93),
  ('company', NULL, NULL, 'field', 'registration_number', 'Company registration number',
   'CIPC registration number (e.g. 2015/123456/07).', 'company', false, false, true, 21),
  ('company', NULL, NULL, 'field', 'vat_number', 'VAT number', NULL, 'company', false, false, false, 22),
  ('company', NULL, NULL, 'field', 'physical_address', 'Business address', NULL, 'company', false, false, false, 23)
ON CONFLICT ON CONSTRAINT profile_requirements_scope_key DO NOTHING;

-- ---------------------------------------------------------------------------
-- 5. Completion engine learns the new field keys
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
        WHEN p_audience = 'employee' AND v_r.item_key = 'employment_start_date' THEN
          CASE WHEN v_emp.employment_start_date IS NOT NULL THEN 'complete' ELSE 'missing' END
        WHEN p_audience = 'employee' AND v_r.item_key = 'residential_address' THEN
          CASE WHEN coalesce(trim(v_emp.residential_address), '') <> '' THEN 'complete' ELSE 'missing' END
        WHEN p_audience = 'employee' AND v_r.item_key = 'emergency_contact' THEN
          CASE WHEN coalesce(trim(v_emp.emergency_contact_name), '') <> ''
                AND coalesce(trim(v_emp.emergency_contact_phone), '') <> ''
            THEN 'complete' ELSE 'missing' END
        WHEN p_audience = 'employee' AND v_r.item_key = 'contact_email' THEN
          CASE WHEN coalesce(trim(v_emp.contact_email), '') <> '' THEN 'complete' ELSE 'missing' END
        WHEN p_audience = 'employee' AND v_r.item_key = 'license_codes' THEN
          CASE WHEN coalesce(trim(v_emp.license_codes), '') <> '' THEN 'complete' ELSE 'missing' END
        WHEN p_audience = 'employee' AND v_r.item_key = 'psira_grade' THEN
          CASE WHEN coalesce(trim(v_emp.psira_grade), '') <> '' THEN 'complete' ELSE 'missing' END
        WHEN p_audience = 'company' AND v_r.item_key = 'ceo_names' THEN
          CASE WHEN coalesce(trim(v_co.ceo_first_name), '') <> ''
                AND coalesce(trim(v_co.ceo_last_name), '') <> ''
            THEN 'complete' ELSE 'missing' END
        WHEN p_audience = 'company' AND v_r.item_key = 'support_email' THEN
          CASE WHEN coalesce(trim(v_co.support_contact_email), '') <> '' THEN 'complete' ELSE 'missing' END
        WHEN p_audience = 'company' AND v_r.item_key = 'registration_number' THEN
          CASE WHEN coalesce(trim(v_co.registration_number), '') <> '' THEN 'complete' ELSE 'missing' END
        WHEN p_audience = 'company' AND v_r.item_key = 'vat_number' THEN
          CASE WHEN coalesce(trim(v_co.vat_number), '') <> '' THEN 'complete' ELSE 'missing' END
        WHEN p_audience = 'company' AND v_r.item_key = 'physical_address' THEN
          CASE WHEN coalesce(trim(v_co.physical_address), '') <> '' THEN 'complete' ELSE 'missing' END
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
