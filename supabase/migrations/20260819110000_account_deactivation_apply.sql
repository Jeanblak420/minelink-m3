-- Review, apply, and undo. See 20260819100000 and the spec s2.3 / s1.1.
--
-- NOTHING HERE DELETES OR SCRUBS. The only destructive statements are the two
-- session revocations, and a session is not data -- it is an access grant, and
-- revoking it is the point.
--
-- auth.refresh_tokens.user_id is `character varying`, NOT uuid -- alone among
-- the auth tables touched here, verified against production 2026-08-19.
-- `= v_uid` raises 42883 (operator does not exist: character varying = uuid).
--
-- THREE CORRECTIONS TO THE PLANNED SQL, all found by verifying against
-- production before applying rather than trusting the draft:
--
-- 1. notification type. public.notifications.type has a CHECK constraint
--    (verified 2026-08-19) whose vocabulary does NOT include
--    'account_deactivation' -- only 'general' does. Task 6
--    (request_account_deactivation, 20260819100000) already hit this and
--    settled on type='general' with 'kind':'account_deactivation' inside
--    metadata. review_account_deactivation_request below matches that
--    convention exactly, because Task 10's console screens will filter on it
--    and two different conventions across the same feature would break them.
--
-- 2. the cron-backstop auth context. deactivate_account's own header says it
--    is callable by "the platform admin (console) or the service role (the
--    cron backstop)", and the spec (s2.1) states the daily backstop calls
--    this function as "plain SQL. no edge function." -- i.e. a pg_cron job,
--    not a PostgREST request. Verified empirically 2026-08-19 by running
--    `select auth.uid(), auth.role(), current_user;` on this connection
--    (postgres, the same role a migration/cron job runs as): auth.uid() and
--    auth.role() are BOTH null -- there is no request.jwt.claims GUC at all
--    outside a PostgREST-proxied request, so auth.role() is never literally
--    the string 'service_role' for a plain-SQL cron caller. A guard written
--    as `is_platform_admin() or auth.role() = 'service_role'` would raise
--    'Not permitted.' on every single cron-triggered deactivation -- the one
--    caller the function exists to serve. Fixed by also accepting
--    `auth.uid() is null`, which is the correct signal for "no end-user
--    session at all" (a real signed-in user's JWT always carries a `sub`).
--    This does not widen who may call the function: deactivate_account is
--    granted to nobody but its owner (see the foot of this file), so the
--    only sessions that ever reach this line already have ambient authority
--    over the whole database (postgres itself, i.e. cron / migrations / the
--    Supabase SQL editor) or are a genuine platform admin. The same reasoning
--    applies to insert_audit_log(), which internally calls
--    require_platform_admin() and would otherwise abort the whole
--    deactivation (including the session revocations already applied in the
--    same transaction) on every cron run; the audit row is written directly
--    for that path, using the same columns insert_audit_log itself writes.
--
-- 3. audit_logs.target_type vocabulary. The planned SQL passed 'profiles' as
--    target_type into insert_audit_log() (and into the direct-insert
--    fallback for correction #2). audit_logs_target_type_check (verified
--    2026-08-19, and already the subject of one prior fix in this codebase,
--    20260815111000) admits only 'organization' | 'user' | 'serialToken' |
--    'seat' | 'seatRequest' | 'tokenRequest' | 'childAdmin' | 'system' --
--    'profiles' is not a member, so both audit writes would raise 23514 and
--    roll back the deactivation/reactivation that already happened in the
--    same transaction. Changed to 'user' throughout. The direct-insert
--    fallback's actor_platform_role also moved from the invented
--    'service_role' to 'system' for the same reason -- 'system' is precisely
--    the value 20260815111000 added to this same CHECK for a non-human actor.

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
  v_req   public.account_deactivation_requests;
  v_admin text;
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

  -- notification_type 'general' -- see the file header correction #1.
  -- 'account_deactivation' is not a member of notifications.type's CHECK
  -- constraint; 'kind' inside metadata carries it instead, matching
  -- request_account_deactivation (20260819100000/20260819105000).
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
end;
$$;

