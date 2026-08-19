# SDD ledger — plan: docs/superpowers/plans/2026-08-19-release-hardening.md

Spec: docs/superpowers/specs/2026-08-19-release-hardening-design.md (read, reachable)
Branch: chore/release-v1-hardening
Plan BASE: c1f15b3

## Pre-flight conflict scan

### Cross-task pairs (shared file or interface)

| tasks | shared | produces → consumes | finding |
|---|---|---|---|
| 1 → 3 | pubspec | `package_info_plus` → crash sink app_version | clean, order correct |
| 1 → 13 | pubspec | `firebase_core`/`firebase_messaging` → PushService | clean |
| 1 → all | tool/release_guards.dart | 2 new guards → every later verify step | **CONFLICT 1** |
| 2 → 3 | `crash_reports` | table → sink INSERT | clean |
| 2 → 4 | `crash_reports` | table → reader SELECT | clean |
| 2 → 12 | `crash_reports` | table → prune | clean |
| 5 → 6 | `account_deletion_requests` | table + `finalise_result` col → finalise writes it | clean (col is in T5 DDL) |
| 6 → 7 | `finalise_account_deletion` | returns `{"storage":[...]}` → `data?.storage` | clean |
| 6 → 8 | edge fn contract | `{"request_id"}` → posted by job | clean |
| 6 → 11 | `public.device_tokens` | T6 finalise DELETEs it; T11 CREATEs it | **CONFLICT 2** |
| 9 → 10 | `AccountDeletionRequest` vs `AccountDeletionRow` | distinct types by design | clean — console-only fields must not reach the user view |
| 4 → 10 | app_router, console_sidebar_bridge, super_admin_shell_layout | both add entries to the same 3 files | clean if sequential; T10 must not clobber T4 |
| 11 → 12 | `device_tokens` | table → prune | clean |
| 11 → 13 | register/unregister RPCs | → DeviceTokenRepository | clean |
| stamp order | all 6 migrations | replay runs 100000→150000 | internally consistent once CONFLICT 2 is resolved |

### Task self-consistency

| task | own text agrees with itself? |
|---|---|
| 1 | **no** — see CONFLICT 1 |
| 2 | yes — probe → DDL → RLS proof → ledger check |
| 3 | yes — 5 tests map 1:1 onto the implementation's 5 stated properties |
| 4 | yes — injected `reports` param makes the layout test DB-free, as the test assumes |
| 5 | yes — MLD01/MLD02 raised in fn, asserted in probes |
| 6 | yes — 3 schema facts probed in Step 1 are exactly the 3 the SQL depends on; audit_logs/trips columns flagged as assumptions with fallbacks |
| 7 | yes |
| 8 | yes — `app.settings.*` flagged with Vault fallback |
| 9 | yes — fake service implements exactly the 3 interface methods |
| 10 | yes — second behavioural test body is described, not left blank |
| 11 | **partial** — same `app.settings.service_role_key` dependency as T8, not flagged there. See RULING 3 |
| 12 | yes |
| 13 | yes — degradation test needs no Firebase, which is the point |
| 14 | yes |

### Rulings

**Ruling 1 (CONFLICT 1) — drop the nested-`version:` YAML workaround in Task 1 Step 3; scope the guard to the `dependencies:` block instead.**
The plan's primary approach anchors `mockito-not-in-dependencies` on `^  mockito:`, which matches the entry under `dev_dependencies` equally — so it would fail on the fixed tree. The plan's own workaround (nesting `mockito:` under a `version:` key) is not idiomatic pub syntax and risks failing `flutter pub get`. Take the plan's stated fallback instead: `spanLines: true` with a pattern matching `mockito:` only between `^dependencies:` and `^dev_dependencies:`, **and a mandatory `plantWrapped`** — `spanLines` without it makes the selftest prove nothing (the 2026-08-16 lesson in that file).
*Cost if wrong:* a more complex regex. Mitigated because the selftest must plant both a single-line and a wrapped violation, so a blind guard fails the selftest rather than reporting green.

**Ruling 2 (CONFLICT 2) — renumber the `device_tokens` migration from `20260819130000` to `20260819090000`, and execute Task 11 immediately after Task 4.**
`finalise_account_deletion` (Task 6, stamp 110000) contains `delete from public.device_tokens`, a table Task 11 creates at stamp 130000. plpgsql resolves table names at run time, so `create function` succeeds and a cold replay passes — but on production, Task 6 lands before Task 11, and any deletion finalised in that window raises `42P01`. Renumbering makes stamp order and apply order agree, and removes the coupling entirely rather than papering over it with a `to_regclass` guard that would be dead code the moment Task 11 lands.
Revised execution order: **1, 2, 3, 4, 11, 5, 6, 7, 8, 9, 10, 12, 13, 14.** Task 12 (prune) still follows both its tables.
*Cost if wrong:* a stamp that sorts away from its logical grouping. Trivial and reversible.

**Ruling 3 — carry Task 8's `app.settings.*` pre-check note into Task 11's dispatch.**
Task 11's fan-out trigger reads `app.settings.service_role_key` exactly as Task 8's job does, but only Task 8 flags that it may not be configured. Same check, same Vault fallback, same prohibition on hardcoding a service-role key into a committed migration.
*Cost if wrong:* the trigger silently posts with a null bearer token and every push 401s — invisible, because the trigger swallows its own errors by design.

---

