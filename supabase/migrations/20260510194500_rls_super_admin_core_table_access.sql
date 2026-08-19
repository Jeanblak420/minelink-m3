begin;

-- Cross-org reads/updates for platform super admins (live uses is_super_admin / is_main_super_admin).

drop policy if exists employees_select_super_admin on public.employees;
create policy employees_select_super_admin on public.employees
  for select
  to authenticated
  using (public.is_super_admin());

drop policy if exists employees_update_super_admin on public.employees;
create policy employees_update_super_admin on public.employees
  for update
  to authenticated
  using (public.is_super_admin())
  with check (public.is_super_admin());

drop policy if exists companies_update_super_admin on public.companies;
create policy companies_update_super_admin on public.companies
  for update
  to authenticated
  using (public.is_super_admin())
  with check (public.is_super_admin());

drop policy if exists profiles_select_super_admin on public.profiles;
create policy profiles_select_super_admin on public.profiles
  for select
  to authenticated
  using (public.is_super_admin());

drop policy if exists profiles_update_main_super_admin on public.profiles;
create policy profiles_update_main_super_admin on public.profiles
  for update
  to authenticated
  using (public.is_main_super_admin())
  with check (public.is_main_super_admin());

commit;
