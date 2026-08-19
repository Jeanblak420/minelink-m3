-- Fix round 1 for 20260819110000. Four issues found by the coordinator's
-- review, two Important and two Minor, all verified live before this file
-- was written. New migration, not an edit to 20260819110000 -- that file is
-- already applied and stamped (CLAUDE.md s6 rule 1: never fold a follow-up
-- fix into an earlier file).
--
-- IMPORTANT 1 -- deactivate_account / reactivate_account throw 23514 on a
-- company-less (pending_company) employee, and one live user is in that
-- state today.
--
--   employees_company_required: check (company_id is not null or
--     status = 'pending_company')
--
-- The unconditional `update ... set status = 'inactive' where user_id = v_uid`
-- flips a pending_company row's status while leaving company_id null, which
-- satisfies neither disjunct and raises 23514 -- rolling back the ENTIRE
-- deactivation, including the session revocations and the ban flag already
-- applied earlier in the same function. reactivate_account's
-- `status = 'active'` write has the identical hole.
--
-- Probed live (read-only, no write) against the real row:
--   select id, user_id, company_id, status from public.employees
--    where user_id = 'aaba128b-28a3-49cf-9ac8-735b4e171938';
--   -> company_id: null, status: 'pending_company'
-- One real user carries exactly the state that trips this.
--
-- THE FIX: scope both updates to `company_id is not null`, i.e. leave
-- pending_company rows alone entirely, rather than trying to transition them.
-- Reasoning: a user who never finished company setup has no employees row
-- worth putting through an active/inactive cycle -- there is no company
-- floor access to revoke, no shift to be pulled off. The AUTHORITATIVE lock
-- is auth.users.banned_until, set unconditionally above this line in both
-- functions and untouched by this fix: it blocks sign-in regardless of
-- whether any employees row exists or what its status is. Scoping the
-- employees write is strictly narrower than the original intent (transition
-- a real employment record), not a workaround for an error.
--
-- IMPORTANT 2 -- review_account_deactivation_request wrote no audit row.
-- Spec s2.3: "Writes an audit log row." It didn't -- only deactivate and
-- reactivate did. An admin's approve/reject of someone's request to leave is
-- exactly the kind of decision an audit trail exists to attribute. Added,
-- using the same insert_audit_log shape and 'user' target_type already
-- verified in 20260819110000 (audit_logs_target_type_check does not admit
-- 'profiles'). This function is authenticated-admin-only (guarded at the
-- top), so insert_audit_log's internal require_platform_admin() always
-- succeeds here -- no branching needed, same as reactivate_account.
--
-- MINOR 3 -- reactivate_account had no existence guard. An unknown uuid
-- returned {"status":"reactivated"} and wrote a misleading audit row
-- claiming an account was restored that never existed. Added the same
-- existence check deactivate_account already has.
--
-- MINOR 4 -- list_account_deactivation_requests' active_trips subquery used
-- `t.status not in ('completed','cancelled')`, which evaluates to NULL (not
-- true) for a NULL t.status, silently excluding those trips from the count.
-- This chip is informational for a human reviewer, and over-reporting a
-- blocker costs a glance while under-reporting one hides a driver who is
-- mid-load -- treat NULL status as active. Verified live: public.trips.status
-- is itself NOT NULL (0 rows with a null status today), so this specific
-- state is not currently reachable through the schema -- the fix is
-- defensive, matching the coordinator's instruction, not closing a gap that
-- is live today.
--
-- UNPLANNED FIFTH FIX, found only because proving IMPORTANT 1 end-to-end
-- required it -- insert_audit_log() itself raises when p_organization_id is
-- NULL. Its `org` variable is declared `record` and only ever assigned
-- inside `if p_organization_id is not null then select ... into org`; when
-- that branch is skipped, the later `org.company_name` / `org.org_type`
-- reads raise `55000: record "org" is not assigned yet` -- a record with no
-- assigned tuple shape cannot be field-accessed even to read NULL.
--
-- This is pre-existing and not introduced by 20260819110000 or this file --
-- confirmed by reading 20260510205000_super_admin_write_rpcs_and_hardening.sql
-- (the current full-text source; its body matches pg_get_functiondef() on the
-- live function exactly). It was never hit before because every prior call
-- site that could reach a NULL p_organization_id happened to also be a path
-- that already worked around it in some other way. reactivate_account
-- (unconditionally, admin-only) does not: a company-less employee --
-- precisely IMPORTANT 1's fixed scenario, and precisely the live user
-- aaba128b-28a3-49cf-9ac8-735b4e171938's situation -- has v_company_id = null,
-- so proving the reactivate half of IMPORTANT 1's probe requires this fixed
-- too. Fixed by replacing the `record` with two plain `text` variables that
-- default to NULL on their own, which is exactly what a company-less actor's
-- audit row should carry. Same 8-parameter signature, no OUT-column change,
-- so `create or replace` is safe (CLAUDE.md s6).

