# RLS policy verdicts — every policy on the production schema, read

**S2-12.** Read 2026-08-15 against project `yftazblpmicqtamyiwyb`. Re-derivable:
every table below is produced by the queries recorded in §6, run against
`pg_policy`, so this is a snapshot of what is *deployed*, not of what the
migrations say should be.

---

## 1. The counts, measured

| | |
|---|---|
| Tables in `public` | **69** |
| With RLS enabled | **69** — every one |
| With at least one policy | **68** |
| Policies | **152** |

**The gate says "~250 remaining RLS policy bodies". There are 152 in total.**
That is the whole schema, not a remainder — the 36 `storage.objects` policies
counted under S2-13 are in a different catalogue and are not included here.

**`place_index` is the one table with RLS on and no policy.** Deny-by-default,
and correct: it also has **no grant to `authenticated` or `anon`**, so it is
unreachable from a client session in either direction and is served only
through a SECURITY DEFINER RPC. Recorded rather than flagged.

---

## 2. Method, and the harness error it caught first

The first pass classified each policy by regex against a **hand-listed** set of
caller-scoping predicates. It produced 13 flags, of which **10 were false
positives** — policies using `has_company_role`, `chat_is_room_participant`,
`are_chat_participants_allowed`, `is_org_group_member` and `is_main_super_admin`,
none of which were in the list I had typed out.

That is the failure mode this project keeps recording: *the audit tool
under-reports in the direction that invents findings.* The corrected method
derives the predicate set **from the policies themselves**:

1. Extract every function name appearing in any `polqual` / `polwithcheck`.
   → **29 distinct functions**, all in `public`, plus `auth.uid()`.
2. For each, test whether it is **anchored to the caller** — reaches
   `auth.uid()` in its own body or transitively through another `public`
   function (recursive CTE, depth 4).
   → **25 anchored.** Four are not: `can_read_notification_scope`,
   `chat_is_super_admin`, `chat_role_of`, `chat_user_company_id`.
3. Read the four. Each takes a `uid`/`role` **parameter**, and every policy
   using them passes `(select auth.uid())` explicitly. Anchored at the call
   site. **No unscoped predicate exists in the schema.**

---

## 3. Verdicts by table

`r` = SELECT · `a` = INSERT · `w` = UPDATE · `d` = DELETE · `*` = ALL.
**A command with no policy is denied** — that is the verdict for most write
paths here, and it is deliberate: mutations go through SECURITY DEFINER RPCs
per CLAUDE.md §6.

### 3.1 Platform-admin only — ✅ correct

| table | cmds | verdict |
|---|---|---|
| `audit_logs` | r,a | `is_super_admin()` both. Append-only to clients: no update, no delete policy. ✅ |
| `serial_tokens` | r,a,w | `is_super_admin()`. No delete. ✅ |
| `platform_admin_settings` | r,w | read `is_super_admin()`, write `is_main_super_admin()`. ✅ |
| `margin_ledger` | * | `is_platform_admin()`. **This is the one the §4 domain model requires be admin-only** — the transporter must never see the admin's cut. ✅ |
| `organization_seats` | r,* | read scoped to `get_user_company_id()`, all-write `is_super_admin()`. ✅ |
| `seat_reassignment_log` | r,* | read = own company's owner; write `is_super_admin()`. ✅ |
| `showcase_data` | r,* | **read is `true`** — see §4. Write `is_platform_admin()`. ⚠ |

### 3.2 Company-scoped, read-only to clients — ✅ correct

Writes have **no policy at all**, so RLS denies them; the RPCs are the only
door. Every SELECT is `is_company_staff(company_id)` or equivalent, plus an
admin override.

`compliance_documents` · `driver_assignments` · `driver_limit_requests` ·
`employee_status_history` · `employees` · `fleet_maintenance_records` ·
`fleet_service_schedules` · `fleet_vehicles` · `fuel_entries` ·
`load_quality_certs` · `monthly_targets` · `recon_dispute_comments` ·
`recon_disputes` · `reconciliation_uploads` · `route_assignments` · `routes` ·
`target_cycles` · `trip_nav_state` · `vehicle_operating_costs` ·
`chat_room_companies` · `support_ticket_events` · `profile_requirements`

Two worth naming:

* **`employees` — SELECT only, no write policy of any kind.** Every employee
  mutation therefore runs through a SECURITY DEFINER RPC, and the
  `guard_company_active` trigger is not on this table. That combination is
  exactly the hole S2-10 closed at the resolver
  (`get_managed_company_id_for_current_user`, migration `20260815120000`).
* **`monthly_targets` / `target_cycles`** — SELECT grant only, no write grant
  and no write policy, which is what §4's targets note claims. Confirmed. ✅

### 3.3 Transaction-party scoped — ✅ correct

Read and write reach every company on the underlying transaction, by
`EXISTS` against `transactions`/`trips`, never by a flat company id.

| table | verdict |
|---|---|
| `transactions` | read = any of the three party staff; write = any of the three **managers**. ✅ |
| `trips` | same shape, resolved through `transactions`. ✅ |
| `reconciliations` | staff read / manager write across all three parties. ✅ |
| `pod_uploads` | read = all three parties; **insert = `is_company_staff_active(transporter)` only** — the driver's company, which is right: the POD is theirs to file. ✅ |
| `seal_records` | read = parties; insert = supplier staff (active). ✅ |
| `stockpile_docs`, `stockpile_transactions` | read = supplier or buyer staff; write = `is_company_stockpile_writer`. ✅ |
| `haul_routes` | supplier or buyer staff read, manager write. ✅ |
| `load_invoices` | **buyer only, on both sides** — `is_company_staff(buyer_company_id)`. The mine and the transporter can never read a buyer's invoice, which §4 requires. ✅ |
| `security_confirmations` | admin, the trip's driver, or the mine's active staff. ✅ |
| `trip_waypoints` | `is_trip_party(trip_id)` for read and write. ✅ |
| `request_dispatches` | read = admin, transporter, or the requester via the request; insert admin-only; update also the dispatched transporter. ✅ |
| `transportation_requests` | read/write keyed on `requesting_company_id`, with `buyer_company_id` as an additional reader when non-null — the split landed at S6-28. ✅ |
| `routes` | admin, supplier, buyer, or the dispatched transporter. ✅ |

