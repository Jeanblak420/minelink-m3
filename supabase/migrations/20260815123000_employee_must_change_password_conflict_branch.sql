-- 20260815123000_employee_must_change_password_conflict_branch.sql
--
-- S2-9 (G3) correction. 20260815122000 set `must_change_password` only on the
-- INSERT branch of `create_company_managed_employee`, reasoning that the
-- `on conflict do update` branch was "a re-link of an account whose password
-- is already its own".
--
-- That model of the flow was wrong, and the walk caught it: creating a real
-- employee as the Iron Hills owner left the flag **false**.
--
-- `auth.users` carries an `on_auth_user_created` trigger that inserts the
-- profile row. `company-user-admin` calls `auth.admin.createUser` first and
-- this RPC second, so by the time it runs **the profile always exists** and
-- the INSERT branch never executes. The fix was a no-op on the only path that
-- reaches it.
--
-- There is also no re-link case to protect: the RPC refuses outright if an
-- `employees` row already exists for the target, so it only ever runs for a
-- brand-new managed employee whose password the admin has just chosen. Both
-- branches should set the flag.
--
-- Rewritten by substitution rather than retyped, per CLAUDE.md §6 — the body
-- is 4.5 KB and the change is two lines. The count is asserted, so a no-op
-- raises instead of passing quietly.
do $$
declare
  v_def text;
  v_new text;
  v_anchor text := '    display_name = excluded.display_name,';
  v_repl text := '    display_name = excluded.display_name,'
               || chr(10)
               || '    -- S2-9: the admin chose this password and knows it. Set on the'
               || chr(10)
               || '    -- conflict branch too, because on_auth_user_created has already'
               || chr(10)
               || '    -- inserted the profile by the time this RPC runs, so the INSERT'
               || chr(10)
               || '    -- branch above never executes on the real path.'
               || chr(10)
               || '    must_change_password = true,';
  v_hits int;
begin
  select pg_get_functiondef(p.oid) into v_def
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public' and p.proname = 'create_company_managed_employee';

  if v_def is null then
    raise exception 'create_company_managed_employee not found';
  end if;

  v_hits := (length(v_def) - length(replace(v_def, v_anchor, ''))) / length(v_anchor);
  if v_hits <> 1 then
    raise exception 'expected exactly 1 conflict-branch anchor, found %', v_hits;
  end if;

  v_new := replace(v_def, v_anchor, v_repl);
  execute v_new;
end
$$;

comment on function public.create_company_managed_employee(uuid, text, text, text, text) is
  'Creates an admin-managed employee. Sets profiles.must_change_password = true on BOTH the insert and the conflict-update path (S2-9, 2026-08-15): the admin chose the password and knows it, and on_auth_user_created has already created the profile row by the time this runs, so only the conflict path is ever taken. Existing employees are deliberately not back-filled.';
