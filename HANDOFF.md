# Handoff — Mine-Link v1.0 release hardening

**For:** a Claude Code session running locally in this repo with a real shell.
**Branch:** `chore/release-v1-hardening` (off `feat/minelink-fork-merge`)
**Written:** 2026-08-10 by a cloud session with no shell.
**Last updated:** 2026-08-12 — **108/413**, pushed.

---

## ⛳ START HERE — 2026-08-12

**You are executing the standing order.** It is a multi-session brief with six
waves; you are not re-briefed between sessions. Read `To-Do's.md` and `PLAN.md`
first — both change under you.

### Where the waves stand

| Wave | State |
|---|---|
| **1.1** Remove employee dismissal | ✅ **Done** — `e989f14` |
| **1.2** Seed-data inventory | ✅ **Inventory done, `docs/seed-data-inventory.md`. AWAITING CLIENT.** Delete nothing. |
| **1.3** P3-51 org-type role enforcement | ✅ **Done** — `a890a60` |
| **1.4** P8-30 weight dispute (strip the hold, wire the disputes) | ⬜ **Next** |
| **1.5** P3-43 companies RLS tightening | ⬜ |
| **1.6** chat/support attachments → private + signed URLs | ⬜ |
| **1.7** P0-04 rotate the ArcGIS token | ⬜ **needs a human** — see the blockers list |
| **2–6** | untouched, except Phase 8/9 items another session has been landing |

### ⚠ Two sessions are writing this worktree right now — this is not theoretical

During the 2026-08-12 session `HEAD` moved twice under it (`f2b2f14`, then
`2c6c317`), and **the other session's `git commit` swept six of this session's
staged deletions into its own P9 commit.** No work was lost, but the six
dismissal-file deletions are recorded in a commit whose message is about
super-admin sparklines.

Consequences to plan for:

- **Stage and commit in one motion.** Do not `git add` and then go and run a
  10-minute `flutter test` — that is the window in which your index gets
  committed by someone else.
- **A red `flutter analyze` may not be yours.** Sixteen `missing_required_argument`
  errors appeared mid-session from the other session's in-flight P9-03 edit and
  resolved themselves when they finished. Check `git status` before "fixing"
  anything you did not touch.
- **Never `git stash` / `checkout -- .` / `clean` / switch branch.** Standing rule.

### The Wave 1.2 finding that matters most

**P3-42 is wrong.** It says the demo data comes out by removing two migration
files from the chain. The larger seed — `insights_demo_20260803`, 37 transactions
+ 37 trips + 33 PODs, **97% of the seeded volume** — **exists in no migration
file and in no ledger row.** It went into production from an ad-hoc script.
Deleting migration files removes nothing from a live database; the rows need an
explicit, predicate-guarded `DELETE`, and that needs the client's approval and a
PITR marker first (P0-08, which only a human can take).

**94.1% of all recorded tonnage on the platform is seeded.** After the purge:
3 trips, 4 transactions, 2 PODs and 70 t. Expect near-empty dashboards — that is
the correct outcome, not a regression to chase.

### Read the function body before you build from a plan item

Fifteen items have now been *corrected* rather than built. Three more this
session, and the pattern is always the same — the plan asserts an absence, and
the thing is already there:

- **P3-51** said `assign_employee_role` does not check org type. It does, and
  `is_valid_role_for_org` already held the client's exact matrix. The real hole
  was somewhere the plan never looked: `super_admin_set_employee_role`.
- **P10-D3** said the v2 sparkline reads `weighbridge_records`. It never did —
  it sums `RawReconRow.netMass` from trips.
- **P10-D2** said the POD upload path had never produced a file because it was
  broken. It is correct code; the photo is simply **optional** and nobody has
  attached one.

`select pg_get_functiondef(oid)` first. It has been right more often than the
plan, every single time.

### Two duplicate checklist IDs were found and fixed (2026-08-12)