comment on function public.review_account_deactivation_request(uuid, boolean, text) is
  'Platform-admin approve/reject of a pending deactivation request. Rejects '
  'require a non-empty note. Notifies the requester either way via '
  'notification type=general / metadata.kind=account_deactivation (the '
  'literal type value is not in notifications.type''s CHECK constraint).';

-- ---------------------------------------------------------------------------
-- deactivate_account -- the act. Reversible, destroys nothing.
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
  -- Platform admin (console), the service role (a genuine service-role
  -- PostgREST/edge-function call, if one is ever added), OR a caller with no
  -- JWT context at all -- which is what the daily cron backstop actually is,
  -- per the file header correction #2. Nothing here widens the real boundary:
  -- this function is granted to nobody by name (see the foot of the file), so
  -- reaching this line at all already requires either a genuine platform
  -- admin's JWT or ambient database authority (cron / migrations / the SQL
  -- editor), which could bypass this check entirely regardless of its wording.
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

  -- A company owner must never end up deactivated: companies.user_id is NOT
  -- NULL-able in practice and an ownerless company has nobody who can act for
  -- it. request_account_deactivation refuses this at the front door; this is
  -- the same rule at the back door, because the cron job also calls here.
  if exists (select 1 from public.companies where user_id = v_uid) then
    raise exception 'That user owns a company and cannot be deactivated.'
      using errcode = 'MLD01';
  end if;

  -- Revoke the live session so the change takes effect now, not at next token
  -- expiry. NOTE the ::text cast -- see the file header.
  delete from auth.refresh_tokens where user_id = v_uid::text;
  delete from auth.sessions        where user_id = v_uid;

  -- The sign-in refusal. GoTrue's own switch, and ONE column to undo.
  -- auth.identities is NOT touched, the password is NOT scrambled, and
  -- deleted_at is NOT set: those are deletion mechanics, and this is not a
  -- deletion.
  update auth.users set banned_until = 'infinity' where id = v_uid;

  update public.employees set
    status     = 'inactive',
    updated_at = timezone('utc', now())
  where user_id = v_uid;

  -- public.profiles is deliberately NOT modified. display_name is what every
  -- historical trip, chat message and audit row renders through, and an
  -- account being inactive is a fact about access, not about who the person
  -- was.

  update public.account_deactivation_requests
     set status = 'deactivated', deactivated_at = timezone('utc', now())
   where user_id = v_uid and status in ('pending','approved')
  returning id into v_req;

  -- insert_audit_log's REAL signature, verified against production 2026-08-19:
  --   (p_action_type, p_target_type, p_target_id, p_target_name,
  --    p_organization_id, p_description, p_before_data, p_after_data)
  -- Eight parameters, the last two defaulted -- super_admin_set_company_status
  -- calls it with six, which is why six is known to work. p_organization_id is
  -- the COMPANY, not the user: passing a user id there would file every
  -- deactivation under an organisation that does not exist.
  --
  -- insert_audit_log() itself calls public.require_platform_admin(), which
  -- resolves auth.uid() -- null under the cron/plain-SQL path (file header
  -- correction #2), so routing through it there would raise and roll back
  -- everything already done above on every cron-triggered run. Use it only
  -- when a real admin session is present; otherwise write the row directly,
  -- matching insert_audit_log's own column shape exactly.
  --
  -- target_type = 'user', not 'profiles': audit_logs_target_type_check
  -- (verified 2026-08-19) only admits 'organization' | 'user' | 'serialToken'
  -- | 'seat' | 'seatRequest' | 'tokenRequest' | 'childAdmin' | 'system' --
  -- 'profiles' is not a member and the insert would raise 23514. This is the
  -- same class of vocabulary mismatch as 20260815111000's fix to this same
  -- table, and actor_platform_role = 'system' below is the value that fix
  -- added for exactly a non-human actor like the cron backstop.
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
  'employees.status = inactive. Never touches auth.identities, never '
  'scrambles the password, never sets auth.users.deleted_at, never writes '
  'public.profiles (spec s1.1). Callable by a platform admin or by the daily '
  'cron backstop, which runs as plain SQL with no JWT context at all -- see '
  'the file header for why the guard checks auth.uid() is null rather than '
  'auth.role() = ''service_role''.';

-- ---------------------------------------------------------------------------
-- reactivate_account -- the exact inverse
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
  -- Platform admin ONLY -- never the service role, and the cron job never
  -- calls this. Nothing should ever restore access automatically; removing
  -- access and granting it back are not symmetric risks.
  if not public.is_platform_admin() then
    raise exception 'Only a platform admin may reactivate an account.'
      using errcode = '42501';
  end if;

  select coalesce(nullif(btrim(p.display_name), ''), p.email),
         (select e.company_id from public.employees e where e.user_id = v_uid limit 1)
    into v_name, v_company_id
    from public.profiles p where p.id = v_uid;

  -- null, not a past timestamp. A past timestamp also permits sign-in, but
  -- null is what a never-banned account carries, so a reactivated account
  -- becomes indistinguishable from one that was never touched. Anything else
  -- leaves residue that a query filtering `banned_until is not null` misreads.
  update auth.users set banned_until = null where id = v_uid;

  -- Unconditionally 'active'. The only status this flow ever writes is
  -- 'inactive', and guessing at a prior state nobody recorded would be worse
  -- than a stated rule.
  update public.employees set status = 'active', updated_at = timezone('utc', now())
   where user_id = v_uid;

  update public.account_deactivation_requests
     set status = 'reactivated',
         reactivated_at = timezone('utc', now()),
         reactivated_by = auth.uid()
   where user_id = v_uid and status = 'deactivated';

  -- This path is platform-admin only (guarded above), so auth.uid() is
  -- always present here and insert_audit_log's internal
  -- require_platform_admin() always succeeds -- no branching needed, unlike
  -- deactivate_account.
  --
  -- target_type = 'user', not 'profiles' -- see the matching note in
  -- deactivate_account; audit_logs_target_type_check does not admit 'profiles'.
  perform public.insert_audit_log(
    'ACCOUNT_REACTIVATED', 'user', v_uid, v_name, v_company_id,
    'Account reactivated'
  );

  return jsonb_build_object('user_id', v_uid, 'status', 'reactivated');
end;
$$;

comment on function public.reactivate_account(uuid) is
  'The exact inverse of deactivate_account: banned_until back to NULL '
  '(never a past timestamp), employees.status back to active. Platform-admin '
  'only, never the cron backstop -- granting access back is not a symmetric '
  'risk to removing it.';

-- ---------------------------------------------------------------------------
-- list_account_deactivation_requests -- the console queue
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
         -- Active trips, counted down BOTH driver paths.
         --
         -- driver_assignments is the authoritative one (CLAUDE.md s4: driver
         -- screens resolve the truck through it precisely because 2nd+ drivers
         -- were invisible otherwise), and it keys on
         -- driver_assignments.driver_employee_id -> employees.id, NOT on a
         -- user id -- hence the join through employees.
         -- fleet_vehicles.driver_user_id is the legacy single-driver column and
         -- is still populated, so it is unioned in.
         --
         -- This chip is informational for a human reviewer. Over-reporting a
         -- blocker costs a glance; under-reporting one hides a driver who is
         -- mid-load, which is the entire reason the chip exists.
         (select count(distinct t.id)::int
            from public.trips t
           where t.status not in ('completed','cancelled')
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
  'active trips do not block a deactivation request.';

revoke execute on function public.review_account_deactivation_request(uuid, boolean, text) from public, anon;
revoke execute on function public.deactivate_account(uuid) from public, anon, authenticated;
revoke execute on function public.reactivate_account(uuid) from public, anon;
revoke execute on function public.list_account_deactivation_requests(text) from public, anon;
grant execute on function public.review_account_deactivation_request(uuid, boolean, text) to authenticated;
grant execute on function public.reactivate_account(uuid) to authenticated;
grant execute on function public.list_account_deactivation_requests(text) to authenticated;
-- deactivate_account is NOT granted to authenticated: it is reached by the
-- daily cron backstop (plain SQL, no JWT context) or by ambient database
-- authority (migrations / SQL editor); never directly by an admin's own
-- session in this task.
