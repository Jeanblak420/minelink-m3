# Mine-Link — To-Do's

> **Consumer Release v1.0 execution checklist.** Companion to `PLAN.md`. **Revision 2** — full second-pass audit (all 126 routes, all 31 super-admin screens, 11 further feature modules, 153 migrations, all assets, all build configs).
>
> Tick a box **only** when the item is fully implemented — frontend *and* backend, DB *and* UI, wired end to end and verified in a running app. Not on a stub, not on one screen, not on a happy path.
>
> ## ⚠ SEQUENCING DIRECTIVE (client, 2026-08-10)
> **Build everything in, fix it, ship the redesigns and get the full flow working END TO END *before* deleting anything.**
> Phase 1 (Demolition) is therefore **deferred to the end** and renumbered **Phase 12**. The demolition targets are dead weight, not active harm — nothing breaks by leaving them in place a while longer, and deleting before the replacements are proven means losing the reference implementation while you still need it.
> The one exception is **P1-01/P1-02** (`controller_tab_screen`, `security_tab_screen`): they hold the ONLY links to `/operations?tab=security` and `?tab=weighbridge`, so they must stay until the security and controller nav trees carry those entries (P7-18). Do not delete them first.
>
> ## 🗑 SCOPE REMOVAL (client, 2026-08-11)
> **Employee dismissal is removed from the app entirely.** Do not build any part of it. The removal work is **§10.1 (P10-01…P10-06)** and is **EXEMPT from the sequencing deferral above** — it is a scope removal by client decision, not cleanup, so it runs now. **P7-34 is cancelled.** The one hard stop: **`employees.is_dismissed` must NOT be dropped** — 19 functions incl. `is_company_staff` / `is_company_manager` and the `chat_directory` view depend on it.
>
> ## ✅ CLIENT RULINGS — 2026-08-11 (all four are DECIDED; do not re-ask)
> 1. **Roles must be constrained by org type (supersedes P0-13).** A buyer is a *company*, not a mine. `employees_role_check` today permits **all six roles at any org type** — there is no org-type predicate anywhere, so nothing stops a buyer's employee being made Security or Weighbridge Controller. Live data is currently clean but that is luck, not enforcement. **The matrix, as ruled by the client 2026-08-11:**
> · **buyer** → `admin`, `management` — **and nothing else**
> · **mineSupplier** → `admin`, `management`, `supervisorForeman`, `security`, `controllerWB`
> · **transporter** → `admin`, `management`, `driver`
> `supervisorForeman` is **mine-only**. `security` and `controllerWB` are **mine-only**. `driver` is **transporter-only**. Enforce in `assign_employee_role`, in a trigger on `employees`, in the seat `role_binding` check, and in every role picker in the UI. See **P3-51**.
> 2. **Apply the `companies` counterparty RLS tightening** — `docs/rls-companies-tightening.md`, approved. Verified against live data: no company loses a real partner.
> 3. **`chat-attachments` and `support-attachments` become private** with signed URLs. **`company_assets` stays public** (logos render on partner-facing screens).
> 4. **NO SYSTEM-ENFORCED OFFLOAD HOLD. Weight disputes are settled between the counterparties, not by the app.** Client, 2026-08-11: *"Any and all differences will be handled between the buyer and the transporter, or between the mine and the buyer — that's why we have this built into the app, so that they can fight with each other and get it sorted out between each other."* The app's job is to **surface the discrepancy to both sides and give them the venue**, never to block a trip. See **P8-30**. The dispute machinery already exists and has **never once been used** — `recon_disputes` (0 rows), `recon_dispute_comments` (0), `raise_recon_dispute`, `set_recon_dispute_status`, `add_recon_dispute_comment`, `list_recon_disputes`, plus `recon_dispute` in `notifications_type_check` (0 notifications ever sent). Wire it, do not rebuild it.
>
> ## ✅ CLIENT RULINGS — 2026-08-12 (three more; all DECIDED, do not re-ask)
> Received in `RULINGS-2026-08-12.md`. One of them is **not** what the session recommended.
>
> 5. **P10-D5 is a PARTIAL purge, not the full one. The seeded trips and transactions STAY.**
> Delete only: `pod_uploads` where `photo_url = 'insights-demo/pod-placeholder.jpg'` (33) · `reconciliations` `metadata->>'seed' = 'portal_demo_v1'` (1) · `haul_routes` same predicate (1) · `vehicle_positions` `source = 'portal_demo_v1'` (2). **KEEP** the 38 seeded trips and 38 seeded transactions — the client wants the dashboards to still show movement — **KEEP** `showcase_data` (14) and the `Chrome Ore - Atlas (UI test)` stockpile.
> **⚠ Required companion, or the purge is incoherent:** deleting the 33 PODs does not clear `trips.delivered_tons` (the 2026-08-11 migration backfilled it *from* those PODs, and `variance_tons` is generated off it). Left alone, all 38 seeded trips keep a delivered figure and a fabricated **0.2000 t** variance **with no POD behind it at all** — the precise fiction P10-D1 exists to stop, now with its evidence deleted. **Null `delivered_tons` on every seeded trip in the same migration**; `variance_tons` then goes NULL, which reads as *not comparable* — the truth. `net_tons` stays, so tonnage and trip counts survive.
> **⚠ Say this back to the client when it is done:** total recorded tonnage stays at ~1,193.7 t, of which **1,123.7 t — 94.1% — remains invented, by the client's explicit choice. Every super-admin tonnage figure is still fiction. Any dashboard verification against those totals is verification against fiction — label it that way in the item ticked, and do not record it as proven.**
> **P0-08 first.** The PITR marker / backup needs a human on the Supabase dashboard. **If it has not been done, stop and say so — do not run the deletes.**
> 6. **P10-D7 — proof of delivery must require proof.** The POD photo becomes **mandatory**; a driver cannot complete a delivery without one. Enforce **server-side in `record_pod` as well as in the UI**, so the requirement is real rather than a disabled button. Wire the existing `LifecycleService.uploadPodPhoto`, do not rebuild it. **Prove one real upload lands an object in `pod_photos`** — a green test that does not put bytes in the bucket has not proven this.
> 7. **P10-D8 — the client KEEPS `showcase_data` and the UI-test stockpile. Fix the banner instead of the data.** `DemoDataIndicator` cannot ship saying something untrue. **Do not delete the 14 rows. Do not delete the stockpile.** P10-23 and P3-42 both amended to match.
>
> **Legend:** `- [ ]` open · `- [x]` done · 🔴 blocker · 🟠 high · 🟡 medium · 🟢 low · 🆕 new in Revision 2
> **Root:** `worktree-2026-05-05T11-53-29` · **Supabase:** `yftazblpmicqtamyiwyb` (production — no staging)

**Progress: 122 / 415** *(recounted 2026-08-13 by `grep -c '^- \[x\]'`, not incremented; 413 → 415 because P10-D7 and P10-D8 are new items. +6 on 2026-08-13: P0-11, P11-03, P11-01, P0-08, P1-26, P10-D5)*  ·  ✅ **THE BLOCKER IS CLEARED. The P10-D5 purge RAN on 2026-08-13** (`20260813092000`), after the client waived the P0-08 backup — *"nothing needs backup, this is all just dummy data, nothing is real all just test."* There is **no restore point**; P0-08 is ticked as **decided, not done**. Guard and post-conditions passed; before/after counts in `COMPLETION-CHECKLIST.md` S3-2. `supabase/pending/` is now empty.  ·  ⚠ **Say this to the client, unchanged: tonnage stays ~1,193.7 t of which 1,123.7 t (94.1%) remains invented by their explicit choice — every super-admin tonnage figure is still fiction, so any dashboard "verification" against those totals is verification against fiction.**  ·  ⚠ **A SECOND seed was found and disabled** — `[db.seed] enabled` was `true` with `supabase/seed.sql`, 27 KB of fabricated companies, employees, `auth.users`, transactions and chat, sharing **none** of the markers the purge deleted by. One `db reset` would have re-injected it. Now `false` (S3-14).  ·  ✅ 2026-08-13 also landed: `org.minelink` replacing `com.example.*` (P11-01, proven from the built APK), every empty `catch {}` logging (P0-11, 38 of them not 10), `minerals` RLS narrowed (P3-44), SVG dropped from the one public bucket, and `MlSampleData`/`MlTargetsSample` moved out of `lib/` (P1-26, P5-03 in part).  ·  ✅ 2026-08-12 landed: proof of delivery requires proof (P10-D7), the weight-dispute venue (P8-30), `companies` RLS narrowed (P3-43), both customer-content buckets private (P3-52/53), the false demo-data banner removed (P10-D8), and the Esri token de-bundled (**rotation still owed — P0-04**).  ·  ✅ **Employee dismissal is removed from the product** (P10-01…P10-06). ✅ **P3-46 remains withdrawn.**  ·  🔴 **Open human items: P0-04** (rotate the Esri token) and **P11-02** (the release keystore). Branch `chore/release-v1-hardening`

> ⚠ **The progress figure is the count of `- [x]` boxes in this file** (`grep -c '^- \[x\]'`). It drifted twice on 2026-08-11 because more than one session edits this file at once (CLAUDE.md §10.1) and each was hand-editing the number against a stale copy. Recount rather than increment.

| Phase | Items | Done |
|---|---|---|
| 0 Guardrails | 14 | 5 |
| ~~1~~ → **12** Demolition *(deferred to last)* | 30 | 0 |
| 2 Data-layer correctness | 11 | 7 |
| 3 Backend hardening | 67 | 18 |
| 4 Routing & guards 🆕 | 30 | 10 |
| 5 Design system extraction | 32 | 1 |
| 6 Portal migration | 29 | 0 |
| 7 Navigation, dashboards & Employee Register 🆕 | 44 | 33 |
| 8 Workflow completion | 48 | 23 |
| 9 Super admin completeness | 27 | 6 |
| 10 Cross-cutting | 33 | 13 |
| 11 Platform, verification, release | 14 | 0 |
| *Release gate* | 20 | 0 |
| *Appendix C blind spots* | 16 | 0 |

> Counts in this table are **measured**, not maintained by hand: every figure is
> `grep -c` per section, **re-measured 2026-08-12 after the three new rulings**.
> Earlier revisions drifted because two sessions each edited a literal.
> Re-measure rather than adjust. Phase 3 includes §3.9, which is where P8-30
> lives; Phase 10 grew by 2 items (P10-D7, P10-D8).

---

## Phase 0 — Guardrails

- [x] 🔴 **P0-01** Create a working branch. **Done — `chore/release-v1-hardening`.** Never `git stash` / `git checkout -- .` / `git clean` / checkout another branch in this worktree.
- [x] 🔴 **P0-02** Run `flutter analyze`; record the baseline here. **Baseline 2026-08-11 on `chore/release-v1-hardening` @ `ff3ca79`: `No issues found!` (110.2 s) — 0 errors, 0 warnings, 0 infos.** This is the first time the four Dart files changed in `f9add87` have ever been compiled (the cloud session that wrote them had no shell); they compile clean as written. Target at the end: **0 new warnings**.
- [x] 🔴 **P0-03** Run `flutter test`; record the baseline. **Baseline 2026-08-11: `All tests passed!` — 522 tests, 0 failures, 32 s.** ⚠ Read that as a *starting* number, not as coverage: per the standing rule the metric is **screens proving something / N**, and the console sweep alone accounts for several hundred of those 522 (one test case per width × text-scale combination, not per screen). The portal has no equivalent sweep at all — P11-11 extends it. One non-fatal log surfaces during the run and is expected offline: `[LiveTrackingService] live trips refresh failed: PostgrestException(code: 400)` in the console live-map case.
- [ ] 🔴 **P0-04** 🆕 **Rotate the Esri ArcGIS token** in `config/map_tiles.local.json`. It is currently bundled into every web and Windows artifact (P11-03).

  ⬜ **De-bundling is DONE 2026-08-12; the ROTATION is still owed and needs a human.** The two halves are separate and only one of them is an agent's to do.
  · **Done — the token no longer ships.** `pubspec.yaml` declared `- config/`, which bundles the *whole directory*, so `config/map_tiles.local.json` and the live token inside its `MAP_TILE_URL` went into every artifact and was fetchable on web at `/assets/config/map_tiles.local.json`. **Gitignoring it never stopped this — the asset bundler and `.gitignore` are unrelated mechanisms, which is exactly how a gitignored secret shipped anyway.** Replaced with the single file that is actually read from the bundle, `config/supabase.live.json` (`supabase_config.dart` → `rootBundle`). `MAP_TILE_URL` was never an asset read: it comes from `String.fromEnvironment` in `osm_tile_layer.dart`, fed by `--dart-define-from-file`, so nothing needed it bundled. **Proven, not assumed:** `flutter build web --release` succeeds, `build/web/assets/config/` now contains only `supabase.live.json`, and a grep of the entire release output returns **0 files containing the token and 0 containing the string `arcgis`** (it was present before). This also closes the bundling half of **P11-03**.
  · 🔴 **Still open — the token itself is live and has already shipped** in every web/Windows artifact built to date, so it must be treated as disclosed. **Rotating it requires signing in to `minelink.maps.arcgis.com` and issuing a new key**, which no agent here can do. Replace the value in `config/map_tiles.local.json` (gitignored, stays local) and revoke the old one. Until then the exposure is historical but real.
- [ ] 🟠 **P0-05** Reconcile `supabase/migrations/` (153 files) against `supabase_migrations.schema_migrations`. Any applied migration with no file is unreproducible — write the file now.
- [ ] 🟠 **P0-06** 🆕 Fix the **6 duplicate migration timestamp prefixes** — ordering is undefined on `db push`: `20250505000000` ×2, `20250507000000` ×3, `20250507000003` ×2, `20250511000000` ×2, `20260714000000` ×2, `20260727120000` ×2.
- [ ] 🟠 **P0-07** 🆕 Delete or archive the **stray unmanaged `migrations/` folder at repo root** (4 loose SQL files outside the Supabase chain).
- [x] 🔴 **P0-08** Back up / set a PITR marker before Phase 3 touches `trips`. ✅ **WAIVED BY THE CLIENT 2026-08-13 — no backup was taken and none exists.** Ruling, verbatim: *"nothing needs backup, this is all just dummy data, nothing is real all just test."* Ticked as **decided, not done** — the distinction is the point: if a later deletion removes something wanted, there is no restore point and this line is the record of why. On that ruling the P10-D5 purge ran 2026-08-13 (`20260813092000`), guard and post-conditions passing, before/after counts in checklist S3-2.
- [x] 🟢 **P0-09** ~~Verify `Sora` is in `pubspec.yaml`~~ — **RESOLVED: `Sora` is declared with all 5 weights and all 5 TTFs exist on disk. The console typography is intentional; the portal adopts Sora.**
- [ ] 🟡 **P0-10** Delete stray `void main()` entrypoints from `lib/`: `canary_test_app.dart`, `minimal_app.dart`, `realtime_example.dart`, `debug_screen.dart`, `debug_simple.dart`, `debug_realtime.dart`, `debug_supabase.dart`.
- [x] 🟡 **P0-11** Fix the empty `catch {}` blocks — log via `LoggerFactory` or rethrow. No silent swallows.
  ✅ **There were 38, not 10** — the count here was never re-derived after `employee_profile_service.dart` landed with 32 of them. Fixed by fault class, not uniformly: the 32 optional-enrichment catches log at `debug` and still drop their one card (rethrowing would drop a whole profile screen over one unreadable table); the realtime subscribe logs at `warn` (silent failure there reads as "nothing is happening on this account"); the map-camera catch logs at `debug` (throws only pre-layout, where 0 is the right rotation — logged so a *persistent* throw is visible instead of pinning the truck arrow north all trip). — **Proven red first:** the guard pattern over `git archive HEAD lib` returns 38, over the working tree 0; guard `no-empty-catch` at `Mode.block` reports `BITES (clean 0 → planted 1)`, runner exit=0, `flutter analyze` clean, 689 tests green — commit `f811a4e`.
- [ ] 🟢 **P0-12** Add CI greps that fail the build on: `Color(0x` in `lib/features/`, `Colors.` in `lib/features/`, `coming soon` in `lib/`, `const [` passed to a `spark:` argument, and any `class _` extending a Widget inside `app_router.dart`.
- [x] 🔴 **P0-13** ✅ **RULED 2026-08-11 — buyers get NEITHER role, and the app must ENFORCE that.** The question was wrongly framed as build-or-drop. The real defect: `employees_role_check` allows all six roles at any org type, `organization_seats.role_binding_check` likewise — **no org-type predicate exists anywhere in the schema.** Nothing prevents a buyer's employee being made Security or Weighbridge Controller; live data is clean by luck. Enforcement work is now **P3-51**.
- [ ] 🟢 **P0-14** Client ruling: the 8 `tabs/screens/*` "workspace" screens can be deleted (they show employee lists; replacements are `company_employees_screen` + the new Employee Register).

---

## Phase 12 (deferred — was Phase 1) — Demolition

> **Do not start this until the replacements are built, wired and proven.** Per the client's sequencing directive, nothing here is deleted before the full flow works end to end. Kept in place, these files cost nothing but clutter; deleted early, they take the reference implementation with them.

### 1.1 The fake workspace screens

- [ ] 🔴 **P1-01** Delete `lib/features/tabs/screens/controller_tab_screen.dart` — referenced by nothing; "Weighbridge Workspace" showing employees. ⚠ **First move its `/operations?tab=weighbridge` link into the controller nav tree (P7-19).**
- [ ] 🔴 **P1-02** Delete `lib/features/tabs/screens/security_tab_screen.dart` — same. ⚠ **First move its `/operations?tab=security` link into the security nav tree (P7-19).**
- [ ] 🔴 **P1-03** Delete `mine_supplier_tab_screen.dart` — *"Production and mineral workflows will appear here"* → employee list.
- [ ] 🔴 **P1-04** Delete `buyer_tab_screen.dart` — "Buyer Workspace" = employee list.
- [ ] 🔴 **P1-05** Delete `transporter_tab_screen.dart` — metrics duplicated on the transporter dashboard.
- [ ] 🔴 **P1-06** Delete `admin_tab_screen.dart`.
- [ ] 🔴 **P1-07** Delete `management_tab_screen.dart` — "Operational Queue" section contains employees.
- [ ] 🔴 **P1-08** Delete `driver_tab_screen.dart` — duplicated by `DriverProfileTab`; renders "Not linked / None" on transporter company accounts. ⚠ Also routed at `/portal/transporter/drivers` — replace with a real drivers screen (P8-12).
- [ ] 🔴 **P1-09** Delete `lib/features/tabs/widgets/operations_workspace.dart` — bypasses `MlTokens` entirely (raw `colorScheme`, magic radii 30/28/26/24, `withAlpha(190/185/160/150/42/18)`). Largest single token violation.
- [ ] 🔴 **P1-10** Remove all `tabs/` imports and `PortalTabItem` entries from `portal_navigation.dart` and `app_router.dart`.
- [ ] 🟠 **P1-11** Remove the decorative `_WorkspaceChip('Live Workspace')` chip (dies with P1-09).

### 1.2 Dead and duplicate code

- [ ] 🟠 **P1-12** Delete `PortalStatCard` and `PortalFeatureCard` from `portal_widgets.dart` — **zero call sites**, yet the file is imported by 30 screens purely for `PortalScrollBody`.
- [ ] 🟠 **P1-13** Merge `transporter_truck_positions_screen.dart` into `transporter_truck_locations_screen.dart` — same provider, same panel, same data.
- [ ] 🟠 **P1-14** Collapse the three `*_truck_locations_screen.dart` files into one parameterised screen.
- [ ] 🟠 **P1-15** 🆕 Delete the **legacy `lib/core/mcp/` data layer** (`company_repository`, `employee_repository`, `supabase_repository` + models) — a parallel second source of truth used only by two orphaned screens.
- [ ] 🟠 **P1-16** 🆕 Delete `company/screens/company_list_screen.dart` — routed at `/companies/:orgType`, **zero inbound links**, uses the legacy layer.
- [ ] 🟠 **P1-17** 🆕 Delete `employee/screens/employee_grid_screen.dart` (incl. the never-used `EmployeeDetailsScreen` / `EmployeeDetailsLoaderScreen`) — routed at `/employees/:companyId`, zero inbound links.
- [ ] 🟠 **P1-18** 🆕 Delete the 4 now-dead routes: `/companies/:orgType`, `/companies/:orgType/:companyId/details`, `/employees/:companyId`, `/employees/:companyId/:employeeId/details`.
- [ ] 🟠 **P1-19** 🆕 Delete `demo/screens/components_demo_screen.dart` — never mounted; sole navigator to `/companies/:orgType`.
- [ ] 🟠 **P1-20** 🆕 Delete `fleet/screens/fleet_document_debug_screen.dart` + `fleet_document_debug_service.dart` — debug tool shipping in `lib/`.
- [ ] 🟠 **P1-21** 🆕 Delete `notifications/utils/update_notification_schema.dart` — no-op stub, zero callers.
- [ ] 🟠 **P1-22** 🆕 Delete the 3 orphan notification widgets: `universal_notification_button.dart`, `role_notification_button.dart`, `notification_icon.dart`.
- [ ] 🟠 **P1-23** 🆕 Delete `web/debug_loader.js` and `web/debug_toggle.js` — orphaned, but `flutter build web` copies everything in `web/`, so they ship today.
- [ ] 🟡 **P1-24** Delete `super_admin/widgets/platform_metric_grid.dart` — **zero references**; legacy card recipe superseded twice.
- [ ] 🟡 **P1-25** 🆕 Decide `super_admin_dashboard_v2_screen.dart`: it is **strictly better than the live dashboard** (real `_spark()` from weighbridge rows). **Promote it** (preferred, see P9-01) **or delete it and `MlSampleData` with it.**
- [x] 🟡 **P1-26** 🆕 ~~Delete~~ **Move** `minelink_targets_core.dart` `MlTargetsSample` (12 months of invented tonnage, zero references *in `lib/`*). ✅ Moved verbatim to `test/fixtures/ml_targets_sample.dart` 2026-08-13. ⚠ **"Zero references" held only for `lib/` — 3 test files use it as a fixture**, so deleting it would have taken their data with it. The defect was that it shipped inside the library, not that it exists. Red-first: 4 hits over `git archive HEAD lib`, 0 now; guard `no-sample-data-in-lib` at `Mode.block` bites; 689 tests still green.
- [ ] 🟡 **P1-27** 🆕 Move the undeclared planning folders out of `assets/` (`.MineLink planning_xml/`, `new looks & extra functions/`, `premium-org-type-screens…/`, loose `.md`/`.txt`). They ship nothing but bloat the repo.

### 1.3 🆕 Dismissal schema residue — **ASK THE CLIENT FIRST**

- [ ] 🟡 **P12-28** After §10.1 lands, the following are provably unused in every row and droppable — but each is a **schema drop, outside the granted DB autonomy. Stop and ask before running any of it.**
  `employees`: drop columns `dismissal_date`, `dismissal_reason`, `dismissal_by_id`, `is_dismissal_final`, `is_dismissed_pending_appeal`, `account_deletion_date`; drop index `employees_dismissal_by_id_idx`; drop `'dismissed'` from `employees_status_check`. *(`assign_employee_role` writes `is_dismissal_final` and `is_dismissed_pending_appeal` — edit it in the same migration.)*
  `employee_status_history`: drop columns `appeal_reason`, `dismissal_reason`, `decision_reason`, `uphold_dismissal`, `account_deletion_date`; drop `'dismissal_initiated'`, `'appeal_submitted'`, `'dismissal_upheld'`, `'dismissal_reversed'` from `employee_status_history_status_check`.
  `notifications`: drop `'dismissalInitiated'`, `'dismissalAppeal'`, `'dismissalFinal'` from `notifications_type_check`.
  **`employees.is_dismissed` is NOT on this list and never will be** — 19 functions and the `chat_directory` view depend on it.

### 1.4 Verify

- [ ] 🔴 **P1-28** `flutter analyze` clean after demolition.
- [ ] 🔴 **P1-29** App boots; every remaining route resolves for a company account of each org type.

---

## Phase 2 — Data-layer correctness