`P3-51` named two different items and so did `P8-30`. The one cited by the
client ruling / standing order kept its number; the other moved to the next free
ID (**P3-66**, **P8-47**). All 413 IDs are now unique — the check is:

```
grep '^- \[' "To-Do's.md" | grep -o '^\- \[.\] [^*]*\*\*P[0-9]*-[0-9A-Z]*\*\*' \
  | grep -o 'P[0-9]*-[0-9A-Z]*' | sort | uniq -d
```

---

## Read these first, in this order

1. `CLAUDE.md` — the project's own rules. Auto-loaded. It wins over anything here.
2. `PLAN.md` — the audit and the reasoning. Repo root.
3. `To-Do's.md` — the 405-item checklist. Repo root. **This is the work queue.**
4. `git log --oneline chore/release-v1-hardening` — 6 commits, each explaining itself.

---

## Where the 2026-08-11 local session got to

**78 / 406. `flutter analyze` clean, `flutter test` 675/675. Everything pushed
to `origin/chore/release-v1-hardening` (`58f0580`).**

| Commit | What |
|---|---|
| `31bf703` | **The shared Employee Register** — P7-27/28/29/32/34/35, P5-15, P7-33 |
| `67c24da` | **P3-46 withdrawn** — the mine request path proven working; P8-02 already built |
| `1aef1e3` | **The dashboard kit + the mine dashboard** — P7-20/21/24/25 |
| `da00f6f` | **Buyer + transporter dashboards** — P7-22, P7-23 |
| `c7ff370` | **PLAN.md §16** — two settled rulings + the post-v1.0 cleanup list |
| `00ec23c` | **The router extraction** — P4-01…P4-07, and 31 dead fallbacks, not 4 |
| `72ba520` | **The variance hole closed** — P3-10…P3-16, P3-47 |
| `58f0580` | **Phase 8 dead CTAs** — P8-01…P8-07 + the guardrail test |

### ⚠ Another session is editing this worktree right now

`To-Do's.md` was modified underneath this session mid-run (CLAUDE.md §10.1):
Phase 12 grew an item and the header count changed between two of my writes, so
my counter update silently no-op'd against a stale literal.

**The progress figure is now defined as the count of ticked boxes**
(`grep -c '^- \[x\]' "To-Do's.md"`) and says so in the file. **Recount it;
never increment it.** That is the only edit-conflict-proof way to maintain it.

### What to pick up next, in order

1. **The label-vs-data sweep, P8-18…P8-29** — the half of item 3 not yet done.
   "Tons Allocated" showing delivered net tons, "Waybill #" rendering a
   transaction ref, the `clamp(0,50)` presented as a full list, the clock icon
   on a mass KPI. One of this family — raw UUIDs under Supplier/Transporter
   labels — is already fixed on the buyer recon card in `58f0580`; use it as the
   pattern.
2. **Phase 9, super admin (P9-01…P9-19).** Three hardcoded monotonically-rising
   arrays painted as trend lines beside live metrics, with the real `_spark()`
   already existing 320 lines away. `MlSampleData` in a default constructor
   argument. "Pending requests" counting every request ever raised. The
   "Expired token requests" banner counting *open* token requests while the
   genuinely relevant `tokensExpiringSoon` is computed and discarded. A subtitle
   claiming data comes "live from the biometric gate" — there is no biometric
   gate. Then seat serials: `generate_seat_serial` already produces the correct
   format and is **never called** (0 of 106 seats), and `supervisorForeman` is
   missing from its CASE.
3. **Phase 10, cross-cutting (P10-01…P10-23)** — the severed dismissal chain,
   the unenforced chat hierarchy, `DemoDataIndicator` telling every real
   customer "Demo Data Active".

### Traps found this session — read before repeating the work

- **A layout sweep that does not assert on content proves nothing.** The first
  green run of `employee_register_sweep_test.dart` was fake: `onlineUsersProvider`
  throws without an initialised Supabase, so every case rendered an error state,
  and an error state never overflows. Both new sweeps now assert a known string
  renders at every width × scale *before* believing the absence of faults. The
  same guard is in `dead_cta_guard_test.dart` (it checks it actually read lib/).
  **Copy it into any new sweep.**
