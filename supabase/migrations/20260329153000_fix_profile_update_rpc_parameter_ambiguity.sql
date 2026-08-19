begin;

drop function if exists public.update_my_company_profile(text, text, text, text, text);
drop function if exists public.update_my_employee_profile(text, text, text, text, boolean, text, text, text, text, text, text, text);

create or replace function public.update_my_company_profile(
  company_name_input text default null,
  whatsapp_number_input text default null,
  logo_url_input text default null,
  ceo_first_name_input text default null,
  ceo_last_name_input text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
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
    ceo_last_name = coalesce(nullif(trim(coalesce(ceo_last_name_input, '')), ''), public.companies.ceo_last_name)
  where user_id = auth.uid()
  returning *
  into company_record;

  if company_record.id is null then
    raise exception 'Company profile not found';
  end if;

  return to_jsonb(company_record);
end;
$$;

create or replace function public.update_my_employee_profile(
  first_name_input text default null,
  last_name_input text default null,
  whatsapp_number_input text default null,
  profile_photo_url_input text default null,
  is_south_african_citizen_input boolean default null,
  id_number_input text default null,
  passport_or_workers_permit_input text default null,
  license_document_input text default null,
  id_document_url_input text default null,
  passport_document_url_input text default null,
  work_visa_document_url_input text default null,
  license_document_url_input text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
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
    license_document_url = coalesce(license_document_url_input, public.employees.license_document_url)
  where user_id = auth.uid()
  returning *
  into employee_record;

  if employee_record.id is null then
    raise exception 'Employee profile not found';
  end if;

  return to_jsonb(employee_record);
end;
$$;

grant execute on function public.update_my_company_profile(text, text, text, text, text) to authenticated;
grant execute on function public.update_my_employee_profile(text, text, text, text, boolean, text, text, text, text, text, text, text) to authenticated;

commit;
