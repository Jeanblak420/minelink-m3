# Transporter portal — reviewer report (condensed, 2026-08-23). Task 4 of Phase 3. Verify each before fixing.

No-drift: truck-locations, tons-out(+search, mine render), trips(+detail), drop-off, live-map (console-owned).
1. super_admin_dashboard_widgets.dart:540-552 KPI tile `Spacer()` + `Flexible(_Delta)` → delta chip mid-card (all three dashboards via portal_dashboard_kit.dart:221) · c4 · orig differs (bare _Delta) → ConstrainedBox/unflexed.
2. minelink_charts.dart:557 legend 'This period' ignores latestLabel; :560 'Target' key unconditional (no target plotted) · c8/§5.7 · orig same; shared with console overview.
3. transporter_portal_dashboard_screen.dart:467-494 MlDonut no legend (MlDonut minelink_charts.dart:812 has no legend slot); also mine :476, buyer :426 · §4 → legend rows.
4. fleet_management_screen.dart:38,52,68,91,132,178,249,298,383,423,471; fleet_vehicle_table.dart:212-291,413,449,473,497,587,595,611 title case ("Fleet Management","Fleet Register","Total Fleet","Inactive Vehicles","Register Truck","Add Vehicle","Unassign Driver","Mark Vehicle as Inactive","Reactivate Vehicle","1st Trailer","Assigned Driver","ID Number","ID Doc","Passport Number","Passport Doc","Work Permit Doc","License Doc","View Doc") · c3.
5. fleet_vehicle_table.dart:162-166 Material DataTable filled heading; :182-300 sans bold heads; plates sans; '-' vs '—' (:106,112 vs :365…) · §4/§5.3.
6. fleet_vehicle_table.dart:518-551 `_statusChip` solid gradient pill, red for Unassigned (:525,:537) → MlStatusBadge done/neutral · c5.
7. fleet_vehicle_table.dart never reads fleetStatusProvider — no ON ROUTE/IN MAINTENANCE per row (test comment redesign_renders_test.dart:1102-1108 claims it) · c6.
8. fleet_management_screen.dart:169 `cols = w>900?4:2` never 1 → mono captions break mid-token on phone ("carrying_a_lo/ad") · c7 → 1 col under 560.
9. fleet_management_screen.dart:89-93 FAB "Add vehicle"; header actions :67-86 Refresh only → MlPageHeader action · §4.
10. trucks_on_route_screen.dart:49 'Trucks On Route', :73 'On Route' · c3.
11. ml_status_badge.dart:47-55 no 'on route' match → trucks_on_route_screen.dart:177,250 'On route' and transporter_drivers_screen.dart:353-354 'Driver on route' pills grey · c5 → add 'on route' to transit.
12. fixture portal_capture_fixtures.dart:980-988 kFleetStatus sets driverName not drivers; fleet_vehicle_status.dart:69-81 reads drivers only → on-route truck shows "No driver assigned" · c6.
13. fixtures kFleetStatus (:980-1000) vs kVehicleDrivers (:1029-1048) vs trips (~:215) disagree on which truck is on route · c6.
14. transporter_drivers_screen.dart:223-262 `_Stat` titleLarge w800 sans, no bar → MlStatCard · §5.3/5.
15. transporter_maintenance_screen.dart:775 'R ${cost.toStringAsFixed(2)}', :951 toStringAsFixed(0), :776 km ungrouped → NumberFormat like earnings_screen.dart:20-28 (shared mlRand?) · §5.3.
16. earnings_screen.dart:24-28 "R-61,023" → '−R61,023' (match PortalKpiRow.formatDelta) · §5.3.
17. ml_page_header.dart:96-134 inner Wrap has no width → wrapped second-row button floats mid-row on phone (fuel-costs phone y≈135-225) · c4 product-wide (same as Mine #46).
18. transporter_request_tracking_screen.dart:29-37 + request_tracking_view.dart:35-47 page title repeated as section title with same meta · §5.4.
19. ml_section_title.dart:138 CrossAxisAlignment.start → action button hangs below meta (maintenance, request tracking) · c4 (same as Mine #14).
20. transporter_reconciliations_screen.dart:63-68 "Reconciliation batches" bare titleMedium w800 sans → MlSectionTitle (check mine/buyer recon screens) · c1.
21. weight_reconciliation_view.dart:91 '3 delivered loads' counts Pending · c6 (same as Mine #15).
22. company_employees_screen.dart:65 'Company Employees'; :856-868 + :958-961 off-org role vanishes; fixture screen_fixtures.dart:100-112 · c3/c6 (same as Mine #28-29).
23. company_list_screen.dart:247,255,261,262,268,282,284 title case (same as Mine #45).
24. notification_model.dart:68-108 NotificationType.label title case; fleet_notification_service.dart:81; notification_service.dart:361,371; fixture shared_tail_fixtures.dart:476 · c3 (Shared).
25. profile_screen.dart:511,527,544,562,633,662,678,716,828,989; token_access_details.dart:118,122,126,138 title case ("Company Information","CEO Information","CEO First Name","Update Profile","Token Assigned","Token Lifetime","Token Expiration","Token Expires in") · c3 (Shared).
26. company_token_requests_panel.dart:15-19 Card sizes to content in profile_screen.dart:462-463 column → full width · c4 (Shared).
27. dispatch_route_widgets.dart:269-273 sheet title titleLarge w800 sans; :338-342 'Trips' heading; :511-513 metric values sans accent PortalColors → figure/editorial · c1/§5.
28. transporter_routes_screen.dart:208-214 trip status as muted subtitle text → MlStatusBadge · c5.
29. compliance_screen.dart:107-150 doc list no section head/meta → MlSectionTitle('Documents') · §5.4 minor.
30. fixtures portal_tail_fixtures.dart:358,691 TN 55 QQ GP not in fleet; recon/tracking rows other transporters under Fixture Haulage · c6 low.

NOT drift: Fleet state head stacked (<560 branch); net profit red for loss; MlButton.go green (documented); variance severity; card item titles; uppercase pills; gridlines; fuel Log cost/Log fuel; drop-off card heading; R/ton chip; blank map; shared screens rendered as mine.
Missing renders: accept-route sheet + _AssignTrucksDialog; DriverAssignmentDialog; transporter live-map; transporter trips/tons-out; light for most; phone for routes/maintenance/earnings/truck-locations/recon; desktop trucks-on-route/drop-off.