- **Console components keep breaking the first time they are rendered narrow.**
  `SaSectionHeader` overflowed by 39px at 430px × 1.3; `SaStatTile` threw
  `BoxConstraints forces an infinite height` inside an `MlGrid` (it paints its
  accent as a `CrossAxisAlignment.stretch` sibling, and `MlGrid` is a `Wrap`).
  Both fixed. Expect more as console components move into the portal.
- **Before widening any RLS policy, read the row's full column list.** See
  PLAN.md §16.1(b) — widening `transportation_requests_select` for the linked
  mine would have leaked the buyer's price and the platform margin.
- **A threshold that fires on everything is not a signal.** Side B graded
  variance on a flat `> 0.05 t` → error, which flags **all 35** reconciled loads
  red (each is ~0.57% short). Both sides now share
  `portal/utils/variance_severity.dart` — percentage of load, 0.05 t floor,
  1% / 3% bands. When you touch a threshold, check what it does to the live rows.
- **Plan counts are estimates, not measurements.** P4-06 said four bare
  `Center(Text('Company not loaded.'))` fallbacks; there were **31**. Grep before
  believing a count.

### Corrected rather than built — now **twelve** items

P8-10, P8-11, P9-09, P7-31, P3-46, P8-02, P7-25's coming-soon card, P8-01,
P8-03, P8-04, P8-05, P8-06. **Verify before building.** It has been right more
often than the plan has.

### New decisions this session (overrule freely; they are deliberate)

- **`routes.variance_tolerance_pct` is NULL by default and holds nothing.** The
  `offloaded` hold is opt-in per route. Picking a tolerance number is an
  operator's call, not a migration's — so the migration does not pick one, and
  behaviour is unchanged until somebody sets it.
- **The mine cannot upload a POD, and cannot close a trip.** Its weighbridge
  figure is the other half of the variance; the party under test does not get to
  declare the result. `complete_trip` allows transporter, buyer or platform
  admin.
- **A systematic small shortfall across every load is deliberately NOT surfaced
  per-row.** It is real (the live data shows it) but it is an aggregate finding;
  colouring every row red buries it. Raised as a follow-up under P3-13.
- Everything from the earlier list below still stands.

---

## Where the earlier part of this session got to

**58 / 405. `flutter analyze` clean, `flutter test` 657/657.** Five commits, each
one self-contained:

| Commit | What |
|---|---|
| `31bf703` | **The shared Employee Register** — P7-27/28/29/32/34/35, P5-15, P7-33's sidebar half |
| `67c24da` | **P3-46 withdrawn** — the mine request path proven working; P8-02 already built |
| `1aef1e3` | **The dashboard kit + the mine dashboard** — P7-20/21/24/25 |
| `da00f6f` | **Buyer + transporter dashboards** — P7-22, P7-23 |

**Phase 7.4 (dashboards) and 7.5 (Employee Register) are complete.** What is
left in Phase 7 is the *proof* — P7-37…P7-42, none of which can be done without
a running browser and a signed-in account per role.

### What to pick up next, in order

1. **P4-01…P4-07** — extract the five screen classes out of `app_router.dart`
   (~430 lines backing 15 routes with no screen files), and replace the four
   bare `Center(Text('Company not loaded.'))` fallbacks with `MlEmptyState` +
   retry. The three dashboards now model exactly that pattern — copy the
   unlinked/error/data split from `PortalEmployeeRegisterScreen`.
2. **P3-10…P3-16 — the variance hole.** `trips.delivered_tons`, a variance
   generated column, `record_pod` writing both and splitting `offloaded` from
   `completed` (the app can only produce 8 of the 9 canonical statuses today),
   the party check corrected to match its own error message, the 37 completed
   trips backfilled, and variance surfaced in all three recon screens and the
   exports. This is the commercial heart of the reconciliation and the largest
   remaining functional gap.