## Progress

### Ruling 4 — R-1 re-scoped from deletion to deactivation (Jean, mid-planning, 2026-08-19)

Jean: *"Accounts (company profiles) shouldn't be deletable really, only deactivate it, make it inactive."* Asked whether that extended to individual people, he chose **deactivate-only for both**, with the Play consequence stated in the question he answered.

Spec §1.1 written as the superseding authority; §1's FK graph kept (it is why a delete is impossible, and the expensive half if the stores force the issue). Plan rewritten: **13 tasks, not 14.**

- Struck: the anonymisation scrub, the storage purge, the whole `account-deletion` edge function, and the `pg_net`/service-role-key path in the backstop.
- Added: `reactivate_account` (platform-admin only, never the cron), `reactivated_at`/`reactivated_by`, and a test asserting the user-facing card never says "delete".
- Renumbered: `device_tokens` → Task 5 (stamp `20260819090000`, per Ruling 2); old 5→6, 6→7, 8→8, 9→9, 10→10, 12→11, 13→12, 14→13. Old Task 7 struck. `20260819130000` deliberately vacant.
- **Rulings 2 and 3 are now moot** and are superseded by this one: Ruling 2's ordering conflict is resolved by the renumber it called for (`deactivate_account` no longer touches `device_tokens` at all); Ruling 3's `app.settings.service_role_key` concern survives only for the push trigger (Task 5), because the deactivation backstop is now plain SQL.

*Cost if wrong:* R-1 does not close the Google Play blocker it was created for. Recorded in the spec §6 follow-ups, the plan's Global Constraints banner, and required in Task 13's checklist update — three places, in words, so no reader infers compliance from a green marker.

### Ruling 5 — proceed with production migrations without a second confirmation

Jean was told in the execution-mode message that Tasks 2, 5–8 and 11 apply migrations to production with no staging, and answered by selecting execution mode. Combined with CLAUDE.md §10.2 (every migration on this repo lands on live data — it is the normal workflow, not an exception) and §1's standing instruction *"otherwise just do"*, that is sufficient authorisation.

Mitigations already in the plan, not added here: all DDL is additive (`create table/function if not exists`), every live probe runs inside a transaction that rolls back, and Task 7 ends with a full `health_probe.py` because it writes to `auth.*`.

*Cost if wrong:* a migration lands that Jean wanted to review first. All six are additive and reversible by `drop`, and none touches an existing table's data.

---

## Progress

### Ruling 6 — three schema facts resolved ahead of Task 7 (controller, read-only)

Resolved against production while Task 1 ran, so the Task 7 implementer does not pay a round trip. Two were flagged assumptions; the third was **not flagged and was wrong**.

1. **`insert_audit_log` takes eight parameters, not six.** Real identity: `(p_action_type, p_target_type, p_target_id, p_target_name, p_organization_id, p_description, p_before_data, p_after_data)`. The last two are defaulted — `super_admin_set_company_status` calls it with six, which is why six works. The plan's guessed order was close but named the wrong fourth and fifth arguments.
2. **`p_organization_id` was being passed a user id.** The plan wrote `insert_audit_log(..., v_uid, ...)` in that slot. That would file every deactivation under an "organisation" that is actually a person. Fixed to look up the user's `employees.company_id`, and `p_target_name` now carries the display name rather than null.
3. **The `active_trips` blocker chip was counting the wrong thing.** The plan joined `fleet_vehicles.driver_user_id`, but `trips` has no driver column and CLAUDE.md §4 records that driver screens resolve the truck through `driver_assignments` *precisely because second-and-subsequent drivers were invisible otherwise*. `driver_assignments` keys on `driver_employee_id -> employees.id`, not on a user id. The subquery now covers **both** paths and counts distinct trips.

*Cost if wrong:* (1) and (2) would raise or mis-file an audit row. (3) is the one that matters: under-reporting the chip hides a driver who is mid-load from the reviewer, which is the entire reason the chip exists. Over-reporting costs a glance.

Plan text updated in place so the Task 7 brief carries all three. The pre-apply note now says re-run the confirming query rather than re-derive the answer.

Task 1: complete (commits 7dba2b8..bc32c14, review clean — spec ✅, quality approved)
Task 1: minor (deferred): the `mockito-not-in-dependencies` negative-lookahead is correct but subtle; a future maintainer could misjudge it at a glance. Well-commented already. Surface to the final whole-branch review for a triage call.
Task 1: note — 1285 tests pass, 1 skipped, 0 failed. Baseline in the plan said "~1125"; the higher count is drift from other sessions in this shared worktree (CLAUDE.md §10.1), not caused by this task. Use 1285/1 as the baseline from here.
Task 1: note — `package_info_plus` is `^10.2.1`, not the plan's guessed `^8.1.1`; forced by `wakelock_plus ^1.6.1`. Task 3 must use the resolved version.

### Ruling 7 — `migration_ledger_check.py` cannot run in this environment; verify the stamps by hand instead

The tool reaches the ledger through `public.migration_ledger()`, which is platform-admin only, so it must sign in. `ML_LEDGER_PASSWORD` is deliberately not in the repo and is not in this environment, so the tool exits with its "could not check" path on every migration task in this plan. That is **not a pass**, and no task may report it as one.

