# Driver app — reviewer report (condensed, 2026-08-23). Task 5 of Phase 3; do NOT start before Mine/Buyer/Transporter are ticked.

Renders looked at: screen-driver-app-dashboard-phone-dark, -delivered-phone-dark, -tablet-dark, screen-account-setup-prompt-phone-dark, screen-driver-app-trip-phone-dark, dash-driver-trip-phone-dark/light, screen-driver-app-profile-phone-dark, screen-driver-navigation-phone-dark, -no-route-phone-dark, screen-hazard-report-phone-dark, screen-notifications-phone-dark, screen-drop-off-phone-dark (no drift), portal-driver-phone-dark (shell, no drift).

Findings (file:line · class · original):
1. driver_app_screen.dart:445 `_DashboardHeader` titleLarge sans w800 "Dashboard"/"Profile" (called :257, :1065) · class 1 · orig same → MlPageHeader.
2. driver_app_screen.dart:778 `_MiniStat` headlineSmall sans w800 numerals, no tone bar (card :762) · class1/§5.3,5 · orig same → MlStatCard.
3. driver_app_screen.dart:837–845 "Tons delivered"/"This week" titleMedium sans w800 heading · class 1 → MlSectionTitle with meta.
4. driver_app_screen.dart:927 week-chart bars use `MlTone.accent.well()` (~1.3:1 on card) · class 5 → accent at alpha .55 for non-today.
5. driver_routes_screen.dart:443/:454/:492 "Current Trip" titleLarge sans w800 · class 3+1 → MlSectionTitle('Current trip', action: badge).
6. driver_routes_screen.dart:716–719 "Recent Trips" titleMedium sans w800 · class 3+1 → MlSectionTitle('Recent trips', meta: mlCount).
7. driver_routes_screen.dart:382 stats-strip numerals titleLarge sans · §5.3 → editorial face.
8. driver_routes_screen.dart:100–106 Trip tab has no page header/meta · §5.4 → MlPageHeader('Trip', meta plate/status).
9. driver_routes_screen.dart:542 Navigate is MlButton.go (green), :550 Directions primary (cyan) — two filled emphases · class 5 → Navigate primary, Directions tonal; Upload POD (:591) and Start route (:532) stay go.
10. driver_app_screen.dart:1069 profile identity MlCard sizes to content (276px in 380 col) · class 4 → SizedBox(width: double.infinity).
11. driver_app_screen.dart:1233 trip history date `toString().substring(0,16)` vs MlTime.day/clock elsewhere · copy → `${MlTime.day} · ${MlTime.clock}`.
12. driver_navigation_screen.dart:848 `_fmtDistance` "4.0 / km" breaks between figure and unit (also `_fmtMeters`) · class 7 → NBSP.
13. driver_navigation_screen.dart:1424 "then Turn right…" mid-sentence capital · class 3 → lowercase first char.
14. driver_navigation_screen.dart:1537 late "+N min" in MlTone.error · class 5 → warn.
15. core/widgets/osm_tile_layer.dart:168 RichAttributionWidget default black (i) invisible on dark (all five maps) · class 5 → openButton with textMuted icon. (orig differs — orig nav had no attribution.)
16. widgets/hazard_report_sheet.dart:37–40 + models/mine_hazard.dart:53–59 "Blasting Zone","Slow Haulage","Road Closure" · class 3.
17. test/fixtures/shared_tail_fixtures.dart:768–769 driver setup prompt lists "Tax clearance certificate" (company doc) under audience employee · class 6 → own missingRequired for kDriverProfileSetup (:816).
18. notifications/models/notification_model.dart:70–97 NotificationType.displayName mixed case ("Driver Assigned","Profile Update","Role Assigned","Vehicle Status Changed") · class 3 (shared — Shared task). Plate "CK 84 / RT GP" wraps in body text (fixture :~476; live from server) · class 7, flag only.
19. tabs/screens/driver_tab_screen.dart:47,77,88 "Driver Workspace","Update Profile","Loads Console"; link label "My workspace" at driver_app_screen.dart:1002 · class 3. Also `_pushScreen` (:121) stock AppBar title duplicates MlPageHeader on pushed screens (low).
20. driver_app_screen.dart:303/:329 stat cards fixed 2×2 at 1024px tablet · §5.6 low → MlTileGrid/Wrap.

NOT drift: hero gradient (sanctioned exception), four-hue wells, primary bright in light (shared), amber bell, drop-off card title, blank tiles (harness), MlAppShell bar in harness, Dashboard highlight on leaf routes, lifecycle gating, End danger, "1 Loads" nit.
Missing renders: POD dialog; Trip tab with recent/other/empty states; trip history; DriverTabScreen; truck positions; truck locations phone; waybill modal; driver-chrome notifications; light for Dashboard/Trip/Profile/navigation/hazard/drop-off.
