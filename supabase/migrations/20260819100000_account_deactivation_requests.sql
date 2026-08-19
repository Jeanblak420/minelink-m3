-- In-app account DEACTIVATION.
--
-- Originally scoped as deletion, because Play's User Data policy and App Store
-- 5.1.1(v) require it. Jean ruled on 2026-08-19 that nothing on this platform
-- is ever deleted -- companies or people -- so this is deactivation, and the
-- store gap stays open and recorded. See the spec s1.1.
--
--   "Accounts (company profiles) shouldn't be deletable really, only
--    deactivate it, make it inactive."  -- Jean, 2026-08-19
--
-- NOTHING HERE DESTROYS DATA. No PII is scrubbed, no credential is scrambled,
-- no auth.identities row is deleted. The account becomes unusable and stays
-- fully recoverable through reactivate_account (20260819110000).
--
-- The spec's s1 foreign-key analysis is kept even though nothing deletes: it
-- is why a delete is impossible here (companies.user_id -> profiles is ON
-- DELETE CASCADE, plus eleven NO ACTION references), and it is the expensive
-- half of the work if the stores ever force the issue.

create table if not exists public.account_deactivation_requests (
  id              uuid primary key default gen_random_uuid(),
  user_id         uuid not null references public.profiles(id) on delete cascade,
  requested_at    timestamptz not null default timezone('utc', now()),
  reason          text,
  status          text not null default 'pending'
                    check (status in ('pending','approved','rejected',
                                      'cancelled','deactivated','reactivated')),
  reviewed_by     uuid references public.profiles(id) on delete set null,
  reviewed_at     timestamptz,
  review_note     text,
  -- A TTL, not a business day: now() is correct and ml_today() is not
  -- (CLAUDE.md s7.1 exempts timestamps that stamp a row rather than decide a day).
  auto_apply_at   timestamptz not null
                    default timezone('utc', now()) + interval '30 days',
  deactivated_at  timestamptz,
  -- The reversal is a first-class event, not an absence. Who restored an
  -- account and when is exactly what an audit asks, and a status flipped back
  -- with no trace cannot answer it.
  reactivated_at  timestamptz,
  reactivated_by  uuid references public.profiles(id) on delete set null
);

comment on table public.account_deactivation_requests is
  'User-initiated account deactivation, reviewed by a platform admin. Nothing '
  'is deleted or scrubbed -- see the spec s1.1 (Jean, 2026-08-19). Anything '
  'still pending at auto_apply_at is applied by '
  'apply_due_account_deactivations_job(), and every deactivation is reversible '
  'by reactivate_account(). NOTE: this does NOT satisfy Google Play''s '
  'account-DELETION requirement; that gap is open and recorded.';

-- One open request per user. `deactivated` is deliberately NOT in this list:
-- a reactivated user must be able to ask again later, and a permanently
-- occupied slot would prevent it.
create unique index if not exists account_deactivation_requests_one_open
  on public.account_deactivation_requests (user_id)
  where status in ('pending', 'approved');

create index if not exists account_deactivation_requests_due_idx
  on public.account_deactivation_requests (auto_apply_at)
  where status = 'pending';

alter table public.account_deactivation_requests enable row level security;

-- SELECT grant only. No write grant and no write policy: every write goes
-- through an RPC, the same shape as monthly_targets.
drop policy if exists account_deactivation_requests_select
  on public.account_deactivation_requests;
create policy account_deactivation_requests_select
  on public.account_deactivation_requests
  for select to authenticated
  using (user_id = auth.uid() or public.is_platform_admin());

grant select on public.account_deactivation_requests to authenticated;

-- ---------------------------------------------------------------------------
-- request_account_deactivation
-- ---------------------------------------------------------------------------
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
  perform public.create_notification_internal(
    pr.id, null, null,
    'Account deactivation requested',
    coalesce(v_name, 'A user') || ' has asked for their account to be deactivated.',
    'general', v_name, v_uid, null, null, 'high',
    jsonb_build_object('deactivation_request_id', v_id, 'kind', 'account_deactivation')
  )
  from public.profiles pr
  where pr.platform_role is not null;

  return v_id;
end;
$$;

comment on function public.request_account_deactivation(text) is
  'Opens a deactivation request. Refuses a company owner with SQLSTATE MLD01 '
  '(a company is never deleted and its owner cannot leave it ownerless -- the '
  'message names the suspension and transfer routes) and a duplicate with '
  'MLD02. Active trips do NOT block: the request is harmless and the review '
  'step exists to catch that.';

-- ---------------------------------------------------------------------------
-- cancel_account_deactivation_request
-- ---------------------------------------------------------------------------
create or replace function public.cancel_account_deactivation_request()
returns void
language plpgsql
security definer
set search_path = public, extensions, pg_temp
as $$
declare
  v_uid uuid := auth.uid();
  v_n   int;
begin
  if v_uid is null then
    raise exception 'Not signed in' using errcode = '42501';
  end if;

  -- 'pending' only. Once an admin has approved, the user cannot unilaterally
  -- withdraw -- a decision has been taken on it.
  update public.account_deactivation_requests
     set status = 'cancelled'
   where user_id = v_uid and status = 'pending';

  get diagnostics v_n = row_count;
  if v_n = 0 then
    raise exception 'No pending deactivation request to cancel.'
      using errcode = 'MLD02';
  end if;
end;
$$;

-- ---------------------------------------------------------------------------
-- my_account_deactivation_request -- what the card renders
-- ---------------------------------------------------------------------------
create or replace function public.my_account_deactivation_request()
returns jsonb
language sql
stable
security definer
set search_path = public, extensions, pg_temp
as $$
  select to_jsonb(r)
    from public.account_deactivation_requests r
   where r.user_id = auth.uid()
     and r.status in ('pending','approved','rejected')
   order by r.requested_at desc
   limit 1;
$$;

revoke execute on function public.request_account_deactivation(text) from public, anon;
revoke execute on function public.cancel_account_deactivation_request() from public, anon;
revoke execute on function public.my_account_deactivation_request() from public, anon;
grant execute on function public.request_account_deactivation(text) to authenticated;
grant execute on function public.cancel_account_deactivation_request() to authenticated;
grant execute on function public.my_account_deactivation_request() to authenticated;