Substitute, which I ran myself for Task 2 and will run for each migration task: compare `ls supabase/migrations/ | grep 20260819` against `select version, name from supabase_migrations.schema_migrations where version >= '20260819000000'`. That is the same comparison the tool makes for the *new* stamps — what it additionally covers (the 101 baselined pre-existing discrepancies) is out of this plan's scope and unchanged by it.

Task 2 verified this way: one file `20260819140000_crash_reports.sql`, one row `20260819140000 | crash_reports`. Match.

*Cost if wrong:* a stamp mismatch slips through that the tool would have caught. Mitigated by doing the comparison manually every time, and by surfacing to Jean at the end that he should re-run the tool with the password to confirm the whole ledger, including the baseline.

Task 2: review — spec ✅, quality Changes needed. 2 Important, 1 Minor.

### Ruling 8 — the `anon` gap is real, but do NOT open an `anon` INSERT policy

The reviewer is right that `crash_reports_insert_own` is `to authenticated`, so a genuine pre-auth crash (splash, `/login`, before any session) runs as `anon`, is denied by RLS, and is exactly the case the migration's own comment claims to serve. The comment is therefore false as written.

**The obvious fix — add an `anon` INSERT policy — is the wrong one.** The publishable key ships inside every web bundle and every APK. An `anon` INSERT policy on this table is an unauthenticated, unmetered write endpoint into a **500 MB free-plan database** whose documented history (CLAUDE.md §10.2) includes a two-hour outage caused by disk and write pressure. Trading that for a narrow class of crash reports is a bad trade, and it is the kind of trade that looks free until someone finds the endpoint.

**The correct fix is that the sink already solves this.** `SupabaseReportingSink` (Task 3) buffers when a post fails and drains on the next success — that is a required, tested property. A pre-auth crash is therefore held in memory and delivered the moment the user signs in. The residual loss is only a crash on a session that *never* signs in, which is genuinely narrower than "all bootstrap crashes".

So: keep `authenticated`-only, **make the comment tell the truth**, and make the retain-across-sign-in behaviour an explicit, tested requirement of Task 3 rather than an accident of the offline buffer.

*Cost if wrong:* crashes from users who open the app and never sign in are not collected. Accepted deliberately, and now written down rather than silently untrue.

### Ruling 9 — the two remaining findings are fixed in a NEW migration, not by editing the applied one

CLAUDE.md §6 rule 1: one file per applied migration, and **never fold a follow-up fix into an earlier file** — it makes the file list and the ledger disagree. `20260819140000` is applied and has its ledger row, so the comment correction and the length CHECKs go in `20260819145000_crash_reports_hardening.sql`.

Promoting the Minor (no server-side length bound) into this round rather than deferring it: it is the direct mitigation for the abuse surface Ruling 8 just declined to widen, it is two `check` constraints, and a follow-up migration is already being written. Deferring it would mean a third migration later for two lines.

*Cost if wrong:* one extra migration file in the sequence. The alternative — editing an applied migration — is the thing the rule exists to prevent.

Task 2: fix round 1/5 (3 addressed, 0 open — anon-gap comment truthful + no anon policy added; retention comment names 20260819150000; error/stack CHECKs live; commits 28d5ba8..9bc2fa1)
Task 2: complete (commits 0201b78..9bc2fa1, re-review clean, 1 parked)

### Ruling 10 — park the stale "account deletion (R-1)" wording; fold the fix into Task 11 for free

Both crash_reports migrations describe `user_id ... on delete set null` as protecting a report from "an account **deletion** (R-1)". R-1 is deactivation now, and `deactivate_account` never deletes a `profiles` row — so that sentence describes a path that does not fire.

Real, and low severity: the **column choice is still correct** (SET NULL is right defensively if a profile is ever deleted by any other route), so nothing functional is wrong. Only the rationale's framing is stale.

Not worth a third migration on its own — a migration whose entire payload is a corrected comment is noise in the ledger. **Task 11 (`prune_telemetry_job`, stamp `20260819150000`) already touches `crash_reports`**, and its own migration must update the table comment anyway to flip "not yet present as of this migration" to present tense once the prune function exists. Correcting "deletion" → "deactivation" in that same `comment on table` costs nothing extra and lands in the file that makes the other half of the sentence true.

Carried into Task 11's dispatch.

*Cost if wrong:* a comment stays misleading for the remaining tasks. It misleads about *why* a column was chosen, not about what the code does.

Task 3: implemented (commit a976849). Review: spec ❌, quality Changes needed — 1 Critical, 1 Important.
  Critical: flush() removes by COUNT from the live queue, so a queue overflow during an in-flight flush deletes never-sent reports. Reviewer REPRODUCED it with a real test (queueLimit=3; A in flight, B/C/D enqueue, overflow evicts A, post succeeds for A, removal deletes B). Silent crash-report loss — the one failure mode a crash reporter must not have. Makes the class doc's third claimed property false.
  Important: PackageInfo.fromPlatform() unguarded in main.dart:71-73, inside a try/catch that rethrows — a telemetry version lookup can drop the app into the bootstrap error screen. PlaceIndexConfig three lines below is the documented precedent for the correct shape.
  Accepted adaptation (not drift): _currentUserId() extracted with its own try/catch — inlined, SupabaseConfig.client throws pre-init and the whole report would be dropped rather than queued. Reviewer confirmed only two SupabaseConfig touch points exist and both are guarded.
Task 3: fix round 1/5 dispatched.

