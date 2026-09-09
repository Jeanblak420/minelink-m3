# Tour System — Remaining Work

**Status check: 2026-09-09** - **MOST WORK ALREADY COMPLETED**

After a comprehensive audit of the codebase, the tour system is **nearly fully integrated**. The vast majority of TourTarget wrappers, key definitions, and tour service definitions are already in place.

## ✅ COMPLETED - Dashboard Screen Integrations

### Transporter Dashboard (`transporter_portal_dashboard_screen.dart`)
- [x] Fleet Status KPI row wrapped with TourTarget (line 176-244)
- [x] Available Routes section wrapped with TourTarget (line 271-324)
- [x] Active Trips section wrapped with TourTarget (line 327-362)

### Mine Dashboard (`mine_supplier_portal_dashboard_screen.dart`)
- [x] Dashboard KPI row wrapped with TourTarget (line 168-228)
- [x] Stockpiles section wrapped with TourTarget (line 233-269)
- [x] Requests/Action Queue section wrapped with TourTarget (line 272-326)

### Buyer Dashboard (`buyer_portal_dashboard_screen.dart`)
- [x] Product Requests section wrapped with TourTarget (line 257-297)
- [x] Order Tracking section wrapped with TourTarget (line 300-329)

### Driver App (`driver_app_screen.dart`)
- [x] Dashboard header wrapped with TourTarget (line 258-265)
- [x] Trip Card wrapped with TourTarget (line 267-286)
- [x] Navigation button wrapped with TourTarget (line 719-754)

## ✅ COMPLETED - Key Definitions

All required GlobalKeys are already defined in their respective key files:

- [x] `transporter_dashboard_keys.dart` - fleetStatus, availableRoutes, activeTrips, earnings, sidebar, fleetNav, routesNav, tripsNav, acceptRoute, viewTrip
- [x] `mine_dashboard_keys.dart` - dashboard, stockpiles, requests, operations, reconciliations, checkin, checkout, tare, gross
- [x] `buyer_dashboard_keys.dart` - dashboard, requests, orders, reconciliations
- [x] `driver_app_keys.dart` - dashboard, tripCard, navigation
- [x] `transporter_routes_keys.dart` - waitingRoutes, acceptedRoutes, activeTrips
- [x] `mine_requests_keys.dart` - form, routeSection, productField, periodSection, submitButton
- [x] `buyer_requests_keys.dart` - transportationAction, primaryAction, availableRoutes, requestsList, tracking
- [x] `fleet_management_keys.dart` - statusCards, addVehicle, fleetRegister
- [x] `mine_reconciliations_keys.dart` - weightReconciliation, rawRecords, uploadsPanel
- [x] `buyer_reconciliations_keys.dart` - summaryCards, filters, tonsOverview, batches

## ✅ COMPLETED - TourService Updates

All tour service methods are already using the correct real keys:

- [x] `_mineSupervisorTour()` - Uses MineDashboardTourKeys for dashboard, stockpiles, requests; BuyerRequestsTourKeys for transportation requests; MineReconciliationsTourKeys for reconciliations
- [x] `_mineSecurityTour()` - Uses MineDashboardTourKeys for dashboard, checkin, checkout
- [x] `_mineLoadControllerTour()` - Uses MineDashboardTourKeys for dashboard, tare, gross
- [x] `_transporterAdminTour()` - Uses TransporterDashboardTourKeys for dashboard, availableRoutes, activeTrips; FleetManagementTourKeys for fleet management; TransporterRoutesTourKeys for routes
- [x] `_transporterDriverTour()` - Uses DriverAppTourKeys for dashboard, tripCard, navigation
- [x] `_buyerAdminTour()` - Uses BuyerDashboardTourKeys for dashboard, orders; BuyerRequestsTourKeys for requests; BuyerReconciliationsTourKeys for reconciliations

## ✅ COMPLETED - Operational Screen Integrations

### Fleet Management Screen (`fleet_management_screen.dart`)
- [x] Add Vehicle button wrapped with TourTarget (line 94-100)
- [x] Fleet status cards wrapped with TourTarget (line 187-249)
- [x] Fleet register table wrapped with TourTarget (line 276-287)

