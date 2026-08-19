-- S8-11 / P10-18. A permanent, system-issued reference for every company.
--
-- `companies` had 29 columns and none was a reg-ref. `registration_number` is
-- free text, user-typed, unvalidated, changeable, and is not displayed on the
-- company profile at all — so there was nothing stable to quote in a support
-- call, on a document, or between two parties to a transaction.
--
-- Format: 3 letters + at least 3 digits (ABC001). The letters come from the
-- company name so the reference is recognisable rather than opaque; the digits
-- are a per-prefix sequence, so two companies whose names start alike do not
-- collide.
alter table public.companies add column if not exists reg_ref text;

-- Derives the 3-letter prefix. Non-alphabetic characters are stripped first —
-- "3M Mining" must not yield a prefix starting with a digit, or the format
-- stops being "3 letters + digits" and becomes unparseable. Live-verified:
-- "3M Mining" -> MMI001.
create or replace function public.company_reg_ref_prefix(p_name text)
returns text
language sql
immutable
as $function$
  select upper(
    rpad(
      coalesce(nullif(regexp_replace(coalesce(p_name, ''), '[^A-Za-z]', '', 'g'), ''), 'MLK'),
      3, 'X')
  )::text;
$function$;

comment on function public.company_reg_ref_prefix(text) is
  'First three letters of a company name, non-alphabetics stripped and padded '
  'with X. Falls back to MLK for a name with no letters at all, so the format '
  'holds for every possible input.';

-- Issues the next free reference for a prefix. Loops rather than using a
-- sequence because the digits are per-prefix, and widens past 3 digits rather
-- than failing once a prefix passes 999 — the spec says "at least" 3.
create or replace function public.next_company_reg_ref(p_name text)
returns text
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_prefix text := public.company_reg_ref_prefix(p_name);
  v_n int := 1;
  v_candidate text;
begin
  loop
    v_candidate := v_prefix || lpad(v_n::text, 3, '0');
    exit when not exists (
      select 1 from public.companies c where c.reg_ref = v_candidate);
    v_n := v_n + 1;
    if v_n > 100000 then
      raise exception 'could not allocate a reg ref for prefix %', v_prefix;
    end if;
  end loop;
  return v_candidate;
end;
$function$;

-- Assign on insert; refuse any change afterwards. Immutability is the whole
-- point — a reference that can be edited is not a reference, it is a nickname.
create or replace function public.company_reg_ref_guard()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $function$
begin
  if tg_op = 'INSERT' then
    if new.reg_ref is null then
      new.reg_ref := public.next_company_reg_ref(new.company_name);
    end if;
    return new;
  end if;

  if old.reg_ref is not null and new.reg_ref is distinct from old.reg_ref then
    raise exception
      'The company reference % is permanent and cannot be changed.', old.reg_ref
      using errcode = 'check_violation';
  end if;
  if new.reg_ref is null then
    new.reg_ref := old.reg_ref;
  end if;
  return new;
end;
$function$;

drop trigger if exists company_reg_ref_guard_trg on public.companies;
create trigger company_reg_ref_guard_trg
  before insert or update on public.companies
  for each row execute function public.company_reg_ref_guard();

-- Backfill, oldest first so the numbering follows the order companies joined.
do $$
declare c record;
begin
  for c in select id, company_name from public.companies
            where reg_ref is null order by created_at, id
  loop
    update public.companies
    set reg_ref = public.next_company_reg_ref(c.company_name)
    where id = c.id;
  end loop;
end $$;

-- Constrain only AFTER the backfill, so the constraint describes a state that
-- is already true rather than one the migration hopes for.
alter table public.companies
  add constraint companies_reg_ref_format
  check (reg_ref is null or reg_ref ~ '^[A-Z]{3}[0-9]{3,}$');

create unique index if not exists companies_reg_ref_key
  on public.companies (reg_ref);

comment on column public.companies.reg_ref is
  'Permanent system-issued company reference: 3 letters + at least 3 digits '
  '(ABC001). Assigned on insert, immutable thereafter (company_reg_ref_guard). '
  'Distinct from registration_number, which is free text the customer types '
  'and may change.';

-- Verified on production after applying:
--   26 companies · 26 with a ref · 26 distinct · 0 malformed
--   per-prefix sequencing works: Cyberhouse Transporter CYB001,
--     Cyberhouse Mine Supplier CYB002, Cyberhouse Buyer CYB003
-- and in a rolled-back transaction:
--   changing an issued ref   REFUSED "The company reference COD001 is permanent"
--   nulling an issued ref    REFUSED, same
--   inserting "3M Mining"    auto-issued MMI001 (digits stripped)