create or replace function public.review_account_deactivation_request(
  p_id      uuid,
  p_approve boolean,
  p_note    text default null
)
returns void
language plpgsql
security definer
set search_path = public, extensions, pg_temp
as $$
declare
  v_req            public.account_deactivation_requests;
  v_admin          text;
  v_target_name    text;
  v_target_company uuid;
begin
  if not public.is_platform_admin() then
    raise exception 'Only a platform admin may review deactivation requests.'
      using errcode = '42501';
  end if;

  select * into v_req from public.account_deactivation_requests where id = p_id;
  if not found then
    raise exception 'No such deactivation request.' using errcode = 'MLD02';
  end if;
  if v_req.status <> 'pending' then
    raise exception 'That request is already %.', v_req.status using errcode = 'MLD02';
  end if;

  -- A rejection the user cannot understand is a rejection they will re-submit.
  if not p_approve and nullif(btrim(coalesce(p_note, '')), '') is null then
    raise exception 'A reason is required when rejecting a deactivation request.'
      using errcode = 'MLD02';
  end if;

  update public.account_deactivation_requests
     set status      = case when p_approve then 'approved' else 'rejected' end,
         reviewed_by = auth.uid(),
         reviewed_at = timezone('utc', now()),
         review_note = nullif(btrim(coalesce(p_note, '')), '')
   where id = p_id;

  select coalesce(nullif(btrim(display_name), ''), email)
    into v_admin from public.profiles where id = auth.uid();

  -- notification_type 'general' -- notifications.type's CHECK constraint does
  -- not admit 'account_deactivation'; 'kind' inside metadata carries it
  -- instead, matching request_account_deactivation (20260819100000/105000).
  perform public.create_notification_internal(
    v_req.user_id, null, null,
    case when p_approve then 'Account deactivation approved'
                        else 'Deactivation request declined' end,
    case when p_approve
         then 'Your account will be deactivated shortly. You will not be able to sign in, and an administrator can restore it if you change your mind.'
         else 'Your deactivation request was declined: ' || coalesce(p_note, '') end,
    'general', v_admin, auth.uid(), null, null, 'high',
    jsonb_build_object('deactivation_request_id', p_id, 'kind', 'account_deactivation')
  );

  -- IMPORTANT 2 fix: audit the review decision. This function is guarded
  -- admin-only above, so auth.uid() is always present and
  -- insert_audit_log()'s internal require_platform_admin() always succeeds --
  -- no no-JWT branching needed here, unlike deactivate_account.
  -- target_type = 'user' (the account under review), not 'profiles' --
  -- audit_logs_target_type_check does not admit 'profiles' (see 20260819110000).
  select coalesce(nullif(btrim(p.display_name), ''), p.email),
         (select e.company_id from public.employees e where e.user_id = v_req.user_id limit 1)
    into v_target_name, v_target_company
    from public.profiles p where p.id = v_req.user_id;

  perform public.insert_audit_log(
    case when p_approve then 'ACCOUNT_DEACTIVATION_APPROVED'
                        else 'ACCOUNT_DEACTIVATION_REJECTED' end,
    'user', v_req.user_id, v_target_name, v_target_company,
    case when p_approve
         then 'Deactivation request approved (request ' || p_id::text || ')'
         else 'Deactivation request rejected: ' || coalesce(p_note, '') ||
              ' (request ' || p_id::text || ')' end
  );
end;
$$;

comment on function public.review_account_deactivation_request(uuid, boolean, text) is
  'Platform-admin approve/reject of a pending deactivation request. Rejects '
  'require a non-empty note. Notifies the requester either way via '
  'notification type=general / metadata.kind=account_deactivation, and audits '
  'the decision (ACCOUNT_DEACTIVATION_APPROVED/REJECTED, target_type=user). '
  'Fixed 20260819115000: the audit write was missing entirely.';