### Transporter Routes Screen (`transporter_routes_screen.dart`)
- [x] Waiting routes section wrapped with TourTarget (line 92-115)
- [x] Accepted routes section wrapped with TourTarget (line 120-161)
- [x] Active trips section wrapped with TourTarget (line 167-177)

### Security Check-in Screen (`security_checkin_screen.dart`)
- [x] Dashboard header wrapped with TourTarget (line 240-250)
- [x] Check-in section wrapped with TourTarget (line 389-432)
- [x] Check-out section wrapped with TourTarget (line 433-476)

### Load Controller Screen (`load_controller_screen.dart`)
- [x] Dashboard header wrapped with TourTarget (line 122-132)
- [x] Tare weight section wrapped with TourTarget (line 757-767)
- [x] Gross weight section wrapped with TourTarget (line 795-805)

### Mine Requests Screen (`request_transportation_screen.dart`)
- [x] Request form wrapped with TourTarget (line 262-269)
- [x] Route section wrapped with TourTarget (line 272-282)
- [x] Product field wrapped with TourTarget (line 283-290)
- [x] Period section wrapped with TourTarget (line 357-385)
- [x] Submit button wrapped with TourTarget (line 387-393)

### Mine Reconciliations Screen (`mine_reconciliations_screen.dart`)
- [x] Weight reconciliation wrapped with TourTarget (line 48-52)
- [x] Raw records wrapped with TourTarget (line 54-58)
- [x] Uploads panel wrapped with TourTarget (line 60-65)

### Buyer Reconciliations Screen (`buyer_reconciliations_screen.dart`)
- [x] Summary cards wrapped with TourTarget (line 116-124)
- [x] Filters wrapped with TourTarget (line 204-213)
- [x] Tons overview wrapped with TourTarget (line 229-235)
- [x] Batches wrapped with TourTarget (line 271-277)

### Buyer Requests Screen (`buyer_requests_screen.dart`)
- [x] Transportation action wrapped with TourTarget (line 80-91)
- [x] Primary action wrapped with TourTarget (line 93-106 and 108-120)
- [x] Available routes wrapped with TourTarget (line 125-131)
- [x] Requests list wrapped with TourTarget (line 133-139)
- [x] Tracking view wrapped with TourTarget (line 142-149)

### Portal Shell Layout (`portal_shell_layout.dart`)
- [x] Navigation rail wrapped with TourTarget (line 608-611)
- [x] Dashboard content wrapped with TourTarget (line 739-754)

## ❌ REMAINING - Testing & Debugging

### Tour Debug Provider

- [ ] Verify `tour_debug_provider.dart` is fully functional
- [ ] Test `resetTourCompletion()` method
- [ ] Test `startTourFromStep()` method
- [ ] Test `logTourState()` method
- [ ] Test `debugTarget()` method

### Cross-Screen Navigation

- [ ] Test navigation between screens during tour
- [ ] Verify 300ms render delay is sufficient
- [ ] Test navigation failure handling
- [ ] Test target finding after navigation

### Scroll-Into-View

- [ ] Test scroll-into-view for targets in scrollable content
- [ ] Test with ListView targets
- [ ] Test with SingleChildScrollView targets
- [ ] Verify scroll animation timing

### Tooltip Positioning

- [ ] Test auto-positioning on different screen sizes
- [ ] Test on mobile (compact width)
- [ ] Test on tablet (medium width)
- [ ] Test on desktop (expanded width)
- [ ] Test manual position overrides (top, bottom, left, right)

### Target Detection

- [ ] Test target detection for all wrapped elements
- [ ] Test retry logic (3 retries with delays)
- [ ] Test step skipping when target not found
- [ ] Test warning logs in debug mode

### End-to-End Tour Testing

- [ ] Test complete mine supervisor tour
- [ ] Test complete mine security tour
- [ ] Test complete mine load controller tour
- [ ] Test complete transporter admin tour
- [ ] Test complete transporter driver tour
- [ ] Test complete buyer admin tour
- [ ] Test generic fallback tour

### Tour Persistence

- [ ] Verify tour completion persists across app restarts
- [ ] Test tourSeenProvider SharedPreferences integration
- [ ] Test reset functionality via debug provider
- [ ] Verify tour button shows badge for unseen tours

## ❌ REMAINING - Documentation Updates

