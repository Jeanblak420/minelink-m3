begin;

create or replace function public.employee_company_id(target_employee_id uuid)
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select e.company_id
  from public.employees e
  where e.id = target_employee_id
  limit 1;
$$;

create or replace function public.can_access_employee_profile_photo(target_employee_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select
    public.is_employee_self(target_employee_id)
    or public.is_company_staff(public.employee_company_id(target_employee_id));
$$;

create or replace function public.can_access_employee_document(target_employee_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select
    public.is_employee_self(target_employee_id)
    or public.is_company_manager(public.employee_company_id(target_employee_id));
$$;

update storage.buckets
set public = case
  when id = 'company_assets' then true
  when id in ('employee_assets', 'chat_files') then false
  else public
end
where id in ('company_assets', 'employee_assets', 'chat_files');

drop policy if exists employee_assets_select_employee_scoped on storage.objects;
drop policy if exists chat_files_select_room_participants on storage.objects;

create policy employee_assets_select_employee_scoped
on storage.objects
for select
to authenticated
using (
  bucket_id = 'employee_assets'
  and (
    (
      (storage.foldername(name))[1] = 'profile_photos'
      and public.can_access_employee_profile_photo(((storage.foldername(name))[2])::uuid)
    )
    or (
      (storage.foldername(name))[1] in ('id_documents', 'passport_documents', 'work_visa_documents', 'license_documents')
      and public.can_access_employee_document(((storage.foldername(name))[2])::uuid)
    )
  )
);

create policy chat_files_select_room_participants
on storage.objects
for select
to authenticated
using (
  bucket_id = 'chat_files'
  and public.can_access_chat_room(((storage.foldername(name))[1])::uuid)
);

commit;