-- ---------------------------------------------------------------------------
-- deactivate_account -- IMPORTANT 1 fix: scope the employees write to rows
-- that actually have a company. See file header.
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

  if exists (select 1 from public.companies where user_id = v_uid) then
    raise exception 'That user owns a company and cannot be deactivated.'
      using errcode = 'MLD01';
  end if;

  delete from auth.refresh_tokens where user_id = v_uid::text;
  delete from auth.sessions        where user_id = v_uid;

  -- THE authoritative lock. Applies regardless of whether an employees row
  -- exists at all, or what state it is in -- see file header IMPORTANT 1.
  update auth.users set banned_until = 'infinity' where id = v_uid;

  -- Scoped to company_id is not null: a pending_company row (no company yet)
  -- fails employees_company_required if flipped to 'inactive' while
  -- company_id stays null, and there is no real employment to suspend
  -- anyway. See file header IMPORTANT 1 -- the live user
  -- aaba128b-28a3-49cf-9ac8-735b4e171938 is in exactly this state today.
  update public.employees set
    status     = 'inactive',
    updated_at = timezone('utc', now())
  where user_id = v_uid
    and company_id is not null;

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
  'The act. Revokes sessions, sets banned_until = infinity (the sole '
  'authoritative lock -- applies even with no employees row), sets '
  'employees.status = inactive ONLY for rows that already carry a company_id '
  '(fixed 20260819115000: a pending_company row with no company would '
  'otherwise raise 23514 and roll back the whole deactivation). Never touches '
  'auth.identities, never scrambles the password, never sets '
  'auth.users.deleted_at, never writes public.profiles (spec s1.1).';

