# Phase 1 — Backend Phase A (verify live + additive mine-nav) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add the ML fork's genuinely-unique mine-navigation + mine-road-request backend to the live worktree database as **purely additive** migrations, adapted to the live schema/RPC contracts, without touching any existing table that holds real data.

**Architecture:** The worktree is the foundation and points at live Supabase `yftazblpmicqtamyiwyb` (49 tables, real data). ML's mine-nav layer (`mine_locations`, `trip_waypoints`, `security_confirmations`, `mine_hazards`, `mine_road_requests`, `showcase_data`) does not exist in live. We port ML's DDL/RLS/RPCs, rewriting every reference to match live table/column names (e.g. `fleet_vehicles`, `transportation_requests`, `trips`, `companies`, `employees`, `profiles`) and the live RPC signatures. Migrations are drafted by an implementer, reviewed, tested on a throwaway Supabase dev branch (or dry-run), then applied to production via MCP `apply_migration`.

**Tech Stack:** Supabase Postgres 17.6, RLS, SECURITY DEFINER RPCs, Supabase MCP (`apply_migration`, `execute_sql`, `list_migrations`, `get_advisors`, `create_branch`), Flutter/Dart (worktree), `--dart-define` config.

## Global Constraints
- Package name stays `flutter_application_1`. Product name only in `AppBranding.appName`.
- Target live project ref: `yftazblpmicqtamyiwyb`. `config/supabase.*.json` already point here — verify, don't change.
- **Additive only in Phase A.** No `DROP`/`ALTER` on existing populated tables. New tables use `CREATE TABLE IF NOT EXISTS`; new RPCs `CREATE OR REPLACE FUNCTION`.
- Every new table has RLS enabled + party-scoped policies mirroring the live pattern (company-scoped via `companies`/`employees`, super-admin full access). Security lives in RLS/RPCs, not Dart.
- New migration filenames follow the worktree's existing convention (timestamp prefix), NOT ML's `0000NN_` scheme. Read `supabase/MIGRATION_HYGIENE.txt` first.
- Enums that hit the wire carry `.wire` + tolerant `parse()`.
- Do NOT modify the 3 pre-existing uncommitted map files; `git add` only files this plan creates.

---

### Task 1: Prep — isolation branch, live baseline, migration hygiene

**Files:**
- Create: git branch `feat/minelink-fork-merge`
- Read: `supabase/MIGRATION_HYGIENE.txt`, `supabase/migrations/` (latest timestamps)

- [ ] **Step 1:** From the worktree, create the merge branch carrying current work: `git checkout -b feat/minelink-fork-merge` (preserves the 3 uncommitted map files in the working tree; do not commit them).
- [ ] **Step 2:** Read `supabase/MIGRATION_HYGIENE.txt` and note the timestamp-prefix rule + the "list remote before push" rule.
- [ ] **Step 3:** Via MCP `list_migrations(yftazblpmicqtamyiwyb)`, record the latest applied migration version so new files sort AFTER it.
- [ ] **Step 4:** Confirm `config/supabase.live.json` + `config/supabase.local.json` reference `yftazblpmicqtamyiwyb`. If yes, no change.
- [ ] **Step 5:** Commit only the two planning docs: `git add docs/superpowers/specs/2026-07-26-minelink-fork-merge-design.md docs/superpowers/plans/2026-07-26-phase1-backend-mine-nav.md && git commit -m "docs: fork-merge spec + phase 1 plan"`.

### Task 2: Draft adapted mine-nav migrations (implementer, no live writes)

**Files:**
- Read (ML donors): `ML/supabase/migrations/000010_gps_navigation.sql`, `000011_mine_locations.sql` (defines mine_locations + trip_waypoints + security_confirmations + mine_location_points), `000015_mine_hazards.sql`, `000016_mine_road_requests.sql`, `000017_showcase_data.sql`, `000047_convert_request_to_transport.sql`, and the ML services that call them (`mine_location_service.dart`, `hazard_service.dart`, waypoint/security providers, `mine_road_service.dart`).
- Read (live contracts): worktree `supabase/migrations/*` for canonical `companies`/`employees`/`profiles`/`trips`/`transportation_requests`/`fleet_vehicles` shapes + the `trip_nav_state`, `company_locations` tables already live.
- Create: `worktree/supabase/migrations/<ts>_mine_nav_tables.sql`, `<ts>_mine_hazards.sql`, `<ts>_mine_road_requests.sql`, `<ts>_showcase_data.sql` (draft only).