3. Then straight down `To-Do's.md`.

### Traps found this session — read before repeating the work

- **A layout sweep that does not assert on content proves nothing.** The first
  green run of `employee_register_sweep_test.dart` was entirely fake:
  `onlineUsersProvider` throws without an initialised Supabase, so every case
  rendered an error state — and an error state never overflows. Both new sweeps
  now assert a known string renders at every width × scale *before* believing
  the absence of faults. **Copy that into any new sweep.**
- **Two real pre-existing layout faults surfaced the moment console components
  were rendered narrow**: `SaSectionHeader` overflowed by 39px at 430px × 1.3
  (meta and action were non-flex children after a `Spacer`), and `SaStatTile`
  threw `BoxConstraints forces an infinite height` inside an `MlGrid`, because
  it paints its accent as a `CrossAxisAlignment.stretch` sibling and `MlGrid` is
  a `Wrap`. Both fixed. **Expect more of this as console components move into
  the portal** — the console is a desktop-only surface and has never been
  rendered at 430px.
- **Before widening any RLS policy, read the row's full column list.** Widening
  `transportation_requests_select` so a linked mine could read its order was
  drafted and rejected: that row carries `price_per_ton`, `rate` and
  `admin_notes`. The near-miss would have leaked the buyer's price and the
  admin's margin to the mine.
- **Six plan items have now been corrected rather than built** (P8-10, P8-11,
  P9-09, P7-31, P3-46 + P8-02, and P7-25's coming-soon card, which does not
  exist). Verify before building. It has been right more often than the plan.

### Decisions recorded this session (overrule freely, but they are deliberate)

- **`buyer_company_id` is NOT renamed.** It is load-bearing for 5 functions, 4
  policies and the admin inbox's `companies!buyer_company_id` embed. It is
  documented in-database instead (migration `20260811160000`) and the Dart
  renamed off it. The column rename needs a client ruling.
- **Rand series are indexed onto the tonnage axis** on the buyer and
  transporter trends, with the real peak R/day stated in the meta line. Drawn
  raw, R/day flattens t/day onto the floor.
- **Driver earnings are ruled out of the driver dashboard** (P7-26): the rate
  belongs to the transporter–platform contract, and §4's each-party-sees-only-
  its-own-price rule applies to a driver too.
- **`premium_mine_dashboard.dart` is retired but NOT deleted** — no longer
  selected by the appearance setting, file kept until Phase 12 per the
  sequencing directive. Its *chrome* (the premium shell skin) is untouched.

---

## The one sequencing rule

**Build everything, fix everything, get the full flow working end to end — THEN delete.**

Phase 1 (Demolition) has been renumbered **Phase 12** and moved to the end at the
client's explicit instruction. Do not delete anything early. Specifically:

> `tabs/screens/controller_tab_screen.dart` and `security_tab_screen.dart` hold the
> **only** links to `/operations?tab=weighbridge` and `?tab=security`. Security and
> Load Controller are the only roles authorised to write security incidents, gate
> checks and weighbridge records — and they cannot currently reach that screen at
> all. Those two files must outlive the nav rebuild that replaces them (P7-18),
> not precede it. Deleting them first cuts two roles off from their only workflow.

---

## DO THIS FIRST — ✅ done 2026-08-11, do not redo

```
flutter analyze   ->  No issues found!   (baseline, P0-02)
flutter test      ->  All tests passed!  (522 at baseline, 622 now)
```

The four Dart files from `f9add87` **compiled clean as written** — nothing needed
fixing. The three by-eye checks that commit asked for were all verified:

- `PortalTabItem`, `WaitingForRoleScreen` and `ProfileScreen` all have `const`
  constructors, so the top-level `const _waitingTab` / `_profileTab` compile.
- `_fetchLatestVehiclePositions()` — `_pageSize` (1000) and `VehiclePositionRecord`
  are both in scope; `transactions.updated_at` and `vehicle_positions.recorded_at`
  both exist on the live project, so neither new query throws at runtime.