Task 3: fix round 1/5 (2 addressed, 0 open — identity-based removal via _PendingReport+monotonic id+removeWhere; PackageInfo guarded per the PlaceIndexConfig precedent; commits a976849..8235fed)
Task 3: complete (commits 3453d7c..8235fed, re-review clean). Re-reviewer proved the regression test bites by reverting to count-based removal in a scratch edit (failed 3 vs 2) and left the tree clean. 1292 passing, 1 skipped, 0 failed.

Task 4: implemented (commit 4fa1eee). Review: spec ✅, quality Changes needed — 2 Important, 2 Minor.
  Important 1: the 9-case sweep only ever passes `reports: []`, so the filter chips, the card Rows and the stack-trace horizontal-scroll box are never rendered by any test. Horizontal-scroll correctness rested on a manual read of the widget tree. THE FAULT IS IN THIS PLAN'S OWN TEST TEMPLATE, not the implementer's reading of it.
  Important 2: nav entry landed ungrouped instead of in the Tokens & Seats group, and — the part that matters — has no `_FlyoutItem`, so it is unreachable from the collapsed rail.
  Minor: redundant nested Scaffold; dead server-side filter params on getCrashReports.
  Accepted deviation (not flagged): minelink_sidebar_core.dart also edited, because console_sidebar_nav_map_test.dart enforces nav-map consistency. The repo's own guard working.

### Ruling 11 — generalise Task 4's test-template defect to every remaining UI task

The empty-fixture sweep is not a Task 4 mistake, it is a defect in the plan I wrote, and Tasks 9, 10 and 12 inherit the same template. Rather than discovering it three more times in review, the requirement is now in the plan's Global Constraints: populated + hostile fixture, assert content is present, assert geometry where containment or alignment is the property that matters.

"Hostile" is specified concretely because the obvious fixture is useless — a long *sentence* wraps harmlessly; an unbroken 300-character token is what actually overflows a `Row`.

*Cost if wrong:* a few more test cases per screen. The alternative is a green sweep over a blank screen, which is the exact failure CLAUDE.md §10.5 already warns about ("28 green tests once covered 7 real screens").

Task 4: fix round 1/5 (4 addressed, 0 open — populated+hostile sweep with geometry assertions; nav moved into Tokens & Seats with its collapsed-rail flyout in BOTH sidebar implementations; nested Scaffold removed; filters wired server-side via FutureProvider.family + a lightweight facets query; commits 4fa1eee..31de699)
Task 4: complete (commits 8235fed..31de699, re-review clean). 1312 passing, 1 skipped, 0 failed. R-3 (crash reporting) now complete end to end: table, sink, reader.
Task 4: note — the implementer's F4 fix exceeded the brief in a good way: server-side filters apply `eq` BEFORE the 500-row cap, so an older matching row cannot be silently missed once the table outgrows the cap. Re-reviewer confirmed the record-keyed family has correct structural equality and does not leak a provider per rebuild.

### Ruling 12 — the fan-out trigger must degrade silently when no service-role key is configured

Measured on production 2026-08-19: `app.settings.supabase_url` is NULL, `app.settings.service_role_key` is unset, and `vault.decrypted_secrets` is empty. The plan's trigger reads `current_setting('app.settings.service_role_key', true)` into an `Authorization: Bearer` header, so as written it would post `Bearer ` (null concatenated away) and every call would 401 — **invisibly**, because the trigger swallows its own errors by design.

**I cannot fix this by supplying the key.** A service-role key must never be written into a committed migration, and this environment does not hold one. So:

1. The trigger **checks for the key first and returns immediately if it is absent** — no POST, no warning. Absence is the known, documented, expected state until Jean completes setup, and a warning on every notification insert is noise that trains people to ignore warnings. This is the same contract `PlaceIndexConfig` has for a paused extras project: a capability that can be missing must degrade, not shout.
2. It reads **Vault first, `app.settings` second**, so whichever mechanism Jean chooses works without another migration.
3. `docs/push-setup.md` (Task 12) gains this as a **sixth** required artifact alongside the five Firebase ones. Push was already 🟡 pending credentials; this is one more line in the same list, not a new class of problem.

*Cost if wrong:* push stays inert one step longer than expected. That is already true for the Firebase half, and the alternative — a trigger that 401s silently on every notification in production — is strictly worse because it looks like it works.

Task 5: implemented (commit 2bdf88b). Review: spec ✅, quality Changes needed — 2 Important, 1 Minor.
  Important A: `push-fanout` has NO incoming auth check, and its own header comment claims it does. With verify_jwt=false that is an open endpoint. Harmless while FCM_SERVICE_ACCOUNT is unset (returns 200 "skipped"), but the moment Jean sets that secret — no code change — it becomes an unauthenticated push fan-out for any UUID a caller supplies: spam/quota-exhaustion vector plus a notification-existence oracle. MUST FIX NOW, because the thing that arms it is a config change by someone who will not be reading this code.
  Important B: `device_tokens` comment states retention by `prune_telemetry_job()` as present-tense fact; that function does not exist yet. Identical to the Task 2 finding.
  Minor (accepted, not fixed): `register_device_token`'s `on conflict (token) do update set user_id = auth.uid()` lets a holder of another user's raw FCM token re-point it. Exploitation needs the opaque high-entropy token, which RLS does not expose; impact is denial of push on that token, not disclosure — `push-fanout` always selects tokens by the NOTIFICATION's user_id, never by the token's claimed owner. Accepted for the stated shared-depot-tablet use case; a clarifying comment is folded into the Task 11 pass.

