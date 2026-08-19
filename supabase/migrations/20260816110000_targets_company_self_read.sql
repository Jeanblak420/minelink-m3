-- A company could not read its own target.
--
-- `assert_target_scope` demanded `is_super_admin()` for EVERY scope, including
-- `company` keyed on the caller's own company. The mine dashboard's "Tons out"
-- band asks for exactly that (`get_targets_state(scope => 'company',
-- company_id => <own>)`), so the call returned 42501 for every company user and
-- the band rendered `No target set` — a sentence that was indistinguishable
-- from the truth and would have stayed on screen unchanged after somebody set
-- a target. That is the same "an absence nobody chose looks like a decision"
-- fault the targets system was rewritten to remove, reappearing on the company
-- side of the same feature.
--
-- The split below is the whole fix: shape validation is one function, and the
-- two authorities are separate. Writers are untouched.

-- Shape only. No authority. Extracted verbatim from `assert_target_scope` so
-- the read path and the write path cannot drift on what a valid scope key is.
create or replace function public.assert_target_scope_shape(
  p_scope text,
  p_org_type text,
  p_company_id uuid
) returns void
language plpgsql
stable
security definer
set search_path to 'public'
as $$
begin
  if p_scope = 'platform' then
    if p_org_type is not null or p_company_id is not null then
      raise exception 'platform scope takes no key';
    end if;
  elsif p_scope = 'org_type' then
    if p_org_type !~ '^(mineSupplier|buyer|transporter)$' then
      raise exception 'invalid org type %', coalesce(p_org_type, 'null');
    end if;
    if p_company_id is not null then
      raise exception 'org_type scope takes no company';
    end if;
  elsif p_scope = 'company' then
    if p_company_id is null then
      raise exception 'company scope needs a company';
    end if;
    if not exists (select 1 from public.companies where id = p_company_id) then
      raise exception 'unknown company %', p_company_id;
    end if;
    if p_org_type is not null then
      raise exception 'company scope takes no org type';
    end if;
  else
    raise exception 'invalid scope %', coalesce(p_scope, 'null');
  end if;
end
$$;

comment on function public.assert_target_scope_shape(text, text, uuid) is
  'Validates a target scope key. Carries NO authority check — callers add their '
  'own. Split out of assert_target_scope so read and write share one definition '
  'of a valid key.';

-- WRITE authority. Unchanged behaviour: super admin only, checked before shape
-- so a non-admin cannot probe which company ids exist.
create or replace function public.assert_target_scope(
  p_scope text,
  p_org_type text,
  p_company_id uuid
) returns void
language plpgsql
stable
security definer
set search_path to 'public'
as $$
begin
  if not public.is_super_admin() then
    raise exception 'forbidden' using errcode = 'insufficient_privilege';
  end if;
  perform public.assert_target_scope_shape(p_scope, p_org_type, p_company_id);
end
$$;

comment on function public.assert_target_scope(text, text, uuid) is
  'WRITE authority for the targets system: super admin only. Used by '
  'set_monthly_target / set_cycle_draft / lock_target_cycle / '
  'start_new_target_cycle. Reads go through assert_target_scope_read.';

-- READ authority. A super admin reads every scope. Everyone else reads exactly
-- one thing: their own company.
--
-- Authority is decided BEFORE shape, so an unprivileged caller cannot use the
-- 'unknown company %' branch to discover which company ids exist.
--
-- `is_company_staff` rather than `is_company_staff_active` is deliberate. An
-- expired company is read-only (S2-10), not blind, and gating this on active
-- status would put an expired company's dashboard straight back to reporting
-- 'No target set' against a target that exists — the exact defect being fixed
-- here, one status value further along. Reading a commitment is not acting on
-- one. `is_company_staff` already covers both the company account itself
-- (is_company_owner) and its active, undismissed employees.
create or replace function public.assert_target_scope_read(
  p_scope text,
  p_org_type text,
  p_company_id uuid
) returns void
language plpgsql
stable
security definer
set search_path to 'public'
as $$
begin
  if not (
    public.is_super_admin()
    or (
      p_scope = 'company'
      and p_company_id is not null
      and public.is_company_staff(p_company_id)
    )
  ) then
    raise exception 'forbidden' using errcode = 'insufficient_privilege';
  end if;
  perform public.assert_target_scope_shape(p_scope, p_org_type, p_company_id);
end
$$;

comment on function public.assert_target_scope_read(text, text, uuid) is
  'READ authority for the targets system. Super admin: every scope. Anyone '
  'else: the company scope of a company they are staff at, and nothing else. '
  'A company may see the target it is measured against; only the platform '
  'admin may set one.';

revoke all on function public.assert_target_scope_shape(text, text, uuid) from public;
revoke all on function public.assert_target_scope_read(text, text, uuid) from public;
grant execute on function public.assert_target_scope_shape(text, text, uuid) to authenticated;
grant execute on function public.assert_target_scope_read(text, text, uuid) to authenticated;
