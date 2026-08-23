# Buyer portal — reviewer report (condensed, 2026-08-23). Task 3 of Phase 3. Verify each before fixing.

No-drift: waybills, truck-locations, compliance, tons-out, trips, waybill-none dialog, register (its italic title flagged to client), notifications (DB strings).
1. super_admin_dashboard_widgets.dart:540-551 KPI delta chip Spacer+Flexible → mid-card (all dashboards; de5a345) · c4 · orig differs (bare _Delta) [= Transporter #1].
2. super_admin_dashboard_widgets.dart:119 stack<560 → buyer "Invoice cover" (497px col at 1600) stacks View→ left, TextButton 8px inset (portal_dashboard_kit.dart:505-510) · c4.
3. minelink_charts.dart:557 'This period' hardcoded; :559-560 'Target' legend key unconditional · c6/§5.7 [= Transporter #2].
4. buyer_portal_dashboard_screen.dart:213 Trucks inbound KPI tone atMine vs :295 strip transit → transit · c5.
5. available_routes_section.dart:57-63 ActionChip label hard-clipped ("perm") no overflow · c7.
6. buyer_requests_screen.dart:65-90 FilledButton.tonalIcon + FilledButton.icon, accent on the SECOND → MlButton pair, accent first · c5/§4 [= Mine #43].
7. ml_section_title.dart:116 stacked action Align centerLeft → lone refresh icon stranded left (requests phone y≈1397, recon phone y≈2465; request_tracking_view.dart:41-46) · c2.
8. buyer_routes_mines_screen.dart:42-43 'Routes & Mines' MlSectionTitle as page title → MlPageHeader('Routes & mines') · c3+1.
9. buyer_routes_mines_screen.dart:19-24 `_tones` cycled by index :100 → one tone · c5.
10. buyer_loads_value_screen.dart:293 MlColumn('Source', flex:2, minWidth:124) → table min ~1376 on 1224 card, action col off-screen; :308 action flex:3 minWidth:96 · c7 · orig differs (no minWidths) → Source flex 3 / pin action width.
11. load_quality_table.dart:99 '2 certificates' counts loads [= Mine #15].
12. operations_hub_screen.dart:332-334, :447-449, :726-728 sans headings [= Mine #1,2,4].
13. tons_out_filter.dart:181-184 e.date midnight vs now-24h; tons_out_entry.dart:74 [= Mine #18].
14. tons_out_detail_screen.dart:163-167, _SummaryBox :220-250 [= Mine #17].
15. tons_out_detail_screen.dart:335-338 'Filters'; :609-625 DataTable heads, dates 15/08/2026 [= Mine #20-22].
16. tons_out_detail_screen.dart:88 title 'Tons out' → 'Search loads' [= Mine #22].
17. live_trip_map_view.dart:487-494 SizedBox(112)+FittedBox shrinks badge → drop · c7/§10.4.
18. company_employees_screen.dart:65 'Company Employees'; :856-868 vs :957-961 off-org role vanishes [= Mine #28-29].
19. company_list_screen.dart:247,255-284 title case; hero :218-225 sans titleLarge w700 [= Mine #45].
20. profile_screen.dart:511,527,544,562,633,662,678,716,828,989; token_access_details.dart:118-130 title case; company_token_requests_panel.dart:22-24 and company_locations_section.dart:44-49 sans card heads → MlSectionTitle · c3+1 (Shared).
21. employee_profile_screen.dart:2278 delta red → _amber (:1152) [= Mine #30].
22. buyer_reconciliations_screen.dart:131 'Total Records', :152 'Tons Delivered', :233 'All $label' ("All Source"), :172-190 hero "Tons delivered 71.12" vs card "Delivered 70.70" (mine net vs offload) → caption "mine net" · c3+6.
23. portal_trip_detail_screen.dart:120-137 hand-rolled head Row no meta; :176-183 sans values [= Mine #44] low.

NOT drift: payable line under solid (fixture); queue tones; delta > value; LOADING amber (already); card identity titles; uppercase heads; request-tracking head stack; Total Tons=; mono captions; hero tile v1; register roster; notifications DB strings; compliance subtitle sans; hub empty ledger deliberate (screen_fixtures.dart:687); blank maps; shell placeholder.
Missing: buyer dashboard dark; loads-value dark/phone; buyer recon desktop; buyer transactions; buyer-rail renders of shared screens.
