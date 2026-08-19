-- The rest of the objects that existed in production with NO migration file.
--
-- Companion to `20260510184000_seat_management_objects_that_had_no_file.sql`,
-- written 2026-08-18 after the schema diff that the first repair made possible.
-- Getting the replay to APPLY its files was never the finish line: "which files
-- errored" and "what is actually missing" are different questions, and only the
-- second one is the answer. Comparing the rebuilt database against production
-- found 68 of 68 tables but a delta of seven functions, and one column that no
-- migration in this repo ever adds.
--
-- Everything here is read back from the live catalog on 2026-08-18.
--
--   organization_seats.role_binding
--       No file adds it. `20260815115000_seat_role_vocabulary_supervisor`
--       constrains it and died on a rebuild with
--           42703  column "role_binding" does not exist
--       and `20260812090000_org_type_role_matrix_triggers` reads it in a
--       trigger body, which resolves at run time and so said nothing.
--
--   can_access_company_broadcast(jsonb)
--   can_publish_company_broadcast(jsonb)
--   get_user_company_id()
--       Present in production, created by no file. Nothing FAILED without
--       them — they are absent from a rebuild in silence, which is why only a
--       schema diff finds this class and no replay ever will.
--
-- WHY THIS STAMP. `organization_seats` arrives at 20260510181500, and the two
-- broadcast functions are LANGUAGE SQL, whose bodies Postgres validates when
-- the function is created — so `is_company_owner`, `is_company_staff` and
-- `is_company_manager` must already exist. All three come from the canonical
-- reset at 20260327000100. This file sits after the latest of those.
--
-- That distinction is the one that cost two replays on the previous repair: a
-- LANGUAGE SQL body constrains the stamp, a plpgsql body does not, and an RLS
-- policy expression does. Same file, three different rules.

begin;

-- ------------------------------------------------------------ the column

alter table public.organization_seats
  add column if not exists role_binding text;

comment on column public.organization_seats.role_binding is
  'Optional employee role this seat is bound to. Reconstructed 2026-08-18 — '
  'reached production with no migration file, so a cold replay could not '
  'build it and the constraint added by 20260815115000 had nothing to bind.';

-- ----------------------------------------------------------- the functions

create or replace function public.get_user_company_id()
returns uuid
language sql
stable
security definer
set search_path to ''
as $$
  select company_id from public.employees where user_id = auth.uid() limit 1;
$$;

create or replace function public.can_access_company_broadcast(
  message_payload jsonb)
returns boolean
language sql
stable
security definer
set search_path to 'public'
as $$
  select
    case
      when nullif(message_payload ->> 'company_id', '') is null then false
      else
        public.is_company_owner((message_payload ->> 'company_id')::uuid)
        or public.is_company_staff((message_payload ->> 'company_id')::uuid)
    end;
$$;

create or replace function public.can_publish_company_broadcast(
  message_payload jsonb)
returns boolean
language sql
stable
security definer
set search_path to 'public'
as $$
  select
    case
      when nullif(message_payload ->> 'company_id', '') is null then false
      else
        public.is_company_owner((message_payload ->> 'company_id')::uuid)
        or public.is_company_manager((message_payload ->> 'company_id')::uuid)
    end;
$$;

commit;