### 3.4 Role-scoped writes — ✅ correct, with one note

| table | write predicate | verdict |
|---|---|---|
| `gate_checks` | `has_company_role(company_id, {security, admin, management})` | ✅ the gate is the security guard's |
| `weighbridge_records` | `has_company_role(company_id, {controllerWB, admin, management})` | ✅ the weighbridge is the controller's |
| `security_incidents` | `has_company_role(company_id, {security, admin, management})` | ✅ |
| `stockpiles` | insert `false` **or** a production pile by a stockpile writer; update `is_company_stockpile_writer` | ✅ order piles are system-minted only, exactly as §4 requires |

📌 **`has_company_role()` does not test company status.** All three tables
carry the `guard_company_active` trigger from `20260815097000`, so expiry is
enforced one layer down. Recorded because the predicate reads as if it were
the whole check and is not.

### 3.5 Self-scoped — ✅ correct

`profiles` (`id = auth.uid()`, update self only) · `chat_message_reads` ·
`chat_message_reactions` · `support_notifications` · `notifications`
(own row, or the company's within the caller's notification scope).

### 3.6 Chat and support — ✅ correct

`chat_rooms`, `chat_messages`, `chat_message_reactions`,
`support_tickets`, `support_ticket_messages`, `support_ticket_events`,
`support_inbox_prefs`, `broadcast_messages`, `org_connections`. Every one is
participant- or ticket-scoped, with the sender pinned to `auth.uid()` on
insert so a message cannot be posted under someone else's name.

---

## 4. The three unconditional reads — ⚠ each deliberate, each recorded

`USING (true)`, to `authenticated`:

* **`mine_hazards`** — a safety broadcast. A driver approaching a blasting zone
  may belong to any transporter on the network, so scoping it per company
  would withhold a hazard from the person driving into it. Platform-wide read
  is the intended behaviour.
  ⚠ **Its INSERT is `reported_by = auth.uid()`** — any authenticated user can
  publish a hazard to every driver on the platform. Update and delete are
  admin-only, so a false hazard cannot be quietly edited away, but it also
  cannot be removed by the mine it defames. **Worth a client ruling**: should
  posting be limited to mine staff, or is open reporting the point?
* **`profile_requirements`** — 38 rows of configuration: which documents each
  `(org_type, role)` must supply, with labels and sort order. No company or
  personal data. ✅
* **`showcase_data`** — 14 rows of demo content for the tour, read by nothing
  (`showcaseDataProvider` is watched by no widget). Client ruled 2026-08-12
  that the rows stay. Latent, not live. ✅ (with the standing note that the
  rows attribute invented content to real companies).

---

## 5. Findings — two, both fixed, both walked

### F1 (SEVERE) — an expired company could not renew

`20260815094000` preserved the renewal request and verified it by INSERTing
into `token_requests` directly. **The app never inserts directly**: it calls
`create_company_token_request`, which opened with `is_company_manager()` —
manager *and company active* since that same migration. So the protection was
verified on a path the product does not take, and the path it does take was
shut. A lapsed customer could not ask to pay.

Walked as the Iron Hills owner with the company flipped to `expired`, rolled
back: `is_company_manager` → **false**, RPC → **REFUSED**. After
`20260815124000`: **ALLOWED, status pending**.

### F2 — a non-manager could raise a commercial request under a colleague's name

`token_requests` carried two **permissive** INSERT policies, and permissive
policies OR — so the weaker one decided:

```
token_requests_insert_company_manager
  requested_by_user_id = auth.uid() AND is_company_manager_any_status(org)
"Company users can create seat requests"
  organization_id = get_user_company_id()        <-- no actor test at all
```

Walked as a real `security` guard at Iron Hills
(`is_company_manager_any_status` = false), rolled back: the INSERT was
**ALLOWED**, with `requested_by_user_id` set to a **different** employee. The
platform admin's inbox would have shown a seat-expansion request from somebody
who never made one — audit integrity on the commercial path S4 had just
finished hardening.

After `20260815124000`: forging another user's id → **REFUSED**; the same
insert in their own name → still **ALLOWED**, so no functional regression.

---

## 6. Reproducing this

```sql
-- counts
select count(*) from pg_policy p join pg_class c on c.oid=p.polrelid
  join pg_namespace n on n.oid=c.relnamespace where n.nspname='public';

-- every predicate the policies rely on, derived rather than listed
with pol as (
  select coalesce(pg_get_expr(polqual,polrelid),'') || ' ' ||
         coalesce(pg_get_expr(polwithcheck,polrelid),'') as expr
  from pg_policy p join pg_class c on c.oid=p.polrelid
  join pg_namespace n on n.oid=c.relnamespace where n.nspname='public')
select distinct (regexp_matches(expr,'([a-z_][a-z0-9_]*)\s*\(','g'))[1] from pol;

-- per-table command coverage and predicates
select c.relname, p.polcmd::text,
       pg_get_expr(p.polqual,p.polrelid), pg_get_expr(p.polwithcheck,p.polrelid)
from pg_policy p join pg_class c on c.oid=p.polrelid
join pg_namespace n on n.oid=c.relnamespace where n.nspname='public'
order by 1,2;
```