- `listPartnerCompanies` has three callers. `buyer_routes_mines_screen` has a real
  `.when(error:)` branch and now shows the failure. The other two
  (`mine_supplier_buyers_detail_screen:116`, `mine_supplier_portal_dashboard_screen:51`)
  use `.valueOrNull ?? const []` and so still swallow the error into an empty list —
  **no worse than before** (the old code returned `[]` too), but the rethrow buys
  them nothing until they grow an error branch. Worth doing with P2-09.

⚠ One thing the rewrite left: both new paged reads sort by a **non-unique** column
(`updated_at`, `recorded_at`) and page with `.range()`. Ties across a page boundary
can drop a row. Harmless for positions (deduped to latest-per-vehicle) and nearly
so for partners (ids go into a Set), but ordering by `id` would make both exact.

---

## What is already done (do not redo)

| Ref | What | Where |
|---|---|---|
| P3-01 | 27 SECURITY DEFINER functions were callable **unauthenticated**. Advisor 27 → 0. | migrations `20260810160000`, `20260810161500` |
| P3-03, P3-62, P3-63 | search_path pinned, 6 FK indexes, 1 RLS initplan fix | same |
| P8-11b | `accept_request_dispatch` now rejects inactive vehicles | migration `20260810170000` |
| P2-01 | `vehicle_positions` was `.limit(500)` **platform-wide** — a company's trucks fell out of the window entirely once total ping volume crossed it. Now time-bounded + paged. | `logistics_service.dart` |
| P2-03/04 | `listPartnerCompanies` `.limit(200)` removed; blanket `catch (_)` now logs + rethrows | same |
| P2-06/07, P4-08 | **Privilege escalation closed.** An employee with no role assigned was handed `companyTabs()` — the complete owner console. Now renders `WaitingForRoleScreen`. | `portal_tabs_resolver.dart` |
| P0-02, P0-03 | analyze + test baselines recorded | `43d1681` |
| P7-02 | 16 portal destinations had **no URL at all**, plus a shared `/account-security` (the screen was routed only under `/super-admin/`) | `be3dfa6` |
| P7-01/08…14/16/17, P4-18 | **The sectioned nav trees.** Pure-data `PortalNavNode` tree per (org type, role); roster tabs and the duplicate `Truck positions` gone; `CommunicationsHubScreen` finally routed so Announcements exists | `968295e` |
| P7-02/03/04/06, P7-43 | **The rail renders the tree and navigates by URL.** Dropdown groups, collapsed-rail flyouts, integer + summed badges, tree-wide search, longest-prefix selection, layout sweep | `b13811b` |
| P4-09 *(router half)*, P7-07 | **Intra-org role guard.** The redirect and the rail now read the same tree | `dc2beeb` |
| P7-05 | **All eight badge sources wired** to live queues, tree-scoped, loading/error never rendering a zero | `b52cfa0` |
| P3-43 *(prepared, NOT applied)* | The companies-RLS narrowing package, committed unapplied and queued for Phase 3 | `docs/rls-companies-tightening.md`, `a93a82e` |
| P2-05, P2-09 | Both paged reads re-keyed onto `id`; the two screens that swallowed the partner error now show it | `f8190bb` |
| **P7-30, P7-33** *(enforcement half)* | **Employee Register RLS audit + `list_company_member_presence`** — the presence read returns 1 row of 4 for a company manager, so every colleague would have rendered offline | migrations `20260811120000` + `20260811140000`, `a5c5ff0` + `08df975` |
| P7-42 *(partial)* | Badges verified against live data: 2 of 8 proven, 1 proven-silent, 3 unprovable on today's rows | `32660f3` |
| **P3-46 + P8-02** | **Withdrawn, not built** — the mine request path proven working end to end on live data; column semantics documented in-database; Dart renamed off the misleading name | migration `20260811160000`, this session |
| **P7-27/28/29/32/34/35, P5-15, P7-33 *(sidebar half)*** | **The shared Employee Register.** One screen for the console and all three org types at `/portal/{org}/register`; 13 direct table reads moved into `company/services/employee_register_service.dart`; presence switched onto `list_company_member_presence`; the hardcoded navy replaced by `MlSemantic`/`MlTone` with the console handing its own palette in; signature and dismissal-review surfaced | this session |