### Ruling 13 — fold Important B into Task 11, fix Important A immediately

Same reasoning as Ruling 10 and now covering both tables. `20260819090000` is applied and stamped; CLAUDE.md §6 rule 1 forbids editing it, and a migration whose entire payload is a corrected comment is noise in the ledger.

**Task 11 (`prune_telemetry_job`, stamp `20260819150000`) is where the comment becomes true**, and it must rewrite both table comments anyway. It therefore now carries three comment corrections: `crash_reports` deletion→deactivation (Ruling 10), `crash_reports` retention forward-reference → present tense, and `device_tokens` retention forward-reference → present tense, plus the `register_device_token` token-reassignment note. All in the one migration that earns them.

**Important A is NOT deferred.** It is a security control that is missing while its own comment says it exists, and it is armed by a config change rather than a deploy — exactly the shape that gets missed. Fixed now, in the edge function, no migration needed.

*Cost if wrong:* the two comments stay misleading for six more tasks. They misled about retention timing, not about behaviour, and Task 11 is the natural home.

Task 5: fix round 1/5 (1 addressed, 0 open — push-fanout now 401s before any DB work, bare body, comment corrected; commits 2bdf88b..3870a5d)
Task 5: complete (commits 31de699..3870a5d, re-review clean, 2 parked)
Task 5: note — the accept path could NOT be verified live: nothing in this environment can read the real SUPABASE_SERVICE_ROLE_KEY (MCP withholds it by design, Management API 403s). The re-reviewer instead extracted `timingSafeEqualStrings` into a standalone Node script and asserted 9 cases (identical→true; first-char, last-char, shorter, longer, empty, case, trailing-space→false). Length mismatch forces diff=1 up front and the loop only ORs, so overlap cannot mask it. Encoding safe: TextEncoder is UTF-8 and a service-role JWT is ASCII base64url. **Jean still owes one live curl with the real key** — command is in task-5-report.md.

### Ruling 14 — fold the trigger's whitespace hazard into Task 11 as well

The re-reviewer found a residual in `20260819090000_device_tokens.sql`: the trigger tests `btrim(v_key) = ''` for emptiness but **never reassigns the trimmed value** before concatenating it into the `Authorization` header. A vault secret pasted with a trailing newline or space therefore produces a header that can never match, and because the trigger swallows its own errors by design, **push would silently never work and nothing anywhere would say why.**

One statement fixes it (`v_key := btrim(v_key);`). The migration is applied and §6 rule 1 forbids editing it, so it joins the Task 11 payload — which is now: four comment corrections (Rulings 10, 13) plus this. Task 11 must `create or replace` the trigger function to carry it.

This one is a **behaviour** fix, not a comment, so unlike the others it would have justified its own migration. It is folded only because Task 11 lands before any of this is configured, so no window exists where it matters.

*Cost if wrong:* if Task 11 slips, a whitespace-carrying secret fails silently. Mitigated by also stating the no-whitespace requirement in docs/push-setup.md (Task 12).

Task 6: implemented (commit 2ccebc1). Review: spec ❌, quality Changes needed — 1 Critical, 1 Minor.
  CRITICAL: the admin fan-out predicate `where pr.platform_role is not null` matches 114 of 117 profiles, because profiles.platform_role is NOT NULL and DEFAULTS to 'normalUser'. Only 3 rows are 'superGlobalSerialAdminMain'. Every deactivation request would have broadcast a high-importance notification NAMING THE REQUESTER AND QUOTING THEIR REASON to every user on the platform — mines, buyers, transporters, drivers. A person quietly asking to leave would have had that sent to their competitors and their own staff.
  **THE PREDICATE CAME FROM THIS PLAN, i.e. from me, not from the implementer.** Third plan-authored defect after the empty-fixture sweep (Ruling 11) and the insert_audit_log/driver-path faults (Ruling 6).
  Blast radius: ZERO. Verified — `account_deactivation_requests` is empty and no notification carries `deactivation_request_id`, because every probe ran inside a rolled-back transaction. The discipline of rolling back probes is what made a Critical in production code cost nothing.
  Minor (report-only): MLD01 fires before MLD02, so an owner with a pending request gets the ownership message. Correct order — ownership is the more fundamental and still-actionable blocker. Implementer asked to state it explicitly rather than leave it implicit.
  Accepted adaptation (not drift): notifications.type CHECK rejects 'account_deactivation', so 'general' is used with kind/deactivation_request_id carried in metadata. Reviewer confirmed the constraint live.

Fix: new migration 20260819105000_account_deactivation_admin_fanout_fix.sql (create or replace, corrected predicate) — NOT an edit to the applied file (§6 rule 1). Must be proved by COUNTING the notifications a probe produces (== 3 admins, not 114) and asserting the recipients are the admin profiles, then rolling back. A fix verified only by reading the SQL is how this got through the first time.
Plan text corrected at the source so the defect cannot be re-extracted into a future brief.

Task 6: fix round 1/5 (1 addressed, 0 open — MEASURED notified=3, admins=3, non_admin_recipients=0, recipient roles all superGlobalSerialAdminMain; deployed prosrc confirmed free of `is not null`; replaced function byte-identical to the original except the predicate and comments; commits 2ccebc1..3017e60)
Task 6: complete (commits 3870a5d..3017e60, re-review clean)

