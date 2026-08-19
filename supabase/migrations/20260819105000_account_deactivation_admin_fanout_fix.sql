-- Fix: request_account_deactivation() notified EVERY user on the platform,
-- not just admins.
--
-- The bug: the original function (20260819100000) fanned the "deactivation
-- requested" notification out with `where pr.platform_role is not null`.
-- profiles.platform_role is NOT NULL and DEFAULTS to 'normalUser', so
-- `is not null` matches every profile. Measured on production 2026-08-19:
-- 114 of 117 profiles are 'normalUser', 3 are 'superGlobalSerialAdminMain'.
-- A single deactivation request would have inserted a high-importance
-- notification -- naming the requester and quoting their stated reason --
-- into the inbox of all 117 users: mines, buyers, transporters, drivers,
-- everyone. Someone quietly asking to leave would have had that broadcast to
-- their own competitors and staff.
--
-- Never fired in production: account_deactivation_requests was empty and no
-- notification carried a deactivation_request_id, because every prior probe
-- ran inside a rolled-back transaction. Nothing to clean up.
--
-- The fix: match the column, not its null-ness.
--
--   where pr.platform_role = 'superGlobalSerialAdminMain'
--
-- This is the exact value public.is_super_admin() (called via
-- is_platform_admin()) tests, so the two agree by construction.
--
-- DO NOT use is_platform_admin() in this predicate. is_platform_admin() asks
-- "is the CALLER an admin" -- there is no caller-role check needed here, the
-- question is "which CANDIDATE ROW (pr) is an admin", i.e. it must be
-- evaluated per profiles row in the FROM clause, not once against auth.uid().
-- That mismatch is exactly the trap that let `is not null` look reasonable.
--
-- CLAUDE.md records that the child-admin tier was deliberately removed and
-- both super admins are equal -- so a single admin platform_role value is
-- expected, and was verified against production before writing this file
-- (select distinct platform_role from public.profiles -> exactly the two
-- values above, nothing else).

create or replace function public.request_account_deactivation(
  p_reason text default null
)
returns uuid
language plpgsql
security definer
set search_path = public, extensions, pg_temp
as $$
declare
  v_uid     uuid := auth.uid();
  v_company text;
  v_id      uuid;
  v_name    text;
begin
  if v_uid is null then
    raise exception 'Not signed in' using errcode = '42501';
  end if;

  -- MLD01 -- sole company owner.
  --
  -- Refused at REQUEST time, not review time, because it is actionable by the
  -- user. The message names TWO real routes rather than being a dead end:
  -- super_admin_set_company_status(id,'suspended') already exists and is how a
  -- company goes inactive, and ownership transfer is the other way out.
  select c.company_name into v_company
    from public.companies c
   where c.user_id = v_uid
   limit 1;

  if v_company is not null then
    raise exception
      'You own %. Its account must be suspended by a platform admin, or ownership transferred, before yours can be deactivated.',
      v_company
      using errcode = 'MLD01';
  end if;

  -- MLD02 -- belt and braces with the unique index. The index is the real
  -- guarantee; this raise is the readable error.
  if exists (
    select 1 from public.account_deactivation_requests
     where user_id = v_uid and status in ('pending','approved')
  ) then
    raise exception 'You already have a deactivation request in progress.'
      using errcode = 'MLD02';
  end if;

  insert into public.account_deactivation_requests (user_id, reason)
  values (v_uid, nullif(btrim(coalesce(p_reason, '')), ''))
  returning id into v_id;

  select coalesce(nullif(btrim(p.display_name), ''), p.email)
    into v_name from public.profiles p where p.id = v_uid;

  -- notification_type 'general' -- public.notifications.type has a CHECK
  -- constraint and 'account_deactivation' is not one of its allowed values.
  -- 'general' is the closest fit among the existing vocabulary; the
  -- deactivation_request_id in metadata is what a client filters/deep-links on.
  --
  -- Fan-out predicate: platform_role = 'superGlobalSerialAdminMain', NOT
  -- `is not null` -- see the file header. This is the fix.
  perform public.create_notification_internal(
    pr.id, null, null,
    'Account deactivation requested',
    coalesce(v_name, 'A user') || ' has asked for their account to be deactivated.',
    'general', v_name, v_uid, null, null, 'high',
    jsonb_build_object('deactivation_request_id', v_id, 'kind', 'account_deactivation')
  )
  from public.profiles pr
  where pr.platform_role = 'superGlobalSerialAdminMain';

  return v_id;
end;
$$;

comment on function public.request_account_deactivation(text) is
  'Opens a deactivation request. Refuses a company owner with SQLSTATE MLD01 '
  '(a company is never deleted and its owner cannot leave it ownerless -- the '
  'message names the suspension and transfer routes) and a duplicate with '
  'MLD02. Active trips do NOT block: the request is harmless and the review '
  'step exists to catch that. Notifies platform admins only '
  '(platform_role = ''superGlobalSerialAdminMain''), fixed 20260819105000 '
  'after a fan-out bug briefly (never in production) matched every profile.';