All three migrations are mirrored to files **and** the ledger timestamps were
repointed, per `supabase/MIGRATION_HYGIENE.txt`. Keep doing that.

---

## Traps — corrections to the audit that will otherwise waste your time

The audit was written by reading, not running. Three of its findings were wrong and
have been corrected in `To-Do's.md`, but read these before you act on anything:

1. **The transporter accept + allocate flow ALREADY EXISTS.** It is
   `showDispatchedRouteDetailSheet` + `_AssignTrucksDialog` in
   `lib/features/portal/widgets/dispatch_route_widgets.dart`, reached from the
   transporter dashboard's Available-routes section. It already filters to
   available trucks and caps ticks at `num_slots`. **Do not build
   `TransporterAcceptRouteScreen` or `AllocateFleetScreen`** — wire the existing
   `accept-route/:routeId` and `allocate-fleet/:routeId` routes to this sheet
   instead. `_AssignTrucksDialog` is private; make it public to reuse it.

2. **`accept_request_dispatch` already validated maintenance and the truck cap.**
   An earlier note said it didn't. It does — plus caller role, dispatch status,
   fleet ownership and double-booking. Only `is_active` was missing, now fixed.

3. **Seat serials are NOT missing.** `organization_seats` already has
   `serial_number` and `role_binding`; `generate_seat_serial(p_role)` already
   produces 15 chars with the last 3 identical per role type, exactly to spec.
   It is simply **never called** — `create_serial_token` mints seats with
   `generate_series`. 0 of 106 seats have a serial. The job is wiring, not
   building. Note `supervisorForeman` is missing from its CASE and falls to `GEN`.

**General lesson: verify audit claims against the live DB or the actual file before
building on them.** Two of the three above came from confident summaries that were
wrong.

---

## ✅ P3-46 is WITHDRAWN — read this before trusting the audit again

**There are 0 release blockers open.** P3-46 said a mine could not submit a
request at all. It can, and always could. Verified end to end on the live
database 2026-08-11 as Iron Hills Mining's owner, in a rolled-back transaction:
mine inserts a `transportation` request → inserts a mine-only `buyer` request →
reads both back through RLS → the row resolves to the **Mine/Supplier** admin
inbox by its requester's `org_type` → admin `sent_back` → mine `resubmitted`.
Six steps, all green. `transportation_requests` still holds its original 6 rows.

**The lesson is bigger than the item.** `buyer_company_id` is the **requester**
column — `not null` on every row, holding a mine's id just as readily as a
buyer's — and `is_company_staff()` tests employment, **never org type**. The
audit read an honest policy through a dishonest column name and produced a
blocker. The 6-of-6-buyers evidence was real and meant nothing: it is what a
platform looks like before any mine happens to have raised one.

Both halves are now documented where the confusion starts: `comment on column`
in migration `20260811160000`, and the Dart renamed to
`companyRequestsProvider` / `listForRequester`. **P8-02 was the same story** —
`showBuyersRequestDialog` is a complete type-3 form wired on three mine
surfaces; the `'Buyer requests are coming soon.'` stub does not exist in `lib/`.

⚠ **A near-miss worth carrying forward.** The obvious fix — widening
`transportation_requests_select` so a linked mine can read the order it is
fulfilling — was drafted and rejected. That row carries `price_per_ton`, `rate`
and `admin_notes`; the policy would have leaked the buyer's price and the
admin's margin to the mine, against CLAUDE.md §4. The linked mine already reads
its orders through `list_request_tracking()`, which returns facts rather than
the row. **Before widening any policy, read the row's full column list.**

**That is five plan items now corrected rather than built** (P8-10, P8-11,
P9-09, P7-31, and now P3-46 + P8-02). Verify before building: it has been right
more often than the plan has.

