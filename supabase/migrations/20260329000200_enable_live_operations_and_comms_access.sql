create or replace function public.has_company_role(
  target_company_id uuid,
  allowed_roles text[]
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.employees e
    where e.company_id = target_company_id
      and e.user_id = auth.uid()
      and e.role = any (allowed_roles)
      and e.status = 'active'
      and e.is_dismissed = false
  );
$$;

create or replace function public.can_access_company_broadcast(message_payload jsonb)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select
    case
      when nullif(message_payload ->> 'company_id', '') is null then false
      else
        public.is_company_owner((message_payload ->> 'company_id')::uuid)
        or public.is_company_staff((message_payload ->> 'company_id')::uuid)
    end;
$$;

create or replace function public.can_publish_company_broadcast(message_payload jsonb)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select
    case
      when nullif(message_payload ->> 'company_id', '') is null then false
      else
        public.is_company_owner((message_payload ->> 'company_id')::uuid)
        or public.is_company_manager((message_payload ->> 'company_id')::uuid)
    end;
$$;

drop policy if exists broadcast_messages_select_authenticated on public.broadcast_messages;
drop policy if exists broadcast_messages_insert_authenticated on public.broadcast_messages;

drop policy if exists broadcast_messages_select_company_scope on public.broadcast_messages;
create policy broadcast_messages_select_company_scope
on public.broadcast_messages
for select
to authenticated
using (public.can_access_company_broadcast(payload));

drop policy if exists broadcast_messages_insert_company_scope on public.broadcast_messages;
create policy broadcast_messages_insert_company_scope
on public.broadcast_messages
for insert
to authenticated
with check (
  created_by = (select auth.uid())
  and public.can_publish_company_broadcast(payload)
);

drop policy if exists weighbridge_records_company_staff on public.weighbridge_records;
drop policy if exists security_incidents_company_staff on public.security_incidents;
drop policy if exists gate_checks_company_staff on public.gate_checks;

drop policy if exists weighbridge_records_select_company_staff on public.weighbridge_records;
create policy weighbridge_records_select_company_staff
on public.weighbridge_records
for select
to authenticated
using (public.is_company_staff(company_id));

drop policy if exists weighbridge_records_insert_authorized on public.weighbridge_records;
create policy weighbridge_records_insert_authorized
on public.weighbridge_records
for insert
to authenticated
with check (
  public.is_company_manager(company_id)
  or public.has_company_role(company_id, array['controllerWB'])
);

drop policy if exists weighbridge_records_update_authorized on public.weighbridge_records;
create policy weighbridge_records_update_authorized
on public.weighbridge_records
for update
to authenticated
using (
  public.is_company_manager(company_id)
  or public.has_company_role(company_id, array['controllerWB'])
)
with check (
  public.is_company_manager(company_id)
  or public.has_company_role(company_id, array['controllerWB'])
);

drop policy if exists weighbridge_records_delete_managers on public.weighbridge_records;
create policy weighbridge_records_delete_managers
on public.weighbridge_records
for delete
to authenticated
using (public.is_company_manager(company_id));

drop policy if exists security_incidents_select_company_staff on public.security_incidents;
create policy security_incidents_select_company_staff
on public.security_incidents
for select
to authenticated
using (public.is_company_staff(company_id));

drop policy if exists security_incidents_insert_authorized on public.security_incidents;
create policy security_incidents_insert_authorized
on public.security_incidents
for insert
to authenticated
with check (
  public.is_company_manager(company_id)
  or public.has_company_role(company_id, array['security'])
);

drop policy if exists security_incidents_update_authorized on public.security_incidents;
create policy security_incidents_update_authorized
on public.security_incidents
for update
to authenticated
using (
  public.is_company_manager(company_id)
  or public.has_company_role(company_id, array['security'])
)
with check (
  public.is_company_manager(company_id)
  or public.has_company_role(company_id, array['security'])
);

drop policy if exists security_incidents_delete_managers on public.security_incidents;
create policy security_incidents_delete_managers
on public.security_incidents
for delete
to authenticated
using (public.is_company_manager(company_id));

drop policy if exists gate_checks_select_company_staff on public.gate_checks;
create policy gate_checks_select_company_staff
on public.gate_checks
for select
to authenticated
using (public.is_company_staff(company_id));

drop policy if exists gate_checks_insert_authorized on public.gate_checks;
create policy gate_checks_insert_authorized
on public.gate_checks
for insert
to authenticated
with check (
  public.is_company_manager(company_id)
  or public.has_company_role(company_id, array['security'])
);

drop policy if exists gate_checks_update_authorized on public.gate_checks;
create policy gate_checks_update_authorized
on public.gate_checks
for update
to authenticated
using (
  public.is_company_manager(company_id)
  or public.has_company_role(company_id, array['security'])
)
with check (
  public.is_company_manager(company_id)
  or public.has_company_role(company_id, array['security'])
);

drop policy if exists gate_checks_delete_managers on public.gate_checks;
create policy gate_checks_delete_managers
on public.gate_checks
for delete
to authenticated
using (public.is_company_manager(company_id));
