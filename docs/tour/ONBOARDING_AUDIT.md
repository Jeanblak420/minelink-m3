# Onboarding Tour Audit

This document identifies key UI elements across the app that would benefit from coach-mark onboarding tours.

> **STATUS (2026-09-08)** — the dashboards (transporter, mine, buyer, driver),
> security check-in, load controller, **fleet management**, **transporter
> routes**, **buyer/mine requests**, and the **mine + buyer reconciliations**
> screens are all wrapped with `TourTarget` and wired into the role tours in
> `tour_service.dart`. Every item below is now a live tour target unless it is
> one of the noted exceptions (route-detail sheets, maintenance screen,
> pushed form screens — see `REMAINING_WORK.md` for the full mapping and the
> remaining device-testing list). Automated coverage:
> `test/features/tour/tour_system_test.dart`.

## Transporter Portal

### Dashboard Screen (`transporter_portal_dashboard_screen.dart`)
- **Fleet Status Cards** - The three key KPI cards showing On Route, Available, In Maintenance
- **Available Routes Section** - Where transporters see and accept new routes
- **Active Trips Summary** - Overview of current trips
- **Earnings Summary** - Revenue and tons moved
- **Period Selector** - Week/Month/Year toggle for data

### Fleet Management Screen (`transporter_maintenance_screen.dart`)
- **Fleet Register Table** - The main table showing all vehicles
- **Add Vehicle Button** - Key action for adding new trucks
- **Status Badges** - On Route, Available, In Maintenance indicators
- **Maintenance Records** - Service history section

### Routes Screen (`transporter_routes_screen.dart`)
- **Available Routes List** - Main list of routes to accept
- **Route Details** - Pricing, tonnage, route information
- **Accept Route Action** - Primary action for this screen

### Trips/Trucks on Route Screen (`trucks_on_route_screen.dart`)
- **Trip Cards** - Individual trip information
- **Driver Assignment** - Managing drivers per truck
- **Trip Status** - Current trip status indicators

## Mine/Supplier Portal

### Dashboard Screen (`mine_supplier_portal_dashboard_screen.dart`)
- **Stockpile Cards** - Real-time stockpile levels
- **Active Trips Summary** - Current operations overview
- **Operations Hub Link** - Access to security, weighbridge, gate operations
- **Reconciliations Summary** - Daily reconciliation status

### Operations Hub Screen
- **Navigation Tabs** - Security, Weighbridge, Gate, Production, Quality
- **Stockpile Management** - Stockpile cards and actions
- **Employee Management** - Staff assignments and roles

### Requests Screen (`request_transportation_screen.dart`)
- **Request Form** - Creating new transportation requests
- **Product Selection** - Choosing products and specifications
- **Route Definition** - Setting pickup/drop-off locations
- **Submit Request** - Primary action

### Reconciliations Screen (`mine_reconciliations_screen.dart`)
- **Reconciliation Table** - Daily reconciliation data
- **Variance Indicators** - Highlighting discrepancies
- **POD Icons** - Proof of delivery indicators

## Buyer Portal

### Dashboard Screen (`buyer_portal_dashboard_screen.dart`)
- **Orders Summary** - Active orders and status
- **Incoming Deliveries** - Expected deliveries
- **Stockpile Monitoring** - Mine stockpile levels
- **Reconciliation Status** - Delivery verification

### Requests Screen (`buyer_requests_screen.dart`)
- **Product Request Form** - Requesting products from mines
- **Order Tracking** - Monitoring order progress
- **Delivery Schedule** - Expected delivery dates

### Loads & Value Screen (`buyer_loads_value_screen.dart`)
- **Loads Table** - Detailed load information
- **Value Summary** - Cost and reconciliation data
- **Invoice Generation** - Creating invoices

## Driver App

### Driver Dashboard Screen (`driver_app_screen.dart`)
- **Trip Card** - Current trip information
- **Navigation Button** - Access to turn-by-turn navigation
- **Status Actions** - Start route, arrival check-in, POD
- **Communication** - Chat access

### Navigation Screen (`driver_navigation_screen.dart`)
- **Map View** - Turn-by-turn navigation
- **Route Instructions** - Voice and visual guidance
- **Hazard Alerts** - Safety notifications

## Common Elements

### Navigation
- **Sidebar/Rail** - Main navigation between sections
- **Bottom Navigation** - Mobile navigation (driver app)
- **Profile Menu** - User settings and logout

### Profile/Settings
- **User Profile** - Account information
- **Company Settings** - Organisation configuration
- **Theme Toggle** - Light/dark mode switch
- **Notifications** - Notification preferences

### Communication
- **Chat Dock** - Messaging launcher
- **Notification Bell** - Alerts and notifications
- **Messages Screen** - Conversation list

## Tour Strategy

### Priority 1: Core Workflow (First 5-7 steps)
1. Dashboard overview (key KPIs)
2. Primary action (e.g., accept route, create request)
3. Navigation to key feature
4. Key feature overview
5. How to monitor/tracking

### Priority 2: Secondary Features (3-5 steps)
- Fleet management (transporter)
- Stockpile monitoring (mine)
- Order tracking (buyer)
- Trip monitoring (all portals)

### Priority 3: Advanced Features (2-3 steps)
- Reconciliations
- Maintenance
- Communication

## Implementation Notes

- Each tour should be 5-10 steps maximum to avoid overwhelming users
- Focus on the most valuable features first
- Cross-screen navigation should be used sparingly
- Targets should be stable UI elements (not dynamic lists)
- Provide actionable guidance, not just explanation
