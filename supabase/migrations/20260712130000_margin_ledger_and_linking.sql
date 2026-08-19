-- Super-admin pricing / margin ledger + linking (CLAUDE.md §4).
--
-- On linking, the platform admin sets pricing by entering the agreed price per
-- ton and their own margin in ZAR. The app derives the transporter's price per
-- ton (agreed − margin). The margin is recorded in a super-admin-only ledger;
-- the transporter only ever sees their resulting price (stored on the dispatch),
-- never the admin's margin.

begin;

-- 1. Super-admin-only margin ledger.
create table if not exists public.margin_ledger (
  id uuid primary key default gen_random_uuid(),
  request_id uuid not null references public.transportation_requests(id) on delete cascade,
  supplier_company_id uuid references public.companies(id),
  agreed_price_per_ton numeric not null,
  admin_margin_per_ton numeric not null,
  transporter_price_per_ton numeric not null,
  currency text not null default 'ZAR',
  created_by uuid default auth.uid(),
  created_at timestamptz not null default timezone('utc', now())
);

alter table public.margin_ledger enable row level security;

drop policy if exists margin_ledger_admin_all on public.margin_ledger;
create policy margin_ledger_admin_all on public.margin_ledger
  for all to authenticated
  using (public.is_platform_admin())
  with check (public.is_platform_admin());

grant select, insert on public.margin_ledger to authenticated;

-- 2. The transporter's resulting price rides on the dispatch (never the margin).
alter table public.request_dispatches
  add column if not exists transporter_price_per_ton numeric;

-- 3. Atomic link + dispatch: set mine, record margin, price + create dispatches,
--    mark the request linked. Replaces the set_request_supplier + dispatch pair.
create or replace function public.link_and_dispatch_request(
  p_id uuid,
  p_supplier_company_id uuid,
  p_agreed_price numeric,
  p_admin_margin numeric,
  p_transporter_ids uuid[]
) returns transportation_requests
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_row public.transportation_requests;
  v_tid uuid;
  v_transporter_price numeric;
begin
  if not public.is_platform_admin() then
    raise exception 'Only the MineLink representative may link and dispatch requests';
  end if;
  if not exists (select 1 from public.transportation_requests where id = p_id) then
    raise exception 'Request % not found', p_id;
  end if;
  if p_supplier_company_id is null then
    raise exception 'Select the supplying mine first';
  end if;
  if p_transporter_ids is null or array_length(p_transporter_ids, 1) is null then
    raise exception 'Select at least one transporter to dispatch to';
  end if;
  if p_agreed_price is null or p_admin_margin is null then
    raise exception 'Enter the agreed price per ton and your margin';
  end if;
  if p_agreed_price < 0 or p_admin_margin < 0 then
    raise exception 'Price and margin must be zero or positive';
  end if;
  if p_admin_margin > p_agreed_price then
    raise exception 'Margin cannot exceed the agreed price';
  end if;

  v_transporter_price := p_agreed_price - p_admin_margin;

  insert into public.margin_ledger (
    request_id, supplier_company_id, agreed_price_per_ton,
    admin_margin_per_ton, transporter_price_per_ton, currency, created_by
  ) values (
    p_id, p_supplier_company_id, p_agreed_price,
    p_admin_margin, v_transporter_price, 'ZAR', auth.uid()
  );

  foreach v_tid in array p_transporter_ids loop
    insert into public.request_dispatches (
      request_id, transporter_company_id, dispatched_by, transporter_price_per_ton
    ) values (p_id, v_tid, auth.uid(), v_transporter_price)
    on conflict (request_id, transporter_company_id) do update
      set transporter_price_per_ton = excluded.transporter_price_per_ton;
  end loop;

  update public.transportation_requests set
    supplier_company_id = p_supplier_company_id,
    status = 'linked',
    reviewed_by = auth.uid(),
    reviewed_at = timezone('utc', now())
  where id = p_id
  returning * into v_row;

  return v_row;
end;
$function$;

revoke all on function public.link_and_dispatch_request(uuid, uuid, numeric, numeric, uuid[]) from public;
revoke all on function public.link_and_dispatch_request(uuid, uuid, numeric, numeric, uuid[]) from anon;
grant execute on function public.link_and_dispatch_request(uuid, uuid, numeric, numeric, uuid[]) to authenticated;

-- 4. Read the ledger (super-admin only).
create or replace function public.list_margin_ledger()
returns table (
  id uuid,
  request_id uuid,
  supplier_name text,
  agreed_price_per_ton numeric,
  admin_margin_per_ton numeric,
  transporter_price_per_ton numeric,
  currency text,
  created_at timestamptz
)
language sql
stable
security definer
set search_path to 'public'
as $function$
  select l.id, l.request_id, sc.company_name, l.agreed_price_per_ton,
    l.admin_margin_per_ton, l.transporter_price_per_ton, l.currency, l.created_at
  from public.margin_ledger l
  left join public.companies sc on sc.id = l.supplier_company_id
  where public.is_platform_admin()
  order by l.created_at desc;
$function$;

revoke all on function public.list_margin_ledger() from public;
revoke all on function public.list_margin_ledger() from anon;
grant execute on function public.list_margin_ledger() to authenticated;

commit;
