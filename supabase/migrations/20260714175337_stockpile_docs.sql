-- Stockpile documents (AUDIT_FINDINGS item 2): lab-result PDFs + pictures a
-- Supervisor/mine attaches to a stockpile. The two "Upload results" / "Upload
-- picture" actions were dead "coming soon" stubs; this gives them real storage.
--
-- Files reuse the private `request_docs` bucket under
-- `<supplier_company_id>/stockpiles/<stockpile_id>/<uuid>_<name>`, so the
-- existing company-folder storage RLS (20260712190000_request_docs.sql) applies
-- unchanged. This table only holds the metadata (which stockpile, kind, object
-- path, original name).
--
-- Additive only. Reuses helpers is_company_staff() and
-- is_company_stockpile_writer() from the canonical platform schema.

begin;

create table if not exists public.stockpile_docs (
  id uuid primary key default gen_random_uuid(),
  stockpile_id uuid not null references public.stockpiles (id) on delete cascade,
  kind text not null check (kind in ('lab_result', 'picture')),
  storage_path text not null,
  file_name text not null,
  uploaded_by uuid references auth.users (id) on delete set null,
  created_at timestamptz not null default timezone('utc', now())
);
create index if not exists stockpile_docs_stockpile_idx
  on public.stockpile_docs (stockpile_id, created_at desc);

alter table public.stockpile_docs enable row level security;

-- Read: any staff of the parent stockpile's supplier or buyer company
-- (mirrors stockpile_transactions select).
drop policy if exists stockpile_docs_select on public.stockpile_docs;
create policy stockpile_docs_select on public.stockpile_docs
for select to authenticated
using (
  exists (
    select 1 from public.stockpiles s
    where s.id = stockpile_docs.stockpile_id
      and (public.is_company_staff(s.supplier_company_id)
        or public.is_company_staff(s.buyer_company_id))
  )
);

-- Write/delete: a stockpile writer (supplier manager or an active
-- supervisorForeman) of the parent stockpile's supplier company — the same
-- predicate that gates stockpile writes (20260713000000_audit_fixes_round.sql).
drop policy if exists stockpile_docs_insert on public.stockpile_docs;
create policy stockpile_docs_insert on public.stockpile_docs
for insert to authenticated
with check (
  exists (
    select 1 from public.stockpiles s
    where s.id = stockpile_docs.stockpile_id
      and public.is_company_stockpile_writer(s.supplier_company_id)
  )
);

drop policy if exists stockpile_docs_delete on public.stockpile_docs;
create policy stockpile_docs_delete on public.stockpile_docs
for delete to authenticated
using (
  exists (
    select 1 from public.stockpiles s
    where s.id = stockpile_docs.stockpile_id
      and public.is_company_stockpile_writer(s.supplier_company_id)
  )
);

grant select, insert, delete on public.stockpile_docs to authenticated;

commit;