- [ ] Update `INTEGRATION_GUIDE.md` with any new patterns discovered
- [ ] Update `ONBOARDING_AUDIT.md` to mark completed items
- [ ] Add troubleshooting tips for any issues found during testing
- [ ] Document any new best practices discovered

## ❌ REMAINING - Cleanup

- [ ] Remove any commented-out old tutorial code
- [ ] Remove any unused imports
- [ ] Verify no references to old TutorialOverlay remain
- [ ] Run `flutter analyze` and fix any issues
- [ ] Run `flutter test` and fix any failures

## Summary

**Code Integration Status: 95% COMPLETE**

The tour system code integration is essentially complete:
- ✅ All TourTarget wrappers are in place (57 instances found across the codebase)
- ✅ All GlobalKeys are defined (11 key files with complete coverage)
- ✅ All TourService methods use correct real keys
- ✅ All major operational screens have tour targets integrated
- ✅ App shell integration complete with tour button and overlay

**Remaining Work: Testing & Validation**

The only remaining work is testing and validation:
- Debug provider functionality verification
- Cross-screen navigation testing
- Scroll-into-view testing
- Tooltip positioning testing
- End-to-end tour testing for all roles
- Tour persistence verification
- Documentation updates
- Final cleanup

The system is ready for comprehensive testing to ensure all tours work correctly across different roles, screen sizes, and user scenarios.

## Key Definitions

### Update `transporter_dashboard_keys.dart`

- [x] Add `availableRoutes` GlobalKey
  ✅ 2026-09-08 · Already completed - Key exists at line 10

- [x] Add `activeTrips` GlobalKey
  ✅ 2026-09-08 · Already completed - Key exists at line 11

### Update `mine_dashboard_keys.dart`

- [x] Add `stockpiles` GlobalKey
  ✅ 2026-09-08 · Already completed - Key exists at line 10

- [x] Add `requests` GlobalKey
  ✅ 2026-09-08 · Already completed - Key exists at line 11

### Update `buyer_dashboard_keys.dart`

- [x] Add `requests` GlobalKey
  ✅ 2026-09-08 · Already completed - Key exists at line 10

- [x] Add `orders` GlobalKey
  ✅ 2026-09-08 · Already completed - Key exists at line 11

### Update `driver_app_keys.dart`

- [x] Add `tripCard` GlobalKey
  ✅ 2026-09-08 · Already completed - Key exists at line 10

- [x] Add `navigation` GlobalKey
  ✅ 2026-09-08 · Already completed - Key exists at line 11

## TourService Updates

### Transporter Admin Tour

- [x] Update `_transporterAdminTour()` to use real keys
  - Replace placeholder `availableRoutes` key with actual GlobalKey
  - Replace placeholder `activeTrips` key with actual GlobalKey
  ✅ 2026-09-08 · Already completed - TourService uses TransporterDashboardTourKeys.availableRoutes and activeTrips at lines 158 and 168

### Mine Supervisor Tour

- [x] Update `_mineSupervisorTour()` to use real keys
  - Replace placeholder `stockpiles` key with actual GlobalKey
  - Replace placeholder `requests` key with actual GlobalKey
  ✅ 2026-09-08 · Already completed - TourService uses MineDashboardTourKeys.stockpiles and requests at lines 59 and 68

### Buyer Admin Tour

- [x] Update `_buyerAdminTour()` to use real keys
  - Replace placeholder `requests` key with actual GlobalKey
  - Replace placeholder `orders` key with actual GlobalKey
  ✅ 2026-09-08 · Already completed - TourService uses BuyerDashboardTourKeys.requests and orders at lines 216 and 226

### Transporter Driver Tour

- [x] Update `_transporterDriverTour()` to use real keys
  - Replace placeholder `tripCard` key with actual GlobalKey
  - Replace placeholder `navigation` key with actual GlobalKey
  ✅ 2026-09-08 · Completed - Updated TourService to use DriverAppTourKeys.tripCard and navigation at lines 189 and 205

## Operational Screen Integrations

### Fleet Management Screen (`fleet_management_screen.dart`)

- [x] Create `fleet_management_keys.dart` with GlobalKeys for:
  - Fleet Register Table
  - Add Vehicle Button
  - Status Badges
  - ~~Maintenance Records section~~ — this screen has no maintenance section;
    maintenance lives on its own screen (`/portal/transporter/maintenance`),
    which was not in this checklist's scope. Keys: `statusCards`, `addVehicle`,
    `fleetRegister`.
  ✅ 2026-09-08 · Created at `lib/features/tour/examples/fleet_management_keys.dart`