Task 7: implemented (commit 748d4bc). Review (opus): spec ✅ on the governing rule, quality Changes needed — 2 Important, 4 Minor.
  Implementer found and fixed THREE real bugs in the brief's own SQL, all verified live: notifications.type CHECK rejects 'account_deactivation'; audit_logs.target_type CHECK rejects 'profiles'; and — the important one — the brief's guard `is_platform_admin() or auth.role() = 'service_role'` could NEVER be satisfied by its own documented cron caller, because a pg_cron/plain-SQL call has no JWT at all and auth.role() is NULL, not 'service_role'. Task 8's backstop would have failed on every run.
  THE WIDENED GUARD IS SAFE, on evidence not reasoning: `proacl` on deactivate_account is `{postgres=X/postgres}` — public, anon, authenticated and service_role all have NO execute; authenticator inherits none of them; no definer wrapper references it; a real non-admin JWT was refused 42501 live. A null-uid caller must already BE postgres, which could rewrite the function anyway. Note `auth.role() = 'service_role'` is now dead code.
  IMPORTANT 1 (live-data bug, found by probe): `employees_company_required` is `company_id is not null or status = 'pending_company'`. Setting status='inactive' on such a row violates it and rolls back the WHOLE deactivation. One real user is in that state today (aaba128b-28a3-49cf-9ac8-735b4e171938), and once Task 8's cron exists it would retry that row nightly forever. reactivate_account has the same hole.
  IMPORTANT 2: review_account_deactivation_request writes no audit row, though spec §2.3 requires it — the approve/reject decision is precisely what an audit needs to attribute.
  Minors: no existence guard on reactivate_account (unknown uuid returns success + a misleading audit row); NULL-status trips vanish from active_trips; and the report's Probe A transcript could not have run as written (the brief's fixture uses profiles.user_type='buyer', which profiles_user_type_check rejects) — implementer told to report what actually executed.
  Verified zero residue: banned_until is not null = 0 before and after, 117 users unchanged.
Task 7: fix round 1/5 dispatched (new migration 20260819115000, not an edit to the applied file).

Task 7: fix round 1/5 (4 addressed + 1 unplanned, 0 open — commits 748d4bc..22a3c08)
Task 7: complete (commits 3017e60..22a3c08, re-review clean)
Task 7: controller verification beyond the re-review. I probed the cron path myself because the re-review's claim looked inconsistent with something I hit: a DIRECT `insert_audit_log` call from a no-JWT connection is REFUSED ('Platform admin access required' — require_platform_admin -> is_super_admin -> `p.id = auth.uid()`, and auth.uid() is NULL without a JWT). Yet `deactivate_account` succeeds in that same context. Resolved by reading the source: it BRANCHES. With a JWT it calls the shared insert_audit_log; with none it inserts into audit_logs directly as actor_platform_role='system'. So the cron path keeps its audit trail instead of silently dropping it, which is the right call and is documented in the migration. Verified live in a rolled-back transaction: deactivate SUCCEEDED, banned_until=infinity, exactly 1 audit row, action ACCOUNT_DEACTIVATED.
Task 7: note — `insert_audit_log` (shared, 11 callers) was patched as an unplanned fifth fix. Re-reviewer diffed it statement-by-statement against pg_get_functiondef: only `org record` -> two text locals, same values inserted. Accepted, and flagged to the final whole-branch review because shared code changed under a task that did not set out to change it.

