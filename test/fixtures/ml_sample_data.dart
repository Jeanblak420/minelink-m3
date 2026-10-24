// Sample/fixture data for the insights-v2 console widgets.
//
// S3-11 / S3-12 (P5-03, P1-26, P9 items), moved here 2026-08-13.
//
// These classes used to live in `lib/features/super_admin/widgets/insights_v2/`.
// Nothing in `lib/` referenced them any more — P9-03 had already removed the
// constructor DEFAULTS that let a caller omit an argument and silently render
// fabricated platform figures — but they still shipped inside the library, and
// they carried the last hardcoded `spark:` trend arrays in the tree
// (`[4, 6, 5, 7, 6, 8, 7, 9, 8, 10]` and two more), which is exactly what S3-12
// forbids.
//
// They are fixtures, not product data, and widget tests legitimately need
// fixtures — so they are MOVED rather than deleted. Deleting them, as S3-11's
// wording said, would have taken 5 test files' data with them and bought
// nothing: the defect was that invented figures shipped in the app, not that
// invented figures exist in a test.
//
// Carried across verbatim, so the extraction cannot have altered any value.

import 'package:flutter/material.dart';
import 'package:flutter_application_1/features/super_admin/widgets/insights_v2/minelink_screens_core.dart';

// ===========================================================================
// SECTION 4 — Sample data
// ===========================================================================

/// Everything the two screens render, in one place. Swap these for your real
/// repository calls — the widgets take the data as constructor arguments and
/// never reach for these directly.
class MlSampleData {
  const MlSampleData._();

  // ---- Dashboard ---------------------------------------------------------

  static const List<MlOrgAggregate> orgAggregates = <MlOrgAggregate>[
    MlOrgAggregate(
      id: 'insights.transporters',
      title: 'Transporters',
      subtitle: '6 organizations · 42 fleet',
      icon: Icons.local_shipping_outlined,
      tone: MlChipTone.cyan,
      metrics: [
        MapEntry('Trips', '1,248'),
        MapEntry('Tons', '55,340 t'),
        MapEntry('Fleet', '42'),
      ],
      spark: [4, 6, 5, 7, 6, 8, 7, 9, 8, 10],
      sparkColor: Color(0xFF5FA8FF),
    ),
    MlOrgAggregate(
      id: 'insights.buyers',
      title: 'Buyers',
      subtitle: '7 organizations · 22 buyer users',
      icon: Icons.shopping_cart_outlined,
      tone: MlChipTone.violet,
      metrics: [
        MapEntry('Orders', '318'),
        MapEntry('Tons', '41,860 t'),
        MapEntry('Value', 'R14.2m'),
      ],
      spark: [5, 4, 6, 5, 7, 6, 8, 7, 9, 8],
      sparkColor: Color(0xFFB98CFF),
    ),
    MlOrgAggregate(
      id: 'insights.mines',
      title: 'Mines / Suppliers',
      subtitle: '11 organizations · 6 active pits',
      icon: Icons.terrain_rounded,
      tone: MlChipTone.amber,
      metrics: [
        MapEntry('Tons', '74,040 t'),
        MapEntry('Loads', '21,338'),
        MapEntry('Users', '89'),
      ],
      spark: [3, 4, 4, 5, 6, 6, 7, 8, 9, 11],
      sparkColor: Color(0xFFF0A55F),
    ),
  ];

  static const List<MlPendingRequest> pendingRequests = <MlPendingRequest>[
    MlPendingRequest(
      id: 'requests.mine-transport',
      label: 'Requested routes',
      icon: Icons.alt_route_rounded,
      count: 1,
      sub: 'Buyers request mine — dispatch routes to be opened.',
      tone: MlChipTone.cyan,
    ),
    MlPendingRequest(
      id: 'requests.product',
      label: 'Requested product',
      icon: Icons.inventory_2_outlined,
      count: 2,
      sub: 'Buyers or mines request a new product listing.',
      tone: MlChipTone.violet,
    ),
    MlPendingRequest(
      id: 'requests.buyers',
      label: 'Requested buyers',
      icon: Icons.person_add_alt_1_outlined,
      count: 1,
      sub: 'Mines request buyer connections and roster access.',
      tone: MlChipTone.amber,
    ),
  ];

