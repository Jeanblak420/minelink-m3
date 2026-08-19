-- ============================================================================
-- list_company_member_presence — fail loudly, not emptily (follow-up to
-- 20260811120000)
-- ----------------------------------------------------------------------------
-- The original put the authorization test in the WHERE clause, so an
-- unauthorized caller received **zero rows rather than an error**. That is the
-- exact shape of the bug the function was written to fix: the screen's old
-- direct `profiles` read returned nothing to a company manager and rendered
-- every colleague "offline", because a silent empty read is indistinguishable
-- from a true empty result.
--
-- It is contained today — the nav tree and the router guard both restrict the
-- Employee Register to owner/admin/management, so no unauthorized caller
-- reaches it. But containment that depends on two client-side gates staying
-- correct is not the same as a server that says no. If either drifts,
-- "everyone offline" comes straight back one layer down, and it would look
-- like a quiet product bug rather than an authorization failure.
--
-- So: raise. `42501` (insufficient_privilege) is what PostgREST maps to HTTP
-- 403, which means the Dart layer surfaces it through the same error path as
-- any other denial rather than rendering a confident empty register.
--
-- Behaviour is unchanged for every legitimate caller: an owner, an active
-- non-dismissed admin or management user, and the platform admin all still get
-- their company's rows. Only the denial changes — from `[]` to a 403.
-- ============================================================================

create or replace function public.list_company_member_presence(
  p_company_id uuid
)
returns table (
  user_id uuid,
  last_seen_at timestamptz,
  has_signature boolean
)
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  -- P7-33, enforced in the database. `is_company_manager` is exactly owner +
  -- active, non-dismissed admin/management.
  if not (
    public.is_company_manager(p_company_id)
    or public.is_platform_admin()
  ) then
    raise exception
      'not authorised to read member presence for company %', p_company_id
      using errcode = '42501';
  end if;

  return query
    select
      p.id,
      p.last_seen_at,
      -- Never the URL itself: the register only needs to show WHO is missing
      -- a signature (P7-35).
      (p.signature_url is not null and p.signature_url <> '')
    from public.employees e
    join public.profiles p on p.id = e.user_id
    where e.company_id = p_company_id;
end;
$$;

comment on function public.list_company_member_presence(uuid) is
  'Employee Register presence, company-scoped. Returns last_seen_at and a '
  'has_signature flag for one company''s employees, to a company owner/admin/'
  'management user or the platform admin; RAISES 42501 for anyone else rather '
  'than returning an empty set. Exists because profiles_select_own restricts '
  'profiles to the caller''s own row, so a manager reading the table directly '
  'gets nothing and every colleague renders offline -- a fabricated status. '
  'Returning two facts rather than widening the profiles policy keeps '
  'platform_role, must_change_password, metadata, email and signature_url shut.';

-- `create or replace` preserves grants, but re-state them so this file stands
-- alone and can be read without the earlier one. Never PUBLIC: anon inherits
-- from it, which is how 27 functions were callable unauthenticated before
-- 20260810161500.
revoke execute on function public.list_company_member_presence(uuid) from public;
grant  execute on function public.list_company_member_presence(uuid) to authenticated;