Task 8: implemented (c5733ee). Review: spec ✅, Approved with 1 Important — the owner-exclusion was SILENT. Nothing logged; the job returned 0 identically whether nothing was due or N rows were skipped. Compounded by the console defaulting to pending-only (a stuck row sits at 'approved') and by review_account_deactivation_request not preventing an admin approving exactly the request that will then be skipped forever. The skip-owners DESIGN was judged sound; only its invisibility was the defect.
Task 8: fix round 1/5 (1 addressed, 0 open — once-per-run skip count, fires only when >0; predicate proven the exact complement of the loop's, character-for-character; commits c5733ee..5292cc7). Re-review retrieved the warning VERBATIM from postgres_logs, closing the implementer's disclosed gap: "apply_due_account_deactivations_job: 1 request(s) skipped -- requester owns a company; transfer ownership or suspend the company".
Task 8: complete (commits 22a3c08..5292cc7, re-review clean). Job returns 0; banned count 0. Cron live at 03:50 UTC.
Task 8 -> Task 10 carry: console must NOT default to pending-only, and a stuck 'approved' owner row must render distinctly from one merely awaiting tonight's run. Written into the plan.

Task 9: implemented (1dbe015). Review: spec ❌, 2 Critical.
  CRITICAL 1: password re-auth silently bypassable — it only ran `if (password.isNotEmpty)`, so typing DEACTIVATE alone submitted. Self-disclosed by the implementer, who argued nothing is granted because the RPC is security definer keyed off auth.uid(). **That defends the wrong threat.** It shows another ACCOUNT cannot be affected; re-auth exists to stop an unattended already-signed-in session — a shared depot tablet, a driver's phone on a seat. Such a session has a valid JWT and a valid auth.uid(). The RPC answers "is this uid allowed to do this" and says nothing about who is physically at the keyboard, which on a platform where devices are shared BY DESIGN is the entire point of the control.
  CRITICAL 2: the card imports and calls SupabaseConfig.client directly, violating CLAUDE.md §6 — and making its own service docstring false, which claims to be "the only file that touches SupabaseConfig.client".
  Both have ONE fix: move re-auth into AccountDeactivationService (already injected), so the widget stops touching the client AND the gate can be hard and unconditional while remaining testable. The implementer reported the test constrained the design; it did not — the injection point already existed and was not used.
  Minor: account_deactivation_request.dart:40 falls back to DateTime.now().toUtc() for a NOT NULL column; unreachable but a wall-clock read that can reach a displayed date (§7.1 is categorical).
  Clean on everything else, independently re-verified: no "delete" anywhere in the rendered widget (checked by reading the file, not just trusting the test), MLD01/MLD02 branch on e.code only, MLD01 names both routes, `approved` hides Cancel, tests assert real content across populated states with hostile 300-char unbroken tokens, mounted on both profile surfaces.
Task 9: fix round 1/5 dispatched. Regression test for the empty-password case must be shown FAILING against current code first.

Task 9: fix round 1/5 (3 addressed, 0 open — re-auth is now a hard unconditional gate on the service; widget no longer imports SupabaseConfig; DateTime.now() fallback dropped; commits 1dbe015..004a1f3)
Task 9: complete (commits 5292cc7..004a1f3, re-review clean). 1357 passing, 1 skipped, 0 failed.
Task 9: note — re-reviewer went beyond the ask and searched for ALTERNATE submit paths (onSubmitted / onFieldSubmitted / TextInputAction / autofocus): none exist, and MlButton's onPressed:null genuinely disables InkWell.onTap rather than just styling it. A hard gate on one button is worthless if a text field's submit handler bypasses it. It also PROVED the regression test bites by reverting the gate to its old shape, watching the test fail, and restoring — tree verified clean.

Task 10: implemented (a1d0c45). Review: spec ✅, quality Changes needed — 2 Important.

### Ruling 15 — the swept-in "Margin ledger History" rename STAYS. Reverting it would break another session's in-flight work.

Commit `a1d0c45` bundled a rename unrelated to this task — "Margin ledger" → "Margin ledger History" in `minelink_sidebar_core.dart` and `super_admin_shell_layout.dart`. That is exactly the CLAUDE.md §10.1 hazard: several sessions write this worktree and work gets swept into somebody else's commit.

The instinct is to split it out. **That would be the wrong move here, and I verified why before deciding:** the other session's *uncommitted* files already carry the other half — `margin_ledger_screen.dart:165` sets the new title and `test/widgets/app_sidebar_behaviour_test.dart:176,186` tap `find.text('Margin ledger History')`. Reverting the committed half would make that session's own test fail against a label that no longer exists. §10.1's rule is *never touch uncommitted state that is not yours*; reverting would violate it by proxy.

So it stays, and the mitigation is attribution rather than removal: recorded here, and surfaced to the final whole-branch review and to Jean, so nobody reads `a1d0c45` and concludes the deactivation console renamed the margin ledger.

*Cost if wrong:* one commit contains a change its message does not mention. The alternative was breaking a live session's work to tidy a label.

Important 2 (Approve has no confirmation, while Reject and Reactivate both do) → fix round 1 dispatched. Self-flagged by the implementer as wanting a second opinion; the reviewer agreed it is not clearly defensible.

Task 10: fix round 1/5 (1 addressed, 0 open — Approve now confirms, names the person, and warns on an owner row; commits a1d0c45..e7abdb8)
Task 10: complete (commits 004a1f3..e7abdb8, re-review clean). 1386 passing, 1 skipped, 0 failed.
Task 10: note — the re-reviewer traced the SQL to check the dialog's consequence text is TRUE rather than plausible: review_account_deactivation_request only flips status to 'approved' and notifies; the lockout happens later in the 03:50 cron. The dialog says "once this is applied by the nightly run", which is correct. A confirmation that misdescribes its own consequence is worse than none.
Task 10: the two concurrent-session files (margin_ledger_screen.dart, app_sidebar_behaviour_test.dart) remain modified and untouched throughout, verified after every step.

Task 11: complete (commits e7abdb8..bb9fe2d, review Approved, no fix round). prune_telemetry_job live at 55 3 * * * (11 cron jobs, no collision); returns 0; bound proven (2 of 5 eligible rows under a limit). All FIVE deferred corrections verified against DEPLOYED state via obj_description, not against the file: crash_reports deletion->deactivation with the SET NULL choice still stated as correct, both retention hedges dropped, device_tokens token-reassignment risk documented, and notifications_push_fanout byte-identical to 20260819090000 except the one added `v_key := btrim(v_key);`.

### Finding — the crash sink works, and that is how we learned it floods

`crash_reports` went 0 -> 36 rows during the session from REAL usage. All 36 are the same non-fatal Flutter framework advisory ("ListTile background color or ink splashes may be invisible"), platform web, inside a 7-second window — 35 of them at the same millisecond. One list render produced 36 rows.

Traced to `list_tile.dart:1147-1178`: the check sits inside `assert(() {...}())`, so it is **stripped from release and profile builds**. Zero risk to a shipped app. The exposure is that this project has no staging (CLAUDE.md §10.2) and every local debug run writes to production — which is its normal, accepted operating mode.

Root cause: `installCrashHandlers` forwards every `FlutterErrorDetails` without consulting `details.silent`, and `SupabaseReportingSink` has no dedup or rate limit — `queueLimit` bounds memory, not the insert rate, so 35 identical reports in one millisecond became 35 rows.

Severity: **Important, not Critical.** 90-day retention bounds accumulation but does nothing about write rate.

### Ruling 16 — fix the flood now rather than listing it as a follow-up

The reviewer scoped it as a follow-up, correctly for a migration-only task. But leaving it means shipping a crash reporter whose first observed behaviour in production was to write 36 junk rows in 7 seconds, against a 500 MB free-plan database whose history includes a two-hour outage from write and disk pressure. "The crash reporter is done" is not true while that is its behaviour.

It is a small, well-understood change to a file that already has a tested seam, so it goes in now as Task 11b rather than onto a list nobody reads.

*Cost if wrong:* one extra small task. The alternative is a known flood left running against the database this plan is meant to protect.

Task 11b: complete (commits bb9fe2d..e176391, review Approved). 1409 passing, 1 skipped, 0 failed. Dedup collapses a burst into one row + count; first occurrence never delayed; 60s bounded window, map pruned every report() so it cannot leak; `silent` respected; NO message-text filtering (a denylist rots and can suppress real errors — dedup and `silent` are structural).
Task 11b: the reviewer traced the worst case on the CHECK constraint arithmetically — a 4096-char error plus a ' (x36)' marker re-clips to `keep = 4096 - marker.length`, giving exactly 4096, never over. That was the single most likely defect in the change and it is provably absent. A violation there would have been invisible: the sink swallows its own insert failures by design.
Task 11b: minor (deferred): fingerprint is `context + ' ' + error` with a plain space, so ('A','B C') and ('A B','C') collide. Narrow and unexploited by any current caller, untested. Fix with a non-printable separator or a length-prefixed context.
Task 11b: minor (deferred): `_PendingReport.row` is mutated in place to add the count marker while a flush may be in flight; correct under the mocked postBatch, not independently confirmed against supabase_flutter's serialisation timing.

Task 12: complete (commits e176391..e64eb7e, review Approved, no fix round). 1424 passing, 1 skipped, 0 failed. Web release build succeeds with no Firebase config — the real proof of degradation.
Task 12: the implementer went beyond the brief and also ran `flutter build apk --debug` with no google-services.json, which caught an XML-comment bug (`--` is illegal inside `<!-- -->`) in its OWN manifest edits, and proved the conditional Gradle apply genuinely works. Neither the web build nor the test suite would have caught that.
Task 12: Windows/macOS/Linux send NOTHING — `_platformString()` returns null outside android/iOS and `_pushToken()` returns before calling the RPC, so `device_tokens.platform`'s CHECK ('android'|'ios'|'web') can never be violated by a desktop run. Verified by code read, not inference.
Task 12: minor (deferred): a push carrying `metadata.nav_tab` lands on `/home` rather than the named tab, because PushService has no ProviderContainer outside the widget tree. `route`-based links ARE exact. Real gap for driver dispatch; documented in three places rather than silently shipped.

Task 13: complete (commits e64eb7e..238baa1). COLD REPLAY RAN FOR REAL: 270/270 applied into an empty project, 0 failures, including all ten of this plan's migrations. First attempt died at 144/270 with no traceback (collateral from a concurrent session on this shared machine); relaunched detached and it completed. BOTH scratch projects deleted and verified gone via GET /v1/projects.
Final whole-branch review (opus): 2 must-fix, 5 should-fix-soon, deferred minors triaged.
Final fix wave: complete (238baa1..ab0885c), re-review clean. 11 migrations, 11 ledger rows, stamps exact. 1424 passing, 1 skipped, 0 failed. Residue clean: 0 banned, 0 requests, 36 crash_reports preserved.

### Ruling 17 — park the `'expired'` company-status gap; do not open a second fix wave

The fix wave carved `status <> 'suspended'` out of the owner block. `companies_status_check` actually allows five values (`active, pendingActivation, expired, suspended, blocked`), and the live `expire-organizations-daily` cron sets `'expired'` on orgs whose token lapses — with no admin action. So an owner of an *expired* company is still stuck at all four gates.

**Pre-existing, not introduced here** — the old code blocked them too. And the fix wave's own rationale ("a company already suspended is out of operation") applies just as well to an expired one, so the carve-out is arguably too narrow.

Parked rather than fixed: the skill allows exactly one fix wave after the final review, this is not load-bearing for anything downstream, and widening the predicate is a product decision about whether an expired org is equivalent to a suspended one — not mine to make silently at the end of a run.

*Cost if wrong:* an owner of an expired company still cannot deactivate. Same state they were in before this work; now documented with the exact one-line fix identified.

### Ruling 18 — `tool/schema_parity_baseline.json` is left stale, because I cannot refresh it

The final review flagged this as must-fix-before-merge: the baseline predates these eleven migrations, so 8 of 9 shapes now report DIFFER. Every delta was checked and matches the new objects exactly — no unexplained drift — but a guard that always reports DIFFER is a guard turned into noise, which is precisely what it exists to prevent.

`python tool/schema_parity_check.py --accept` needs `ML_LEDGER_PASSWORD`, deliberately absent from this environment. **I cannot run it.** Surfacing to Jean rather than leaving it silently stale or pretending it passed.

*Cost if wrong:* the parity guard stays noisy until Jean runs one command.
