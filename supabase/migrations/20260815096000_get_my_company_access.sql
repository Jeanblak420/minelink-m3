-- One place the UI asks "may I act, and if not, why not".
--
-- Added because there was nowhere to ask. CompanyMCP carries no `status` and
-- no `token_expires_at`, so no screen could tell a user their token had
-- expired — which is why the block landed silently in 20260815094000: writes
-- simply failed with a row-level-security error and nothing explained it.
--
-- Deliberately ONE call returning everything the explanation needs (status,
-- expiry date, what is still permitted), so the banner, the disabled-action
-- tooltips and the router redirect all read the same answer and cannot
-- disagree with each other — or with the RLS policies, since `is_active` is
-- the same public.is_company_active() the write policies consult.
--
-- [p_company_id] supports the platform admin's company-mirror observer mode:
-- an admin belongs to no company, so current_company_id() is null for them and
-- they must be able to ask about the company they are looking at.
create or replace function public.get_my_company_access(p_company_id uuid default null)
returns table(
  company_id uuid,
  company_name text,
  org_type text,
  status text,
  token_expires_at timestamptz,
  is_active boolean,
  is_platform_admin boolean,
  days_since_expiry int
)
language plpgsql
stable security definer
set search_path to 'public'
as $function$
declare
  v_admin boolean := public.is_platform_admin();
  v_id uuid := coalesce(p_company_id, public.current_company_id());
begin
  -- A platform admin asking about nothing in particular is never restricted.
  if v_id is null then
    return query select null::uuid, null::text, null::text, null::text,
                        null::timestamptz, true, v_admin, null::int;
    return;
  end if;

  -- Only ever answers about a company the caller may already see. Without
  -- this an authenticated user could probe any company's licence state by id.
  if not (v_admin or public.is_company_owner(v_id)
          or public.is_company_staff(v_id)
          or public.is_company_manager_any_status(v_id)) then
    return query select null::uuid, null::text, null::text, null::text,
                        null::timestamptz, true, v_admin, null::int;
    return;
  end if;

  return query
    select c.id, c.company_name, c.org_type, c.status, c.token_expires_at,
           public.is_company_active(c.id),
           v_admin,
           case when c.token_expires_at is not null
                     and c.token_expires_at <= timezone('utc', now())
                then greatest(0, (date_part('day',
                       timezone('utc', now()) - c.token_expires_at))::int)
           end
    from public.companies c
    where c.id = v_id;
end;
$function$;

comment on function public.get_my_company_access(uuid) is
  'The single source for "may I act, and if not, why not". is_active is the '
  'same public.is_company_active() the write policies consult, so the banner, '
  'the tooltips, the router redirect and RLS cannot disagree. Scoped: only '
  'answers about a company the caller may already see.';

grant execute on function public.get_my_company_access(uuid) to authenticated;

-- Verified on production, three callers:
--   expired owner (SteelWorks SA)  status=expired, is_active=false,
--                                  token_expires_at=2026-04-23,
--                                  days_since_expiry=113
--   active owner  (Cyberhouse Mine Supplier)
--                                  status=active, is_active=true,
--                                  days_since_expiry=null