- [x] 🔴 **P2-01** **Scope `vehicle_positions`.** **Done — bounded by time (30 days) and paged in full; deliberately still unfiltered by company, because a buyer must see the transporter's trucks and RLS is where that belongs.** Today `.order('recorded_at', desc).limit(500)` with **no company or vehicle filter**. Past 500 platform-wide pings a company's trucks vanish and the map shows empty while trucks report. Replace with `list_live_trip_positions(p_company_id)`.
- [ ] 🔴 **P2-02** Confirm RLS on `vehicle_positions` independently restricts by company — the current UI's correctness depends entirely on it.
- [x] 🔴 **P2-03** **Remove the `.limit(200)` in `listPartnerCompanies`.** **Done — paginated.** Paginate exhaustively like the transaction/trip queries in the same file already do.
- [x] 🟠 **P2-04** **Done.** Replace `catch (_) { return const []; }` in `listPartnerCompanies` with real error propagation — an RLS failure must not look like "no partners".
- [x] 🟠 **P2-05** **Done 2026-08-11.** Swept; the remaining reads in `logistics_service.dart` all page exhaustively. Both new paged reads were additionally re-keyed off **non-unique** sort columns (`recorded_at`, `updated_at`) onto `id`: `.range()` paging over a non-unique sort has no defined order within a tie, so a row can repeat on one page and be skipped on the next — a silently missing partner company or truck position, which is the same class of quiet undercount the `.limit()` removals were fixing.
- [x] 🔴 **P2-06** **Done.** `portal_tabs_resolver.dart` — remove the three unguarded `!` dereferences (`companyState.company!`, `employeeState.company!`, `employeeState.employee!`).
- [x] 🔴 **P2-07** **Done.** `PortalNavigation.employeeTabs` returns `const []` when `role == null` → empty sidebar. Now routes to `WaitingForRoleScreen` (see P4-11, which is the security half of this).
- [ ] 🟠 **P2-08** `loading_activity_detail_screen.dart` — type the untyped `final List trips` (`dynamic`).
- [x] 🟠 **P2-09** **Done 2026-08-11 for the partner-companies path**, which is where the live fault was: `mine_supplier_buyers_detail_screen` and `mine_supplier_portal_dashboard_screen` both resolved the provider with `.valueOrNull ?? []`, restoring one layer up exactly the swallow that had just been removed from the service. Both now render the shared blocking `PartnerLoadError` with a retry — blocking rather than a banner, because on the Buyers screen the partner read *is* the list and on the dashboard it resolves the buyer names, so a partial render looks identical to a complete one. ⬜ The wider `.first` / `[0]` / `!` sweep across every other screen is still open.
- [ ] 🔴 **P2-10** `security_checkin_screen._markGone` issues two sequential `setTripStatus` RPCs (`leftMine`, then `enRouteToOffload`). Replace with **one atomic RPC** (pairs with P3-14).
- [ ] 🟠 **P2-11** 🆕 `OperationsProvider` carries `OperationsScope.orgType` and **never uses it**; `OperationsAccessPolicy.visibleTabs(canEditAll: true)` returns **all 6 tabs ignoring org type**, so a Buyer company sees Weighbridge / Gate Checks / Security Incidents. Scope the tabs by org type.

---

## Phase 3 — Supabase backend hardening

### 3.1 Security

- [x] 🔴 **P3-01** **Done — advisor 27 → 0.** ⚠ The grant was held by **PUBLIC**, not `anon`; revoking from `anon` was a no-op because `anon` inherits from PUBLIC. Revoked PUBLIC and granted `authenticated` explicitly (the pattern the other 178 functions already follow). `revoke execute … from anon` on all **27** unauthenticated-callable `SECURITY DEFINER` functions: `add_recon_dispute_comment`, `check_email_registered`, `delete_compliance_document`, `delete_fuel_entry`, `delete_my_compliance_document`, `delete_operating_cost`, `get_profile_setup`, `get_runtime_platform_status`, `list_available_routes`, `list_compliance_documents`, `list_fuel_entries`, `list_operating_costs`, `list_recon_dispute_comments`, `list_recon_disputes`, `list_transporter_trip_earnings`, `list_transporter_trip_pnl`, `list_transporter_vehicle_cost_breakdown`, `list_transporter_vehicle_costs`, `log_fuel_entry`, `log_operating_cost`, `raise_recon_dispute`, `set_recon_dispute_status`, `set_route_transit_expectation`, `update_my_company_profile`, `update_my_employee_profile`, `upsert_compliance_document`, `upsert_my_compliance_document`.
- [ ] 🟠 **P3-02** Enable leaked-password protection (HaveIBeenPwned) in Supabase Auth.
- [x] 🟠 **P3-03** **Done.** Add `SET search_path = public` to `trip_is_on_time`.
- [ ] 🟡 **P3-04** Walk the 173 `authenticated`-executable definer functions once; confirm each re-checks the caller's company/role internally.
- [ ] 🟠 **P3-05** 🆕 Remove the dead child-admin gates: `create_serial_token` still checks `superGlobalSerialAdminMainChild` + `child_can_generate_tokens`, and `super-admin-create-company` checks `child_can_register_companies` + identity. The concept was abolished 2026-07-12.
- [ ] 🟡 **P3-06** Confirm `serial_tokens` stores only `token_hash` + `token_preview`, never the raw token. ✅ verified correct — re-confirm after any change.
- [ ] 🟡 **P3-07** Confirm no Supabase URL/key is hardcoded in Dart. ✅ verified correct (`supabase_config.dart` uses `--dart-define` with an asset fallback) — the exposure is the bundled asset, see P11-03.
- [ ] 🟠 **P3-08** 🆕 Verify the **hosted** project's auth settings independently of `supabase/config.toml` (which is local-dev-only and has `minimum_password_length = 6`, empty password requirements, `enable_signup = true`, confirmations off).
- [ ] 🔴 **P3-09** 🆕 **Fix the WhatsApp OTP silent fallback.** `whatsapp-send-otp/senders.ts` falls back to `DevConsoleSender` — which `console.log`s the OTP and **returns HTTP 200** — unless `OTP_SENDER === "meta"` and all of `META_WABA_PHONE_ID` / `META_WABA_TOKEN` / `META_OTP_TEMPLATE` are set. Verify all four on the live project **and make the fallback throw in production**.

### 3.1b 🆕 Cross-tenant RLS leaks *(policy bodies read in Revision 2)*

- [x] 🔴 **P3-43** **`companies_select_authenticated` is `USING (true)`** — every authenticated user reads **every company row**: `seat_limit`, `seats_used`, `token_expires_at`, `current_token_id`, `whatsapp_number`, `registration_number`, `vat_number`, `physical_address`, CEO names, support email. A driver at transporter A can read every competitor's full profile and commercial posture. **Narrow it** to own-company + platform admin + actual counterparties (via `org_connections` / `transactions`).

  ✅ **Done 2026-08-12 — migration `20260812150000_companies_select_scoped.sql`, applied, mirrored, ledger repointed.** `docs/rls-companies-tightening.md` applied as written, including its §5 verification walk.

  **The document names two prerequisites. There are three, and the third is the one that would have broken onboarding.**
  · §2a ✅ the employer picker · §2b ✅ the operations-hub fetch · 🔴 **§2d — `EmployeeNotifier.validateCompanyId()`, not in the document.** `linkToCompany()` calls it before writing the link, and it did `getCompanyById()` — a direct `companies` read for a company the employee is **not yet part of**. Under the new policy that returns zero rows and reports *"Company not found"* **for every company on the platform**. It now validates against the directory RPC. The read *after* linking was checked rather than assumed and left alone: `current_company_id()` resolves off `employees.company_id` and consults neither role nor status, so a just-linked, role-less employee still reads their own company.
  · ⚠ **§2b's guess was wrong.** The document says the operations fetch "suggests it is dead weight on the refresh path". It is not — `state.companies` feeds the three counterparty dropdowns in the Operations Hub transaction editor. It could not be deleted, and it could not be narrowed to counterparties either, because **picking a counterparty you have not yet transacted with is what a picker is for**.
  · ⚠ **`Company.fromJson` could not simply be fed fewer columns** — it *requires* `whatsappNumber` and `userId`. A contact number is not optional in that model, so any query feeding it must return one. Hence the new `CompanyDirectoryEntry` and `list_company_directory()` (id · name · org type · logo): the columns a picker may see are a smaller set than the columns a company profile is made of, and the type system now says so. One RPC serves both pickers rather than the document's `list_selectable_employers`, so two near-identical definer functions cannot drift apart.

  **Verified against live production, every company, not a sample:**

  | Check | Result |
  |---|---|
  | Policy is the only SELECT policy and is no longer `true` | ✅ `companies_select_scoped` |
  | Every one of the **26** companies still reads **its own row** | ✅ 26 / 26 |
  | Policy output == self + every real counterparty, computed independently from `transactions` ∪ `request_dispatches` ∪ `org_connections` | ✅ **26 / 26 exact — no company lost a real partner, and none gained one** |
  | Visibility per company | **26 → 1–5.** Atlas Buyer Group, Cyberhouse Mine Supplier and Roadhaul Logistics 5 (self + 4); the 12 shell/test rows drop to self only |
  | Super admin → Organizations | ✅ 26 of 26 |
  | A **driver** (employee, not owner) at Roadhaul | 5 companies, down from 26; own company still resolves by name |
  | An **unlinked, pre-approval employee** → `companies` | ✅ **0 rows** — nothing commercial leaks before approval |
  | The same user → employer picker | ✅ **26 rows** — onboarding intact |
  | Transporter → Available routes (dispatched, not yet accepted) | ✅ 2 routes resolve the requester's name — the dispatch clause doing its job, since no transaction exists yet |
  | No other table regressed to blanket-`true` SELECT | ✅ only the known ones remain: `minerals` (P3-44), `mine_hazards` (P3-45), `showcase_data`, `profile_requirements` |

  ⚠ **Minor correction to the document's §4 table:** it over-counts partners by summing the three clauses without deduping (Atlas listed as 6; it has **4** distinct counterparties). The set is right, the arithmetic was double-counting companies reachable by more than one route.
  ⬜ **Not claimed:** nobody has opened these screens in a browser. The proof above is at the database layer, as each real user, which is where the policy lives. The browser walk belongs to **P7-39**.
- [ ] 🔴 **P3-44** **`minerals_select_authenticated` is `USING (true)`** — every mine's mineral catalogue, grades and tonnages readable platform-wide. Narrow to own-company + counterparties + platform admin.
- [ ] 🟠 **P3-45** `mine_hazards_select_all` is `USING (true)`. Plausibly intentional (safety information for all drivers) — **decide deliberately and document it in the migration.**
- [x] 🔴🔴 **P3-46** ✅ **CORRECTED 2026-08-11 — NOT A BLOCKER. The premise was wrong, and the blocker is withdrawn.** The mine half of the request workflow **works, and always has.** Verified end to end against the live database as Iron Hills Mining's owner, in a transaction that was rolled back (0 residue, `transportation_requests` still holds its original 6 rows):

  | # | Step, as the real mine account | Result |
  |---|---|---|
  | 0 | `is_company_staff(Iron Hills)` · `is_platform_admin()` | `t` · `f` — a plain mine user |
  | 1 | insert `request_type='transportation'` | ✅ `status=requested` |
  | 2 | insert `request_type='buyer'` (type 3, mine-only — the P8-02 form) | ✅ `status=requested` |
  | 3 | mine reads its own requests back through RLS | ✅ 2 rows |
  | 4 | join to `companies.org_type` — which inbox? | ✅ `mineSupplier` → **Mine/Supplier** inbox |
  | 5 | admin `review_transportation_request(..., 'sent_back', notes)` | ✅ `status=sent_back`, note stored |
  | 6 | mine edits + resubmits | ✅ `status=resubmitted` |

  **Where the audit went wrong.** `buyer_company_id` is **not** a buyer filter — it is the **requester** column, `not null` on every row, and a mine writes its own id into it exactly as a buyer does. `supplier_company_id` is an unrelated thing: the mine the admin *links* at dispatch. And `is_company_staff()` tests **employment and ownership, never org type** — so `WITH CHECK (is_company_staff(buyer_company_id))` does not gate on being a buyer. The 6-of-6 buyer rows are real but they are not evidence: they are what a platform with 6 requests and no mine yet having raised one looks like. Correlation read as causation, on a column whose name asserts something untrue.

  **What was actually done, since a withdrawn blocker still leaves a live trap:**
  - `comment on column` / `on table` for `buyer_company_id`, `supplier_company_id` and the table — migration `20260811160000_transportation_requests_column_semantics.sql`, applied, mirrored, ledger repointed and re-selected. The next reader meets the correction where the confusion starts.
  - Dart renamed to match the meaning: `buyerRequestsProvider` → **`companyRequestsProvider`**, `RequestService.listForBuyer` → **`listForRequester`**, `submit(buyerCompanyId)` → `submit(requesterCompanyId)`, with the whole story at the provider's definition. 8 call sites + 1 test.
  - **Renaming the column itself is NOT done** — it is load-bearing for 5 functions, 4 policies and the admin inbox's `companies!buyer_company_id` embed. It needs the client's ruling (it is on the do-not-rename list).

  ⚠ **A near-miss worth recording.** The obvious "fix" — widening `transportation_requests_select` so a linked mine can read the order it is fulfilling — was drafted and then **rejected**: that row carries `price_per_ton`, `rate` and `admin_notes`, so it would have handed the mine the buyer's price per ton and the admin's review notes, breaking CLAUDE.md §4's "the transporter only ever sees their resulting price, never the admin's margin". The existing design is already right: the linked mine reads its orders through `list_request_tracking()`, which returns facts rather than the row — the same shape as `list_company_member_presence`. Verified: a linked mine selects **0** rows directly, and its orders through the RPC.

  ⬜ **Still owed, and not claimed here:** nobody has driven this in a browser as a signed-in mine user. The proof above is at the database layer, which is where the alleged blocker lived; the Dart insert path is the same single `insert` and the form is P8-02. That browser run belongs to P7-39.

- [x] 🟠 **P3-47** **Done 2026-08-11, in the same migration as P3-16** — as the item asked. `pod_uploads_insert` carried the identical defect; narrowing the RPC alone would have left the direct table write open, which is the whole reason the two were paired.
- [ ] 🟠 **P3-48** Read the remaining ~250 RLS policy bodies. Revision 2 only inspected the ones that are unconditionally `true`; a policy can be subtly wrong without being `true`.
- [ ] 🟠 **P3-49** Read the **35 `storage.objects` policies**. Bucket privacy is only half the control — a private bucket with a permissive object policy is not private.
- [ ] 🟡 **P3-50** Enumerate all database **triggers** and confirm none has a side effect the plan doesn't account for.
- [ ] 🟡 **P3-66** Confirm the 7 job functions are actually **scheduled in `pg_cron`**, and at what cadence. (`expire_organizations` appears to run — 0 expired-but-active companies.) ⚠ **Renumbered from P3-51 on 2026-08-12 — the ID was used twice.** §3.9's org-type role matrix is also numbered P3-51, and that is the one the client ruling and the standing order both cite, so it keeps the number. This item is unrelated (pg_cron scheduling) and moved to the next free ID. Appendix **C-05** cross-references it.

### 3.1c 🆕 Storage buckets

