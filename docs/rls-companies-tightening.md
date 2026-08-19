# Prepared change — narrowing the `companies` SELECT policy (P3-43)

**Status:** analysed, drafted, **NOT applied.** Two code changes must land first.
**Prepared:** 2026-08-11 by the cloud session (DB + read access, no shell).
**Apply when:** Phase 3, after the prerequisites in §2 are merged.

---

## 1. The problem

```sql
companies_select_authenticated  FOR SELECT  USING (true)
```

It is the **only** SELECT policy on `companies`. Every authenticated user — a driver,
a security guard, anyone — can read **every company row on the platform**, including
`seat_limit`, `seats_used`, `token_expires_at`, `current_token_id`, `whatsapp_number`,
`registration_number`, `vat_number`, `physical_address`, CEO names and support email.

A driver at one transporter can enumerate every competitor's full profile and their
commercial posture. On a multi-tenant B2B platform that is the leak that matters most.

---

## 2. PREREQUISITES — code changes that must land BEFORE the policy

A per-tenant predicate cannot satisfy these two call sites. Applying the policy
without fixing them first **will break onboarding**.

### 2a. 🔴 The onboarding employer picker — `company_service.dart:82`

```dart
final data = await _supabase.from('companies').select();   // all rows, ALL columns
```

Reached by `EmployeeNotifier.loadAvailableCompanies()` →
`company_selection_screen.dart:32` and `request_declined_screen.dart:58`.

This is a **pre-approval employee** choosing their employer. They legitimately need to
see companies they have no relationship with — that is the whole point of the screen.
But they currently receive every column, including seat and token data.

**Fix:** replace with a SECURITY DEFINER RPC returning only what the picker renders.

```sql
create or replace function public.list_selectable_employers()
returns table (id uuid, company_name text, org_type text, logo_url text)
language sql stable security definer set search_path = public as $$
  select c.id, c.company_name, c.org_type, c.logo_url
  from public.companies c
  where c.status <> 'suspended'
  order by c.company_name;
$$;
revoke execute on function public.list_selectable_employers() from public;
grant  execute on function public.list_selectable_employers() to authenticated;
```

Then point `getCompanies()` at `.rpc('list_selectable_employers')`. This is a
*net security win on its own* — it stops leaking seat/token/VAT data to users who
have not even been approved yet.

### 2b. 🟠 The operations-hub all-companies fetch — `operations_service.dart:13`

```dart
.from('companies').select().order('company_name')       // all rows, ALL columns
```

Fires on **every** `OperationsNotifier.refresh()` — i.e. every visit to `/operations`
and every portal operations tab, for any user with a company scope.

**Check first whether the result is used at all.** The audit suggests it is dead
weight on the refresh path. If unused, delete the call. If used (e.g. to label a
counterparty on a transaction row), narrow it to the ids actually referenced and let
the counterparty predicate below cover it.

### 2c. 🟡 Already slated for deletion — no action needed, just don't be surprised

- `company_repository.dart:60` `getByOrgType` → `/companies/:orgType`, **no role
  guard**, all columns for a whole org type. Screen is P1-16 (deferred to Phase 12).
- `database_service.dart:45` via `company_database_service.dart:46` `getAllCompanies()`.

Both die with the legacy `core/mcp/` layer. If the policy lands first they will
simply return fewer rows — they are not on a critical path.

---

## 3. The migration

```sql
-- Who counts as a counterparty: anyone this company has actually transacted with,
-- been dispatched alongside, or been explicitly chat-connected to by the platform
-- admin. SECURITY DEFINER so it does not re-enter the companies policy.
create or replace function public.is_company_counterparty(p_target uuid)
returns boolean
language sql stable security definer set search_path = public as $$
  with me as (select public.current_company_id() as id)
  select exists (
    -- a shared transaction in any role combination
    select 1 from public.transactions t, me
    where me.id in (t.supplier_company_id, t.buyer_company_id, t.transporter_company_id)
      and p_target in (t.supplier_company_id, t.buyer_company_id, t.transporter_company_id)
  ) or exists (
    -- a dispatch links a transporter to the requester/supplier BEFORE any
    -- transaction exists (transactions are only created on accept), so without
    -- this a transporter cannot see who dispatched them a route.
    select 1 from public.request_dispatches d
    join public.transportation_requests r on r.id = d.request_id, me
    where (d.transporter_company_id = me.id
             and p_target in (r.buyer_company_id, r.supplier_company_id))
       or (me.id in (r.buyer_company_id, r.supplier_company_id)
             and p_target = d.transporter_company_id)
  ) or exists (
    -- an active platform-granted chat connection
    select 1 from public.org_connections oc, me
    where oc.status = 'granted'
      and ((oc.company_low_id = me.id  and oc.company_high_id = p_target)
        or (oc.company_high_id = me.id and oc.company_low_id  = p_target))
  );
$$;
revoke execute on function public.is_company_counterparty(uuid) from public;
grant  execute on function public.is_company_counterparty(uuid) to authenticated;

drop policy if exists companies_select_authenticated on public.companies;

create policy companies_select_scoped
  on public.companies
  for select
  to authenticated
  using (
    -- Each helper is wrapped in a scalar subquery so Postgres evaluates it ONCE
    -- per statement instead of once per row (same initplan issue as auth.uid()).
    (select public.is_platform_admin())
    or user_id = (select auth.uid())
    or id = (select public.current_company_id())
    or public.is_company_counterparty(id)
  );
```

