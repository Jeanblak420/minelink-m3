-- Fix: "permission denied for table profiles (42501)" when saving a signature.
--
-- Root cause: `set_my_signature` (added in 20260712110000_profile_signatures.sql)
-- was declared SECURITY INVOKER, so its UPDATE on public.profiles runs as the
-- calling `authenticated` role. That role is only ever GRANTed SELECT on
-- public.profiles (canonical reset, line ~2424) — every other self-service
-- profile mutation in this app (update_my_company_profile,
-- update_my_employee_profile, …) is SECURITY DEFINER for exactly this reason.
-- An RLS policy (profiles_update_own) cannot substitute for the missing
-- table-level UPDATE privilege: Postgres requires BOTH. Result: the RPC threw
-- 42501 before RLS was ever evaluated.
--
-- Fix: bring set_my_signature in line with the codebase convention — make it
-- SECURITY DEFINER so it runs as the table owner. The body is still scoped to
-- `id = auth.uid()`, so a caller can only ever write their own row, and we do
-- NOT widen the REST surface by granting UPDATE on the table directly.

begin;

create or replace function public.set_my_signature(p_signature_path text)
returns void
language sql
security definer
set search_path = public
as $$
  update public.profiles
  set signature_url = p_signature_path,
      updated_at = timezone('utc', now())
  where id = (select auth.uid());
$$;

-- Postgres grants EXECUTE to PUBLIC by default; lock it back down to signed-in
-- users only (mirrors the original migration).
revoke all on function public.set_my_signature(text) from public;
revoke all on function public.set_my_signature(text) from anon;
grant execute on function public.set_my_signature(text) to authenticated;

commit;