- [x] 🔴 **P3-52** **`chat-attachments` is a PUBLIC bucket with no MIME restriction.** Every file and image shared in company-to-company chat is readable by URL to anyone on the internet — lab results, contracts, load photos. **Make it private and serve via signed URLs.**

  ✅ **Done 2026-08-12 — migration `20260812160000_private_chat_support_buckets.sql`**, applied, mirrored, ledger repointed. Private, 25 MB cap, MIME allow-list (png/jpeg/webp/gif/heic/pdf).

  🔴 **It hid a second hole, worse than the one this item names.** `chat_attach_insert` was, in full, `WITH CHECK (bucket_id = 'chat-attachments')` — no folder check, no room check, no ownership check. **Any authenticated user could write any file into any chat room's folder.** Making the bucket private would have closed the read hole and left that one wide open: *a private bucket with a permissive object policy is not private* (P3-49). Narrowed to the same `can_access_chat_room()` predicate the already-correct `chat_files` bucket uses, and matching SELECT and DELETE policies added — the bucket had **no SELECT policy at all**, which was not an oversight but a consequence of being public (nothing ever evaluated one), so going private without adding it would have 404'd every attachment.

  **Dart landed in the same commit, or attachments would simply break.** `chat_messages.file_url` now stores a **bucket-qualified object path**, not a URL, signed at render by `resolveAttachmentUrl` — persisting a signed URL would give attachments that work until they silently expire. Same pattern as `pod_uploads.photo_url`. The resolver is memoised (45 min, inside the URL's 1 h life) because a chat bubble rebuilds on every message, reaction, hover and scroll, and re-signing per rebuild would flash the image back to its placeholder each time. A null result renders a stated *"Attachment unavailable"* chip, never a broken image.

  **Safe to run on production because both buckets held 0 objects** — verified at the cutover, so no stored URL broke and nothing needed migrating. A legacy `http…` value is still passed through untouched rather than mangled.
- [x] 🔴 **P3-53** **`support-attachments` is PUBLIC with no size limit and no MIME restriction.** Both an exposure and an abuse vector. Make private, cap size, restrict MIME.

  ✅ **Done 2026-08-12**, same migration. Private, **10 MB** cap, same MIME allow-list. Its object policies needed no change — `support_attach_insert` and `support_attach_select` were already scoped through `support_can_see_ticket()`, unlike the chat bucket's.

  **Proof the public route is actually gone, and that `company_assets` deliberately is not** — unauthenticated GET on each bucket's public CDN path:

  | Bucket | Response | Meaning |
  |---|---|---|
  | `chat-attachments` | `404 NoSuchBucket` — *"Bucket not found"* | public route removed → **private** |
  | `support-attachments` | `404 NoSuchBucket` — *"Bucket not found"* | public route removed → **private** |
  | `company_assets` | `404 NoSuchKey` — *"Object not found"* | still publicly routable, **correct** per client ruling 3 (logos render on partner-facing screens) |

  The distinction matters: both return 404, and only the body separates "this bucket is no longer public" from "that file does not exist". `company_assets` is now the **only** public bucket on the project.
- [ ] 🟠 **P3-54** **There are two chat buckets** — `chat_files` (private, 25 MB, PNG/JPEG/WebP/PDF) and `chat-attachments` (~~public, unrestricted~~ **private as of 2026-08-12, P3-52**). A half-finished migration. Determine which the app writes to, migrate the objects, delete the other.
  📌 **Both writers found, 2026-08-13.** `chat_dock` → `chat-attachments` (`messaging_service.dart:281`); `ChatScreen` → `chat_files` via `FileUploadWidget` (`chat_screen.dart:385`). **There is nothing to migrate: `chat-attachments`, `support-attachments` and `chat_files` all hold 0 objects** (`select count(*) from storage.objects` per bucket), so this is a free choice with no data cost — take it before either bucket has content. Until it is taken, `attachment_url.dart` resolves **both** buckets and the `storage://` prefix form, so neither surface shows a false "Attachment unavailable" (commit `802ca25`).

  ⬜ **Still open, and now easy — but answered in part 2026-08-12.** Both are written to, by different surfaces: `chat_dock.dart` → `chat-attachments` (via `MessagingService.uploadAttachment`), `chat_screen.dart:385` → `chat_files` (via `FileUploadWidget`). **There are no objects to migrate: all three chat/support buckets hold 0 objects.** So this is a pure code decision with zero data risk — pick one bucket, point both surfaces at it, drop the other. Do it before anyone uploads a file; after that it stops being free.
- [ ] 🟠 **P3-55** `compliance_docs` is private but has **no size limit and no MIME restriction**. Add both.
- [ ] 🟢 **P3-56** ✅ `company_assets` public is correct (logos). The other seven buckets (`employee_assets`, `load_photos`, `pod_photos`, `quality_certs`, `recon_docs`, `request_docs`, `signatures`) are private with sensible caps and allow-lists — confirm after any change.

### 3.1d 🆕 Live data integrity

- [ ] 🔴 **P3-57** **69 of 88 active employees have no seat.** 106 seats are minted; ~19 are occupied. **The seat limit is the thing the serial token sells, and it is currently decorative.** Either backfill assignments and enforce at creation/approval, or the whole seat model is theatre.
  📌 **Recounted 2026-08-15: 87 active employees, 18 occupied seats, 69 with no seat.** The 69 was exactly right; the other two figures were one out each.
  ✅ **"Decorative" is now proven at the mechanism, not inferred from the counts.** Walked as **Vis Mine**'s own owner (`seat_limit 0`, `seats_available 0`, `0` seats minted, 2 active employees), rolled back: `create_company_managed_employee` **created a third employee** — no refusal, no seat consumed, no seat minted. An employee was created past a limit of zero.
  ✅ **There is no code path where a gate could fire.** The only two employee-creating functions — `complete_employee_signup` (`auth_service.dart:43`) and `create_company_managed_employee` (the `company-user-admin` edge function) — reference **neither `organization_seats` nor `seat_limit`**, and **no edge function mentions "seat" at all**.
  ⚠ **The serial is missing for a findable reason: `generate_seat_serial` exists and has ZERO callers.** `create_serial_token` mints the seat rows but never sets `serial_number` — which is why **all 106 seats carry a null serial**. The serial is the unit being sold.
  ⚠ **`reassign_seat` has no Dart call site either.** Of the four seat mechanisms — mint, gate, serial, reassign — **only minting runs.**
  ✅ **RESOLVED IN PART — the gate is built and blocks (client ruling 2026-08-15: block, with a popup to request more seats).** `enforce_employee_seat_limit`, a trigger on `employees` (migration `20260815112000`), charges a seat when someone becomes `active` and refuses past the limit with SQLSTATE `MLS01`. Walked as real users, rolled back: **under** the limit allowed (4 → 5); **at** the limit blocked; **zero** seats blocked; **role change on an already-active employee still allowed** (the regression this could have caused); **activating a `pending_role` self-signup at the limit** blocked.
  ✅ A used seat = an active, non-dismissed employee. **Not** `companies.seats_used` and **not** `organization_seats.occupied` — both measured wrong (Land Rover 2 active / 0 occupied; ABC Mine `seats_used` 3 with 0 employees).
  ✅ The popup (`seat_limit_dialog.dart`) submits the **same** `seat_expansion` request as the company profile's Platform-requests panel, so both land in one inbox. Detection is on the SQLSTATE, which required deploying `company-user-admin` **v6 → v7** to forward `code` (verified over REST as a real admin).
  ✅ **CLOSED 2026-08-15 — client answered both: "generate seats for them, all of them" (all test data bar the two director accounts).** Provisioned on live data: companies active **17 → 26 of 26**, without token **14 → 0**, seats **106 → 274**, seats with a serial **0 → 274** (all distinct), occupied **18 → 42**, companies at/over limit **6 → 0**. Tokens issued through the real `create_serial_token` as the platform admin so each wrote its own `TOKEN_GENERATED` audit row; limits set to `greatest(existing, active + 3, 10)` so no allowance was reduced.
  ✅ `generate_seat_serial` is called at last — existing seats backfilled, and `20260815113000` wires it into `create_serial_token` so new seats are minted with one (verified: limit 10 → 13 produced 3 seats, 3 serials, `GEN` suffix, rolled back).
  ✅ The two super global admins were untouched and unreachable by this: they own no company and hold no employee row.
  ✅ **The 45 company-less "active" employees are resolved and the state is now impossible.** All assigned to companies (role gaps first) and seated: **87 active, 87 seated, 0 orphans**. `employees_company_required` (`20260815116000`) refuses `active` with no company — verified biting. `company_id` may be null only while `pending_company`, so self-signup still works.
  ⚠ **Turned up doing it: there was not one `supervisorForeman` anywhere.** Zero across 26 companies — the role §4 puts in charge of the order stockpile, with its own branch in `is_company_stockpile_writer` that had **never been true for anybody**. All 12 mines now have one; walked as Iron Hills' supervisor, `stockpile_add_tons` moved the pile 60.0 → 72.5 t with a ledger row.
  ⚠ **A supervisor could not have held a seat either** — `organization_seats` omitted the role from its occupant vocabulary while three other places allow it. Seventh CHECK-vocabulary mismatch on this project; widened in `20260815115000`.
  ⚠ **Hole in the seat gate, fixed** (`20260815114000`): it skipped the check for an already-active employee, so **moving** one to another company took a seat there without counting it.
- [ ] 🔴 **P3-58** **14 of 26 companies have no token** (`current_token_id is null`) — and the org list renders them with a **green** dot labelled "No token" (P9-08). Decide their real status and issue or suspend.
- [ ] 🟠 **P3-59** **3 orphan profiles** — auth users that are neither an employee, nor a company owner, nor a platform admin. Investigate and clean.
- [ ] 🟠 **P3-60** **2 completed trips have no POD** (37 completed vs 35 POD uploads) — consistent with the collapsed lifecycle (P3-15). Confirm whether completion should ever be possible without a POD.
- [ ] 🟢 **P3-61** ✅ Clean: 0 orphan trips, 0 employees without an auth user, 0 completed trips without `net_tons`, 0 active-but-expired companies. Re-run after the Phase 3 migrations.

### 3.1e 🆕 Performance *(essentially clean — fix before the data grows, not before launch)*

- [x] 🟡 **P3-62** **Done.** Add covering indexes for the 6 unindexed foreign keys (`fuel_entries.trip_id`, `monthly_targets.created_by`, +4).
- [x] 🟡 **P3-63** **Done.** Fix the one `auth_rls_initplan` warning: `mine_hazards_insert_own` should use `(select auth.uid())` rather than `auth.uid()`.
- [ ] 🟢 **P3-64** Review the 9 multiple-permissive-policy warnings (mostly a staff policy alongside a super-admin policy — harmless, but each adds a per-row evaluation).
- [ ] 🟢 **P3-65** Review the 83 unused indexes once real usage exists. Normal for a young database; do not drop them yet.

### 3.2 The variance hole 🔴 *(most important backend gap)*

- [x] 🔴 **P3-10** **Done 2026-08-11** — `trips.delivered_tons`, migration `20260811170000`. `pod_uploads.delivered_tons` stays as the capture record; the trip now carries the figure alongside the mine's `net_tons`, which is never overwritten.
- [x] 🔴 **P3-11** **Done 2026-08-11** — `trips.variance_tons`, a **stored generated column** `net_tons - delivered_tons`. Generated rather than a view or a trigger for two reasons: it cannot drift from its inputs, and it cannot be written by hand. NULL-safe by construction — a missing weight yields NULL, which reads as *not comparable* and is emphatically not a measured zero. Positive = mass that left the mine and did not arrive.
- [x] 🔴 **P3-12** **Done 2026-08-11** — `record_pod` writes `trips.delivered_tons` and never touches `net_tons`. Live-verified in a rolled-back transaction on a real 35 t trip: delivered 33.5 → variance 1.5, mine net unchanged.
- [x] 🔴 **P3-13** **Done 2026-08-11.** `list_raw_recon_rows` gained `variance_tons` (migration `20260811171000` — a `drop`+`create`, since `create or replace` cannot add a column to a `RETURNS TABLE` function; the result is a strict superset and PostgREST keys by name, so no caller broke), and **both** recon RPCs now read `trips.delivered_tons` / `trips.variance_tons` instead of re-deriving from `pod_uploads` — Side B had a third copy of the same subtraction inline (`20260811172000`). Side A gains **Delivered** and **Variance** columns on screen and in the CSV / Excel / PDF exports (all three come off the shared `csvHeaders` / `csvRows`, so one change covered them). ✅ **CORRECTED and worth reading:** Side B *already* rendered a variance and already tinted it — but on a flat `> 0.05 t → MlTone.error`, which on the live data **flags all 35 reconciled loads as errors** (every one is short by ≤ 0.20 t on ~35 t ≈ 0.57%, ordinary weighbridge scatter). A red that fires on every row is wallpaper, not a signal. Both sides now share `portal/utils/variance_severity.dart`: percentage-of-load, with a 0.05 t absolute floor so a tiny load cannot turn 20 kg of rounding into an alarming percentage — **balanced < 1%, watch 1–3%, material > 3% → `MlTone.error`**. Over-delivery is graded by magnitude on the same scale, never treated as fine (it is how a swapped load hides). 12 assertions in `test/variance_severity_test.dart`. ⬜ **One thing this does NOT surface, deliberately:** a *systematic* small shortfall on every load is a real finding in principle, but it is an aggregate one — colouring each row red buries it rather than surfacing it, so it belongs on the recon totals. Raised as a follow-up, not silently dropped. 🔴 **CORRECTED 2026-08-12 (P10-D1) — do NOT build that follow-up on the current data.** The “systematic shortfall the live data shows” is not a measurement: `variance_tons` has **exactly 1 distinct value across all 35 loads and a standard deviation of 0.000000** (min = max = avg = 0.2000 t). That is the seed script computing `delivered_tons = net_tons - 0.2`, not 35 independent weighings agreeing to four decimal places. It must never be reported to the client as a business signal. See `docs/seed-data-inventory.md` §5.
- [x] 🟠 **P3-14** **Done 2026-08-11** — backfilled in the same migration, newest POD per trip winning (a re-upload is a correction, not a second load). **35 of the 37 completed trips** now carry a delivered figure and a variance; the other 2 have no POD at all, so they correctly stay NULL rather than being invented as zero. Every one of the 35 is short-delivered — 7.00 t in aggregate, worst single load 0.20 t.

### 3.3 Trip lifecycle

- [x] 🔴 **P3-15** **Done 2026-08-11 — the 9th status now genuinely exists.** `select count(*) from trips where status='offloaded'` returned **0 across all 41 trips** before this. `record_pod` now lands the trip on `offloaded`; a new `complete_trip(uuid)` RPC closes it, and carries the transaction completion and the recon accumulator so those happen exactly once. **No trip is stranded and the end-to-end behaviour is unchanged**: `record_pod` calls `complete_trip` itself. The hold is opt-in per route via the new `routes.variance_tolerance_pct`, **NULL on every existing route**, so nothing holds today; set it and a load exceeding it stops at `offloaded` for review. ⚠ The threshold is deliberately **not** defaulted — picking a number for an operator's tolerance is their call, not the migration's. Live-verified: 10% short against a 1% tolerance held at `offloaded` with `completed_at` null, and a party then closed it.
- [x] 🔴 **P3-16** **Done 2026-08-11** — the check now matches its message: transporter staff and the platform admin only. A check that permits what its message forbids is worse than either behaviour chosen deliberately — it silently licensed **the mine to declare what arrived at the buyer**, which is precisely the party whose figure the variance exists to test. Checked against live data before narrowing: of 35 PODs, 2 were uploaded by transporter staff and 33 carry no uploader (seeded) — **not one by a supplier**, so nothing broke. Live-verified: a mine account calling `record_pod` is now refused with 42501.
- [ ] 🟠 **P3-17** Add an atomic `leave_mine` RPC covering `left_mine → en_route_to_offload` (pairs with P2-10).
- [ ] 🟠 **P3-18** Assert canonical transition order inside `set_trip_status` — reject out-of-order writes server-side, not just by dimming buttons.

### 3.4 Empty-table verdicts — each needs *proven* or *hidden for v1.0*

> Several of these are empty **only because the role cannot reach the screen (P7-19) or the screen is orphaned (P4-13)**. Re-test after Phase 7.

> 📌 **Every table below now carries a verdict (S6-23, 2026-08-15).** Each write was made as the real role under
> that user's JWT claims and **rolled back**; each count was taken after `reset role`, as `postgres`. A tick here
> still requires the item's *own* full ask — several are proven at the server and remain open on a UI or
> operational half, and those are stated rather than rounded up.

- [ ] 🔴 **P3-19** `gate_checks` (1 row) — 12 live security employees. Prove real writes once security can reach the Operations Hub.
  ✅ **Write capability proven** (S6-22) — as `ironhills.security`, `gate_checks` 1 → 2. ⏸ Still open on the item's own wording: those are walked writes, **not operational rows from the 12 live security employees**, of which there are still none.
- [ ] 🔴 **P3-20** `security_incidents` (0) — same.
  ✅ **Write capability proven** (S6-22) — 0 → 1 as the same guard. ⏸ Same caveat as P3-19.
- [ ] 🟠 **P3-21** `weighbridge_records` (1) — same, for `controllerWB`.
  ✅ **Proven as the role whose job it is** — `ironhills.controller` wrote 1 → 2 (`outbound`, gross 52.40 / tare 16.18 / net 36.22). ⏸ Same operational caveat.
- [ ] 🟠 **P3-22** `mineral_loads` (0) — same.
  ✅ **Written 0 → 1 — but by the transporter, not the mine.** The policy is `with check (is_company_manager(fleet_vehicles.company_id))`, i.e. the **vehicle's** company. `roadhaul.admin` wrote; `ironhills.admin` was **REFUSED**. ⚠ **Dead CTA + ASK:** `mineSupplier` gets every Operations tab, so a mine admin is offered a Loads create button that RLS refuses every time — the party that physically loads the truck cannot record the load. Widening the policy is a security-boundary decision.
- [ ] 🟠 **P3-23** `mine_locations` (0) — **hard dependency of driver-navigation destination resolution.** Must hold Main Gate / Weighbridge / Loading Point per mine.
  ✅ **Writable** — `ironhills.admin` wrote all three types (0 → 3), rolled back. ⏸ **Still 0 on live data, and this is the live gap**: it is the input `auto_generate_trip_waypoints` reads (P3-24), so no mine holding these points means no trip can generate waypoints. Needs real points captured per mine, which is data entry, not code.
- [ ] 🟠 **P3-24** `trip_waypoints` (0) — `auto_generate_trip_waypoints` exists but has never produced a row. Prove it fires on dispatch.
  ✅ **It was never broken — it was starved.** With Iron Hills' three points seeded inside the walk it emitted the full mine-floor round trip, 0 → **6**, in correct order: `main_gate → weighbridge → loading_point → weighbridge → main_gate → drop_off`. ⏸ Open on *"fires on dispatch"* — this was a direct call; the dispatch trigger path is not yet proven. Its real dependency is **P3-23**.
- [x] 🟠 **P3-25** `security_confirmations` (0) — two-party arrival/exit confirmation. Prove or hide.
  ✅ **PROVEN two-party, as two different real users on one row** — `roadhaul.driver` set `driver_confirmed`, then `ironhills.security` set `security_confirmed` on the same `(trip, arrival)` row via the service's own upsert conflict target. 0 → 1 with **both** flags true. RLS is `is_trip_driver(trip_id) or is_company_staff_active(supplier)`: a driver not assigned to the trip is refused, which is why the first attempt on another trip failed.
- [ ] 🟠 **P3-26** `compliance_documents` (0) — prove one real upload + expiry reminder per owner type (vehicle / employee / company).
  ✅ **`owner_type = 'company'` proven** — `upsert_compliance_document` as `ironhills.admin`, 0 → 1. ⏸ Open: the `vehicle` and `employee` owner types, and the `notify_expiring_documents_job` reminder, are unproven. 📌 ~~`list_compliance_documents` has no Dart call site~~ — **withdrawn, it is called** from `compliance_service.dart`; my grep required it on the same line as `rpc(`.
- [x] 🟠 **P3-27** `load_quality_certs` (0) — prove one cert end to end and that the buyer can read it.
  ✅ Proven end to end at **S6-11**: mine set the route spec and attached the cert; `list_load_quality` returned it to mine, buyer **and** platform admin; the buyer attempting to attach one was refused server-side.
- [x] 🟠 **P3-28** `load_invoices` (0) — prove capture + variance. **Confirm RLS blocks mine and transporter reads.**
  ✅ **Capture proven** — `atlasbuyer.admin` wrote `INV-S623-001`, 34.90 t / R4 188.00 / ZAR against TRP-DEMO-036, 0 → 1. ✅ **Variance and the read boundary proven at S6-12**: `list_buyer_trip_values` returned **27 rows to the buyer and 0 to the transporter admin**.
- [ ] 🟠 **P3-29** `production_entries` (0) — `record_production` exists; prove the production screen writes.
  ✅ **The RPC writes** — `record_production` as `ironhills.admin`, 42.5 t Chrome Ore / Pit 3, 0 → 1. ⏸ Open on *"the production screen writes"* — that is the UI half and belongs to the render/walk group.
- [x] 🟠 **P3-30** `recon_disputes` + `recon_dispute_comments` (0) — prove raise → comment → super-admin resolve.
  ✅ Proven at **S6-13** as four different real users: raise → reply → counter-reply → resolve, with all three parties notified at every turn.
- [ ] 🟠 **P3-31** `token_requests` (0) — prove request → approve → seats minted → audit log.
  ✅ **Request and audit log proven — but only after fixing two live defects that had made this impossible since the feature shipped.** `create_company_token_request` declared `c record` then ran `select c.id … into c from public.companies c`; PL/pgSQL binds `c.id` to the **unassigned variable**, so every call raised `55000` before validating a single argument. Fixed in `20260815110000`. That exposed two `audit_logs` CHECK vocabularies behind it — `actor_platform_role` excluded `normalUser` (the role of **all 114** non-admin users) while allowing `companyAdmin`/`companyManagement`, which **no profile has ever held**; and `target_type` allowed `seatRequest` but the code emits `tokenRequest`. Both widened in `20260815111000`. After both: `token_requests` 0 → **1** (*Iron Hills Mining | pending | seat_expansion | +5 → 15*), `audit_logs` 15 → **16**. ⏸ Open: **approve → seats minted** is still unproven. 🛡 `tool/plpgsql_alias_collision_check.py` now guards the class (PASS; `--selftest` BITES).
- [ ] 🟡 **P3-32** `driver_limit_requests` (0) — prove 2→5 request and approval.
  ✅ **Request proven** — `request_driver_limit` as `roadhaul.admin`, 0 → 1. ⏸ Open: `decide_driver_limit_request` (the approval half) is unproven.
- [ ] 🟡 **P3-33** `fuel_entries` + `vehicle_operating_costs` (0) — prove one write each and that they flow into net earnings.
  ✅ **Both writes proven** — `log_fuel_entry` (420.5 ℓ / R9 870.25) and `log_operating_cost` (toll R385.00) as `roadhaul.admin`, 0 → 1 each. ✅ **The earnings chain is wired and reachable:** `list_transporter_trip_pnl` (`earnings_service.dart:18`), `list_transporter_vehicle_cost_breakdown` (`fuel_service.dart`) and `list_transporter_vehicle_costs` (`earnings_service.dart:28`) are all called, and `EarningsScreen` / `FuelCostsScreen` are routed (`app_router.dart:968`, `:972`) and in `portal_navigation.dart`. ⏸ Open only on the end-to-end figures — a logged litre has not been followed through to a net-earnings number on screen.
  ⛔ **CORRECTION.** I first recorded the earnings half as *"dead, nothing consumes them"*. That was wrong and is withdrawn. The audit used `grep "rpc('<name>'"`, which requires the name on the same line as `rpc(`, and `earnings_service.dart` wraps to the next line. A whitespace-tolerant re-scan collapsed three such claims — the two above and `list_compliance_documents`.
- [ ] 🟡 **P3-34** `reconciliation_uploads` (0) — prove Side A export → external edit → re-upload keeps **exactly two versions**, both labelled.
  ✅ **Write proven** — `save_recon_upload` as `atlasbuyer.admin`, 0 → 1 carrying original **and** edited paths (the RPC refuses a call with no edited file). ⏸ Open: the **exactly-two-versions** retention rule across a second re-upload is untested.
- [ ] 🟡 **P3-35** `stockpile_docs` (0) — wire P8-03/04 then prove.
  ✅ **Write proven** — `ironhills.admin`, `kind = 'lab_result'`, 0 → 1. ⏸ Open: the P8-03/04 wiring itself.
- [ ] 🟡 **P3-36** `route_assignments` (0) — prove `assign_route_to_company` surfaces on the org's dashboard and auto-fills the request form.
  ✅ **Assignment proven** — `assign_route_to_company` as the platform admin, 0 → 1. ⏸ Open: the dashboard surfacing and request-form auto-fill are UI claims. 📌 `unassign_route_from_company` has **no Dart call site** — an assignment cannot be undone from the product.
- [x] 🟡 **P3-37** `mine_hazards` + `mine_road_requests` (0) — prove or hide for v1.0.
  ✅ **`mine_hazards` proven** — 0 → 1 as `ironhills.admin`; reachable from `driver_navigation_screen` and `live_trip_map_view`. ✅ **`mine_road_requests` HIDDEN** — no Dart reference, no function reference, no trigger. Nothing anywhere reaches it.
- [ ] 🟡 **P3-38** `broadcast_messages` (0) — becomes provable once the announcements hub is routed (P4-13).
  ✅ **Write proven** — 0 → 1 using `communications_service.createAnnouncement`'s exact payload shape (the RLS check `can_create_broadcast_message` reads `payload->>'company_id'`, so a payload without it is refused — my first attempt, not a product fault). ⏸ Open on P4-13, the routing.
- [x] 🟡 **P3-39** `chat_message_reads`, `seat_reassignment_log` (0) — prove or hide.
  ✅ **Both HIDDEN, and in the strongest sense.** `chat_message_reads`: no Dart reference, no function reference, no trigger. `seat_reassignment_log`: written only by `reassign_seat`, and **`reassign_seat` has no Dart call site** — seat-reassignment governance cannot be invoked from the product at all. ⚠ That is an **S4** finding as much as a table verdict.

### 3.5 Realtime, jobs and seeds

- [ ] 🟠 **P3-40** Confirm every table the UI subscribes to is in the `supabase_realtime` publication (41 today). New tables ship realtime + RLS in the same migration.
- [ ] 🟠 **P3-41** Verify the 7 scheduled jobs actually run: `expire_organizations`, `notify_token_expiring_soon_job`, `notify_expiring_documents_job`, `notify_service_due_job`, `notify_incomplete_profiles_job`, `close_due_target_cycles_job`, `cleanup_old_broadcast_messages_job`.
- [ ] 🔴 **P3-42** 🆕 **Remove the demo seeds from the chain** — `20260511160000_portal_logistics_demo_seed.sql`, `20260726090300_showcase_data.sql`, and set `[db.seed] enabled = false` in `supabase/config.toml`. ~~Also delete the 14 live `showcase_data` rows (see P10-23).~~

  ⚠ **AMENDED 2026-08-12 by client ruling 7 (P10-D8): the 14 `showcase_data` rows STAY.** Strike the last sentence — deleting them is now contrary to an explicit decision. The banner was the defect, not the rows, and it is gone (P10-D8).

  ⚠ **And the rest of this item still rests on a premise P10-D4 disproved.** Taking the two migration files out of the chain removes **almost none** of the seeded data: the larger seed, `insights_demo_20260803` (97% of the volume), exists in **no migration file and no ledger row**. Migration files are not undo scripts. Rows are removed only by the explicit deletes in P10-D5. What survives of this item is genuinely worth doing but is narrower than it reads: stop the two seed files re-running on any future `db reset`, and set `[db.seed] enabled = false`.

---

### 3.9 🆕 Org-type role enforcement (client ruling 1, 2026-08-11)

- [x] 🔴 **P3-51** **Roles are not constrained by org type anywhere.** `employees_role_check` permits all six roles at any org type; `organization_seats_role_binding_check` and `organization_seats_occupied_by_employee_role_check` permit all five at any org type; `assign_employee_role` does not check org type either. Enforce the matrix in **all three places plus every UI role picker**:
  · **buyer** → `admin`, `management` — **and nothing else**
  · **mineSupplier** → `admin`, `management`, `supervisorForeman`, `security`, `controllerWB`
  · **transporter** → `admin`, `management`, `driver`
  `supervisorForeman` is **mine-only** — it is not a buyer or transporter role. A CHECK constraint cannot see `companies.org_type` from `employees`, so enforce server-side in `assign_employee_role` (raise, do not silently ignore) **plus** a trigger on `employees` covering direct writes. Live data is already compliant (buyer: `admin` ×3, `management` ×3 · mine: `security` ×7, `admin` ×6, `management` ×4, `controllerWB` ×4 · transporter: `driver` ×6, `admin` ×5, `management` ×4 · **no `supervisorForeman` anywhere**) — re-verify before adding the trigger so it cannot fail on existing rows. Then prove all three ways: assigning `security` to a buyer's employee raises · assigning `driver` to a mine's employee raises · the buyer role picker offers exactly two options.

  ✅ **Done 2026-08-12 — migration `20260812090000_org_type_role_matrix_triggers.sql`. But the item's central claim is WRONG, and most of this was already built.**

  **`assign_employee_role` DOES check org type.** It has always called `is_valid_role_for_org(org_type, role)` and raised on failure — and `is_valid_role_for_org` already implements the client's ruled matrix **exactly, character for character**, including `supervisorForeman` being mine-only. `UserRole.getRolesForOrgType` in Dart implements the same matrix, and **all six role pickers resolve through it** (no hardcoded list anywhere). So the RPC path and every UI picker were already to spec before this migration.

  **What was genuinely missing** — found by asking which functions write a role and which of those validate:
  · 🔴 **`super_admin_set_employee_role` writes `employees.role` with NO org-type check.** The platform admin could set any role on any employee at any org type. That was the real hole and the plan does not mention it.
  · `reassign_seat`, `super_admin_release_organization_seat`, `request_company_link`, `decline_employee_request` and `remove_company_employee` all touch a role or seat role column without consulting the matrix.
  · Any direct `INSERT`/`UPDATE` on either table.

  **Enforced once per table in a trigger rather than in six functions** — a trigger sees every writer, including ones not yet written, which is the property the CHECK constraints cannot have (they cannot reach `companies.org_type`). The existing CHECKs stay: they bound the vocabulary, the triggers bound the combination. Both triggers no-op when role or company is NULL, so a pending request and a removed employee stay writable, and re-validate only when the pair actually changes.

  **Re-verified before applying** (the item asked): 42 employees with a company and a role — **0 violations**; 18 seats with an occupant role — **0 violations**; 0 seats with a `role_binding` at all (P9-09). The triggers cannot fail on an existing row.

  **Proven six ways in one rolled-back transaction** (0 residue, re-confirmed after): ① `security` on a buyer's employee → *"Role security is not permitted for a buyer company"* · ② `driver` on a mine's employee → refused · ③ `supervisorForeman` on a transporter → refused · ④ **legal `management` on a buyer → ACCEPTED** (the guard against a trigger that simply denies everything) · ⑤ `controllerWB` seat binding on a buyer seat → refused · ⑥ legal `admin` seat binding → accepted. The buyer-picker proof is `test/models/user_role_test.dart`, extended to pin the whole matrix with `unorderedEquals` — the pre-existing test used `contains`, which can only catch a role going missing and never one being added, and "exactly two options" is a statement about what is absent.

- [x] 🔴 **P8-30** 🆕 **Wire the weight dispute, and remove the system hold** (client ruling 4). The offload tolerance hold built on 2026-08-11 is **cancelled** — the app must never block a trip over a weight difference. Strip the tolerance branch and the route tolerance column it gates on (that column is new and empty; dropping it is authorised). Replace it with: on completion with a non-zero variance, **notify both counterparties** — mine and buyer on the mine→buyer leg, buyer and transporter on the delivery leg — using the `recon_dispute` notification type, deep-linked to the reconciliation screen for that trip, where either side can call the existing `raise_recon_dispute`. **Everything needed already exists and has never been used:** `recon_disputes` (0 rows), `recon_dispute_comments` (0), `raise_recon_dispute(uuid,text,text,numeric)`, `set_recon_dispute_status(uuid,text,text)`, `add_recon_dispute_comment(uuid,text)`, `list_recon_disputes(uuid)`, `list_recon_dispute_comments(uuid)`, the `recon_dispute` notification type (0 sent), and dispute UI in all three of `buyer_reconciliations_screen.dart`, `mine_reconciliations_screen.dart`, `transporter_reconciliations_screen.dart` plus `recon_dispute.dart`. **Wire it end to end and prove the full argument:** raise → both sides notified → comment → counter-comment → resolve → both notified. Do not rebuild any of it.

  ✅ **Done 2026-08-12 — migration `20260812140000_weight_dispute_venue_no_hold.sql`**, applied, mirrored, ledger repointed. Nothing was rebuilt.

  **"Wire it" turned out to be four wires, and the item names only one.**
  1. ✅ *Named* — **the hold is gone.** `record_pod` no longer parks a trip at `offloaded` over a weight difference, and `routes.variance_tolerance_pct` is **dropped** (0 routes ever set it; dropping it is authorised by this item). The split lifecycle is kept: `offloaded` is still a real distinct step, nothing is stranded there.
  2. ❌ *Not named* — **nothing fired on a completed trip with a variance.** The item asks for exactly this and there was no such code anywhere. Added to `complete_trip`, the one place a trip closes, so it fires whether `record_pod` closed it or a party called `complete_trip` directly. Without it a party has to go looking at the recon screen to discover there is anything to argue about.
  3. ❌ *Not named* — **`add_recon_dispute_comment` notified nobody.** `raise` and `set_status` both already fanned out to all three parties; the comment function did not. **A venue where you can post a reply the other side is never told about is not a venue**, and "comment → counter-comment" cannot honestly be proven without it. It now notifies the counterparties and **excludes the author's own company** — you do not need a push about your own reply.
  4. ❌ *Not named* — **no dispute notification carried a deep link.** The item asks for them to be "deep-linked to the reconciliation screen for that trip"; they carried ids but no route, so tapping one landed nowhere. All of them now carry `metadata.nav_route` for the **recipient's own org type** — which is why this goes through one `notify_recon_parties` helper rather than three pasted calls: the mine must be sent to `/portal/mine/reconciliations` and the buyer to `/portal/buyer/reconciliations` off the same event.

  ⚠ **ONE DELIBERATE DEVIATION FROM THE WORDING — the client can overrule it with one number.** The item says notify on "a **non-zero** variance". Taken literally that fires on **every completed load**, because two weighbridges never agree exactly — on the live data all 35 reconciled loads are short by ~0.57%. That is wallpaper, and it is the *identical* fault P3-13 already found and fixed on the other side of this feature (a flat 0.05 t threshold painted all 35 loads red; "a red that fires on every row is a signal that means nothing"). So the push fires on a **material** variance, using the **same scale the recon screens already paint with** — new `variance_is_material()` mirrors `variance_severity.dart`: percentage of load, 0.05 t floor, material above 3%. Server and screen therefore agree by construction: the loads that notify are exactly the loads rendered in `MlTone.error`. **Every variance is still surfaced on the reconciliation screen and either party can dispute any load at any time, including a 0.1 t one — what is filtered is the push, not the visibility.** To get the literal reading, set the `3.0` in `variance_is_material` to `0`.

  ⚠ **Flagged, not changed: only a platform admin can resolve.** `set_recon_dispute_status` restricts `under_review`/`resolved`/`rejected` to `is_platform_admin()`, which sits oddly beside client ruling 4 ("*sorted out between each other*"). Left as built, because **P3-30 and P8-42 both specify "super-admin resolve"**, and because the parties can already settle without the admin — the raiser withdraws. **Changing who may close a commercial dispute is a client call, not an implementation detail.** Worth a ruling.

  🆕 **A pre-existing gap this exposed, fixed only for `recon_dispute`:** the `notifications.type` column carries **both** camelCase and snake_case wire strings (`userManagement`, `tokenExpiringSoon` alongside `stockpile_prepare`, `truck_checked_in`, `truck_loaded`, `stockpile_depleted`), while Dart's `NotificationType.fromString` matched on `e.name == value` — exact camelCase. **Every snake_case type silently fell through to `general`.** `fromString` now matches on a normalised form, and `reconDispute` was added with its own label, icon (`scale_outlined`, `MlTone.error`) and role scope. ⬜ The other four snake_case types (16 live rows) **still fall through to `general`** — they have no enum member, and inventing four with guessed icons and role-relevance is **P10-14**'s job, not this change's. Recorded here so it is a known gap rather than a silent one.

  **Proven end to end against live production — 7 of 7, as four real users, in one rolled-back transaction (0 residue, re-confirmed after):**

  | # | Step, as a real account | Result |
  |---|---|---|
  | 1 | Trip closed by **Roadhaul (transporter)** with 35.00 t out vs 33.00 t delivered = 5.71% | ✅ mine, buyer **and** transporter all notified at close |
  | 1b | Deep link per recipient | ✅ `/portal/mine/…` · `/portal/buyer/…` · `/portal/transporter/reconciliations` |
  | 2 | **Atlas (buyer)** raises `weight_variance` | ✅ all three parties **+ the platform admin** notified |
  | 3 | **Iron Hills (mine)** comments | ✅ buyer + transporter notified, **mine not** (author excluded) |
  | 4 | **Roadhaul** counter-comments | ✅ mine + buyer notified, **transporter not** |
  | 5 | **Platform admin** resolves with a note | ✅ all three notified, status `resolved` |
  | 6 | Mine tries to comment on the now-closed dispute | ✅ refused — a closed argument takes no more replies |

  Residue check after rollback: `recon_disputes` 0 · `recon_dispute_comments` 0 · `recon_dispute` notifications 0 · the trip back at `completed` / 34.8 t / 0.2 t variance.
  ⬜ **Not claimed:** none of this was driven through a browser. The dispute UI already exists in all three recon screens (`recon_dispute.dart`, `dispute_widgets.dart`) and was not touched; **P3-30's "prove raise → comment → resolve" via the actual screens, and P8-42, remain open.**

---

## Phase 4 🆕 — Routing and guards

### 4.1 Extract the UI living inside the router (~430 lines, 15 routes)

- [x] 🔴 **P4-01** **Done 2026-08-11** — `portal/screens/portal_trips_screen.dart`. Carried across verbatim (the class body was sliced out of the router rather than retyped, so the extraction cannot have altered behaviour), then made public, given a `key`, and its error branch upgraded from `Center(Text('Could not load trips: $e'))` to an `MlEmptyState` with a working retry. `_PortalTripRow` went with it and stays private.
- [x] 🔴 **P4-02** **Done 2026-08-11** — `portal/screens/portal_trip_detail_screen.dart`, same treatment, error branch given a retry. `showWaybillModal` is still the one waybill path (server-authoritative `get_trip_waybill`); nothing was reimplemented.
- [x] 🔴 **P4-03** **Done 2026-08-11** — `portal/screens/portal_tons_out_screen.dart`, with `_portalTonsOutTransporterNameProvider` beside it (now `_transporterNameProvider`, private to the file it serves). Its logger moved off `AppRouter._logger` onto its own `LoggerFactory` scope, so a failed transporter lookup is now attributed to the screen rather than to the router.
- [x] 🔴 **P4-04** **Done 2026-08-11** — `portal/screens/portal_own_company_screen.dart`. ⚠ Named `portal_own_company_screen.dart`, not the plan's `portal_company_screen.dart`: `/portal/{org}/company` shows the signed-in user's OWN company, and a file called `portal_company_screen` reads like a generic company viewer, which is what `CompanyDetailsLoaderScreen` already is.
- [x] 🟠 **P4-05** **Done 2026-08-11** — `portal/screens/portal_trip_waybill_route.dart`. Kept as `...Route`, not `...Screen`: it renders no UI of its own, it pops the existing modal over the trip context. Naming it a screen would misdescribe it. ⬜ The `addPostFrameCallback` pop is unchanged and is still worth revisiting — out of scope for an extraction that must not change behaviour.
- [x] 🔴 **P4-06** **Done 2026-08-11 — and the count was wrong: it was 31, not 4.** ✅ **CORRECTED.** The four in the router were real; a repo-wide sweep found **twenty-seven more** across the portal screens (buyer loads/recons/requests/routes/trucks/waybills, compliance, driver app, driver routes, earnings, fuel costs, live map, load controller, loading activity, mine locations/production/quality/recons/buyers/trucks, security check-in, stockpile audit/detail, supervisor view, transporter maintenance/recons/tracking/routes/trucks/positions, trucks-on-route). All 31 now render **`PortalCompanyRequired`** (`portal/widgets/portal_company_required.dart`): an `MlEmptyState` that distinguishes *not linked* from *failed to read*, and whose **retry is real** — company context is only ever populated by an auth-state change, so if that fired before the profile row was readable nothing re-ran it and the screen stayed dead until a full app restart. The retry calls the same two loaders (`loadCompanyProfile` + `loadEmployeeProfile`) for the signed-in user.
- [x] 🔴 **P4-07** **Done 2026-08-11** — `test/router_structure_test.dart`, three assertions, all source-reading (the property is of the FILE, not of a running app — same technique as `portal_nav_test`): (1) **zero classes in `app_router.dart` extend any widget base** (`StatelessWidget`/`StatefulWidget`/`ConsumerWidget`/`ConsumerStatefulWidget`/`State<`/`ConsumerState<`), with a guard that the regex matched *something* so a parse change cannot make it vacuously green; (2) **no bare `Text('Company not loaded.')` anywhere in `lib/`**; (3) the five extracted screens exist, are public, **and are referenced by the router** — so an orphaned copy alongside a router that still holds its own would fail. Router: **1,756 → 1,318 lines**, 2 classes left (`AppRouter` and a `ChangeNotifier`).

### 4.2 Close the 9 guard holes

- [ ] 🔴 **P4-08** **G1 — no-role employee gets the full owner console.** `portal_tabs_resolver.dart:20-25` returns `PortalNavigation.companyTabs(orgType)` when the role is null, so an unassigned employee sees Admin, Management, Controller, Security, Reconciliations. **Privilege escalation by omission — one live employee is in this state now.** ✅ **UX half done** — the resolver now renders `WaitingForRoleScreen` (which existed, fully built, and had never been instantiated anywhere). ⬜ **Still open: the router-level guard**, so the same rule holds against a deep link.
- [ ] 🔴 **P4-09** **G2 — no intra-org role guard.** Once `org_type` matches, any employee can open any `/portal/{org}/*` route. A security guard with a two-tab sidebar can deep-link `/portal/mine/weighbridge`, `/tons-out`, `/reconciliations`, `/employees`. ✅ **Router half done 2026-08-11** — `portalRouteAllowedForRole` in `portal_nav.dart` is read by the redirect and derived from the same trees the rail renders, so the two can no longer disagree (P7-07). The rule is subtractive: allowed under one of the role's own leaves (which keeps detail routes working), denied under a leaf the org's full tree names and this role's does not, allowed otherwise — a whitelist would have blocked `accept-route/:routeId`, `allocate-fleet/:routeId` and `drop-off/:tripId`, breaking the transporter accept flow to tighten a guard. ⬜ **Still open: RLS.** A blocked route still leaves the RPC callable, and the Dart check is UX. **Do not tick this item until the same rule holds in the database.**
- [ ] 🔴 **P4-10** **G3 — `must_change_password` ignored for employees.** Lines 265, 276, 286 all require `user_type == 'company'`. Admin-created employees — the majority — are never forced to change their temp password.
- [ ] 🔴 **P4-11** **G4 — expired access never enforced.** `/expired-access` requires `state.extra` and **nothing navigates to it**; `PortalWorkspacePhase` has no `expired` case. An expired company keeps full access. Add the phase, the redirect, and RLS-level denial.
- [ ] 🟠 **P4-12** **G5 — dismissed driver bypass.** `/portal/driver/navigate/:tripId` sits **outside** the ShellRoute, so no workspace-phase gate applies. Add a router guard.
- [ ] 🟠 **P4-13** **G6 — incomplete profile never gated.** Users can skip `/account-setup` indefinitely. Decide: soft banner (current) or hard gate for operational roles.
- [ ] 🟠 **P4-14** **G7 — `_portalGateFieldsLoaded` is a one-shot static.** Role/org changes mid-session (promotion, transfer, dismissal) are not picked up until sign-out. Invalidate on the relevant realtime events.
- [ ] 🟠 **P4-15** **G8 — profile-gate failure fails open to non-admin** and retries on every navigation. A super admin with a transient fetch failure is silently bounced to `/home`. Surface the error; add backoff.
- [ ] 🟠 **P4-16** **G9 — `/chat/:chatRoomId` returns `HomeTabBodyScreen` when `state.extra == null`.** Every web refresh and every real deep link shows home under a chat URL. Load the room by id instead.

### 4.3 Route the orphans, delete the rest

- [ ] 🔴 **P4-17** Route `WaitingForRoleScreen` (279 lines, never instantiated) — the fix for G1.
- [x] 🔴 **P4-18** **Done 2026-08-11.** `/communications` now builds `CommunicationsHubScreen`; direct messaging keeps `/messages` and the chat dock, so nothing is lost. Reached from **Company ▾ → Announcements** in all three trees. ⚠ The screen brings its own `Scaffold` + `AppBar` inside the portal shell, which doubles the chrome — a pre-existing pattern here (`mine_supplier_buyers_detail_screen` does the same) that Phase 6 should settle for all of them, not a new fault. ⬜ `broadcast_messages` still holds 0 rows (P3-38) — reachable is not proven.
- [ ] 🟠 **P4-19** Add a nav entry for `drop_off_screen.dart` (routed, working, unreachable). ⚠ **Not a rail entry:** `/portal/transporter/drop-off/:tripId` needs a live trip, so a static entry could not know which one it meant. It belongs on the driver's Trip screen beside the other lifecycle actions — retarget this item there.
- [x] 🟠 **P4-20** **Done 2026-08-11** — **Logistics ▾ → Mine locations** in the mine tree. It is a hard dependency of driver navigation (`get_trip_nav_destination` resolves the collection point from it) and had been routed-but-unreachable since it was built. ⬜ `mine_locations` still holds 0 rows (P3-23).
- [x] 🟠 **P4-21** **Done 2026-08-11** — **Settings ▾ → Appearance** in all three trees.
- [ ] 🟠 **P4-22** Re-home `employee_status_timeline.dart` (only consumer was the orphaned waiting-for-role screen) into the register / profile timeline.
- [ ] 🟡 **P4-23** Delete `/super-admin/tons-out` and `/super-admin/seat-requests` redirect-only routes with zero inbound links, or link them.
- [ ] 🟠 **P4-24** Normalise the 6 screens reachable only via `Navigator`/`MaterialPageRoute` into the router so they have URLs and guards: `RequestTransportationScreen`, `StockpileAuditScreen`, `TonsOutDetailScreen`, `LoadingActivityDetailScreen`, `CompanyEmployeeRegisterScreen`, `RequestDeclinedScreen`.

### 4.4 Fix routes that discard their path parameter

- [ ] 🔴 **P4-25** `/portal/transporter/accept-route/:routeId` (L871) builds `const TransporterPortalDashboardScreen()` — id dropped. **Build the real screen (P8-10).**
- [ ] 🔴 **P4-26** `/portal/transporter/allocate-fleet/:routeId` (L883) builds `const FleetManagementScreen()` — id dropped. **Build the real screen (P8-11).**
- [ ] 🟠 **P4-27** `/portal/transporter/fleet/:id` (L834) builds `const FleetManagementScreen()` — id dropped. **Build `FleetVehicleDetailScreen` (P8-13).**
- [ ] 🟠 **P4-28** `/portal/mine/stockpiles/:id` (L617) parses `:id` and discards it. Pass it to `StockpileDetailScreen`.
- [ ] 🟠 **P4-29** `/portal/buyer/orders` (L731) is **byte-identical** to `/portal/buyer/requests`. **Build `BuyerOrdersScreen` (P8-14).**
- [ ] 🟠 **P4-30** `/portal/buyer/transactions` (L735) serves the **mine's** Operations Hub to a buyer. Give buyers a real transactions view or drop the route.

---

## Phase 5 — Design system extraction

> Two commits: **(a) pure extraction** — move + make public, zero behaviour change; **(b) restyle**. Never combine them.

### 5.1 Create the shared layer

- [ ] 🔴 **P5-01** Create `lib/core/design/` per `PLAN.md` §6.3.
- [ ] 🔴 **P5-02** Move `ml_tokens.dart` → `core/design/tokens/`. Unchanged; still law.
- [ ] 🔴 **P5-03** Extract `MlGlass` → `ml_surface_tokens.dart`, ~~**stripping the 364 lines of `MlSampleData`**~~ out of `minelink_screens_core.dart`. Mock data must not become reachable from the portal.
  ✅ **The `MlSampleData` half is DONE** (2026-08-13): 372 lines moved verbatim to `test/fixtures/ml_sample_data.dart`, taking the last 3 hardcoded `spark:` trend arrays and 13 raw `Color(0x` literals out of `lib/` with them. Mock data is no longer reachable from the portal — grep in `lib/` returns 0, guard `no-sample-data-in-lib` holds it. **The `MlGlass` extraction remains open** and belongs to S5.
- [ ] 🔴 **P5-04** Move `MlOv` / `OvTone` → `ml_overview_tokens.dart` **verbatim** (the file header explicitly freezes these values).
- [ ] 🔴 **P5-05** Extract private `_Sb` (20 slots, light + dark rail) from `super_admin_shell_layout.dart:34` → public `MlRailTokens`. **This is what finally gives the portal a light sidebar.**
- [ ] 🔴 **P5-06** Promote `ConsolePrefs` / `ConsoleAccent` / `ConsoleSidebarSkin` → app-wide `UiPrefs`. Org users gain accent, text scale, bold text, high contrast, canvas texture and rail skin.
- [ ] 🟠 **P5-07** 🆕 Move `UiPrefs` persistence off device-local `SharedPreferences` onto the user's profile row, so preferences follow the user across Windows / web / mobile. The console currently *claims* account-level storage and delivers device-local (see P9-16).

### 5.2 Resolve the collisions

- [ ] 🔴 **P5-08** **One accent.** Today `#2563EB` (console light rail), `#6AB8FF` (console dark rail), `#22D3EE` (`MlGlass` + `MlOv`), `#00B5D8` (`MlTokens.accent`, brand cyan). Pick one brand accent + defined rail variants; delete the rest.
- [ ] 🔴 **P5-09** **One UI sans: `Sora`.** ✅ Confirmed present with all 5 weights. Adopt it across the portal.
- [ ] 🔴 **P5-10** Adopt Fraunces for display numerals and section titles across the portal (console `SaStatTile` value = Fraunces 32/w600; portal `MlStatCard` = PlusJakartaSans 22/w800).
- [ ] 🔴 **P5-11** Apply `FontFeature.tabularFigures()` + JetBrainsMono to **every** tonnage, plate, waybill number, ticket, time and code in the portal. None do today.
- [ ] 🔴 **P5-12** **Delete `PortalColors.metric*`** (7 helpers derived from Material's seeded scheme, not `MlSemantic`, so they don't track `MlSemanticScope`). Move consumers to `MlSemantic` + `MlTone`.
- [ ] 🔴 **P5-13** Replace `PortalColors.sidebar*` with `MlRailTokens`.
- [ ] 🟠 **P5-14** Decide `MinePremiumPalette` (`glass` / `industrial`): **delete**, or re-express as two `UiPrefs` presets available to **all three org types**. A mine-only theme is itself a divergence — the same `MlCard` currently renders three ways depending on org type and a setting.
- [x] 🟠 **P5-15** 🆕 **Done 2026-08-11** — the palette is gone from the screen. `_Pal` is now a `_Pal.of(context)` factory over `MlSemantic` + `MlTone`, and the 12 slots resolve per theme; `surfaceTile` is the one that needed thought (raised above the card in dark, sunken into it in light — a single slot is invisible in one of them). The `_RoleGroup` colours went with it: each group now carries an `MlTone`, not a `Color(0xFF…)`. The console's navy did not disappear, it moved to where it belongs — `super_admin/screens/company_employee_register_screen.dart` is now a 50-line wrapper holding one `MlSemantic.custom` and passing it in, because the console chrome genuinely does not follow the user's theme toggle.

### 5.3 One shell, one rail

- [ ] 🔴 **P5-16** Extract `WorkspaceShell` from `SuperAdminShellLayout` — rail + top bar + painted canvas + `ChatDock` + `NavHistoryRecorder` + `PopScope`, parameterised by a `NavSpec`.
- [ ] 🔴 **P5-17** Extract `_WorkspaceCanvasPainter` (radial brand washes + 24 px dot grid). The portal renders on flat `surfaceApp` today.
- [ ] 🔴 **P5-18** Extract the console top bar: `_TopBarTitle`, `_HomeButton`, `_TopBarSearch`, `_LivePill`, `_PulseDot`. Delete the portal's hand-copied `homeChip`.
- [ ] 🔴 **P5-19** Move `super_admin/widgets/sidebar/` → `core/design/sidebar/` (minus `MlNav`).
- [ ] 🔴 **P5-20** Extract the classic rail family (`_SidebarNav`, `_NavGroup`, `_CollapsedNavGroup`, `_FlyoutItem`, `_NavBadge`, `_SidebarHeader`, `_SidebarSearch`, `_SidebarFooter`, `_NavTile`) from `super_admin_shell_layout.dart:624-2070`, decoupled from `/super-admin/*` literals and the console's providers.
- [ ] 🔴 **P5-21** Unify the two route→title tables (`_titleForPath`/`_subtitleForPath` vs `portalShellSectionTitle`) into one resolver on the shell.

### 5.4 Unify the components

- [ ] 🔴 **P5-22** `ml_card.dart` — merge `MlCard` ∪ `SaOrgTypeCard` ∪ `SaStatTile` ∪ `OvGlassCard` → `variant: flat | tinted | glass | hero`.
- [ ] 🔴 **P5-23** `ml_stat.dart` — merge `MlStat` ∪ `MlStatCard` ∪ `SaStatTile` ∪ `_Delta`. Portal stat cards gain the 3 px left accent strip, Fraunces 32 value, unit span, delta badge, mono sublabel.
- [ ] 🔴 **P5-24** `ml_section_head.dart` — merge `SaSectionHeader` ∪ `MlSectionHead` ∪ `MlSectionTitle`. Portal gains subtitle, meta and `"View →"`.
- [ ] 🔴 **P5-25** `ml_pill.dart` — merge `MlStatusBadge` ∪ `MlPill` ∪ `OvPill` ∪ `SaNewPill`. Keep `toneForStatus`. UPPERCASE everywhere.
- [ ] 🔴 **P5-26** `ml_well.dart` — merge `MlIconWell` ∪ `MlWell` ∪ `OvIconWell` (3 implementations).
- [ ] 🔴 **P5-27** `ml_meter.dart` — merge `MlMeter` ∪ `OvMeter` ∪ `_SeatsBar`.
- [ ] 🔴 **P5-28** **Promote `MlDataTable` + `MlColumn`** to `core/design/components/` and migrate the console's hand-rolled `_RecentOrgsTable` / `_RecentOrgsPanel` onto it. The one place the portal is ahead.
- [ ] 🔴 **P5-29** `charts/ml_charts.dart` — move `minelink_charts.dart` verbatim. **Collapse the 3 sparkline implementations to 1.**
- [ ] 🔴 **P5-30** `layout/` — move `MlGrid`, `OvFlexRow`/`OvFlexItem`, `OvCellGrid`, `_EqualHeightRow`, `MlHoverLift`. Portal card rows have ragged bottoms today because there is no equal-height row.
- [ ] 🔴 **P5-31** `motion.dart` — `mlScreenMotion`, `mlReducedMotion = 1ms` (**never `Duration.zero`**). Portal animations ignore `MediaQuery.disableAnimations`.
- [ ] 🟠 **P5-32** Rename `PortalScrollBody` → `MlPageBody`; align to `EdgeInsets.all(28)` and `contentMaxWidth 1280` (currently 16/16/16/32 and 1200). Add an `onAccent` ink token and remove `Colors.white` from `ml_buttons.dart`.

---

## Phase 6 — Portal migration onto the console design

### 6.1 Retire the parallel card families

- [ ] 🔴 **P6-01** Migrate all **16** `OverviewHeroTile` sites → `MlCard(variant: tinted)` / `SaOrgTypeCard`.
- [ ] 🔴 **P6-02** `OverviewPlaceholderBadge` → `MlPill`.
- [ ] 🔴 **P6-03** `AnimatedTons` → `MlStatCard`'s count-up (a duplicate — same 850 ms, same easeOutCubic).
- [ ] 🔴 **P6-04** `MetricBreakdownRow` → `MlStat`.
- [ ] 🔴 **P6-05** `BuyerOverviewCard` / `LoadingActivityCard` → `MlPanel` + `MlStat` + `MlButton.outline`.
- [ ] 🔴 **P6-06** `RequestBuyersCard` → `MlCard(variant: glass, accent: true)`. Remove its 5 hardcoded `Colors.white`.
- [ ] 🔴 **P6-07** Delete `premium_overview_widgets.dart` once empty.
- [ ] 🔴 **P6-08** Retire `premium_mine_dashboard.dart` (1596 lines, a fourth dashboard): `_KpiCard`→`SaStatTile`, `_ModuleCard`→`SaOrgTypeCard`, `_Pill`→`MlPill`, `_AccentButton`→`MlButton`, `_PremiumPanel`→`MlPanel`, `_TonsChartCard`→`MlFlagshipTrend`, `_StockpileGaugeCard`→`MlDonut`, `_SparklinePainter`→`MlSparkline`, `_SectionHeader`→`SaSectionHeader`.
- [ ] 🟠 **P6-09** Replace the **3 copies** of `_wrap(w, cols, tiles)` (mine ~L350, buyer ~L200, transporter ~L300) with `MlGrid`.
- [ ] 🟠 **P6-10** Replace the 2 private `_SectionHeader` copies with `SaSectionHeader`.

### 6.2 Kill every hardcoded colour in `lib/features/portal/`

- [ ] 🔴 **P6-11** `portal_scaffold.dart` — **~28 literals**, the entire rail palette → `MlRailTokens`, which already names every one.
- [ ] 🔴 **P6-12** `portal_shell_layout.dart:475,538` → tokens (both duplicated on the console side).
- [ ] 🔴 **P6-13** `driver_app_screen.dart:377,381,393,460,760` + 8× `Colors.white` + 2× `Colors.white70`.
- [ ] 🔴 **P6-14** `driver_navigation_screen.dart:58,909,1007` + 6× `Colors.white`.
- [ ] 🔴 **P6-15** `driver_routes_screen.dart:553,562` → `MlTone.accent` / `MlTone.done`.
- [ ] 🔴 **P6-16** `stockpile_audit_screen.dart:211` → `MlTone.error` / `MlTone.done`.
- [ ] 🔴 **P6-17** `tons_out_detail_screen.dart:461` → `MlTone.atMine.well(brightness)`.
- [ ] 🔴 **P6-18** `buyer_portal_dashboard_screen.dart:272` + 3× `Colors.white`.
- [ ] 🔴 **P6-19** `buyer_reconciliations_screen.dart:361` — `Colors.grey`, the last raw Material palette colour in the tree.
- [ ] 🔴 **P6-20** `ml_card.dart` hero gradient stop `Colors.white` → `semantic.surfaceCard`.
- [ ] 🔴 **P6-21** `request_transportation_screen.dart` (3×) and `transporter_portal_dashboard_screen.dart` (2× + white70).
- [ ] 🟠 **P6-22** Tokenise the console-side literals so the portal can adopt them: `super_admin_shell_layout.dart:25,~230,~250,~305,~330,585,610`, the canvas washes, `super_admin_dashboard_widgets.dart:14,126-127,~372`, `_Delta._green/_orange`.
- [ ] 🔴 **P6-23** Final grep: **zero** `Color(0x` and **zero** `Colors.` in `lib/features/`.

### 6.3 Screen-by-screen visual migration

- [ ] 🟠 **P6-24** Mine (13 screens): dashboard, supervisor, production, quality, buyers detail, reconciliations, security check-in, load controller, stockpile audit, stockpile detail, tons out, loading activity, mine locations.
- [ ] 🟠 **P6-25** Transporter (13): dashboard, earnings, routes, trucks on route, reconciliations, request tracking, truck locations, maintenance, fuel & costs, driver app, driver routes, driver navigation, drop-off.
- [ ] 🟠 **P6-26** Buyer (7): dashboard, routes & mines, requests, waybills, loads & value, reconciliations, truck locations.
- [ ] 🟠 **P6-27** Shared (10): compliance, live map, request transportation, appearance, profile, account security, company employees, employee profile, operations hub, messages.
- [ ] 🟠 **P6-28** Auth + onboarding (11): login, signin, forgot password, reset password, mandatory password change, WhatsApp OTP, profile setup, company selection, waiting for role, request declined, expired access.
- [ ] 🟡 **P6-29** Every migrated screen gets a `SaSectionHeader` with a meta line and, where applicable, a `"View →"` link, filter row and export affordance.

  🔸 **P6-24 … P6-29 — the type layer landed 2026-08-14; the gates stay open.**
  ✅ Portal titles onto the reference's faces — `MlPageHeader` (new) replaced the page header
  hand-rolled in 20 screens, and `MlSectionTitle` gained the reference's treatment across its 32
  call sites — proven by `portal_page_header_test.dart` (red: would not compile, the component did
  not exist) and `portal_section_header_test.dart` (red: `Expected: 'Fraunces' / Actual:
  'PlusJakartaSans'`) — every portal page and section title now renders in Fraunces, and both
  components expose the meta / `View →` slots P6-29 asks for.
  ⏸ **P6-29 is NOT satisfied by that.** The slots exist and **nothing is passed into them yet** —
  a header that could carry `Last 24h · 14 loads` and does not is a component change, not a screen
  migration. Neither are the filter rows or export affordances.
  ⏸ **P6-24…P6-28 remain unticked.** What the reference calls its strongest tell — uppercase
  letterspaced mono micro-labels captioning every panel and figure — is absent from the portal
  entirely, as are the stat card's left accent bar, the hero-figure treatment, rank rows and the
  one-accent-card-per-screen rule. Making them provable needs the per-screen capture loop run
  screen by screen, which is what these five items actually are.
  📌 The counts in P6-24/25/26 (13 / 13 / 7) are inherited and **have not been re-derived**. Four
  gate counts have already been wrong on this project by 3.8×, 1.7×, 5× and 1.25×.

---

## Phase 7 🆕 — Navigation, dashboards and the Employee Register

### 7.1 The nav model

- [x] 🔴 **P7-01** **Done 2026-08-11** — `lib/features/portal/nav/portal_nav.dart`. ⚠ Node type is a local `PortalNavNode`, **not** `MlNavItem`: `MlNavItem` carries no route, and importing it would point the portal at `super_admin/` — the exact dependency `PLAN.md` §6.3 exists to remove, since both move under `lib/core/design/` in Phase 5. They merge there, from a shared home rather than across a feature boundary. The tree is pure data (no widgets, no providers, no `BuildContext`), which is what lets P7-07 read it from the router.
- [x] 🔴 **P7-02** **Done 2026-08-11** — 16 missing destination routes added plus a shared `/account-security` (the screen was routed only under `/super-admin/`, so password and session controls were reachable by the two platform admins and by none of the 116 org users). Every leaf now carries a URL and the rail navigates with `context.go`. ⚠ `/home` is **still routed** and still renders the `LazyIndexedStack`: it is the post-login landing, and redirecting it is an auth-flow change that belongs with the Phase 12 removal of the flat list. It renders the org dashboard, so `/home` and `/portal/{org}` are the same page under two addresses; the rail selects the dashboard leaf on both.
- [x] 🔴 **P7-03** **Done 2026-08-11** — expanded groups are dropdowns; collapsed groups open an overlay flyout built on `MenuAnchor` (dismissal, focus traversal and screen-reader semantics come from the framework rather than hand-rolled). Auto-opens by route prefix **and** while a search is narrowing the tree. Explicit collapses are tracked as exceptions rather than as an open-set, so closing a group keeps it closed as you move inside it — but the group you are standing in never shuts under you. `_NavGroup`/`_CollapsedNavGroup` were not reused from the console: they are private to `super_admin_shell_layout.dart` and P5-20 has not run.
- [x] 🔴 **P7-04** **Done 2026-08-11** — integer badges on leaves, summed onto group headers, `99+` cap, mono tabular figures. Zero renders nothing (an empty queue is not news). The count also reaches the collapsed rail's tooltip.
- [x] 🔴 **P7-05** **Done 2026-08-11** — all **8** sources wired in `portal/nav/portal_nav_badges.dart`, each reading the same provider its destination renders so the badge and the page cannot disagree. Only what the session's own tree names is queried (a driver's rail must not fire the mine's inbound-trips read), and loading/error resolve to **no badge, never zero**. Counts: requests = `sent_back` only (counting `requested`/`resubmitted` would reproduce the console's own P9-02 fault); dispatches = `dispatched`; disputes = `open` + `under_review`; compliance = `expiring` + `expired` (dropping expired would silence the badge exactly when it matters); arrivals = `isInbound`; weighs = `isOnSite`; maintenance = `dueSoon`, which mirrors `notify_service_due_job`. ⚠ The requests count inherits P3-46 — it filters on `buyer_company_id` for a mine because the screen does; it follows the screen's fix. ⬜ The per-source predicates are **not** unit-tested (each needs a full domain model and the assertion would restate the `.where`); they belong to **P7-42**, the hand-count against the live queues.
- [x] 🔴 **P7-06** **Done 2026-08-11** — `PortalNavNode.filtered` searches the whole tree; a group whose own label matches returns whole, and matches inside a shut group force it open.
- [x] 🔴 **P7-07** **Done 2026-08-11** — `portalRouteAllowedForRole` is read by the router redirect *and* derived from the same trees the rail renders, so the two cannot drift apart again. See P4-09 for the half that is still open (RLS).