  static const List<MlRegistryStat> registry = <MlRegistryStat>[
    MlRegistryStat(
      id: 'orgs',
      label: 'Total companies',
      value: '24',
      icon: Icons.apartment_rounded,
      tone: MlChipTone.cyan,
      sub: 'across 4 org types',
      delta: '2',
      deltaTone: MlDelta.up,
    ),
    MlRegistryStat(
      id: 'orgs.active',
      label: 'Active',
      value: '20',
      icon: Icons.check_circle_outline_rounded,
      tone: MlChipTone.green,
      sub: 'tokens valid · 100% up',
      delta: '83% healthy',
      deltaTone: MlDelta.good,
    ),
    MlRegistryStat(
      id: 'orgs.expired',
      label: 'Expired',
      value: '3',
      icon: Icons.timer_off_outlined,
      tone: MlChipTone.amber,
      sub: 'action needed',
      delta: '1',
      deltaTone: MlDelta.warn,
    ),
    MlRegistryStat(
      id: 'orgs.suspended',
      label: 'Suspended',
      value: '1',
      icon: Icons.block_rounded,
      tone: MlChipTone.red,
      sub: 'manually held',
      delta: 'unchanged',
      deltaTone: MlDelta.flat,
    ),
    MlRegistryStat(
      id: 'users',
      label: 'Total users',
      value: '186',
      icon: Icons.groups_outlined,
      tone: MlChipTone.blue,
      sub: 'across all orgs',
      delta: '14',
      deltaTone: MlDelta.up,
    ),
    MlRegistryStat(
      id: 'tokens.requests',
      label: 'Open token requests',
      value: '3',
      icon: Icons.token_outlined,
      tone: MlChipTone.amber,
      sub: 'awaiting approval',
      delta: '2',
      deltaTone: MlDelta.warn,
    ),
    MlRegistryStat(
      id: 'users.active',
      label: 'Active users right now',
      value: '14',
      icon: Icons.bolt_rounded,
      tone: MlChipTone.cyan,
      sub: 'using the app · last 2 min',
      delta: 'Live',
      deltaTone: MlDelta.live,
    ),
    MlRegistryStat(
      id: 'insights.mines',
      label: 'Total tons managed',
      value: '171,240',
      unit: 't',
      icon: Icons.scale_rounded,
      tone: MlChipTone.green,
      sub: 'Jan → today',
      delta: '6.4%',
      deltaTone: MlDelta.up,
    ),
  ];

  static const List<MlRecentOrg> recentOrgs = <MlRecentOrg>[
    MlRecentOrg(
      id: 'r1',
      name: 'Iron Hills Mining',
      type: 'Mine',
      status: 'Active',
      location: 'Johannesburg',
      users: 62,
      seatsUsed: 5,
      seats: 5,
      expiry: '42d 08 : 34 : 55',
      date: "12 Aug '26",
      expiryState: MlExpiry.ok,
      avatarColors: [Color(0xFF6D8BFF), Color(0xFF9B6CF0)],
    ),
    MlRecentOrg(
      id: 'r2',
      name: 'Atlas Buyer Group',
      type: 'Buyer',
      status: 'Idle',
      location: 'Cape Town',
      users: 18,
      seatsUsed: 3,
      seats: 3,
      expiry: '13d 03 : 11 : 55',
      date: "17 Jul '26",
      expiryState: MlExpiry.warn,
      avatarColors: [Color(0xFFF472B6), Color(0xFFA855F7)],
    ),
    MlRecentOrg(
      id: 'r3',
      name: 'Roadhaul Logistics',
      type: 'Transporter',
      status: 'Active',
      location: 'Durban',
      users: 24,
      seatsUsed: 4,
      seats: 4,
      expiry: '02d 18 : 46 : 05',
      date: "06 Jul '26",
      expiryState: MlExpiry.warn,
      avatarColors: [Color(0xFFFB9A4B), Color(0xFFF97316)],
    ),
    MlRecentOrg(
      id: 'r4',
      name: 'Northern Coal Co.',
      type: 'Mine',
      status: 'Active',
      location: 'Emalahleni',
      users: 38,
      seatsUsed: 4,
      seats: 6,
      expiry: '78d 22 : 04 : 12',
      date: "20 Sep '26",
      expiryState: MlExpiry.ok,
      avatarColors: [Color(0xFF4ADE80), Color(0xFF10B981)],
    ),
    MlRecentOrg(
      id: 'r5',
      name: 'Sable Mercantile',
      type: 'Buyer',
      status: 'Token expired',
      location: 'Gqeberha',
      users: 8,
      seatsUsed: 1,
      seats: 2,
      expiry: 'Expired · 5d ago',
      date: "29 Jun '26",
      expiryState: MlExpiry.expired,
      avatarColors: [Color(0xFFFBBF24), Color(0xFFF59E0B)],
    ),
  ];

  // ---- Transporters overview --------------------------------------------

  static const String period = 'Aug 2026 · MTD';
  static const String updated = '2 min ago';

  static const List<double> augDaily = [
    1148, 1205, 1160, 1288, 1332, 1240, 1376, 1338, 1412, 1355, 1462, 1400,
    1470, 1426, 1508, 1472, 1548, 1495, 1612, 1520, 1486, 1534, 1412,
  ];

