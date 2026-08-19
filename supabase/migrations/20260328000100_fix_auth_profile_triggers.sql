create or replace function public.handle_auth_user_created()
returns trigger
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  user_metadata jsonb := coalesce(new.raw_user_meta_data, '{}'::jsonb);
begin
  insert into public.profiles (id, email, user_type, display_name, metadata)
  values (
    new.id,
    coalesce(new.email, ''),
    case
      when user_metadata ->> 'user_type' in ('company', 'employee') then user_metadata ->> 'user_type'
      else 'employee'
    end,
    coalesce(
      user_metadata ->> 'display_name',
      split_part(coalesce(new.email, ''), '@', 1)
    ),
    user_metadata
  )
  on conflict (id) do update
  set
    email = excluded.email,
    user_type = excluded.user_type,
    display_name = excluded.display_name,
    metadata = excluded.metadata,
    updated_at = timezone('utc', now());

  return new;
end;
$$;

create or replace function public.handle_auth_user_updated()
returns trigger
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  user_metadata jsonb := coalesce(new.raw_user_meta_data, '{}'::jsonb);
begin
  update public.profiles as p
  set
    email = coalesce(new.email, p.email),
    display_name = coalesce(user_metadata ->> 'display_name', p.display_name),
    metadata = p.metadata || user_metadata,
    updated_at = timezone('utc', now())
  where p.id = new.id;

  return new;
end;
$$;
