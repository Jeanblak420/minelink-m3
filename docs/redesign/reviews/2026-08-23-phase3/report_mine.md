# Mine portal — reviewer report (condensed, 2026-08-23). Verify each before fixing.

Route verdicts: operations hub (drift 1-5; renders are TRANSPORTER fixture, mine tabs unphotographed); supervisor stockpiles (6); stockpile detail (7); stockpile audit (8-11); production (12); quality (13-14); reconciliations (15); recon tables (13,15,16); tons-out (no drift); tons-out/:id (no render, no drift); tons-out-search/detail (17-22); locations (23-24); truck-locations (25-26); live-map (26-27); employees (28-29); employee profile (30-35); register (36-39); employee grid (40); buyers (41-42); compliance (no drift; transporter render); requests isMine (NO RENDER; 43); trips (no drift); trip detail (44); company (45); MlPageHeader phone wrap (46).

1. operations_hub_screen.dart:330-334 `_OperationsSummaryHeader` company name headlineSmall w800 sans in stock Card · c1 · orig same.
2. operations_hub_screen.dart:439-466 tab-card heading titleLarge w800 sans+icon, FilledButton stacked under · c1+2 → MlSectionTitle(action:).
3. Title case: operations_hub_screen.dart:635,668,678,689,837,947,1123-1124,1210,1314-1315,1426; operations_models.dart:44 ('Gate Checks'); "Mineral Catalogue","Mineral Loads","Security Incidents","Gate Checks", dialog titles Add/Edit Mineral/Transaction, Record/Edit Weighbridge Entry, Record/Edit Mineral Load, Report/Edit Security Incident, Record/Edit Gate Check · c3.
4. operations_hub_screen.dart:703-740 `_OperationsEmptyState` hand-rolled (title :726-728) → MlEmptyState · c1/§5.7.
5. fixture screen_fixtures.dart:691-711 operationsOverride zero records; render 1139-1157,1240-1276 transporter org · c6.
6. premium_overview_widgets.dart:241-246 MetricBreakdownRow values bodyLarge w800 sans (20 sites) → mono tabular · §5.3.
7. stockpile_detail_screen.dart:109-114 "Remaining on hand 559 t" titleLarge sans accent vs Fraunces cards → MlType.figure · §5.3.
8. stockpile_audit_screen.dart:56-60,64-70 two titleLarge sans headings → MlSectionTitle · c1.
9. stockpile_audit_screen.dart:222-224 "Loaded out" in error tone (red) → warn/neutral · c5 (orig red700 too).
10. stockpile_audit_screen.dart:271-276 plate breaks on phone ("truck CK 84 RT / GP") → MlPlatePill/NBSP · c7.
11. stockpile_audit_screen.dart:196-201 `_Stat`, :282-285 `_TxnRow` delta sans w800 figures → mono · §5.3.
12. mine_production_screen.dart:601-607 `_ProductionPileCard` hero figure mono 22 w800 vs Fraunces on Supervisor → MlType.figure+formatTons · §5.3.
13. load_quality_table.dart:338-345 `_pctCell` "38.0% / 42.0%" wraps at " / " (no softWrap:false); columns :183-189 MOISTURE right/SIZING left abut; ml_data_table.dart:79 gutter · c7 (also recon-tables light y≈1098).
14. ml_section_title.dart:137-138 Row crossAxis start → 48px IconButton action staggered from 14px meta (quality :59-72, ~120) · c4 · orig differs.
15. weight_reconciliation_view.dart:90 `mlCount(rows.length,'delivered load')` counts Pending rows; load_quality_table.dart:99 'certificate' counts uncertified · c6.
16. raw_recon_view.dart:766-780 `_podLink` MlTokens.accent (cf `_waybillLink` :753-758 accentInk) · c5.
17. tons_out_detail_screen.dart:203-288 five `_SummaryBox` gradient accent tiles (:226 gradient, :245-255 badge), heading row :612-614 tinted → MlStatCard ×5 · c5/§4.
18. tons_out_entry.dart:74 date truncated to midnight; tons_out_filter.dart:174-184 windows on e.date vs raw_recon_view :144-159 on timeOut → "Last 24h" 71.12 vs 103.22 · c6 · orig differs.
19. tons_out_entry.dart:72,78 'Time' = timeOut unlabelled; head tons_out_detail_screen.dart:621 → 'Time out' · c3/6.
20. tons_out_detail_screen.dart:558-566,620-627 title-case sans heads 'Truck Reg No','Net Mass'; :606-608 minWidth = window width-64 (includes 280 sidebar) clips table → MlDataTable · c3+4.
21. tons_out_detail_screen.dart:636 plate plain sans; :555 massCellColor peach tint; :640-654 → MlPlatePill, mono, no tint · §5.2,3.
22. tons_out_detail_screen.dart:334-338 'Filters' titleSmall w800 sans; :88 title 'Tons out' on Search loads page → MlSectionTitle + 'Search loads' · c1+3.
23. mine_locations_screen.dart:106-110 and company_locations_section.dart:44-49 card headings icon+titleMedium w800 sans, no meta → MlSectionTitle · c1; phone "Add location" stacks left (company_locations_section.dart:84) vs anchor Edit right (mine_locations_screen.dart:297).
24. mine_location.dart:24,28 'Main Gate','Loading Point' title case (+ mine_locations_screen.dart:112,329-332,402) · c3.
25. truck_locations_panel.dart:192-198 stale "9h" same faint tone as "4m"; :159 well always transit → warn past threshold (live_truck_marker.dart:312 has warn branch) · c5 · orig differs.
26. truck_locations_panel.dart:124-135 desktop ListView no separators/header; live_trip_map_view.dart:411-420 same → ListView.separated + MlSectionTitle · §4.
27. live_truck_marker.dart:51 highlighted marker scheme.error → accent (match vehicle_positions_map.dart:57-60) · c5.
28. company_employees_screen.dart:65,98,272,351,354,365,444,503,565,571,635,692,727 title case: 'Company Employees','Management Access Required','Remove User','No Employees Found','Add User','Accept Employee Request','Confirm Role Change','Decline Request','Edit User','Pending Request','Select Role:','Manage User And Role' · c3.
29. fixture screen_fixtures.dart:106-110 controllerWB under transporter → not drawn; screen :866-870,:953 grouping; 3 PEOPLE but 2 drawn · c6.
30. employee_profile_screen.dart:2278 `m.deltaUp ? _green : _red` → _amber (:55) · c5.
31. employee_profile_screen.dart:2187-2194 document tile well always red; statusColor :2173 unused · c5.
32. employee_profile_screen.dart:565-600 footer Wrap no width/alignment → button mid-row · c4 · orig differs (Row/Spacer).
33. employee_profile_screen.dart:927 'Message  ${e.firstName}' double space, wraps at 1600 (Row :916-975) · c7.
34. profile_setup_employer_card.dart:20 returns shrink on provider error; employee_profile_fixtures.dart:173-190 lacks employeeProfileSetupProvider override (shared_tail_fixtures.dart:782-790 has one) · c6.
35. phone: employee_profile_screen.dart:522-529 controls Wrap leaves × alone; :1064-1078 email breaks mid-token; "6 h / ago" · c4/7 low.
36. employee_register_screen.dart:562-567 'Employee '+'Register'; :579 'Live Employee Register · A read-only view…' · c3.
37. employee_register_screen.dart:61 `blue => tone(MlTone.transit)` as accent 16× (:531,:544,:566,:584,:827-832); employee_profile_screen.dart:54 _blue, gradient :1351 · c5/§5.2.
38. employee_register_screen.dart:759 Offline dot `_p.red` → slate · c5.
39. fixture shared_tail_fixtures.dart:642-676 transporter with mine-floor roles; render 4427-4446 `/portal/transporter/register` · c6.
40. employee_grid_screen.dart:40 '$companyName Employees'; no meta · c3.
41. premium_overview_widgets.dart:40-43,101-113 BuyerOverviewCard (:256) accent gradient + cyan BoxShadow on every card · c5/§4.
42. mine_supplier_buyers_detail_screen.dart:171-192 page heading is MlSectionTitle + hand Text, not MlPageHeader; phone meta/action stack left · c1+4.
43. buyer_requests_screen.dart:56-58 description no isMine branch ("transportation and product requests" — a mine raises transportation and BUYER requests); :62-92 actions in a left Wrap, FilledButton.tonalIcon (blue) beside cyan → MlPageHeader(actions) · c3,2,5. NO RENDER of isMine:true.
44. portal_trip_detail_screen.dart:174-181,141-148 codes/tonnage sans w600; facts :88-104 bare Container no header → MlType.code + MlCard/MlSectionTitle · §5.3/4.
45. company_list_screen.dart:247 'Company Information'; :255,262,263,268,281,284 'Company Name','MineLink Reference','WhatsApp Number','Organization Type','Created At','Last Updated' wrap in 130px column (:305 scale(130)); :322 reference sans → sentence/short labels, MlType.code · c3+7.
46. ml_page_header.dart:95-100 wrapped meta+actions run lands LEFT under the title on phone (employees/compliance phone y≈135-175), description below actions · c4 product-wide → trailing Wrap width: infinity + alignment end, or Column under ~560.

NOT drift (agent): Operations Hub name; caps micro-labels; snake captions; gridlines; hub two tabs (transporter policy); supervisor meta repeats; Daily (D)/Weekly (W); OverviewHeroTile sans card titles; audit AppBar (pushed); production `—` (commented); quality red breaches; dialog titles app-wide headlineSmall; `Total Tons=` mandated by CLAUDE.md; `·` wraps; MlSectionTitle <400 stacking; blank tiles harness; group heads/card titles; role-group labels; own-company identity row (documented); Ctrl K; plain-space breaks in "Updated 15 / Aug 2026" (not raised).
Missing renders: /requests isMine; operations as mine org; tons-out/:id; mine-org live-map/employees/profile/register/compliance/company/trip detail; phone stockpiles/production/quality/truck-locations/reconciliations; light anywhere but recon tables.