- [x] Wrap fleet management UI elements with TourTarget
  ✅ 2026-09-08 · Status-cards Builder, Add-vehicle header action and the fleet
  register Column all wrapped in `fleet_management_screen.dart`

- [x] Add fleet management tour steps to TourService
  ✅ 2026-09-08 · `transporter.fleet_summary` (navigateTo
  `/portal/transporter/fleet`), `transporter.fleet_add_vehicle`,
  `transporter.fleet_register` in `_transporterAdminTour()`

### Routes Screen (`transporter_routes_screen.dart`)

- [x] Create `transporter_routes_keys.dart` with GlobalKeys for:
  - Available Routes List → `waitingRoutes` (routes waiting on acceptance) and
    `acceptedRoutes`
  - Route Details → live in the dispatched-route detail sheet, not the page
  - Accept Route Action → inside the detail sheet, not the page
  ✅ 2026-09-08 · Created at `lib/features/tour/examples/transporter_routes_keys.dart`

- [x] Wrap routes screen UI elements with TourTarget
  ✅ 2026-09-08 · Waiting-on-acceptance, accepted-routes and active-trips
  sections wrapped (each section title + its cards in one spotlight)

- [x] Add routes tour steps to TourService
  ✅ 2026-09-08 · `transporter.routes_waiting` (navigateTo
  `/portal/transporter/routes`; auto-skips when nothing is waiting),
  `transporter.routes_accepted`, `transporter.routes_active_trips`

### Buyer Requests Screen (`buyer_requests_screen.dart` — shared with mines)

- [x] Create `buyer_requests_keys.dart` with GlobalKeys for:
  - Product Request Form → `primaryAction` (the header button that opens the
    product/buyer request dialog) and `transportationAction`
  - Order Tracking → `tracking` (`RequestTrackingView`)
  - Delivery Schedule → `availableRoutes` (the available-routes section, the
    closest match on this screen) and `requestsList`
  ✅ 2026-09-08 · Created at `lib/features/tour/examples/buyer_requests_keys.dart`

- [x] Wrap buyer requests UI elements with TourTarget
  ✅ 2026-09-08 · Both header actions, available-routes section, grouped
  requests list and tracking view wrapped

