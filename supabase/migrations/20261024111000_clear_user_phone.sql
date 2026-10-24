-- Removing a WhatsApp sign-in: clear a user's phone.
--
-- Part of the login-methods work (20261024110000, ADMIN-MOBILE-TODO.md 2.2).
--
-- WHY A FUNCTION: GoTrue's admin API IGNORES `phone: ""`. Measured on
-- production 2026-10-24 against a throwaway user: PUT /admin/users/{id}
-- {"phone": ""} returned 200 and the phone, and the phone identity, were both
-- still there — so phone + password and WhatsApp codes kept working after the
-- console said the number was removed. That is the failure this file exists
-- to prevent.
--
-- Called ONLY by the `admin-update-user` edge function with the service role,
-- after it has checked the caller is a platform admin and that the user keeps
-- an email to sign in with. Not callable by anon or authenticated.
--
-- ROLLBACK
--   drop function public.admin_clear_user_phone(uuid);

begin;

create or replace function public.admin_clear_user_phone(p_user_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_email text;
begin
  select email into v_email from auth.users where id = p_user_id;
  if not found then
    raise exception 'User not found';
  end if;
  -- Never strand an account: it must keep a real email to sign in with.
  if coalesce(v_email, '') = '' or v_email ilike '%@wa.mineralguide.com' then
    raise exception 'This user has no email address to sign in with; '
                    'their WhatsApp number cannot be removed';
  end if;

  update auth.users
     set phone = null,
         phone_confirmed_at = null,
         phone_change = '',
         phone_change_token = '',
         phone_change_sent_at = null,
         updated_at = now()
   where id = p_user_id;

  delete from auth.identities where user_id = p_user_id and provider = 'phone';
end;
$$;

revoke all on function public.admin_clear_user_phone(uuid) from public, anon, authenticated;
grant execute on function public.admin_clear_user_phone(uuid) to service_role;

commit;
