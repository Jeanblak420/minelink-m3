begin;

create or replace function public.get_runtime_platform_status()
returns jsonb
language plpgsql
security definer
stable
set search_path = public
as $$
declare
  missing_capabilities text[] := array[]::text[];
  required_realtime_tables text[] := array[
    'profiles',
    'companies',
    'employees',
    'employee_status_history',
    'notifications',
    'fleet_vehicles',
    'chat_rooms',
    'chat_messages',
    'broadcast_messages',
    'minerals',
    'transactions',
    'weighbridge_records',
    'mineral_loads',
    'security_incidents',
    'gate_checks'
  ];
  required_table_name text;
begin
  if not exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and information_schema.columns.table_name = 'fleet_vehicles'
      and column_name = 'is_active'
  ) then
    missing_capabilities := array_append(
      missing_capabilities,
      'fleet_vehicles.is_active'
    );
  end if;

  if not exists (
    select 1
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname = 'create_actioned_notification'
  ) then
    missing_capabilities := array_append(
      missing_capabilities,
      'rpc:create_actioned_notification'
    );
  end if;

  if not exists (
    select 1
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname = 'mark_all_notifications_read'
  ) then
    missing_capabilities := array_append(
      missing_capabilities,
      'rpc:mark_all_notifications_read'
    );
  end if;

  if not exists (
    select 1
    from storage.buckets
    where id = 'employee_assets'
      and public = false
  ) then
    missing_capabilities := array_append(
      missing_capabilities,
      'storage:employee_assets_private'
    );
  end if;

  if not exists (
    select 1
    from storage.buckets
    where id = 'chat_files'
      and public = false
  ) then
    missing_capabilities := array_append(
      missing_capabilities,
      'storage:chat_files_private'
    );
  end if;

  foreach required_table_name in array required_realtime_tables
  loop
    if not exists (
      select 1
      from pg_publication_tables
      where pubname = 'supabase_realtime'
        and schemaname = 'public'
        and tablename = required_table_name
    ) then
      missing_capabilities := array_append(
        missing_capabilities,
        'realtime:' || required_table_name
      );
    end if;

    if not exists (
      select 1
      from pg_class c
      join pg_namespace n on n.oid = c.relnamespace
      where n.nspname = 'public'
        and c.relname = required_table_name
        and c.relreplident = 'f'
    ) then
      missing_capabilities := array_append(
        missing_capabilities,
        'replica_identity:' || required_table_name
      );
    end if;
  end loop;

  return jsonb_build_object(
    'ready',
    cardinality(missing_capabilities) = 0,
    'missing_capabilities',
    to_jsonb(missing_capabilities),
    'profiles_in_realtime',
    exists (
      select 1
      from pg_publication_tables
      where pubname = 'supabase_realtime'
        and schemaname = 'public'
        and tablename = 'profiles'
    ),
    'operations_realtime_hardened',
    not exists (
      select 1
      from unnest(array[
        'minerals',
        'transactions',
        'weighbridge_records',
        'mineral_loads',
        'security_incidents',
        'gate_checks'
      ]) as required_table(table_name)
      where not exists (
        select 1
        from pg_class c
        join pg_namespace n on n.oid = c.relnamespace
        where n.nspname = 'public'
          and c.relname = required_table.table_name
          and c.relreplident = 'f'
      )
    ),
    'private_employee_assets',
    exists (
      select 1 from storage.buckets
      where id = 'employee_assets' and public = false
    ),
    'private_chat_files',
    exists (
      select 1 from storage.buckets
      where id = 'chat_files' and public = false
    )
  );
end;
$$;

grant execute on function public.get_runtime_platform_status() to anon, authenticated;

alter table public.profiles replica identity full;
alter table public.companies replica identity full;
alter table public.employees replica identity full;
alter table public.employee_status_history replica identity full;
alter table public.notifications replica identity full;
alter table public.fleet_vehicles replica identity full;
alter table public.chat_rooms replica identity full;
alter table public.chat_messages replica identity full;
alter table public.broadcast_messages replica identity full;
alter table public.minerals replica identity full;
alter table public.transactions replica identity full;
alter table public.weighbridge_records replica identity full;
alter table public.mineral_loads replica identity full;
alter table public.security_incidents replica identity full;
alter table public.gate_checks replica identity full;

do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    alter publication supabase_realtime set table
      public.profiles,
      public.companies,
      public.employees,
      public.employee_status_history,
      public.notifications,
      public.fleet_vehicles,
      public.chat_rooms,
      public.chat_messages,
      public.broadcast_messages,
      public.minerals,
      public.transactions,
      public.weighbridge_records,
      public.mineral_loads,
      public.security_incidents,
      public.gate_checks;
  end if;
end;
$$;

commit;