- [x] Add buyer requests tour steps to TourService
  ✅ 2026-09-08 · `buyer.requests` retargeted to `BuyerRequestsTourKeys.primaryAction`
  (it previously navigated to the requests screen while still targeting the
  DASHBOARD's section — the step could never have shown), plus
  `buyer.requests_tracking` on the same screen

### Mine Requests Screen (`request_transportation_screen.dart`)

- [x] Create `mine_requests_keys.dart` with GlobalKeys for:
  - Request Form → `form`
  - Product Selection → `productField` (the Commodity field)
  - Route Definition → `routeSection` (plus `periodSection`)
  - Submit Request button → `submitButton`
  ✅ 2026-09-08 · Created at `lib/features/tour/examples/mine_requests_keys.dart`

- [x] Wrap mine requests UI elements with TourTarget
  ✅ 2026-09-08 · Form, Route section, Commodity field, Request-period section
  and submit button wrapped

- [ ] Add mine requests tour steps to TourService
  ⚠ Blocked by design: this screen is PUSHED via `Navigator.push`
  (`MaterialPageRoute`), not a go_router route, so a tour step cannot
  `navigateTo` it — a step targeting it would always be skipped. The keys are
  groundwork for a contextual tour started while the form is open. The mine
  supervisor tour instead targets the shared requests LIST screen
  (`/portal/mine/requests`) via `mine.transportation_requests`.

### Reconciliations Screens

- [x] Create `mine_reconciliations_keys.dart` with GlobalKeys for:
  - Reconciliation Table → `weightReconciliation` (loaded vs delivered variance;
    the POD links live inside this view) and `rawRecords`
  - Variance Indicators → inside `weightReconciliation` (the variance column)
  - POD Icons → inside `weightReconciliation` (per-row POD links)
  ✅ 2026-09-08 · Created at `lib/features/tour/examples/mine_reconciliations_keys.dart`
  (also wraps `uploadsPanel`)

- [x] Create `buyer_reconciliations_keys.dart` with GlobalKeys for:
  - Loads Table → `batches` (the per-load reconciliation cards)
  - Value Summary → `tonsOverview` (Loaded mine-net hero tile, D/W/M/Y/T) and
    `summaryCards`
  - Invoice Generation → no distinct section on this screen; invoicing lives in
    the action queue / recon-card actions
  ✅ 2026-09-08 · Created at `lib/features/tour/examples/buyer_reconciliations_keys.dart`
  (also wraps `filters`)

- [x] Wrap mine reconciliations UI elements with TourTarget
  ✅ 2026-09-08 · Weight-reconciliation, raw-records and uploads-panel views
  wrapped in `mine_reconciliations_screen.dart`

- [x] Wrap buyer reconciliations UI elements with TourTarget
  ✅ 2026-09-08 · Summary cards, filters, tons hero tile and batches section
  wrapped in `buyer_reconciliations_screen.dart`

- [x] Add reconciliations tour steps to TourService
  ✅ 2026-09-08 · `mine.reconciliations` (navigateTo
  `/portal/mine/reconciliations`) and `buyer.reconciliations` (navigateTo
  `/portal/buyer/reconciliations`)

### Security Check-in Screen (`security_checkin_screen.dart`)

- [x] Review existing TourTarget wrappers
  ✅ 2026-09-08 · Already completed - Dashboard header wrapped at line 240-250, check-in section at line 389-432, checkout section at line 433-476

- [x] Add any missing TourTarget wrappers for key elements
  ✅ 2026-09-08 · Already completed - All key security elements have TourTarget wrappers

- [x] Verify TourService security tour uses correct keys
  ✅ 2026-09-08 · Already completed - TourService uses MineDashboardTourKeys.checkin and checkout at lines 92 and 101

### Load Controller Screen (`load_controller_screen.dart`)

- [x] Review existing TourTarget wrappers
  ✅ 2026-09-08 · Already completed - Dashboard header wrapped at line 122-132, tare weight at line 757-767, gross weight at line 795-805

- [x] Add any missing TourTarget wrappers for key elements
  ✅ 2026-09-08 · Already completed - All key weighbridge elements have TourTarget wrappers

- [x] Verify TourService weighbridge tour uses correct keys
  ✅ 2026-09-08 · Already completed - TourService uses MineDashboardTourKeys.tare and gross at lines 125 and 134

## Testing & Debugging

Automated coverage for everything testable without a device lives in
`test/features/tour/tour_system_test.dart` (17 tests, all passing).

### Tour Debug Provider

- [x] Verify `tour_debug_provider.dart` is fully functional
  ✅ 2026-09-08 · Code review (all four methods are kDebugMode-guarded and
  update `lastDebugAction`) plus automated tests
- [x] Test `resetTourCompletion()` method
  ✅ 2026-09-08 · Clears the seen flag and records the debug action
- [x] Test `startTourFromStep()` method
  ✅ 2026-09-08 · Starts at the requested step; rejects an out-of-range index
  and a step index with no tour
- [x] Test `logTourState()` method
  ✅ 2026-09-08 · Covered in `tour_system_test.dart`
- [x] Test `debugTarget()` method
  ✅ 2026-09-08 · Reports geometry for a mounted target; reports "context is
  null" for one that is not in the tree

### Cross-Screen Navigation

- [ ] Test navigation between screens during tour
  ⏳ Needs a running app (`go()` + real screen build times); the `navigateTo`
  wiring itself is verified in the TourService tests
- [ ] Verify 300ms render delay is sufficient
  ⏳ Needs a running app on device hardware
- [ ] Test navigation failure handling
- [ ] Test target finding after navigation

### Scroll-Into-View

- [ ] Test scroll-into-view for targets in scrollable content
- [ ] Test with ListView targets
- [ ] Test with SingleChildScrollView targets
- [ ] Verify scroll animation timing
  ℹ The no-scrollable-ancestor path (immediate measure, no scroll) is
  exercised by every `TourOverlay` test in `tour_system_test.dart`; the real
  scroll paths need a running app with real content

### Tooltip Positioning

- [ ] Test auto-positioning on different screen sizes
- [ ] Test on mobile (compact width)
- [ ] Test on tablet (medium width)
- [ ] Test on desktop (expanded width)
- [ ] Test manual position overrides (top, bottom, left, right)

### Target Detection

- [ ] Test target detection for all wrapped elements
  ⏳ Every key added this session was verified against its screen by code
  review and `flutter analyze`; a device run through each role's tour is the
  real proof (see End-to-End below)
- [ ] Test retry logic (3 retries with delays)
  ℹ The context-null skip path is automated; the render-object-null retry
  loop needs a target whose context exists but whose render object is
  briefly unavailable — needs a running app
- [x] Test step skipping when target not found
  ✅ 2026-09-08 · An unmounted target is skipped after its delay; a tour whose
  every target is missing runs to completion instead of wedging
- [x] Test warning logs in debug mode
  ✅ 2026-09-08 · Test run logs `TourOverlay WARNING: Target context not found
  for step ghost1` and the tour advances

### End-to-End Tour Testing

All seven need a running app, signed in as each role (start from the app-bar
help button, or `tourDebugProvider.startTourFromStep(0)` in debug builds):

- [ ] Test complete mine supervisor tour
- [ ] Test complete mine security tour
- [ ] Test complete mine load controller tour
- [ ] Test complete transporter admin tour
- [ ] Test complete transporter driver tour
- [ ] Test complete buyer admin tour
- [ ] Test generic fallback tour

### Tour Persistence

- [x] Verify tour completion persists across app restarts
  ✅ 2026-09-08 · A new `ProviderContainer` over the same mocked
  SharedPreferences restores the seen flag
- [x] Test tourSeenProvider SharedPreferences integration
  ✅ 2026-09-08 · Fresh install (unset → false), `markSeen` (true + persisted),
  `reset` (false + persisted)
- [x] Test reset functionality via debug provider
  ✅ 2026-09-08 · `TourDebugNotifier.resetTourCompletion()`
- [ ] Verify tour button shows badge for unseen tours
  ⏳ Needs the portal shell running (the badge reads `tourSeenProvider`)

## Documentation Updates

- [x] Update `INTEGRATION_GUIDE.md` with any new patterns discovered
  ✅ 2026-09-08 · New "Patterns learned during the rollout" section
- [x] Update `ONBOARDING_AUDIT.md` to mark completed items
  ✅ 2026-09-08 · Status section added at the top
- [x] Add troubleshooting tips for any issues found during testing
  ✅ 2026-09-08 · Included in the guide's troubleshooting section
- [x] Document any new best practices discovered
  ✅ 2026-09-08 · Included in the guide's patterns section

## Cleanup

- [x] Remove any commented-out old tutorial code
  ✅ 2026-09-08 · No disabled tutorial code blocks exist anywhere in `lib/`;
  the only mentions of the old system are three doc comments that name it as
  the thing each new class REPLACES
- [x] Remove any unused imports
  ✅ 2026-09-08 · Including the duplicate `mine_dashboard_keys.dart` import in
  `mine_supplier_portal_dashboard_screen.dart` that `flutter analyze` flagged
- [x] Verify no references to old TutorialOverlay remain
  ✅ 2026-09-08 · No code references — no `TutorialOverlay` widget, no
  `tutorialOverlayProvider` / `tutorialSeenProvider` / `tutorialStepsProvider`.
  Three doc comments (`tour_step.dart`, `tour_service.dart`, `tour_overlay.dart`)
  mention the old names only as historical context for what replaced them
- [x] Run `flutter analyze` and fix any issues
  ✅ 2026-09-08 · **No issues found** — fixed the duplicate-import warning and
  two `use_build_context_synchronously` lints in `tour_overlay.dart` (both
  target reads now guard on `targetContext.mounted`, which also prevents
  looking up a deactivated element after navigation)
- [x] Run `flutter test` and fix any failures
  ✅ 2026-09-08 · 2712 passing (17 new tour tests). The 2 failures the new
  wraps introduced in `requests_screen_copy_and_actions_test.dart` were fixed
  by unwrapping `TourTarget` in the test helpers. **5 failures remain and are
  PRE-EXISTING** — verified by stashing all tour work and re-running
  (`redesign_renders_test.dart`: company employees ×2, shared tail employee
  register ×2; `form_dialog_overflow_sweep_test.dart`: company employee form) —
  all employee-screen tests, unrelated to the tour system
