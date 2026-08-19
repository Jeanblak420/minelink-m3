create or replace function public.check_email_registered(target_email text)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.profiles
    where lower(email) = lower(trim(target_email))
  );
$$;

grant execute on function public.check_email_registered(text) to anon, authenticated;
