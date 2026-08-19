-- Remote DB was missing current_platform_role() (child-admin RLS helpers expect it).

create or replace function public.current_platform_role()
returns text
language sql
stable
security definer
set search_path = public
as $$
  select p.platform_role
  from public.profiles p
  where p.id = auth.uid()
  limit 1;
$$;

grant execute on function public.current_platform_role() to authenticated;
