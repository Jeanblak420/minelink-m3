-- Login methods: email and/or WhatsApp per user, one of them primary.
--
-- Applied from the M3 project on 2026-10-24 at Jean's request
-- (ADMIN-MOBILE-TODO.md 2.2: "the super admin can change, edit and or add any
-- and all user's default login methods ... set one up as secondary and one up
-- as primary"), under the explicit OK he gave for this work's database changes.
--
-- HOW SIGN-IN WORKS (unchanged by this file, recorded because it decides it)
--
--   One auth user, one password. Two ways to name the account:
--     * email + password      — when auth.users.email is a real address;
--     * WhatsApp number + password, or a WhatsApp code
--                             — when auth.users.phone is set (Supabase phone
--                               auth; password grant with `phone` works, proven
--                               on production 2026-10-24).
--   An account with no real email carries a placeholder
--   `wa-<digits>@wa.mineralguide.com` (auth requires an email); it is never a
--   way to sign in by itself, only the legacy fallback for number + password.
--
-- WHAT THIS ADDS
--
--   * profiles.login_primary ('email' | 'whatsapp') — which method is the
--     person's primary one. NULL means "not chosen": read as 'whatsapp' for a
--     placeholder-email account, 'email' otherwise (admin_login_methods does
--     the reading, so there is one rule).
--   * admin_login_methods(user) — a super admin reads what a user can sign in
--     with, straight from auth.users (the app cannot read auth.users). The
--     placeholder email is reported as "no email", never as an address.
--
--   Changing methods is done by the `admin-update-user` edge function (v4),
--   which holds the service role and refuses any change that would leave a
--   user with no way to sign in.
--
-- ROLLBACK
--   drop function public.admin_login_methods(uuid);
--   alter table public.profiles drop column login_primary;

begin;

alter table public.profiles
  add column if not exists login_primary text
  check (login_primary is null or login_primary in ('email', 'whatsapp'));

comment on column public.profiles.login_primary is
  'Primary sign-in method: email or whatsapp. NULL = not chosen (read as '
  'whatsapp for a placeholder-email account, email otherwise). Set by the '
  'admin-update-user edge function.';

create or replace function public.admin_login_methods(p_user_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  u record;
  v_placeholder boolean;
  v_email text;
  v_phone text;
  v_primary text;
begin
  perform public.require_platform_admin();

  select au.email, au.phone into u from auth.users au where au.id = p_user_id;
  if not found then
    raise exception 'User not found';
  end if;

  v_placeholder := coalesce(u.email, '') ilike '%@wa.mineralguide.com';
  v_email := case when v_placeholder or coalesce(u.email, '') = '' then null else u.email end;
  v_phone := case when coalesce(u.phone, '') = '' then null
                  else '+' || ltrim(u.phone, '+') end;

  select p.login_primary into v_primary from public.profiles p where p.id = p_user_id;
  -- A chosen primary that is no longer set up falls back to the other one.
  if v_primary = 'email' and v_email is null then v_primary := null; end if;
  if v_primary = 'whatsapp' and v_phone is null and not v_placeholder then v_primary := null; end if;
  v_primary := coalesce(v_primary,
                        case when v_email is null then 'whatsapp' else 'email' end);

  return jsonb_build_object(
    'email', v_email,
    'phone', v_phone,
    'has_email', v_email is not null,
    -- A placeholder account without a phone can still sign in with its
    -- number + password through the placeholder (legacy); count it.
    'has_whatsapp', v_phone is not null or v_placeholder,
    'primary', v_primary
  );
end;
$$;

revoke all on function public.admin_login_methods(uuid) from public, anon;
grant execute on function public.admin_login_methods(uuid) to authenticated;

commit;
