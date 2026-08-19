# Mine-Link — Consumer Release v1.0 Implementation Plan

**Repo:** `worktree-2026-05-05T11-53-29` (Dart package is `flutter_application_1` — **do not rename**)
**Supabase:** `yftazblpmicqtamyiwyb` (eu-west-1, PG 17.6) — **production; there is no staging**
**Targets:** Windows · Web · Android (iOS optional) — one codebase, one behaviour set
**Plan date:** 2026-08-10 · **Revision 2** (full second-pass audit)
**Companion:** `To-Do's.md` — the markable execution checklist

---

## 0. Evidence base

Revision 2 was written after **two full audit passes** over the real tree and the live database.

| Source | Coverage |
|---|---|
| `lib/` | 458 files enumerated. **All 126 routes in `app_router.dart` read line-by-line.** All 31 super-admin screens. All 34 portal screens. All 8 tab screens. 11 further feature modules (operations, company, employee, profile, profile_setup, notifications, chat, fleet, auth, tutorial, home). The whole shell/sidebar/token layer. |
| Spec docs | `CLAUDE.md` (77 KB, full), all `The_Mineral_Guide_*` overviews, `Mine_Supplier_&_Buyer_features.txt`, the Super Global Serial Admin setup guide (215 KB), `AUDIT_FINDINGS.md`, `docs/**` incl. design-system v0.1 and v2 specs |
| Supabase | 68 tables, 200+ RPCs, 4 edge functions, RLS coverage, realtime publication, security advisors, live row counts, live function bodies |
| Non-Dart | 153 migrations, 4 edge-function sources, all assets and fonts, 79 test files, Android/Web/Windows/iOS build configs, `config/` secrets |

