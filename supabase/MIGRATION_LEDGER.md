# Migration ledger reconciliation

**Generated 2026-08-12 against the live project `yftazblpmicqtamyiwyb` (production, no staging).**
Closes checklist gate **S1-6**. Regenerate before believing any of it — the numbers below are a
snapshot, and more than one session applies migrations to this project.

## How this was verified, and why that matters

`supabase_migrations.schema_migrations` stores a `statements` array holding **the SQL that actually
ran**. That turns "is this file what was applied?" from an assumption into a check. Every claim
below is a comparison of that stored SQL against the file on disk, normalised for:

- whitespace,
- `--` and `/* */` comments,
- the explicit `begin;` / `commit` wrapper the files carry and `apply_migration` strips.

That last one matters: **without it, 18 migrations look like they differ when the delta is exactly
the 15 characters of the transaction wrapper.** An earlier pass of this reconciliation reported 35
mismatches; 18 of them were that wrapper and nothing else.

## Result

| Category | Count | State |
|---|---:|---|
| A. Ledger stamp matches a file of the same name, **body verified identical** | 79 | ✅ clean |
| B. Body identical, stamp wrong | 0 | ✅ fixed — 58 rows repointed 2026-08-12 |
| C. Applied, file of that name exists, **body differs** | 17 | ⚠ see below |
| D. Applied, **no file of that name anywhere** | 19 | ⚠ unreproducible from git |
| Files present that were never applied under that name | 70 | mostly pre-reset history |

Ledger row count before and after the repoint: **115 → 115.** No row was created or lost.

Duplicate timestamp prefixes: **6 → 0.** Two involved applied migrations and were resolved by
renaming the file onto the stamp the ledger already held (`stockpile_docs` → `20260714175337`,
`chat_mark_room_read_rpc` → `20260801100612`); four were never-applied 2025-era files, disambiguated
into free slots.

The stray root `migrations/` folder (4 files, tracked) is archived to `legacy/root-migrations-archive/`.

## C — applied, but the file does not reproduce what ran (17)

Do **not** assume these files are safe to replay. Ordered by how much the two disagree.

### C1. The file is empty of applied SQL — the ledger stored no statements (2)

| Ledger | Name | Applied | File |
|---|---|---:|---:|
| `20260516202040` | `fleet_vehicle_details` | **0 chars** | 6,946 |
| `20260714000000` | `dashboard_tons_from_net_mass` | **0 chars** | 4,314 |

The ledger row exists with an empty `statements` array, so there is no record of what ran. The file
is the only evidence, and it is unverifiable against the database.

### C2. One file, several apply calls (1)

| Ledger | Name | Applied | File |
|---|---|---:|---:|
| `20260516021736` | `token_requests_platform` | 3,589 | **21,099** |

The file is ~6× the applied body because `token_requests_platform`, `_notify` and `_triggers` are
three ledger rows mirrored into one file — the inverse of the one-file-per-migration rule. The
other two rows appear in category D.

### C3. Same content, different statement order (1)

| Ledger | Name | Applied | File | Similarity |
|---|---|---:|---:|---:|
| `20260808120000` | `targets_and_cycles` | 22,671 | 22,671 | 0.819 |

**Identical total length, 45 differing hunks** — `start_new_target_cycle` and
`close_due_target_cycles_job` occupy swapped positions. The end state is very likely the same set of
objects in a different order, but that has **not** been proven object-by-object and should not be
recorded as proven. CLAUDE.md §6 already notes a comments-only drift check on this migration; this is
a different and larger discrepancy than that check covered.

### C4. Encoding corruption in the file (1)

| Ledger | Name | Similarity | Delta |
|---|---|---:|---|
| `20260727191434` | `buyer_load_values_invoices` | 0.99984 | file has `�` where the applied SQL has `-` |

A single mojibake character, and it is **inside SQL, not a comment** — comments are stripped before
comparison. The file as checked in would not replay byte-identically.

### C5. Small deltas, cause not yet characterised (12)

| Ledger | Name | Applied | File |
|---|---|---:|---:|
| `20260329120000` | `align_live_comms_access_with_canonical` | 11,548 | 11,570 |
| `20260329170000` | `runtime_and_realtime_hardening` | 4,668 | 4,749 |
| `20260511203645` | `super_admin_monthly_insights_bundle_rpc` | 4,512 | 4,499 |
| `20260712123237` | `drop_child_admin_completely` | 13,312 | 13,318 |
| `20260712222103` | `audit_fixes_round` | 22,143 | 22,211 |
| `20260726182626` | `mine_hazards` | 3,580 | 3,904 |
| `20260726182759` | `mine_road_requests` | 1,993 | 2,237 |
| `20260726182845` | `showcase_data` | 4,175 | 4,620 |
| `20260727191456` | `mine_production_dispatch` | 5,556 | 5,556 |
| `20260811120000` | `company_member_presence` | 1,103 | 1,312 |
| `20260811140000` | `member_presence_raises_on_denial` | 1,305 | 1,470 |
| `20260812090000` | `org_type_role_matrix_triggers` | 3,600 | 3,630 |

Where the file is **larger**, the likeliest cause is a follow-up edit made to the file after applying
— which is the failure CLAUDE.md §6 rule 1 exists to prevent. Where it is **smaller**
(`super_admin_monthly_insights_bundle_rpc`), something was applied that the file does not contain.

## D — applied with no file of that name (19)

Unreproducible from git. A fresh project could not be rebuilt from `supabase/migrations/` alone.

```
20260322154940  mcp_bootstrap
20260322155113  mcp_bootstrap_function_search_path_fix
20260322164524  add_missing_db_helpers_and_rls_optimizations
20260322174533  create_super_admin_role
20260322185701  add_super_admin_provisioning
20260503135130  task32_security_hardening
20260504114345  grant_seat_requests_permissions
20260504114427  grant_permissions_for_new_tables
20260504212635  add_seat_reassignment_log_and_serial_numbers
20260504212707  add_seat_management_rpc_functions
20260516021757  token_requests_platform_notify
20260516021813  token_requests_platform_triggers
20260516202107  fleet_vehicle_details_v2
20260516202124  fleet_vehicle_details_rpcs
20260516202153  fleet_vehicle_create_rpc
20260516202205  fleet_vehicle_update_rpc
20260516202955  add_current_platform_role_function
20260712113639  supervisor_notification_on_link
20260726182254  mine_locations_waypoints_security_confirmations
```

Several have a plausible near-name file (`add_current_platform_role_function` ↔
`20260516310000_grant_current_platform_role_rpc.sql`; `supervisor_notification_on_link` ↔
`20260712140000_supervisor_notification.sql`), but a near-name is not a match and is not recorded as
one here. The `statements` array for each of these rows is the only surviving copy of what ran —
**it can be dumped from the ledger and mirrored to a file**, which is the cheapest route to closing
category D properly.

## What S1-6 asked for, and where the gate's wording is wrong

The gate reads: *"every applied migration has a file, every file a ledger row."*

The second half is not achievable and not desirable. **70 files were never applied under their own
name**, and most are pre-reset history — the 2025-era `reset_database`, `initial_setup` and
`fix_*` files superseded by `20260327000100_canonical_platform_reset.sql`. Minting a ledger row for
each would assert that SQL ran which never ran. They are correctly retained as history and correctly
absent from the ledger.

The first half is achievable and is **not yet true** — 19 rows have no file (category D).