**No write-path impact.** There are no reachable direct writes to `companies` — every
legitimate mutation already goes through an RPC (`update_my_company_profile`, the
super-admin token/org functions). The one direct write, `company_repository.updateLogo`,
has no callers.

---

## 4. Measured blast radius — run against live data 2026-08-11, **corrected 2026-08-13**

Every active company retains **all** of its real relationships:

| Company | org type | via txn | via conn | via dispatch | ~~total kept~~ | **distinct partners** |
|---|---|---|---|---|---|---|
| Atlas Buyer Group | buyer | 2 | 1 | 3 | ~~6~~ | **4** |
| Roadhaul Logistics | transporter | 4 | 0 | 2 | ~~6~~ | **4** |
| Cyberhouse Mine Supplier | mineSupplier | 4 | 0 | 1 | ~~5~~ | **4** |
| Cyberhouse Transporter | transporter | 2 | 0 | 2 | ~~4~~ | **2** |
| Iron Hills Mining | mineSupplier | 2 | 1 | 1 | ~~4~~ | **2** |
| Cyberhouse Buyer | buyer | 2 | 0 | 1 | ~~3~~ | **2** |
| b man trans / b the buyer / bryson logistics / SteelWorks SA | — | 2 | 0 | 0 | 2 | **2** each |
| Fast Freight Logistics, Test Live Transporter | transporter | 0 | 0 | 2 | 2 | **2** each |

> ⚠ **The original "total kept" column was a sum of the three channels and double-counted.**
> A partner reachable both by transaction *and* by dispatch was counted twice. The
> per-channel figures reproduce exactly on re-query; only the total was wrong.
> **No partner is lost by this correction** — the *set* of visible companies is unchanged,
> the count of it was overstated. Settled by walking it as a real user rather than by
> arithmetic: Sipho Driver at Roadhaul Logistics sees **5 of 26** — own company + 4
> partners — which is the distinct column, not the summed one.

The 12 companies that drop to 0 partners have **no transactions, no dispatches and no
connections** — they are shell/test rows (and 14 of 26 companies have no serial token
at all). Nothing real is lost. A 0-partner company still reads **its own row**, so no
portal loses the `org_type` its router guard resolves.

**Status: APPLIED and VERIFIED.** `companies_select_scoped` is live and is the only
SELECT policy on the table. §5's walk was executed 2026-08-13 as four real users
(driver, security, transporter admin, super global admin) by setting
`request.jwt.claims` under `role authenticated` in rolled-back transactions; results
in `COMPLETION-CHECKLIST.md` S2-1. §2a landed as `list_company_directory()` — the
draft's name was `list_selectable_employers`.

---

## 5. Verification after applying

```sql
-- 1. Policy is the only SELECT policy and is no longer `true`
select polname, pg_get_expr(polqual, polrelid)
from pg_policy p join pg_class c on c.oid = p.polrelid
where c.relname = 'companies' and p.polcmd = 'r';

-- 2. No other table regressed to a blanket-true SELECT
select c.relname, p.polname
from pg_policy p join pg_class c on c.oid=p.polrelid
join pg_namespace n on n.oid=c.relnamespace
where n.nspname='public' and pg_get_expr(p.polqual,p.polrelid) in ('true','(true)');

-- 3. Advisor should not gain a new warning
--    (mcp get_advisors type=security, or the dashboard linter)
```

**Then walk these by hand, signed in as a real non-admin user of each org type:**

| Path | Expect |
|---|---|
| Sign in as a company owner | portal loads; `app_router.dart:202` guard resolves `org_type` |
| Sign in as an employee (each role) | portal loads; `app_router.dart:220` guard resolves |
| Buyer → Routes & Mines | linked mines still listed (`logistics_service.dart:294`) |
| Mine → Buyers | linked buyers still listed |
| Mine → tons-out per transporter | transporter name resolves (`app_router.dart:1331`) |
| Transporter → Available routes | requester company name shows on a **dispatched, not yet accepted** route — this is what §3's dispatch clause exists for |
| Chat | connected-org contacts still resolve |
| Employee onboarding → pick employer | **the §2a RPC path**, not the table read |
| Super admin → Organizations | all 26 still listed |
| Super admin → request inboxes | `requester_company` embed still populated (`request_service.dart:217`) — a narrowed policy **silently nulls** this rather than erroring, so check the value, not just the absence of a crash |

---

## 6. Rollback

```sql
drop policy if exists companies_select_scoped on public.companies;
create policy companies_select_authenticated
  on public.companies for select to authenticated using (true);
```

Instant, and safe to run at any time — it only widens visibility back to today's
behaviour. Keep this to hand while verifying; there is no staging environment.

---

## 7. Notes for whoever applies this

- Mirror the migration to `supabase/migrations/` in the same commit and repoint the
  ledger version, per `supabase/MIGRATION_HYGIENE.txt`.
- The embedded-join case (`request_service.dart:217`) fails **silently** — PostgREST
  nulls an embedded resource the caller cannot read rather than raising. Any embed
  on `companies` added later inherits that behaviour. Worth a comment where it lives.
- `logistics_service.dart:294` now rethrows `PostgrestException` rather than swallowing
  it, so an over-tight policy there surfaces as a visible error with retry instead of
  a confident empty list. That was deliberate (P2-04) and makes this change safer to
  verify.
