-- Phase 4/6 backbone — Buyer request → Representative review → dispatch (§7.5, §8).
-- Additive. Reuses is_company_staff/is_company_manager/is_platform_admin().

------------------------------------------------------------------------------
-- 1. Requests (transportation / product / buyer queues share one table).
------------------------------------------------------------------------------
create table if not exists public.transportation_requests (
  id uuid primary key default gen_random_uuid(),
  buyer_company_id uuid not null references public.companies (id) on delete cascade,
  created_by uuid references auth.users (id) on delete set null,
  request_type text not null default 'transportation'
    check (request_type in ('transportation','product','buyer')),
  status text not null default 'submitted'
    check (status in ('submitted','under_review','sent_back','accepted','declined','dispatched')),

  -- Controlled inputs (§7.5).
  payment_terms text,            -- 50/50 | Daily | 7 days | 14 days | 30 days | 60 days
  diesel text,                   -- On account | On transporter
  operating_hours_24h boolean not null default false,
  operating_start text,          -- 'HH:MM' (null when 24h)
  operating_end text,            -- 'HH:MM' (null when 24h)
  starting_date date,            -- null when ongoing; earliest = tomorrow (app-enforced)
  is_ongoing boolean not null default false,

  -- Free-text fields.
  loading_point text,
  offloading_point text,
  commodity text,
  distance text,
  rate text,
  tons_available text,
  contract_duration text,
  num_slots text,
  route_notes text,

  -- Review trail.
  admin_notes text,              -- representative's send-back / decision note
  reviewed_by uuid references auth.users (id) on delete set null,
  reviewed_at timestamptz,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);
create index if not exists transportation_requests_buyer_idx
  on public.transportation_requests (buyer_company_id);
create index if not exists transportation_requests_status_idx
  on public.transportation_requests (status);
create index if not exists transportation_requests_type_idx
  on public.transportation_requests (request_type);

create trigger transportation_requests_updated_at
before update on public.transportation_requests
for each row execute function public.set_updated_at();

------------------------------------------------------------------------------
-- 2. Dispatches — which transporter(s) a request was sent to on accept (§8.3/8.4).
------------------------------------------------------------------------------
create table if not exists public.request_dispatches (
  id uuid primary key default gen_random_uuid(),
  request_id uuid not null references public.transportation_requests (id) on delete cascade,
  transporter_company_id uuid not null references public.companies (id) on delete cascade,
  status text not null default 'dispatched'
    check (status in ('dispatched','accepted','declined')),
  dispatched_by uuid references auth.users (id) on delete set null,
  dispatched_at timestamptz not null default timezone('utc', now()),
  unique (request_id, transporter_company_id)
);
create index if not exists request_dispatches_request_idx
  on public.request_dispatches (request_id);
create index if not exists request_dispatches_transporter_idx
  on public.request_dispatches (transporter_company_id);

------------------------------------------------------------------------------
-- 3. RLS.
------------------------------------------------------------------------------
alter table public.transportation_requests enable row level security;
alter table public.request_dispatches enable row level security;

-- Requests: buyer staff see/manage their own; platform admin sees/manages all.
create policy transportation_requests_select on public.transportation_requests
for select to authenticated
using (public.is_company_staff(buyer_company_id) or public.is_platform_admin());

create policy transportation_requests_insert on public.transportation_requests
for insert to authenticated
with check (public.is_company_staff(buyer_company_id));

create policy transportation_requests_update on public.transportation_requests
for update to authenticated
using (public.is_company_staff(buyer_company_id) or public.is_platform_admin())
with check (public.is_company_staff(buyer_company_id) or public.is_platform_admin());

create policy transportation_requests_delete on public.transportation_requests
for delete to authenticated
using (public.is_company_manager(buyer_company_id) or public.is_platform_admin());

-- Dispatches: admin manages; transporter sees its own; buyer sees its request's.
create policy request_dispatches_select on public.request_dispatches
for select to authenticated
using (
  public.is_platform_admin()
  or public.is_company_staff(transporter_company_id)
  or exists (
    select 1 from public.transportation_requests r
    where r.id = request_dispatches.request_id
      and public.is_company_staff(r.buyer_company_id)
  )
);
create policy request_dispatches_insert on public.request_dispatches
for insert to authenticated
with check (public.is_platform_admin());
create policy request_dispatches_update on public.request_dispatches
for update to authenticated
using (public.is_platform_admin() or public.is_company_staff(transporter_company_id))
with check (public.is_platform_admin() or public.is_company_staff(transporter_company_id));

grant select, insert, update, delete on public.transportation_requests to authenticated;
grant select, insert, update, delete on public.request_dispatches to authenticated;

------------------------------------------------------------------------------
-- 4. RPCs — representative review + dispatch (§8.3/8.4).
------------------------------------------------------------------------------

-- Representative reviews a request: under_review | sent_back | accepted | declined.
create or replace function public.review_transportation_request(
  p_id uuid,
  p_action text,
  p_notes text default null
)
returns public.transportation_requests
language plpgsql security definer set search_path = public as $$
declare v_row public.transportation_requests;
begin
  if not public.is_platform_admin() then
    raise exception 'Only the MineLink representative may review requests';
  end if;
  if p_action not in ('under_review','sent_back','accepted','declined') then
    raise exception 'Invalid review action %', p_action;
  end if;
  update public.transportation_requests set
    status = p_action,
    admin_notes = coalesce(p_notes, admin_notes),
    reviewed_by = auth.uid(),
    reviewed_at = timezone('utc', now())
  where id = p_id
  returning * into v_row;
  if not found then raise exception 'Request % not found', p_id; end if;
  return v_row;
end;
$$;

-- Dispatch an accepted request to the chosen transporter(s) (§8.4).
create or replace function public.dispatch_transportation_request(
  p_id uuid,
  p_transporter_ids uuid[]
)
returns public.transportation_requests
language plpgsql security definer set search_path = public as $$
declare
  v_row public.transportation_requests;
  v_tid uuid;
begin
  if not public.is_platform_admin() then
    raise exception 'Only the MineLink representative may dispatch requests';
  end if;
  if p_transporter_ids is null or array_length(p_transporter_ids, 1) is null then
    raise exception 'Select at least one transporter to dispatch to';
  end if;
  foreach v_tid in array p_transporter_ids loop
    insert into public.request_dispatches (request_id, transporter_company_id, dispatched_by)
    values (p_id, v_tid, auth.uid())
    on conflict (request_id, transporter_company_id) do nothing;
  end loop;
  update public.transportation_requests set
    status = 'dispatched',
    reviewed_by = auth.uid(),
    reviewed_at = timezone('utc', now())
  where id = p_id
  returning * into v_row;
  if not found then raise exception 'Request % not found', p_id; end if;
  return v_row;
end;
$$;

grant execute on function public.review_transportation_request(uuid, text, text) to authenticated;
grant execute on function public.dispatch_transportation_request(uuid, uuid[]) to authenticated;
