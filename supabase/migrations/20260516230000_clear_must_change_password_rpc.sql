-- Lets a signed-in user clear must_change_password after auth.updateUser succeeds,
-- even if a direct profiles UPDATE is blocked by RLS drift on some deployments.

begin;

create or replace function public.clear_must_change_password_for_self()
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;

  update public.profiles
  set
    must_change_password = false,
    updated_at = timezone('utc', now())
  where id = auth.uid();
end;
$$;

grant execute on function public.clear_must_change_password_for_self() to authenticated;

commit;