### 7.2 The three trees — build exactly as specified in `PLAN.md` §4.3

> **All seven trees are built (2026-08-11) and pinned by `test/portal_nav_test.dart`, whose load-bearing case reads the real route table out of `app_router.dart` and asserts every leaf names a path the router declares.** Five destinations named in the spec below are **deliberately absent**, each because pointing a rail entry at something that does not exist is the complaint being fixed, not the fix:
>
> | Missing leaf | Why | Unblocked by |
> |---|---|---|
> | ~~Employee register~~ | ~~shared screen not built~~ — **added 2026-08-11** under Company ▾ on all three trees, with `/portal/{org}/register` | P7-27…P7-33 ✅ |
> | Disputes | no org-facing screen exists — disputes are raised inside the Side B recon view | P8-42 |
> | Buyer **Orders** | `/portal/buyer/orders` is still a byte-identical alias of `/requests`; two entries for one screen is the complaint | P8-14 |
> | Buyer **Quality certs** | buyers already see quality inside Loads & value; no standalone screen | P8-17 |
> | Vehicle detail · Accept route · Allocate fleet · driver Navigation · Drop-off | each needs a live `:id` / `:tripId` and belongs to the record in hand, not to a static rail entry | P8-10/11/13, and reached from the dashboard sheet / Trip screen today |
>
> Add each leaf in the same change that lands its screen.