---

## Highest-value work remaining, in order

1. ~~`flutter analyze` clean~~ — done, and the test baseline with it.
2. ~~**P7 — the navigation rebuild**~~ — **structurally done.** All seven trees
   exist, every leaf carries a URL, the rail renders groups with flyouts and
   integer badges, search reaches nested leaves, and the router's role guard
   reads the same tree. What is still open under P7 and why:

   - ~~P7-05 — badge sources~~ — **done.** All eight read live queues, in
     `portal/nav/portal_nav_badges.dart`. What is *not* proven is whether each
     count is the right one: that is **P7-42**, a hand-count against the live
     queues, and it is now the cheapest high-value check left in P7.
   - **P7-20…P7-26 — the three dashboards.** Untouched. `PLAN.md` §4.4, band by
     band. Item 4 below.
   - **P7-27…P7-36 — the Employee Register.** P7-30 and P7-33's enforcement
     half are **done** (the RLS audit and its migration). What remains is the
     screen work — and it is smaller than the plan implies. Item 3 below.
   - **P7-37…P7-42 — the proof.** The nav matrix, the deep-link sweep in a real
     browser, back/forward, and badges reconciled against a hand-count. Nothing
     in this branch has been opened in a running app.
   - **P4-09's RLS half.** The router guard is defence in depth; a blocked route
     still leaves the RPC callable. Do not tick P4-09 until the rule holds in
     the database.
   - Five leaves are deliberately absent from the trees (Employee register,
     Disputes, buyer Orders, buyer Quality certs, and everything needing a live
     `:id`). The table under P7's §7.2 in `To-Do's.md` says which and why. **Add
     each leaf in the same change that lands its screen.**

   Where things live: `lib/features/portal/nav/portal_nav.dart` (trees + the
   guard), the rail in `portal_scaffold.dart`, the wiring in
   `portal_shell_layout.dart`, tests in `test/portal_nav_test.dart` and
   `test/widgets/portal_nav_rail_sweep_test.dart`.

   ⚠ `/home` is still routed and still renders the `LazyIndexedStack` over the
   old flat `PortalTabItem` list, because it is the post-login landing and
   redirecting it is an auth-flow change. It shows the org dashboard, so it and
   `/portal/{org}` are the same page under two addresses. `portal_navigation.dart`
   and the eight `tabs/screens/*` files stay alive until Phase 12 for that
   reason — **do not delete them to "finish" the nav.**

3. ~~**P7.5 — the shared Employee Register.**~~ **Done 2026-08-11.** Both
   audit corrections held: P7-31 was already implemented, and P7-28 really was
   12 slots rather than 116 edits. What the work turned up beyond the plan:

   - **The console top bar overflowed by 183 px at 430 px wide**, and had done
     since it was written — nothing had ever rendered that screen narrow,
     because it was console-only and the console is a desktop surface. One
     `Row` of eight children with a `Spacer` that cannot give back what the
     breadcrumb already took. Now two clusters that drop onto separate lines
     under 760 px. Found by the new sweep, not by reading.
   - **A layout sweep that does not assert on content proves nothing.** The
     first green run of `test/widgets/employee_register_sweep_test.dart` was
     entirely fake: `onlineUsersProvider` throws without an initialised
     Supabase, so every case rendered an error state and no case overflowed.
     The sweep now asserts `TOTAL STAFF` renders at every width × scale before
     it believes the absence of faults. Worth copying into any new sweep.
   - **`has_signature` is three states, not two.** Present / missing / *did not
     resolve*. Rendering the third as "missing" would be the same class of
     fabrication P7-30 was raised over, one field along.

   Still owed on this screen: it has **not been opened in a running browser**
   against a signed-in company manager (P7-37/P7-39), and P7-31's org-type KPI
   branches are verified by fixture, not against live rows.

   *(Original notes kept below — they are still the accurate description of the
   shape of the work.)*

   - **P7-31 (org-type-aware KPIs) is already implemented** in the original,
     at `company_employee_register_screen.dart:174` and `:245`. Verify it;
     do not build it.
   - **P7-28 (`_Pal`) is 12 slots, not 116 edits.** Make `_Pal` a
     `_Pal.of(context)` factory over `MlSemantic`/`MlTone` and add a local
     `final _p = _Pal.of(context);`. Every existing `_p.x` then resolves to
     the local unchanged. Only `_RoleSection._card` and `_MemberCard._chip`
     need context threaded.
   - **Switch the presence read to `list_company_member_presence`.** The
     direct `profiles` read cannot work for a company user — it returns their
     own row and nothing else, and the `catch (_) {}` around it turns that
     into "everyone offline" rather than an error.
   - The screen takes a whole `Company` object, not an id, so a portal entry
     point must resolve the row. And it queries 13 tables directly against
     CLAUDE.md §6 — add `company/services/employee_register_service.dart`
     as part of the move.
   - Route and nav leaf must land together: `test/portal_nav_test.dart`
     asserts every leaf resolves against the real route table.

   The super-admin
   version at `super_admin/screens/company_employee_register_screen.dart` is
   excellent and already real (live presence, driver→truck, KPIs computed from
   live rows). Promote it to `company/screens/employee_register_screen.dart`,
   delete its hardcoded `_Pal` palette in favour of `MlSemantic`/`MlTone`, make the
   KPIs org-type aware, and **audit RLS for every table it reads** before exposing
   it to company users.
4. **P7.4 — the three org dashboards.** Specified band by band in `PLAN.md` §4.4.
5. **P4.1 — extract the 5 screen classes living inside `app_router.dart`** (~430
   lines backing 15 routes, no screen files).
6. **P3.2/3.3 — the variance hole.** `trips` has no `delivered_tons` and no
   variance anywhere; `record_pod` skips the canonical `offloaded` status. This is
   the commercial heart of the reconciliation.

---

## Do NOT do without asking the client

- **Narrowing the `companies` RLS policy.** It is `USING (true)` — every
  authenticated user reads every company row, which is a real cross-tenant leak
  (P3-43). But partner resolution, chat contacts and company-name lookups all read
  that table. Map the read paths first. There is **no staging** — the one Supabase
  project is production, with 116 profiles and 41 trips on it.
- **Making `chat-attachments` private** (P3-52). It is public today, so existing
  chat file URLs are unauthenticated links. Flipping it breaks every historical
  attachment until they are served signed. Plan the migration.
- Any deletion (Phase 12).

---

## Two hard-won process notes

- **Never batch a ledger repoint with a transactional probe.** The
  `update supabase_migrations.schema_migrations …` for `20260811140000` was
  sent in the same call as a `begin; … rollback;` verification query, so the
  rollback discarded it. The stamp silently sat at `apply_migration`'s own
  timestamp while the file said otherwise — file and ledger disagreeing, which
  is the exact thing `MIGRATION_HYGIENE.txt` exists to prevent. Run the repoint
  on its own and re-select to confirm.
- **An authorization check in a `WHERE` clause is a silent denial.** It returns
  `[]`, which is indistinguishable from a true empty result and renders as
  fabricated truth one layer up. `list_company_member_presence` was written
  that way and corrected to `raise … errcode '42501'` in `08df975`. Worth
  applying the same eye to the other definer functions during P3-04's walk.

---

## Blockers only a human can clear

- **Leaked-password protection** — a Supabase dashboard toggle, last remaining
  security advisor item.
- **Android `applicationId` is `com.example.flutter_application_1`** and the release
  build **signs with the debug keystore**. Play rejects both, and the package name
  is permanent after first publish. Needs a real keystore.
- **A live ArcGIS token is bundled into every web and Windows artifact** via the
  `config/` asset declaration. Rotate it and de-bundle.
- **WhatsApp OTP silently falls back to a console logger returning HTTP 200** if any
  of four env vars is unset — users would never receive login codes and nothing
  would error. Verify on the live project.