-- ---------------------------------------------------------------------------
-- reactivate_account -- MINOR 3 fix: existence guard. IMPORTANT 1 fix: same
-- employees scoping as deactivate_account.
-- ---------------------------------------------------------------------------
create or replace function public.reactivate_account(p_user_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions, pg_temp
as $$
declare
  v_uid        uuid := p_user_id;
  v_name       text;
  v_company_id uuid;
begin
  if not public.is_platform_admin() then
    raise exception 'Only a platform admin may reactivate an account.'
      using errcode = '42501';
  end if;

  -- MINOR 3 fix: without this, an unknown uuid returned
  -- {"status":"reactivated"} and wrote an audit row claiming an account was
  -- restored that never existed.
  if not exists (select 1 from public.profiles where id = v_uid) then
    raise exception 'No such user.' using errcode = 'MLD02';
  end if;

  select coalesce(nullif(btrim(p.display_name), ''), p.email),
         (select e.company_id from public.employees e where e.user_id = v_uid limit 1)
    into v_name, v_company_id
    from public.profiles p where p.id = v_uid;

  -- null, not a past timestamp -- see 20260819110000.
  update auth.users set banned_until = null where id = v_uid;

  -- Same scoping as deactivate_account, and for the same reason: a
  -- pending_company row was never transitioned to 'inactive' by
  -- deactivate_account (fixed above), so there is nothing here to put back
  -- to 'active' either, and an unconditional write would hit the identical
  -- employees_company_required hole in reverse.
  update public.employees set status = 'active', updated_at = timezone('utc', now())
   where user_id = v_uid
     and company_id is not null;

  update public.account_deactivation_requests
     set status = 'reactivated',
         reactivated_at = timezone('utc', now()),
         reactivated_by = auth.uid()
   where user_id = v_uid and status = 'deactivated';

  perform public.insert_audit_log(
    'ACCOUNT_REACTIVATED', 'user', v_uid, v_name, v_company_id,
    'Account reactivated'
  );

  return jsonb_build_object('user_id', v_uid, 'status', 'reactivated');
end;
$$;

comment on function public.reactivate_account(uuid) is
  'The exact inverse of deactivate_account: banned_until back to NULL '
  '(never a past timestamp), employees.status back to active ONLY for rows '
  'with a company_id (mirrors the deactivate_account fix). Platform-admin '
  'only, never the cron backstop. Fixed 20260819115000: added the existence '
  'guard deactivate_account already had.';

-- ---------------------------------------------------------------------------
-- list_account_deactivation_requests -- MINOR 4 fix: NULL trip status
-- ---------------------------------------------------------------------------
create or replace function public.list_account_deactivation_requests(
  p_status text default 'pending'
)
returns table (
  id               uuid,
  user_id          uuid,
  display_name     text,
  email            text,
  company_name     text,
  role             text,
  reason           text,
  status           text,
  requested_at     timestamptz,
  auto_apply_at    timestamptz,
  review_note      text,
  deactivated_at   timestamptz,
  is_company_owner boolean,
  active_trips     int
)
language sql
stable
security definer
set search_path = public, extensions, pg_temp
as $$
  select r.id, r.user_id, p.display_name, p.email, c.company_name, e.role,
         r.reason, r.status, r.requested_at, r.auto_apply_at, r.review_note,
         r.deactivated_at,
         exists (select 1 from public.companies co where co.user_id = r.user_id),
         -- Active trips, counted down BOTH driver paths. MINOR 4 fix: a NULL
         -- t.status made `t.status not in ('completed','cancelled')`
         -- evaluate to NULL (not true), silently dropping that trip from the
         -- count. This chip is informational for a human reviewer, and
         -- over-reporting a blocker costs a glance while under-reporting one
         -- hides a driver who is mid-load -- treat NULL status as active.
         (select count(distinct t.id)::int
            from public.trips t
           where (t.status is null or t.status not in ('completed','cancelled'))
             and (exists (select 1
                            from public.driver_assignments da
                            join public.employees e on e.id = da.driver_employee_id
                           where da.vehicle_id = t.vehicle_id
                             and e.user_id = r.user_id)
               or exists (select 1
                            from public.fleet_vehicles fv
                           where fv.id = t.vehicle_id
                             and fv.driver_user_id = r.user_id)))
    from public.account_deactivation_requests r
    join public.profiles p on p.id = r.user_id
    left join public.employees e on e.user_id = r.user_id
    left join public.companies c on c.id = e.company_id
   where public.is_platform_admin()
     and (p_status is null or r.status = p_status)
   order by r.requested_at;
$$;

comment on function public.list_account_deactivation_requests(text) is
  'Platform-admin console queue. is_company_owner and active_trips are '
  'informational blocker chips for the reviewer, not enforced refusals -- '
  'active trips do not block a deactivation request. Fixed 20260819115000: '
  'a NULL trip status no longer silently drops that trip from the count.';

-- ---------------------------------------------------------------------------
-- insert_audit_log -- unplanned fifth fix. See file header. Pre-existing bug,
-- not introduced here; fixed because proving IMPORTANT 1's reactivate path
-- for a company-less user requires it. Same 8-arg signature as
-- 20260510205000_super_admin_write_rpcs_and_hardening.sql (the current
-- full-text source, confirmed to match the live function via
-- pg_get_functiondef before this file was written) -- only the body changes.
-- ---------------------------------------------------------------------------
create or replace function public.insert_audit_log(
  p_action_type text,
  p_target_type text,
  p_target_id uuid default null,
  p_target_name text default null,
  p_organization_id uuid default null,
  p_description text default '',
  p_before_data jsonb default null,
  p_after_data jsonb default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  actor    record;
  -- Plain scalars, not a `record`, and for exactly this reason: a `record`
  -- variable that is never assigned via SELECT INTO has no tuple shape at
  -- all, and reading a field off it later raises `55000: record "org" is not
  -- assigned yet` -- even to read a NULL. Plain text variables default to
  -- NULL on their own, which is exactly the right value for a company-less
  -- actor's audit row.
  v_org_name text;
  v_org_type text;
begin
  perform public.require_platform_admin();

  select p.id, p.email, p.platform_role
  into actor
  from public.profiles p
  where p.id = auth.uid()
  limit 1;

  if p_organization_id is not null then
    select c.company_name, c.org_type
      into v_org_name, v_org_type
      from public.companies c
     where c.id = p_organization_id
     limit 1;
  end if;

  insert into public.audit_logs (
    actor_user_id,
    actor_email,
    actor_platform_role,
    action_type,
    target_type,
    target_id,
    target_name,
    organization_id,
    organization_name,
    organization_type,
    description,
    before_data,
    after_data,
    created_at
  )
  values (
    auth.uid(),
    coalesce(actor.email, ''),
    coalesce(actor.platform_role, 'normalUser'),
    p_action_type,
    p_target_type,
    p_target_id,
    p_target_name,
    p_organization_id,
    v_org_name,
    v_org_type,
    coalesce(p_description, ''),
    p_before_data,
    p_after_data,
    timezone('utc', now())
  );
end;
$$;

comment on function public.insert_audit_log(text, text, uuid, text, uuid, text, jsonb, jsonb) is
  'Writes one audit_logs row. Requires the caller to be a platform admin '
  '(require_platform_admin()). Fixed 20260819115000: p_organization_id = null '
  '(a company-less actor or target) used to raise 55000 -- record "org" is '
  'not assigned yet -- because org was a `record` only ever assigned inside '
  'the p_organization_id is not null branch. Now two plain text locals that '
  'default to NULL correctly.';
