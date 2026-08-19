-- Fix wave following the whole-branch review of the release-hardening effort.
-- Two cross-cutting findings, neither visible to any individual task's review.
--
-- ===========================================================================
-- FINDING 1 -- a company owner is told two ways to leave, and NEITHER works.
-- ===========================================================================
--
-- request_account_deactivation's MLD01 message (20260819105000) names two
-- routes out for a company owner: "suspended by a platform admin, or
-- ownership transferred". Verified live before writing this file:
--
--   select prosrc from pg_proc where proname = 'super_admin_set_company_status';
--
-- confirms that function only ever does
--   update public.companies set status = p_status, updated_at = ... where id = p_company_id;
-- -- it NEVER touches companies.user_id. So suspending a company changes
-- nothing the MLD01 guard looks at: `exists (select 1 from public.companies
-- where user_id = auth.uid())` still matches a suspended company exactly as
-- it matches an active one, and apply_due_account_deactivations_job's
-- identical exclusion predicate still matches it too. Ownership transfer
-- would clear the block, but has no UI anywhere in this repo (grepped;
-- nothing calls a transfer-ownership RPC from lib/). Net effect: a company
-- owner cannot deactivate their account today, full stop, and both escape
-- routes the message offers are dead.
--
-- Also verified live: `select distinct status, count(*) from public.companies
-- group by status` returns exactly one row, `active` x26` -- and the column
-- is `not null default 'pendingActivation'` (information_schema, verified
-- live), so `status <> 'suspended'` below never needs a NULL branch.
--
-- THE FIX -- make suspension actually work, changed consistently in the
-- three places the coordinator named, using the exact same predicate
-- (`status <> 'suspended'`) in all three so they cannot drift apart:
--
--   1. request_account_deactivation's MLD01 guard (front door)
--   2. deactivate_account's own MLD01 guard (back door, the cron path)
--   3. apply_due_account_deactivations_job's skip-count query AND its loop
--      exclusion -- both changed together, kept exact complements of each
--      other (one is `exists (... and status <> 'suspended')`, the other is
--      the same `exists` wrapped in `not`), which is what keeps the warning
--      count and the number of rows actually skipped in agreement.
--
-- An owner of a SUSPENDED company can now open a request and can be
-- deactivated: the company is out of operation on the platform (an
-- application-level judgement already made the moment a platform admin
-- suspends it), nothing operational depends on that owner while it stays
-- suspended, and the whole thing is reversible either way (reactivate the
-- company, reactivate the account). An owner of an ACTIVE company is still
-- refused exactly as before -- this does not loosen anything for the
-- ordinary case, it only makes the promised escape route real.
--
-- THE MESSAGE, made honest. The old wording read like the owner could
-- either route themselves ("suspended by a platform admin, or ownership
-- transferred" -- the second clause names no actor, which reads as
-- something the owner can do). Ownership transfer has no UI anywhere in
-- this app today, so a message that implies a self-service route is simply
-- wrong. Both routes now explicitly name the actor: a platform admin.
--
-- ===========================================================================
-- FINDING 2 -- deactivation does not stop push (fixed now, while inert).
-- ===========================================================================
--
-- deactivate_account never touched device_tokens, and push-fanout
-- (20260819090000's notifications_push_fanout trigger + the push-fanout edge
-- function) selects tokens by user_id alone -- no banned_until check, no
-- employee-status check. notify_company_role filters on status='active' so
-- ROLE fan-outs stop for a deactivated user, but a DIRECT notification to
-- their user_id would still reach notifications_push_fanout and still
-- attempt delivery to their device.
--
-- Harmless today: notifications_push_fanout's own header explains that with
-- no key in Vault and no app.settings.service_role_key set, it returns
-- immediately after `select ... into v_key` finds nothing -- no POST is ever
-- sent, to anyone, regardless of this fix. It arms itself the moment Jean
-- sets FCM_SERVICE_ACCOUNT and wires a key in -- a config change, with no
-- deploy and no code review, and the person making that change is the
-- person least likely to be re-reading this function's body. Fixing it now,
-- while it is provably inert, means there is nothing left to remember later.
--
-- THE FIX -- deactivate_account deletes the user's device_tokens rows.
-- reactivate_account does NOT recreate them, deliberately: a device token is
-- a fact about a device's current registration, not a fact about the user's
-- access. The device re-registers itself the next time it signs in, via
-- register_device_token (20260819090000) -- that is the normal, expected
-- path for every device on every sign-in, deactivation or not. Restoring
-- stale rows on reactivate would risk pushing to a token that is not even
-- installed on that device anymore. This asymmetry is deliberate -- do not
-- "fix" it by adding a mirroring delete-restore in reactivate_account.

-- ---------------------------------------------------------------------------
-- 1a. request_account_deactivation -- front door. Suspended companies no
-- longer block; the message names the platform admin as the actor for both
-- routes. Every other line carried forward byte-identical from the live
-- function (verified via pg_get_functiondef before writing this).
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

  -- MLD01 -- sole owner of a company that is NOT already suspended.
  --
  -- Fixed 20260819160000: a suspended company no longer blocks. Verified
  -- live that super_admin_set_company_status never touches companies.user_id
  -- -- so before this fix, suspending a company did nothing to unblock its
  -- owner, and the message's other named route (ownership transfer) has no
  -- UI anywhere in this app. A company already suspended is out of
  -- operation on the platform; nothing operational depends on its owner
  -- while it stays that way, and the whole thing is reversible either way.
  select c.company_name into v_company
    from public.companies c
   where c.user_id = v_uid
     and c.status <> 'suspended'
   limit 1;

  if v_company is not null then
    raise exception
      'You own %. A platform admin must have that company suspended, or its ownership transferred, before your account can be deactivated.',
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
  -- `is not null` -- see 20260819105000's file header. This is that fix.
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
  'only while their company is NOT suspended -- a suspended company no '
  'longer blocks (fixed 20260819160000: super_admin_set_company_status never '
  'touched companies.user_id, so suspension used to do nothing to unblock '
  'the owner). The message names a platform admin as the actor for both the '
  'suspend and the ownership-transfer route -- the latter has no self-service '
  'UI. Duplicate requests refused with MLD02. Active trips do NOT block: the '
  'request is harmless and the review step exists to catch that. Notifies '
  'platform admins only (platform_role = ''superGlobalSerialAdminMain'').';

-- ---------------------------------------------------------------------------
-- 1b. deactivate_account -- back door (the cron path calls this directly).
-- Same suspended-company carve-out as the front door. Also Finding 2: revoke
-- push by deleting the user's device_tokens rows. Every other line carried
-- forward byte-identical from the live function (verified via
-- pg_get_functiondef before writing this).
-- ---------------------------------------------------------------------------
create or replace function public.deactivate_account(p_user_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions, pg_temp
as $$
declare
  v_uid        uuid := p_user_id;
  v_req        uuid;
  v_name       text;
  v_company_id uuid;
begin
  if not (public.is_platform_admin()
          or auth.role() = 'service_role'
          or auth.uid() is null) then
    raise exception 'Not permitted.' using errcode = '42501';
  end if;

  if not exists (select 1 from public.profiles where id = v_uid) then
    raise exception 'No such user.' using errcode = 'MLD02';
  end if;

  select coalesce(nullif(btrim(p.display_name), ''), p.email),
         (select e.company_id from public.employees e where e.user_id = v_uid limit 1)
    into v_name, v_company_id
    from public.profiles p where p.id = v_uid;

  -- MLD01 -- same suspended-company carve-out as request_account_deactivation
  -- above. Fixed 20260819160000. This is the back door the cron backstop
  -- calls, so it must agree with the front door's rule or a request that was
  -- accepted at request time could still be refused here forever.
  if exists (
    select 1 from public.companies
     where user_id = v_uid and status <> 'suspended'
  ) then
    raise exception 'That user owns a company and cannot be deactivated.'
      using errcode = 'MLD01';
  end if;

  delete from auth.refresh_tokens where user_id = v_uid::text;
  delete from auth.sessions        where user_id = v_uid;

  update auth.users set banned_until = 'infinity' where id = v_uid;

  update public.employees set
    status     = 'inactive',
    updated_at = timezone('utc', now())
  where user_id = v_uid
    and company_id is not null;

  -- Finding 2, fixed 20260819160000: revoke push. device_tokens rows are a
  -- fact about a device's current registration, not about the user's
  -- access -- deleting them here (rather than leaving them for push-fanout
  -- to filter on user_id alone) is the actual stop, because
  -- notifications_push_fanout / push-fanout select by user_id with no
  -- banned_until or employee-status check at all. Deliberately NOT restored
  -- by reactivate_account: a device re-registers itself via
  -- register_device_token the next time it signs in, which is the normal
  -- path on every sign-in regardless of deactivation history. Do not add a
  -- mirroring insert on reactivate to "fix" this asymmetry.
  delete from public.device_tokens where user_id = v_uid;

  update public.account_deactivation_requests
     set status = 'deactivated', deactivated_at = timezone('utc', now())
   where user_id = v_uid and status in ('pending','approved')
  returning id into v_req;

  if auth.uid() is not null then
    perform public.insert_audit_log(
      'ACCOUNT_DEACTIVATED', 'user', v_uid, v_name, v_company_id,
      'Account deactivated (request ' || coalesce(v_req::text, 'n/a') || ')'
    );
  else
    insert into public.audit_logs (
      actor_user_id, actor_email, actor_platform_role, action_type,
      target_type, target_id, target_name, organization_id, description,
      created_at
    ) values (
      null, 'system', 'system', 'ACCOUNT_DEACTIVATED', 'user',
      v_uid::text, v_name, v_company_id,
      'Account deactivated (request ' || coalesce(v_req::text, 'n/a') ||
        ') by the auto-apply cron backstop',
      timezone('utc', now())
    );
  end if;

  return jsonb_build_object('user_id', v_uid, 'request_id', v_req,
                            'status', 'deactivated');
end;
$$;

comment on function public.deactivate_account(uuid) is
  'The act. Revokes sessions, sets banned_until = infinity, sets '
  'employees.status = inactive for rows with a company_id, and deletes the '
  'user''s device_tokens rows (fixed 20260819160000, Finding 2 -- push-fanout '
  'selects by user_id alone with no banned_until/status check, so this is '
  'the actual stop; NOT restored by reactivate_account on purpose -- a '
  'device re-registers itself via register_device_token on next sign-in). '
  'MLD01 refuses only while the owned company is not suspended (fixed '
  '20260819160000, Finding 1 -- suspension used to do nothing to unblock '
  'the owner, since super_admin_set_company_status never touches '
  'companies.user_id). Never touches auth.identities, never scrambles the '
  'password, never sets auth.users.deleted_at, never writes public.profiles '
  '(spec s1.1). Callable by a platform admin or by the daily cron backstop, '
  'which runs as plain SQL with no JWT context at all -- see 20260819110000''s '
  'file header for why the guard checks auth.uid() is null rather than '
  'auth.role() = ''service_role''.';

-- ---------------------------------------------------------------------------
-- 1c. apply_due_account_deactivations_job -- the skip-count query and the
-- loop's exclusion predicate, changed TOGETHER and kept exact complements
-- (`exists (... and status <> 'suspended')` vs. the same wrapped in `not`),
-- which is what keeps the warning's reported count equal to the number of
-- rows the loop actually skips. Every other line carried forward
-- byte-identical from the live function (verified via pg_get_functiondef
-- before writing this).
-- ---------------------------------------------------------------------------
create or replace function public.apply_due_account_deactivations_job()
returns int
language plpgsql
security definer
set search_path = public, extensions, pg_temp
as $$
declare
  v_row     record;
  v_count   int := 0;
  v_skipped int;
begin
  -- Count once, before the loop -- see 20260819125000's file header for why
  -- once-per-run and not per-row. Same due-predicate as the loop below; the
  -- only difference is this counts the ones the loop's WHERE clause
  -- excludes for ownership of a non-suspended company.
  --
  -- Fixed 20260819160000: `status <> 'suspended'` added to both this query
  -- and the loop's `not exists` below, kept as exact complements of each
  -- other on purpose -- a company owner whose company IS suspended is no
  -- longer skipped or counted here at all; they fall through to the loop
  -- and get deactivated like anyone else.
  select count(*) into v_skipped
    from public.account_deactivation_requests r
   where (r.status = 'approved'
          or (r.status = 'pending' and r.auto_apply_at <= timezone('utc', now())))
     and exists (
           select 1 from public.companies co
            where co.user_id = r.user_id and co.status <> 'suspended'
         );

  if v_skipped > 0 then
    raise warning
      'apply_due_account_deactivations_job: % request(s) skipped -- requester owns a company that is not suspended; suspend the company or transfer ownership',
      v_skipped;
  end if;

  for v_row in
    select r.user_id
      from public.account_deactivation_requests r
     where (r.status = 'approved'
            or (r.status = 'pending' and r.auto_apply_at <= timezone('utc', now())))
       -- See 20260819120000's file header for the MLD01 decision, and the
       -- 20260819160000 fix note above the skip-count query: a company
       -- owner is skipped up front only while their company is NOT
       -- suspended -- kept an exact complement of the skip-count predicate
       -- above so the warning's number always equals what this loop skips.
       and not exists (
             select 1 from public.companies co
              where co.user_id = r.user_id and co.status <> 'suspended'
           )
     order by r.requested_at
     -- Bounded. An unbounded nightly loop is the shape that took this instance
     -- down on 2026-08-16; there will never be 200 of these in a night, and if
     -- there are, something is wrong and slower is correct.
     limit 200
  loop
    -- One bad row must not stop the rest. This is the close_due_target_cycles_job
    -- lesson: an exception propagating out of the loop freezes the nightly run
    -- for every other scope. The ordinary MLD01 case (a company owner of a
    -- non-suspended company) is already excluded and counted by the WHERE
    -- clause + count above, so this handler is a backstop for the genuinely
    -- unexpected -- not the expected steady state.
    begin
      perform public.deactivate_account(v_row.user_id);
      v_count := v_count + 1;
    exception when others then
      raise warning 'apply_due_account_deactivations_job: user % skipped: %',
        v_row.user_id, sqlerrm;
    end;
  end loop;

  return v_count;
end;
$$;

comment on function public.apply_due_account_deactivations_job() is
  'Applies approved deactivation requests, and pending ones 30 days old. Plain '
  'SQL -- no pg_net and no edge function, because deactivation destroys '
  'nothing and needs no storage purge. Company owners whose company is NOT '
  'suspended are excluded from the selection query up front (never retried '
  'into a permanent nightly warning) -- see the MLD01 decision in '
  '20260819120000''s file header; a single `raise warning` naming the count '
  'is logged once per run when any are excluded, and they stay visible to an '
  'admin via list_account_deactivation_requests.is_company_owner. Fixed '
  '20260819160000: an owner of a SUSPENDED company is no longer skipped at '
  'all -- the skip-count query and the loop''s exclusion were both changed '
  'to `status <> ''suspended''`, kept exact complements of each other so the '
  'warning''s count always equals what the loop actually skips. The return '
  'value counts only rows actually deactivated, not skipped ones. Never '
  'reactivates: that is platform-admin only, deliberately.';

-- ---------------------------------------------------------------------------
-- 2. reactivate_account -- no functional change. Comment only, so the
-- device_tokens asymmetry (deactivate deletes, reactivate does not restore)
-- is not "fixed" by someone reading this function in isolation later.
-- ---------------------------------------------------------------------------
comment on function public.reactivate_account(uuid) is
  'The exact inverse of deactivate_account: banned_until back to NULL '
  '(never a past timestamp), employees.status back to active. Platform-admin '
  'only, never the cron backstop -- granting access back is not a symmetric '
  'risk to removing it. Deliberately does NOT recreate device_tokens rows '
  '(fixed 20260819160000 alongside deactivate_account''s delete, Finding 2): '
  'a token is a fact about a device''s current registration, not about the '
  'user''s access, and the device re-registers itself via '
  'register_device_token on its next sign-in regardless of deactivation '
  'history. Do not add a mirroring insert here to make this symmetric.';