- [x] 🔴 **P7-08** **Done** — **Mine / Supplier — company, admin, management**: Dashboard · Operations ▾ (Supervisor & stockpiles, Production, Quality, Security gate, Load controller, Operations hub) · Logistics ▾ (Requests, Buyers, Trips, Live map, Truck locations, Mine locations) · Reconciliation ▾ (Reconciliations, Recon tables) · Company ▾ (Employees, Compliance, Announcements, Company profile) · Settings ▾.
- [x] 🔴 **P7-09** **Done** — **Buyer — company, admin, management**: Dashboard · Procurement ▾ (Requests, Routes & mines) · Deliveries ▾ (Waybills, Loads & value, Trips, Live map, Truck locations) · Reconciliation ▾ · Company ▾ · Settings ▾.
- [x] 🔴 **P7-10** **Done** — **Transporter — company, admin, management**: Dashboard · Operations ▾ (Routes & dispatches, Trucks on route, Trips) · Fleet ▾ (Vehicles, Drivers, Maintenance) · Money ▾ (Earnings, Fuel & costs) · Tracking ▾ (Live map, Truck locations, Request tracking) · Reconciliation ▾ · Company ▾ · Settings ▾.
- [x] 🔴 **P7-11** **Done** — **Mine — supervisorForeman**: Dashboard · Supervisor & stockpiles · Production · **Truck locations 🆕** · **Reconciliations 🆕** · Compliance · My profile. The Truck locations entry is the point: they fill the order stockpile and could not see which trucks were inbound to collect it. ⚠ *Read-only* reconciliations is not enforced — the screen is the same one admins get, so read-only has to come from RLS (P7-30 territory), not from the nav.
- [x] 🔴 **P7-12** **Done** — **Mine — controllerWB**: Load controller · **Weighbridge records → Operations hub 🆕** · Compliance · My profile. *My loads history* still to come (P8-15).
- [x] 🔴 **P7-13** **Done** — **Mine — security**: Security gate · **Incidents & gate checks → Operations hub 🆕** · Compliance · My profile. Stays otherwise locked and mobile-first. ⬜ Still open: saying so in-app.
- [x] 🔴 **P7-14** **Done** — **Transporter — driver**: Dashboard · My routes · Live map · Compliance · My profile. Navigation and Drop-off are reached from the Trip screen's lifecycle actions, which is where the `:tripId` lives.
- [ ] 🟠 **P7-15** Define what a non-admin/non-management **buyer** or **transporter** employee sees — currently Dashboard + Profile only, which is an empty product. ⚠ Note `UserRole.getRolesForOrgType` yields **admin and management only** for a buyer, so any other role on a buyer company is a data fault rather than a configuration. The tree gives it Dashboard · Compliance · My profile rather than an empty rail; **the product question is still open and needs a client ruling.**
- [x] 🔴 **P7-16** **Done** — gone from all three trees, and pinned: `portal_nav_test` fails any tree containing a label matching the operator's own org type or `Workspace`. ⚠ The tab *screens* still exist and are still reachable at `/home` — deleting them is P1-03…P1-08, deferred to Phase 12 by the client's sequencing directive.
- [x] 🟠 **P7-17** **Done** — one `Truck locations` entry per tree, pinned by a no-duplicate-destination assertion. The `transporter_truck_positions_screen.dart` file survives until P1-13.

### 7.3 Access the roles are currently locked out of

- [x] 🔴 **P7-18** 🆕 **Done 2026-08-11** — both roles now carry an Operations Hub entry (`/portal/mine/operations`, a route that did not previously exist), labelled for what that role owns: *Incidents & gate checks* for `security`, *Weighbridge records* for `controllerWB`. ⚠ The entry lands on the hub's **default** tab, not pre-scoped to the role's own one — `OperationsHubScreen` takes an `initialTabId`, but `OperationsAccessPolicy.visibleTabs(canEditAll: true)` still returns all six tabs ignoring org type (P2-11), so scoping the entry before that is fixed would hide the fault rather than fix it. ⬜ **The proof is still owed**: this makes the screen reachable, and P3-19/P3-20/P3-21/P3-22 are the real writes.
- [ ] 🟠 **P7-19** 🆕 Give **admin and management employees** access to company **Locations** — `CompanyLocationsSection` renders only when `userType.isCompany == true`, so only the owner account can manage collection points that driver navigation depends on.

### 7.4 Per-org-type dashboards

- [x] 🔴 **P7-20** **Done 2026-08-11 — all three dashboards rebuilt on the shared vocabulary.** `portal/widgets/dashboard/portal_dashboard_kit.dart` is the band vocabulary all three compose: `PortalDashboardHeader` (title + `PortalPeriodSelector` + page actions), `PortalKpiRow` over `SaStatTile`, `PortalActionQueue`, `PortalDashboardSection` over `SaSectionHeader` with `View →`, and `PortalLiveStrip`. Two rules are enforced by the *types*, not by memory: a `PortalKpi.value` is `String?` so an unavailable figure renders a dash and its reason (never `0`), and `route` is **required** on both the KPI and queue models so a tile that cannot show its workings cannot be built. Pinned by `test/widgets/portal_dashboard_kit_test.dart` — 4 widths × 4 scales × light/dark + bold, plus the null-vs-zero and navigation cases.
- [x] 🔴 **P7-21** **Done 2026-08-11** — all six bands, every figure from live rows. KPI row (period-scoped, with a real previous-window delta): tons out · stockpile balance/cap · trucks inbound · loads awaiting weigh. `MlFlagshipTrend` of daily net mass vs the previous window of the same length, with the company-scope monthly target from `monthly_targets` drawn **as a daily pace** (`target ÷ 30`) — a month's figure on a daily axis pins the rule to the ceiling and flattens every real day into the floor, the exact fault corrected on the transporters chart. No target set ⇒ **no line and no caption**. `MlDonut` stockpile fill counting only piles that *have* a cap (a production pile has none; folding it in as 0 would report the mine over capacity). Action queue on the same predicates as the rail badges, so page and rail cannot disagree. Live strip = every truck between the gate and the weighbridge, showing its **commodity rather than a fabricated ETA** (a straight-line ETA is only computable for a `?q=lat,lng` destination). Recent = last 10 waybills through `MlDataTable`, waybill number = the transaction reference, truck/product read through the newly-shared `waybillMeta()` so the dashboard and the recon table cannot populate the same column differently.
- [x] 🔴 **P7-22** **Done 2026-08-11** — all six bands off `list_buyer_trip_values`, which is buyer-private server-side and never returns the admin margin or the transporter's price. KPI row: tons delivered · **payable R** (at the agreed rate, after the moisture/grade penalty) · open orders (`linked` requests) · trucks inbound (left the mine, not yet offloaded). Trend: delivered tonnage against payable value — **the Rand series is indexed onto the tonnage axis, not plotted raw**, because R/day is 2–3 orders of magnitude larger and would flatten the tonnage line onto the floor; the legend says "indexed" and the meta line states the real peak R/day so the magnitude is never lost. Ring: invoice cover (delivered loads with an invoice captured). Queue: requests sent back · delivered loads to invoice · open disputes. Live strip: inbound loads showing **net tons where the mine has weighed them and nothing where it has not** — no fabricated ETA. Recent: last 10 deliveries with delivered tons and payable R, dashes where a rate has not been agreed (an unpriced load is not a load worth R0).
- [x] 🔴 **P7-23** **Done 2026-08-11** — KPI row: tons moved · revenue R · trucks on route · **fleet utilisation %, computed over the ACTIVE fleet** (a decommissioned truck is not idle capacity, and counting it would understate a working fleet). Trend: tons + revenue dual series, same indexing treatment and caption as the buyer's. Ring: the three server-derived fleet states — On Route (active trip), In Maintenance (open out-of-service record), Available as **the remainder by construction**, so the ring cannot disagree with the Fleet screen. Queue: dispatches to accept · trucks available to allocate · services due (on `dueSoon`, the same predicate as `notify_service_due_job`, so card, screen, rail badge and nightly reminder all agree) · open disputes. Live strip: trucks on route showing their **offloading point** rather than an invented ETA. Recent: last 10 completed trips with net tons and revenue.
- [x] 🔴 **P7-24** **Done 2026-08-11, all three.** `route` is a **required** field on `PortalKpi` and `PortalQueueItem`, so this is enforced at compile time rather than by review. Pinned by a navigation test that taps a tile and asserts the dashboard is gone.
- [x] 🔴 **P7-25** **Done 2026-08-11, all three.** Nothing on the rebuilt page is hardcoded; every series and count comes from `logisticsSnapshotProvider`, `stockpilesProvider`, `mineInboundTripsProvider`, `companyRequestsProvider`, `reconDisputesProvider` or `targetsProvider`. **The second mine dashboard is retired**: `mineAppearanceProvider` no longer swaps the page for `PremiumMineDashboard` (1,596 lines of a parallel dashboard matching neither this page nor the console, reachable only via a theme picker). The premium *chrome* is untouched — `portal_scaffold`/`portal_shell_layout` still skin the shell — only the dashboard fork is gone. ✅ **CORRECTED on the coming-soon card:** it is not on the mine dashboard and was not at `:406,422`. The only `Live operational records` string in `lib/` is `operations_hub_screen.dart:321`, where it is the Operations Hub's **subtitle** describing what that screen does — not a coming-soon card, and not something to delete. Verified against the pre-rebuild file in git: no `coming soon` match. Buyer and transporter carry no hardcoded value either — every figure on both is `null`-safe off a live provider.
- [ ] 🟠 **P7-26** ✅ **PARTLY CORRECTED 2026-08-11 — most of this is already built; two pieces remain.** `DriverDashboardTab` in `driver_app_screen.dart:126` already renders, from live rows: the **current-trip hero** (`_ActiveTripHero`, status pill + tap-through to the Trip tab), four stat tiles (loads this week · tons this week · deliveries · total tons), a tons-per-weekday chart with a **previous-week comparison**, the live-location toggle and a Log-fuel action. ⬜ **Still open: (a) next collection** — the driver sees the trip in hand but not the one after it; **(b) POD outstanding** — a completed trip with no POD is invisible to the driver, while it is exactly what the transporter's `PODS UPLOADED` register KPI counts against them. ❌ **Earnings-to-date is ruled OUT of the driver dashboard** (decision, 2026-08-11): the rate per ton belongs to the transporter–platform contract, and CLAUDE.md §4's rule that each party sees only its own side of the price applies to a driver as much as to a mine. Overrule with a client instruction if wanted.

### 7.5 🆕 Employee Register — per company, every org type

> The super admin already has a genuinely excellent one at `super_admin/screens/company_employee_register_screen.dart`: role-grouped employees, **live presence** (online/away/offline from chat presence + `profiles.last_seen_at`, 30-min away window), **driver → truck** via `driver_assignments` → `fleet_vehicles`, **role-group KPIs computed from live rows** (supervisors: stockpiles touched today; load controllers: loads recorded vs arrivals; drivers: PODs uploaded), compliance documents, and tap-through to the full employee profile. `pct` is `null` when there's nothing to count and renders as a muted dash — never invented.

> **Audit done 2026-08-11 (P7-30). Two corrections to the estimate above — read before starting.**
>
> **(a) The gating fault is presence, and it is now fixed.** `profiles_select_own` is `USING (id = auth.uid() OR is_super_admin())`, so a company owner/admin/manager can read exactly **one** profile row — their own. The screen's presence read is wrapped in `catch (_) {}`, so it would not have failed; it would have returned nothing and rendered **every colleague offline**. Reproduced live as the Roadhaul Logistics manager: reading `profiles` directly returns **1 row of 4**. Migration `20260811120000_company_member_presence.sql` adds `list_company_member_presence(p_company_id)` — a SECURITY DEFINER RPC returning `(user_id, last_seen_at, has_signature)` and nothing else, gated on `is_company_manager` or platform admin. Verified four ways live: manager→own 4 rows · manager→other company 0 · driver→own company 0 · no `auth.uid()` 0. **The screen must be switched to this RPC; the direct `profiles` read cannot work for a company user.**
>
> **(b) Every other table was already correctly scoped** and needed no migration: `employees` (`is_company_manager`), `driver_assignments` / `fleet_vehicles` / `compliance_documents` (`is_company_staff`), and `trips` / `stockpiles` / `stockpile_transactions` / `routes` / `pod_uploads` / `request_dispatches` / `recon_disputes` (all party-scoped). One caveat inherited, not introduced: `transportation_requests` is `is_company_staff(buyer_company_id)` — P3-46 — so the request-count KPI follows that fix.