**Interfaces:**
- Produces new tables/RPCs consumed by Phase 5 (fleet/nav) Dart ports: `mine_locations`, `mine_location_points`, `trip_waypoints`, `security_confirmations`, `mine_hazards`, `mine_road_requests`, `showcase_data`; RPCs `convert_request_to_transport(...)`, waypoint list/advance, security-confirm, hazard list. Exact signatures captured in the migration + reported back.

- [ ] **Step 1:** Implementer reads the ML donor SQL + live contracts and produces draft migration files under `supabase/migrations/` with:
  - Every FK/column rewritten to live names (e.g. ML `vehicles`→`fleet_vehicles`; align request FKs to `transportation_requests`/`request_dispatches`; trips FK to live `trips`).
  - `CREATE TABLE IF NOT EXISTS`, RLS enabled, party-scoped policies matching the live pattern.
  - RPCs as `CREATE OR REPLACE FUNCTION ... SECURITY DEFINER` with `REVOKE EXECUTE ... FROM anon` unless intentionally public.
  - A header comment tracing each file to its ML origin.
- [ ] **Step 2:** Implementer returns a summary: table/column/RPC list, every adaptation made, and any place where the live schema lacks something the ML SQL assumed (flag for decision).
- [ ] **Step 3:** I (orchestrator) review the drafts against the live schema for correctness + additive-safety. Fix issues inline. Do NOT apply yet.

### Task 3: Validate migrations on a throwaway dev branch (no prod risk)

- [ ] **Step 1:** MCP `get_cost(branch)` then `confirm_cost`; `create_branch(yftazblpmicqtamyiwyb, name: "mine-nav-verify")` to get an isolated copy.
- [ ] **Step 2:** `apply_migration` each drafted file to the dev branch; fix any SQL error and re-apply until clean.
- [ ] **Step 3:** `execute_sql` smoke checks on the branch: insert a sample mine_location/hazard/waypoint under a test company, exercise each new RPC, confirm RLS blocks cross-company reads.
- [ ] **Step 4:** `get_advisors(security)` on the branch — confirm no new ERROR-level issues; only expected SECURITY DEFINER WARNs.
- [ ] **Step 5:** `delete_branch` the dev branch once green.

### Task 4: Apply to production + capture live-only artifacts

- [ ] **Step 1:** `list_migrations` again; confirm no name clash.
- [ ] **Step 2:** `apply_migration` each verified file to `yftazblpmicqtamyiwyb` (production), in order.
- [ ] **Step 3:** `list_tables` — confirm the 6 new tables now exist (55 total) with RLS enabled and 0 rows.
- [ ] **Step 4:** `get_advisors(security)` on prod — confirm still 0 ERROR; note any new WARN.
- [ ] **Step 5:** Capture the live-only `reset-admin-password` edge function into the repo: `get_edge_function(reset-admin-password)` → write to `supabase/functions/reset-admin-password/index.ts`.
- [ ] **Step 6:** Commit: `git add supabase/migrations/<the new files> supabase/functions/reset-admin-password && git commit -m "feat(backend): additive mine-nav tables + RPCs; capture reset-admin-password fn"`.

### Task 5: Address low-risk advisor items

- [ ] **Step 1:** Review the 2 anon-callable SECURITY DEFINER functions (e.g. `check_email_registered`); if not intentionally public, add `REVOKE EXECUTE ... FROM anon` in a small migration. If intentional (signup email check), leave + document.
- [ ] **Step 2:** Note "Leaked Password Protection Disabled" as a dashboard toggle for the user (cannot be set via migration) — record in the phase report.
- [ ] **Step 3:** Commit any REVOKE migration.

## Self-Review (done)
- Spec coverage: implements Spec §7 Phase A + §5 mine-nav tables + §6.2 convert bridge backend + §9 advisor items. ✓
- Placeholder scan: no TBDs; each task has concrete MCP/git commands. Detailed SQL is produced by the implementer in Task 2 (real files), reviewed in Task 2 Step 3 — appropriate granularity for a schema-port whose exact DDL must be read from donors. ✓
- Additive-safety enforced by Global Constraints + dev-branch validation before prod. ✓

## Verification (phase done when)
- 6 new tables live with RLS, 0 ERROR advisors, dev-branch smoke tests passed, migrations + reset-admin fn committed on `feat/minelink-fork-merge`.