Everything below is **[VERIFIED]** in code or in the live DB unless marked **[SPEC]** (a requirement from the project's own documents).

---

## 1. Executive summary

The app is in far better shape than a gap list implies. The portal screens are genuinely wired to Supabase through a strong RPC layer. **There is no fabricated business data in any portal** — no fake tonnages, no invented companies, no stubbed screens, no dead buttons in 11 of the feature modules.

Revision 1 identified five problem areas. Revision 2 found **six more**, three of which block a store release outright.

### The eleven things standing between this and release

1. **Two design systems.** Console and portals share zero visual components. Nine token classes, **four accent colours**, two UI fonts, four parallel card families in the portal alone.
2. **Eight fake "workspace" screens** under `lib/features/tabs/screens/` — the same widget showing the **employee roster** under operational titles. Two are unreferenced.
3. **Two silent truncations** in `logistics_service.dart` that corrupt ~15 screens across all three org types.
4. **The variance hole** — mine net tons and driver delivered tons live in different tables; the variance is computed **nowhere**. `record_pod` also skips the canonical `offloaded` status.
5. **Dead CTAs and label-vs-data lies** a customer hits in the first ten minutes.
6. 🆕 **~430 lines of UI live inside `app_router.dart`.** Five screen classes with no screen files back 15 routes. Six more routes parse a path parameter and **discard it** — `accept-route/:routeId`, `allocate-fleet/:routeId`, `fleet/:id`, `stockpiles/:id`, plus `buyer/orders` which is a byte-identical alias of `buyer/requests`.
7. 🆕 **55 of 64 `/portal/*` routes are unreachable** from any menu. The nav is a flat `List<PortalTabItem>` living at one URL (`/home`); the router's whole hierarchy was built as inbound deep-link aliases and never wired into the app's own navigation. **This is the root cause of the "nav menus have the wrong stuff in them" complaint.**
8. 🆕 **Four auth-guard holes**, one of them severe: an employee whose role has not been assigned yet is handed **the complete company-owner tab set** — Admin, Management, Controller, Security, Reconciliations, everything. `WaitingForRoleScreen` exists and is never instantiated. Also: `must_change_password` is ignored for employees; `/expired-access` is never navigated to by anything, so expired companies keep full access; and there is **no intra-org role guard**, so a security guard can deep-link straight into the weighbridge.
9. 🆕 **The dismissal notification chain is severed.** Four notification builders exist with **zero callers**; the three RPCs write no notifications; `/dismissal-management/:employeeId` is reachable **only** from notifications that are never created. Dismiss someone → they are never told → they cannot appeal → nobody can resolve it.
10. 🆕 **Security and Load Controller cannot reach the Operations screen** they are the only roles authorised to write to. That is precisely why `security_incidents` and `gate_checks` are empty.
11. 🆕 **Three hard release blockers**: Android ships as `com.example.flutter_application_1` **signed with the debug keystore** (Play rejects both; the package name is permanent after first publish), and a **live ArcGIS token is bundled into every web and Windows artifact** through the `config/` asset declaration.

Plus a silent-failure risk worth closing: the **WhatsApp OTP sender falls back to a console logger returning HTTP 200** if any of four env vars is unset — users would simply never receive login codes, with no error anywhere.

---

## 2. Domain model

### 2.1 Org types and roles **[VERIFIED — `lib/features/auth/models/user_type.dart`]**

```
Platform ── Super Global Serial Admin   (company_id, org_type, role all null)
Organization ── mineSupplier · buyer · transporter
Company      ── one org type · one serial token · one seat limit
Employee     ── security · controllerWB ("Load Controller") · supervisorForeman
                · driver · admin · management
```

| Org type | Roles in code |
|---|---|
| `mineSupplier` | security, controllerWB, supervisorForeman, admin, management |
| `buyer` | admin, management |
| `transporter` | driver, admin, management |

**Live DB [VERIFIED]:** 88 employees — 29 admin, 26 management, 12 security, 11 controllerWB, 11 driver, **0 supervisorForeman**, 1 null-role sitting inactive. The supervisor role has never been exercised with a real user. The null-role employee is currently seeing the full owner console (§1.8).

**Settled conflicts** — older docs disagree; these are the rulings:

| Question | Ruling | Source |
|---|---|---|
| Child super admin? | **No.** Both super admins are equal, full-rights. | `CLAUDE.md`, 2026-07-12 |
| Self-signup? | **Removed.** All accounts admin-provisioned. | `README.md`, audit F-004 |
| Marketplace / proforma / 15% VAT flow? | **Out of scope for v1.0.** | not in built state |
| Buyer-side weighbridge + security roles? | **Drop for v1.0** — driver's offload entry already captures receiving weight. Needs client sign-off. | spec conflict |
| Default theme | **Dark**, user-toggleable | `CLAUDE.md` §5 |
| Product name | **MineLink** only | `CLAUDE.md` |

⚠ The `create_serial_token` RPC **still gates on `superGlobalSerialAdminMainChild` and `child_can_generate_tokens`** even though the child-admin concept was abolished in the app. So does `super-admin-create-company`. Clean both.

### 2.2 Canonical trip lifecycle **[SPEC — do not invent statuses]**

```
scheduled → en_route_to_load → arrived_at_mine → loading → loaded
          → left_mine → en_route_to_offload → offloaded → completed   (+ cancelled)
```

The app can currently only ever produce **eight of the nine** — `record_pod` jumps `loaded → completed`.

### 2.3 Request state machine **[SPEC — its own enum, never `TripStatus`]**

```
requested → sent_back ⇄ resubmitted → approved → linked
```

**Live [VERIFIED]:** 6 requests (5 `linked`, 1 `requested`) · 5 dispatches (3 `dispatched`, 2 `accepted`) · 41 trips (37 `completed`, 1 each `loading` / `arrived_at_mine` / `en_route_to_offload` / `cancelled`). The pipeline demonstrably runs; the edges are unfinished.

### 2.4 The four request types **[SPEC — separate entities, never one table with a type flag]**

1. **Request Transporter/Routes** — mine or buyer. Trucks required, `Ongoing | Single`, start locked to today+2, notes.
2. **Request Product** — buyer only. Product spec, tons (`t` suffix), payment terms, price/ton.
3. **Request Buyer** — mine only. Tons available, spec, multi-PDF lab results, image, price/ton, `FOB | FOT`, OSM location saved as `https://www.google.com/maps?q={lat},{lng}`.
4. **Seat / token requests** — company → super admin.

---

## 3. The end-to-end workflow this release must deliver

The single acceptance narrative. Every phase exists to make one step real.

| # | Actor | Action | System must do |
|---|---|---|---|
| 1 | Super Admin | Register company | edge fn → auth user + `profiles.user_type='company'` + `must_change_password` + `companies` row + **permanent reg-ref `ABC001`** + audit |
| 2 | Super Admin | Generate serial token | hashed token, raw shown **once**, seats minted, org `active`, live countdown starts |
| 3 | Company owner | First sign-in | forced `/mandatory-password-change` → portal |
| 4 | Company/Admin/Mgmt | Create or approve employees | seat gate blocks at limit → "Request Extra Seats" |
| 5 | Mine or Buyer | Submit request (types 1–3) | row in `transportation_requests`, status `requested`, platform notified |
| 6 | Super Admin | Review in one of **four** inboxes | clean, **non-editable** render; approve or send back with note (loop) |
| 7 | Super Admin | Link & price | Route ID `RT-…` minted; **margin in R**; `margin_ledger` admin-only; transporter sees only their R/ton |
| 8 | Super Admin | Due-diligence gate | Preview → "Are you sure…correct?" → green tick "Due diligence done correctly, accurately and accepted" → "100% sure?" → transporter list → "Send to [name]?" |
| 9 | *system* | `link_and_dispatch_request` | request → `linked`; **capped order stockpile** minted; `scheduled` trip created; **3 notifications** |
| 10 | Transporter Admin | Accept + allocate | only **Available** trucks, capped at trucks-required, in-maintenance rejected server-side; drivers assigned (2/truck, 5 via approval) |
| 11 | *system* | Allocation effects | trucks/drivers → On Route; buyer sees allocated trucks; driver deep-linked to "My routes" |
| 12 | Mine Supervisor | Fill the pile | `stockpile_add_tons` cap-enforced + ledger row; **every +30 t = one trailer → "ready to collect" alert** |
| 13 | Driver | Start route | `→ en_route_to_load`; GPS at 30 s |
| 14 | Mine Security | Mark Arrived | `→ arrived_at_mine`; `gate_checks` row; **Load Controller notified** |
| 15 | Load Controller | Weigh & waybill | Tare then Gross (**photo + manual**); 4 seal serials + photos; **Net = Gross − Tare computed, never typed**; recon row + load + seal + **stockpile decrement** + waybill; Security notified |
| 16 | Mine Security | Mark Left Site | `left_mine → en_route_to_offload` **atomically** |
| 17 | Driver | Offload | POD photo + delivered tons → **`offloaded`**; signature + timestamp into the waybill RECEIVED block |
| 18 | *system* | Close | `→ completed`; **variance = mine net − driver delivered, stored and surfaced** |
| 19 | Mine | Quality cert | one `load_quality_certs` per load against the route spec |
| 20 | Buyer | Money close-out | loaded/delivered/**payable** Rand; `payable = delivered × (1 − excess moisture/100)`; invoice capture; **variance = invoiced − payable**. Buyer-private |
| 21 | Any party | Dispute | raise → comment → super admin resolves |
| 22 | *system* | Stockpile → 0 | `stockpile_depleted_at` stamped, mine notified, transaction closes |

---

## 4. 🆕 Navigation architecture — the structural rebuild

This is the section that answers *"each org type's screens and sidebar nav menus must have the correct stuff in them and all the unused and old nonsense removed."*

### 4.1 Why the nav is wrong today **[VERIFIED]**

`portal_navigation.dart` is **not a sidebar-to-route map**. It is a `List<PortalTabItem>` of pre-constructed widgets consumed by `LazyIndexedStack` inside `HomeTabBodyScreen`. Consequences:

- **The entire tab surface lives at one URL: `/home`.** No tab has its own address.
- `portal_shell_layout.dart:63-95` (`_portalAliasTabLabel`) exists purely to *reverse-map* a `/portal/{org}/x` deep link back onto a tab index for sidebar highlighting.
- The router's 64 `/portal/*` routes were built as inbound deep-link aliases for an external system. **55 of them are unreachable from the app.** Only `{org}/employees`, `{org}/employees/:id`, `{org}/notifications` and `/portal/driver/navigate/:tripId` have real inbound links.
- The nav is **flat** — no sections, no groups, no dropdowns, no flyouts when collapsed. Badges are a boolean 8 px dot with no counts.
- Because it's flat, the search box can only filter top-level labels; it cannot find nested destinations.
- The list ends with three employee-roster tabs on every org type (`Admin`, `Management`, `Workspace`/`Mine-Supplier`), which is the "old nonsense" the client sees.

Meanwhile the **console sidebar already does all of this properly** — `MlNavItem` trees, `_NavGroup` expandable sections, `_CollapsedNavGroup` overlay flyouts, `_NavBadge` live integer counts, live text search across the whole tree, five rail skins.

### 4.2 The rebuild

**One nav model, one rail, three trees.** Extract the console sidebar into `lib/core/design/sidebar/`, then build `lib/features/portal/nav/portal_nav.dart` producing a **sectioned `List<MlNavItem>` per (orgType, role)**, where every leaf carries a real route. `/home` stops being the universal container; each destination gets its own URL, which also fixes deep-linking, browser back/forward on web, and the 55 orphan routes in one move.

Rules for every tree:
- **Sections are dropdown groups.** Expandable when the rail is expanded; overlay flyout when collapsed. Auto-open by route prefix.
- **Every group header carries the sum of its children's badges.** Badges are integers, never dots.
- **Nothing appears that the role cannot use.** The sidebar and the router guard must agree (today they don't — §5.3).
- **No org type sees a tab named after its own org type.**

### 4.3 The target trees

#### Mine / Supplier — company, admin, management

```
Dashboard                                    → /portal/mine
Operations  ▾
  Supervisor & stockpiles                    → /portal/mine/stockpiles
  Production                                 → /portal/mine/production
  Quality                                    → /portal/mine/quality
  Security gate                    [badge]   → /portal/mine/security
  Load controller                  [badge]   → /portal/mine/weighbridge
  Operations hub                             → /portal/mine/operations
Logistics  ▾
  Requests                         [badge]   → /portal/mine/requests
  Buyers                                     → /portal/mine/buyers
  Trips                                      → /portal/mine/trips
  Live map                                   → /portal/mine/live-map
  Truck locations                            → /portal/mine/truck-locations
  Mine locations                             → /portal/mine/locations
Reconciliation  ▾
  Reconciliations                            → /portal/mine/reconciliations
  Recon tables (tons out)                    → /portal/mine/tons-out
  Disputes                         [badge]   → /portal/mine/disputes
Company  ▾
  Employee register                          → /portal/mine/register        🆕
  Employees                                  → /portal/mine/employees
  Compliance                       [badge]   → /portal/mine/compliance
  Announcements                              → /portal/mine/announcements   🆕
  Company profile                            → /portal/mine/company
Settings  ▾
  My profile · Account & security · Appearance · Notifications [badge]
```

**Mine — supervisorForeman:** Dashboard · Supervisor & stockpiles · Production · **Truck locations** 🆕 · **Reconciliations (read-only)** 🆕 · Compliance · Profile
**Mine — controllerWB:** Load controller · **My loads history** 🆕 · **Operations hub → weighbridge** 🆕 · Compliance · Profile
**Mine — security:** Security gate · **Operations hub → incidents & gate checks** 🆕 · Compliance · Profile *(otherwise locked, mobile-first)*

#### Buyer — company, admin, management

```
Dashboard                                    → /portal/buyer
Procurement  ▾
  Requests                         [badge]   → /portal/buyer/requests
  Orders                                     → /portal/buyer/orders          🆕 (real screen)
  Routes & mines                             → /portal/buyer/routes
Deliveries  ▾
  Waybills · Loads & value · Quality certs 🆕 · Trips · Live map · Truck locations
Reconciliation  ▾
  Reconciliations · Recon tables · Disputes [badge]
Company  ▾
  Employee register 🆕 · Employees · Compliance [badge] · Announcements 🆕 · Company profile
Settings  ▾
  My profile · Account & security · Appearance · Notifications [badge]
```

#### Transporter — company, admin, management

```
Dashboard                                    → /portal/transporter
Operations  ▾
  Routes & dispatches              [badge]   → /portal/transporter/routes
  Accept route                     [badge]   → /portal/transporter/accept-route/:id  🆕
  Allocate fleet                             → /portal/transporter/allocate-fleet/:id 🆕
  Trucks on route                            → /portal/transporter/trucks-on-route
  Trips                                      → /portal/transporter/trips
Fleet  ▾
  Vehicles · Vehicle detail 🆕 · Drivers · Maintenance [badge] · Compliance [badge]
Money  ▾
  Earnings · Fuel & costs
Tracking  ▾
  Live map · Truck locations *(positions merged in)* · Request tracking
Reconciliation  ▾
  Reconciliations · Recon tables · Disputes [badge]
Company  ▾
  Employee register 🆕 · Employees · Announcements 🆕 · Company profile
Settings  ▾
  My profile · Account & security · Appearance · Notifications [badge]
```

**Transporter — driver:** Dashboard · My routes · Navigation · **Drop-off** 🆕 · Live map · Compliance · Profile

### 4.4 🆕 Per-org-type dashboards

All three dashboards share the same shape today — title, subtitle, a copy-pasted `_wrap` helper (3 duplicates), a 4-up stat row, a 3/4-up feature row. No section headers, no meta lines, no period selector, no filters, no export. The mine additionally has **two entirely different dashboards** selected by a user setting (`PremiumMineDashboard`, 1596 lines), neither of which matches the console.

**Every org dashboard is rebuilt on the console's dashboard structure** — `SaSectionHeader` + meta + `"View →"`, `SaStatTile` with left accent strip and delta badge, `SaOrgTypeCard`, `MlGrid`, real charts from `ml_charts.dart`, period selector, export affordance:

| Band | Mine / Supplier | Buyer | Transporter |
|---|---|---|---|
| **KPI row** (real, with 7-day deltas) | Tons out today · Stockpile balance / cap · Trucks inbound · Loads awaiting weigh | Tons delivered · Payable R · Open orders · Trucks inbound | Tons moved · Net earnings R · Trucks on route · Fleet utilisation % |
| **Trend** | `MlFlagshipTrend` tons-out vs target | delivered vs payable | tons + earnings dual series |
| **Ring** | `MlDonut` stockpile fill | order fill per route | fleet on-route / available / maintenance |
| **Action queue** | arrivals to check in · loads to weigh · requests awaiting resubmit · disputes | requests awaiting resubmit · invoices to capture · disputes | dispatches to accept · trucks to allocate · maintenance due · disputes |
| **Live strip** | trucks currently on site | trucks inbound with ETA | trucks on route with ETA |
| **Recent** | last 10 waybills (`MlDataTable`) | last 10 deliveries | last 10 completed trips |

Every tile deep-links to the screen that services it. Nothing decorative, nothing random, no "Coming soon" pill.

### 4.5 🆕 Employee Register — per company, every org type

The super admin already has a genuinely excellent per-company **Employee Register** at `lib/features/super_admin/screens/company_employee_register_screen.dart`. **[VERIFIED]** it provides:

- Employees grouped by **role**, loaded from `employees` ordered by `created_at`
- **Live presence** per person — online / away / offline, from the chat presence set plus `profiles.last_seen_at` with a 30-minute away window
- **Driver → truck** resolution via `driver_assignments` → `fleet_vehicles.vehicle_registration_number`
- **Role-group KPIs computed from live rows, never invented** — supervisors: stockpiles touched today from `stockpile_transactions`; load controllers: loads recorded vs arrivals from `trips.loaded_at`; drivers: PODs uploaded vs trips. `pct` is `null` when there is nothing to count and renders as a muted dash
- **Compliance documents** per employee
- Tap-through to the full `EmployeeProfileScreen`

Today it is **super-admin-only**, reachable only from the company mirror screen, and it hardcodes a fixed dark `_Pal` palette because the console chrome is permanently dark navy.

**The work:** promote it to a shared, theme-aware screen every company can open for itself.

1. Move to `lib/features/company/screens/employee_register_screen.dart`.
2. **Delete `_Pal`**; render through `MlSemantic` / `MlTone` so it works in the portal's light and dark themes and inherits the unified design system.
3. Parameterise the company id: super admin passes any company; a portal user gets their own, resolved through `resolvePortalCompanyId`.
4. **RLS check:** every query it runs (`employees`, `profiles.last_seen_at`, `driver_assignments`, `fleet_vehicles`, `stockpile_transactions`, `trips`, `compliance_documents`) must be readable by a company owner / admin / management **for their own company only**. Where a policy is missing, add it in the same migration — do not widen anything.
5. Make the role-group KPIs **org-type aware**: mine shows supervisor / load-controller / security metrics; transporter shows driver POD and on-route metrics; buyer shows admin / management activity.
6. Route it per org type (`/portal/{org}/register`) and put it under **Company ▾** in all three nav trees.
7. Visible to **company, admin and management only** — enforced in RLS, not just the sidebar.

---

## 5. 🆕 Routing, guards and the missing screens

### 5.1 UI living inside the router **[VERIFIED — ~430 lines]**

Five screen classes are defined inside `app_router.dart` itself, backing 15 routes with **no screen files**:

| Inline class | Lines | Routes | Problem |
|---|---|---|---|
| `_PortalOwnCompanyScreen` | 1170-1183 | `/portal/{mine,buyer,transporter}/company` | bare `Center(Text('Company not loaded.'))` fallback |
| `_PortalTonsOutScreen` (+ provider 1186-1199) | 1201-1251 | `{org}/tons-out` ×3 + `mine/tons-out/:transporterId` | same bare fallback |
| `_PortalTripsScreen` + `_PortalTripRow` | 1272-1408 | `{org}/trips` ×3 | real data, no screen file |
| `_PortalTripDetailScreen` | 1410-1566 | `{org}/trips/:id` ×3 | no screen file |
| `_PortalTripWaybillRoute` | 1568-1594 | `.../trips/:id/waybill` ×4 | pops a modal in `addPostFrameCallback` |

All five must be extracted into `lib/features/portal/screens/`, restyled onto the unified design system, and given a real `MlEmptyState` instead of `Center(Text('Company not loaded.'))` (which appears at lines 1177, 1234, 1281 and 1417 with no retry).

### 5.2 Routes that discard their path parameter **[VERIFIED]**

| Route | Line | Reality | Required |
|---|---|---|---|
| `/portal/transporter/accept-route/:routeId` | 871 | `const TransporterPortalDashboardScreen()` — id dropped | **Build `TransporterAcceptRouteScreen`** — workflow step 10 |
| `/portal/transporter/allocate-fleet/:routeId` | 883 | `const FleetManagementScreen()` — id dropped | **Build `AllocateFleetScreen`** — Available-trucks-only, capped at trucks-required, driver assignment |
| `/portal/transporter/fleet/:id` | 834 | `const FleetManagementScreen()` — id dropped | **Build `FleetVehicleDetailScreen`** — trips, maintenance, fuel, compliance, drivers |
| `/portal/mine/stockpiles/:id` | 617 | `const StockpileDetailScreen()` — id dropped | Pass the id |
| `/portal/buyer/orders` | 731 | byte-identical to `/portal/buyer/requests` | **Build `BuyerOrdersScreen`** — linked orders with fill %, allocated trucks, ETA |
| `/portal/buyer/transactions` | 735 | the **mine's** Operations Hub reused for a buyer | Give buyers a transactions view, or drop the route |
| `/communications` | 461 | `MessagesScreen` — same as `/messages` | Should be `CommunicationsHubScreen` (§5.4) |

Steps 10 and 11 of the workflow — the transporter accepting a dispatch and allocating trucks — **have no screens at all.** They are the largest functional hole in the release.

### 5.3 Auth-guard holes **[VERIFIED — `app_router.dart:228-370`]**

| # | Hole | Impact |
|---|---|---|
| **G1** | **No-role employee gets the full owner tab set.** `portal_tabs_resolver.dart:20-25` returns `PortalNavigation.companyTabs(orgType)` when the role is null. `WaitingForRoleScreen` exists and is **never instantiated**. | **Severe — privilege escalation by omission.** One live employee is in this state now. |
| **G2** | **No intra-org role guard.** Once `org_type` matches, any employee can open any `/portal/{org}/*` route. A security guard whose sidebar is two tabs can deep-link `/portal/mine/weighbridge`, `/tons-out`, `/reconciliations`, `/employees`. | **Severe.** Router and sidebar disagree about the role model. |
| **G3** | **`must_change_password` ignored for employees.** Lines 265, 276, 286 all require `user_type == 'company'`. | Admin-created employees — the majority — never forced to change their temp password. |
| **G4** | **Expired access never enforced.** `/expired-access` requires `state.extra` and **nothing in the app ever navigates to it**. `PortalWorkspacePhase` has no `expired` case. | An expired company keeps full operational access. |
| **G5** | Dismissed employee caught only by the shell. `/portal/driver/navigate/:tripId` sits **outside** the ShellRoute. | A dismissed driver can still deep-link into live navigation. |
| **G6** | Incomplete profile never gated. | Users can skip `/account-setup` indefinitely. |
| **G7** | `_portalGateFieldsLoaded` is a one-shot static. | Promotion, transfer or dismissal mid-session is not picked up until sign-out. |
| **G8** | Profile-gate failure **fails open to non-admin** and retries on every navigation. | A super admin with a transient fetch failure is silently bounced to `/home`. |
| **G9** | `/chat/:chatRoomId` returns `HomeTabBodyScreen` when `state.extra == null`. | Every web refresh and every real deep link shows home under a chat URL. |

### 5.4 Orphaned screens **[VERIFIED — built, working, unreachable]**

| Screen | Verdict |
|---|---|
| `chat/screens/communications_hub_screen.dart` (920 lines) | Company **announcements** + room creation. Never instantiated. `/communications` renders `MessagesScreen` instead. The whole announcements feature is unreachable. **Route it.** |
| `employee/screens/waiting_for_role_screen.dart` (279) | The fix for G1. Never instantiated. **Route it.** |
| `employee/widgets/employee_status_timeline.dart` | Only consumer is the orphan above. |
| `portal/screens/drop_off_screen.dart` | Routed, working, no nav entry. **Add nav entry.** |
| `portal/screens/mine_locations_screen.dart` (405) | Routed, no nav entry — and it is a hard dependency of driver-navigation destination resolution. **Add nav entry.** |
| `super_admin/screens/super_admin_dashboard_v2_screen.dart` | Routed, zero inbound links — and it is **strictly better than the live dashboard**, with a real `_spark()` computed from weighbridge rows. **Promote or delete.** |
| `company/screens/company_list_screen.dart`, `employee/screens/employee_grid_screen.dart` | Routed, zero inbound links, and both use the **parallel legacy `core/mcp/` data layer** — a second source of truth. **Delete with the layer.** |
| `demo/screens/components_demo_screen.dart`, `fleet/screens/fleet_document_debug_screen.dart` | Debug/gallery leftovers. **Delete.** |
| `tabs/screens/controller_tab_screen.dart`, `security_tab_screen.dart` | Never referenced — and they hold the **only** links to `/operations?tab=security` and `?tab=weighbridge` (§5.5). |
| `notifications/widgets/{universal_notification_button,role_notification_button,notification_icon}.dart` | Orphans. **Delete.** |
| `notifications/utils/update_notification_schema.dart` | No-op stub, zero callers. **Delete.** |

### 5.5 🆕 The Operations Hub is real — the roles just can't reach it **[VERIFIED]**

`operations_hub_screen.dart` (1745 lines) is **fully real**: six tabs — Minerals, Transactions, Weighbridge, Mineral Loads, Security Incidents, Gate Checks — each with a working create/edit dialog writing to the correct live table, plus realtime subscriptions. The "placeholder operations tabs" claim in the older docs is **out of date**.

The problem is access:
- `OperationsAccessPolicy.canCreate` authorises **`controllerWB`** for weighbridge records and **`security`** for incidents and gate checks.
- Those two roles' sidebars are exactly `[SecurityCheckinScreen, Profile]` and `[LoadControllerScreen, Profile]`.
- The only links to `/operations?tab=security` and `/operations?tab=weighbridge` live in `SecurityTabScreen` and `ControllerTabScreen` — **both orphaned**.

**That is the whole explanation for `security_incidents = 0` and `gate_checks = 1`.** Fix: put an Operations Hub entry, scoped to the tab that role owns, in the security and controller nav trees.

Second defect: `OperationsAccessPolicy.visibleTabs(canEditAll: true)` returns **all six tabs ignoring `orgType`**, so a Buyer company sees Weighbridge, Gate Checks and Security Incidents — mine concepts. `OperationsScope.orgType` is carried and never used.

### 5.6 🆕 The dismissal chain is severed **[VERIFIED]**

- `NotificationService.createDismissalInitiatedNotification` (L429), `createManagementDismissalNotification` (L455), `createDismissalAppealNotification` (L519), `createDismissalFinalDecisionNotification` (L579) — **zero callers anywhere.**
- The RPCs `initiate_employee_dismissal`, `submit_employee_dismissal_appeal`, `resolve_employee_dismissal` **write no notifications**, and no trigger does either.
- Live `notifications` contains **0 rows** of those three types.
- `/dismissal-management/:employeeId` is reachable **only** from those notification types.
- `company_employees_screen.dart:865` lists dismissed employees and **never links to the resolution screen**.

Net: dismiss someone → they are never told → they cannot appeal → nobody can resolve it. Two small changes fix it: call the four existing builders, and add a "Review dismissal" button on the dismissed-employee card.

### 5.7 Complete missing-screen register

| # | Screen | Why | Priority |
|---|---|---|---|
| 1 | `TransporterAcceptRouteScreen` | Workflow step 10; route exists, param discarded | 🔴 |
| 2 | `AllocateFleetScreen` | Workflow step 10; Available-trucks-only + driver assignment | 🔴 |
| 3 | `EmployeeRegisterScreen` (per org type) | Client requirement §4.5 | 🔴 |
| 4 | `PortalTripsScreen` | Extract from router | 🔴 |
| 5 | `PortalTripDetailScreen` | Extract from router | 🔴 |
| 6 | `PortalTonsOutScreen` | Extract from router | 🔴 |
| 7 | `PortalOwnCompanyScreen` | Extract from router | 🔴 |
| 8 | `PortalTripWaybillRoute` | Extract from router | 🟠 |
| 9 | `FleetVehicleDetailScreen` | Route exists, param discarded | 🟠 |
| 10 | `BuyerOrdersScreen` | Route is an alias of requests | 🟠 |
| 11 | `RouteDetailScreen` (buyer) | Every route card opens the global map | 🟠 |
| 12 | `MineLoadHistoryScreen` (controllerWB) | Controller can't see their own loads | 🟠 |
| 13 | Announcements entry (route the comms hub) | 920 built lines, unreachable | 🟠 |
| 14 | Seat serial management (super admin) | Spec item, **nothing exists** | 🟠 |
| 15 | Seat reassignment governance | Spec item, **nothing exists** | 🟠 |
| 16 | Dismissal review queue | Only entry is a notification never created | 🟠 |
| 17 | Group-chat creation UI | `createOrgGroup` exists, never called | 🟡 |
| 18 | `MessagesScreen` mobile layout | Hardcoded 340 px sidebar + `Row`, no `LayoutBuilder` | 🟡 |
| 19 | Locations for admin/management employees | Section is company-account-only | 🟡 |
| 20 | Quality certs tab (buyer nav) | Table + RPCs exist, no nav entry | 🟡 |
| 21 | Company reg-ref display | **Column does not exist** | 🟡 |

---

## 6. Design system

### 6.1 The problem **[VERIFIED by grep — zero cross-imports of widgets]**

`super_admin/**` imports only providers, models and services from `portal/**`. No portal file imports anything visual from `super_admin/`.

**Nine token/palette classes:** `MlTokens`/`MlSemantic`/`MlTone` (shared) · `_Sb` (private, console rail, 20 slots) · `MlGlass` · `MlOv`/`OvTone` · `MlSidebarTokens` · `PortalColors` · `MinePremiumPalette` · plus the hardcoded `_Pal` inside the Employee Register.

**Four accents:** `#2563EB` · `#6AB8FF` · `#22D3EE` · `#00B5D8` (the brand cyan).
**Two UI sans:** `Sora` (console) vs `PlusJakartaSans` (portal). ✅ **`Sora` is genuinely declared in `pubspec.yaml` with all 5 weights, and all 5 TTFs exist on disk.** The console typography is intentional — **the portal adopts Sora.**

**Four parallel card families in the portal:** `portal/widgets/ml/` (66 `MlCard` sites — the good one) · `portal_widgets.dart` (`PortalStatCard`/`PortalFeatureCard`, **zero call sites**, yet imported by 30 files for `PortalScrollBody`) · `premium_overview_widgets.dart` (16 `OverviewHeroTile` sites) · `premium_mine_dashboard.dart` (1596 lines, mine-only, selected by a user setting).

**Duplicated primitives:** the 44×3 accent rule (2×) · the 850 ms count-up (2×) · the icon well (3×) · the `_wrap` grid helper (3×) · `_SectionHeader` (2×) · the sparkline painter (**3×**).

### 6.2 Direction

**The console is the reference.** Two exceptions where the portal is ahead and the console adopts *it*: `MlDataTable` + `MlColumn` (13 sites; the console hand-rolls tables) and `MlButton`'s 7-kind system with the **green "go" / orange "leave"** gradients the spec mandates.

### 6.3 Target structure

```
lib/core/design/
  tokens/    ml_tokens.dart · ml_surface_tokens.dart (MlGlass, minus MlSampleData)
             ml_overview_tokens.dart (MlOv, verbatim) · ml_rail_tokens.dart (_Sb → public)
             ui_prefs.dart (ConsolePrefs → app-wide UiPrefs)
  shell/     workspace_shell.dart · workspace_canvas.dart · top_bar/
  sidebar/   the whole console sidebar, minus MlNav
  components/ ml_card · ml_stat · ml_section_head · ml_pill · ml_well · ml_meter
              ml_data_table (promoted from portal) · ml_buttons · ml_empty_state · layout/
  charts/    ml_charts.dart (6 painters, no fl_chart)
  motion.dart  mlScreenMotion · mlReducedMotion = 1ms (never Duration.zero)
```

Nav trees stay in features: `super_admin/nav/console_nav.dart` and the new `portal/nav/portal_nav.dart`.

### 6.4 Non-negotiable rules **[SPEC — `CLAUDE.md` §5]**

Tokens are law — no raw `Color(0x…)` or `Colors.*` in feature code · `MlSemantic.of(context)` for light/dark, never manual brightness branching · PlusJakartaSans→**Sora** UI, **JetBrainsMono with `tabularFigures()` for every code, plate, ticket and tonnage**, Fraunces display · status pills and table headers **UPPERCASE** · radii 8/12/16/20/24/999 · motion 260/180/850/180-220/280 ms, **no infinite decorative animation, no glassmorphism** · sidebar 274/78, app bar 72, content 1280, padding 28 · **no emoji** · tonnage `33.2 t`, currency **R (ZAR)** only, times 24h mono · every screen survives text scale 0.85–1.3 and bold text.

---

## 7. Data-layer correctness

### 7.1 `logistics_service.dart` — two silent truncations **[VERIFIED]**

**A.** `vehicle_positions` is queried **globally with no company or vehicle filter** — `.order('recorded_at', desc).limit(500)`, deduped client-side. Past 500 platform-wide pings a company's trucks vanish and **the map shows empty while trucks are actively reporting**. Correctness also depends 100% on RLS. Backs five screens plus all three dashboards. Fix: route through the existing scoped `list_live_trip_positions(p_company_id)`.

**B.** `listPartnerCompanies` caps at `.limit(200)` transactions — while the same file paginates transactions and trips exhaustively *with an explicit comment saying a cap would silently undercount*. Truncates the buyer's linked mines, the mine's buyers, and buyer-name resolution in `tonsOutEntriesFromWaybills`. Also swallows every error with `catch (_) { return const []; }`.

### 7.2 The variance hole **[VERIFIED — the most important backend gap]**

**[SPEC]** *"Store both plus the computed variance — never overwrite one with the other."*

- `trips.net_tons` — the mine's authoritative net ✅
- `pod_uploads.delivered_tons` — the driver's offload figure ✅
- **No `delivered_tons` on `trips`. No variance column or view anywhere.** The lost/stolen/swapped-mass signal — the entire commercial reason reconciliation exists — is not computed.

### 7.3 `record_pod` **[VERIFIED from the live function body]**

Sets `status = 'completed'` directly, **never writing `offloaded`**. Also permits **supplier** staff to upload POD while raising *"Only the transporter/driver may upload proof of delivery"* — the check and the message disagree.

### 7.4 Non-atomic gate check-out **[VERIFIED]**

`security_checkin_screen._markGone` issues two sequential `setTripStatus` RPCs. A failure between them strands the trip in `left_mine` with no way forward.

---

## 8. Supabase backend

### 8.1 Solid **[VERIFIED]**

68 tables, **RLS enabled and policied on every one** · 200+ RPCs covering the whole lifecycle · realtime on 41 tables · 7 scheduled jobs · 4 edge functions, all 1:1 with source, and the old public admin backdoor properly decommissioned (returns HTTP 410).

### 8.2 Security findings **[VERIFIED via advisors]**

| Finding | Count | Severity |
|---|---|---|
| `SECURITY DEFINER` functions executable by **`anon`** | **27** | **High — fix before release** |
| Executable by `authenticated` without grant review | 173 | Medium — audit once |
| `trip_is_on_time` mutable `search_path` | 1 | Low |
| Leaked-password protection disabled | 1 | Medium — one toggle |

The 27 include `update_my_company_profile`, `update_my_employee_profile`, `upsert_compliance_document`, `delete_compliance_document`, `log_fuel_entry`, `delete_fuel_entry`, `raise_recon_dispute`, `set_recon_dispute_status`, `list_transporter_trip_pnl` — real damage surface.

### 8.3 Tables backing UI that have never held a row **[VERIFIED]**

`weighbridge_records`(1) · `mineral_loads`(0) · `security_incidents`(0) · `gate_checks`(1) · `mine_locations`(0) · `trip_waypoints`(0) · `security_confirmations`(0) · `mine_hazards`(0) · `mine_road_requests`(0) · `recon_disputes`(0) · `compliance_documents`(0) · `fuel_entries`(0) · `vehicle_operating_costs`(0) · `load_quality_certs`(0) · `load_invoices`(0) · `production_entries`(0) · `route_assignments`(0) · `stockpile_docs`(0) · `reconciliation_uploads`(0) · `driver_limit_requests`(0) · `token_requests`(0) · `chat_message_reads`(0) · `broadcast_messages`(0) · `seat_reassignment_log`(0)

Each needs a **verdict**: proven with a real write, or hidden from the UI for v1.0. Several are empty purely because of §5.5 (roles can't reach the screen) and §5.4 (screen is orphaned) — those become provable once the nav is fixed.

### 8.4 Migrations **[VERIFIED]**

**153 files**, `YYYYMMDDHHMMSS_snake_case.sql`, spanning 20250504 → 20260810.

- **6 duplicate timestamp prefixes** — ordering undefined on `supabase db push`: `20250505000000` ×2 · `20250507000000` ×3 · `20250507000003` ×2 · `20250511000000` ×2 · `20260714000000` ×2 · `20260727120000` ×2.
- **Demo seed still in the chain** against a stated no-mock-data requirement: `20260511160000_portal_logistics_demo_seed.sql`, `20260726090300_showcase_data.sql`, and `supabase/seed.sql` with `[db.seed] enabled = true`.
- A **stray unmanaged `migrations/` folder at repo root** with 4 loose SQL files outside the Supabase chain.
- Rules **[SPEC]**: files are the source of truth · one file per applied migration, never fold a fix into an earlier file · repoint `apply_migration`'s timestamp · mirror to a file in the same commit · **no staging — every migration lands on live data**.

### 8.5 🆕 Edge-function risk **[VERIFIED]**

`whatsapp-send-otp/senders.ts` returns `MetaCloudSender` **only** when `OTP_SENDER === "meta"` and all of `META_WABA_PHONE_ID` / `META_WABA_TOKEN` / `META_OTP_TEMPLATE` are set. Otherwise it silently falls back to `DevConsoleSender`, which `console.log`s the OTP and **returns success**. In production with one env var missing, **login OTPs are never delivered and the failure is invisible** — the hook returns 200.

### 8.6 🆕 Cross-tenant RLS leaks **[VERIFIED — policy bodies read]**

Revision 1 confirmed every table *has* policies. Revision 2 read the policy bodies. Coverage ≠ correctness — **three tables are readable platform-wide by any authenticated user**:

| Table | Policy | `USING` | Impact |
|---|---|---|---|
| `companies` | `companies_select_authenticated` | **`true`** | **Every authenticated user reads every company row** — `seat_limit`, `seats_used`, `token_expires_at`, `current_token_id`, `whatsapp_number`, `registration_number`, `vat_number`, `physical_address`, CEO names, support email. A driver at transporter A can read every competitor's full profile and their commercial token/seat posture. **Cross-tenant data leak.** |
| `minerals` | `minerals_select_authenticated` | **`true`** | Every mine's mineral catalogue, grades and tonnages readable by every user on the platform. |
| `mine_hazards` | `mine_hazards_select_all` | **`true`** | Arguably intentional (hazards are safety information for all drivers) — but decide it deliberately and document it. |

`showcase_data` and `profile_requirements` are also `true`, which is fine — one is demo data being deleted, the other a seeded catalog.

The fix is not to drop these policies but to **narrow them**: companies should be readable by their own staff, by the platform admin, and by counterparties they are actually transacting with (via `org_connections` / `transactions`), which is what the UI genuinely needs. Everything else is leakage.

**One more, likely a real bug:** `transportation_requests_insert` checks **`is_company_staff(buyer_company_id)`** only. The table carries both `buyer_company_id` and `supplier_company_id`, and **[SPEC]** says mines submit requests too — *Request Transporter/Routes* is identical for both org types, and *Request Buyer* is mine-only. A mine submitting a request either fails RLS or has to write itself into `buyer_company_id`, which corrupts the semantics. Verify against a real mine account and fix the policy.

**Consistency note:** `pod_uploads_insert` permits supplier staff, exactly matching the `record_pod` defect in §7.3. Both are wrong in the same way — fix them together.

### 8.7 🆕 Storage buckets **[VERIFIED]**

12 buckets, 35 `storage.objects` policies. **Three buckets are public:**

| Bucket | Public | Size limit | MIME restriction | Verdict |
|---|---|---|---|---|
| `chat-attachments` | **YES** | 25 MB | **none** | 🔴 **Every file and image shared in company-to-company chat is readable by URL to anyone on the internet.** On a B2B platform where mines share lab results, contracts and load photos in chat, this is a confidentiality breach. |
| `support-attachments` | **YES** | **none** | **none** | 🔴 Public, unlimited size, any MIME type. Both an exposure and an abuse vector. |
| `company_assets` | YES | 10 MB | images only | 🟢 Fine — company logos are meant to be public. |

⚠ **There are two chat buckets.** `chat_files` is private with a 25 MB cap and a PNG/JPEG/WebP/PDF allow-list; `chat-attachments` is public and unrestricted. That is a half-finished migration — determine which one the app actually writes to, migrate the objects, and delete the other.

`compliance_docs` is private but has **no size limit and no MIME restriction**. The remaining seven (`employee_assets`, `load_photos`, `pod_photos`, `quality_certs`, `recon_docs`, `request_docs`, `signatures`) are private with sensible caps and allow-lists — correctly configured.

### 8.8 🆕 Data integrity on live data **[VERIFIED]**

| Check | Result | Meaning |
|---|---|---|
| Active employees with **no seat** | **69 of 88** | 🔴 **The seat model is not enforced in practice.** 106 seats are minted; roughly 19 are actually occupied. The seat limit is the thing the serial token sells, and it is currently decorative. |
| Companies with **no token** | **14 of 26** | 🔴 Over half the platform has no serial token — and the org list renders them with a **green** dot labelled "No token". |
| Active companies whose token has expired | 0 | ✅ `expire_organizations` appears to be doing its job. |
| Orphan trips (no transaction) | 0 | ✅ |
| Employees with no auth user | 0 | ✅ |
| **Orphan profiles** (neither employee, nor company owner, nor platform admin) | **3** | 🟠 Auth users belonging to nothing. Investigate and clean. |
| Completed trips with no `net_tons` | 0 | ✅ Every completed trip has a mine weight. |
| Completed trips vs POD uploads | **37 vs 35** | 🟠 Two trips reached `completed` without a POD — consistent with the collapsed lifecycle in §7.3. |

### 8.9 🆕 Performance **[VERIFIED via advisors — essentially clean]**

83 unused indexes (normal on a young database), 6 unindexed foreign keys (`fuel_entries.trip_id`, `monthly_targets.created_by`, and four more), 9 multiple-permissive-policy warnings (mostly a staff policy alongside a super-admin policy — harmless but each adds a per-row evaluation), and **one** `auth_rls_initplan` on `mine_hazards_insert_own` where `auth.uid()` should be `(select auth.uid())`. **Nothing here blocks a release.** Worth fixing before the data grows, not before launch.

---

## 9. The complete gap register

### 9.1 Dead actions **[VERIFIED]**

| # | Where | What happens |
|---|---|---|
| 1 | `transporter_portal_dashboard._RequestRoutesTile` | gradient CTA → `_snack('Route requests open with the platform marketplace.')` |
| 2 | `mine_supplier_buyers_detail_screen.dart:163` | `'Buyer requests are coming soon.'` |
| 3–4 | `stockpile_detail_screen.dart:129,131` and `supervisor_view_screen.dart:183,185` | "Upload Results" / "Upload Picture" coming-soon snackbars |
| 5 | stockpile "Test requests" | coming-soon snackbar |
| 6 | `buyer_reconciliations._download` | exports 6 key/value rows of **UUIDs** — no tonnage, loads or variance |
| 7 | `buyer_routes_mines_screen` | every route card ignores the route, opens the **global** map |
| 8 | mine dashboard Buyers card | promises "generate invoices, download reconciliations"; both buttons call `_openBuyers` |
| 9 | `mine_supplier_portal_dashboard:406,422` | "Live operational records" with a "Coming soon" pill |
| 10 🆕 | `super_admin_dashboard:93-96` | header link **"Export snapshot"** → just navigates to audit logs |
| 11 🆕 | `super_admin_dashboard:1387-1391` | quick action **"Export report"** with a download icon → just navigates |
| 12 🆕 | `super_admin_dashboard_v2:116` | `case 'export': return null;` |
| 13 🆕 | `super_admin_dashboard:1186-1200` | the 3 pending-request cards link to the **combined** inbox, never the split mine/buyer ones |

### 9.2 UI wording not backed by data **[VERIFIED]**

**Portal:** "Tons Allocated" = delivered net tons · "Assign trucks per route" for buyers who cannot · "Waybill #" = transaction ref · `'Reconciliation batch'` literal on every row + raw UUIDs labelled "Supplier"/"Transporter" · `Recon <uuid8>…` · "Trip" column = `TXN <id>` · "incoming and scheduled trucks" = every trip incl. completed, `clamp(0,50)` with no "showing 50 of N" · stale stockpile/supervisor prose · clock icon on a mass KPI.

🆕 **Super admin:**
- *"updated live from the **biometric gate and API events**"* — **there is no biometric gate**; it's a plain select per page load.
- *"oldest first, ordered by criticality"* — fixed hardcoded order, no sort, no criticality concept.
- **"Pending requests" counts every request ever raised** — `listForAdmin()` has no status filter, so approved, linked and declined are all counted. Both dashboards.
- Banner *"Expired token requests — N companies need approvals"* counts **open token requests**, nothing to do with expiry. Meanwhile the genuinely relevant `tokensExpiringSoon` is computed and **thrown away**.
- "Total tons managed / Jan → today" with a delta that is actually *share of all-time tonnage moved in the last 24 h*, rendered as growth.
- User preferences say *"saved to the signed-in admin's account"* — they are **SharedPreferences, device-local**, and will not follow the admin across Windows/web/mobile.
- A company with **no token** renders a **green** dot labelled "No token".

🆕 **Tutorial:** `DemoDataIndicator` shows *"Demo Data Active — showing example content"* whenever `showcase_data` is non-empty — i.e. **always** — while no example content is shown anywhere. It tells real customers their live screens are demo data.

### 9.3 Fabricated data **[VERIFIED]**

**Correction to Revision 1:** there is **no `math.Random` in `super_admin/`**. `SaSparkline` is a pure painter. The fabrication is worse in a way — **three hardcoded monotonically-rising arrays at the call site**:

- `super_admin_dashboard_screen.dart:182` `const [4,6,5,7,6,8,7,9,8,10]` — Transporters
- `:199` `const [5,4,6,5,7,6,8,7,9,8]` — Buyers
- `:216` `const [3,4,4,5,6,6,7,8,9,11]` — Mines/Suppliers

Copied verbatim from the design drop's sample data, painted next to three genuinely live metrics. **The real version is already written 320 lines away** in `super_admin_dashboard_v2_screen.dart:166-182` (`_spark()` sums `RawReconRow.netMass` per day) — on the screen nobody can reach.

- `minelink_screens_core.dart:383-747` — `MlSampleData`, **364 lines** of invented platform figures, used as **default constructor arguments** on `MineLinkDashboardScreen`. Today all four are passed explicitly, so nothing fake renders — but any future caller that omits one silently ships fabricated platform totals.
- `minelink_targets_core.dart:479+` — `MlTargetsSample`, 12 months of invented tonnage, zero references.
- `employee_profile_service.dart:581,597,624,690,831` — **5 synthetic sparklines**: one flat-zero 7-day series, four that repeat the current value 7×, while the provider doc claims "real counts + 7-day sparklines".
- `mine_supplier_overview_metrics.dart:144` — allocated-stockpile tonnage standing in for real tons-out.

### 9.4 🆕 Cross-cutting rules not implemented **[VERIFIED]**

- **Chat hierarchy: not enforced at all.** `get_chat_contacts` returns, for any non-super-admin, *every user in their own company regardless of role* plus *every user at every connected company*. **A driver can DM anyone in their company or any connected company.** `role` is returned but used only as a grouping label, never as a permission. Conversely companies/managers **cannot** reach everyone as specified.
- **Group chat: structurally impossible.** `createOrgGroup` accepts exactly **two** company ids — a 3-company group cannot exist — and it is **never called from any UI**. No org-type-uniqueness check anywhere. All 13 live rooms are `type='dm'`.
- **"Only the company can end a chat": no method, no column, no button.**
- **Notification scoping:** every read is `.eq('user_id', me)`. "Companies see all" and "management sees below them" are **not visibility rules** — the hierarchy is only a *narrowing filter on your own rows*, and depends on the sender fanning out copies, which is done for some events and not others. Two bugs: **`UserRole.driver` is absent from management's and admin's scope lists**, so driver-scoped notifications never appear; and the company branch filters on `org_type` only, so a company sees notifications intended for a specific role.
- **Company reg-ref: does not exist.** `companies` has 29 columns and none is a reg-ref. `registration_number` is free-text, user-typed, unvalidated, not permanent, and **not displayed on the company profile at all**.
- **Seat serials: nothing exists.** Seats are integers (`seat_number`). No 15-char serial, no role-bound last-3-characters, no UI. `occupied_by_employee_role` exists on the row and is **never rendered**.
- **Seat reassignment governance: nothing exists.** No counter, no column, no RPC, no UI. Zero hits for `reassign` across `lib/` and `supabase/migrations/`.
- **Audit log filters:** the repository supports actor / org / orgType / actionTypes / date range / limit / offset. The screen exposes **only action-type chips**, never passes `limit`, so the default **100-row cap** applies with no pagination — and the export therefore exports at most 100 rows. All four export formats (CSV/PDF/Excel/JSON) are genuinely implemented.
- **Signatures:** correctly build-once/reuse-everywhere — `ProfileSignatureCard` renders for every user type, the pad exports a genuinely transparent PNG, and both `record_truck_load` and `record_pod` pull `profiles.signature_url` server-side. **Nobody is ever asked to re-sign.** But only **3 of 116** profiles have one, and a user without one gets a blank waybill signature line with no warning.

### 9.5 What's genuinely well built — verify, don't rebuild

The due-diligence gate is **implemented exactly to spec**, including the green tickable checkbox and all three confirmations, with server-side re-validation. Margin in R and the admin-only ledger are correct (`revoke all from public/anon`). Route ID minting is correct. Targets are correct: three independent scopes, `target <= 0` renders **"Not set"** and suppresses the ring, unreached horizons render **dashed grey**. Token generation hashes correctly and shows the raw token once behind a warning, with a real three-button Cancel/Edit/Confirm step. The live countdown exists and ticks every second on the org detail screen. All four request inboxes exist with genuinely read-only detail panes. The Operations Hub is fully real. The test suite loads real TTFs and sweeps 6 widths × 4 text scales with adversarial fixtures, and honestly documents its own gaps.

---

## 10. Platform, assets and secrets

### 10.1 Release blockers **[VERIFIED]**

| # | Blocker | Detail |
|---|---|---|
| **B1** | **Android `applicationId = "com.example.flutter_application_1"`** | Play **rejects** `com.example.*`. **Permanent after first publish** — must be fixed before the first upload, not after. |
| **B2** | **Android release build signs with the debug keystore** | `signingConfig = signingConfigs.getByName("debug")`. No `key.properties`, no keystore. A debug-signed AAB cannot be uploaded. |
| **B3** | **Live ArcGIS token bundled into every artifact** | `pubspec.yaml` declares `config/` as an asset dir; `config/map_tiles.local.json` holds a **real Esri token**. Gitignored — but **gitignore does not stop the Flutter bundler**. On web it is fetchable at `/assets/config/map_tiles.local.json`. Billable and scrapeable. **Rotate the token**, declare the two config files individually, and pass tile config via `--dart-define-from-file`. |

### 10.2 Not blockers, but fix

- Android `minSdk`/`targetSdk`/`versionCode` inherit Flutter defaults; `version: 1.0.0+1` untouched.
- `ACCESS_BACKGROUND_LOCATION` requires a Play Console background-location declaration **plus a demo video** at review.
- Windows: `CMakeLists.txt` has `project(the_mineral)` / `BINARY_NAME "the_mineral"` — the shipped exe is **`the_mineral.exe`** while everything else says MineLink.
- Web: `debug_loader.js` and `debug_toggle.js` are orphaned but **`flutter build web` copies everything in `web/`**, so they ship. Delete.
- iOS (if added): **`NSCameraUsageDescription` and `NSPhotoLibraryUsageDescription` are missing** despite `image_picker` — guaranteed crash on first photo pick and an App Store rejection. Location descriptions and background modes are correct.
- `config/supabase.live.json` is committed (publishable key — acceptable if RLS is airtight) but hard-points every build at production with no build-time switch.
- `active user accounts.txt` at repo root — gitignored, but present on disk and would be swept into any folder handoff. **Plaintext passwords.**
- `supabase/config.toml` (local dev only): `minimum_password_length = 6`, empty password requirements, `enable_signup = true`, confirmations off. Verify the **hosted** project's auth settings independently.

### 10.3 Assets — all clear ✅ **[VERIFIED]**

**Every one of the 16 declared font files exists**, including all five Sora weights. Every other declared asset exists. **No missing assets.** The waybill PDF is drawn **programmatically** — `assets/Varsiwave waybil 2l.png` is only a visual reference in a doc comment and needs no declaration; the only `rootBundle.load()` calls are for four TTFs, all present. Undeclared planning folders sit inside `assets/` and inflate the repo but ship nothing.

### 10.4 Tests **[VERIFIED]**

79 real test files. Quality is genuinely high — `super_admin_overflow_sweep_test.dart` loads the real TTFs via `FontLoader`, sweeps **6 widths × 4 text scales** plus bold-text variants, captures full `FlutterErrorDetails`, uses adversarial fixtures (6-figure tonnage, 248 companies, 1.7M tons), and honestly documents the screens it leaves out rather than passing vacuously. `waybill_pdf_test.dart` asserts real output.

**Zero coverage:** chat/messaging (14 migrations, no test) · support tickets · stockpiles and the order flow · hazards/waypoints/road requests · production dispatch · buyer load values and invoices · margin ledger · POD photos and cross-party visibility · quality certs · driver assignments · compliance beyond the model · ETA alerts · trip P&L · account setup.

---

## 11. Phasing

| Phase | Theme | Size |
|---|---|---|
| **0** | Guardrails — branch, baseline, migration hygiene, delete stray entrypoints, **rotate the ArcGIS token** | S |
| **1** | Demolition — 8 tab screens + `operations_workspace`, dead widgets, duplicate location screens, legacy `core/mcp/` layer, debug/demo screens | M |
| **2** | Data-layer correctness — positions scoping, partner cap, null guards, atomic check-out | M |
| **3** | Backend hardening — revoke anon grants, `offloaded` status, variance column + view, `record_pod` party check, child-admin cleanup, duplicate migration timestamps, demo seeds | M |
| **4** | 🆕 **Routing & guards** — extract the 5 inline screens, fix all 9 guard holes, route the orphans, give every destination a URL | **L** |
| **5** | Design system extraction — `lib/core/design/`, unify tokens, one shell, one rail | **L** |
| **6** | Portal migration onto the console design | **L** |
| **7** | 🆕 **Navigation rebuild** — sectioned dropdown trees per org type per role, integer badges, per-org dashboards, **Employee Register** | **L** |
| **8** | Workflow completion — the missing screens (accept-route, allocate-fleet, orders, route detail, vehicle detail, load history), dead CTAs, wording fixes | **L** |
| **9** | Super admin completeness — real sparklines, pending-count fix, seat serials, reassignment governance, audit filters, wording | M |
| **10** | Cross-cutting — dismissal chain, chat hierarchy, group chat, notification scoping, signatures, reg-ref, expiry enforcement, empty-table verdicts | **L** |
| **11** | Platform parity, verification, release gate | M |

---

## 12. Definition of done

1. `flutter analyze` clean, no new warnings.
2. **Zero raw `Color(0x…)` / `Colors.*` in `lib/features/`** (CI grep).
3. **Zero "coming soon" / "not implemented" strings in `lib/`** (CI grep).
4. **Zero hardcoded data series rendered as a trend** (CI grep for `const [` passed to a `spark:` argument).
5. **Zero screen classes defined inside `app_router.dart`.**
6. **Every route either has a nav entry, is a legitimate detail/deep-link route reachable from a parent screen, or is deleted.** No orphans.
7. **Every (org type × role) × every nav entry** opens a screen rendering real data or an honest empty state — recorded in a matrix.
8. **The full 22-step workflow executed end to end on the live project by real test accounts of every role**, with evidence per step.
9. Every KPI label, column header and card subtitle verified against its query.
10. All 27 anon RPC grants revoked; leaked-password protection on; all 9 guard holes closed.
11. Every table in §8.3 has a verdict — proven with a real write, or hidden.
12. Every screen survives text scale 0.85–1.3 with bold text at 3 widths.
13. **Android ships with a real `applicationId` and a real release keystore. The ArcGIS token is rotated and de-bundled.**
14. Windows, Web and Android built from the **same commit** and smoke-tested through the same workflow.
15. Every applied migration has a matching file committed in the same change.

Report progress as *"screens proving something / N"*, never as passing-test count.

---

## 13. Risks

| Risk | Impact | Mitigation |
|---|---|---|
| **No staging** — every migration hits 116 profiles, 88 employees, 41 trips | High | Review before apply; additive-only where possible; back up before the variance/status migrations |
| Phase 4 + 7 rewrite the entire navigation surface | High | Extract first with zero behaviour change, then re-tree. Separate commits |
| Phase 5 touches ~100 files | High | Pure extraction commit, then restyle commit |
| **B1 is irreversible after first publish** | Critical | Fix the `applicationId` before any store upload |
| WhatsApp OTP silent fallback | High | Verify all four env vars on the live project **before** launch; add a hard failure instead of a 200 |
| Deleting the 8 tab screens removes entries users click | Medium | They show employee lists; replacement is `company_employees_screen` + the new Employee Register |
| Physical GPS can't be proven headlessly | Medium | A real road trip is a release gate |
| 173 `authenticated`-executable definer functions | Medium | Walk the list once in Phase 3 |

---

## 14. Handover notes

- Own branch. **Never** `git stash` / `git checkout -- .` / `git clean` / checkout another branch in this worktree. One commit per logical change.
- Package is `flutter_application_1` — **do not rename**. Product name lives only in `AppBranding.appName`.
- **All DB access through a feature `service` or a `core` repository.** Screens and providers never touch `SupabaseConfig.client` directly.
- Lifecycle mutations go through the cascade RPCs, never ad-hoc table updates.
- Wire enums carry an explicit `.wire`/`.id` and a tolerant `parse`.
- Request status is its own enum. The four request types stay separate entities. Extend `stockpile_entry` / `tons_out_entry` — never parallel tables.
- `LoggerFactory.getLogger('Scope')`, never `print`.
- Security lives in RLS and RPCs. Dart-side checks are UX. **Implement both.**
- New table the UI subscribes to → realtime **and** RLS in the same migration.
- The repo has ~150 root-level legacy scratch scripts. They are historical artifacts and actively mislead. The live app is `lib/` + `supabase/`.

---

---

## 16. 🆕 Settled decisions and the post-v1.0 cleanup list

> Added 2026-08-11. Two of these are **settled client rulings**: they are not
> open questions, and a later session that "fixes" one is reintroducing a
> defect. The rest is deferred work that is genuinely deferred, not forgotten.

### 16.1 Settled — do not reopen

**(a) `transportation_requests.buyer_company_id` is NOT renamed for v1.0.**
*Ruled by the client, 2026-08-11.* The column means **requester** — any org
type, `not null` on every row — and the name misled a careful audit into
raising a false release blocker (P3-46). The rename is the real fix and is
genuinely wanted; it is not worth doing now. It is load-bearing for **5
functions, 4 policies and the admin inbox's `companies!buyer_company_id`
embed**, on a single production project with **no staging**, for naming clarity
alone. The mitigation is in place and is the right one: a
`comment on column` (migration `20260811160000`) that reaches the next reader
in the same place the confusion starts, plus the Dart renamed off the
misleading name (`companyRequestsProvider`, `listForRequester`). See §16.2.

**(b) The linked mine must NOT be given a direct SELECT on
`transportation_requests`.** *Settled, 2026-08-11.* The obvious "fix" for a
mine that cannot read the order it is fulfilling is to widen
`transportation_requests_select` to `is_company_staff(supplier_company_id)`.
**That would leak the buyer's price per ton and the platform's own margin
notes to the mine** — the row carries `price_per_ton`, `rate` and
`admin_notes`, and RLS is row-level, not column-level. It breaks §4's rule
that each party sees only its own side of the price, which is the commercial
premise of the whole platform.

The existing design is already correct: the linked mine reads its orders
through **`list_request_tracking()`**, a `SECURITY DEFINER` RPC that returns
*facts* (status, commodity, loading/offloading point, trip counts, tons
delivered) rather than the row. Same shape as `list_company_member_presence`.
Verified live: a linked mine selects **0** rows from the table directly and
gets its orders through the RPC.

> **If a future session finds "the mine can't see its order" and reaches for
> the policy — stop.** The answer is to extend the RPC's return columns, never
> to widen the policy. Before widening ANY policy on this schema, read the
> row's full column list first.

### 16.2 Post-v1.0 cleanup list

Deferred deliberately. None of it blocks the release; all of it is real.

| # | Item | Why deferred | Why it still matters |
|---|---|---|---|
| 1 | **Rename `buyer_company_id` → `requester_company_id`** (+ `listForAdmin`'s embed alias, and the 5 functions / 4 policies that reference it) | §16.1(a) — production rename, no staging, naming clarity alone | It has already cost one false release blocker and a session's work. A comment mitigates; it does not fix. Do it behind a staging environment. |
| 2 | **A staging Supabase project** | Out of scope for v1.0 | Every migration in this effort landed on live data with 116 profiles and 41 trips. Item 1 and any future rename are blocked on this. |
| 3 | **Delete `premium_mine_dashboard.dart`** (1,596 lines) and the appearance-driven dashboard fork's remnants | Phase 12 — no deletions until the flow is proven end to end | Retired 2026-08-11 (no longer selected), but still on disk. The premium *chrome* stays; only the dashboard fork is dead. |
| 4 | **Load and concurrency behaviour** at 50 companies / 500 trucks | §15 item 14 | The `vehicle_positions` cap was the one scale defect found by reading. There will be others. |
| 5 | **Crash/error telemetry** (Sentry or equivalent) | §15 item 11 | A consumer release with no crash reporting is flying blind. |


---

## 15. 🆕 What this audit did NOT cover

This plan is thorough, but it is not omniscient. Everything below is a known blind spot. Treat each as work, not as clearance.

**Verified by reading, never by running.** Nothing in this plan has been built, launched or clicked. No Flutter build was attempted on any platform. Every "REAL / works / verified" judgement is a code-and-schema reading, not a runtime observation. The first execution phase should expect to find things a static read cannot.

| # | Not covered | Why it matters | Suggested owner |
|---|---|---|---|
| 1 | **The 35 `storage.objects` policies** — counted, not read | Bucket privacy is only half the control; the object policies are the other half. A private bucket with a permissive object policy is not private. | Phase 3 |
| 2 | **The 173 `authenticated`-executable `SECURITY DEFINER` function bodies** | Each must re-check the caller's company and role internally. Sampled, not exhaustively walked. | Phase 3 |
| 3 | **The remaining ~250 RLS policy bodies** | Revision 2 read only the ones that are unconditionally `true`. A policy can be subtly wrong without being `true`. | Phase 3 |
| 4 | **Database triggers** | Never enumerated systematically. Some are known (`monthly_targets_guard`, `chat_bump_last_message`, `handle_employees_updated_at`); there may be others with side effects the plan doesn't account for. | Phase 3 |
| 5 | **`pg_cron` schedules** | The 7 job *functions* exist. Whether they are actually scheduled — and at what cadence — was never confirmed. `expire_organizations` at least appears to be running (0 expired-but-active companies). | Phase 3 |
| 6 | **Contents of 4 portal screens** — `mine_locations_screen`, `transporter_maintenance_screen`, `driver_navigation_screen`, `request_transportation_screen` | Existence and routing confirmed; internals never audited for mock data or dead actions. | Phase 6 |
| 7 | **`chat_dock.dart` (6047 lines)** | Surface-audited only. The largest single file in the app. | Phase 10 |
| 8 | **`super_admin_repository.dart`** | Large; read in part. | Phase 9 |
| 9 | **Unexamined directories** — `Guide/`, `Looks of Pages within the app/`, `public_html_portal/`, `Someone/`, `output/`, `authenticate/`, `bin/`, `docker/`, `scripts/` | Probably junk, possibly not. `public_html_portal/` and `docker/` in particular could imply deployment surface nobody has accounted for. | Phase 0 |
| 10 | **`analysis_options.yaml` lint configuration** | A clean `flutter analyze` means little if the rules are permissive. | Phase 0 |
| 11 | **Crash and error reporting** | No evidence of Sentry or any equivalent. A consumer release with no crash telemetry is flying blind. **Recommend adding one.** | Phase 11 |
| 12 | **Offline and poor-connection behaviour** | Named as a requirement, never audited. Drivers on mine haul roads will lose signal — what happens to a POD upload mid-submit is unknown. | Phase 11 |
| 13 | **Accessibility beyond text scale** | Screen-reader labels, focus order, contrast ratios and touch-target sizes were not audited. | Phase 11 |
| 14 | **Load and concurrency** | No view on behaviour with 50 companies and 500 trucks. The `vehicle_positions` defect (§7.1) is the one scale problem found by reading; there will be others. | post-v1.0 |
| 15 | **Backup, restore and disaster recovery** | No documented procedure. On a single production project with no staging, this is a real gap. | Phase 11 |
| 16 | **Legal and commercial** | POPIA compliance (South African data protection), data-retention policy, terms of service, privacy policy, the client's own sign-off criteria. **Out of engineering scope but not out of release scope.** | client |

**Two structural caveats on the plan itself.** Item counts and phase sizes are estimates from static reading, not from having done the work — Phase 5 and 7 in particular could grow once the extraction starts. And the audit inherits the codebase's own documentation, which contradicts itself across generations; §2.1 records the rulings taken, but a ruling is a decision, not a fact, and the client may overrule any of them.