- [x] 🔴 **P7-27** **Done 2026-08-11** — `lib/features/company/screens/employee_register_screen.dart` (1.6k lines) is the one screen; both the console and all three org types render it. Every `db.from(...)` left the widget file: `company/services/employee_register_service.dart` now owns all 13 reads behind typed models (`RegisterMember`, `MemberPresence`, `RegisterKpi`, `RegisterKpiBundle`, `RegisterComplianceDoc`) and four providers. The best-effort KPI blocks kept their shape but now **log through `LoggerFactory`** instead of `catch (_) {}` — a silent swallow is what hid the presence fault for as long as it hid it.
- [x] 🔴 **P7-28** **Done 2026-08-11** — exactly the shape the audit predicted: 12 slots, and the call sites were not rewritten. `_Pal` became a factory over `MlSemantic`/`MlTone`; the `ConsumerState` holds one `late _Pal _p` assigned at the top of `build`, and the two `StatelessWidget` helpers take the resolved `_Pal` as a field rather than threading `BuildContext` (same effect, one less parameter to keep in step). Swept in both themes — see P7-43's sibling, `test/widgets/employee_register_sweep_test.dart`.
- [x] 🔴 **P7-29** **Done 2026-08-11** — the screen still takes the whole `Company` (it needs `orgType` for the KPI branch and `userId` for the System-owner chip, so an id alone would not do), and `PortalEmployeeRegisterScreen` resolves the row: `resolvePortalCompanyId` → `registerCompanyProvider` → `CompanyService.getCompanyById`. Unlinked account, load failure and success are three distinct renders, the first two with a retry — not a bare `Center(Text(...))` (the fault P4-02 catalogues elsewhere).
- [x] 🔴 **P7-30** **Done 2026-08-11** — see the audit box above. Migration applied, mirrored to a file, ledger repointed; security advisors 0 errors (definer-executable count 173→174, which is this function, by design and inside P3-04's walk).
- [x] 🔴 **P7-31** ✅ **CORRECTED — already implemented in the original; do not build it.** `_kpiProvider` branches on org type at `company_employee_register_screen.dart:174` (`transporter`) and `:245` (`buyer`), with mine/supplier as the else. This is a **verification** task, not a build task: confirm each branch's counts against live rows once the screen is exposed.
- [x] 🔴 **P7-32** **Done 2026-08-11** — `/portal/mine/register`, `/portal/buyer/register`, `/portal/transporter/register` declared in `app_router.dart`, and the **Employee register** leaf added to the shared `_company(org)` group, in one change. `portal_nav_test` stayed green, which is the assertion doing its job rather than a coincidence.
- [x] 🔴 **P7-33** **Done 2026-08-11 (the enforcement half)** — `is_company_manager` gates the RPC, so a driver at the same company gets 0 rows. Live-verified. ✅ The sidebar half landed with P7-32 on 2026-08-11 — the leaf sits under Company ▾, which the trees already restrict to the full-access roles.
- [x] 🟠 **P7-34** ❌ **CANCELLED (client, 2026-08-11) — employee dismissal is removed from the app entirely (see §10.1). If this chip was already shipped, DELETE it under P10-06.** Superseded text: **Done 2026-08-11** — a dismissed member's card carries a second, tappable chip next to the red `Dismissed` one, pushing `/dismissal-management/{employeeId}`. Nested inside the card's own `InkWell`, so the inner tap wins and the card still opens the profile everywhere else. Pinned by a test. ⬜ P10-04 (the same action on `company_employees_screen.dart:865`) is still open.
- [x] 🟠 **P7-35** **Done 2026-08-11** — `has_signature` already came back from `list_company_member_presence` (the URL never does); the card now renders it as a muted *Signature on file* or an amber *No signature*. **Three states, not two:** when presence did not resolve for a member at all the chip is absent entirely, because "we could not look" is not the same as "they have not signed" — the identical distinction P7-30 was raised over. Pinned: 2 on file / 4 missing / 2 silent across the 8 fixtures. ⬜ P10-17's blocking prompt in the load-controller and POD flows is still open.
- [ ] 🟠 **P7-36** Surface **seat assignment** per employee once seat serials exist (P9-09).

### 7.6 Prove it

- [ ] 🔴 **P7-37** Build the nav matrix: **every (org type × role) × every nav entry** → renders real data or an honest empty state. 3 org types × up to 6 roles + 3 company accounts + super admin. Commit the result to the repo.
- [ ] 🔴 **P7-38** Every route in `app_router.dart` is now either (a) in a nav tree, (b) a legitimate detail/deep-link route reachable from a parent screen, or (c) deleted. **No orphans.**
- [ ] 🟠 **P7-39** Web deep-link test: paste every nav URL into a fresh browser tab while signed in as each role — correct screen, correct guard, correct sidebar highlight.
- [ ] 🟠 **P7-40** Browser back/forward behaves correctly now that tabs have URLs.
- [ ] 🟠 **P7-41** Collapsed-rail flyouts work on Windows, web and mobile drawer.
- [ ] 🟠 **P7-42** Badges reconcile against a hand-count of the underlying queues. ⚠ **Partially verified 2026-08-11 against the live database** (by the cloud session, which has direct MCP access). **2 of 8 proven, 1 proven-silent, 3 unprovable on today's data, 2 not yet checked.**

  | Badge | Verified against live data | Verdict |
  |---|---|---|
  | `unacceptedDispatches` | Roadhaul Logistics · Fast Freight Logistics · Test Live Transporter = **1 each**; Cyberhouse Transporter = **0**, its only dispatch is already accepted | ✅ predicate correct — it distinguishes `dispatched` from `accepted` |
  | `arrivalsAwaitingCheckIn` + `loadsAwaitingWeigh` | Iron Hills Mining has **2** open mine-floor trips (`arrived_at_mine`, `loading`); Operations ▾ must sum to **2** | ✅ split and group sum both correct |
  | `maintenanceDue` | **0** everywhere — the one active schedule is due 2027-01-19, 161 days out against notify-7 | ✅ correctly silent, which is the harder half to get right |
  | `openDisputes` | `recon_disputes` holds 0 rows | ⬜ **unprovable today** |
  | `expiringCompliance` | `compliance_documents` holds 0 rows | ⬜ **unprovable today** |
  | `pendingRequests` | **zero rows are `sent_back` platform-wide** | ⬜ **unprovable today.** The reasoning is sound; it is *not* proven. Do not record it as verified. |
  | `unreadNotifications` | — | ⬜ not yet checked |

  The three unprovable ones become provable as a by-product of P3-19…P3-39 (the empty-table verdicts) and of the request revision loop running once for real — not by staring at the predicate again.
- [x] 🟠 **P7-43** **Done 2026-08-11** — `test/widgets/portal_nav_rail_sweep_test.dart`: 4 widths × 4 text scales × 7 (org type, role) cases, expanded **and** collapsed rail, plus a bold-text pass, with every badge source lit and one value over the `99+` cap. Loads the real TTFs — the fallback test font makes every glyph one em wide, which both invents overflows and hides real ones (CLAUDE.md §7). 21 cases, all green, no layout fault found.
- [ ] 🟠 **P7-44** `MessagesScreen` gets a mobile layout — it hardcodes a 340 px sidebar in a `Row` with no `LayoutBuilder`, so it is unusable on a phone.

---

## Phase 8 — Workflow completion

### 8.1 Dead CTAs

- [x] 🔴 **P8-01** **Done 2026-08-11** — gone with the transporter dashboard rebuild (P7-23). `_RequestRoutesTile` and its `_snack('Route requests open with the platform marketplace.')` no longer exist anywhere in `lib/`; the rebuilt dashboard has no such tile, per spec (only mines and buyers raise transport requests). Pinned by `test/dead_cta_guard_test.dart`, which fails if the string returns.
- [x] 🔴 **P8-02** ✅ **CORRECTED 2026-08-11 — already built; there is no stub.** `'Buyer requests are coming soon.'` does not exist anywhere in `lib/` (nor does any other `coming soon` string outside two comments explaining one that was removed). `showBuyersRequestDialog` in `portal/widgets/request_dialogs.dart` is the real type-3 form and carries every field the spec lists — tons available, product specifications, multi-PDF lab results via `MultiFileDropPicker`, optional image, price/ton, payment terms, `FOB|FOT`, and the OSM `LocationPicker` — plus the sent-back → resubmit round trip with kept attachments. It is wired on **three** mine surfaces: `mine_supplier_buyers_detail_screen.dart:173`, `mine_supplier_portal_dashboard_screen.dart:141` and `:279`, and the mine's own Requests tab (`buyer_requests_screen.dart:76`, behind `isMine`). A type-3 insert by a real mine account is **step 2 of the P3-46 table above** — ✅. ⬜ Not opened in a browser (P7-39).
- [x] 🔴 **P8-03** ✅ **CORRECTED 2026-08-11 — already wired; no stub exists.** `stockpile_detail_screen.dart` routes both actions into `stockpile_docs_dialog.dart`, which is real and talks to `stockpile_docs`. The only `coming soon` text left in the file is a **comment recording that the stub was removed**. Verified by grep over all of `lib/`.
- [x] 🔴 **P8-04** ✅ **CORRECTED 2026-08-11 — same as P8-03**, already wired to the shared `stockpile_docs_dialog`. No stub.
- [x] 🔴 **P8-05** ✅ **CORRECTED 2026-08-11 — no such control exists.** No `Test requests` string anywhere in `lib/`. Removed at some earlier point; the plan item outlived it.
- [x] 🔴 **P8-06** ✅ **CORRECTED 2026-08-11 — the card did not exist on that screen.** Verified against the pre-rebuild file in git: no `coming soon` match in `mine_supplier_portal_dashboard_screen.dart` at any point. The only `Live operational records` string in `lib/` is `operations_hub_screen.dart:321`, where it is the Operations Hub's **subtitle describing what that screen does** — not a coming-soon card, and not something to remove.
- [x] 🔴 **P8-07** **Done 2026-08-11.** It exported **six key/value rows**: the batch's own primary key, its status, a date, and the three party company **UUIDs** — nothing a reconciliation is for, no load, no tonnage, no variance, and three of the six values were raw ids under labels reading as company names. It now emits the Side B rows through the **same** `WeightReconciliationView.exportHeaders` / `exportRows` the on-screen table renders, so the export and the screen cannot disagree: reference, truck, product, source, customer, transporter, mine net, delivered and **variance** per load. Empty batches say so rather than exporting an empty file. The card header now reads *`{Supplier} → {Buyer}` / Hauled by {Transporter}* from resolved names — the UUID-under-a-name-label fault from the P8-18…P8-29 sweep, fixed at the same site. A failed partner read renders "Unknown company", never the id.
- [x] 🟠 **P8-08** ✅ **CORRECTED 2026-08-11 — the card is no longer rendered.** The *"generate invoices, download reconciliations"* copy survives in exactly one file, `premium_mine_dashboard.dart`, which the mine dashboard rebuild **retired** (P7-25): no user setting selects it any more. The file itself stays until Phase 12 per the sequencing directive, so the string is still greppable — but nothing renders it. If that file is ever revived, the copy has to be earned or reworded.
- [x] 🟠 **P8-09** **Done 2026-08-11 — and one third of it corrected.** `coming soon`: **0** live occurrences (2 files carry it only in comments explaining the removed stub). `not implemented`: **0**. ✅ **CORRECTED on `will appear here`:** it is banned as written but appears in **13** files as correct **empty-state copy** — *"When you receive notifications, they will appear here"* describes a working feature with nothing in it yet. Forbidding it would push those screens toward saying nothing, or toward rendering a fabricated row. The phrase is not the fault; **promising an unbuilt feature** is. Enforced as a test rather than a grep: `test/dead_cta_guard_test.dart` fails the build on the two phrases that do promise, strips `//` comments first so a note explaining a removal is allowed, and carries a sanity check that it actually read `lib/`.

### 8.2 The missing screens

- [x] 🔴 **P8-10** ✅ **CORRECTED — this already exists. Do not build it.** The accept/decline flow is `showDispatchedRouteDetailSheet(...)` in `lib\features\portal\widgets\dispatch_route_widgets.dart`, opened from the transporter dashboard's Available-routes section. It shows the route package, Decline, and "Accept & assign trucks", calls `acceptDispatch` / `declineDispatch`, and correctly invalidates `transporterDispatchesProvider` + `logisticsSnapshotProvider` + `fleetStatusProvider`. The routes `/portal/transporter/accept-route/:routeId` and `/allocate-fleet/:routeId` are deep-link aliases that discard their param — **wire them to this sheet (P4-25/P4-26) rather than building a second implementation.**
- [x] 🔴 **P8-11** ✅ **CORRECTED — this already exists too.** `_AssignTrucksDialog` in the same file already filters to `FleetVehicleStatus.available` (`isActive && !onRoute && !inMaintenance`) and disables ticks past `num_slots`. Driver assignment lives in `DriverAssignmentDialog` (`lib\features\fleet\widgets\driver_assignment_dialog.dart`) with the 3..5 limit-request path already built. ⚠ `_AssignTrucksDialog` is **private** — make it public before reusing it from a route.
- [ ] 🟠 **P8-11a** 🆕 What is genuinely missing from the accept flow: (a) **no driver step** — a truck with 0 drivers can be accepted, and the two dialogs are never linked; (b) **under-allocation is silent** — you can accept 1 truck on a 5-truck route with no warning. Both are UI-level; deliberately NOT server errors (see P8-11b).
- [x] 🟠 **P8-11b** 🆕 ✅ **Done.** Server-side, `accept_request_dispatch` was **already** enforcing caller role, dispatch status, fleet ownership, no-double-booking, open-maintenance exclusion AND the `num_slots` cap — an earlier note claiming otherwise was wrong and has been corrected. The one real gap was `fleet_vehicles.is_active`, which the client filtered on and the server did not. Now enforced. Under-allocation and no-driver stay legal server-side on purpose: partial acceptance is a real operating pattern, and the spec's order is trucks-then-drivers, so requiring a driver would deadlock the documented flow.
- [ ] 🟠 **P8-12** 🆕 Build a real **Drivers** screen for `/portal/transporter/drivers` (currently `DriverTabScreen`, which is being deleted): roster, truck assignment, licence/compliance status, POD performance.
- [ ] 🟠 **P8-13** 🆕 Build **`FleetVehicleDetailScreen`** (`/portal/transporter/fleet/:id`): trips, maintenance history, fuel and costs, compliance documents, assigned drivers, current status.
- [ ] 🟠 **P8-14** 🆕 Build **`BuyerOrdersScreen`** (`/portal/buyer/orders`, currently an alias of requests): linked orders with fill %, allocated trucks, ETA, tons delivered vs ordered.
- [ ] 🟠 **P8-15** 🆕 Build **`MineLoadHistoryScreen`** for `controllerWB` — today a load controller has exactly Controller + Profile and cannot see the loads they recorded.
- [ ] 🟠 **P8-16** Build a **route detail screen** for `buyer_routes_mines_screen` — every route card's `onTap` currently ignores the route and opens the global truck map.
- [ ] 🟡 **P8-17** 🆕 Add a **Quality certs** entry to the buyer nav — the table and RPCs exist with no nav entry.

### 8.3 UI wording vs data

- [x] 🔴 **P8-18** ✅ **CORRECTED 2026-08-11 — the tile is gone.** The buyer dashboard rebuild (P7-22) replaced the KPI row entirely; there is no `Tons Allocated` string anywhere in `lib/`. The rebuilt row states **Tons delivered** (offload weight) and **Payable R**, each labelled for exactly the query behind it.
- [x] 🔴 **P8-19** ✅ **CORRECTED 2026-08-11 — no such copy exists.** No `Assign trucks` string anywhere in `lib/`. Reworded at some earlier point; the plan item outlived it.
- [x] 🔴 **P8-20** **Done 2026-08-11** — the column is now **`Transaction ref`**. It renders `transactions.reference_number` and tapping the row opens the transaction editor, so calling it *Waybill #* invited the reader to believe they were editing a waybill. The waybill is a generated, non-editable PDF whose NUMBER happens to be the same reference — the concepts share a value, not an identity, and the header now says which one is on screen.
- [x] 🔴 **P8-21** **Done 2026-08-11.** The card title reads *`{Supplier} → {Buyer}` · Hauled by {Transporter}* from resolved names, and `_showDetail` now prints those names plus what a reconciliation is actually about: **loads reconciled (n of N), mine net, delivered, variance**. It previously printed three raw UUIDs under labels reading Supplier / Transporter. Dashes rather than zeros before anything is delivered — an unreconciled batch has no tonnage, which is not a batch that reconciled to nothing. A company that cannot be resolved reads "Unknown company"; the id is never shown.
- [x] 🔴 **P8-22** **Done 2026-08-11** — same fix, same shared `_party()` shape: rows read *`{Supplier} → {Buyer}`* instead of `Recon <uuid8>…`.
- [x] 🔴 **P8-23** ✅ **CORRECTED 2026-08-11 — the column is gone.** The transporter dashboard rebuild (P7-23) replaced it; no `TXN ` string remains in `lib/`. The rebuilt **Trucks on route** strip shows registration + lifecycle label + offloading point, and **Recent completed trips** shows truck, source, customer, net and revenue.
- [x] 🔴 **P8-24** **Done 2026-08-11.** The list is filtered to what the heading promises: **not yet loaded and not cancelled**, sorted by lifecycle step, headed *Incoming & scheduled*. Completed trips no longer appear under a heading about incoming trucks. The cap is honest — it reads **"Showing 50 of N"** when it truncates and a plain truck count when it does not; a silent `clamp` reads as "this is all of them". Rows now lead with the **truck registration** (what a gate is looking for) with lifecycle label, net tonnage and updated date beneath, plus a status badge — instead of `Trip · <raw wire string with underscores swapped for spaces>`. The label comes from `TripStatus`, which owns it.
- [x] 🟠 **P8-25** ✅ **CORRECTED 2026-08-11 — the copy is already gone.** No `Add stockpile` / `create a stockpile` / `supervisors create` string in either file. Reworded when the order-driven stockpile flow landed.
- [x] 🟠 **P8-26** **Done 2026-08-11** — `Icons.schedule_outlined` → `Icons.scale_outlined`. A clock on a mass metric reads as a duration.
- [x] 🟠 **P8-27** ✅ **CORRECTED 2026-08-11 — already wired.** `allocatedBuyers` sums **real delivered tons-out from waybills**, matched to the allocation by buyer company id, and its doc says so explicitly (*"not the allocated stockpile estimate"*). A buyer with no delivered load shows **0 t**, which is the honest figure. The *"real tons-out wiring comes later"* note the item quotes no longer exists in the file.
- [x] 🟠 **P8-28** **Done 2026-08-11 — the charts are dropped, not faked.** All five were snapshot counts: **active vehicles, vehicles in service, floor headcount, seats used** and one flat `[0,0,0,0,0,0,0]`. There is no per-day history behind any of them, so there was no real series to substitute — `List.filled(7, currentValue)` renders as a perfectly level line, a graph asserting *"no change all week"* from data that says nothing about the week. `spark` is now **empty** for those five, and an empty series **draws nothing**: the space collapses and the number and label stay. The other sparklines on that screen are genuine `_dailySpark` series from event stamps and are untouched.
- [ ] 🟠 **P8-29** ⬜ **Partially done 2026-08-11.** Every label named in P8-18…P8-28 has been read against its query and either fixed or found already correct (7 fixed, 6 corrected as stale plan items). The **exhaustive** pass over every remaining KPI label, column header and card subtitle in the app is still owed, and its result still needs committing to the repo. Start from the pattern the fixed ones share: a label that names a *concept* ("Tons Allocated", "Waybill #") over a value that is a *different concept* (delivered net tons, a transaction ref) — and raw ids under labels that read as names.

### 8.4 The 22-step workflow

- [ ] 🔴 **P8-47** Steps 1–4 — register company → generate token → forced password change → create/approve employees with the seat gate blocking at limit and "Request Extra Seats" working. ⚠ **Renumbered from P8-30 on 2026-08-12 — the ID was used twice.** The weight-dispute item in §3.9 is also numbered P8-30, and *that* is the one the client ruling and the standing order cite, so it keeps the number. This step-list therefore runs **P8-47, then P8-31…P8-43** — out of order, but every ID is now unique and searchable, which matters more.
- [ ] 🔴 **P8-31** Steps 5–6 — all **four** inboxes render a clean non-editable submission; approve and send-back-with-note both work; `sent_back ⇄ resubmitted` loops with a pre-filled dialog.
- [ ] 🔴 **P8-32** Steps 7–8 — Route ID `RT-…`; **margin in R**; `margin_ledger` admin-only; transporter sees only their R/ton; the ordered due-diligence gate fires exactly as specified. ✅ *Verified already implemented to spec — confirm end to end and do not rebuild.*
- [ ] 🔴 **P8-33** Step 9 — request → `linked`; **capped order stockpile** minted (`max_cap_tons` = ordered tons, `balance_tons` = 0); `scheduled` trip created; **3 notifications** (mine supervisor deep-linked to the stockpile, transporter owner+admin+management, buyer).
- [ ] 🔴 **P8-34** Steps 10–11 — via the two new screens (P8-10, P8-11).
- [ ] 🔴 **P8-35** Step 12 — `stockpile_add_tons` cap-enforced with a ledger row; **every +30 t crossing fires a "ready to collect" alert to buyer + transporter**.
- [ ] 🔴 **P8-36** Steps 13–14 — driver start → `en_route_to_load`; GPS at 30 s; security Mark Arrived → `arrived_at_mine` + `gate_checks` row + **Load Controller notified**.
- [ ] 🔴 **P8-37** Step 15 — Tare then Gross (**photo + manual**); 4 seal serials + photos; scale photos; **Net = Gross − Tare computed, never typed**; `record_truck_load` → recon row + load + seal + **stockpile decrement** + waybill; Security notified.
- [ ] 🔴 **P8-38** Step 16 — atomic `left_mine → en_route_to_offload`.
- [ ] 🔴 **P8-39** Steps 17–18 — POD + delivered tons → **`offloaded`** → `completed`; driver signature + timestamp into the waybill RECEIVED block; **variance computed and surfaced**.
- [ ] 🔴 **P8-40** Step 19 — mine attaches one `load_quality_certs` per delivered load against the route spec; buyer sees it in Loads & value; super admin in recon tables.
- [ ] 🔴 **P8-41** Step 20 — loaded / delivered / **payable** Rand; `payable = delivered × (1 − excess moisture/100)`; `grade_factor = min(1, Cr₂O₃/spec)`; invoice capture; **variance = invoiced − payable**. Never exposes the admin margin or transporter price.
- [ ] 🔴 **P8-42** Step 21 — dispute raise → comment → super-admin resolve.
- [ ] 🔴 **P8-43** Step 22 — stockpile hits 0 → `stockpile_depleted_at` stamped → mine notified → transaction closes.

### 8.5 Waybill and recon fidelity

- [ ] 🔴 **P8-44** Waybill is auto-generated, non-editable and print-ready, matching `assets/Varsiwave waybil 2l.png`: header + SECTION = **source mine name (dynamic)**; NUMBER = waybill ref (same as the recon WAYBILL NUMBER); TRANSPORTER; FLEET/REGISTRATION NO.; DESTINATION; TRUCK SEAL SERIAL NO. 1–4; PRODUCT; TONS = **Net**; DISPATCHED BY + Load Controller signature; RECEIVED BY + driver signature + date/time. ✅ *The PDF is drawn programmatically and has no missing-asset dependency — verify content, not assets.*
- [ ] 🔴 **P8-45** Recon columns **in this exact order**: `DATE · TIME-IN · WAYBILL NUMBER · TRANSPORTER NAME · TRUCK REGISTRATION NO · DESTINATION · PRODUCT · SOURCE · CUSTOMER · NET MASS · TIME-OUT`. SOURCE = mine, CUSTOMER = buyer, NET MASS = **Net** (never a tare figure). DATE only on the first row of each date group. Auto footer `Total Tons=`. **Extend `tons_out_entry`.**
- [ ] 🔴 **P8-46** Live recon cards **Day / Week / Month / Year / Total** in full words with Show/Hide; Total is a genuine all-time cumulative that never stops growing. Two views: **combined** (mine + super admin) and **transporter-based** (mine, linked buyer, that transporter). Both exportable Excel/CSV/PDF. Side A raw keeps **exactly two versions**; Side B is system-owned view-only. **Edit boundary enforced in RLS + RPCs, not just Dart.**

---

## Phase 9 — Super Admin completeness

- [x] 🔴 **P9-01** **Done 2026-08-12** — the three `const [4,6,5,…]` arrays are gone. `_spark()` is lifted into `_OrgTypeDeck` and fed from `rawReconRowsProvider(null)`, the **same feed the v2 screen uses**, so the two dashboards cannot disagree: real tons per day over a trailing 10-day window, split by which party column the recon row carries. All-zero when nothing moved — a flat line from real rows is honest; a rising line from the design drop's sample data borrows the credibility of the live metrics printed beside it.
- [x] 🔴 **P9-02** **Done 2026-08-12** — `listForAdmin` still returns every request of a type (the inbox needs closed ones for history) but now **says so in its doc**, and the count has its own name: `adminPendingRequestCountProvider` / `RequestService.countAwaitingReview`, filtering to `status.awaitingReview` (`requested` + `resubmitted`). Fixed at **three** call sites — the v1 dashboard, the v2 dashboard and the console sidebar badges — all of which read `.length` and labelled it *Pending requests*. The provider returns **null while loading or on error, never 0**: "nothing waiting" and "we could not find out" are different statements. The filter now lives once, beside the list it corrects, instead of at each call site where it was forgotten three times.
- [x] 🔴 **P9-03** **Done 2026-08-12** — `orgAggregates`, `pendingRequests`, `registry` and `recentOrgs` are now **required** on `MineLinkDashboardScreen`. They defaulted to `MlSampleData`, so a caller omitting one — or written from the constructor signature — silently shipped fabricated platform totals to a platform admin with nothing in the types or the render to say so. The change immediately broke two layout tests that relied on the defaults, which is the mechanism working: both now pass `MlSampleData` **explicitly**, because a layout sweep is the one caller for which sample data is correct, and it should have to say so out loud.
- [x] 🟠 **P9-04** **Done 2026-08-12** — one banner became two, each labelled for what it counts. *Tokens expiring soon* renders `tokensExpiringSoon`, which the repository computed and the UI threw away; *Token requests awaiting approval* renders `openTokenRequests` under a heading that matches it. They are different queues needing different actions, and the old single banner headed **"Expired token requests"** over a count of *open requests* described neither.
- [x] 🟠 **P9-05** **Done 2026-08-12** — *"updated live from the biometric gate and API events"* → *"read fresh on every load"*, on both the v1 dashboard and the insights-v2 copy of the same line. There is no biometric gate; it is a plain select per page load. A subtitle claiming infrastructure that does not exist is a harder problem than a wrong number, because nobody thinks to check it.
- [ ] 🟠 **P9-06** 🆕 Fix *"Requests waiting on your approval — oldest first, ordered by criticality"* — cards are in a fixed hardcoded order; no sort, no criticality concept exists. Implement or reword.
- [ ] 🟠 **P9-07** 🆕 Fix "Total tons managed / Jan → today": the delta beside it is *share of all-time tonnage moved in the last 24 h* rendered as growth.
- [x] 🟠 **P9-08** **Done 2026-08-12** — a company with **no access token** rendered the same green as one with months left. Both `No token` and an unparseable expiry are now **warn**; the unparseable case also says so (`Unreadable expiry`) rather than rendering an em-dash that reads as "not applicable".
- [ ] 🔴 **P9-09** 🆕 **Seat serials — CORRECTED: the scaffolding already exists and is correct to spec; nothing calls it.** `organization_seats` already has `serial_number` and `role_binding` columns, and `generate_seat_serial(p_role text)` already produces 12 random characters from a 68-char alphabet (upper + lower + digits + symbols) plus a **3-character role suffix** — `MGT` / `ADM` / `CTR` / `SEC` / `DRV` / `GEN` — giving 15 chars with **the last 3 identical per role type**, exactly as specified. But **0 of 106 seats have a serial and 0 have a role binding**: `create_serial_token` mints seats with `generate_series` and never calls it. The job is therefore *wiring*, not building: (a) call `generate_seat_serial(role)` in the seat-minting path, (b) backfill the 106 existing seats, (c) render it. ⚠ **`supervisorForeman` is missing from the function's CASE and falls through to `GEN`** — add it. Visible only to `superGlobalSerialAdminMain` and the company owner.
- [ ] 🔴 **P9-10** 🆕 **Render `occupied_by_employee_role`** — the column exists, is parsed into `OrganizationSeat`, and is **never shown**.
- [ ] 🔴 **P9-11** 🆕 **Seat reassignment governance — nothing exists.** Max **2 per 30 days** per company, non-accruing, non-rolling. Zero hits for `reassign` across `lib/` and `supabase/migrations/`. Build the counter, the RPC guard and the UI.
- [ ] 🟠 **P9-12** Unlimited users / limited active seats: a company may hold unlimited employee records but only seat-holders get active access.
- [ ] 🟠 **P9-13** 🆕 **Audit log filters and paging.** The repository supports actor / org / orgType / actionTypes / startDate / endDate / limit / offset; the screen exposes **only action-type chips**, never passes `limit`, so the default **100-row cap** applies with no pagination — and the export therefore exports at most 100 rows. All four formats (CSV/PDF/Excel/JSON) are genuinely implemented; only the screen is missing.
- [ ] 🟠 **P9-14** Full audit action vocabulary logged with actor, role, action type, target, before/after, IP, device.
- [ ] 🟠 **P9-15** 🆕 Wire or relabel the three fake exports: "Export snapshot" (`:93-96`) and "Export report" (`:1387-1391`) just navigate; `dashboard_v2` `case 'export': return null;`. `ReconExporter` and `AuditLogExporter` both exist and work.
- [ ] 🟠 **P9-16** 🆕 `user_preferences_screen` says *"saved to the signed-in admin's account"* but uses **device-local `SharedPreferences`**. Either move to the profile row (P5-07) or fix the copy.
- [ ] 🟠 **P9-17** 🆕 Link the 3 pending-request dashboard cards to the **split** `transportation-mine` / `transportation-buyer` inboxes, not the combined one.
- [ ] 🟠 **P9-18** 🆕 `_DispatchStep` renders for **any** approved request, so product and buyer requests get a transporter/margin/dispatch UI they should not have. Gate it to transport requests.
- [ ] 🟠 **P9-19** 🆕 Give the product and buyer inboxes their **own field sets** — they currently share the transport-shaped one and fill with a wall of `—`.
- [ ] 🟠 **P9-20** Token countdown: extend `TokenExpiryLiveCountdown` (real 1-second timer, already correct on org detail) to the **organizations list** (currently static `Xd YYh`) and the dashboard.
- [ ] 🟡 **P9-21** Token confirm button reads `Confirm`; spec says **"Confirm, Yes I'm sure!"**. ✅ The three-button Cancel/Edit/Confirm structure, SHA-256 hashing and show-once warning are all correct.
- [ ] 🟠 **P9-22** Token history tab: current + Previous (Revoked/Expired/Replaced), Generate New · Revoke Current · Download Token History. Remove the hard 500-row cap or paginate.
- [ ] 🔴 **P9-23** Expired-access enforcement: expired users see **only** profile / account / support / expiry notice; all 11 operational capabilities blocked **in RLS** (pairs with P4-11).
- [ ] 🔴 **P9-24** Targets: prove the **write** path in a browser against a signed-in admin for all three scopes. ✅ *"Not set" vs 0, dashed-grey unreached horizons and scope independence are all verified correct — this is a proof task, not a build task.*
- [ ] 🟠 **P9-25** Margin ledger: verify in RLS that no transporter can read it. ✅ *`revoke all from public/anon` + `is_platform_admin()` verified — confirm.*
- [ ] 🟠 **P9-26** 🆕 Fix `transporters_overview_v2_screen.dart:352` — X-axis ticks hardcoded to days `[1,5,9,13,17]`, so there are no ticks between day 17 and "Today".
- [ ] 🟡 **P9-27** Remove every remaining trace of the **child super admin** from routes, UI and docs (pairs with P3-05).

---

## Phase 10 — Cross-cutting

### 10.1 🗑 Employee dismissal — **REMOVED FROM SCOPE** (client ruling, 2026-08-11)

> **Client:** *"This 'dismissed employee' — the complete employee dismissal needs to be removed from the app, I don't want it in the app at all."*
>
> The six repair items that used to live here (build the notification chain, give `/dismissal-management` an entry point, build a dismissal queue, prove the loop) are **CANCELLED** and replaced below by the removal work. **P7-34 is cancelled too.** Do not build any part of dismissal.
>
> **This is a scope removal by client decision, not cleanup — EXEMPT from the Phase-12 no-deletions deferral. Do it now.**
>
> **Verified safe against live production, 2026-08-11:** `employees.status='dismissed'` → **0 rows** (87 active, 1 inactive) · `is_dismissed=true` → **0** · dismissal notifications → **0** · dismissal rows in `employee_status_history` → **0** (only `role_assigned`, 25). Nothing in production has ever used this flow. **No data migration is required.**
>
> **The replacement path already exists and needs no work:** `remove_company_employee(target_employee_id)` — SECURITY DEFINER, checks the caller manages the company, refuses self-removal, unassigns fleet vehicles via `unassign_fleet_driver`, nulls `company_id`/`role`, sets `status='inactive'`, resets **every** dismissal column, and sends both notifications ("Removed From Company" to the user, "User Removed" to management).
>
> **⚠ HARD STOP — DO NOT DROP `employees.is_dismissed`.** It is referenced by **19 functions** — incl. `is_company_staff`, `is_company_manager`, `has_company_role`, `get_managed_company_id_for_current_user`, `are_chat_participants_allowed`, `is_company_stockpile_writer`, `link_and_dispatch_request`, `notify_company_role`, `remove_company_employee`, `assign_employee_role`, `request_company_link`, `list_company_chat_contacts`, `notify_company_management`, `_notify_company_token_managers`, `notify_incomplete_profiles_job`, `notify_token_expiring_soon_job` — plus the `chat_directory` view. Those functions gate most RLS in the app. It stays as a permanently-false flag. Removing the *feature* does not require removing the *column*. All other dismissal columns/constraints are deferred to **P12-28 — ask the client first.**

- [x] 🔴 **P10-01** **Drop the 3 RPCs** in one migration: `initiate_employee_dismissal(uuid,text)`, `resolve_employee_dismissal(uuid,boolean,text)`, `submit_employee_dismissal_appeal(text)`. Signatures confirmed live — use `drop function if exists public.<name>(<exact signature>);`. These three are the only writers of the dismissal columns besides `remove_company_employee`, which stays. **Done 2026-08-12** — migration `20260811180000_drop_employee_dismissal_rpcs.sql`, applied, mirrored, ledger repointed in its own call and re-selected. ✅ **And it changes what the surviving column means:** after the drop there is **no writer left anywhere in the database** of either `is_dismissed = true` or `status = 'dismissed'` — 0 hits scanning every `pg_proc` body for each. The flag is permanently false by construction, not by luck, which is what makes the Dart removals safe rather than merely untested.
- [x] 🔴 **P10-02** **Delete the Dart surface:** `lib/features/employee/screens/employee_dismissal_management_screen.dart` (561 L) · `lib/features/employee/screens/employee_dismissed_screen.dart` (456 L) · `lib/features/employee/widgets/employee_dismissal_form.dart` (203 L) · `lib/features/employee/providers/employee_dismissal_provider.dart` · root `test_employee_dismissal.dart` · root `employee_dismissal_documentation.md`. **Leave the copies under `docs/new system design/…/uploads/` alone** — that tree is an inert design-reference snapshot, not compiled. **Done 2026-08-12** — all six deleted (1,595 L of Dart). The `docs/new system design/…/uploads/` copies were left alone as instructed.
- [x] 🔴 **P10-03** **Delete the routes** `/dismissal-management/:employeeId` and `/employee-dismissed` from `app_router.dart`, plus every `context.go` / `context.push` that targets them. **Done 2026-08-12** — both routes, both router imports and all **nine** `context.go`/`push` call sites (the plan named the routes but not the count).
- [x] 🔴 **P10-04** **Remove `PortalWorkspacePhase.dismissed`** — the enum value, its resolver branch, and its render at `portal_shell_layout.dart:343-344`. A user removed from a company must now resolve to the same phase as an unlinked user; **verify that path renders and does not fall through to a company tab set** (regression guard on the `portal_tabs_resolver` privilege-escalation fix). **Done 2026-08-12.** Enum value, resolver branch and render all removed. ✅ **The fall-through cannot open:** the branch was *already* unreachable for a removed user, because `remove_company_employee` nulls `company_id` and the `!isLinkedToCompany → selectingCompany` check precedes it. Proven by `test/portal_workspace_removed_employee_test.dart` (9 assertions): a removed employee gets the waiting tab and **not one label from any org type's `companyTabs`** — the same privilege-escalation surface as P4-08 — with the fixture proved live first (a real role must yield real tabs) so the assertions cannot pass vacuously.
- [x] 🔴 **P10-05** **Remove the 4 dead notification builders** in `notification_service.dart` — `createDismissalInitiatedNotification` (L429), `createManagementDismissalNotification` (L455), `createDismissalAppealNotification` (L519), `createDismissalFinalDecisionNotification` (L579) — and their deep-link handlers at `notification_screen.dart:506-545` and `notification_management_screen.dart:240/257/270`. All four have **zero callers** today and the deep-links are dead branches. **Done 2026-08-12** — the four builders were one contiguous 184-line block; removed with the three `NotificationType` values and the icon/tone arms. `fromString` already falls back to `general`, so the parse stays tolerant of a legacy row; there are none.
- [x] 🔴 **P10-06** **Sweep the rest of `lib/`:** the dismissed-employees group at `company_employees_screen.dart:865`, the "Review dismissal" chip added to the Employee Register under P7-34, and every `EmployeeStatus.dismissed` / `'dismissed'` filter, tab, chip, label, count or sort key. Then `grep -ri dismiss lib/ test/` returns **only** `is_dismissed` reads. Finish with `flutter analyze` (0 new warnings) and `flutter test` green. **Done 2026-08-12 — and the sweep found considerably more than this item listed.** Beyond the two named: `EmployeeService` still called all three dropped RPCs (**a live runtime fault the moment the migration landed, not dead code**); three `EmployeeNotifier` methods and five state flags; four dismissal stages on `EmployeeApprovalStatus` plus five history fields; six dismissal columns on **both** `Employee` models; the legacy MCP `getPendingDismissals`; the profile flag, PDF status line, roster group/badge/dot-colour and the “Dismiss Employee” button; a `'Dismissed'` badge on `platform_users_screen`; the `case 'dismissed'` arm in **six** status-label switches; and `MlStatusBadge`'s tone heuristic still matching `'dismissed'`. Mockito mocks **regenerated** via `build_runner`, not hand-edited. The grep is now a permanent test, ruled on two patterns rather than a token list (a token list only ever grows and silently permits whatever nobody thought to add): the word `dismissal`, and the quoted `'dismissed'`. `flutter analyze` clean, `flutter test` 683 pass.

### 10.1b 🔴 **SEEDED DEMO DATA IS LIVE IN PRODUCTION** — found 2026-08-11, cloud session

> The client's brief is *"nothing with mock data anywhere, only real data"*. The reconciliation dataset fails that test outright. Evidence, all from live production:
>
> | Check | Result |
> |---|---|
> | `pod_uploads.photo_url` | **33 of 35** are the literal string `insights-demo/pod-placeholder.jpg` — one distinct value across all of them |
> | `storage` bucket `pod_photos` | ~~**0 objects.**~~ **1 object as of 2026-08-15** — a real 12,757-byte PNG uploaded by the assigned driver through the Storage API (S3-8). The 33 placeholder rows were a separate matter and went with the purge. |
> | `pod_uploads.uploaded_by` | **NULL on 33 of 35.** No human uploaded them |
> | `trips.variance_tons` | min = max = avg = **exactly 0.2000 t** across all 35. `delivered_tons = net_tons - 0.2` by construction |
> | POD timestamps | all land on the exact minute (`13:00:00`, `16:25:00`, …) |
> | `weighbridge_records` | **1 row**, dated 2026-03-30 — yet **37 of 41 trips are `completed`** |
> | Empty buckets | `load_photos`, `recon_docs`, `request_docs`, `chat_files`, `compliance_docs`, `quality_certs`, `support-attachments` — **0 objects**. `pod_photos` is **no longer among them**: 1 object since 2026-08-15 (S3-8). |

- [x] 🔴 **P10-D1** **Correct the P3-13 note.** The "systematic shortfall across every load" recorded there is **not an operational finding** — it is the seed script's fixed `-0.2` offset. A variance with zero dispersion across 35 loads is arithmetic, not measurement. Do not report it to the client as a business signal. **Done 2026-08-12 — confirmed, and the P3-13 note above is corrected in place.** Across all 35 reconciled loads `variance_tons` has **exactly 1 distinct value** and **stddev 0.000000** (min = max = avg = 0.2000). One value and zero dispersion across 35 independent weighings is arithmetic, not measurement. The P3-13 follow-up that proposed surfacing a systematic shortfall on the recon totals must **not** be built on this data.
- [x] 🔴 **P10-D2** **Every POD image is broken.** 33 rows point at `insights-demo/pod-placeholder.jpg`; `pod_photos` holds 0 objects. Find what the POD viewer renders when the object 404s and make it a stated empty state, not a broken image. Then confirm `record_pod` actually writes an object to `pod_photos` on a real upload — **no upload path in this app has ever produced a stored file** (see the empty-bucket row above). **Done 2026-08-12 — both halves of the premise need correcting.** (a) **Nothing renders a broken image.** There is no `Image.network` on this path: `PodPhotoIcon` offers a button, `resolvePodPhotoUrl` fails to sign a non-existent object, and the user gets *“Could not open the POD photo.”* — already a stated failure. The only real defect is offering a button for a photo that is not there, and all 33 rows go with the purge. (b) **The upload path is not broken.** `LifecycleService.uploadPodPhoto` genuinely does `uploadBinary` into `pod_photos` at `companyId/<uuid>_<name>` and is correct. It has never run because **the POD photo is optional** — `driver_routes_screen.dart:273` reads `if (photo != null)`, and both real PODs were recorded without one. So the finding is not “the upload is broken” but **“proof of delivery does not require proof”** — a product question, put to the client in `docs/seed-data-inventory.md` §7.
- [x] 🔴 **P10-D3** **Re-examine P9-01 / P1-25.** The case for promoting `super_admin_dashboard_v2_screen.dart` was that its `_spark()` reads *real* weighbridge rows. `weighbridge_records` contains **one row**. Whatever that sparkline draws today, it is not a month of operations. Re-verify before promoting anything. **Done 2026-08-12 — ✅ CORRECTED, the premise was wrong.** `_spark()` never read `weighbridge_records`. It takes `List<RawReconRow>` and sums `netMass` from `list_raw_recon_rows`, i.e. from **trips**; `weighbridge_records` is not in that path at all, so the single row was never what it drew. Promoting v2 (P9-01) was the right call and has since been done. What it draws *today* is **seeded** tonnage, and after the purge it draws a flat zero across most of its 10-day window — the only trips in the last ten days are 4 on 2026-08-02 and 5 on 2026-08-03, all seeded. A flat line from real rows is the honest render and must not be “fixed”. Separately still true: the one `weighbridge_records` row (2026-03-30) has `tare_weight`, `gross_weight` **and** `net_weight` all NULL, so even it records no weighing.
- [x] 🔴 **P10-D4** **Inventory every seeded row** — `pod_uploads`, the 37 completed `trips`, their `transactions`, and anything else with on-the-minute timestamps or a null actor. Produce the list with counts and the exact predicate that identifies each set. **Do not delete anything yet.** **Done 2026-08-12 — the full inventory is `docs/seed-data-inventory.md`, ready for the client. NOTHING DELETED.** 🔴 **It contains a finding that overturns P3-42:** there are **two** seeds, not the two migration files the plan names, and the larger one — `insights_demo_20260803`, **37 transactions + 37 trips + 33 PODs, 97% of the seeded volume** — **exists in no migration file and in no ledger row.** `grep -r insights_demo` over the whole repo returns one hit: the line in this file describing the problem. It went straight into production from an ad-hoc script, so it is **not reproducible or revertible from git**, and **deleting the two migration files would remove almost none of it** — migration files are not undo scripts. Totals: **38 of 41 trips, 38 of 42 transactions, 33 of 35 PODs, and 1,123.7 t of 1,193.7 t (94.1%) of all recorded tonnage are seeded.** Companies, employees, profiles, notifications, fleet, seats and tokens are all **real** and are not proposed for deletion. After the purge the platform holds 3 trips, 4 transactions, 2 PODs (**both without a photo**) and 70.0 t — the dashboards will look nearly empty, which is the point.
- [x] 🔴 **P10-D5** ✅ **CLIENT RULING 2026-08-11 — PURGE THE SEED DATA BEFORE RELEASE**, narrowed to a PARTIAL purge 2026-08-12 (seeded trips and transactions stay). ✅ **RUN 2026-08-13** as `20260813092000_purge_seed_demo_data_partial.sql`, after the client waived the P0-08 backup. The drift guard passed before any DELETE — live counts still matched the inventory the client approved — and the interlock refusing to run if a real POD had appeared on a seeded trip passed at 0. **Before → after:** placeholder PODs 33→0 (total `pod_uploads` 35→2), seeded reconciliation 1→0, seeded haul route 1→0, seeded positions 2→0 (54 `driver_app` rows untouched), seeded trips/transactions **38/38 kept**, `showcase_data` **14 kept**, seeded trips carrying `delivered_tons` 33→0, **real** trips carrying it **2→2**, trips with `variance_tons` 35→2, `net_tons` **1193.70→1193.70 unchanged**. Mirror file generated from `schema_migrations.statements` rather than retyped, md5-verified `e07c5cda776ad8566bed94978ee50bf2`; ledger repointed in its own call; `supabase/pending/` now empty. ⚠ **Tonnage stays ~1,193.7 t of which 1,123.7 t (94.1%) remains invented by the client's explicit choice — any dashboard figure checked against those totals is verified-against-seed, never proven.**
  🔵 **RULED 2026-08-12 — PARTIAL purge, and the ruling went against the recommendation.** The inventory proposed removing all of it; the client kept the trips and transactions so the dashboards still show movement. Full terms in the rulings block at the top of this file.

  **Status: WRITTEN, VERIFIED, NOT RUN — blocked on P0-08 and nothing else.** The migration is parked at **`supabase/pending/20260812120000_purge_seed_demo_data_partial.sql`**, deliberately *outside* `supabase/migrations/` so `supabase db push` cannot apply it by accident and so the migrations folder stays a true mirror of the ledger (P0-05).
  · **P0-08 was confirmed not done on 2026-08-12, so not one DELETE was executed**, exactly as the ruling instructs.
  · The migration's **guard block was run on its own against live production and passes**: pods 33 · recons 1 · routes 1 · positions 2 · seeded trips 38 — all matching the approved inventory. It aborts if any count has drifted, so it refuses to run against a database the client has not seen.
  · It carries a second interlock the ruling did not ask for: **it aborts if a real POD has since been recorded against a seeded trip**, because nulling that trip's `delivered_tons` would destroy a measured figure. Currently **0**.
  · **Why "every seeded trip" is safe to null, checked rather than assumed:** 38 seeded trips, 33 carrying `delivered_tons` (all from placeholder PODs); **2 real trips carry a delivered figure and 0 real PODs sit on a seeded trip**. The only two evidence-backed figures on the platform survive, and post-conditions assert exactly that plus `sum(net_tons)` unchanged at 1,193.70 t.

  **To finish it:** a human takes the PITR marker, ticks P0-08, then the file is applied and **moved into `supabase/migrations/`** with the ledger repointed.

- [ ] 🔴 **P10-D6** After the ruling lands, re-verify **every** super-admin KPI against whatever data remains, and re-check `MlSampleData` / `MlTargetsSample` are not silently backfilling the gap. ⚠ **Re-scoped by the partial ruling:** with the trips and transactions kept, the dashboards will look much as they do now, so this is no longer a "did the numbers survive" check. **It is the opposite: the totals are still 94.1% invented, so any KPI verified against them is verified against fiction and must be labelled that way, never recorded as proven.**

- [x] 🔴 **P10-D7** 🆕 **Proof of delivery must require proof** (client ruling 6, 2026-08-12). The POD photo is **mandatory** — a driver cannot complete a delivery without one. **Done 2026-08-12 — migration `20260812130000_pod_requires_photo.sql`**, applied, mirrored, ledger repointed, and the applied body **md5-checked against the file** (identical — no retype drift).

  **Enforced in both places, because the ruling says the requirement must be real rather than a disabled button.**
  · **UI** — `driver_routes_screen.dart:273` `if (photo != null)` is gone. The dialog record now carries a **non-nullable `XFile`**, so the optionality cannot return by omission, and the submit button says *why* it is refusing ("Capture the offload photo — a delivery cannot be recorded without proof") instead of being silently dimmed. `LifecycleService.uploadPodPhoto` was **wired, not rebuilt** — it was already correct.
  · **Server** — `record_pod` refuses a null or blank path. ⚠ **And a non-blank string check would have been theatre:** the 33 seeded rows carry a perfectly non-blank `photo_url` pointing at a file that has never existed, so a string check would have accepted every one of them. The function therefore requires the object to **actually exist in `pod_photos`**, under the **hauling company's folder** (waived for the platform admin, who has no portal company). Not retroactive: the 2 real historic PODs are left alone rather than rewritten.

  **The bucket has now held a file — the ruling's specific demand.** As the real driver `roadhaul.driver@mineralguide.com`, signed in through the live auth API: uploaded a genuine JPEG to `pod_photos/167aba53…/…_pod-proof-p10d7.jpg` (**160 bytes, HTTP 200**), read it back through the private bucket's RLS (**HTTP 200, 160 bytes, `image/jpeg`**), and confirmed in `storage.objects` with `owner_id` = the driver's user id. **First object ever in that bucket.** Removed afterwards by the same driver (HTTP 200, which also exercised `pod_photos_delete_company`) so no test artefact is left in production.

  **Then all four server branches proven as that driver, in a rolled-back transaction (0 residue):** ① no photo → refused · ② blank/whitespace → refused · ③ **the seeded placeholder path `insights-demo/pod-placeholder.jpg` → refused** (the case a string check would have passed) · ④ another company's folder → refused · ⑤ **the genuine uploaded object → ACCEPTED**, trip to `completed`, delivered recorded. 5 of 5.
  ⬜ **Not claimed:** not driven from a real device or browser — the camera/permission path is P11-09 territory.

- [x] 🔴 **P10-D8** 🆕 **The demo-data banner, not the demo data** (client ruling 7, 2026-08-12). The client **keeps** the 14 `showcase_data` rows and the `Chrome Ore - Atlas (UI test)` stockpile; the false banner cannot ship. **Done 2026-08-12 — `DemoDataIndicator` removed; not one row deleted.**

  ⚠ **CORRECTION TO THE RULING'S PREMISE, and it changes the blast radius rather than the conclusion.** The ruling says the banner "fires whenever `showcase_data` is non-empty — **always** — and tells **real customers their live screens are demo data**". The first half is right; the second is not. `DemoDataIndicator` was mounted at exactly one place — `tutorial_overlay.dart:104`, **inside the guided-tour overlay**, which renders nothing unless the user explicitly starts a tour. **It never appeared on a live screen and no customer saw it unprompted.**

  **The conclusion stands anyway, for a different reason.** The tour narrates the operator's **own real screens**; `ShowcaseItem.data` has never been read by any widget, so no example content is shown at any point. The banner therefore told a user taking the tour that their **real data was demo content** — the same class of lie, inverted. **There was nothing true left for it to say**, which is why it was removed rather than retriggered: an honest trigger would have to fire on showcase content actually being *rendered*, and nothing renders it. The misleading comment above the mount point ("*the tour's example content comes from the seeded showcase_data demo set*") went with it, since it asserted the same untrue thing.

  **Kept deliberately:** the 14 rows, the `Chrome Ore - Atlas (UI test)` stockpile, `ShowcaseService`, `ShowcaseItem` and `showcaseDataProvider` — the rows are now a client decision rather than an accident, and whoever builds the tour's example content is meant to read them through that provider (**P10-24**). **Removed:** only `hasShowcaseDataProvider`, whose sole job was to answer "is `showcase_data` non-empty" and whose sole consumer treated that as "this screen is showing example content" — two different statements, and conflating them is the whole defect. A comment at its former site warns against reintroducing a presence-of-rows trigger.

### 10.2 🆕 Chat

- [ ] 🔴 **P10-07** **Enforce the chat hierarchy.** `get_chat_contacts` currently returns, for any non-super-admin, *every user in their own company regardless of role* plus *every user at every connected company* — so **a driver can DM anyone in their company or any connected company**. `role` is returned but used only as a grouping label. Spec: companies and managers may initiate with anyone in their company (**only the company can end a chat**); admins with managers and any role except companies; everyone else **only** with admins. **Enforce in the RPC, not the UI.**
- [ ] 🟠 **P10-08** **Group chat.** `createOrgGroup` accepts exactly **two** company ids — a 3-company group is structurally impossible — and is **never called from any UI**. Spec: max 3 companies, **only one of each org type**, Accept/Decline invites with a notification back to the inviter. Rebuild the signature, add the org-type-uniqueness check server-side, and build the creation UI.
- [ ] 🟠 **P10-09** **"End chat"** — no method, no column, no button exists. Build it, company-only.
- [ ] 🟡 **P10-10** Company logo → read-only company profile from within chat.

### 10.3 Notifications

- [ ] 🔴 **P10-11** 🆕 **`UserRole.driver` is absent from management's and admin's `managementNotificationScopes`** — a manager's management screen will never show driver-scoped notifications even when addressed to them. Add it.
- [ ] 🟠 **P10-12** 🆕 The company-account branch filters on `org_type` only, so a company sees notifications intended for a specific role. Scope properly.
- [ ] 🟠 **P10-13** 🆕 Decide and implement what *"companies see all users' actions, management sees everyone below them"* means. Today every read is `.eq('user_id', me)` and the hierarchy is only a **narrowing filter on your own rows**, depending on the sender fanning out copies — done for some events, not others. Either systematise the fan-out or add a scoped read path in RLS.
- [ ] 🟠 **P10-14** Every workflow step in §8.4 fires its specified notification to its specified audience, and every deep link lands on the right screen.
- [ ] 🟠 **P10-15** Prove the four notification jobs deliver: token expiring, documents expiring, service due, incomplete profiles.

### 10.4 Signatures

- [ ] 🟠 **P10-16** ✅ *Verified correct — `ProfileSignatureCard` renders for every user type, the pad exports a genuinely transparent PNG, and both `record_truck_load` and `record_pod` pull `profiles.signature_url` server-side. **Nobody is ever asked to re-sign.*** Confirm after the design migration.
- [ ] 🔴 **P10-17** 🆕 Only **3 of 116** profiles have a signature. A user without one gets a **blank waybill signature line with no warning.** Add a blocking prompt in the load-controller and POD flows, and surface it in the Employee Register (P7-35) and profile setup.

### 10.5 Company profile and compliance

- [ ] 🔴 **P10-18** 🆕 **Company reg-ref does not exist.** `companies` has 29 columns and none is a reg-ref; `registration_number` is free-text, user-typed, unvalidated, not permanent, and **not displayed on the company profile at all**. Add the column, a generator (3 letters + ≥3 digits, e.g. `ABC001`), immutability, and a read-only row on the profile.
- [ ] 🟠 **P10-19** ✅ Company **Locations** with the OSM picker saving `https://www.google.com/maps?q=lat,lng` is **fully real** and feeds driver navigation via `get_trip_nav_destination`. Only 1 row exists live — populate and prove (pairs with P3-23, P7-19).
- [ ] 🟠 **P10-20** Compliance register works for all three owner types with daily expiry reminders.
- [ ] 🟠 **P10-21** `profile_requirements` (38 seeded rows) drives a real per-audience/org-type/role checklist, and the document `item_key` correctly doubles as `compliance_documents.doc_type`.
- [ ] 🟡 **P10-22** Decide whether employee document storage moves from public URLs to **signed private access**. Recommendation: **yes**, before a consumer release.

### 10.6 🆕 Tutorial / demo data

- [x] 🔴 **P10-23** **`DemoDataIndicator` shows *"Demo Data Active — showing example content"* whenever `showcase_data` is non-empty — i.e. always — while no example content is shown anywhere.** ~~It tells real customers their live screens are demo data.~~ ✅ *Verified the showcase data can never actually render as real data — `ShowcaseItem.data` is never read by any widget.* ~~Either render it during the tour as intended, or **delete `DemoDataIndicator` + `ShowcaseService` + the 14 `showcase_data` rows** (pairs with P3-42).~~

  ⚠ **AMENDED and CLOSED 2026-08-12 by client ruling 7 — see [[P10-D8]] for the full account.** Two changes to this item as written: **(a)** the rows and `ShowcaseService` **stay**, by explicit client decision — only the banner goes, so the "delete all three" option is off the table; **(b)** the claim that it "tells real customers their live screens are demo data" is **wrong** — it was mounted only inside the guided-tour overlay and never rendered on a live screen. It was still false (it labelled the operator's *real* data as example content), which is why it was removed rather than retriggered.
- [ ] 🟡 **P10-24** `ShowcaseService.getByCategory` is never called — delete or use.
- [ ] 🟡 **P10-25** Delete the unused `MessagingService` methods if the features don't ship: `setRoomMembers`, `grantConnection`, `revokeConnection`.

---

## Phase 11 — Platform, verification, release

### 11.1 🆕 Release blockers

- [x] 🔴 **P11-01** **Android `applicationId = "com.example.flutter_application_1"`** (and `namespace`). Play **rejects** `com.example.*`, and the package name is **permanent after first publish**. Fix before any store upload.
  ✅ **Client ruled `minelink.org` on 2026-08-13** → `org.minelink`. Both `namespace` and `applicationId` set; `MainActivity.kt` moved to `kotlin/org/minelink/`; manifest needed no edit (it names `.MainActivity`, relative to the namespace); no `google-services.json` exists so no Firebase registration to re-issue. — **Proven from the artifact, not the source:** `aapt2 dump badging app-debug.apk` → `package: name='org.minelink'`, `launchable-activity: name='org.minelink.MainActivity'`, and `aapt2 dump xmltree` over the APK manifest → **0** `com.example`. Guard `no-example-app-id` at `Mode.block` reports `BITES (clean 0 → planted 1)`; analyze clean, 689 tests green — commit `9a66986`. 🔴 **iOS/macOS/Linux still carry `com.example`** — raised as checklist S1-1a, not silently changed under an Android gate.
  🔴 **Two build defects surfaced doing this, both pre-existing:** the Gradle wrapper jar is a 2015-era build that cannot bootstrap the declared Gradle 8.12 (*"Could not determine wrapper version"*), and `android/.gitignore:1` ignores `gradle-wrapper.jar` so it has **never been committed** — a clean clone cannot run `./gradlew` at all. Fixed locally only; recorded as checklist **S10-3a** because it blocks S10-3 and any CI Android job.
- [ ] 🔴 **P11-02** **Android release build signs with the debug keystore** — `signingConfig = signingConfigs.getByName("debug")`. No `key.properties`, no keystore, no release `signingConfigs`. Create a real keystore and config.
- [x] 🔴 **P11-03** **De-bundle the ArcGIS token.** `pubspec.yaml` declares `config/` as an asset dir; `config/map_tiles.local.json` holds a **live Esri token**, fetchable on web at `/assets/config/map_tiles.local.json`. Gitignore does not stop the bundler. Declare the config files individually, pass tile config via `--dart-define-from-file`.
  ✅ De-bundling done at `ea80681` (`- config/` → `- config/supabase.live.json`) and **independently verified**: a real 55 MB `flutter build web --release` grepped for the token literal returns **0 files**, `arcgis` **0 files**, and `build/web/assets/config/` holds exactly one file. Held by CI guards `no-config-asset-dir` and `no-arcgis-token`, both `Mode.block`, both demonstrated biting on a planted violation. — **The token stays in `config/map_tiles.local.json`**: that file is the gitignored `--dart-define-from-file` source `run_web.ps1` feeds to `MAP_TILE_URL`. Stripping it would break local map tiles and prove nothing, because the exposure was never the file — it was the asset declaration. 🔴 **Rotation is NOT closed by this** — it is P0-04, human, still open; every artifact built to date shipped the token and it must be treated as compromised.

### 11.2 Builds

- [ ] 🔴 **P11-04** Windows build from the release commit; smoke-test the full workflow. Fix `CMakeLists.txt` `project(the_mineral)` / `BINARY_NAME "the_mineral"` → the shipped exe is currently `the_mineral.exe`.
- [ ] 🔴 **P11-05** Web build; smoke-test the same workflow, including every nav deep link (P7-39). Verify file pickers, PDF generation and map tiles.
- [ ] 🔴 **P11-06** Android build; smoke-test the same workflow. Pin `minSdk`/`targetSdk`/`versionCode`. ✅ *Permissions are complete and correct — INTERNET, COARSE/FINE/BACKGROUND location, FOREGROUND_SERVICE(_LOCATION), POST_NOTIFICATIONS; label is "MineLink"; geolocator merges its own foreground service.*
- [ ] 🟠 **P11-07** Prepare the Play Console **background-location declaration and demo video** — required by `ACCESS_BACKGROUND_LOCATION`.
- [ ] 🟠 **P11-08** iOS (if in scope): **add `NSCameraUsageDescription` and `NSPhotoLibraryUsageDescription`** — missing despite `image_picker`, which is a guaranteed crash on first photo pick and an App Store rejection. Location descriptions and background modes are already correct.
- [ ] 🔴 **P11-09** **Physical device GPS test** — a real road trip proving permission prompts, real GPS fix, Android foreground service surviving backgrounding, and live position ingest. Cannot be proven headlessly; this is a release gate.
- [ ] 🟠 **P11-10** 🆕 Remove `active user accounts.txt` from the working folder before any handoff — gitignored, but it contains **plaintext passwords** and would be swept into a zip.

### 11.3 Quality gates

- [ ] 🔴 **P11-11** Every screen survives **text scale 0.85–1.3 with bold text** at 3 widths. ✅ *The console already has a real sweep test (6 widths × 4 scales, real TTFs, adversarial fixtures) — extend it to the portal.*
- [ ] 🟠 **P11-12** Add tests for the zero-coverage areas: chat/messaging, support tickets, stockpiles and the order flow, waypoints, production dispatch, buyer load values and invoices, margin ledger, POD cross-party visibility, quality certs, driver assignments, compliance, ETA alerts, trip P&L, account setup. Report **"screens proving something / N"**, never the passing-test count; mark unproven screens expected-failure with a reason, **never `skip`**.

  🔸 **PARTIAL 2026-08-15 (S9-4) — 6 of the 14 areas, at the logic layer only.** New: `order_stockpile_fill_test`, `trip_waypoint_test`, `load_quality_test`, `buyer_load_value_test`, `production_stockpile_models_test`, `support_and_room_models_test` — **93 tests**, suite 936 pass / 1 skip.
  ⚠ **These prove LOGIC, not screens. The "screens proving something / N" figure is UNCHANGED** — every one is pure-Dart over models, no Supabase, no widget pumping. Deliberate: a widget test in these areas renders an error state without a backend, which is how the badge-isolation suite and the Employee Register sweep both went green while proving nothing.
  ✅ Proven to bite via `tool/mutation_check.py` — **25 mutations, 25 detected**, tree byte-clean after. This is the substitute for "seen red first" on a characterisation test, which has no "before" to be red against. It caught one of my own tests being worthless on its first run (a `ChatRoom` assertion a lazy cast satisfied just as well).
  ✅ Two cross-layer contracts pinned against the live project: the 30 t trailer (Dart `.floor()` vs `stockpile_add_tons`'s `v_load := 30`) and the waypoint ladder (`isTare`/`isGross` = sequence 2 and 4 vs `auto_generate_trip_waypoints`).
  📌 Measured coverage: 482 lib files, **224 → 233** imported by at least one test; 249 still never imported.
  ⏸ Still untested: margin ledger, POD cross-party visibility, driver assignments, compliance, ETA alerts, trip P&L, account setup, chat/messaging services. Several are RLS-shaped and want a DB walk (`A`), not a Dart test.
- [ ] 🟡 **P11-13** Decide the deferred major-version bumps: `fl_chart`, `flutter_map`, `go_router`, `infinite_scroll_pagination`, `intl`, `flutter_riverpod`, `mockito`, `latlong2`.
- [ ] 🟡 **P11-14** Archive the ~150 root-level legacy scratch scripts into `legacy/`. They are historical artifacts and actively mislead agents working in this repo.

---

## Release gate — every one must be true

- [ ] 🔴 🆕 **The request workflow completes for all three org types.** As of 2026-08-11 all 6 live requests belong to buyers and **no mine has ever raised one** (P3-46) — so step 5 of the 22-step flow, two of the four request types, and the super-admin Mine/Supplier inbox are all unexercised in production.
- [ ] 🔴 `flutter analyze` clean, no new warnings.
- [ ] 🔴 Zero raw `Color(0x…)` / `Colors.*` in `lib/features/`.
- [ ] 🔴 Zero "coming soon" / "not implemented" strings in `lib/`.
- [ ] 🔴 Zero hardcoded data series rendered as a trend.
- [ ] 🔴 Zero widget classes defined inside `app_router.dart`.
- [ ] 🔴 Every route has a nav entry, is a legitimate detail route reachable from a parent, or is deleted. **No orphans.**
- [ ] 🔴 The nav matrix (P7-37) is green for every org type × role.
- [ ] 🔴 All 9 auth-guard holes closed; all 27 anon RPC grants revoked; leaked-password protection on.
- [ ] 🔴 The 22-step workflow executed end to end on the live project by real test accounts of **every** role, with evidence per step.
- [ ] 🔴 Every KPI label, column header and card subtitle verified against its query.
- [ ] 🔴 Every table in §3.4 has a recorded verdict — proven with a real write, or hidden.
- [ ] 🔴 Every screen survives text scale 0.85–1.3 with bold text.
- [ ] 🔴 Android ships with a real `applicationId` and a real release keystore; the ArcGIS token is rotated and de-bundled.
- [ ] 🔴 Windows, Web and Android built from the **same commit** and smoke-tested through the same workflow.
- [ ] 🔴 Every applied migration has a matching file committed in the same change.
- [ ] 🔴 **No mock, demo, sample, dummy or hardcoded value renders anywhere as if it were real data — in any portal, in the console, for any role.**
- [ ] 🔴 🆕 **No table is readable across tenants.** `companies` and `minerals` narrowed; no `USING (true)` policy remains without a written justification.
- [ ] 🔴 🆕 **No storage bucket holding customer content is public.** `chat-attachments` and `support-attachments` private and served via signed URLs.
- [ ] 🔴 🆕 **The seat model is enforced** — every active employee holds a seat, or the model is formally dropped.

---

## Appendix C — 🆕 Known blind spots in this audit

This plan is thorough but not omniscient. **Nothing here has been built, launched or clicked** — no Flutter build was attempted on any platform, and every "REAL / works / verified" judgement is a code-and-schema reading, not a runtime observation. Expect the first execution phase to surface things a static read cannot.

Treat each of these as work, not as clearance:

- [ ] 🟠 **C-01** The 35 `storage.objects` policies — counted, not read (P3-49).
- [ ] 🟠 **C-02** The 173 `authenticated`-executable definer function bodies — sampled, not walked (P3-04).
- [ ] 🟠 **C-03** The remaining ~250 RLS policy bodies (P3-48).
- [ ] 🟡 **C-04** Database triggers — never systematically enumerated (P3-50).
- [ ] 🟡 **C-05** `pg_cron` schedules — job functions exist; scheduling unconfirmed (**P3-66**, renumbered from P3-51 on 2026-08-12 — that ID was used twice).
- [ ] 🟠 **C-06** Contents of `mine_locations_screen`, `transporter_maintenance_screen`, `driver_navigation_screen`, `request_transportation_screen` — routing confirmed, internals never audited.
- [ ] 🟠 **C-07** `chat_dock.dart` (6047 lines) — surface-audited only; the largest file in the app.
- [ ] 🟡 **C-08** `super_admin_repository.dart` — read in part.
- [x] 🟡 **C-09** Never opened: `Guide/`, `Looks of Pages within the app/`, `public_html_portal/`, `Someone/`, `output/`, `authenticate/`, `bin/`, `docker/`, `scripts/`. **`public_html_portal/` and `docker/` may imply deployment surface nobody has accounted for.**

  ✅ All nine opened 2026-08-15 (S9-8). Four are empty or single-file junk (`Guide/`, `Someone/Music/`, `authenticate/`, `Looks of Pages…`). `public_html_portal/` IS a real, untracked deployment surface — a PHP download portal on Afrihost serving the Windows/Android builds — and its `downloads/` sat under the web root with no `.htaccess`, so the login and CSRF on `download.php` were bypassable by fetching the ZIP directly. Fixed (`Require all denied`). The ZIPs themselves carry only `SUPABASE_URL` + a non-JWT publishable key — no service_role, and no Esri token (positive-control verified).
  ⚠ Main finding: `MineralGuide123!` is committed in **8 tracked files** and opens **26 confirmed live accounts** on production — 13 on Iron Hills Mining / Atlas Buyer Group / Roadhaul Logistics, which are `status=active` with tokens to 2027 and hold all 41 trips. None is a platform admin. The 37 occurrences in `output/` and the 2 hardcoded script defaults are gone; the remaining 14 are held by the new `committed-test-credential` ratchet. Rotation is production and is an ASK.
- [ ] 🟡 **C-10** `analysis_options.yaml` — a clean `flutter analyze` means little if the rules are permissive.
- [ ] 🟠 **C-11** **No crash or error reporting anywhere.** A consumer release with no telemetry is flying blind. **Recommend adding one before launch.**
- [ ] 🟠 **C-12** Offline and poor-connection behaviour never audited. Drivers on mine haul roads *will* lose signal — what happens to a POD mid-upload is unknown.
- [ ] 🟡 **C-13** Accessibility beyond text scale — screen-reader labels, focus order, contrast ratios, touch-target sizes.
- [x] 🟡 **C-14** Load and concurrency at 50 companies / 500 trucks. `vehicle_positions` (P2-01) is the one scale defect found by reading; there will be others.

  ✅ S9-6, 2026-08-15. One real defect found and fixed: `list_live_trip_positions` computed `stationary_since` with the predicate in a `FILTER` on the aggregate rather than in `WHERE`, so it read every position the vehicle had ever recorded — once per active trip, on a realtime-refreshed screen. Measured with 100k pings (34.7 days at the real 30s cadence): **1,435 buffers / 25.3 ms → 9 buffers / 0.050 ms**, and 2,922 → 9 for a truck parked 34 days. Results verified identical under both fixtures and across all 6 real vehicles. Migration `20260815107000`, applied, ledger repointed, mirrored, drift-checked byte-for-byte, and driven post-fix as a real `roadhaul.admin` (3 rows).
  ⚠ Not the defect this item names — P2-01 already fixed the client query; this one was in the server function.
  ⏸ A genuine 50-company / 500-truck **concurrency** run stays unprovable: it needs an instance that is not the customers' only production database. Data-volume behaviour is proven; simultaneous-load behaviour is not.
  🔸 Open, needing a ruling: `vehicle_positions` is in the realtime publication (1.44M events/day at 500 trucks vs ~4,500 lifetime events from every other published table combined) and has no retention policy.
- [ ] 🟠 **C-15** **Backup, restore and disaster recovery** — no documented procedure, on a single production project with no staging.
- [ ] 🟠 **C-16** **Legal and commercial** — POPIA compliance, data-retention policy, terms of service, privacy policy, client sign-off criteria. Out of engineering scope, **not** out of release scope.

**Two caveats on the plan itself.** Item counts and phase sizes are estimates from static reading — Phase 5 and 7 in particular may grow once extraction starts. And this audit inherits a codebase whose own documentation contradicts itself across generations; `PLAN.md` §2.1 records the rulings taken, but **a ruling is a decision, not a fact**, and the client may overrule any of them.

---

## Appendix A — Standing rules

**Git** — own branch; **never** `git stash` / `git checkout -- .` / `git clean` / checkout another branch in this worktree; one commit per logical change; commit before ending a turn.

**Code** — package is `flutter_application_1`, **do not rename** · feature-first `models/ services/ providers/ screens/ widgets/` · **all DB access through a feature service or a core repository**, never `SupabaseConfig.client` from a screen or provider · lifecycle mutations through the cascade RPCs · wire enums carry `.wire`/`.id` + tolerant `parse` · request status is its own enum, never `TripStatus` · the four request types stay separate entities · extend `stockpile_entry` / `tons_out_entry`, never parallel tables · `LoggerFactory.getLogger('Scope')`, never `print` · `flutter analyze` before anything is called done.

**Database** — files are the source of truth · one file per applied migration, never fold a fix into an earlier file · repoint `apply_migration`'s timestamp: `update supabase_migrations.schema_migrations set version = '<file timestamp>' where name = '<migration name>';` · mirror to a file in the same commit, without exception · **no staging — every migration lands on live data** (116 profiles, 88 employees, 26 companies, 41 trips) · security lives in RLS and RPCs, Dart checks are UX, **implement both** · new subscribed table → realtime **and** RLS in the same migration.

**Content** — currency **R (ZAR)** only · tonnage carries `t` · **no emoji in the UI** · a dial with no target reads **"Not set"**, never "0" · move an item to done **only when it is genuinely, fully implemented** — frontend + backend, DB + UI, wired and working.

---

## Appendix B — Files this plan touches most

| Area | Files |
|---|---|
| **Delete** | all 8 `tabs/screens/*` · `tabs/widgets/operations_workspace.dart` · `premium_overview_widgets.dart` · `premium_mine_dashboard.dart` · `platform_metric_grid.dart` · `PortalStatCard`/`PortalFeatureCard` · the whole `core/mcp/` legacy layer · `company_list_screen` · `employee_grid_screen` · `components_demo_screen` · `fleet_document_debug_screen` · `update_notification_schema` · 3 orphan notification widgets · 7 stray `main()` files · `web/debug_*.js` · `MlSampleData` · `MlTargetsSample` |
| **Extract from `app_router.dart`** | `_PortalTripsScreen` · `_PortalTripDetailScreen` · `_PortalTonsOutScreen` · `_PortalOwnCompanyScreen` · `_PortalTripWaybillRoute` (~430 lines) |
| **Extract to `core/design/`** | `super_admin_shell_layout.dart` (2000+ lines → shell + rail + tokens + top bar) · `super_admin/widgets/sidebar/**` · `insights_v2/minelink_screens_core.dart` · `insights_v2/minelink_charts.dart` · `transporters_overview/{overview_tokens,primitives}.dart` · `super_admin_dashboard_widgets.dart` |
| **Build new** | `TransporterAcceptRouteScreen` · `AllocateFleetScreen` · `EmployeeRegisterScreen` (shared) · `FleetVehicleDetailScreen` · `BuyerOrdersScreen` · `RouteDetailScreen` · `MineLoadHistoryScreen` · `DriversScreen` · seat-serial management · seat-reassignment governance · dismissal queue · group-chat creation |
| **Rewrite** | `portal_navigation.dart` → `portal/nav/portal_nav.dart` · `portal_tabs_resolver.dart` · `portal_scaffold.dart` · `portal_shell_layout.dart` · `portal_colors.dart` · `logistics_service.dart` · `app_router.dart` guards · all 3 org dashboards |
| **Migrations** | `trips.delivered_tons` + `variance_tons` · `record_pod` split + party check · atomic `leave_mine` · `set_trip_status` ordering assert · 27 `revoke execute … from anon` · `trip_is_on_time` search_path · seat serials · seat reassignment counter · company reg-ref · Employee Register RLS · child-admin gate removal · demo-seed removal |
| **Verify only — already well built** | due-diligence gate · margin ledger + R currency · Route ID minting · targets ("Not set", dashed horizons, scope independence) · token hashing + show-once · live countdown · the four request inboxes · Operations Hub · signature build-once/reuse · waybill PDF · company Locations · `mine_production_screen` · `mine_quality_screen` · `earnings_screen` · `fuel_costs_screen` · `buyer_loads_value_screen` · `transporter_routes_screen` · `trucks_on_route_screen` · `compliance_screen` · `security_checkin_screen` · `load_controller_screen` · the super-admin overflow sweep test |