  static const List<double> julDaily = [
    1005, 1068, 1032, 1118, 1160, 1092, 1188, 1150, 1215, 1170, 1242, 1198,
    1256, 1220, 1280, 1246, 1305, 1262, 1330, 1288, 1252, 1296, 1198,
  ];

  static const List<double> railTrend = [
    12, 14, 13, 16, 15, 17, 16, 18, 17, 19, 21, 20, 22, 24, 23, 26, 25, 28,
    30, 29, 32,
  ];

  /// Fleet distribution. This used to be a three-way split sitting beside a
  /// separate utilisation donut; the two carried the same story from different
  /// angles, so they're now one ring — per-company counts around the outside,
  /// the utilisation figure in the middle.
  static const List<MlDonutSegment> fleetSegments = <MlDonutSegment>[
    MlDonutSegment('Roadhaul Logistics', 32, Color(0xFF22D3EE)),
    MlDonutSegment('Trans African Haul', 23, Color(0xFFA78BFA)),
    MlDonutSegment('Corridor Freight', 22, Color(0xFFF472B6)),
    MlDonutSegment('b man trans', 12, Color(0xFF64748B)),
    MlDonutSegment('Land Rover', 7, Color(0xFF334155)),
  ];

  /// Percentage of the fleet currently in use — the donut's centre figure.
  static const int fleetUtilisedPct = 33;

  /// Retained so existing callers keep compiling. Prefer [fleetSegments].
  @Deprecated('Merged into fleetSegments — the utilisation donut is gone.')
  static const List<MlDonutSegment> utilSegments = fleetSegments;

  static const List<MlBoardRow> leaderboard = <MlBoardRow>[
    MlBoardRow('01', 'Roadhaul Logistics', '12,460.8 t'),
    MlBoardRow('02', 'Trans African Haul', '9,580.0 t'),
    MlBoardRow('03', 'Corridor Freight', '6,800.0 t'),
    MlBoardRow('04', 'b man trans', '0.0 t', idle: true),
  ];

  static const List<MlAlert> alerts = <MlAlert>[
    MlAlert(
      kind: 'w',
      icon: Icons.warning_amber_rounded,
      title: 'Capacity review needed',
      detail: 'Roadhaul Logistics trending 88% fleet utilisation',
      age: '12m',
    ),
    MlAlert(
      kind: 'g',
      icon: Icons.check_circle_outline_rounded,
      title: 'Daily reconciliation complete',
      detail: 'All movement totals matched successfully',
      age: '45m',
    ),
    MlAlert(
      kind: 'b',
      icon: Icons.schedule_rounded,
      title: 'Waybill follow-up pending',
      detail: '18 open records >24h need review before closeout',
      age: '1h',
    ),
    MlAlert(
      kind: 'w',
      icon: Icons.warning_amber_rounded,
      title: 'Cyberhouse Transporter idle',
      detail: 'No trips recorded in 24 days — verify account status',
      age: '3h',
    ),
  ];

  static const List<MlTransporter> transporters = <MlTransporter>[
    MlTransporter(
      code: 'RH',
      name: 'Roadhaul Logistics',
      badges: [MapEntry('Top volume', 'c'), MapEntry('96% PoD', 'g')],
      employees: 54,
      drivers: 28,
      fleet: 42,
      routes: 9,
      trips: 18,
      tons: '12,420.5',
      waybillsDone: 140,
      waybillsOpen: 6,
      utilization: 91,
      waybillsClosedPct: 96,
      activity: '3m ago',
      tempo: [10, 14, 12, 18, 17, 22, 26, 24, 29, 28, 32, 30, 36, 38, 42],
    ),
    MlTransporter(
      code: 'TH',
      name: 'Trans African Haul',
      badges: [MapEntry('Steady ops', 'c'), MapEntry('96% PoD', 'g')],
      employees: 26,
      drivers: 22,
      fleet: 31,
      routes: 7,
      trips: 14,
      tons: '9,880.1',
      waybillsDone: 96,
      waybillsOpen: 9,
      utilization: 87,
      waybillsClosedPct: 93,
      activity: '19m ago',
      tempo: [8, 10, 9, 13, 15, 14, 16, 15, 20, 22, 21, 25, 24, 27, 26],
    ),
    MlTransporter(
      code: 'CF',
      name: 'Corridor Freight',
      badges: [MapEntry('Late files', 'w'), MapEntry('89% PoD', 'b')],
      employees: 19,
      drivers: 16,
      fleet: 23,
      routes: 5,
      trips: 10,
      tons: '6,940.1',
      waybillsDone: 82,
      waybillsOpen: 3,
      utilization: 76,
      waybillsClosedPct: 88,
      activity: '2h ago',
      tempo: [14, 12, 15, 11, 13, 10, 12, 9, 11, 10, 12, 11, 13, 10, 12],
    ),
  ];
}
